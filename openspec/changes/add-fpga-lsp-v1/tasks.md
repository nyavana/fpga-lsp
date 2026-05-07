## 0. Implementation Workflow (applies to every group below)

- [ ] 0.1 Dispatch each self-contained task group to a subagent (general-purpose Agent, or Explore for research-heavy lookups) with a full self-contained brief; keep the main conversation thread for coordination, review, and judgment-heavy integration. Don't over-fragment — one subagent per cohesive group, not one per checkbox.
- [ ] 0.2 Stay in the main thread for tightly-coupled work: cross-cutting integration, debugging CI failures, resolving design ambiguities that surface mid-implementation.

## 1. Repo & Marketplace Scaffolding

- [ ] 1.1 Create top-level layout: `.claude-plugin/`, `plugins/fpga-lsp/{.claude-plugin,bin,hooks,scripts,skills,agents}/`, `plugins/fpga-flow/`, `scripts/`, `.github/workflows/`
- [ ] 1.2 Write `.claude-plugin/marketplace.json` declaring the `fpga-lsp` marketplace and registering `fpga-lsp` ONLY (do NOT register `fpga-flow` until v2 ships; JSON has no comment syntax, so no commented or "reserved" entry)
- [ ] 1.3 Write `plugins/fpga-flow/README.md` as a placeholder describing the planned v2 plugin and explicitly noting it is not yet installable; do NOT create a `plugin.json` for `fpga-flow`
- [ ] 1.4 Write `LICENSE` (MIT) at repo root
- [ ] 1.5 Write `README.md` at repo root with: install incantation, v1 success criteria, supported platform (Linux x64), manual install command for unsupported platforms, pinned Verible version, **complete `vhdl_ls` setup** (`cargo install vhdl_ls` AND a `vhdl_ls.toml` template plus `VHDL_LS_CONFIG` guidance for standard libraries — call out explicitly that `cargo install` alone is not enough), dogfooding pointer to `nyavana/pvz-fpga`

## 2. Plugin Manifest

- [ ] 2.1 Write `plugins/fpga-lsp/.claude-plugin/plugin.json` with name (`fpga-lsp`), version, description, and references to `.lsp.json`, `bin/` wrappers, `hooks/hooks.json`, the three skills, and the `sv-reviewer` agent
- [ ] 2.2 Run `claude plugin validate plugins/fpga-lsp` locally and confirm zero schema errors
- [ ] 2.3 Manually validate that `/plugin install fpga-lsp@fpga-lsp` succeeds against the local marketplace before moving on

## 3. LSP Wrapper Scripts

- [ ] 3.1 Write `plugins/fpga-lsp/bin/verible-ls`: resolves `verible-verilog-ls` in this order — (a) `$PATH`, (b) `${CLAUDE_PLUGIN_DATA}/bin/`, (c) on Linux x64 invoke `scripts/install-verible.sh` and re-check; on success exec the binary with `--rules_config_search --file_list_path=<resolved-path>`; on failure print a one-line README-pointing error and exit non-zero
- [ ] 3.2 Write `plugins/fpga-lsp/bin/vhdl-ls`: resolves `vhdl_ls` from `$PATH` only (no auto-install); on success exec; on failure print a README-pointing error covering both `cargo install vhdl_ls` AND `vhdl_ls.toml` library configuration and exit non-zero
- [ ] 3.3 Make wrappers POSIX-portable enough to run on the supported platforms; mark executable; add shellcheck pass to CI later
- [ ] 3.4 Both wrappers must compute the resolved `--file_list_path` consistently with `gen-filelist.sh`'s output (same workspace-hash function, same project-file precedence)

## 4. LSP Wiring

- [ ] 4.1 Write `plugins/fpga-lsp/.lsp.json` with two server entries: `verible` (command `${CLAUDE_PLUGIN_ROOT}/bin/verible-ls`, extensions `.sv`/`.svh` → `systemverilog`, `.v`/`.vh` → `verilog`) and `vhdl_ls` (command `${CLAUDE_PLUGIN_ROOT}/bin/vhdl-ls`, extensions `.vhd`/`.vhdl` → `vhdl`); confirm no bare binary names appear in the file
- [ ] 4.2 Confirm Claude Code starts both LSP servers via the wrappers on file open in a workspace where both binaries are reachable
- [ ] 4.3 Confirm the missing-`vhdl_ls` error surface is the wrapper's README-pointing message (with `vhdl_ls.toml` guidance), not Claude Code's generic "command not found"

