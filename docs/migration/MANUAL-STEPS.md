# Manual steps

## Phase 0 backend baseline failure

The suite ran with the project `.venv` and its per-test temporary databases. Thirteen tests passed. One failed because `backend/tests/test_diary_api.py:349` expects the phrase `at least two different entries` in the clinical-report prompt, while the current prompt says `at least two distinct entry citations`. Rerun after any intentional prompt/test update with:

```powershell
.\.venv\Scripts\python.exe -m unittest discover -s backend\tests -v
```

The Phase 0 production frontend build passed using `npm run build`; Vite printed a chunk-size warning for voice/model bundles. Existing tests use temporary data directories. Keep integration tests away from repository `data/`; if a new test starts the backend directly, set `JOURNAL_DATA_DIR` to a throwaway path first.


## Connect WSL Nomi to Windows Ollama

RESOLVED for this Windows host on 2026-10-09: mirrored networking is enabled in `%UserProfile%\.wslconfig`, WSL was restarted, and WSL `curl http://127.0.0.1:11434/api/tags` returned HTTP 200 with both configured models. Nomi was relaunched with `OLLAMA_HOST=http://127.0.0.1:11434`. The steps below are for reapplying or diagnosing this configuration later.

Preferred setup on supported Windows 11 (22H2+): merge the following into `%UserProfile%\.wslconfig` without deleting any existing sections/settings:

```ini
[wsl2]
networkingMode=mirrored
```

Then run `wsl --shutdown` from PowerShell and reopen Ubuntu. From WSL, check `curl http://127.0.0.1:11434/api/tags`. If it returns JSON, launch Nomi with `OLLAMA_HOST=http://127.0.0.1:11434` in its environment (for example, `OLLAMA_HOST=http://127.0.0.1:11434 ./src-tauri/target/release/nomi`). This keeps Ollama bound to its normal local interface. Microsoft documents mirrored localhost access at https://learn.microsoft.com/windows/wsl/networking.

If mirrored mode is unavailable, Windows Ollama must listen on an address reachable from WSL and Windows Firewall should restrict inbound 11434 to the WSL virtual subnet. Avoid exposing the unauthenticated Ollama API to public or untrusted networks. Ollama documents `OLLAMA_HOST` as the bind-address setting at https://github.com/ollama/ollama/blob/main/docs/faq.mdx.

## Windows installer build blocker (2026-10-09; still open)

- The Windows checkout is stale/diverged and has user-owned modified and untracked files; do not run the full build from that checkout or overwrite files to synchronize it.
- The current Windows host blocks `rustc.exe` under Application Control (OS error 4551). The global `python` command resolves to an inaccessible Microsoft Store alias, but the project `.venv\Scripts\python.exe` runs Python 3.14.7. Rustc remains the blocking tool. No current Windows `.exe` was built.
- Resume the Windows build on a Windows host where the approved Rust MSVC toolchain can execute and Python 3.11+ is available, using a clean/current checkout of the WSL source commit. Then run `npm run setup:dev` and `npm run build:all` (defaults to NSIS on Windows). Keep Nuitka's Windows sidecar build and the installer build on Windows.
