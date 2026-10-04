# Setup and Deployment Engineering

| Document Control | Value |
|---|---|
| Document Type | Engineering Handoff Portal |
| System | Production Database — Setup and Deployment |
| Audience | Greg, maintainers, database administrators, future engineering sessions |
| Status | CURRENT HANDOFF — V0.3.38 migration 069 Production accepted; presentation closeout pending |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-10-04 |

Operator-facing instructions are separate under [`../operatorSOP/`](../operatorSOP/README.md).

Repository-wide Production deployment history is maintained newest-first in [`../../../../../../System_Documentation/Production_Deployment_Change_Log.md`](../../../../../../System_Documentation/Production_Deployment_Change_Log.md).

## Current migration 069 / V0.3.38 evidence

[Controlled migration 069 record](../../../../../Setup/Acceptance/Setup_205_Migration_069_Deployment_Record.md): exact accepted/deployed identities, validated backup/hash, server maintenance PASS and Greg's protected browser PASS. Work Day sequence repair, Historical Day Add, noted empty-day removal, passive audit and milestones are accepted. The footer-date and dashboard wrapping/stage corrections are source-only presentation closeout, with installation still pending. Do not rerun migration 069.

[Install a reviewed Setup change](../../../../../Setup/operatorSOP/Install_a_Reviewed_Setup_Change.md) provides the current plain-language procedure. Every UI candidate must pass the visible date check before deployment; every resumed chat must read the current server runbook and release record. Historical sections below remain evidence, not current runtime instructions.

## 2026 Launch Status

The real 2026 Setup Session has been created and is now the active annual planning/execution context. The initial accepted Scheduling Board launch target was `06a6536d92db5c7352beeed496563ed9bfdb7146`. As of 2026-10-04, the current Production runtime is `e2f58d016f015f1ac695940e9ab67c61c04a8a8a` (`V0.3.38-setup-day-milestones`). The accepted Setup surface includes #205 rolling Scheduling Board/Captain dispatch, #206 bounded Pick List demand/frontier + transient Pick Delay, #88 persisted movement capture, #175 Perform Work / #132 Report Work, and #172 Report Correction. The migration tail now includes 063 Pick List Delay, 064 Extra Material requirement restore, 065 Setup movement capture, and 066 Manager override cancel-after-movement correction.

The launch deployment installed migrations 057/058 after the exact candidate passed the full Setup/Application regression (458/458) and disposable browser acceptance. The Scheduling Board preserves the accepted Catalog/Plan ordering, lavender material-task cue, Day-view filters, completed/cancelled-day handling, performance improvements, and current scheduling behavior.

The Work Day calendar is collapsed by default so it does not consume scheduling space. **+ Add Work Days** is a visually primary action; its calendar supports tablet-friendly click/tap multi-select without Ctrl/Shift, disables dates that already exist, and does not overwrite existing Work Days.

The durable boundary remains:

```text
Reusable Catalog = recurring Setup knowledge
2026 annual Session = this season's planning/execution set
season-only work = 2026 only unless explicitly promoted
actual work/history = preserved operational evidence
```

Broad Work Day deletion was not introduced. #206 now owns the completed Production Pick List demand/frontier and Pick Delay behavior. Persisted physical pick/movement execution has been handed to #88; scanner/tablet plumbing remains #113; GIS/location interpretation remains #171; Manager reference/Home Location maintenance remains #230. Do not fold those responsibilities back into #206 or the Scheduling Board.


## #145 Material Completeness / Catalog Gate — COMPLETE

Issue #145 is complete and closed. The Manager Material Completeness Audit, Display/LOR ownership correction paths, reviewed shared/non-task Kit disposition, and reconstruction-safe Delete Task behavior were Production accepted before the real 2026 annual launch. The durable audit contract remains documented in [Setup_Material_Completeness_Audit_2026-09-20.md](Setup_Material_Completeness_Audit_2026-09-20.md).

