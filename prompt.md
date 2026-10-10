# Nomi project handoff prompt

You are taking over the Nomi desktop migration. Use this as a bootstrap guide, then verify the live repository before editing. The binding requirements are in `NOMI_TAURI_MASTER_PROMPT.md`; this file records user decisions, current state, constraints, and the next actions.

## Start here (read first)

**Goal:** finish a Tauri v2 desktop app for Windows and Linux. Preserve the React/TypeScript frontend and Python/FastAPI backend; package the backend as a Nuitka sidecar. Ollama stays external (`qwen2.5:3b` chat, `nomic-embed-text` embeddings).

**Canonical working copy:** WSL Ubuntu 26.04 at `/home/govi2020/Nomi`. Last verified HEAD before Phase 9 utilities: `cf5b157`; Phase 9 changes uncommitted. The Windows copy at `C:\Users\Govind\Desktop\Nomi` is stale/diverged (last observed HEAD `7e6a00b`) and contains user-owned files. Never sync whole trees or reset either checkout. If WSL is inaccessible, stop before pretending the Windows copy has the latest work.

**User constraints:** no tests should be added or run now. The user authorized WSL work, local setup, and Linux + Windows support. Do not use Cargo `--offline`. Keep model defaults above. Do not access real journal data or pull/remove Ollama models without permission.

**Last known result:** Linux `.deb` built and the release app passed an authenticated API smoke using isolated data. Package SHA-256: `f4c002209c4b17d3a7768149ce1ad11d01f0f436e6202498d3cb29bb56bdc92e`. This does not establish Windows packaging, AppImage compatibility, or full feature parity.

**Do these in order:**

1. Check `git status`, branch/log, and running processes in WSL. Read this file plus `NOMI_TAURI_MASTER_PROMPT.md` and all `docs/migration/*.md`; confirm the status against source. Never read `data/`.
2. Review pending Phase 7 diffs. Reconcile `docs/migration/PROGRESS.md` in WSL with the successful rebuilt-release result recorded below. Rebuild the Nuitka sidecar before Tauri whenever backend code changes.
3. Run only non-test checks (build, TypeScript, Clippy, narrow manual smoke) and use a new ignored `build/` or `/tmp` data directory. Commit only intended tracked files; preserve all user-owned untracked files.
4. Finish Phases 7–9 from the master prompt: security/network review, Ollama first-run UX, docs and platform-aware scripts, truthful verification matrix, Linux/Windows packaging. Mark impossible checks NOT RUN and give manual steps; do not claim full app operation from the API smoke.
5. Report concrete commands, verified outcomes, platform limits, and remaining steps. Keep the user informed while long builds run.

Then read the detailed sections below and the listed project docs before making changes. If live repository state differs from this handoff, live source and user instructions take precedence; update this file/progress notes when needed.

## Dated handoff snapshot — 2026-10-08

This snapshot separates migration progress from product verification. A phase marked implemented does not imply every feature in the full verification matrix works.

