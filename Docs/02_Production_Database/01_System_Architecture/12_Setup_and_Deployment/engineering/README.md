# Setup and Deployment Engineering

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff Portal |
| System | Production Database — Setup and Deployment |
| Audience | Greg, maintainers, database administrators, future engineering sessions |
| Status | CURRENT HANDOFF — real 2026 Setup Session live; Perform Work / Report Work / Report Correction Production accepted |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-27 |

Operator-facing instructions are separate under [`../operatorSOP/`](../operatorSOP/README.md).

## 2026 Launch Status

The real 2026 Setup Session has been created and is now the active annual planning/execution context. The initial accepted Scheduling Board launch target was `06a6536d92db5c7352beeed496563ed9bfdb7146`. The current Production runtime is `fc0b76d57826eebf04b81c99cbb904109162cd87` (`V0.3.19-pick-list`), with the rolling #206 Pick List, #175 Perform Work / #132 Report Work, and #172 Report Correction accepted and migrations 060 + 061 + 062 installed.

The launch deployment installed migrations 057/058 after the exact candidate passed the full Setup/Application regression (458/458) and disposable browser acceptance. The Scheduling Board preserves the accepted Catalog/Plan ordering, lavender material-task cue, Day-view filters, completed/cancelled-day handling, performance improvements, and current scheduling behavior.

The Work Day calendar is collapsed by default so it does not consume scheduling space. **+ Add Work Days** is a visually primary action; its calendar supports tablet-friendly click/tap multi-select without Ctrl/Shift, disables dates that already exist, and does not overwrite existing Work Days.

The durable boundary remains:

```text
Reusable Catalog = recurring Setup knowledge
2026 annual Session = this season's planning/execution set
season-only work = 2026 only unless explicitly promoted
actual work/history = preserved operational evidence
```

Broad Work Day deletion was not introduced. #206 / PR #216 delivered the Production rolling physical Pick List and early-demand resolution. #206 remains open for tablet validation, full-season / Master material-list scope, movement planning, and named park-location/GIS handoff; those responsibilities must not be folded back into the Scheduling Board.


## #145 Material Completeness / Catalog Gate — COMPLETE

Issue #145 is complete and closed. The Manager Material Completeness Audit, Display/LOR ownership correction paths, reviewed shared/non-task Kit disposition, and reconstruction-safe Delete Task behavior were Production accepted before the real 2026 annual launch. The durable audit contract remains documented in [Setup_Material_Completeness_Audit_2026-09-20.md](Setup_Material_Completeness_Audit_2026-09-20.md).

The real 2026 Setup Session has since been created under #122 and is live. Material Audit remains a Manager correction/review tool during the season; it is no longer a pre-creation gate for the already-existing 2026 Session.

## Current Production State

```text
protected application = https://my.sheboyganlights.org/setup/
initial Scheduling Board launch target = 06a6536d92db5c7352beeed496563ed9bfdb7146
current live Setup SHA = fc0b76d57826eebf04b81c99cbb904109162cd87
version = V0.3.19-pick-list
current accepted migrations = 059 reusable task-name synchronization + 060 Pick List Manager override + 061 Report Work + 062 Report Correction Intake
deployment-closeout Setup business fingerprint = a779cc9f77adde416a0b8a78f40e9b70
current annual reusable-name mismatches = 0
2025 Setup Session = historical / verification evidence
2026 Setup Session = LIVE annual planning/execution context
```

Historical governed Setup fingerprint from the #204 source-only deployment:

```text
7dd32f21ca9a455329de54e8799f01b5
```

## Accepted Reusable Expected Duration UI — #204

Managers now enter reusable expected duration as **Expected hrs** plus **Expected mins (0–59)** while the durable field remains `expected_duration_minutes`.

Stored total minutes are split for operator review and recombined on save through the existing governed reusable-task PATCH / `ref.update_setup_task` path. Both controls blank preserve NULL/missing. The minute control is a remainder, not a second total-duration field. Annual `actual_duration_minutes` and #132 progress-report semantics are unchanged.

Accepted runtime candidate: `052d31dd4e68e13f2997f723778b88eddf9c53cf`.

## Accepted Assignment / Kit Relationship Contract

LOR remains authoritative for current Stage/real-Scene Display membership. Display Ownership provides one effective reusable task owner when a scope has several material-bearing tasks and never rewrites LOR or `ref.display.container_id`.

Physical Kit Boxes are existing `ref.container` rows. Reusable task -> Kit assignment remains many-to-many through:

```text
ref.setup_task_container_support
relationship_type = 'KIT'
```