The real 2026 Setup Session has since been created under #122 and is live. Material Audit remains a Manager correction/review tool during the season; it is no longer a pre-creation gate for the already-existing 2026 Session.

## Current Production State

```text
protected application = https://my.sheboyganlights.org/setup/
initial Scheduling Board launch target = 06a6536d92db5c7352beeed496563ed9bfdb7146
current live Setup SHA = e2f58d016f015f1ac695940e9ab67c61c04a8a8a
version = V0.3.38-setup-day-milestones
current accepted migration tail = 063 Pick List Delay + 064 Extra Material requirement restore + 065 Setup movement capture + 066 Manager override cancel-after-movement correction + 067 governed Annual Readiness hold command
current preservation proof = migration069 retained report; online business data continues changing
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
#172 Report Correction / field observation intake — PRODUCTION ACCEPTED / CLOSED
#205 Scheduling Board / Captain dispatch — migration069 PRODUCTION ACCEPTED / presentation closeout pending
#206 Pick List / material readiness / Pick Delay — PRODUCTION ACCEPTED / CLOSEOUT COMPLETE
#88 persisted PICKED/movement execution — ACTIVE LAUNCH GATE
#222 performance protection in parallel
#219 / GIS / writable movement later where required
```

Do not recreate the annual Session, revive disposable pre-launch scheduler assumptions, or move #206 physical-demand logic into the Scheduling Board.

## Runtime / Rollback

Server/runtime authority remains `Gregovate/MSB-Server-Management`.

The accepted #184 and #167 rollback archives are retained. Restoration is a governed database operation and must reconcile legitimate post-deployment work; do not use those archives as casual UI rollback points.

The current live Setup application is `e2f58d016f015f1ac695940e9ab67c61c04a8a8a` (`V0.3.38-setup-day-milestones`). The migration 069 archive/hash and accepted report are in the controlled record linked above. The V0.3.34 material below is historical rollback evidence. V0.3.34 installed migration 067 and therefore has a migration-aware rollback boundary. The validated pre-deployment archive is `/home/msbadmin/backups/setup-205/msb-pre-setup-205-v034-20261002T005512.dump` with SHA256 `7d2017c6f55993b7464d10ccbd3b80f0fe85ff1fac866f6521d63e50b1e01f66`; governed Setup fingerprint remained `9951600040f7b01c75b8c104b4ddeb8c` through deployment. Use the Production Database change runbook for any rollback or recovery; do not treat a source checkout rollback as sufficient across migration 067. Older #206/#88/#172/#175/#132/#184/#167/#204 rollback archives remain historical recovery evidence for the releases that created them.

## Resume Checklist

Before the next Setup change:

1. refresh current remote `main` and record exact HEAD;
2. read Project Rules and this engineering portal;
3. read `Setup_Session_Production_Engineering_Handoff_2026-09-12.md`;
4. read `Setup_Task_Supporting_Information_Contract_2026-09-11.md`;
5. preserve accepted V0.3.7 through V0.3.13 plus #184/#167 inventory behavior/data;
6. use the live 2026 Session for annual planning/execution and retain 2025 only as historical/verification evidence;
7. preserve the accepted Scheduling Board, Perform Work / Report Work, and Report Correction -> Work Order Intake boundaries;
8. treat #206 Pick List/Pick Delay as accepted Production behavior and put persisted physical pick/movement execution under #88;
9. use `Gregovate/MSB-Server-Management` for runtime/deployment/browser-review authority; and
10. update controlled docs and acceptance evidence whenever accepted behavior or the resume point changes.

## Related Systems

