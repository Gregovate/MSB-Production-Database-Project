# Setup Session Schema Design Proposal — 2026-09-06

| Document control | Value |
|---|---|
| Status | PROPOSED ENGINEERING DESIGN — live schema gate completed 2026-09-06; no migration or production change approved |
| System | Setup and Deployment — Setup Session |
| Owner | MSB Technical Team |
| Related issue | [#122 — Engineer annual Setup Session planning, pick-list, movement, and park-location subsystem](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122) |
| Related requirements | [Reusable Setup Work Plan and Scheduler Requirements — 2026-09-06](Reusable_Setup_Work_Plan_and_Scheduler_Requirements_2026-09-06.md) |

## Purpose

Define the relational shape for the Setup Session after live Production PostgreSQL verification.

The subsystem must combine:

- reusable Setup task knowledge;
- annual Setup Session state;
- daily scheduling and actual work history;
- current Production Database Display/Container/storage truth;
- Setup-specific Container and Display movement/unload history;
- a simple manager and field-operator UI.

This document is a design proposal only. It does **not** authorize PostgreSQL DDL, migration, Directus configuration, application deployment, or production data changes.

## Live production schema gate — 2026-09-06

Read-only DBeaver reconnaissance was run against live database `msb` on PostgreSQL 16.9.

Confirmed live facts:

- there are no existing `ref.setup%` or `ops.setup%` tables;
- no generic `resource`, `equipment`, `vehicle`, `asset`, or `tool` table exists in `ref`/`ops` that Setup must reuse;
- `ref.season` already contains 2025 and 2026;
- 2025 is inactive and 2026 is active;
- `ops.test_session` has 226 rows for 226 distinct Containers for 2026;
- `ops.test_session` enforces `UNIQUE (season_year, container_id)` and `season_year -> ref.season(season_year)`;
- Production currently contains 1,056 Displays, of which 1,025 have a Container assignment;
- all 1,025 assigned Displays resolve through `ref.display.container_id -> ref.container -> ref.storage_location`;
- 31 Displays currently have no Container assignment;
- `ref.task_type` is a broad reusable Work Order/task taxonomy and is **not** the practical reusable Setup task catalog;
- `ops.work_order` uses the existing Stage/non-Stage context precedent of `stage_id` or `work_area_id`;
- `ref.work_area` exists for non-Stage operational areas such as Office, Command Center, Wood Shop, Food Bank Facility, and Volunteer Trailer;
- current reference and operational tables use project actor stamping through `ref.set_actor_on_insert()` and `ref.set_actor_on_update()`.

These facts replace the earlier provisional assumption that reusable Setup tasks should live in `ops`.

## Authority boundaries

### Current/master Production truth

The existing masters remain authoritative:

```text
ref.display
    -> durable Display identity
    -> current Display-to-Container assignment

ref.container
    -> durable Container / KIT / trailer identity
    -> current home/storage location

ref.storage_location
    -> workshop/storage location identity

ref.stage
    -> durable park Stage/Sub-stage context

ref.work_area
    -> non-Stage operational area

ref.person
    -> person identity

ref.season
    -> annual organization season identity
```

Setup must not create year-specific Display-to-Container copies and must not introduce generic Container assignment history.

### Reusable Setup knowledge

Reusable task definitions survive across seasons and therefore belong in `ref`.

### Annual operational truth

A Setup Session, annual task state, work-day planning/actuals, and movement events belong in `ops`.

### Procedure boundary

The database owns what work is planned, which Displays/Containers/KITs are required, where current assets are, and what happened during Setup.

Procedures own how the work is performed.

Do not duplicate Container IDs, rack locations, or other current Production Database facts inside Procedure text merely to make Setup work.

## Core relational model

```text
REFERENCE / REUSABLE

ref.setup_task
    -> stable practical task identity

ref.setup_task_context
    -> Stage / Work Area context

ref.setup_task_dependency
    -> reusable predecessors

ref.setup_task_display
    -> required Displays

ref.setup_task_container_support
    -> supplemental KIT/support Containers

ref.setup_task_captain
    -> normal captain/alternate knowledge

ref.setup_resource
ref.setup_task_resource_requirement
    -> small Setup-specific scarce-resource model


ANNUAL OPERATION

ops.setup_session
    -> one Setup Session per season

ops.setup_session_task
    -> one annual task occurrence/state

ops.setup_work_day
ops.setup_work_day_task
    -> planned and actual who/what/when

ops.setup_movement_event
ops.setup_movement_event_display
    -> Container/Display field movement and bulk unload evidence


DERIVED OPERATIONAL VIEWS

ops.v_setup_task_catalog
ops.v_setup_remaining_tasks
ops.v_setup_schedule
ops.v_setup_pick_list
ops.v_setup_container_current_state
ops.v_setup_display_current_state
ops.v_setup_container_onboard_display
```

The exact names remain proposed until DDL review.

## Reusable reference tables

### `ref.setup_task`

One row per practical reusable Setup task.

Minimum fields:

- `setup_task_id` — stable surrogate PK; never encodes order;
- `task_name` — human-readable work name;
- `display_order` — human presentation order, independent of dependency order;
- `active_flag`;
- `definition_status` — candidate/reviewed/current/retired or equivalent;
- `min_crew`;
- `preferred_crew`;
- `elapsed_minutes_min`;
- `elapsed_minutes_max`;
- `completion_point` — plain-language definition of done;
- `weather_notes`;
- reusable date/window guidance where justified;
- task-specific power-up/testing guidance where justified;
- reusable notes;
- project-standard actor/audit fields.

Task rename rule:

```text
same practical work + clearer wording
    -> same setup_task_id

material split / merge / change in practical work unit
    -> new task identity
```

### `ref.setup_task_context`

A reusable task must have field context even when it requires no inventory.

A separate relationship table is preferred over a single `stage_id` column because it can support a real cross-area task without later adding ad hoc extra columns.

Minimum fields:

- `setup_task_context_id`;
- `setup_task_id`;
- `stage_id` nullable FK to `ref.stage`;
- `work_area_id` nullable FK to `ref.work_area`;
- `context_role` such as PRIMARY / RELATED if needed;
- notes only where required.

Each context row should enforce exactly one of `stage_id` or `work_area_id`.

Most tasks are expected to have one PRIMARY Stage context. Multiple contexts are allowed only where the real work actually spans areas.

Inventory-independent does **not** mean context-independent.

Examples already established:

- Arrange Volunteer Food -> Stage 4 context, no required Display material;
- Arrange Rental Equipment -> Stage 4/general-area context;
- Position Volunteer Trailer -> Stage 4/general-area context;
- Deliver Command Center -> Stage 40 context.

### `ref.setup_task_dependency`

Structured predecessor relationship.

Minimum fields:

- `setup_task_dependency_id`;
- `setup_task_id` — successor;
- `prerequisite_setup_task_id` — required predecessor;
- optional notes/type only if field evidence requires more than a hard predecessor.

Required constraints:

- unique task/prerequisite pair;
- no self-dependency.

Task display order, dependency order, and one day's planned order remain separate concepts.

### `ref.setup_task_display`

Reusable task-to-Display relationship.

Minimum fields:

- `setup_task_display_id`;
- `setup_task_id`;
- `display_id` FK to `ref.display`;
- optional role/reason.

Do **not** copy Container or storage location here.

At runtime:

```text
setup task
    -> required Display
        -> current ref.display.container_id
            -> current ref.container
                -> current ref.storage_location
```

### `ref.setup_task_container_support`

Supplemental Container relationship used only when the requirement cannot be derived from required Displays.

Examples:

- KIT Containers whose detailed contents are intentionally not represented as Displays;
- Arch Trailer later required as the Who House base/platform;
- another reviewed support Container with a real task dependency.

Normal current Display Containers are **not** duplicated here.

### `ref.setup_task_captain`

Reusable leadership knowledge.

Minimum fields:

- `setup_task_captain_id`;
- `setup_task_id`;
- `person_id` FK to `ref.person`;
- captain/alternate role or priority where useful.

This is distinct from the captain actually assigned to a particular work day.

### `ref.setup_resource`

A deliberately small Setup-specific resource master is justified because live reconnaissance found no existing generic resource/equipment master.

Initial examples may include:

- SkyTrak;
- Boom Lift;
- Tool Cat;
- Truck;
- Trailer capability.

This is not a generalized fleet, skills, maintenance, or organization-wide asset system.

### `ref.setup_task_resource_requirement`

Minimum fields:

- `setup_task_resource_requirement_id`;
- `setup_task_id`;
- `setup_resource_id`;
- required quantity;
- REQUIRED/PREFERRED distinction only if it proves useful;
- notes.

## Annual operational tables

### `ops.setup_session`

One annual Setup Session context.

Proposed minimum fields:

- `setup_session_id`;
- `season_year` FK to `ref.season(season_year)`;
- `session_status`;
- official Setup start date where useful;
- final readiness/completion date where useful;
- annual environmental dates/states such as grass-cutting-stopped where justified;
- notes;
- project-standard actor/audit fields.

Required relationship:

```text
UNIQUE (season_year)
```

Admin creates the annual Setup Session, analogous to establishing the annual Test Session context.

The initial rollout may use statuses such as:

```text
DRAFT
VERIFYING
VERIFIED
ACTIVE
CLOSED
```

Exact status values remain DDL-review material.

### `ops.setup_session_task`

One annual occurrence/state row for each reusable task included in the session.

Minimum fields:

- `setup_session_task_id`;
- `setup_session_id`;
- `setup_task_id`;
- stored annual task state;
- annual not-before date/override where necessary;
- completion timestamp;
- completion person;
- annual notes/override data;
- actor/audit fields.

Required relationship:

```text
UNIQUE (setup_session_id, setup_task_id)
```

READY should normally be derived from predecessors, dates, and applicable external conditions rather than maintained as a manually editable truth.

A useful stored state set is likely smaller:

```text
NOT_STARTED
IN_PROGRESS
COMPLETE
DEFERRED
```

Then:

- READY/BLOCKED are derived;
- PLANNED/SELECTED is derived from work-day scheduling;
- COMPLETE remains explicit annual fact.

### `ops.setup_work_day`

One planned/actual Setup work date within a session.

Minimum fields:

- `setup_work_day_id`;
- `setup_session_id`;
- `work_date`;
- expected volunteer count where useful;
- actual volunteer count where useful;
- day status;
- general weather/resource/day notes;
- actor/audit fields.

### `ops.setup_work_day_task`

One task scheduled/worked on one work day.

Minimum fields:

- `setup_work_day_task_id`;
- `setup_work_day_id`;
- `setup_session_task_id`;
- `planned_order`;
- actual captain/person assigned that day;
- planned crew size;
- actual crew size;
- start/finish or elapsed evidence where worth preserving;
- reschedule/change reason where useful;
- notes;
- actor/audit fields.

This supports:

- one task across several days without cloning it;
- many parallel tasks on one date;
- moving a task to another date without altering reusable task identity or dependencies.

## Movement and unload subsystem

Movement is a core Setup Session responsibility. It is **not** generic Container history and must not overwrite `ref.container.location_code` or `ref.display.container_id`.

### Required field behavior

A Container scan at a park location establishes that:

- the Container is at that Setup location;
- every Display still physically traveling with that Container is also at that location.

A Display stops following later Container movement when it is unloaded or otherwise moved independently.

Example:

```text
mixed Container scanned at Candyland
    -> Container = Candyland
    -> every still-onboard Display = Candyland

Candyland Display set unloaded
    -> those Displays detach from Container movement
    -> those Displays remain at Candyland

same Container moved/scanned at Whoville
    -> Container = Whoville
    -> only remaining onboard Displays = Whoville
    -> previously unloaded Candyland Displays stay at Candyland
```

This behavior is essential for the Arch Trailer and other mixed Containers.

### Baseline carrier rule

At the beginning of a Setup Session, absent contrary Setup movement evidence:

```text
Display carrier = current ref.display.container_id
Container home location = current ref.container.location_code
```

No thousands-row seasonal snapshot is required merely to establish that baseline.

### `ops.setup_movement_event`

One row per operator/business movement action.

Proposed minimum fields:

- `setup_movement_event_id`;
- `setup_session_id`;
- `event_type`;
- `container_id` nullable — scanned/carrier Container where applicable;
- `setup_session_task_id` nullable — task that explains the event when applicable;
- destination `stage_id` nullable;
- destination `work_area_id` nullable;
- destination `storage_location_code` nullable;
- `occurred_at`;
- `source_type`;
- notes;
- actor/audit fields.

Likely event semantics:

- `CONTAINER_LOCATION` — scan/manual confirmation that a Container is at a destination;
- `UNLOAD` — selected Displays removed from a Container at destination;
- `LOAD` — selected Displays attached to a carrier Container;
- `DISPLAY_LOCATION` — individual/bulk Display movement independent of a Container;
- `VERIFIED_PRESENT` — correction/verification that a Display is at a location when intermediate scans were missed.

`source_type` should distinguish evidence such as:

```text
SCAN
MANUAL
TASK_COMPLETION
ADMIN_CORRECTION
```

The event names remain proposed. The important requirement is that recorded evidence remains honest: a later verification must not fabricate intermediate movements that were never observed.

### `ops.setup_movement_event_display`

Child rows identify the Displays affected by a display-bearing event.

Minimum fields:

- `setup_movement_event_display_id`;
- `setup_movement_event_id`;
- `display_id`;
- unique event/display pair.

Examples:

- `CONTAINER_LOCATION` normally requires no child Display rows; onboard Display location is derived by carrier propagation;
- `UNLOAD` contains all Displays unloaded in that operator action;
- `LOAD` contains all Displays attached/reloaded to the carrier;
- `DISPLAY_LOCATION` or `VERIFIED_PRESENT` contains the individually/bulk affected Displays.

### Derived current carrier/location state

Do not maintain another manually edited current-location column.

Derive current state from:

1. baseline `ref.display.container_id` / `ref.container.location_code`;
2. latest Setup movement events in the selected annual session.

Required views/concepts:

- `ops.v_setup_container_current_state`;
- `ops.v_setup_display_current_state`;
- `ops.v_setup_container_onboard_display`.

A Display is treated as attached to its baseline/current carrier until an `UNLOAD`, independent Display-location event, or verified-placement event detaches it. A later `LOAD` may explicitly attach it again, including to a different temporary carrier if field reality requires that.

### Bulk unload UI

Individual Display scanning must be the exception, not the standard workflow.

Normal transport workflow:

```text
scan Container / trailer
    -> confirm or scan current Setup location
        -> system inspects Displays still onboard
            -> system groups expected unload sets using current field context/task knowledge
                -> operator chooses plain-language action
```

Example for the Arch Trailer:

```text
Arch Trailer — Container 34
Current Setup Location: Racing Arches

Unload:
[ Racing Arches ]
[ Polar Bear Playground ]
[ Candyland ]
[ Icicle Tunnel ]
[ Stars ]
[ Food Collection ]
[ Move Container only ]
```

The operator should not need to know that the trailer contains many internal Display IDs or material for several Stages.

Selecting an unload group shows the expected count/list and provides an **Adjust Displays** exception path before confirmation.

After confirmation:

- that Display set is detached at the destination;
- remaining Displays continue traveling with the Container;
- subsequent Container scans affect only those remaining onboard.

### Task completion reconciliation

Task completion is stronger evidence than a missing scan.

When a task is marked COMPLETE, the system may reconcile required Display movement when the expected location is unambiguous:

```text
required Display has no adequate movement record
    + task completion verifies material is present
        -> record VERIFIED_PRESENT at the task location
        -> source = TASK_COMPLETION
```

Do **not** manufacture missing `LOAD`, `CONTAINER_LOCATION`, or `UNLOAD` events.

Only the Display set actually proven by the completed task is corrected. Completion of one task does not move every Display assigned to the same Container.

## Movement-aware pick list

The pick list is not just a static list of Containers.

Conceptual path:

```text
selected/scheduled task
    -> required Displays
        -> current authoritative Display-to-Container assignment
    + supplemental support Containers
        -> deduplicate Container IDs
            -> compare against Setup movement state
```

Useful derived states include:

```text
NEEDS PICKING
ALREADY AT PARK
STAGED / PARTIALLY UNLOADED
REQUIRED DISPLAY SET ALREADY PLACED
```

A shared Container already at the park must not appear as though it needs to be fetched from storage again simply because another task later requires material still onboard.

## 2025 verification season and 2026 creation

### 2025

2025 is the first Setup Session created for team verification.

Admin creates `ops.setup_session` for existing `ref.season` 2025.

Managers use the UI to distinguish clearly between:

```text
EDIT REUSABLE TASK
    -> changes future reusable task knowledge

EDIT 2025 ACTUAL
    -> corrects historical 2025 fact only
```

2025 verification should cover:

- task name/boundary;
- reusable order and predecessors;
- normal crew/captains/resources;
- required Displays/KIT/support Containers;
- historical 2025 dates/actuals where evidence exists;
- known shared/mixed Container unload groupings.

Current validated `ref.display.container_id` relationships are accepted as the available authoritative Container assignments for 2025 reconstruction.

Do not create seasonal Container-assignment history.

Do not invent 2025 movement events when no evidence exists. Historical movement may remain unknown/partial.

### 2026

After the 2025 verification pass is accepted, Admin creates the 2026 Setup Session.

Creation seeds fresh `ops.setup_session_task` rows from the verified active reusable task catalog.

Do **not** copy forward:

- 2025 completion state;
- 2025 planned/actual dates;
- 2025 movement events;
- 2025 actual crew/duration/delay state.

Reusable task knowledge carries forward; annual execution state does not.

The initial rollout may prevent the UI from offering 2026 creation until 2025 is marked VERIFIED, but this is an initial rollout rule rather than a permanent database law that every future year must enforce identically.

## Permissions / responsibility boundary

### Admin

Admin can:

- create the annual Setup Session;
- perform annual session-level administrative actions;
- finalize/close annual verification or season state as designed.

### Managers

Managers can:

- add/edit/rename/reorder reusable Setup tasks;
- add/retire tasks according to task identity rules;
- edit dependencies, contexts, captains, resources, Display and support-Container requirements;
- manage annual scheduling and actuals;
- correct 2025 historical facts during verification.

### Field operators / transport crews

Field operators should be able to perform simple movement actions without permission to alter reusable task definitions:

- scan Container/Display/location;
- confirm Container location;
- bulk unload an expected group;
- adjust the expected set when reality differs;
- record an individual exception movement.

The UI must present physical actions, not database structure.

## Actor/audit contract

New Setup tables should follow the existing project actor pattern verified in live production.

Use the applicable project-standard fields, including:

- `created_at`;
- `created_by` where current standard requires it;
- `created_by_person_id`;
- `updated_at`;
- `updated_by` where current standard requires it;
- `updated_by_person_id`.

Attach:

```text
ref.set_actor_on_insert()
ref.set_actor_on_update()
```

as appropriate, rather than creating a Setup-specific actor mechanism.

Exact nullability/defaults will be stated in the DDL proposal after comparison with the current migration standards.

## Human-readable views / UI surfaces

### Task Library

Manager-facing reusable catalog:

- context;
- display order;
- task name;
- predecessor names;
- crew range;
- normal captain(s);
- major resources;
- elapsed time;
- date/weather/power notes;
- completion point;
- material requirements;
- review/active status.

Managers can add/edit/rename/reorder/retire here.

### Annual Setup Season

Season selector should make the current rollout obvious:

```text
2025 — Historical Verification
2026 — created after 2025 verification
```

Annual UI shows dates, state, captain/crew actuals, reschedule reasons, notes, and movement/material readiness without silently editing reusable definitions.

### Movement / Unload

Action-first field UI:

```text
Scan Container
    -> confirm location
        -> choose what happened here
```

Examples:

- Unload Racing Arches;
- Unload Polar Bear Playground;
- Unload Icicle Tunnel;
- Move Container only.

The system resolves the underlying Displays.

## Task order, dependency, and schedule order remain separate

1. `ref.setup_task.display_order` — normal human catalog order;
2. `ref.setup_task_dependency` — actual prerequisites;
3. `ops.setup_work_day_task.planned_order` — one day's chosen work order.

Sorting the catalog must never alter dependencies. Moving a task to another date must never alter reusable dependency structure.

## Recommended implementation order

Movement is part of the core design now even if the field scan UI is deployed after the first verification screen.

### Slice 1 — Core schema + 2025 verification UI

DDL proposal should include the reusable task foundation and annual session foundation needed to create/select 2025 and review it in the real application.

At minimum:

- `ref.setup_task`;
- `ref.setup_task_context`;
- `ref.setup_task_dependency`;
- `ref.setup_task_display`;
- `ref.setup_task_container_support`;
- `ref.setup_task_captain`;
- `ref.setup_resource`;
- `ref.setup_task_resource_requirement`;
- `ops.setup_session`;
- `ops.setup_session_task`;
- task-catalog / annual verification views.

Historical source rows are imported/reconstructed under controlled rules; they do not become duplicate reusable tasks.

### Slice 2 — Work-day scheduler and annual actuals

Add/activate:

- `ops.setup_work_day`;
- `ops.setup_work_day_task`;
- remaining-work and schedule views;
- manager schedule UI.

### Slice 3 — Movement/unload execution

Add/activate the movement event tables, current-state views, and action-first Scan/Setup UI.

The movement **schema and semantics are reviewed with the core design now**; this slice distinction is deployment order, not permission to redesign movement later from scratch.

### Slice 4 — Movement-aware pick list and resource readiness

Combine scheduled task demand with current Production relationships and movement state so leaders can answer:

> Given today's planned work, what still has to be brought to the park, what is already there, and what material has already been unloaded/placed?

## Required acceptance cases

The final schema/UI must represent all of these without spreadsheet tricks or repetitive scanning:

- Magic Igloo practical phases with explicit predecessors and multi-day continuation;
- independent tasks with no predecessors;
- one completed task releasing several successors without auto-scheduling them;
- many parallel tasks across Stages on one day;
- Food Collection early and late phases with separate dates;
- Who House dependency on earlier arch/trailer availability;
- current Display-to-Container material resolution;
- KIT/support Container requirements not derivable from Displays;
- Container 34 shared across many tasks but appearing once in the movement-aware pick logic;
- Arch Trailer multi-drop workflow across Racing Arches, Polar Bear Playground, Candyland, Icicle Tunnel, Stars, and Food Collection;
- one Container scan moving all currently attached Displays;
- unload of one Display group preventing that group from following later Container scans;
- later move of the same Container moving only remaining onboard Displays;
- bulk unload by expected group without scanning every Display;
- operator adjustment when the expected unload set differs from reality;
- individual Display move as exception workflow;
- task completion correcting a forgotten scan through `VERIFIED_PRESENT` without fabricating intermediate events;
- 2025 historical verification separated from reusable-task editing;
- Admin-created 2026 session seeded fresh only after the 2025 verification rollout is accepted;
- team sorting/filtering the task catalog without losing predecessor relationships.

## Remaining DDL-review questions

The major architecture questions are now resolved. Remaining implementation details before production DDL are narrower:

1. exact ID generation style and actor-field nullability/defaults for each new table;
2. exact controlled status values/check constraints;
3. exact procedure/function used by Admin to create a Setup Session and seed annual task rows;
4. exact universal-resolver adapter used by Setup to choose/display Stage/Sub-stage context;
5. exact procedure-linking mechanism without duplicating document paths/IDs;
6. exact application/service transaction that performs task-completion movement reconciliation;
7. whether movement destination needs a durable GIS/site-location FK in the first release or can begin with Stage/Work Area/Storage context while the GIS identity model is completed.

## Immediate next engineering step

Produce the first **DDL proposal only** for the core Setup schema, beginning with the reusable task catalog and annual 2025 verification/session foundation and including the agreed movement-event objects in the schema review.

Do not execute that DDL in Production until the proposal is reviewed and explicitly approved.