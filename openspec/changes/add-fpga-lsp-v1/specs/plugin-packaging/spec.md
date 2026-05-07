## ADDED Requirements

### Requirement: Marketplace manifest declares only installable plugins
The repository SHALL ship a `.claude-plugin/marketplace.json` at the repo root that declares the marketplace identity (`fpga-lsp`) and registers `fpga-lsp` (the only v1-installable plugin). The file SHALL NOT register `fpga-flow` until that plugin has a complete manifest and is installable. JSON has no comment syntax, so a "reserved" or "commented-out" `fpga-flow` entry is not acceptable.

#### Scenario: User adds the marketplace
- **WHEN** the user runs `/plugin marketplace add nyavana/fpga-lsp` in Claude Code
- **THEN** Claude Code SHALL discover the marketplace, list `fpga-lsp` as installable, and SHALL NOT error on a missing or partial `fpga-flow` registration

#### Scenario: Inspecting marketplace.json in v1
- **WHEN** a maintainer reads `.claude-plugin/marketplace.json`
- **THEN** the `plugins` array SHALL contain exactly one entry (`fpga-lsp`) and SHALL NOT contain a `fpga-flow` entry, placeholder or otherwise

### Requirement: fpga-flow placeholder lives in the repo without misrepresenting installability
The repository SHALL contain `plugins/fpga-flow/README.md` describing the planned v2 plugin and explaining that it is not yet installable. The directory SHALL NOT contain a `.claude-plugin/plugin.json` or any other manifest until v2 ships.

#### Scenario: Reader lands on the fpga-flow directory
- **WHEN** a reader browses `plugins/fpga-flow/` in v1
- **THEN** they SHALL find a README explaining v2 plans and SHALL NOT find a manifest that claims the plugin is installable

### Requirement: Plugin manifest is installable in one command
The `plugins/fpga-lsp/.claude-plugin/plugin.json` manifest SHALL declare the plugin name (`fpga-lsp`), version, description, and references to its `.lsp.json` LSP config, the `bin/` wrapper scripts, hooks, skills, and the `sv-reviewer` agent, in the format consumed by Claude Code's plugin loader.

#### Scenario: User installs the plugin
- **WHEN** the user runs `/plugin install fpga-lsp@fpga-lsp` after adding the marketplace
- **THEN** Claude Code SHALL install the plugin, register its LSP servers (via the wrappers), hooks, skills, and agent without further user prompts

#### Scenario: Manifest passes claude plugin validate
- **WHEN** a maintainer runs `claude plugin validate plugins/fpga-lsp` against the manifest
- **THEN** the validation SHALL succeed with no schema errors

### Requirement: License and README are present at the repo root
The repository SHALL include a `LICENSE` file (MIT) and a `README.md` at the root. The README SHALL document the two-line install incantation (`/plugin marketplace add ...` then `/plugin install ...`), the v1 success criteria, the supported platform for auto-install (Linux x64), the manual install command for unsupported platforms, the pinned Verible version, the **complete `vhdl_ls` setup** (`cargo install vhdl_ls` AND a `vhdl_ls.toml` template plus `VHDL_LS_CONFIG` guidance for standard libraries — `cargo install` alone is insufficient), and a dogfooding note pointing to `nyavana/pvz-fpga`.

#### Scenario: New user lands on the README
- **WHEN** a user reads `README.md` for the first time
- **THEN** they SHALL find the install commands, the supported platform, the manual install fallback, and a pointer to the dogfooding project within the first screen of the README

#### Scenario: VHDL user follows the README
- **WHEN** a VHDL user follows the README's `vhdl_ls` setup section
- **THEN** they SHALL be guided through both the binary install AND the `vhdl_ls.toml` standard-library configuration, with at minimum a working template they can copy into a project root