| Phase | State | Evidence / remaining work |
|---|---|---|
| 0. Recon and decisions | Complete, commit `6dd1c48` | No Electron app existed. Browser React/Vite + FastAPI/SQLite is the baseline. User selected permanent identifier `com.nomi.desktop`, Linux support, and local install approval. |
| 1. Backend launch contract | Complete, commits `a2e29ce`, `0ab1cbc` | Config, health, loopback, logging, shutdown, and compiled MCP self-spawn handling. Historical tests were run then; do not repeat under current instruction. |
| 2. Frontend runtime config | Complete, commit `c2235a7` | API client/runtime config, backend gate, browser proxy preserved; frontend production build passed. |
| 3. Tauri shell | Implemented, commit `7e6a00b` | Tauri v2 dev launch worked on WSLg. Native Windows Rust build was blocked by Application Control, OS error 4551. |
| 4. Managed backend lifecycle | Implemented, `494c5c7`, lint fix `c636310` | WSL manual checks passed port collision recovery, synthetic CRUD, parent kill cleanup <5 s, normal shutdown. Windows process cleanup not verified. |
| 5. Nuitka backend sidecar | Linux build complete, `16df829` | One-file sidecar built and launched outside venv. Latest Phase 7 rebuild SHA: `cc93da31245a02f0dde99d409fb6e9934bdbec2528dea5aa06198c84591b377a`. Windows sidecar not built. |
| 6. Linux production package | Debian package built/run, `d30f549`, data-default fix `f8b5603`; phase still open | Latest package is 57.81 MiB and passed release API smoke. AppImage and oldest-supported Linux baseline are unverified. Windows NSIS package is unbuilt. |
| 7. API boundary hardening | Implemented and release-verified, **uncommitted in WSL** | Latest Debian release returned 401 without/wrong token and 200 with correct token; synthetic CRUD passed in the earlier release check. Reconcile progress, inspect diff, commit intentional source/docs only. |
| 8. Ollama first-run UX | Implemented; endpoint smoke passed, **feature not complete** | Status/pull API, exact configured model-tag matching, readiness card with explicit ready state, fixed Ollama download opener, and progress UI are in source. Packaged check with Ollama unreachable got health 200, status 401 unauth/200 auth, reachable=false, pull HTTP 200 with parseable NDJSON error. Actual WebView visual states and successful model download are NOT RUN. No model was downloaded. |
| 9. Full verification/docs/release | In progress | Added BUILD.md, TESTING.md, setup/build commands and README desktop instructions. Full matrix, clean-machine validation, Windows installer, baseline Linux/AppImage, and several feature checks remain. |

### Exact known Git state and generated artifacts

- WSL repo path: `/home/govi2020/Nomi`; Ubuntu 26.04 / WSL2. Last queried branch name was `feat/tauri-shell`; HEAD `f8b5603`.
- WSL modified tracked files now include Phase 7 security changes and Phase 8 backend/UI/Rust changes: `backend/config.py`, `backend/ollama_client.py`, `backend/server.py`, `docs/migration/PROGRESS.md`, `frontend/src/App.tsx`, `frontend/src/services/apiClient.ts`, `frontend/src/services/memoryService.ts`, `frontend/src/styles.css`, `package.json`, `src-tauri/Cargo.lock`, `src-tauri/Cargo.toml`, `src-tauri/src/lib.rs`.
- WSL added project files: `docs/migration/BUILD.md`, `docs/migration/TESTING.md`, `frontend/src/components/AiReadinessCard.tsx`, `scripts/build-all-linux.sh`, `scripts/build-backend.mjs`, `scripts/build_backend.py`, `scripts/run-linux.sh`, `scripts/setup-linux.sh`, `scripts/setup.mjs`. Untracked user-owned files also include `NOMI_TAURI_MASTER_PROMPT.md`, `README.md`, `docs/migration/SECURITY-NOTES.md`, `setup.ps1`, and this `prompt.md`. Inspect ownership and preserve them; do not stage unrelated files. Build artifacts are ignored.
- `docs/migration/PROGRESS.md` now records the Phase 7 release and Phase 8 API verification; recheck it in WSL before commit.
- Windows path `C:\Users\Govind\Desktop\Nomi` had stale HEAD `7e6a00b`, unrelated local edits, and untracked user documents/images/installer. It is not a safe mirror of WSL. User data must stay out of any sync.
- Latest Linux `.deb`: `/home/govi2020/Nomi/src-tauri/target/release/bundle/deb/Nomi_0.1.0_amd64.deb`, 57.81 MiB, SHA-256 `f4c002209c4b17d3a7768149ce1ad11d01f0f436e6202498d3cb29bb56bdc92e`. Latest sidecar SHA-256 `359793bd8c9021f87c873096a4c0483b52cfb0cebc6930646bd3495169383af3`. These are ignored build outputs, not committed deliverables; verify before reuse.

### Exact last verification evidence

- Command that built the current Linux package (online Cargo, not offline):
  `env CARGO_REGISTRIES_CRATES_IO_PROTOCOL=git CARGO_NET_GIT_FETCH_WITH_CLI=true CARGO_HTTP_CAINFO=/etc/ssl/certs/ca-certificates.crt npm run tauri:build -- --bundles deb`