## 5. Verible Install Script (shared between SessionStart and wrapper)

- [ ] 5.1 Pin a Verible release tag in a single shared location (`scripts/verible.version`) read by `install-verible.sh`, the wrapper, and CI — no version drift between any two callers
- [ ] 5.2 Write `scripts/install-verible.sh`: detect platform/arch; on Linux x64 with no `verible-verilog-ls` reachable, download the pinned release tarball, verify its checksum, extract into `${CLAUDE_PLUGIN_DATA}/bin/`, exit 0; on macOS/Windows/Linux arm64, exit 0 cleanly without attempting a download (the wrapper handles the user-facing error); on download/checksum failure, fail loudly with a one-line message and remove any partial files
- [ ] 5.3 Skip install entirely if `verible-verilog-ls` is already on `$PATH` or in `${CLAUDE_PLUGIN_DATA}/bin/`
- [ ] 5.4 Confirm the wrapper's lazy-install path produces the same result as a SessionStart pre-warm path (single source of truth)

## 6. Filelist Generation (no project clobber)

- [ ] 6.1 Write `scripts/gen-filelist.sh`: if `<workspace>/verible.filelist` exists at the workspace root, leave it untouched and exit 0; otherwise walk the workspace, collect `.sv`/`.svh`/`.v`/`.vh` files, skip `.git/`, `build/`, `output_files/`, `simulation/`, `node_modules/`, and write to `${CLAUDE_PLUGIN_DATA}/filelists/<workspace-hash>.filelist` (one path per line)
- [ ] 6.2 Verify `gen-filelist.sh` against a project that already commits a `verible.filelist` — confirm the file is byte-identical after the script runs and no plugin-managed file appears in the working tree
- [ ] 6.3 Verify that on a project with no committed filelist, `git status` is unchanged after `gen-filelist.sh` runs (plugin-managed file lives outside the working tree)
- [ ] 6.4 Verify cross-file go-to-def works on a multi-module SV project after the wrapper passes `--file_list_path` (whichever path was resolved); verify it does NOT work without the flag (proves the filelist + flag combination is load-bearing)
- [ ] 6.5 Verify the auto-generated filelist is regenerated on every session and includes new files without manual intervention; verify two workspaces with the same directory name but different paths get separate filelists

## 7. Hook Wiring

- [ ] 7.1 Write `plugins/fpga-lsp/hooks/hooks.json` registering: SessionStart → `install-verible.sh` then `gen-filelist.sh`; PostToolUse → format-on-save handler for `.sv`/`.svh`/`.v`/`.vh` files modified by Write/Edit
- [ ] 7.2 Implement the format-on-save handler: resolve `verible-verilog-format` (PATH → plugin cache); exit cleanly if not found; otherwise format the modified file in place
- [ ] 7.3 First-fire-per-session notice: emit a JSON object on stdout `{"systemMessage": "fpga-lsp: formatted <path> with verible-verilog-format"}` (NOT plain stdout — PostToolUse stdout is debug-only). Subsequent fires SHALL emit nothing.
- [ ] 7.4 Track first-fire state per session (e.g., a marker file under `${CLAUDE_PLUGIN_DATA}/session-state/<session-id>` or env-var pattern recommended by Claude Code hook docs)

## 8. Skills

- [ ] 8.1 Write `plugins/fpga-lsp/skills/sv-lint/SKILL.md` wrapping `verible-verilog-lint`, supporting one or many file paths, documenting Verible's diagnostic output format
- [ ] 8.2 Write `plugins/fpga-lsp/skills/sv-format/SKILL.md` wrapping `verible-verilog-format`, supporting in-place and preview modes, documenting which mode the agent should pick when
- [ ] 8.3 Write `plugins/fpga-lsp/skills/sv-diff/SKILL.md` wrapping `verible-verilog-diff`, supporting two-file or two-revision input
- [ ] 8.4 Confirm each `SKILL.md` invokes a single Verible CLI and contains no bespoke diagnostic logic

## 9. sv-reviewer Agent (Verible-first, evidence-cited)

