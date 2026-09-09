# Setup Parallel Crew / Shift Scheduling Contract — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Planning-Workflow Contract |
| System | Production Database — Setup Session |
| Status | CURRENT DESIGN DIRECTION — operator-confirmed; not yet implemented |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; Issue #132; Setup Smart Scheduler Workflow; Setup Planning Candidate Work View |

## Purpose

Define how the Setup smart scheduler represents **parallel work**, shifts, and temporary crew lanes without turning scheduling into person assignment.

The scheduler decides **what work is assigned to a work period and crew lane**. It does **not** need to know which named people make up that crew.

## Operator-Confirmed Scheduling Model

MSB may run several Setup tasks in parallel on the same day.

The planning model uses temporary crew lanes such as:

```text
Crew A
Crew B
Crew C
```

and work periods such as:

```text
MORNING
AFTERNOON
ALL_DAY
```

A person is not permanently attached to a crew label. The same volunteer may work with Crew A in the morning and Crew B in the afternoon.

Therefore Crew A/B/C are **scheduling lanes for a work period**, not durable teams and not person records.

## Scheduler Boundary — Do Not Schedule People

The smart scheduler should not require named-person assignment to schedule normal Setup work.

It should reason from:

- eligible task;
- work date;
- shift/work period;
- crew lane;
- planned crew count where useful;
- task crew guidance;
- equipment/material/readiness;
- current progress;
- physical-effort guidance; and
- operator-selected order.

Named volunteer identity belongs outside the core scheduling decision.

Future attendance, capability, Captain, or volunteer-history workflows may record people separately, but the smart scheduler must remain useful without building a person roster first.

## Parallel Work-Day Board

A useful work-day planner should allow multiple tasks to be scheduled at the same time in different lanes.

Conceptually:

```text
THURSDAY

MORNING
  Crew A   Magic Igloo — Bungees
  Crew B   Candyland — Tree Benches
  Crew C   Elf Choir — Conductor / Notes

AFTERNOON
  Crew A   Mega Tree — Lights
  Crew B   Magic Igloo — Bungees continuation
  Crew C   Food Collection — Arches

ALL DAY
  Crew A/B/C lanes available for tasks intentionally treated as all-day work
```

The exact UI may use columns, cards, lanes, or another tablet-friendly drag/drop layout, but parallelism must be explicit.

## Crew Labels Are Shift-Local Planning Lanes

`Crew A` in the morning does not imply the same people as `Crew A` in the afternoon.

Likewise, a volunteer may change crews between shifts without requiring a scheduler edit.

Do not model Crew A/B/C as permanent `ref.person` groups.

A practical assignment identity is conceptually:

```text
work day
+ shift
+ crew lane
+ task
```

with a planned headcount if the operator wants it.

## Morning / Afternoon / All-Day Semantics

The existing Setup scheduling candidate already recognizes:

```text
MORNING
AFTERNOON
ALL_DAY
```

and planned crew count on `ops.setup_work_day_task`.

The missing scheduling concept is the **parallel crew lane**.

Future engineering should extend the existing lightweight work-day scheduling contract rather than inventing a separate person-scheduling system.

### ALL_DAY

An all-day assignment means the task is expected to occupy a lane for both major work periods or otherwise be treated as all-day work.

It must not imply that the exact same named people remain on the task all day.

If field practice requires one task to be explicitly assigned to different crew lanes in Morning and Afternoon, the data model must permit that instead of forcing a single person/team identity.

## Drag / Drop Direction

Desired interaction:

```text
AVAILABLE NOW
    task cards

        drag -> Thursday / Morning / Crew A
        drag -> Thursday / Morning / Crew B
        drag -> Thursday / Afternoon / Crew A
        drag -> Friday / All Day / Crew C
```

Within a lane, drag/drop order can represent the intended sequence if more than one task is assigned to that lane/work period.

Moving a task between lanes must change only annual short-range scheduling state. It must not alter reusable Stage/Scene order.

## Relationship to Smart Eligibility

The left-side candidate pool should continue to show only tasks that are currently eligible.

Blocked downstream tasks such as cord laying, network connection, or other prerequisite-dependent work remain absent until they become available.

Once eligible, a task may be placed in any practical shift/crew lane selected by the operator.

The scheduler does not need to calculate named-person conflicts because named people are not part of this scheduling layer.

## In-Progress / Multi-Period Work

An incomplete task can appear repeatedly across work periods until complete.

Example:

```text
Monday Morning / Crew A
  Magic Igloo — Bungees
  work report: 30% complete

Tuesday
  lighter work scheduled instead

Wednesday Afternoon / Crew B
  Magic Igloo — Bungees continuation
```

This is normal operation.

The scheduler should not force a task to remain on the same crew lane, shift, or consecutive day.

## Field Reporting Alignment

Each actual work report should still capture the real work period evidence required by issue #132:

```text
crew size
elapsed hours/minutes
progress / what was completed
what remains
complete/not complete
```

Where a scheduled assignment exists, the report should retain enough context to identify the relevant work day / shift / crew lane without requiring named crew members.

The crew lane is operational context; `crew_count` remains the actual headcount evidence.

Do not infer actual named participants from the crew lane.

## Current Implementation Evidence / Gap

Migration `009_create_setup_scope_schedule_execution_commands.sql` already added lightweight scheduling with:

```text
shift_code = MORNING | AFTERNOON | ALL_DAY
sort_order
planned_crew_count
```

The current scheduling command does not include a Crew A/B/C lane field, so parallel crew-lane scheduling is an unimplemented extension of the existing work-day model.

Before schema changes, verify the exact current Production constraints and browser behavior. Do not apply database changes from this design document.

## Initial Complexity Guardrail

Do not add person-level optimization or conflict checking to the first smart scheduler.

The first useful parallel scheduling model is:

```text
eligible tasks
-> operator drag/drop
-> date
-> shift
-> crew lane A/B/C
-> optional planned crew count
-> task order within lane
```

People can move among crews during the day without affecting scheduler correctness.

## Acceptance Direction

A useful first release should prove:

1. several tasks can be planned in parallel for the same work period;
2. Morning, Afternoon, and All-Day remain supported;
3. Crew A/B/C are temporary scheduling lanes, not person groups;
4. the same volunteer may conceptually change crews between shifts without scheduler changes;
5. named people are not required to create or maintain the schedule;
6. eligible tasks can be drag/dropped between work-day/shift/crew lanes;
7. tasks may continue on a different day, shift, or crew lane until complete;
8. actual work reports capture crew count, elapsed time, progress, and remaining work;
9. reusable Stage/Scene order remains separate from annual schedule order; and
10. the resulting structure still feeds Pick List/logistics from the tasks actually scheduled.

## Related Durable Sources

- [Setup Smart Scheduler Workflow](Setup_Smart_Scheduler_Workflow_2026-09-09.md)
- [Setup Planning Candidate Work View](Setup_Planning_Candidate_Work_View_2026-09-09.md)
- [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md)
- [Setup Pick List Tablet Workflow](Setup_Pick_List_Tablet_Workflow_2026-09-09.md)
- GitHub issue #122
- GitHub issue #132
