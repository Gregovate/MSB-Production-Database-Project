# #419 Phase 2 completion and release checkpoint

## 2026-10-21 — documentation verification and Backbone ownership

The executable application, SQL migrations and acceptance sources in PR #438
match the installed `24c0c8e526e032f4a7202a77ed14ab9a30b2459b` release; the changes
are documentation only. Source review corrected inaccurate Crew Create claims:
Create is Manager-only in the installed UI, API and SQL. Reporter replies require
an authorized original linked Person, an unanswered clarification, and unpromoted
Intake. Due by is required on Create/Promote/Edit/Set Due by; legacy undated records
remain completable. Sorting, filters and aging are distinct from creation age.

The October 20 receipts below establish deployment and the first actual delivery.
No fresh host inspection or all-event Inbox verification was performed during this
review. Remaining operational evidence is per-event recipient coverage and worker
observation; source checks do not fill that gap. Search performance remains with
the separate performance workstream.

GitHub #419 and Server Management #81 were found closed, despite earlier prose
saying to keep them open. Their closure is not evidence that the remaining
operational checks or portal publication happened. No milestone is assigned to
either issue. Record outstanding operational acceptance under #419; do not label
all Phase 2 acceptance complete solely because the implementation issue closed.

Backbone owns the portal and PR #27. Latest operator direction is **one recolored
Work Orders button**, removing both old Work Order shortcuts and targeting
`/workorder/`. This supersedes the historical instruction to retain Testing's
shortcut; it does not change Testing behavior. Source handoff:
[Internal Web Backbone handoff](../../Docs/02_Production_Database/01_System_Architecture/06_Work_Orders/Internal_Web_Backbone_Handoff.md).
PR #437 owns Setup-procedure discoverability; PR #438 owns these corrected Work
Order SOPs. Backbone publication and protected live verification are separate.


## 2026-10-20 — #419 Phase 2 Work Orders and email — Production PASS

- Installed application: **V1.1.2-manager-utilities**, source `24c0c8e526e032f4a7202a77ed14ab9a30b2459b`; PR #435 merged as `7f88be7d9a6b476fa60688e775b1e044140f5c28`. Infrastructure: Server Management #81, merged PRs #87 and #88.
- Migrations `002_work_management_due_by.sql` and `003_work_management_mail_delivery.sql` applied through existing #37 maintenance, validated rollback snapshot, independent source promotion and return ONLINE. Server regression: **193 passed**. Shared checkout `17c522c4f8ec06549bf7a6d9e8530c61276203f7` preserved.
- Upgrade receipt: `/home/msbadmin/work-management-deployment-reports/WO81-service-a6601b10c3e340b7b3e044c1639aee02.txt`.
- Bounded first delivery: SMTP accepted; Greg explicitly confirmed Inbox receipt. Receipt: `/home/msbadmin/work-management-deployment-reports/WO81-service-2788a2d26bc247e48196e29feae8d0be.txt`.
- Scheduled mail enabled; Setup timer remained active. Receipt: `/home/msbadmin/work-management-deployment-reports/WO81-service-947799d704a94744a7c95c5e2ee73188.txt`.
- Capture ON; only legacy email Flows `ebcde355-32c5-4826-b6fa-360621d0d357` and `9a7fb87b-d78e-492b-b2c5-ac3b521b5cf7` inactive, verified by activation gates. Non-mail Flows/operations and historical pending notifications preserved. Worker runs about every minute, bounded to 50 events; uncertain claimed sends are not automatically retried. Setup daily email schedule is separate and unchanged.
- Greg confirmed the live application working. Utilities is a separate Manager page for fictional no-send email previews. Source templates remain reviewed editable files; this utility does not edit or send them.
- Disposable SQL PASS/CLEAN EXIT at `61b73293f32ca9b49f3be863e3d9da89095db7a0`: `/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261020T234604.txt`. Later Utilities change was presentation-only; no repeat database dump was required.
- Snapshot path/hash and full preservation evidence reside in retained private server journals; their literal values were not supplied in the abbreviated receipt and are not invented here.
- **Follow-ups, not deployment failures:** Apps tile publication remains outstanding; all-event recipient coverage and longer-running worker observation are not claimed. Greg's 3–4-second typed-search delay is assigned to his separate performance thread; no performance investigation or change is part of this closeout. Issue-state reconciliation and remaining evidence are recorded above. These documentation commits do not change the installed application SHA.


## Historical preparation record

The following pre-release status is retained as history and is superseded by the Production receipt above.


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
executed on the current-Production clone but HOLD at the Testing fixture lookup:
report `/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261020T233903.txt`.
The restored data contained no open Testing-linked WO matching the old test.
Setup (836 passed, 5 skipped), FieldWiring (209 passed), Work Orders (163 passed),
clone read acceptance, migration installation and V1 SQL assertions passed before
that failure. Teardown passed; Production fingerprint and shared HEAD unchanged.
The corrected fixture creates its own open WO inside the existing rollback-only
transaction, attaches an existing Testing-session identity, and asserts that
both unrelated WO fields and the complete Testing-session row remain unchanged.
It does not reopen a real completed WO. This correction still requires fresh SQL
acceptance; the earlier failure is not waived.

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
