# People Manager Metadata Browser Regression Preflight Failure — 2026-09-09

| Item | Value |
|---|---|
| Status | **PREVIEW NOT STARTED — TEST ASSERTION CORRECTED** |
| Disposable-accepted runtime application/database candidate | `deaa9157282e59e8acd6a7da2a82fc9296e44f20` |
| Browser-review worktree after test-only correction | `2de2d244ec7259e52f9d312587a86ef38c7f512f` |
| Production mutation | NONE |
| Disposable browser clone created | NO |
| Flask preview started | NO |
| Failed report | `/tmp/MSB_People_Manager_Browser_Preview_20260909T184342.txt` |

## Failure

The governed browser-review runner stopped during the detached candidate pytest regression, before the current-Production dump/disposable browser clone or Flask preview was started.

The failing assertion was:

```text
assert 'api/people/${state.selectedPersonId}/leadership' in JS
```

The actual reviewed JavaScript correctly loads all person metadata inside `selectPerson(personId)` and calls:

```text
api(`api/people/${personId}/leadership`)
```

The test asserted an implementation-variable spelling that the application does not use. This was a stale/brittle test expectation, not a missing leadership API call or application behavior defect.

## Correction

`People/Application/test_people_manager_contract.py` now asserts the actual leadership request emitted by `selectPerson(personId)`:

```text
api(`api/people/${personId}/leadership`)
```

No runtime application file and no database migration changed from disposable-accepted candidate `deaa9157282e59e8acd6a7da2a82fc9296e44f20`.

The browser-review wrapper/server are pinned to worktree `2de2d244ec7259e52f9d312587a86ef38c7f512f`, which differs in the People runtime candidate area only by this test assertion. The server still applies the same migrations `001`, `002`, and `003` and launches the same V0.2.0 runtime application accepted by the disposable gate.

## Production invariant

The failed browser preflight proved Production remained unchanged:

```text
Person fingerprint before: 47f494107952a84f30a406374b8d01d7
Person fingerprint after:  47f494107952a84f30a406374b8d01d7
PASS: production ref.person fingerprint unchanged

Production checkout before: 72f5b7164f31753a33e5c2a9d83d9a7a6909a417
Production checkout after:  72f5b7164f31753a33e5c2a9d83d9a7a6909a417
PASS: production checkout unchanged
PASS: production FieldWiring service remains healthy
PASS: preview port 8795 is no longer listening
```

## Retry boundary

Do not rerun the disposable database gate solely for this test-string correction. Runtime application/database behavior is byte-identical to the accepted candidate. Restart the governed browser-review command after pulling the corrected branch; its first detached regression must pass before any disposable browser clone or Flask preview is started.
