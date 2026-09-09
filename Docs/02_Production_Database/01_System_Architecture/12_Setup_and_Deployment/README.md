# Setup and Deployment

| Document Control | Value |
|---|---|
| Document Type | Operator / User Portal |
| System | Production Database — Setup and Deployment |
| Audience | MSB volunteers, reviewers, managers, and Setup operators |
| Status | CURRENT — Production reusable catalog rebuilt; 2025 review and live task development continue |
| Owner | MSB Production Database / Setup administrator |
| Last Reviewed | 2026-09-09 |
| Keywords | Setup, 2025 review, training, 2026 plan, Setup procedures, deployment |

Setup and Deployment covers the work of planning and carrying out the annual move from storage to the park, plus the information crews need while installing the show.

The Setup application is live at:

```text
https://my.sheboyganlights.org/setup/
```

The current working session is **2025 — Historical Verification**. It uses real Production data so managers can reconstruct what happened in 2025, improve reusable Setup knowledge, and identify workflow problems before the 2026 Setup Session is created.

## Current PostgreSQL Working Baseline

The reusable task reconstruction was deployed to Production on 2026-09-09. The current working baseline in PostgreSQL is:

```text
active reusable tasks      = 185
total reusable task rows   = 187
reusable dependencies      = 0
2026 Setup Sessions        = 0
```

The two additional reusable rows are retired identities preserved for history. The dependency set is intentionally empty pending the reviewed predecessor/readiness pass.

The reviewed reconstruction workbook and historical schedules remain evidence for how this baseline was built, but they are **not the ongoing master task list**. From this point forward, continue building, correcting, organizing, and reviewing reusable Setup tasks against the **current Production PostgreSQL data**. New historical evidence may inform a task correction, but the current PostgreSQL catalog is the working source of truth.

The application remains in live evaluation. Managers should continue to report missing tasks, incorrect scope/order, prerequisite/readiness needs, and UI/workflow problems rather than silently working around them.

## Start Here

### Review the 2025 Setup history

Managers and authorized reviewers should start with:

[Review and Correct the 2025 Setup History](operatorSOP/Review_2025_Setup_History.md)

During this review you may, where supported by evidence:

- verify or correct 2025 annual information;
- add missing reusable Setup tasks;
- correct task scope and normal order;
- add or correct prerequisites;
- add or correct equipment/resources;
- improve normal crew/time/readiness information;
- review current Setup procedures; and
- record questions or suggestions for the Setup workflow.

Do not change information merely to make a record look complete. Unknown information may remain UNVERIFIED or be marked NEEDS CORRECTION.

### Find current Stage Setup instructions

For current published Setup/Takedown/Inspection documents by Display, Stage, Sub-stage, or Scene, use:

```text
https://my.sheboyganlights.org/procedures/
```

Field-facing Stage Setup Instructions remain separate from repository operator procedures. They are the documents crews use while physically installing Stages/Scenes in the park.

## What Do You Need To Do?

- [Review or correct the 2025 Setup history](operatorSOP/Review_2025_Setup_History.md)
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

The selected Setup Session controls the allowable operational year. The 2025 session accepts 2025 operational dates only. Audit timestamps still show when the change was actually recorded.

Only an Administrator may create a new annual Setup Session or promote an annual order into the future reusable baseline.

## Current Evaluation Boundary

The reconstructed reusable catalog is accepted in Production, but Issue #122 remains open because the broader Setup Session workflow is not finished.

Current known boundaries:

- no 2026 Setup Session has been created;
- the current PostgreSQL reusable catalog is the working baseline and will continue to be corrected as real task knowledge is found;
- the predecessor/readiness pass is still required before creating 2026; the current reusable dependency count is intentionally zero;
- Pick List generation is not yet a live Production workflow;
- Container/Display movement and scanning write commands remain outside the current live workflow;
- known catalog corrections can still be found during live review, such as the missing physical Frosty setup task discovered immediately after deployment; and
- Stage-level ↔ Scene drag/drop is tracked separately in Issue #133 and is not a blocker to continuing catalog work.

## Related Systems

- [Operator procedures](operatorSOP/README.md)
- [Engineering handoff](engineering/README.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Wiring System](../09_Wiring_System/README.md)

The prior engineering-heavy Setup/Deployment root portal remains preserved at [`engineering/Legacy_Setup_and_Deployment_Engineering_Portal_2026-09-07.md`](engineering/Legacy_Setup_and_Deployment_Engineering_Portal_2026-09-07.md) so established technical history and inbound references are not lost.
