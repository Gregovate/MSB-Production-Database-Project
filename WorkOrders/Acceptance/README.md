# Work Management #419 — disposable clone and browser review

**Status: V0.3 source-only candidate; new disposable-write validation and browser review still pending. V0.2 operator review was CHANGES REQUIRED.** Work Management is the existing MSB Database Work Orders subsystem.

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
