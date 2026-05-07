## ADDED Requirements

### Requirement: sv-reviewer agent ships with the plugin
The plugin SHALL ship an agent at `plugins/fpga-lsp/agents/sv-reviewer.md` named `sv-reviewer`. The agent's purpose SHALL be reviewing SystemVerilog code with HDL-specific judgment that mechanical lint cannot express, building on top of Verible lint output rather than replacing it.

#### Scenario: Agent is discoverable after install
- **WHEN** a user installs the plugin and lists available agents
- **THEN** `sv-reviewer` SHALL appear with a one-line description identifying it as a SystemVerilog-aware code reviewer that runs Verible first

### Requirement: sv-reviewer runs Verible lint first and treats its output as ground truth
The `sv-reviewer` agent SHALL invoke `verible-verilog-lint` (using the resolved project filelist) on the files under review BEFORE producing any judgment. The agent SHALL cite specific Verible rule IDs (e.g., `always-comb`, `case-missing-default`) when its findings derive from a lint diagnostic, so the user can suppress or reconfigure individual rules. The agent SHALL NOT claim deterministic detection of patterns Verible's rule engine doesn't cover.

#### Scenario: Reviewing a file with a Verible-detectable issue
- **WHEN** the user invokes `sv-reviewer` on a `.sv` file containing a pattern Verible flags (e.g., `always-comb` rule fires on a missing default in a case statement)
- **THEN** the agent SHALL run `verible-verilog-lint` first, cite the Verible rule ID in its report, quote the offending code, and explain the design implication

#### Scenario: Lint pass with no diagnostics
- **WHEN** the user invokes `sv-reviewer` on a file Verible lints cleanly
- **THEN** the agent SHALL report the clean lint pass, then proceed to judgment-layer review (interpretation, design-level concerns) without fabricating Verible diagnostics

### Requirement: sv-reviewer's interpretive layer covers HDL-specific design pitfalls
On top of Verible's mechanical findings, the `sv-reviewer` agent SHALL apply HDL-specific judgment scoped to: inferred latches, blocking-vs-nonblocking misuse in `always_ff` blocks, sensitivity-list drift, X-propagation hazards, and clock-domain crossing hygiene. For findings in this layer that are NOT backed by a Verible rule, the agent SHALL mark them as judgment-based (not detective) and SHALL phrase them as concerns to verify rather than confirmed defects.

#### Scenario: Higher-order CDC concern with no Verible rule
- **WHEN** the user invokes `sv-reviewer` on a multi-file design where signals appear to cross clock domains without explicit synchronisation
- **THEN** the agent MAY flag the suspected CDC, SHALL mark the finding as judgment-based, SHALL cite the relevant signal and module locations, and SHALL frame the recommendation as "verify whether this needs a synchronizer" rather than "this is a CDC bug"

#### Scenario: Inferred latch backed by Verible
- **WHEN** Verible's lint flags an inferred latch in an `always_comb` block
- **THEN** the agent SHALL surface the Verible diagnostic with the rule ID and add an interpretive explanation of why latch inference is harmful and how to fix it

### Requirement: sv-reviewer is filelist-aware
The `sv-reviewer` agent SHALL load the filelist resolved by `lsp-bootstrap` (project-owned `verible.filelist` if present, otherwise the plugin-managed copy under `${CLAUDE_PLUGIN_DATA}/filelists/`) and use it both when invoking `verible-verilog-lint` and when resolving cross-file symbol references in its judgment-layer review.

#### Scenario: Reviewing a multi-file design
- **WHEN** the user invokes `sv-reviewer` in a workspace with a resolved filelist
- **THEN** the agent SHALL pass the filelist to `verible-verilog-lint` and SHALL be able to reference symbols defined in other files within the project

#### Scenario: Reviewing in a workspace without a resolvable filelist
- **WHEN** the user invokes `sv-reviewer` in a workspace where neither a project-owned nor a plugin-managed filelist exists
- **THEN** the agent SHALL warn that cross-file analysis is degraded, SHALL run Verible single-file, and SHALL proceed with single-file judgment-layer review only

### Requirement: sv-reviewer is conservative on ambiguous patterns
For its judgment-layer findings (those NOT backed by a Verible rule), the `sv-reviewer` agent SHALL flag only patterns it can match with high confidence and SHALL NOT issue warnings on patterns where the SV semantics are ambiguous or context-dependent (e.g., asynchronous resets that look like sensitivity-list drift but are intentional).

#### Scenario: Reviewing legitimate asynchronous reset
- **WHEN** the user invokes `sv-reviewer` on a `.sv` file containing a correctly-written async reset pattern (`always_ff @(posedge clk or negedge rst_n)`)
- **THEN** the agent SHALL NOT flag the sensitivity list as drift in either the Verible-cited or judgment-layer sections of the review
