# Work Management #419 — disposable clone and browser review

**Status: SOURCE-ONLY; not started or browser accepted.** Work Management is the existing MSB Database Work Orders subsystem.

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

**Status:** This is an isolated disposable **infrastructure readiness fix**, not a reason to change Work Order schema, Production app/roles, Directus Flow behavior or reporter notifications. Pin and test the corrected new SHA before the next operator-run attempt.

## Remaining acceptance gates

Run and correct Python source tests, revised WO419 PostgreSQL read model and clone audit before calling the first browser review READY. #419 P0 **atomic triage/Promote & Assign, alternate Setup corrections, original-reporter Request More Information/replies, final resolution emails and noncompeting Directus cutover are NOT implemented or accepted**. No temporary read-only preview can waive those future gates.

This README is the acceptance handoff. As authored, these scripts exist as source on draft PR #420, but the clone/browser has **not run on the server**, and Server Management port/profile PR #80 **merged**; port/clone/browser readiness remains unproven until an actual server run.
