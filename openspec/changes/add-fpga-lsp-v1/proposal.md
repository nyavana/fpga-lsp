## Why

AI coding agents (Claude Code in particular) have no semantic understanding of HDL code: they grep, guess, hallucinate signal hierarchies, and never see lint or elaboration errors until something is run. The HDL LSP ecosystem (Verible, rust_hdl, slang-server) is mature for human editors but invisible to agents because no one has wired it up as a one-click Claude Code plugin. The official Claude Code marketplace ships LSP plugins for ~12 general-purpose languages and zero HDLs. This change ships v1 of `fpga-lsp` — the first plugin that closes that gap for SystemVerilog/Verilog/VHDL, validated against `nyavana/pvz-fpga` (a SystemVerilog DE1-SoC project) on Linux x64.

## What Changes

- New marketplace repository at `nyavana/fpga-lsp`. Marketplace ships `fpga-lsp` only in v1; `fpga-flow` lives as a placeholder directory and is registered in `marketplace.json` only when it becomes installable.
- `fpga-lsp` plugin: native Claude Code LSP wiring for Verible (`.sv`, `.svh`, `.v`, `.vh`) and rust_hdl (`.vhd`, `.vhdl`), routed through plugin-owned wrapper scripts at `${CLAUDE_PLUGIN_ROOT}/bin/` that resolve the binary location at exec time so `.lsp.json` does not depend on PATH propagation from hooks.
- The Verible wrapper lazy-installs the pinned Verible binary on Linux x64 when missing (so the LSP just works on first launch). A SessionStart hook also pre-warms the install and generates a filelist for cross-file analysis: it respects an existing project-owned `verible.filelist` at the workspace root, and otherwise writes a plugin-managed filelist under `${CLAUDE_PLUGIN_DATA}/` and passes it to Verible via `--file_list_path` (avoiding any clobber of project config).
- Three Verible CLI wrapper skills: `sv-lint`, `sv-format`, `sv-diff`.
- One agent: `sv-reviewer` — Verible-lint-aware, scoped to common SV pitfalls (inferred latches, blocking-vs-nonblocking in `always_ff`, sensitivity-list drift, X-propagation, clock-domain hygiene), reads the filelist for project-aware review.
- PostToolUse hook for SystemVerilog format-on-save.
- GitHub Actions CI smoke-testing the install + LSP handshake in a clean container on every push.
- README with install incantation, dogfooding notes, and pinned Verible version policy. MIT license.

Explicitly **out of scope for v1** (called out so it stays out): macOS / Windows / Linux-arm64 binary install, slang-server opt-in, synthesis feedback (defers to `fpga-flow`), project-file parsing (`.qsf`, `.xpr`), veridian / svlangserver configs.

## Capabilities

### New Capabilities
- `plugin-packaging`: marketplace + plugin manifest layout that makes `fpga-lsp` installable via `/plugin install fpga-lsp@fpga-lsp`. `fpga-flow` is a placeholder directory only and is not registered in `marketplace.json` until installable.
- `lsp-wiring`: declarative `.lsp.json` mapping HDL extensions to Verible and rust_hdl, with `command` pointing to plugin-owned wrapper scripts (`${CLAUDE_PLUGIN_ROOT}/bin/verible-ls`, `${CLAUDE_PLUGIN_ROOT}/bin/vhdl-ls`) and Verible-specific args (`--rules_config_search`, `--file_list_path`).
- `lsp-bootstrap`: wrapper scripts that resolve binary location (system PATH → plugin cache → lazy install on Linux x64 → helpful error otherwise) and pass project-aware args; SessionStart hook that pre-warms the Verible install and generates a filelist (respecting an existing project-owned `verible.filelist`, otherwise writing to `${CLAUDE_PLUGIN_DATA}/`).
- `sv-skills`: `sv-lint`, `sv-format`, `sv-diff` skills wrapping Verible CLI tools with stable invocation surfaces and interpretation context for the agent.
- `sv-reviewer-agent`: SystemVerilog reviewer agent that runs Verible lint first and cites diagnostic IDs as evidence, then layers HDL-specific judgment (latch inference, sensitivity lists, blocking-vs-nonblocking, X-propagation, clock-domain hygiene) — interpretation, not deterministic detection. Filelist-aware.
- `format-on-save`: PostToolUse hook that runs `verible-verilog-format` after edits to SystemVerilog files; emits a first-fire-per-session notice via the hook's `systemMessage` JSON output (not stdout).
- `ci-smoke-test`: GitHub Actions workflow that runs `claude plugin validate` on the manifest, parses `.lsp.json` for the actual configured command, and exercises an LSP handshake against that command — so a typo in the manifest cannot pass CI.

### Modified Capabilities
<!-- None — this is a greenfield repository. -->

## Impact

- New repository scaffolding under `plugins/fpga-lsp/` (manifest, `.lsp.json`, `bin/` wrappers, skills, agent, hooks, scripts) plus top-level `.claude-plugin/marketplace.json`, `scripts/`, `README.md`, `LICENSE`, and `.github/workflows/`. `plugins/fpga-flow/` exists only as a placeholder with a README until v2 ships.
- External dependencies: Verible (pinned release, lazy-installed by the wrapper into `${CLAUDE_PLUGIN_DATA}/bin/`; SessionStart pre-warms) and rust_hdl (`vhdl_ls`, user-installed via `cargo install vhdl_ls`; v1 README documents the additional `vhdl_ls.toml` standard-library setup that `cargo install` alone does not provide).
- User-visible install surface: two slash commands (`/plugin marketplace add nyavana/fpga-lsp`, `/plugin install fpga-lsp@fpga-lsp`); Linux x64 users need zero further setup for SystemVerilog/Verilog, other platforms see a helpful error from the wrapper (not Claude Code's generic "command not found") on first LSP launch.
- No code in `nyavana/pvz-fpga` is modified; that repo serves as the dogfooding target for the v1 success criteria.
