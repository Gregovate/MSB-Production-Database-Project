# Setup Session Manager Review Guide

## Purpose

Use this guide for the shared Setup Session application and the Production-backed **2025 historical review / training session**.

The 2025 Setup Session is being used to do two useful things at once:

- reconstruct and improve the real 2025 Setup record; and
- train a small group of future Setup Managers on the workflow before the 2026 Setup Session is created.

This is **not disposable test data**. Changes saved in this application are Production Database records.

## The most important safety rule

The selected Setup Session controls the allowable operational year.

```text
2025 historical review
    -> work dates and historical actual dates must be in 2025

2026 Setup Session
    -> work dates and operational dates must be in 2026
```

The browser limits date controls to the selected year, and the database independently rejects an operational date from the wrong year.

That means a reviewer working in 2025 cannot accidentally schedule a task for 2026 simply by entering the wrong date.

Audit timestamps remain truthful. If you correct a 2025 task during 2026, the task's historical operational date may be 2025 while its database `updated_at` / recording timestamp remains 2026.

## Access and sharing

The application may be shared by URL with approved reviewers, but **the link does not grant authority**.

Each reviewer must authenticate through the existing application access boundary and must have the appropriate Setup capability.

Current responsibilities are:

- **Reader / field user** — view permitted Setup information;
- **Manager / reviewer** — review/correct annual information, maintain reusable tasks, prerequisites, resources, task scope, annual order, and near-term scheduling;
- **Administrator** — all Manager capabilities plus annual Setup Session creation and promotion of an annual order into the reusable future baseline.

Only an Administrator should create the 2026 Setup Session.

Only an Administrator can use **Use Current Order as Future Baseline**. This prevents a 2025 training/reconstruction order or a one-year condition from silently becoming the starting order for a later season.

## What is permanent during 2025 review

There are two different kinds of information in the application.

### Annual 2025 information

This describes what happened or was planned in 2025:

- verification state;
- annual planned order;
- 2025 work-day/date/shift/crew-lane assignments;
- 2025 crew/time evidence;
- annual notes;
- progress/completion evidence.

These records belong only to the 2025 Setup Session.

### Reusable Setup knowledge

This describes how the work normally exists across seasons:

- task name and active state;
- Site-wide / Stage / Scene scope;
- normal local sequence (`10`, `20`, `30`...);
- normal crew range and expected duration;
- equipment/resources;
- prerequisites;
- completion point;
- readiness/weather notes; and
- reusable whole-Setup baseline order.

Edits to reusable information are intentionally permanent and may be used when the Administrator later creates 2026.

Do not treat reusable task edits as throwaway training changes.

## The Setup philosophy

This subsystem is deliberately not a traditional project-management schedule.

The normal operating cycle is:

```text
know all remaining Setup work
    -> keep it in a useful planned order
    -> look at prerequisites/readiness/resources
    -> schedule only the next few practical days
    -> perform work
    -> record progress/completion
    -> return to the remaining ordered backlog
    -> plan the next few days
```

Most unfinished work should remain **unscheduled** most of the time. That is normal.

A task belongs in Setup when it helps make a decision, can realistically be missed, has a meaningful prerequisite/resource, needs useful progress/completion tracking, or creates historical learning worth carrying forward.

Do not create tasks for routine actions that are already implied by real work. For example, ordinary unloading does not need a separate task merely because delivered material must come off a trailer.

## Reusable task versus annual task

A **Reusable Task** is the permanent definition of practical Setup work.

An **Annual Task** is that reusable task's occurrence in one Setup Session.

The two should not be confused. A 2025 annual change does not automatically redefine future seasons, while a reusable-task correction intentionally improves the permanent Setup model.

## Task scope: Park Infrastructure, Stage, or Scene

Reusable tasks can belong to three practical scopes.

### Park Infrastructure / no LOR Stage

Use the no-Stage scope for critical park-wide work that has no appropriate LOR Stage or Scene owner.

Current examples include:

- Remove Street Lights;
- Convert Street Lights to Show Power; and
- Turn On Site Breakers.

These tasks are not LOR-derived. Do not create a fake Stage, Scene, or Preview merely to hold them.

