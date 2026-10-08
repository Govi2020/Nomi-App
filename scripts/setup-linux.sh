#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v node >/dev/null || ! command -v npm >/dev/null; then
  echo "Install Node.js 22.12+ (with npm), then rerun this script." >&2
  exit 1
fi
if ! command -v rustc >/dev/null || ! command -v cargo >/dev/null; then
  echo "Install Rust with rustup, then rerun this script." >&2
  exit 1
fi
if ! pkg-config --exists webkit2gtk-4.1; then
  echo "Tauri Linux dependencies are missing. Install the packages listed in docs/migration/BUILD.md." >&2
  exit 1
fi

if [[ ! -x "$ROOT_DIR/.venv/bin/python" ]]; then
  python3 -m venv "$ROOT_DIR/.venv"
fi
"$ROOT_DIR/.venv/bin/python" -m pip install -r "$ROOT_DIR/backend/requirements.txt"
npm ci
(cd frontend && npm ci)
echo "Setup complete. Start Nomi with: npm run tauri:dev"
echo "Ollama is optional for journaling; no AI models were downloaded."
