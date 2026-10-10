#!/usr/bin/env bash
# Prepare a Linux/WSL host for a Windows NSIS build of Nomi, then build it.
# Run from the project root: ./setup_and_build_exe.sh [--install]
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

INSTALL=0
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=1 ;;
    -h|--help)
      sed -n '1,5p' "$0"
      cat <<'HELP'

Options:
  --install  Install Linux cross-build prerequisites with apt and rustup.

This script cross-compiles the Tauri shell for Windows. The Nomi backend is
also a bundled executable and must be compiled by Windows Python/Nuitka first.
Place that file at:
  src-tauri/binaries/nomi-backend-x86_64-pc-windows-msvc.exe
HELP
      exit 0
      ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

die() { echo "ERROR: $*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

[[ "$(uname -s)" == Linux ]] || die 'Run this script in Linux or WSL.'
[[ -f package.json && -f src-tauri/tauri.conf.json ]] || die 'Run this script from the Nomi project root.'

if (( INSTALL )); then
  have sudo || die 'sudo is required for --install.'
  sudo apt-get update
  sudo apt-get install -y build-essential curl file wget pkg-config libssl-dev \
    clang lld llvm nsis
  if ! have rustup; then
    echo 'Install rustup from https://rustup.rs, then rerun this script.' >&2
    die 'Automatic Rust installation is intentionally not performed.'
  fi
  rustup target add x86_64-pc-windows-msvc
  if ! have cargo-xwin; then cargo install --locked cargo-xwin; fi
fi

for tool in node npm rustup cargo lld-link llvm-rc makensis; do
  have "$tool" || die "Missing '$tool'. Install it, or rerun with --install (for apt/rustup-managed tools)."
done

TARGET=x86_64-pc-windows-msvc
SIDECAR="src-tauri/binaries/nomi-backend-${TARGET}.exe"
[[ -x node_modules/.bin/tauri ]] || die 'Frontend dependencies are missing. Run npm ci in the project root first.'
[[ -f "$SIDECAR" ]] || die "Windows backend sidecar is missing: $SIDECAR. Build it on Windows with Python 3.11+ and Nuitka using scripts/build_backend.py, then copy the resulting Windows executable to this path. Linux Nuitka output cannot serve as the Windows sidecar."

if ! rustup target list --installed | grep -Fxq "$TARGET"; then
  if (( INSTALL )); then rustup target add "$TARGET"; else die "Rust target $TARGET is missing. Run rustup target add $TARGET or rerun with --install."; fi
fi
if ! cargo xwin --version >/dev/null 2>&1; then
  if (( INSTALL )); then cargo install --locked cargo-xwin; else die 'cargo-xwin is missing. Install with: cargo install --locked cargo-xwin'; fi
fi

export NOMI_BUNDLES=nsis
echo "Building Nomi Windows installer for $TARGET..."
npm run tauri:build -- --runner cargo-xwin --target "$TARGET" --bundles nsis

OUTPUT="src-tauri/target/$TARGET/release/bundle/nsis"
echo "Build complete. Installer output: $ROOT_DIR/$OUTPUT"
find "$OUTPUT" -maxdepth 1 -type f -iname '*.exe' -print
