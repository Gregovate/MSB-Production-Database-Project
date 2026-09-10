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

## Two Different Scopes Must Not Be Collapsed

Setup has two related but different concepts:

### 1. Physical / documentation location scope

A physical Display belongs to the existing current Stage/Sub-stage/Scene hierarchy.

The authoritative hierarchy already exists through:

- `ref.display.stage_id -> ref.stage`;
- current `ref.lor_scene_display -> ref.lor_scene` membership where the Display belongs to a real Scene scope; and
- the production-accepted shared field-context / Folder Alignment resolver.

A Scene is a real field/documentation scope only when it is deliberately aligned. If there is no more-specific Scene/Sub-stage scope, the Display remains at the applicable Stage/Sub-stage scope.

A Display has one physical Setup location in that hierarchy. It must not be assigned to two different physical Setup locations merely to satisfy task planning.

### 2. Reusable task material requirement

A reusable Setup task is a practical unit of work. Its material requirement is **not automatically equal to every Display in its Stage or Scene**.

A task may require:

- zero Displays/assets;
- one Display;
- many Displays as a practical group; or
- Displays plus reviewed supplemental support/KIT Containers.

Examples established during live review:

- `Grease Gate bearings` can legitimately require **no Display rows**;
- a `Setup Panels` task can intentionally require **a group of panel Displays**;
- grouped work such as Hwy 42 Traffic Signs, Rotary MSB Signs, Front Entrance panels, Northern Lights, and similar areas must be reviewed as practical task material, not inferred from the whole Stage merely because the task is Stage-organized.

The same physical Display/location may participate in more than one work task when the work itself requires that Display. Physical location ownership and task material participation are separate concepts.

## Required Resolver Flow

The material resolver must follow:

```text
selected reusable Setup task
    -> required Displays / durable assets for that task
        -> each Display's current ref.display.container_id
            -> deduplicate current Containers / trailers
                -> add reviewed supplemental support / KIT Containers
                    -> explain why each item / Container is required
```

Do **not** replace this with:

```text
task Stage -> every Stage Display -> Containers
```

or:

```text
task Scene -> every Scene Display -> Containers
```

unless that task's reviewed material requirement is in fact the entire Stage/Scene group.

Stage/Scene organization is useful context and may provide a bulk-selection source for editing task material, but it is not itself sufficient proof that every Display in that scope is required by the task.

## Current Production Defect

`Setup/Application/setup_next_repository.py` currently builds `field_context()` Display scope from:

1. explicit `ref.setup_task_display` mappings; plus
2. automatic expansion of every Display in `ref.lor_scene_display` for the task's `lor_scene_id`.

There is no Stage-level material branch.

This produces two failure classes:

- Stage-organized tasks with no explicit task material can show **0 Displays / 0 Containers** even when the Stage contains the intended group;
- Scene-organized tasks can appear to work while potentially overstating task material by automatically treating all Scene members as required.

Representative Production review evidence:

- Stage 01 `Claymation Panels` -> 0 resolved Displays although Stage 01 has active Displays;
- Stage 16 `Setup Northern Lights` -> 0;
- Stage 16 `Layout RGB Locations (20' Spacing, 32P & 30D)` -> 0;
- Stage 16 `Northern Lights Plug in Power & Network` -> 0;
- Christmas Story Scene currently resolves 8 Displays / 4 Containers because of automatic Scene expansion;
- additional operator-noted areas include Hwy 42 Traffic Signs, Rotary MSB Signs, and Front Entrance.

The fix is **not** simply to add automatic Stage expansion. Task material must remain a task-level reviewed requirement.

## Editing Requirement

The Catalog needs a practical way to maintain task material without forcing one Display at a time where a real work group already exists.

Required direction:

- show current required Displays for the selected reusable task;
- allow selecting a known Stage/Sub-stage/Scene/LOR group as a **bulk source** when that group truly matches the practical task;
- allow explicit add/remove/reassign corrections;
- preserve zero-Display tasks as valid;
- surface each Display's current Container after task material is selected;
- do not create a second maintained Container list when Container demand can be derived from current Display-to-Container relationships;
- keep supplemental support/KIT Container relationships explicit and separate because they are not always derivable from Display storage.

Bulk selection is an editing convenience, not an automatic inheritance rule.

## Container Rules

`ref.display.container_id` remains the current storage/transport relationship for a Display.

The resolver should derive Container demand from selected task Displays and deduplicate it. This is necessary because one Container/trailer may carry Displays for several Stages or tasks.

Known examples:

- Container 34 / Arch Trailer carries Displays for multiple Stages;
- Antenna Trailer carries material for several unrelated Display groups;
- a KIT/support Container can be required even when no task Display currently points to it.

Do not assign a Display to the wrong Container or wrong Stage merely to express a Setup dependency.

## Planning Boundary

Reusable task material is separate from:

- Stage/Scene Catalog organization;
- task predecessor/dependency relationships;
- preferred execution order;
- annual schedule/date assignment;
- readiness conditions;
- current Container movement state.

A task such as bearing lubrication can be real Setup work with no Display material. Conversely, a grouped panel-install task can require many Displays and several Containers.

## 2026 Session Gate

The operator decision remains: **do not create the 2026 Setup Session until the reconstructed 2025 plan is complete.**

Before propagation, task material must be trustworthy enough that planning/Pick List work does not inherit known false or missing Display/Container relationships.

## Implementation Gate

Before changing Production behavior:

1. inventory current `ref.setup_task_display` mappings and representative tasks;
2. identify tasks that legitimately require zero Displays;
3. identify practical group tasks whose material can be bulk-selected from existing Stage/Scene/LOR grouping evidence;
4. confirm the editing workflow against representative areas including Front Entrance, Hwy 42 Traffic Signs, Rotary MSB Signs, Northern Lights, and one known-good Scene group;
5. change the resolver only after the task-material editing/selection rule is explicit;
6. test that zero-Display tasks remain valid and that bulk group selection does not become silent automatic inheritance;
7. verify derived Container deduplication and shared-trailer behavior; and
8. perform protected browser validation before Production acceptance.

## Related Durable Sources

- [Setup Pick List Tablet Workflow](Setup_Pick_List_Tablet_Workflow_2026-09-09.md)
- [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md)
- [Setup engineering portal](README.md)
- [Google Drive Stage/Sub-stage/Scene folder SOP](../../../../../00_Project_Overview/Google_Drive/operatorSOP/Create_Stage_Substage_Scene_Folder.md)
- [Shared Field Context Database Layer Acceptance](../../07_Labeling_and_Scanning/Shared_Field_Context_Database_Layer_Acceptance_2026-08-23.md)
- GitHub Issue #122