- [ ] 9.1 Write `plugins/fpga-lsp/agents/sv-reviewer.md` declaring the agent's purpose, scope, tool access, and explicit instruction to run `verible-verilog-lint` (with the resolved filelist) BEFORE producing any judgment
- [ ] 9.2 Embed the workflow: (a) lint pass + cite Verible rule IDs in findings, (b) interpretive layer for the five HDL pitfalls (inferred latches, blocking-vs-nonblocking in `always_ff`, sensitivity-list drift, X-propagation, clock-domain hygiene); judgment-layer findings explicitly marked as "verify whether ..." not "this is ..."
- [ ] 9.3 Make the agent load the resolved filelist (project file or plugin-managed copy) and pass it to lint; warn if neither is reachable and proceed single-file
- [ ] 9.4 Verify the agent does NOT flag a correctly-written async reset as sensitivity-list drift (false-positive guardrail)
- [ ] 9.5 Defer the fixture-based eval corpus (true-positive + false-positive harness) to v1.1 — open a tracking issue rather than building it for v1

## 10. CI

- [ ] 10.1 Write `.github/workflows/ci.yml` running on push and PR, on a single Linux x64 runner
- [ ] 10.2 CI step 1: run `claude plugin validate plugins/fpga-lsp`; fail the workflow on schema errors before anything else runs
- [ ] 10.3 CI step 2: install via the local marketplace path (or equivalent) to exercise the actual install flow; assert the install succeeds
- [ ] 10.4 CI step 3: run `scripts/install-verible.sh` and assert the pinned Verible binary lands under `${CLAUDE_PLUGIN_DATA}/bin/`
- [ ] 10.5 CI step 4: parse `plugins/fpga-lsp/.lsp.json` (e.g., `jq '.lspServers.verible.command'` and `.args`), exec exactly that command + args as the smoke LSP, send `initialize` then `textDocument/didOpen` for a deliberately broken sample `.sv` file, and assert at least one diagnostic comes back. Do NOT hard-code `verible-verilog-ls` in the smoke step.
- [ ] 10.6 Verify CI reads the pinned Verible version from the same shared source as `install-verible.sh` (`scripts/verible.version`)
- [ ] 10.7 Verify CI fails when (a) the manifest is invalid, (b) `install-verible.sh` is broken, (c) `.lsp.json` points the wrapper at a non-existent path, and (d) the LSP handshake comes back with no diagnostics

## 11. Dogfood & Ship

- [ ] 11.1 Install the plugin from a local checkout against `nyavana/pvz-fpga`
- [ ] 11.2 Verify success criterion 1: parse errors and lint warnings appear automatically after every edit to a `.sv` file (no tool call required)
- [ ] 11.3 Verify success criterion 2: go-to-definition resolves module/signal symbols across files (the resolved filelist + `--file_list_path` is doing its job)
- [ ] 11.4 Verify success criterion 3: `/fpga-lsp:sv-lint`, `/fpga-lsp:sv-format`, `/fpga-lsp:sv-diff` are invocable as bundled skills (or picked automatically by relevance)
- [ ] 11.5 Verify success criterion 4: `sv-reviewer` runs on a `pvz-fpga` file without extra setup, runs Verible first, cites rule IDs, and produces a reasonable interpretive review
- [ ] 11.6 Verify the format-on-save first-fire notice appears via `systemMessage` (not buried in debug logs) and subsequent fires are silent
- [ ] 11.7 Verify on a `pvz-fpga` checkout that any pre-existing `verible.filelist` is left byte-identical after a session
- [ ] 11.8 Tag `v1.0.0` and publish the marketplace entry
- [ ] 11.9 Open issues for anything broken during dogfooding that is out of v1 scope (track for v1.1, fixture-based reviewer eval, or `fpga-flow`)

## 12. Wrap-Up: Docs, Commit, Push

- [ ] 12.1 Update `README.md` with any guidance changes that surfaced during implementation (install gotchas, vhdl_ls.toml template tweaks, dogfooding caveats)
- [ ] 12.2 Update `plugins/fpga-flow/README.md` if anything about v2's planned scope shifted during v1 build-out
- [ ] 12.3 Run `openspec validate add-fpga-lsp-v1` once more and confirm the change still validates clean
- [ ] 12.4 Stage relevant files (`git add` with explicit paths — never `git add -A` or `.`) and create the commit. Commit message style: `<type>: <description>` subject (e.g., `feat: ship fpga-lsp v1`), optional terse body explaining the why. NO `Co-Authored-By: Claude ...` trailer, NO `Generated with Claude Code` footer, NO emoji. Attribution is disabled globally; this rule reinforces it.
- [ ] 12.5 Push to the appropriate branch (`main` unless the user requested a feature branch). Do not force-push.
