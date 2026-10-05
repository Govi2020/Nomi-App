# Migration progress

## Phase 0 — Recon, backup, baseline (2026-10-05)

- Done: confirmed browser-based React/Vite + FastAPI/SQLite runtime; no Electron app. Backed up the empty `data/` directory outside the repository.
- Decided: user selected `com.nomi.desktop`, approved project-local Nuitka installation, and expanded the target to Windows + Linux. Other §7 defaults are accepted: external Ollama, remote browser voice models, per-user NSIS on Windows, manual-only import, version 0.1.0, unsigned release. Linux output will be AppImage and `.deb`, baseline Ubuntu 22.04/Debian 12.
- Surprised: backend MCP starts a separate Python stdio child process; frontend chat streaming bypasses `apiClient`; settings live in WebView localStorage. Baseline backend tests ran in `.venv`: 13 passed, one failed on a clinical-report prompt assertion. Frontend `npm run build` passed with Vite's chunk-size warning. The direct Hugging Face model paths may redirect to storage/CDN hosts; capture actual redirects in WebView before finalizing CSP.
- Gate status: Phase 0 complete and committed as `6dd1c48`. Nuitka's install in `.venv-build` is approved; no system-wide toolchain install is approved. The unrelated baseline test remains failing and unchanged.

## Phase 1 — Backend launchable and compile-safe (stopped at exit gate)

- Done: added NOMI path/host/port/version config with legacy `JOURNAL_DATA_DIR` fallback; added `/health`, loopback guard, rotating file logs, stdin shutdown, and compiled MCP self-spawn mode; restricted CORS/Host and retained dev proxy access.
- Verified: launcher health contract, loopback listener, and EOF shutdown passed on port 8765 using a new synthetic `%TEMP%` data directory. Two Phase 1 suite attempts both returned 14/15; the same clinical-report prompt assertion documented at Phase 0 fails. `git diff --check` passed.
- Gate status: **FAIL — STOPPED per operating rule after two attempts.** Phase 2 has not started. Need user direction on whether to align the stale prompt/test wording, or preserve behavior and record this known test failure before proceeding.
