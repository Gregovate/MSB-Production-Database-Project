# Existing crew size scheduling repair — #205 under #122

Candidate V0.3.107-schedule-crew-size. Not deployed; browser acceptance pending.
Base main 14f7a949e80f319ab608bb55f705b677a97cac8c.

Rick and Greg both reproduced a locked Unknown Crew size for an existing day
crew. The dialog set readOnly whenever a crew existed and submission discarded
existing-crew counts. Existing staffing is now editable, including a Captain
selected through Add Captain who already has a crew that day.

Design authority: [Scheduling Board contract](../../Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/Setup_Scheduling_Board_Contract_2026-09-17.md#november-11--existing-crew-staffing-in-schedule-annual-task-205).

The existing crew-with-tasks endpoint handles the staffing update and placement
in one transaction, using existing governed SQL functions. The other period and
Captain come from the selected database crew. Wrong-day crews are rejected.
Existing assignment sort order placement remains supplied by the dialog.
No SQL migration, permission broadening, or actual-work mutation is introduced.

Local regression: 979 application tests passed before the final five validation
cases; all 22 repository placement cases then passed. Node dialog checks cover
editable confirmed/unknown counts, existing/new Captain paths and failure retention.
Run the complete application suite for the final published candidate.

Use the existing run_setup_disposable_browser_preview.ps1 wrapper with this
branch's exact SHA, TargetRef fix/205-existing-crew-size, PreviewPort 8898,
ExpectedVersion V0.3.107-schedule-crew-size and AllowConcurrentProductionWrites.
No candidate migrations. Inspect current clone migration readiness normally;
do not reapply unrelated Production migrations as part of this source repair.

Browser checks: existing Rick day crew and selected period with Unknown staffing;
enter count and save a task, refresh and confirm persisted count across its shared
crew tasks. Change an existing confirmed count; other period and Captain must
remain unchanged. Add Captain picker choosing an existing Captain must reuse his
crew. Test a new Captain, changing selected day/period, Cancel without writes,
invalid count and rejected historical move. All writes go to disposable clone.
Exit through reusable preview CLEAN EXIT before Production approval.

## Review correction — V0.3.108-schedule-catch-up

Greg confirmed V107 allows entry for Rick's existing crew but saving Task185
onto November10 rejects a duplicate day assignment. Task185 is Ready to Schedule,
not a continuation task. Left readiness checks future scheduling; the SQL duplicate
guard correctly covers past assignments too. No V107 save-persistence PASS exists.
Preview CLEAN EXIT was operator confirmed. Production approval remains pending.

V108 adds task identity and a selected-day existing-assignment notice. Open
existing assignment edits unworked assignments through the established dialog;
reported history is revealed without allowing moves. Report Work / review report
uses setup205OpenManagerRecord on the exact work-day assignment, including
completed-day visibility. No duplicate is created, no actual work is changed by
opening, and selecting another day restores normal Save behavior.

Retest Task185 on Day38: see its existing assignment and identity before Save;
open it and update crew size if unworked. Use Report Work / review report to
catch up on the real occurrence. Confirm persisted staffing after refresh, other
period/Captain unchanged, Cancel writes nothing. A reported occurrence must
remain reviewable without becoming movable. Then test another day and both
new/existing Captain paths. Reuse the same wrapper/ref/port with V108 and its
new exact candidate SHA. CLEAN EXIT required; no Production changes authorized.

## Simplified backlog — V0.3.109-scheduling-backlog

V108 operator review confirmed the same-day assignment lookup and prominent
Report Work action. Greg rejected showing Task185 as ready in the first place.
V108 preview CLEAN EXIT confirmed. No Production approval or deployment.

V109 classifies active unreported assignments as SCHEDULED regardless of whether
the date has passed. Unstarted tasks remain in Perform Work for catch-up and do not appear
in the default Ready scheduling backlog or its schedulable printout. Explicit
Scheduled inspection still works. Hard-blocker visibility cannot accidentally
reintroduce them. Reported unfinished tasks with no future assignment remain continuations, even
when another historical occurrence still awaits a report. All scheduled
occurrences remain in Perform Work for reporting or Needs Report review. Never-scheduled tasks retain normal rules.
Assignments, reports, completion and actual effort remain unchanged.

986 application tests PASS, including an executable queue regression covering
Task185, past unreported work, partial reports, future assignments, completed work,
print output and blocker visibility. No SQL migrations.

Retest exact new SHA with the existing wrapper/ref on8898, version
V0.3.109-scheduling-backlog. Task185 must be absent from default Ready tasks and
schedulable print but present in Perform Work / scheduled search. Confirm report
catch-up works, a genuine continuation stays available and an unscheduled task
can be assigned with editable existing-crew size; refresh confirms persistence.
Finish reusable CLEAN EXIT before Production approval.

## Perform Work identity clarification — V109 presentation revision

Operator confirms Task185 disappeared from Needs Scheduling: backlog gate PASS.
Perform Work review showed missing visible task numbers and repeated overall
75% beside distinct dated assignments. Display Catalog Task numbers in the past
review summary and collapsed assignment headings; season-only work says Annual
Task with annual ID. Percentages explicitly say Overall task progress and each
review remains tied to its original dated assignment. Do not merge November6
and November7 reports or infer two separate 75% reports.

Presentation-only revision retains V0.3.109; setup_next_pass.js browser asset pin
is refreshed to2026-11-11.109.1. Retest new exact SHA. Existing catch-up and
staffing acceptance remains pending; no new Production permission. Check Task184
on both dates, Task185, season-only identity, and unchanged report links.

## Enforcement candidate — V0.3.110-reschedule-resolution

Source SHA will be pinned in PR482. Not deployed or PostgreSQL/browser accepted.
Migration080 installs a per-annual-task serializing BEFORE INSERT guard. Every
new occurrence must resolve prior active missing reports, even through legacy
commands or direct INSERT. COMPLETE cannot receive new work. Existing data and
all UPDATE-based governed no-work moves remain untouched. This is preventive
enforcement, not automatic cleanup of the eight audit cases.

Schedule and task drops identify outstanding work and offer existing Report Work,
Move — no work performed, and Unschedule — no work performed actions. Changing
the destination date cannot bypass resolution. Reported partial work with no
outstanding missing reports may receive a new continuation. Shared staffing and
assignment saves remain atomic. No auto-report, auto-completion or silent deletion.

Local gate: 986 application tests, executable dialog/action checks, Node syntax,
and PostgreSQL parser checks on migration/PLpgSQL/validation. These are not a
claim of live PostgreSQL behavioral acceptance.

Use the existing disposable wrapper on8898 and exact SHA/ref, ExpectedVersion
V0.3.110-reschedule-resolution, with MigrationPaths
Setup/Database/080_prevent_unreported_setup_assignment_duplicates.sql and
ValidationPaths Setup/Acceptance/setup_205_unreported_assignment_guard_validation.sql.
Validation exercises current and legacy insert signatures rejecting unresolved
occurrences, and a real reported partial task accepting a new continuation, all
inside rollback. Stop if the current clone lacks an appropriate fixture.

Browser: attempt a new date for Task184 with missing Nov6/7 reports; it must
require resolution first. Test Report Work, no-work move, no-work unschedule and
Cancel; each dated history/report remains truthful. Test task-drop/new-crew-drop
as well as Schedule. After actual report or explicit no-work resolution in the
clone, test valid partial continuation. Ensure successful staffing persistence.
CLEAN EXIT required. Production migration/deployment remains separately approved
under current Server Management maintenance/snapshot/rollback authority.

## Scheduling-board identity follow-up

Operator reports Task184 allowed onto Rich's crew despite older unreported
occurrences. Provided board crop shows Setup Tent and Food Collection Sign
(Task178), while Perform Work shows Task184 Stands/Wraps. No header/version or
assignment ID is visible in that board crop; do not assert either user error or
a proven V110 database-guard bypass. Obtain visible Client version and exact
Task/assignment identity before classifying.

Board cards now include reusable Task or explicit Annual Task number, sharing
the Perform Work label helper. V110 presentation-only asset pin110.1 for board.
986 application tests and Node syntax pass; no new schema changes beyond080.
Current-clone acceptance of080 and reported Task184 behavior remain pending.

Operator's later V110 screenshot confirms the Task184 unresolved Nov6 notice,
report/no-work actions, and disabled Save despite choosing another date. This
is a visible guard PASS, not yet a staffing/move/report persistence acceptance.
Dialog now explicitly identifies Edit existing assignment and original scope;
Save existing assignment updates that occurrence rather than adding another.

## V0.3.111-explicit-no-work — close the existing-edit bypass

Greg correctly identified that opening the existing assignment hid the resolution
notice and allowed a move without an explicit no-work decision. V111 requires
a separate no-work checkbox before changing date/period/crew on a past unreported
assignment. Without confirmation, Save writes neither placement nor staffing and
shows the decision inside the dialog. Report Work is available directly there.
Planned staffing-only corrections retain their independent meaning and do not
require declaring no work. Past unreported group/day/cell drops also require
explicit no-work confirmation. Existing guarded Report Work/move/history and
080 INSERT enforcement remain unchanged.

Board cards now display Task numbers. Existing-edit mode and original date,
period, crew/Captain are explicit. Tests exercise past movement detection and
submit refusal/approval, report action and unchanged staffing-only route.
986 application tests and syntax checks PASS. No Production changes.

Retest exact V111 SHA using the same080 migration and validation paths in the
existing disposable wrapper. Open Task184's existing past assignment; change date
and attempt Save without checking no-work: no write must occur. Confirm no-work
and test movement of that same occurrence, not insertion of another. Test direct
Report Work, staffing-only changes, and drag/drop confirmation. Verify original
actual history remains protected. Then CLEAN EXIT for separate Production gate.

## V111 checkbox presentation follow-up

Operator confirmed moving the November6 Task184 occurrence to November11.
November7 remains a separate unresolved occurrence; moving the first must not
fabricate a report or erase the second. If no work happened November7, explicitly
unschedule that occurrence rather than moving it alongside November11.
The no-work label now aligns a 24px checkbox with its statement, a 44px minimum
clickable label, and scoped rules overriding the generic stacked form layout.
Asset revision111.1; runtime remains V0.3.111-explicit-no-work. Browser acceptance
of this presentation adjustment is pending. Production unchanged.

## V111 scope presentation follow-up (asset111.2)

Greg completed CLEAN EXIT and corrected Task184 in Production independently.
Do not undo those corrections for testing. Perform Work collapsed cards and
past-assignment summaries now show annual Stage key/name and Scene, with explicit
Stage-level or Site-wide fallback, using owning task scope rather than the
assignment projection alone. Regression covers both renderers and escaped names.
The read-only setup_205_duplicate_unreported_readonly_audit.sql identifies unfinished
2026 tasks with at least two unmatched assignments, ordered by task/date/assignment.
Current results must be supplied from Production or a fresh clone; no replacement
duplicate has yet been confirmed. Existing historical audit is not current proof.
Presentation only: retain V0.3.111-explicit-no-work; no Production changes.

Validation: 986 application tests PASS; Node syntax PASS; audit SQL parser PASS.
Real audit results and exact-candidate browser acceptance remain pending.

## V111 NOT READY inspection follow-up (asset111.3)

Operator accepted task scope display after refreshing the browser on89c8afe.
The Action Center's nine NOT READY tasks had a count but no full matching list.
The count now opens/focuses a Tasks marked NOT READY section derived directly
from k.notReady, including unscheduled work outside the upcoming seven days.
Rows identify Task/Annual Task, Stage/Scene, readiness reason and existing
guarded Review readiness action. No new writes or notifications.
Executable regression verifies count/list membership, unscheduled scope and
opening/focusing without navigating away. 986 application tests and Node syntax
PASS. Presentation/navigation only; retain V0.3.111-explicit-no-work.
Exact new candidate browser acceptance pending; Production remains unchanged.
Operator reports the read-only duplicate audit returned zero rows after their
Production corrections; this is not proof of attempted INSERT rejection.
Recurring retained browser code after updates remains a separate follow-up.

## V111 complete outstanding inventory (asset111.4)

Operator confirmed NOT READY inspection is useful and supplied full Action Center
text. Task numbers were missing in other action sections and the exceptions did
not enumerate every remaining task. Added All outstanding tasks from k.incomplete,
once per annual task, including future-scheduled and deferred work. Rows show
identity, Stage/Scene, execution/scheduling/readiness state, blocker reasons,
readiness note and existing guarded planning action. Added task identity throughout
assignment, continuation and overloaded-shift task lists. No stored flags/reports
changed based on apparently satisfied notes. Regression covers full inventory,
scheduled/partial/deferred inclusion and completed exclusion. 986 tests and Node
syntax PASS. Retain presentation-only V0.3.111-explicit-no-work. New exact source
requires browser acceptance and CLEAN EXIT; no Production changes.
