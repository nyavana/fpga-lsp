## ADDED Requirements

### Requirement: PostToolUse hook formats SystemVerilog after edits
The plugin SHALL register a PostToolUse hook in `plugins/fpga-lsp/hooks/hooks.json` that runs `verible-verilog-format` on `.sv`, `.svh`, `.v`, and `.vh` files immediately after Claude Code's `Write` or `Edit` tool modifies them. The hook SHALL resolve the `verible-verilog-format` binary using the same precedence as the LSP wrapper (system PATH, then `${CLAUDE_PLUGIN_DATA}/bin/`).

#### Scenario: Agent writes a SystemVerilog file
- **WHEN** the agent uses Write or Edit to modify a `.sv` file in a workspace where the plugin is installed and Verible is reachable
- **THEN** the PostToolUse hook SHALL run `verible-verilog-format` on the modified file before control returns to the agent, leaving the file in formatted state

#### Scenario: Agent writes a Verilog file
- **WHEN** the agent uses Write or Edit to modify a `.v` or `.vh` file
- **THEN** the PostToolUse hook SHALL apply the same format-on-save behavior to it

### Requirement: First-fire-per-session notice is emitted via systemMessage JSON output
The first time the format-on-save hook fires within a Claude Code session, it SHALL emit a JSON object on stdout containing a `systemMessage` field with a one-line, user-visible notice (e.g., `{"systemMessage": "fpga-lsp: formatted <path> with verible-verilog-format"}`). The hook SHALL NOT rely on plain (non-JSON) stdout for the notice, because PostToolUse plain stdout is documented to go to the debug log only and is not user-visible. Subsequent fires within the same session SHALL produce no `systemMessage` (silent) to avoid noise.

#### Scenario: First edit in a session
- **WHEN** the format-on-save hook fires for the first time in a session
- **THEN** the hook SHALL emit a JSON object on stdout with a `systemMessage` field whose value identifies the action and the file, and Claude Code SHALL surface that message to the user

#### Scenario: Hook output schema is well-formed
- **WHEN** the hook produces its first-fire output
- **THEN** the stdout payload SHALL be a single valid JSON object containing a `systemMessage` string field, parseable by Claude Code's hook output handler without errors

#### Scenario: Subsequent edits in the same session
- **WHEN** the format-on-save hook fires for the second or later time in the same session
- **THEN** the hook SHALL NOT emit a `systemMessage` and SHALL NOT print user-visible notice text

### Requirement: Format-on-save does not run when Verible is missing
If `verible-verilog-format` cannot be resolved (not on `$PATH` and not in `${CLAUDE_PLUGIN_DATA}/bin/`), the PostToolUse hook SHALL exit cleanly without emitting an error or `systemMessage` on every edit.

#### Scenario: Verible missing on macOS without manual install
- **WHEN** the agent edits a `.sv` file on a macOS workspace where the user has not installed Verible
- **THEN** the PostToolUse hook SHALL exit cleanly and SHALL NOT block, fail, or noisily warn on the edit
