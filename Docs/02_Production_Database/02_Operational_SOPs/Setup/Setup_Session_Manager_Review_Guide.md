# Setup Session Manager Review Guide

## Purpose

Use this guide while reviewing the final Setup Session browser candidate and the reconstructed 2025 Setup work plan.

The current disposable candidate is intended to let Managers test the operating model before Production installation:

- correct reusable Setup tasks;
- verify reconstructed 2025 annual information;
- organize reusable work by **Site-wide / Infrastructure**, Stage-level, or Scene-level scope;
- maintain prerequisites;
- review crew/time and equipment/resource expectations;
- establish reusable and annual Setup order;
- schedule only the next practical few work days;
- dispatch parallel Crew A / B / C lanes;
- open the current published Setup Procedure PDF from the Captain view;
- see mapped material/current-location context; and
- record task progress/completion in the disposable clone.

Pick List generation and movement/scanning **writes** remain later guarded work. The final review candidate does not pretend those are complete.

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

Most unfinished work should be **unscheduled** most of the time. That is normal and intentional.

Do not create tasks merely because a physical action happens. A task belongs in Setup when it helps someone make a decision, can realistically be missed, has a useful prerequisite/resource, needs meaningful progress/completion tracking, or creates historical learning worth carrying forward.

Routine unloading that is simply implied by delivering material is not a separate task unless the unloading itself has meaningful logistics or control value.

## Reusable task versus annual task

A **Reusable Task** describes practical work that normally exists every Setup season.

Reusable information includes:

- task name and active state;
- Site-wide / Stage / Scene scope;
- normal local sequence (`10`, `20`, `30`...);
- normal crew range and expected duration;
- equipment/resources;
- prerequisites;
- completion point;
- readiness/weather notes; and
- reusable global Setup baseline order.

An **Annual Task** is that reusable task's occurrence in one Setup season.

Annual information includes:

- verification state;
- execution state;
- annual planned order;
- short-horizon date/shift/crew-lane assignment when scheduled;
- annual notes / reason for plan change;
- progress entries; and
- actual completion evidence.

A strange year can therefore change the annual plan without corrupting the reusable baseline. For example, 2026 road construction may force unusual access/order that should not automatically carry into 2027.

## Task scope: Site-wide, Stage, or Scene

Reusable tasks can belong to one of three practical scopes.

### Site-wide / Infrastructure

Use this for critical Setup work that is not owned by an LOR Stage or Scene.

Examples include:

- Command Center trailer setup;
- WiFi antenna / gateway / internet setup;
- hotspot deployment;
- street-light removal;
- street-light fuse conversion for show power; and
- site breaker activation.

These tasks are **not LOR-derived**. Do not create a fake Stage, Scene, or Preview to hold them.

Their field Procedures live under the controlled non-LOR Google Drive root:

```text
G:\Shared drives\Display Folders\Site Infrastructure\Procedures\Setup
```

See the Google Drive operator procedure:

`Docs/00_Project_Overview/Google_Drive/operatorSOP/Create_Site_Infrastructure_Procedure_Folder.md`

### Stage-level / General

Use Stage-level when the practical task applies to the Stage generally and should not be forced into one Scene.

### Scene-level

Use Scene-level when a current LOR Scene is the natural reusable organizational home for the work.

The Manager assigns Scene scope explicitly. Setup does not infer it from task names or Display names.

The Reusable Task Catalog groups all three scopes and makes Stage/Scene groups collapsible.

## Reusable local sequence

Within Site-wide, one Stage-level bucket, or one Scene, the reusable sequence uses numbers such as:

```text
10
20
30
40
```

This is the normal local precedence for that area. The gaps are useful because a newly discovered task can temporarily be inserted at `15` or `25`, then the group can be normalized back into manageable increments of 10.

Managers can reorder by drag/drop or the up/down controls.

This sequence does **not** mean all of Setup runs as one serial line.

## Reusable global Setup baseline versus annual planned order

The final planning model has two whole-Setup orders.

### Reusable global baseline

This is the normal starting order we learn over time. Once a useful overall pattern becomes established, the next annual Setup Session can inherit it instead of starting from a blank list.

### Annual planned order

This is the current season's working opinion of what should happen next across the entire remaining Setup backlog.

It can change frequently because of:

- road construction or access restrictions;
- weather;
- volunteer turnout;
- lift / vehicle availability;
- leaves not yet fallen;
- material problems;
- predecessor work taking longer than expected; or
- an unexpected opportunity to get another area done early.

Reordering the annual plan does not automatically change the reusable baseline.

Use **Use Current Order as Future Baseline** only when the annual order represents generally useful learning that should carry forward. Do not promote a one-year oddity such as road construction merely because it affected 2026.

## Planning filters

The planning screen is one annual ordered backlog. The status controls only expand or contract what is visible.

The normal filter set is:

```text
Unscheduled
Scheduled
In Progress
Completed
```

The default emphasizes unfinished work and keeps completed work out of the way.

Filtering does **not** reorder or duplicate tasks. A task keeps its annual planned-order position even while hidden.

A task may also show **Blocked / Not Ready**. That is not a separate copy of the task; it means the task remains in the planning order but cannot practically proceed yet.

## Prerequisites and readiness

A prerequisite means another reusable task must complete first.

Example — Elf Choir:

```text
Locates
    -> Set Scaffold and Elves
        -> Install Notes and Conductor
```

Managers can add/remove prerequisites in the task review screen. Circular dependencies and self-dependencies are blocked by the database command layer.

Readiness is different from prerequisites.

Example: Festive Trees can have its predecessors complete and still remain **NOT_READY** until leaves have fallen from the trees.

