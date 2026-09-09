# Setup Catalog Reconstruction Import — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Reconstruction / Import Contract |
| System | Production Database — Setup Session |
| Status | IMPLEMENTATION CANDIDATE — disposable Production-clone acceptance required before Production consideration |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; Setup Catalog Reconciliation Workflow; Setup Smart Scheduler Workflow |

## Purpose

Define the controlled conversion of the reviewed 2022/2025 reconstruction workbook into the reusable Setup catalog that will become the basis for future Setup planning before a 2026 Setup Session is created.

This is the point where provisional historical reconstruction is intentionally normalized into current Production Stage/Scene identity and permanent reusable task knowledge.

## Source Authority

The candidate is based on:

1. the operator-reviewed `MSB_Setup_ONE_LIST_Reconciliation_20260909_WITH_EFFORT` workbook;
2. the current Production reusable-task snapshot containing 68 active reusable tasks before reconstruction;
3. the current Production `ref.stage` / `ref.lor_scene` inventory exported 2026-09-09; and
4. operator-confirmed mappings and task-boundary decisions made during the reconstruction review.

Historical Stage numbers are not durable identity. Current Production Stage/Scene IDs control.

## Candidate Catalog Result

The controlled candidate targets:

```text
active reusable tasks after reconstruction = 185
existing reusable identities retained       = 66
new reusable definitions                    = 119
provisional task 40                         = retired/inactive
provisional task 58 "light"                 = retired/inactive
new 2025 annual rows                        = 0
reusable dependency rows after import       = 0
```

Task 40 (`Deliver Command Center`) is the obsolete provisional duplicate. Existing task 51 (`Deliver and Set Up Command Center Trailer`) is retained as the reusable Command Center task.

Task 58 (`light`) is a junk provisional reconstruction row and is retired.

Retirement preserves the historical shells rather than deleting history. Their 2025 annual occurrences are excluded from the historical session.

## 2025 Annual Boundary

The reconstructed catalog is future reusable knowledge. Newly reconstructed reusable tasks must **not** be fabricated as 2025 annual occurrences simply because the catalog is being improved during 2025 review.

Therefore migration 024 creates reusable tasks directly and does not call the normal browser creation command that automatically appends new tasks to open sessions.

Existing 2025 historical rows remain historical evidence. The future 2026 Setup Session will be created only after the reusable catalog and predecessor/readiness model are accepted.

## Effort Metadata

The only new reusable planning metadata introduced by this reconstruction is:

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

The reviewed workbook used `MEDIUM` in some rows; the database vocabulary normalizes those values to `MODERATE`.

Candidate reviewed counts:

```text
LIGHT       8
MODERATE   12
HEAVY       4
NULL       161
```

No `planning_role`, trailer-specific flag, or special Arch/Antenna classification is introduced.

## Existing Ordering Model Is Reused

No new scheduler-order column is required for this import.

Existing model:

```text
ref.setup_task.display_order              normal order inside Stage/Scene
ref.setup_task.baseline_plan_order        reusable whole-Setup starting order
ops.setup_session_task.planned_order      annual Manager-adjustable order
ops.setup_work_day_task.sort_order        order inside scheduled work
ops.setup_work_day_task.crew_lane         parallel temporary crew lane
```

The reviewed historical dates/order are used only to seed a practical reusable `baseline_plan_order`. They are evidence of sequencing, not future calendar dates.

## Canonical Task Names

Equivalent locating work is normalized to:

```text
Locate Power & Network
```

The candidate contains ten such reusable tasks in the appropriate current Stage/Scene scopes.

Equivalent panel-position marking is normalized to:

```text
Layout Panels
```

The candidate contains four such reusable tasks.

This normalization does **not** collapse physically different work such as:

- `Layout Trees`;
- `Layout New Trees`;
- `Layout RGB Locations ...`; or
- `Layout Display`.

Those remain distinct reusable tasks where field practice supports them.

## OMW / Heat Mister Reconciliation

Historical `OMW / Heat Mister` evidence resolves to current Global Warming Stage identity, with the relevant Global Warming Scene.

The reusable sequence retains the core work:

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

The reconstruction deliberately distinguishes logistics from work that must itself be planned/reported.

### Pure logistics

