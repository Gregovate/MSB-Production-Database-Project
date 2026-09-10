# Setup Stage / Scene Material Resolution Contract — 2026-09-10

| Document Control | Value |
|---|---|
| Document Type | Engineering Contract / Live Review Finding |
| System | Production Database — Setup Session |
| Status | IMPLEMENTATION CANDIDATE — operator-confirmed behavior; Production change not authorized |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; Issue #141; PR #125; superseded PR #142 |
| Production Setup baseline | `f39174c21bb7382c50b6d70d68a2bab1cb7bb098` |

## Purpose

Define the minimum Setup material behavior required to turn the existing reusable Setup task catalog and current LOR-derived Display/Container inventory into trustworthy scheduling and Pick List inputs.

This contract preserves the installed Setup system. It does not redesign LOR2DB, Display identity, Container assignment, LOR Preview construction, current LOR Scene membership, or the existing reusable/annual Setup task model.

## Operator Goal

A Setup task is a schedulable unit of work with its own crew size, Captain, equipment/resources, predecessors, duration, schedule, progress, and completion.

Some Setup tasks require physical Displays to be available at the job site. Other legitimate Setup tasks do not require Display material at all, including examples such as underground power/network locating, physical layout/marking, plugging in power/network, and greasing bearings.

When a task does require Displays, Setup must collate the current LOR-owned Display membership and current Container assignments so the task can later contribute correct demand to the Setup Pick List.

## Authority Boundary

```text
LOR / LOR2DB
    -> owns current show grouping and Display membership

ref.display
    -> owns permanent Display identity and current container_id

Setup
    -> owns reusable work/task knowledge
    -> records whether a task requires Display material
    -> consumes the applicable current LOR material set
    -> derives Containers from the resolved Displays
```

Setup must not maintain a second ordinary Display-membership list that competes with LOR.

Programming-only LOR Previews/groups remain valid and necessary show-programming objects. Their existence does not automatically make them separate physical Setup Scenes or separate Setup tasks.

## Task Scope Versus Material Applicability

Existing reusable task Stage/Scene scope remains the work scope.

Add/retain one independent reusable-task fact:

```text
requires_display_material boolean NOT NULL DEFAULT false
```

Semantics:

```text
false
    -> the task remains fully valid and schedulable
    -> zero LOR-derived Displays
    -> zero Display-derived Containers

true
    -> resolve the current LOR Display material for the task's existing Stage/Scene work scope
```

Do not infer this value from task name, Stage, Scene, action type, or the mere existence of Displays in that scope.

## Existing Shared LOR Stage / Scene Classification Is Authority

Setup must reuse the established Folder Alignment LOR Scene/group classification rather than inventing a second classification system.

Current `Folder_Alignment/folder_alignment.py::classify_scene()` semantics include:

```text
Root                         -> ROOT / Stage-level
unprefixed LOR group name    -> DISPLAY_GROUP / Stage-level
NN-...-XX Stage-root form    -> STAGE_ROOT / Stage-level
NNa-...-XX                   -> SUB_STAGE
NN-...                       -> SCENE
NNa-...                      -> SCENE within Sub-stage context
```

This classification exists specifically to distinguish structured Stage/Sub-stage/Scene scopes from ordinary LOR Display/programming groups.

Important examples proven during 2026-09-10 Production read-only review:

```text
Stage 01
    Goal Sign                     -> Stage-level programming group
    Making Spirits Bright         -> Stage-level programming group
    Open-Close Sign               -> Stage-level programming group
    RotaryGear-01                 -> Stage-level programming group
    TuneRadio-2CH-01              -> Stage-level programming group
    01-Entrance Arch              -> real Scene
    01-Front Gate                 -> real Scene

Stage 16
    16-Northern Lights-NL         -> Stage-root identity, not a child Setup Scene
```

Setup organization and material resolution must consume this shared classification consistently.

## Material Resolver

### No-material task

```text
requires_display_material = false
    -> no LOR-derived Display rows
    -> no Display-derived Container rows
```

Explicit supplemental Setup resources/support Containers remain separate and are not removed by this rule.

### Scene task

For a reusable task assigned to a real LOR Scene and requiring Display material:

```text
task.lor_scene_id
    -> exact current ref.lor_scene_display membership
    -> active ref.display rows
    -> current ref.display.container_id
    -> deduplicated Containers
```

Do not include sibling Scene material or Stage-level material.

### Stage task

For a Stage-level reusable task requiring Display material:

```text
all current LOR groups for the task Stage
    -> classify each with the shared Folder Alignment classification
    -> include groups classified as ROOT / DISPLAY_GROUP / STAGE_ROOT
    -> exclude groups classified as real child SCENE
    -> union current ref.lor_scene_display memberships by display_id
    -> active ref.display rows
    -> current ref.display.container_id
    -> deduplicated Containers
```

A Display must not become task material merely because another Display from the same Container is required.

The resolver starts with the Display set and derives Containers afterward.

## Setup Organization UI

The reusable Setup task organizer must not present every `ref.lor_scene` row as a separately schedulable Setup Scene.

Only real structured Scene/Sub-stage scopes from the shared classification belong in the Setup hierarchy as separate schedulable scopes.

Programming/display groups that classify to the Stage remain hidden as child Scene buckets and contribute to Stage-level material when a Stage task has `requires_display_material = true`.

Example:

```text
Stage 01
    Stage-level / General
        Stage 01 Panels
        Locate Power & Network
        Layout Panels
        ...

    Scene — 01-Entrance Arch
        independent crew/Captain/equipment/schedule

    Scene — 01-Front Gate
        independent crew/Captain/equipment/schedule
```

