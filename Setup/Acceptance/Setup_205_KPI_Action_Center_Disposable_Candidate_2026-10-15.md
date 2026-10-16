# #205 Whole-Setup KPI / Action Center / Report Work — Browser Candidate

| Item | Value |
|---|---|
| Status | CORRECTED SOURCE REGRESSION PASS — BROWSER REJECTED (HTTP 500) / REPEAT PENDING |
| Governing | #122 / #205, controlled Setup engineering contract |
| Candidate branch | `fix/205-setup-deadline-kpis-20261015` |
| App build | `V0.3.67-setup-action-center` — client/server synchronized; corrected HTTP 500 |
| Exact browser/acceptance candidate | `dbf4487ac7b94ced7dd5d2f8fd9cb5f69457ee8c` — SQL bind correction, distinct synchronized version and pre-ready API check |
| Previous rejected application implementation SHA | `e4ed6ff13d6e16e9d8a6ed5278c1d81ee2d00eaa` (V0.3.66, HTTP 500) |
| Latest upstream integrated | `main b2d5f8c2f202b228a180bd950187718937c41019` |
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

At the original feature source `e4ed6ff13d6e16e9d8a6ed5278c1d81ee2d00eaa`, [GitHub Actions run 38831054784](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38831054784) passed:
- 779 Setup/Application Python;
- 202 FieldWiring/Application Python;
- shared #205 executable Node KPI and Manager Action Center cases, including task overlap, undated/future work dates, cancelled days, overcapacity, deadline passage, missing report, archived/hidden day reveal, guarded navigation and no notification controls.

These are source regressions. No clone or browser result can be inferred from them.

## October 15/16 exact-candidate acceptance failure and repaired test

The laptop browser review on the exact older `e4ed6ff13d6e16e9d8a6ed5278c1d81ee2d00eaa` candidate stopped in `Setup/Acceptance/test_setup_gis_preview.py`. Its real GIS/FieldWiring routing assertions succeeded up to an obsolete Setup health check hard-coded to `V0.3.65-scheduled-search-focus`; the preview intentionally serves `V0.3.66-setup-action-center`. This is **not** a database migration failure, nor proof of a broken park map. The runner explicitly executes the pinned candidate's `Setup/Application` tests **plus** `Setup/Acceptance/test_setup_gis_preview.py`, whereas the earlier source CI exercised only `Setup/Application`. The stale assertion therefore escaped CI.

The repaired acceptance test now imports `PRODUCTION_VERSION` from the same candidate's `production_backend` and compares the protected Setup health endpoint against that runtime identity; it preserves every GIS/FieldWiring route, version, isolation and disallowed-POST check. The CI workflow now includes that acceptance test in its full Setup job. [Actions #38838749001](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38838749001) **PASS** at new exact candidate `aaf7778c73f09a851db1f12abbe77770b09d5182`: **785 Setup (including GIS preview), 202 FieldWiring, Node #205 checks**. No GIS/application source file or schema changed; build stays `V0.3.66-setup-action-center`.

The failed preview report `/home/msbadmin/setup-acceptance-reports/Setup_Disposable_Browser_Preview_20261016T020328.txt` shows **Production Setup fingerprint unchanged** `419a9534bb446e2776008dfdcf3bcda1`, installed Setup SHA unchanged `86341d49dc8ccf290575f9d2b418c235094a1377`, preview cleanup completed, and runner exit 1. It did NOT print `BROWSER REVIEW READY` or `CLEAN EXIT`. Preserve that failure receipt.

Greg reports two recent migrations in other workstreams, which are **not disputed**. This #205 candidate supplies **zero additional migration files**, and a governed disposable current-Production clone starts with whichever previously accepted migrations really exist in current Production. Do not reapply, undo or guess the identities of those earlier migrations.

**Historical retest instruction (superseded by the HTTP 500 correction above):** formerly used `aaf7778c73f09a851db1f12abbe77770b09d5182` for **both** disposable acceptance and browser preview, per governing acceptance runbook; do not use the old SHA with newer branch tooling or skip final operator browser/CLEAN EXIT. The same existing laptop worktree can be fast-forwarded and reused; no new worktree, reset, Production mutation or GIS changes.

## October 15/16 browser HTTP 500 — root cause proven and corrected (LATEST)

The browser preview at `/tmp/Setup_Disposable_Browser_Preview_Flask_20261016T021107.log` loaded the V0.3.66 assets but the real GET `/api/setup/scheduling-board?season_year=2026` returned 500. The **actual server traceback** was `IndexError: tuple index out of range` from psycopg2 at `setup_scheduling_board_repository.py` line 146, in the **parameterized annual-task board SELECT**. The statement was introduced with the SQL comment `/* Current 100% work evidence, one date per annual task. */`. psycopg2 inspects percent markers (including those in SQL comments) before sending SQL to PostgreSQL; the bare `%` consumed an extra bind specifier with only a single session-ID parameter. This is a proven application-code defect, **not** a need for an additional migration or correction to data. The earlier complete 2026 workday information remained unavailable only because the full board GET failed.

