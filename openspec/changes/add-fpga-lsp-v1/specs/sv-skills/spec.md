## ADDED Requirements

### Requirement: sv-lint skill wraps verible-verilog-lint
The plugin SHALL ship a `sv-lint` skill at `plugins/fpga-lsp/skills/sv-lint/SKILL.md`. The skill SHALL invoke `verible-verilog-lint` against one or more SystemVerilog files supplied as input and SHALL document the expected output format (Verible's diagnostic format) so the agent can interpret results without guessing.

#### Scenario: Agent invokes sv-lint on a single file
- **WHEN** the agent calls the `sv-lint` skill with a path to a `.sv` file
- **THEN** the skill SHALL run `verible-verilog-lint` on that file and return the lint output, and the agent SHALL be able to associate each diagnostic with a file/line from the documented format

#### Scenario: Agent invokes sv-lint on multiple files
- **WHEN** the agent calls `sv-lint` with multiple file paths
- **THEN** the skill SHALL run lint on each and return aggregated output keyed by file

### Requirement: sv-format skill wraps verible-verilog-format
The plugin SHALL ship a `sv-format` skill at `plugins/fpga-lsp/skills/sv-format/SKILL.md`. The skill SHALL invoke `verible-verilog-format` on a target file (or stdin payload) and SHALL document whether it formats in place or returns the formatted text so the agent can pick the right mode.

#### Scenario: Agent invokes sv-format in-place on a file
- **WHEN** the agent calls `sv-format` with a file path and the in-place mode
- **THEN** the skill SHALL rewrite the file with `verible-verilog-format`'s output and return a confirmation

#### Scenario: Agent invokes sv-format in preview mode
- **WHEN** the agent calls `sv-format` with a file path and the preview mode
- **THEN** the skill SHALL return the formatted text without modifying the file

### Requirement: sv-diff skill wraps verible-verilog-diff
The plugin SHALL ship a `sv-diff` skill at `plugins/fpga-lsp/skills/sv-diff/SKILL.md`. The skill SHALL invoke `verible-verilog-diff` to compare two SystemVerilog files (or two revisions of the same file) and return a semantic diff that ignores whitespace/comment-only changes.

#### Scenario: Agent compares two SystemVerilog files
- **WHEN** the agent calls `sv-diff` with two file paths
- **THEN** the skill SHALL run `verible-verilog-diff` and return the semantic diff output

### Requirement: Skills do not duplicate functionality of the LSP
The `sv-lint`, `sv-format`, and `sv-diff` skills SHALL be thin wrappers over Verible CLIs and SHALL NOT re-implement diagnostics that are already produced by the LSP server in real time. Their value is stable invocation surface and documented interpretation context, not new functionality.

#### Scenario: Maintainer reviews skill scope
- **WHEN** a maintainer reads each `SKILL.md`
- **THEN** the skill body SHALL invoke a single Verible CLI per skill, SHALL document the CLI it wraps, and SHALL NOT contain bespoke diagnostic logic
