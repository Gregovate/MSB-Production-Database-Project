# #205 Whole-Setup KPI / Action Center / Report Work — Browser Candidate

| Item | Value |
|---|---|
| Status | SOURCE REGRESSION PASS — CURRENT-PRODUCTION CLONE/BROWSER REVIEW NOT PERFORMED |
| Governing | #122 / #205, controlled Setup engineering contract |
| Candidate branch | `fix/205-setup-deadline-kpis-20261015` |
| App build | `V0.3.66-setup-action-center` — client/server synchronized |
| Application source checkpoint | `e4ed6ff13d6e16e9d8a6ed5278c1d81ee2d00eaa` |
| Latest upstream integrated | `main c63eb5c118ef65bbb80ff72ecc7b283087d5b3d8` |
| Database migrations in this candidate | **NONE**; notification 074 is on a separate parked branch |
| Production | UNCHANGED; no authorization requested |
| GIS / People | Preserved; no unrelated subsystem mutation |

## Corrected scope

- Plan/Schedule and Perform Work both prioritize full Setup Total / effectively Completed / Remaining, actionable blocked, past unreported occurrences, distinct recent physical-work completions per day, required calendar and possible non-Sunday workday pace, hard November 19 deadline and qualified task-count forecast.
- The shared classifier is independent of Captain filter, de-duplicates annual tasks, and does not use late `recorded_at` as the physical completion date.
- Manager Action Center has direct guarded actions to inspect original report history, schedule unfinished continuations, review annual blockers, focus a workday, inspect near-term Captain TBD, and inspect next-seven-day linear-hour crew/shift overload.
- Completed annual tasks with an earlier unreported original occurrence direct to history/Manager correction review; do not create a duplicate report or pretend a completed annual task can be reopened.
- Report Work labels actual date, actual crew, hours/minutes and cumulative whole-task percent, and confirms **both** scheduled and actual work date before saving while preserving the form on cancel.
- Day filters clarify they are **Days needing reports** or **Fully reported days**, not a per-task hide-completed filter.
- **All Directus mail work is paused**: parked on `hold/205-directus-notifications-20261015`. No notification endpoints, migration 074, sender, job, Flow or email-preview interface are in this candidate.

## Source regression — PASS

At `e4ed6ff13d6e16e9d8a6ed5278c1d81ee2d00eaa`, [GitHub Actions run 38831054784](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38831054784) passed:
- 779 Setup/Application Python;
- 202 FieldWiring/Application Python;
- shared #205 executable Node KPI and Manager Action Center cases, including task overlap, undated/future work dates, cancelled days, overcapacity, deadline passage, missing report, archived/hidden day reveal, guarded navigation and no notification controls.

These are source regressions. No clone or browser result can be inferred from them.

## Governed disposable acceptance and browser review

Owner/authority: `Gregovate/MSB-Server-Management`:
`docs/server/PostgreSQL_Disposable_Acceptance_Standard.md`,
`docs/server/Pre_Production_Browser_Review_Runbook.md`,
`docs/server/Application_and_Test_Port_Register.md` (Setup `8898`).

The *operator's clean checkout of this exact branch* must contain the final candidate SHA; stop if dirty, a different branch, or 8898 belongs to an unknown preview. Source-only: no migrations; use the current Production copy. The candidate may advance only through controlled acceptance reruns.

```powershell
# Run only in the actual clean target branch checkout. Do not switch an
# unrelated checkout or alter other active worktrees.
$sha = 'e4ed6ff13d6e16e9d8a6ed5278c1d81ee2d00eaa'
$ref = 'fix/205-setup-deadline-kpis-20261015'
.\Setup\Acceptance\run_setup_disposable_acceptance.ps1 `
    -CandidateSha $sha -TargetRef $ref -MigrationPaths @() -ValidationPaths @()

# Only after the preceding disposable gate prints PASS:
.\Setup\Acceptance\run_setup_disposable_browser_preview.ps1 `
    -PreviewPort 8898 -CandidateSha $sha -TargetRef $ref `
    -ExpectedVersion 'V0.3.66-setup-action-center' `
    -MigrationPaths @()
```

**Do not open** `http://127.0.0.1:8898/` until `BROWSER REVIEW READY` is printed. Do not call acceptance complete without the operator's review, safe cleanup, fingerprint/source-after checks and `CLEAN EXIT`.

## Required browser/operator checklist

1. Whole-Setup annual task total, effective completed, remaining, excluded deferred and scheduled task counts match independent cloned data; compare old 63 to later 72 completion observation at ID/date level, not assuming either is current.
2. In-progress tasks lacking genuine current/future continuation match row-level data; investigate previously observed 12 UI vs 13 query discrepancy, not just a screenshot.
3. Past historical original missing reports remain visible when work is later rescheduled or the annual task is finished. No false alarm for partial/100%-reported occurrence, cancelled day, or a future assignment.
4. Manager blocker details name actual hard prerequisite, linked Work Order number and independently NOT READY reason; navigation opens the correct existing planning edit, including scheduled blocked tasks.
5. From Plan/Schedule and Perform Work, click missing report → original Setup Day, Crew, AM/PM and named task. Verify collapsed day expands, Captain scope is not hiding it, and actual Report Work/Progress History opens; completed annual tasks show history/correction rather than false new report.
6. In-progress 90% remains unfinished; Plan continuation opens actual Scheduler with correct annual task, does not move or erase historical work.
7. Explicit actual date and scheduled date confirmation, cancel preserving values, minutes distinct from hours, and Manager Correct report of an existing wrong-date report (including completed annual task); field device/mobile width and iPhone Safari date picker.
8. Upcoming near-term overloaded shifts show accurate linear duration vs 3h AM / 2h PM / 5h All Day, and click opens correct day. Captain TBD shown only as relevant current/future work.
9. Verify 2026 Nov 19 hard deadline and Chicago/day/Sunday/zero-sample/past-deadline labeling. Labor remains secondary; no fabricated on-track status.
10. Hard refresh/stale-tab navigation and client/server build guard. Both screens show `V0.3.66`; footer `Updated 2026-10-15`; no email controls, no GIS or People regression.

