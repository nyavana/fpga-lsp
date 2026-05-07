# fpga-flow (placeholder)

`fpga-flow` is the planned v2 companion to `fpga-lsp`: a synthesis-feedback
plugin wrapping Yosys, Verilator, and Quartus so AI agents can drive
elaboration, simulation, and synthesis without shelling out blindly.

## Status

**Not installable in v1.** This directory reserves the marketplace slot
and documents intent. There is no `.claude-plugin/plugin.json` on purpose
— registering an incomplete manifest would either fail validation or
hand users a broken install. The repo's `marketplace.json` ships a single
entry (`fpga-lsp`); `fpga-flow` will be added when v2 is installable.

## Planned scope (v2, subject to change)

- Job-id MCP pattern for multi-minute synthesis runs (Yosys, Quartus).
- Verilator simulation driver with structured pass/fail output.
- Quartus `.rpt` parsing for timing/utilization, surfaced as diagnostics.
- Project-file awareness (`.qsf`, optionally `.xpr`).

## Why a separate plugin

`fpga-lsp` is JSON-only and zero-maintenance once shipped. Synthesis is
license-gated (Quartus), heavyweight, and version-fragile to parse;
coupling cadences would block LSP shipping. Full rationale in
`openspec/changes/add-fpga-lsp-v1/design.md` (Decision 11).
