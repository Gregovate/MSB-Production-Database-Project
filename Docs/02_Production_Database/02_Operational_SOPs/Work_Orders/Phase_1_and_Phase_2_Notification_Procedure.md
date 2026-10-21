# Work Management — Phase 1 Intake Notification and Phase 2 Reporter Follow-up

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
- **Follow-ups, not deployment failures:** Apps tile publication remains outstanding; all-event recipient coverage and longer-running worker observation are not claimed. Greg's 3–4-second typed-search delay is assigned to his separate performance thread; no performance investigation or change is part of this closeout. Keep #419/#81 open for remaining scope. These documentation commits do not change the installed application SHA.


## Historical preparation record

The following pre-release status is retained as history and is superseded by the Production receipt above.


**Status:** Phase 1 application is live at https://my.sheboyganlights.org/workorder/. Phase 2 in draft PR #435 is NOT installed or sending. Existing Directus emails remain active.

**Engineering authority:** [Work Order System Design](../../01_System_Architecture/06_Work_Orders/Work_Order_System_Design.md). Existing released task SOPs, Production Directus Flow behavior, and Server Management deployment runbooks govern until explicit cutover.

## Phase 1 — Manager and Crew use the new Work Management application

1. After the permanent Work Orders URL is registered and the link is published in the protected MSB application portal, open **Work Orders** there. Managers and Crew use the same portal link; access differs by assigned privileges. Do not use temporary `127.0.0.1:8898`, an unregistered port, or a disposable preview URL for Production.
2. A volunteer needing a new repair still uses the existing **Submit Work Order Request** Google Form linked from the portal. Existing Setup **Task Feedback** continues to create `SETUP_CORRECTION` Intake through its governed route, not an active Work Order.
3. A new Intake continues to trigger the existing **Directus WOI Request Triage Email** notification to the current Manager recipients. **Keep that Flow active during Phase 1**, together with its verified Directus Intake creation path. V1 application's `PENDING_CUTOVER` outbox is only a recorded intent, not an email sent.
4. Managers open **Public Intake** or **Task Feedback** from Work Management, read the original finding, notes, reporter and context, then decide whether to request more information, assign a correction owner, disposition the feedback, or promote an actual repair request. Promotion is not proof that the original issue was corrected.
5. Existing Directus **Create Repair Work Order**, **Work Order Email Assignees** and **Work Order Complete-Update Display Test Session** flows must be individually inventoried, with their operational side effects verified, before any disablement. Testing completion is not merely an email feature.
6. Legacy Directus Work Order bookmarks may be hidden **only after** the protected Work Orders application link and corresponding authorized workflows are live, checked, and rollback-ready. Hiding bookmarks is not a permission change and does not stop Flows, direct URL access, or API operations. Maintain a documented Manager fallback until cutover is accepted.

### Phase 1 Manager notification verification

An authorized operator submits a controlled real-shape request through the existing form/Setup route, confirms one original Intake ID and correct Manager email recipients, checks that no duplicate active Work Order was created, and verifies the same request appears in Work Management's Manager queue. Do not repeat a public Intake insert directly in PostgreSQL to imitate the Directus event. If delivery fails, retain/re-enable the existing Directus Flow and use the approved incident procedure; do not declare a V1 outbox row `SENT`.

## Phase 2 — Reporter clarification and outcome email procedure (NOT YET LIVE)

### Requesting more information

1. Manager opens the **original** Intake/Task Feedback record and reads the finding/notes.
2. Choose **Ask reporter for details**, enter a specific question, confirm the actual original reporter/contact, and submit once. The question is saved as an attributable event on the same ticket; the owner remains responsible.
3. After the Phase 2 sender is approved/activated, verify the notification was SMTP accepted or visibly flagged FAILED/MISSING_RECIPIENT; confirm Inbox receipt separately. The email must include a limited-scope protected response link. It must **not** disclose unrelated reports.
4. Reporter submits an answer against the same record. The responsible owner sees it in activity and receives the approved response notification. Manager updates next action rather than creating a second Intake.

### Completing, deferring, rejecting or cancelling

1. Choose the accurate authorized outcome. **Resolved/Verified** means the correction was actually verified. **Deferred** needs a reason and follow-up responsibility. **Rejected/No Action** or **Cancelled** needs a substantive reason. **Duplicate/Linked** identifies the actual related case. Promotion to Work Order is not completion.
2. For a linked Work Order, wait for genuine authoritative Work Order completion before a completed-repair notice; cancellation must never be represented as work performed.
3. Once Phase 2 is live, confirm that the *original reporter*, not an arbitrary Manager or default volunteer, is the notification recipient. The notice must identify the ticket, disposition, plain-language reason, responsible owner, and safe ticket link.
4. The system must record stable event+recipient deduplication and actual delivery status. QUEUED, PENDING_CUTOVER and MISSING_RECIPIENT are not successful delivery.
5. If recipient contact is missing or delivery fails, Manager sees **Reporter could not be notified** and is responsible for an approved manual follow-up. Do not silently mark reporter contact complete.

### What to tell Managers before Phase 2 activation

> Work Management currently records clarification requests and correction outcomes, but reporter-facing email for these events is **not active**. If you ask for more information or resolve, defer, reject or cancel a ticket, verify how the original reporter will be contacted. Do not promise that the application sent them an email. When Phase 2 launches, the original reporter will receive targeted clarification and outcome messages, with delivery/failure status visible.

### Phase 2 launch and rollback gate

Before telling staff that reporter emails are active, review the current Directus mail Flows and Google Workspace server delivery contract; approve message templates, recipient mapping, access links, no-send previews, delivery receipts, retry/idempotency, absent-contact behavior and rollback. Enable only one sender for each event and disable only an exact proven duplicate mail Flow; keep non-mail side effects. Test request→reply→resolution, deferred, reject, cancel, later linked Work Order completion, no-address, failed delivery and repeat/retry. Document the Phase 2 activation date and recipients in the owning operations record.

**Production change authority:** These instructions do not authorize SQL migration, proxy/service publication, Flow disablement or a live mail cutover.

## Phase 2 Manager utilities (candidate, not yet installed)

- **Email template previews** shows fictional examples with subject, formatted
  body and plain text. It never sends, queues or edits mail.
- On a selected ticket, **Email delivery status** distinguishes held, queued,
  missing contact, failed, in-progress/uncertain and SMTP-accepted messages.
  Missing contact includes reporters who cannot use the protected response link.
  Arrange manual contact; do not create another account or forward a private link
  as an access workaround. Report failed/uncertain attempts to the operator.
  Do not repeat the business action to resend an email.
- A reporter follows the email link, signs in with their existing authorized
  account and chooses **Reply to clarification** on that same Intake. The answer
  alerts its correction owner, or the Manager who asked when no owner was chosen.
  Replies sent back by email are not ingested. A new reply requires an outstanding
  question; promoted and resolved requests cannot accept an old answer.
- Managers use **Set Due by** for active Testing-linked work. Enter the date and
  a reason; Testing and repair status stay unchanged. General Edit/Cancel remains
  unavailable for those records. Old undated records can still be completed.
- The aging report and exported CSV include Due by and deadline status alongside
  creation age. Due today is not overdue; inactive records are not overdue.
