# fpga-lsp — Plan

A one-click Claude Code plugin that gives AI coding agents real LSP-grade
intelligence for FPGA HDL projects (SystemVerilog, Verilog, VHDL), with
FPGA-specific skills layered on top.

---

## 1. Why we are building this

### The motivating project
The author maintains [`nyavana/pvz-fpga`](https://github.com/nyavana/pvz-fpga),
a Plants vs Zombies clone running on the Terasic DE1-SoC (Cyclone V). The repo
is mostly **SystemVerilog + Tcl + C + Makefile** — a typical mixed-language
FPGA codebase.

While working on it with AI coding agents (Claude Code in particular), one
problem kept showing up:

> Agents have no semantic understanding of HDL code.
> They grep, they guess, they hallucinate signal hierarchies, and they
> can't see lint or elaboration errors until something is run.

VS Code users solve this by installing Verible / rust_hdl / svlangserver as
LSP extensions. Coding agents do not get any of that for free. The agent's
view of the codebase collapses to plain-text search the moment it touches a
`.sv` or `.vhd` file.

### The gap, stated precisely
1. **No "FPGA LSP for agents" exists today** as a one-click install.
2. **No FPGA-aware MCP/LSP plugin is present in the official Claude Code
   marketplace.** Languages covered: C/C++, C#, Go, Java, Kotlin, Lua, PHP,
   Python, Rust, Swift, TypeScript. HDLs: none.
3. The HDL LSP ecosystem (Verible, rust_hdl, svlangserver, veridian, slang) is
   mature in editors but **invisible to agents** unless someone wires it up.

### Goal
Ship a Claude Code plugin that:
- Installs in **one click** (`/plugin install fpga-lsp@fpga-lsp`).
- Gives the agent **automatic diagnostics + go-to-definition + references +
  hover** on `.sv`/`.svh`/`.v`/`.vhd`/`.vhdl` files, with no manual setup
  beyond installing the LSP binary.
- Bundles **FPGA-specific skills** (lint, format, semantic diff) so the agent
  has more than a generic LSP — it has hardware-aware tooling.
- Leaves room for a **future synthesis-feedback layer** (Yosys/Verilator/Quartus
  via MCP) without rewriting v1.

---

## 2. Findings along the way

### 2.1 LSP servers for HDLs already exist — that space is crowded
Building yet another SV/VHDL LSP from scratch would duplicate prior art.

| Language | Existing LSPs | Notes |
|---|---|---|
| SystemVerilog / Verilog | [Verible](https://github.com/chipsalliance/verible) (CHIPS Alliance, 1.8k stars, weekly releases, cross-file via `verible.filelist`), [hudson-trading/slang-server](https://github.com/hudson-trading/slang-server) (MIT, built on slang, prebuilt binaries, active since 2025-08), [svlangserver](https://github.com/imc-trading/svlangserver) (effectively dormant — single 2025 commit after a 2-year gap), [veridian](https://github.com/vivekmalneedi/veridian) (Rust, lags slang releases, Linux-only binary), [svls](https://github.com/dalance/svls) (lint-only) | **Verible = safest default. slang-server = best deeper-analysis opt-in (HRT open-sourced their server in 2025).** svlangserver/veridian both stale. |
| VHDL | [rust_hdl / VHDL-LS](https://github.com/VHDL-LS/rust_hdl) (Rust, complete), [ghdl-ls](https://github.com/ghdl/ghdl-language-server) (GHDL-based), VHDL-tool | rust_hdl is the obvious choice. |

**Implication:** v1 should _wire existing LSPs_, not write a new one.

### 2.2 AI-agent EDA work is happening, but in the synthesis layer
Adjacent prior art focuses on synthesis/sim, not LSP-grade intelligence.

- [MCP4EDA (NellyW8)](https://github.com/NellyW8/MCP4EDA) — MCP server wrapping
  Yosys, Verilator, GTKWave, OpenLane, KLayout. Targets ice40 / Xilinx /
  open-source flows. **No Quartus or Vivado.**
- [ssql2014/mcp4eda](https://github.com/ssql2014/mcp4eda) — similar collection.
- [VerilogCoder (NVIDIA)](https://research.nvidia.com/publication/2024-08_verilogcoder-autonomous-verilog-coding-agents-graph-based-planning-and-abstract),
  [A2HCoder](https://arxiv.org/html/2508.10904v1), [CorrectHDL](https://arxiv.org/html/2511.16395),
  [ResBench](https://arxiv.org/html/2503.08823v1) — research agents for HDL
  generation. None of them ship as a Claude Code plugin.

**Implication:** the LSP-for-agents niche is genuinely empty for FPGA. The
synthesis-MCP niche is partially filled but Quartus-shaped.

### 2.3 Generic MCP-LSP bridges already exist
Several projects already wrap arbitrary LSPs as MCP tools:

- [`isaacphi/mcp-language-server`](https://github.com/isaacphi/mcp-language-server) — Go, exposes definition/references/diagnostics/hover/rename.
- [`jonrad/lsp-mcp`](https://github.com/jonrad/lsp-mcp) — TypeScript, Docker-first.
- [`bug-ops/mcpls`](https://github.com/bug-ops/mcpls) — Rust, multi-LSP routing with project-marker auto-detection.
- [`blackwell-systems/agent-lsp`](https://github.com/blackwell-systems/agent-lsp) — adds skill layer, blast-radius analysis, speculative execution. 30 languages.
- [Gopls native MCP](https://go.dev/gopls/features/mcp) — built into the LSP itself.

**Initial assumption:** fork one of these, configure for HDL, ship as MCP.
**That assumption turned out to be wrong** — see next finding.

### 2.4 Claude Code has **native** LSP plugin support
This was the biggest discovery. From the
[Claude Code plugin reference](https://code.claude.com/docs/en/plugins-reference#lsp-servers):

> _Plugins can provide [Language Server Protocol](https://microsoft.github.io/language-server-protocol/)
> (LSP) servers to give Claude real-time code intelligence while working on your codebase._
>
> _LSP integration provides:_
> - _**Instant diagnostics**: Claude sees errors and warnings immediately after each edit_
> - _**Code navigation**: go to definition, find references, and hover information_
> - _**Language awareness**: type information and documentation for code symbols_

The official marketplace already ships LSP plugins for Go, Python, Rust, etc.
HDLs are missing. A plugin is just JSON:

```json
{
  "name": "fpga-lsp",
  "lspServers": {
    "verible": {
      "command": "verible-verilog-ls",
      "extensionToLanguage": {
        ".sv": "systemverilog",
        ".svh": "systemverilog",
        ".v": "verilog",
        ".vh": "verilog"
      }
    },
    "vhdl_ls": {
      "command": "vhdl_ls",
      "extensionToLanguage": {
        ".vhd": "vhdl",
        ".vhdl": "vhdl"
      }
    }
  }
}
```

**Implication:** the entire MCP-LSP bridge approach (forking
`mcp-language-server`, writing Go code, shipping binaries) is **redundant**.
Claude Code already does the bridging natively. We just declare LSPs in JSON.

### 2.5 The user-facing constraint is a binary install, not the plugin
LSP plugins (including the official `rust-analyzer-lsp`, `pyright-lsp`)
**require the user to install the LSP binary separately**:

> _**You must install the language server binary separately.** LSP plugins
> configure how Claude Code connects to a language server, but they don't
> include the server itself._

So "one-click install" really means:
1. `/plugin install fpga-lsp@fpga-lsp` — instant, all JSON.
2. Install the LSP binary — Verible (single static binary release),
   `cargo install vhdl_ls`. Can be automated by a `setup.sh` shipped in the
   plugin.

### 2.6 SystemVerilog LSP choice — landscape shifted in 2025
Initial research treated Verible vs svlangserver as the main axis. By May 2026
the picture has shifted:

- **Verible** (1.8k stars, weekly releases): strong lint/format. Cross-file
  go-to-def **does work**, but only when a `verible.filelist` is provided —
  without one, it silently falls back to single-file analysis. Single static
  binary on every major OS/arch.
- **hudson-trading/slang-server** (MIT, 217 stars, v0.2.5 on 2026-04-21):
  HRT open-sourced their slang-based server in late 2025. Built on the most
  spec-compliant SV frontend, prebuilt Linux/macOS/Windows binaries, real
  cross-module elaboration. Younger than Verible but on a real release cadence.
- **svlangserver**: effectively dormant — single 2025 commit after a ~2-year
  gap. Demoted to "legacy".
- **veridian**: lags slang releases (v9.1 vs slang v10.0), Linux-only binary.
  Niche.
- **slang** (the library) and **svls** (lint-only) remain useful complements.

**Decision:** ship Verible as the v1 default (broadest binary coverage,
longest track record, weekly releases) **and auto-generate `verible.filelist`
on plugin start** so cross-file go-to-def actually works out of the box.
Expose slang-server as the opt-in "deeper analysis" tier in v1.1 — replacing
the originally-planned svlangserver opt-in. Re-evaluate after dogfooding on
`pvz-fpga`.

### 2.7 Quartus/Vivado MCP is harder, more valuable, separate concern
A Quartus-flavored MCP (option A from the original brainstorm) would expose
synth/fit/timing/program tools to the agent. It's much harder than v1:

- Quartus is proprietary, license-gated, **cannot be bundled**.
- Synthesis is multi-minute → MCP request/response model needs job-id pattern.
- Report parsing is text-based, version-fragile.
- ~2–4 weeks of work vs. 2–4 days for the LSP plugin.

**Decision:** keep it as a separate plugin (`fpga-flow`) in the same
marketplace, shipped after v1.

---

## 3. Final plan

### 3.1 Architecture
Two plugins, one marketplace.

```
nyavana/fpga-lsp                        # GitHub repo + Claude Code marketplace
├── .claude-plugin/
│   └── marketplace.json                # declares both plugins
├── plugins/
│   ├── fpga-lsp/                       # v1 — ship this first
│   │   ├── .claude-plugin/plugin.json
│   │   ├── .lsp.json                   # Verible + vhdl_ls wiring (slang-server in v1.1)
│   │   ├── skills/
│   │   │   ├── sv-lint/SKILL.md        # verible-verilog-lint wrapper
│   │   │   ├── sv-format/SKILL.md      # verible-verilog-format wrapper
│   │   │   └── sv-diff/SKILL.md        # verible-verilog-diff wrapper
│   │   ├── agents/
│   │   │   └── sv-reviewer.md          # SystemVerilog code reviewer
│   │   ├── hooks/
│   │   │   └── hooks.json              # SessionStart: install Verible + gen filelist
│   │   │                               # PostToolUse: format-on-save for *.sv
│   │   └── scripts/
│   │       ├── install-verible.sh      # idempotent binary fetcher (linux x64 in v1)
│   │       └── gen-filelist.sh         # walk workspace, emit verible.filelist
│   └── fpga-flow/                      # v2 — ship after v1 lands
│       └── ...                         # MCP server for Yosys/Verilator/Quartus
├── scripts/
│   └── install-verible.sh
├── PLAN.md                             # this file
└── README.md
```

Why two plugins, not one:
- LSP plugin is JSON-only and zero-maintenance.
- Synthesis MCP server is code, has license complications, drags in heavier
  deps. Don't couple their release cadences.

### 3.2 v1 scope (the LSP plugin)
**Ship:**
- LSP wiring for Verible (`.sv`, `.svh`, `.v`, `.vh`) and rust_hdl
  (`.vhd`, `.vhdl`).
- `verible.filelist` auto-generation on plugin start so cross-file
  go-to-def actually works (load-bearing for the v1 success criterion below).
- SessionStart hook that installs the pinned Verible binary on Linux x64 if
  not already on `$PATH`. One-click really means one click.
- Three skills: `sv-lint`, `sv-format`, `sv-diff` (Verible CLI wrappers; the
  value is consistent invocation + interpretation context for the agent, not
  the wrapping itself).
- One agent: `sv-reviewer` — Verible-lint-aware, scoped to common SV pitfalls
  (inferred latches, blocking-vs-nonblocking in `always_ff`, sensitivity-list
  drift, X-propagation, clock-domain hygiene), reads the filelist for
  project-aware review.
- One hook: PostToolUse format-on-save for SystemVerilog.
- README with install incantation and dogfooding notes on `pvz-fpga`.
- MIT license, GitHub Actions CI smoke-testing the install + LSP handshake on
  every push, pinned Verible version with quarterly bump.

**Do not ship in v1:**
- macOS / Windows / Linux-arm64 binary install (defer to v1.1 — Linux x64 first).
- slang-server config (v1.1 opt-in, replaces the originally-planned
  svlangserver opt-in).
- Synthesis feedback (that's `fpga-flow`).
- Project-file parsing (`.qsf`, `.xpr`) — defer.
- veridian / svlangserver configs — both stale, no plans to ship.

### 3.3 v1 timeline (~6 days, Linux x64 only)
| Day | Deliverable |
|---|---|
| 1 | `plugin.json`, `.lsp.json`, smoke test on `pvz-fpga` (manual Verible install). |
| 2 | `gen-filelist.sh` + SessionStart hook that installs Verible on Linux x64 and emits `verible.filelist`. Verify cross-file go-to-def works on `pvz-fpga`. |
| 3 | `sv-lint`, `sv-format`, `sv-diff` skills + format-on-save hook. |
| 4 | `sv-reviewer` agent. CI workflow (Docker-based clean-machine install test). |
| 5 | `marketplace.json`, README, LICENSE. Install-from-scratch test in a fresh container. |
| 6 | Publish to `github.com/nyavana/fpga-lsp`. Dogfood on `pvz-fpga`. Fix what breaks. |

### 3.4 Install UX
```bash
# In Claude Code:
/plugin marketplace add nyavana/fpga-lsp
/plugin install fpga-lsp@fpga-lsp
```

On first session start, the SessionStart hook checks `$PATH` for
`verible-verilog-ls`. If absent, it downloads the pinned Verible release into
`${CLAUDE_PLUGIN_DATA}/bin/`, generates `verible.filelist` for the current
workspace, and exits. No further user action required on Linux x64. On other
platforms (v1.1), the hook prints the manual install command and opens the
README.

### 3.5 Success criteria
After v1, on `pvz-fpga` running on Linux x64, the agent should:
- See parse errors and lint warnings **automatically** after every edit to a
  `.sv` file (no tool call required — Claude Code does this via LSP).
- Resolve "go to definition" for module/signal symbols **across files in the
  project** (made possible by the auto-generated `verible.filelist`; this is
  the change vs. Verible's default single-file fallback).
- Invoke `/fpga-lsp:sv-lint`, `/fpga-lsp:sv-format`, `/fpga-lsp:sv-diff` as
  bundled skills (or have Claude pick them automatically by relevance).
- Be reviewable by the `sv-reviewer` agent without extra setup.

If those four work end-to-end, v1 has shipped its core value.

### 3.6 Future work (post-v1, in priority order)
1. **macOS + Windows + Linux-arm64 binary install** — extend the SessionStart
   hook to cover the four remaining OS/arch combos. Verible publishes
   binaries for all of them; the lift is mostly platform detection and
   per-OS smoke tests.
2. **slang-server opt-in** — surface deeper cross-module elaboration via
   `hudson-trading/slang-server` for users who need it. User picks via
   `user_config`. Replaces the originally-planned svlangserver opt-in.
3. **`fpga-flow` plugin (option A)** — MCP server exposing Yosys, Verilator,
   GTKWave, optionally Quartus. Modeled after MCP4EDA but Cyclone-V/DE1-SoC
   flavored.
4. **Synthesis-aware lint** — feed Verible AST through a heuristic that flags
   inferred latches, oversize muxes, clock-domain crossings before synthesis
   ever runs. This is the actual differentiated value vs. existing tooling.
5. **Submit the bare LSP wiring upstream** to `claude-plugins-official` as
   `verible-lsp` and `vhdl-lsp`. Keep `fpga-lsp` as the value-added fork
   with filelist auto-gen + skills + reviewer + (eventually) synth feedback.
6. **Watch parallel work** — `sinply/hdl-lsp-marketplace` (created
   2026-04-27, same niche, 0 stars) is the closest known parallel project.
   Monitor for collisions or collaboration opportunities. Adjacent Claude
   Code plugins `Fzhiyu1/chipforge-plugin` and `codejunkie99/Gateflow-Plugin`
   target sim/synth, not LSP — complementary, not competing.

### 3.7 Why this is the right execution path
The constraints "one-click Claude Code install" and "automatic LSP for agents"
narrow the design space to exactly one option:

- A custom MCP-LSP bridge would be more code, worse UX, and lose Claude Code's
  built-in auto-diagnostics-on-edit behavior.
- A from-scratch HDL LSP would be years of work and duplicates Verible.
- A vendor-flow MCP server (Quartus/Vivado) doesn't satisfy the "automatic LSP"
  requirement at all — it's a complement, not a replacement.

The native plugin route is faster to ship, cheaper to maintain, and aligns
with the platform's intended extension surface.

**Where the real differentiation lives** (be honest — the CLI wrappers alone
aren't a moat):

1. **Auto-installer + filelist generator.** Anyone can declare an LSP in JSON;
   almost no one will close the gap to "actually works on a multi-module
   project the moment you `/plugin install`". That gap is the single biggest
   reason Verible has been invisible to agents until now.
2. **`sv-reviewer` agent** with HDL-specific judgment baked in (latch
   inference, sensitivity lists, X-propagation, clock-domain hygiene).
3. **Eventual synth-feedback layer** (`fpga-flow`) sharing the same
   marketplace and reviewer agent.

The skills (`sv-lint`, `sv-format`, `sv-diff`) are convenience, not
differentiation — agents can already shell out to the Verible CLI. They earn
their keep by giving the agent a stable invocation surface and a documented
context for interpreting output.

---

## 4. Open questions to revisit after v1

- Does the auto-generated `verible.filelist` give the agent enough cross-file
  context on multi-module designs, or do we need to make slang-server the
  default after dogfooding?
- Should the `sv-reviewer` agent eventually call into `fpga-flow` for
  synthesis-aware review, or stay LSP-only?
- Is there a clean way to feed Quartus `.rpt` parsing into LSP diagnostics so
  timing/utilization issues surface in the same channel as parse errors?
- Tcl files in `pvz-fpga` (and most FPGA projects) currently have no LSP
  coverage — worth a `fpga-flow` companion or out of scope?

---

## 5. References

### LSP servers for HDLs
- [chipsalliance/verible](https://github.com/chipsalliance/verible) — SV parser, linter, formatter, LSP
- [Antmicro: Integrating LSP in Verible](https://antmicro.com/blog/2023/02/integrating-the-lsp-in-verible)
- [VHDL-LS/rust_hdl](https://github.com/VHDL-LS/rust_hdl) — VHDL LSP in Rust
- [hudson-trading/slang-server](https://github.com/hudson-trading/slang-server) — HRT's slang-based SV LSP, MIT, prebuilt binaries (open-sourced 2025)
- [imc-trading/svlangserver](https://github.com/imc-trading/svlangserver) — workspace-indexing SV LSP (effectively dormant)
- [vivekmalneedi/veridian](https://github.com/vivekmalneedi/veridian) — Rust SV LSP (lags slang releases)
- [dalance/svls](https://github.com/dalance/svls) — lint-focused SV LSP
- [MikePopoloski/slang](https://github.com/MikePopoloski/slang) — SV compiler/library
- [HRT: Designing a SystemVerilog Language Server](https://www.hudsonrivertrading.com/hrtbeat/designing-a-systemverilog-language-server/) — original blog; HRT later open-sourced the server as `slang-server`

### MCP / agent tooling for HDL
- [NellyW8/MCP4EDA](https://github.com/NellyW8/MCP4EDA) — RTL→GDSII MCP server (paper)
- [ssql2014/mcp4eda](https://github.com/ssql2014/mcp4eda) — EDA tool MCP collection
- [agent4eda.com](https://www.agent4eda.com/)

### Generic MCP-LSP bridges (rejected as base for v1)
- [isaacphi/mcp-language-server](https://github.com/isaacphi/mcp-language-server)
- [jonrad/lsp-mcp](https://github.com/jonrad/lsp-mcp)
- [bug-ops/mcpls](https://github.com/bug-ops/mcpls)
- [blackwell-systems/agent-lsp](https://github.com/blackwell-systems/agent-lsp)
- [Gopls MCP feature](https://go.dev/gopls/features/mcp)

### Claude Code plugin platform
- [Discover and install plugins](https://code.claude.com/docs/en/discover-plugins)
- [Plugins reference (LSP servers section)](https://code.claude.com/docs/en/plugins-reference#lsp-servers)
- [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official)

### Adjacent Claude Code plugins (overlap check, May 2026)
- [Fzhiyu1/chipforge-plugin](https://github.com/Fzhiyu1/chipforge-plugin) — Icarus Verilog sim + VCD-to-WaveJSON; no LSP
- [codejunkie99/Gateflow-Plugin](https://github.com/codejunkie99/Gateflow-Plugin) — Verilator lint + Yosys synth + SymbiYosys formal; no LSP
- [sinply/hdl-lsp-marketplace](https://github.com/sinply/hdl-lsp-marketplace) — same niche as fpga-lsp, created 2026-04-27, monitor

### Research on LLMs for HDL
- [VerilogCoder (NVIDIA)](https://research.nvidia.com/publication/2024-08_verilogcoder-autonomous-verilog-coding-agents-graph-based-planning-and-abstract)
- [A2HCoder](https://arxiv.org/html/2508.10904v1)
- [CorrectHDL](https://arxiv.org/html/2511.16395)
- [ResBench](https://arxiv.org/html/2503.08823v1)

### Vendor flow (future `fpga-flow` plugin)
- [Quartus Prime Tcl scripting](https://www.intel.com/content/www/us/en/docs/programmable/683562/21-3/scripting-with-tcl-in-the-software.html)
