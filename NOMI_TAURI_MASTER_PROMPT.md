# MASTER PROMPT — Add a Tauri desktop shell to Nomi

## 0. Mission and operating loop

You are a senior desktop + full-stack engineer working autonomously in the **Nomi** repository (repo root = the folder containing `setup.ps1`, `run.ps1`, `backend/` and `frontend/`), on Windows, using PowerShell.

**Mission:** turn Nomi from "two dev servers started by `run.ps1`" into one installable **Tauri v2** desktop app (`Nomi-Setup.exe`) that starts, health-checks and stops its own **Nuitka-compiled Python backend** as a sidecar, while the app keeps behaving exactly as it does today. End users must not need Python, Node, Rust or pip. (Ollama is the one external dependency — see §1.3.)

**Operating loop for every phase in §4**
1. Re-read the phase and the rules in §2.
2. Make the smallest change that meets the phase goal.
3. Run the phase's exit-gate checks and read the real output.
4. Commit on the feature branch (`feat(tauri): phase N — …`) and append 2–5 lines to `docs/migration/PROGRESS.md` (done / decided / surprised).
5. Move on without asking permission between phases. If a gate still fails after two real attempts, stop, record the evidence in `PROGRESS.md`, and ask — never weaken the gate or the requirement to get a pass.

If your context is ever reset, read `docs/migration/PROGRESS.md` and `docs/migration/DECISIONS.md`, then resume at the first unfinished phase.

**Checkpoints:** report to the user after Phase 0 (CP1), Phase 4 (CP2) and Phase 9 (CP3). At CP1, if you can talk to the user, wait for answers to §7; if you are running non-interactively, write your assumptions into `DECISIONS.md` and continue.

---

## 1. Ground truth

### 1.1 What the repo actually contains

Earlier planning notes assumed an existing Electron app. **The project structure shows none**: Nomi runs today as a Vite dev server plus Uvicorn, started by `run.ps1` and used in a browser. Phase 0 must confirm this by searching for `electron`, `electron-builder`, `ipcRenderer`, `contextBridge`, `preload` and a `main.js`-style entry. If there is no Electron, this task is **add Tauri**, not **replace Electron**: skip every "port Electron feature X" step and just record that none existed. If Electron does exist, inventory every capability it uses (windows, tray, IPC, notifications, shortcuts, updates, menus, paths, child processes) and port each one before removing anything.

The code is the source of truth. `Backend-Spec.md` is historical and partly stale. `frontend/app.js`, `frontend/styles.css` and the prototype ZIP in `frontend/` are not part of the app: never ship them, never delete them without asking.

| Layer | Today | Consequence |
|---|---|---|
| Frontend | React + TypeScript + Vite, Tailwind, GSAP; Vite proxies API calls to the backend; `services/apiClient.ts` exists | Relative `/api/...` calls won't work inside Tauri → runtime-configured base URL |
| Backend | FastAPI + Uvicorn (`server.py`), SQLite (`db.py`), RAG (`rag.py`), MCP server + client (`mcp_server.py`, `mcp_client.py`) | Compile with Nuitka; needs a programmatic launcher; MCP is probably a stdio **subprocess**, which breaks when compiled unless handled |
| Local AI | Ollama on `127.0.0.1:11434` (`qwen2.5:3b` chat, `nomic-embed-text` embeddings); `setup.ps1` pulls the models | External app, not bundled → detection + first-run flow (§1.3) |
| Voice | Whisper Tiny (STT, Transformers.js) and Kokoro (TTS) run **in the browser/WebView**, not in Python | CSP, WASM/WebGPU, microphone permission, model download and caching inside WebView2 |
| Data | `data/` at the repo root: `journal.db`, `audio/`, `media/`, `logs/` — **real, private journal data** | Production data must live in the OS app-data dir; dev default stays `data/` |
| Scripts | `setup.ps1`, `run.ps1` | Must keep working at every commit |

### 1.2 Requirements carried over from the original spec (all still binding)

