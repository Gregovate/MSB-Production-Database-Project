# Setup Task Detail Compact Layout — Production Acceptance — 2026-09-11

| Document Control | Value |
|---|---|
| Document Type | Production Acceptance Record |
| System | Production Database — Setup Session |
| Status | ACCEPTED PRODUCTION |
| Owner | MSB Production Database engineering |
| Accepted application SHA | `2eee967b6c5359c0e2e2d876a2fe44af8359315c` |
| Accepted version | `V0.3.8-task-detail-compact` |
| Repository merge | PR #160 / merge commit `d882bb33785321de9a6a880347521adf9518502e` |
| Prior accepted runtime | `9d0c31421ce7cbd1b1cbcf733b06198ace418e9d` / `V0.3.7-catalog-dirty-edit-followup` |

## Purpose

Preserve the accepted Production evidence for Issue #153 so the V0.3.8 task-detail layout, deployment facts, fingerprint baseline, and final operator acceptance do not depend on chat history or issue comments.

This was a source-only Setup application deployment. It did not include a database migration, schema change, authorization change, Plan / Schedule behavior change, or Production data migration.

## Accepted UI Behavior

At normal laptop/desktop width the task-detail editor is organized as two independent vertical rails:

```text
LEFT                               RIGHT
Reusable Task Definition            Annual Historical Actual
Material / Logistics                Captains / Knowledge Owners
```

Accepted behavior:

- the reusable task editor remains a compact two-column editor inside the left rail;
- **Material / Logistics** follows immediately beneath the reusable definition instead of spanning the full page below both rails;
- the four essential material counts remain visible in the compact summary;
- **View Material Details** remains available for the full resolved Display / Container detail and reasons;
- **Annual Historical Actual** remains in the right rail;
- **Captains / Knowledge Owners** remains immediately below Annual Historical Actual;
- Prerequisites and Equipment / Resources remain below the rail block and are reachable with materially less scrolling; and
- the layout-only stylesheet does not introduce a new independent color palette.

Cross-application palette and dark-mode logo standardization are deliberately separate work under Issue #159.

## Disposable Browser Acceptance

Final accepted browser/deployment candidate:

```text
2eee967b6c5359c0e2e2d876a2fe44af8359315c
```

Final laptop browser review confirmed:

- visible `Client V0.3.8`;
- compact reusable editor;
- independent left/right rails;
- Material / Logistics beneath Reusable Task Definition;
- Annual Historical Actual plus Captains / Knowledge Owners in the right rail;
- no large dead area beneath the reusable editor;
- Material Details remained functional; and
- light/dark readability was acceptable for Issue #153.

Physical mobile-device acceptance was **not** performed. Responsive stacking is covered by the implementation/contract and a narrowed-desktop-browser proxy only. Do not claim physical mobile acceptance from this record.

Two earlier preview attempts stopped before browser startup because of acceptance-contract false positives. Both teardown checks proved Production and the live Setup checkout remained unchanged. The final accepted candidate above contains the corrected contracts and refined rail layout.

## Production Pre-Mutation Gate

Immediately before source-only deployment:

```text
live Setup SHA                     = 9d0c31421ce7cbd1b1cbcf733b06198ace418e9d
accepted target                    = 2eee967b6c5359c0e2e2d876a2fe44af8359315c
forward ancestry                   = PASS
live Setup worktree                = clean
exact detached candidate regression = 53 passed in 0.24s
REGRESSION_RC                      = 0
PRE_MUTATION_GATE                  = PASS
Production fingerprint             = 9510360aa7de2da59d1ed8a9ad9d69f7
```

No Production mutation had occurred at this gate.

## Source-Only Production Deployment

Only the detached Setup worktree advanced:

```text
OLD_HEAD   = 9d0c31421ce7cbd1b1cbcf733b06198ace418e9d
TARGET_SHA = 2eee967b6c5359c0e2e2d876a2fe44af8359315c
```

Checkout verification passed with a clean worktree.

Only:

```text
msb-setup.service
```

was restarted.

No PostgreSQL migration was applied and no database dump restore was required.

## Runtime / Regression Evidence

Post-restart health:

```json
{"data_mode":"postgres","status":"ok","version":"V0.3.8-task-detail-compact"}
```

Focused live deployed regression:

```text
53 passed in 0.24s
LIVE_REGRESSION_RC=0
```

Protected route health also returned `V0.3.8-task-detail-compact`.

## Production Fingerprint Evidence

The source-only deployment did not change the Setup Production data covered by the deployment fingerprint:

```text
PROD_BEFORE = 9510360aa7de2da59d1ed8a9ad9d69f7
PROD_AFTER  = 9510360aa7de2da59d1ed8a9ad9d69f7
DEPLOYMENT_FINGERPRINT = PASS
```

This fingerprint records equality across the source-only deployment. It is not a permanent promise that later legitimate Manager activity will never change Production data.

## Final Protected Production Browser Acceptance

The real protected Production application was opened after deployment:

```text
https://my.sheboyganlights.org/setup/
```

Final operator validation passed:

- visible `Client V0.3.8`;
- left rail = Reusable Task Definition -> Material / Logistics;
- right rail = Annual Historical Actual -> Captains / Knowledge Owners;
- Prerequisites / Resources remain below without the prior dead space; and
- final laptop layout matched the accepted disposable-browser candidate.

No special Production data write was required for final Issue #153 acceptance.

## Recent Runtime Lineage

The immediate prior accepted runtime was Issue #154 V0.3.7:

```text
9d0c31421ce7cbd1b1cbcf733b06198ace418e9d
V0.3.7-catalog-dirty-edit-followup
```

That release fixed the unsafe reusable-edit / `Mark Verified` path after the earlier V0.3.6 candidate failed real Production acceptance and was rolled back. V0.3.8 preserves the accepted V0.3.7 dirty-edit and client/server build-match protections while changing task-detail presentation.

## Deliberate Follow-Ups / Deferrals

Issue #153 does not absorb unrelated work discovered during acceptance:

- Issue #159 remains open for cross-application light/dark palette and dark-mode white-logo consistency.
- Setup Google Doc migration from `Archive` to authoritative `SourceDocs` was documented separately in Issue #161 / PR #162 and is now closed completed.
- physical mobile-device acceptance was not performed for V0.3.8.

## Related Authority

- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/Setup_Session_Production_Engineering_Handoff_2026-09-11.md`
- `Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/README.md`
- Issue #153 — compact Setup task-detail / Material layout
- Issue #154 — dirty-edit / Mark Verified safety
- Issue #159 — cross-application theme/logo consistency
- PR #160 — V0.3.8 implementation lineage
