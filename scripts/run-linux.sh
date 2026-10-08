#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
if [[ ! -x "$ROOT_DIR/.venv/bin/python" || ! -d "$ROOT_DIR/frontend/node_modules" || ! -d "$ROOT_DIR/node_modules" ]]; then
  echo "Developer dependencies are missing. Run ./scripts/setup-linux.sh first." >&2
  exit 1
fi
if [[ -r /proc/version ]] && grep -qi microsoft /proc/version; then
  export LIBGL_ALWAYS_SOFTWARE="${LIBGL_ALWAYS_SOFTWARE:-1}"
  export WEBKIT_DISABLE_DMABUF_RENDERER="${WEBKIT_DISABLE_DMABUF_RENDERER:-1}"
  export GDK_BACKEND="${GDK_BACKEND:-x11}"
fi
exec npm run tauri:dev
