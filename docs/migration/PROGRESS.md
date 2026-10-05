# Migration progress

## Phase 0 — Recon, backup, baseline (2026-10-05)

- Done: confirmed browser-based React/Vite + FastAPI/SQLite runtime; no Electron app. Backed up the empty `data/` directory outside the repository.
- Decided: user selected `com.nomi.desktop`, approved project-local Nuitka installation, and expanded the target to Windows + Linux. Other §7 defaults are accepted: external Ollama, remote browser voice models, per-user NSIS on Windows, manual-only import, version 0.1.0, unsigned release. Linux output will be AppImage and `.deb`, baseline Ubuntu 22.04/Debian 12.
- Surprised: backend MCP starts a separate Python stdio child process; frontend chat streaming bypasses `apiClient`; settings live in WebView localStorage. Baseline backend tests ran in `.venv`: 13 passed, one failed on a clinical-report prompt assertion. Frontend `npm run build` passed with Vite's chunk-size warning. The direct Hugging Face model paths may redirect to storage/CDN hosts; capture actual redirects in WebView before finalizing CSP.
- Gate status: Phase 0 complete and committed as `6dd1c48`. Nuitka's install in `.venv-build` is approved; no system-wide toolchain install is approved. The unrelated baseline test remains failing and unchanged.

## Phase 1 — Backend launchable and compile-safe

- Done: added NOMI path/host/port/version config with legacy `JOURNAL_DATA_DIR` fallback; added `/health`, loopback guard, rotating file logs, stdin shutdown, and compiled MCP self-spawn mode; restricted CORS/Host and retained dev proxy access.
- Verified: launcher health contract, loopback listener, and EOF shutdown passed on port 8765 using a new synthetic `%TEMP%` data directory. Two initial suite attempts returned 14/15 on the same stale assertion; after the user-approved assertion alignment, the full suite passed 15/15. `git diff --check` passed.
- Gate status: the user approved aligning the stale test expectation with the existing prompt; product prompt/behavior unchanged. The full suite passed 15/15 after the user-approved assertion alignment, clearing the Phase 1 gate.

## Phase 2 — Frontend runtime API config + production build

- Done: centralized Tauri/browser backend runtime config, backend events and invoke wrappers in `apiClient.ts`; routed Talk streaming through its request boundary; existing diary media URL paths already use `resolveApiUrl`. Added app-root `BackendGate` with starting, error, retry, and logs actions. Browser mode still passes straight through and keeps its Vite proxy workflow.
- Build: local TypeScript project build and Vite production build passed. `frontend/dist` has no `.map` or `.env` files. The only literal loopback backend address outside `apiClient.ts` is the existing Vite development proxy target. `npm` was absent from this shell's PATH, so the equivalent local `tsc` and `vite` wrappers were invoked directly.
- Gate status: Phase 2 build gate passed; no additional tests were added or run per the user's instruction. Large existing voice/model chunks continue to trigger Vite's size advisory.

## Phase 3 — Tauri v2 shell (Linux executable build passed)

- Done: added the root Tauri CLI package, v2 Rust shell/config/capability files, single-instance and opener plugins, a temporary external-backend `get_backend_info` stub, and generated app icons. The capability grants only Tauri core defaults; no webview shell or direct arbitrary file-open permission. The config targets per-user NSIS on Windows and AppImage/`.deb` on Linux under the selected permanent identifier.
- Verified: `cargo check` and `npm run tauri:dev` passed in Ubuntu 26.04 on WSL2 with Cargo online (git registry protocol; no `--offline`). Tauri CLI 2.12.1 compiled and launched the Linux executable; Vite returned HTTP 200. The Windows-native attempt remains blocked by Application Control (OS error 4551), so Linux is the active build environment. No tests were added or run.

## Phase 4 — Managed backend lifecycle (in progress)

- Implemented in the Tauri Rust shell: debug backend launch from the project venv, isolated data-dir and instance ID, loopback ephemeral port, health/instance validation, lifecycle events, bounded stdout/stderr log file, retry/backoff, restart command, logs-folder action, and shutdown signal with timeout/kill fallback. Release sidecar packaging remains unfinished.
- Verified manually against `/tmp/nomi-phase4-managed`: managed `/health` returned `status=ok` and the app instance ID; a synthetic title-only entry was created and read back from SQLite; killing the managed child caused the supervisor to start a new healthy child on the same port. `/api/health` reports Ollama unreachable, so model-backed features are not available in this WSL session until Ollama runs. Vite served the UI (HTTP 200).
- First launch emitted Mesa/EGL errors; a screenshot of the Tauri window itself could not be captured through the Codex desktop. The separate frontend rendered in the Codex browser at the Vite URL.
- Follow-up: with `LIBGL_ALWAYS_SOFTWARE=1`, `WEBKIT_DISABLE_DMABUF_RENDERER=1`, and `GDK_BACKEND=x11`, WSLg created a Nomi 1280×800 window. Clippy passed after a one-line log-rotation conditional cleanup.
- Clean Tauri exit was verified: after stopping the dev session, neither the executable nor its managed backend remained running. The forced port-collision case was not run. No tests were added or run, per user instruction. Phase 4 gate remains in progress pending the port-collision check and remaining packaging work.
