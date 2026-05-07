## Context

`nyavana/pvz-fpga` is a SystemVerilog DE1-SoC project that the maintainer works on with Claude Code. AI agents currently see HDL files as opaque text — no parse errors, no go-to-def, no symbol awareness — because Claude Code's official LSP plugins cover only general-purpose languages (C/C++, Go, Python, Rust, etc.) and no HDL.

Two adjacent ecosystems already exist and shape the design space:

1. **HDL LSPs are mature.** Verible (CHIPS Alliance, weekly releases, single static binary), rust_hdl (`vhdl_ls`), hudson-trading/slang-server (open-sourced 2025-08, prebuilt binaries), and a few stale alternatives (svlangserver, veridian) cover SV/Verilog/VHDL well — for human editors.
2. **Claude Code has native LSP plugin support.** Plugins declare LSPs in JSON via `.lsp.json`; the platform handles bridging, diagnostics-on-edit, and go-to-def. Generic MCP-LSP bridges (`isaacphi/mcp-language-server`, `jonrad/lsp-mcp`, `bug-ops/mcpls`, `blackwell-systems/agent-lsp`) exist and are redundant given the native pathway.

The constraint that drove the design is **one-click install on Linux x64** for the maintainer's daily workflow on `pvz-fpga`. Verible publishes prebuilt binaries for every major OS/arch but Claude Code LSP plugins do not bundle the binary itself — the user must install it separately. v1 closes that gap on Linux x64 with a SessionStart auto-installer; other platforms are deferred.

A second non-obvious constraint: Verible's go-to-def and find-references silently fall back to single-file analysis unless a `verible.filelist` is present (or pointed at via `--file_list_path`). Without explicit handling, the agent's experience on a multi-module project (every real FPGA codebase) is degraded in a way that's invisible to the user. v1 must generate a filelist — but it must NOT clobber a project-owned `verible.filelist` at the workspace root, since many curated projects rely on explicit ordering for elaboration.

A third constraint surfaced during review: the SessionStart hook's `CLAUDE_ENV_FILE` mechanism is documented to propagate to subsequent **Bash** commands, not necessarily to LSP server subprocesses spawned from `.lsp.json`. Relying on hook-side `PATH` mutation to make a downloaded Verible binary visible to the LSP is fragile. v1 routes LSP startup through plugin-owned wrapper scripts that resolve the binary at exec time; the SessionStart hook becomes a fast-path optimization (pre-warm the install, generate the filelist) rather than load-bearing for LSP correctness.

The companion plugin `fpga-flow` (synthesis MCP wrapping Yosys/Verilator/Quartus) is intentionally out of scope: Quartus is license-gated and unbundleable, synthesis is multi-minute (needs a job-id MCP pattern), and report parsing is version-fragile. Coupling its release cadence to v1 would block shipping.

## Goals / Non-Goals

**Goals:**
- Ship a Claude Code plugin that turns `/plugin install fpga-lsp@fpga-lsp` into working LSP intelligence (diagnostics, go-to-def, find-references, hover) for `.sv`, `.svh`, `.v`, `.vh`, `.vhd`, `.vhdl` on Linux x64 with zero further user action.
- Make cross-file go-to-def work on multi-module SystemVerilog projects out of the box — by respecting an existing project-owned `verible.filelist` when present, and otherwise auto-generating one in plugin-owned storage and pointing Verible at it via `--file_list_path`.
- Provide three Verible CLI wrapper skills (`sv-lint`, `sv-format`, `sv-diff`) and one HDL-specific reviewer agent (`sv-reviewer`) that earn their keep through stable invocation surface and HDL judgment, not by re-implementing Verible.
- Keep the marketplace structure ready for a future `fpga-flow` plugin without coupling release cadences.
- Validate end-to-end against `nyavana/pvz-fpga` before declaring v1 done.

