# People Manager Browser Preview Preflight Failures — 2026-09-09

| Item | Value |
|---|---|
| Status | **PREVIEW NOT STARTED — HARNESS CORRECTED BEFORE RETRY** |
| Exact accepted People candidate | `7cd4c02420f564c1fe563d0c12052480c6ce6f6b` |
| Failed wrapper | `People/Acceptance/run_people_manager_browser_preview.ps1` |
| Production database mutation | NONE |
| Disposable clone created | NO |
| People migrations applied | NO |
| Preview Flask application started | NO |

## Attempt 1 — Production Setup port selected by obsolete launcher behavior

The first People Manager pre-production browser-review launch used an older Controller-era launcher pattern that silently defaulted to TCP port `8794` and auto-opened the workstation browser before the remote preview was ready.

Current Server Management runtime authority shows that `192.168.5.9:8794` is the permanent Production Setup listener. The stale-preview cleanup therefore failed closed when it found that listener:

```text
FAIL: TCP port 8794 is still listening after People preview cleanup
LISTEN ... 192.168.5.9:8794
```

The cleanup did not remove or replace the listener.

The later Setup browser-review implementation already established the safer launcher behavior:

- `PreviewPort` is mandatory;
- `8794` is explicitly rejected because it is the live Production Setup listener; and
- the browser is not auto-opened before the remote runner reports browser-review readiness.

Those rules were promoted into the generic Server Management `Pre_Production_Browser_Review_Runbook.md` and the People wrapper/cleanup path was corrected to consume them.

## Attempt 2 — `msbadmin` runtime-path traversal check

The corrected-port retry used `8795`. Stale cleanup proved the port free, and the People browser runner then stopped during preflight with:

```text
FAIL: documented production Python runtime is missing: /opt/fieldwiring/.venv/bin/python
```

That diagnosis was false. The documented Production runtime path is correct, but the runner evaluated:

```bash
[[ -x /opt/fieldwiring/.venv/bin/python ]]
```

as `msbadmin`.

`msbadmin` is the SSH/system-administration account and cannot traverse the protected application runtime paths under `/opt/fieldwiring` / `/opt/msb-setup`. Runtime existence/executable/import/regression checks must therefore be evaluated as the service account, normally `fieldwiring`, after foreground `sudo` authorization. An `msbadmin` traversal failure must not be interpreted as a missing runtime and must not be "fixed" by broadening path permissions.

The failed cleanup also replaced the original preflight exit status with a secondary `production ref.person fingerprint was not captured` status. Because the runner had failed before the fingerprint gate, that after-check was not applicable. The browser-review runbook now requires teardown to preserve the original failure and report uncaptured early-gate invariants as `SKIP` rather than overwriting the real error.

The reusable runtime-path and teardown-status rules were promoted into the Server Management `Pre_Production_Browser_Review_Runbook.md`. The People runner was corrected to validate the Python runtime as `fieldwiring` and to preserve early preflight failures.

## Why the candidate was not affected

Both failures occurred before the People browser-preview runner captured a Production dump, created a disposable PostgreSQL clone, applied People migrations, or started the Flask preview.

The exact disposable-accepted People application/database candidate therefore remains unchanged:

```text
7cd4c02420f564c1fe563d0c12052480c6ce6f6b
```

The second attempt also proved cleanup left the selected preview port closed and Production FieldWiring healthy. A direct server listener check showed only the expected Production Setup gunicorn listener on `192.168.5.9:8794`; `8795` was not listening.

## Retry boundary

Use the corrected wrapper and an explicit non-Production candidate port, for example:

```powershell
.\People\Acceptance\run_people_manager_browser_preview.ps1 -PreviewPort 8795
```

The example does not declare `8795` permanently reserved or guaranteed free; the server-side preflight must verify it at runtime.

Wait for `BROWSER REVIEW READY` before manually opening the localhost URL. Do not use or clean Production Setup port `8794` as browser-preview state.
