# Setup Parallel Crew / Shift Scheduling Contract — 2026-09-09

| Document Control | Value |
|---|---|
| Document Type | Engineering Planning-Workflow Contract |
| System | Production Database — Setup Session |
| Status | CURRENT DESIGN DIRECTION — operator-confirmed; not yet implemented |
| Owner | MSB Production Database engineering |
| Related Work | Issue #122; Issue #132; Setup Smart Scheduler Workflow; Setup Planning Candidate Work View |

## Purpose

Define how the Setup smart scheduler represents **parallel work**, shifts, temporary crew lanes, and lightweight day-of Captain assignment without turning scheduling into person assignment.

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

Future attendance, capability, or volunteer-history workflows may record people separately, but the smart scheduler must remain useful without building a person roster first.

## Lightweight Captain Assignment

A **day-of / scheduled-work Captain** is different from assigning the individual members of a crew.

MSB often knows who will lead a crew when the work is scheduled, or may not know until the day of the work. Captain assignment therefore should be **optional when scheduling and easy to fill or change later**.

The desired operator behavior is:

```text
Schedule task into date / shift / Crew A
    -> planned crew count optional
    -> Captain optional / may remain TBD

Later, when known:
    -> select Captain from active eligible people
    -> no need to enter the rest of the crew
```

The scheduler must not block a task from being scheduled merely because the Captain is not yet known.

A practical card may show only:

```text
Crew A
Task: Magic Igloo — Bungees
Planned crew: 4
Captain: Paul N.       # or TBD
```

Captain selection should be a quick type-ahead or equivalent compact control, not a separate staffing workflow.

### Reusable leadership versus scheduled-work Captain

Do not collapse these concepts:

```text
ref.setup_task_captain
    reusable task knowledge / Captain / Alternate / Advisor relationship

scheduled-work Captain
    person leading this actual work-day / shift / crew-lane assignment
```

A reusable task Captain may be a useful suggestion when scheduling, but the actual crew Captain for a particular work period can differ.

The system should not silently copy reusable leadership into annual execution fact without operator confirmation.

### Work-report authorization implication

Current Production execution authorization is based on Manager or reusable CAPTAIN/ALTERNATE relationships. A future scheduled-work Captain is intended to be the person who can easily submit the work report for that crew/work period.

Before implementation, engineering must deliberately reconcile these authorization semantics. Do not assume the existing reusable-task Captain relationship is equivalent to the day-of crew Captain.

The intended operator outcome is simple:

- Manager can always manage/report under the governed boundary;
- an explicitly assigned scheduled-work Captain should be able to report the work for that scheduled assignment;
- no individual crew roster is required.

Exact database/auth changes require separate implementation review and acceptance.

## Parallel Work-Day Board

A useful work-day planner should allow multiple tasks to be scheduled at the same time in different lanes.

Conceptually:

```text
THURSDAY

MORNING
  Crew A   Magic Igloo — Bungees        Captain: Paul
  Crew B   Candyland — Tree Benches     Captain: TBD
  Crew C   Elf Choir — Conductor/Notes  Captain: Fred

AFTERNOON
  Crew A   Mega Tree — Lights           Captain: Tim
  Crew B   Magic Igloo — Bungees cont.  Captain: Paul
  Crew C   Food Collection — Arches     Captain: TBD

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

with a planned headcount and optional scheduled-work Captain.

## Morning / Afternoon / All-Day Semantics

The existing Setup scheduling candidate already recognizes:

```text
MORNING
AFTERNOON
ALL_DAY
```

and planned crew count on `ops.setup_work_day_task`.

The missing scheduling concepts are the **parallel crew lane** and optional **scheduled-work Captain**.

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

Captain selection should remain an inline secondary edit on the scheduled card, not part of the drag operation itself.

## Relationship to Smart Eligibility

The left-side candidate pool should continue to show only tasks that are currently eligible.

Blocked downstream tasks such as cord laying, network connection, or other prerequisite-dependent work remain absent until they become available.

Once eligible, a task may be placed in any practical shift/crew lane selected by the operator.

The scheduler does not need to calculate named-person conflicts because named people are not part of this scheduling layer beyond the optional Captain for a scheduled work assignment.

## In-Progress / Multi-Period Work

An incomplete task can appear repeatedly across work periods until complete.

Example:

```text
Monday Morning / Crew A
  Magic Igloo — Bungees
  Captain: Paul
  work report: 30% complete

Tuesday
  lighter work scheduled instead

Wednesday Afternoon / Crew B
  Magic Igloo — Bungees continuation
  Captain: Paul or another accepted Captain
```

This is normal operation.

The scheduler should not force a task to remain on the same crew lane, shift, Captain, or consecutive day.

## Field Reporting Alignment

Each actual work report should still capture the real work period evidence required by issue #132:

```text
crew size
elapsed hours/minutes
progress / what was completed
what remains
complete/not complete
```

Where a scheduled assignment exists, the report should retain enough context to identify the relevant work day / shift / crew lane and scheduled-work Captain without requiring named crew members.

The crew lane is operational context; `crew_count` remains the actual headcount evidence.

Do not infer actual named participants from the crew lane or from the Captain identity.

## Current Implementation Evidence / Gap

Migration `009_create_setup_scope_schedule_execution_commands.sql` already added lightweight scheduling with:

```text
shift_code = MORNING | AFTERNOON | ALL_DAY
sort_order
planned_crew_count
```

The current scheduling command does not include a Crew A/B/C lane field or scheduled-work Captain, so both remain unimplemented extensions of the existing work-day model.

The current command also appears oriented around one annual-task assignment per work day. Future implementation must verify whether repeated Morning/Afternoon assignments for the same annual task require a different assignment identity/constraint.

Before schema changes, verify the exact current Production constraints and browser behavior. Do not apply database changes from this design document.

## Initial Complexity Guardrail

Do not add person-level optimization, full volunteer rosters, or conflict checking to the first smart scheduler.

The first useful parallel scheduling model is:

```text
eligible tasks
-> operator drag/drop
-> date
-> shift
-> crew lane A/B/C
-> optional planned crew count
-> optional Captain / TBD
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
6. Captain is optional when scheduling and can be filled/changed quickly later;
7. reusable task leadership and day-of scheduled-work Captain remain distinct;
8. an accepted scheduled-work Captain can submit the work report without requiring the rest of the crew to be entered individually;
9. eligible tasks can be drag/dropped between work-day/shift/crew lanes;
10. tasks may continue on a different day, shift, crew lane, or Captain until complete;
11. actual work reports capture crew count, elapsed time, progress, and remaining work;
12. reusable Stage/Scene order remains separate from annual schedule order; and
13. the resulting structure still feeds Pick List/logistics from the tasks actually scheduled.

## Related Durable Sources

- [Setup Smart Scheduler Workflow](Setup_Smart_Scheduler_Workflow_2026-09-09.md)
- [Setup Planning Candidate Work View](Setup_Planning_Candidate_Work_View_2026-09-09.md)
- [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md)
- [Setup Pick List Tablet Workflow](Setup_Pick_List_Tablet_Workflow_2026-09-09.md)
- GitHub issue #122
- GitHub issue #132
