# Setup Session Schema Design Proposal — 2026-09-06

| Document control | Value |
|---|---|
| Status | PROPOSED ENGINEERING DESIGN — no migration or production change approved |
| System | Setup and Deployment — Setup Session |
| Owner | MSB Technical Team |
| Related issue | [#122 — Engineer annual Setup Session planning, pick-list, movement, and park-location subsystem](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122) |
| Related requirements | [Reusable Setup Work Plan and Scheduler Requirements — 2026-09-06](Reusable_Setup_Work_Plan_and_Scheduler_Requirements_2026-09-06.md) |

## Purpose

Define the first relational shape needed to replace the working reconstruction spreadsheet with a maintainable, human-readable Setup task catalog and a manual annual scheduler that can later generate current pick lists from Production Database relationships.

This is a schema proposal only. It does not authorize PostgreSQL DDL, migration, Directus configuration, or production changes.

## Why the reconstruction workbook is not the production model

The current reconstruction workbook is useful evidence, but it combines current candidate tasks and historical evidence in one flat table. The inspected workbook currently contains 177 Task List rows across 22 columns. Only 31 rows are current working/candidate task definitions; 146 rows are historical evidence or historical-plan rows.

The flat workbook also stores predecessor meaning as free text such as `MI-01 complete`. That creates several problems:

- task identity, display order, predecessor relationships, historical evidence, and annual planning state are mixed together;
- sorting by Stage changes the visual sequence and makes predecessor meaning difficult to follow;
- task IDs such as `MI-01` are being used partly as ordering aids even though identity and ordering are separate concerns;
- one task can span several days but one spreadsheet row does not model repeated planned/actual work sessions cleanly;
- the workbook is too dense to serve as the team-facing task review experience.

The database model must therefore separate reusable task knowledge from relationships and annual scheduling state.

## Existing database boundaries to preserve

Current project architecture separates stable/reference entities in `ref` from operational workflow in `ops`, with UI-facing views using `ops.v_*`. Existing production systems already use `ref.display`, `ref.container`, `ref.stage`, `ref.person`, `ref.season`, and `ops.*` annual workflow tables.

Setup must preserve those authorities:

- `ref.display` remains Display identity and current Display-to-Container assignment;
- `ref.container` remains Container/KIT/trailer identity;
- current Container/storage/location relationships remain owned by the Production Database and are not copied into reusable Setup task text;
- `ref.stage` remains the normal Stage/Sub-stage orientation vocabulary;
- `ref.person` remains person identity;
- annual Setup state belongs in `ops`.

The uploaded LOR V7 scene database remains useful for current LOR Stage/Scene/Display completeness evidence, but it does not replace Production PostgreSQL Container/location authority.

## Core relational model

The first design should separate four layers:

```text
Reusable Setup Task Catalog
    -> stable task identity, human order, crew/resource knowledge
    -> structured predecessor relationships
    -> required Displays/assets and supplemental KIT/Container dependencies

Annual Setup Session
    -> this season's task state

Work Days / Scheduled Task Sessions
    -> the dates leaders intentionally plan to work a task
    -> one task may appear on several dates
    -> one date may contain many parallel tasks

Derived Pick List
    -> scheduled task(s)
    -> required Displays/assets
    -> current ref.display.container_id
    + supplemental required KIT/support Containers
    -> deduplicated current Containers/locations
```

## Proposed core tables

The names below are proposed names, not approved implementation objects.

### `ops.setup_task`

One row per reusable practical Setup task.

Minimum fields:

- `setup_task_id` — stable surrogate PK; never encodes task order;
- `stage_id` — nullable FK to `ref.stage`; null for genuine cross-stage/support work;
- `task_name` — human-readable scheduled work name;
- `display_order` — human presentation order within the Stage/setup area;
- `active_flag`;
- `definition_status` — candidate/reviewed/current/retired or equivalent controlled state;
- `min_crew`;
- `preferred_crew`;
- `elapsed_minutes_min`;
- `elapsed_minutes_max`;
- `completion_point` — plain-language definition of done;
- `weather_notes` and/or later structured weather rule;
- reusable date/window guidance where justified;
- task-specific power-up/testing rule;
- notes appropriate to reusable planning knowledge.

`display_order` controls how humans see the Stage task list. It is not a dependency and can be changed without changing task identity.

### `ops.setup_task_dependency`

Self-referential many-to-many predecessor relationship.

Minimum fields:

- `setup_task_dependency_id`;
- `setup_task_id` — successor task;
- `prerequisite_setup_task_id` — task that must be complete first;
- dependency type/notes only if real field evidence requires more than a hard predecessor.

No predecessor row means the task has no task predecessor.

This table is the key fix for the spreadsheet sorting problem. A user can sort the catalog by Stage, task name, captain, or anything else without losing the actual predecessor relationship.

It also supports cross-Stage dependencies such as Who House waiting for arch work/trailer availability.

### `ops.setup_task_display`

Reusable task-to-Display/durable-asset relationship.

Minimum fields:

- `setup_task_display_id`;
- `setup_task_id`;
- `display_id` FK to `ref.display`;
- optional reason/role where it helps explain why the Display is required.

This table identifies the physical Displays/assets the task requires. It does **not** store their Container or rack location.

At pick-list time:

```text
setup_task_display.display_id
    -> current ref.display.container_id
        -> current Container/storage/location authority
```

Therefore a Display can move to another Container without requiring the reusable Setup task to be edited.

### `ops.setup_task_container_support`

Supplemental task-to-Container relationship only where the dependency cannot be derived from required Displays.

Minimum fields:

- `setup_task_container_support_id`;
- `setup_task_id`;
- `container_id` FK to `ref.container`;
- `support_reason`;
- active/reviewed state if needed.

Examples:

- KIT Containers whose contents are intentionally not represented as Displays;
- Arch Trailer required later as Who House base/platform;
- other reviewed support Containers where current Display assignment cannot derive the dependency.

Do not populate this table with every normal current Display Container. Normal Containers are derived live through `ref.display.container_id`.

### `ops.setup_task_captain`

Reusable task-to-person leadership knowledge.

Minimum fields:

- `setup_task_captain_id`;
- `setup_task_id`;
- `person_id` FK to `ref.person`;
- priority/role such as normal captain or alternate where needed.

This answers `Who normally knows how to lead this task?` It is separate from the person actually leading a crew on a particular date.

### `ops.setup_task_evidence`

Historical/procedural/leader evidence supporting a reusable task definition without cluttering the team task list.

Minimum fields:

- `setup_task_evidence_id`;
- `setup_task_id` nullable while evidence is still being classified;
- `source_type` — historical report, Setup Procedure, leader review, field notes, etc.;
- `source_date` / `source_year` where known;
- `source_reference`;
- `evidence_summary`;
- optional observed crew/person-hours/captain fields where the source actually supports them;
- reviewed state and reviewer attribution using the project's normal actor/audit pattern.

The 146 historical rows currently mixed into the spreadsheet belong here or in a controlled import/staging equivalent, not in the everyday team task catalog.

## Annual scheduling tables

### `ops.setup_session`

One annual Setup Session context.

Minimum fields:

- `setup_session_id`;
- season reference using the current established season pattern after live-schema verification;
- session status;
- official start date;
- final readiness milestone;
- annual environmental state needed by Setup, such as grass-cutting-stopped date/state where applicable;
- notes/audit fields.

The exact FK/key relationship to `ref.season` must be confirmed from live production before DDL. Existing systems use annual `season_year` and `ref.season` active-season behavior.

### `ops.setup_session_task`

One annual occurrence/state row for each reusable task that applies this season.

Minimum fields:

- `setup_session_task_id`;
- `setup_session_id`;
- `setup_task_id`;
- annual task status;
- annual not-before date or override where required;
- completion timestamp/date;
- completion/person attribution as justified;
- annual notes/override fields only where the reusable definition does not apply unchanged.

The annual task row should carry overall state such as NOT STARTED / IN PROGRESS / COMPLETE / DEFERRED. READY should preferably be derived from task completion, predecessors, dates, and applicable external rules rather than manually maintained when practical.

### `ops.setup_work_day`

One row per actual/planned Setup work date.

Minimum fields:

- `setup_work_day_id`;
- `setup_session_id`;
- `work_date`;
- expected/actual volunteer count where useful;
- general day notes such as weather/resource context;
- day status if needed.

### `ops.setup_work_day_task`

Manual scheduler assignment and work-session row.

Minimum fields:

- `setup_work_day_task_id`;
- `setup_work_day_id`;
- `setup_session_task_id`;
- `planned_order` within that day;
- `captain_person_id` — person actually assigned that day;
- `planned_crew_size`;
- `actual_crew_size` where worth preserving;
- optional start/finish or elapsed evidence;
- `completed_this_day` or equivalent execution evidence;
- notes/change reason where useful.

This table is what gives MSB the needed scheduling flexibility:

- one annual task can have work-day rows on October 8, October 9, and October 10 without cloning the task;
- one work day can contain many tasks from several Stages in parallel;
- moving a task from one proposed date to another changes scheduling rows, not the reusable task definition or its predecessor relationships;
- future READY tasks can remain unscheduled indefinitely until leaders deliberately choose them.

## Setup-specific resource planning — proposed second slice

Resource structure should remain deliberately small and Setup-specific rather than becoming a generalized organization-wide skills/equipment system.

Likely objects after the core task/schedule model is accepted:

- `ops.setup_resource` — scarce planning resources such as SkyTrak, Boom Lift, Tool Cat, truck/trailer capability;
- `ops.setup_task_resource_requirement` — task + resource + required quantity;
- `ops.setup_session_resource_availability` — annual/effective-date availability such as 1 boom lift on Oct 5, 2 on Oct 9, 3 on Oct 16.

Crew size remains directly on the task. Captains use `ref.person` through the task-captain relationship.

Do not build detailed volunteer skills or a general fleet system merely to support the first Setup scheduler.

## Human-readable views / operator surfaces

The database tables are not the team experience.

### `ops.v_setup_task_catalog` — first team-review deliverable

One clean row per reusable current/candidate task, ordered by Stage and `display_order`.

Show only information leaders need to review the real task list:

- Stage / setup area;
- task order;
- task name;
- predecessor task names, rendered in plain language;
- crew range;
- normal captain(s);
- major equipment summary;
- expected elapsed time;
- date/weather/power-up notes;
- completion point;
- definition/review status.

Historical evidence rows must not appear in this default view. Evidence belongs behind a task detail/drill-down.

This view gives the team the missing place to review `the task list` before the full scheduler is implemented.

### `ops.v_setup_remaining_tasks`

For the active annual session, show one row per incomplete task with:

- Stage/task order/task name;
- annual status;
- predecessor completion/readiness explanation;
- planned date(s), if any;
- captain/resource summary;
- blocked/date-gated reason where applicable.

### `ops.v_setup_schedule`

Human-readable manual schedule ordered by date then planned order.

A task that spans several days appears on each intentionally scheduled work day while remaining one annual task.

### `ops.v_setup_pick_list`

Derived from the selected/scheduled work, not manually maintained.

Conceptual query path:

```text
work date
    -> scheduled setup_session_task rows
    -> reusable setup_task
    -> setup_task_display
        -> current ref.display.container_id
    + setup_task_container_support
    -> deduplicate container_id
    -> current Container description/location/storage
    -> explain every task/reason requiring that Container
```

Exact location-table joins remain gated on live production inventory because current documentation contains `ref.location` / `ref.storage_location` naming evidence that still requires current-schema confirmation.

## Task order versus dependency versus schedule order

These must remain three separate concepts:

1. `setup_task.display_order` — how the reusable Stage task list is normally shown to humans;
2. `setup_task_dependency` — actual prerequisite relationships that control readiness;
3. `setup_work_day_task.planned_order` — the order/crew plan for one particular date.

This separation is the central fix for the spreadsheet/MS Project failure mode.

Sorting a task catalog never changes dependencies. Reordering a future work day never changes the reusable Stage task order. Completing one task can release several successors without automatically scheduling them.

## Recommended implementation slices

### Slice 1 — Team-review Task Catalog

Build only enough schema and Directus/read-only presentation to let the team review the real task list:

- `ops.setup_task`;
- `ops.setup_task_dependency`;
- `ops.setup_task_captain`;
- `ops.setup_task_display`;
- `ops.setup_task_container_support`;
- `ops.setup_task_evidence`;
- `ops.v_setup_task_catalog`.

Seed the current 31 working/candidate definitions from the reconstruction workbook as review data. Keep the 146 historical evidence rows out of the default task view.

This gives the email/team review a real destination before the annual scheduler exists.

### Slice 2 — Manual annual scheduler

Add:

- `ops.setup_session`;
- `ops.setup_session_task`;
- `ops.setup_work_day`;
- `ops.setup_work_day_task`;
- remaining-work and schedule views.

This gives leaders the manual scheduler they actually need: unfinished work plus deliberate planned work dates, with absolute ability to move/reorder tasks.

### Slice 3 — Derived pick list

Add the read-only dependency resolver/view using current Production Display-to-Container/storage data plus reviewed supplemental KIT/support Containers.

Do not create a maintained task-to-current-Container copy.

### Slice 4 — Resource readiness and execution/movement

Add structured Setup resource availability, then scan/movement execution once the planning and pick-list model is accepted.

## Schema questions to resolve before DDL

1. Confirm current production actor/audit columns/triggers that every new `ops` table must use.
2. Confirm the exact annual relationship to `ref.season` and whether `season_year` remains the operational FK/key pattern.
3. Confirm the current authoritative location/storage objects and fields before defining the pick-list view.
4. Confirm whether current `ref.stage` alone is sufficient as the primary task grouping for 2026 or whether a current Scene FK is needed immediately.
5. Confirm whether any real reusable task spans more than one Stage. If yes, replace nullable `stage_id` with a task-to-scope relationship instead of adding ad hoc extra stage columns.
6. Confirm the smallest useful structured power-up rule set from leader review.
7. Confirm whether date/window rules need structured recurrence in the reusable task or whether concrete annual `not_before_date` values in `setup_session_task` are sufficient for 2026.
8. Confirm the current procedure-linking mechanism needed from a task without duplicating Google paths/document IDs.
9. Confirm whether task definition changes need explicit version rows or whether existing audit history plus retirement/new-task rules are sufficient for the first production season.

## Acceptance cases for schema review

The relational model must represent without spreadsheet ordering tricks:

- Magic Igloo practical phases with explicit predecessor relationships and multi-day continuation;
- independent tasks with no predecessors;
- several successors becoming READY from one completed task;
- many parallel tasks across Stages without automatic same-day scheduling;
- Food Collection early and late phases with separate annual date planning;
- Who House dependent on earlier arch/trailer availability;
- current Display-to-Container resolution including Old Elf Choir/Old Man Winter cross-container storage;
- Container 34 shared across several selected tasks but appearing once on the pick list;
- KIT Containers included through supplemental reviewed support when Displays cannot derive them;
- one task scheduled on multiple dates;
- several tasks scheduled on one date;
- task-specific power-up/testing eligibility;
- team sorting/filtering the task catalog without losing predecessor relationships.

## Immediate next engineering step

Do **not** add more columns to the reconstruction workbook to solve ordering/scheduling.

The next engineering step is to validate this relational shape against live Production PostgreSQL metadata, then produce the first DDL proposal for **Slice 1 — Team-review Task Catalog** only.

That first slice creates the place the team currently lacks to review and organize the real Setup task list. The annual scheduler and pick-list views build on the same task identities rather than forcing the team to keep working in a spreadsheet.