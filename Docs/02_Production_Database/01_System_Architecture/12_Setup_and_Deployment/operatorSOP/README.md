# Setup and Deployment Operator Procedures

| Document Control | Value |
|---|---|
| Document Type | Operator Portal |
| System | Production Database — Setup and Deployment |
| Audience | MSB reviewers, managers, and Setup operators |
| Status | CURRENT — Production runtime operational; UI/workflow in live evaluation |
| Owner | MSB Production Database / Setup administrator |
| Last Reviewed | 2026-09-11 |
| Keywords | Setup, 2025, historical review, training, reusable tasks, resources, material, prerequisites, Shift-drag, 2026 baseline |

Use this area for plain-English instructions for working in the Setup application. Engineering, database, service, permission, and deployment details belong in [`../engineering/`](../engineering/README.md).

## Current Application

Open the protected Setup application at:

```text
https://my.sheboyganlights.org/setup/
```

The current shared working session is:

```text
2025 — Historical Verification
```

The application uses real Production data. It is available for manager/reviewer use now, but the UI/workflow is still being evaluated through real 2025 review work.

Current Production client:

```text
Client V0.3.10
```

## What Do You Need To Do?

- [Review and Correct the 2025 Setup History](Review_2025_Setup_History.md) — verify 2025 information, improve reusable Setup knowledge, add missing tasks/resources where appropriate, mark which tasks use Display/Container material, add/correct prerequisites, and record questions or suggestions.

Additional task procedures will be added only when the corresponding workflow is actually production-operational.

## Equipment / Resource Workflow

Use the compact resource picker for ordinary task work:

```text
search existing resource
    -> select resource
    -> enter task quantity / Required-vs-Preferred / task notes
    -> add or update requirement
```

The normal picker is intentionally name-oriented. Search for an existing entry before creating anything new.

Use **Manage Resource Catalog** when the reusable catalog itself needs maintenance. Managers can search active and inactive entries and correct an existing resource in place, including name, type, catalog notes, active state, and optional display order.

Renaming an existing resource preserves its `setup_resource_id` and current task assignments. Exact normalized duplicate names are blocked, and likely matches are shown while entering a new resource name.

Task-specific quantity / Required-vs-Preferred / task notes remain separate from catalog-level identity and catalog notes.

## Material Checkbox

Reusable tasks have:

```text
[ ] Uses Display / Container Material
```

Use it this way:

- **unchecked** — the task does not require LOR-derived Display/Container material;
- **checked** — Setup automatically resolves the current Displays and Containers from the task's existing Stage or real Scene scope.

Do not choose an LOR Preview, programming group, or separate material source. The application already knows the task's Stage/Scene scope and resolves current material automatically.

A colored task marker/highlight is only a visual cue that the material checkbox is enabled. The checkbox is the actual stored setting.

It is normal for tasks such as locating, layout, network/power preparation, greasing, or other non-Display work to leave this box unchecked.

### Important current limitation

The current material result is **Stage/Scene material context**, not yet a task-specific pick/release list inside one Stage.

If one Stage has several separate physical Setup tasks, more than one material-enabled Stage-level task can resolve the same Stage-level Displays/Containers even when only part of that material should be brought to the park for the current step.

Example: Magic Igloo may need frame material first while skins should remain warm in the workshop until a later task. The current checkbox does not yet subdivide that Stage material by step or decide when each subset should leave storage.

Do **not** treat every resolved item as "pick this now" merely because it appears in the Material / Logistics context. Task-specific staged material and pick-list timing remain separate future work tracked in Issue #141.

## Moving Tasks Between Stage-level and Scene

Managers can drag a reusable task between **Stage-level / General** and a real **Scene** within the Stage. A task can also be dragged to another valid Stage/Scene destination.

This is a real reusable-scope change, not only a visual reorder. The application saves the new Stage/Scene scope through the governed Setup command and keeps the existing Stage/Scene validity checks.

Use this when the task was organized under the wrong Stage-level/Scene location. Do not create a fake Scene or use a programming-only LOR group as a Setup Scene merely to obtain a different material result.

## Adding and Reviewing Prerequisites

A prerequisite is another reusable Setup task that truly must be complete before the dependent task can proceed.

### Fast prerequisite entry

To make task A depend on task B:

```text
hold Shift before left-button-down on task A
    -> drag task A onto task B
    -> release
    -> task A depends on task B
```

Neither task moves during Shift-drag. Releasing over empty Stage/Scene space cancels the prerequisite gesture.

### Normal movement

Drag without Shift when you intend to reorder a task or move it to another valid Stage/Scene. Ordinary drag remains the normal movement interaction.

### Task-detail prerequisite controls

Open task detail to use the canonical prerequisite list. Each prerequisite appears once with **Up**, **Down**, and **Remove** controls. A separate **Add prerequisite** control remains available for manual entry.

After a prerequisite is assigned, it is no longer offered in that task's Add list.

**Up** and **Down** change review/display order only. They do not make one prerequisite depend on another. Every listed prerequisite remains independently required.

Circular prerequisite relationships are rejected. Do not work around that warning by creating fake tasks or reversing the intended dependency.

## Important Boundaries

- The 2025 review area uses real Production data.
- Annual 2025 corrections stay with the 2025 Setup Session.
- Reusable Task changes are permanent Setup knowledge and may affect future seasons.
- The material checkbox is reusable task knowledge, not a one-year 2025 fact.
- Resource-catalog identity/type/notes/active/order are reusable catalog facts; task quantity/requirement/notes remain task-specific.
- Operational dates entered for the selected Setup Session must be in that session's year.
- Only an Administrator may create a new annual Setup Session or carry annual order forward as the future reusable baseline.
- Hard predecessors are not the same as preferred order or outside/site readiness conditions.
- Extra Materials / KIT assignments / material-source tracking remain separate work in Issue #167.
- Pick Lists and Container/Display movement/scanning writes are not part of the current live-review workflow.
- Do not create fake records merely to test the UI. Use real review work and report workflow/UI findings instead.

## During Live Evaluation

Managers and reviewers are encouraged to:

- open tasks and compare annual 2025 information with reusable task information;
- add genuinely missing reusable tasks;
- search for existing resource catalog entries before creating new ones;
- correct poor resource names in place through **Manage Resource Catalog** instead of creating replacements;
- mark **Uses Display / Container Material** only when that task really needs the current Display/Container material for its Stage/Scene work;
- leave the material checkbox off for valid non-material tasks;
- treat resolved material as context, not an automatic instruction to pick every item immediately;
- add/correct resources and real prerequisites;
- correct task scope, order, crew/time expectations, and notes where supported;
- verify records only when they have actually been reviewed;
- leave uncertain information UNVERIFIED or mark it NEEDS CORRECTION;
- ask questions and make suggestions about confusing, missing, or inefficient workflow; and
- report UI problems instead of working around them silently.

The known long-page task-context usability improvement identified during V0.3.10 acceptance is tracked separately in Issue #169.

## Related Documents

- [Setup and Deployment](../README.md)
- [Review and Correct the 2025 Setup History](Review_2025_Setup_History.md)
- [Engineering handoff](../engineering/README.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
