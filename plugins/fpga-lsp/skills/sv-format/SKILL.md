---
name: sv-format
description: Format a SystemVerilog/Verilog file with `verible-verilog-format`, either in-place (rewrite the file) or in preview mode (print formatted text to stdout, file unchanged). Use when the user asks to "format this `.sv` file", "reformat X", or "show me what Y would look like formatted / preview the formatting before I commit".
allowed-tools: Bash
---

# sv-format

Thin wrapper over `verible-verilog-format`. Two modes; pick based on intent.

## In-place mode

Rewrites the file on disk:

```
verible-verilog-format --inplace <path>
```

Use when the user wants the working tree updated — phrasings like "format this file", "fix the formatting", "reformat X". On success the command prints nothing and exits 0; report the path that was rewritten.

## Preview mode

Prints formatted text to stdout, leaves the file untouched:

```
verible-verilog-format <path>
```

Use when the user wants to see the result before committing — phrasings like "preview the formatting", "show me what it would look like formatted", "diff the formatted version against current". Capture stdout and return it; the caller can diff against the original.

## Picking the mode

- Default to in-place when the request is imperative and the file is in the working tree.
- Default to preview when the request is exploratory, when the file is read-only, or when the caller has signalled they want to inspect the diff first.
- When ambiguous, ask once.

## Exit behavior

Non-zero exit means the file did not parse; surface Verible's stderr verbatim — the file is unchanged in both modes when this happens.

## Scope

This skill SHALL invoke only `verible-verilog-format`. No bespoke style rules, no post-processing of the output.