Their Procedures use the controlled non-LOR Google Drive root:

```text
G:\Shared drives\Display Folders\41 Park Infrastructure-PI
```

Current published Setup PDFs belong directly in:

```text
41 Park Infrastructure-PI\Procedures\Setup
```

Editable Google Doc sources belong in:

```text
41 Park Infrastructure-PI\Procedures\Setup\SourceDocs
```

Superseded Setup documents belong in:

```text
41 Park Infrastructure-PI\Procedures\Setup\Archive
```

Supporting Setup images belong in:

```text
41 Park Infrastructure-PI\Procedures\Setup\images
```

See:

`Docs/00_Project_Overview/Google_Drive/operatorSOP/Create_Site_Infrastructure_Procedure_Folder.md`

### Stage-level / General

Use Stage-level when the practical task belongs to a real LOR Stage generally but should not be forced into one Scene.

**Command Center is the important example.** `40-CommandCenter` has a real LOR Preview and is therefore legitimate Stage 40 even though its Preview currently has no wired inventory items.

Command Center work therefore belongs to Stage 40, including:

- Deliver and Set Up Command Center Trailer;
- Install WiFi Antenna;
- Install Gateway and Test Internet Connection; and
- Deploy Hotspots.

Do not move these into Park Infrastructure merely because the Preview has no wired Displays.

### Scene-level

Use Scene-level when a current LOR Scene is the natural reusable organizational home for the work.

The Manager assigns Scene scope explicitly. Setup does not infer Scene scope from task or Display names.

Example: `Install Fred's Stars` belongs to current Scene `02-Fred's Stars`.

## Collapsible organization and reconstruction gaps

The Reusable Task Catalog is grouped:

```text
Park Infrastructure
Stage
    Stage-level / General
    Scene
    Scene
```

Stage and Scene groups are collapsible to keep screen real estate manageable.

Missing reusable work is shown inline in its Stage/Scene context rather than in a detached reconstruction-gap list at the top of the screen.

## Reusable local sequence

Within Park Infrastructure, one Stage-level bucket, or one Scene, tasks normally use:

```text
10
20
30
40
```

The gaps make it easy to insert a newly discovered task at `15` or `25`, then normalize/reorder the group later.

Managers can reorder using drag/drop or the up/down controls.

This local sequence does not mean the entire Setup season is serial.

## Reusable whole-Setup baseline and annual planned order

The system keeps two different whole-Setup orders.

### Reusable baseline order

This is the normal starting order learned over time and intended to help the next Setup Session begin with a useful plan.

Only an Administrator can promote an annual order into this reusable baseline.

### Annual planned order

This is the current Setup Session's working opinion of what should happen next.

It may change because of:

- road construction or access restrictions;
- weather;
- volunteer turnout;
- lift/vehicle availability;
- leaves not yet fallen;
- material problems;
- predecessor work taking longer than expected; or
- an unexpected opportunity to complete another area early.

A strange annual order should remain annual unless an Administrator deliberately decides the new order is useful future knowledge.

## Planning filters

The planning screen is one ordered annual backlog.

Filters only expand or contract what you are viewing:

```text
Unscheduled
Scheduled
In Progress
Completed
```

Filtering does not duplicate or reorder tasks.

A task may also show **Blocked / Not Ready**. It can remain high in the planned order while still being unavailable for immediate work.

## Prerequisites and readiness

A prerequisite means another reusable task must complete first.

Example — Elf Choir:

```text
Locates
    -> Set Scaffold and Elves
        -> Install Notes and Conductor
```

Managers can add/remove prerequisites. The database blocks self-dependencies and circular prerequisite chains.

Readiness is different from a prerequisite. Festive Trees, for example, may have its prerequisites satisfied but still be NOT_READY until leaves have fallen.

## Add or copy reusable work

Use **Add Task Here** when creating genuinely new reusable work in a particular Park Infrastructure / Stage / Scene scope.

Use **Copy** when a new task is substantially similar to an existing reusable task.

Copy carries reusable definition fields and structured resources, but it does not blindly copy previous annual history or prerequisites.

A copied task gets a new reusable identity and should be reviewed in its destination scope.

