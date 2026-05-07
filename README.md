# fpga-lsp

`fpga-lsp` wires Verible (SystemVerilog/Verilog) and rust_hdl/`vhdl_ls`
(VHDL) into Claude Code as a native LSP plugin so AI agents see parse
errors, lint diagnostics, go-to-definition, and hover for HDL files —
without a tool call, without an MCP bridge, and without leaving the editor.

## Install

Run these two commands inside Claude Code:

```
/plugin marketplace add nyavana/fpga-lsp
/plugin install fpga-lsp@fpga-lsp
```

On Linux x64, the pinned Verible binary is auto-installed on first session
into the plugin's data directory; SystemVerilog and Verilog work
immediately. VHDL needs one extra step (see `vhdl_ls` setup below). Other
platforms need a one-line manual install (see Manual install).

## v1 success criteria

`fpga-lsp` v1 is "done" when the following hold against `nyavana/pvz-fpga`:

1. Parse errors and lint warnings appear automatically after every edit to
   a `.sv` file — no agent tool call required.
2. Go-to-definition resolves module and signal symbols across files,
   driven by a resolved Verible filelist (project-owned if present,
   otherwise plugin-managed).
3. The bundled skills `sv-lint`, `sv-format`, and `sv-diff` are invocable
   (or auto-picked by relevance).
4. The `sv-reviewer` agent runs `verible-verilog-lint` first and cites
   Verible rule IDs in its findings.

## Supported platforms

| Platform        | SystemVerilog/Verilog | VHDL              |
| --------------- | --------------------- | ----------------- |
| Linux x64       | Auto-install          | Manual `cargo`    |
| macOS           | Manual install        | Manual `cargo`    |
| Windows         | Manual install        | Manual `cargo`    |
| Linux arm64     | Manual install        | Manual `cargo`    |

Linux x64 is the only auto-install target in v1. Other platforms get a
clear, README-pointing error from the LSP wrapper on first launch — not a
generic "command not found" — so the failure mode is obvious.

## Pinned versions

- **Verible**: `v0.0-4053-g89d4d98a`
  ([release](https://github.com/chipsalliance/verible/releases/tag/v0.0-4053-g89d4d98a))
- **Linux x64 tarball SHA256**:
  `1edc1f29c70d74213ed373e727183802d5a733e23f9ab9c74462f5b18b76f2c0`

The Verible release is bumped in a dedicated PR roughly every quarter.
Verible itself ships weekly; pinning keeps everyone on the same LSP
behaviour and keeps reproducibility for downstream projects bounded.

## Manual install (unsupported platforms)

Pick the right asset for your platform from the Verible release page
linked above (`...-linux-static-arm64.tar.gz`, `...-macOS.tar.gz`,
`...-win64.zip`, etc.) and substitute it into the URL below.

```bash
curl -L \
  https://github.com/chipsalliance/verible/releases/download/v0.0-4053-g89d4d98a/<asset> \
  -o /tmp/verible.tar.gz
tar xzf /tmp/verible.tar.gz -C ~/.local/
# Then add to your shell rc (bash/zsh/fish):
export PATH="$HOME/.local/verible-v0.0-4053-g89d4d98a/bin:$PATH"
```

Verify:

```bash
verible-verilog-ls --version
```

The plugin's `verible-ls` wrapper resolves the binary from `$PATH` first,
so a manual install is picked up automatically.

## VHDL: complete `vhdl_ls` setup

`cargo install vhdl_ls` is **not enough on its own**. The binary it
installs cannot resolve `library ieee;` or `use ieee.std_logic_1164.all;`
without a `vhdl_ls.toml` (or a global config pointed at by the
`VHDL_LS_CONFIG` env var) that tells it where the standard libraries live.
Without that, every real VHDL file errors on its first `library` clause.

### Step 1 — install the binary

```bash
cargo install vhdl_ls
```

### Step 2 — drop a `vhdl_ls.toml` at your project root

```toml
# vhdl_ls.toml at project root
[libraries]
mylib.files = [
  "src/**/*.vhd",
]

# Standard libraries usually come from rust_hdl's bundled stdlib
# (vhdl_ls auto-locates std/ieee). If your install does not, point
# std.files / ieee.files at the bundled paths or set VHDL_LS_CONFIG
# to a global config that does.
```

Replace `mylib` with your design library name and update `src/**/*.vhd`
to match your source layout. Add more libraries by repeating the
`<lib>.files = [ ... ]` block.

### Step 3 (optional) — global config via `VHDL_LS_CONFIG`

If you maintain several VHDL projects and want a single source of truth
for standard-library paths, set `VHDL_LS_CONFIG` to a global config:

```bash
export VHDL_LS_CONFIG="$HOME/.config/vhdl_ls/global.toml"
```

The project-local `vhdl_ls.toml` still takes precedence for `[libraries]`
declared there. See [VHDL-LS/rust_hdl](https://github.com/VHDL-LS/rust_hdl)
for current details on bundled stdlib resolution and config search order.

## What you get

- **Diagnostics on edit** for `.sv`, `.svh`, `.v`, `.vh`, `.vhd`, `.vhdl`
  — no tool call, the platform feeds them to the agent.
- **Go-to-definition / find-references / hover** via Verible and `vhdl_ls`.
- **Cross-file analysis** for SystemVerilog: a session-start hook walks
  the workspace and writes a filelist into the plugin data dir, then
  passes its path to Verible via `--file_list_path`. If your repo already
  commits a `verible.filelist`, the plugin respects it byte-for-byte and
  uses that instead.
- **Three skills**: `sv-lint`, `sv-format`, `sv-diff` — stable wrappers
  around the matching Verible CLI tools.
- **One agent**: `sv-reviewer` — runs Verible lint first, cites rule IDs
  as evidence, then layers HDL-specific judgment (inferred latches,
  blocking-vs-nonblocking in `always_ff`, sensitivity-list drift,
  X-propagation, clock-domain hygiene).
- **Format-on-save** for SystemVerilog via a PostToolUse hook.

## Out of scope for v1

These are explicitly deferred so v1 can ship — not forgotten:

- Auto-install on macOS, Windows, and Linux arm64.
- `slang-server` opt-in (planned for v1.1 once dogfooding shows a need).
- Synthesis feedback (Yosys/Verilator/Quartus) — that's the planned
  `fpga-flow` plugin in this same marketplace.
- Project-file parsing (`.qsf`, `.xpr`).
- `veridian` and `svlangserver` integrations (both stale upstream).

## Dogfooding

`fpga-lsp` is validated against
[`nyavana/pvz-fpga`](https://github.com/nyavana/pvz-fpga), a SystemVerilog
DE1-SoC project. The four success criteria above are checked end-to-end
against that repo before each tagged release.

## Companion plugin: `fpga-flow`

`plugins/fpga-flow/` is reserved for v2. It ships only a placeholder
README in v1 — no manifest, not registered in `marketplace.json`, not
installable. See `plugins/fpga-flow/README.md` for planned scope.

## License

MIT. See [`LICENSE`](./LICENSE).
