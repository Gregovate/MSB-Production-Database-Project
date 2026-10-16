# #205 Whole-Setup KPI / Action Center / Report Work — Browser Candidate

## CURRENT V0.3.76 — six operator corrections in ONE #205 disposable browser review

**Source PASS / operator browser acceptance PENDING.** Exact candidate `f4279c1fb850c682623242b361ce7472ef35ab5f`, build `V0.3.76-operator-review-fixes`, existing draft PR #394, [GitHub CI #38925934280](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38925934280): **838 Setup Python, FieldWiring full, #205 Node checks PASS**. This candidate follows the operator-rejected V0.3.75 browser preview, which may still be open. **Obtain previous CLEAN EXIT before launching another protected preview; do not force-stop a separate live process or open two clones.** No Production mutation authorized.

Test **all findings together** in the ONE governed disposable current-Production clone and same port 8898, with migrations **075** and **076**, plus their two rollback-only validations:
- D16 Crew A count AM 3 / PM 2 auto-saves, survives refresh, and changes shift, day staffing AND task-card planned crew/labor text without losing other unsaved inputs. Task count/known hours on active scheduling are only for unfinished assignments (historical reported tasks excluded); 6h expected task may continue past AM to PM with actual partial reporting, without artificial Manager decision. Exact actual work remains protected.
- Mega Cube Planning Info: min 7/max 4 should show inline validation (no SQL alert or trapped form); correct range and save explicitly. **Open Full Reusable Task** must navigate without blindly saving invalid Planning Info and hand unsaved edits to the Catalog form for deliberate review. Test both directions of 2026 Catalog/annual planning estimate sync, including corrections on reported tasks; preserve actual reports and readiness history.
- Perform Work document scroll and fixed Back to top / Navigation button; Task Feedback and actual Number of Volunteers/Hours/Minutes/help.
- Manager Action Center tab is active ONLY when actually selected; verify light/dark Action Center links/buttons.
- Kit Inventory now has persistent top Setup nav links (Catalog, Plan, Perform, Manager Action Center) and Back to Setup. Verify navigation to all views and the back path.
- Same-Captain past/no-work reschedule to any valid future day including Oct 20 (prior omission; no false dates or arbitrary captain), saved update visible immediately, original move audit/real reports preserved; Plan/Schedule sticky header, lane colors and day separation at desktop widths.

**The previous V0.3.75 current-Production clone is NOT reusable after its CLEAN EXIT; the new launcher creates ONE fresh current-Production disposable clone** and runs both validations before browser. Launch only from the clean, fast-forwarded *existing* desktop review worktree `C:\Users\Greg\Github\MSB-Production-Database-Project-205-review` (NOT primary checkout), checked on branch `fix/205-setup-deadline-kpis-20261015`. Registered port 8898 must be free of prior preview. Read governing Server Management runbook/port authority before starting.

```powershell
.\Setup\Acceptance\run_setup_disposable_browser_preview.ps1 `
    -PreviewPort 8898 `
    -CandidateSha 'f4279c1fb850c682623242b361ce7472ef35ab5f' `
    -TargetRef 'fix/205-setup-deadline-kpis-20261015' `
    -ExpectedVersion 'V0.3.76-operator-review-fixes' `
    -MigrationPaths @(
        'Setup/Database/075_allow_setup_planned_crew_count_corrections.sql',
        'Setup/Database/076_capture_2026_reusable_task_estimates.sql'
    ) `
    -ValidationPaths @(
        'Setup/Acceptance/setup_205_planned_crew_count_disposable_validation.sql',
        'Setup/Acceptance/setup_205_2026_catalog_estimate_disposable_validation.sql'
    )
```

**Stop gate:** Failed source regression, migration, SQL validation, unknown port ownership, or bad fingerprint blocks the browser. On `BROWSER REVIEW READY`, inspect and explicitly report operator pass/fail; preserve `CLEAN EXIT` evidence. PR stays DRAFT, Production unchanged, notifications parked. Avoid archived earlier candidate commands below.

---


## ARCHIVED V0.3.75 integrated browser review — operator REJECTED (DO NOT RUN)


### October 16 14:17 validation parse error — corrected before retest

The previous disposable run exited status 3 before browser startup because a PL/pgSQL record was named `current_catalog` (PostgreSQL reserved keyword), producing a syntax error near `current_catalog.task_name`. The annual-to-Catalog check had passed. Cleanup succeeded and Production fingerprint and live Setup SHA were unchanged. The corrected SQL uses `v_catalog_row`, and a new regression test protects this name. Source CI [38915030375](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38915030375) PASS: **832 Setup Python, #205 Node, FieldWiring**. This is a disposable-validation-only fix; client/server version remains V0.3.75. Office desktop review checkout: `C:\Users\Greg\Github\MSB-Production-Database-Project-205-review`. Run exactly the single updated command below from that clean and refreshed worktree. No separate clone/test or Production mutation.

**SOURCE REGRESSION PASS; DISPOSABLE MIGRATION AND OPERATOR BROWSER ACCEPTANCE PENDING.** This is the next test for the **original rejected #205 browser review**, including the October 16 two-way task estimate correction. Do NOT split it into another release, clone or thread. Draft [PR #394](https://github.com/Gregovate/MSB-Production-Database-Project/pull/394), source candidate `f2e5015b7ab905f390d3ed485c723389e13bcc75`, build `V0.3.75-2026-reported-sync`. [CI #38915030375](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38915030375) PASS **832 Setup Python, FieldWiring full, #205 executable Node tests**. All following source-only commits may update this handoff, but must not silently replace the pinned application SHA. Production unchanged.

**Included corrections to test together:**
1. Crew A D16/22 planned AM count can be changed after task-level actual work, shows **Saved**, and survives reload; existing actual Crew 1 / progress on assignments 84 and 143 remains untouched. Blank day-crew AM/PM is **no confirmed Captain-led shift**, not zero task-hours; planned 1 means Captain alone.
2. Task expected elapsed duration and displayed known task-hours do not disappear when a planned day-crew count is NULL; derived person-hours are TBD/partial without staffing. Retain mandatory task-level expected duration, normal crew minimum and effort entries before new scheduling; keep the existing reported-continuation exception.
3. **2026 TWO-WAY task estimate synchronization in the very same review:** Save normal crew min/max, duration and effort in **2026 Scheduling Board Planning Info** and verify the linked reusable Catalog record immediately matches; edit the same estimates via the **reusable Catalog editor** and verify 2026 annual Planning Info now matches. Repeat Catalog-to-annual and annual-to-Catalog on a **reported 2026 task** (in disposable data only); earlier reported crew, duration/progress, assignment and historical readiness stay unchanged. Test season-only isolation, future-year boundary and fail-closed atomic behavior. 2027 Catalog policy remains pending deliberate review.
4. The earlier rejected browser-feedback items stay in this test: the Manager Action Center **navigation** button and action row formatting in both themes; dominant scheduling pane and sticky day header with bounded independent scroll, stronger day boundaries and colored Crew A–D lanes; Report Work numeric volunteers and Hours/Minutes/help; late/no-report versus confirmed no-work Manager rescheduling, original date audit, and same-Captain future crew choice with no arbitrary Captain/TBD default. Where a future workday is missing, verify the app's existing Work Day creation boundary rather than falsely claiming automatic date creation. AM/PM shift pressure must distinguish unconfirmed staffing from proven available capacity.
5. No fake work reports, no archived/progress mutation, no changes to Production, and no emails from this launch candidate. Rejection on any item leaves #394 DRAFT.

