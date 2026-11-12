# Setup #206 V0.3.33 Manager Material Status Production Acceptance — 2026-10-01

## Status

**PRODUCTION ACCEPTED**

Owning issue: **#206 — Setup #122 Pick List / material readiness / mobilization**  
Commanding Setup issue: **#122**  
Performance cross-reference: **#222**

## Accepted application identity

```text
Production Setup SHA = e9839123e7483d7ced630b3dc6ab8f377c3f3262
Production version   = V0.3.33-material-status-review-fixes
Production mode      = postgres
```

Implementation / integration:

```text
application PR #276 merge = e81d4e2da9d84324d85f6423dca0aae831a98753
deployment tooling PR #277 merge = 893cca3fa593e75f4c41ec7e18e03aa24b6f971c
main-only deployment guard PR #278 merge = 5659de172cb5eb2abcf05e50c190a00ca775c4a7
documentation closeout PR #279 merge = e6d2659f4ee6a35cc659ae4aeddb36978844c5f9
database migration = NONE
```

This was a source-only Setup deployment. Later documentation-only commits do not redefine the deployed application identity.

## Accepted scope

The release completes the Manager Material Status launch slice and associated Pick List correction.

Accepted behavior includes:

- separate Manager Material Status screen while the Rolling Pick List remains the picker/material-handler execution surface;
- Stage / Scene / status filters plus search by Display, Container, task, location, date, and reason;
- sort by Stage / Scene, status, Pick By, Needed For, Home Location, and physical identity;
- one-item Manager Add / Edit Dates / Remove Override controls;
- schedule and Manager demand remain independent:
  - schedule + Manager override = `BOTH`;
  - schedule never replaces, deactivates, or rewrites the Manager override;
  - removing the Manager override from `BOTH` leaves schedule demand intact;
- blank Manager Needed For uses the effective Pick By date for Pick List filtering so the override does not disappear;
- Workshop / unresolved / movement-truth safety boundaries remain;
- Manager Material Status unscheduled-material resolution uses bounded batched reads instead of per-task `field_context()` calls;
- physical rows show concise deduplicated Contents rather than repeated annual task blocks;
- Unresolved is read-only on Material Status and routes correction to Material Audit;
- status-transition handling keeps an override-only item visible when Add / Remove changes its status;
- `CONT:134` removal/re-add behavior was exercised during browser acceptance and the re-added item appeared on both Manager Material Status and Rolling Pick List.

## Performance acceptance

Initial disposable browser evidence on the earlier V0.3.32 candidate:

```text
GET /api/setup/material-status
app_ms = 13222.3
active_in_worker = 1
```

The cause was repeated per-task unscheduled material resolution.

After batching, operator review reported the Manager Material Status load was much better and the request no longer emitted a `SETUP_PERF_EVENT kind=SLOW`. The #222 trace threshold for individual slow GET events is 250 ms, so the reviewed request completed below that event threshold.

Separate Material Audit requests remained about 4.7–4.8 seconds and remain open performance work under #222.

## Pre-Production acceptance

Final exact candidate:

`e9839123e7483d7ced630b3dc6ab8f377c3f3262`

Full Setup/Application regression:

```text
651 passed in 1.14s
```

Reusable current-Production disposable acceptance:

```text
SETUP REUSABLE DISPOSABLE ACCEPTANCE: CLEAN EXIT
Production Setup fingerprint before/after unchanged
Live Setup SHA before/after unchanged
Exit status = 0
```

Final browser/operator acceptance:

```text
SETUP REUSABLE DISPOSABLE BROWSER PREVIEW: CLEAN EXIT
Operator disposition = PASS
```

Browser acceptance covered:

- Material Status performance;
- search/filter/sort;
- Manager override Add / Edit / Remove;
- Pick By / Needed For date behavior;
- blank Needed For;
- `BOTH` demand behavior;
- concise Contents presentation;
- Unresolved -> Material Audit handoff;
- status-transition visibility;
- `CONT:134` removal/re-add and visibility on both Manager Material Status and Rolling Pick List.

## Production deployment

Authority:

`Gregovate/MSB-Server-Management/docs/server/Setup_Source_Only_Application_Deployment_Runbook.md`

Deployment boundary:

- no PostgreSQL schema or data migration;
- no environment change;
- no systemd unit shape change;
- no proxy/firewall change;
- only `/opt/msb-setup` advanced to the exact accepted application SHA;
- only `msb-setup.service` was restarted.

Final wrapper result:

```text
SETUP #206 V0.3.33 SOURCE-ONLY PRODUCTION DEPLOYMENT WRAPPER: PASS
```

Production evidence:

```text
Production Setup fingerprint before = 72f5e30b374631daf91e059593b37500
Production Setup fingerprint after  = 72f5e30b374631daf91e059593b37500
PASS: governed Setup data unchanged by source deployment

Final Setup SHA = e9839123e7483d7ced630b3dc6ab8f377c3f3262
Final Setup health = {"data_mode":"postgres","status":"ok","version":"V0.3.33-material-status-review-fixes"}
Exit status = 0
```

Deployment report:

`/home/msbadmin/setup-deployment-reports/Setup_206_V033_Material_Status_Source_Only_Production_Deploy_20261001T231702.txt`

## Rollback boundary

Because this deployment was source-only, the rollback unit is:

```text
prior Setup SHA = 79574e3a7d16e82ef3e045eb2c7c96cff624e4e1
+ restart msb-setup.service
```

No PostgreSQL rollback archive was required or created for this release.

## Repository closeout

The accepted application history is contained in current `main`.

The Production Deployment Change Log and Setup engineering runtime documentation were updated after deployment.

#206 is closed for this accepted scope. Remaining work stays with its existing owners:

```text
#205 = Scheduling Board post-launch defects
#222 = shared Setup performance work, including slow Material Audit
#37  = Server Management Setup maintenance/write-freeze
#88/#113/#171 = movement / scanner / GIS boundaries
```

Do not reopen #206 merely to absorb those separate workstreams.

---