- Backend source changes require rebuilding the sidecar first: `npm run build:backend` (or `./scripts/build-backend.sh`), then the Tauri command above. A release attempt using the stale sidecar initially returned 200 for unauthenticated entries; rebuilding Nuitka sidecar + Debian package fixed it. `tauri build` alone does not regenerate Nuitka output.
- Current packaged release smoke after rebuild: health 200; protected API no token 401; wrong token 401; correct token 200; authenticated create/read 200. It used isolated XDG data directories under ignored `build/`; token was not printed. Release app was Ctrl-C closed.
- Latest frontend build and Rust Clippy passed; Vite continues to warn about large voice/model chunks. `python3 -m compileall -q backend`, `git diff --check`, and Node helper syntax checks passed. No tests were added or run.
- Phase 8 packaged API result: `/health` 200, AI status unauthorized 401, authorized 200 with `ollama_reachable=false`; pull endpoint returned 200 with an NDJSON error event because Ollama was intentionally unreachable. No real Ollama model was fetched. Process was shut down after the smoke. Actual UI appearance and successful model-download progress remain unverified.
- WSLg launch env used successfully: `LIBGL_ALWAYS_SOFTWARE=1 WEBKIT_DISABLE_DMABUF_RENDERER=1 GDK_BACKEND=x11`. Without it Mesa/EGL emitted errors; with it a 1280×800 Tauri window launched. A separate Codex browser Vite tab displayed frontend content; do not mistake that for proof of packaged visual rendering.

## Mission

Finish converting Nomi into a working, installable cross-platform Tauri v2 desktop application while preserving its existing React frontend, Python/FastAPI backend, SQLite behavior, browser development workflow, Ollama integration, MCP behavior, journal data, media, and local voice features. The desktop app must supervise its own Nuitka-compiled backend sidecar; an end user must not need Python, Node, Rust, or pip. Ollama remains a separately installed local dependency. Complete the remaining requirements in the master prompt, record honest PASS / FAIL / NOT RUN outcomes, and report limitations plainly.

## Important user instructions and decisions

- Permanent Tauri identifier selected by the user: `com.nomi.desktop`.
- The user authorized local project setup/install and expanded the target to Windows **and Linux**.
- The user explicitly asked to continue the migration and asked to work from WSL. WSL is the intended active development/build environment when available.
- The user explicitly said: **do not implement tests right now**. Do not add test files/suites or run test suites unless the user later changes this instruction. Operational checks such as builds, clippy, lint/type-check, and narrowly scoped manual smoke checks are acceptable. Older test results in progress notes are historical facts, not permission to resume tests.
- The user selected Ollama model `qwen2.5:3b`. Current backend defaults also use `nomic-embed-text` for embeddings. Do not replace either without instruction.
- The user asked to try the app without Cargo's `--offline` flag. Continue using online dependency resolution; do not use `--offline` as a workaround.
- The user has asked how to run the app, which environment variables/setup are needed, and how the current scripts behave. Finish clear developer/build/run documentation and scripts as specified in the master prompt.
- The user's latest request was to create this detailed handoff prompt so another AI can resume without losing context.

## Critical data and workspace cautions

- `data/` at repo root may contain private journal content, database, audio, media, and logs. **Do not inspect, copy, commit, delete, reset, or use it for smoke tests.** Use a fresh throwaway location under ignored `build/` or `/tmp` for synthetic records. The initial migration notes say the original `data/` was empty at Phase 0, but current data must be treated as private regardless.
- Do not overwrite or clean user-owned, untracked files. The Windows checkout currently contains user files such as `Heart_Labeled.png`, Word documents, a WhatsApp image, a Helium installer, `README.md`, `setup.ps1`, and `NOMI_TAURI_MASTER_PROMPT.md`; inspect only what is necessary and preserve them. Do not stage or commit user-owned files just to make Git clean.
- Do not run broad `git clean`, reset, recursive deletion, or copy-all operations. Build output under ignored `build/`, `.venv-build`, `node_modules`, `frontend/dist`, and `src-tauri/target` may be generated, but preserve user work and validate targets before cleanup.
- The Windows and WSL checkouts are currently **not synchronized and have divergent histories**. Do not assume they are the same worktree or overwrite one from the other wholesale. The most recent verified project implementation is in WSL at `/home/govi2020/Nomi`, Ubuntu 26.04 WSL2, with HEAD `f8b5603` and commits through Linux packaging. The Windows checkout at `C:\Users\Govind\Desktop\Nomi` showed HEAD `7e6a00b` during handoff creation and has additional user-owned untracked files and local changes. Check both states, identify the right source of truth, and bring required artifacts across carefully. If WSL access is denied by the environment, explain that and work only on authorized Windows files; do not silently treat the stale Windows checkout as containing all later commits.
- Prior WSL commands sometimes required elevated `wsl.exe` access. If an automatic approval review rejects/times out, follow the environment's approval guidance; do not assume it succeeded.