Blocked/not-ready work can remain high in the planned order so Management remembers its importance without falsely treating it as executable work.

## Copy a reusable task

Use **Copy** when a new task is substantially similar to an existing reusable task.

The candidate copies:

- reusable definition fields;
- normal crew/time expectations;
- readiness/weather/reusable notes; and
- structured equipment/resource assignments.

It does **not** blindly copy:

- prerequisites; or
- previous annual actual/history.

Choose the destination Site-wide / Stage / Scene scope. The destination group is brought into view so the copied task can be reordered immediately.

The copied task gets a new reusable identity and appears as a new UNVERIFIED annual occurrence in an open Setup Session.

## Rolling-horizon scheduling

Do not schedule the whole Setup season.

A normal workflow is to plan approximately the first few days, perform that work, then return to the ordered backlog and choose the next practical few days.

The near-term work-day assignment contains:

- date;
- shift — **Morning**, **Afternoon**, or **All Day**;
- crew lane — normally **Crew A**, **Crew B**, and occasionally **Crew C**;
- selected task; and
- planned crew count.

An unscheduled task remains valid work and remains visible in the annual backlog.

Removing a near-term schedule assignment returns the task to the unscheduled planning pool rather than deleting the task.

## Parallel crew lanes

Crew lanes are a lightweight dispatch aid, not an individual volunteer roster.

Example:

```text
Saturday

MORNING
    Crew A                  Crew B                  Crew C (if needed)
    Stage/Scene X           Stage/Scene Y           Site-wide work
    Task(s)                 Task(s)                 Task(s)

AFTERNOON
    Crew A                  Crew B
    Stage/Scene Z           Stage/Scene Q
```

Several tasks can run in the same shift because Setup commonly has parallel crews.

Do not turn Crew A/B/C into permanent people assignments. The purpose is simply to show that separate groups are working in parallel.

## Multi-day tasks and progress

Do not split a practical task solely because it lasts more than one work period.

Festive Trees is the model example. One reusable/annual task can remain **IN_PROGRESS** across multiple days while Captains record useful progress such as:

```text
Crew size: 4
Completed quantity: 3
Which units: Trees 1, 3, 4
Note: tall lift unavailable after noon
```

The entire annual task is marked COMPLETE only when the practical job is truly finished.

## Captain / Perform Work screen

The field-execution screen brings together what a Captain needs for a selected task:

- task and scope;
- completion point / readiness / weather notes;
- prerequisite state;
- expected crew/time;
- structured equipment/resources;
- mapped Displays/support Containers and their current Setup/home-location context;
- current published Setup Procedure PDF;
- prior progress entries; and
- progress/completion controls.

For ordinary completion:

- crew size is required;
- completion/progress note is optional;
- authenticated operator/Captain is recorded by the governed command;
- completion time is recorded automatically.

The Captain should not need to leave this screen to hunt for the field PDF.

## Setup Procedures

### Stage / Scene procedures

Stage-level tasks resolve the existing marked Stage Procedure root.

Scene-level tasks resolve the selected current Scene through the shared Field Context / Procedure resolver. Setup does not guess a Scene from the task name.

### Site-wide / Infrastructure procedures

Site-wide tasks resolve the controlled non-LOR root:

```text
G:\Shared drives\Display Folders\Site Infrastructure
```

That folder reuses the existing Procedure structure and marker contract but does not participate in LOR hierarchy resolution.

Current published PDFs belong directly in:

```text
Site Infrastructure\Procedures\Setup
```

Editable Setup sources belong in:

```text
Site Infrastructure\Procedures\Setup\SourceDocs
```

Historical/superseded Setup material belongs in:

```text
Site Infrastructure\Procedures\Setup\Archive
```

Setup-local images belong in:

```text
Site Infrastructure\Procedures\Setup\images
```

## Equipment and resources

Use structured equipment/resource assignments for recurring requirements such as lifts, vehicles, trailers, and tools.

Quantity and Required/Preferred status belong in the structured relationship rather than only in free-text notes.

Do not invent resource counts. For example, Stage 02 panel installation needs one powered stake pounder for the task while both Short Stake Pounder and Tall Stake Pounder exist as distinct available resource types.

## Pick Lists — next guarded layer

The intended Pick List flow remains:

```text
selected near-term Setup work
    -> required Displays/assets
    -> current Display-to-Container assignments
    + supplemental required/support KIT Containers
    -> deduplicate shared Containers/trailers
    -> show why each physical item is needed
```

A Pick List replaces manual material bookkeeping. It does not create fake labor tasks.

Container 34 / Arch Trailer is a special logistics case because it carries material for several areas and later becomes the Who House base. Ordinary unload steps should not become six separate user-facing work tasks merely because material must come off the trailer.

## Movement and scanning — current boundary

Scanning identifies a physical object. Setup owns the operational meaning of a future movement action.

Examples of permanent identifiers include:

```text
DISP:<display_id>
CONT:<container_id>
LOC:<location_code>
```

The Captain screen can already consume annual/current material-location state for information.

The final browser-review candidate still does **not** install movement/scanning write commands. No scan should silently create a destructive movement event merely because identifiers were scanned in sequence.

## Browser-review safety

The final browser review runs at `127.0.0.1:8794` against a disposable PostgreSQL clone captured from current Production.

Migrations and review seeds not yet approved for Production are applied only inside that clone.

Changes made through the browser are discarded during cleanup. The harness verifies:

- Production Setup data fingerprint is unchanged; and
- the live shared application checkout is unchanged.

Production installation remains a separate acceptance gate after this final browser pass.