**Non-Goals:**
- Building a new HDL LSP. Verible and rust_hdl exist; v1 wires them up.
- Building a generic MCP-LSP bridge. Claude Code's native LSP plugin support is the right surface; bridges are redundant.
- macOS / Windows / Linux-arm64 auto-install in v1. Verible publishes binaries for these but per-OS smoke testing is deferred to v1.1.
- Bundling slang-server. It's the planned v1.1 opt-in for deeper analysis; v1 ships Verible only.
- Synthesis feedback (Yosys/Verilator/Quartus). That's `fpga-flow`, a separate plugin in the same marketplace, post-v1.
- Project-file parsing (`.qsf`, `.xpr`). Deferred.
- Bundling veridian or svlangserver. Both stale; explicitly skipped.

## Decisions

### Decision 1: Native Claude Code LSP plugin, not an MCP-LSP bridge
**Choice:** Use Claude Code's native `.lsp.json` plugin format (declared in the plugin manifest).
**Alternatives considered:** Fork `isaacphi/mcp-language-server` (Go), `jonrad/lsp-mcp` (TypeScript), `bug-ops/mcpls` (Rust), or `blackwell-systems/agent-lsp` and configure for HDLs.
**Rationale:** The native pathway gives automatic diagnostics-on-edit (the platform feeds them to the agent without an explicit tool call), is JSON-only with zero code to maintain, and matches how all official Claude Code language plugins ship. A bridge would add binary distribution, a runtime, and a worse UX (the agent would have to call a tool to see diagnostics) for no win.

### Decision 2: Verible as the v1 SystemVerilog default; slang-server deferred to v1.1
**Choice:** Ship Verible (`verible-verilog-ls`) as the default SV LSP. Defer `hudson-trading/slang-server` to a v1.1 opt-in.
**Alternatives considered:** slang-server as default, svlangserver, veridian, svls.
**Rationale:** Verible has the broadest binary coverage (every major OS/arch from a single CI), the longest track record (1.8k stars, weekly releases), and ships lint/format/diff CLIs reused by the v1 skills — one binary covers LSP + skills. slang-server is more spec-compliant on cross-module elaboration but is younger (v0.2.5, 217 stars) and would split the binary footprint. svlangserver is dormant (single 2025 commit after a 2-year gap). veridian lags slang releases and is Linux-only. svls is lint-only. Verible's known weakness — silent single-file fallback without a filelist — is mitigated by Decision 4.

### Decision 3: rust_hdl (`vhdl_ls`) as the v1 VHDL default, user-installed via `cargo install` plus library config
**Choice:** Wire `vhdl_ls` in `.lsp.json`. Do not auto-install in v1; document the full setup in the README — `cargo install vhdl_ls` for the binary AND a `vhdl_ls.toml` (or `VHDL_LS_CONFIG` env var) pointing at the user's standard libraries.
**Alternatives considered:** ghdl-ls, VHDL-tool; auto-install rust_hdl via a binary release; assume `cargo install` alone is enough.
**Rationale:** rust_hdl is the obvious VHDL LSP choice and has prebuilt binaries, but `pvz-fpga` is SystemVerilog-first — VHDL coverage is a "don't leave it broken" concern, not a daily workflow. The non-obvious gotcha is that `cargo install vhdl_ls` produces only the binary; analysing real VHDL needs `vhdl_ls.toml` configured with `std_logic_1164` and other standard libraries. The original v1 README guidance omitted this and would have left users with a binary that errored on every `library ieee;` declaration. v1 README now ships the complete recipe; auto-install (binary + libraries) can wait until a VHDL user actually needs it.