## Project architecture and technologies

- Frontend: React, TypeScript, Vite, Tailwind, GSAP; browser/WebView performs Whisper Tiny STT and Kokoro TTS inference with Transformers.js / ONNX Runtime assets.
- Desktop shell: Tauri v2 / Rust, crate/package `nomi`, product `Nomi`, version `0.1.0`, identifier `com.nomi.desktop`.
- Backend: Python 3.14-compatible FastAPI + Uvicorn; SQLite database and local data files; RAG/search and MCP client/server. The backend MCP path starts a separate stdio child, so preserve the compiled self-spawn handling.
- Local AI: Ollama on `http://127.0.0.1:11434`, chat `qwen2.5:3b`, embeddings `nomic-embed-text`; Ollama/model assets are not bundled.
- Backend production packaging: Nuitka 4.2.2 one-file native executable, named `nomi-backend-<rust-host-triple>` under `src-tauri/binaries/`. The triple is derived from `rustc -vV`, not hard-coded. Tauri bundles it beside the app as the `nomi-backend` sidecar.
- Data: debug backend defaults to repository `data/` for backward-compatible development, or `NOMI_DATA_DIR` / legacy `JOURNAL_DATA_DIR`; production uses per-user app data. Never test against real journal data.
- Locking/build files include root `package.json` + `package-lock.json` in the WSL checkout, `frontend/` dependencies, `requirements.lock.txt`, `backend/requirements-build.txt`, and `src-tauri/Cargo.lock`.

## Relevant environment variables

Backend configuration in `backend/config.py` currently reads:

- `NOMI_DATA_DIR` (preferred data root; takes precedence over legacy `JOURNAL_DATA_DIR`)
- `JOURNAL_DATA_DIR` (legacy data root)
- `NOMI_HOST` (defaults to `127.0.0.1`; keep loopback only)
- `NOMI_PORT` (defaults to `8000`; Tauri manager supplies a dynamically allocated port)
- `NOMI_APP_VERSION` (defaults to `0.1.0`)
- `NOMI_API_TOKEN` (optional standalone; Tauri generates a fresh per-launch 256-bit token)
- `OLLAMA_HOST` (defaults to `http://127.0.0.1:11434`)
- `CHAT_MODEL` (defaults to `qwen2.5:3b`)
- `EMBED_MODEL` (defaults to `nomic-embed-text`)
- Similarity/RAG tunables: `LINK_SIM_THRESHOLD`, `REL_SIM_THRESHOLD`, `FOLLOWUP_MIN_SIM`, `RAG_TOP_K`, `GRAPH_MAX_ENTRIES`.

For WSLg GUI rendering, prior successful launch used `LIBGL_ALWAYS_SOFTWARE=1 WEBKIT_DISABLE_DMABUF_RENDERER=1 GDK_BACKEND=x11`. For Cargo online fetches in this Ubuntu WSL environment, the prior working configuration was `CARGO_REGISTRIES_CRATES_IO_PROTOCOL=git CARGO_NET_GIT_FETCH_WITH_CLI=true CARGO_HTTP_CAINFO=/etc/ssl/certs/ca-certificates.crt`. The first ordinary sparse-registry attempt failed certificate verification; use the configured online workaround, never `--offline`. A one-time crate cache repair used curl with the system CA; only repeat if the same dependency-fetch problem occurs.

