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

`Claymation Panels` is an MSB task/work-package name. It is not the name of one LOR Scene. The Claymation work package can aggregate several existing LOR Display groups.

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
material Display source  = one or more specific LOR Scenes/groups
```

The material group must not force the task into Scene scope.

### 3. LOR Display/material group

LOR already maintains the Display grouping in `ref.lor_scene_display`. Setup should consume that authoritative grouping when a practical task corresponds to the group instead of copying every Display into a second manually maintained task list.

This avoids the "forgotten Display" failure: if a Display is later added to the authoritative LOR group, Setup resolves it automatically without a separate Display-to-task maintenance step.

A task may use:

- no material group;
- one LOR group; or
- several LOR groups when one practical crew task spans several programming groups.

The Stage 02 Claymation task proves that more-than-one material group is required. A single task may aggregate several LOR groups while the task itself remains Stage 02 scoped.

A LOR group may also be relevant to more than one reusable task over the Setup lifecycle, for example physical setup, cord/network hookup, or testing. Therefore the task-to-LOR-material-group relationship must not be designed as one-to-one.

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

## Read-Only Coverage Evidence — Stages 00, 01, 02, and 13

The 2026-09-09 read-only material-group coverage review found:

```text
Stage 00 active Displays reviewed = 11
Stage 01 active Displays reviewed = 14
Stage 02 active Displays reviewed = 32
Stage 13 active Displays reviewed = 38
Total                            = 95
```

Every one of those 95 active Displays had `lor_group_count = 1` in the reviewed result. No active Display in those four Stages appeared ungrouped or multiply grouped in that evidence set.

This strongly supports using current LOR group membership as the normal dynamic Display source rather than maintaining a second Setup Display list.

## Known-Good Reference: 13-Christmas Story

`13-Christmas Story` is the reference case that currently behaves correctly in Production.

Observed live Material / Logistics result:

```text
true task/physical scope   = 13-Christmas Story Scene
LOR material group         = 13-Christmas Story Scene
Displays resolved          = 8
Containers resolved        = 4
current Container IDs      = 6, 131, 150, 171
Displays without Container = 1
```

This behavior is correct and must be preserved. The LOR Scene gathers the intended Displays, and those Displays lead to their current Containers.

The Stage-level/background correction should reproduce this same material-resolution pattern **without changing the task's physical/documentation scope to a Scene**.

## Stage-Level Material-Group Examples

### Stage 00 — Hwy 42

```text
Setup HWY42 Traffic Signs
    task/documentation scope -> Stage 00
    material LOR group       -> 275 HWY42 Traffic Signs
    current result           -> 7 Displays -> Containers 1, 146

Setup HWY42 MSB / Rotary Signs
    task/documentation scope -> Stage 00
    material LOR group       -> 289 HWY42 MSB and Rotary Signs
    current result           -> 4 Displays -> Container 1
```

### Stage 02 — Triangle

```text
02 Triangle Volunteer Path Setup
    task/documentation scope -> Stage 02
    material LOR group       -> 279 Volunteer Path Lights
    current result           -> 2 Displays -> Container 72

02 Claymation Panels
    task/documentation scope -> Stage 02
    material LOR groups      -> several current Stage 02 LOR groups
```

The operator-defined `Claymation Panels` work package includes displays commonly referred to by MSB as Claymation characters. Current reviewed Stage 02 evidence includes these LOR groups:

```text
280 Abominable      -> TR-Abominable      -> Container 2
281 Narwhal         -> TR-Narwhal         -> Container 2
282 CharlieInTheBox -> TR-CharlieInTheBox -> Container 2
284 Frosty          -> TR-FrostyComeBack  -> Container 2
```

The operator also identifies Rudolph as part of the Claymation work package. No Rudolph-named active Display/LOR group appeared in the reviewed Stage 00/01/02/13 coverage output, so its current authoritative LOR identity must be located rather than guessed before finalizing the Claymation material mapping.

Other Stage 02 groups such as Signage, US Flag, Volunteer Path Lights, Fred's Stars, and Mega Tree remain separate material groupings unless actual task practice says otherwise.

### Stage 01 — Front Entrance

Stage 01 currently includes Stage-fallback programming groups plus true Scenes. Current Stage-fallback groups include Goal Sign, Making Spirits Bright, Open-Close Sign, RotaryGear-01, and TuneRadio-2CH-01; true Scenes include `01-Entrance Arch` and `01-Front Gate`.

A Stage 01 task may use one or more of those programming groups while continuing to resolve Procedures/Wiring to Stage 01 unless it is truly scoped to `01-Entrance Arch` or `01-Front Gate`.

### Zero-material task

```text
Grease Gate bearings
    task/documentation scope -> Stage 01 / Front Gate area
    material LOR group       -> none
