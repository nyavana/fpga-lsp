## ADDED Requirements

### Requirement: Plugin-owned wrapper script resolves the Verible binary at exec time
The plugin SHALL ship `plugins/fpga-lsp/bin/verible-ls`. When invoked (by Claude Code as the LSP `command`), the wrapper SHALL resolve the underlying `verible-verilog-ls` binary in this order: (1) `$PATH`, (2) `${CLAUDE_PLUGIN_DATA}/bin/`, (3) on Linux x64, run `scripts/install-verible.sh` to fetch the pinned release into `${CLAUDE_PLUGIN_DATA}/bin/` and re-check. If a binary is found, the wrapper SHALL exec it with the args defined in `lsp-wiring`. If no binary can be resolved, the wrapper SHALL print a single human-readable error pointing at the README and exit non-zero.

#### Scenario: System Verible already installed
- **WHEN** the wrapper runs and `verible-verilog-ls` is on `$PATH` (system package, manual install)
- **THEN** the wrapper SHALL exec the system binary without invoking the installer

#### Scenario: Cached Verible from a prior session
- **WHEN** the wrapper runs and a previous session installed Verible into `${CLAUDE_PLUGIN_DATA}/bin/`
- **THEN** the wrapper SHALL exec the cached binary without invoking the installer

#### Scenario: First Verible launch on Linux x64 with no install
- **WHEN** the wrapper runs on Linux x64 and no `verible-verilog-ls` exists on `$PATH` or in the plugin cache
- **THEN** the wrapper SHALL invoke `install-verible.sh`, and on success SHALL exec the freshly installed binary

#### Scenario: Verible cannot be resolved on an unsupported platform
- **WHEN** the wrapper runs on macOS, Windows, or Linux arm64 with no `verible-verilog-ls` reachable
- **THEN** the wrapper SHALL print a one-line error naming the platform, the manual install command, and the README link, and SHALL exit non-zero so Claude Code surfaces the message

### Requirement: Plugin-owned wrapper script resolves the vhdl_ls binary at exec time
The plugin SHALL ship `plugins/fpga-lsp/bin/vhdl-ls`. When invoked, the wrapper SHALL resolve the underlying `vhdl_ls` binary by checking `$PATH`. The wrapper SHALL NOT attempt to install `vhdl_ls`. If the binary is found, the wrapper SHALL exec it. If not, the wrapper SHALL emit the README-pointing error defined in `lsp-wiring` and exit non-zero.

#### Scenario: vhdl_ls present on PATH
- **WHEN** the wrapper runs and `vhdl_ls` is on `$PATH`
- **THEN** the wrapper SHALL exec the binary directly

#### Scenario: vhdl_ls missing
- **WHEN** the wrapper runs and `vhdl_ls` is not on `$PATH`
- **THEN** the wrapper SHALL print the README-pointing setup error (covering both `cargo install vhdl_ls` and `vhdl_ls.toml` library configuration) and exit non-zero

### Requirement: install-verible.sh is the single source of truth for Verible install
The plugin SHALL ship `scripts/install-verible.sh`, invoked by both the SessionStart hook (eager pre-warm) and the `verible-ls` wrapper (lazy fallback). On Linux x64 with no `verible-verilog-ls` on `$PATH` or in `${CLAUDE_PLUGIN_DATA}/bin/`, the script SHALL fetch the pinned Verible release archive, verify its checksum, extract its binaries into `${CLAUDE_PLUGIN_DATA}/bin/`, and exit successfully. On macOS, Windows, or Linux arm64, the script SHALL exit cleanly without attempting a download (the wrapper handles the user-facing error). The pinned version SHALL be a single tagged release (not a moving "latest" reference) sourced from one shared location read by the script, the wrapper, and CI.

#### Scenario: SessionStart pre-warm on Linux x64 with no Verible
- **WHEN** the SessionStart hook fires on Linux x64 with no `verible-verilog-ls` reachable
- **THEN** the hook SHALL invoke `install-verible.sh`, which SHALL download the pinned release, verify the checksum, extract into `${CLAUDE_PLUGIN_DATA}/bin/`, and exit successfully — so the first LSP launch is not blocked on the download

