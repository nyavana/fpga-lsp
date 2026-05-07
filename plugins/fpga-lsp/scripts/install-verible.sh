#!/usr/bin/env bash
# Installs the pinned Verible release into ${CLAUDE_PLUGIN_DATA}/bin/.
# Shared between the SessionStart hook (eager pre-warm) and the verible-ls
# wrapper (lazy fallback). Single source of truth for version + checksum.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION_FILE="${SCRIPT_DIR}/verible.version"

if [ ! -r "$VERSION_FILE" ]; then
  printf 'install-verible.sh: missing version file at %s\n' "$VERSION_FILE" >&2
  exit 1
fi

VERIBLE_TAG="$(tr -d '[:space:]' < "$VERSION_FILE")"

# Hard-coded SHA256 for the linux-static-x86_64 tarball of VERIBLE_TAG.
# A version bump in verible.version requires updating this checksum too.
SHA256_LINUX_X64="1edc1f29c70d74213ed373e727183802d5a733e23f9ab9c74462f5b18b76f2c0"

# Fallback for CLAUDE_PLUGIN_DATA when run outside a Claude Code session (e.g. CI).
: "${CLAUDE_PLUGIN_DATA:=${XDG_DATA_HOME:-$HOME/.local/share}/claude-code/plugins/fpga-lsp}"

BIN_DIR="${CLAUDE_PLUGIN_DATA}/bin"

err() {
  printf 'install-verible.sh: %s; see README for manual install\n' "$1" >&2
}

# Skip if a usable binary is already reachable.
if command -v verible-verilog-ls >/dev/null 2>&1; then
  exit 0
fi
if [ -x "${BIN_DIR}/verible-verilog-ls" ]; then
  exit 0
fi

OS="$(uname -s)"
ARCH="$(uname -m)"

PLATFORM=""
case "$OS" in
  Linux)
    case "$ARCH" in
      x86_64|amd64) PLATFORM="linux-static-x86_64" ;;
      aarch64|arm64) PLATFORM="linux-static-arm64" ;;
    esac
    ;;
  Darwin) PLATFORM="macOS" ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM="win64" ;;
esac

if [ "$PLATFORM" != "linux-static-x86_64" ]; then
  printf 'install-verible.sh: auto-install not supported on %s/%s; install Verible %s manually\n' \
    "$OS" "$ARCH" "$VERIBLE_TAG" >&2
  exit 0
fi

ASSET="verible-${VERIBLE_TAG}-${PLATFORM}.tar.gz"
URL="https://github.com/chipsalliance/verible/releases/download/${VERIBLE_TAG}/${ASSET}"

mkdir -p "$BIN_DIR"

TMPDIR="$(mktemp -d)"
TARBALL="${TMPDIR}/${ASSET}"

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

if command -v curl >/dev/null 2>&1; then
  if ! curl -fsSL --retry 3 --retry-delay 2 -o "$TARBALL" "$URL"; then
    err "download failed from $URL"
    exit 1
  fi
elif command -v wget >/dev/null 2>&1; then
  if ! wget -q -O "$TARBALL" "$URL"; then
    err "download failed from $URL"
    exit 1
  fi
else
  err "neither curl nor wget available to download Verible"
  exit 1
fi

ACTUAL="$(sha256sum < "$TARBALL" | cut -c1-64)"
if [ "$ACTUAL" != "$SHA256_LINUX_X64" ]; then
  err "checksum mismatch (expected ${SHA256_LINUX_X64}, got ${ACTUAL})"
  exit 1
fi

EXTRACT_DIR="${TMPDIR}/extract"
mkdir -p "$EXTRACT_DIR"
if ! tar -xzf "$TARBALL" -C "$EXTRACT_DIR"; then
  err "tar extraction failed"
  exit 1
fi

SRC_BIN_DIR="${EXTRACT_DIR}/verible-${VERIBLE_TAG}/bin"
if [ ! -d "$SRC_BIN_DIR" ]; then
  err "extracted archive missing expected bin/ directory"
  exit 1
fi

# Copy every binary the release ships under bin/.
for f in "$SRC_BIN_DIR"/*; do
  [ -f "$f" ] || continue
  cp -f "$f" "${BIN_DIR}/"
  chmod +x "${BIN_DIR}/$(basename "$f")"
done

if [ ! -x "${BIN_DIR}/verible-verilog-ls" ]; then
  err "post-install check failed: verible-verilog-ls not present"
  exit 1
fi

printf 'install-verible: installed verible %s\n' "$VERIBLE_TAG" >&2
