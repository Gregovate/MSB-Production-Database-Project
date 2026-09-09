# People Manager Browser Preview Preflight Failure — 2026-09-09

| Item | Value |
|---|---|
| Status | **PREVIEW NOT STARTED — HARNESS CORRECTED BEFORE RETRY** |
| Exact accepted People candidate | `7cd4c02420f564c1fe563d0c12052480c6ce6f6b` |
| Failed wrapper | `People/Acceptance/run_people_manager_browser_preview.ps1` |
| Selected/default port | `8794` |
| Production database mutation | NONE |
| Disposable clone created | NO |
| People migrations applied | NO |
| Preview Flask application started | NO |

## Failure

The first People Manager pre-production browser-review launch used an older Controller-era launcher pattern that silently defaulted to TCP port `8794` and auto-opened the workstation browser before the remote preview was ready.

Current Server Management runtime authority shows that `192.168.5.9:8794` is the permanent Production Setup listener. The stale-preview cleanup therefore failed closed when it found that listener:

```text
FAIL: TCP port 8794 is still listening after People preview cleanup
LISTEN ... 192.168.5.9:8794
```

The cleanup did not remove or replace the listener.

## Why the candidate was not affected

The failure occurred during stale-preview cleanup, before the uploaded bundle was promoted into the normal preview path and before the People browser-preview server runner performed its Production dump, disposable clone restore, candidate migrations, or Flask startup.

The exact disposable-accepted People application/database candidate therefore remains unchanged and remains:

```text
7cd4c02420f564c1fe563d0c12052480c6ce6f6b
```

## Governing correction

The later Setup browser-review implementation already established the safer launcher behavior:

- `PreviewPort` is mandatory;
- `8794` is explicitly rejected because it is the live Production Setup listener; and
- the browser is not auto-opened before the remote runner reports browser-review readiness.

Those rules were promoted into the generic Server Management `Pre_Production_Browser_Review_Runbook.md` on 2026-09-09 and the People browser-review wrapper/cleanup path was corrected to consume them.

The corrected People launch now requires an explicit non-Production candidate port. The remote preflight remains responsible for proving that the selected port is actually unused before any preview startup.

## Retry boundary

The next browser-review attempt must use the corrected wrapper and an explicit non-Production candidate port, for example:

```powershell
.\People\Acceptance\run_people_manager_browser_preview.ps1 -PreviewPort 8795
```

The example does not declare `8795` permanently reserved or guaranteed free; the server-side preflight must verify it at runtime.

Do not use or clean Production Setup port `8794` as browser-preview state.