## Current verified state as of 2026-10-06

The WSL repo's known committed history:

1. `6dd1c48` Phase 0 architecture recon and doctor.
2. `a2e29ce` Phase 1 launchable backend.
3. `0ab1cbc` Phase 1 follow-up to align a stale assertion (historical approved change).
4. `c2235a7` Phase 2 runtime backend gate.
5. `7e6a00b` Phase 3 Tauri shell scaffold.
6. `494c5c7` supervise backend from Tauri shell.
7. `c636310` Rust lint cleanup.
8. `16df829` Linux Nuitka backend build.
9. `d30f549` bundle backend in Linux Tauri package.
10. `f8b5603` preserve repository data default in development.

At handoff, WSL has uncommitted Phase 7 API boundary changes in `backend/config.py`, `backend/server.py`, `frontend/src/services/apiClient.ts`, `frontend/src/services/memoryService.ts`, `src-tauri/Cargo.toml`, `src-tauri/Cargo.lock`, `src-tauri/src/lib.rs`, and docs. Untracked WSL files include the master prompt, README, `setup.ps1`, and security notes. Preserve the user files; inspect `git status` before staging. `docs/migration/PROGRESS.md` in WSL still says Phase 7 is in progress because an attempted sync from Windows was interrupted. The Windows copy has a Phase 7 completion update, but is not the active checkout; reconcile the note into WSL deliberately after checking exact contents.

### Completed or manually verified

- Phase 0 confirmed there was no Electron app; this is a Tauri addition, not an Electron replacement. The browser Vite + FastAPI workflow remains.
- Phases 1–3 provide backend config/launcher/health, frontend API runtime config/backend loading gate, and Tauri v2 shell. `npm run tauri:dev` launched in WSLg; Vite UI rendered separately in Codex browser. Do not claim the Codex browser screenshot proves the packaged Tauri screen itself was rendered.
- Phase 4 Rust backend manager launches the debug venv backend and release sidecar, chooses a loopback ephemeral port, checks `/health` and app instance, emits state events, logs stdout/stderr, retries/restarts, and stops the tracked child. In WSL, manual checks passed occupied-port recovery, synthetic entry create/read, parent `SIGKILL` child cleanup under 5 seconds, and normal shutdown with no child left. Windows-specific cleanup is not verified.
- Phase 5 Linux backend sidecar build script exists at `scripts/build-backend.sh`, executable in WSL. It reads the Rust host triple and uses an isolated `.venv-build`. The previously built 49 MiB sidecar worked outside the Python venv, returned `/health`, did synthetic CRUD, and handled stdin `SHUTDOWN`; cold/warm startup measured about 2.85/2.74 seconds. After API-token changes, the sidecar was correctly rebuilt from current sources; latest sidecar SHA-256 was `cc93da31245a02f0dde99d409fb6e9934bdbec2528dea5aa06198c84591b377a`.
- Phase 6 Linux Tauri packaging works on Ubuntu 26.04. Latest rebuilt Debian package: `src-tauri/target/release/bundle/deb/Nomi_0.1.0_amd64.deb`, 57.81 MiB, SHA-256 `138fa628ca7a6cc3d0380459ebd08a1a0bafcee340d39ae1fda1343f9f550b2a`. The release run first revealed that the package had a stale pre-token sidecar; the sidecar and package were rebuilt, then the current release app passed API verification. Runtime verification used fresh isolated `XDG_DATA_HOME` and `XDG_STATE_HOME` paths under ignored `build/`.
- Phase 7 implementation creates a per-launch OS-random 256-bit bearer token in Rust, sends it to the sidecar via `NOMI_API_TOKEN`, exposes it only through the narrow Tauri command/event config, and sends it in `Authorization: Bearer` from the frontend API client. FastAPI checks token constant-time for all HTTP routes except `/health`; browser mode with no token remains compatible. Media fetching uses authenticated requests and blob URLs.
- Latest Linux release manual API smoke: `/health` without token = 200; `/api/entries` without token = 401; wrong token = 401; correct token = 200; authenticated synthetic create = 200; authenticated read = 200. Token was read only in-process and never printed. Earlier dev security smoke also checked untrusted Origin (no CORS allow header) and spoofed Host (400).
- Latest checks: frontend TypeScript/Vite production build passed with existing large voice/model chunk advisory; `cargo clippy -- -D warnings` passed after Phase 7. The package and release executable built successfully, and release runtime started with its bundled backend. No tests were added or run during these requested phases.
- Security notes exist at `docs/migration/SECURITY-NOTES.md`. Main capability has `core:default` only. Production CSP allows local backend plus Hugging Face model hosts. A read-only artifact scan found no `.map`/`.env` under frontend/dist and no `.env` under backend/src-tauri. Nuitka does not make Python or JS prompts/schema/routes secret; same-user malware can inspect process memory/environment.

