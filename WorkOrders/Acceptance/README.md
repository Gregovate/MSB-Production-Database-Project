# Work Management #419 — disposable clone and browser review

## Current Phase 2 acceptance

See [Phase 2 completion checkpoint](Phase_2_Completion_Checkpoint.md) for the
current draft candidate and exact remaining gates. Phase 1 is installed;
Phase 2 is not. Older dated evidence below must not be applied to newer code.


## Current release preparation — October 20, V1.0.1-production-route

Phase 1 functional approval and Production authorization are recorded in #419/#81.
The Production route correction follows the existing Synology perimeter and mounts
the same application at /workorder/. Local app/read-model regression: 86 PASS.
Existing acceptance-profile regression: 17 PASS, one local netlink restriction;
the original cleanup test is retained unchanged for CI/host execution.
No SQL changes or sender activation. Exact-candidate CI and actual protected
Manager/Crew route acceptance remain required; source tests do not establish
Cloudflare identity integrity or direct-origin bypass protection.
Earlier CHANGES REQUIRED entries below describe earlier candidates.

**Status: V0.3 source-only candidate; new disposable-write validation and browser review still pending. V0.2 operator review was CHANGES REQUIRED.** Work Management is the existing MSB Database Work Orders subsystem.

## October 20 — V1 native Manager/Crew browser candidate, source regression PASS; live browser pending

**Why:** The operator's current-Production disposable SQL evidence for native V1 migration and Create/Assign/Progress/Complete/Intake promotion is PASS. The prior generic `start` browser still calls the old CloneCommands and cannot substitute for a native V1 UI acceptance. This change extends the **existing** #419 PowerShell wrapper/remote runner to start the same UI against native `ops.work_management_v1_command` instead.

**Mode:** `-V1Browser -V1ReviewerRole Manager` or `-V1Browser -V1ReviewerRole Crew` on original `run_work_management_disposable_browser_preview.ps1`. Remote modes `start_v1_manager` or `start_v1_crew` share the same registered sequential `8898` and existing start/resume/reconnect + exact-bound-PID cleanup. The server still performs full Setup/FieldWiring/#419 regressions, Production before/after WO+Intake fingerprints, restores private PostGIS clone, validates source SHA, read projection and clone write preflight **before** V1 browser launch.

**Native commands:** Inside **private clone only** the runner creates a separate `work_management_app LOGIN` with temporary private password, executes the already-validated guarded V1 migration and grants **only that role** its narrow native command EXECUTE + read-only projections. Manager/Crew review must match the pinned reviewer’s actual cloned Directus role; the runner fails closed on mismatch and never grants reviewer elevation. The existing protected `preview_entry.py` replaces client identity with the pinned reviewer on every request. `WORK_MGMT_RUNTIME_MODE=v1_disposable` is a distinct runtime that verifies database name `msb_wo419_preview`, role `work_management_app`, and the exact Docker-private host IP before native commands. It requires explicit `WORK_MGMT_V1_CLONE_WRITE_GATE=approved_private_clone` and 48-character preview CSRF plus protected JSON command header. The normal `production` startup/write gate and Production DSN remain separate and cannot be enabled by this source mode.

**UI:** Banner says `Work Orders V1 NATIVE · Disposable database · No emails sent`; actions save to disposable native SQL and are discarded at teardown, not Production. Existing Directus Manager vs Crew rights are reflected in native queries. One prior clone-only `Link to seasonal Setup` button is hidden in this native mode because V1 native SQL does **not** yet support the composed Setup link command; never offer a misleading 409 button. This remains a governed integration follow-up and release blocker where relevant.

**Test status:** Source Work Management and Engineering Compliance CI PASS, including clone-mode role/IP negative tests and original runner/wrapper source assertions. **No real V1 browser launch or end-to-end UI save has yet passed**; these cannot be reported as accepted. First session is Manager to prove Create, actual Intake Promote/Assign, Progress, Complete, Task Feedback and queues. Second **sequential** session is Crew with a distinct approved active Person email to prove no native Create/Intake triage/Manager assignment, proper assigned-work update, and absence of unauthorized tickets. Both sessions require full server `WO419 DISPOSABLE BROWSER REVIEW: CLEAN EXIT`, workstation `WO419 V1 native browser tunnel: CLEAN EXIT`, no residual port 8898/clone/worktree/state, and unchanged Production fingerprint. Stop at first HOLD and preserve exact server report; **no manual cleanup as routine**.

**Operator launch gating:** Use the latest exact PR #420 SHA and clean BLUE laptop worktree. Do not start if another Setup/#88/#171 review occupies 8898. This is a **V1 browser test only**, not permission to merge/deploy, assign Work Order Manager rights in Production, start a permanent service, or enable email/Flows.

---

## October 20, 01:09 server report — V1 native PostgreSQL clone SQL PASS

**Operator validated** the accepted V1 SQL migration and real native command functions on the restored **private current-Production disposable database**. Retained evidence: `/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261020T010953.txt`.

Observed terminal:

```text
PASS: V1 proposed native schema/functions installed on disposable clone
NOTICE: WO419 V1 disposable validation: Manager Create, native assignee Progress/Complete, non-Manager denial, Intake promotion, and no-send intent PASS
ROLLBACK
WO419 V1 DISPOSABLE SQL VALIDATION PASS
No browser listener started; clone-only validation transaction rolled back
WO419 preview cleanup, initial status=0
PASS: verified Work Orders listener stopped; disposable teardown permitted
PASS: owned disposable clone removed
PASS: disposable candidate worktree unregistered
PASS: Production Work Order/Intake fingerprint unchanged
PASS: shared checkout HEAD unchanged
PASS: preview port no longer listening
WO419 DISPOSABLE BROWSER REVIEW: CLEAN EXIT
WO419 V1 disposable SQL validation: CLEAN EXIT
```

**Accepted gate:** real PostgreSQL DDL applied and functional SQL checks passed inside disposable clone. Transactional sample records/grants rolled back; clone/port cleaned; no Production write or email. **NOT YET browser acceptance or V1 Production deployment approval.**

**Next gate: native V1 browser, not the old CloneCommands.** The existing #419 runner has separate `start_v1_manager` and `start_v1_crew` operator modes exposed by the original PowerShell wrapper's `-V1Browser -V1ReviewerRole Manager|Crew`, and reuses port 8898 sequentially. The V1 browser must use a private clone-local `work_management_app` LOGIN (never `fieldwiring_app` for V1 saves), source-pinned `v1_runtime.V1Repository/V1Commands` and `ops.work_management_v1_command`; no native Work Order table DML grant to that LOGIN. Manager grant is temporary **in the clone** for the one verified reviewer identity; Crew mode grants no Manager rights. The entire clone, its work, and temporary credentials must be destroyed on complete CLEAN EXIT. The original 8898 browser/resume process ownership checks remain controlling. Do not run simultaneously with Setup/#88/#171 previews.

**V1 browser acceptance still CHANGES REQUIRED** until actual Manager Create and Intake promotion, multi-person assignment, assigned Crew Progress/Complete, denied Crew Create, Task Feedback and Testing read state, and clean-exit reports are observed. In particular, existing Production cases WO-372 and WO-402 are not automatically completed by clone acceptance. Mail remains no-send/pending cutover.

---

## October 20, 00:57 server report — V1 migration parse HOLD; exact source corruption corrected

**Operator pasted only the relevant tail**, which is sufficient for diagnosis. Existing Work Orders disposable read acceptance completed `PASS` including Intake #60. Then the V1 SQL migration began creating the isolated clone's proposed tables/functions and failed during `ops.work_management_v1_command` creation:

```
ERROR: unterminated quoted string at or near "'); END"
LINE 338: ...'activity_id',v_event,'notifications','PENDING_CUTOVER');
WO419 DISPOSABLE BROWSER REVIEW: HOLD (status 3)
```

