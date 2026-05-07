#!/usr/bin/env bash
# Resolves a Verible filelist for the workspace. Prints the absolute path on stdout.
# - If <workspace>/verible.filelist exists, leave it untouched and echo its path.
# - Otherwise, generate a plugin-managed filelist under ${CLAUDE_PLUGIN_DATA}/filelists/
#   keyed by a hash of the realpath of the workspace.
set -euo pipefail

WORKSPACE="${1:-$PWD}"

if [ ! -d "$WORKSPACE" ]; then
  printf 'gen-filelist.sh: workspace not a directory: %s\n' "$WORKSPACE" >&2
  exit 1
fi

# Fallback for CLAUDE_PLUGIN_DATA when run outside a Claude Code session (e.g. CI).
: "${CLAUDE_PLUGIN_DATA:=${XDG_DATA_HOME:-$HOME/.local/share}/claude-code/plugins/fpga-lsp}"

WORKSPACE_ABS="$(cd "$WORKSPACE" && pwd -P)"

PROJECT_FILELIST="${WORKSPACE_ABS}/verible.filelist"
if [ -f "$PROJECT_FILELIST" ]; then
  printf '%s\n' "$PROJECT_FILELIST"
  exit 0
fi

# Workspace hash must match bin/verible-ls's formula exactly.
WS_HASH="$(printf '%s' "$WORKSPACE_ABS" | sha256sum | cut -c1-16)"

TARGET_DIR="${CLAUDE_PLUGIN_DATA}/filelists"
TARGET="${TARGET_DIR}/${WS_HASH}.filelist"
mkdir -p "$TARGET_DIR"

TMP="$(mktemp "${TARGET_DIR}/.${WS_HASH}.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

# Collect HDL sources, exclude common non-source directories, sort deterministically.
find "$WORKSPACE_ABS" \
  \( -path '*/.git' -o -path '*/.git/*' \
     -o -path '*/build' -o -path '*/build/*' \
     -o -path '*/output_files' -o -path '*/output_files/*' \
     -o -path '*/simulation' -o -path '*/simulation/*' \
     -o -path '*/node_modules' -o -path '*/node_modules/*' \
  \) -prune -o \
  -type f \( -name '*.sv' -o -name '*.svh' -o -name '*.v' -o -name '*.vh' \) \
  -print 2>/dev/null \
  | LC_ALL=C sort > "$TMP"

mv "$TMP" "$TARGET"
trap - EXIT

printf '%s\n' "$TARGET"
