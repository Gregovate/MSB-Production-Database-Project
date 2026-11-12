# Controller Production Preflight Acceptance Evidence — 2026-09-02

| Item | Value |
|---|---|
| Status | **PASS — READY FOR EXPLICIT PRODUCTION DEPLOYMENT GATE** |
| Issue | #110 |
| Draft PR | #111 |
| Accepted application target | `2fd2067958cc0a903260fe6f089f88ae63a857f1` |
| Verified production baseline | `e9ab029a17067b38b34f9306069f54899925f73f` |
| Preflight runner | `Controllers/Acceptance/run_controller_setup_management_production_preflight.ps1` |
| Production database mutation | NONE |
| Production checkout movement | NONE |
| Production service restart | NONE |

## Purpose

Record the successful production-side preflight for the accepted Controller setup-capacity planner and browser-maintenance candidate before any production mutation is authorized.

This preflight exercised the same live-server prerequisites required by the production deployment runbook while deliberately stopping before migration application, checkout movement, or service restart.

## Production Baseline

Verified live shared checkout:

```text
e9ab029a17067b38b34f9306069f54899925f73f
```

Preflight health:

```text
FieldWiring = {"data_mode":"postgres","status":"ok","version":"V0.3.3"}
Procedures  = {"data_mode":"postgres","status":"ok","version":"V0.1.0"}
```

Production Controller fingerprint before preflight:

```text
578217bcb18e1291ceced673a3de3b27
```

## Exact Accepted Target / Ancestry

Accepted application target:

```text
2fd2067958cc0a903260fe6f089f88ae63a857f1
```

The live production checkout was proven to be a fast-forward ancestor of that exact target:

```text
e9ab029a17067b38b34f9306069f54899925f73f
    ->
2fd2067958cc0a903260fe6f089f88ae63a857f1
```

Result:

```text
Verified fast-forward ancestry
```

## Detached Production-Runtime Regression

The exact accepted target was checked out into a detached production-side worktree and tested with the production Python environment.

Result:

```text
231 passed in 2.59s
DETACHED CANDIDATE REGRESSION: PASS
```

No production checkout movement occurred.

## Rollback Archive Path Test

The preflight created and structurally validated a real custom-format PostgreSQL rollback archive using the same production backup path and direct-stdin validation method required by the deployment runbook.

Temporary archive:

```text
/home/msbadmin/backups/postgres/msb-preflight-controller-setup-management-20260903T031255.dump
```

SHA256:

```text
b3b935e6bc52f69ae953ea9ce8c1896867a03a54686e36ac7ebe0c5d08088c36
```

Result:

```text
ROLLBACK ARCHIVE TEST: PASS
```

The temporary preflight archive was removed during cleanup after validation. The actual production deployment will create and retain its own uniquely named rollback archive before database mutation.

## Production Database Preflight

The production database preflight ran read-only and passed.

It confirmed:

- deployed Controller browser functions 021/022 exist;
- Controller management functions from candidate migrations 023/024 are not already installed;
- `fieldwiring_app` does not have broad INSERT/UPDATE/DELETE privileges on governed Controller tables;
- the exact accepted target contains the required migration files.

Result:

```text
DATABASE PREFLIGHT: PASS
```

## Negative Security Check

A direct request without Cloudflare Access identity returned the expected protected-path error:

```json
{"engineering_error":"Cloudflare Access operator identity is missing","error":"Cloudflare Access identity is required for Controller management."}
```

The preflight therefore confirmed the protected Controller-management boundary remained active before deployment.

## Deliberate Stop Point

The preflight reached the explicit non-mutation stop point:

```text
PRODUCTION PREFLIGHT STOP POINT REACHED
No migrations applied. No checkout movement. No service restart.
CONTROLLER SETUP + MANAGEMENT PRODUCTION PREFLIGHT: PASS
CONTROLLER SETUP + MANAGEMENT PRODUCTION PREFLIGHT WRAPPER: PASS
```

No candidate migration was installed and the production application checkout remained unchanged.

## Production Safety After-Check

Production Controller fingerprint after preflight:

```text
Before: 578217bcb18e1291ceced673a3de3b27
After:  578217bcb18e1291ceced673a3de3b27
PASS: production Controller fingerprint unchanged
```

Preflight report retained on `msb-prod-db`:

```text
/tmp/MSB_Controller_Setup_Management_Production_Preflight_20260903T031255.txt
```

## Current Gate State

The Controller setup-capacity planner and browser-maintenance implementation has now passed:

1. exact-candidate application regression;
2. live production read-only planner/UID/SPARE probe;
3. current-production disposable-clone migrations and Controller write lifecycle acceptance;
4. production deployment preflight including rollback-archive path validation and live negative security check.

The remaining step is the **explicit production deployment gate** governed by the active MSB Server Management Production Database Change Deployment Runbook.

Production deployment is not authorized by this document alone. It requires explicit operator approval before running:

```text
Controllers/Acceptance/run_controller_setup_management_production_deploy.ps1
```
