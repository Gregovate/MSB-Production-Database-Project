# Setup Task Material Resolver Contract — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Contract / Live Review Finding |
| System | Production Database — Setup and Deployment |
| Status | CURRENT DESIGN AUTHORITY — Production resolver correction pending |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; PR #125; PR #138 |

## Purpose

Record the task/material distinction established during 2025 Setup Catalog review so future engineering does not reconstruct it from chat, screenshots, or individual task examples.

This contract governs how reusable Setup work should resolve required Displays/assets and, downstream, current Containers for planning and Pick List use.

## Three Concepts Must Not Be Collapsed

### 1. Reusable task scope

A reusable Setup task is the practical unit of work and has a Stage/Sub-stage/Scene/Park Infrastructure organizational home.

Task scope answers **where the work belongs**. It does not prove that the task owns any Display.

Example:

```text
Grease Gate bearings
    -> belongs at the Front Gate / applicable Stage scope
    -> is real reusable Setup work
    -> may legitimately own zero Displays
```

Do not move a task to another Stage/Scene merely to make Material / Logistics appear populated.

### 2. Display physical/documentation location

A physical Display belongs to the existing current Stage/Sub-stage/Scene hierarchy.

The authoritative hierarchy already exists through:

- `ref.display.stage_id -> ref.stage`;
- current `ref.lor_scene_display -> ref.lor_scene` membership where the Display belongs to a real Scene scope; and
- the production-accepted shared field-context / Folder Alignment resolver.

A Scene is a real field/documentation scope only when it is deliberately aligned. If there is no more-specific Scene/Sub-stage scope, the Display remains at the applicable Stage/Sub-stage scope.

A Display has one physical Setup location in that hierarchy. It must not be assigned to two different physical Setup locations merely to satisfy task planning.

### 3. Reusable task Display work-package ownership

Display assignment is optional and separate from task scope.

Current operating rule established during live 2025 review:

```text
one Display
    -> zero or one reusable Setup task

one reusable Setup task
    -> zero, one, or many Displays
```

If a Display belongs to a reusable Setup work package, one reusable task owns that Display for Setup planning/reporting. Do not duplicate the same Display across reusable tasks.

The practical task boundary controls the assignment. Do not create one task per panel merely to make Display ownership easy.

Examples:

```text
Grease Gate bearings
    -> zero Displays is valid

Set Up Traffic Signs
    -> one reusable task
    -> may own the full reviewed Traffic Sign Display group

Set Up MSB & Rotary Signs
    -> one reusable task
    -> may own the reviewed MSB / Rotary sign Display group

Setup Panels
    -> one practical crew/work-package task
    -> may own many panel Displays
```

Known review areas include Hwy 42 Traffic Signs, Rotary MSB Signs, Front Entrance, Northern Lights, and other grouped physical work.

LOR Scene/display-group and Stage membership are useful **selection evidence** for establishing a task's work package, but they do not automatically make every Display in that scope belong to every task located there.

## Required Resolver Flow

The material resolver must follow:

```text
selected reusable Setup task
    -> its assigned Display work package, if any
        -> each Display's current ref.display.container_id
            -> deduplicate current Containers / trailers
                -> add reviewed supplemental support / KIT Containers
                    -> explain why each item / Container is required
```

A task with no assigned Displays may correctly resolve zero Displays and zero derived Containers. That is not inherently a data defect.

Do **not** replace task-level ownership with automatic inheritance such as:

```text
task Stage -> every Stage Display -> Containers
```

or:

```text
task Scene -> every Scene Display -> Containers
```

Stage/Scene/LOR groups may be offered as bulk-selection sources when the whole group truly is the practical work package. Bulk selection is an editing convenience that writes reviewed task-to-Display ownership; it is not silent inheritance.

## Current Production Defect

`Setup/Application/setup_next_repository.py` currently builds `field_context()` Display scope from:

1. explicit `ref.setup_task_display` mappings; plus
2. automatic expansion of every Display in `ref.lor_scene_display` for the task's `lor_scene_id`.

This violates the operating model in two different ways:

- Scene-organized tasks can appear to own every Scene Display even when no reviewed task-to-Display ownership exists;
- many real Display-bearing Stage-level work packages have no populated `ref.setup_task_display` ownership yet and therefore show zero, while zero is also a legitimate result for non-Display tasks such as bearing maintenance.

The application cannot safely distinguish those Stage-level cases merely from Stage membership. The missing piece is reviewed task-level Display ownership plus a practical Manager editing workflow.

Representative Production review evidence includes:

