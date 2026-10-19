# Work Management #419 — disposable clone and browser review

**Status: V0.3 source-only candidate; new disposable-write validation and browser review still pending. V0.2 operator review was CHANGES REQUIRED.** Work Management is the existing MSB Database Work Orders subsystem.

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