### Decision 4: LSP wiring goes through plugin-owned wrapper scripts, not bare commands
**Choice:** `.lsp.json` `command` fields point to wrapper scripts under `${CLAUDE_PLUGIN_ROOT}/bin/` (`verible-ls`, `vhdl-ls`). Each wrapper resolves the binary at exec time: check `$PATH`, then `${CLAUDE_PLUGIN_DATA}/bin/`, then (Verible only, on Linux x64) trigger `install-verible.sh`, then exec with the right args. If no binary can be found, the wrapper prints a single human-readable error pointing at the README and exits non-zero.
**Alternatives considered:** Bare `command: "verible-verilog-ls"` with PATH set by SessionStart; `.lsp.json` `env` field to set PATH.
**Rationale:** Claude Code's docs promise `CLAUDE_ENV_FILE` propagation to subsequent Bash commands, not to LSP subprocesses. Relying on hook-side PATH mutation is fragile: if the SessionStart hook didn't run (cold session, hook regression), the LSP wouldn't start. Wrappers move binary resolution into the LSP startup path itself, where it's correctness-critical. They also give us a single place to (a) pass project-aware args like `--file_list_path` and `--rules_config_search`, and (b) emit a useful error on missing `vhdl_ls` (Claude Code's native "command not found" path is generic and can't reference our README). The `${CLAUDE_PLUGIN_ROOT}` and `${CLAUDE_PLUGIN_DATA}` substitutions are documented in the plugins reference.

### Decision 5: Verible LSP launched with `--rules_config_search` and explicit `--file_list_path`
**Choice:** The `verible-ls` wrapper invokes `verible-verilog-ls --rules_config_search --file_list_path=<resolved-path>`.
**Alternatives considered:** Default args; require the user to set `verible.filelist` at the workspace root and let Verible auto-discover.
**Rationale:** `--rules_config_search` makes Verible walk up the tree looking for `.rules.verible_lint`, so projects that ship a lint config (like real teams do) get respected — without it, diagnostics are noisy and ignore the project's intent. `--file_list_path` is required because Decision 6 writes the filelist to plugin-managed storage when there's no project-owned one; auto-discovery only finds workspace-root `verible.filelist`. Wiring both at the plugin level means every user gets the right behavior without a per-project setup step.

### Decision 6: Filelist generation respects project ownership; plugin-managed copy lives outside the workspace
**Choice:** `gen-filelist.sh` (run from SessionStart and as a lazy fallback from the wrapper) checks for an existing `verible.filelist` at the workspace root. If present, the wrapper passes its absolute path via `--file_list_path` and the script does NOT touch it. If absent, the script walks the workspace, collects `.sv`/`.svh`/`.v`/`.vh` files (skipping `.git/`, `build/`, `output_files/`, `simulation/`, `node_modules/`), and writes a plugin-managed filelist to `${CLAUDE_PLUGIN_DATA}/filelists/<workspace-hash>.filelist`. The wrapper passes that path via `--file_list_path`.
**Alternatives considered:** Always write `verible.filelist` to the workspace root (original v1 plan); require the user to commit a filelist; generate once and cache; require an explicit slash command.
**Rationale:** The original "always write to workspace root" plan would clobber project-owned filelists, which real FPGA projects curate with explicit ordering for elaboration — silent data loss is unacceptable. Respecting an existing file delegates to the project's intent; writing the auto-generated copy under `${CLAUDE_PLUGIN_DATA}` keeps plugin state out of the user's working tree (no surprise commits, no `.gitignore` edits required). Hashing the workspace path keeps multiple project filelists isolated. Regeneration on every session stays cheap and avoids stale-cache footguns; the wrapper falls back to lazy regeneration if SessionStart didn't run.

