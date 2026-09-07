# Setup and Deployment

| Document Control | Value |
|---|---|
| Document Type | Operator / User Portal |
| System | Production Database — Setup and Deployment |
| Audience | MSB volunteers, reviewers, managers, and Setup operators |
| Status | CURRENT — Production runtime operational; Setup UI/workflow in live evaluation |
| Owner | MSB Production Database / Setup administrator |
| Last Reviewed | 2026-09-07 |
| Keywords | Setup, 2025 review, training, 2026 plan, Setup procedures, deployment |

Setup and Deployment covers the work of planning and carrying out the annual move from storage to the park, plus the information crews need while installing the show.

The Setup application is now live at:

```text
https://my.sheboyganlights.org/setup/
```

The current working session is **2025 — Historical Verification**. It uses real Production data so managers can reconstruct what happened in 2025, learn the workflow, improve reusable Setup knowledge, and identify UI/workflow problems before the 2026 Setup Session is created.

The application is operational, but the Setup/UI subsystem is still in **live evaluation**. The current review period is intended to generate questions, corrections, suggestions, and usability findings before final acceptance.

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

Production deployment is accepted, but final UI/workflow acceptance is intentionally open while managers use the 2025 session.

Current known boundaries:

- no 2026 Setup Session has been created;
- Pick List generation is not yet a live Production workflow;
- Container/Display movement and scanning write commands remain outside this review boundary; and
- the open Setup PRs remain the active engineering workstream until live-use findings are resolved.

## Related Systems

- [Operator procedures](operatorSOP/README.md)
- [Engineering handoff](engineering/README.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Wiring System](../09_Wiring_System/README.md)

The prior engineering-heavy Setup/Deployment root portal remains preserved at [`engineering/Legacy_Setup_and_Deployment_Engineering_Portal_2026-09-07.md`](engineering/Legacy_Setup_and_Deployment_Engineering_Portal_2026-09-07.md) so established technical history and inbound references are not lost.