# Completed-task follow-up correction — November 3, 2026

Owner: #205 under #122. Status: source-tested candidate; protected current-clone
browser/operator acceptance and Production release pending.
Build: `V0.3.104-completed-task-followup`.
Branch: `fix/205-completed-task-late-warnings`.
Base main: `0506d4bbd6a21931e0fcc45a84bf63bc31e96975`.

[Design authority](../../Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/Setup_205_Schedule_Performance_and_Daily_Accountability_Contract_2026-10-15.md#november-3-correction--completed-tasks-leave-active-missing-report-queues).

## Evidence and scope

Greg supplied 11 missing-match assignments across 10 tasks. Completed tasks 436,
424 and 422 account for assignments 332, 286, 317 and 243. Greg confirms task 424
is complete and the remaining power-cord problem is a separate Setup Work Order.
The candidate removes these four from active follow-up without deleting or
modifying any assignment, progress, labor or completion record. Seven remain:
304/348/347/308 with task progress, and 341/350/309 with no task reports.
These are dated operator evidence and regression fixtures, not a fresh live count.

Shared browser classification covers Perform Work, Plan/Schedule, Action Center,
day state, default active-card filters and outstanding shift capacity. Completed
history remains available through history toggles, scheduled search and original
links. Partial-task warnings identify the scheduled assignment needing review
and show task progress. Annual completion wins even when a report's performed
date sorts differently from its entry date; maximum percent alone never closes
reopened work. Existing mail content classifier uses the same rule in HTML/text.
No schema migration, database repair, SMTP, timer, recipient or receipt changes.

## Source verification

- Full Setup/Application + Setup/Acceptance: **1215 passed, 8 skipped** (optional
  environment-dependent checks). Full history was fetched for pinned historical
  deployment-tool fixtures before the passing run.
- FieldWiring/Application + Procedures/Application: **286 passed**.
- All ten executable #205 Node suites listed in the existing source workflow pass.
- New executable eleven-assignment classifier/rendering test runs from pytest.
- Mail test proves 11 -> 7, completed tasks absent from both formats, four partial
  percentages present, three no-report rows, and unchanged inputs.
- JavaScript syntax and `git diff --check` pass.

These checks do not establish current-Production-clone or operator acceptance.

## Protected browser review

Reuse `run_setup_disposable_browser_preview.ps1`, port 8898, exact published
candidate SHA, this branch as TargetRef and the build above. No migration paths
are needed. Preserve existing worktrees and confirm the prior preview is closed.
The runner owns clone creation, production fingerprints, local tunnel, read-only
notification preview and CLEAN EXIT; do not substitute an independent server.

Review in the same clone:
1. Perform Work and Manager Action Center: completed John's Tree, both Sledders
   entries and Glistening Grove no longer appear as late/report obligations.
2. Remaining partial rows show 85/75/50/10% and the specific original date/crew;
   report-free rows retain no-work-reported wording. Recompute live-clone counts
   if work has changed since Greg's query; do not force a historical count.
3. Show completed/history and scheduled search still reveal original assignments
   and work history. No duplicate work report or correction is needed.
4. Schedule day filters and shift workload exclude completed tasks; recorded
   labor and actual report counts stay unchanged. Check light/dark laptop layout.
5. Protected no-send Manager Brief preview agrees with the on-screen worklist,
   contains current Container/Display sections unchanged, and original links work.
6. Record operator verdict and runner CLEAN EXIT before release preparation.

## Production boundary and next gate

This is an application **and private Manager Brief content** update. Deploying
only Setup would leave the installed daily sender stale. Reuse Server Management
`docs/server/Setup_Manager_Brief_Release_2026-11-01.md` and its existing digest
installer under the source-only/mail-update runbooks, with a newly reviewed exact
candidate manifest and fresh baseline after acceptance. The old November 1
package is pinned to V0.3.103 and must not be rerun for this candidate. Separate
Production approval, merged ancestry, exact-source promotion, no-send preview,
receipt preservation and controlled deployment closeout remain required.