The same Kit may support several reusable tasks. Existing SUPPORT / REQUIRED_CONTAINER semantics remain separate.

## Durable Extra Material / Inventory Contract — #184

Issue #184 / PR #185 is complete and merged. The permanent Production subsystem owns:

```text
ref.setup_extra_material                     normalized catalog
ref.setup_task_extra_material                reusable task requirement
ref.setup_task_extra_material_source         expected source allocation
ref.setup_container_extra_material           expected Container / Kit content
ref.setup_container_extra_material_review    Remainders / Unverified Items
ops.setup_extra_material_inventory_event     append-only physical event history
ops.setup_extra_material_inventory_balance   current physical balance view
```

Application surfaces:

```text
Reusable task detail: Extra Materials Required by This Task
/setup/kit-inventory/
/setup/t-post-inventory/
```

Permanent semantic separation:

```text
what task requires
!= what a Kit/Container should contain
!= where material is physically stored
!= what was physically counted
!= current Display -> Container membership
```

Manager-maintained expected definitions do not create inventory counts. Inventory events do not rewrite expected definitions. Physical T-Post storage may legitimately be shared/bulk or stored with a Kit/Display; storage does not assign task requirement ownership.

## Completed One-Time Reconstruction — #167

Issue #167 / PR #187 now owns historical closeout only. The accepted one-time candidate was:

```text
1e0e2d2c3ffbcafc2ffef2bb4a98c81d600e8b1b
```

Production one-time migrations:

```text
038
043
044
045
046
047
048
```

They loaded reviewed legacy-procedure/normalization evidence into the durable #184 structures without creating a 2026 Session, physical inventory events, or competing task-to-Kit relationships. Current Production Kit assignments were preserved unchanged. Unknown/conflicting values remain `UNVERIFIED` / `NEEDS_REVIEW` or durable Remainders.

Disposable acceptance:

```text
SETUP_REUSABLE_DISPOSABLE_ACCEPTANCE_PASS
Production fingerprint before/after = 6b7e34a06ca82a2b9a2eb04a41b1e130 unchanged
live Setup SHA before/after = 9761cf91596a35c732acec3ed7872271f7f16d2a unchanged
report = /home/msbadmin/setup-acceptance-reports/Setup_Disposable_Acceptance_20260915T003934.txt
```

Production acceptance:

```text
SETUP_167_PRODUCTION_RECONSTRUCTION_PASS
live regression = 298 passed
FINAL LIVE SHA = 1e0e2d2c3ffbcafc2ffef2bb4a98c81d600e8b1b
2026 Setup Sessions = 0
physical inventory events = 0
protected core fingerprint before/after = adc431f96b5622e125bf44d96e3d7807 unchanged
rollback archive = /home/msbadmin/backups/setup-167/msb-pre-setup-167-reconstruction-20260915T005504.dump
targeted pre-image = /home/msbadmin/backups/setup-167/msb-pre-setup-167-target-tables-20260915T005504.dump
report = /home/msbadmin/setup-deployment-reports/Setup_167_Kit_Inventory_Reconstruction_Production_Migrate_20260915T005504.txt
```

A prior Production attempt failed only because the deployment harness checked `/tpost-inventory/` instead of the real `/t-post-inventory/`. The fail-closed runner restored both the live checkout and the targeted tables; marker counts returned to zero. The harness is now contract-tested against that route typo.

## Preservation Baseline

Preserve:

```text
V0.3.7  dirty-edit/client-build safety
V0.3.8  compact task-detail layout
V0.3.9  Shift-drag prerequisite + canonical prerequisite editor
V0.3.10 reusable Resource Catalog
031      task-resource upsert named-constraint repair
V0.3.11 persistent active-task identity
V0.3.13 Display ownership + physical Kit Box assignment
#184     durable Extra Material / Kit Inventory / T-Post subsystem
#167     accepted one-time reconstructed data now resident in #184 structures
#204     reusable expected duration entered as Hours / Minutes; stored as total minutes
```

Also preserve the Stage/Scene resolver, the 2025 historical/verification boundary, current Display/Container authority, narrow governed write commands, and the existing analytics integration/privacy boundary. The real 2026 Session is now live; do not recreate it or reintroduce pre-launch assumptions that treat 2025 as the current planning context.

## Accepted Report Correction / Work Order Intake — #172

Issue #172 / PR #236 is Production accepted.

The live field-execution path is:

```text
Perform Work
  -> Report Correction
  -> PostgreSQL authoritative Setup context preparation
  -> protected Setup backend
  -> Directus Work Order Intake create
  -> existing items.create triage-email Flow
  -> Manager triage
```