Ordinary transport-only evidence is not promoted to a reusable Setup task merely because the old schedule recorded a move. Examples removed from the reusable candidate include:

```text
Deliver Horse & Sleigh to park
Bring Frosty to park
Deliver boxes for inside Santa's Station
```

The future Pick List / movement workflow owns ordinary material mobilization.

### Pre-Setup workshop access

Moves that are actual work because they physically unlock access to stored Displays/material remain real reusable tasks.

This captures the operational reason large items appeared at the beginning of the historical schedule: some large trailers/Displays must leave the workshop before crews can reach racks and other Setup material.

These are modeled as ordinary reusable tasks, not with a separate planning-role field.

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

The current reusable `UNLOAD_CONTAINER` tasks remain valid where unloading is itself meaningful physical work. The future Pick List/movement layer must support the same model for Arch Trailer, Antenna Trailer, and future shared trailers without adding `is_arch_trailer`, `is_mixed_stage_trailer`, or equivalent special-case flags.

## Aggregate Historical Evidence Is Not a Reusable Task

Cross-area shorthand rows are retained as evidence but are not converted into one synthetic reusable task.

Examples:

```text
Panel-location marking
Lay cords - multiple areas
Traditional Christmas locating/layout planning
```

Reusable work belongs in the actual current Stage/Scene scope where the work is independently planned and tracked.

## Santa's Station Name Normalization

Historical `Quarry` evidence resolves to current Santa's Station Stage identity.

Reusable task names in the candidate use Santa's Station naming rather than perpetuating the old Quarry name.

Historical source documents can continue to show Quarry because that is what they were called at the time; the reusable current catalog does not.

## Dependency Reset and Next Pass

The old dependency set is not trusted after the scope/identity reconstruction.

Migration 024 intentionally clears:

```text
ref.setup_task_dependency
```

This is not the final scheduler state. It creates a clean dependency baseline for the separate reviewed predecessor/readiness pass.

Before creating the 2026 Setup Session, that next pass must distinguish:

```text
HARD PREDECESSOR
PREFERRED ORDER
READINESS CONDITION
```

Examples include:

- Locates before Layout where field practice requires it;
- Layout before physical installation where locations must be marked;
- grass cutting stopped before cord laying;
- physical assembly before downstream power/network work;
- genuine workshop-access tasks before work that cannot be physically reached.

## Disposable Acceptance Gate

Candidate migrations:

```text
023_add_setup_task_effort.sql
024_reconstruct_setup_catalog_from_reviewed_one_list.sql
```

Migration 024 sources its reviewed catalog rows from:

```text
Setup/Database/reconstruction/024_catalog_batch_01.sql
...
Setup/Database/reconstruction/024_catalog_batch_05.sql
```

Acceptance tooling:

```text
Setup/Acceptance/run_setup_catalog_reconstruction_disposable_acceptance.ps1
Setup/Acceptance/setup_catalog_reconstruction_disposable_acceptance_server.sh
Setup/Acceptance/setup_catalog_reconstruction_disposable_validation.sql
```

The acceptance runner may read Production with `pg_dump` and `SELECT` only. All schema/data writes occur in a disposable PostgreSQL clone restored from current Production.

The disposable validation must prove at minimum:

- 185 active reusable tasks;
- 66 existing identities retained and 119 new definitions created by the migration source;
- tasks 40 and 58 inactive;
- task 51 preserved;
- 10 canonical `Locate Power & Network` tasks;
- 4 canonical `Layout Panels` tasks;
- accepted effort counts;
- no new annual rows for task IDs created by reconstruction;
- no 2026+ Setup Session;
- zero reusable dependencies pending the predecessor pass;
- valid current Stage/Scene foreign-key pairing; and
- Production Setup fingerprint unchanged after disposable acceptance.

## Production Gate

Passing disposable acceptance does not authorize Production mutation.

Any Production application of migrations 023/024 requires:

1. current candidate SHA identified;
2. current Production preflight;
3. retrieval and reading of the governing Production Database deployment runbook from `Gregovate/MSB-Server-Management` in that workstream;
4. explicit operator approval for the Production mutation; and
5. post-deployment catalog/browser acceptance before proceeding to the predecessor pass.

No 2026 Setup Session should be created as part of this reconstruction deployment.
