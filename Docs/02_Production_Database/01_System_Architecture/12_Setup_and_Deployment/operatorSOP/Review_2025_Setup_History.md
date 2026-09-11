# Review and Correct the 2025 Setup History

| Document Control | Value |
|---|---|
| Document Type | Operator Procedure |
| System | Production Database — Setup and Deployment |
| Task | Review and correct the 2025 Setup history and reusable Setup knowledge |
| Audience | Authorized Setup reviewers and managers |
| Status | CURRENT — live 2025 review plus current reusable-task development |
| Owner | MSB Setup administrator |
| Last Reviewed | 2026-09-11 |
| Keywords | Setup, 2025, historical review, reusable task, material, resources, verification |

## Purpose

Use the real 2025 Setup Session to preserve/correct 2025 history while improving reusable Setup knowledge before the 2026 Setup Session is created.

Changes are real Production changes. The current PostgreSQL reusable Catalog is the working task baseline. Historical spreadsheets/schedules remain evidence; they are not a parallel ongoing task master.

## Open the Setup Application

Use:

```text
https://my.sheboyganlights.org/setup/
```

Sign in through the normal MSB Google/Cloudflare Access login when prompted.

Confirm the selected session is:

```text
2025 — Historical Verification
```

Operational dates entered for this session must be in 2025. Audit/update timestamps remain the real current recording time.

## Understand the Two Kinds of Changes

### 2025 annual history

These changes describe what happened or was planned in 2025. Examples include:

- verification/reconciliation state;
- actual crew count or duration when known;
- actual start/completion information when known;
- annual notes;
- 2025-specific planned order; and
- 2025 work-day/scheduling information when useful for reconstruction.

### Reusable Task knowledge

These changes describe how MSB normally performs Setup work. Examples include:

- task name and active state;
- Park Infrastructure / Stage / Scene scope;
- normal local sequence/order;
- normal crew size and expected duration;
- Physical Effort;
- whether the task **Uses Display / Container Material**;
- prerequisites/readiness;
- equipment/resources and quantities;
- completion point; and
- other reusable instructions that should carry forward.

Reusable Task changes are permanent Setup knowledge and may become part of future seasons.

## Review a Task

1. Open the task in the 2025 Historical Verification session.
2. Read reusable task information and annual 2025 information separately.
3. Compare them with what you know and with reliable procedures/evidence.
4. Correct only information you can support.
5. Review whether the task normally requires Display/Container material.
6. Add annual notes when useful 2025-specific detail should be preserved.
7. Set the annual verification/reconciliation state only after the record has actually been reviewed.

Do not mark a task accepted merely because it exists.

## Add or Correct Reusable Tasks

If real Setup work is missing, Managers may add a reusable task when that work should normally exist beyond one historical occurrence.

Use the correct practical scope:

```text
Park Infrastructure / no LOR Stage
Stage-level / General
real Scene
```

Use **Add Task Here** or **Copy** where appropriate.

Do not create one task per panel or one task per Display merely to make material easier to represent. Build tasks at the practical work-package level used by crews.

Tasks such as locating, laying out an area, plugging power/network, greasing bearings, or similar work can be valid reusable tasks without Display material.

## Use the Display / Container Material Checkbox

Reusable task details now include:

```text
[ ] Uses Display / Container Material
```

### Leave it unchecked when the task does not require Display material

Examples can include:

- Locate Power & Network;
- layout/site preparation;
- plug-in/network preparation;
- Grease Bearings; or
- another valid task whose work does not depend on moving/installing the current Displays for that Stage/Scene.

An unchecked box is not a missing-data error.

### Check it when the task requires the current Display/Container material

When checked, Setup automatically uses the task's existing scope:

```text
Stage-level task
    -> current Stage-level LOR Display groups
    -> excludes true child-Scene material

real Scene task
    -> exact current Display membership of that Scene
```

Then Setup follows the resolved Displays to their current Containers.

The operator does **not** choose:

- an LOR Preview;
- a programming/display group;
- a separate LOR Scene merely as a material source; or
- a manual Display list for ordinary material resolution.

If the task's Stage/Scene scope is wrong, correct the task scope. Do not choose a different material source to compensate.

### Current staged-material limitation

The current resolver answers:

