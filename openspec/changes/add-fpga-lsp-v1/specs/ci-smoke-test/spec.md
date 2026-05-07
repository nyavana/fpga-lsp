## ADDED Requirements

### Requirement: CI runs `claude plugin validate` on the manifest
The repository SHALL include a GitHub Actions workflow at `.github/workflows/` that, on every push to any branch and on every pull request, runs `claude plugin validate plugins/fpga-lsp` (or its current equivalent per the plugins reference) before any other smoke step. The validation SHALL fail the workflow on manifest, hook, or `.lsp.json` schema errors.

#### Scenario: CI catches a manifest schema error
- **WHEN** a maintainer pushes a commit that breaks the plugin manifest (e.g., missing required field, wrong type)
- **THEN** `claude plugin validate` SHALL fail the workflow at the validate step with a clear error pointing to the offending field

#### Scenario: CI catches a `.lsp.json` schema error
- **WHEN** a maintainer pushes a commit that breaks `.lsp.json` schema (e.g., missing `command`, malformed `extensionToLanguage`)
- **THEN** the validate step SHALL fail before the smoke test runs

### Requirement: CI smoke test reads the LSP command from `.lsp.json`
After validation passes, the CI workflow SHALL parse `plugins/fpga-lsp/.lsp.json` to extract the `verible` server's `command` and `args` fields, then exec exactly those values to launch the LSP for the smoke test. The workflow SHALL NOT hard-code `verible-verilog-ls` (or any other binary name) in the smoke step, because that would let CI pass on a manifest that points at the wrong command.

#### Scenario: Smoke test exercises the plugin-configured command
- **WHEN** the CI smoke step runs after a successful validate
- **THEN** the launched LSP process SHALL be the binary resolved by exec'ing the exact `command` + `args` read from `.lsp.json` (the wrapper script, in v1)

#### Scenario: CI catches a typo in the LSP command path
- **WHEN** a maintainer pushes a commit that points `.lsp.json`'s `verible.command` at a non-existent path
- **THEN** the smoke step SHALL fail at exec, not silently fall back to a different binary

### Requirement: CI exercises a full LSP handshake against a deliberately broken sample
The smoke step SHALL run the SessionStart bootstrap (`install-verible.sh` + `gen-filelist.sh`) in a clean Linux x64 container, then send `initialize` followed by `textDocument/didOpen` for a deliberately broken sample SystemVerilog file to the wrapper-launched LSP, and assert that at least one diagnostic comes back.

#### Scenario: CI runs on a passing change
- **WHEN** a maintainer pushes a commit that does not break the install or LSP handshake
- **THEN** the workflow SHALL complete successfully with the LSP returning at least one diagnostic for the broken sample file

#### Scenario: CI catches a broken install
- **WHEN** a maintainer pushes a commit that breaks `install-verible.sh` (e.g., bad URL, wrong checksum)
- **THEN** the workflow SHALL fail at the install step with a clear error pointing to the failing script

#### Scenario: CI catches a broken LSP handshake
- **WHEN** a maintainer pushes a commit that installs Verible successfully but breaks the LSP handshake (e.g., wrong args in `.lsp.json`, wrapper exits non-zero)
- **THEN** the workflow SHALL fail at the handshake step

### Requirement: CI uses the pinned Verible version from a single shared source
The CI workflow SHALL source the pinned Verible version from the same shared location used by `install-verible.sh` and the wrapper (e.g., `scripts/verible.version` or a single env var), so CI cannot pass on a version that real users do not get.

#### Scenario: Bumping the pinned Verible version
- **WHEN** a maintainer bumps the pinned Verible version in the shared source
- **THEN** the next CI run SHALL exercise the new version and SHALL fail if the new version breaks the handshake

### Requirement: v1 CI matrix is Linux x64 only
The CI workflow SHALL run on Linux x64 only in v1. Adding macOS, Windows, and Linux arm64 runners is a v1.1+ concern and SHALL be tracked alongside the corresponding auto-install support.

#### Scenario: Inspecting the workflow matrix
- **WHEN** a maintainer reads the workflow file
- **THEN** the `runs-on` configuration SHALL specify only a Linux x64 runner
