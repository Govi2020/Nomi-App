# Developer setup and desktop build

## End users

Install a packaged Nomi release (`.deb` on Debian/Ubuntu or the Windows per-user installer). Users do not need Python, Node.js, Rust, or pip. Ollama is separate and optional: journaling works without it; AI features require Ollama plus the configured chat and embedding models. Voice features download their browser-side model assets on first use and require internet then.

The Linux package has only been built on Ubuntu 26.04 so far. Compatibility with the intended Ubuntu 22.04 / Debian 12 baseline is unverified. Windows packaging has not completed. Do not distribute the current development package as a verified cross-platform release.

## Developer prerequisites

- Node.js 22.12+ and npm.
- Rust stable installed with rustup and the target toolchain for the host.
- Python 3.11+ for development and Nuitka sidecar compilation. End users do not need Python.
- Windows: Visual Studio C++ Build Tools and WebView2 runtime.
- Linux: Python 3 venv support plus Tauri v2 build packages including GTK/WebKitGTK 4.1, librsvg, appindicator, patchelf, build-essential, and pkg-config. Use Tauri's current prerequisites page for distro-specific package names.
- Ollama at `http://127.0.0.1:11434` for AI feature development; models are optional during ordinary setup.

On supported Debian/Ubuntu developer hosts, the core Linux build packages can be installed with:

```sh
sudo apt update
sudo apt install libwebkit2gtk-4.1-dev build-essential curl wget file libxdo-dev libssl-dev libayatana-appindicator3-dev librsvg2-dev pkg-config python3 python3-venv
```

Package availability varies by release; check the official [Tauri Linux prerequisites](https://v2.tauri.app/start/prerequisites/) for the host distro. The WSL build was performed on Ubuntu 26.04. It does not prove that the selected Ubuntu 22.04 baseline has the same development packages available from its default repositories.

## Setup and run

From the repository root:

```sh
npm run setup:dev
npm run tauri:dev
```

On Linux/WSL, `./scripts/setup-linux.sh` provides prerequisite checks and the same developer dependency setup; `./scripts/run-linux.sh` runs the Tauri development app. On WSL it selects the software-rendered X11 settings that worked for WSLg. This starts Vite, the Tauri shell, and the managed debug backend. The browser-only workflow remains available on Windows through `./run.ps1` after `./setup.ps1`.

Setup creates `.venv`, installs backend development requirements, and runs `npm ci` in the root and frontend. It does not pull Ollama models. Configure or override backend settings in the process environment:

| Variable | Default / use |
|---|---|
| `NOMI_DATA_DIR` | Optional data root; debug defaults to repository `data/`. Use a throwaway directory for manual smoke checks. |
| `JOURNAL_DATA_DIR` | Legacy data-root override; used if `NOMI_DATA_DIR` is unset. |
| `OLLAMA_HOST` | `http://127.0.0.1:11434` |
| `CHAT_MODEL` | `qwen2.5:3b` |
| `EMBED_MODEL` | `nomic-embed-text` |
| `NOMI_HOST`, `NOMI_PORT` | Backend bind host/port. Desktop manager supplies loopback and a dynamic port. |
| `NOMI_API_TOKEN` | Optional for standalone backend; Tauri supplies a per-launch random token. |
| `NOMI_APP_VERSION` | Defaults to `0.1.0`. |

Other tuning variables (`LINK_SIM_THRESHOLD`, `REL_SIM_THRESHOLD`, `FOLLOWUP_MIN_SIM`, `RAG_TOP_K`, `GRAPH_MAX_ENTRIES`) are defined in `backend/config.py`.

## Build a Linux Debian package

On a Linux host with the prerequisites installed:

```sh
./scripts/setup-linux.sh
npm run build:backend
npm run tauri:build -- --bundles deb
```

Or run `./scripts/build-all-linux.sh`, which rebuilds the native Nuitka sidecar first and defaults to the Debian bundle. Set `NOMI_BUNDLES=deb,appimage` only on a host appropriate for every target. Tauri AppImage guidance requires building on the oldest supported Linux baseline; Ubuntu 26.04 does not establish Ubuntu 22.04 compatibility.

The sidecar is emitted to `src-tauri/binaries/nomi-backend-<rust-host-triple>` (with `.exe` on Windows). It is ignored/generated and must be rebuilt after backend source or dependency changes; `tauri build` does not rebuild it. The Linux output currently lands under `src-tauri/target/release/bundle/`.

On Windows, run `npm run setup:dev`, then `npm run build:backend`, then `npm run tauri:build -- --bundles nsis`. The previous Windows native build was blocked by Application Control (OS error 4551); that host limitation remains unresolved.

Cargo must resolve online. In this WSL environment, the known working online configuration is:

```sh
export CARGO_REGISTRIES_CRATES_IO_PROTOCOL=git
export CARGO_NET_GIT_FETCH_WITH_CLI=true
export CARGO_HTTP_CAINFO=/etc/ssl/certs/ca-certificates.crt
```

Do not use `--offline` to work around registry failures.

## Data safety

Production user data lives in the OS app-data directory. Debug defaults to repository `data/` for compatibility. Never inspect or use real `data/` for verification. Put synthetic smoke data under a new ignored `build/` subdirectory or `/tmp`; do not commit it. Existing browser settings and per-user WebView storage depend on the permanent identifier `com.nomi.desktop` and must remain stable.
