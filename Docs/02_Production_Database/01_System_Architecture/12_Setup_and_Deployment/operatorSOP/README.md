# Setup and Deployment Operator Procedures

| Document Control | Value |
|---|---|
| Document Type | Operator Portal |
| System | Production Database — Setup and Deployment |
| Audience | MSB reviewers, managers, and Setup operators |
| Status | CURRENT — Production reusable catalog rebuilt; live review/task development continues |
| Owner | MSB Production Database / Setup administrator |
| Last Reviewed | 2026-09-09 |
| Keywords | Setup, 2025, historical review, training, reusable tasks, resources, 2026 baseline |

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

The application uses real Production data.

The reusable catalog reconstruction was accepted in Production on 2026-09-09. Current working baseline:

```text
active reusable tasks    = 185
total reusable rows      = 187
reusable prerequisites   = 0
2026 Setup Sessions      = 0
```

The prerequisite count is intentionally zero until the reviewed predecessor/readiness pass rebuilds the real dependency model.

The current PostgreSQL catalog is now the working source for task development. The reconstruction workbook and historical schedules remain evidence, but operators/managers should continue adding and correcting real reusable tasks in the live Setup application rather than maintaining a separate spreadsheet master.

## What Do You Need To Do?

- [Review and Correct the 2025 Setup History](Review_2025_Setup_History.md) — verify 2025 information, improve reusable Setup knowledge, add missing tasks/resources where appropriate, and record questions or suggestions.
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md) — includes current rules for task scope, Display ownership, Containers, predecessors/readiness, and reusable task development.

Additional task procedures will be added only when the corresponding workflow is actually Production-operational.

## Important Task-Building Rules

Keep these concepts separate:

```text
Task scope        = where the work belongs
Display ownership = which Displays are part of that reusable work package
Container         = storage/transport mechanism for Displays/material
```

Important operator rules:

- a task can belong to a Stage/Scene even when **no Display is assigned** to it;
- example: `Grease Bearings` belongs at `01-Front Gate` even though it should not own GateWrap/GateWreath Displays;
- one Display may belong to **zero or one** reusable Setup task, never two;
- one reusable task may own many Displays or none;
- do not create one task per panel merely to make Display relationships easy;
- use practical crew/work-package tasks such as `Set Up Traffic Signs`, `Set Up MSB & Rotary Signs`, or `Volunteer Path Setup` when those are independently planned/tracked jobs;
- Stage/Scene placement does not automatically mean every task in that scope owns every Display in the scope;
- Containers normally tell us where Displays are stored and how they get to the park; they do not define task scope;
- some Containers are themselves part of the deployed show (`display_pallet`) and may remain at the park until Takedown instead of returning to the workshop after unloading; and
- the current Material / Logistics panel is still being corrected to follow these rules, so do not move tasks to the wrong scope or duplicate Display assignments just to make that panel look populated.

See the detailed Manager guide for the full operating model and examples.

## Important Boundaries

- The 2025 review area uses real Production data.
- Annual 2025 corrections stay with the 2025 Setup Session.
- Reusable Task changes are permanent Setup knowledge and may affect future seasons.
- Continue reusable task development against the current PostgreSQL catalog; do not recreate a parallel spreadsheet master.
- Operational dates entered for the selected Setup Session must be in that session's year.
- Only an Administrator may create a new annual Setup Session or carry annual order forward as the future reusable baseline.
- Do not create the 2026 Setup Session until the current catalog and predecessor/readiness pass are useful enough for planning.
- Pick Lists, governed task-to-Display ownership editing, and Container/Display movement/scanning writes are not part of the current live workflow.
- Do not create fake records merely to test the UI. Use real review work and report workflow/UI findings instead.

## During Live Evaluation

Managers and reviewers are encouraged to:

- open tasks and compare annual 2025 information with reusable task information;
- add genuinely missing reusable tasks discovered during live review;
- add/correct resources and prerequisites;
- correct task scope, order, crew/time expectations, effort, and notes where supported;
- identify the practical Display work package for Display-bearing tasks without creating one task per Display;
- verify records only when they have actually been reviewed;
- leave uncertain information UNVERIFIED or mark it NEEDS CORRECTION;
- ask questions and make suggestions about confusing, missing, or inefficient workflow; and
- report UI problems instead of working around them silently.

A current example is the missing physical `Set Up Frosty` task discovered after catalog deployment. The old transport entry `Bring Frosty to park` remains logistics evidence; the live catalog needs the reusable physical setup task and its Stars prerequisite relationship.

## Related Documents

- [Setup and Deployment](../README.md)
- [Engineering handoff](../engineering/README.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
