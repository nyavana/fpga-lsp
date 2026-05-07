---
name: sv-lint
description: Run Verible's lint over SystemVerilog/Verilog files and surface diagnostics. Use when the user wants lint output for one or more `.sv`/`.svh`/`.v`/`.vh` files (e.g. "lint this file", "what does Verible say about X", "check this RTL for warnings").
allowed-tools: Bash
---

# sv-lint

Thin wrapper over `verible-verilog-lint`. Invoke the CLI, return the diagnostics, let the caller interpret them.

## Invocation

Single file:

```
verible-verilog-lint --rules_config_search <path>
```

Many files: pass each path as a positional argument in one invocation:

```
verible-verilog-lint --rules_config_search <path1> <path2> ...
```

Always pass `--rules_config_search` so a project-level `.rules.verible_lint` (walking up from each source file) is respected without forcing the user to point at it.

If a workspace-root `verible.filelist` exists, or a plugin-managed filelist exists at `${CLAUDE_PLUGIN_DATA}/filelists/<workspace-hash>.filelist`, optionally pass `--file_list_path=<that path>` for cross-file rules. Prefer the project file when both exist.

## Output format

Verible emits one diagnostic per line:

```
<path>:<line>:<col>: <message> [<rule-id>]
```

- `<rule-id>` is the canonical Verible rule (e.g. `always-comb`, `case-missing-default`, `explicit-parameter-storage-type`). Cite it verbatim when reporting.
- Lines without the trailing `[rule-id]` are usually parser errors — surface them as parse errors, not lint warnings.
- Exit code is non-zero when any diagnostic is emitted; do not treat that as a failure of the skill itself.

## Reporting

When multiple paths are passed, group diagnostics by file in the response. Keep rule IDs intact so the caller can look them up. Do not invent severities Verible did not emit.

## Scope

This skill SHALL invoke only `verible-verilog-lint`. No bespoke checks, no rewriting of messages, no interpretation beyond grouping.