LOR may still contain separate programming Previews for Goal Sign, MSB Sign, Open-Close Sign, and other programming needs. Setup does not delete, rename, or redesign those LOR objects.

## Production Read-Only Acceptance Cases

The following five Stages are the required regression/acceptance set.

### Stage 00 — HWY 42

Current LOR:

```text
HWY42 MSB and Rotary Signs     4 Displays
HWY42 Traffic Signs            7 Displays
Stage-level total             11 Displays
```

Both LOR groups are required programming organization and remain Stage-level Setup material.

Expected Stage material result:

```text
11 Displays
Containers 1, 146
```

### Stage 01 — Front Entrance

Expected independently schedulable Display Setup jobs:

```text
Stage 01 Panels
    Stage-level groups          7 Displays

01-Entrance Arch
    exact Scene                 3 Displays

01-Front Gate
    exact Scene                 4 Displays

Total Stage 01                14 Displays
```

Stage-level seven:

```text
Goal Sign                     1
Making Spirits Bright         3
Open-Close Sign               1
RotaryGear-01                 1
TuneRadio-2CH-01              1
```

### Stage 02 — Triangle

Expected independently schedulable Display Setup jobs:

```text
Stage 02 Claymation Panels
    Stage-level groups         10 Displays

02-Volunteer Path Lights       2 Displays
02-Fred's Stars                16 Displays
02-Mega Tree                    4 Displays

Total Stage 02                 32 Displays
```

Stage-level ten:

```text
Abominable                     1
CharlieInTheBox                1
Frosty                         1
Headlights                     1
Narwhal                        1
Signage                        4
US Flag                        1
```

### Stage 13 — Winter Wonderland

Current read-only evidence:

```text
13-Christmas Story             8
13-Christmas Vacation          8
13-Christmas With the Kranks   3
13-Nightmare Before Christmas  3
13-Polar Express               7
Die Hard                       1
Root                           8
Total                          38
```

Expected classification from the established LOR naming contract:

```text
real Scene material            29 Displays
Stage-level Root/Display group  9 Displays
Total                           38 Displays
```

`13-Christmas Story` remains a known-good exact Scene regression case.

### Stage 16 — Northern Lights

Current LOR:

```text
16-Northern Lights-NL          66 Displays
Containers                    16, 17, 18, 19
```

The LOR row is the Stage-root identity, not a child Setup Scene.

Expected Stage material result:

```text
66 Displays
Containers 16, 17, 18, 19
child Scene material = 0
```

## Partition Invariants

For each acceptance Stage:

```text
Stage-level material Displays
UNION real child Scene material Displays
    = all applicable current active LOR Displays for that Stage
```

and:

```text
Stage-level material Displays
INTERSECT real child Scene material Displays
    = empty
```

No Display may be lost or double-counted solely because LOR uses multiple programming Previews.

## Sorting Defect — Separate Application Correction in Same Focused Workstream

Current `Plan / Schedule` and `Perform Work` surfaces do not reliably sort/group by Stage because their current ordering is driven primarily by annual/baseline/task order.

The Stage sort/presentation correction is an application concern, not a new scheduling model. Preserve existing planning order fields and add a deterministic Stage-oriented presentation option/grouping without changing the meaning of reusable or annual order.

## Pick List Boundary

This work does not implement the final Pick List execution workflow.

It establishes the trustworthy material resolver that the existing Pick List contract requires:

```text
selected / scheduled Setup work
    -> required Displays
    -> current Containers
    -> deduplicate Containers
    -> show why each Container/item is required
```

The same Container may contain Displays for several tasks/Stages/Scenes. Container contents must not be used to infer task membership.

## Explicitly Rejected Directions

Do not implement:

- explicit `LOR_STAGE` / `LOR_PREVIEW` / `LOR_SCENE` material-source rows per task;
- a user-facing Preview material selector;
- zero-to-many manually selected ordinary LOR material-source relationships;
- Stage material as every active `ref.display.stage_id` row regardless of Scene ownership;
- Stage material as Stage Displays minus every `ref.lor_scene_display` row;
- Stage material based on which Setup Scene tasks happen to exist;
- a manually maintained ordinary task-to-Display copy of LOR membership;
- automatic Setup task creation from every LOR Preview/group;
- changes to LOR2DB merely to satisfy Setup scheduling;
- Google Drive marker presence as Display inventory authority.

Superseded PR #142 implemented the explicit material-source direction above and was closed without merge or Production deployment.

## Implementation Boundary

Minimum candidate scope:

1. add `requires_display_material` to reusable Setup task knowledge, default false, through a governed Manager command;
2. reuse/extract the existing Folder Alignment LOR group classification so Setup and Folder Alignment share one rule;
3. filter the Setup organization hierarchy so ordinary programming/display groups are not shown as child Setup Scenes;
4. resolve Stage material as the union of Stage-level LOR groups;
5. preserve exact Scene material behavior;
6. derive Containers only after Display resolution;
7. preserve explicit supplemental resources/support Containers;
8. correct Stage-oriented presentation/sorting in Plan / Schedule and Perform Work without replacing existing planning-order semantics;
9. add deterministic tests for Stages 00, 01, 02, 13, and 16 plus no-material tasks; and
10. use disposable current-Production-clone and protected browser acceptance before any Production consideration.

## Production Gate

No Production mutation is authorized by this document or branch work.

Any schema or application deployment must follow the current Production Database and Setup deployment runbooks from `Gregovate/MSB-Server-Management`, with exact candidate SHA, disposable acceptance, browser review, explicit operator authorization, post-deploy health/regression/fingerprint checks, and rollback evidence as applicable.
