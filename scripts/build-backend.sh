#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_VENV="${ROOT_DIR}/.venv-build"
BUILD_DIR="${ROOT_DIR}/build/backend"
BINARIES_DIR="${ROOT_DIR}/src-tauri/binaries"

if ! command -v rustc >/dev/null 2>&1; then
  echo "rustc is required to determine the Tauri sidecar target triple." >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to build the backend sidecar." >&2
  exit 1
fi

TRIPLE="$(rustc -vV | sed -n 's/^host: //p')"
if [[ -z "${TRIPLE}" ]]; then
  echo "Could not read the host target triple from rustc -vV." >&2
  exit 1
fi

if [[ ! -x "${BUILD_VENV}/bin/python" ]]; then
  python3 -m venv "${BUILD_VENV}"
fi
PYTHON="${BUILD_VENV}/bin/python"
"${PYTHON}" -m pip install --disable-pip-version-check -r "${ROOT_DIR}/requirements.lock.txt"

mkdir -p "${BUILD_DIR}" "${BINARIES_DIR}"
"${PYTHON}" -m nuitka \
  --mode=onefile \
  --onefile-tempdir-spec='{CACHE_DIR}/Nomi/{VERSION}' \
  --product-version=0.1.0 \
  --follow-imports \
  --assume-yes-for-downloads \
  --jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 2)" \
  --output-dir="${BUILD_DIR}" \
  --output-filename=nomi-backend \
  "${ROOT_DIR}/backend/entry.py"

SOURCE="${BUILD_DIR}/nomi-backend"
DEST="${BINARIES_DIR}/nomi-backend-${TRIPLE}"
if [[ ! -x "${SOURCE}" ]]; then
  echo "Nuitka did not produce the expected executable: ${SOURCE}" >&2
  exit 1
fi
install -m 0755 "${SOURCE}" "${DEST}"
echo "Sidecar: ${DEST}"
du -h "${DEST}"
sha256sum "${DEST}"
