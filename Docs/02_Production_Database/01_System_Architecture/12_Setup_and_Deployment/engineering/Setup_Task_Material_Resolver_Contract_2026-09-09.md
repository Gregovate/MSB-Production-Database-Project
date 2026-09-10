# Setup Task Material Resolver Contract — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Contract / Live Review Finding |
| System | Production Database — Setup and Deployment |
| Status | CURRENT DESIGN AUTHORITY — Production resolver correction pending |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; PR #125; PR #138 |

## Purpose

Preserve the operator-confirmed distinction between reusable Setup task scope, LOR Display grouping, physical/documentation scope, and Container derivation so future work does not reconstruct this model from screenshots or chat.

## Four Concepts Must Remain Separate

### 1. Reusable Setup task

A task is a practical unit of work that can be planned and staffed independently.

Examples:

```text
02 Triangle Volunteer Path Setup
02 Claymation Panels
```

Both can remain Stage 02 tasks and be assigned to different crews.

A task may also legitimately require no Display material at all. `Grease Gate bearings` is the canonical example.

### 2. Task physical/documentation scope

Task scope answers where the work belongs for Setup organization and shared Procedures/Wiring context.

The existing Folder Alignment contract controls this scope:

```text
NN-Name-XY      -> Stage
NNa-Name-XY     -> Sub-stage
NN-Name         -> Scene under the owning Stage
NNa-Name        -> Scene under the owning Sub-stage
```

If an LOR programming/grouping Scene does not correspond to a real `NN-Scene` / `NNa-Scene` structured folder, the physical/documentation scope remains the owning Stage/Sub-stage.

Therefore a task may be:

```text
task/documentation scope = Stage 02
material Display source  = a specific LOR Scene/group
```

The material group must not force the task into Scene scope.

### 3. LOR Display/material group

LOR already maintains the Display grouping in `ref.lor_scene_display`. Setup should consume that authoritative grouping when a practical task corresponds to the group instead of copying every Display into a second manually maintained task list.

This avoids the "forgotten Display" failure: if a Display is later added to the authoritative LOR group, Setup resolves it automatically without a separate Display-to-task maintenance step.

A task may use no material group, one group, or—if actual field practice requires it—more than one group. Exact schema cardinality must be inventoried before implementation rather than assumed.

For a true Scene, task scope and material group may be the same Scene. For a Stage-level/background grouping, they deliberately differ.

### 4. Container derivation

Once required Displays are resolved from the selected LOR material group(s), current Containers derive from each Display's current `ref.display.container_id`.

```text
selected/scheduled task
    -> LOR material group(s), if any
    -> current Displays in those groups
    -> current Display.container_id
    -> deduplicate Containers/trailers
    -> add explicit supplemental KIT/support Containers when needed
```

A Container may hold Displays from more than one Scene or Stage. That is normal. Container membership is downstream storage/transport evidence and must not be used to infer task scope or LOR material-group membership.

## Known-Good Reference: 13-Christmas Story

`13-Christmas Story` is the reference case that currently behaves correctly in Production.

Observed live Material / Logistics result:

```text
true task/physical scope = 13-Christmas Story Scene
LOR material group       = 13-Christmas Story Scene
Displays resolved        = 8
Containers resolved      = 4
Displays without Container = 1
```

This behavior is correct and must be preserved. The LOR Scene gathers the intended Displays, and those Displays lead to their current Containers.

The Stage-level/background correction should reproduce this same material-resolution pattern **without changing the task's physical/documentation scope to a Scene**.

## Stage-Level Material-Group Examples

```text
02 Claymation Panels
    task/documentation scope -> Stage 02
    material Display source  -> Show Background Stage 02 Triangle Claymation

02 Triangle Volunteer Path Setup
    task/documentation scope -> Stage 02
    material Display source  -> its corresponding LOR grouping

Grease Gate bearings
    task/documentation scope -> Stage 01 / Front Gate
    material Display source  -> none
```

This lets separate crews receive separate work packages inside the same Stage while all field Procedures/Wiring still resolve to the correct Stage unless a true Scene exists.

## Required Stage-Level Programming / Grouping Scenes

