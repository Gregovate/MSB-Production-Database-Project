# Rick 2025 Reconstruction Batch 01 — 2026-09-08

| Document Control | Value |
|---|---|
| Document Type | Engineering Historical Reconstruction Mapping |
| System | Production Database — Setup Session |
| Status | REVIEW CANDIDATE — no Production mutation authorized by this document |
| Owner | MSB Production Database engineering |
| Source Window | 2025-09-30 through Thanksgiving 2025 |
| Related Work | Issue #122; PR #125; issue #132 |

## Purpose

Turn Rick Hoffmann's 2025 Setup records into specific, reviewable Production Database candidates rather than leaving the spreadsheets as disconnected reference material.

This batch maps only evidence that can be tied with reasonable confidence to an existing 2025 Setup Session task and a defensible crew count. Ambiguous shorthand and work that exposes a missing reusable task are kept out of the import-ready set until the task boundary is resolved.

The current Production mapping snapshot shows `existing_progress_rows = 0` for the listed 2025 tasks, so this first historical-progress batch does not need to merge with pre-existing progress history.

## Source Files

- `Copy of Copy of 2025 Work (1).xlsx`
- `MSB Rick Recorded Hours 2025(1).xlsx`
- current 2025 Production task mapping snapshot exported 2026-09-08

Rick's total daily hours are not treated as task duration unless the source isolates one task or states an explicit task time range.

## Import-Ready Historical Progress Candidates

| Date | setup_session_task_id | setup_task_id | Current Task | Shift | Crew | Duration min | Historical progress evidence | Import note |
|---|---:|---:|---|---|---:|---:|---|---|
| 2025-10-06 | 37 | 37 | Install Skins and Bungees | ALL_DAY | 6 | 300 | Tom, Mark, Paul, Mike V., Steve, Norm worked on Magic Igloo skins from 9:00 to 2:00; source explicitly says this does not include bungees. | Strongest duration evidence in current batch; partial progress only. |
| 2025-10-07 | 50 | 50 | Locates — Elf Choir | ALL_DAY | 1 |  | Rick located network/electrical for Elf Choir. | Date + task + one named worker are explicit; exact duration unknown. |
| 2025-10-07 | 63 | 63 | Locate underground network and power — Hwy 42 | ALL_DAY | 1 |  | Rick located network/electrical for Hwy 42. | Date + task + one named worker are explicit; exact duration unknown. |
| 2025-10-07 | 37 | 37 | Install Skins and Bungees | ALL_DAY | 2 |  | Paul N. and Norman worked on Magic Igloo bungees. | Partial progress; exact duration unknown. |
| 2025-10-08 | 37 | 37 | Install Skins and Bungees | MORNING | 1 |  | Rob worked on Magic Igloo bungees in the morning. | Partial progress. |
| 2025-10-08 | 37 | 37 | Install Skins and Bungees | AFTERNOON | 1 |  | Paul worked on Magic Igloo bungees in the afternoon. | Partial progress. |
| 2025-10-09 | 47 | 47 | Install Fred's Stars | MORNING | 3 |  | Tim, John, and Paul worked on Fred's Stars in the morning. | Current reusable range 2–3 is consistent with this evidence. |
| 2025-10-13 | 11 | 11 | Install Mt Crumpit Panels | ALL_DAY | 4 |  | Rick's hours record identifies Tom, Steve, John, and Rick on Mt Crumpit. | A separate shorthand source contains an uncertain Mark entry; the more explicit hours record supports four. |
| 2025-10-13 | 21 | 21 | Install Icicle Tunnel | ALL_DAY | 6 |  | Paul, Randy, Mike, Dave H., Paul H., and Rob worked on Icicle Tunnel. | Exact duration unknown. |
| 2025-10-15 | 11 | 11 | Install Mt Crumpit Panels | ALL_DAY | 4 |  | Mark, Tom, Steve, and Rick worked on Mt Crumpit. | Repeated multi-day evidence for same reusable task. |
| 2025-10-20 | 11 | 11 | Install Mt Crumpit Panels | ALL_DAY | 4 |  | Tom, Steve, John, and Rick worked on Mt Crumpit. | Repeated multi-day evidence for same reusable task. |
| 2025-10-21 | 2 | 2 | Install Mega Cube Frame and Panels | ALL_DAY | 3 |  | Tom, Randy, and Paul worked on Mega Cube; source says they likely did not connect controllers. | Maps to frame/panel task, not Controller / Final Hookup. |
| 2025-10-27 | 30 | 30 | Install Polar Bear Igloos | ALL_DAY | 3 |  | Paul, Randy, and Paul H. worked on Igloos in Polar Bear Playground. | Exact duration unknown. |
| 2025-11-13 | 19 | 19 | Put Up 24 Stars | ALL_DAY | 5 |  | Stars were hung by Paul and Rich with three people on the ground. | Treat as progress evidence; do not infer all 24 were completed unless separately confirmed. |