#### Scenario: Lazy install fallback when SessionStart did not run
- **WHEN** Claude Code spawns the wrapper for the first LSP file open in a session where SessionStart did not run (cold session, hook regression) and no Verible binary is reachable
- **THEN** the wrapper SHALL invoke `install-verible.sh` itself and complete the install before exec'ing — slower than the pre-warmed path but still correct

#### Scenario: Existing binary detected (skip install)
- **WHEN** `install-verible.sh` runs and `verible-verilog-ls` is already on `$PATH` or in `${CLAUDE_PLUGIN_DATA}/bin/`
- **THEN** the script SHALL exit successfully without re-downloading

#### Scenario: Download fails or checksum mismatches
- **WHEN** the download fails (network error, GitHub release deletion) or the downloaded archive's checksum does not match the pinned value
- **THEN** the script SHALL fail loudly with a one-line error naming the failure mode and pointing the user to the manual install command in the README, and SHALL NOT leave a partial or unverified binary in `${CLAUDE_PLUGIN_DATA}/bin/`

### Requirement: Filelist generation respects an existing project-owned filelist
`scripts/gen-filelist.sh` SHALL check for an existing `verible.filelist` at the workspace root before generating anything. If present, the script SHALL leave it untouched and the `verible-ls` wrapper SHALL pass that absolute path via `--file_list_path`.

#### Scenario: Project ships its own verible.filelist
- **WHEN** the workspace contains a `verible.filelist` at the root
- **THEN** `gen-filelist.sh` SHALL NOT modify, overwrite, append to, or replace the file, and the wrapper SHALL launch Verible with `--file_list_path=<workspace>/verible.filelist`

#### Scenario: Re-running on a workspace with an existing filelist
- **WHEN** `gen-filelist.sh` runs again in a session against a workspace whose `verible.filelist` was present in the previous session
- **THEN** the file SHALL still be byte-identical after the run

### Requirement: Filelist auto-generation writes to plugin-managed storage when no project file exists
When the workspace has no `verible.filelist` at the root, `gen-filelist.sh` SHALL walk the workspace, collect `.sv`/`.svh`/`.v`/`.vh` files, skip common non-source directories (`.git/`, `build/`, `output_files/`, `simulation/`, `node_modules/`), and write the result to `${CLAUDE_PLUGIN_DATA}/filelists/<workspace-hash>.filelist` (one path per line). The wrapper SHALL pass that absolute path via `--file_list_path`. The auto-generated file SHALL NOT be written into the user's working tree.

#### Scenario: First session on a multi-module SystemVerilog project
- **WHEN** the SessionStart hook runs in a workspace with no project filelist and `.sv` files in multiple subdirectories
- **THEN** the plugin-managed filelist SHALL exist under `${CLAUDE_PLUGIN_DATA}/filelists/`, SHALL contain every `.sv`/`.svh`/`.v`/`.vh` file in the project tree, and Verible SHALL use it for cross-file go-to-def

#### Scenario: Build artifacts are excluded
- **WHEN** the workspace contains generated Verilog under `build/` or `output_files/`
- **THEN** the plugin-managed filelist SHALL NOT contain those files

#### Scenario: Workspace working tree stays clean
- **WHEN** `gen-filelist.sh` runs in a workspace with no project filelist
- **THEN** no `verible.filelist` (or any other plugin-managed file) SHALL appear at the workspace root or anywhere else inside the user's working tree, and `git status` SHALL be unchanged by plugin activity

#### Scenario: Multiple projects keep separate filelists
- **WHEN** the user has two workspaces with the same directory name but different paths
- **THEN** the two plugin-managed filelists SHALL live at different `<workspace-hash>` paths and SHALL NOT collide

#### Scenario: Filelist is regenerated on every session
- **WHEN** the user adds a new `.sv` file to a workspace and starts a new session
- **THEN** the regenerated plugin-managed filelist SHALL include the new file without requiring any manual intervention

### Requirement: vhdl_ls is not auto-installed in v1
The SessionStart hook and the `vhdl-ls` wrapper SHALL NOT attempt to install `vhdl_ls`. The failure surface for missing `vhdl_ls` is the wrapper-emitted error defined in `lsp-wiring`.

#### Scenario: Linux x64 user without vhdl_ls
- **WHEN** the SessionStart hook runs and `vhdl_ls` is not on `$PATH`
- **THEN** the hook SHALL NOT attempt to install or fetch `vhdl_ls` and SHALL NOT error on its absence
