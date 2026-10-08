# Nomi current architecture (Phase 0)

Recon date: 2026-10-05. Scope: source and configuration only. No files under `data/` were opened. The directory was empty when checked; a copy was made to `C:\Users\Govind\AppData\Local\Temp\Nomi-data-backup-20261005-044613` before reviewing paths.

User's CP1 direction: permanent bundle identifier `com.nomi.desktop`; include Linux alongside Windows. Linux packaging is planned as AppImage + `.deb`, using Ubuntu 22.04/Debian 12 as a conservative starting baseline for Tauri's WebKitGTK 4.1 dependency. Nuitka installation is approved only inside project-local `.venv-build`.

## Current startup flow

- `setup.ps1:12-26` locates Python 3.11+, then `:40-49` creates/reuses `.venv` and installs `backend/requirements.txt`. `:51-61` requires Node 22.12+ and runs `npm ci` in `frontend/`; `:64` creates `data/audio`, `data/media`, and `data/logs`; `:66-78` checks local Ollama and, when reachable, pulls `qwen2.5:3b` and `nomic-embed-text`. Models are currently hard-coded in this setup script, even though `backend/config.py` allows model environment overrides.
- `run.ps1:7-17` uses `.venv/Scripts/python.exe`, backend URL `127.0.0.1:8000`, frontend URL `127.0.0.1:5173`, and logs under `data/logs/`. `:34` starts `python -m uvicorn backend.server:app --host 127.0.0.1 --port 8000 --log-level info`; there is no reload flag. `:48` starts Vite with `--host 127.0.0.1 --strictPort` (port is 5173 from Vite's default). `:41-46` waits on `/openapi.json`, not the AI-dependent health endpoint. It opens the browser at `:62` and attempts process-tree cleanup at `:66-71`.
- `run.ps1` sets no app-specific environment variables. Its child processes inherit the current shell environment. The backend can read the variables listed below. `setup.ps1` uses the defaults for its two pulled model names rather than resolving Python config.

## Backend

- `backend/server.py:17` creates `FastAPI(title="Private Journal Backend")`. `:18-24` adds `CORSMiddleware` with `allow_origins=["*"]`, all methods and all headers. There is no `TrustedHostMiddleware` or auth middleware.
- Startup event `backend/server.py:94-96` calls `db.init_db()`. No explicit FastAPI shutdown handler is registered.
- `GET /api/health` at `backend/server.py:110-125` checks Ollama reachability and both models. Therefore it is an AI readiness check, not a process-only health check; `ok` is false when Ollama is absent.
- Route groups (`backend/server.py`): diary CRUD and related/follow-up (`:128-263`); insights and report (`:265-282`); timeline (`:284-293`); AI feedback/search/graph (`:295-314`); audio and media upload/serve (`:316-391`); Ask AI conversation history (`:465-493`); Talk streaming (`:495-530`); chat/RAG (`:537+`).

## Paths, data and configuration

- `backend/config.py:4-8`: `BASE_DIR` is based on `Path(__file__).resolve().parent.parent`; `JOURNAL_DATA_DIR` overrides `<repo>/data`; SQLite is `<DATA_DIR>/journal.db`; audio/media are `<DATA_DIR>/audio` and `<DATA_DIR>/media`. There is no separate log-directory setting.
- `backend/config.py:10-18` reads `OLLAMA_HOST` (default `http://127.0.0.1:11434`), `CHAT_MODEL` (`qwen2.5:3b`), `EMBED_MODEL` (`nomic-embed-text`), `LINK_SIM_THRESHOLD` (`0.35`), `REL_SIM_THRESHOLD` (`0.20`), `FOLLOWUP_MIN_SIM` (`0.45`), `RAG_TOP_K` (`6`), and `GRAPH_MAX_ENTRIES` (`300`). These numeric environment values are parsed during import. The `data/` override used by existing scripts is named `JOURNAL_DATA_DIR`, not the proposed future `NOMI_DATA_DIR`.
- `backend/db.py:12-97` defines the SQL schema in a Python string; `:99-104` opens SQLite and enables foreign keys. No explicit `PRAGMA journal_mode` or `PRAGMA user_version` migration is used. `:207-219` executes `CREATE TABLE IF NOT EXISTS` and adds missing `energy` and `mood_score` columns after checking `PRAGMA table_info`.
- `backend/db.py:202-204,207-222` seeds demo entries only when `DATA_DIR` resolves to the repository's default `data/` path and the entries table is empty. Tests in `backend/tests/test_diary_api.py:21-25` use a temporary data directory.
- Python DB schema and prompts are embedded in `.py`; there are no separately loaded SQL/prompt/JSON files in backend source. `server.py` reads request upload streams and writes uploaded audio/media files under configured directories.

## Processes and MCP

- The backend's only explicit subprocess is the MCP server: `backend/mcp_client.py:37-42` launches `sys.executable -m backend.mcp_server`, sets cwd to `config.BASE_DIR`, and passes `dict(os.environ)` into `StdioServerParameters`. It is lazy and persistent for the client lifetime (`:31-62`). Transport is stdio (`backend/mcp_server.py:212`). MCP opens SQLite read-only (`mcp_server.py:22-25`).
- No explicit `subprocess`, `threading.Thread`, or `multiprocessing` use was found in backend Python source. Asyncio locks coordinate the MCP session (`mcp_client.py:14-18`). Browser code creates temporary AudioWorklet modules and browser workers/ONNX runtime as needed.
- Backend `requirements.txt`: FastAPI, Uvicorn standard extras, python-multipart, httpx, NumPy, and MCP. NumPy is the primary native/binary Python dependency; Uvicorn standard extras may include native HTTP/WSGI acceleration packages depending on platform.

## Frontend capabilities and network

- React app entry is `frontend/src/main.tsx:1-5`, rendering `App` directly. There is no React Router dependency; navigation is in-memory React state (`frontend/src/App.tsx:25+`). Refresh returns to the default page.
- Vite's `/api` proxy targets `http://127.0.0.1:8000` (`frontend/vite.config.ts:7-14`). `services/apiClient.ts:1-2,7+` is the normal API URL boundary, but `services/talkService.ts:17` independently calls relative `/api/talk/stream` and parses the POST response as SSE.
- Diary image/video display uses backend media URLs (`features/diary/DiaryPage.tsx:542,566`); uploads use a file picker (`:554`) through `memoryService.uploadDiaryMedia` (`services/memoryService.ts:116-118`). No HTML5 drag/drop handler was found. Backend audio upload/serve routes exist, but the current frontend does not call `/api/audio/upload`; `memoryService.saveRecording` transcribes locally then saves the transcript as text with source `audio` (`services/memoryService.ts:138-151`). Talk session playback creates a local object URL (`features/talk/TalkToMePage.tsx:278`).
- The frontend builds JSON and PDF downloads using Blob/object URLs (`features/support/SupportPage.tsx:94-105`; `services/pdfExportService.ts:186-200`) and can use `window.print()` (`features/support/SupportPage.tsx:247`). No `window.open`, clipboard, browser notification, WebSocket, `EventSource`, or indexedDB usage was found. Talk streaming uses `fetch` and a `ReadableStream`, not EventSource.
- Theme, ask history, and user preferences use `window.localStorage` (`App.tsx:34-40,171,185-188`; `services/userPreferences.ts:24`). Diary entries and Ask conversations are stored by the backend in SQLite. There is no `localStorage`-to-database migration in the current app.
- Microphone permission is requested through `navigator.mediaDevices.getUserMedia` in Diary (`features/diary/DiaryPage.tsx:212-221`) and Talk (`features/talk/TalkToMePage.tsx:573+`). Whisper is `Xenova/whisper-tiny.en` through `@huggingface/transformers` (`services/localTranscriptionService.ts:3,22-42`), using WebGPU where available and WASM CPU fallback. Kokoro is `onnx-community/Kokoro-82M-v1.0-ONNX` through `kokoro-js` (`services/kokoroTtsService.ts:1,10-26`). These model IDs use Hugging Face's Hub; first-use model downloads require internet and can follow Hugging Face CDN/object-storage redirects. Vite has no explicit COOP/COEP headers.
- Direct runtime destinations found in source: frontend → same-origin Nomi `/api/*` (with Vite proxy to loopback in browser dev); frontend → Hugging Face Hub/model delivery for Whisper and Kokoro assets. Backend → local Ollama at `OLLAMA_HOST` for tags/chat/embeddings. Setup → local Ollama API for readiness and Ollama CLI `pull` for model downloads (Ollama's registry/network traffic is handled by Ollama, not by Nomi Python). No additional telemetry, analytics, or remote API provider is configured. Hugging Face documents Hub downloads redirecting to storage/CDN hosts; the current allowlist documentation includes `huggingface.co`, `cas-server.xethub.hf.co`, `cas-server.xethub-eu.hf.co`, `transfer.xethub.hf.co`, `transfer.xethub-eu.hf.co`, `us.aws.cdn.hf.co`, `us.gcp.cdn.hf.co`, `cdn-lfs-us-1.hf.co`, and `cdn-lfs-eu-1.hf.co`. A real WebView network trace is still needed to establish which regional endpoints this install uses. The bundled ONNX WASM file appears in Vite's build output as a local asset, so it does not require an external CDN at runtime.

## Electron inventory and baseline

- Runtime search for `electron`, `electron-builder`, `ipcRenderer`, `contextBridge`, `preload`, and `main.js` found no Electron app code or package dependency. Matches are in historical `Backend-Spec.md` only. `frontend/app.js`, `frontend/styles.css`, and `frontend/stillroom-prototype.zip` are stray/legacy assets and are not imported by the React entry; preserved.
- Virtualenv metadata and execution confirm Python `3.14.7` (`.venv/pyvenv.cfg`). The test suite ran against its per-test temporary databases: 13 passed, 1 failed (`test_clinician_discussion_report_uses_all_diary_metadata_and_validates_evidence`, at `backend/tests/test_diary_api.py:349`, expected an old phrase in the generated prompt). Baseline **FAIL (13/14)**; this unrelated baseline failure is recorded, not changed.
- The required `npm run build` completed (`tsc -b && vite build`). Baseline **PASS**, with Vite's chunk-size warning for the combined voice/model chunks; build artifacts contain a local ONNX WASM asset.
- Current detected build tools: Rust/Cargo 1.99.0 with target `x86_64-pc-windows-msvc`; Node 24.19.0/npm 11.17.0; Visual Studio Build Tools 18 with VC x64 tools detected; WebView2 runtime present (154.0.4258.53); Ollama responds on its local API. Nuitka is not installed in `.venv`. No system toolchains were installed for this recon.

## Documentation consulted

- [Tauri v2 Windows prerequisites](https://v2.tauri.app/start/prerequisites/) documents MSVC C++ Build Tools and WebView2 requirements.
- [Tauri v2 Linux prerequisites](https://v2.tauri.app/start/prerequisites/) documents the WebKitGTK 4.1 and build dependencies; [Tauri Linux distributions](https://v2.tauri.app/distribute/) lists AppImage and Debian package formats.
- [Nuitka user manual](https://nuitka.net/user-documentation/user-manual.html) lists supported Python versions and compiler requirements; as consulted on 2026-10-05, Python 3.14 is supported.
- [Transformers.js environment](https://huggingface.co/docs/transformers.js/api/env) documents browser remote model loading; [Hugging Face model downloads](https://huggingface.co/docs/hub/models-downloading) documents CDN/storage redirects.

## Desktop migration update (2026-10-08)

This section records changes since the Phase 0 snapshot above; the source files remain authoritative.

- Tauri v2 shell uses permanent identifier `com.nomi.desktop`; Rust owns the managed backend lifecycle and the frontend uses the narrow backend info/restart/log commands. The webview capability grants `core:default` only; the shell plugin is initialized for Rust-side sidecar management, without granting webview shell permission.
- The managed backend binds to loopback on a dynamically selected port. `/health` reports process readiness independent of Ollama. Production uses a Nuitka one-file sidecar next to the Tauri executable. Debug uses the project virtual environment.
- Tauri generates a fresh OS-random API bearer token each launch, passes it to the backend through `NOMI_API_TOKEN`, and the frontend sends it through the centralized API client. `/health` is unauthenticated; other HTTP routes require the token when configured. Browser development remains token-free unless `NOMI_API_TOKEN` is set.
- `backend/config.py` now supports `NOMI_DATA_DIR`, retaining `JOURNAL_DATA_DIR` as a legacy fallback. Debug defaults to repository `data/`; release data belongs in the OS per-user app-data folder. Treat all real journal data as private and use a new synthetic directory for smoke checks.
- `GET /api/ai/status` and `POST /api/ai/models/pull` provide token-protected Ollama/model readiness and NDJSON pull progress. The current UI offers Ollama installation guidance and model downloads; Ollama itself and its models remain external. The configured model tags must match exactly (`qwen2.5:3b`, `nomic-embed-text` normalized to `:latest`).
- Phase 7 release API checks and the Phase 8 unavailable-Ollama stream check have passed in WSL. This is not a full application feature audit. Windows packaging, AppImage/Ubuntu 22.04 baseline, actual successful model pull, complete WebView feature matrix, and clean-machine lifecycle remain unverified. See `PROGRESS.md`, `TESTING.md`, and `MANUAL-STEPS.md`.