The following LOR Scenes are required show-programming/grouping constructs even though they resolve physically/documentationally to their owning Stage rather than to separate `NN-Scene` folders:

```text
Stage 00
- Show Background Stage 00 HWY42 MSB-Rotary-Trees
- Show Background Stage 00 HWY42 Traffic Signs

Stage 01
- Show Background Stage 01 FE Goal Sign
- Show Background Stage 01 FE MSB Sign
- Show Background Stage 01 FE Open-Close Sign
- Show Background Stage 01 FE Outside Gate
```

These six are required for programming the show and for authoritative Display grouping. Do not delete, rename away, or promote them into separate physical Scene folders merely because they do not use `NN-Scene` naming.

Their LOR membership can supply Setup material while Folder Alignment still resolves Procedures/Wiring to Stage 00 or Stage 01.

## Current Production Defect

`Setup/Application/setup_next_repository.py::field_context()` currently uses the task's `lor_scene_id` for two different concepts at once:

- task Scene organization; and
- automatic Display material expansion through `ref.lor_scene_display`.

That works for the true Scene reference case `13-Christmas Story`, but fails for Stage-level tasks whose Display material is represented by a separate background/programming LOR Scene. Those tasks currently show zero Displays/Containers unless explicit `ref.setup_task_display` rows happen to exist.

Representative review areas include:

- Stage 00 Hwy 42 Traffic Signs;
- Stage 00 Hwy 42 MSB / Rotary signs;
- Stage 01 Front Entrance grouping scenes;
- Stage 02 Triangle Volunteer Path and Claymation as separate crew tasks;
- Stage 16 Northern Lights; and
- other Stage-level tasks with a distinct LOR grouping but no true `NN-Scene` folder.

The fix is **not** automatic expansion of every Display on the Stage and **not** manual maintenance of every Display-to-task row.

The missing relationship is a way for a reusable task to reference its authoritative LOR material grouping independently of its Stage/Scene physical/documentation scope.

## Existing `ref.setup_task_display`

Existing `ref.setup_task_display` data must be inventoried before retirement, reinterpretation, or migration.

Do not enforce a new one-Display/one-task uniqueness rule. A Display can legitimately be involved in more than one reusable work task over the course of Setup—for example layout, physical setup, cord/network hookup, and testing—while remaining in one physical Stage/Scene location.

Use existing explicit rows only where they represent real exceptions or deliberate material detail not already captured by an authoritative LOR grouping. Do not make them the primary maintenance mechanism for ordinary grouped Displays.

## Implementation Direction

Before choosing schema, inventory representative Production tasks and their LOR grouping candidates.

The implementation should support:

- task scope remaining Stage/Sub-stage/true Scene according to Folder Alignment;
- zero material group for tasks such as bearing maintenance;
- a Stage-level task referencing an LOR background/programming Scene solely as its Display/material source;
- separate tasks in one Stage referencing different LOR Display groups so parallel crews get the correct material;
- true Scene tasks such as Christmas Story using their Scene group naturally;
- dynamic membership from current `ref.lor_scene_display`, so Displays are not forgotten in a second maintained list;
- current Container derivation from the resolved Displays;
- Container deduplication even when one Container carries several Scene/Stage groups;
- explicit supplemental KIT/support Containers separately; and
- clear UI language distinguishing **Task Scope** from **Material Group**.

## 2026 Session Gate

**Do not create the 2026 Setup Session until the reconstructed 2025 Setup plan is complete.**

Material resolution must be trustworthy before 2026 propagation so planning/Pick List work does not inherit known missing or false Display/Container relationships.

## Related Durable Sources

- [Google Drive Path Resolution Contract](../../../../../00_Project_Overview/Google_Drive/engineering/Google_Drive_Path_Resolution_Contract.md)
- [Setup Pick List Tablet Workflow](Setup_Pick_List_Tablet_Workflow_2026-09-09.md)
- [Setup Predecessor and Readiness Contract](Setup_Predecessor_and_Readiness_Contract_2026-09-09.md)
- [Setup engineering portal](README.md)
- GitHub Issue #122
