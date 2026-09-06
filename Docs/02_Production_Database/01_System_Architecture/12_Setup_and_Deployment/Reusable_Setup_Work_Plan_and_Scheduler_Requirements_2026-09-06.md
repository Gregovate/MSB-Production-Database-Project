# Reusable Setup Work Plan and Scheduler Requirements — 2026-09-06

| Document control | Value |
|---|---|
| Status | CURRENT ENGINEERING REQUIREMENTS — conceptual model established; schema/application not yet approved |
| System | Setup and Deployment — Setup Session |
| Owner | MSB Technical Team |
| Related issue | [#122 — Engineer annual Setup Session planning, pick-list, movement, and park-location subsystem](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122) |
| Governing planning direction | [Setup Session 2026 Planning Direction — 2026-09-04](11_Setup_Session_2026_Planning_Direction_2026-09-04.md) |

## Purpose

Capture the reusable scheduling requirement established during 2026 Setup planning: MSB needs a human-readable way to define practical Setup work once, reuse it from season to season, preserve ordered phases and prerequisites, and schedule work that may span more than one field day.

This document supports the governing Setup Session planning direction. It does **not** create a competing subsystem authority and does not approve PostgreSQL table names, columns, migrations, or final UI technology.

## Core requirement

The Setup scheduler must model the real work rather than assume:

```text
one Stage = one task
one task = one day
one date = one Stage
```

All three assumptions are false for real MSB Setup.

A Stage may require multiple practical phases that must occur in sequence. A practical task may take more than one Setup day. One Setup day may also contain work on several different tasks.

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

## Representative acceptance case — Magic Igloo

Magic Igloo is not one indivisible Setup task.

At minimum, the practical sequence currently identified is:

```text
Magic Igloo
    1. Frame
    2. Skins
    3. Security Cameras
    4. Lighting
```

These phases must be performed in order.

Conceptually:

```text
Frame COMPLETE
    -> Skins may become READY

Skins COMPLETE
    -> Security Cameras may become READY

Security Cameras COMPLETE
    -> Lighting may become READY
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

1. Frame
   Status: COMPLETE

2. Skins
   Status: IN PROGRESS
   Worked: Oct 7, Oct 8
   Remaining: continue skins
   Ready because: Frame complete

3. Security Cameras
   Status: WAITING
   Waiting for: Skins complete

4. Lighting
   Status: WAITING
   Waiting for: Security Cameras complete
```

The operator should not need to read predecessor IDs, dependency graph notation, Gantt bars, or database keys to understand why work is or is not ready.

Structured relationships may exist underneath the application, but the application should translate them into plain-language explanations such as:

- `Waiting for Skins to be completed`;
- `Not before November 1`;
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
- useful start/finish or elapsed evidence;
- whether the task completed;
- significant defer/change reason where useful.

Do not require detailed timecard-style data entry unless later field evidence proves it useful.

## Dependency model requirement

The scheduler needs simple structured prerequisites without becoming a critical-path project-management engine.

The primary hard relationship is:

```text
Task B cannot become ready until Task A is complete
```

A task may have more than one prerequisite where the real field process requires it.

The system should also support other readiness rules separately from task-to-task prerequisites, including:

- not-before dates;
- external readiness conditions such as underground locate complete;
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
What is waiting for another task?
What work fits today's crew and available leaders?
What equipment is available?
What fits the weather?
What has a date restriction?
```

The system presents the facts and constraints. Human leaders choose the work.

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
        -> enter date/weather rules where needed
        -> review resulting human-readable plan
```

For simple sequential plans, the UI should make the normal order obvious without requiring the user to manually construct a graph.

For more complex cases, explicit prerequisite selection may be needed.

## Non-goals

This reusable scheduler must not become:

- Microsoft Project;
- a Gantt-chart maintenance system;
- automatic critical-path calculation;
- resource leveling;
- one-task-per-day scheduling;
- a generalized volunteer skills system;
- a generalized equipment-management system;
- a duplicate Procedure-authoring system;
- a manually maintained second source of truth for current Containers/KITs/storage.

## Initial acceptance requirements

Before schema approval, prove the conceptual model against at least:

1. **Magic Igloo** — ordered Frame -> Skins -> Security Cameras -> Lighting sequence, with at least one task capable of spanning multiple days;
2. **Food Collection** — early work and later traffic-lane work remain separate and can have different date windows/material dependencies;
3. a task that can be completed in part on one date and resumed later without cloning the task;
4. one Setup day containing multiple tasks from more than one Stage;
5. a task blocked by both a prior task and an external readiness condition;
6. a task whose required equipment makes it unsuitable for a day even though its predecessor is complete;
7. a task selected for another day because its normal captain/alternate availability changes;
8. material resolution limited to the selected phase rather than the entire parent Stage.

## Immediate engineering consequence

The first Setup scheduling implementation should not start with a calendar UI.

The engineering order should be:

```text
1. define reusable practical task/work-plan behavior
2. prove ordered prerequisites and multi-day task continuation
3. establish annual task state
4. establish daily work-session behavior
5. connect selected tasks to the material dependency resolver/pick list
6. then build the human-readable planner/scheduler presentation
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