**The existing reusable browser launcher makes ONE current-Production disposable PostgreSQL clone and runs source regression, BOTH migrations and BOTH rollback SQL validations before serving the same clone on port 8898. Do not invoke the separate disposable acceptance launcher.** Run only from a clean, fast-forwarded `C:\lor\ImportExport\VSCode-205-kpi-review` checkout on branch `fix/205-setup-deadline-kpis-20261015`; check the current Server Management Pre-Production Browser Review Runbook and port ownership before starting.

```powershell
.\Setup\Acceptance\run_setup_disposable_browser_preview.ps1 `
    -PreviewPort 8898 `
    -CandidateSha 'f2e5015b7ab905f390d3ed485c723389e13bcc75' `
    -TargetRef 'fix/205-setup-deadline-kpis-20261015' `
    -ExpectedVersion 'V0.3.75-2026-reported-sync' `
    -MigrationPaths @(
        'Setup/Database/075_allow_setup_planned_crew_count_corrections.sql',
        'Setup/Database/076_capture_2026_reusable_task_estimates.sql'
    ) `
    -ValidationPaths @(
        'Setup/Acceptance/setup_205_planned_crew_count_disposable_validation.sql',
        'Setup/Acceptance/setup_205_2026_catalog_estimate_disposable_validation.sql'
    )
```

**Hard gate:** The source-only CI does not establish SQL runtime success. If migration or validation fails, the runner must STOP without operator browser review and without Production writes; record the report and fix the *same PR*. Only open the review URL after `BROWSER REVIEW READY`; record the operator's integrated verdict and require `CLEAN EXIT`. Release needs separate #122 authorization and current Server Management PostgreSQL maintenance/rollback runbook. Nothing here authorizes a Production migration.

---


## ARCHIVED HOLD — V0.3.74 incomplete pre-V0.3.75 snapshot (DO NOT RUN)

**Engineering intent is now corrected and source work has begun; NOT a ready browser candidate.** Controlled authorities: Setup Planning Operating Model and #205 Scheduling Engineering Contract. During the **2026 launch only**, task-level planning estimates (normal crew min/max, expected duration, effort) must synchronize **both directions** between each linked reusable Catalog task and current 2026 annual task. Earlier one-way migration 076 design/checklist was incomplete. Keep mandatory task-estimate scheduling gate, separate nullable day-crew AM/PM counts, season-only isolation, task-level actual reports/history, and explicit 2027 review boundary.

Current implemented source commit `56fad8e15a606b2bad13ce9bc83793ba4863a3db`, build `V0.3.74-2026-catalog-sync`. GitHub [CI 38910656967](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38910656967) PASS **831 Setup Python, FieldWiring full and required #205 Node**. CI verifies source contracts and atomic Catalog UI Save; it does **not** execute live PostgreSQL migration/trigger behavior.

**Migrations in this candidate:** `Setup/Database/075_allow_setup_planned_crew_count_corrections.sql` (preserve actual work while letting day-crew planned headcounts change) and `Setup/Database/076_capture_2026_reusable_task_estimates.sql` (existing annual-to-Catalog command plus guarded Catalog-to-2026 annual trigger). **Disposable-only validations:** `Setup/Acceptance/setup_205_planned_crew_count_disposable_validation.sql` and `Setup/Acceptance/setup_205_2026_catalog_estimate_disposable_validation.sql` (both directions, rollback). These require governed ONE current-Production disposable clone, not a separate acceptance clone and browser clone. No Production migration is authorized.

**Open engineering acceptance boundary:** The Catalog-to-annual mirror currently rejects Catalog estimate edits when the linked 2026 annual task already has actual-work history; this preserves existing annual history safeguards but can conflict with the broad two-way 2026 learning workflow. Its behavior needs explicit reconciliation in the engineering design and disposable tests before any operator browser review. Do not claim unrestricted two-way sync, and do not give a live migration instruction as a workaround. Keep PR #394 DRAFT. Do **not** run older V0.3.73, V0.3.72 or V0.3.70 commands below; those are archived.

---


## ARCHIVED V0.3.73 source review — superseded by V0.3.74; DO NOT RUN

**Governing correction PASS (2026-10-16):** Greg rejected waiving mandatory task estimates. The exact earlier `board205RequireEstimates()` gate has been restored, including its existing locked-history continuation exception; day-crew AM/PM counts still distinguish NULL (not staffed as Captain-led crew) from 1 (Captain alone). Source/test commit `b2070faa5b71908fbf688af09b0468c66b8bdde8` passed [CI 38907841461](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38907841461): **826 Setup Python, #205 executable Node including restored blocking gate, and FieldWiring full**. This does **not** authorize reuse of the superseded SHA/command below or establish browser acceptance. PR is still draft; Production remains unchanged. A future browser candidate requires a new pinned source/version identity and current governed one-clone acceptance before operator testing.



**STOP / governing correction:** The previous handoff implied all task estimates could be omitted; that was never authorized. The test command and candidate SHA below describe a now-superseded source snapshot and **must not be used** for a new operator test. The existing `board205RequireEstimates()` mandatory gate was restored, with the original historical-continuation exception. Retest/re-pin a new exact SHA only after full regressions. Blank *day-crew AM/PM staffing* remains distinct from missing mandatory *task-level planning estimates*. Do not run any older archived handoff in this file.

**SOURCE REGRESSION PASS OF SUPERSEDED SHA; DISPOSABLE/BROWSER NOT ACCEPTED.** #122 governs #205; this remains existing draft PR #394. Exact source candidate SHA \`3bc3b6588b4fc1f8c350cbe7f064c1360e5a47cd\`; visible client/server build \`V0.3.73-optional-staffing-plan\`. [CI #38906299419](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38906299419) PASS **826 Setup Python, 202 FieldWiring Python, all required #205 Node checks including new nullable-staffing/task-duration executable**.