### Incomplete and not verified (do not overclaim)

- **Phase 6/platform packaging incomplete:** Linux `.deb` is built and run, but AppImage was not built. Do not claim Ubuntu 22.04/Debian 12 compatibility from a builder on Ubuntu 26.04; Tauri guidance requires building AppImage on the oldest supported target. Windows packaging/NSIS and Windows sidecar build are not completed; prior native Windows Cargo build was blocked by Application Control (OS error 4551). macOS is not a requested target.
- **Phase 7:** final progress note sync and commit are outstanding. Wider outbound network/CSP review is not complete; model redirects/CDNs have not been captured through actual WebView. Smoke is a narrow API boundary check, not proof every UI feature works.
- **Phase 8 not done:** Ollama readiness and first-run onboarding / model-pull progress UX not implemented/verified. Ollama was unreachable in WSL, so AI/RAG/MCP behaviors depending on Ollama remain unavailable. Never download models or remove user models without permission.
- **Phase 9 not done:** no full 21-row verification matrix, clean-machine validation, data upgrade/uninstall lifecycle, unusual path coverage, packaged MCP, STT/TTS permissions, media drag-drop, exports, Windows install, or reboot persistence checks. Provide `docs/migration/MANUAL-STEPS.md` instructions for user-only scenarios.
- Documentation/scripts are incomplete against deliverables: add `docs/migration/BUILD.md`, `TESTING.md` (descriptive checks only; do not add/run tests against user's present instruction), robust platform setup/dev/build/clean/verify scripts as master spec requires, README desktop section, and ensure `run.ps1` browser behavior remains intact. The user asked for platform-agnostic commands and setup/run scripts earlier; document PowerShell and Linux/WSL commands clearly.
- Current root `setup.ps1` and `README.md` are untracked/user-owned in the WSL history. Inspect before editing; don't overwrite user content. Existing root scripts may be old: confirm whether they create `.venv`/Node dependencies and what they install before describing them.
- The Windows and WSL checkout diverge. Do not assume Windows has any commits beyond `7e6a00b`; WSL is the source of truth for the implemented migration unless evidence/user direction changes that.

## Immediate next steps

1. Start in `/home/govi2020/Nomi` (WSL) if accessible. Read `git status --short`, `git diff`, all migration docs, and compare with this prompt. Do not reset/clean or stage any user asset. Confirm whether the app/release build processes from prior turn are stopped; the release app was Ctrl-C closed, but process-list once more before continuing.
2. Finish syncing the Phase 7 progress wording to WSL using a careful single-file transfer/edit. Include the current package hash, the initial stale sidecar discovery and corrected successful release run, and current limits. Do not copy repository trees or `data/`.
3. Review Phase 7 diff for correctness/security and run only approved non-test checks: `npm run build` or Tauri pre-build, `cargo clippy -- -D warnings`, inspect CSP/capability/network access. If edits require regeneration, run `./scripts/build-backend.sh` **before** `npm run tauri:build -- --bundles deb`; Tauri does not automatically rebuild the Nuitka sidecar. Always check artifact contents/hashes and use isolated data for runtime.
4. Commit only intentional Phase 7 code and its migration/security docs in the WSL branch. Never stage the untracked `README.md`, `setup.ps1`, `NOMI_TAURI_MASTER_PROMPT.md`, this `prompt.md`, user documents/images/installer, or `data/` without explicit review and intent. Do not blindly commit the Windows checkout's unrelated assets.
5. Continue Phase 8 Ollama onboarding additively. Keep `qwen2.5:3b` and `nomic-embed-text`; AI absence must not prevent ordinary journaling. Do not fetch/pull model data without explicit authorization. The user's no-tests instruction remains in effect.
6. Complete cross-platform setup/build/run documentation and scripts. Make scripts platform-aware rather than assuming Windows or bash. Setup should explain prerequisites for developers (Node/npm, Rust/Tauri prerequisites, Python only for dev/backend compilation, Ollama/models) versus end-user runtime (packaged app plus separately installed Ollama). Do not promise end users need build tools.
7. Finish Phase 9 with a real result for each verification matrix item. Perform only checks that are permitted and possible; mark others NOT RUN and give precise manual steps. Do not describe the whole app as verified just because the shell and API smoke work.
8. Build/test Linux AppImage on an appropriate oldest-supported Linux environment and Windows NSIS on a supported Windows host. The earlier Windows Application Control rejection is a host limitation; report evidence and ask for a suitable host/approval only if needed. Never weaken packaging requirements just to obtain a pass.
9. Provide the user concise run commands, setup dependencies/env variables, commit list, package locations/hashes, verified results, limitations, and next actions. The desktop dev command currently is `npm run tauri:dev` from repo root after `npm ci` and frontend prerequisites; backend runs under project venv. Linux release build sequence is `./scripts/build-backend.sh` then `npm run tauri:build -- --bundles deb` (with the online Cargo env workaround above in this WSL). Browser workflow via existing `run.ps1` must be preserved and documented.

## Current files / locations to orient yourself

- Master requirements: `NOMI_TAURI_MASTER_PROMPT.md`
- Migration state: `docs/migration/PROGRESS.md`
- Decisions and architecture: `docs/migration/DECISIONS.md`, `docs/migration/00-current-architecture.md`
- Manual follow-up: `docs/migration/MANUAL-STEPS.md`
- Security notes: `docs/migration/SECURITY-NOTES.md`
- Rust backend lifecycle/token: `src-tauri/src/lib.rs`
- Tauri permissions/CSP/targets: `src-tauri/capabilities/default.json`, `src-tauri/tauri.conf.json`
- Backend config/auth: `backend/config.py`, `backend/server.py`
- Frontend API/auth/media: `frontend/src/services/apiClient.ts`, `frontend/src/services/memoryService.ts`
- Linux Nuitka script: `scripts/build-backend.sh`
- Backend lock inputs: `requirements.lock.txt`, `backend/requirements-build.txt`
- Current WSL Linux package: `/home/govi2020/Nomi/src-tauri/target/release/bundle/deb/Nomi_0.1.0_amd64.deb` (generated, ignored build output; verify it still exists before claiming it is available).

## Operating rules

- Follow the phase operating loop in the master prompt: reread phase, make focused changes, inspect actual command results, update progress, commit intentional tracked changes, continue without requesting routine approval.
- Keep user updated in concise progress messages during long work. Do not ask questions already answered above.
- Do not introduce tests under the current instruction. Existing tests may be mentioned historically, but don't run them.
- Keep security/privacy statements accurate; compiled Python is still inspectable and no new journal-text upload/telemetry should be introduced.
- For each claim, distinguish source/build success from app runtime and full feature verification.


## Continuation update — 2026-10-09

- Canonical WSL HEAD before this continuation: cf5b157. Phase 7 and 8 are committed. New Phase 9 utility changes are uncommitted.
- New utilities: npm run build:all builds the sidecar then Tauri (defaults nsis on Windows, deb on Linux; NOMI_BUNDLES overrides); npm run clean is dry-run by default and targets only build/backend, frontend/dist, src-tauri/target; npm run verify:package -- <path> hashes the artifact and checks Debian layout without executing; scripts/import-dev-data.py previews by default and requires --apply plus typing IMPORT, refuses existing/nested destination, and does not open the database.
- Verified: three Node syntax checks, Python py_compile, git diff --check, and read-only Debian artifact layout/hash. Current package size 60,616,492 bytes; SHA-256 f4c002209c4b17d3a7768149ce1ad11d01f0f436e6202498d3cb29bb56bdc92e. Expected usr/bin/nomi and usr/bin/nomi-backend are present.
- Clean was not executed; no data was imported; no tests were added or run. Install did not complete: the previous sudo dpkg -i waited for interactive authorization, was interrupted, and dpkg-query showed Nomi not installed.
- Outstanding: commit only intended tracked files (package.json, the four utility scripts, BUILD.md, TESTING.md, and PROGRESS.md); preserve untracked user-owned NOMI_TAURI_MASTER_PROMPT.md, README.md, prompt.md, setup.ps1. Windows NSIS/sidecar remains unbuilt after Application Control error 4551; AppImage and Ubuntu 22.04/Debian 12 compatibility remain unverified; actual packaged WebView flows and successful Ollama pulls remain unverified; use the honest NOT RUN matrix.
- WSL /home/govi2020/Nomi remains source of truth. Windows checkout is stale/diverged. Sync exact named files only. Never access data/.


## Microphone permission fix — 2026-10-09

- User reported inability to grant microphone access in the running WSL/Linux app.
- Installed versions: Tauri 2.12.1, Wry 0.57.0, WebKitGTK 4.1. Tauri exposes `Builder::on_permission_request`; WebKitGTK rejects an unhandled user-media permission request by default, and Tauri had no handler.
- Added a handler to `src-tauri/src/lib.rs`: only microphone requests from webview label `main` at local app origins (`tauri://localhost`, `http://localhost:5173`, `https://tauri.localhost`) receive `Allow`; all other kinds/origins receive `Default`.
- `cargo clippy -- -D warnings` and `cargo build --release` passed, no tests run. New release executable is running with isolated XDG dirs under `build/run-session`.
- Actual microphone capture is still NOT VERIFIED. `pactl` and `arecord` are unavailable in this WSL distribution, so source detection was not performed. Ask the user to click Diary/Talk microphone control. If it still fails, inspect Windows Microphone privacy settings and WSLg audio input routing; distinguish webview permission from physical/device routing.


## Windows Ollama / .exe request follow-up — 2026-10-09

- User says Ollama works on their Windows PC and asks to connect it to the WSL app and produce a Windows executable.
- WSL uses NAT (default route was 172.29.16.1). Read-only checks: `127.0.0.1:11434` connection refused; gateway `172.29.16.1:11434` timed out. No connection established. Preferred route: Windows 11 22H2+ mirrored networking (`%UserProfile%\.wslconfig`, merge `[wsl2] networkingMode=mirrored`), `wsl --shutdown`, then verify from WSL with `curl http://127.0.0.1:11434/api/tags`; launch with `OLLAMA_HOST=http://127.0.0.1:11434`. Keep existing `.wslconfig` settings. Avoid public exposure of Ollama API.
- Windows build attempt/inspection: Node/npm available, `rustc` invocation is blocked by Application Control OS error 4551, the global Python alias is an inaccessible Microsoft Store shim, but the project `.venv\Scripts\python.exe` runs Python 3.14.7. No Windows exe created. Windows checkout HEAD 7e6a00b with modified/untracked user files is stale/diverged; do not sync wholesale or build from it. Use a clean/current checkout on a Windows host where Rust MSVC and Python can run. `docs/migration/MANUAL-STEPS.md` has steps/blockers.


## Ollama connection action completed — 2026-10-09

- Created `%UserProfile%\.wslconfig` (it was absent) with `[wsl2] networkingMode=mirrored`, restarted WSL, and confirmed WSL default route switched to the mirrored interface.
- WSL `curl http://127.0.0.1:11434/api/tags` returned HTTP 200; response lists `qwen2.5:3b` and `nomic-embed-text`. No pull/delete/model change occurred.
- Relaunched Nomi release with `OLLAMA_HOST=http://127.0.0.1:11434`, using isolated XDG dirs. UI chat/RAG behavior remains unverified until user interaction.
- Windows EXE request remains blocked by Windows Application Control error 4551 for rustc; no exe produced. Python alias is inaccessible. Do not use stale modified Windows checkout to create artifact.