## Rolling-horizon scheduling

Do not schedule the entire Setup season.

A normal workflow is to schedule the first few practical days, perform that work, then return to the ordered backlog and schedule the next few days.

A near-term work assignment contains:

- work date;
- shift — **Morning**, **Afternoon**, or **All Day**;
- crew lane — normally **Crew A**, **Crew B**, and occasionally **Crew C**;
- selected task; and
- planned crew count.

The work date must be inside the active Setup Session year. For the shared 2025 review, only 2025 dates are valid.

Removing a work-day assignment returns the task to the unscheduled backlog; it does not delete the task.

## Parallel crew lanes

Crew lanes are a lightweight dispatch aid, not an individual-person roster.

Example:

```text
Saturday Morning

Crew A                  Crew B                  Crew C (if needed)
Stage/Scene X           Stage/Scene Y           Park Infrastructure
Task(s)                 Task(s)                 Task(s)
```

Several crews can work at the same time. This is intentional and is one reason the annual planned order should not be mistaken for a rigid serial Gantt schedule.

## Multi-day tasks and progress

Do not split a practical task merely because it lasts more than one work period.

Festive Trees is the model example. One annual task can remain IN_PROGRESS while Captains record progress such as:

```text
Crew size: 4
Completed quantity: 3
Which units: Trees 1, 3, 4
Note: tall lift unavailable after noon
```

The task becomes COMPLETE only when the practical job is complete.

For ordinary tasks, the completion form stays compact. Partial/multi-unit detail is optional and can be expanded only when needed.

## Captain / Perform Work screen

The field screen brings together:

- task and scope;
- completion point/readiness/weather notes;
- prerequisite state;
- expected crew/time;
- structured equipment/resources;
- mapped Displays/support Containers and current/home-location context;
- current published Setup Procedure PDF;
- progress history; and
- progress/completion controls.

For Scene-scoped work, current Scene membership may supply the applicable Displays automatically. Fred's Stars is the current example: the Scene relationship identifies the Fred Star Displays and their current Container rather than requiring duplicate manual task/display relationships.

## Equipment and resources

Use structured resource relationships for recurring requirements such as lifts, vehicles, trailers, and tools.

Quantity and Required/Preferred status belong in the structured relationship instead of only in notes.

Do not invent counts. Stage 02 panel installation, for example, needs one powered stake pounder for the task while Short Stake Pounder and Tall Stake Pounder exist as distinct resource choices.

## Procedures

Stage- and Scene-scoped tasks use the established marked Google Drive Stage/Scene Procedure structure.

Park Infrastructure uses the exact non-LOR root:

```text
G:\Shared drives\Display Folders\41 Park Infrastructure-PI
```

The Captain should be able to open the current published Setup PDF without leaving the task screen.

## Pick Lists — next guarded layer

The intended Pick List flow remains:

```text
selected near-term Setup work
    -> required Displays/assets
    -> current Display-to-Container assignments
    + supplemental required/support Containers
    -> deduplicate shared Containers/trailers
    -> show why each physical item is needed
```

Pick Lists should remove manual material bookkeeping without creating fake labor tasks.

## Movement and scanning — current boundary

Scanning identifies a physical object. Setup owns the operational meaning of a future movement action.

Current permanent identifier patterns include:

```text
DISP:<display_id>
CONT:<container_id>
LOC:<location_code>
CTRL:<controller_id>
```

The Captain screen may show current material/location context, but narrow Setup movement/scanning write commands are still a separate guarded implementation step.

Do not infer a movement event merely because identifiers were scanned.

## 2025 review to 2026 transition

The 2025 review remains available as historical truth.

When the Administrator decides the 2025 reconstruction is useful enough and explicitly creates the 2026 Setup Session:

- 2026 gets its own annual task rows;
- the date guard changes automatically to 2026;
- 2025 annual records remain 2025 records;
- reusable task knowledge continues forward; and
- only an Administrator may deliberately promote an annual order into the reusable future baseline.

No reviewer action inside the 2025 session should implicitly create or schedule 2026.

## Related architecture

See:

`Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/Setup_Session_Shared_Review_and_Season_Year_Guard_2026-09-07.md`
