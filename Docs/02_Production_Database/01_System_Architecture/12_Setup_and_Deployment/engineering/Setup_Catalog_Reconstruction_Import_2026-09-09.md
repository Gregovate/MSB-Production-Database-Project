# Setup Catalog Reconstruction Import — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Reconstruction / Import Record |
| System | Production Database — Setup Session |
| Status | ACCEPTED IN PRODUCTION — one-time reconstruction complete; current PostgreSQL catalog is the ongoing working baseline |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; Setup Catalog Reconciliation Workflow; Setup Smart Scheduler Workflow |

## Purpose

Record the controlled conversion of the reviewed 2022/2025 reconstruction workbook into the reusable Setup catalog that now serves as the current Production working baseline.

This was the point where provisional historical reconstruction was normalized into current Production Stage/Scene identity and permanent reusable task knowledge. It is now a **deployment/history record**, not the ongoing task master.

## Current Authority After Import

The one-time reconstruction import is complete.

From this point forward:

```text
current Production PostgreSQL reusable catalog
    = working task baseline

reviewed one-list workbook / 2022 schedule / 2025 notes
    = historical and reconstruction evidence
```

Do not maintain a second spreadsheet as a parallel authoritative task list. Continue building, correcting, organizing, and enriching reusable tasks against the current PostgreSQL data through the governed Setup application/database commands.

## Source Authority Used For The Import

The accepted import was based on:

1. the operator-reviewed `MSB_Setup_ONE_LIST_Reconciliation_20260909_WITH_EFFORT` workbook;
2. the Production reusable-task snapshot containing 68 active reusable tasks before reconstruction;
3. the Production `ref.stage` / `ref.lor_scene` inventory exported 2026-09-09; and
4. operator-confirmed mappings and task-boundary decisions made during the reconstruction review.

Historical Stage numbers were not treated as durable identity. Current Production Stage/Scene IDs controlled the import.

## Accepted Catalog Result

Production acceptance established:

```text
active reusable tasks after reconstruction = 185
total reusable task rows                    = 187
existing reusable identities retained       = 66
new reusable definitions                    = 119
provisional task 40                         = retired/inactive
provisional task 58 "light"                 = retired/inactive
new 2025 annual rows                        = 0
reusable dependency rows after import       = 0
2026 Setup Sessions                         = 0
```

Task 40 (`Deliver Command Center`) was the obsolete provisional duplicate. Existing task 51 (`Deliver and Set Up Command Center Trailer`) was retained as the reusable Command Center task.

Task 58 (`light`) was a junk provisional reconstruction row and was retired.

Retirement preserved the historical shells rather than deleting history. Their 2025 annual occurrences were excluded from the historical session.

## 2025 Annual Boundary

The reconstructed catalog is reusable knowledge. Newly reconstructed reusable tasks were **not** fabricated as 2025 annual occurrences simply because the catalog was improved during 2025 review.

Migration 024 therefore created reusable tasks directly and did not use the normal browser creation behavior that appends new tasks to an open session.

Existing 2025 historical rows remain historical evidence. The future 2026 Setup Session will be created only after the live reusable catalog and predecessor/readiness model are useful enough for planning.

## Effort Metadata

The reusable planning metadata introduced by this reconstruction is:

```text
ref.setup_task.effort_level
```

Accepted values:

```text
LIGHT
MODERATE
HEAVY
NULL = not yet reviewed / unknown
```

The reviewed workbook used `MEDIUM` in some rows; the database vocabulary normalized those values to `MODERATE`.

Accepted Production counts:

```text
LIGHT       8
MODERATE   12
HEAVY       4
NULL       161
```

No `planning_role`, trailer-specific flag, or special Arch/Antenna classification was introduced.

## Existing Ordering Model Reused

No duplicate scheduler-order column was added.

Existing model:

```text
ref.setup_task.display_order              normal order inside Stage/Scene
ref.setup_task.baseline_plan_order        reusable whole-Setup starting order
ops.setup_session_task.planned_order      annual Manager-adjustable order
ops.setup_work_day_task.sort_order        order inside scheduled work
ops.setup_work_day_task.crew_lane         parallel temporary crew lane
```

Historical dates/order were used only to seed a practical reusable `baseline_plan_order`. They remain sequencing evidence, not future calendar dates.

## Canonical Task Names

Equivalent locating work was normalized to:

```text
Locate Power & Network
```

The accepted import produced ten such reusable tasks in the reviewed current scopes.

Equivalent panel-position marking was normalized to:

```text
Layout Panels
```

The accepted import produced four such reusable tasks.

This normalization did **not** collapse physically different work such as:

- `Layout Trees`;
- `Layout New Trees`;
- `Layout RGB Locations ...`; or
- `Layout Display`.

Those remain distinct reusable tasks where field practice supports them.

## OMW / Heat Mister Reconciliation

Historical `OMW / Heat Mister` evidence resolved to current Global Warming Stage identity.

The reusable sequence retained the core work:

```text
Locate Power & Network
Layout New Trees
Setup Panels
Plug in Power & Network
```

Historical continuation/shorthand rows such as:

```text
OMW locating/fix
OMW network locating
Finish OMW panels
```

remain evidence for those reusable tasks rather than becoming three additional reusable definitions.

## Pure Logistics Versus Real Setup Work

