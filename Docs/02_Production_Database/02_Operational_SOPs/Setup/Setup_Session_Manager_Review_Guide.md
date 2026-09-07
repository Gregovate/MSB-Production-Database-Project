# Setup Session Manager Review Guide

| Document Control | Value |
|---|---|
| Document Type | Operator / Manager Procedure |
| System | Production Database — Setup Session |
| Audience | Setup Managers, reviewers, and administrators |
| Status | CURRENT — live 2025 review/training workflow; UI/workflow evaluation remains open |
| Owner | MSB Production Database / Setup administrator |
| Last Reviewed | 2026-09-07 |

## Purpose

Use this guide for the live Setup application and the Production-backed **2025 Historical Verification** session.

The 2025 session has two purposes:

- reconstruct and improve the real 2025 Setup record; and
- train future Setup Managers by using the actual workflow before the 2026 Setup Session is created.

This is **not disposable test data**. Changes saved in the application are real Production Database records.

The application itself is still under live evaluation. Managers should report questions, suggestions, missing information, confusing screens, and workflow problems instead of silently adapting around them.

## Open the Application

Use:

```text
https://my.sheboyganlights.org/setup/
```

Sign in through the normal MSB Google/Cloudflare Access login.

Confirm the selected session is:

```text
2025 — Historical Verification
```

## The Most Important Safety Rule

The selected Setup Session controls the allowable operational year.

```text
2025 Historical Verification
    -> work dates and historical actual dates must be in 2025

2026 Setup Session
    -> work dates and operational dates must be in 2026
```

The browser limits date controls to the selected year, and the database independently rejects an operational date from the wrong year.

Audit timestamps remain truthful. If you correct a 2025 task during 2026, the historical operational date may be 2025 while the database records the correction as having been made in 2026.

## Roles and Authority

A shared link does not grant authority. Each user must authenticate and have the appropriate Setup capability.

Current responsibilities are:

- **Reader / field user** — view permitted Setup information;
- **Manager / reviewer** — review and correct annual 2025 information, maintain reusable tasks, task scope, prerequisites, resources, order, and supported planning information; and
- **Administrator** — all Manager capabilities plus annual Setup Session creation and promotion of an annual order into the reusable future baseline.

Only an Administrator should create the 2026 Setup Session.

Only an Administrator can use **Use Current Order as Future Baseline**.

## Annual 2025 Information vs Reusable Setup Knowledge

This distinction is fundamental.

### Annual 2025 information

Annual information describes what happened or was planned in 2025:

- verification state;
- annual planned order;
- 2025 work-day/date/shift/crew-lane assignments when used;
- 2025 crew/time evidence;
- annual notes; and
- progress/completion evidence.

These records belong only to the 2025 Setup Session.

### Reusable Setup knowledge

Reusable information describes how the work normally exists across seasons:

- task name and active state;
- Park Infrastructure / Stage / Scene scope;
- normal local sequence/order;
- normal crew range and expected duration;
- equipment/resources;
- prerequisites;
- completion point;
- readiness/weather notes; and
- reusable whole-Setup baseline order.

Edits to reusable information are intentionally permanent and may be used when the Administrator later creates 2026.

Before changing reusable information, ask:

> Is this a normal Setup rule we want to carry forward, or is this only something that happened in 2025?

If it only happened in 2025, keep it in annual history.

## Review and Verify Existing Tasks

For each task you review:

1. Open the task in the 2025 session.
2. Read the reusable definition and annual 2025 information separately.
3. Compare them with what you know and with reliable procedures/evidence.
4. Correct only information you can support.
5. Add annual notes when useful 2025-specific detail should be preserved.
6. Set the verification state only after the record has actually been reviewed.

Verification states are:

```text
UNVERIFIED
VERIFIED
NEEDS CORRECTION
```

Leave a task UNVERIFIED when you do not know enough. Use NEEDS CORRECTION when you know something is wrong but the correct answer still needs work.

Do not mark a task VERIFIED merely because the task exists.

## Add Missing Reusable Tasks

If real Setup work is missing, Managers may add a reusable task when that work should normally exist beyond one historical occurrence.

Use **Add Task Here** in the correct scope. Use **Copy** when the new task is substantially similar to an existing task, then review the copy carefully.

A task is useful when it:

- can realistically be missed;
- affects readiness, planning, or resources;
- has meaningful prerequisites;
- needs useful progress/completion tracking; or
- preserves operational learning worth carrying forward.

Do not create separate tasks for ordinary actions that are already implied by the real work.

## Choose the Correct Scope

Reusable tasks can belong to three practical scopes.

### Park Infrastructure / no LOR Stage

Use this only for park-wide work with no appropriate LOR Stage or Scene owner.

Examples include street-light and site-breaker work.

These Procedures use:

```text
G:\Shared drives\Display Folders\41 Park Infrastructure-PI
```

Do not create a fake LOR Stage, Scene, or Preview merely to hold park-wide work.

