# Nomi

Nomi is a local-first journaling application. The React/Vite frontend talks to a FastAPI backend, which stores journal data in SQLite. AI chat, reflection, and journal insights use a local Ollama service. Voice transcription and speech playback models run in the browser and are downloaded by the browser on first use.

## Requirements

- Windows 10 or 11 with PowerShell.
- Python 3.11 or newer.
- Node.js 22.12 or newer (Node.js 22 LTS includes npm).
- Ollama for AI features. Install it from [ollama.com/download/windows](https://ollama.com/download/windows).
- Enough disk space for Ollama models (`qwen2.5:3b` and `nomic-embed-text`) and first-use browser voice models.

The core app can start without Ollama, but AI-powered features will be unavailable until Ollama is running and both models are installed. SQLite is bundled with Python; no separate database server is needed.

## Setup once

From this folder in PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
./setup.ps1
```

The script creates `.venv`, installs `backend/requirements.txt`, runs `npm ci` in `frontend`, and creates the local `data` folders. If Ollama is installed and running, it also downloads `qwen2.5:3b` and `nomic-embed-text`. To omit the model downloads, use `./setup.ps1 -SkipOllamaModels`; install/start Ollama and rerun setup later to fetch them.

If PowerShell blocks scripts, the process-scoped execution policy command above applies only to the current PowerShell window. Install Ollama separately before setup if you want the script to download its models.

## Run the full application

```powershell
./run.ps1
```

This starts the FastAPI backend at `http://127.0.0.1:8000` and the Vite frontend at `http://127.0.0.1:5173`, then opens the frontend in your browser. Keep the PowerShell window open; press **Ctrl+C** to stop both services. Logs are written under `data/logs/` (`backend.log`, `backend-error.log`, `frontend.log`, and `frontend-error.log`).

Start the Ollama desktop app/service before using AI features. The models can be checked or downloaded manually with:

```powershell
ollama pull qwen2.5:3b
ollama pull nomic-embed-text
```

The app binds its backend to `127.0.0.1` for local use. Journal database and media files are created under `data/` and are not committed to Git. Back up that directory if you need to preserve journal data.

## Troubleshooting

- **Python/Node not found:** install the required tools, reopen PowerShell, then rerun `./setup.ps1`.
- **Port already in use:** close the other process using port 8000 or 5173 and rerun `./run.ps1`.
- **AI reports a missing model:** start Ollama and run the two `ollama pull` commands above.
- **Voice features are slow on first use:** the browser is downloading the local Whisper/Kokoro model files; allow that download to finish.

For frontend-only development, use `cd frontend; npm run dev`. For backend-only development after setup, use `.venv\Scripts\python.exe -m uvicorn backend.server:app --host 127.0.0.1 --port 8000` from the project root.

## Desktop app (Tauri)

The Tauri desktop shell manages its own local backend and stores release data in the operating system's per-user app-data directory. Ollama remains a separate optional install; journaling works without it. Start the desktop developer app with `npm run tauri:dev` after `npm run setup:dev`. Linux developers can use `./scripts/setup-linux.sh` and `./scripts/run-linux.sh`. To build, run `npm run build:backend` before `npm run tauri:build -- --bundles nsis` on Windows or `npm run tauri:build -- --bundles deb` on Linux. See [docs/migration/BUILD.md](docs/migration/BUILD.md) for prerequisites, environment variables, package paths, and platform limits. The browser workflow described above remains supported.