> What current Stage/Scene Displays and Containers are associated with this material-enabled task scope?

It does **not** yet answer:

> Which subset of that material should be picked or delivered for this exact work step today?

If several Stage-level tasks exist under one Stage, multiple material-enabled tasks can resolve the same Stage-level material. That is expected with the current model and does not mean all of the resolved material should be transported at the first step.

Magic Igloo is the key example: frame work may happen first while skins deliberately stay warm in the workshop until the later skin-install task. The current material checkbox does not yet subdivide those Stage materials by task step or release time.

Treat Material / Logistics as **resolved context**, not as a complete pick/release instruction. Task-specific staged material and timing remain future engineering work tracked in Issue #141.

### Color coding

Tasks with material enabled receive a colored marker/highlight in supported views. That is only a visual cue.

```text
checkbox = stored reusable-task fact
color    = visual reminder
```

The material summary shown with the task is read-only resolved context. Use it to confirm that Setup is resolving the expected Displays/Containers.

## Stage and Scene Organization

The reusable Catalog, Plan / Schedule, and Perform Work can present tasks by Stage with separate:

```text
Stage-level / General
Scene — <real Scene>
```

Programming-only LOR groups are not separate Setup Scenes merely because they exist in LOR.

Use **Planned order** when you need to see or change the annual planning sequence. Stage view is a presentation/grouping view and does not rewrite planned order by itself.

## Search

The **Find task or Stage** search applies across the reusable Catalog, Plan / Schedule, and Perform Work.

You can search by task, Stage, Scene, and related visible context. Clear the search to restore the complete view.

## Review Resources, Prerequisites, and Readiness

For reusable tasks, check whether practical requirements are represented correctly:

- lifts/vehicles/trailers/tools;
- other recurring resources;
- Physical Effort where known;
- real predecessor tasks that must complete first; and
- readiness conditions that may block work.

Do not invent quantities or dependencies merely to fill fields.

A predecessor is another Setup task that must be complete first. A readiness condition may instead be an external/site condition such as mowing/mulching being complete in the applicable work area. Do not create fake Setup tasks merely to represent outside conditions.

## Procedures and Instructions

Where a Setup task has a current published Setup procedure, the application may show that procedure and, for authorized Managers, the editable source used to maintain it.

If an editable procedure is corrected, the current published PDF must also be updated before the instruction is treated as current.

Detailed document-publishing instructions are owned by the Google Drive / Display Folder workflow.

## Ask Questions and Make Suggestions

The application remains under real-use evaluation. Report things such as:

- information that is hard to understand;
- missing information needed to make a Setup decision;
- awkward or repetitive steps;
- task organization that does not match real work;
- unexpected Display/Container material resolution;
- a Stage where material must be staged/released differently between separate tasks;
- resources or prerequisites that are difficult to represent;
- missing readiness behavior;
- search/filter/navigation problems; and
- ideas that would make 2026 planning or field work easier.

Do not silently work around a system problem by creating fake tasks, moving work to the wrong Stage/Scene, or duplicating material relationships.

## 2026 Creation Gate

There is currently no 2026 Setup Session.

A newly created Setup Session seeds **every active reusable task** into that annual Session. Therefore the active reusable Catalog must be cleaned before 2026 is created.

Do not force newer reusable tasks into the 2025 annual history just to make 2025 Plan / Schedule look complete. A valid reusable task can exist without a 2025 annual row.

Issue #145 tracks the Catalog-cleanup gate before 2026 creation.

## What Successful Review Looks Like

A useful review leaves:

- 2025 annual facts corrected where evidence exists;
- uncertain information left for follow-up rather than guessed;
- reusable task boundaries corrected at practical crew/work-package level;
- material enabled only for tasks that actually require LOR-derived Displays/Containers;
- non-material tasks left valid with material disabled;
- current material context reviewed without assuming it is a complete pick/release plan;
- correct Stage/real-Scene scope;
- resources, effort, predecessors/readiness, order, and normal expectations improved where supported;
- no fake records created merely for testing or UI workarounds; and
- no 2026 Session created until the active Catalog is ready to propagate.

## Related Documents

- [Setup operator procedures](README.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
- [Setup engineering handoff](../engineering/README.md)
