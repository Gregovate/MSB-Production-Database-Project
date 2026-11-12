# Setup Planning Summary Production Acceptance — 2026-09-15

| Document control | Value |
|---|---|
| Status | ACCEPTED PRODUCTION |
| Application | Setup |
| Issue | #122 — Planning-level printable summary / hand-markup slice |
| Implementation PR | #188 |
| Exact application candidate / deployed runtime | `70a0e9e5b9f1c4f58c86a8352685b7852f08eb5d` |
| Prior live Setup SHA | `1e0e2d2c3ffbcafc2ffef2bb4a98c81d600e8b1b` |
| Health version | `V0.3.13-assignment-layer` |
| Database migration | None — source-only application change |
| Production date | 2026-09-15 |

## Purpose

Record Production acceptance of the Issue #122 Planning Summary / hand-markup surface used to review the reusable Setup Catalog before annual scheduling and Pick List construction.

The Planning Summary is a review artifact, not a second Catalog and not an annual Setup Session. Durable corrections remain in the Setup application.

## Accepted Behavior

Manager browser review established the print packet as a scheduler-readiness / Pick-List cleanup tool rather than a generic data dump.

Accepted behavior includes:

- contextual `Print Planning Summary…`, `Print Stage`, and `Print Scene` launchers from the reusable Catalog;
- Stage, Stage + real Scene, and broader reusable-Catalog scopes;
- current Catalog **Step order** preserved in the print output;
- `Step 10`, `Step 20`, etc. terminology rather than ambiguous Display-order wording;
- Crew and Estimated setup time shown prominently;
- missing crew/duration shown explicitly as `MISSING`;
- Display-material work visibly marked `MATERIAL STEP`;
- hard predecessors labeled as required;
- no recorded predecessor shown as a review condition rather than falsely asserting that none is required;
- obvious same-scope predecessor/order conflicts surfaced for review;
- readiness kept distinct from hard predecessors;
- Equipment / Resources, Display / Container material, Kit/support Containers, Extra Materials, T-Posts, Procedure references, reusable notes, and handwriting space retained beneath scheduler-critical facts;
- prominent disposable/non-authoritative warning plus printed date/time; and
- compact landscape browser printing / Save PDF behavior.

## Browser Review Findings

The review intentionally exposed incomplete Catalog/system data rather than hiding it. Examples include missing scheduler inputs, predecessor review needs, material/source review, and the separate Kit Inventory UX gap now tracked by Issue #189 for inline creation of missing Extra Material catalog items.

Those findings remain separate cleanup work and do not invalidate the Planning Summary feature.

## Pre-Production Acceptance

The exact application candidate was exercised through the repository-owned disposable current-Production-clone browser preview.

Representative Stage 00 / HWY 42 review confirmed:

- Catalog launch controls were visible;
- the Planning Summary opened correctly;
- Step order matched the Catalog;
- scheduler-critical missing values were obvious;
- material steps were easy to identify;
- predecessor presentation was understandable; and
- the print density was suitable for hand review and materially better than one-task-per-page Perform Work output.

Manager disposition:

```text
ACCEPTED FOR PRODUCTION DEPLOYMENT GATE
```

## Source-Only Production Deployment

Server authority:

```text
Gregovate/MSB-Server-Management
Docs/server/Setup_Source_Only_Application_Deployment_Runbook.md
```

Pre-deployment state:

```text
OLD_HEAD = 1e0e2d2c3ffbcafc2ffef2bb4a98c81d600e8b1b
service  = active
health   = {"data_mode":"postgres","status":"ok","version":"V0.3.13-assignment-layer"}
```

Exact candidate proof:

```text
TARGET_EXISTS=PASS
FORWARD_ANCESTRY=PASS
```

Detached exact-candidate regression:

```text
307 passed in 1.05s
```

The live detached Setup checkout was advanced to:

```text
70a0e9e5b9f1c4f58c86a8352685b7852f08eb5d
```

Only `msb-setup.service` was restarted.

Post-restart health:

```text
{"data_mode":"postgres","status":"ok","version":"V0.3.13-assignment-layer"}
LIVE_HEALTH=PASS
```

Focused live regression from `/opt/msb-setup`:

```text
307 passed in 1.06s
```

## Production Data Invariant

The source-only deployment captured the governed Setup fingerprint before and after deployment, before any legitimate operator edits.

```text
PROD_BEFORE = 4b1cf9d0ad3e53ff24617cde59ad0454
PROD_AFTER  = 4b1cf9d0ad3e53ff24617cde59ad0454
PRODUCTION_FINGERPRINT=PASS
```

No PostgreSQL migration was applied and no real 2026 Setup Session was created by this change.

## Protected Production Browser Acceptance

The operator reviewed the real protected Production route:

```text
https://my.sheboyganlights.org/setup/
```

Acceptance covered the contextual print launchers, Stage 00 / HWY 42 Step ordering, crew/time missing-data emphasis, `MATERIAL STEP` treatment, predecessor presentation, disposable warning/date, and browser Print / Save PDF usability.

Operator disposition:

```text
PASS
```

## Rollback Boundary

This is a source-only Setup change. If rollback is required for this feature, return `/opt/msb-setup` to:

```text
1e0e2d2c3ffbcafc2ffef2bb4a98c81d600e8b1b
```

and restart only `msb-setup.service` under the Setup Source-Only Application Deployment Runbook. No PostgreSQL restore belongs to this rollback boundary.

## Final Acceptance

The Planning Summary print / hand-markup slice is accepted in Production.

Issue #122 remains open for the remaining Setup Session work, including final reusable-Catalog acceptance sequencing, annual scheduling, Pick List generation, execution/movement integration, and later field workflows.

Issue #189 separately owns the Kit Inventory UX defect exposed during this review: Managers need an inline way to create a missing normalized Extra Material catalog family while adding expected Kit contents.