### Stage-level / General

Use Stage-level when the task belongs to a real LOR Stage generally but should not be forced into a Scene.

`40-CommandCenter` is the important example. It remains legitimate Stage 40 because it has a real LOR Preview, even though its Preview currently has no wired inventory items.

### Scene

Use Scene scope when a current LOR Scene is the natural reusable organizational home for the work.

The Manager assigns Scene scope explicitly. Do not infer Scene ownership merely from a task or Display name.

## Review Resources

Use structured resources for recurring requirements such as:

- lifts;
- vehicles;
- trailers;
- tools;
- stake pounders; and
- other equipment required to perform the task.

Review:

- the correct resource;
- quantity;
- Required vs Preferred status; and
- whether the requirement belongs as reusable knowledge.

Do not invent quantities merely to fill a field.

If a resource itself is missing from the catalog and the application permits you to add it, use a clear durable name that represents the real equipment/resource rather than a one-time note.

## Review Prerequisites and Readiness

A prerequisite means another reusable task must complete first.

Example:

```text
Locates / Field Cleared
    -> Set Scaffold and Elves
        -> Install Notes and Conductor
```

Readiness is different from a prerequisite. A task may have all prerequisites satisfied but still be NOT_READY because of weather, leaves, access, equipment, or another practical condition.

Use prerequisites only for real repeatable dependencies. Do not build a rigid serial chain just because tasks were performed in that order once.

## Review Order

The system keeps two different whole-Setup orders.

### Reusable baseline order

This is the normal starting order learned over time. Only an Administrator may promote an annual order into this future baseline.

### Annual planned order

This is the current Setup Session's working opinion of what should happen next.

It may legitimately differ because of weather, volunteer turnout, equipment, access, road work, leaves, material problems, or opportunities to complete another area early.

A strange 2025 order should remain a 2025 fact unless it represents a genuinely better reusable rule.

## Rolling-Horizon Planning

The Setup system is not intended to be a rigid Gantt schedule.

The normal operating cycle is:

```text
know all remaining Setup work
    -> keep it in useful order
    -> check prerequisites/readiness/resources
    -> schedule only the next few practical days
    -> perform work
    -> record progress/completion
    -> return to the remaining backlog
```

Most unfinished work should remain unscheduled most of the time. That is normal.

## Multi-Day Work and Progress

Do not split a practical task merely because it lasts more than one work period.

One annual task may remain IN_PROGRESS while progress is recorded over several work periods. Complete it only when the practical job is complete.

## Procedures

Stage- and Scene-scoped tasks use the established marked Google Drive Procedure structure.

Park Infrastructure uses:

```text
G:\Shared drives\Display Folders\41 Park Infrastructure-PI
```

Where the application shows a current published Setup PDF, review whether it still matches the work. Authorized Managers may also see the editable source used to maintain it.

If an editable procedure is corrected, update the current published PDF before treating the instruction as current.

## Ask Questions and Make Suggestions

This review period is also how we improve the application before the 2026 Setup cycle.

Report things such as:

- a field or label you do not understand;
- missing information you need to make a decision;
- information that appears duplicated or unnecessary;
- a task that belongs in a different place;
- difficulty representing a resource or prerequisite;
- an awkward or repetitive workflow;
- missing search/filter/navigation behavior;
- a screen that does not match how Setup crews actually work;
- a task/data problem that the application makes hard to correct; and
- ideas that would make 2026 planning or field work easier.

A useful finding does not have to be a software bug. Operational suggestions are part of the evaluation.

## Current Live Boundary

Live now:

- Production-backed 2025 review/training;
- verification and correction of annual 2025 information;
- reusable task creation/copy and maintenance;
- task scope/order/prerequisite/resource maintenance;
- supported annual planning/review controls;
- Procedure/document context; and
- authenticated browser access.

Not yet part of the current Production-ready workflow:

- Pick List generation; and
- Container/Display movement/scanning write commands.

Do not infer a movement event merely because an identifier was scanned or a review action occurred.

## 2025 Review to 2026 Transition

There is currently no 2026 Setup Session.

When the Administrator decides the 2025 reconstruction is useful enough and explicitly creates 2026:

- 2026 gets its own annual task rows;
- the date guard changes automatically to 2026;
- 2025 annual records remain 2025 records; and
- reusable task knowledge continues forward.

No Manager/reviewer action inside the 2025 session should implicitly create or schedule 2026.

## Related Documents

- [Setup operator portal](../../01_System_Architecture/12_Setup_and_Deployment/README.md)
- [2025 review procedure](../../01_System_Architecture/12_Setup_and_Deployment/operatorSOP/Review_2025_Setup_History.md)
- [Setup Session Shared Review and Season-Year Guard](../../01_System_Architecture/12_Setup_and_Deployment/Setup_Session_Shared_Review_and_Season_Year_Guard_2026-09-07.md)
