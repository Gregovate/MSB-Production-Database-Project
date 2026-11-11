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