The reconstruction deliberately distinguished logistics from work that must itself be planned/reported.

### Pure logistics

Ordinary transport-only evidence was not promoted to a reusable Setup task merely because an old schedule recorded a move. Examples excluded from the reusable import included:

```text
Deliver Horse & Sleigh to park
Bring Frosty to park
Deliver boxes for inside Santa's Station
```

The future Pick List / movement workflow owns ordinary material mobilization.

### Pre-Setup workshop access

Moves that are actual work because they physically unlock access to stored Displays/material remain real reusable tasks.

These are modeled as ordinary reusable tasks, not with a separate planning-role field.

## Known Post-Import Catalog Finding — Frosty

The logistics distinction above exposed one omission after Production deployment.

`Bring Frosty to park` was correctly excluded because transportation itself is logistics. However, no separate reusable physical task was created for the actual Frosty setup.

Current correction required in the live PostgreSQL catalog:

```text
Stage 02 — Triangle
    Frosty work
        Set Up Frosty
```

The operator confirmed that Frosty must be set up before the applicable Stars setup work. Add the physical Frosty task to the current catalog, then establish that dependency during the reviewed predecessor pass.

This is an example of the post-import operating rule: **correct the current PostgreSQL catalog directly rather than reopening the reconstruction workbook as a master list.**

## Mixed-Stage Containers and Trailers

The Arch Trailer and Antenna Trailer are examples of a generic shared/mixed-load Container pattern.

They are **not special-case schema identities**.

Future trailers may also carry material used by multiple Stages/Scenes. The workflow must derive that condition from authoritative Container/Display/Stage relationships and reusable task-to-Container relationships.

General rule:

```text
shared Container / trailer
    -> may support multiple Stage/Scene Setup tasks
    -> Container is scanned/resolved once
    -> annual state tracks what remains loaded/unloaded
    -> required unload group becomes actionable when its Setup work needs it
```

The reusable `UNLOAD_CONTAINER` tasks remain valid where unloading is itself meaningful physical work. The future Pick List/movement layer must support the same model for Arch Trailer, Antenna Trailer, and future shared trailers without special-case flags.

## Aggregate Historical Evidence Is Not a Reusable Task

Cross-area shorthand rows remain evidence but were not converted into synthetic reusable tasks.

Examples:

```text
Panel-location marking
Lay cords - multiple areas
Traditional Christmas locating/layout planning
```

Reusable work belongs in the actual current Stage/Scene scope where the work is independently planned and tracked.

## Santa's Station Name Normalization

Historical `Quarry` evidence resolved to current Santa's Station Stage identity.

Reusable task names in the accepted catalog use Santa's Station naming rather than perpetuating the old Quarry name.

Historical source documents can continue to show Quarry because that is what they were called at the time.

## Dependency Reset and Next Pass

The old dependency set was not trusted after the scope/identity reconstruction.

Migration 024 intentionally cleared:

```text
ref.setup_task_dependency
```

Production currently has zero reusable dependency rows by design.

The next reviewed pass must distinguish:

```text
HARD PREDECESSOR
PREFERRED ORDER
READINESS CONDITION
```

Examples include:

- Frosty setup before the applicable Stars work;
- Locates before Layout where field practice requires it;
- Layout before physical installation where locations must be marked;
- grass cutting stopped before cord laying;
- physical assembly before downstream power/network work;
- genuine workshop-access tasks before work that cannot be physically reached; and
- ordered Arch Trailer unload/access dependencies where the shared physical trailer constrains later work.

Do not create the 2026 Setup Session before this pass is useful enough for the planning workflow.

## Acceptance Evidence

Accepted migrations:

```text
023_add_setup_task_effort.sql
024_reconstruct_setup_catalog_from_reviewed_one_list.sql
```

Migration 024 sourced its reviewed rows from:

```text
Setup/Database/reconstruction/024_catalog_batch_01.sql
...
Setup/Database/reconstruction/024_catalog_batch_05.sql
```

Disposable Production-clone validation passed before Production mutation.

Final accepted Production deployment:

```text
Setup runtime SHA                    = 5a8a317357ffa5d77c38bc4df63fe6c7b451dbaf
active reusable tasks                = 185
total reusable task rows             = 187
dependencies                         = 0
2026 Setup Sessions                  = 0
Production Setup fingerprint         = f0b98ac75e297a08eabc3df040708c08
rollback archive                     = /home/msbadmin/backups/setup-catalog/msb-pre-setup-catalog-20260909T184826.dump
deployment report                    = /home/msbadmin/setup-acceptance-reports/Setup_Catalog_Reconstruction_Production_Deploy_20260909T184826.txt
wrapper result                       = SETUP_CATALOG_RECONSTRUCTION_PRODUCTION_DEPLOYMENT_PASS
```

The Production deployment completed with 134 application tests passing, protected negative-path HTTP 401 acceptance, public `/setup/` health PASS, and the final Production fingerprint matching the accepted post-catalog state.

## Production Change Rule Going Forward

This accepted import does not authorize future ad hoc Production changes.

Future Production database/application mutations still require the current project rules and the governing Production Database deployment runbook from `Gregovate/MSB-Server-Management`.

Routine Manager task maintenance that is already exposed through governed application commands is normal Production use and should operate on the current PostgreSQL catalog rather than through another reconstruction migration.
