# Setup Extra Material Source Containers — Production Acceptance — 2026-09-16

## Scope

This record closes Setup Issue #198 / PR #199 for Manager maintenance of reusable Setup Extra Material expected-source Containers.

The accepted application change adds:

- Manager add/change/remove controls for `ref.setup_task_extra_material_source`;
- support for any current `ref.container`, including Display Pallets, Kit Boxes, and shared-stock Containers;
- multiple source Containers per reusable task requirement;
- explicit per-source quantity and verification state;
- source quantity read-back verification after save;
- compact operator-facing quantity formatting without unnecessary `.000` scale zeroes;
- source-allocation auditing against the reusable task requirement;
- an explicit `REVIEW TASK REQUIREMENT` path when fully verified source totals disagree with the reusable requirement;
- a compact T-Post Inventory bootstrap path for assigning the first T-Post stock row to an existing Container.

No PostgreSQL schema migration was part of this deployment.

## Accepted Runtime Candidate

```text
branch       = agent/setup-198-extra-material-source-ui
accepted SHA = 5040fa282410b729d93e58a8299e48e4ee214809
PR           = #199
issue        = #198
```

The Production Setup runtime before deployment was:

```text
c3a525aa73ae99770cb8c62a6b8f0d365efd048c
```

That prior SHA remains the source-only rollback point.

## Reusable Disposable Acceptance

The exact accepted candidate passed the reusable current-Production disposable acceptance:

```text
SETUP_REUSABLE_DISPOSABLE_ACCEPTANCE_PASS
SETUP REUSABLE DISPOSABLE ACCEPTANCE: CLEAN EXIT
```

Production remained unchanged during that gate:

```text
Production Setup fingerprint before = 8663e913b8ebbdadd07d455db77e2d3f
Production Setup fingerprint after  = 8663e913b8ebbdadd07d455db77e2d3f
live Setup SHA before                = c3a525aa73ae99770cb8c62a6b8f0d365efd048c
live Setup SHA after                 = c3a525aa73ae99770cb8c62a6b8f0d365efd048c
```

Retained report:

```text
/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Acceptance_20260916T132429.txt
```

The exact candidate Setup regression at the final pre-Production gate passed:

```text
341 passed in 1.02s
SETUP_198_PRODUCTION_PREFLIGHT_PASS
```

## Disposable Browser Acceptance

The exact candidate was reviewed through the reusable disposable browser preview and exited cleanly:

```text
SETUP REUSABLE DISPOSABLE BROWSER PREVIEW: CLEAN EXIT
```

Operator acceptance verified the final source workflow was understandable and responsive:

- requirement/source editors remain collapsed until intentionally opened;
- `Add Source...` opens source maintenance;
- `Save Source` only becomes active after an actual source-field change;
- source quantities persist exactly after save/reload;
- whole-number quantities display as `16`, `18`, `66`, not scaled decimal strings;
- verified source totals visibly audit the reusable requirement;
- `Edit Requirement` remains a separate deliberate action;
- the page remained responsive after the observer-loop repair.

The Northern Lights disposable acceptance case ended at:

```text
Reusable requirement:
T-Post | 66 EA | 3 FT | Green | VERIFIED

Verified source allocation:
C16 = 16
C17 = 16
C18 = 18
C19 = 16
Total = 66

Audit:
Allocated 66 of 66 EA · BALANCED
```

## Production Source-Only Deployment

Authority:

```text
Gregovate/MSB-Server-Management
docs/server/Setup_Source_Only_Application_Deployment_Runbook.md
```

Pre-mutation state:

```text
OLD_HEAD   = c3a525aa73ae99770cb8c62a6b8f0d365efd048c
TARGET_SHA = 5040fa282410b729d93e58a8299e48e4ee214809
live worktree = clean
msb-setup.service = active
health version = V0.3.13-assignment-layer
forward ancestry = PASS
```

Controlled source-only mutation advanced only `/opt/msb-setup` to the exact accepted SHA and restarted only:

```text
msb-setup.service
```

Post-restart health:

```json
{"data_mode":"postgres","status":"ok","version":"V0.3.13-assignment-layer"}
```

Focused live regression:

```text
15 passed in 0.05s
```

The deployment itself did not mutate governed Setup data:

```text
PRE_DEPLOY_FP  = 8663e913b8ebbdadd07d455db77e2d3f
POST_DEPLOY_FP = 8663e913b8ebbdadd07d455db77e2d3f
```

Deployment result:

```text
PASS: Production Setup fingerprint unchanged
PASS: deployed exact SHA 5040fa282410b729d93e58a8299e48e4ee214809
PASS: msb-setup.service healthy
SETUP_198_SOURCE_ONLY_PRODUCTION_DEPLOY_PASS
```

No PostgreSQL migration, environment change, service-unit change, proxy/firewall change, or host reboot was part of this deployment.

## Legitimate Production Data Correction

After the source-only deployment fingerprint was proven unchanged, the Manager used the real protected Production Setup UI to correct the known Northern Lights reconstruction error.

Final accepted Production state:

```text
Reusable requirement:
T-Post | 66 EA | 3 FT | Green | VERIFIED

Expected source Containers:
C16 = 16 | VERIFIED
C17 = 16 | VERIFIED
C18 = 18 | VERIFIED
C19 = 16 | VERIFIED

C118 provisional source = removed/deactivated

Audit:
Allocated 66 of 66 EA · BALANCED
```

This correction is intentional Production business data and is not expected to preserve the pre-deployment fingerprint after the operator write.

The physical source counts exposed the stale reusable requirement: Northern Lights has 66 lights and one 3-foot green T-Post per light, so the prior 64-EA requirement was corrected deliberately to 66 rather than silently normalized by the source allocation UI.

## Operational Boundary Preserved

The accepted design keeps separate facts separate:

- reusable task requirement quantity/specification;
- expected source Container allocation;
- optional per-source quantity and verification state;
- physical Container inventory/event history.

The UI does not silently divide requirement quantity across sources, does not rewrite Container expected contents when a source is assigned, and does not automatically rewrite a reusable requirement when a source total differs.

## Rollback

For the source-only application deployment, rollback remains:

```text
c3a525aa73ae99770cb8c62a6b8f0d365efd048c
```

Rollback follows the Server Management source-only deployment runbook: detach `/opt/msb-setup` at that SHA and restart only `msb-setup.service`.

The legitimate Northern Lights Production data correction is separate operational data and should not be reverted merely because application source is rolled back.

## Closeout

With the exact runtime candidate deployed and the Production Northern Lights workflow accepted, #198 is complete. The reusable Setup Catalog cleanup gate in #145 can continue using the corrected 66-EA Northern Lights requirement and its verified four-Container source allocation.
