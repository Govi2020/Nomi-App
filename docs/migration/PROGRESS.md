# Migration progress

## Phase 0 — Recon, backup, baseline (2026-10-05)

- Done: confirmed browser-based React/Vite + FastAPI/SQLite runtime; no Electron app. Backed up the empty `data/` directory outside the repository.
- Decided: retain the prompt's defaults for Tauri v2, external Ollama, remote browser voice models, per-user NSIS, and manual-only data import; permanent identifier awaits user confirmation.
- Surprised: backend MCP starts a separate Python stdio child process; frontend chat streaming bypasses `apiClient`; settings live in WebView localStorage. Baseline backend tests ran in `.venv`: 13 passed, one failed on a clinical-report prompt assertion. Frontend `npm run build` passed with Vite's chunk-size warning. The direct Hugging Face model paths may redirect to storage/CDN hosts; capture actual redirects in WebView before finalizing CSP.
- Gate status: architecture report and read-only doctor added and run. Rust, C++ Build Tools, WebView2, Node/npm, Python 3.14.7, and Ollama are present. Nuitka is missing. Phase 0 awaits user decisions and authorization before any system/toolchain installation; the unrelated failing baseline test is not changed.