**Retained original report:** `/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261020T005750.txt`. **No V1 functional commands were reached**; do not claim migration or browser acceptance. Source inspection found a truncated Person-ID validation expression (`WHERE item.value ~ '^[1-9][0-9]{0,9}` lacked `

**Operator evidence:** Laptop invoked the existing `run_work_management_disposable_browser_preview.ps1 -V1Validation` candidate `c0c1f5518accad0638ec2ca4a84429a3bb480538`. Original server report: `/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261020T004438.txt`.

**Verified first gate:** Current Production data restored privately to `msb_wo419_preview`, network address `172.18.0.5`. Existing unified read projection passed, including `INTAKE-40`, `INTAKE-57`, `INTAKE-60`, `WO-372` and `WO-418`. Manager My Work=20, All sampled rows=100, 12 assignee choices, full aging=58 open including one inactive exception; validated catalog authority. This is **read/preflight** acceptance, not the new V1 migration.

**Failure:** `WORK MANAGEMENT #419 DISPOSABLE READ ACCEPTANCE HOLD at clone_write_transaction_rollback: Target year applies only to Planning (urgency 5).` Source `WorkOrders/Acceptance/validate_work_management_clone.py` still provided `urgency=3` **and** `target_year=2026` in a legacy preflight fixture, which contradicted Tom's accepted October 19 *non-Planning target year absent* rule. Its Crew branch also still attempted Crew native Create, contrary to the new Intake-first authorization. The runner correctly stopped before `validate_v1` SQL migration. Do not misreport that V1 SQL failed or passed—**it was not reached**.

**Observed cleanup PASS:** `PASS: verified Work Orders listener stopped; disposable teardown permitted`; `PASS: owned disposable clone removed`; `PASS: disposable candidate worktree unregistered`; `PASS: Production Work Order/Intake fingerprint unchanged`; `PASS: shared checkout HEAD unchanged`; `PASS: preview port no longer listening`. Runner exit `HOLD (status 1)` reflects failed validation. No manual cleanup/retry of abandoned state is required.

**Correction in existing PR #420:** Preflight uses `urgency=3,target_year=None` and replaces obsolete Crew-direct-create positive rehearsal with a transaction-denied 403 assertion, using the same existing Intake path. Added guard tests to detect reintroduced non-Planning years and Crew direct Create before a real clone test. Also corrected the proposed V1 grant contract: `work_management_app` needs **SELECT only** on `ops.work_management_activity` so the existing Manager Intake and Task Feedback read projection can resolve durable V1 activity; no new outbox SELECT, native Work Order DML, or notification sends. This was identified by source inspection and **has not been applied to a clone or Production yet**.

**Next gate:** Run exact new candidate SHA once with the same original `-V1Validation` path. Require a `WO419 V1 DISPOSABLE SQL VALIDATION PASS` **and** full server/laptop CLEAN EXIT before claiming V1 PostgreSQL acceptance; if HOLD again preserve the new report and inspect phase first. Never claim browser/Production acceptance based on source CI.

---

## October 19 — V1 native PostgreSQL disposable validation, no browser (new acceptance mode)

**Purpose:** Before asking for another Work Management browser review or any Production V1 release, run the proposed `WorkOrders/Database/001_work_management_v1_governed_commands.sql` against the **existing current-Production private disposable database clone**, *not* Production. The existing #419 runner and its established **8898 sequential review profile** now have one optional `validate_v1` start mode, selected by the laptop's existing `run_work_management_disposable_browser_preview.ps1 -V1Validation` flag. It does not start a Flask browser/listener, alter `/opt/fieldwiring`, deploy a service, or use a new SSH workflow/port.

**Laptop:** From the existing clean BLUE `C:\lor\ImportExport\MSB-WorkOrders-419` worktree on `issue-419-unified-ticket-read-model-20261018`, refresh the pinned candidate SHA, then invoke the exact existing PowerShell launcher with `-CandidateSha <exact SHA> -PreviewPort 8898 -PreviewEmail 'gliebig@sheboyganlights.org' -ApprovedReviewProfile -V1Validation`. Keep the terminal open during the initial full Setup, FieldWiring, Work Orders regressions and PostgreSQL pg_dump/clone restore.

**What runs:** The normal server runbook checks a clean shared checkout, source ancestry, exact SHA, registered port ownership, Production Work Order/Intake before fingerprint, full Setup/FieldWiring/#419 tests, and a private Docker PostGIS 16 restore. On that **private clone only**, it installs the new `work_management_app NOLOGIN` test role and executes V1 SQL with the clone authorization marker (Production always requires a *different explicit* maintenance authorization marker). `wo419_v1_disposable_validation.sql` then opens a transaction, grants the exact verified reviewer temporary Work Order Manager authority **inside the clone only**, checks native Create→Assignment→Progress→Complete, idempotent retries, rejection of native non-Manager Create, promotion of a real unpromoted public Intake on the clone with original Intake provenance, lack of browser direct native DML, and held/no-send outbox records. Its entire fixture is rolled back. The owned private Docker clone/worktree/dump are then removed with the corrected exact-owner cleanup and Production Work Order/Intake fingerprint and shared source HEAD checked again.

**Acceptance criterion:** `WO419 V1 DISPOSABLE SQL VALIDATION PASS` followed by `WO419 DISPOSABLE BROWSER REVIEW: CLEAN EXIT` on the **server** and `WO419 V1 disposable SQL validation: CLEAN EXIT` on the **laptop** (this status is **SQL-only**, not browser/operator acceptance). Keep the retained server report path. On any `HOLD` or nonzero exit, **do not rerun** or manually kill port 8898: preserve report and inspect exact owner/phase before adjusting source. The new mode does not automatically SSH-resume a failed SQL run because no approved browser state exists to resume. No Production table or role changed, no emails sent, no approved V1 deployment.

**After clone PASS:** Next engineering gate is to exercise real V1 Manager/Crew browser paths on the same disposable database + candidate V1 schema, including required app identity, native commands, Task Feedback, Testing and no-send, before requesting V1 operator acceptance. The current `start` mode still exercises the earlier clone-only `CloneCommands` path; it **does not establish V1 acceptance**.

---
## October 19, 16:39 — Work Orders browser cleanup HOLD, owner-verified recovery, and root correction

**Operator impact:** Candidate `14f4a15a5118401ba084aed87f3f25146419c3d2` completed an operator review on the Command Center PC. When the operator pressed ENTER to finish, the existing WO419 shell runner printed:

```
HOLD: preview PID command mismatch; no broad process kill
PASS: shared checkout HEAD unchanged
HOLD: preview listener remains after cleanup; inspect exact PID before retry
WO419 DISPOSABLE BROWSER REVIEW: HOLD (status 83)
Retained report: /home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261019T202331.txt
```

It **removed the disposable database/worktree before proving the Flask listener was gone**, leaving a broken, orphaned Python process on the shared sequential port 8898. The subsequent read-only server check identified exactly `PID=3469910`, `PGID=3469910`, `SID=3469910`, `fieldwiring`, `/tmp/msb-wo419-preview-candidate-20261019T202331-3468774/WorkOrders/Application/preview_entry.py`, port `127.0.0.1:8898`, **no #419 Docker containers**, and **no resume state**. The operator then ran the exact-identity-gated targeted PID stop and explicitly reported:

```
PASS: Exact orphaned #419 browser verified.
PASS: Port 8898 released.
WO419 ORPHANED BROWSER PROCESS CLEANUP COMPLETE
```

**Root cause:** The source recorded the background launch handle `$!` from `setsid python ... &` as if it were the actual serving PID. `setsid` can fork when its launch handle is already a process-group leader, yielding a different Flask PID. The cleanup compared the wrong PID, correctly refused a broad kill, but wrongly continued deleting the clone/worktree. This is a **browser process ownership/lifecycle defect**, not a WO/Intake data failure.

**Source correction on existing PR #420:** In the existing `WorkOrders/Acceptance/work_management_disposable_browser_preview_server.sh` only, resolve the **real bound listener PID** from `sudo ss -H -ltnp` after Flask health is ready, then verify exact NUL-delimited `/proc/PID/cmdline` argv (`/opt/fieldwiring/.venv/bin/python` + exact candidate `WorkOrders/Application/preview_entry.py` path), numeric `fieldwiring` UID, PGID and SID equal to actual listener PID, and unique port ownership. Store that verified PID in the 0600 reconnect state instead of the untrusted launch handle. On operator completion or failure, attempt a narrow TERM against **only** the freshly verified listener PID; escalate KILL only if that **same exact validated PID** still owns the port. **Any ambiguous/foreign/unverified port halts cleanup without touching the clone/worktree/state**, preserving evidence and recoverability. Only after proving port free may runner remove the owned disposable Docker container and git worktree. Independently check container removed, candidate worktree unregistered, state absent, unchanged Production WO/Intake fingerprint (subject to concurrent external writes), unchanged shared checkout HEAD and port free before reporting CLEAN EXIT. No port reassignment, broad `pkill`, guessed PID, process-group kill, Production migration, or server service change.

**Regression:** GitHub source tests run the real extracted Bash cleanup/verification functions against a disposable local `setsid` Python socket, prove unknown candidate owner is **not killed** and its state remains, then prove the expected listener is stopped, port freed and owned state deleted. Other #419 and engineering compliance checks remain required. **Operator-run live server full disposable lifecycle validation is still pending**; source tests are not evidence of a successful real server CLEAN EXIT on this correction. Next test must report normal complete teardown with no `sudo` manual orphan cleanup and preserve retained report path.

**Governance:** MSB-Server-Management `docs/server/Pre_Production_Browser_Review_Runbook.md` and `docs/server/PostgreSQL_Disposable_Acceptance_Standard.md` remain controlling; reuse established current #419 runner and sequential port 8898. #419 PR #420 remains draft. Do not touch #88/#171 sessions, release Production, alter Flow, send notifications, or silently claim browser acceptance.

---

## October 19 — Reuse fault-tolerant Setup SSH review pattern; office feature handoff

**Authority:** [MSB-Server-Management browser review runbook](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Pre_Production_Browser_Review_Runbook.md), plus [reusable Setup reconnect contract](../../Setup/Acceptance/README.md#recoverable-browser-preview-transport). The September 29 #205 Setup browser review established that an SSH/PTTY disconnect must preserve the actual healthy disposable clone, entered browser changes, and Flask process, and the **same** workstation SSH wrapper must reattach after exact SHA/ref/port/operator/process/clone/version verification. No new runner or port allocation is permitted.

**Observed regression and controlled recovery:** On October 19, the #419 V0.3.2 Manager browser (candidate `b32b48075dce38cb18122c2f84d891f3e0153470`) suffered `client_loop: send disconnect: Connection reset` and workstation SSH exit **255**. The original Work Orders wrapper had no reconnect loop; its remote script used destructive/trapped cleanup logic instead of Setup's resumable state. The operator's read-only server diagnostics proved one abandoned **fieldwiring PID/PGID 3033050**, one Docker-private **`msb-wo419-preview-3031755`** container, and an occupied localhost port **8898**. The approved exact-instance cleanup separately proved `PASS: Exact WO419 preview verified`, `PASS: Port 8898 released`, and `WO419 OWNED PREVIEW CLEANUP COMPLETE`; no #419 container or port listener remained and Production PostgreSQL `pg_isready` returned accepting connections. This is **not a retroactive Production WO/Intake fingerprint PASS** or previous normal CLEAN EXIT.

**Source recovery corrections on existing PR #420:** 
- Single established Work Orders wrapper/runner, exact candidate SHA and sequential shared **8898**; no competing subsystem or test port.
- Shell runner accepts optional **start/resume fifth argument**, writes an owner-private **0600** state file only after browser READY validation, recording no passwords/token/CSRF/DSN. On lost SSH input/HUP after READY it preserves the preview, clone, current test edits, candidate worktree and original evidence. Before READY, failures retain regular controlled teardown.
- Workstation PowerShell wrapper retries transport exits **75/255** (up to 12 attempts) with the **same uploaded digest-verified runner**; no rebuilding private clone and no killing unknown local listeners. A resume verifies exact SHA/ref/port/reviewer, numeric fieldwiring UID, saved preview PID and port ownership, running private container, detached SHA and live `/api/work-orders/health` application version **before** allowing another review or intentional ENTER cleanup. Unknown ownership/state HALTs safely.
- Guard port/state conflicts **before** any pg_dump/clone. The uploaded runner is deleted only after successful normal server teardown; its script is retained on transport loss for verified reattachment. No-STDOUT secret logging or Production DML added.
- Targeted regressions on Linux execute the actual Bash private-state writer (including permissions, content, re-source and overwrite refusal) and fail-closed 4/5/6 argument gates; source contract checks verify same Setup-style bounded PowerShell reconnect, strict identity/ownership, non-destructive mode dispatch and no arbitrary SSH-process termination.

**Acceptance state:** GitHub source tests/Engineering Compliance are necessary but **not evidence that a workstation SSH disconnect/reconnect has been exercised against the real protected browser**. Real fault-tolerance acceptance is pending a later explicit user-approved disposable review when **8898** is available. Do not block ongoing #88 Container Movement / #171 GIS testing while editing #419. Operator UI review remains CHANGES REQUIRED; no Production deployment/email/Flow cutover authorized. Office PC continuation: dedicated `C:\Users\Greg\Github\MSB-WorkOrders-419` blue feature worktree/VS Code window, `git pull --ff-only` only when clean and after fetching exact #419 origin branch. Do not update primary `main` or touch GIS/#88 worktrees.

## October 19 — Tom/Manager review: Intake-only Crew requests, Planning year, Manager privileges

**Source candidate:** Following the Oct 19 in-person Work Orders review, the operator explicitly **reversed the earlier Crew direct-create requirement**. A Crew or other non-Manager reporter uses the same public Park/Workshop Work Order Request Form (`https://forms.gle/Gve4ZbXHDWxs43yh6`), which submits to existing `stage.work_order_intake` for investigation, clarification, approval/promotion and eventual assignment. No new Intake subsystem, Google Form or duplicate WO is authorized. The direct native **Create Work Order** button is Manager-only; the server `CloneCommands.perform(..., 'create', ...)` independently denies any actor lacking verified `can_manage`, even if `can_create` is forged. The existing selector/access policy no longer maps Production Crew to direct `can_create` capabilities.

**Create/Promote defaults:** New actual Work Orders default urgency/priority to **3 — Normal**; Target year is only visible/submitted for **urgency 5 — Planning**, with valid year required for new Planning Work Orders. Non-planning native saves carry NULL target year. Intake requires **no assignments** and **no target year**; assignment is managed during triage/promotion, not on request submission. We **do not claim to change default values inside the third-party Google Form**: its source and Apps Script are separately governed and should be inspected before any public submission defaults are changed.

**Operator permission concern:** Manager capabilities should be deliberately assigned, not inferred from unrelated legacy person flags. User expressed concern about an existing Manager delegation; no named user's authorization, Google Workspace membership, or Directus role has been changed. Role-scope change would require explicit separate authorization and privileges inventory. No Production write, mail send, or Flow cutover.

**Validation:** CI source tests now enforce native Manager-only Create, Crew rejection before any database transaction, existing form link, default urgency 3, Planning-only target year, and retention of Intake/Manager triage. **Source CI PASS does not mean disposable UI acceptance**; hold functional live Manager/Crew browser testing and actual form Intake side effects until review authorized and sequential 8898 available. Preserve active browser data and never force-stop another review.

---
## October 19 — Command Center operator UI review, source corrections, and cross-repo boundaries

**Review verdict: CHANGES REQUIRED.** Command Center PC operated on the accepted isolated #419 browser candidate `72939e3ebf90923347550dd786e3294edbacfcf2`. Screenshots: filter/header layout crowded and clipped; **Create Work Order** exposed the empty "New internal Work Order" panel but no editable fields and repeated its title; Aging Report showed **WO-372** still Open despite Tom reporting physical completion this morning; **WO-389** is a request to assign `RD04-B-03` to Container `C213` (not a mandatory repair Work Order); the `my.sheboyganlights.org` public Google Form button incorrectly said **Submit a Work Order** when it creates a **Work Order Intake** item that a Manager may approve/promote. Person-search usability suggests evaluating whether `ref.person.available_for_work_orders` is redundant, but first audit downstream identities/permissions and notification rules—no field/schema change authorized by feedback. Operator reported `WO419 workstation browser tunnel: CLEAN EXIT`; that is a workstation exit observation, **not** operator acceptance or independent server fingerprint evidence.

**#419 source-only candidate implementation on existing draft PR #420:** responsive filter/actions rows group scope, search, sort separately from completion/planning toggles, Refresh, Create and request link; narrowed input min widths prevent clipping. The direct Create path now explicitly exposes the proper form/fields, focuses work description, advertises `aria-expanded`, and preserves the `create` selection during late reviewer option redraw; removed the duplicate CSS-added heading. Targeted regression tests assert these contracts. **Source regression/CI PASS is not a substitute for real browser functional validation**: next approval review must actually enter and save a disposable Create, test authenticated work-notes and WO completion, reassignment, manager Intake, and normal/logout and SSH disconnect behavior.

**WO-372:** original repair and completion records must be reconciled by authenticated work order workflow with real actual-work notes, credited to the person performing/verifying the job. The fact Tom physically completed it on October 19 is not proof `ops.work_order.done_at` is set; do not invent a timestamp, backdate records, or close Production outside authorized release. If current Production still says Open, that is unrecorded completion, not evidence of an additional physical repair requirement.

**WO-389:** location/home rack assignment belongs to #230 (canonical storage location reference editor), honoring #88 movement/home boundaries. Filed on #230; #419 does not replicate the reference-table editor or update `C213`.

**Portal:** User-requested text change is made as source-only draft [MSB-Internal-Web-Backbone PR #26](https://github.com/Gregovate/MSB-Internal-Web-Backbone/pull/26) (`fix/portal-work-order-request-intake-label-20261019`), retaining the existing public Google Form URL and Manager triage. Publication separately governed by site repo; no website deployment in this PR.

**Release holds:** Prior UI acceptance remains failed until disposable browser functional acceptance; #419 may not deploy/Flow-cutover/send emails or mutate Production Work Order records without explicit new approval. Respect shared sequential port 8898 occupied by any #88/GIS review.

---
## October 19 — Manager disposable browser review: CHANGES REQUIRED, source candidate underway

The operator reached the real protected Work Management browser on the existing current-Production **disposable clone**, reviewed several Manager queues in dark/light modes, and later reported **`WO419 workstation browser tunnel: CLEAN EXIT`**. This confirms a successful exit from the workstation launcher; the exact server cleanup report path/fingerprint for this session was **not pasted**, so do not invent it or claim independent server fingerprint evidence. **Operator UI acceptance was explicitly rejected**, despite the functional Manager pending Intake banner (2 Public requests, 1 Task Feedback) and full Open Work Order Aging Report (58 undated WOs, including one inactive exception) being useful.

**Required repair before next browser handoff:**
- **Work Order execution:** On selected open WO (operator example WO-402, physically completed weeks earlier), show obvious **Add Work Note** and **Complete Work Order** actions immediately at the top of the detail card. Completion form captures actual work notes, then server decides authenticated Person and completion date; do not expose arbitrary Completed By or manually set Date Completed. Save notes without changing completion when progress only. Do not modify WO-402 in Production because it was reportedly finished physically.
- **Manager maintenance:** Put a separate **Manager · Assign / Reassign** button in the Work Order heading, not as an undifferentiated work dropdown. Preserve normalized multi-person assignment history, Manager-only server rights and no-send notification receipts.
- **Create:** One top-bar **Create Work Order** button opens blank native creation fields directly. Remove the generic redundant `Select proposed action` picker from the operator interface; it may remain as internal state but never dictate the visible workflow.
- **Internal navigation:** Browser Back/Forward and explicit **← Back to Work Order list** stay within Work Management and restore selected ticket, authorized queue/filter, planning flag, search, and list scroll. Returning from aging drill-through must not lose the reporting context or exit the application.
- **Planning ideas:** A long-term proposal (WO-105 Area 5 Shelter) must not mingle with normal dispatch. Current urgency **5 = Planning** is the native available category. Use a reversible **Show planning work (Priority 5)** checkbox in every authorized queue **and in the aging report**, default off for day-to-day dispatch. Normal filters exclude only Priority 5, leave unknown priorities untouched and do not delete/mutate/retire historical records. When enabled, full planning records become findable with original metadata. Treat this as an initial view filter, **not an invented durable planning-classification field**.
- **Sorting:** Replace confusing `Critical first / Planning first` names with clear numeric `Most urgent first (1 → 5)` / `Least urgent first (5 → 1)`; numeric ticket IDs and created date remain sortable by both directions.
- **Styling:** Bounded Work Management text-size/readability corrections and #419 components must use established [#159 shared light/dark palette](https://github.com/Gregovate/MSB-Production-Database-Project/issues/159) and [#140 semantic CSS intent](https://github.com/Gregovate/MSB-Production-Database-Project/issues/140), rather than inventing a competing MSB-wide design system. Browser scaling is individual preference, not a substitute for readable app defaults.

**Next controlled run:** Full source regression + same Server Management runner and sequential localhost port 8898, fresh private restore, rollback native WO/Setup gate validation, two role sessions, no-send, no Production changes. Browser must verify actually saving a work note and a completion in the disposable database, reopening via search, Manager Assign/Reassign, Create blank fields, Back, Show Planning off/on incl aging CSV, and light/dark normal font. Need `WO419 BROWSER REVIEW READY`, operator acceptance, then server **CLEAN EXIT/fingerprint** separately. PR #420 draft; no deployment.

## October 19 — second write-preflight HOLD: Setup season read requested unauthorized row lock

**Operator real run:** exact candidate `dc98c63b5e72896aaaeb7898551a34d10a7f4252`; retained server report `/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261019T102500.txt`. The previous `/32` clone-IP mismatch is **fixed and proven** by canonical `172.18.0.5` reporting and progression into the Write/Create/Assign → Setup linkage preflight. Source regressions, current-Production dump/private final-PID1 PostgreSQL restore, read/ledger, 58-open/one-inactive Manager Aging Report, and clone-only write grant/no-send outbox setup all PASSED. The test reached `atomic_work_order_setup_season_gate` and raised `InsufficientPrivilege`, before browser READY.

**Source diagnosis:** `CloneCommands.create_season_only_work_order_gate()` ran `SELECT setup_session_id FROM ops.setup_session ... FOR SHARE` under the clone application role. This requests a PostgreSQL row-level lock, requiring table privileges beyond the deliberately limited `SELECT` on `ops.setup_session`. There is **no justification to grant UPDATE** or broader annual-task DML merely to check if the season is open. The released `SECURITY DEFINER ops.create_setup_season_task` is already Manager-authorized and independently checks season/actor/stage/Work Order. This source-level row lock is the specific likely cause of the observed failure; no full SQL error details were exposed, so live reproduction of that exact statement was not captured.

**Narrow fix:** remove only the unnecessary `FOR SHARE` from the read-only season precheck, retaining selected `ACTIVE/PLANNING` status, existing Manager role, open season/WO duplicate validation, native Setup command and **same PostgreSQL atomic transaction**. Do NOT grant update privileges on `ops.setup_session`, INSERT on `ops.setup_session_task`, or replace the existing Setup command. New restricted-cursor regression fails if the Setup read attempts `FOR SHARE/FOR UPDATE` and proves it reaches `ops.create_setup_season_task` with the same WO and approval. The existing clone-only grant/security regression remains.

**Cleanup proved in operator log:** Production Work Order/Intake fingerprint unchanged, shared checkout unchanged, localhost 8898 listener released; server `WO419 DISPOSABLE BROWSER REVIEW: HOLD (status 1)`. No browser UI opened, no saved WO or Setup task committed, no email/Directus Flow/Production change.

**Retry gate:** only after exact successor SHA source tests PASS. Use existing clean workstation branch, **same** Server Management sequential 8898 wrapper and authorized Manager reviewer, with dump→private disposable clone→read/native rollback and linked Setup gate acceptance. If next step HOLDS, retain the new phase and report, do not bypass grants or mutate Production; continue #419 PR #420. No competing runner/DB.

## October 19 — latest disposable browser attempt HOLD: clone IP string formatting

**Operator report:** exact candidate `f4afad0b82ab7748cfd9c6578465e32d782d4e3f`; server acceptance report
`/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261019T101641.txt`.
Source application regressions **836 passed, 5 skipped (Setup); 209 passed (FieldWiring); 65 passed (#419)**. Production pg_dump, PostGIS final PID1 readiness and private clone restore PASS; clone-only grants/action/outbox fixture installed. Ledger verification returned original WO-372, WO-418 and INTAKE-40/57/60. Manager aging report validated **58 open WOs including one inactive/undated exception**.

**Actual HOLD:** `clone_write_transaction_rollback` failed with `Write target is not the verified clone.` The read-side PostgreSQL query logged `inet_server_addr()::text` as `172.18.0.5/32`; server runner supplied the same private clone's Docker inspect `IPAddress` as a bare address `172.18.0.5`. `CloneCommands.transaction` compared the text representations literally, so the mask caused a false mismatch. This was a **clone identifier serialization error**, NOT an observed schema/SQL/Testing/assignment failure (those mutations never ran).

**Correction:** the existing writer now queries `host(inet_server_addr())`, which produces PostgreSQL's host address without its CIDR mask; the strict expected `msb_wo419_preview` database name, same exact Docker-derived clone IP, separate clone authorization secret and authenticated linked Person audit check are unchanged. Read-side stage output also uses `host()` for comparable diagnostics. The source/fake connection regression covers matching `172.18.0.5` versus previous logged `172.18.0.5/32` formatting, and denies wrong IP, Production database, wrong clone authorization token and missing active linked Person. No broadening of authorized database or another runner/port.

**Cleanup proved by operator report:** Production Work Order/Intake fingerprint unchanged; shared repository checkout unchanged; port 8898 not listening; server runner ended `WO419 DISPOSABLE BROWSER REVIEW: HOLD (status 1)`, followed by workstation exception. **No browser READY, no V0.3 UI or write acceptance.**

**Next:** after new exact-SHA GitHub source CI PASS, use the existing Windows wrapper/branch/8898 profile and authorized reviewer; reuse the same current-Production dump→private clone→source tests→rolled-back native write preflight→browser sequence. If it HOLDS on actual native schema/privileges, retain the phase/report and correct that defect on PR #420. Do not bypass the clone identity check or deploy/send to Production. **Source CI PASS alone is not a server/database or browser acceptance.**

## Aging report acceptance — Manager all open by original created date

In the same Manager browser session and on the same private current-Production clone, select **Open Work Order Aging Report**. This is a **report**, not the normal 80-row work queue.

1. Require full native `date_completed IS NULL` population, including `is_active=false` exceptions, independent of Show completed or My Work assignment scope. The clone validator counts native ops.work_order undated rows and compares with the report **before browser READY**.
2. Verify **oldest original `created_at` first**, days elapsed from creation, priority, assignee, human description/location and inactive exception labels. Change sort to newest, priority both ways and numeric WO number both ways. Do not allow lexical ticket-number ordering.
3. Verify 0–7, 8–30, 31–60, 61+ day aging counts, unassigned and inactive exceptions. Export CSV and verify that the export includes **every report row**, not only visible rows. Clicking WO number must open native ticket detail.
4. Reopen the same application through an approved Production Crew preview identity **in a separate sequential clone session**. The aging option must not be available, and direct API access must return 403. Verify Crew My Assigned Work and Create/Complete remain unaffected.
5. Review examples WO-372/400/107/147/389/416 where present. Do not correct Production data; all preview saves remain disposable. Confirm no-send mail and server-side CLEAN EXIT before finalizing acceptance.

No new runner, port, Production deployment, or email permission is introduced by this report.

## Current #419 seasonal-work and January handoff gate

The same exact-SHA disposable runner tests native Work Order Create/Assign/Complete **plus** an optional rollback-only **linked 2026/other open Setup season GATE** when a real ACTIVE/PLANNING season is present. This calls the accepted, Manager-authorized `ops.create_setup_season_task` function inside the same private clone transaction, requiring `SEASON_ONLY`, a null reusable task key, `linked_work_order_id` and `linked_work_order_gate`. No direct `ops.setup_session_task` INSERT/UPDATE permission or second runner was introduced. On any SQL/permission/trigger error the candidate MUST HOLD before BROWSER REVIEW READY; no one should bypass that with manual Production SQL.

In browser, test Manager direct Create+annual task, Manager Add to seasonal Setup on a Crew-created existing Stage Work Order, Crew-only Setup review flag (no unauthorized annual writes), and duplicate/closed-season rejection. Reopen the Work Order to see the retained linkage event, and use the existing Setup Board to verify waiting/complete semantics. Both reviewers must finish with server-side CLEAN EXIT and unchanged Production fingerprints. These are still **candidate** workflows; do not treat CI PASS as disposable server/browser acceptance.

Separate [#423 2027 Takedown](https://github.com/Gregovate/MSB-Production-Database-Project/issues/423) tracks the January 1 release deadline under #122/#88/#230/#231 without changing the #419 runner.

## V0.3.1 role-specific browser checks — two real reviewer identities

The next source candidate must be reviewed through **the same** approved Server Management PowerShell wrapper and sequential localhost port 8898. Do **not** create a second runner or simultaneous preview. This role change does not authorize Production writes or outgoing email.

**Manager session:** Choose an existing linked Manager identity in the approved wrapper. After exact-SHA regression, current-Production private PostGIS clone restore, native Create/Assign/Complete rollback preflight and WO419 BROWSER REVIEW READY, verify the homepage automatically shows pending **Public Intake** and separate Task Feedback counts, with buttons into each Manager queue. Create a disposable Work Order; assign and reassign multiple exact People; triage retained public Park/Workshop Intake (one-step Promote & Assign), verify saved original Intake no longer appears as *pending*; use Testing Repair and urgent/unassigned queues; sort every view by priority both ways and Work Order number both ways.

**Production Crew session:** Close the prior review with server-side CLEAN EXIT and unchanged Production fingerprints first; run the **same wrapper again**, with a separate approved actual Crew identity and fresh private clone. Crew homepage must show only My Assigned Work, Work Orders I Created, My Submitted Feedback, Create and completion of genuinely assigned WOs. Verify an internal Create saves natively without a fake public Intake or self-assignment and appears in Work Orders I Created. Verify required completion notes and person attribution. No manager Intake badge/queue, no manager assignee selector/triage, and direct attempts against Manager endpoints return 403. Sort the Crew's authorized lists by both priority and numeric number.

**Public form:** The external Work Order Request link navigates only to the existing MSB portal, where the current public Park/Workshop Google Form remains available. Do not test by submitting to the live form or alter Apps Script. This form is distinct from authenticated Crew Create.

Retain both review reports, exact SHA, and server-side CLEAN EXIT outcomes. The historical V0.2 **CHANGES REQUIRED** finding remains, and V0.3.1 operator acceptance is pending. Both sessions must keep outgoing notifications NO_SEND; no Production deployment or Flow cutover.

## V0.3 disposable-write operator review — after source CI PASS only

The operator's prior workstation tunnel reported CLEAN EXIT. That is a workstation transport result, **not independent evidence of server-side CLEAN EXIT or unchanged Production database fingerprint**. The V0.2 review was CHANGES REQUIRED. The next review intentionally allows real writes to the disposable clone, as with prior Setup browser acceptance; all writes disappear at cleanup and no email is sent.

**Existing launcher/port/branch remain unchanged.** After a new exact source-only GitHub Actions PASS and a clean branch checkout, use the same PowerShell wrapper below with the new HEAD, explicit port 8898 and a named approved reviewer. The runner must restore the isolated PostGIS clone, install the clone-only authorization/action SQL in the same source worktree, validate the current Manager catalogs, and perform an automatic Savepoint-rolled-back native Create/Assign/Complete preflight. On failure it must print HOLD, tear down owned disposable resources and retain the evidence report; DO NOT manually bypass a failed preflight or repurpose Production permissions.

**Browser review after WO419 BROWSER REVIEW READY:** MSB logos and light/dark mode match Setup; top-bar Manager Create; ticket-local Assign/Reassign (multiple real volunteers), completion notes and actual clone save; separate public Intake triage, Testing repair, Task Feedback owner/clarification/reply/disposition; saved actor/time and no-send activity; reporter history; user-role negative paths. Use real-shaped WO-372/400/107/147/389/416 and Intake-60/40/57 without modifying Production. Verify a saved clone WO appears on refresh and that linked Testing behavior is truthful.

**Exit:** Press ENTER; require server message WO419 DISPOSABLE BROWSER REVIEW: CLEAN EXIT, unchanged Production Work Order/assignments/Intake fingerprint, shared checkout unchanged, listener released and private clone discarded. Workstation tunnel CLEAN EXIT by itself is not a substitute. Keep report path and findings in owning PR. No Production send, schema deployment, Flow cutover, or Directus bookmark change.

## V0.2 operator workflow rehearsal candidate — CHANGES REQUIRED, source-only

The current branch's V0.2 read-only candidate extends the first completed browser's **CHANGES REQUIRED** finding; it is **not** full P0 workflow acceptance. The separate subsequent PostGIS first-restore HOLD and final-server readiness fix remain documented below. The existing **same** server runner and protected localhost 8898 profile are reused, not cloned or bypassed.

**After latest source CI success**, from the existing clean local branch checkout use the same governed wrapper, supplying the exact current branch SHA and an explicitly approved reviewer Person:

```powershell
git pull --ff-only
$sha = (git rev-parse HEAD).Trim()
.\WorkOrders\Acceptance\run_work_management_disposable_browser_preview.ps1 -CandidateSha $sha -PreviewPort 8898 -PreviewEmail 'REPLACE-WITH-APPROVED-REVIEWER@sheboyganlights.org' -ApprovedReviewProfile
```

The uppercase reviewer placeholder is documentation only and **must not** be used literally. Wrapper enforces branch, clean checkout, SHA, email, local listener and remote ownership. Do not open the browser until the runner reports `WO419 BROWSER REVIEW READY`; if HOLD, retain output and do not improvise or deploy. The new clone validator verifies active People, Task Types, Stages and Work Areas for Manager users. All actions in the browser's **Operator workflow review** remain no-save; their validated summary cannot be used to claim an assignment, completion, Intake promotion or reporter email was persisted.

**Review checklist (still no database writes):** My Work/all/person/completed; My Submitted Feedback and original reporter identity; Manager Critical/Unassigned/General/Testing/Public Intake/Feedback distinct queues; `WO372`, `WO-416`, Testing repairs, `INTAKE-60` and retained public Intake where present; light/dark theme; directly create without invented Intake; exactly one Park Stage or Workshop Work Area; select multiple existing People; required completion notes; specific feedback clarification and reasoned closure; negative user permissions; confirm the no-save truth is conspicuous. Original field findings WO-372/400/107/147/389/416 are **evidence and human-review targets**, never test-mutation instructions.

**After review:** press ENTER in the foreground SSH console, inspect final `WO419 DISPOSABLE BROWSER REVIEW: CLEAN EXIT`, unchanged Production Work Order/assignment/Intake fingerprint and preview listener removed. Store screenshots/findings and the retained acceptance report path on this PR. Missing READY/CLEAN EXIT or any validation drift is HOLD, not acceptance. Next engineering work is durable clone-only actions and no-send notification tests before Production authorization is even considered.

## Authorities

- [Work Orders design](../../Docs/02_Production_Database/01_System_Architecture/06_Work_Orders/Work_Order_System_Design.md) governs identities, Stage Related Information, and P0 acceptance.
- [Server Management PostgreSQL Disposable Acceptance Standard](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/PostgreSQL_Disposable_Acceptance_Standard.md) controls clone isolation.
- [Server Management Pre-Production Browser Review Runbook](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Pre_Production_Browser_Review_Runbook.md) controls temporary listener, SSH, runtime, reviewer identity and cleanup.
- [Application and Test Port Register](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Application_and_Test_Port_Register.md) owns port allocation. [Merged Server Management PR #80](https://github.com/Gregovate/MSB-Server-Management/pull/80) authorizes #419 **sequential, pre-Production reuse of existing localhost 8898**. The listener state is **not known** until the runner checks it. No Setup or #395 review may be stopped to free that listener without its own governed recovery.

## Feature-owned disposable profile files

| Existing #419 candidate file | Responsibility |
| --- | --- |
| run_work_management_disposable_browser_preview.ps1 | Windows SHA, branch, reviewer, port, local-listener and byte-digest checks, foreground SSH tunnel |
| work_management_disposable_browser_preview_server.sh | Server-side clone/port/identity/source/Flask readiness, clean-exit and fingerprint assertions |
| wo419_preview_clone_read_grants.sql | **Clone-only** PostgreSQL read grants; never apply to Production |
| validate_work_management_clone.py | Exact-SHA read checks for real current Work Orders and Setup Feedback |
| ../Application/preview_entry.py | Localhost Flask profile that injects only the runner-selected existing MSB reviewer |

The server runner follows the existing Standard: verify live services/listener, detached exact-SHA worktree, source regression, pg_dump from Production, isolated PostGIS Docker clone, read-only clone role, feature SQL validator, temporary localhost browser and controlled teardown. It never switches the live application checkout, creates Production records, emails volunteers, or alters Directus Flows. A distinct clone name is necessary but insufficient: validate private Docker network/container IP and no published clone DB port.

## Controlled Windows operator invocation — pre-Production review profile approved

From a clean local feature-branch MSB Database checkout, with the exact review commit checked out and the approved Person email:

PowerShell:

    $sha = (git rev-parse HEAD).Trim()
    .\WorkOrders\Acceptance\run_work_management_disposable_browser_preview.ps1 -CandidateSha $sha -PreviewPort 8898 -PreviewEmail 'approved.person@sheboyganlights.org' -ApprovedReviewProfile

Replace that sample reviewer with the **real explicitly approved existing person**. This is the **approved pre-Production review invocation**, subject to current worktree SHA/source gates, a free local/remote listener and successful clone isolation; it is not Production deployment approval. The wrapper refuses to start without the approved-profile switch, current branch/SHA match, clean checkout and free local listener. The remote runner must similarly prove the server listener unused and live services unchanged. Do not open the localhost URL until **WO419 BROWSER REVIEW READY** is printed.

At READY, review My Work, All, another assignee, Show completed, current Intake and WO examples, the **collapsed Related Information** section, Stage-level Kit/Container/Display/material resources and honest "Stage-related" vs "task-linked" labels. Browser interactions in this V0.1 are read-only.

Press ENTER in the SSH session when done, and require the exact **WO419 DISPOSABLE BROWSER REVIEW: CLEAN EXIT** report with unchanged Production fingerprints. If transport fails or a listener remains, stop and inspect recognized owner/state before retry; never kill unknown processes.

## Automated preflight

The [source-only Work Management CI workflow](../../.github/workflows/wo419-work-management-source-tests.yml) is committed in draft PR #420. It checks Bash parsing, Python module compilation, Node JavaScript parsing, fake-repository Flask tests, and the DB-owned ledger/design contracts. It does not have server credentials and cannot touch Production. **A committed workflow is not a passing workflow: no GitHub Actions PASS has yet been reported for this candidate.** The server runner independently repeats feature tests before creating a clone. If CI/source tests fail, correct them and pin a new exact SHA before asking for browser review.

## Laptop source regression receipt — 2026-10-18

**Operator-run PASS (source/fake-repository only):** In the clean Windows laptop worktree `C:\\lor\\ImportExport\\MSB-WorkOrders-419` on branch `issue-419-unified-ticket-read-model-20261018`, commit `8a6d55df64a156af51294c3e7eaec2f40508534d`:

```text
python -m pytest -q -p no:cacheprovider
  WorkOrders/Application/test_work_management_preview.py
  WorkOrders/Acceptance/test_work_management_disposable_profile.py
  Database/Acceptance/test_wo419_unified_ticket_read_model.py

29 passed, 1 skipped in 0.28s
```

The prior exact-wording source guard in `test_419_testing_origin_is_explicit_and_not_a_fake_intake` was corrected to match the existing engineering design; this run has **zero failures**. The one skipped test's reason was not printed in the operator's `-q` output; the profile suite explicitly skips Linux/Bash syntax validation when `bash` is unavailable. **Linux `bash -n`, revised PostgreSQL query against a current-Production disposable clone, live Flask browser, authorized reviewer/port checks and P0 write/email workflows have NOT been accepted.** The resulting receipt does not establish an isolated clone or browser READY.

## Linux GitHub Actions source gate — 2026-10-18

**PASS** for commit `8871a796847f635b1108b3f00f1989455fc159e9`, GitHub Actions run **39127213541** (`Work Management` / `source-only-regression`). Source checkout, Python 3.12 install, `bash -n` on the Work Management server runner, Python module compilation, `node --check` for the browser JavaScript, isolated fake-repository Flask/Work Management/DB-contract pytest suites, and the no-Production-contact step all concluded **success**. This follows the laptop **29 passed, 1 skipped** receipt above; the Windows-only Bash skip was exercised in Linux CI.

Immediately preceding the gate, source-only runner fixes streamed the host-side clone grants file through Docker `psql` **stdin** and corrected the SQL approval marker's actual line terminator. The new source regression protects those invariants. This **does not prove** the disposable restore, live-schema SELECT, Flask/DB integration, port-owner check, authorized user, Production fingerprint or browser interaction. Those must be executed and reported separately by the governed runner. **Production was not contacted by the GitHub Actions job.**

## First live disposable run: PostgreSQL post-init readiness HOLD — 2026-10-18

**Operator-provided evidence:** In a foreground laptop SSH review at pinned candidate `5bc230a84c998a61740067f74234d998f8616eae`, all **25 detached candidate source tests PASSED** before clone creation. The current Production `pg_dump` was captured successfully. During `pg_restore` into the **new disposable PostGIS container**, the connection closed unexpectedly while reporting a `COMMENT ON COLUMN ops.controller_label_batch_item.line1` statement. **Do not infer the COMMENT or Work Management schema is invalid.** Runner teardown completed: Work Order/Intake Production fingerprint unchanged, shared checkout unchanged, preview port no longer listening. Status was **HOLD (1)**; report `/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261018T131424.txt`. There was **no** Work Management BROWSER REVIEW READY or browser acceptance.

**Governing known failure mode, discovered by reading the existing Server Management standard rather than speculating:** [PostgreSQL Disposable Acceptance Standard → PostGIS Disposable Initialization / Readiness Contract](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/PostgreSQL_Disposable_Acceptance_Standard.md#postgis-disposable-initialization--readiness-contract) documents that `postgis/postgis:16-3.5` starts a **temporary initialization Postgres server**, for which `pg_isready` may report success, then intentionally shuts it down to start the final server. The #419 source launcher was incorrectly checking **`pg_isready` alone**. This known race closely matches the observed restore disconnect, **but the retained output has no captured clone PID1/log evidence to establish the precise failure cause conclusively**.

**Required corrective source gate BEFORE retrying:** Reuse the standard's three-part bounded readiness test (**Docker container still Running; `/proc/1/comm` equals `postgres`; `pg_isready` succeeds**) before `createdb`, `pg_restore` or validation; fail closed with clone state and limited diagnostics if not established. Preserve existing same-image, host vs Docker path, Production fingerprint and clean-exit gates. Add feature-owned source regression that specifically prevents reintroduction of `pg_isready`-alone. If the next restore disconnects **after final PID1 has been confirmed**, STOP and inspect Docker exit/OOM state and PostgreSQL logs before any further change; do not relabel this incident as proven OOM.

**Remediation source evidence:** The reviewed runner now waits for the final `postgres` PID1 and container Running status **in addition to** `pg_isready` before database creation and restore. On failure, it captures bounded disposable container state/logs before teardown, including the OOM-killed indicator, rather than guessing. A new source regression checks readiness ordering; Linux GitHub Actions `Work Management` run [39130994564](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/39130994564) **PASSED** for code SHA `e9cf31e66cc4c8e0fc027202515b63e1ea30bf0c`. Later documentation commits require checking the **new** exact HEAD source gate again. **This remains an isolated disposable infrastructure readiness fix**, not a change to Work Order schema, Production roles, services, Directus Flows, or reporter notifications. Pin and test the final amended SHA before the next operator-run attempt.

## Second live disposable run: restore PASS, read-validator HOLD — 2026-10-18

**Operator-observed evidence at pinned SHA `949d377300212ddfc32f903f4a1b85af37e8adf7`:** the final PostGIS server readiness gate PASSED; Production dump and disposable `pg_restore` PASSED; clone-only role and read grants applied. The next phase, `validate_work_management_clone.py`, returned a generic unexpected-exception HOLD, so the real query/role/schema cause is **not yet determined** and **browser READY was never reached**. The retained report is `/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261018T132654.txt`. Cleanup again reported an unchanged Production Work Order/Intake fingerprint, shared checkout and free preview port. Do not say the clone failed to copy: the clone was restored and then deliberately deleted during HOLD cleanup.

**Regression/process finding:** this profile had only executed 25 focused source tests, in contrast to the established disposable Setup acceptance path's full `Setup/Application`, GIS preview and `FieldWiring/Application` regression. The candidate branch has been corrected to run all of those **before** the #419 feature contracts and before the Production dump. A source regression guards their presence and ordering. A progress-display regression was also found: the #419 runner omitted the prior operator-visible dump/restore transfer progress. The branch now uses `pv` when installed (with an explicit no-progress fallback), without sacrificing pipeline failure detection. These are tooling changes, not new Work Order product requirements.

**Current gate:** source changes are unmerged and must pass Linux CI and actual controlled disposable retry. The unexpected validator exception has only been classified safely so far, not root-caused; no P0 functionality or browser acceptance is implied. Keep protected logs/PII out of GitHub; any further detailed diagnostics should be scoped to a named failing phase and sanitized. The operator is not responsible for debugging restore scripts or completing the regression suite by hand.

## Corrected exact-candidate CI regression gate — October 18

At candidate `1aade5888eb6fb9936911df812f3ae3d2c254054`, GitHub Actions Work Management source CI run
[39179779076](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/39179779076)
PASSED: 33 #419 source/Flask/profile tests, 841 complete Setup/GIS tests,
and 209 FieldWiring application tests (1,083 tests total). Bash, Python,
JavaScript and PowerShell parsing also passed. The preceding source-gate HOLD
was a false-negative ordering regression that matched an explanatory `pg_dump`
comment rather than the actual dump invocation. The test now targets the
actual command. The existing workflow's source-only restrictions remain in
place, so this receipt establishes **no disposable clone execution, live
read-query PASS, browser READY, or application acceptance**.

The active main-branch Engineering Compliance required check initially failed
because the existing #420 PR body did not provide the required named evidence
fields; its body was updated without changing the controlling design.
Follow-up [check run 39179836986](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/39179836986)
PASSED. A later documentation commit must be retested at its own exact SHA.

**Next gate remains a controlled, current-Production private disposable clone
and read validator; the previously successful restore followed by read-validator
HOLD must not be misreported as a failed dump. Do not conduct operator browser
review until query assertions and application health pass. Keep P0 write/email
behavior separate from V0.1 read-only review.**

## Read-validator diagnostic checkpoint — 2026-10-18

The previous disposable database restored successfully, but the read validator failed before browser READY. The exact cause is not established. This branch now reports the failing validation phase and exception class without exposing query text, reporter details, or credentials. Source regression protects those phase markers. The next private-server execution remains necessary to identify the actual database failure. No browser or Production acceptance is claimed.

## October 19 — candidate identity HOLD after successful clone restore

Operator run on candidate `d81c2de6438ad8216f6f0d2f0bd13cacf589732b`
passed 836 Setup tests (5 skipped), 209 FieldWiring tests and 34
Work Management tests. Private PostGIS final readiness, dump/restore, role
creation and clone grants passed. The validator then failed during
`candidate_identity` with `CalledProcessError`, before querying any
Work Order records; cleanup preserved the Production fingerprint, shared
checkout HEAD and port. Retained report:
`/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261019T002340.txt`.

**Root-cause boundary:** the detached worktree's Git metadata points into
root-managed shared repository metadata; the restricted `fieldwiring` account
must not be given broader Git access. The existing privileged runner now
verifies the detached commit's exact SHA using `sudo git`, checks it against
the requested candidate and passes the verified SHA to the restricted
read-validator. The validator fails closed for a missing/mismatched proof
without trying to traverse shared Git metadata. The source regression
protects this division. There is no change to Production permissions,
PostgreSQL schema, Docker layout or the authorized clone workflow.
Next: exact-commit CI and a new private disposable clone/query/browser gate;
**no browser READY or Production authorization established yet**.

## Remaining acceptance gates

Run and correct Python source tests, revised WO419 PostgreSQL read model and clone audit before calling the first browser review READY. #419 P0 **atomic triage/Promote & Assign, alternate Setup corrections, original-reporter Request More Information/replies, final resolution emails and noncompeting Directus cutover are NOT implemented or accepted**. No temporary read-only preview can waive those future gates.

This README is the acceptance handoff. As authored, these scripts exist as source on draft PR #420, but the clone/browser has **not run on the server**, and Server Management port/profile PR #80 **merged**; port/clone/browser readiness remains unproven until an actual server run.
;`) and a second accidentally appended partial SQL function/grants suffix after the first `COMMIT`. The special `

**Operator evidence:** Laptop invoked the existing `run_work_management_disposable_browser_preview.ps1 -V1Validation` candidate `c0c1f5518accad0638ec2ca4a84429a3bb480538`. Original server report: `/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261020T004438.txt`.

**Verified first gate:** Current Production data restored privately to `msb_wo419_preview`, network address `172.18.0.5`. Existing unified read projection passed, including `INTAKE-40`, `INTAKE-57`, `INTAKE-60`, `WO-372` and `WO-418`. Manager My Work=20, All sampled rows=100, 12 assignee choices, full aging=58 open including one inactive exception; validated catalog authority. This is **read/preflight** acceptance, not the new V1 migration.

**Failure:** `WORK MANAGEMENT #419 DISPOSABLE READ ACCEPTANCE HOLD at clone_write_transaction_rollback: Target year applies only to Planning (urgency 5).` Source `WorkOrders/Acceptance/validate_work_management_clone.py` still provided `urgency=3` **and** `target_year=2026` in a legacy preflight fixture, which contradicted Tom's accepted October 19 *non-Planning target year absent* rule. Its Crew branch also still attempted Crew native Create, contrary to the new Intake-first authorization. The runner correctly stopped before `validate_v1` SQL migration. Do not misreport that V1 SQL failed or passed—**it was not reached**.

**Observed cleanup PASS:** `PASS: verified Work Orders listener stopped; disposable teardown permitted`; `PASS: owned disposable clone removed`; `PASS: disposable candidate worktree unregistered`; `PASS: Production Work Order/Intake fingerprint unchanged`; `PASS: shared checkout HEAD unchanged`; `PASS: preview port no longer listening`. Runner exit `HOLD (status 1)` reflects failed validation. No manual cleanup/retry of abandoned state is required.

**Correction in existing PR #420:** Preflight uses `urgency=3,target_year=None` and replaces obsolete Crew-direct-create positive rehearsal with a transaction-denied 403 assertion, using the same existing Intake path. Added guard tests to detect reintroduced non-Planning years and Crew direct Create before a real clone test. Also corrected the proposed V1 grant contract: `work_management_app` needs **SELECT only** on `ops.work_management_activity` so the existing Manager Intake and Task Feedback read projection can resolve durable V1 activity; no new outbox SELECT, native Work Order DML, or notification sends. This was identified by source inspection and **has not been applied to a clone or Production yet**.

**Next gate:** Run exact new candidate SHA once with the same original `-V1Validation` path. Require a `WO419 V1 DISPOSABLE SQL VALIDATION PASS` **and** full server/laptop CLEAN EXIT before claiming V1 PostgreSQL acceptance; if HOLD again preserve the new report and inspect phase first. Never claim browser/Production acceptance based on source CI.

---

## October 19 — V1 native PostgreSQL disposable validation, no browser (new acceptance mode)

**Purpose:** Before asking for another Work Management browser review or any Production V1 release, run the proposed `WorkOrders/Database/001_work_management_v1_governed_commands.sql` against the **existing current-Production private disposable database clone**, *not* Production. The existing #419 runner and its established **8898 sequential review profile** now have one optional `validate_v1` start mode, selected by the laptop's existing `run_work_management_disposable_browser_preview.ps1 -V1Validation` flag. It does not start a Flask browser/listener, alter `/opt/fieldwiring`, deploy a service, or use a new SSH workflow/port.

**Laptop:** From the existing clean BLUE `C:\lor\ImportExport\MSB-WorkOrders-419` worktree on `issue-419-unified-ticket-read-model-20261018`, refresh the pinned candidate SHA, then invoke the exact existing PowerShell launcher with `-CandidateSha <exact SHA> -PreviewPort 8898 -PreviewEmail 'gliebig@sheboyganlights.org' -ApprovedReviewProfile -V1Validation`. Keep the terminal open during the initial full Setup, FieldWiring, Work Orders regressions and PostgreSQL pg_dump/clone restore.

**What runs:** The normal server runbook checks a clean shared checkout, source ancestry, exact SHA, registered port ownership, Production Work Order/Intake before fingerprint, full Setup/FieldWiring/#419 tests, and a private Docker PostGIS 16 restore. On that **private clone only**, it installs the new `work_management_app NOLOGIN` test role and executes V1 SQL with the clone authorization marker (Production always requires a *different explicit* maintenance authorization marker). `wo419_v1_disposable_validation.sql` then opens a transaction, grants the exact verified reviewer temporary Work Order Manager authority **inside the clone only**, checks native Create→Assignment→Progress→Complete, idempotent retries, rejection of native non-Manager Create, promotion of a real unpromoted public Intake on the clone with original Intake provenance, lack of browser direct native DML, and held/no-send outbox records. Its entire fixture is rolled back. The owned private Docker clone/worktree/dump are then removed with the corrected exact-owner cleanup and Production Work Order/Intake fingerprint and shared source HEAD checked again.

**Acceptance criterion:** `WO419 V1 DISPOSABLE SQL VALIDATION PASS` followed by `WO419 DISPOSABLE BROWSER REVIEW: CLEAN EXIT` on the **server** and `WO419 V1 disposable SQL validation: CLEAN EXIT` on the **laptop** (this status is **SQL-only**, not browser/operator acceptance). Keep the retained server report path. On any `HOLD` or nonzero exit, **do not rerun** or manually kill port 8898: preserve report and inspect exact owner/phase before adjusting source. The new mode does not automatically SSH-resume a failed SQL run because no approved browser state exists to resume. No Production table or role changed, no emails sent, no approved V1 deployment.

**After clone PASS:** Next engineering gate is to exercise real V1 Manager/Crew browser paths on the same disposable database + candidate V1 schema, including required app identity, native commands, Task Feedback, Testing and no-send, before requesting V1 operator acceptance. The current `start` mode still exercises the earlier clone-only `CloneCommands` path; it **does not establish V1 acceptance**.

---
## October 19, 16:39 — Work Orders browser cleanup HOLD, owner-verified recovery, and root correction

**Operator impact:** Candidate `14f4a15a5118401ba084aed87f3f25146419c3d2` completed an operator review on the Command Center PC. When the operator pressed ENTER to finish, the existing WO419 shell runner printed:

```
HOLD: preview PID command mismatch; no broad process kill
PASS: shared checkout HEAD unchanged
HOLD: preview listener remains after cleanup; inspect exact PID before retry
WO419 DISPOSABLE BROWSER REVIEW: HOLD (status 83)
Retained report: /home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261019T202331.txt
```

It **removed the disposable database/worktree before proving the Flask listener was gone**, leaving a broken, orphaned Python process on the shared sequential port 8898. The subsequent read-only server check identified exactly `PID=3469910`, `PGID=3469910`, `SID=3469910`, `fieldwiring`, `/tmp/msb-wo419-preview-candidate-20261019T202331-3468774/WorkOrders/Application/preview_entry.py`, port `127.0.0.1:8898`, **no #419 Docker containers**, and **no resume state**. The operator then ran the exact-identity-gated targeted PID stop and explicitly reported:

```
PASS: Exact orphaned #419 browser verified.
PASS: Port 8898 released.
WO419 ORPHANED BROWSER PROCESS CLEANUP COMPLETE
```

**Root cause:** The source recorded the background launch handle `$!` from `setsid python ... &` as if it were the actual serving PID. `setsid` can fork when its launch handle is already a process-group leader, yielding a different Flask PID. The cleanup compared the wrong PID, correctly refused a broad kill, but wrongly continued deleting the clone/worktree. This is a **browser process ownership/lifecycle defect**, not a WO/Intake data failure.

**Source correction on existing PR #420:** In the existing `WorkOrders/Acceptance/work_management_disposable_browser_preview_server.sh` only, resolve the **real bound listener PID** from `sudo ss -H -ltnp` after Flask health is ready, then verify exact NUL-delimited `/proc/PID/cmdline` argv (`/opt/fieldwiring/.venv/bin/python` + exact candidate `WorkOrders/Application/preview_entry.py` path), numeric `fieldwiring` UID, PGID and SID equal to actual listener PID, and unique port ownership. Store that verified PID in the 0600 reconnect state instead of the untrusted launch handle. On operator completion or failure, attempt a narrow TERM against **only** the freshly verified listener PID; escalate KILL only if that **same exact validated PID** still owns the port. **Any ambiguous/foreign/unverified port halts cleanup without touching the clone/worktree/state**, preserving evidence and recoverability. Only after proving port free may runner remove the owned disposable Docker container and git worktree. Independently check container removed, candidate worktree unregistered, state absent, unchanged Production WO/Intake fingerprint (subject to concurrent external writes), unchanged shared checkout HEAD and port free before reporting CLEAN EXIT. No port reassignment, broad `pkill`, guessed PID, process-group kill, Production migration, or server service change.

**Regression:** GitHub source tests run the real extracted Bash cleanup/verification functions against a disposable local `setsid` Python socket, prove unknown candidate owner is **not killed** and its state remains, then prove the expected listener is stopped, port freed and owned state deleted. Other #419 and engineering compliance checks remain required. **Operator-run live server full disposable lifecycle validation is still pending**; source tests are not evidence of a successful real server CLEAN EXIT on this correction. Next test must report normal complete teardown with no `sudo` manual orphan cleanup and preserve retained report path.

**Governance:** MSB-Server-Management `docs/server/Pre_Production_Browser_Review_Runbook.md` and `docs/server/PostgreSQL_Disposable_Acceptance_Standard.md` remain controlling; reuse established current #419 runner and sequential port 8898. #419 PR #420 remains draft. Do not touch #88/#171 sessions, release Production, alter Flow, send notifications, or silently claim browser acceptance.

---

## October 19 — Reuse fault-tolerant Setup SSH review pattern; office feature handoff

**Authority:** [MSB-Server-Management browser review runbook](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Pre_Production_Browser_Review_Runbook.md), plus [reusable Setup reconnect contract](../../Setup/Acceptance/README.md#recoverable-browser-preview-transport). The September 29 #205 Setup browser review established that an SSH/PTTY disconnect must preserve the actual healthy disposable clone, entered browser changes, and Flask process, and the **same** workstation SSH wrapper must reattach after exact SHA/ref/port/operator/process/clone/version verification. No new runner or port allocation is permitted.

**Observed regression and controlled recovery:** On October 19, the #419 V0.3.2 Manager browser (candidate `b32b48075dce38cb18122c2f84d891f3e0153470`) suffered `client_loop: send disconnect: Connection reset` and workstation SSH exit **255**. The original Work Orders wrapper had no reconnect loop; its remote script used destructive/trapped cleanup logic instead of Setup's resumable state. The operator's read-only server diagnostics proved one abandoned **fieldwiring PID/PGID 3033050**, one Docker-private **`msb-wo419-preview-3031755`** container, and an occupied localhost port **8898**. The approved exact-instance cleanup separately proved `PASS: Exact WO419 preview verified`, `PASS: Port 8898 released`, and `WO419 OWNED PREVIEW CLEANUP COMPLETE`; no #419 container or port listener remained and Production PostgreSQL `pg_isready` returned accepting connections. This is **not a retroactive Production WO/Intake fingerprint PASS** or previous normal CLEAN EXIT.

**Source recovery corrections on existing PR #420:** 
- Single established Work Orders wrapper/runner, exact candidate SHA and sequential shared **8898**; no competing subsystem or test port.
- Shell runner accepts optional **start/resume fifth argument**, writes an owner-private **0600** state file only after browser READY validation, recording no passwords/token/CSRF/DSN. On lost SSH input/HUP after READY it preserves the preview, clone, current test edits, candidate worktree and original evidence. Before READY, failures retain regular controlled teardown.
- Workstation PowerShell wrapper retries transport exits **75/255** (up to 12 attempts) with the **same uploaded digest-verified runner**; no rebuilding private clone and no killing unknown local listeners. A resume verifies exact SHA/ref/port/reviewer, numeric fieldwiring UID, saved preview PID and port ownership, running private container, detached SHA and live `/api/work-orders/health` application version **before** allowing another review or intentional ENTER cleanup. Unknown ownership/state HALTs safely.
- Guard port/state conflicts **before** any pg_dump/clone. The uploaded runner is deleted only after successful normal server teardown; its script is retained on transport loss for verified reattachment. No-STDOUT secret logging or Production DML added.
- Targeted regressions on Linux execute the actual Bash private-state writer (including permissions, content, re-source and overwrite refusal) and fail-closed 4/5/6 argument gates; source contract checks verify same Setup-style bounded PowerShell reconnect, strict identity/ownership, non-destructive mode dispatch and no arbitrary SSH-process termination.

**Acceptance state:** GitHub source tests/Engineering Compliance are necessary but **not evidence that a workstation SSH disconnect/reconnect has been exercised against the real protected browser**. Real fault-tolerance acceptance is pending a later explicit user-approved disposable review when **8898** is available. Do not block ongoing #88 Container Movement / #171 GIS testing while editing #419. Operator UI review remains CHANGES REQUIRED; no Production deployment/email/Flow cutover authorized. Office PC continuation: dedicated `C:\Users\Greg\Github\MSB-WorkOrders-419` blue feature worktree/VS Code window, `git pull --ff-only` only when clean and after fetching exact #419 origin branch. Do not update primary `main` or touch GIS/#88 worktrees.

## October 19 — Tom/Manager review: Intake-only Crew requests, Planning year, Manager privileges

**Source candidate:** Following the Oct 19 in-person Work Orders review, the operator explicitly **reversed the earlier Crew direct-create requirement**. A Crew or other non-Manager reporter uses the same public Park/Workshop Work Order Request Form (`https://forms.gle/Gve4ZbXHDWxs43yh6`), which submits to existing `stage.work_order_intake` for investigation, clarification, approval/promotion and eventual assignment. No new Intake subsystem, Google Form or duplicate WO is authorized. The direct native **Create Work Order** button is Manager-only; the server `CloneCommands.perform(..., 'create', ...)` independently denies any actor lacking verified `can_manage`, even if `can_create` is forged. The existing selector/access policy no longer maps Production Crew to direct `can_create` capabilities.

**Create/Promote defaults:** New actual Work Orders default urgency/priority to **3 — Normal**; Target year is only visible/submitted for **urgency 5 — Planning**, with valid year required for new Planning Work Orders. Non-planning native saves carry NULL target year. Intake requires **no assignments** and **no target year**; assignment is managed during triage/promotion, not on request submission. We **do not claim to change default values inside the third-party Google Form**: its source and Apps Script are separately governed and should be inspected before any public submission defaults are changed.

**Operator permission concern:** Manager capabilities should be deliberately assigned, not inferred from unrelated legacy person flags. User expressed concern about an existing Manager delegation; no named user's authorization, Google Workspace membership, or Directus role has been changed. Role-scope change would require explicit separate authorization and privileges inventory. No Production write, mail send, or Flow cutover.

**Validation:** CI source tests now enforce native Manager-only Create, Crew rejection before any database transaction, existing form link, default urgency 3, Planning-only target year, and retention of Intake/Manager triage. **Source CI PASS does not mean disposable UI acceptance**; hold functional live Manager/Crew browser testing and actual form Intake side effects until review authorized and sequential 8898 available. Preserve active browser data and never force-stop another review.

---
## October 19 — Command Center operator UI review, source corrections, and cross-repo boundaries

**Review verdict: CHANGES REQUIRED.** Command Center PC operated on the accepted isolated #419 browser candidate `72939e3ebf90923347550dd786e3294edbacfcf2`. Screenshots: filter/header layout crowded and clipped; **Create Work Order** exposed the empty "New internal Work Order" panel but no editable fields and repeated its title; Aging Report showed **WO-372** still Open despite Tom reporting physical completion this morning; **WO-389** is a request to assign `RD04-B-03` to Container `C213` (not a mandatory repair Work Order); the `my.sheboyganlights.org` public Google Form button incorrectly said **Submit a Work Order** when it creates a **Work Order Intake** item that a Manager may approve/promote. Person-search usability suggests evaluating whether `ref.person.available_for_work_orders` is redundant, but first audit downstream identities/permissions and notification rules—no field/schema change authorized by feedback. Operator reported `WO419 workstation browser tunnel: CLEAN EXIT`; that is a workstation exit observation, **not** operator acceptance or independent server fingerprint evidence.

**#419 source-only candidate implementation on existing draft PR #420:** responsive filter/actions rows group scope, search, sort separately from completion/planning toggles, Refresh, Create and request link; narrowed input min widths prevent clipping. The direct Create path now explicitly exposes the proper form/fields, focuses work description, advertises `aria-expanded`, and preserves the `create` selection during late reviewer option redraw; removed the duplicate CSS-added heading. Targeted regression tests assert these contracts. **Source regression/CI PASS is not a substitute for real browser functional validation**: next approval review must actually enter and save a disposable Create, test authenticated work-notes and WO completion, reassignment, manager Intake, and normal/logout and SSH disconnect behavior.

**WO-372:** original repair and completion records must be reconciled by authenticated work order workflow with real actual-work notes, credited to the person performing/verifying the job. The fact Tom physically completed it on October 19 is not proof `ops.work_order.done_at` is set; do not invent a timestamp, backdate records, or close Production outside authorized release. If current Production still says Open, that is unrecorded completion, not evidence of an additional physical repair requirement.

**WO-389:** location/home rack assignment belongs to #230 (canonical storage location reference editor), honoring #88 movement/home boundaries. Filed on #230; #419 does not replicate the reference-table editor or update `C213`.

**Portal:** User-requested text change is made as source-only draft [MSB-Internal-Web-Backbone PR #26](https://github.com/Gregovate/MSB-Internal-Web-Backbone/pull/26) (`fix/portal-work-order-request-intake-label-20261019`), retaining the existing public Google Form URL and Manager triage. Publication separately governed by site repo; no website deployment in this PR.

**Release holds:** Prior UI acceptance remains failed until disposable browser functional acceptance; #419 may not deploy/Flow-cutover/send emails or mutate Production Work Order records without explicit new approval. Respect shared sequential port 8898 occupied by any #88/GIS review.

---
## October 19 — Manager disposable browser review: CHANGES REQUIRED, source candidate underway

The operator reached the real protected Work Management browser on the existing current-Production **disposable clone**, reviewed several Manager queues in dark/light modes, and later reported **`WO419 workstation browser tunnel: CLEAN EXIT`**. This confirms a successful exit from the workstation launcher; the exact server cleanup report path/fingerprint for this session was **not pasted**, so do not invent it or claim independent server fingerprint evidence. **Operator UI acceptance was explicitly rejected**, despite the functional Manager pending Intake banner (2 Public requests, 1 Task Feedback) and full Open Work Order Aging Report (58 undated WOs, including one inactive exception) being useful.

**Required repair before next browser handoff:**
- **Work Order execution:** On selected open WO (operator example WO-402, physically completed weeks earlier), show obvious **Add Work Note** and **Complete Work Order** actions immediately at the top of the detail card. Completion form captures actual work notes, then server decides authenticated Person and completion date; do not expose arbitrary Completed By or manually set Date Completed. Save notes without changing completion when progress only. Do not modify WO-402 in Production because it was reportedly finished physically.
- **Manager maintenance:** Put a separate **Manager · Assign / Reassign** button in the Work Order heading, not as an undifferentiated work dropdown. Preserve normalized multi-person assignment history, Manager-only server rights and no-send notification receipts.
- **Create:** One top-bar **Create Work Order** button opens blank native creation fields directly. Remove the generic redundant `Select proposed action` picker from the operator interface; it may remain as internal state but never dictate the visible workflow.
- **Internal navigation:** Browser Back/Forward and explicit **← Back to Work Order list** stay within Work Management and restore selected ticket, authorized queue/filter, planning flag, search, and list scroll. Returning from aging drill-through must not lose the reporting context or exit the application.
- **Planning ideas:** A long-term proposal (WO-105 Area 5 Shelter) must not mingle with normal dispatch. Current urgency **5 = Planning** is the native available category. Use a reversible **Show planning work (Priority 5)** checkbox in every authorized queue **and in the aging report**, default off for day-to-day dispatch. Normal filters exclude only Priority 5, leave unknown priorities untouched and do not delete/mutate/retire historical records. When enabled, full planning records become findable with original metadata. Treat this as an initial view filter, **not an invented durable planning-classification field**.
- **Sorting:** Replace confusing `Critical first / Planning first` names with clear numeric `Most urgent first (1 → 5)` / `Least urgent first (5 → 1)`; numeric ticket IDs and created date remain sortable by both directions.
- **Styling:** Bounded Work Management text-size/readability corrections and #419 components must use established [#159 shared light/dark palette](https://github.com/Gregovate/MSB-Production-Database-Project/issues/159) and [#140 semantic CSS intent](https://github.com/Gregovate/MSB-Production-Database-Project/issues/140), rather than inventing a competing MSB-wide design system. Browser scaling is individual preference, not a substitute for readable app defaults.

**Next controlled run:** Full source regression + same Server Management runner and sequential localhost port 8898, fresh private restore, rollback native WO/Setup gate validation, two role sessions, no-send, no Production changes. Browser must verify actually saving a work note and a completion in the disposable database, reopening via search, Manager Assign/Reassign, Create blank fields, Back, Show Planning off/on incl aging CSV, and light/dark normal font. Need `WO419 BROWSER REVIEW READY`, operator acceptance, then server **CLEAN EXIT/fingerprint** separately. PR #420 draft; no deployment.

## October 19 — second write-preflight HOLD: Setup season read requested unauthorized row lock

**Operator real run:** exact candidate `dc98c63b5e72896aaaeb7898551a34d10a7f4252`; retained server report `/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261019T102500.txt`. The previous `/32` clone-IP mismatch is **fixed and proven** by canonical `172.18.0.5` reporting and progression into the Write/Create/Assign → Setup linkage preflight. Source regressions, current-Production dump/private final-PID1 PostgreSQL restore, read/ledger, 58-open/one-inactive Manager Aging Report, and clone-only write grant/no-send outbox setup all PASSED. The test reached `atomic_work_order_setup_season_gate` and raised `InsufficientPrivilege`, before browser READY.

**Source diagnosis:** `CloneCommands.create_season_only_work_order_gate()` ran `SELECT setup_session_id FROM ops.setup_session ... FOR SHARE` under the clone application role. This requests a PostgreSQL row-level lock, requiring table privileges beyond the deliberately limited `SELECT` on `ops.setup_session`. There is **no justification to grant UPDATE** or broader annual-task DML merely to check if the season is open. The released `SECURITY DEFINER ops.create_setup_season_task` is already Manager-authorized and independently checks season/actor/stage/Work Order. This source-level row lock is the specific likely cause of the observed failure; no full SQL error details were exposed, so live reproduction of that exact statement was not captured.

**Narrow fix:** remove only the unnecessary `FOR SHARE` from the read-only season precheck, retaining selected `ACTIVE/PLANNING` status, existing Manager role, open season/WO duplicate validation, native Setup command and **same PostgreSQL atomic transaction**. Do NOT grant update privileges on `ops.setup_session`, INSERT on `ops.setup_session_task`, or replace the existing Setup command. New restricted-cursor regression fails if the Setup read attempts `FOR SHARE/FOR UPDATE` and proves it reaches `ops.create_setup_season_task` with the same WO and approval. The existing clone-only grant/security regression remains.

**Cleanup proved in operator log:** Production Work Order/Intake fingerprint unchanged, shared checkout unchanged, localhost 8898 listener released; server `WO419 DISPOSABLE BROWSER REVIEW: HOLD (status 1)`. No browser UI opened, no saved WO or Setup task committed, no email/Directus Flow/Production change.

**Retry gate:** only after exact successor SHA source tests PASS. Use existing clean workstation branch, **same** Server Management sequential 8898 wrapper and authorized Manager reviewer, with dump→private disposable clone→read/native rollback and linked Setup gate acceptance. If next step HOLDS, retain the new phase and report, do not bypass grants or mutate Production; continue #419 PR #420. No competing runner/DB.

## October 19 — latest disposable browser attempt HOLD: clone IP string formatting

**Operator report:** exact candidate `f4afad0b82ab7748cfd9c6578465e32d782d4e3f`; server acceptance report
`/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261019T101641.txt`.
Source application regressions **836 passed, 5 skipped (Setup); 209 passed (FieldWiring); 65 passed (#419)**. Production pg_dump, PostGIS final PID1 readiness and private clone restore PASS; clone-only grants/action/outbox fixture installed. Ledger verification returned original WO-372, WO-418 and INTAKE-40/57/60. Manager aging report validated **58 open WOs including one inactive/undated exception**.

**Actual HOLD:** `clone_write_transaction_rollback` failed with `Write target is not the verified clone.` The read-side PostgreSQL query logged `inet_server_addr()::text` as `172.18.0.5/32`; server runner supplied the same private clone's Docker inspect `IPAddress` as a bare address `172.18.0.5`. `CloneCommands.transaction` compared the text representations literally, so the mask caused a false mismatch. This was a **clone identifier serialization error**, NOT an observed schema/SQL/Testing/assignment failure (those mutations never ran).

**Correction:** the existing writer now queries `host(inet_server_addr())`, which produces PostgreSQL's host address without its CIDR mask; the strict expected `msb_wo419_preview` database name, same exact Docker-derived clone IP, separate clone authorization secret and authenticated linked Person audit check are unchanged. Read-side stage output also uses `host()` for comparable diagnostics. The source/fake connection regression covers matching `172.18.0.5` versus previous logged `172.18.0.5/32` formatting, and denies wrong IP, Production database, wrong clone authorization token and missing active linked Person. No broadening of authorized database or another runner/port.

**Cleanup proved by operator report:** Production Work Order/Intake fingerprint unchanged; shared repository checkout unchanged; port 8898 not listening; server runner ended `WO419 DISPOSABLE BROWSER REVIEW: HOLD (status 1)`, followed by workstation exception. **No browser READY, no V0.3 UI or write acceptance.**

**Next:** after new exact-SHA GitHub source CI PASS, use the existing Windows wrapper/branch/8898 profile and authorized reviewer; reuse the same current-Production dump→private clone→source tests→rolled-back native write preflight→browser sequence. If it HOLDS on actual native schema/privileges, retain the phase/report and correct that defect on PR #420. Do not bypass the clone identity check or deploy/send to Production. **Source CI PASS alone is not a server/database or browser acceptance.**

## Aging report acceptance — Manager all open by original created date

In the same Manager browser session and on the same private current-Production clone, select **Open Work Order Aging Report**. This is a **report**, not the normal 80-row work queue.

1. Require full native `date_completed IS NULL` population, including `is_active=false` exceptions, independent of Show completed or My Work assignment scope. The clone validator counts native ops.work_order undated rows and compares with the report **before browser READY**.
2. Verify **oldest original `created_at` first**, days elapsed from creation, priority, assignee, human description/location and inactive exception labels. Change sort to newest, priority both ways and numeric WO number both ways. Do not allow lexical ticket-number ordering.
3. Verify 0–7, 8–30, 31–60, 61+ day aging counts, unassigned and inactive exceptions. Export CSV and verify that the export includes **every report row**, not only visible rows. Clicking WO number must open native ticket detail.
4. Reopen the same application through an approved Production Crew preview identity **in a separate sequential clone session**. The aging option must not be available, and direct API access must return 403. Verify Crew My Assigned Work and Create/Complete remain unaffected.
5. Review examples WO-372/400/107/147/389/416 where present. Do not correct Production data; all preview saves remain disposable. Confirm no-send mail and server-side CLEAN EXIT before finalizing acceptance.

No new runner, port, Production deployment, or email permission is introduced by this report.

## Current #419 seasonal-work and January handoff gate

The same exact-SHA disposable runner tests native Work Order Create/Assign/Complete **plus** an optional rollback-only **linked 2026/other open Setup season GATE** when a real ACTIVE/PLANNING season is present. This calls the accepted, Manager-authorized `ops.create_setup_season_task` function inside the same private clone transaction, requiring `SEASON_ONLY`, a null reusable task key, `linked_work_order_id` and `linked_work_order_gate`. No direct `ops.setup_session_task` INSERT/UPDATE permission or second runner was introduced. On any SQL/permission/trigger error the candidate MUST HOLD before BROWSER REVIEW READY; no one should bypass that with manual Production SQL.

In browser, test Manager direct Create+annual task, Manager Add to seasonal Setup on a Crew-created existing Stage Work Order, Crew-only Setup review flag (no unauthorized annual writes), and duplicate/closed-season rejection. Reopen the Work Order to see the retained linkage event, and use the existing Setup Board to verify waiting/complete semantics. Both reviewers must finish with server-side CLEAN EXIT and unchanged Production fingerprints. These are still **candidate** workflows; do not treat CI PASS as disposable server/browser acceptance.

Separate [#423 2027 Takedown](https://github.com/Gregovate/MSB-Production-Database-Project/issues/423) tracks the January 1 release deadline under #122/#88/#230/#231 without changing the #419 runner.

## V0.3.1 role-specific browser checks — two real reviewer identities

The next source candidate must be reviewed through **the same** approved Server Management PowerShell wrapper and sequential localhost port 8898. Do **not** create a second runner or simultaneous preview. This role change does not authorize Production writes or outgoing email.

**Manager session:** Choose an existing linked Manager identity in the approved wrapper. After exact-SHA regression, current-Production private PostGIS clone restore, native Create/Assign/Complete rollback preflight and WO419 BROWSER REVIEW READY, verify the homepage automatically shows pending **Public Intake** and separate Task Feedback counts, with buttons into each Manager queue. Create a disposable Work Order; assign and reassign multiple exact People; triage retained public Park/Workshop Intake (one-step Promote & Assign), verify saved original Intake no longer appears as *pending*; use Testing Repair and urgent/unassigned queues; sort every view by priority both ways and Work Order number both ways.

**Production Crew session:** Close the prior review with server-side CLEAN EXIT and unchanged Production fingerprints first; run the **same wrapper again**, with a separate approved actual Crew identity and fresh private clone. Crew homepage must show only My Assigned Work, Work Orders I Created, My Submitted Feedback, Create and completion of genuinely assigned WOs. Verify an internal Create saves natively without a fake public Intake or self-assignment and appears in Work Orders I Created. Verify required completion notes and person attribution. No manager Intake badge/queue, no manager assignee selector/triage, and direct attempts against Manager endpoints return 403. Sort the Crew's authorized lists by both priority and numeric number.

**Public form:** The external Work Order Request link navigates only to the existing MSB portal, where the current public Park/Workshop Google Form remains available. Do not test by submitting to the live form or alter Apps Script. This form is distinct from authenticated Crew Create.

Retain both review reports, exact SHA, and server-side CLEAN EXIT outcomes. The historical V0.2 **CHANGES REQUIRED** finding remains, and V0.3.1 operator acceptance is pending. Both sessions must keep outgoing notifications NO_SEND; no Production deployment or Flow cutover.

## V0.3 disposable-write operator review — after source CI PASS only

The operator's prior workstation tunnel reported CLEAN EXIT. That is a workstation transport result, **not independent evidence of server-side CLEAN EXIT or unchanged Production database fingerprint**. The V0.2 review was CHANGES REQUIRED. The next review intentionally allows real writes to the disposable clone, as with prior Setup browser acceptance; all writes disappear at cleanup and no email is sent.

**Existing launcher/port/branch remain unchanged.** After a new exact source-only GitHub Actions PASS and a clean branch checkout, use the same PowerShell wrapper below with the new HEAD, explicit port 8898 and a named approved reviewer. The runner must restore the isolated PostGIS clone, install the clone-only authorization/action SQL in the same source worktree, validate the current Manager catalogs, and perform an automatic Savepoint-rolled-back native Create/Assign/Complete preflight. On failure it must print HOLD, tear down owned disposable resources and retain the evidence report; DO NOT manually bypass a failed preflight or repurpose Production permissions.

**Browser review after WO419 BROWSER REVIEW READY:** MSB logos and light/dark mode match Setup; top-bar Manager Create; ticket-local Assign/Reassign (multiple real volunteers), completion notes and actual clone save; separate public Intake triage, Testing repair, Task Feedback owner/clarification/reply/disposition; saved actor/time and no-send activity; reporter history; user-role negative paths. Use real-shaped WO-372/400/107/147/389/416 and Intake-60/40/57 without modifying Production. Verify a saved clone WO appears on refresh and that linked Testing behavior is truthful.

**Exit:** Press ENTER; require server message WO419 DISPOSABLE BROWSER REVIEW: CLEAN EXIT, unchanged Production Work Order/assignments/Intake fingerprint, shared checkout unchanged, listener released and private clone discarded. Workstation tunnel CLEAN EXIT by itself is not a substitute. Keep report path and findings in owning PR. No Production send, schema deployment, Flow cutover, or Directus bookmark change.

## V0.2 operator workflow rehearsal candidate — CHANGES REQUIRED, source-only

The current branch's V0.2 read-only candidate extends the first completed browser's **CHANGES REQUIRED** finding; it is **not** full P0 workflow acceptance. The separate subsequent PostGIS first-restore HOLD and final-server readiness fix remain documented below. The existing **same** server runner and protected localhost 8898 profile are reused, not cloned or bypassed.

**After latest source CI success**, from the existing clean local branch checkout use the same governed wrapper, supplying the exact current branch SHA and an explicitly approved reviewer Person:

```powershell
git pull --ff-only
$sha = (git rev-parse HEAD).Trim()
.\WorkOrders\Acceptance\run_work_management_disposable_browser_preview.ps1 -CandidateSha $sha -PreviewPort 8898 -PreviewEmail 'REPLACE-WITH-APPROVED-REVIEWER@sheboyganlights.org' -ApprovedReviewProfile
```

The uppercase reviewer placeholder is documentation only and **must not** be used literally. Wrapper enforces branch, clean checkout, SHA, email, local listener and remote ownership. Do not open the browser until the runner reports `WO419 BROWSER REVIEW READY`; if HOLD, retain output and do not improvise or deploy. The new clone validator verifies active People, Task Types, Stages and Work Areas for Manager users. All actions in the browser's **Operator workflow review** remain no-save; their validated summary cannot be used to claim an assignment, completion, Intake promotion or reporter email was persisted.

**Review checklist (still no database writes):** My Work/all/person/completed; My Submitted Feedback and original reporter identity; Manager Critical/Unassigned/General/Testing/Public Intake/Feedback distinct queues; `WO372`, `WO-416`, Testing repairs, `INTAKE-60` and retained public Intake where present; light/dark theme; directly create without invented Intake; exactly one Park Stage or Workshop Work Area; select multiple existing People; required completion notes; specific feedback clarification and reasoned closure; negative user permissions; confirm the no-save truth is conspicuous. Original field findings WO-372/400/107/147/389/416 are **evidence and human-review targets**, never test-mutation instructions.

**After review:** press ENTER in the foreground SSH console, inspect final `WO419 DISPOSABLE BROWSER REVIEW: CLEAN EXIT`, unchanged Production Work Order/assignment/Intake fingerprint and preview listener removed. Store screenshots/findings and the retained acceptance report path on this PR. Missing READY/CLEAN EXIT or any validation drift is HOLD, not acceptance. Next engineering work is durable clone-only actions and no-send notification tests before Production authorization is even considered.

## Authorities

- [Work Orders design](../../Docs/02_Production_Database/01_System_Architecture/06_Work_Orders/Work_Order_System_Design.md) governs identities, Stage Related Information, and P0 acceptance.
- [Server Management PostgreSQL Disposable Acceptance Standard](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/PostgreSQL_Disposable_Acceptance_Standard.md) controls clone isolation.
- [Server Management Pre-Production Browser Review Runbook](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Pre_Production_Browser_Review_Runbook.md) controls temporary listener, SSH, runtime, reviewer identity and cleanup.
- [Application and Test Port Register](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Application_and_Test_Port_Register.md) owns port allocation. [Merged Server Management PR #80](https://github.com/Gregovate/MSB-Server-Management/pull/80) authorizes #419 **sequential, pre-Production reuse of existing localhost 8898**. The listener state is **not known** until the runner checks it. No Setup or #395 review may be stopped to free that listener without its own governed recovery.

## Feature-owned disposable profile files

| Existing #419 candidate file | Responsibility |
| --- | --- |
| run_work_management_disposable_browser_preview.ps1 | Windows SHA, branch, reviewer, port, local-listener and byte-digest checks, foreground SSH tunnel |
| work_management_disposable_browser_preview_server.sh | Server-side clone/port/identity/source/Flask readiness, clean-exit and fingerprint assertions |
| wo419_preview_clone_read_grants.sql | **Clone-only** PostgreSQL read grants; never apply to Production |
| validate_work_management_clone.py | Exact-SHA read checks for real current Work Orders and Setup Feedback |
| ../Application/preview_entry.py | Localhost Flask profile that injects only the runner-selected existing MSB reviewer |

The server runner follows the existing Standard: verify live services/listener, detached exact-SHA worktree, source regression, pg_dump from Production, isolated PostGIS Docker clone, read-only clone role, feature SQL validator, temporary localhost browser and controlled teardown. It never switches the live application checkout, creates Production records, emails volunteers, or alters Directus Flows. A distinct clone name is necessary but insufficient: validate private Docker network/container IP and no published clone DB port.

## Controlled Windows operator invocation — pre-Production review profile approved

From a clean local feature-branch MSB Database checkout, with the exact review commit checked out and the approved Person email:

PowerShell:

    $sha = (git rev-parse HEAD).Trim()
    .\WorkOrders\Acceptance\run_work_management_disposable_browser_preview.ps1 -CandidateSha $sha -PreviewPort 8898 -PreviewEmail 'approved.person@sheboyganlights.org' -ApprovedReviewProfile

Replace that sample reviewer with the **real explicitly approved existing person**. This is the **approved pre-Production review invocation**, subject to current worktree SHA/source gates, a free local/remote listener and successful clone isolation; it is not Production deployment approval. The wrapper refuses to start without the approved-profile switch, current branch/SHA match, clean checkout and free local listener. The remote runner must similarly prove the server listener unused and live services unchanged. Do not open the localhost URL until **WO419 BROWSER REVIEW READY** is printed.

At READY, review My Work, All, another assignee, Show completed, current Intake and WO examples, the **collapsed Related Information** section, Stage-level Kit/Container/Display/material resources and honest "Stage-related" vs "task-linked" labels. Browser interactions in this V0.1 are read-only.

Press ENTER in the SSH session when done, and require the exact **WO419 DISPOSABLE BROWSER REVIEW: CLEAN EXIT** report with unchanged Production fingerprints. If transport fails or a listener remains, stop and inspect recognized owner/state before retry; never kill unknown processes.

## Automated preflight

The [source-only Work Management CI workflow](../../.github/workflows/wo419-work-management-source-tests.yml) is committed in draft PR #420. It checks Bash parsing, Python module compilation, Node JavaScript parsing, fake-repository Flask tests, and the DB-owned ledger/design contracts. It does not have server credentials and cannot touch Production. **A committed workflow is not a passing workflow: no GitHub Actions PASS has yet been reported for this candidate.** The server runner independently repeats feature tests before creating a clone. If CI/source tests fail, correct them and pin a new exact SHA before asking for browser review.

## Laptop source regression receipt — 2026-10-18

**Operator-run PASS (source/fake-repository only):** In the clean Windows laptop worktree `C:\\lor\\ImportExport\\MSB-WorkOrders-419` on branch `issue-419-unified-ticket-read-model-20261018`, commit `8a6d55df64a156af51294c3e7eaec2f40508534d`:

```text
python -m pytest -q -p no:cacheprovider
  WorkOrders/Application/test_work_management_preview.py
  WorkOrders/Acceptance/test_work_management_disposable_profile.py
  Database/Acceptance/test_wo419_unified_ticket_read_model.py

29 passed, 1 skipped in 0.28s
```

The prior exact-wording source guard in `test_419_testing_origin_is_explicit_and_not_a_fake_intake` was corrected to match the existing engineering design; this run has **zero failures**. The one skipped test's reason was not printed in the operator's `-q` output; the profile suite explicitly skips Linux/Bash syntax validation when `bash` is unavailable. **Linux `bash -n`, revised PostgreSQL query against a current-Production disposable clone, live Flask browser, authorized reviewer/port checks and P0 write/email workflows have NOT been accepted.** The resulting receipt does not establish an isolated clone or browser READY.

## Linux GitHub Actions source gate — 2026-10-18

**PASS** for commit `8871a796847f635b1108b3f00f1989455fc159e9`, GitHub Actions run **39127213541** (`Work Management` / `source-only-regression`). Source checkout, Python 3.12 install, `bash -n` on the Work Management server runner, Python module compilation, `node --check` for the browser JavaScript, isolated fake-repository Flask/Work Management/DB-contract pytest suites, and the no-Production-contact step all concluded **success**. This follows the laptop **29 passed, 1 skipped** receipt above; the Windows-only Bash skip was exercised in Linux CI.

Immediately preceding the gate, source-only runner fixes streamed the host-side clone grants file through Docker `psql` **stdin** and corrected the SQL approval marker's actual line terminator. The new source regression protects those invariants. This **does not prove** the disposable restore, live-schema SELECT, Flask/DB integration, port-owner check, authorized user, Production fingerprint or browser interaction. Those must be executed and reported separately by the governed runner. **Production was not contacted by the GitHub Actions job.**

## First live disposable run: PostgreSQL post-init readiness HOLD — 2026-10-18

**Operator-provided evidence:** In a foreground laptop SSH review at pinned candidate `5bc230a84c998a61740067f74234d998f8616eae`, all **25 detached candidate source tests PASSED** before clone creation. The current Production `pg_dump` was captured successfully. During `pg_restore` into the **new disposable PostGIS container**, the connection closed unexpectedly while reporting a `COMMENT ON COLUMN ops.controller_label_batch_item.line1` statement. **Do not infer the COMMENT or Work Management schema is invalid.** Runner teardown completed: Work Order/Intake Production fingerprint unchanged, shared checkout unchanged, preview port no longer listening. Status was **HOLD (1)**; report `/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261018T131424.txt`. There was **no** Work Management BROWSER REVIEW READY or browser acceptance.

**Governing known failure mode, discovered by reading the existing Server Management standard rather than speculating:** [PostgreSQL Disposable Acceptance Standard → PostGIS Disposable Initialization / Readiness Contract](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/PostgreSQL_Disposable_Acceptance_Standard.md#postgis-disposable-initialization--readiness-contract) documents that `postgis/postgis:16-3.5` starts a **temporary initialization Postgres server**, for which `pg_isready` may report success, then intentionally shuts it down to start the final server. The #419 source launcher was incorrectly checking **`pg_isready` alone**. This known race closely matches the observed restore disconnect, **but the retained output has no captured clone PID1/log evidence to establish the precise failure cause conclusively**.

**Required corrective source gate BEFORE retrying:** Reuse the standard's three-part bounded readiness test (**Docker container still Running; `/proc/1/comm` equals `postgres`; `pg_isready` succeeds**) before `createdb`, `pg_restore` or validation; fail closed with clone state and limited diagnostics if not established. Preserve existing same-image, host vs Docker path, Production fingerprint and clean-exit gates. Add feature-owned source regression that specifically prevents reintroduction of `pg_isready`-alone. If the next restore disconnects **after final PID1 has been confirmed**, STOP and inspect Docker exit/OOM state and PostgreSQL logs before any further change; do not relabel this incident as proven OOM.

**Remediation source evidence:** The reviewed runner now waits for the final `postgres` PID1 and container Running status **in addition to** `pg_isready` before database creation and restore. On failure, it captures bounded disposable container state/logs before teardown, including the OOM-killed indicator, rather than guessing. A new source regression checks readiness ordering; Linux GitHub Actions `Work Management` run [39130994564](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/39130994564) **PASSED** for code SHA `e9cf31e66cc4c8e0fc027202515b63e1ea30bf0c`. Later documentation commits require checking the **new** exact HEAD source gate again. **This remains an isolated disposable infrastructure readiness fix**, not a change to Work Order schema, Production roles, services, Directus Flows, or reporter notifications. Pin and test the final amended SHA before the next operator-run attempt.

## Second live disposable run: restore PASS, read-validator HOLD — 2026-10-18

**Operator-observed evidence at pinned SHA `949d377300212ddfc32f903f4a1b85af37e8adf7`:** the final PostGIS server readiness gate PASSED; Production dump and disposable `pg_restore` PASSED; clone-only role and read grants applied. The next phase, `validate_work_management_clone.py`, returned a generic unexpected-exception HOLD, so the real query/role/schema cause is **not yet determined** and **browser READY was never reached**. The retained report is `/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261018T132654.txt`. Cleanup again reported an unchanged Production Work Order/Intake fingerprint, shared checkout and free preview port. Do not say the clone failed to copy: the clone was restored and then deliberately deleted during HOLD cleanup.

**Regression/process finding:** this profile had only executed 25 focused source tests, in contrast to the established disposable Setup acceptance path's full `Setup/Application`, GIS preview and `FieldWiring/Application` regression. The candidate branch has been corrected to run all of those **before** the #419 feature contracts and before the Production dump. A source regression guards their presence and ordering. A progress-display regression was also found: the #419 runner omitted the prior operator-visible dump/restore transfer progress. The branch now uses `pv` when installed (with an explicit no-progress fallback), without sacrificing pipeline failure detection. These are tooling changes, not new Work Order product requirements.

**Current gate:** source changes are unmerged and must pass Linux CI and actual controlled disposable retry. The unexpected validator exception has only been classified safely so far, not root-caused; no P0 functionality or browser acceptance is implied. Keep protected logs/PII out of GitHub; any further detailed diagnostics should be scoped to a named failing phase and sanitized. The operator is not responsible for debugging restore scripts or completing the regression suite by hand.

## Corrected exact-candidate CI regression gate — October 18

At candidate `1aade5888eb6fb9936911df812f3ae3d2c254054`, GitHub Actions Work Management source CI run
[39179779076](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/39179779076)
PASSED: 33 #419 source/Flask/profile tests, 841 complete Setup/GIS tests,
and 209 FieldWiring application tests (1,083 tests total). Bash, Python,
JavaScript and PowerShell parsing also passed. The preceding source-gate HOLD
was a false-negative ordering regression that matched an explanatory `pg_dump`
comment rather than the actual dump invocation. The test now targets the
actual command. The existing workflow's source-only restrictions remain in
place, so this receipt establishes **no disposable clone execution, live
read-query PASS, browser READY, or application acceptance**.

The active main-branch Engineering Compliance required check initially failed
because the existing #420 PR body did not provide the required named evidence
fields; its body was updated without changing the controlling design.
Follow-up [check run 39179836986](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/39179836986)
PASSED. A later documentation commit must be retested at its own exact SHA.

**Next gate remains a controlled, current-Production private disposable clone
and read validator; the previously successful restore followed by read-validator
HOLD must not be misreported as a failed dump. Do not conduct operator browser
review until query assertions and application health pass. Keep P0 write/email
behavior separate from V0.1 read-only review.**

## Read-validator diagnostic checkpoint — 2026-10-18

The previous disposable database restored successfully, but the read validator failed before browser READY. The exact cause is not established. This branch now reports the failing validation phase and exception class without exposing query text, reporter details, or credentials. Source regression protects those phase markers. The next private-server execution remains necessary to identify the actual database failure. No browser or Production acceptance is claimed.

## October 19 — candidate identity HOLD after successful clone restore

Operator run on candidate `d81c2de6438ad8216f6f0d2f0bd13cacf589732b`
passed 836 Setup tests (5 skipped), 209 FieldWiring tests and 34
Work Management tests. Private PostGIS final readiness, dump/restore, role
creation and clone grants passed. The validator then failed during
`candidate_identity` with `CalledProcessError`, before querying any
Work Order records; cleanup preserved the Production fingerprint, shared
checkout HEAD and port. Retained report:
`/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261019T002340.txt`.

**Root-cause boundary:** the detached worktree's Git metadata points into
root-managed shared repository metadata; the restricted `fieldwiring` account
must not be given broader Git access. The existing privileged runner now
verifies the detached commit's exact SHA using `sudo git`, checks it against
the requested candidate and passes the verified SHA to the restricted
read-validator. The validator fails closed for a missing/mismatched proof
without trying to traverse shared Git metadata. The source regression
protects this division. There is no change to Production permissions,
PostgreSQL schema, Docker layout or the authorized clone workflow.
Next: exact-commit CI and a new private disposable clone/query/browser gate;
**no browser READY or Production authorization established yet**.

## Remaining acceptance gates

Run and correct Python source tests, revised WO419 PostgreSQL read model and clone audit before calling the first browser review READY. #419 P0 **atomic triage/Promote & Assign, alternate Setup corrections, original-reporter Request More Information/replies, final resolution emails and noncompeting Directus cutover are NOT implemented or accepted**. No temporary read-only preview can waive those future gates.

This README is the acceptance handoff. As authored, these scripts exist as source on draft PR #420, but the clone/browser has **not run on the server**, and Server Management port/profile PR #80 **merged**; port/clone/browser readiness remains unproven until an actual server run.
` token in a JavaScript text replacement was interpreted as an interpolation sequence and duplicated the remaining source. Engineering corrected the actual SQL by using a literal-safe replacement and removing the entire repeated section.

**Regression:** `WorkOrders/Acceptance/test_work_management_disposable_profile.py` now checks exactly one V1 command/activity definition and COMMIT, paired PostgreSQL dollar quote delimiters, the complete Person-ID regex, and even apostrophe counts on every SQL source line. Work Management and Engineering Compliance CI PASS on the corrected source; only the controlled server/current-Production clone can establish actual SQL execution and schema/trigger compatibility.

**Cleanup on failed run PASSED:** verified listener stopped; private clone removed; candidate worktree unregistered; Production Work Order/Intake fingerprint unchanged; shared checkout HEAD unchanged; 8898 free. No manual process cleanup needed. **Next controlled action:** one exact-SHA `-V1Validation` rerun after refreshing the clean BLUE laptop worktree. On next HOLD paste approximately ten lines before the first `ERROR/HOLD`, through cleanup, and the retained report path; stop further retries. No Production data changes or emails.

---

## October 20, 00:44 server report — V1 SQL validation BLOCKED by outdated preliminary CloneCommands fixture

**Operator evidence:** Laptop invoked the existing `run_work_management_disposable_browser_preview.ps1 -V1Validation` candidate `c0c1f5518accad0638ec2ca4a84429a3bb480538`. Original server report: `/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261020T004438.txt`.

**Verified first gate:** Current Production data restored privately to `msb_wo419_preview`, network address `172.18.0.5`. Existing unified read projection passed, including `INTAKE-40`, `INTAKE-57`, `INTAKE-60`, `WO-372` and `WO-418`. Manager My Work=20, All sampled rows=100, 12 assignee choices, full aging=58 open including one inactive exception; validated catalog authority. This is **read/preflight** acceptance, not the new V1 migration.

**Failure:** `WORK MANAGEMENT #419 DISPOSABLE READ ACCEPTANCE HOLD at clone_write_transaction_rollback: Target year applies only to Planning (urgency 5).` Source `WorkOrders/Acceptance/validate_work_management_clone.py` still provided `urgency=3` **and** `target_year=2026` in a legacy preflight fixture, which contradicted Tom's accepted October 19 *non-Planning target year absent* rule. Its Crew branch also still attempted Crew native Create, contrary to the new Intake-first authorization. The runner correctly stopped before `validate_v1` SQL migration. Do not misreport that V1 SQL failed or passed—**it was not reached**.

**Observed cleanup PASS:** `PASS: verified Work Orders listener stopped; disposable teardown permitted`; `PASS: owned disposable clone removed`; `PASS: disposable candidate worktree unregistered`; `PASS: Production Work Order/Intake fingerprint unchanged`; `PASS: shared checkout HEAD unchanged`; `PASS: preview port no longer listening`. Runner exit `HOLD (status 1)` reflects failed validation. No manual cleanup/retry of abandoned state is required.

**Correction in existing PR #420:** Preflight uses `urgency=3,target_year=None` and replaces obsolete Crew-direct-create positive rehearsal with a transaction-denied 403 assertion, using the same existing Intake path. Added guard tests to detect reintroduced non-Planning years and Crew direct Create before a real clone test. Also corrected the proposed V1 grant contract: `work_management_app` needs **SELECT only** on `ops.work_management_activity` so the existing Manager Intake and Task Feedback read projection can resolve durable V1 activity; no new outbox SELECT, native Work Order DML, or notification sends. This was identified by source inspection and **has not been applied to a clone or Production yet**.

**Next gate:** Run exact new candidate SHA once with the same original `-V1Validation` path. Require a `WO419 V1 DISPOSABLE SQL VALIDATION PASS` **and** full server/laptop CLEAN EXIT before claiming V1 PostgreSQL acceptance; if HOLD again preserve the new report and inspect phase first. Never claim browser/Production acceptance based on source CI.

---

## October 19 — V1 native PostgreSQL disposable validation, no browser (new acceptance mode)

**Purpose:** Before asking for another Work Management browser review or any Production V1 release, run the proposed `WorkOrders/Database/001_work_management_v1_governed_commands.sql` against the **existing current-Production private disposable database clone**, *not* Production. The existing #419 runner and its established **8898 sequential review profile** now have one optional `validate_v1` start mode, selected by the laptop's existing `run_work_management_disposable_browser_preview.ps1 -V1Validation` flag. It does not start a Flask browser/listener, alter `/opt/fieldwiring`, deploy a service, or use a new SSH workflow/port.

**Laptop:** From the existing clean BLUE `C:\lor\ImportExport\MSB-WorkOrders-419` worktree on `issue-419-unified-ticket-read-model-20261018`, refresh the pinned candidate SHA, then invoke the exact existing PowerShell launcher with `-CandidateSha <exact SHA> -PreviewPort 8898 -PreviewEmail 'gliebig@sheboyganlights.org' -ApprovedReviewProfile -V1Validation`. Keep the terminal open during the initial full Setup, FieldWiring, Work Orders regressions and PostgreSQL pg_dump/clone restore.

**What runs:** The normal server runbook checks a clean shared checkout, source ancestry, exact SHA, registered port ownership, Production Work Order/Intake before fingerprint, full Setup/FieldWiring/#419 tests, and a private Docker PostGIS 16 restore. On that **private clone only**, it installs the new `work_management_app NOLOGIN` test role and executes V1 SQL with the clone authorization marker (Production always requires a *different explicit* maintenance authorization marker). `wo419_v1_disposable_validation.sql` then opens a transaction, grants the exact verified reviewer temporary Work Order Manager authority **inside the clone only**, checks native Create→Assignment→Progress→Complete, idempotent retries, rejection of native non-Manager Create, promotion of a real unpromoted public Intake on the clone with original Intake provenance, lack of browser direct native DML, and held/no-send outbox records. Its entire fixture is rolled back. The owned private Docker clone/worktree/dump are then removed with the corrected exact-owner cleanup and Production Work Order/Intake fingerprint and shared source HEAD checked again.

**Acceptance criterion:** `WO419 V1 DISPOSABLE SQL VALIDATION PASS` followed by `WO419 DISPOSABLE BROWSER REVIEW: CLEAN EXIT` on the **server** and `WO419 V1 disposable SQL validation: CLEAN EXIT` on the **laptop** (this status is **SQL-only**, not browser/operator acceptance). Keep the retained server report path. On any `HOLD` or nonzero exit, **do not rerun** or manually kill port 8898: preserve report and inspect exact owner/phase before adjusting source. The new mode does not automatically SSH-resume a failed SQL run because no approved browser state exists to resume. No Production table or role changed, no emails sent, no approved V1 deployment.

**After clone PASS:** Next engineering gate is to exercise real V1 Manager/Crew browser paths on the same disposable database + candidate V1 schema, including required app identity, native commands, Task Feedback, Testing and no-send, before requesting V1 operator acceptance. The current `start` mode still exercises the earlier clone-only `CloneCommands` path; it **does not establish V1 acceptance**.

---
## October 19, 16:39 — Work Orders browser cleanup HOLD, owner-verified recovery, and root correction

**Operator impact:** Candidate `14f4a15a5118401ba084aed87f3f25146419c3d2` completed an operator review on the Command Center PC. When the operator pressed ENTER to finish, the existing WO419 shell runner printed:

```
HOLD: preview PID command mismatch; no broad process kill
PASS: shared checkout HEAD unchanged
HOLD: preview listener remains after cleanup; inspect exact PID before retry
WO419 DISPOSABLE BROWSER REVIEW: HOLD (status 83)
Retained report: /home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261019T202331.txt
```

It **removed the disposable database/worktree before proving the Flask listener was gone**, leaving a broken, orphaned Python process on the shared sequential port 8898. The subsequent read-only server check identified exactly `PID=3469910`, `PGID=3469910`, `SID=3469910`, `fieldwiring`, `/tmp/msb-wo419-preview-candidate-20261019T202331-3468774/WorkOrders/Application/preview_entry.py`, port `127.0.0.1:8898`, **no #419 Docker containers**, and **no resume state**. The operator then ran the exact-identity-gated targeted PID stop and explicitly reported:

```
PASS: Exact orphaned #419 browser verified.
PASS: Port 8898 released.
WO419 ORPHANED BROWSER PROCESS CLEANUP COMPLETE
```

**Root cause:** The source recorded the background launch handle `$!` from `setsid python ... &` as if it were the actual serving PID. `setsid` can fork when its launch handle is already a process-group leader, yielding a different Flask PID. The cleanup compared the wrong PID, correctly refused a broad kill, but wrongly continued deleting the clone/worktree. This is a **browser process ownership/lifecycle defect**, not a WO/Intake data failure.

**Source correction on existing PR #420:** In the existing `WorkOrders/Acceptance/work_management_disposable_browser_preview_server.sh` only, resolve the **real bound listener PID** from `sudo ss -H -ltnp` after Flask health is ready, then verify exact NUL-delimited `/proc/PID/cmdline` argv (`/opt/fieldwiring/.venv/bin/python` + exact candidate `WorkOrders/Application/preview_entry.py` path), numeric `fieldwiring` UID, PGID and SID equal to actual listener PID, and unique port ownership. Store that verified PID in the 0600 reconnect state instead of the untrusted launch handle. On operator completion or failure, attempt a narrow TERM against **only** the freshly verified listener PID; escalate KILL only if that **same exact validated PID** still owns the port. **Any ambiguous/foreign/unverified port halts cleanup without touching the clone/worktree/state**, preserving evidence and recoverability. Only after proving port free may runner remove the owned disposable Docker container and git worktree. Independently check container removed, candidate worktree unregistered, state absent, unchanged Production WO/Intake fingerprint (subject to concurrent external writes), unchanged shared checkout HEAD and port free before reporting CLEAN EXIT. No port reassignment, broad `pkill`, guessed PID, process-group kill, Production migration, or server service change.

**Regression:** GitHub source tests run the real extracted Bash cleanup/verification functions against a disposable local `setsid` Python socket, prove unknown candidate owner is **not killed** and its state remains, then prove the expected listener is stopped, port freed and owned state deleted. Other #419 and engineering compliance checks remain required. **Operator-run live server full disposable lifecycle validation is still pending**; source tests are not evidence of a successful real server CLEAN EXIT on this correction. Next test must report normal complete teardown with no `sudo` manual orphan cleanup and preserve retained report path.

**Governance:** MSB-Server-Management `docs/server/Pre_Production_Browser_Review_Runbook.md` and `docs/server/PostgreSQL_Disposable_Acceptance_Standard.md` remain controlling; reuse established current #419 runner and sequential port 8898. #419 PR #420 remains draft. Do not touch #88/#171 sessions, release Production, alter Flow, send notifications, or silently claim browser acceptance.

---

## October 19 — Reuse fault-tolerant Setup SSH review pattern; office feature handoff

**Authority:** [MSB-Server-Management browser review runbook](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Pre_Production_Browser_Review_Runbook.md), plus [reusable Setup reconnect contract](../../Setup/Acceptance/README.md#recoverable-browser-preview-transport). The September 29 #205 Setup browser review established that an SSH/PTTY disconnect must preserve the actual healthy disposable clone, entered browser changes, and Flask process, and the **same** workstation SSH wrapper must reattach after exact SHA/ref/port/operator/process/clone/version verification. No new runner or port allocation is permitted.

**Observed regression and controlled recovery:** On October 19, the #419 V0.3.2 Manager browser (candidate `b32b48075dce38cb18122c2f84d891f3e0153470`) suffered `client_loop: send disconnect: Connection reset` and workstation SSH exit **255**. The original Work Orders wrapper had no reconnect loop; its remote script used destructive/trapped cleanup logic instead of Setup's resumable state. The operator's read-only server diagnostics proved one abandoned **fieldwiring PID/PGID 3033050**, one Docker-private **`msb-wo419-preview-3031755`** container, and an occupied localhost port **8898**. The approved exact-instance cleanup separately proved `PASS: Exact WO419 preview verified`, `PASS: Port 8898 released`, and `WO419 OWNED PREVIEW CLEANUP COMPLETE`; no #419 container or port listener remained and Production PostgreSQL `pg_isready` returned accepting connections. This is **not a retroactive Production WO/Intake fingerprint PASS** or previous normal CLEAN EXIT.

**Source recovery corrections on existing PR #420:** 
- Single established Work Orders wrapper/runner, exact candidate SHA and sequential shared **8898**; no competing subsystem or test port.
- Shell runner accepts optional **start/resume fifth argument**, writes an owner-private **0600** state file only after browser READY validation, recording no passwords/token/CSRF/DSN. On lost SSH input/HUP after READY it preserves the preview, clone, current test edits, candidate worktree and original evidence. Before READY, failures retain regular controlled teardown.
- Workstation PowerShell wrapper retries transport exits **75/255** (up to 12 attempts) with the **same uploaded digest-verified runner**; no rebuilding private clone and no killing unknown local listeners. A resume verifies exact SHA/ref/port/reviewer, numeric fieldwiring UID, saved preview PID and port ownership, running private container, detached SHA and live `/api/work-orders/health` application version **before** allowing another review or intentional ENTER cleanup. Unknown ownership/state HALTs safely.
- Guard port/state conflicts **before** any pg_dump/clone. The uploaded runner is deleted only after successful normal server teardown; its script is retained on transport loss for verified reattachment. No-STDOUT secret logging or Production DML added.
- Targeted regressions on Linux execute the actual Bash private-state writer (including permissions, content, re-source and overwrite refusal) and fail-closed 4/5/6 argument gates; source contract checks verify same Setup-style bounded PowerShell reconnect, strict identity/ownership, non-destructive mode dispatch and no arbitrary SSH-process termination.

**Acceptance state:** GitHub source tests/Engineering Compliance are necessary but **not evidence that a workstation SSH disconnect/reconnect has been exercised against the real protected browser**. Real fault-tolerance acceptance is pending a later explicit user-approved disposable review when **8898** is available. Do not block ongoing #88 Container Movement / #171 GIS testing while editing #419. Operator UI review remains CHANGES REQUIRED; no Production deployment/email/Flow cutover authorized. Office PC continuation: dedicated `C:\Users\Greg\Github\MSB-WorkOrders-419` blue feature worktree/VS Code window, `git pull --ff-only` only when clean and after fetching exact #419 origin branch. Do not update primary `main` or touch GIS/#88 worktrees.

## October 19 — Tom/Manager review: Intake-only Crew requests, Planning year, Manager privileges

**Source candidate:** Following the Oct 19 in-person Work Orders review, the operator explicitly **reversed the earlier Crew direct-create requirement**. A Crew or other non-Manager reporter uses the same public Park/Workshop Work Order Request Form (`https://forms.gle/Gve4ZbXHDWxs43yh6`), which submits to existing `stage.work_order_intake` for investigation, clarification, approval/promotion and eventual assignment. No new Intake subsystem, Google Form or duplicate WO is authorized. The direct native **Create Work Order** button is Manager-only; the server `CloneCommands.perform(..., 'create', ...)` independently denies any actor lacking verified `can_manage`, even if `can_create` is forged. The existing selector/access policy no longer maps Production Crew to direct `can_create` capabilities.

**Create/Promote defaults:** New actual Work Orders default urgency/priority to **3 — Normal**; Target year is only visible/submitted for **urgency 5 — Planning**, with valid year required for new Planning Work Orders. Non-planning native saves carry NULL target year. Intake requires **no assignments** and **no target year**; assignment is managed during triage/promotion, not on request submission. We **do not claim to change default values inside the third-party Google Form**: its source and Apps Script are separately governed and should be inspected before any public submission defaults are changed.

**Operator permission concern:** Manager capabilities should be deliberately assigned, not inferred from unrelated legacy person flags. User expressed concern about an existing Manager delegation; no named user's authorization, Google Workspace membership, or Directus role has been changed. Role-scope change would require explicit separate authorization and privileges inventory. No Production write, mail send, or Flow cutover.

**Validation:** CI source tests now enforce native Manager-only Create, Crew rejection before any database transaction, existing form link, default urgency 3, Planning-only target year, and retention of Intake/Manager triage. **Source CI PASS does not mean disposable UI acceptance**; hold functional live Manager/Crew browser testing and actual form Intake side effects until review authorized and sequential 8898 available. Preserve active browser data and never force-stop another review.

---
## October 19 — Command Center operator UI review, source corrections, and cross-repo boundaries

**Review verdict: CHANGES REQUIRED.** Command Center PC operated on the accepted isolated #419 browser candidate `72939e3ebf90923347550dd786e3294edbacfcf2`. Screenshots: filter/header layout crowded and clipped; **Create Work Order** exposed the empty "New internal Work Order" panel but no editable fields and repeated its title; Aging Report showed **WO-372** still Open despite Tom reporting physical completion this morning; **WO-389** is a request to assign `RD04-B-03` to Container `C213` (not a mandatory repair Work Order); the `my.sheboyganlights.org` public Google Form button incorrectly said **Submit a Work Order** when it creates a **Work Order Intake** item that a Manager may approve/promote. Person-search usability suggests evaluating whether `ref.person.available_for_work_orders` is redundant, but first audit downstream identities/permissions and notification rules—no field/schema change authorized by feedback. Operator reported `WO419 workstation browser tunnel: CLEAN EXIT`; that is a workstation exit observation, **not** operator acceptance or independent server fingerprint evidence.

**#419 source-only candidate implementation on existing draft PR #420:** responsive filter/actions rows group scope, search, sort separately from completion/planning toggles, Refresh, Create and request link; narrowed input min widths prevent clipping. The direct Create path now explicitly exposes the proper form/fields, focuses work description, advertises `aria-expanded`, and preserves the `create` selection during late reviewer option redraw; removed the duplicate CSS-added heading. Targeted regression tests assert these contracts. **Source regression/CI PASS is not a substitute for real browser functional validation**: next approval review must actually enter and save a disposable Create, test authenticated work-notes and WO completion, reassignment, manager Intake, and normal/logout and SSH disconnect behavior.

**WO-372:** original repair and completion records must be reconciled by authenticated work order workflow with real actual-work notes, credited to the person performing/verifying the job. The fact Tom physically completed it on October 19 is not proof `ops.work_order.done_at` is set; do not invent a timestamp, backdate records, or close Production outside authorized release. If current Production still says Open, that is unrecorded completion, not evidence of an additional physical repair requirement.

**WO-389:** location/home rack assignment belongs to #230 (canonical storage location reference editor), honoring #88 movement/home boundaries. Filed on #230; #419 does not replicate the reference-table editor or update `C213`.

**Portal:** User-requested text change is made as source-only draft [MSB-Internal-Web-Backbone PR #26](https://github.com/Gregovate/MSB-Internal-Web-Backbone/pull/26) (`fix/portal-work-order-request-intake-label-20261019`), retaining the existing public Google Form URL and Manager triage. Publication separately governed by site repo; no website deployment in this PR.

**Release holds:** Prior UI acceptance remains failed until disposable browser functional acceptance; #419 may not deploy/Flow-cutover/send emails or mutate Production Work Order records without explicit new approval. Respect shared sequential port 8898 occupied by any #88/GIS review.

---
## October 19 — Manager disposable browser review: CHANGES REQUIRED, source candidate underway

The operator reached the real protected Work Management browser on the existing current-Production **disposable clone**, reviewed several Manager queues in dark/light modes, and later reported **`WO419 workstation browser tunnel: CLEAN EXIT`**. This confirms a successful exit from the workstation launcher; the exact server cleanup report path/fingerprint for this session was **not pasted**, so do not invent it or claim independent server fingerprint evidence. **Operator UI acceptance was explicitly rejected**, despite the functional Manager pending Intake banner (2 Public requests, 1 Task Feedback) and full Open Work Order Aging Report (58 undated WOs, including one inactive exception) being useful.

**Required repair before next browser handoff:**
- **Work Order execution:** On selected open WO (operator example WO-402, physically completed weeks earlier), show obvious **Add Work Note** and **Complete Work Order** actions immediately at the top of the detail card. Completion form captures actual work notes, then server decides authenticated Person and completion date; do not expose arbitrary Completed By or manually set Date Completed. Save notes without changing completion when progress only. Do not modify WO-402 in Production because it was reportedly finished physically.
- **Manager maintenance:** Put a separate **Manager · Assign / Reassign** button in the Work Order heading, not as an undifferentiated work dropdown. Preserve normalized multi-person assignment history, Manager-only server rights and no-send notification receipts.
- **Create:** One top-bar **Create Work Order** button opens blank native creation fields directly. Remove the generic redundant `Select proposed action` picker from the operator interface; it may remain as internal state but never dictate the visible workflow.
- **Internal navigation:** Browser Back/Forward and explicit **← Back to Work Order list** stay within Work Management and restore selected ticket, authorized queue/filter, planning flag, search, and list scroll. Returning from aging drill-through must not lose the reporting context or exit the application.
- **Planning ideas:** A long-term proposal (WO-105 Area 5 Shelter) must not mingle with normal dispatch. Current urgency **5 = Planning** is the native available category. Use a reversible **Show planning work (Priority 5)** checkbox in every authorized queue **and in the aging report**, default off for day-to-day dispatch. Normal filters exclude only Priority 5, leave unknown priorities untouched and do not delete/mutate/retire historical records. When enabled, full planning records become findable with original metadata. Treat this as an initial view filter, **not an invented durable planning-classification field**.
- **Sorting:** Replace confusing `Critical first / Planning first` names with clear numeric `Most urgent first (1 → 5)` / `Least urgent first (5 → 1)`; numeric ticket IDs and created date remain sortable by both directions.
- **Styling:** Bounded Work Management text-size/readability corrections and #419 components must use established [#159 shared light/dark palette](https://github.com/Gregovate/MSB-Production-Database-Project/issues/159) and [#140 semantic CSS intent](https://github.com/Gregovate/MSB-Production-Database-Project/issues/140), rather than inventing a competing MSB-wide design system. Browser scaling is individual preference, not a substitute for readable app defaults.

**Next controlled run:** Full source regression + same Server Management runner and sequential localhost port 8898, fresh private restore, rollback native WO/Setup gate validation, two role sessions, no-send, no Production changes. Browser must verify actually saving a work note and a completion in the disposable database, reopening via search, Manager Assign/Reassign, Create blank fields, Back, Show Planning off/on incl aging CSV, and light/dark normal font. Need `WO419 BROWSER REVIEW READY`, operator acceptance, then server **CLEAN EXIT/fingerprint** separately. PR #420 draft; no deployment.

## October 19 — second write-preflight HOLD: Setup season read requested unauthorized row lock

**Operator real run:** exact candidate `dc98c63b5e72896aaaeb7898551a34d10a7f4252`; retained server report `/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261019T102500.txt`. The previous `/32` clone-IP mismatch is **fixed and proven** by canonical `172.18.0.5` reporting and progression into the Write/Create/Assign → Setup linkage preflight. Source regressions, current-Production dump/private final-PID1 PostgreSQL restore, read/ledger, 58-open/one-inactive Manager Aging Report, and clone-only write grant/no-send outbox setup all PASSED. The test reached `atomic_work_order_setup_season_gate` and raised `InsufficientPrivilege`, before browser READY.

**Source diagnosis:** `CloneCommands.create_season_only_work_order_gate()` ran `SELECT setup_session_id FROM ops.setup_session ... FOR SHARE` under the clone application role. This requests a PostgreSQL row-level lock, requiring table privileges beyond the deliberately limited `SELECT` on `ops.setup_session`. There is **no justification to grant UPDATE** or broader annual-task DML merely to check if the season is open. The released `SECURITY DEFINER ops.create_setup_season_task` is already Manager-authorized and independently checks season/actor/stage/Work Order. This source-level row lock is the specific likely cause of the observed failure; no full SQL error details were exposed, so live reproduction of that exact statement was not captured.

**Narrow fix:** remove only the unnecessary `FOR SHARE` from the read-only season precheck, retaining selected `ACTIVE/PLANNING` status, existing Manager role, open season/WO duplicate validation, native Setup command and **same PostgreSQL atomic transaction**. Do NOT grant update privileges on `ops.setup_session`, INSERT on `ops.setup_session_task`, or replace the existing Setup command. New restricted-cursor regression fails if the Setup read attempts `FOR SHARE/FOR UPDATE` and proves it reaches `ops.create_setup_season_task` with the same WO and approval. The existing clone-only grant/security regression remains.

**Cleanup proved in operator log:** Production Work Order/Intake fingerprint unchanged, shared checkout unchanged, localhost 8898 listener released; server `WO419 DISPOSABLE BROWSER REVIEW: HOLD (status 1)`. No browser UI opened, no saved WO or Setup task committed, no email/Directus Flow/Production change.

**Retry gate:** only after exact successor SHA source tests PASS. Use existing clean workstation branch, **same** Server Management sequential 8898 wrapper and authorized Manager reviewer, with dump→private disposable clone→read/native rollback and linked Setup gate acceptance. If next step HOLDS, retain the new phase and report, do not bypass grants or mutate Production; continue #419 PR #420. No competing runner/DB.

## October 19 — latest disposable browser attempt HOLD: clone IP string formatting

**Operator report:** exact candidate `f4afad0b82ab7748cfd9c6578465e32d782d4e3f`; server acceptance report
`/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261019T101641.txt`.
Source application regressions **836 passed, 5 skipped (Setup); 209 passed (FieldWiring); 65 passed (#419)**. Production pg_dump, PostGIS final PID1 readiness and private clone restore PASS; clone-only grants/action/outbox fixture installed. Ledger verification returned original WO-372, WO-418 and INTAKE-40/57/60. Manager aging report validated **58 open WOs including one inactive/undated exception**.

**Actual HOLD:** `clone_write_transaction_rollback` failed with `Write target is not the verified clone.` The read-side PostgreSQL query logged `inet_server_addr()::text` as `172.18.0.5/32`; server runner supplied the same private clone's Docker inspect `IPAddress` as a bare address `172.18.0.5`. `CloneCommands.transaction` compared the text representations literally, so the mask caused a false mismatch. This was a **clone identifier serialization error**, NOT an observed schema/SQL/Testing/assignment failure (those mutations never ran).

**Correction:** the existing writer now queries `host(inet_server_addr())`, which produces PostgreSQL's host address without its CIDR mask; the strict expected `msb_wo419_preview` database name, same exact Docker-derived clone IP, separate clone authorization secret and authenticated linked Person audit check are unchanged. Read-side stage output also uses `host()` for comparable diagnostics. The source/fake connection regression covers matching `172.18.0.5` versus previous logged `172.18.0.5/32` formatting, and denies wrong IP, Production database, wrong clone authorization token and missing active linked Person. No broadening of authorized database or another runner/port.

**Cleanup proved by operator report:** Production Work Order/Intake fingerprint unchanged; shared repository checkout unchanged; port 8898 not listening; server runner ended `WO419 DISPOSABLE BROWSER REVIEW: HOLD (status 1)`, followed by workstation exception. **No browser READY, no V0.3 UI or write acceptance.**

**Next:** after new exact-SHA GitHub source CI PASS, use the existing Windows wrapper/branch/8898 profile and authorized reviewer; reuse the same current-Production dump→private clone→source tests→rolled-back native write preflight→browser sequence. If it HOLDS on actual native schema/privileges, retain the phase/report and correct that defect on PR #420. Do not bypass the clone identity check or deploy/send to Production. **Source CI PASS alone is not a server/database or browser acceptance.**

## Aging report acceptance — Manager all open by original created date

In the same Manager browser session and on the same private current-Production clone, select **Open Work Order Aging Report**. This is a **report**, not the normal 80-row work queue.

1. Require full native `date_completed IS NULL` population, including `is_active=false` exceptions, independent of Show completed or My Work assignment scope. The clone validator counts native ops.work_order undated rows and compares with the report **before browser READY**.
2. Verify **oldest original `created_at` first**, days elapsed from creation, priority, assignee, human description/location and inactive exception labels. Change sort to newest, priority both ways and numeric WO number both ways. Do not allow lexical ticket-number ordering.
3. Verify 0–7, 8–30, 31–60, 61+ day aging counts, unassigned and inactive exceptions. Export CSV and verify that the export includes **every report row**, not only visible rows. Clicking WO number must open native ticket detail.
4. Reopen the same application through an approved Production Crew preview identity **in a separate sequential clone session**. The aging option must not be available, and direct API access must return 403. Verify Crew My Assigned Work and Create/Complete remain unaffected.
5. Review examples WO-372/400/107/147/389/416 where present. Do not correct Production data; all preview saves remain disposable. Confirm no-send mail and server-side CLEAN EXIT before finalizing acceptance.

No new runner, port, Production deployment, or email permission is introduced by this report.

## Current #419 seasonal-work and January handoff gate

The same exact-SHA disposable runner tests native Work Order Create/Assign/Complete **plus** an optional rollback-only **linked 2026/other open Setup season GATE** when a real ACTIVE/PLANNING season is present. This calls the accepted, Manager-authorized `ops.create_setup_season_task` function inside the same private clone transaction, requiring `SEASON_ONLY`, a null reusable task key, `linked_work_order_id` and `linked_work_order_gate`. No direct `ops.setup_session_task` INSERT/UPDATE permission or second runner was introduced. On any SQL/permission/trigger error the candidate MUST HOLD before BROWSER REVIEW READY; no one should bypass that with manual Production SQL.

In browser, test Manager direct Create+annual task, Manager Add to seasonal Setup on a Crew-created existing Stage Work Order, Crew-only Setup review flag (no unauthorized annual writes), and duplicate/closed-season rejection. Reopen the Work Order to see the retained linkage event, and use the existing Setup Board to verify waiting/complete semantics. Both reviewers must finish with server-side CLEAN EXIT and unchanged Production fingerprints. These are still **candidate** workflows; do not treat CI PASS as disposable server/browser acceptance.

Separate [#423 2027 Takedown](https://github.com/Gregovate/MSB-Production-Database-Project/issues/423) tracks the January 1 release deadline under #122/#88/#230/#231 without changing the #419 runner.

## V0.3.1 role-specific browser checks — two real reviewer identities

The next source candidate must be reviewed through **the same** approved Server Management PowerShell wrapper and sequential localhost port 8898. Do **not** create a second runner or simultaneous preview. This role change does not authorize Production writes or outgoing email.

**Manager session:** Choose an existing linked Manager identity in the approved wrapper. After exact-SHA regression, current-Production private PostGIS clone restore, native Create/Assign/Complete rollback preflight and WO419 BROWSER REVIEW READY, verify the homepage automatically shows pending **Public Intake** and separate Task Feedback counts, with buttons into each Manager queue. Create a disposable Work Order; assign and reassign multiple exact People; triage retained public Park/Workshop Intake (one-step Promote & Assign), verify saved original Intake no longer appears as *pending*; use Testing Repair and urgent/unassigned queues; sort every view by priority both ways and Work Order number both ways.

**Production Crew session:** Close the prior review with server-side CLEAN EXIT and unchanged Production fingerprints first; run the **same wrapper again**, with a separate approved actual Crew identity and fresh private clone. Crew homepage must show only My Assigned Work, Work Orders I Created, My Submitted Feedback, Create and completion of genuinely assigned WOs. Verify an internal Create saves natively without a fake public Intake or self-assignment and appears in Work Orders I Created. Verify required completion notes and person attribution. No manager Intake badge/queue, no manager assignee selector/triage, and direct attempts against Manager endpoints return 403. Sort the Crew's authorized lists by both priority and numeric number.

**Public form:** The external Work Order Request link navigates only to the existing MSB portal, where the current public Park/Workshop Google Form remains available. Do not test by submitting to the live form or alter Apps Script. This form is distinct from authenticated Crew Create.

Retain both review reports, exact SHA, and server-side CLEAN EXIT outcomes. The historical V0.2 **CHANGES REQUIRED** finding remains, and V0.3.1 operator acceptance is pending. Both sessions must keep outgoing notifications NO_SEND; no Production deployment or Flow cutover.

## V0.3 disposable-write operator review — after source CI PASS only

The operator's prior workstation tunnel reported CLEAN EXIT. That is a workstation transport result, **not independent evidence of server-side CLEAN EXIT or unchanged Production database fingerprint**. The V0.2 review was CHANGES REQUIRED. The next review intentionally allows real writes to the disposable clone, as with prior Setup browser acceptance; all writes disappear at cleanup and no email is sent.

**Existing launcher/port/branch remain unchanged.** After a new exact source-only GitHub Actions PASS and a clean branch checkout, use the same PowerShell wrapper below with the new HEAD, explicit port 8898 and a named approved reviewer. The runner must restore the isolated PostGIS clone, install the clone-only authorization/action SQL in the same source worktree, validate the current Manager catalogs, and perform an automatic Savepoint-rolled-back native Create/Assign/Complete preflight. On failure it must print HOLD, tear down owned disposable resources and retain the evidence report; DO NOT manually bypass a failed preflight or repurpose Production permissions.

**Browser review after WO419 BROWSER REVIEW READY:** MSB logos and light/dark mode match Setup; top-bar Manager Create; ticket-local Assign/Reassign (multiple real volunteers), completion notes and actual clone save; separate public Intake triage, Testing repair, Task Feedback owner/clarification/reply/disposition; saved actor/time and no-send activity; reporter history; user-role negative paths. Use real-shaped WO-372/400/107/147/389/416 and Intake-60/40/57 without modifying Production. Verify a saved clone WO appears on refresh and that linked Testing behavior is truthful.

**Exit:** Press ENTER; require server message WO419 DISPOSABLE BROWSER REVIEW: CLEAN EXIT, unchanged Production Work Order/assignments/Intake fingerprint, shared checkout unchanged, listener released and private clone discarded. Workstation tunnel CLEAN EXIT by itself is not a substitute. Keep report path and findings in owning PR. No Production send, schema deployment, Flow cutover, or Directus bookmark change.

## V0.2 operator workflow rehearsal candidate — CHANGES REQUIRED, source-only

The current branch's V0.2 read-only candidate extends the first completed browser's **CHANGES REQUIRED** finding; it is **not** full P0 workflow acceptance. The separate subsequent PostGIS first-restore HOLD and final-server readiness fix remain documented below. The existing **same** server runner and protected localhost 8898 profile are reused, not cloned or bypassed.

**After latest source CI success**, from the existing clean local branch checkout use the same governed wrapper, supplying the exact current branch SHA and an explicitly approved reviewer Person:

```powershell
git pull --ff-only
$sha = (git rev-parse HEAD).Trim()
.\WorkOrders\Acceptance\run_work_management_disposable_browser_preview.ps1 -CandidateSha $sha -PreviewPort 8898 -PreviewEmail 'REPLACE-WITH-APPROVED-REVIEWER@sheboyganlights.org' -ApprovedReviewProfile
```

The uppercase reviewer placeholder is documentation only and **must not** be used literally. Wrapper enforces branch, clean checkout, SHA, email, local listener and remote ownership. Do not open the browser until the runner reports `WO419 BROWSER REVIEW READY`; if HOLD, retain output and do not improvise or deploy. The new clone validator verifies active People, Task Types, Stages and Work Areas for Manager users. All actions in the browser's **Operator workflow review** remain no-save; their validated summary cannot be used to claim an assignment, completion, Intake promotion or reporter email was persisted.

**Review checklist (still no database writes):** My Work/all/person/completed; My Submitted Feedback and original reporter identity; Manager Critical/Unassigned/General/Testing/Public Intake/Feedback distinct queues; `WO372`, `WO-416`, Testing repairs, `INTAKE-60` and retained public Intake where present; light/dark theme; directly create without invented Intake; exactly one Park Stage or Workshop Work Area; select multiple existing People; required completion notes; specific feedback clarification and reasoned closure; negative user permissions; confirm the no-save truth is conspicuous. Original field findings WO-372/400/107/147/389/416 are **evidence and human-review targets**, never test-mutation instructions.

**After review:** press ENTER in the foreground SSH console, inspect final `WO419 DISPOSABLE BROWSER REVIEW: CLEAN EXIT`, unchanged Production Work Order/assignment/Intake fingerprint and preview listener removed. Store screenshots/findings and the retained acceptance report path on this PR. Missing READY/CLEAN EXIT or any validation drift is HOLD, not acceptance. Next engineering work is durable clone-only actions and no-send notification tests before Production authorization is even considered.

## Authorities

- [Work Orders design](../../Docs/02_Production_Database/01_System_Architecture/06_Work_Orders/Work_Order_System_Design.md) governs identities, Stage Related Information, and P0 acceptance.
- [Server Management PostgreSQL Disposable Acceptance Standard](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/PostgreSQL_Disposable_Acceptance_Standard.md) controls clone isolation.
- [Server Management Pre-Production Browser Review Runbook](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Pre_Production_Browser_Review_Runbook.md) controls temporary listener, SSH, runtime, reviewer identity and cleanup.
- [Application and Test Port Register](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Application_and_Test_Port_Register.md) owns port allocation. [Merged Server Management PR #80](https://github.com/Gregovate/MSB-Server-Management/pull/80) authorizes #419 **sequential, pre-Production reuse of existing localhost 8898**. The listener state is **not known** until the runner checks it. No Setup or #395 review may be stopped to free that listener without its own governed recovery.

## Feature-owned disposable profile files

| Existing #419 candidate file | Responsibility |
| --- | --- |
| run_work_management_disposable_browser_preview.ps1 | Windows SHA, branch, reviewer, port, local-listener and byte-digest checks, foreground SSH tunnel |
| work_management_disposable_browser_preview_server.sh | Server-side clone/port/identity/source/Flask readiness, clean-exit and fingerprint assertions |
| wo419_preview_clone_read_grants.sql | **Clone-only** PostgreSQL read grants; never apply to Production |
| validate_work_management_clone.py | Exact-SHA read checks for real current Work Orders and Setup Feedback |
| ../Application/preview_entry.py | Localhost Flask profile that injects only the runner-selected existing MSB reviewer |

The server runner follows the existing Standard: verify live services/listener, detached exact-SHA worktree, source regression, pg_dump from Production, isolated PostGIS Docker clone, read-only clone role, feature SQL validator, temporary localhost browser and controlled teardown. It never switches the live application checkout, creates Production records, emails volunteers, or alters Directus Flows. A distinct clone name is necessary but insufficient: validate private Docker network/container IP and no published clone DB port.

## Controlled Windows operator invocation — pre-Production review profile approved

From a clean local feature-branch MSB Database checkout, with the exact review commit checked out and the approved Person email:

PowerShell:

    $sha = (git rev-parse HEAD).Trim()
    .\WorkOrders\Acceptance\run_work_management_disposable_browser_preview.ps1 -CandidateSha $sha -PreviewPort 8898 -PreviewEmail 'approved.person@sheboyganlights.org' -ApprovedReviewProfile

Replace that sample reviewer with the **real explicitly approved existing person**. This is the **approved pre-Production review invocation**, subject to current worktree SHA/source gates, a free local/remote listener and successful clone isolation; it is not Production deployment approval. The wrapper refuses to start without the approved-profile switch, current branch/SHA match, clean checkout and free local listener. The remote runner must similarly prove the server listener unused and live services unchanged. Do not open the localhost URL until **WO419 BROWSER REVIEW READY** is printed.

At READY, review My Work, All, another assignee, Show completed, current Intake and WO examples, the **collapsed Related Information** section, Stage-level Kit/Container/Display/material resources and honest "Stage-related" vs "task-linked" labels. Browser interactions in this V0.1 are read-only.

Press ENTER in the SSH session when done, and require the exact **WO419 DISPOSABLE BROWSER REVIEW: CLEAN EXIT** report with unchanged Production fingerprints. If transport fails or a listener remains, stop and inspect recognized owner/state before retry; never kill unknown processes.

## Automated preflight

The [source-only Work Management CI workflow](../../.github/workflows/wo419-work-management-source-tests.yml) is committed in draft PR #420. It checks Bash parsing, Python module compilation, Node JavaScript parsing, fake-repository Flask tests, and the DB-owned ledger/design contracts. It does not have server credentials and cannot touch Production. **A committed workflow is not a passing workflow: no GitHub Actions PASS has yet been reported for this candidate.** The server runner independently repeats feature tests before creating a clone. If CI/source tests fail, correct them and pin a new exact SHA before asking for browser review.

## Laptop source regression receipt — 2026-10-18

**Operator-run PASS (source/fake-repository only):** In the clean Windows laptop worktree `C:\\lor\\ImportExport\\MSB-WorkOrders-419` on branch `issue-419-unified-ticket-read-model-20261018`, commit `8a6d55df64a156af51294c3e7eaec2f40508534d`:

```text
python -m pytest -q -p no:cacheprovider
  WorkOrders/Application/test_work_management_preview.py
  WorkOrders/Acceptance/test_work_management_disposable_profile.py
  Database/Acceptance/test_wo419_unified_ticket_read_model.py

29 passed, 1 skipped in 0.28s
```

The prior exact-wording source guard in `test_419_testing_origin_is_explicit_and_not_a_fake_intake` was corrected to match the existing engineering design; this run has **zero failures**. The one skipped test's reason was not printed in the operator's `-q` output; the profile suite explicitly skips Linux/Bash syntax validation when `bash` is unavailable. **Linux `bash -n`, revised PostgreSQL query against a current-Production disposable clone, live Flask browser, authorized reviewer/port checks and P0 write/email workflows have NOT been accepted.** The resulting receipt does not establish an isolated clone or browser READY.

## Linux GitHub Actions source gate — 2026-10-18

**PASS** for commit `8871a796847f635b1108b3f00f1989455fc159e9`, GitHub Actions run **39127213541** (`Work Management` / `source-only-regression`). Source checkout, Python 3.12 install, `bash -n` on the Work Management server runner, Python module compilation, `node --check` for the browser JavaScript, isolated fake-repository Flask/Work Management/DB-contract pytest suites, and the no-Production-contact step all concluded **success**. This follows the laptop **29 passed, 1 skipped** receipt above; the Windows-only Bash skip was exercised in Linux CI.

Immediately preceding the gate, source-only runner fixes streamed the host-side clone grants file through Docker `psql` **stdin** and corrected the SQL approval marker's actual line terminator. The new source regression protects those invariants. This **does not prove** the disposable restore, live-schema SELECT, Flask/DB integration, port-owner check, authorized user, Production fingerprint or browser interaction. Those must be executed and reported separately by the governed runner. **Production was not contacted by the GitHub Actions job.**

## First live disposable run: PostgreSQL post-init readiness HOLD — 2026-10-18

**Operator-provided evidence:** In a foreground laptop SSH review at pinned candidate `5bc230a84c998a61740067f74234d998f8616eae`, all **25 detached candidate source tests PASSED** before clone creation. The current Production `pg_dump` was captured successfully. During `pg_restore` into the **new disposable PostGIS container**, the connection closed unexpectedly while reporting a `COMMENT ON COLUMN ops.controller_label_batch_item.line1` statement. **Do not infer the COMMENT or Work Management schema is invalid.** Runner teardown completed: Work Order/Intake Production fingerprint unchanged, shared checkout unchanged, preview port no longer listening. Status was **HOLD (1)**; report `/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261018T131424.txt`. There was **no** Work Management BROWSER REVIEW READY or browser acceptance.

**Governing known failure mode, discovered by reading the existing Server Management standard rather than speculating:** [PostgreSQL Disposable Acceptance Standard → PostGIS Disposable Initialization / Readiness Contract](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/PostgreSQL_Disposable_Acceptance_Standard.md#postgis-disposable-initialization--readiness-contract) documents that `postgis/postgis:16-3.5` starts a **temporary initialization Postgres server**, for which `pg_isready` may report success, then intentionally shuts it down to start the final server. The #419 source launcher was incorrectly checking **`pg_isready` alone**. This known race closely matches the observed restore disconnect, **but the retained output has no captured clone PID1/log evidence to establish the precise failure cause conclusively**.

**Required corrective source gate BEFORE retrying:** Reuse the standard's three-part bounded readiness test (**Docker container still Running; `/proc/1/comm` equals `postgres`; `pg_isready` succeeds**) before `createdb`, `pg_restore` or validation; fail closed with clone state and limited diagnostics if not established. Preserve existing same-image, host vs Docker path, Production fingerprint and clean-exit gates. Add feature-owned source regression that specifically prevents reintroduction of `pg_isready`-alone. If the next restore disconnects **after final PID1 has been confirmed**, STOP and inspect Docker exit/OOM state and PostgreSQL logs before any further change; do not relabel this incident as proven OOM.

**Remediation source evidence:** The reviewed runner now waits for the final `postgres` PID1 and container Running status **in addition to** `pg_isready` before database creation and restore. On failure, it captures bounded disposable container state/logs before teardown, including the OOM-killed indicator, rather than guessing. A new source regression checks readiness ordering; Linux GitHub Actions `Work Management` run [39130994564](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/39130994564) **PASSED** for code SHA `e9cf31e66cc4c8e0fc027202515b63e1ea30bf0c`. Later documentation commits require checking the **new** exact HEAD source gate again. **This remains an isolated disposable infrastructure readiness fix**, not a change to Work Order schema, Production roles, services, Directus Flows, or reporter notifications. Pin and test the final amended SHA before the next operator-run attempt.

## Second live disposable run: restore PASS, read-validator HOLD — 2026-10-18

**Operator-observed evidence at pinned SHA `949d377300212ddfc32f903f4a1b85af37e8adf7`:** the final PostGIS server readiness gate PASSED; Production dump and disposable `pg_restore` PASSED; clone-only role and read grants applied. The next phase, `validate_work_management_clone.py`, returned a generic unexpected-exception HOLD, so the real query/role/schema cause is **not yet determined** and **browser READY was never reached**. The retained report is `/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261018T132654.txt`. Cleanup again reported an unchanged Production Work Order/Intake fingerprint, shared checkout and free preview port. Do not say the clone failed to copy: the clone was restored and then deliberately deleted during HOLD cleanup.

**Regression/process finding:** this profile had only executed 25 focused source tests, in contrast to the established disposable Setup acceptance path's full `Setup/Application`, GIS preview and `FieldWiring/Application` regression. The candidate branch has been corrected to run all of those **before** the #419 feature contracts and before the Production dump. A source regression guards their presence and ordering. A progress-display regression was also found: the #419 runner omitted the prior operator-visible dump/restore transfer progress. The branch now uses `pv` when installed (with an explicit no-progress fallback), without sacrificing pipeline failure detection. These are tooling changes, not new Work Order product requirements.

**Current gate:** source changes are unmerged and must pass Linux CI and actual controlled disposable retry. The unexpected validator exception has only been classified safely so far, not root-caused; no P0 functionality or browser acceptance is implied. Keep protected logs/PII out of GitHub; any further detailed diagnostics should be scoped to a named failing phase and sanitized. The operator is not responsible for debugging restore scripts or completing the regression suite by hand.

## Corrected exact-candidate CI regression gate — October 18

At candidate `1aade5888eb6fb9936911df812f3ae3d2c254054`, GitHub Actions Work Management source CI run
[39179779076](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/39179779076)
PASSED: 33 #419 source/Flask/profile tests, 841 complete Setup/GIS tests,
and 209 FieldWiring application tests (1,083 tests total). Bash, Python,
JavaScript and PowerShell parsing also passed. The preceding source-gate HOLD
was a false-negative ordering regression that matched an explanatory `pg_dump`
comment rather than the actual dump invocation. The test now targets the
actual command. The existing workflow's source-only restrictions remain in
place, so this receipt establishes **no disposable clone execution, live
read-query PASS, browser READY, or application acceptance**.

The active main-branch Engineering Compliance required check initially failed
because the existing #420 PR body did not provide the required named evidence
fields; its body was updated without changing the controlling design.
Follow-up [check run 39179836986](https://github.com/Gregovate/MSB-Production-Database-Project/actions/runs/39179836986)
PASSED. A later documentation commit must be retested at its own exact SHA.

**Next gate remains a controlled, current-Production private disposable clone
and read validator; the previously successful restore followed by read-validator
HOLD must not be misreported as a failed dump. Do not conduct operator browser
review until query assertions and application health pass. Keep P0 write/email
behavior separate from V0.1 read-only review.**

## Read-validator diagnostic checkpoint — 2026-10-18

The previous disposable database restored successfully, but the read validator failed before browser READY. The exact cause is not established. This branch now reports the failing validation phase and exception class without exposing query text, reporter details, or credentials. Source regression protects those phase markers. The next private-server execution remains necessary to identify the actual database failure. No browser or Production acceptance is claimed.

## October 19 — candidate identity HOLD after successful clone restore

Operator run on candidate `d81c2de6438ad8216f6f0d2f0bd13cacf589732b`
passed 836 Setup tests (5 skipped), 209 FieldWiring tests and 34
Work Management tests. Private PostGIS final readiness, dump/restore, role
creation and clone grants passed. The validator then failed during
`candidate_identity` with `CalledProcessError`, before querying any
Work Order records; cleanup preserved the Production fingerprint, shared
checkout HEAD and port. Retained report:
`/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261019T002340.txt`.

**Root-cause boundary:** the detached worktree's Git metadata points into
root-managed shared repository metadata; the restricted `fieldwiring` account
must not be given broader Git access. The existing privileged runner now
verifies the detached commit's exact SHA using `sudo git`, checks it against
the requested candidate and passes the verified SHA to the restricted
read-validator. The validator fails closed for a missing/mismatched proof
without trying to traverse shared Git metadata. The source regression
protects this division. There is no change to Production permissions,
PostgreSQL schema, Docker layout or the authorized clone workflow.
Next: exact-commit CI and a new private disposable clone/query/browser gate;
**no browser READY or Production authorization established yet**.

## Remaining acceptance gates

Run and correct Python source tests, revised WO419 PostgreSQL read model and clone audit before calling the first browser review READY. #419 P0 **atomic triage/Promote & Assign, alternate Setup corrections, original-reporter Request More Information/replies, final resolution emails and noncompeting Directus cutover are NOT implemented or accepted**. No temporary read-only preview can waive those future gates.

This README is the acceptance handoff. As authored, these scripts exist as source on draft PR #420, but the clone/browser has **not run on the server**, and Server Management port/profile PR #80 **merged**; port/clone/browser readiness remains unproven until an actual server run.


## October 20 — native V1 browser review remediation: SOURCE FIXED, disposable retest required

Governing design: `Docs/02_Production_Database/01_System_Architecture/06_Work_Orders/Work_Order_System_Design.md`, October 20 native V1 operator review section. The earlier `efb0cac` native SQL run PASSED and V1 browser tunnel CLEAN EXIT; operator browser disposition was **CHANGES REQUIRED**, not an acceptance.

Same draft PR #420/branch and original #419 Server Management runner only. The remediation source now covers:
- Grouped personal/Manager work views; Crew visibility on option/optgroup plus existing server authorization; Work Order vs unified search vocabulary; concise priority sort help; request-form button separate from Manager native Create.
- Catalog-backed Task Type filter (Work Order IDs only), including authorized Crew read-only Task Type choices, validated endpoint input and SQL filter prior to LIMIT.
- Original public Intake/raw submitted priority, Task Type, Stage, Work Area shown read-only beside proposed normalized selectors. Populate only uniquely matched catalog values or verified existing IDs; unresolved fields require Manager selection before promotion; source Intake preserved.
- Manager Public Intake promotion **or** non-destructive clarification/reasoned disposition (defer/reject/resolve/duplicate), original reporter reply when linked, no later promotion of finally disposed Intake. The same clone/Production-safe native SQL command and legacy preview writer follow this contract; pending queue and Manager counts exclude disposed items. Reporter missing contact creates auditable no-send/MISSING_RECIPIENT evidence and UI warning rather than a misleading successful email claim.
- V1 SQL disposable validation adds a real-shape nonpromotion disposition and attempted prohibited promotion inside a rollback-only nested fixture before the existing legitimate promotion test.

**Acceptance state: NOT ACCEPTED until exact final commit CI PASS, new original `-V1Validation` on private current-Production clone PASS/CLEAN EXIT, Manager `-V1Browser -V1ReviewerRole Manager` acceptance, Crew isolated `-V1Browser -V1ReviewerRole Crew` API/visibility check, and ownership-verified teardown.** Crew simulation requires no new volunteer account; it is a role simulation, not Production identity mapping acceptance. If time is limited, continue Manager usability review first but keep final Crew authorization and Production approval outstanding. No Production writes, Directus Flow/mail cutover, merging or release authorized.

**Operator protocol:** update the existing clean BLUE `C:\lor\ImportExport\MSB-WorkOrders-419` worktree by fast-forward only to the exact PR HEAD recorded on the final CI-green checkpoint. Use `WorkOrders\Acceptance\run_work_management_disposable_browser_preview.ps1` with `-CandidateSha <exact_sha> -PreviewPort 8898 -PreviewEmail gliebig@sheboyganlights.org -ApprovedReviewProfile -V1Validation` first; after SQL PASS/CLEAN EXIT, rerun as `-V1Browser -V1ReviewerRole Manager`. Wait for explicit browser READY before opening `http://127.0.0.1:8898/`; keep PowerShell open. On any HOLD preserve report and do not launch a second clone. No browser acceptance or Production fingerprint outcome is claimed for the new candidate until the operator supplies the actual report.


## October 20 — second operator review remediation: source CI PASS, native clone acceptance PENDING

Second native Manager browser review found duplicate Manager triage navigation; missing visibility of public Intake #65 in an All Work Orders-only view; no Manager correction of active Work Order priority (WO-123 should be reviewed for Priority 5/Planning); no Cancel during unsaved Create; and no reasoned cancellation of an existing inappropriate Work Order (WO-47). The reviewed browser tunnel ended `WO419 V1 native browser tunnel: CLEAN EXIT`, but **the browser was NOT accepted**.

The controlled Work Order System Design records the full requirements. The same PR #420 now implements:
- Manager Public Intake and Task Feedback as separate buttons instead of duplicate general-scope options. Public requests remain Intake and cannot appear in All Work Orders before a real authorized promotion. `INTAKE-65` should be located in Public Intake or unified search when present in the restored snapshot; Intake recency now has a last-activity fallback for a null Work Order created timestamp. Legacy Directus triage email does not prove a new Work Order exists.
- Cancel direct Create without a database command, discarding unsaved entry and returning to the work list.
- Manager Edit of an active open, non-Testing Work Order: validates actual Task Type, urgency, Planning year, Stage or Work Area; requires a substantive change reason; retains before/after values in durable native activity. Existing WO identity and source links stay unchanged. Do not make the WO-123 real Production correction without separate authorization.
- Manager Cancel / No Action of an active open, non-Testing Work Order with mandatory reason. Native and clone writers mark it inactive but **not physically completed**, record the event, retain original Work Order, reject subsequent assignment/progress/completion, present `CANCELLED_NO_ACTION` separately from completed, and hold an unsent reporter-notification intent. The inclusive closed/inactive list option permits historical review. Linked Testing repair cancellation remains disallowed pending governed Testing reconciliation. A Setup prerequisite is not automatically released as if completed.
- Required SQL integrity regression: exactly one native command function, complete dollar-quoted regular expressions, Edit validation separate from Create INSERT; rollback-only native disposable SQL acceptance tests audited correction to Priority 5/target year and cancellation without a completion date.

**The current source tests and Engineering Compliance passed at the pre-document checkpoint; no new private disposable PostgreSQL run has been performed for these changes.** The next gate is EXACT SHA on original reusable `-V1Validation` (private current-Production clone, rollback, no browser, full CLEAN EXIT). Only after real SQL PASS run the original `-V1Browser -V1ReviewerRole Manager` and test actual workability, including finding Intake #65 when present in the snapshot, correcting WO-123, cancelling a disposable WO resembling WO-47, and Cancel during Create. Never claim successful Production mail delivery or completion from a held notification or cancelled Work Order. Crew visibility/auth checks remain separate final acceptance. Keep draft PR, no merge, Production schema writes, permanent service deployment, Directus Flows or mail cutover without authorization.

Current candidate identity is the exact latest draft PR HEAD at the time of invocation, not a prior conversation SHA. Refresh origin/branch and use the SHA printed in the final green PR checkpoint; STOP on mismatch, HOLD, or incomplete cleanup. No competing runner or port.


## October 20 — operator browser finding: full-width Manager editing

Operator reviewed the native V1 Manager candidate and reported `WO419 V1 native browser tunnel: CLEAN EXIT`, but raised an editing usability issue: the two-column ticket browser is useful for selecting a Work Order yet wastes nearly half the screen after choosing **Edit Work Order**. The native browser review remains **CHANGES REQUIRED**, not Production acceptance.

Corrected in the existing PR #420 application: the explicit Manager Edit action toggles a focused full-width detail workspace, hiding only the left ticket list while editing. The selected Work Order, server-side filter, list data, and source identity are unchanged. Successful Edit save or **Cancel Edit** returns to the standard two-column browsing view; Cancel Edit emits no database command. Existing Create/triage/assignment paths are not rearchitected. The original Work Order change/audit rules remain mandatory. Regression checks verify the conditional edit class, CSS, and return controls.

**Retest gate:** exact CI-green candidate, original sequential 8898 disposable validation/browser infrastructure, actual Edit of a disposable Work Order followed by Save, another Edit followed by Cancel, return to list with prior selection and filters, and owned CLEAN EXIT. No Production deployment, Directus Flow/email cutover, or merge authorized.


## October 20 — third native browser review: focused Intake/Feedback navigation and Production fingerprint HOLD

Operator selected current-Production-clone Public Intake #57 and Setup Task Feedback #65. Records are visible; the last remaining review UX defect was the selected Intake/Feedback record initially opening in two-column browse mode, with focus only after an action. Corrected in existing PR #420: an Intake or Feedback selection itself opens the full-width detail workspace; all subsequent triage/follow-up actions stay focused. A successful saved Intake/Feedback action returns to the originating Manager queue; Back returns through existing queue navigation rather than treating it as a general Work Order selection. New source regression checks selected Intake/Feedback focus.

**Safety / separate HOLD:** The operator's original server report `/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261020T143949.txt` reported cleanup status 81 because whole-table Production WO/assignment/Intake fingerprint differed between session start and end. Owned listener, disposable clone, candidate worktree, port cleanup and shared HEAD checks passed. A concurrent legitimate live change could explain a whole-table difference, but it is NOT proven; the report remains **HOLD, not CLEAN EXIT**. The current runner fingerprints complete `ops.work_order`, `ops.work_order_assignment`, and `stage.work_order_intake` contents, so ordinary concurrent Production writes are indistinguishable from unauthorized preview writes. The governing MSB Server Management disposable standard requires a Production no-unauthorized-write proof; do not delete/disable this check or reclassify the HOLD by fiat. Inspect report, attribution, authorized change logs and Server Management runbook; establish a documented concurrent-safe proof before claiming final acceptance. No Production work paused or rolled back by this test, and no Production data write is authorized here.

The latest source candidate is NOT yet operator accepted or installable. Keep PR draft, no Production deploy or mail/Flow cutover. Avoid asking the operator to repeat a long browser review until the fingerprint acceptance mechanism is reconciled.

