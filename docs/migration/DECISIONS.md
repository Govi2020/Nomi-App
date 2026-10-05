# Migration decisions

## Defaults recorded at Phase 0 (2026-10-05)

- Bundle identifier: `com.nomi.desktop`, selected by the user. Treat as permanent once released because it determines the app-data/WebView storage location.
- Ollama: keep external; detect it, guide installation, and offer model download; never bundle, control, or delete user models.
- Voice models: retain current browser-side remote download/cache behavior. Bundle assets only if requested later.
- WebView2 installer mode: `downloadBootstrapper` by default (internet required if WebView2 is absent).
- Install scope: NSIS per-user; preserve app data on uninstall.
- Existing dev data import: manual copy only; no automatic migration.
- Starting version: `0.1.0`.
- Code signing: out of scope; an unsigned installer may prompt SmartScreen.
- Target platforms: Windows and Linux (user override to the prompt's Windows-only default). Linux packaging will target AppImage and Debian packages, with Ubuntu 22.04 / Debian 12 as the compatibility baseline unless later evidence requires another distro. Linux building and runtime testing need a Linux host/VM.
- User approved installing Nuitka, zstandard, and ordered-set in the project-local `.venv-build` only. No system-wide toolchain installation is authorized by that approval.

## Phase 0 workspace notes

- Started on `main` with pre-existing uncommitted `backend/config.py` modification and untracked `NOMI_TAURI_MASTER_PROMPT.md`, `README.md`, `run.ps1`, and `setup.ps1`. These were preserved; the feature branch was created without staging them.
- `data/` was copied before path analysis to `C:\Users\Govind\AppData\Local\Temp\Nomi-data-backup-20261005-044613`. Its top-level listing was empty. No file contents in `data/` were read.
- No system-wide toolchain was installed. Rust, MSVC Build Tools, WebView2, Node/npm, Python 3.14.7, and the local Ollama API were detected; Nuitka was missing at CP1.
