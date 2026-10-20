# #419 Phase 2 completion and release checkpoint

| Control | Value |
| --- | --- |
| Date | 2026-10-20 |
| Candidate | V1.1.1-phase2-followup, draft PR #435 |
| Branch | issue-419-phase2-email-due-date |
| Status | SOURCE CANDIDATE — NOT DEPLOYED |
| Runtime owner | MSB-Server-Management #81 |
| Design | [Work Order System Design](../../Docs/02_Production_Database/01_System_Architecture/06_Work_Orders/Work_Order_System_Design.md) |

## Reconciliation

Application main refreshed at ebea3ff83ea4e4d767b9a8aa6bc19346dafbed34; original
PR head bbd0ad57fb9cc32f0357abc38e5c55a0a3409b05 includes that main. Its two
GitHub checks passed (Work Management 39507059050; Engineering Compliance
39507059236). New commits need their own CI; these results do not transfer.
Server Management main tree inspected at 6c1fb1bbe6c75d46998f46edf9a63f96f6441e5a.
The Work Management runtime authority records installed Phase 1 and signed
identity; older opening statements still require reconciliation.

Prior disposable e3f2d245 PASS/report 20261020T220644 is historical and does not
cover later source-specific templates, preview utility or this completion work.
This execution environment cannot reach 192.168.5.9 (SSH: Network is unreachable).
No Production command, migration, Flow change or email send occurred.

## Source and acceptance coverage

Application/read-model regression: 175 passed. The broader local profile run
had one environmental failure: the existing listener-cleanup test cannot open
a netlink socket. Preserve that gate and require Linux CI; do not waive it or
change the cleanup runner to accommodate this environment.

The existing rollback-only Phase 2 SQL fixture now checks Testing deadline-only
field preservation, original-reporter clarification/reply, owner notification,
repeat-answer rejection, Manager uncertainty visibility and Crew denials. It
has NOT executed on current-Production clone in this workstream.

Use the original `run_work_management_disposable_browser_preview.ps1`, exact
CI-green SHA, registered sequential 8898, `-V1Validation`, then separate
`-V1Browser -V1ReviewerRole Manager` and Crew checks. No new preview runner.
Require SQL PASS, source-specific preview review, deadline save/aging/CSV,
reporter own-ticket and other-ticket denials, delivery-status/no-send behavior,
and actual CLEAN EXIT. Do not start another clone after HOLD.

## Production gates still open

1. Current-candidate CI, disposable SQL and protected browser acceptance.
2. Server Management's governed upgrade of the running independent service,
   migrations 002/003 only, separate mail role, protected pgpass/environment,
   existing #37 freeze/snapshot/return-to-service and preserved shared checkout.
3. Reviewed no-send worker installation and verified exact SMTP transport;
   stop/inspect on uncertain attempts, preserve Setup daily timer/receipts.
4. Controlled atomic event boundary and individually verified retirement of
   only ebcde355-32c5-4826-b6fa-360621d0d357 and
   9a7fb87b-d78e-492b-b2c5-ac3b521b5cf7. Existing pending records stay held.
5. Real authorized request/assignment/clarification/reply/outcome receipt, no
   duplicate messages, retained non-mail Testing behavior, and rollback proof.
6. Apps source is located at `Gregovate/MSB-Internal-Web-Backbone/my/apps/index.html`
   (main 91674b254d204235366f7d9a17f8395ae98149af). Existing Assigned Work Orders
   goes to Directus bookmark 100. Replace only that tile with Work Orders →
   `/workorder/`; retain Testing bookmark 104. Live-page reconciliation and
   controlled Backbone publish are still required, not implied by locating it.

RUNBOOK GAP FOUND: the existing Phase 1 service/database installers require an
absent service/role and are not an upgrade/cutover procedure. Never rerun them.
The responsible Server Management procedure must be completed and tested before
Production mutation. Do not restore a whole database after writers reopen or
remove entered due dates as an application rollback.