## Strong Reusable-Knowledge Candidates From This Batch

### Mt Crumpit crew range

Three separate dated records support a four-person Mt Crumpit crew:

```text
2025-10-13  crew 4
2025-10-15  crew 4
2025-10-20  crew 4
```

Candidate reusable update for task 11:

```text
normal_crew_min = 4
normal_crew_max = 5
```

The maximum remains five rather than four because one shorthand source contains an uncertain fifth person on two of the dates. Do not claim a precise four-person maximum from inconsistent source shorthand.

### Magic Igloo skins/bungees are multi-period work

Task 37 has evidence across at least three work days and multiple work periods:

```text
2025-10-06  skins       crew 6  300 minutes
2025-10-07  bungees     crew 2  duration unknown
2025-10-08  bungees AM  crew 1  duration unknown
2025-10-08  bungees PM  crew 1  duration unknown
```

This directly supports the Setup operating rule that one reusable task can span several days and multiple progress reports.

## Missing Reusable Tasks / Steps Exposed by Rick's Records

These source facts appear operationally real but do not currently map cleanly to a reusable task in the supplied Production snapshot. They should not be forced into an unrelated task merely to get them into the database.

| Date | Evidence | Needed review |
|---|---|---|
| 2025-09-30 | Flags/locates for Dancing Forest and Festive Trees; panel-location work. | Determine whether Stage-specific Locate / Layout tasks are missing. |
| 2025-10-07 | Front Gate wraps; Volunteer Path work; scaffold for conveyor belt/Santa bag; Candyland/Church Tree candy-cane layout. | Several independently staffed steps have no clean current task. |
| 2025-10-10 | Elf Choir harness hookup; Snow Storm bull line; Post Office roof; Arch Trailer unload. | Existing task boundaries do not represent all work; Arch Trailer unload is cross-Stage and must not be duplicated blindly across every Stage unload task. |
| 2025-10-16 | Whoville harness, panels, and Goal harness. | Determine whether a dedicated wiring/harness task is required. |
| 2025-10-21 | Horse & Sleigh placement; Santa's Workshop frame; Kranks VW/Bells harness. | Missing reusable tasks/steps likely. |
| 2025-11-04 | Quarry interior/exterior plus cords for Front Entrance, Claymation, Polar Bears. | Quarry work and Stage-specific Lay Cords tasks are not represented cleanly. |
| 2025-11-11 | Festive Trees cords reached about 60% with Paul H., Randy, Dan, Deb. | Strong candidate for a Stage 05 `Lay Cords` reusable task with crew 4 and partial-progress evidence. |

## Evidence Deliberately Not Imported

Do not convert these into task facts without further review:

- `No idea`, `???`, `maybe`, `I think`, uncertain names, and similar shorthand;
- Rick's whole-day recorded hours when several tasks occurred that day;
- volunteer rosters that cannot be tied to one task;
- repair/database/documentation/storm-damage work that is not normal Setup execution;
- work where the current Production task is too broad or the source could map to several tasks;
- historical names as Captain/Alternate/Advisor assignments.

## Required Database Change Before Importing Duration

`ops.setup_task_progress` currently records crew and progress but has no per-progress elapsed-duration field. Batch 01 contains at least one strong exact duration (Magic Igloo skins, 300 minutes), and future Captain reporting also requires duration.

Do not discard that information into prose only.

Issue #132 owns the change to add per-progress duration and the fast Captain work-report UI. The historical import should use the same duration field once accepted.

## Recommended Controlled Import Shape

After the Batch 01 mapping and duration schema are accepted:

1. create/resolve the required 2025 `ops.setup_work_day` rows;
2. insert idempotent `ops.setup_task_progress` rows for the import-ready table above;
3. retain source provenance identifying Rick's 2025 records and the reconstruction batch;
4. do **not** rewrite existing 2025 `execution_status` merely because historical progress evidence is added;
5. do not mark a task complete unless the source specifically proves completion;
6. apply reviewed reusable crew-range updates separately from annual historical evidence;
7. validate on a disposable current-Production clone before any Production mutation.

The normal live progress command currently changes execution state as it records progress, so the historical import must not blindly replay these old rows through that command against already reconstructed 2025 COMPLETE tasks. Use a bounded reconstruction migration/command that preserves current execution state while adding historical evidence.

## Related Durable Sources

- [Setup Planning Operating Model](Setup_Planning_Operating_Model_2026-09-08.md)
- [Setup Crew Work Reporting Contract](Setup_Crew_Work_Reporting_Contract_2026-09-08.md)
- [2025 Live Review Work Ledger](Setup_2025_Live_Review_Work_Ledger_2026-09-08.md)
- GitHub issue #122
- GitHub issue #132
- GitHub PR #125
