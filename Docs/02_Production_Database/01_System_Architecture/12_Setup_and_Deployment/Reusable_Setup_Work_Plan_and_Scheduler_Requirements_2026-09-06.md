# Reusable Setup Work Plan and Scheduler Requirements — 2026-09-06

| Document control | Value |
|---|---|
| Status | CURRENT ENGINEERING REQUIREMENTS — conceptual model established; schema/application not yet approved |
| System | Setup and Deployment — Setup Session |
| Owner | MSB Technical Team |
| Related issue | [#122 — Engineer annual Setup Session planning, pick-list, movement, and park-location subsystem](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122) |
| Governing planning direction | [Setup Session 2026 Planning Direction — 2026-09-04](11_Setup_Session_2026_Planning_Direction_2026-09-04.md) |

## Purpose

Capture the reusable scheduling requirement established during 2026 Setup planning: MSB needs a human-readable way to define practical Setup work once, reuse it from season to season, preserve ordered phases and prerequisites, schedule work that may span more than one field day, run many independent crews/tasks in parallel when captains, volunteers, equipment, readiness, and material availability permit, and freely choose/reorder only the subset of ready work that leaders actually intend to perform.

This document supports the governing Setup Session planning direction. It does **not** create a competing subsystem authority and does not approve PostgreSQL table names, columns, migrations, or final UI technology.

## Core requirement

The Setup scheduler must model the real work rather than assume:

```text
one Stage = one task
one task = one day
one date = one Stage
one day = one active crew/task
all ready parallel tasks = scheduled today
```

All five assumptions are false for real MSB Setup.

A Stage may require multiple practical phases that must occur in sequence. A practical task may take more than one Setup day. One Setup day may also contain work on several different tasks, and multiple crews may work on different ready tasks at the same time.

Most importantly, the set of tasks that are technically READY is **not** the daily schedule. Leaders deliberately choose which ready/in-progress work to commit to based on the actual day.

The scheduler therefore needs to separate three concepts:

```text
Reusable Setup Work Plan
    -> reusable task definitions and required order

Annual Setup Task Instance
    -> this season's occurrence/status of that reusable task

Daily Work Session
    -> actual or planned work performed on one date against that annual task
```

A task is **not duplicated merely because work continues on a second day**.

## Common Stage bookends

Setup work has two important recurring bookends that must be visible in the reusable work plan rather than left as tribal knowledge.

At the beginning, the required underground electrical/network **locates / field-clearance task** must be completed before the affected installation work begins.

At the end, the Stage's **Plug In / Power Up / Test** task occurs after the physical installation phases and remains blocked until park grass cutting has stopped.

Conceptually:

```text
Locates / field cleared
    -> Stage installation phases may begin
        -> final installation phase complete
            + grass cutting stopped
                -> Plug In / Power Up / Test may begin
```

The locating process itself can remain owned by the existing locator/GIS/site-infrastructure process. The Setup scheduler needs a schedulable/trackable beginning task or readiness checkpoint whose completion releases the affected Setup work.

A single completed locate task may release several downstream Stage tasks in parallel. The human-readable plan should not require leaders to repeatedly interpret the same prerequisite on every row.

## Representative acceptance case — Magic Igloo

Magic Igloo is not one indivisible Setup task.

At minimum, the practical sequence currently identified is:

```text
Magic Igloo
    1. Locates / Field Cleared
    2. Frame
    3. Skins
    4. Security Cameras
    5. Lighting
    6. Plug In / Power Up / Test
```

These phases must be performed in order where the field work requires the prior phase.

Conceptually:

```text
Locates / Field Cleared COMPLETE
    -> Frame may become READY

Frame COMPLETE
    -> Skins may become READY

Skins COMPLETE
    -> Security Cameras may become READY

Security Cameras COMPLETE
    -> Lighting may become READY

Lighting COMPLETE
    + grass cutting has stopped
        -> Plug In / Power Up / Test may become READY
```

The exact task names and final field data remain subject to leader review, but the scheduler must support this ordered dependency behavior directly.

The scheduler must also allow any one of those tasks to span multiple days. For example:

```text
Magic Igloo — Skins
    Monday      work performed, not complete
    Tuesday     work continues, not complete
    Wednesday   work completed
```

This remains one annual task with several work sessions, not three separate copies of the task.

## Human-readable scheduling requirement

The primary operator presentation should read like the way team leaders already discuss Setup.

A useful presentation is closer to:

```text
MAGIC IGLOO

1. Locates / Field Cleared
   Status: COMPLETE

2. Frame
   Status: COMPLETE

3. Skins
   Status: IN PROGRESS
   Worked: Oct 7, Oct 8
   Remaining: continue skins
   Ready because: Frame complete

4. Security Cameras
   Status: WAITING
   Waiting for: Skins complete

5. Lighting
   Status: WAITING
   Waiting for: Security Cameras complete

6. Plug In / Power Up / Test
   Status: WAITING
   Waiting for: Lighting complete
   External gate: grass cutting must be stopped
```

The operator should not need to read predecessor IDs, dependency graph notation, Gantt bars, or database keys to understand why work is or is not ready.

Structured relationships may exist underneath the application, but the application should translate them into plain-language explanations such as:

- `Waiting for locates / field clearance`;
- `Waiting for Skins to be completed`;
- `Not before November 1`;
- `Waiting for park grass cutting to stop before power-up/testing`;
- `Requires SkyTrak and one boom lift`;
- `Ready now`;
- `In progress — work can continue today`.

## Reusable Setup Work Plan

The reusable layer stores knowledge that should survive from year to year.

For each practical task, the minimum useful knowledge may include:

- human-readable task name;
- Stage/Sub-stage/Scene/support context where useful for orientation;
- normal sequence/order within the broader work plan;
- hard prerequisite task(s);
- normal crew requirement;
- normal captain / alternate captain relationships using existing `ref.person` identity where appropriate;
- normal equipment requirements;
- expected elapsed effort or typical field duration;
- date restrictions or preferred installation windows;
- weather restrictions/preferences;
- external readiness rules that apply to the task;
- required Displays/durable physical assets;
- reviewed supplemental Container/KIT support where Production Database Display relationships cannot derive the dependency;
- links/handoff to applicable existing Procedure instructions where useful.

Do not store current Container assignment, current rack location, or another database-owned current fact as manually maintained reusable task text merely because a historical Procedure document contains it.

## Annual Setup Task Instance

The annual layer answers what is happening **this season**.

It should be able to distinguish at least conceptually:

```text
NOT READY
READY
PLANNED / SELECTED
IN PROGRESS
COMPLETE
DEFERRED
```

These are business states, not approved enum names.

The annual task should retain reusable identity while allowing season-specific facts such as:

- whether the task applies this season;
- current readiness;
- intended near-term ordering;
- date-gate status;
- annual equipment availability effect;
- captain/leader availability effect;
- annual locate/field-clearance completion where applicable;
- external readiness gates such as whether park grass cutting has stopped;
- actual completion state;
- useful planned-versus-actual history.

Replanning must not require cloning or rewriting the reusable task definition.

## Daily Work Sessions

A work session represents work done or planned on a particular Setup day against an annual task.

This solves both real scheduling conditions:

### One task across several days

```text
Task A
    -> Oct 7 work session
    -> Oct 8 work session
    -> Oct 9 work session
```

### Several tasks on one day

```text
Oct 8
    -> continue Task A
    -> complete Task B
    -> start Task C
```

A daily work session may eventually capture only the information worth preserving, such as:

- date;
- task worked;
- actual crew size where useful;
- captain/leader actually used where useful;
- useful start/finish or elapsed evidence;
- whether the task completed;
- significant defer/change reason where useful.

Do not require detailed timecard-style data entry unless later field evidence proves it useful.

## Scheduling flexibility and daily commitment

The scheduler must provide **absolute practical flexibility** to reorder and change future work without treating every change as a scheduling failure.

This requirement comes directly from the Microsoft Project failure mode. When many tasks were allowed to proceed in parallel, Microsoft Project effectively placed every parallel task on the same date. That is not how MSB actually plans Setup.

The correct model is:

```text
READY TASKS
    = candidate work leaders may choose from

TODAY / SELECTED
    = the subset leaders have intentionally committed to today
```

The system must **not** automatically schedule every READY task on the same day merely because dependencies allow them to run in parallel.

Leaders need to be able to:

- move a ready task earlier or later;
- reorder tomorrow/next-day work freely;
- remove a task from a proposed day;
- substitute another ready task when crew, captain, weather, equipment, material, or progress changes;
- continue an unfinished task on a later day without cloning it;
- leave other READY tasks unscheduled without treating that as an error; and
- preserve what was originally planned versus what actually happened where that history is useful.

This flexibility does **not** mean scheduled dates are casual placeholders. MSB tries very hard to complete work on the day it is intentionally scheduled.

Therefore:

```text
scheduled for today
    -> serious operating commitment

not completed today
    -> remain IN PROGRESS / incomplete
    -> deliberately continue or reschedule
    -> preserve useful planned-versus-actual history
```

The scheduler should help leaders make a realistic commitment in the morning rather than auto-filling the calendar with every theoretically possible parallel task.

## Parallel crew and task requirement

Setup commonly has many tasks underway at the same time. The scheduler must therefore treat the day's work as a **set of parallel crews**, not as one serial queue where only one task can be active.

For example:

```text
TODAY

Crew 1 — Magic Igloo — Skins
    Captain: <available captain>
    Volunteers: 6

Crew 2 — Front Entrance — Erect Arch
    Captain: <available captain>
    Volunteers: 6

Crew 3 — Church — Lighting
    Captain: <available captain>
    Volunteers: 4

Crew 4 — Food Collection — Perimeter Work
    Captain: <available captain>
    Volunteers: 5
```

All four tasks can proceed concurrently if their own prerequisites, captain/leader needs, crew needs, equipment, date/weather rules, and required material are satisfied.

The practical amount of parallel work is therefore constrained by the combination of:

- how many tasks are actually READY;
- how many experienced captains/leaders are available to lead those tasks;
- how many volunteers are available to form useful crews;
- which equipment is available and whether two tasks compete for the same equipment;
- whether required Containers/KITs/material are already available at the park or can be pulled;
- date/weather/readiness constraints; and
- the leaders' judgment about what combination of work makes sense that day.

The scheduler should make those constraints visible. It should **not** attempt to automatically optimize or resource-level all crews like enterprise project-management software.

### Captain availability versus reusable captain knowledge

The reusable task definition should answer:

> Who normally knows how to lead this task?

The annual/day planning layer should answer:

> Which of those people are actually available today, and who is leading this crew today?

Those are separate facts.

The first model should not assume that every captain relationship is an exclusive scheduling lock. Some future field cases may allow one experienced leader to supervise more than one nearby/simple crew, while other jobs may require a dedicated captain throughout the work. That distinction must come from actual field requirements rather than being invented as a universal rule.

### Volunteer pool versus individual assignment

The first useful scheduler does not require a generalized volunteer-skills system or detailed individual assignment for every volunteer.

A practical minimum is likely:

```text
Available today: 27 volunteers
Available captains: 5

Planned crews:
    Magic Igloo — Skins            7 people
    Front Entrance — Erect Arch    6 people
    Church — Lighting              5 people
    Food Collection — Perimeter    6 people

Unallocated / flexible             3 people
```

The exact UI and whether specific volunteers are named remains open. The immediate requirement is that leaders can see whether the available volunteer pool and captain pool can support several parallel tasks.

### Parallel readiness is not parent-Stage readiness

A blocked phase in one Stage must not prevent unrelated ready work from proceeding elsewhere.

For example:

```text
Magic Igloo — Security Cameras
    WAITING for Skins

Front Entrance — Erect Arch
    READY

Food Collection — Perimeter Work
    READY
```

The scheduler should present the two READY jobs as usable candidates even though Magic Igloo still has unfinished ordered work.

Likewise, completing one phase should release only the dependent work that actually requires it. It should not force the organization to finish an entire Stage before crews can work elsewhere.

## Common beginning Stage phase — locates / field clearance

Before affected Stage installation work begins, MSB performs underground electrical/network locating so the field is cleared for the work that follows.

This is a real beginning Setup task/readiness step, not merely a note buried in a Procedure.

Conceptually:

```text
Locates / field clearance NOT COMPLETE
    -> affected installation task(s) NOT READY

Locates / field clearance COMPLETE
    -> affected downstream task(s) may become READY
```

The Setup scheduler does not need to own the technical locating/GIS workflow itself. It does need to schedule or track completion of the locate task so downstream work does not become available prematurely.

One locate task may serve as a shared prerequisite for several downstream tasks in the same Stage/setup area.

## Common final Stage phase — plug in / power up / test

The last practical part of every Stage is plugging in/powering up the installed material and testing it.

This is a common Stage-completion requirement and should be represented as real Setup work rather than assumed to happen automatically when physical installation is finished.

A Stage may therefore be physically installed but **not yet ready for final power-up/testing**.

MSB does not power up the installed show material while grass cutting is still occurring in the park. Power-up/testing is held until park grass cutting has stopped.

Conceptually:

```text
Stage physical installation complete
    +
park grass cutting still active
        -> final Plug In / Power Up / Test task remains NOT READY

Stage physical installation complete
    +
park grass cutting stopped / confirmed
        -> final Plug In / Power Up / Test task may become READY
```

The grass-cutting operation itself is **not** a Setup Session subsystem. Setup only needs the external readiness fact that the seasonal grass-cutting gate has been cleared.

This rule applies broadly across Stages and must not be hidden as tribal knowledge in individual Procedure documents.

When the grass-cutting gate is cleared, many Stage test tasks may become READY in parallel. The scheduler must still **not** place all of them on that same day automatically. Leaders choose which Stage plug-in/testing work to schedule based on crews, captains, remaining work, time, and other conditions.

## Dependency model requirement

The scheduler needs simple structured prerequisites without becoming a critical-path project-management engine.

The primary hard relationship is:

```text
Task B cannot become ready until Task A is complete
```

A task may have more than one prerequisite where the real field process requires it.

The system should also support other readiness rules separately from task-to-task prerequisites, including:

- not-before dates;
- beginning locate/field-clearance completion where required;
- other external readiness conditions;
- the common park grass-cutting-stopped gate before final power-up/testing;
- required equipment availability;
- required captain/leader availability where operationally necessary;
- weather restrictions or preferences.

Hard prerequisites and advisory preferences should not be treated as the same thing.

## Duration requirement

Do not design the scheduler around a fixed one-day duration.

Every task should be allowed to remain `IN PROGRESS` across multiple dates unless the field process explicitly establishes otherwise.

Expected duration should be represented in a form useful to leaders, for example:

```text
about 4 hours
about 1 day
about 2–3 Setup days
```

The exact normalized database representation remains open.

The purpose of the estimate is to help leaders decide what fits the available day, crew, and equipment — not to calculate a rigid critical path.

## Relationship to the morning planning process

The scheduler should help the leadership meeting answer:

```text
What is still incomplete?
What is actually ready now?
What is already in progress and should be continued?
What is waiting for locates / field clearance?
What is waiting for another task?
Which READY tasks do we actually intend to commit to today?
How many parallel crews can we realistically run today?
Which captains/leaders are available?
How many volunteers are available?
What work fits today's crew and available leaders?
What equipment is available?
What fits the weather?
What has a date restriction?
Has park grass cutting stopped so final Stage power-up/testing can begin?
```

The system presents the facts and constraints. Human leaders choose the work, the order, and how many parallel crews to run.

## Relationship to material dependency resolution

The scheduler and physical dependency resolver are connected but separate concerns.

Conceptually:

```text
selected annual Setup task(s)
    -> reusable task definition identifies required Displays/assets
        -> current Production Database resolves current Containers/storage
            -> supplemental reviewed KIT/Container support where needed
                -> deduplicated physical pick list
```

A multi-day task must not regenerate duplicate physical moves merely because a second work session is scheduled. The resolver must consider what material has already been moved to the park.

Likewise, selecting one phase of a Stage must not automatically pull material for later phases.

When several parallel tasks are selected for the same day, the resolver should combine their physical requirements into one deduplicated pick/load view while retaining the reason each Container/KIT is required.

## Relationship to Procedures

Existing Setup Procedure documents remain primarily **how-to field instructions**.

They are useful evidence for identifying:

- practical task boundaries;
- task sequence;
- crew needs;
- equipment needs;
- prerequisites;
- weather considerations;
- experienced leaders;
- special methods and warnings.

They must not remain the permanent authoritative source for current Container/KIT lists when those facts are or should be owned by the Production Database.

The reusable scheduler should eventually be able to link a task to the applicable Procedure experience without copying current database-owned material facts back into the task definition.

The common beginning locate task, grass-cutting gate, and final Stage plug-in/testing rule belong in reusable Setup planning knowledge, not as duplicated manually maintained text that leaders must rediscover independently in every Stage Procedure.

## Builder / maintenance tool requirement

MSB currently has no tool for creating reusable Setup tasks.

The eventual builder must be understandable to a team leader or knowledgeable maintainer without requiring SQL or Directus relationship-table editing.

Conceptually, a maintainer should be able to:

```text
Choose Stage / Setup area
    -> Add practical task
        -> name task
        -> move task up/down in normal sequence
        -> choose prerequisite task(s)
        -> enter crew/resource information
        -> associate required Displays/assets
        -> associate captain(s)
        -> enter date/weather/external readiness rules where needed
        -> review resulting human-readable plan
```

For simple sequential plans, the UI should make the normal order obvious without requiring the user to manually construct a graph.

For more complex cases, explicit prerequisite selection may be needed.

The builder must not imply that tasks listed beneath the same Stage execute serially by default. A work plan may contain branches and independent tasks that become ready in parallel.

## Non-goals

This reusable scheduler must not become:

- Microsoft Project;
- a Gantt-chart maintenance system;
- automatic critical-path calculation;
- automatic resource leveling/optimization;
- automatic scheduling of every READY task;
- one-task-per-day scheduling;
- one-active-crew scheduling;
- a generalized volunteer skills system;
- a generalized equipment-management system;
- a duplicate Procedure-authoring system;
- a manually maintained second source of truth for current Containers/KITs/storage.

## Initial acceptance requirements

Before schema approval, prove the conceptual model against at least:

1. **Magic Igloo** — ordered Locates / Field Cleared -> Frame -> Skins -> Security Cameras -> Lighting -> Plug In / Power Up / Test sequence, with at least one task capable of spanning multiple days;
2. **Food Collection** — early work and later traffic-lane work remain separate and can have different date windows/material dependencies;
3. a beginning locate task clearing several downstream tasks without duplicating the locate prerequisite as separate work;
4. a task that can be completed in part on one date and resumed later without cloning the task;
5. one Setup day containing multiple tasks from more than one Stage;
6. at least three or four crews working on independent tasks in parallel on the same day when captains/volunteers/resources allow it;
7. several tasks becoming READY in parallel without all of them being automatically scheduled on the same date;
8. leaders freely reordering/substituting future READY work while preserving useful planned-versus-actual history;
9. a task intentionally scheduled for today being treated as a real same-day commitment, with incomplete work carried forward as IN PROGRESS rather than silently rescheduled;
10. a task blocked by both a prior task and an external readiness condition;
11. a task whose required equipment makes it unsuitable for a day even though its predecessor is complete;
12. a task selected for another day because its normal captain/alternate availability changes;
13. a day where available volunteer count limits how many otherwise-ready tasks can actually be staffed;
14. a day where available captain count limits parallel work even though enough volunteers are present;
15. material resolution limited to the selected phase rather than the entire parent Stage;
16. several parallel selected tasks producing one combined deduplicated physical pick list;
17. a physically installed Stage whose final Plug In / Power Up / Test task remains NOT READY while grass cutting continues;
18. grass cutting being confirmed stopped, causing applicable final Stage test tasks to become READY without automatically scheduling all of them for that date.

## Immediate engineering consequence

The first Setup scheduling implementation should not start with a calendar UI.

The engineering order should be:

```text
1. define reusable practical task/work-plan behavior
2. prove common beginning/end bookends, ordered prerequisites, branching/parallel readiness, and multi-day task continuation
3. prove READY-versus-SCHEDULED behavior and free human reordering
4. establish annual task state and external readiness gates
5. establish daily work-session and parallel-crew behavior
6. connect selected tasks to the material dependency resolver/pick list
7. then build the human-readable planner/scheduler presentation
```

A calendar may eventually be one view of this information, but it is not the underlying model.

## Related Documents

- [Setup Session 2026 Planning Direction — 2026-09-04](11_Setup_Session_2026_Planning_Direction_2026-09-04.md)
- [Setup Session Engineering Reconnaissance — 2026-09-03](Setup_Session_Engineering_Reconnaissance_2026-09-03.md)
- [Setup and Deployment](README.md)
- [Containers and Storage](../04_Containers_and_Storage/README.md)
- [People and Identity](../03_People_and_Identity/README.md)
- [Work Orders](../06_Work_Orders/README.md)
- [#122 — Setup Session engineering issue](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122)
