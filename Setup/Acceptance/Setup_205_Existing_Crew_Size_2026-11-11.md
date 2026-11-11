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
