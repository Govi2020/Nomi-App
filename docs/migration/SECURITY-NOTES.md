# Security notes

## Local backend boundary

- The Tauri process creates a fresh 256-bit token from the operating system random source for each launch. Rust passes it to the managed backend through `NOMI_API_TOKEN`; it is not placed in command-line arguments or backend logs.
- The frontend receives the token only through the app's narrow `get_backend_info` Tauri command and sends it as `Authorization: Bearer …` through `apiClient`. `/health` is the only unauthenticated HTTP route. A backend launched independently without `NOMI_API_TOKEN` keeps the existing browser-development workflow.
- The backend still binds to loopback and checks the Host header. CORS allows the Tauri origin and the explicit Vite development origins. CORS is a browser control; the bearer token is what protects requests from other local web pages/processes that can reach loopback.
- Diary attachments are fetched with the bearer header and displayed as in-memory blob URLs. The token is not placed in media URLs. Blob URLs are revoked when the WebView unloads.

## Tauri permissions and content policy

- The main-window capability grants `core:default` only. It has no `shell:*` permission and no broad filesystem permission. Rust owns sidecar process startup; the shell plugin is initialized for the Rust-side resolver.
- The opener plugin is used by a Rust command to reveal the app log directory. Web content cannot request arbitrary shell commands through this capability.
- CSP limits scripts to the app bundle plus WebAssembly evaluation needed by local voice inference. Network connections are limited to the loopback backend, Vite in development, and the configured Hugging Face model hosts. Ollama remains on loopback.

## Limits

- The token helps separate Nomi's managed API from unrelated local requests. It does not protect against malware running as the same user, a compromised Nomi frontend, or a user who can inspect the process environment and app memory.
- Nuitka compiles Python code but does not make the application unreadable. The JavaScript bundle, strings and prompts, SQL/schema details, route names, and model/runtime assets remain inspectable.
- The app makes no new telemetry or journal-text upload. Ollama is an external local service. Voice model files may be downloaded from the allowed model hosts on first use.
- The generated Linux Debian package is unsigned. Its Linux compatibility baseline is not established by a build performed on Ubuntu 26.04; see `PROGRESS.md` and `MANUAL-STEPS.md` for unverified release work.