- Stage 01 `Claymation Panels` currently shows 0 resolved Displays even though this is intended as Display-bearing work;
- Stage 16 `Setup Northern Lights`, `Layout RGB Locations (20' Spacing, 32P & 30D)`, and `Northern Lights Plug in Power & Network` currently show 0;
- Christmas Story Scene currently shows 8 Displays / 4 Containers because of automatic Scene expansion; this result may be physically plausible but the ownership must come from reviewed task material rather than implicit Scene inheritance;
- additional operator-noted areas include Hwy 42 Traffic Signs, Rotary MSB Signs, and Front Entrance; and
- `Grease Gate bearings` is the counterexample proving that Stage-level zero cannot automatically be treated as missing material.

The fix is **not** to add automatic Stage expansion. The fix is to make task-level Display work-package ownership reviewable and trustworthy, then have the resolver consume it.

## Manager Editing Requirement

The Catalog needs a practical way to maintain task material without forcing one Display at a time where a real work group already exists.

Required direction:

- show the Displays currently owned by the selected reusable task;
- show enough Stage/Sub-stage/Scene context to understand where those Displays physically belong;
- allow selecting a known Stage/Sub-stage/Scene/LOR group as a **bulk source** when that group truly matches the practical task;
- write explicit task-to-Display ownership for the reviewed selected Displays rather than relying on future implicit inheritance;
- allow explicit add/remove/reassign corrections;
- prevent one Display from being assigned to more than one reusable Setup task;
- preserve zero-Display tasks as valid;
- surface each Display's current Container after ownership is established;
- do not create a second maintained Container list when Container demand can be derived from current Display-to-Container relationships; and
- keep supplemental support/KIT Container relationships explicit and separate because they are not always derivable from Display storage.

When reassigning a Display from one reusable task to another, the UI should show the current owner and require an explicit move/reassign rather than silently duplicating the relationship.

## Container Rules

`ref.display.container_id` remains the current storage/transport relationship for a Display.

The resolver should derive Container demand from the selected task's owned Displays and deduplicate it. This is necessary because one Container/trailer may carry Displays for several Stages even though each Display itself has only one reusable Setup task owner.

Known examples:

- Container 34 / Arch Trailer carries Displays for multiple Stages;
- Antenna Trailer carries material for several unrelated Display groups; and
- a KIT/support Container can be required even when no task Display currently points to it.

Do not assign a Display to the wrong Container or wrong Stage merely to express a Setup dependency.

## Planning Boundary

Reusable task Display ownership is separate from:

- Stage/Scene Catalog organization;
- physical Display Stage/Scene location;
- task predecessor/dependency relationships;
- preferred execution order;
- annual schedule/date assignment;
- readiness conditions; and
- current Container movement state.

A task such as bearing lubrication can be real Setup work with no Display material. Conversely, a grouped panel-install task can own many Displays and derive several Containers.

## 2026 Session Gate

The operator decision remains: **do not create the 2026 Setup Session until the reconstructed 2025 plan is complete.**

Before propagation, task material must be trustworthy enough that planning/Pick List work does not inherit known false or missing Display/Container relationships.

## Implementation Gate

Before changing Production behavior:

1. inventory current `ref.setup_task_display` ownership and representative tasks;
2. identify tasks that legitimately require zero Displays;
3. identify practical group tasks whose material can be bulk-selected from existing Stage/Scene/LOR grouping evidence;
4. identify any Display currently mapped to more than one reusable task and reconcile it before enforcing uniqueness;
5. confirm the editing workflow against representative areas including Front Entrance, Hwy 42 Traffic Signs, Rotary MSB Signs, Northern Lights, and one known-good Scene group;
6. implement explicit add/remove/reassign behavior and preserve zero-Display tasks;
7. only then remove implicit Scene-wide material ownership from the resolver;
8. verify derived Container deduplication and shared-trailer behavior; and
9. perform protected browser validation before Production acceptance.

## Related Durable Sources

- [Setup Pick List Tablet Workflow](Setup_Pick_List_Tablet_Workflow_2026-09-09.md)
- [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md)
- [Setup engineering portal](README.md)
- [Google Drive Stage/Sub-stage/Scene folder SOP](../../../../../00_Project_Overview/Google_Drive/operatorSOP/Create_Stage_Substage_Scene_Folder.md)
- [Shared Field Context Database Layer Acceptance](../../07_Labeling_and_Scanning/Shared_Field_Context_Database_Layer_Acceptance_2026-08-23.md)
- GitHub Issue #122
