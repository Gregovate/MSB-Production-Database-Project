# Setup #175 / #132 Perform Work + Report Work Production Acceptance — 2026-09-26

| Document Control | Value |
|---|---|
| Document Type | Production Acceptance Record |
| System | Production Database — Setup Session |
| Issues | #175, #132, #122 |
| Related | #205 continuation scheduling, #172 correction intake |
| Status | ACCEPTED / PRODUCTION |
| Owner | MSB Production Database / Setup |
| Accepted Date | 2026-09-26 |

## Accepted Production Target

```text
application SHA = 15864bcce17d0b59c8396e99178e7113fc368b2d
version         = V0.3.19-pick-list
migration       = Setup/Database/061_add_live_assignment_report_work.sql
```

The Production deployment intentionally pinned the browser-accepted application SHA above even though later commits on the feature branch added deployment tooling and closeout documentation.

## Production Capability Accepted

The live Setup application now supports the scheduled field-execution loop:

```text
Plan / Schedule
  -> scheduled assignment
  -> Perform Work
     -> Captain-filtered scheduled work
     -> Print Task
     -> current published Procedure
     -> Report Work
  -> actual work history
  -> partial work remains IN_PROGRESS
  -> schedule a new continuation assignment when needed
```

Accepted operator behavior:

- **Perform Work** is driven by real scheduled assignments, not the annual backlog.
- Scheduled work is grouped by Setup Day, AM/PM, Crew/Captain, and assignment order.
- The **Captain** dropdown includes **All scheduled work** plus scheduled Captains.
- A signed-in scheduled Captain may be selected by default when no saved preference exists.
- An explicit Captain / All choice is remembered for that user and season.
- **Print Task** produces the bounded selected-task cover sheet rather than the Scheduling Board.
- The current published Setup Procedure is available from task context.
- Procedure-resolution failure does not block legitimate Report Work.
- **Report Correction** is visible but intentionally disabled; #172 owns the future field-correction intake/triage workflow.

## Report Work Actuals

Each new work report captures:

- **Work completed on** — actual calendar date work happened;
- actual crew size;
- actual elapsed Hours / Minutes;
- cumulative percent complete;
- what was done / what remains for incomplete work; and
- optional quantity / unit detail when useful.

Durable semantics:

```text
scheduled date != actual work date != recorded_at
```

The scheduled assignment remains the planning/history identity. **Work completed on** is actual execution evidence. `recorded_at` remains the automatic audit timestamp.

The migration adds `ops.setup_task_progress.performed_on`, `duration_minutes`, and `percent_complete` for new execution evidence without backfilling false values onto older progress rows.

## Partial Work / Continuation

Browser acceptance confirmed the real continuation lifecycle:

```text
worked assignment
  -> historical / locked

annual task
  -> IN_PROGRESS

remaining work
  -> new scheduled assignment
  -> may move to another day / shift / Crew / Captain
  -> remains movable until actual work is reported against that occurrence
```

Operator acceptance specifically confirmed that partial work can be rescheduled and the new continuation can be assigned to a different Captain without rewriting the original worked occurrence.

## Work-Report Corrections

Managers can use **Correct report** on an existing progress-history entry.

The correction path:

- updates the existing progress row rather than creating a duplicate;
- preserves the progress identity;
- preserves the scheduled-assignment link;
- preserves the original reporter and `recorded_at`;
- uses the existing update-audit actor/timestamp fields;
- recalculates derived annual duration/status/completion evidence; and
- does not unlock or move the historical worked assignment.

There is no ordinary delete/replace path for a work report.

## #175 Print / Procedure Scope Disposition

The Production-accepted #175 field-print behavior is the bounded **Setup Task Cover Sheet** reviewed by the operator during browser acceptance.

It includes selected-task identity, scheduled context, generated time, task context, and handwritten field-notes/correction space.

Earlier #175 issue text described a broader disposable packet/currentness concept, including an expiration-based packet. That broader concept is not the current Production behavior and was not retained as a #175 launch blocker after operator review accepted the bounded task cover sheet.

The controlled published Setup Procedure remains authoritative. A printed cover sheet is a field aid, not a new procedure source.

## #172 Boundary

Field correction / observation intake remains separate.

Current Production behavior:

```text
Report Work       = enabled / Production
Correct report    = enabled for Managers / Production
Report Correction = visible but disabled
```

#172 owns enabling the durable **Report Correction** observation/intake/triage path. It must preserve known Setup task/schedule/procedure context without turning every observation into a Work Order automatically.

## Engineering Acceptance

Exact accepted candidate regression:

```text
python -m pytest .\Setup\Application -q
525 passed in 0.98s
```

Reusable current-Production-clone disposable acceptance:

```text
SETUP REUSABLE DISPOSABLE ACCEPTANCE: CLEAN EXIT
```

Browser acceptance included:

- scheduled-assignment projection;
- Captain filtering;
- Procedure load;
- Work completed on date;
- compact Report Work form;
- Manager report correction;
- bounded Print Task output;
- Report Correction label;
- partial work -> IN_PROGRESS;
- continuation scheduling; and
- reassignment of the future continuation to a different Captain.

Operator disposition:

```text
working good enough — ready for Production
```

## Production Deployment

Bounded deployment result:

```text
SETUP #175/#132 REPORT WORK PRODUCTION DEPLOYMENT WRAPPER: PASS
Exit status: 0
```

Final invariants:

```text
Frozen Setup business fingerprint: 3e581494b460ee8e161c76b1481934ae
Final Setup business fingerprint:  3e581494b460ee8e161c76b1481934ae
PASS: governed Setup business data fingerprint unchanged

2026 Setup Session count before: 1
2026 Setup Session count after:  1
PASS: 2026 Setup Session count unchanged

Setup progress row count before: 0
Setup progress row count after:  0
PASS: Setup progress row count unchanged
```

Rollback archive:

```text
/home/msbadmin/backups/setup-175-132/
msb-pre-setup-175-132-report-work-20260926T175240.dump
```

Rollback archive SHA256:

```text
6661cc8541728ea21664c4a0bd2c6e2f50fcf78d95ca2cc34ec74211ecfd0fca
```

Deployment report:

```text
/home/msbadmin/setup-deployment-reports/
Setup_175_132_Report_Work_Production_Deploy_20260926T175240.txt
```

The deployment runner also completed the exact-target Production-runtime regression, migration 061 contract/least-privilege validation, service restart/health validation, authenticated and unauthenticated API checks, live Setup regression, and final checkout/invariant checks before returning PASS.

## Closeout

- #175 Production field-execution / Captain Work List slice: accepted and complete.
- #132 Report Work / actual duration/date/progress slice: accepted and complete.
- #205 continuation scheduling behavior: browser-confirmed and preserved.
- #172 field correction / observation intake: remains open and is the next owning workstream.
- #122 remains the commanding Setup integration issue.
