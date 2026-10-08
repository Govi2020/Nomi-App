#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
export CARGO_REGISTRIES_CRATES_IO_PROTOCOL="${CARGO_REGISTRIES_CRATES_IO_PROTOCOL:-git}"
export CARGO_NET_GIT_FETCH_WITH_CLI="${CARGO_NET_GIT_FETCH_WITH_CLI:-true}"
export CARGO_HTTP_CAINFO="${CARGO_HTTP_CAINFO:-/etc/ssl/certs/ca-certificates.crt}"
npm run build:backend
npm run tauri:build -- --bundles "${NOMI_BUNDLES:-deb}"