### Decision 7: SessionStart hook pre-warms the Verible install; the wrapper is the source of truth
**Choice:** The SessionStart hook eagerly invokes `install-verible.sh` (downloads the pinned Verible release into `${CLAUDE_PLUGIN_DATA}/bin/` if not already there) and `gen-filelist.sh`. The `verible-ls` wrapper invokes the same `install-verible.sh` lazily on first LSP launch as a fallback. Both code paths share one installer script; on macOS, Windows, or Linux arm64 the installer prints a helpful message via the wrapper and exits cleanly.
**Alternatives considered:** Eager install only (original v1 plan, broke when the hook didn't fire); lazy install only (slow first LSP launch); bundle the binary.
**Rationale:** The wrapper has to handle the install lazily anyway — a SessionStart hook is not load-bearing for LSP correctness (see Decision 4). But running install eagerly means the first LSP file open isn't blocked on a 10-second tarball download. SessionStart becomes a UX optimization on top of the wrapper's correctness guarantee. Sharing one installer script means there's no risk of the eager path and lazy path diverging in version, checksum, or extraction logic. On unsupported platforms the wrapper produces the user-facing error so the message is consistent regardless of which entry point fired first.

### Decision 8: Pin the Verible version; bump quarterly
**Choice:** Hard-code a single Verible release tag in `install-verible.sh`. Bump in a dedicated PR every quarter.
**Alternatives considered:** Always fetch latest; let the user override.
**Rationale:** Verible ships weekly. "Always latest" turns the plugin into a moving target that breaks reproducibility for `pvz-fpga` and CI. Pinning gives every user the same LSP behavior; the quarterly bump keeps drift bounded. A user override flag is reasonable but not v1 — wait for someone to ask.

### Decision 9: PostToolUse format-on-save as a hook, with `systemMessage` JSON output for user notice
**Choice:** PostToolUse hook runs `verible-verilog-format` on `.sv`/`.svh`/`.v`/`.vh` after Write/Edit. The same CLI is also wrapped as a `/fpga-lsp:sv-format` skill for explicit "format this file/range" calls. The first-fire-per-session notice is emitted via the hook's structured JSON output (`{"systemMessage": "fpga-lsp: formatted <path> with verible-verilog-format"}`), not plain stdout.
**Alternatives considered:** Skill-only (agent must remember to call); hook-only (no manual invocation surface); plain stdout for the notice.
**Rationale:** Format-on-save matches what human editors do and keeps the working tree consistent without the agent having to remember. The skill exists for cases where the agent wants to format a specific file or range outside the edit flow. The notice channel matters: per Claude Code's hook docs, PostToolUse stdout goes to the debug log and is NOT user-visible. `systemMessage` is the documented field for surfacing a one-line user notice without polluting Claude's conversation context. Two invocation surfaces, one binary, structured output, no duplication.

### Decision 10: `sv-reviewer` runs Verible first and cites evidence; LLM judgment is interpretive, not detective
**Choice:** Ship `sv-reviewer` as a Claude Code agent (own context window). Workflow: (1) run `verible-verilog-lint` on the target files using the project filelist, (2) consume the lint diagnostics as ground truth and cite specific Verible rule IDs, (3) layer interpretation on top — explain *why* a flagged pattern is risky, suggest fixes, escalate higher-order concerns (X-propagation hazards, clock-domain hygiene) that don't have crisp Verible rules. Scope is the same five SV pitfalls as before. Filelist-aware.
**Alternatives considered:** Pure prompt-based detection (original v1 spec — "SHALL detect inferred latches"); skill that runs in main context; lint-rule pack inside Verible.
**Rationale:** A prompt-only LLM cannot deterministically detect every inferred latch or clock-domain crossing — that's static-analysis territory and over-promising it sets the user up to ignore false negatives. Verible already has rules for the mechanical cases (inferred latches, blocking-in-`always_ff`); the agent's value is interpretation, not re-implementation. Citing rule IDs makes findings auditable and gives the user a path to suppress or configure individual rules. For higher-order concerns Verible can't express, the agent should mark its conclusions as judgment-based, not detective. Fixture-based eval (true-positive + false-positive corpus) belongs in v1.1 — useful but not blocking for v1 ship; the conservative-match guardrail and Verible-first workflow are the v1 protections against false positives.

### Decision 11: `fpga-flow` is a placeholder directory only; not registered in `marketplace.json` until installable
**Choice:** `nyavana/fpga-lsp` repo ships `fpga-lsp` as the only entry in `.claude-plugin/marketplace.json` for v1. `plugins/fpga-flow/README.md` exists as a placeholder describing the planned v2 plugin, but the directory contains no manifest and is NOT listed in the marketplace JSON. The marketplace gains the `fpga-flow` entry only when v2 is installable.
**Alternatives considered:** Register `fpga-flow` with a "reserved" or "unreleased" flag (original v1 plan); single bundled plugin; separate repos.
**Rationale:** JSON has no comment syntax; "commenting out" a marketplace entry isn't a thing. Registering a plugin without a valid manifest would either fail validation or surface a broken-install error to users. The marketplace structure is still ready for v2 (the directory is reserved, the README signals intent), but v1 doesn't ship anything that lies about being installable. Coupling rationale unchanged: the LSP plugin is JSON-only and zero-maintenance; the synthesis MCP server is real code with license complications and heavier deps. Coupling their release cadences would block LSP shipping on synthesis readiness.

### Decision 12: CI validates the manifest and parses `.lsp.json` for the smoke command
**Choice:** Linux x64 container, fresh checkout. CI steps: (1) `claude plugin validate plugins/fpga-lsp` to catch manifest, hook, and `.lsp.json` schema errors before anything runs; (2) install via the local marketplace path to exercise the actual install flow; (3) run `install-verible.sh`; (4) parse `plugins/fpga-lsp/.lsp.json` to extract the `verible` server's `command` and `args`, then exec exactly that against a deliberately broken sample `.sv` file and assert diagnostics come back via the LSP `initialize` + `textDocument/didOpen` flow.
**Alternatives considered:** Launch `verible-verilog-ls` directly in CI (original v1 plan — couldn't catch a manifest typo); no CI in v1; CI per supported OS.
**Rationale:** The original CI plan would have happily passed a commit that typo'd the LSP command in `.lsp.json`, because CI was launching the binary directly rather than the plugin-configured command. Reading the command from `.lsp.json` makes the smoke test exercise the actual user pathway. `claude plugin validate` (per the plugins reference) catches manifest/schema regressions cheaper than a smoke-test failure. v1 covers Linux x64 only because that's the only auto-install path; v1.1 adds matrix coverage as the auto-install does.

## Risks / Trade-offs

- **Risk:** Verible's pinned release goes stale and lacks a fix the user needs.
  → **Mitigation:** Quarterly bump cadence; document override mechanism in v1.1; users can install a newer Verible to `$PATH` manually and the SessionStart hook will detect it and skip auto-install.

- **Risk:** Filelist auto-generation misclassifies a non-source file (e.g., generated `.v` in a build directory) and Verible chokes.
  → **Mitigation:** Default `gen-filelist.sh` to skip common build/output dirs (`build/`, `output_files/`, `simulation/`, `.git/`, `node_modules/`); document override hook for projects with non-standard layouts.

- **Risk:** SessionStart hook download fails (network, GitHub release deletion, checksum mismatch) and the user sees a confusing first-run error.
  → **Mitigation:** Hook fails loudly with a clear message pointing to the manual install command in the README; pin to a tag (not a moving release link); checksum the downloaded archive.

- **Risk:** PostToolUse format-on-save fights with the user's editor on a shared file, or formats an unsaved buffer the user didn't want touched.
  → **Mitigation:** Hook scopes to file extensions Verible owns; surfaces a one-line "formatted by fpga-lsp" notice the first time it runs per session so the behavior is discoverable and disable-able.

- **Risk:** `sv-reviewer` over-fires on legitimate patterns (e.g., asynchronous resets that look like sensitivity-list drift) and trains the user to ignore it.
  → **Mitigation:** Verible-first workflow grounds findings in concrete rule IDs the user can suppress per-line or per-config; the agent's interpretive layer is scoped to high-confidence patterns; iterate based on dogfooding feedback from `pvz-fpga`; document how to skip the reviewer per-PR. Build a fixture-based eval corpus (true positives + false positives) in v1.1.

- **Risk:** A user installs `vhdl_ls` via `cargo install` and opens a `.vhd` file expecting it to work, but every `library ieee;` declaration errors because there's no `vhdl_ls.toml` configured with standard libraries.
  → **Mitigation:** README ships the complete recipe (binary install + `vhdl_ls.toml` template + `VHDL_LS_CONFIG` guidance). The `vhdl-ls` wrapper detects a missing-libraries failure pattern (where feasible) and surfaces a README-pointing message rather than letting raw rust_hdl errors flood the diagnostics channel.

- **Trade-off:** Linux x64 only in v1 means macOS users (a real chunk of the FPGA tooling audience) get a manual install. Acceptable because the maintainer's daily workflow is Linux x64; widening platform coverage in v1.1 is mechanical (Verible already publishes the binaries) and not architecturally interesting.

- **Trade-off:** Pinning Verible quarterly means users on the bleeding edge (or a new Verible release that fixes their bug) have to wait. Reproducibility wins; we accept the lag and offer the manual-install escape hatch.

- **Trade-off:** Wrapping Verible CLIs as skills is convenience, not a moat — agents can already shell out. The skills earn their keep by giving the agent a stable invocation surface and documented context for interpreting output, not by adding new functionality.

## Implementation Workflow

This is a process note, not a product decision — recorded here so the apply phase follows it consistently.

- **Subagent-driven execution.** Implementation work in `tasks.md` SHALL be dispatched to subagents (general-purpose Agent unless a more specific type fits) rather than executed directly in the main conversation thread. The main thread coordinates: it reviews subagent output, sequences task groups, and resolves cross-cutting decisions. Self-contained units — scaffolding a directory, writing a wrapper script, drafting the CI workflow, authoring a skill — each go to one subagent with a self-contained brief. Tightly-coupled or judgment-heavy work (e.g., final integration, debugging a CI failure) may stay in the main thread. The goal is context-window discipline on a long task list; do not over-fragment (a 3-step task doesn't need 3 subagents).

- **Wrap-up at the end.** Once all functional task groups are complete and the four success criteria pass on `nyavana/pvz-fpga`, the implementation finishes with: (1) updating the README and any in-repo docs that drifted during implementation, (2) committing the change, (3) pushing to `main` (or a feature branch if requested).

- **Commit message style.** Commits SHALL use simple `<type>: <description>` subject lines (per the global git-workflow conventions) with an optional terse body. They SHALL NOT include `Co-Authored-By: Claude ...`, `Generated with Claude Code` footers, or any other AI/Claude attribution. Attribution is already disabled in the user's global settings; this rule reinforces it for any tool path that might re-introduce the trailer.

## Migration Plan

This is a greenfield change — no existing users, no migration. Rollout is:

1. Land the v1 implementation on `main` of `nyavana/fpga-lsp`.
2. Tag `v1.0.0` once CI smoke test passes and dogfooding on `pvz-fpga` confirms the four success criteria (auto-diagnostics on edit, cross-file go-to-def, three skills callable, `sv-reviewer` callable).
3. Publish marketplace entry. The maintainer is the first user.
4. Watch for `sinply/hdl-lsp-marketplace` (parallel project, created 2026-04-27, 0 stars) for collisions or collaboration; reach out if convergence makes sense.

Rollback is `/plugin uninstall fpga-lsp`. The SessionStart hook's installed Verible binary lives under `${CLAUDE_PLUGIN_DATA}/bin/` and is removed with the plugin; nothing touches the user's system `$PATH` outside the session.

## Open Questions

- Does the auto-generated `verible.filelist` give the agent enough cross-file context on multi-module designs, or does dogfooding push us to make slang-server the default sooner than v1.1?
- Should `sv-reviewer` eventually call into `fpga-flow` for synthesis-aware review, or stay LSP-only? (Defer until `fpga-flow` exists.)
- Is there a clean way to feed Quartus `.rpt` parsing into LSP diagnostics so timing/utilization issues surface in the same channel as parse errors? (Future work; out of scope for v1.)
- Tcl files in `pvz-fpga` (and most FPGA projects) currently have no LSP coverage — `fpga-flow` companion or out of scope entirely?