- Keep the Python backend. No Rust rewrite. Preserve routes, request/response shapes and DB behaviour; backend changes are additive (env-based config, `/health`, a launcher file, new status routes).
- Tauri **v2** is the shell; React runs unchanged in its WebView; the plain-browser workflow (`run.ps1`) keeps working.
- Production backend = Nuitka-compiled executable bundled as a Tauri sidecar named `nomi-backend-<host-triple>.exe`; the triple comes from `rustc -vV`, never hard-coded.
- Rust owns the lifecycle: spawn → health-gated ready → UI; graceful stop; no orphans; never kill by process name.
- Loopback only (`127.0.0.1`), dynamic port, exactly one frontend module that knows the backend URL.
- User data lives outside the install directory and survives updates; AI/voice models are separate assets, not baked into the binary.
- Production frontend is the minified build with no source maps. No secrets, no telemetry, no journal text sent anywhere new.
- Minimal Tauri capabilities. Honest security claims: compiled code is harder to read, not unreadable.
- If requirements conflict: correctness > preserving features > security/privacy > reliable packaging > maintainability > performance.

### 1.3 Where "nothing to install" collides with the current design (decided)

**Ollama stays external.** Production Nomi must start and journal normally even if Ollama is absent; AI features then show a clear "AI engine not available" state. Detect it (`GET /api/tags` on the configured Ollama host), guide the user to install it (open the official download page in the system browser), then offer a one-click download of the two required models with progress (Ollama's streaming pull API). Read model names from `config.py`; don't hard-code them again. Do not bundle, start, stop or reconfigure the user's Ollama, and never run `ollama rm` or touch the user's installed models. Bundling Ollama is a possible future option: record it in `DECISIONS.md`, don't build it.

**Voice models.** Find out exactly where the Whisper/Kokoro weights and the ONNX/WASM runtime files are fetched from (Hugging Face? jsDelivr? local?). Keep the current behaviour, allow exactly those hosts in the CSP, and say in the final report that first-run voice setup needs internet if that is the case. Offer — don't implement unprompted — bundling the weights as app resources.

---

## 2. Non-negotiable rules

**Journal data and privacy**
1. `data/` is the user's real private journal. Never delete, move, overwrite or reformat anything in it. Never read entry contents: no querying `journal.db` for rows, no opening `data/media`, `data/audio` or `data/logs` (logs may contain entry text). Schema, `PRAGMA user_version`, file names and sizes are fine. Your context may be sent to a cloud model; the journal must never be.
2. Test only against a throwaway data dir with synthetic entries (`$env:NOMI_DATA_DIR = "$env:TEMP\nomi-test-<n>"`), never against `data/`.
3. Before touching any path logic, copy `data/` to a backup outside the repo (copy, don't inspect) and tell the user where it is.
4. Journal text, search queries, prompts and tokens must never appear in logs, error dialogs, crash output or test fixtures.

**Workspace safety**
5. Run `git status` first and work on branch `feat/tauri-shell`. Don't discard uncommitted changes; if there are any, ask (or leave them untouched and note it).
6. Forbidden: `git reset --hard`, `git clean -fd` / `-fdx` (it would delete `data/` and `.venv/`), `git checkout -- .`, `taskkill /IM python.exe` (or any kill-by-name), and recursive deletes outside this allow-list: `build/`, `dist/`, `frontend/dist/`, `src-tauri/target/`, `src-tauri/binaries/`, `.venv-build/`, `*.build`, `*.dist`, `*.onefile-build`.
7. Never commit `data/`, `.venv*/`, `target/`, compiled binaries, `.env*`, or any key/certificate.
8. `setup.ps1` and `run.ps1` must keep working at every commit — extend them or add new scripts, don't break them.

**Scope discipline**
9. Smallest diff that works. Don't rename routes, change response schemas, restructure modules (the backend is a flat set of modules — keep it), "clean up" unrelated code, or upgrade dependencies without a concrete need recorded in `DECISIONS.md`.
10. Ask before deleting or rewriting any file you didn't create.

**Honesty and verification**
11. Never call something done or passing unless you ran it. Report PASS / FAIL / NOT RUN (with the reason). If you can't do something (no toolchain, no clean VM, needs admin), say so and write exact steps for the user in `docs/migration/MANUAL-STEPS.md`.
12. Check tool options against what is installed (`nuitka --help`, `npx tauri --help`) and against the current official **Tauri v2** and Nuitka docs. Your recollection of flags and plugin APIs may be out of date; the examples in this prompt are starting points, not gospel.
13. Don't silently install system-wide toolchains (Rust, Visual Studio Build Tools). Check, list everything that's missing in one message at CP1 with exact install commands, and proceed after the user approves or installs them.

---

## 3. Architecture decisions (taken; revisit only on evidence)

| # | Decision | Why |
|---|---|---|
| D1 | Tauri v2. Rust does lifecycle, native glue and nothing else. | Spec §16 |
| D2 | The backend is launched through a new thin `backend/entry.py` that calls `uvicorn.run(app, …)` with the app **object** (no `"server:app"` string, no `--reload`). `server.py` stays importable as `server:app` for `run.ps1` and the tests. | Compiled builds can't rely on string imports or reloaders; dev workflow stays intact |
| D3 | **Dev:** Rust spawns `.venv\Scripts\python.exe backend\entry.py` through the same lifecycle code as production. `NOMI_EXTERNAL_BACKEND=http://127.0.0.1:8000` makes Rust attach to a hot-reloading backend you started by hand instead. | Dev exercises the real lifecycle; fast iteration stays possible |
| D4 | **Prod:** Nuitka `--onefile` with a persistent cache dir, bundled via `bundle.externalBin`. Switch to `--standalone` shipped via `bundle.resources` and spawned by Rust from the resource dir if **any** of these happens: cold start > 10 s, warm start > 3 s, an orphaned process after killing Nomi that the Job Object can't fix, or Defender flags/quarantines the exe. Record the measurements. | Single file matches the spec; standalone is the proven fallback |
| D5 | Rust picks a free loopback port and passes it in; on bind failure it retries with a new port (max 3). | No hard-coded port |
| D6 | Readiness: Rust polls `/health` and requires `instance` to equal the nonce it passed in, so it never trusts a stranger who grabbed the port. | Spec §8 |
| D7 | Shutdown: `SHUTDOWN` line on the child's stdin → graceful exit → 5 s wait → kill. Backups: a stdin-EOF watchdog inside the backend, and on Windows a Job Object (`KILL_ON_JOB_CLOSE`) containing **only the sidecar**, not Nomi itself (an updater/installer launched by Nomi must survive Nomi's exit). | No orphans, even if Nomi is killed |
| D8 | Per-launch random bearer token required on every route except `/health`, plus strict CORS and a Host-header allow-list. Implemented in Phase 7, after feature parity. | Any local process or webpage can otherwise reach `127.0.0.1` |
| D9 | Production data dir = Tauri `app_local_data_dir()`, passed as `NOMI_DATA_DIR`. Dev default stays `<repo>/data`. Nothing is auto-moved. | Spec §12 |
| D10 | MCP never uses `sys.executable mcp_server.py` in production: run it **in-process** (preferred, e.g. the MCP SDK's in-memory transport) or **self-spawn** the same binary with `--mcp-server`. Decide in Phase 1 after reading `mcp_client.py`. | A compiled binary has no script to launch |
| D11 | Installer: NSIS, per-user (`currentUser`) → `Nomi-Setup.exe`; uninstall keeps user data by default. | No admin prompt; journals never in `Program Files` |
| D12 | No auto-updater and no signing material in the repo. | Keys must never ship; signing is a release-time concern |

### Backend launch contract (single source of truth — Rust and Python must both match it)

| Item | Value |
|---|---|
| Args | `--host 127.0.0.1` and `--port <int>` (`--mcp-server` only if D10 = self-spawn) |
| Env | `NOMI_DATA_DIR`, `NOMI_INSTANCE_ID` (random nonce), `NOMI_APP_VERSION`, `NOMI_API_TOKEN` (from Phase 7), `NOMI_DEV=1` (dev only: adds dev CORS origins) |
| stdin | piped; the line `SHUTDOWN` or EOF → graceful exit |
| stdout / stderr | captured by Rust into a log file; never shown in the UI |
| `GET /health` | `{"status":"ok","service":"nomi-backend","version":"…","instance":"<nonce>"}` — no auth, no data |
| Exit code | 0 = clean; anything else while Nomi is running = crash |

---

## 4. Phases

### Phase 0 — Recon, backup, baseline (no code changes)

1. `git status`; create `feat/tauri-shell`; back up `data/` (rule 3).
2. Write `docs/migration/00-current-architecture.md`, with file/line references, answering:
   - How `setup.ps1` / `run.ps1` start things: ports, env vars, reload flags, log locations.
   - Backend: where the app is created, middleware/CORS settings, startup/shutdown hooks, any existing health route, route groups (names only).
   - `config.py`: every path and setting (watch for `__file__`, `Path.cwd()`, relative paths), Ollama host and model names, env vars read.
   - `db.py`: DB path, journal mode, how the schema is created or migrated (`user_version`?).
   - MCP: transport; how the server process is launched (`sys.executable`? script path?); which env vars it receives.
   - Every other subprocess / thread / `multiprocessing` use; every non-`.py` file read at runtime (SQL, prompts, JSON).
   - `requirements.txt` (heavy or native packages) and the Python version of `.venv`.
   - Frontend: every way the backend is reached (`fetch(`, `EventSource`, `WebSocket`, `localhost`, `127.0.0.1`, `:8000`, `/api`), the Vite proxy, router type, `<img>` / `<audio>` URLs for media, drag-and-drop uploads, downloads/exports, clipboard, notifications, `window.open`, and where *settings* live (DB vs localStorage/IndexedDB).
   - Voice: where Whisper/Kokoro/ONNX-WASM files are fetched from; any COOP/COEP headers set in Vite; how mic permission is requested.
   - A table of **every outbound network destination** of the frontend and backend.
   - The Electron search result (expected: none).
3. Baseline: run `backend/tests` and `npm run build` in `frontend/`; record results. Don't fix unrelated failures.
4. Write `scripts/doctor.ps1` (read-only): checks `rustc` / `cargo`, MSVC Build Tools with the C++ workload (via `vswhere`), the WebView2 runtime, Node/npm, the `.venv` Python version, whether Nuitka supports it, and Ollama reachability. For anything missing, give exact install commands (for example `winget install Rustlang.Rustup`, and VS 2022 Build Tools with the "Desktop development with C++" workload).

**Exit gate / CP1:** report written; baseline recorded; summary to the user covering the confirmed architecture, anything that contradicts this prompt, missing toolchain pieces, and the questions in §7.

### Phase 1 — Backend: launchable and compile-safe (no behaviour change)

- `config.py`: add `NOMI_DATA_DIR`, `NOMI_HOST` (default `127.0.0.1`) and `NOMI_PORT`; defaults = today's behaviour. Derive the DB, audio, media and log paths from the data dir. Replace every `__file__` / cwd-relative path assumption — they break once compiled.
- `/health` per the launch contract (extend an existing route rather than breaking it).
- New `backend/entry.py`, placed beside `server.py` so top-level imports keep resolving both from source and when compiled: parse args/env; refuse a non-loopback host unless `NOMI_ALLOW_NON_LOOPBACK=1`; call `multiprocessing.freeze_support()`; set up rotating file logging under `<data>/logs/` with **Uvicorn access logging off** (URLs carry search queries); start the stdin watchdog (EOF or `SHUTDOWN` → set `server.should_exit`); run Uvicorn with the app object and a single worker. **Never use `os.kill(pid, 0)` on Windows — it terminates the target process.**
- Middleware: replace any `allow_origins=["*"]` with an allow-list (`http://tauri.localhost`, `https://tauri.localhost`, `tauri://localhost`, plus `http://localhost:5173` and `http://127.0.0.1:5173` only when `NOMI_DEV=1`); add `TrustedHostMiddleware` for `127.0.0.1` and `localhost`.
- MCP: implement D10. If a stdio client is kept anywhere, pass `NOMI_DATA_DIR` explicitly through the server parameters' `env` — the MCP SDK's stdio client may forward only a small whitelist of environment variables (verify in the installed version).
- Lifespan shutdown: close DB connections and HTTP clients cleanly.

**Exit gate:** `backend/tests` green; `run.ps1` still works in a browser; `python backend\entry.py --port 8765` (throwaway `NOMI_DATA_DIR`) serves `/health`; closing its stdin makes it exit within ~3 s; `netstat -ano | findstr :8765` shows only `127.0.0.1`.

### Phase 2 — Frontend: runtime API config + production build (no behaviour change in the browser)

- Make `services/apiClient.ts` the only module that knows the backend location (and later the token). It resolves `{ baseUrl, token? }` at runtime: inside Tauri via `invoke("get_backend_info")` plus the `backend://ready`, `backend://error` and `backend://crashed` events; in a plain browser from `import.meta.env.VITE_API_BASE_URL ?? ""` so the Vite proxy keeps working. Route every other direct `fetch` / `EventSource` / URL builder found in Phase 0 — including media and audio URLs — through it.
- Add a `BackendGate` at the app root: "Starting Nomi…" → app; on failure a readable error with Retry and "Open logs folder". In browser mode it passes straight through.
- `vite.config.ts`: `build.sourcemap = false` (explicit), `server.strictPort = true` on a fixed port, `clearScreen = false`; keep the proxy for browser mode. Router: if `BrowserRouter` is used, test refresh/deep links in Tauri and switch to `HashRouter` if they 404.
- Confirm `frontend/dist` has no `.map`, no `.env`, nothing from the stray root files, and no key-looking strings.

**Exit gate:** `npm run build` passes; the `run.ps1` browser workflow is unchanged; a grep finds no hard-coded backend URLs outside `apiClient.ts`.

### Phase 3 — Tauri v2 shell

- Add a root `package.json` (Tauri CLI as a devDependency; scripts `tauri`, `tauri:dev`, `tauri:build`) and `@tauri-apps/api` to the frontend; scaffold `src-tauri/` (`Cargo.toml`, `build.rs`, `src/main.rs` + `src/lib.rs`, `tauri.conf.json`, `capabilities/default.json`, icons).
- `tauri.conf.json`: productName `Nomi`; `identifier` per §7 (must be unique, must not end in `.app`, and **must never change after release** — it determines the app-data folder, which holds the database *and* the WebView's localStorage/IndexedDB); `build.devUrl` = the Vite URL; `build.frontendDist` = `../frontend/dist`; before-dev/before-build commands run inside `frontend/`; window ≈ 1280×800, min ≈ 900×600, background colour = the theme's base colour (no white flash). Set `dragDropEnabled: false` if Phase 0 found HTML5 drag-and-drop uploads (Tauri's default swallows them on Windows). Don't change `useHttpsScheme` later either: it changes the web origin and wipes localStorage/IndexedDB (settings, cached voice models).
- CSP (`app.security.csp`, plus a looser `devCsp` for the Vite HMR socket). Start from this and add only origins that Phase 0 proved necessary (for example Hugging Face hosts for the voice models), each justified in `DECISIONS.md`:

  ```
  default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; worker-src 'self' blob:;
  connect-src 'self' ipc: http://ipc.localhost http://127.0.0.1:*;
  img-src 'self' data: blob: http://127.0.0.1:*; media-src 'self' blob: http://127.0.0.1:*;
  style-src 'self' 'unsafe-inline'; font-src 'self' data:
  ```

  If inline styles break because Tauri's nonce injection overrides `'unsafe-inline'`, add `style-src-attr 'unsafe-inline'` rather than loosening `script-src`.
- If Phase 0 found COOP/COEP headers in Vite (needed for multi-threaded ONNX/WASM), replicate them through Tauri's security headers config (verify the current field name) and confirm `crossOriginIsolated` is true in the WebView.
- Capabilities: only what the main window needs. **No `shell:*` permissions for the webview** — Rust spawns the sidecar itself. Expose a handful of narrow app commands (`get_backend_info`, `restart_backend`, `open_logs_folder`). External links go through the opener plugin, scoped to explicit https origins (for example the Ollama download page).
- `tauri-plugin-single-instance`: two Nomi instances would run two backends against one SQLite file. A second launch focuses the first window.
- Icons: generate with `tauri icon` from a 1024×1024 source; if only `frontend/public/Nomi.ico` exists, use its largest frame, flag it, and don't block.
- Verify how `tauri dev` behaves when the `externalBin` file doesn't exist yet. If it errors, use a dev config overlay without `externalBin` rather than committing a fake binary.
- Stub `get_backend_info` to return `NOMI_EXTERNAL_BACKEND` so the shell can be tested before Phase 4.

**Exit gate:** `npm run tauri:dev` shows the real Nomi UI against a hand-started backend (`NOMI_EXTERNAL_BACKEND`); no CSP violations in the console during normal use, including loading the Whisper and Kokoro features.

### Phase 4 — Rust backend manager (one code path for dev and prod)

- A `backend` module with explicit states (Stopped / Starting / Ready / Failed / Crashed / Stopping) in managed Tauri state, emitting `backend://starting`, `backend://ready`, `backend://error` and `backend://crashed`.
- Spawn per the launch contract. Dev (debug build): `.venv\Scripts\python.exe backend\entry.py`, located via `NOMI_PYTHON` or `<CARGO_MANIFEST_DIR>/../.venv`, with a clear error if missing; never `--reload`. Prod: the sidecar (`app.shell().sidecar("nomi-backend")`, or a plain `Command` from the resource dir if D4 switches). Make sure no console window flashes.
- Port: bind `127.0.0.1:0`, read the port, release it, pass it on; retry on bind failure (D5).
- Readiness: poll `/health` every ~200 ms for up to 60 s (configurable); validate the JSON and `instance`; stop early if the child exited. On failure emit `backend://error` with the reason and the log path, and keep the window open on the error screen.
- stdout/stderr go to `<app log dir>/backend-stdio.log` (size-bounded, never in the UI).
- Crash handling: an unexpected exit while not stopping → `backend://crashed`, automatic restart (prefer the same port; max 3 restarts per 2 minutes with backoff), then a persistent Failed state with a Restart button.
- Shutdown (window close, `RunEvent::ExitRequested`, `RunEvent::Exit`): mark Stopping, write `SHUTDOWN`, wait ≤ 5 s, then kill **the tracked child only**; Job Object per D7; idempotent.
- `get_backend_info` returns `{ baseUrl, status }`; `apiClient` refreshes on `backend://ready`.
- `cargo clippy` clean; unit-test the pure logic (port picking, health parsing, restart policy).

**Exit gate / CP2** (throwaway data dir): `npm run tauri:dev` loads the UI and a journal entry can be created and read through the Rust-spawned backend. Kill the backend PID → crash state → automatic recovery. Close the window → no `entry.py` process remains (`Get-CimInstance Win32_Process | Where-Object CommandLine -match 'entry.py'`). End Nomi from Task Manager → the backend is gone within ~5 s. Occupy the first chosen port → still starts.

### Phase 5 — Nuitka build of the backend

- Build from a **clean** venv (`.venv-build/`, gitignored) containing only `backend/requirements.txt` (pinned into `requirements.lock.txt`) plus `backend/requirements-build.txt` (Nuitka, zstandard, ordered-set). Never compile from the dev venv — it would drag test and dev packages into the binary. Confirm Nuitka supports the venv's Python; if not, pin a supported version (3.11/3.12) for the build venv and say so.
- `scripts/build-backend.ps1`: compile `backend/entry.py` → `build/backend/nomi-backend.exe`, then copy it to `src-tauri/binaries/nomi-backend-<triple>.exe` (triple parsed from `rustc -vV`), printing size and SHA-256. Candidate flags (verify against `--help`): `--onefile` with a persistent `{CACHE_DIR}`-based `--onefile-tempdir-spec`, `--msvc=latest` (Rust needs the MSVC tools anyway), `--assume-yes-for-downloads`, `--output-dir`, `--output-filename`, `--remove-output`, `--include-package` / `--include-package-data` for hidden imports, `--nofollow-import-to` for test/GUI packages, `--company-name` / `--product-name` / `--file-version` / `--product-version`, `--windows-icon-from-ico`. Don't use `--windows-console-mode=disable` unless piped stdin/stdout are proven to work; Tauri's shell plugin normally hides the console window (verify).
- Expect hidden imports (Uvicorn internals, anyio backends, pydantic, the httpx stack, `mcp`) and data files: run the exe, read the traceback, add the include, rebuild. Use a faster profile (no LTO) while iterating and a release profile for the final build.
- `backend/tests/smoke_packaged.py` (httpx): starts a given exe (or `python backend\entry.py`) with a throwaway data dir and free port; waits for `/health`; creates, reads, lists and searches entries; exercises one MCP-backed path; if Ollama is reachable, asks one AI question; closes stdin; asserts the process and its children exit.
- Measure cold start (first run, empty cache) and warm start; apply D4's thresholds; test the orphan scenario (kill the parent, inspect the process tree).
- Verify that nothing from `backend/` ships as readable `.py` (search the build output *and* the onefile cache dir). Note what stays visible in the binary (string constants including LLM prompts, SQL, route names).

**Exit gate:** the smoke test passes against the compiled exe from a shell without the venv activated and with a minimal `PATH` (`C:\Windows;C:\Windows\System32`).

### Phase 6 — Production wiring and installer

- `tauri.conf.json`: `bundle.externalBin: ["binaries/nomi-backend"]`, `bundle.targets: ["nsis"]`, per-user install. Choose the WebView2 install mode per §7.
- Rust (prod): resolve `app_local_data_dir()`, create it, verify it's writable, pass it as `NOMI_DATA_DIR`; put logs in `app_log_dir()`. The backend creates the DB on first run.
- `scripts/import-dev-data.ps1`: optional, manual, **copies** `<repo>\data\*` into the app data dir while Nomi is closed; refuses to overwrite an existing DB without `-Force`; never runs automatically. (Settings kept in browser storage during dev won't carry over because the origin differs — say so if Phase 0 found any.)
- `scripts/build-all.ps1`: frontend production build → backend compile → copy sidecar → `tauri build` → print the installer path and hash. Also `scripts/dev.ps1` (with an `-ExternalBackend` switch), `scripts/clean.ps1` (allow-listed paths only, rule 6) and `scripts/verify-package.ps1` (no `.py` / `.map` in the package, runs the smoke test). The flow must work from a fresh checkout with lockfiles committed (`package-lock.json`, `Cargo.lock`, `requirements.lock.txt`).
- Confirm the uninstaller leaves the data dir alone by default.

**Exit gate:** `scripts/build-all.ps1` produces `Nomi-Setup.exe`; installing it on this machine launches Nomi; the backend runs as the sidecar; new data lands in the app data dir; closing Nomi leaves no `nomi-backend` process.

### Phase 7 — Hardening

- Token (D8): Rust generates 32 random bytes from the OS RNG per app run and passes them via `NOMI_API_TOKEN` (env, never argv); `get_backend_info` exposes them to the frontend; `apiClient` sends `Authorization: Bearer …`; the backend compares in constant time (`secrets.compare_digest`) and rejects everything but `/health`; the token is never logged. Media/audio loaded through plain `<img>` / `<audio>` URLs can't send headers — switch those to authenticated fetch → blob URLs (or short-lived signed URLs).
- Verify: no token → 401; wrong `Origin` → CORS-blocked; spoofed `Host` → 400; the listener is loopback-only (which also avoids the Windows Firewall prompt).
- Audit and list the final capabilities, CSP and plugins (no unused plugins, no `shell` for the webview, no broad `fs` scope); re-run the outbound-network table from Phase 0.
- Secrets scan of `frontend/dist`, `backend/` and `src-tauri/`; confirm no `.env` is bundled.
- `docs/migration/SECURITY-NOTES.md`: what Nuitka does and doesn't give you; what stays inspectable (JS bundle, string constants and prompts, SQL schema, route names, model weights); advice to keep anything truly proprietary out of the client.

**Exit gate:** all four verifications above pass and are recorded.

### Phase 8 — First-run experience for Ollama and models (small, additive)

- Backend (new routes only, token-protected): AI status (Ollama reachable? chat/embedding model installed? names from `config.py`) and a streaming model-pull endpoint that proxies Ollama's pull API with progress.
- Frontend: a minimal banner/card with the states Ollama missing (Install Ollama → opens the official page; Check again), models missing (Download with progress), and ready. Journaling works in every state; AI features show a clear disabled state.
- Simulate states without touching the user's real setup: point `OLLAMA_HOST` at a dead port for "not installed"; override the model names with nonexistent ones for "missing model". Never remove real models.

**Exit gate:** each state renders correctly; the pull stream is verified against an already-installed model (completes instantly) and the progress UI against a mocked stream.

### Phase 9 — Full verification, docs, final report

- Run the whole matrix in §5. For the clean-machine test use Windows Sandbox, a VM or another PC with no Python/Node/Rust/VS; if none is available, mark it NOT RUN and give the user a step-by-step script in `MANUAL-STEPS.md`.
- Update `README.md` (append a "Desktop app (Tauri)" section; leave the existing instructions), add `docs/migration/BUILD.md` and `TESTING.md`, finalise `.gitignore`.
- Deliver the final report (§6) — **CP3**.

---

## 5. Verification matrix (record PASS / FAIL / NOT RUN for each)

| # | Scenario | What to check |
|---|---|---|
| 1 | Cold start (packaged) | Window → "Starting Nomi…" → UI; no console flashes; time recorded |
| 2 | Clean shutdown | Close window → no `nomi-backend` process within 5 s; DB file copyable (not locked) |
| 3 | Nomi killed | End task on Nomi → backend gone within ~5 s |
| 4 | Backend crash | Kill backend PID → crash state → automatic recovery → journal works |
| 5 | Startup failure | Rename/corrupt the sidecar or make the data dir unwritable → readable error with log path, app still closable, no blank screen |
| 6 | Occupied port | Occupy the first chosen port (and 8000 in dev) → app still starts |
| 7 | Journal CRUD + persistence | Create / edit / delete, restart Nomi, data still there |
| 8 | Search and retrieval | Keyword and semantic search return results |
| 9 | AI chat / RAG | Ollama running → streaming answer is not buffered by the WebView |
| 10 | MCP | A question that triggers an MCP tool works in the **packaged** build |
| 11 | STT | Mic permission prompt → transcription works; model cache survives restart |
| 12 | TTS | Kokoro speaks; works after restart |
| 13 | Settings | Persist across restarts |
| 14 | Media | File picker and drag-and-drop upload; images/audio display and play |
| 15 | Export / download features | Work, if the app has them |
| 16 | Ollama absent / model missing | Journaling works; AI shows the clear states from Phase 8 |
| 17 | Data lifecycle | First run creates data; an existing DB opens; install-over upgrade (same identifier) keeps data and replaces the backend; uninstall keeps data; reinstall sees it; reboot → still intact |
| 18 | Unusual paths | Data/install dirs containing spaces or non-ASCII characters |
| 19 | Clean machine | No Python/Node/Rust/VS: install, launch, rows 7–14 |
| 20 | Security | Loopback-only listener; 401 without token; CORS/Host checks; no `.py` / `.map` in the package; no secrets |
| 21 | Dev workflows | `run.ps1` still works; `backend/tests` green; `npm run tauri:dev` works |

---

## 6. Deliverables and final report

**Deliverables:** `backend/entry.py`, `backend/requirements-build.txt`, `requirements.lock.txt`, `backend/tests/smoke_packaged.py`; the `apiClient.ts` change and `BackendGate`; `src-tauri/**`; root `package.json`; `scripts/{doctor,dev,build-backend,build-all,clean,verify-package,import-dev-data}.ps1`; `docs/migration/{00-current-architecture,PROGRESS,DECISIONS,BUILD,TESTING,SECURITY-NOTES,MANUAL-STEPS}.md`; the README section; `.gitignore`.

**Final report (concise):**
1. What changed, grouped by area, with the commit list.
2. How to run: dev, external-backend dev, production build, clean.
3. The §5 matrix with real results (no optimism).
4. Measurements: cold/warm start, installer size, the D4 outcome.
5. Known limitations and risks (for example voice models needing internet on first use, an unsigned installer triggering SmartScreen, Ollama being a separate install).
6. Anything left untouched on purpose (stray `frontend/` files, `Backend-Spec.md`) and cleanup suggestions.
7. Decisions that still need the user.

---

## 7. Decisions to confirm with the user at CP1 (defaults apply if you can't ask)

| Decision | Default |
|---|---|
| Bundle identifier (reverse-domain, permanent) | Ask. Use the placeholder `com.nomi.desktop` until confirmed, and flag it loudly |
| Ollama strategy | Detect + guide + one-click model download (no bundling) |
| Voice models | Keep the current remote download + local cache |
| WebView2 install mode | `downloadBootstrapper` (needs internet on PCs without WebView2); consider `embedBootstrapper` or an offline installer |
| Install scope | NSIS per-user, no admin |
| Importing existing dev data | Manual script, never automatic |
| Starting version | `0.1.0` |
| Code signing | Out of scope; note that unsigned installers trigger SmartScreen warnings |
| Target platform | Windows only for now; keep paths and `cfg(windows)` code tidy so macOS/Linux can follow |