**Corrections on PR #394:** remove the raw SQL percent marker in the comment, without altering intended 100%-progress query semantics; add regression that verifies the actual annual-query bind placeholders and every parameterized board SQL; choose new visibly distinct `V0.3.67-setup-action-center` with synchronized server/client/build/asset pins; extend the existing disposable Setup preview runner with a **read-only 2026 Scheduling Board GET** against the cloned database **before** printing `BROWSER REVIEW READY`. The new check fails with captured Flask traceback on any 500, avoiding another operator entering a broken scheduling screen. GIS, mail, current workday source and database migrations are untouched.

**Test evidence:** [CI #38840185514](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38840185514) PASS, **790 Setup** (including executable GIS preview, parameterized query and fail-before-READY parser checks), **202 FieldWiring**, both #205 executable Node regressions. Exact candidate `dbf4487ac7b94ced7dd5d2f8fd9cb5f69457ee8c`. Source test success does **not** establish live-clone SELECT success; the new acceptance/browser cycle must prove it.

**Operator acceptance:** the ongoing original 8898 browser session is **REJECTED**, irrespective of whether its eventual cleanup reports `CLEAN EXIT`. Preserve its original server error log and review report. Complete governed existing preview cleanup and Production-after fingerprint check **before** opening another disposable session. Then fast-forward the existing **laptop** worktree only; use `dbf4487ac7b94ced7dd5d2f8fd9cb5f69457ee8c` as `-CandidateSha` for both reusable current-Production disposable acceptance and 8898 browser preview, `-ExpectedVersion 'V0.3.67-setup-action-center'`, `-MigrationPaths @()`. The feature supplies **zero NEW migrations**; don't replay or undo the separate real recent installed migrations. No Production release, no GIS or mail work.

## Governed disposable acceptance and browser review

Owner/authority: `Gregovate/MSB-Server-Management`:
`docs/server/PostgreSQL_Disposable_Acceptance_Standard.md`,
`docs/server/Pre_Production_Browser_Review_Runbook.md`,
`docs/server/Application_and_Test_Port_Register.md` (Setup `8898`).

The *operator's clean checkout of this exact branch* must contain the final candidate SHA; stop if dirty, a different branch, or 8898 belongs to an unknown preview. Source-only: no migrations; use the current Production copy. The candidate may advance only through controlled acceptance reruns.

```powershell
# Run only in the actual clean target branch checkout. Do not switch an
# unrelated checkout or alter other active worktrees.
$sha = 'dbf4487ac7b94ced7dd5d2f8fd9cb5f69457ee8c'
$ref = 'fix/205-setup-deadline-kpis-20261015'
.\Setup\Acceptance\run_setup_disposable_acceptance.ps1 `
    -CandidateSha $sha -TargetRef $ref -MigrationPaths @() -ValidationPaths @()

# Only after the preceding disposable gate prints PASS:
.\Setup\Acceptance\run_setup_disposable_browser_preview.ps1 `
    -PreviewPort 8898 -CandidateSha $sha -TargetRef $ref `
    -ExpectedVersion 'V0.3.67-setup-action-center' `
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
10. Hard refresh/stale-tab navigation and client/server build guard. Both screens show `V0.3.67`; footer `Updated 2026-10-15`; no email controls, no GIS or People regression.

## Hard stop

If live-clone classification mismatches, the source is not accepted. Fix source, commit and redo full regression + clone + browser at new exact SHA. Do not directly edit Production data, issue Manager email or deploy merely because GitHub CI passed.

Production release under #122 is a **separate explicit approval** after current-clone/browser and Clean Exit. Document report SHA, fingerprints, operator outcome and accepted source before requesting installation.

## Laptop worktree handoff — safe after an interrupted `origin/main` fetch

The authoritative laptop checkout is `C:\lor\ImportExport\VSCode` (Repository Change Workflow). **Never run `git pull` in that dirty primary checkout** to test a feature. An ordinary `git fetch origin --prune` may race a VS Code auto-fetch on `origin/main`; the `cannot lock ref` incident of October 15 returned current `origin/main` SHA `b2d5f8c2`. Treat it as concurrent reference movement, not evidence of corrupt Git. Do not delete lock files, prune worktrees, reset branches, or assume the terminal's unguarded `PASS` line is truthful.

The feature branch was reconciled with the new `main` documentation by additive two-parent merge `70aa51b9b40eb6aa5409a28277e664a2cb01a122`, preserving application source `dbf4487ac7b94ced7dd5d2f8fd9cb5f69457ee8c` and `V0.3.67-setup-action-center`. Use a **single** copy/paste PowerShell script block; PowerShell's `elseif` may not execute correctly if pasted as a separate interactive statement. Check all status codes before any further step.

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $primary = 'C:\lor\ImportExport\VSCode'
    $review = 'C:\lor\ImportExport\VSCode-205-kpi-review'
    $branch = 'fix/205-setup-deadline-kpis-20261015'
    $candidate = 'dbf4487ac7b94ced7dd5d2f8fd9cb5f69457ee8c'
    $version = 'V0.3.67-setup-action-center'

    Set-Location $primary
    $url = (& git remote get-url origin).Trim()
    if ($LASTEXITCODE -ne 0 -or $url -notmatch 'Gregovate/MSB-Production-Database-Project(\.git)?$') {
        throw 'STOP: laptop checkout is not the expected MSB repository.'
    }
    & git status --short
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect the existing checkout.' }
    & git worktree list
    if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect other worktrees.' }
    if (Test-Path -LiteralPath $review) { throw "STOP: review path exists: $review" }

    # Fetch exactly this PR's branch. Do not touch the contested origin/main ref.
    & git fetch origin "refs/heads/${branch}:refs/remotes/origin/${branch}"
    if ($LASTEXITCODE -ne 0) { throw 'STOP: targeted feature fetch failed.' }
    & git show-ref --verify --quiet "refs/heads/$branch"
    $localBranchState = $LASTEXITCODE
    if ($localBranchState -notin @(0,1)) { throw 'Cannot inspect local branch.' }
    if ($localBranchState -eq 0) { & git worktree add $review $branch }
    if ($localBranchState -eq 1) { & git worktree add -b $branch $review "origin/$branch" }
    if ($LASTEXITCODE -ne 0) { throw 'STOP: worktree creation failed.' }

    Set-Location $review
    & git pull --ff-only origin $branch
    if ($LASTEXITCODE -ne 0) { throw 'STOP: review branch cannot fast-forward.' }
    & git merge-base --is-ancestor $candidate HEAD
    if ($LASTEXITCODE -ne 0) { throw 'STOP: candidate SHA missing from review branch.' }
    & git merge-base --is-ancestor origin/main HEAD
    if ($LASTEXITCODE -ne 0) { throw 'STOP: branch does not include currently fetched main.' }
    $modifiedApp = @( & git diff --name-only $candidate HEAD -- Setup/Application Setup/Database )
    if ($LASTEXITCODE -ne 0 -or $modifiedApp.Count) { throw 'STOP: application/database changed after pinned candidate.' }
    $dirty = @( & git status --porcelain )
    if ($LASTEXITCODE -ne 0 -or $dirty.Count) { throw 'STOP: review worktree is not clean.' }
    Write-Host 'PASS: clean isolated #205 laptop worktree, exact candidate and current-main ancestry.'

    & .\Setup\Acceptance\run_setup_disposable_acceptance.ps1 `
        -CandidateSha $candidate -TargetRef $branch -MigrationPaths @() -ValidationPaths @()
    if (-not $?) { throw 'STOP: disposable acceptance failed.' }

    & .\Setup\Acceptance\run_setup_disposable_browser_preview.ps1 `
        -PreviewPort 8898 -CandidateSha $candidate -TargetRef $branch `
        -ExpectedVersion $version -MigrationPaths @()
    if (-not $?) { throw 'STOP: browser review failed; preserve evidence.' }
}
```

Wait for `SETUP REUSABLE DISPOSABLE BROWSER REVIEW READY` before visiting `http://127.0.0.1:8898/`. Keep that PowerShell session in the foreground; finish operator review, then press Enter to permit governed cleanup. Obtain actual `CLEAN EXIT`. No Production approval/deploy is implied.

Only after confirmed CLEAN EXIT, optional *local* review worktree cleanup. Keep primary checkout and active PR branch intact:

```powershell
& {
    $ErrorActionPreference = 'Stop'
    Set-Location 'C:\lor\ImportExport\VSCode'
    $review = 'C:\lor\ImportExport\VSCode-205-kpi-review'
    if (-not (Test-Path -LiteralPath $review)) { throw 'Review worktree missing.' }
    $dirty = @( & git -C $review status --porcelain )
    if ($LASTEXITCODE -ne 0 -or $dirty.Count) { throw 'STOP: review worktree has changes.' }
    & git worktree remove $review
    if ($LASTEXITCODE -ne 0) { throw 'STOP: worktree removal failed.' }
    & git worktree list
}
```

No force-delete, no ref reset, no pulling Production/feature into the dirty laptop primary checkout. If Git reports the branch already checked out in another worktree, stop and inspect ownership rather than forcing a second checkout.