**Engineering authority:** [Setup Planning Operating Model](../../Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/Setup_Planning_Operating_Model_2026-09-08.md), then [#205 contract](../../Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/engineering/Setup_205_Schedule_Performance_and_Daily_Accountability_Contract_2026-10-15.md). A planned crew of 1 = Captain alone; NULL = no Captain-led crew confirmed that shift (Captain may be unavailable or join another crew). New crew counts frequently start NULL. Actual crew/hours are recorded individually in Report Work and remain protected. Task-estimate requirements remain mandatory for new work (with the existing historical-continuation exception); planned day-crew AM/PM counts may be NULL without losing independently known linear task-hours; and shows partial/TBD planned labor rather than misleading 0 labor. Known task-hour and staffing-coverage distinctions appear in board and Perform Work.

**Database boundary:** This candidate **still includes NEW migration 075**, the function-only Manager planned AM/PM count correction introduced in V0.3.72, and the corresponding rollback-protected Crew 22 disposable validation. It is NOT source-only. No schema/table/actual-work/history changes are authorized. Notification migration 074 remains parked. Execute both SQL paths **only against the governed disposable current-Production clone**, not Production. Database-changing release requires later explicit #122 authority and Server Management maintenance/rollback runbook.

**One-clone test:** Current clean existing laptop review checkout \`C:\lor\ImportExport\VSCode-205-kpi-review\` must be fast-forwarded to latest \`fix/205-setup-deadline-kpis-20261015\`; verify \`3bc3b658...\` is an ancestor of tooling HEAD. Read Server Management's Pre-Production Browser Review Runbook and Port Register. After previous preview CLEAN EXIT, run the reusable browser launcher directly (do not run separate disposable acceptance, which would copy Production twice):

\`\`\`powershell
.\Setup\Acceptance\run_setup_disposable_browser_preview.ps1 \`
    -PreviewPort 8898 \`
    -CandidateSha '3bc3b6588b4fc1f8c350cbe7f064c1360e5a47cd' \`
    -TargetRef 'fix/205-setup-deadline-kpis-20261015' \`
    -ExpectedVersion 'V0.3.73-optional-staffing-plan' \`
    -MigrationPaths @('Setup/Database/075_allow_setup_planned_crew_count_corrections.sql') \`
    -ValidationPaths @('Setup/Acceptance/setup_205_planned_crew_count_disposable_validation.sql')
\`\`\`

**Required combined operator check:** (1) D16 Crew A/22 planned AM 3 saves after prior actual work, persists after refresh; actual recorded 1 on assignments 84/143 remains unchanged; Captain-history change still blocked; (2) leave another crew's shift count NULL: no made-up Captain availability, no 0 total task-hours, and task expected duration still shown; (3) count 1 means Captain only, resulting estimated labor only when task duration is known; (4) missing task duration/normal task crew minimum/effort blocks new scheduling and opens existing Planning Info, while a blank day-crew AM/PM headcount does not erase known task duration; (5) independent task-hours and partial/unknown planned person-hours on both screens; (6) preceding V0.3.71 operator rejection findings (Action Center, rescheduling, scroll/day header, AM/PM overload) still require operator review, not automatic approval from CI. No browser opening until \`BROWSER REVIEW READY\`; obtain operator verdict and \`CLEAN EXIT\`.

**Production:** unchanged. The exact source SHA and migration are not deployed; issue #205/PR #394 remain OPEN/DRAFT. Failed migration or validation means STOP and fix a new exact candidate; do not bypass gates.

---


## ARCHIVED V0.3.72 planned-crew handoff (source verified, superseded by V0.3.73; DO NOT RUN)

**NEW SOURCE-CERTIFIED CANDIDATE; BROWSER/DISPOSABLE NOT YET ACCEPTED.** Under #122/#205; operator rejected V0.3.71. New application SHA `fe07cae28a35e98db30281c64aa366ce0aa72ad0`, version `V0.3.72-planned-crew-corrections` on existing draft PR #394. GitHub [CI 38904126715](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38904126715) PASS **826 Setup Python / 202 FieldWiring Python / #205 Node**. Latest branch commits after this exact application SHA may be documentation only. Treat exact application SHA and current branch/tooling SHA separately; never substitute the branch head without verifying candidate ancestry.

**Operator-confirmed business rule:** Planned AM/PM crew counts are Manager-editable even if actual work was reported; actual crew/progress records and history remain unchanged. Manager/SQL historical lock on changing Captain remains in place. Read-only field evidence for **Crew 22** proved 2026-10-16 assignments 84 and 143 had actual/progress while planned AM/PM were NULL. Earlier `ops.update_setup_work_day_crew` in migration 050 rejected the AM planned count; controlled migration **075** replaces only this guarded SQL function. **Database-changing candidate** — no Production migration, mail or session data changes authorized.

**One-clone operator review ONLY:** Existing `Setup/Acceptance/run_setup_disposable_browser_preview.ps1` runs full Setup + FieldWiring Python regression, makes ONE current-Production disposable copy, applies migration `075` **to clone only**, runs rollback-protected validation that changes Crew 22 planned AM/PM counts while keeping actual and Captain history untouched, and starts the same clone for 8898 operator review. Do NOT run a separate disposable acceptance launcher first. The prior preview reportedly exited cleanly; still check exact-run/port ownership as the launcher requires.

Run only in existing clean, fast-forwarded `C:\lor\ImportExport\VSCode-205-kpi-review` branch `fix/205-setup-deadline-kpis-20261015`, after reading the Server Management Pre-Production Browser Review Runbook and Port Register. Stop on dirty/mismatched checkout, unknown port listener, failed migration or SQL validation.

```powershell
.\Setup\Acceptance\run_setup_disposable_browser_preview.ps1 `
    -PreviewPort 8898 `
    -CandidateSha 'fe07cae28a35e98db30281c64aa366ce0aa72ad0' `
    -TargetRef 'fix/205-setup-deadline-kpis-20261015' `
    -ExpectedVersion 'V0.3.72-planned-crew-corrections' `
    -MigrationPaths @('Setup/Database/075_allow_setup_planned_crew_count_corrections.sql') `
    -ValidationPaths @('Setup/Acceptance/setup_205_planned_crew_count_disposable_validation.sql')
```

**Required operator acceptance:** On the disposable browser test D16 Crew A/22 with actual 1 on two Morning assignments, enter AM planned 3 and optionally PM planned staffing; require autosave **Saved** and the values remain after a fresh GET/browser refresh. Original recorded actual crew remains 1 for assignments 84/143 and progress/history unchanged. Verify legitimate Captain historical change still rejects safely and source other V0.3.71 review findings remain open unless explicitly accepted. `BROWSER REVIEW READY`, explicit operator result and final `CLEAN EXIT` are mandatory. If the SQL validation fails, STOP and correct the candidate; never use Production as a substitute test.

**Release boundary:** Migration-bearing Production deployment will require separate #122 authorization and current Server Management database-change runbook / Issue #37 maintenance boundary, validated rollback snapshot and protected ONLINE return. This handoff does **not** authorize release.

---


## ARCHIVED — previous V0.3.71 single-clone browser review (REJECTED)

**Source regression PASSED; operator browser acceptance PENDING.** V0.3.70 was operator rejected. Application SHA `58af4ea3079efe1585314a63329b77b95f31cb4f`, build `V0.3.71-operator-review-corrections`. [GitHub CI #38897393929](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38897393929): PASS 821 Setup Python, 202 FieldWiring Python and #205 executable Node checks. The existing #205 PR branch contains post-app documentation-only changes; use the pinned application SHA rather than substituting branch HEAD for runtime identity.

Use the existing **clean laptop review checkout** `C:\lor\ImportExport\VSCode-205-kpi-review` on `fix/205-setup-deadline-kpis-20261015`. Follow Repository Change Workflow: fetch this branch and fast-forward clean checkout before launch, check candidate ancestry and all wrapper preflights; do not reset or alter primary checkout. Prior preview must have `CLEAN EXIT` (operator reported). Read current Server Management browser runbook and port register.

**One clone: the browser-preview launcher itself runs full Setup and FieldWiring Python regression, captures current Production ONCE, restores disposable PostgreSQL ONCE and starts the exact candidate on port 8898. Do NOT run the separate disposable-acceptance launcher beforehand.** Source CI supplies Node coverage; preview is still needed to verify visual interactions and actual DB projections.

```powershell
# Run only in the clean and current existing #205 review branch checkout.
.\Setup\Acceptance\run_setup_disposable_browser_preview.ps1 `
    -PreviewPort 8898 `
    -CandidateSha '58af4ea3079efe1585314a63329b77b95f31cb4f' `
    -TargetRef 'fix/205-setup-deadline-kpis-20261015' `
    -ExpectedVersion 'V0.3.71-operator-review-corrections' `
    -MigrationPaths @()
```

Open `http://127.0.0.1:8898/` only after `BROWSER REVIEW READY`; keep foreground console open and obtain `CLEAN EXIT` afterward. **Do not deploy or merge** without operator acceptance and separate #122 release approval. Recheck every Oct 16 design requirement against live browser evidence: board scroll and day header, crew stripes/day boundaries, actions contrast in both themes, numeric volunteering inputs/help, late follow-up vs no-work movement, same-Captain suggestion and atomic new crew, AM/PM capacity classification. Real field-browser geometry, unknown duration/shift eligibility and ability to create a new work date are not certified by source CI.

---


## ARCHIVED V0.3.70 source checkpoint — superseded by V0.3.73 above

This older source table and its commands are **historical evidence only**; migration NONE applied then, not to V0.3.72. Never run its older candidate commands for the current review.

| Item | Value |
|---|---|
| Status | UPDATED SOURCE REGRESSION PASS — prior browser review REJECTED, new candidate disposable/browser pending |
| Governing | #122 / #205, controlled Setup engineering contract |
| Candidate branch | `fix/205-setup-deadline-kpis-20261015` |
| App build | `V0.3.70-unified-setup-review` — all rejected operator-UI changes in one source candidate; not browser accepted |
| Current source-only candidate | `fa07150740e98460944306893d6cdf07a5af02c0` — integrated CI PASS; governed disposable/browser acceptance PENDING |
| Previous rejected application implementation SHA | `e4ed6ff13d6e16e9d8a6ed5278c1d81ee2d00eaa` (V0.3.66, HTTP 500) |
| Latest upstream integrated | `main b2d5f8c2f202b228a180bd950187718937c41019` |
| Database migrations in this candidate | **NONE**; notification 074 is on a separate parked branch |
| Production | UNCHANGED; no authorization requested |
| GIS / People | Preserved; no unrelated subsystem mutation |

## ARCHIVED executable handoff — V0.3.70, DO NOT RUN

**Superseded by CURRENT V0.3.72 section above. Do not run.** The October 15 browser review was rejected; CLEAN EXIT there only proved cleanup. This handoff pins the **single integrated** source commit fa07150740e98460944306893d6cdf07a5af02c0 and version V0.3.70-unified-setup-review. Later branch commits through 950e4e16 affect documentation/SOP only. [Integrated CI 38854498823](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38854498823): PASS **816 Setup, 202 FieldWiring**, plus executable KPI, navigation, autosave, drag and no-work rescheduling checks. Source tests are not operator acceptance.

The existing review worktree may still be on the laptop; the block safely **reuses a clean matching worktree** or creates a detached one if absent. It does not pull/reset the primary checkout, disturb Production, or invent migrations. It verifies current remote main without racing VS Code's origin/main auto-fetch. Any non-fast-forward, dirty worktree, SHA mismatch, 8898 port conflict or preview failure is a STOP, not permission for workaround. Read the governing Server Management Pre-Production Browser Review Runbook before launch. This is ONE end-to-end operator review, against the **unified checklist at the end of this document**, not separate feature previews.

```powershell
& {
    $ErrorActionPreference = 'Stop'
    $primary = 'C:\lor\ImportExport\VSCode'
    $review = 'C:\lor\ImportExport\VSCode-205-kpi-review'
    $branch = 'fix/205-setup-deadline-kpis-20261015'
    $candidate = 'fa07150740e98460944306893d6cdf07a5af02c0'
    $version = 'V0.3.70-unified-setup-review'
    if (-not (Test-Path -LiteralPath $primary)) { throw 'STOP: expected laptop primary checkout is absent.' }
    $url = ((& git -C $primary remote get-url origin) -join '').Trim()
    if ($LASTEXITCODE -ne 0 -or $url -notmatch 'Gregovate/MSB-Production-Database-Project(\.git)?

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

## ARCHIVED historical V0.3.67 laptop handoff — DO NOT RUN for current candidate

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

## October 15/16 — Schedule faster without a Crew Save button or placeholder bucket

**Current candidate V0.3.68:** exact implementation SHA `a7572c56d783244dc384a7a4fdb371852c08a241` under draft PR #394; [full source CI #38848810539](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38848810539) PASS: **803 Setup Python, 202 FieldWiring Python**, executable KPI/navigation/Captain autosave/mixed-AM-PM group-drop Node checks.

**Operator request:** Remove the repetitive Save button on crew Captain assignment. Selecting a Captain or changing AM or PM headcount now automatically PATCHes via the existing Manager-protected governed `update_setup_work_day_crew` command; change/blur triggers write, states show Saving / Saved / Not saved; edited values are retained on failure and the task drop explicitly waits for accepted crew values rather than dropping with unsaved staffing. Requests for one crew serialize to avoid old responses overwriting a later Captain/count; duplicate-Captain and short-crew warnings remain. Failed API writes do NOT silently claim persistence. Existing historical actual-work locking remains enforced in PostgreSQL. No schema changes.

**Additional operator idea, implemented as source candidate:** Each workday's crew grid now begins with two visible, keyboard-targetable drag/drop strips: **Drop here · New AM Crew** / **Drop here · New PM Crew**. The operator can first drag unscheduled work onto a day: the server creates a Crew and the selected assignment in **one transaction**, leaving no placeholder if anything fails. A multi-selection of existing AM/PM assignments retains **each original shift**, uses audited existing Setup crew/assignment functions, and rolls back new Crew/entire group if an assignment has actual-work history, wrong Session, duplicate or other failure. Crew/Captain/staffing can then be filled in with autosave. Legacy All Day assignments are explicitly declined for manual review, not silently transformed. Only Manager-authorized operations may write. Task/crew moves to an existing crew across dates were also corrected to preserve mixed AM/PM.

**Still not solved / not claimed:** calendar-first month view, long-day Focus layout, sticky day header, consistent Crew A/B/C colors, Task Feedback/help, misleading progress/1% default, action-tab taxonomy, 404 field context and full user feedback remain open. This V0.3.68 slice is not a complete resolution of the broader rejected review. No further migration, mail service, Directus change or Production deployment.

**Next gates:** current-Production disposable clone acceptance and real 8898 browser workflow, verify unsaved Captain/count on blur before drop, mixed-shift group moved across dates, day-level atomic drop, failure rollback, actual work history locks, operator response on laptop and Android/tablet, final CLEAN EXIT. Previous V0.3.67 browser review CLEAN EXIT does **not** approve this new candidate. User approval and #122 deployment gate separate. Do not hand out deployment commands before browser review.

## MANDATORY acceptance for V0.3.69 — Manager reschedules from Perform Work (not left late)

Greg requires this **in the next #205 browser test**. This is not the optional future calendar-first redesign and does not activate paused email functionality. Corrected exact source candidate `43b993182086d62a0fad08a1deede3624448fcc4` at `V0.3.69-perform-no-work-reschedule`; [GitHub Actions #38851349128](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38851349128) **source PASS**, **806 Setup Python + 202 FieldWiring Python + Node #205 KPI/navigation, Captain autosave, drag-shift and Manager no-work move checks**. Application source did not previously pass protected browser acceptance; **no Production deployment**.

**Actual protected browser/operator verification required:**

1. Find a past unreported 2026 annual task on **Perform Work** with no real work, no progress entry, and noncancelled source day. Manager sees `Reschedule · No work performed` directly on the task card, without needing to load the separately failing optional task context. Captain/Production Crew users must not see or execute this Manager operation.
2. Click, confirm original task/date/crew/AM-PM, select another **current/future existing Setup Day** and existing Crew/shift. The screen requires explicit `NO WORK WAS PERFORMED` confirmation. **Do not add an invented 0-minute or 1% progress report.**
3. On successful protected PATCH, verify that same assignment ID now appears in the destination day/Crew/AM-PM. Its prior workday/Perform Work view no longer counts it as `LATE — NO WORK REPORTED`; the historic original location remains in a recorded `ops.setup_schedule_event` **ASSIGNMENT_MOVED** audit (old/new date, crew, shift and Manager actor, from accepted migration 069). The annual task is **not marked complete** by moving it.
4. Exercise **+ Create a new crew** in the Perform Work reschedule dialog with an existing future workday, preserving original AM/PM. The accepted atomic crew-with-task endpoint should create one destination crew and move the task in one transaction or roll it all back. Captains and crew counts can be assigned using the new auto-save afterward.
5. Verify no eligible destination day triggers a clear **Add Work Days in Plan / Schedule** instruction, not a fabricated date/crew or a write. Cancel and server denial retain original item and late banner; no success message after failed API.
6. Verify a valid report, started/actual work or an accidentally recorded **1%** report makes an assignment history-locked: **no Manager no-work reschedule control and server rejects a forged move**. An actual partial-work occurrence needs a *new continuation*; do not move or erase reported history. Existing incorrect 1% records require independent authorized correction/reconciliation.
7. On an unreported new assignment, open Report Work and verify **Whole task % complete is blank rather than prefilled 1**; a positive actual progress percentage remains required only when work really happened. No new reports or audit records should be invented by merely opening a card.
8. Repeat at laptop and field tablet viewport where practical. Confirm the action does **not depend on field-context HTTP 404**; inspect read-only clone schedule audit, original/new counts and no progress inserted. Obtain actual current-Production disposable acceptance, one 8898 protected browser review, **CLEAN EXIT and explicit operator approval** under #122 before any Production release.

**Preflight constraint:** Check that the current disposable clone has accepted migration 069 (`ops.setup_schedule_event` and the actor-audited `ops.update_setup_work_day_assignment`) before claiming original scheduling facts are preserved. If it is missing, **STOP**: no silent non-audited move or invented migration. This candidate introduces **zero new schema migrations**. Distinguish a Manager-authorized no-work move of the **original occurrence** (correctly clears its obsolete late condition) from scheduling a different continuation (must not suppress unresolved potentially worked historical reports).

**Other open review findings remain:** weather half-day group-batch rescheduling from Perform Work is not yet a single batch action; rejected KPI/Action Center taxonomy, Report Work grid sizing/help, Task Feedback wording, historical erroneous 1% corrections, and field-context HTTP 404 still require separate resolution. This narrow V0.3.69 source PASS does **not** make the overall PR Production-ready.

## Unified acceptance requirement after operator rejected V0.3.67 (October 15/16) — NO MORE PARTIAL PREVIEWS

**Greg's explicit direction: ALL the rejected operational fixes must be in the SAME candidate and the SAME browser review.** Advancing only the no-work reschedule, while leaving the oversized KPI/Action Center and unusable Report Work boxes, is NOT acceptable. Historical V0.3.67 browser CLEAN EXIT denotes disposable cleanup, **not** UI acceptance.

**Single integrated candidate:** `V0.3.70-unified-setup-review`, exact source SHA `fa07150740e98460944306893d6cdf07a5af02c0`, draft PR #394. [Integrated GitHub Actions #38854157408](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38854157408) **PASS: 816 Setup Python; 202 FieldWiring Python; executable #205 KPI, navigation, Captain autosave, cross-day mixed AM/PM and original Manager no-work reschedule Node checks**. This is source-regression evidence ONLY. No current-Production disposable/browser acceptance or Production changes.

### One operator-run browser review must confirm ALL of these

1. **Scheduling Board stays visible.** Only short Total/Completed/Remaining, attention-needed, actual-vs-required pace, hard deadline and cautious task-count estimate appear above the board. Long exception reports are NOT in a collapsed panel above the calendar; the protected **Manager Action Center tab** alone holds them. Verify laptop and tablet viewport, scrolling, day-to-day drag and no excessive task finder / KPI crowding.
2. **Manager Action Center is a separate authenticated tab/page.** Verify Manager can navigate from schedule/Perform Work to it and back to exact original task/day/crew/shift actions. Captain/Production Crew cannot open by tab OR direct `?view=action-center` URL. Check concise summary, explanation that 146 blockers/46 NOT READY/188 no-first-schedule/11 partial/9 continuation can overlap, and qualified task-count pace; no false green assurance or duplicate long technical lists over scheduling.
3. **Report Work input layout repaired.** Crew input readable, Hours and Minutes equal width/height in one row (not one oversized Minutes input), actual date prominent, cumulative whole-task percent blank until intentional entry, notes below. Test narrow tablet/laptop viewport and numeric input focus without clipping. Confirm true positive progress only, hours+minutes jointly entered and distinct persisted duration. Report-date confirmation must show scheduled and actual dates.
4. **Contextual ? help and plain-language Task Feedback.** Show/tap/keyboard-focus adjacent `?` for actual date, Crew, Hours, Minutes, whole-task %, notes; brief field-specific instructions and existing authoritative Report Work SOP, no reset of unsaved form. Operator action now says **Task Feedback**, still uses existing #172 Manager Work Order Intake, not progress correction or automatic Work Order creation. Manager **Correct report** remains a separate audited historical procedure.
5. **Optional field context HTTP 404 is not a Report Work hard failure.** For season-only annual tasks lacking reusable `setup_task_id`, no requests to `tasks/NaN` or `tasks/0`; missing optional location/resources/procedure is clearly marked as unavailable while the Report Work form still loads. Failure to load authoritative progress history must NOT be converted to fake empty history.
6. **Completed work no longer consumes scheduling space.** Default whole-day `Fully reported days` hidden and individual **Show reported task cards** OFF. Mixed days hide reported-only task cards and compress fully reported crew rows, but keep unreported real tasks visible. Turning on Show reported cards or searching a reported assignment reveals exact history; don't erase report associations or hide a different unfinished continuation. Day header sticks and day boundaries are distinct; AM/PM/captain schedule remains usable.
7. **No Save button for Captain and crew counts.** Change Captain, AM and PM counts on busy day; verify protected autosave and inline Saved / Not saved, overlapping changes serialized, short-crew and duplicate Captain checks retained. Drop waits for saved staffing and refuses failed writes; other crews' edit text isn't lost to a whole-board refresh.
8. **Drop straight onto new crew** under AM/PM day headers. One transaction creates Crew and places task(s); on failure rolls back both; future crew Captain/count can be assigned by autosave. Moving mixed AM/PM selection across dates into any crew preserves original shifts. Same-day intentionally chosen shift changes permitted. Audited assignment identity and Progress history remain.
9. **Manager no-work reschedule from Perform Work.** Original past unreported unworked assignment moves to selected future day/Crew or new crew on explicit NO WORK confirmation; old Late warning and KPI obligation clear after **successful audited** existing assignment move; no fake progress. Historical saved 1%, started/reported assignment cannot be moved without the separately governed correction/continuation. Test Manager-only access, cancel/failed API, original/new dates and `ops.setup_schedule_event` actor.
10. **Half-day weather/volunteer disruption.** Manager selects shift's still-unworked assignments in Perform Work, confirms NO WORK on ALL selected, and moves as ONE atomic group to future day and existing/new crew. Server rejects any recorded-work/legacy/duplicate move and rolls back the group; destination shift identities remain accurate. A task with real progress is not silently moved or dismissed.
11. **Real 2026 counts and data credibility.** Compare 294/78/216 browser observation only to current-Production disposable clone (not as assumed latest live totals). Check past unreported, NOT READY vs hard blocks, 9 vs 11 overlap, 188 not-future-assigned, and 12 vs 13 earlier discrepancy using stable task IDs. Confirm incomplete tasks retain correct history and no unwanted 1% progress is created. Independently investigate **already-saved accidental 1% records** through Manager-approved correction/forensic workflow; this implementation does NOT silently undo them.
12. **Final governance:** exact SHA/version/asset pins, same latest-Production clone fingerprint, Setup+FieldWiring regression, protected 8898 browser operator pass, retained reports, actual CLEAN EXIT and explicit Greg approval BEFORE source-only Production release under commanding #122. No new schema migration, no Directus email, no GIS/People changes or real Production writes in this PR.

**Not silently claimed as implemented:** the *possible* future true calendar-day unassigned-task queue, crew-by-color scheme, task mini-list in sticky day headers, complete redesign of Pick-demand planning, and data remediation for historical accidental 1% records remain documented discovery/optional design or separate governed investigation. Do not treat those brainstormed enhancements as accepted scope or use them to declare this candidate complete.

**Status: SOURCE PASS, BROWSER REJECTED/PENDING NEW REVIEW.** No new PowerShell script or laptop operator testing request until Greg wants to run the single integrated acceptance. Any discovered defect in the 12 checks reopens this ONE candidate, not a new piecemeal release.
) { throw 'STOP: wrong repository origin.' }
    & git -C $primary worktree list
    if ($LASTEXITCODE -ne 0) { throw 'STOP: worktrees could not be inspected.' }
    & git -C $primary fetch origin "refs/heads/fix/205-setup-deadline-kpis-20261015:refs/remotes/origin/fix/205-setup-deadline-kpis-20261015"
    if ($LASTEXITCODE -ne 0) { throw 'STOP: candidate branch fetch failed.' }
    if (Test-Path -LiteralPath $review) {
        $top = ((& git -C $review rev-parse --show-toplevel) -join '').Trim()
        if ($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($top).TrimEnd('\') -ine [IO.Path]::GetFullPath($review).TrimEnd('\')) { throw 'STOP: existing review directory is not expected Git worktree.' }
        $dirty = @(& git -C $review status --porcelain)
        if ($LASTEXITCODE -ne 0 -or $dirty.Count) { throw 'STOP: review worktree has changes. Preserve them.' }
        $currentBranch = ((& git -C $review branch --show-current) -join '').Trim()
        if ($LASTEXITCODE -ne 0 -or ($currentBranch -ne '' -and $currentBranch -ne $branch)) { throw 'STOP: another branch owns review worktree.' }
        & git -C $review merge --ff-only "origin/$branch"
        if ($LASTEXITCODE -ne 0) { throw 'STOP: review worktree could not fast-forward.' }
    } else {
        & git -C $primary worktree add --detach $review "origin/$branch"
        if ($LASTEXITCODE -ne 0) { throw 'STOP: isolated review worktree creation failed.' }
    }
    Set-Location $review
    & git merge-base --is-ancestor $candidate HEAD
    if ($LASTEXITCODE -ne 0) { throw 'STOP: integrated source candidate absent.' }
    $main = @(& git ls-remote origin refs/heads/main)
    if ($LASTEXITCODE -ne 0 -or $main.Count -ne 1) { throw 'STOP: cannot verify current remote main.' }
    $mainSha = (($main[0] -split '\s+')[0]).Trim()
    & git merge-base --is-ancestor $mainSha HEAD
    if ($LASTEXITCODE -ne 0) { throw 'STOP: remote main has advanced; reconcile before preview.' }
    $changed = @(& git diff --name-only $candidate HEAD -- Setup/Application Setup/Database .github/workflows)
    if ($LASTEXITCODE -ne 0 -or $changed.Count) { throw 'STOP: source or CI differs from pinned candidate.' }
    $dirty = @(& git status --porcelain)
    if ($LASTEXITCODE -ne 0 -or $dirty.Count) { throw 'STOP: review checkout is dirty.' }
    Write-Host 'PASS: clean isolated review and V0.3.70 application candidate.'

    & .\Setup\Acceptance\run_setup_disposable_acceptance.ps1 -CandidateSha $candidate -TargetRef $branch -MigrationPaths @() -ValidationPaths @()
    if (-not $?) { throw 'STOP: current-Production disposable acceptance failed.' }
    & .\Setup\Acceptance\run_setup_disposable_browser_preview.ps1 -PreviewPort 8898 -CandidateSha $candidate -TargetRef $branch -ExpectedVersion $version -MigrationPaths @()
    if (-not $?) { throw 'STOP: browser review failed; preserve evidence.' }
}
```

Wait for **SETUP REUSABLE DISPOSABLE BROWSER REVIEW READY** before visiting http://127.0.0.1:8898/; keep PowerShell running during the whole review, then press Enter for governed cleanup and obtain CLEAN EXIT. Neither CI nor CLEAN EXIT constitutes user acceptance; explicit #122 approval and Production deployment are separate.

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

## October 15/16 — Schedule faster without a Crew Save button or placeholder bucket

**Current candidate V0.3.68:** exact implementation SHA `a7572c56d783244dc384a7a4fdb371852c08a241` under draft PR #394; [full source CI #38848810539](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38848810539) PASS: **803 Setup Python, 202 FieldWiring Python**, executable KPI/navigation/Captain autosave/mixed-AM-PM group-drop Node checks.

**Operator request:** Remove the repetitive Save button on crew Captain assignment. Selecting a Captain or changing AM or PM headcount now automatically PATCHes via the existing Manager-protected governed `update_setup_work_day_crew` command; change/blur triggers write, states show Saving / Saved / Not saved; edited values are retained on failure and the task drop explicitly waits for accepted crew values rather than dropping with unsaved staffing. Requests for one crew serialize to avoid old responses overwriting a later Captain/count; duplicate-Captain and short-crew warnings remain. Failed API writes do NOT silently claim persistence. Existing historical actual-work locking remains enforced in PostgreSQL. No schema changes.

**Additional operator idea, implemented as source candidate:** Each workday's crew grid now begins with two visible, keyboard-targetable drag/drop strips: **Drop here · New AM Crew** / **Drop here · New PM Crew**. The operator can first drag unscheduled work onto a day: the server creates a Crew and the selected assignment in **one transaction**, leaving no placeholder if anything fails. A multi-selection of existing AM/PM assignments retains **each original shift**, uses audited existing Setup crew/assignment functions, and rolls back new Crew/entire group if an assignment has actual-work history, wrong Session, duplicate or other failure. Crew/Captain/staffing can then be filled in with autosave. Legacy All Day assignments are explicitly declined for manual review, not silently transformed. Only Manager-authorized operations may write. Task/crew moves to an existing crew across dates were also corrected to preserve mixed AM/PM.

**Still not solved / not claimed:** calendar-first month view, long-day Focus layout, sticky day header, consistent Crew A/B/C colors, Task Feedback/help, misleading progress/1% default, action-tab taxonomy, 404 field context and full user feedback remain open. This V0.3.68 slice is not a complete resolution of the broader rejected review. No further migration, mail service, Directus change or Production deployment.

**Next gates:** current-Production disposable clone acceptance and real 8898 browser workflow, verify unsaved Captain/count on blur before drop, mixed-shift group moved across dates, day-level atomic drop, failure rollback, actual work history locks, operator response on laptop and Android/tablet, final CLEAN EXIT. Previous V0.3.67 browser review CLEAN EXIT does **not** approve this new candidate. User approval and #122 deployment gate separate. Do not hand out deployment commands before browser review.

## MANDATORY acceptance for V0.3.69 — Manager reschedules from Perform Work (not left late)

Greg requires this **in the next #205 browser test**. This is not the optional future calendar-first redesign and does not activate paused email functionality. Corrected exact source candidate `43b993182086d62a0fad08a1deede3624448fcc4` at `V0.3.69-perform-no-work-reschedule`; [GitHub Actions #38851349128](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38851349128) **source PASS**, **806 Setup Python + 202 FieldWiring Python + Node #205 KPI/navigation, Captain autosave, drag-shift and Manager no-work move checks**. Application source did not previously pass protected browser acceptance; **no Production deployment**.

**Actual protected browser/operator verification required:**

1. Find a past unreported 2026 annual task on **Perform Work** with no real work, no progress entry, and noncancelled source day. Manager sees `Reschedule · No work performed` directly on the task card, without needing to load the separately failing optional task context. Captain/Production Crew users must not see or execute this Manager operation.
2. Click, confirm original task/date/crew/AM-PM, select another **current/future existing Setup Day** and existing Crew/shift. The screen requires explicit `NO WORK WAS PERFORMED` confirmation. **Do not add an invented 0-minute or 1% progress report.**
3. On successful protected PATCH, verify that same assignment ID now appears in the destination day/Crew/AM-PM. Its prior workday/Perform Work view no longer counts it as `LATE — NO WORK REPORTED`; the historic original location remains in a recorded `ops.setup_schedule_event` **ASSIGNMENT_MOVED** audit (old/new date, crew, shift and Manager actor, from accepted migration 069). The annual task is **not marked complete** by moving it.
4. Exercise **+ Create a new crew** in the Perform Work reschedule dialog with an existing future workday, preserving original AM/PM. The accepted atomic crew-with-task endpoint should create one destination crew and move the task in one transaction or roll it all back. Captains and crew counts can be assigned using the new auto-save afterward.
5. Verify no eligible destination day triggers a clear **Add Work Days in Plan / Schedule** instruction, not a fabricated date/crew or a write. Cancel and server denial retain original item and late banner; no success message after failed API.
6. Verify a valid report, started/actual work or an accidentally recorded **1%** report makes an assignment history-locked: **no Manager no-work reschedule control and server rejects a forged move**. An actual partial-work occurrence needs a *new continuation*; do not move or erase reported history. Existing incorrect 1% records require independent authorized correction/reconciliation.
7. On an unreported new assignment, open Report Work and verify **Whole task % complete is blank rather than prefilled 1**; a positive actual progress percentage remains required only when work really happened. No new reports or audit records should be invented by merely opening a card.
8. Repeat at laptop and field tablet viewport where practical. Confirm the action does **not depend on field-context HTTP 404**; inspect read-only clone schedule audit, original/new counts and no progress inserted. Obtain actual current-Production disposable acceptance, one 8898 protected browser review, **CLEAN EXIT and explicit operator approval** under #122 before any Production release.

**Preflight constraint:** Check that the current disposable clone has accepted migration 069 (`ops.setup_schedule_event` and the actor-audited `ops.update_setup_work_day_assignment`) before claiming original scheduling facts are preserved. If it is missing, **STOP**: no silent non-audited move or invented migration. This candidate introduces **zero new schema migrations**. Distinguish a Manager-authorized no-work move of the **original occurrence** (correctly clears its obsolete late condition) from scheduling a different continuation (must not suppress unresolved potentially worked historical reports).

**Other open review findings remain:** weather half-day group-batch rescheduling from Perform Work is not yet a single batch action; rejected KPI/Action Center taxonomy, Report Work grid sizing/help, Task Feedback wording, historical erroneous 1% corrections, and field-context HTTP 404 still require separate resolution. This narrow V0.3.69 source PASS does **not** make the overall PR Production-ready.

## Unified acceptance requirement after operator rejected V0.3.67 (October 15/16) — NO MORE PARTIAL PREVIEWS

**Greg's explicit direction: ALL the rejected operational fixes must be in the SAME candidate and the SAME browser review.** Advancing only the no-work reschedule, while leaving the oversized KPI/Action Center and unusable Report Work boxes, is NOT acceptable. Historical V0.3.67 browser CLEAN EXIT denotes disposable cleanup, **not** UI acceptance.

**Single integrated candidate:** `V0.3.70-unified-setup-review`, exact source SHA `fa07150740e98460944306893d6cdf07a5af02c0`, draft PR #394. [Integrated GitHub Actions #38854157408](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/38854157408) **PASS: 816 Setup Python; 202 FieldWiring Python; executable #205 KPI, navigation, Captain autosave, cross-day mixed AM/PM and original Manager no-work reschedule Node checks**. This is source-regression evidence ONLY. No current-Production disposable/browser acceptance or Production changes.

### One operator-run browser review must confirm ALL of these

1. **Scheduling Board stays visible.** Only short Total/Completed/Remaining, attention-needed, actual-vs-required pace, hard deadline and cautious task-count estimate appear above the board. Long exception reports are NOT in a collapsed panel above the calendar; the protected **Manager Action Center tab** alone holds them. Verify laptop and tablet viewport, scrolling, day-to-day drag and no excessive task finder / KPI crowding.
2. **Manager Action Center is a separate authenticated tab/page.** Verify Manager can navigate from schedule/Perform Work to it and back to exact original task/day/crew/shift actions. Captain/Production Crew cannot open by tab OR direct `?view=action-center` URL. Check concise summary, explanation that 146 blockers/46 NOT READY/188 no-first-schedule/11 partial/9 continuation can overlap, and qualified task-count pace; no false green assurance or duplicate long technical lists over scheduling.
3. **Report Work input layout repaired.** Crew input readable, Hours and Minutes equal width/height in one row (not one oversized Minutes input), actual date prominent, cumulative whole-task percent blank until intentional entry, notes below. Test narrow tablet/laptop viewport and numeric input focus without clipping. Confirm true positive progress only, hours+minutes jointly entered and distinct persisted duration. Report-date confirmation must show scheduled and actual dates.
4. **Contextual ? help and plain-language Task Feedback.** Show/tap/keyboard-focus adjacent `?` for actual date, Crew, Hours, Minutes, whole-task %, notes; brief field-specific instructions and existing authoritative Report Work SOP, no reset of unsaved form. Operator action now says **Task Feedback**, still uses existing #172 Manager Work Order Intake, not progress correction or automatic Work Order creation. Manager **Correct report** remains a separate audited historical procedure.
5. **Optional field context HTTP 404 is not a Report Work hard failure.** For season-only annual tasks lacking reusable `setup_task_id`, no requests to `tasks/NaN` or `tasks/0`; missing optional location/resources/procedure is clearly marked as unavailable while the Report Work form still loads. Failure to load authoritative progress history must NOT be converted to fake empty history.
6. **Completed work no longer consumes scheduling space.** Default whole-day `Fully reported days` hidden and individual **Show reported task cards** OFF. Mixed days hide reported-only task cards and compress fully reported crew rows, but keep unreported real tasks visible. Turning on Show reported cards or searching a reported assignment reveals exact history; don't erase report associations or hide a different unfinished continuation. Day header sticks and day boundaries are distinct; AM/PM/captain schedule remains usable.
7. **No Save button for Captain and crew counts.** Change Captain, AM and PM counts on busy day; verify protected autosave and inline Saved / Not saved, overlapping changes serialized, short-crew and duplicate Captain checks retained. Drop waits for saved staffing and refuses failed writes; other crews' edit text isn't lost to a whole-board refresh.
8. **Drop straight onto new crew** under AM/PM day headers. One transaction creates Crew and places task(s); on failure rolls back both; future crew Captain/count can be assigned by autosave. Moving mixed AM/PM selection across dates into any crew preserves original shifts. Same-day intentionally chosen shift changes permitted. Audited assignment identity and Progress history remain.
9. **Manager no-work reschedule from Perform Work.** Original past unreported unworked assignment moves to selected future day/Crew or new crew on explicit NO WORK confirmation; old Late warning and KPI obligation clear after **successful audited** existing assignment move; no fake progress. Historical saved 1%, started/reported assignment cannot be moved without the separately governed correction/continuation. Test Manager-only access, cancel/failed API, original/new dates and `ops.setup_schedule_event` actor.
10. **Half-day weather/volunteer disruption.** Manager selects shift's still-unworked assignments in Perform Work, confirms NO WORK on ALL selected, and moves as ONE atomic group to future day and existing/new crew. Server rejects any recorded-work/legacy/duplicate move and rolls back the group; destination shift identities remain accurate. A task with real progress is not silently moved or dismissed.
11. **Real 2026 counts and data credibility.** Compare 294/78/216 browser observation only to current-Production disposable clone (not as assumed latest live totals). Check past unreported, NOT READY vs hard blocks, 9 vs 11 overlap, 188 not-future-assigned, and 12 vs 13 earlier discrepancy using stable task IDs. Confirm incomplete tasks retain correct history and no unwanted 1% progress is created. Independently investigate **already-saved accidental 1% records** through Manager-approved correction/forensic workflow; this implementation does NOT silently undo them.
12. **Final governance:** exact SHA/version/asset pins, same latest-Production clone fingerprint, Setup+FieldWiring regression, protected 8898 browser operator pass, retained reports, actual CLEAN EXIT and explicit Greg approval BEFORE source-only Production release under commanding #122. No new schema migration, no Directus email, no GIS/People changes or real Production writes in this PR.

**Not silently claimed as implemented:** the *possible* future true calendar-day unassigned-task queue, crew-by-color scheme, task mini-list in sticky day headers, complete redesign of Pick-demand planning, and data remediation for historical accidental 1% records remain documented discovery/optional design or separate governed investigation. Do not treat those brainstormed enhancements as accepted scope or use them to declare this candidate complete.

**Status: SOURCE PASS, BROWSER REJECTED/PENDING NEW REVIEW.** No new PowerShell script or laptop operator testing request until Greg wants to run the single integrated acceptance. Any discovered defect in the 12 checks reopens this ONE candidate, not a new piecemeal release.