```

Zero material is valid when the task is real work but has no Display work package.

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

That works for the true Scene reference case `13-Christmas Story`, but fails for Stage-level tasks whose Display material is represented by one or more separate background/programming LOR Scenes. Those tasks currently show zero Displays/Containers unless explicit `ref.setup_task_display` rows happen to exist.

Representative review areas include:

- Stage 00 Hwy 42 Traffic Signs;
- Stage 00 Hwy 42 MSB / Rotary signs;
- Stage 01 Front Entrance grouping scenes;
- Stage 02 Triangle Volunteer Path and Claymation as separate crew tasks;
- Stage 16 Northern Lights; and
- other Stage-level tasks with distinct LOR grouping(s) but no true `NN-Scene` folder.

The fix is **not** automatic expansion of every Display on the Stage and **not** manual maintenance of every Display-to-task row.

The missing relationship is a way for a reusable task to reference zero, one, or several authoritative LOR material groups independently of its Stage/Scene physical/documentation scope.

## Existing `ref.setup_task_display`

Existing `ref.setup_task_display` data must be inventoried before retirement, reinterpretation, or migration.

Do not enforce a new one-Display/one-task uniqueness rule. A Display can legitimately be involved in more than one reusable work task over the course of Setup—for example layout, physical setup, cord/network hookup, and testing—while remaining in one physical Stage/Scene location.

Use existing explicit rows only where they represent real exceptions or deliberate material detail not already captured by an authoritative LOR grouping. Do not make them the primary maintenance mechanism for ordinary grouped Displays.

## Implementation Direction

Before choosing schema, inventory representative Production tasks and their LOR grouping candidates.

The implementation should support:

- task scope remaining Stage/Sub-stage/true Scene according to Folder Alignment;
- zero material group for tasks such as bearing maintenance;
- one or several LOR material groups for a Stage-level task;
- separate tasks in one Stage referencing different LOR Display groups so parallel crews get the correct material;
- several LOR groups being aggregated into one practical task, as with Stage 02 Claymation;
- a LOR group being reusable by more than one task when different phases operate on the same Displays;
- true Scene tasks such as Christmas Story using their Scene group naturally;
- dynamic membership from current `ref.lor_scene_display`, so Displays are not forgotten in a second maintained list;
- current Container derivation from the resolved Displays;
- Container deduplication even when one Container carries several Scene/Stage groups;
- explicit supplemental KIT/support Containers separately; and
- clear UI language distinguishing **Task Scope** from **Material Group(s)**.

The material-review UI should also distinguish an intentionally material-free task from a task whose material grouping has simply not yet been reviewed. Do not make an unexplained zero look the same as `NONE`.

## 2026 Session Gate

**Do not create the 2026 Setup Session until the reconstructed 2025 Setup plan is complete.**

Material resolution must be trustworthy before 2026 propagation so planning/Pick List work does not inherit known missing or false Display/Container relationships.

## Related Durable Sources

- [Google Drive Path Resolution Contract](../../../../../00_Project_Overview/Google_Drive/engineering/Google_Drive_Path_Resolution_Contract.md)
- [Setup Pick List Tablet Workflow](Setup_Pick_List_Tablet_Workflow_2026-09-09.md)
- [Setup Predecessor and Readiness Contract](Setup_Predecessor_and_Readiness_Contract_2026-09-09.md)
- [Setup engineering portal](README.md)
- GitHub Issue #122
