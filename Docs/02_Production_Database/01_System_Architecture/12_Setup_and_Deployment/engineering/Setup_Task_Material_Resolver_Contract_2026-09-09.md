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

A task is a practical unit of work that can be planned/staffed independently.

Examples:

```text
02 Triangle Volunteer Path Setup
02 Claymation Panels
```

Both may belong to Stage 02 and be assigned to different crews.

A task may also legitimately require no Display group at all. `Grease Gate bearings` is the canonical example.

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
task scope     = Stage 02
material group = an LOR Scene/group that gathers the Displays used by that task
```

The material group must not force the task into Scene scope.

### 3. LOR Display/material group

LOR already maintains useful Scene/group membership in `ref.lor_scene_display`. Setup should consume that authoritative grouping when a practical task corresponds to the group instead of copying every Display into a second manually-maintained task list.

This avoids the "forgotten Display" failure: if a Display is later added to the authoritative LOR group, Setup can resolve it automatically without a separate Display-to-task maintenance step.

A task may use zero, one, or, if real field practice requires it, more than one LOR material group. Exact schema cardinality must be confirmed before implementation; do not assume a single nullable column without inventory.

For a true Scene such as `13-Christmas Story`, the task physical scope and the LOR material group may happen to be the same Scene.

For a Stage-level/background grouping, they deliberately differ:

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

### 4. Container derivation

Once the required Display group is known, current Containers derive from the Displays' current `ref.display.container_id` values.

```text
selected/scheduled task
    -> LOR material group(s), if any
    -> current Displays in those group(s)
    -> current Display.container_id
    -> deduplicate Containers/trailers
    -> add explicit supplemental KIT/support Containers when needed
```

Do not maintain a second task-to-Container list where current Display storage already supplies the answer.

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

These six are required for programming the show and for authoritative Display grouping. Do not delete or normalize them away merely because they do not create separate Google Drive Scene folders.

Their LOR Scene membership can be used as task material grouping while Folder Alignment still resolves Procedures/Wiring to Stage 00 or Stage 01.

## Current Production Defect

`Setup/Application/setup_next_repository.py::field_context()` currently uses the task's `lor_scene_id` for both concepts at once:

- task Scene organization; and
- automatic Display material expansion through `ref.lor_scene_display`.

That works for a true Scene such as Christmas Story, but fails for Stage-level tasks whose material is represented by a separate background/programming LOR Scene. Those tasks currently show zero Displays/Containers unless explicit `ref.setup_task_display` rows happen to exist.

Representative review examples include:

- Stage 01 `Claymation Panels` / Front Entrance groupings;
- Stage 16 `Setup Northern Lights`;
- Stage 16 `Layout RGB Locations (20' Spacing, 32P & 30D)`;
- Stage 16 `Northern Lights Plug in Power & Network`;
- Hwy 42 Traffic Signs;
- Hwy 42 MSB / Rotary Signs; and
- Stage 02 Volunteer Path versus Claymation Panels as separate crew tasks within the same Stage.

The fix is **not** automatic expansion of every Display on the Stage and **not** manual maintenance of every Display-to-task row.

The missing relationship is a way for a task to reference its authoritative LOR material grouping independently of its Stage/Scene physical/documentation scope.

## Implementation Direction

Before choosing schema, inventory representative Production tasks and their LOR grouping candidates.

The implementation should support:

- task scope remaining Stage/Sub-stage/true Scene according to Folder Alignment;
- zero material group for tasks such as bearing maintenance;
- a Stage-level task referencing an LOR background/programming Scene solely as its Display/material source;
- separate tasks in one Stage referencing different LOR Display groups so parallel crews get the correct material;
- true Scene tasks using their Scene group naturally;
- dynamic membership from current `ref.lor_scene_display`, so Displays are not forgotten in a second maintained list;
- current Container derivation from the resolved Displays;
- explicit supplemental KIT/support Containers separately; and
- clear UI language distinguishing **Task Scope** from **Material Group**.

Existing `ref.setup_task_display` data must be inventoried before retirement/reinterpretation. Do not delete or migrate it blindly; determine whether any rows represent exceptions not captured by an LOR group.

## 2026 Session Gate

The operator decision remains: **do not create the 2026 Setup Session until the reconstructed 2025 plan is complete.**

Material resolution must be trustworthy before 2026 propagation so near-term planning/Pick List work does not inherit known missing or false Display/Container relationships.

## Related Durable Sources

- [Google Drive Path Resolution Contract](../../../../../00_Project_Overview/Google_Drive/engineering/Google_Drive_Path_Resolution_Contract.md)
- [Setup Pick List Tablet Workflow](Setup_Pick_List_Tablet_Workflow_2026-09-09.md)
- [Setup Predecessor and Readiness Contract](Setup_Predecessor_and_Readiness_Contract_2026-09-09.md)
- [Setup engineering portal](README.md)
- GitHub Issue #122
