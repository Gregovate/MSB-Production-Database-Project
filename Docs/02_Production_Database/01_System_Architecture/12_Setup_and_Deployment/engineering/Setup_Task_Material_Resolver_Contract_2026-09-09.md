# Setup Task Material Resolver Contract — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Contract / Live Review Finding |
| System | Production Database — Setup and Deployment |
| Status | CURRENT DESIGN AUTHORITY — Production resolver correction pending |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; PR #125; PR #138 |

## Purpose

Preserve the operator-confirmed material-resolution model discovered during 2025 Setup review so future work does not create a second manually maintained Display grouping outside LOR.

The governing principle is:

```text
LOR owns current Display placement/grouping.
Setup owns reusable work/tasks.
Folder Alignment resolves LOR Scene evidence to physical Stage/Sub-stage/Scene scope.
Material / Logistics reports the current Displays/Containers for the task's resolved physical scope when that task actually requires Display/container material.
```

## Core Rule

Material / Logistics is a **scope-context resolver**, not a task-owned parts list.

For a reusable Setup task whose Display/container material flag is enabled:

```text
true Scene task
    -> resolve Displays in that exact LOR Scene
    -> derive current Containers from those Displays

Stage/Sub-stage task
    -> collect all LOR Scene memberships whose accepted physical/documentation
       resolution falls back to that Stage/Sub-stage
    -> exclude Displays whose LOR Scene resolves to a more-specific true Scene
    -> derive current Containers from the resulting Displays
```

The resolver must use the accepted Folder Alignment/shared field-context rules for physical scope classification. Do not use a simple Scene-name regex as Production authority; regex classification used during read-only diagnostics was only a convenient inspection aid.

## Display / Container Material Applicability

Live review clarified that Display/container material is **not relevant to every Setup task** even when the task belongs to a Stage/Scene that has many Displays.

The normal stage workflow often contains several separate reusable tasks such as:

```text
Locate
Layout
Setup
Cords
Network
Test
```

Not every task in that sequence needs the physical Displays/Containers presented as task material. In the common pattern, Display/container material becomes relevant primarily at the **Setup** step. Other steps may still use ordinary task resources, procedures, wiring context, prerequisites, readiness, and Stage/Scene scope without needing the Display/container material panel to represent required material.

Current preferred design direction is therefore a narrow boolean on the reusable task, conceptually:

```text
requires_display_material boolean NOT NULL DEFAULT false
```

Semantics:

```text
false
    -> task remains fully scoped to its Stage/Scene
    -> no Display/container material is considered required for this task
    -> prerequisites, readiness, procedures, resources, wiring, effort, etc. still apply

true
    -> resolve current Display/container material from the task's Stage/Scene scope
```

This flag must not be inferred solely from task name or action type because the operator stated the Locate/Layout/Setup/Cords/Network/Test pattern is common but not universal. Default false is deliberate; material should be enabled only where the reusable task truly needs it.

Canonical examples:

```text
Grease Gate Bearings
    scope                     = applicable Gate/Stage/Scene
    requires_display_material = false

Setup Northern Lights
    scope                     = Stage 16
    requires_display_material = true

Layout RGB Locations
    scope                     = Stage 16
    requires_display_material = false unless operator review says otherwise

Northern Lights Plug in Power & Network
    scope                     = Stage 16
    requires_display_material = false unless operator review says otherwise
```

The UI label should describe the business effect clearly (for example `Uses Display / Container Material`) rather than an ambiguous term such as `Task Only`.

## Operational Separation Rule — Promote the Material Boundary in LOR

When a subset of a Stage is important enough that it needs to be scheduled, crewed, and resolved as an independent material work area, the preferred design is to make that subset a **real LOR Scene** rather than creating a second task-specific Display list in Setup.

Example established during live review:

```text
02 Triangle Volunteer Path Setup
```

If Volunteer Path Lights remains a Stage-fallback LOR group, a Stage-level Setup task sees the broader Stage 02 fallback material context when material is enabled.

If Volunteer Path Lights is promoted to a real Stage-02 Scene in LOR, then:

```text
02-Volunteer Path Lights  (illustrative name; exact accepted naming must follow LOR/Folder Alignment rules)
    -> current LOR Scene membership owns the Volunteer Path Displays
    -> Folder Alignment resolves that Scene as its own physical/documentation scope
    -> the reusable Volunteer Path Setup task can live at that Scene
    -> Material / Logistics resolves exactly that Scene's Displays/Containers
```

The remaining Stage-02 fallback task(s), such as a Stage-level Claymation Panels task, then naturally exclude the Volunteer Path Scene material because true child-Scene Displays do not belong to the parent Stage fallback set.

This keeps the grouping in one place:

```text
LOR Scene membership = authoritative Display grouping
Setup task scope      = where the work is planned/staffed
Material resolver     = current Displays/Containers for that scope, when enabled
```

Do not create a separate Setup Display-membership list merely to obtain this separation.

A real Scene should only be created when the work/material boundary is operationally real. Do not manufacture Scenes for every task. Tasks such as `Grease Gate Bearings` can remain scoped to the applicable Stage/Scene while requiring no Display material.

Creating a true LOR Scene also means it becomes a real Folder Alignment scope. If Procedures/Wiring are expected at that Scene level, the corresponding controlled Google Drive Scene structure must remain aligned with the accepted folder contract; do not create a LOR Scene that silently contradicts the documentation hierarchy.

## Why This Model

The same LOR data already controls the physical show design. If a Display is moved in LOR and the accepted LOR ingest/reconciliation updates current Stage/Scene membership, Setup material context should update automatically.

Setup must not require a second Display-to-task maintenance step merely to keep material location current.

This avoids a predictable failure mode:

```text
Display moved in LOR
    + Setup copy not updated
    -> stale Setup material list
```

Under the scope resolver:

```text
Display moved in LOR
    -> current LOR Scene/Stage scope changes
    -> next Setup material resolution follows the new scope automatically
```

The reusable Setup task itself does not automatically move merely because one Display moved. Task scope remains a deliberate reusable work decision.

## Read-Only Coverage Evidence — Stages 00, 01, 02, 13, and 16

The 2026-09-09 read-only material review found 95 active Displays across Stages 00, 01, 02, and 13, and every reviewed Display had exactly one current `ref.lor_scene_display` membership in that evidence set.

```text
Stage 00 = 11 active Displays
Stage 01 = 14 active Displays
Stage 02 = 32 active Displays
Stage 13 = 38 active Displays
Total    = 95
```

Stage 16 was then reviewed separately and provides the strongest Stage-level defect case:

```text
Stage 16 Northern Lights
    lor_scene_id               = 298
    scene_name                 = 16-Northern Lights-NL
    active Displays            = 66
    DS Displays                = 32
    PS Displays                = 34
    Containers                 = 16, 17, 18, 19
    every reviewed Display     = exactly one LOR group
```

The current Setup Stage-level tasks still resolve 0 Displays / 0 Containers because `SetupNextRepository.field_context()` has no Stage fallback path.

This proves both that LOR is the correct authority and that Stage-level material resolution is a real code defect rather than missing LOR data.

## Known-Good Reference: 13-Christmas Story

`13-Christmas Story` is the current known-good Production reference.

```text
task scope                  = true Scene 13-Christmas Story
Displays resolved           = 8
Containers resolved         = 4
Container IDs               = 6, 131, 150, 171
Displays without Container  = 1
```

This behavior is correct and must be preserved.

The Stage/Sub-stage fallback fix should use the same downstream pattern:

```text
resolved physical scope
    -> current LOR Display memberships in that scope
    -> current Display.container_id
    -> deduplicated Containers
```

## Stage 16 Acceptance Case

Stage 16 currently has three Stage-level reusable tasks:

```text
Layout RGB Locations (20' Spacing, 32P & 30D)
Setup Northern Lights
Northern Lights Plug in Power & Network
```

The current LOR authority says the Stage contains 66 Displays, specifically 32 DS + 34 PS, across Containers 16, 17, 18, and 19.

The task name's embedded `32P & 30D` count is stale and demonstrates why task names and Procedures must not be treated as authoritative material counts. Display counts and Container resolution must come from current LOR-derived database relationships.

After the Stage fallback resolver exists, a Stage-16 task with `requires_display_material = true` must resolve:

```text
66 Displays
4 Containers
Container IDs 16, 17, 18, 19
```

A Stage-16 task with `requires_display_material = false` remains a valid Stage-16 task but must not present those 66 Displays/4 Containers as material required for that task.

## Preview UUID Is Not the Scope Boundary

A follow-up read-only inventory proved that `preview_uuid` cannot be used as the general Setup material boundary.

Observed examples:

```text
Stage 00
    HWY42 MSB and Rotary Signs  -> one Preview UUID
    HWY42 Traffic Signs         -> different Preview UUID

Stage 01
    one Preview UUID contains:
        01-Entrance Arch        true Scene
        01-Front Gate           true Scene
        RotaryGear-01           Stage fallback
        TuneRadio-2CH-01        Stage fallback
    other Stage-fallback groups use other Preview UUIDs

Stage 02
    one Preview UUID contains the eight Stage-fallback groups
    another Preview UUID contains 02-Fred's Stars and 02-Mega Tree

Stage 13
    one Preview UUID contains both:
        true 13-... Scenes
        Stage-fallback Root / Die Hard groups
```

Therefore:

- Preview identity remains valid LOR provenance/operating context;
- Preview identity must **not** determine whether material belongs to a Setup Stage or Scene;
- physical scope must be resolved per LOR Scene/group using the accepted Folder Alignment/shared field-context rules.

## LOR Programming Groups Are Still Authoritative Inputs

Stage-fallback LOR Scenes/groups remain important programming/grouping constructs even when they do not become separate physical/documentation Scene folders.

Examples include:

```text
Stage 00
- HWY42 MSB and Rotary Signs
- HWY42 Traffic Signs

Stage 01
- Goal Sign
- Making Spirits Bright
- Open-Close Sign
- RotaryGear-01
- TuneRadio-2CH-01

Stage 02
- Abominable
- CharlieInTheBox
- Frosty
- Headlights (Rudolph)
- Narwhal
- Signage
- US Flag
- Volunteer Path Lights (until the operator's new true Scene is ingested/reconciled)

Stage 13
- Root
- Die Hard
```

Those groups provide Display membership evidence. Their physical/documentation scope still resolves according to Folder Alignment unless one is deliberately promoted to a real Scene because it represents a true independently planned material/work area.

Do not delete or promote them merely to make Setup material resolution easier. Promotion to a true Scene should reflect actual operational separation, as with the Volunteer Path change.

## Current Production Defect

`Setup/Application/setup_next_repository.py::field_context()` currently expands Displays automatically only when the Setup task itself has `lor_scene_id`.

That works for true Scene tasks such as Christmas Story but leaves Stage-level tasks at zero unless explicit `ref.setup_task_display` rows exist.

The required correction is **not** task-specific Display ownership and **not** task-specific LOR-group ownership.

It is:

```text
if requires_display_material = false:
    no Display/container material result
else if task is true Scene scoped:
    resolve that Scene's Displays
else if task is Stage/Sub-stage scoped:
    resolve all current LOR Displays whose accepted physical scope falls back
    to that same Stage/Sub-stage
```

Then derive current Containers from those Displays.

When a Stage-level material subset must be independently crewed/planned, prefer making that subset a true LOR Scene and moving the applicable reusable task into that Scene rather than creating another material relationship in Setup.

## Existing `ref.setup_task_display`

Existing `ref.setup_task_display` data must be inventoried before retirement, reinterpretation, or deletion.

Do not make it the normal source for scope-level material context and do not add a uniqueness constraint merely to force a task-ownership model that the operator has not accepted.

If explicit rows represent genuine exceptions or supplemental detail, preserve them only under a separately reviewed rule.

## Container Rule

Containers are downstream storage/transport evidence.

```text
resolved Displays
    -> each current ref.display.container_id
    -> deduplicate Containers
```

A Container may legitimately contain Displays belonging to several LOR groups, Scenes, or Stages. Container membership must not be used to infer task scope.

Supplemental KIT/support Containers that are not derivable from Display storage remain a separate explicit relationship.

## 2026 Session Gate

**Do not create the 2026 Setup Session until the reconstructed 2025 Setup plan is complete.**

Material resolution must be trustworthy before 2026 propagation so planning/Pick List work does not inherit known missing or false Display/Container relationships.

## Implementation Gate

Before Production behavior changes:

1. use the accepted Folder Alignment/shared field-context resolver as the scope authority;
2. preserve the known-good `13-Christmas Story` behavior;
3. add a default-false reusable-task Display/container material applicability flag with explicit operator control;
4. implement Stage/Sub-stage fallback aggregation across all LOR Scene groups that resolve to that scope, regardless of Preview UUID;
5. exclude true Scene Displays from the parent Stage fallback set;
6. derive/deduplicate Containers from resolved Displays;
7. keep supplemental KIT/support Containers separate;
8. when a work/material subset needs independent scheduling and crew assignment, prefer a real LOR Scene plus matching Setup task scope rather than a new Setup material-group table;
9. preserve legitimate no-material tasks such as `Grease Gate Bearings`;
10. validate the common Locate/Layout/Setup/Cords/Network/Test pattern without assuming it is universal;
11. regression-test Stages 00, 01, 02, 13, Volunteer Path after its next LOR ingest/reconciliation, and Northern Lights/Stage 16; and
12. perform protected browser validation before Production acceptance.

## Related Durable Sources

- [Google Drive Path Resolution Contract](../../../../../00_Project_Overview/Google_Drive/engineering/Google_Drive_Path_Resolution_Contract.md)
- [Setup Pick List Tablet Workflow](Setup_Pick_List_Tablet_Workflow_2026-09-09.md)
- [Setup Predecessor and Readiness Contract](Setup_Predecessor_and_Readiness_Contract_2026-09-09.md)
- [Setup engineering portal](README.md)
- GitHub Issue #122
