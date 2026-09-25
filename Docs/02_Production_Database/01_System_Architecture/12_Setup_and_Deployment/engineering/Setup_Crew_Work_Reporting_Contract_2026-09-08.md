# Setup Crew Work Reporting Contract — 2026-09-08

| Document Control | Value |
|---|---|
| Document Type | Engineering Workflow Contract |
| System | Production Database — Setup Session |
| Status | CURRENT — operator-confirmed execution/reporting requirement |
| Owner | MSB Production Database engineering |
| Last Reviewed | 2026-09-08 |
| Related Work | Issue #122; Issue #132; PR #125 |

## Purpose

Define how actual Setup work should be reported in the field so the planner preserves useful historical effort without becoming a rigid project-management or timesheet system.

This contract is based on operator-confirmed field practice and the current Setup execution implementation.

## Non-Linear Stage Planning

A Stage is organization and context. It is **not** a completion gate.

MSB does not normally finish every task for one Stage and then move sequentially to the next Stage.

The practical field model is:

```text
preferred task order / prerequisites
    + people available now
    + relevant skills / experience available
    + equipment / trailers / lifts available
    + weather / site readiness
    + work already partially completed
    -> choose the best useful work that can be performed now
```

Consequences:

- crews may work on several different Stages during the same day;
- a Stage may remain partially complete while work begins elsewhere;
- a multi-day task may be paused and resumed later;
- equipment availability may cause a later-ranked task to be worked before an earlier task;
- volunteer availability may cause smaller or differently-skilled jobs to be selected;
- the planner must preserve preferred order without treating it as a mandatory sequential waterfall.

This is a major reason Setup is not equivalent to a conventional project-management system.

## Work Reporting Responsibility

The normal field expectation is that the **Captain of the crew** records the work performed for that crew/task period.

The report must be easy enough to complete from the field without reconstructing the day later.

The authenticated reporter identity should be captured automatically through the existing actor/audit boundary. The Captain should not have to type their own name into every report.

Managers may retain governed override/report capability.

## Current Implemented Progress Model

The current Setup execution design already supports durable **multi-period progress** through:

```text
ops.setup_task_progress
```

Current progress evidence includes:

```text
setup_session_task_id
setup_work_day_id
shift_code
crew_count
completed_quantity
completed_units
progress_note
marks_task_complete
recorded_at
created_by_person_id / audit identity
```

The current protected browser form asks for:

```text
Crew size
Completed quantity (optional)
Which units / what was completed (optional)
Progress note
Mark task complete
```

The current API and governed command record crew size and progress detail but do **not** record elapsed work duration for each progress period.

That is the current gap.

## Required Per-Progress Duration

Each progress/work report should record:

```text
actual crew size
elapsed work duration
what was accomplished / progress detail
whether the task is now complete
```

Duration belongs on the **individual progress/work-period record**, because one reusable task can span multiple days and multiple crews.

Recommended database representation:

```text
duration_minutes integer > 0
```

Recommended field UI can remain human-friendly:

```text
Crew size   [ 6 ]
Hours       [ 2 ]
Minutes     [ 30 ]
```

or an equivalent simple duration control.

The application can convert that to total minutes before saving.

Do not require the Captain to fabricate exact clock start/end timestamps when the meaningful fact is simply that the crew worked the task for about 2 hours 30 minutes.

## Why Annual Task Duration Alone Is Not Enough

`ops.setup_session_task.actual_duration_minutes` exists at the annual-task level, but one scalar value cannot faithfully represent this real pattern:

```text
Day 1: Crew 6 works 2h 30m — partial
Day 3: Crew 4 works 1h 15m — partial
Day 6: Crew 5 works 45m — complete
```

The durable source should be the individual progress rows.

If an annual total is useful, it should be derived or deliberately summarized from those progress rows rather than overwriting the evidence of each work period.

## Elapsed Duration vs Person-Hours

These are different measures.

Example:

```text
crew size = 6
elapsed duration = 2.5 hours
```

means:

```text
elapsed crew-task duration = 2.5 hours
person-hours                = 15.0 hours
```

Both can be useful for future planning, but they must not be confused.

Useful derived measures include:

```text
total elapsed crew-task minutes = SUM(duration_minutes)
person-hours                    = SUM(crew_count * duration_minutes) / 60
work periods                    = COUNT(progress rows)
```

The reusable planning estimate should not be automatically overwritten by one atypical work period.

## Captain Reporting UX

The reporting interaction should be available directly from the current crew/task execution view.

Target field workflow:

1. Captain opens the assigned/current task.
2. Selects **Report Work** or equivalent.
3. Enters actual crew size.
4. Enters hours/minutes worked.
5. Optionally records quantity/units and a short progress note.
6. Checks **Task Complete** only if the reusable task's completion point was actually reached.
7. Saves once.

The app should automatically know:

- authenticated reporter;
- current Setup Session;
- task identity;
- current/selected work day when available.

The Captain should not need to navigate raw Setup tables or re-enter context the application already knows.

## Multi-Day Tasks

A progress report does not imply completion.

Required behavior:

- multiple progress records may exist for one annual task;
- each record has its own crew size and duration;
- a task remains `IN_PROGRESS` until explicitly completed;
- later crews can continue the same task;
- previous progress history remains visible;
- total effort can be derived from all progress periods.

## Historical Reconstruction

Rick Hoffmann's 2025 notes can help populate or estimate:

- actual crew size;
- actual work period duration where explicitly supported;
- partial progress;
- completion date/state;
- reusable normal crew range;
- reusable expected duration.

Do not convert a person's whole-day recorded hours into a task duration when that day included several tasks.

Where the historical evidence supports separate work periods, preserve them as separate evidence rather than collapsing them into one fake task duration.

## Authorization Boundary

The existing Setup execution model already distinguishes field execution from broad Manager maintenance. Current migration 009 states that progress/completion commands are available to Managers or a person explicitly assigned as CAPTAIN/ALTERNATE for the reusable task.

Keep that governed model.

The browser/API should not broaden direct table DML merely to add duration reporting.

## Acceptance Criteria

A complete implementation should prove:

- positive per-progress duration validation;
- duration appears in progress history;
- repeated progress reports can be recorded across several work days for one task;
- Captain/Alternate/Manager execution authorization remains intact;
- authenticated reporter identity is stamped automatically;
- partial progress does not mark a task complete;
- task completion remains explicit;
- elapsed duration and person-hours can be derived separately;
- no artificial start/end timestamps are required for ordinary duration reporting; and
- no sequential Stage-completion rule is introduced.

## Related Durable Sources

- [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md)
- [Setup engineering portal](README.md)
- [2025 Live Review Work Ledger](Setup_2025_Live_Review_Work_Ledger_2026-09-08.md)
- GitHub issue #122
- GitHub issue #132
- GitHub PR #125
