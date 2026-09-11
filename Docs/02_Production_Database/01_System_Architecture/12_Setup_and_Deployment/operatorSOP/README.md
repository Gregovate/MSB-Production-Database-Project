# Setup and Deployment Operator Procedures

| Document Control | Value |
|---|---|
| Document Type | Operator Portal |
| System | Production Database — Setup and Deployment |
| Audience | MSB reviewers, managers, and Setup operators |
| Status | CURRENT — Production runtime operational; UI/workflow in live evaluation |
| Owner | MSB Production Database / Setup administrator |
| Last Reviewed | 2026-09-11 |
| Keywords | Setup, 2025, historical review, training, reusable tasks, resources, material, 2026 baseline |

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

## What Do You Need To Do?

- [Review and Correct the 2025 Setup History](Review_2025_Setup_History.md) — verify 2025 information, improve reusable Setup knowledge, add missing tasks/resources where appropriate, mark which tasks use Display/Container material, and record questions or suggestions.

Additional task procedures will be added only when the corresponding workflow is actually production-operational.

## Material Checkbox

Reusable tasks now have:

```text
[ ] Uses Display / Container Material
```

Use it this way:

- **unchecked** — the task does not require LOR-derived Display/Container material;
- **checked** — Setup automatically resolves the current Displays and Containers from the task's existing Stage or real Scene scope.

Do not choose an LOR Preview, programming group, or separate material source. The application already knows the task's Stage/Scene scope and resolves current material automatically.

A colored task marker/highlight is only a visual cue that the material checkbox is enabled. The checkbox is the actual stored setting.

It is normal for tasks such as locating, layout, network/power preparation, greasing, or other non-Display work to leave this box unchecked.

## Important Boundaries

- The 2025 review area uses real Production data.
- Annual 2025 corrections stay with the 2025 Setup Session.
- Reusable Task changes are permanent Setup knowledge and may affect future seasons.
- The material checkbox is reusable task knowledge, not a one-year 2025 fact.
- Operational dates entered for the selected Setup Session must be in that session's year.
- Only an Administrator may create a new annual Setup Session or carry annual order forward as the future reusable baseline.
- Pick Lists and Container/Display movement/scanning writes are not part of the current live-review workflow.
- Do not create fake records merely to test the UI. Use real review work and report workflow/UI findings instead.

## During Live Evaluation

Managers and reviewers are encouraged to:

- open tasks and compare annual 2025 information with reusable task information;
- add genuinely missing reusable tasks;
- mark **Uses Display / Container Material** only when that task really needs the current Display/Container material for its Stage/Scene work;
- leave the material checkbox off for valid non-material tasks;
- add/correct resources and prerequisites;
- correct task scope, order, crew/time expectations, and notes where supported;
- verify records only when they have actually been reviewed;
- leave uncertain information UNVERIFIED or mark it NEEDS CORRECTION;
- ask questions and make suggestions about confusing, missing, or inefficient workflow; and
- report UI problems instead of working around them silently.

## Related Documents

- [Setup and Deployment](../README.md)
- [Engineering handoff](../engineering/README.md)
- [Detailed Manager Review Guide](../../../02_Operational_SOPs/Setup/Setup_Session_Manager_Review_Guide.md)
