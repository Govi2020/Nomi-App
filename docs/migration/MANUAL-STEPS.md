# Manual steps

## Phase 0 backend baseline failure

The suite ran with the project `.venv` and its per-test temporary databases. Thirteen tests passed. One failed because `backend/tests/test_diary_api.py:349` expects the phrase `at least two different entries` in the clinical-report prompt, while the current prompt says `at least two distinct entry citations`. Rerun after any intentional prompt/test update with:

```powershell
.\.venv\Scripts\python.exe -m unittest discover -s backend\tests -v
```

The Phase 0 production frontend build passed using `npm run build`; Vite printed a chunk-size warning for voice/model bundles. Existing tests use temporary data directories. Keep integration tests away from repository `data/`; if a new test starts the backend directly, set `JOURNAL_DATA_DIR` to a throwaway path first.