## Hard stop

If live-clone classification mismatches, the source is not accepted. Fix source, commit and redo full regression + clone + browser at new exact SHA. Do not directly edit Production data, issue Manager email or deploy merely because GitHub CI passed.

Production release under #122 is a **separate explicit approval** after current-clone/browser and Clean Exit. Document report SHA, fingerprints, operator outcome and accepted source before requesting installation.

## Worktree-first desktop PowerShell execution (operator handoff)

These are the missing complete operator steps required by the repository Worktree Change Workflow. They preserve other worktrees and uncommitted changes and consume the same reusable Server Management disposable/browser runbooks above. The app candidate stays pinned at `e4ed6ff13d6e16e9d8a6ed5278c1d81ee2d00eaa`; later docs/tooling on the target branch are permitted only when no affected application/database content differs.

```powershell
$ErrorActionPreference = 'Stop'
$primary = 'C:\Users\Greg\Github\MSB-Production-Database-Project'
$worktree = 'C:\Users\Greg\Github\MSB-Production-Database-Project-205-kpi-review'
$branch = 'fix/205-setup-deadline-kpis-20261015'
$candidate = 'e4ed6ff13d6e16e9d8a6ed5278c1d81ee2d00eaa'
$version = 'V0.3.66-setup-action-center'

Set-Location $primary
& git worktree list
if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect worktrees.' }
& git fetch origin --prune
if ($LASTEXITCODE -ne 0) { throw 'Git fetch failed.' }
if (Test-Path -LiteralPath $worktree) { throw "Worktree path already exists: $worktree" }
& git show-ref --verify --quiet "refs/heads/$branch"
if ($LASTEXITCODE -eq 0) {
    & git worktree add $worktree $branch
} elseif ($LASTEXITCODE -eq 1) {
    & git worktree add -b $branch $worktree "origin/$branch"
} else { throw 'Failed to inspect local feature branch.' }
if ($LASTEXITCODE -ne 0) { throw 'Worktree creation failed; stop.' }
Set-Location $worktree
& git pull --ff-only origin $branch
if ($LASTEXITCODE -ne 0) { throw 'Feature branch did not fast-forward; stop.' }
& git merge-base --is-ancestor $candidate HEAD
if ($LASTEXITCODE -ne 0) { throw 'Pinned application candidate is not an ancestor; stop.' }
& git merge-base --is-ancestor origin/main HEAD
if ($LASTEXITCODE -ne 0) { throw 'Target branch does not include updated main; stop.' }
$changedApp = @(git diff --name-only $candidate HEAD -- Setup/Application Setup/Database)
if ($LASTEXITCODE -ne 0 -or $changedApp.Count) { throw 'Application/database changed after pinned candidate; stop and repin.' }
$dirty = @(git status --porcelain)
if ($LASTEXITCODE -ne 0 -or $dirty.Count) { throw 'Worktree not clean; stop.' }

.\Setup\Acceptance\run_setup_disposable_acceptance.ps1 `
    -CandidateSha $candidate -TargetRef $branch `
    -MigrationPaths @() -ValidationPaths @()
if (-not $?) { throw 'Disposable acceptance failed; do not launch browser review.' }

.\Setup\Acceptance\run_setup_disposable_browser_preview.ps1 `
    -PreviewPort 8898 -CandidateSha $candidate -TargetRef $branch `
    -ExpectedVersion $version -MigrationPaths @()
if (-not $?) { throw 'Browser preview failed; preserve report, do not deploy.' }
```

Wait for `SETUP REUSABLE DISPOSABLE BROWSER REVIEW READY`; only then open `http://127.0.0.1:8898/` and perform the checklist above. Keep the original PowerShell session open. Press ENTER when done to invoke governed cleanup; record a **CLEAN EXIT** and operator outcome. Production deployment is never part of these steps.

After CLEAN EXIT, optional local worktree cleanup (do not delete the open PR's local branch):

```powershell
Set-Location 'C:\Users\Greg\Github\MSB-Production-Database-Project'
$worktree = 'C:\Users\Greg\Github\MSB-Production-Database-Project-205-kpi-review'
if (-not (Test-Path -LiteralPath $worktree)) { throw 'Expected worktree does not exist.' }
$dirty = @(git -C $worktree status --porcelain)
if ($LASTEXITCODE -ne 0 -or $dirty.Count) { throw 'Review worktree is not clean; do not remove.' }
& git worktree remove $worktree
if ($LASTEXITCODE -ne 0) { throw 'Worktree removal failed.' }
& git worktree list
```

An unexpected listener, SSH error, dirty checkout, missing `BROWSER REVIEW READY`, or missing `CLEAN EXIT` is a **STOP**. Do not force-remove any server or worktree resources, or infer acceptance from a successful source-only CI run.