The reporter supplies the concise finding and may optionally add suggested correction/evidence. The application preserves the exact scheduled assignment, annual/reusable task identities, Setup Day/date/shift/Crew/Captain, Stage/Scene, current Procedure identity when available, authenticated reporter, and submission timestamp.

Report Correction does not create an active Work Order directly and does not grant Production Crew Manager-level mutation authority.

Real protected-route Production validation created Work Order Intake #60 and confirmed the existing Manager triage email fired.

Acceptance record:

[Setup #172 Report Correction Production Acceptance — 2026-09-27](../../../../../Setup/Acceptance/Setup_172_Report_Correction_Production_Acceptance_2026-09-27.md)

## Current Post-Launch Sequence

#145, #184, and #167 are complete, and the real 2026 Setup Session is live. #122 remains the commanding Setup issue. Remaining work resumes from real 2026 annual/schedule identities:

```text
#175 Captain Work List / Procedure context — PRODUCTION ACCEPTED / CLOSED
#132 Report Work — PRODUCTION ACCEPTED / CLOSED
#172 Report Correction / field observation intake — PRODUCTION ACCEPTED / CLOSEOUT
#206 Pick List / material readiness — existing remaining scope
#222 performance protection in parallel
#219 / GIS / writable movement later where required
```

Do not recreate the annual Session, revive disposable pre-launch scheduler assumptions, or move #206 physical-demand logic into the Scheduling Board.

## Runtime / Rollback

Server/runtime authority remains `Gregovate/MSB-Server-Management`.

The accepted #184 and #167 rollback archives are retained. Restoration is a governed database operation and must reconcile legitimate post-deployment work; do not use those archives as casual UI rollback points.

The current live Setup application is `fc0b76d57826eebf04b81c99cbb904109162cd87` (`V0.3.19-pick-list`). #172 installed migration 062 after exact-candidate regression, disposable acceptance, browser acceptance, bounded Production deployment, and real protected-route Work Order Intake/email validation. The validated #172 rollback archive is `/home/msbadmin/backups/setup-172/msb-pre-setup-172-20260928T005954.dump` (SHA256 `fe0d349a587ec0363cb69bb295618c49ab8df771ff9bcb8bf9c0e71c66b8b89a`). Because migration 062 is installed, source-only checkout rollback is not a complete #172 rollback. Use the Production Database change runbook and reconcile legitimate post-deployment Intake/Setup work before restoring or removing database state. Older #206/#175/#132/#184/#167/#204 rollback evidence remains historical recovery evidence for those deployments.

## Resume Checklist

Before the next Setup change:

1. refresh current remote `main` and record exact HEAD;
2. read Project Rules and this engineering portal;
3. read `Setup_Session_Production_Engineering_Handoff_2026-09-12.md`;
4. read `Setup_Task_Supporting_Information_Contract_2026-09-11.md`;
5. preserve accepted V0.3.7 through V0.3.13 plus #184/#167 inventory behavior/data;
6. use the live 2026 Session for annual planning/execution and retain 2025 only as historical/verification evidence;
7. preserve the accepted Scheduling Board, Perform Work / Report Work, and Report Correction -> Work Order Intake boundaries;
8. keep #206 Pick List/material-demand work in its owning workstream;
9. use `Gregovate/MSB-Server-Management` for runtime/deployment/browser-review authority; and
10. update controlled docs and acceptance evidence whenever accepted behavior or the resume point changes.

## Related Systems

- [Setup operator portal](../README.md)
- [Operator procedures](../operatorSOP/README.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [Kit Inventory / T-Post Production Acceptance](../../../../../Setup/Acceptance/Setup_Kit_Inventory_TPost_Production_Acceptance_2026-09-15.md)
- [#172 Report Correction Production Acceptance](../../../../../Setup/Acceptance/Setup_172_Report_Correction_Production_Acceptance_2026-09-27.md)
- [#175 / #132 Perform Work + Report Work Production Acceptance](../../../../../Setup/Acceptance/Setup_175_132_Report_Work_Production_Acceptance_2026-09-26.md)
- [Setup Assignment Layer V0.3.13 Production Acceptance](../../../../../Setup/Acceptance/Setup_Assignment_Layer_V0313_Production_Acceptance_2026-09-12.md)


## #205 Scheduling Board

- [Setup Scheduling Board Contract — 2026-09-17](Setup_Scheduling_Board_Contract_2026-09-17.md) — Production-accepted annual Day Number/DOW board, crew/shift scheduling, season-only annual work, Work Order gates, historical assignment stickiness, and reusable-learning boundary.