- [Setup operator portal](../README.md)
- [Operator procedures](../operatorSOP/README.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [Kit Inventory / T-Post Production Acceptance](../../../../../Setup/Acceptance/Setup_Kit_Inventory_TPost_Production_Acceptance_2026-09-15.md)
- [#206 V0.3.33 Manager Material Status Production Acceptance](../../../../../Setup/Acceptance/Setup_206_V033_Manager_Material_Status_Production_Acceptance_2026-10-01.md) — current #206 Manager Material Status / Manager override / Pick List Needed For / performance-batching source-only Production acceptance.
- [#206 V0.3.22 Pick List Delay Production Acceptance](../../../../../Setup/Acceptance/Setup_206_V0322_Pick_List_Delay_Production_Acceptance_2026-09-30.md) — historical bounded material frontier / transient Pick Delay / automatic schedule-release acceptance.
- [#205 Scheduling Board / Captain Dispatch Production Acceptance](../../../../../Setup/Acceptance/Setup_205_Scheduling_Board_Production_Acceptance_2026-09-29.md)
- [#172 Report Correction Production Acceptance](../../../../../Setup/Acceptance/Setup_172_Report_Correction_Production_Acceptance_2026-09-27.md)
- [#175 / #132 Perform Work + Report Work Production Acceptance](../../../../../Setup/Acceptance/Setup_175_132_Report_Work_Production_Acceptance_2026-09-26.md)
- [Setup Assignment Layer V0.3.13 Production Acceptance](../../../../../Setup/Acceptance/Setup_Assignment_Layer_V0313_Production_Acceptance_2026-09-12.md)


## #205 Scheduling Board

- [Setup Scheduling Board Contract — 2026-09-17](Setup_Scheduling_Board_Contract_2026-09-17.md) — Production-accepted annual Day Number/DOW board, crew/shift scheduling, permanent season-only identity, schedulable Work Order-linked annual work, Captain live-dispatch default, planned-vs-actual labor visibility, historical assignment stickiness, and reusable-learning boundary.
- [#205 Production Acceptance — 2026-09-29](../../../../../Setup/Acceptance/Setup_205_Scheduling_Board_Production_Acceptance_2026-09-29.md) — exact V0.3.21 source-only Production acceptance and #206 handoff.


## #88 Pick Mode / Movement Capture — ACTIVE LAUNCH GATE / V0.3.29 RELEASE CONTEXT

V0.3.29 Pick Mode / Movement Capture was Production accepted and later superseded by V0.3.31 and the current V0.3.33 Setup application:

```text
historical #88 release = V0.3.29-pick-clarity
current Production     = e9839123e7483d7ced630b3dc6ab8f377c3f3262 / V0.3.33-material-status-review-fixes
```

The #88 movement-capture foundation remains active behavior inside the current Setup release; this section preserves release/design context rather than declaring V0.3.29 to be the current runtime.

V0.3.28 validated the field-evidence model: real Record Location observations are not blocked by planned access dates or missing prior PICKED events, canonical Home Location is shown for return, and Pick response time is materially improved by focused authoritative validation plus immediate UI settlement.

The V0.3.28 browser review then exposed final picker-clarity cleanup. V0.3.29:
- removes the obsolete **Movement / Scanning** shared Setup tab because it duplicated the direct Pick List entry point and had no unique operational workflow;
- removes the corresponding unnecessary movement-summary fetch from ordinary Setup page load while retaining the protected API;
- makes the Pick List summary physical-material-only: **Items to pick**, **Delayed items**, **Items already moved**, and **Containers picked**;
- defines **Containers picked** from an actual current-Session `PICKED` event rather than any outbound/moved state, so a Container discovered in the park without a Pick scan does not falsely increment Pick throughput; and
- preserves immediate Pick-count settlement and background authoritative readiness refresh.

- [Setup #88 Pick Mode and Movement Capture Design — 2026-09-29](Setup_88_Pick_Mode_Movement_Design_2026-09-29.md) — current launch design through the V0.3.29 picker-clarity successor for Zebra HID Pick Mode, field Record Location, GPS evidence, Training Mode, current-state semantics, return-home behavior, and durable offline queue/sync.
