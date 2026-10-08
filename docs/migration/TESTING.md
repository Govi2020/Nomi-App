# Verification record and manual checklist

The user requested that no tests be implemented or run during this migration. Do not add test files or run test suites unless the user changes that instruction. This document records builds and operational checks separately from automated tests.

## Verified in WSL (Ubuntu 26.04)

- Frontend `npm run build` passed after the Ollama readiness UI changes; Vite reports the existing large voice/model chunk advisory.
- `cargo clippy --manifest-path src-tauri/Cargo.toml -- -D warnings` passed after adding the fixed Ollama download opener command.
- Python source `compileall` and `git diff --check` passed after adding AI status and streaming pull routes.
- Prior Phase 7 release manual API smoke: process health 200, protected route without token 401, wrong token 401, valid token 200, synthetic create/read 200. It used isolated XDG directories and a rebuilt Nuitka sidecar.
- Final Phase 8 Debian artifact: 57.81 MiB, SHA-256 `f4c002209c4b17d3a7768149ce1ad11d01f0f436e6202498d3cb29bb56bdc92e`; sidecar SHA-256 `359793bd8c9021f87c873096a4c0483b52cfb0cebc6930646bd3495169383af3`. The final package includes the explicit ready-state frontend card and exact model-tag matching.
- Packaged Phase 8 API check with `OLLAMA_HOST` set to a dead loopback port: `/health` 200; `/api/ai/status` 401 without a token and 200 with the managed token (`ollama_reachable=false`); `/api/ai/models/pull` returned a streamed, parseable NDJSON error event. Release app shut down after check. This verifies API contract/error stream only, not visible UI or successful downloads.
- Process manager manual checks previously passed busy-port recovery, synthetic entry CRUD, parent kill cleanup within 5 seconds, and normal shutdown. WSLg rendered a 1280×800 app window with software-rendering environment flags.

## Not verified yet

- Phase 8 end-to-end states in an actual packaged WebView, including missing Ollama, missing model, successful Ollama pull progress, and ready state. Ollama was unreachable in the last isolated WSL check; do not download models without authorization.
- Windows NSIS installer and Windows Nuitka sidecar; Windows packaging previously hit Application Control OS error 4551.
- AppImage and Ubuntu 22.04 / Debian 12 compatibility; current build host is Ubuntu 26.04.
- Full product matrix: chat/RAG stream, packaged MCP, microphone permissions, Whisper, Kokoro, settings persistence, uploads/media playback, exports, data upgrade/uninstall/reinstall/reboot lifecycle, non-ASCII paths, clean machine without developer tools, install-over upgrades, and Windows process cleanup.
- Full WebView network trace for voice model redirects/CDNs.

## Master prompt matrix status

| # | Scenario | Result | Evidence / remaining work |
|---|---|---|---|
| 1 | Cold packaged start | PARTIAL | WSL release app and bundled sidecar started; application UI was not visually inspected through the packaged WebView. |
| 2 | Clean shutdown | PASS (WSL release, Ctrl+C) | Manager and backend exited after the release API smoke. Window-close behavior still needs native visual confirmation. |
| 3 | Nomi process killed | PASS (WSL debug) | Killing the exact Tauri manager PID stopped the managed backend within 5 seconds. Windows not verified. |
| 4 | Backend crash and recovery | PASS (WSL debug) | Killing the managed backend caused restart and health recovery on the same port. |
| 5 | Startup failure UI | NOT RUN | No deliberate missing/corrupt-sidecar or unwritable-data UI inspection. |
| 6 | Occupied port | PASS (WSL debug) | Manager recovered from a deliberately busy first port. |
| 7 | Journal CRUD and persistence | PARTIAL | Synthetic create/read passed; edit/delete/restart persistence were not fully manually checked in the desktop package. |
| 8 | Search and retrieval | NOT RUN | Keyword and semantic retrieval were not checked in this migration continuation. |
| 9 | AI chat / RAG stream | NOT RUN | Ollama unavailable in the isolated WSL release check. |
| 10 | Packaged MCP | NOT RUN | No packaged MCP-triggering interaction performed. |
| 11 | STT | NOT RUN | Microphone permission and Whisper transcription not checked. |
| 12 | TTS | NOT RUN | Kokoro playback/restart not checked. |
| 13 | Settings persistence | NOT RUN | WebView settings persistence not checked across release restarts. |
| 14 | Media | NOT RUN | File selection, upload, image/audio playback, and drag/drop not fully checked. |
| 15 | Export / downloads | NOT RUN | Export/print/download flows not checked in packaged WebView. |
| 16 | Ollama absent / model missing | PARTIAL | Packaged API status with Ollama unavailable and authenticated pull error stream verified; actual card appearance and missing-model state not visually inspected. |
| 17 | Data lifecycle | NOT RUN | Upgrade, uninstall retention, reinstall, and reboot persistence not checked. |
| 18 | Unusual paths | NOT RUN | Spaces/non-ASCII install and data paths not checked. |
| 19 | Clean machine | NOT RUN | No clean Windows or Linux host without developer tools was available. |
| 20 | Security | PARTIAL | Token 401/200, Host 400, CORS rejection, loopback binding, capability/CSP and artifact scans checked; complete outbound WebView trace not done. |
| 21 | Dev workflows | PARTIAL | Tauri dev and frontend build ran in WSL; current PowerShell browser workflow was not rerun after changes. |

## Manual release checklist (when available, without adding tests)

Use a clean synthetic data directory and record PASS/FAIL/NOT RUN per item. Never point checks at the user's repository `data/`.

1. Cold packaged start reaches the real app UI and manager/backend health.
2. Close app normally; confirm sidecar exits within 5 seconds and database can be copied.
3. Force-kill the Tauri manager; confirm its tracked backend exits within 5 seconds.
4. Kill backend child; observe crashed state, restart, and successful journal action.
5. Cause startup failure; confirm readable error/log path and closable window.
6. Occupy the first selected port; confirm manager retries.
7. Create, edit, read, delete a synthetic diary row and confirm persistence after restart.
8. Verify keyword/semantic search with suitable synthetic entries.
9. With Ollama available, verify streamed AI chat/RAG response.
10. Verify packaged MCP tool call.
11. Verify microphone permission and transcription; cache survives restart.
12. Verify TTS speech and restart behavior.
13. Verify settings persist.
14. Verify file picker, supported drag/drop, image/audio display and playback.
15. Verify exports/downloads/print features.
16. With Ollama absent/models missing, confirm journaling still works and AI readiness UI is clear; never remove real models.
17. Verify data survives install-over, uninstall (data retained), reinstall, and reboot.
18. Verify paths containing spaces and non-ASCII characters.
19. On a clean machine without Python/Node/Rust/Visual Studio, verify packaged install and core flows.
20. Verify loopback listener, token/CORS/Host checks, and package has no Python source/maps/secrets.
21. Verify browser `run.ps1` workflow and Tauri dev workflow.


## Developer utility checks

- Node syntax checks passed for `build-all.mjs`, `clean.mjs`, and `verify-package.mjs`; Python bytecode compilation passed for `import-dev-data.py`.
- Read-only package verification passed for the current Debian artifact: expected launcher and backend sidecar entries found; 60,616,492 bytes; SHA-256 `f4c002209c4b17d3a7768149ce1ad11d01f0f436e6202498d3cb29bb56bdc92e`.
- The clean utility was not executed. The data import utility was not run against any data. No test suites were added or run.
