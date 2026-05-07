---
name: sv-diff
description: Compare two SystemVerilog/Verilog sources with `verible-verilog-diff` for a semantic, SV-aware diff that ignores whitespace and comment-only changes. Use when the user wants to compare two `.sv` files, or two git revisions of the same file, and plain `diff` would be noisy because of formatting or comments.
allowed-tools: Bash
---

# sv-diff

Thin wrapper over `verible-verilog-diff`. Use this instead of plain `diff` when whitespace or comment churn would obscure the real changes.

## Two-file mode

Two distinct files on disk:

```
verible-verilog-diff <a.sv> <b.sv>
```

## Two-revision mode

To compare two git revisions of the same path, extract each revision to a temp file first, then diff:

```
git show <ref-a>:<path> > /tmp/sv-diff-a.sv
git show <ref-b>:<path> > /tmp/sv-diff-b.sv
verible-verilog-diff /tmp/sv-diff-a.sv /tmp/sv-diff-b.sv
```

The git extraction is the caller's responsibility; this skill is the diff invocation itself.

## Output format

`verible-verilog-diff` exits 0 when the two inputs are semantically identical (only whitespace/comment differences, or no differences at all). It exits non-zero and prints a token-level diff when the inputs differ semantically. Treat exit 0 with empty output as "no semantic change".

## When to pick this over plain `diff`

- The user cares about behavior, not formatting: `verible-verilog-diff`.
- The user cares about every textual change including comments and indentation: plain `diff`.
- After a `verible-verilog-format` pass: `verible-verilog-diff` should exit 0.

## Scope

This skill SHALL invoke only `verible-verilog-diff`. No bespoke comparison logic.
