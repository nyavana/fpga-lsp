## ADDED Requirements

### Requirement: SystemVerilog and Verilog files are routed to Verible via a plugin-owned wrapper
The plugin's `.lsp.json` SHALL declare a `verible` LSP server entry whose `command` is `${CLAUDE_PLUGIN_ROOT}/bin/verible-ls` (NOT a bare `verible-verilog-ls`) and whose `extensionToLanguage` map covers `.sv` and `.svh` (language id `systemverilog`) and `.v` and `.vh` (language id `verilog`). The wrapper script is responsible for resolving the real Verible binary at exec time so `.lsp.json` does not depend on `$PATH` mutations from hooks.

#### Scenario: Agent opens a SystemVerilog file
- **WHEN** the agent (or a hook) opens a `.sv` file in a workspace where the plugin is installed and a Verible binary is reachable through the wrapper (system PATH, plugin cache, or fresh lazy install)
- **THEN** Claude Code SHALL spawn the wrapper, which SHALL exec the underlying `verible-verilog-ls`, and Claude Code SHALL route diagnostics, hover, definition, and reference requests for that file to it

#### Scenario: Agent opens a Verilog header file
- **WHEN** the agent opens a `.svh` or `.vh` file
- **THEN** Claude Code SHALL route LSP requests for that file to the same wrapper-spawned Verible server with the matching language id

#### Scenario: `.lsp.json` does not name `verible-verilog-ls` directly
- **WHEN** a maintainer reads `plugins/fpga-lsp/.lsp.json`
- **THEN** the `verible` entry's `command` SHALL be the wrapper path (`${CLAUDE_PLUGIN_ROOT}/bin/verible-ls`) and SHALL NOT be a bare binary name

### Requirement: Verible LSP is launched with project-aware args
The `verible` server entry SHALL pass `--rules_config_search` and `--file_list_path=<resolved-path>` to `verible-verilog-ls` (via the wrapper). The resolved filelist path is whichever path the lsp-bootstrap requirements settled on for the current workspace (project-owned root file, or plugin-managed file under `${CLAUDE_PLUGIN_DATA}`).

#### Scenario: Verible respects a project's lint config
- **WHEN** the wrapper launches `verible-verilog-ls` in a workspace that contains `.rules.verible_lint`
- **THEN** the launched process SHALL be invoked with `--rules_config_search` so it walks up the tree to find that file, and SHALL apply the project's lint rules instead of defaulting

#### Scenario: Verible uses the resolved filelist
- **WHEN** the wrapper launches `verible-verilog-ls`
- **THEN** the launched process SHALL be invoked with `--file_list_path=<absolute-path>` matching the filelist path determined by `lsp-bootstrap`

### Requirement: VHDL files are routed to rust_hdl via a plugin-owned wrapper
The `.lsp.json` SHALL declare a `vhdl_ls` LSP server entry whose `command` is `${CLAUDE_PLUGIN_ROOT}/bin/vhdl-ls` (NOT a bare `vhdl_ls`) and whose `extensionToLanguage` map covers `.vhd` and `.vhdl` (language id `vhdl`). The wrapper resolves the underlying `vhdl_ls` binary and is the surface for the missing-binary error message.

#### Scenario: Agent opens a VHDL file when vhdl_ls is installed
- **WHEN** the agent opens a `.vhd` or `.vhdl` file in a workspace where `vhdl_ls` is reachable through the wrapper
- **THEN** Claude Code SHALL spawn the wrapper, which SHALL exec the underlying `vhdl_ls`, and Claude Code SHALL route LSP requests for that file to it

#### Scenario: vhdl_ls is missing from PATH
- **WHEN** the agent opens a `.vhd` file in a workspace where no `vhdl_ls` binary can be resolved by the wrapper
- **THEN** the wrapper SHALL emit a single human-readable error pointing the user to the README's complete vhdl_ls setup instructions (binary install AND `vhdl_ls.toml` standard-library configuration), and SHALL exit non-zero so Claude Code surfaces the message instead of a generic "command not found"; the failure SHALL NOT crash the session or block other LSP servers

### Requirement: No other HDL LSP is wired in v1
The `.lsp.json` SHALL NOT declare entries for slang-server, svlangserver, veridian, ghdl-ls, or VHDL-tool in v1. Adding them is a v1.1+ concern.

#### Scenario: Inspecting the plugin manifest
- **WHEN** a maintainer reads `plugins/fpga-lsp/.lsp.json`
- **THEN** the file SHALL contain exactly two server entries (`verible` and `vhdl_ls`) and no others
