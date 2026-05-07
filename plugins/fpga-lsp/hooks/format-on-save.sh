#!/usr/bin/env bash
# PostToolUse handler: runs verible-verilog-format --inplace on Write/Edit of
# .sv/.svh/.v/.vh files. Emits a systemMessage on first fire per session;
# silent thereafter. Exits cleanly if Verible isn't reachable so we don't
# noisily fail on every edit on unsupported platforms.
set -euo pipefail

# Fallback for CLAUDE_PLUGIN_DATA when run outside a Claude Code session.
: "${CLAUDE_PLUGIN_DATA:=${XDG_DATA_HOME:-$HOME/.local/share}/claude-code/plugins/fpga-lsp}"

PAYLOAD="$(cat || true)"
FILE="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"

if [ -z "$FILE" ]; then
  exit 0
fi

case "$FILE" in
  *.sv|*.svh|*.v|*.vh) ;;
  *) exit 0 ;;
esac

if [ ! -f "$FILE" ]; then
  exit 0
fi

resolve_fmt() {
  if command -v verible-verilog-format >/dev/null 2>&1; then
    command -v verible-verilog-format
    return 0
  fi
  if [ -x "${CLAUDE_PLUGIN_DATA}/bin/verible-verilog-format" ]; then
    printf '%s\n' "${CLAUDE_PLUGIN_DATA}/bin/verible-verilog-format"
    return 0
  fi
  return 1
}

FMT="$(resolve_fmt || true)"
if [ -z "$FMT" ]; then
  # Per spec: exit cleanly without emitting anything when format binary is missing.
  exit 0
fi

if ! "$FMT" --inplace "$FILE" >/dev/null 2>&1; then
  # Format failure on a single file shouldn't disrupt the edit flow.
  exit 0
fi

# Prefer session_id from the stdin payload (canonical per the hooks docs);
# fall back to env vars and then to "default" so the marker still works
# when invoked outside a Claude Code hook context.
SESSION="$(printf '%s' "$PAYLOAD" | jq -r '.session_id // empty' 2>/dev/null || true)"
SESSION="${SESSION:-${CLAUDE_SESSION_ID:-${CLAUDE_SESSION:-default}}}"
STATE_DIR="${CLAUDE_PLUGIN_DATA}/session-state"
MARKER="${STATE_DIR}/${SESSION}"

mkdir -p "$STATE_DIR"

if [ ! -e "$MARKER" ]; then
  : > "$MARKER"
  jq -nc --arg msg "fpga-lsp: formatted $FILE with verible-verilog-format" \
    '{systemMessage: $msg}'
fi

exit 0
