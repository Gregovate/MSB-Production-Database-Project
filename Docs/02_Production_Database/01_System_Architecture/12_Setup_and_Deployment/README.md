# Setup and Deployment

| Document Control | Value |
|---|---|
| Document Type | Operator / User Portal |
| System | Production Database — Setup and Deployment |
| Audience | MSB volunteers, reviewers, managers, and Setup operators |
| Status | CURRENT — Production runtime operational; Setup UI/workflow in live evaluation |
| Owner | MSB Production Database / Setup administrator |
| Last Reviewed | 2026-09-12 |
| Keywords | Setup, 2025 review, reusable tasks, active task context, resources, prerequisites, Shift-drag, Setup procedures, deployment |

Setup and Deployment covers the work of planning and carrying out the annual move from storage to the park, plus the information crews need while installing the show.

The Setup application is live at:

```text
https://my.sheboyganlights.org/setup/
```

The current working session is **2025 — Historical Verification**. It uses real Production data so managers can reconstruct what happened in 2025, improve reusable Setup knowledge, and identify UI/workflow problems before the 2026 Setup Session is created.

Current Production client:

```text
Client V0.3.11
```

## Start Here

### Review the 2025 Setup history and reusable tasks

Managers and authorized reviewers should start with:

[Review and Correct the 2025 Setup History](operatorSOP/Review_2025_Setup_History.md)

During this review you may, where supported by evidence:

- verify or correct 2025 annual information;
- add, delete, deactivate, or correct reusable Setup tasks through the supported controls;
- correct task Stage/Scene scope and normal order;
- mark whether a reusable task **Uses Display / Container Material**;
- add, remove, and reorder real task prerequisites;
- use **Shift + drag** in the Catalog for fast prerequisite entry;
- search and assign existing equipment/resources;
- use **Manage Resource Catalog** to rename/correct resource entries in place, review inactive entries, and maintain catalog notes/type/active state/optional display order;
- improve normal crew/time/readiness information;
- review current Setup procedures; and
- record questions or suggestions for the Setup workflow.

Do not change information merely to make a record look complete.

### Persistent active task identity

Setup V0.3.11 keeps the selected reusable task identity visible in the sticky application header while you scroll through long task detail.

The header shows **ACTIVE TASK** plus the selected Stage/task identity. Switching tasks updates that identity immediately. This is an edit-safety control for Catalog cleanup: the operator should always be able to tell which reusable task is active before changing reusable task information.

The persistent identity does not replace the normal task-detail heading and does not change Save / Discard / Stay dirty-edit behavior.

### Resource catalog maintenance

The normal task-resource picker is intentionally name-oriented. Search for the existing resource first, then set task-specific quantity, Required-vs-Preferred, and task notes.

Use **Manage Resource Catalog** only when the reusable catalog entry itself needs correction. Renaming an existing catalog row preserves its `setup_resource_id` and existing task assignments. Exact normalized duplicate names are blocked, and likely matches are shown while entering a new resource name.

The optional numeric catalog display order remains available for review/maintenance, but operators do not need to maintain numeric order merely to make the normal picker usable.

### Prerequisite shortcuts

A hard prerequisite is another reusable Setup task that really must finish first.

To make task A depend on task B:

```text
hold Shift before left-button-down on task A
    -> drag A onto task B
    -> release
```

Neither task moves during Shift-drag. Ordinary drag without Shift continues to move/reorder tasks and can move a task to another valid Stage/Scene.

Open task detail for the canonical prerequisite list, manual **Add prerequisite**, **Up**, **Down**, and **Remove** controls. Up/Down changes display/review order only; it does not create dependency relationships between prerequisites.

### Display / Container material

The reusable task editor includes:

```text
[ ] Uses Display / Container Material
```

When checked, Setup automatically resolves the current Displays and Containers from the task's existing Stage or real Scene. Operators do not choose an LOR Preview, programming group, or separate material source.

Leave the box unchecked for valid tasks that do not require Display material, such as locating, power/network preparation, greasing, or other non-Display work.

### Find current Stage Setup instructions

For current published Setup/Takedown/Inspection documents by Display, Stage, Sub-stage, or Scene, use:

```text
https://my.sheboyganlights.org/procedures/
```

Field-facing Stage Setup Instructions remain separate from repository operator procedures. They are the documents crews use while physically installing Stages/Scenes in the park.

## What Do You Need To Do?

- [Review or correct the 2025 Setup history and reusable task knowledge](operatorSOP/Review_2025_Setup_History.md)
- [See all Setup operator procedures](operatorSOP/README.md)
- [Maintain or publish Stage Setup documents](../../../00_Project_Overview/Google_Drive/README.md)
- [Open the Setup application](https://my.sheboyganlights.org/setup/)
- [Open Setup/Procedure documents](https://my.sheboyganlights.org/procedures/)
- [Engineering / development / recovery](engineering/README.md)

## Important 2025 Review Rule

There are two different kinds of information in the Setup application:

```text
2025 annual information
    = what happened or was planned in 2025

Reusable Task information
    = normal Setup knowledge that may carry forward
```

A correction that only applies to 2025 belongs in the 2025 annual history. A correction to how MSB normally performs a task belongs in the reusable task definition.

The **Uses Display / Container Material** setting, reusable resource requirements, and reusable prerequisites are reusable task knowledge. They should describe normal Setup behavior, not something that happened only in 2025.

The selected Setup Session controls the allowable operational year. The 2025 session accepts 2025 operational dates only. Audit timestamps still show when the change was actually recorded.

Only an Administrator may create a new annual Setup Session or promote an annual order into the future reusable baseline.

## Current Evaluation Boundary

Production deployment is accepted, but broader Setup workflow development remains active while managers use the 2025 session and clean the reusable Catalog.

Current known boundaries:

- no 2026 Setup Session has been created;
- active reusable Catalog cleanup is required before 2026 creation because all active reusable tasks are seeded into a new annual Session;
- Extra Materials / KIT assignments / material-source tracking remain separate work in Issue #167;
- structured outside/site readiness remains separate from task prerequisites;
- task-specific staged material/Pick List timing remains separate work in Issue #141;
- persistent active-task context is accepted in Production as Setup V0.3.11 under Issue #169;
- Pick List generation is not yet a live Production workflow; and
- Container/Display movement and scanning write commands remain outside this review boundary.

## Related Systems

- [Operator procedures](operatorSOP/README.md)
- [Engineering handoff](engineering/README.md)
- [Setup Active Task Context V0.3.11 Production Acceptance — 2026-09-12](../../../../../Setup/Acceptance/Setup_Active_Task_Context_V0311_Production_Acceptance_2026-09-12.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Wiring System](../09_Wiring_System/README.md)

The prior engineering-heavy Setup/Deployment root portal remains preserved at [`engineering/Legacy_Setup_and_Deployment_Engineering_Portal_2026-09-07.md`](engineering/Legacy_Setup_and_Deployment_Engineering_Portal_2026-09-07.md) so established technical history and inbound references are not lost.
