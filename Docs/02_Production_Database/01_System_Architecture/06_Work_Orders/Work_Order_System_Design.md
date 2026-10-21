Warning: truncated output (original token count: 48110)
Total output lines: 1081

# Work Order System Design

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
[Internal Web Backbone handoff](Internal_Web_Backbone_Handoff.md).
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


## Purpose

This document records the current engineering contract for the MSB Production Database Work Order subsystem. PostgreSQL is the system of record for Work Orders. User interfaces and intake mechanisms may change without moving Work Order authority out of PostgreSQL.

## Core Data Model

A Work Order represents one actionable task. Current Work Orders may represent display repairs, build/setup work, shop or facility work, equipment issues, or planning work.

The core model preserves these design rules:

- Work Order identity and lifecycle are owned by PostgreSQL.
- `ref.person` owns volunteer/person identity; there is no separate Work Order user identity model.
- assignments are normalized so one Work Order may have zero, one, or many assignees.
- `display_id` is the permanent Production Database display relationship when a Work Order concerns a display.
- Work Orders distinguish operational urgency from future planning through separate **Urgency** and **Target Year** fields.
- Work Orders use a Stage or Work Area as the operational location appropriate to the task.
- completion preserves who completed the work, when it was completed, and the completion notes describing what was done.

Current PostgreSQL schema, constraints, procedures, and triggers are implementation truth when they differ from older design drafts.

## October 19 — Manager Open Work Order Aging Report (additional #419 requirement)

**Operator direction:** Managers need a dedicated aging report of **all open Work Orders ordered by original creation date**, not a recency list ordered by `updated_at`, a narrow first-page sample, or a mix of human Intake and active Work Orders. Native `ops.work_order.created_at` is the starting date. **Recorded-open means `date_completed IS NULL`**: include Work Orders whose `is_active=false` but which have no completion date as explicit exceptions, rather than letting stale/inconsistent records disappear from review. Do not infer completion from assignment, Testing milestones, active_flag or absent status-history events.

**Implemented draft V0.3.1 source:** Extend the existing WO419-M01 PostgreSQL projection with `opened_at = ops.work_order.created_at` (Intake has NULL in this Work Order report). A new authenticated **Manager-only** aging endpoint queries the same PostgreSQL projection, calculating nonnegative elapsed calendar-equivalent 24-hour days using `CURRENT_TIMESTAMP - opened_at`. The report returns **every recorded-open Work Order without the normal list's 80/100-row LIMIT**, sorted by oldest creation by default, and can also sort by newest creation, native numeric WO ID and urgency in either direction. Show WO number, original created date, days open, recorded priority, human description/location, current assignees, active/inactive exception, and totals by 0–7, 8–30, 31–60 and 61+ days. A Manager-controlled CSV exports the **entire open report**, not only what is visible in the scroll pane; free-form CSV text is escaped against spreadsheet formula execution. The report does not mutate Work Orders.

**Navigation/permissions:** The Manager has an explicit **Open Work Order Aging Report** choice under the existing role-oriented home. Production Crew does not see the option, and the report API rejects Crew requests independently. Crew continues to use My Assigned Work / Created by Me. Opening a row navigates to the actual existing Work Order detail (no duplicate ticket identity or record).

**Test gate:** Source tests verify the no-LIMIT SQL, native creation-date projection, 403 for Crew, all-open/inactive/unassigned counts, urgency/number sorting, full CSV, and native record links. The governed current-Production disposable clone must prove actual `created_at` read and counts before browser READY; operator verifies oldest-first results and report/CSV match, then CLEAN EXIT. These are acceptance requirements, not an assertion that V0.3.1 was deployed. No Production DML, notification send or Flow cutover.

## October 19 — Work Management disposable operator browser acceptance: CHANGES REQUIRED

**Operator source evidence:** The V0.3 disposable Manager browser on the current private Production clone was usable and ended **`WO419 workstation browser tunnel: CLEAN EXIT`**. This confirms the workstation tunnel exited cleanly; separately require retained server-side cleanup/fingerprint report before claiming full acceptance. Operator explicitly **did not accept** the workflow. Preserve the existing good Manager pending Intake/Task Feedback banner and the Manager Open Work Order Aging Report.

**Workflow failures and governing corrections:**
1. **Assigned Work Orders must be actionable immediately.** Opening WO-402 (the "Sally" panel/LOR Wiring change, physically completed weeks earlier) showed no obvious way to record what was done and mark complete. The old Directus Work Order screen exposed Completion Notes, Completed By, Date Completed and Repair Complete; the new UI must preserve those functions **more efficiently**. In an open WO, make **Add Work Note** and **Complete Work Order** direct labeled actions at the **top of ticket detail**, with required substantive notes. The backend resolves completer identity/date from the authenticated active Person, never from operator-editable Completed By/Date. Normal crew can work assigned WOs; Manager may work/complete WOs when authorized. Work notes must not silently mark complete. Any truly closed WO must not offer duplicate completion.
2. **Manager assignment is maintenance, not crew repair execution.** Manager sees an explicit **Assign / Reassign** button in WO heading, opening normalized active-Person selection and retaining assignment/unassignment history. Not placed as the main/default work action among notes and completion. Crew cannot see or call Manager assignment permissions. Public Intake triage and Task Feedback remain separate queues/actions.
3. **Create is a real command.** `+ Create Work Order` must open a blank editor immediately; never require an additional vague `Select proposed action` dropdown, never carry another ticket's text, location, assignees or urgency. It saves only on the isolated clone during disposable review, with Manager and Crew authorization rules preserved.
4. **Browser Back stays inside the application.** Work queue/view/ticket selection uses in-app `history.pushState`/`popstate` navigation. Back restores the prior queue/filters, selected Work Order and list scroll (including return from aging-report drill-through), rather than exiting the Work Management screen. Browser Forward and Create state must also be recoverable. The application cannot invent new server routes or reload Production.
5. **Protect long-range ideas, including WO-105 "New Area 5 Shelter".** Operator said this is a very valuable planning idea but **must not pollute routine repairs and assignments**. Existing priority `5` is labeled `Planning`; expose a reversible **Show planning work (Priority 5)** boolean toggle in **every authorized view and the aging report**, default OFF for normal work. Backend applies it before LIMIT; keep unknown priority visible. ON restores original pending/open planning items with full detail. **Never auto-complete, delete, down-prioritize, archive or promote them into active repair assignments.** This is an initial view contract using current native urgency 5; it is *not* proof that an independent durable "idea vs repair" classification flag already exists. Any future independent classification schema needs separate reviewed authority and migration.
6. **Sort terminology must be human-readable.** `Critical first` / `Planning first` was confusing. Use `Priority · Most urgent first (1 → 5)` / `Priority · Least urgent first (5 → 1)`, ticket number ascending/descending, and oldest/newest creation date; keep server sorting numeric/urgency before row LIMIT in every view.
7. **Readable consistent MSB typography/theme.** Operator reported undersized browser text even at high zoom. Bounded #419 adjustments increase routine text to ~15–17 px and make action buttons obvious while following existing [#159 standard light/dark palette](https://github.com/Gregovate/MSB-Production-Database-Project/issues/159) and [#140 semantic CSS meanings](https://github.com/Gregovate/MSB-Production-Database-Project/issues/140). Do not invent another project-wide CSS system from within #419 or change all apps while testing this one.

**Safety/acceptance:** preserve governing native `ops.work_order`, normalized assignments, Intake and real Testing generated repairs; the disposable clone is intended to persist test edits and discard them at cleanup, with no outgoing emails or Directus Flow cutover. No user-reported WO-402 or WO-105 status is permission to alter those Production records. Source CI is not actual browser acceptance. The next test uses the **same** Server Management sequential localhost 8898 wrapper and a new exact candidate SHA, real Manager/Crew role sessions, save/refresh/back/forward/aging filter checks and final server cleanup/fingerprint proof. Current PR #420 stays draft and operator review remains **CHANGES REQUIRED**.

## October 19 — Atomic Work Order ↔ season-only Setup integration

**Operator requirement:** A park repair identified during seasonal Setup (examples: Magic Igloo welds / LP-08 damaged outlet box) should be captured as a Work Order **and** one linked seasonal Setup obligation without navigating an unrelated second editor. Work Order completion and Setup readiness must remain consistent. This must not create reusable Catalog knowledge or require reporting the same physical repair twice.

**Existing authority confirmed:** Setup migration `050_add_setup_scheduling_board_foundation.sql` already provides `ops.create_setup_season_task(...)` for authenticated Managers, `ops.setup_session_task.task_origin='SEASON_ONLY'`, and `linked_work_order_id/linked_work_order_gate`. Its released Board projection in `setup_scheduling_board_repository.py` shows `WAITING_ON_WORK_ORDER` while the native Work Order is incomplete and `effective_complete`/board `COMPLETE` once `ops.work_order.date_completed` is recorded. This is the appropriate existing one-job/two-context contract, not a new Setup workflow or Work Order status history.

**V0.3 disposable candidate in draft PR #420:**
- Crew may create a real, initially unassigned internal Work Order and select **Flag for Manager Setup review**. That request is recorded in an attributed ticket event; Crew cannot run the privileged Setup annual task function, assign volunteers or declare a report complete by flagging it.
- Manager can choose **Create linked season-only Setup task now** while creating/promoting a Stage-based repair Work Order; the native Work Order insert and `ops.create_setup_season_task` execute in the **same transaction**, with exact chosen open `PLANNING/ACTIVE` season and permanent WO identity. Failure rolls back both.
- Manager can also use **Add this Work Order to seasonal Setup** from an *existing* Stage-based Work Order (including a Crew-created one). It reuses that Work Order ID and source Stage/problem, checks for an existing seasonal link, and creates **one** annual `GATE`. It never creates a duplicate WO or Intake.
- Non-Setup work remains a Work Order; Stage membership alone does not silently create annual tasks. Seasonal integration requires a deliberate Manager selection. No `ref.setup_task` reusable record is generated. Selecting a historical or closed season fails. Original Work Order actor, assignees, repair notes and audit remain authoritative.
- Work Management does not itself schedule a crew/day, modify seasonal annual actuals or create `ops.setup_task_progress` records. Those remain #122/#205 responsibilities. Underlying Setup effective completion follows the genuine native Work Order completion. The existing restricted Setup command and Directus actor authority are retained.
- Current clone-only activity stores the proposed integration evidence and no-send receipts; Production publication of this cross-app feature requires reconciliation of durable source/linked references, least-privilege grants, and full role/Setup/browser acceptance before deploying either side.

**Acceptance:** current-Production isolated clone restores the real annual Setup Session, passes `Create WO → create annual GATE → confirm SEASON_ONLY/no reusable key/link truth → complete native WO → confirm Setup Board projection → savepoint rollback`; also tests Crew request/denial, existing Crew WO Manager link, duplicate/retry protection, exact season selection, and no-email/Production invariants. Retain WO-372/WO-416 as read-only recognizable fixtures until authorized disposal testing.

**Related future lifecycle:** [#423 January 2027 Takedown](https://github.com/Gregovate/MSB-Production-Database-Project/issues/423) is a separate #122-governed, container-first operational release with January 1 readiness; its physical loading/movement/testing handoff uses #88/#230/#231 and may generate Work Orders, but #419 must never become a competing movement or storage system. Takedown is the first operational preparation for the following Setup season, not a pretext to fabricate 2027 Setup task progress.

## Work Orders V1 secure write architecture — candidate design pending disposable database validation

**Approved product intent, not deployment authorization:** V1 must retain native `ops.work_order`, `ops.work_order_assignment`, and `stage.work_order_intake`, plus existing Testing repair creation and seasonal Setup gate behavior. Tom's October 19 decision remains controlling: non-Managers submit the same public Park/Workshop **Work Order Request** into Intake; native creation and promotion by authorized Managers; no Intake assignment or target year; urgency defaults 3, target year only for Planning urgency 5; authenticated assignees record work notes and completion.

**Pre-release source candidate:** `WorkOrders/Database/001_work_management_v1_governed_commands.sql` introduces only supporting Work Order permission, activity and held-notification-intent tables inside the established `ops` schema; these **do not become a new ticket system**. Database-side `ops.work_management_v1_actor`, `ops.work_management_v1_command`, and `ops.work_management_v1_activity` enforce verified active `ref.person`/Directus identity, scoped Manager approvals, active assignment for Crew updates, request-key idempotency, native Work Order identities, completion notes/date/person, and permanently retained Intake-linked events. Only a reviewed dedicated `work_management_app` LOGIN gets **EXECUTE** on narrow command functions and whitelisted read-only tables, never browser direct authoritative WO DML. No named Work Order Manager grants are generated at migration; these require separate recorded approval. V1 `Production` identity is explicitly **not** equivalent to the existing broad Setup Manager boolean.

**Application:** `WorkOrders/Application/v1_runtime.py` and `production_entry.py` are separate, disabled-by-default paths for the existing `backend.py` and unified interface. Production backend cannot connect through the disposable clone token or preview role, and cannot write without exact release env gate/registered protected reverse proxy/private command secret. Server-side SQL independently re-authorizes the Person on every action; only verified assigned Crew can update or complete. No alternate Work Order table, synthetic WO numbers, or client-supplied `completed_by` or completion timestamp.

**Mail/Directus boundary:** `ops.work_management_outbox` is durable only; each queued intent remains `PENDING_CUTOVER` (or `MISSING_RECIPIENT`) and **does not represent a sent email**. A future operator-approved single MSB mail delivery worker, retry evidence and Directus/Apps Script Flow reconciliation are necessary before mailing. Existing public Form/Intake notifications/Testing remain unchanged until explicit cutover. New code does not silently reassign/reopen/close historical Production WO-372/402/400/107/147/389/416.

**Acceptance gaps:** Source regression passing does **not** prove PostgreSQL function SQL parses or the migration matches the current-Production schema, row locks, existing triggers, privilege matrix or notification behavior; the proposed migration must run against the actual disposable current-Production clone with Manager/other-Crew negative rights, rolls back on failure, and must preserve Production fingerprint. Permanent server service/proxy/port is a Server Management runbook gap—do not repurpose the existing sequential 8898 preview allocation. An explicit Production DB maintenance/snapshot window, exact operator accepted browser SHA/version, named Manager grant review and rollback plan precede any merge/deployment. The source remains draft/CHANGES REQUIRED.

---

## October 19, afternoon — Tom/operator correction: request-to-Intake before Crew Work Orders (supersedes earlier direct-Crew-create decision)

**Governing operator decision made during live Command Center review:** All **non-Managers** must submit a **Work Order Request** to the **same existing Park/Workshop Google Form** as other reporters (`https://forms.gle/Gve4ZbXHDWxs43yh6`), feeding the existing `stage.work_order_intake` and established Manager investigation/triage. They **must not directly create native `ops.work_order`** from the internal Work Management app. Do not create a competing second Intake model or use unassigned native Work Orders as a substitute for triage. A request may be clarified, rejected/closed, or promoted/assigned during Manager triage. Crew still may read/complete truly assigned Work Orders with authenticated required actual-work notes.

**Manager-only direct Create:** Retain the existing native Create editor for a **verified Manager** (capability from `ref.setup_browser_capabilities`, not `ref.person.is_manager` or any informal flag). Server commands must reject non-Manager direct Create even if they forge `can_create` or POST directly. Manager may optionally create an unassigned native WO without routing through Intake; Intake promotion is the normal route for volunteer submissions. No Intake assignments, target year, or native work-order ID before approval/promotion. Manager may assign one or more volunteers **at triage/promotion**.

**Urgency and year:** Default new Work Order urgency to **3 — Normal**. No default target year or target-year request at Intake. The *native* Work Order editor shows/accepts **target year only for urgency 5 — Planning**; require a valid year when creating/promoting Planning. Other priorities omit target year in the form and the PostgreSQL save. Existing historical Work Orders retain existing fields unless a Manager performs a separately authorized correction. Public Google Form default, if any, is owned by the existing Google Form and not silently asserted/modified in this source branch.

**People:** Existing `ref.person.available_for_work_orders` boolean merits dependency review since the new assignment picker searches People, but do not remove it or modify authoritative People without verifying current references and release scope.

**Permission follow-up:** Operator expressed concern about effectiveness of a delegated Manager. Do not revoke named individual's permissions without separate explicit authorization. Review whether Work Order triage rights should be separated from broader Setup management permissions rather than conflating manager labels.

**Source-only:** #419 draft PR #420 implements the application route and authorization/Planning year rule. Preserve original Park/Workshop public form URL, Intake statuses/manager queues, historic WO projections, notification no-send, and independent #88/#171/#230 scope. Browser acceptance still CHANGES REQUIRED until controlled disposable UI retest. No Production or Directus/Google Form deployment.

---

## October 19 — #419 role-oriented Work Management home and universal sorting

**Operator decision (supersedes any Manager-only direct-create assumption):** The existing public Google Work Order Request Form remains reachable from the MSB portal for any reporter, including users with sheboyganlights.org accounts. Its existing Park/Workshop branches and Apps Script stay unchanged. A public submission enters `stage.work_order_intake` for **Manager triage**; it must not silently become an active Work Order.

**Internal Production Crew:** A signed-in, uniquely linked active MSB Person with existing Crew browse permission may **create a native Work Order directly** without the public form or fake Intake. This creation is intentionally **unassigned**, with attributable reporter/creator, description, location, actual catalog Task Type, urgency and target year. The Manager later assigns it. Crew home defaults to **My Work** (their exact active Person assignments), with Show completed, sorting, details, required-note authenticated Complete for assigned WOs, and a separate My Submitted Feedback view. Crew **must not receive a Manager Intake/Task Feedback triage queue, Intake counts, assignment editor or Manager global queues**. Crew may still open the existing public form link to report an issue through the public process.

**Manager:** In addition to normal My Work and internal direct Create, Managers can assign/reassign multiple active People with normalized history and work-order owner accountability; see all/unassigned/emergency/Testing/other Person views; review and promote public Intake through the existing governed one-step flow; and route Task Feedback through its separate correction lifecycle. Manager homepage must **automatically show actionable pending Public Intake and separate pending Task Feedback counts/links whenever nonzero**, without opening Directus or changing search filters. These counts are Manager-only server responses; hiding HTML is not authorization.

**Every list/view, including Crew My Work and My Submitted Feedback as well as Manager queues, has selectable sorting by** existing urgency/priority ascending or descending **and numeric native Work Order/Intake ID ascending or descending**, performed in the PostgreSQL query **before LIMIT**. The display must label Intake priority as a reporter-proposed estimate, not a triaged urgency. Do not sort ticket strings lexically (WO-100 before WO-99). Different native ticket types remain distinct and identities unchanged.

**Authority:** Use current verified `ref.setup_browser_capabilities` and linked `ref.person` as the interim protected preview read/Manager classification, not an invented account list. Work Management command permission is independently enforced: direct Create for authorized Crew/Manager, Assign/Promote/Correction owner/disposition for Manager, Complete by Manager or actual active assignee. Full Production Work Order-specific role/policy mapping remains a pre-release gate. No email transport, public form change, Production record edit or Directus Flow cutover is authorized by this decision.

**Acceptance:** Review with **both a Manager and an actual Crew reviewer**, using the same established sequential 8898 disposable runner and a new clone per approved reviewer; verify Crew cannot view Intake/Manager queues or assign another Person, but can directly create a native unassigned WO and complete an actual assigned WO with notes. Verify the Manager sees pending Intake immediately, can resolve/reassign, and both roles can numerically sort any permitted list. Clone writes are discarded at cleanup; no-send notification receipts only.

## October 19 — V0.3 operator review: disposable saves, ticket-local actions and Setup brand

**Operator correction:** V0.2 CHANGES REQUIRED. The controlled current-Production **disposable** browser must permit real saves against the isolated clone as established for other MSB applications; blocking all writes was a mistaken engineering restriction, not an operator decision. Notifications remain no-send. Ticket actions belong in selected Work Order/Intake detail; Manager New Work Order belongs at the top. Reuse the released Setup MSB blue/white SVG assets, shared msb-theme key, and Setup color variables in both themes.

**V0.3 candidate implementation:** Existing Work Orders and normalized assignment rows remain authoritative. New clone-only commands use real Person/Manager authorization, explicit private clone IP and db name, a distinct private clone authorization token, CSRF, request-key deduplication, native completion fields and existing Testing data triggers. Existing Intake is retained during candidate one-step Promote & Assign, with an attributed clone-only link/history; no destructive legacy triage trigger. Clone-only correction owner/questions/replies/dispositions and a NO_SEND outbox provide browser-verifiable history without introducing a new Production ticket authority. No Production mail path, Directus Flow, Google Form or Work Order record is modified.

**Acceptance remains gated:** Source CI is necessary but not enough. On the **existing** Server Management disposable runner, validate real schema/trigger grants and Create→Assign→Complete on a savepoint-rolled-back clone fixture before browser READY; then verify Manager actions, feedback, Testing-origin repairs, rollback/failure cases and clean exit. Reconcile any discovered mismatch in this owning design rather than patching Production or inventing defaults. Do not claim Production capability or reporter email delivery from a clone-only result. PR #420 remains draft. Historical findings WO-372/400/107/147/389 and WO-416 are preserved unchanged in Production.

## #419 Manager-only Intake triage and existing public Google Form boundary (October 18)

**Operator direction:** Intake review/triage is a distinct **Manager task/queue**, not an ordinary volunteer's My Work list and not automatic promotion. The Manager opens submitted public requests, reviews original reporter/source and location, resolves missing information, corrects urgency/type/target year, and chooses the governed disposition and assignees. Triage must not be conflated with the separate active Work Order queue or with Testing-origin repair assignment. The one-step Manager **Promote & Assign** command and preservation of original Intake evidence remain mandatory.

The current [public request SOP](../../02_Operational_SOPs/Work_Orders/Submit_a_Work_Order_Request.md) documents an existing **Google Work Order Request Form** reachable from `my.sheboyganlights.org`, requiring no Directus login, with two conditional branches:
- **Park:** show-site/park work with park location and problem details; resolve the supported Stage/park relationships during Manager review.
- **Workshop:** workshop, storage, office, equipment and other non-park/general work; resolve a valid **Work Area**, not a fabricated Park Stage.

The accepted Stage XOR Work Area rule still applies to promoted Work Orders. Public requests enter existing `stage.work_order_intake` and await Manager triage; they do **not** become active `ops.work_order` merely on form submission. The current [triage SOP](../../02_Operational_SOPs/Work_Orders/Triage_a_Work_Order_Request.md) describes Submitted/Promote/Delete legacy choices, but the governed #419 design must retain required source/report/provenance, use atomic assignment and avoid destructive correction disposition. Treat Task Feedback (`SETUP_CORRECTION`) as a separately filtered correction-review route within the Manager function, not as an indistinguishable repair Intake.

**Form-code provenance gap:** the Work Orders SOP states that an **attached Google Apps Script** depends on the form's current question titles/answers and branching. Current repository-tree reconnaissance found the public-facing SOP and screenshot evidence and the separate #172 `Setup/Application/setup_work_order_intake_api.py` / `Setup/Database/062_add_setup_context_work_order_intake.sql`; it did **not** establish a version-controlled export of the public Google Form's Apps Script. That script's live source, destination mapping, validation and ownership must be inspected and documented before changing the form or Intake parser. Do not misidentify the #172 authenticated Setup API as the public form's Apps Script, invent source code, or change the external form during #419 UI implementation.

**Browser acceptance:** Manager sees separate Public Intake/Triage and Task Feedback review queues and can distinguish Park/Stage from Workshop/general Work Area; a submitted public request may be reviewed, assigned and promoted once without losing original data. An unprivileged volunteer cannot triage. Testing-generated active repair jobs never enter public Intake. Capture end-to-end cases for both form branches against approved disposable records; no live Google Form submissions or outbound email during disposable acceptance unless separately authorized.

## #419 launch-critical park repair punch list and urgency queues (October 18)

**Operator browser finding:** WO-416, Light Pole 8 Outlet Box Damaged, appears among assignments without urgency sorting or an actionable Manager workflow. The existing Work Order system must serve as the *2026 setup punch list and show-season repair manager* for problems discovered during setup or in the park that are **not reusable Setup Catalog tasks**. Do not create annual/reusable Setup tasks to compensate for the missing Work Order UI. Link the real Stage/Display/Container/asset and relevant Setup gate when supported; retain authoritative Work Order identity.

**Existing urgency catalog remains authoritative:** 1 Immediate/Critical (including emergency weather/operational repairs); 2 High; 3 Normal (routine repair); 4 Low; 5 Planning. The public Request priority is merely an Intake estimate until Manager triage. Managers must be able to set/correct urgency, filter and sort by urgency as the default actionable repair queue, with completion/target-year ordering and explicit unassigned/overdue views. Display readable urgency labels and emphasize critical items without replacing database priorities with a new category. Surface critical unassigned work immediately and preserve accurate owner/acknowledgment and next action.

**Operational two-mode use:** pre-show punch-list discovery/assignment/completion for one-time setup findings, and during-show immediate/emergency response and normal park Display repairs. Provide a dedicated Testing-generated repair filter without hiding the same Work Orders from appropriate My Work/All Work views. Emergency notification must have reviewed and audited event/recipient authority, delivered-vs-queued truth, and one sender per event; do not assume the current Directus mail Flows implement a verified new emergency alert. Completion uses required notes, authenticated completer/date and linked Testing or Setup prerequisite behavior; non-completion or deferral cannot falsely release a Setup dependency.

**Release blocker:** a read-only list lacking Create, multi-person Assign/Reassign, urgent triage/sort, completion, Intake, feedback correction and notifications is not an operational punch-list candidate. Verify these actions end-to-end on a disposable current-Production clone with no-send delivery and real-shape park repairs before operator acceptance or any Production cutover. Preserve existing Directus/Testing operations until individually reconciled.

## #419 first operator review — representative backlog dispositions (October 18)

The active read-only disposable review exposed actual existing records with stale completion/assignment states. These are **operator-reported findings**, not verified Production corrections. Source screenshot references are held in the operator conversation; no private report text or contact data is required in this design.

| Existing WO | Operator finding | Required future authorized action |
| --- | --- | --- |
| WO-372 — Magic Igloo broken welds | Physical work completed Saturday, as part of testing schedule advancement; still recorded not complete | Verify completed work and required completion notes; mark complete using the authenticated Work Order workflow and confirm the related Setup scheduling gate reflects authoritative completion. Do not fabricate Report Work. |
| WO-400 — Stage 17 wiring photos not appearing | Should be assigned to Adam | Resolve Adam to one exact active `ref.person` identity before Manager reassignment; preserve prior assignment history and make notification accountable. |
| WO-107 — candy cane display naming from Wiring | Operator reports this was resolved through Controller Inventory and Controller label work | Review the completed correction and record substantive completion notes through the existing Work Order completion lifecycle; do not automatically infer the Work Order's completion timestamp from implementation history. |
| WO-147 — Food Collection background Wiring work | Operator reports complete | Review and mark complete with required notes and authenticated completer; preserve original evidence. |
| WO-389 — rack RD04-B-03 for Container C213 | Depends on database change, rack-space creation and #230; defer attention until Dec/Jan | Keep visible as deferred/planned follow-up with ownership, reason, #230 link, and target review period, not an incorrectly completed Work Order or forgotten My Work item. Verify existing status/target-year capabilities before adding a new state. |

These examples establish a **backlog reconciliation** use case: Manager must distinguish completed-but-open, reassignment required, planned/deferred dependencies, and actually actionable open jobs, without bulk mutation or erasure of history. The Work Orders UI must provide clear human-readable owner, next action, provenance, target/review date where supported, and accurately recorded completion status. A volunteer who discovers an old assignment is not assumed to have been notified or to have accepted responsibility. No Production writes were authorized by this browser review.

## #419 browser finding — assignment backlog and dedicated Testing view (October 18)

During the first successful read-only browser review, the operator found that Work Orders assigned to the signed-in volunteer included previously unknown work, work needing reassignment, and work physically done but not recorded complete. **Do not interpret current assignment or recorded status as evidence the volunteer received notice or actually performed the work.** The candidate exposed a real historical operational backlog; no Production assignments or completions were changed by reviewing it.

The unified application's Manager workflows must make **New Internal Work Order**, **Assign/Reassign (one or multiple existing People)**, **Unassigned**, and **Review/Complete** easy to discover without reverting to Directus table navigation. Preserve assignment history, legitimate actual completion notes, actor/time and Testing integration. A physically completed but open record requires review and authorized completion, not automatic bulk closure. Reassignment must not rewrite who historically held the assignment.

**Dedicated Testing Work Orders view:** retain the existing Testing-origin repair identity and automatic creation rules, but present a separate filter/queue for Test Session repairs, including repair jobs still requiring human assignment, alongside the general My Work and All Work Orders views. This is a *view of the same authoritative ops.work_order records*, not a new source of truth or Intake pathway. Assigning Testing work remains a deliberate authorized Manager operation; do not confuse automatic repair creation with automatic assignee selection. Completion must still update the linked Testing record through the approved lifecycle.

The read-only V0.1 browser cannot exercise these required commands and is **CHANGES REQUIRED**, not P0 acceptance. The findings do not authorize Production data cleanup, alternate completion SQL, Flow retirement, or a new database model.

## #419 — Unified MSB Work Management Application Contract (October 18, 2026)

**Engineering authority and status:** This section records the agreed operating model and the **verified current Production findings** for [#419](https://github.com/Gregovate/MSB-Production-Database-Project/issues/419). It governs application implementation and regression acceptance; GitHub issues track the work and PRs implement it. **New Work Management screens, correction ownership/replies, and reporter notification workflows are NOT deployed merely because this design or a candidate SQL query is committed.** The earlier production Work Order and Intake data models remain authoritative.

### Subsystem ownership and implementation location — confirmed October 18

**Controlling operator decision:** MSB **Work Orders / Work Management is already a Production Database subsystem**, with its established engineering authority and portal at `Docs/02_Production_Database/01_System_Architecture/06_Work_Orders/`. The new ticket-focused Work Management application is **the next implementation of that existing subsystem**, not a new independent MSB subsystem or a separate GitHub repository. Keep all source, database contracts, application code, acceptance tests, and engineering documentation under **`Gregovate/MSB-Production-Database-Project`**, organized in the existing subsystem and the project's normal application/database/test trees. Do not ask the operator to create `MSB_WorkManagement` or move these authoritative records to another repository.

- **Authority:** PostgreSQL remains the one source of Work Orders (`ops.work_order`), normalized assignments, Test Session repair links, and existing Work Order Intake (`stage.work_order_intake`). Reuse existing Setup Task Feedback submission, public Intake, existing Directus/Testing integration and all approved identities; do **not** create another master ticket or Intake database.
- **Existing engineering home:** the `06_Work_Orders/Work_Order_System_Design.md` document **is** the governing subsystem design; `06_Work_Orders/README.md` is its portal/resume handoff. Application implementation belongs in the same MSB Database Git repository under a clearly named Work Order/Work Management source area aligned with the existing Setup/People/FieldWiring conventions. Establish the exact application directory from current repository structure before creating it; do not invent a parallel documentation hierarchy.
- **Separate deployable does not mean separate repository:** the Work Management browser service may have its own controlled runtime, route and version while remaining in this repository. Server Management still owns the registered disposable review-port and deployment/runbook procedures; they do not move the business application into a new GitHub repository.
- **Existing cross-system boundaries:** #172 Setup Task Feedback remains its existing free-form entry point; Testing owns generation/feedback of test repair events; Setup #205 consumes real Work Order completion gates; Directus automation must be deconflicted at the approved laun…26110 tokens truncated…n for the Setup-to-Directus create boundary:

- `SETUP_DIRECTUS_URL` — defaults to the documented local Directus listener `http://127.0.0.1:8055`;
- `SETUP_DIRECTUS_INTAKE_TOKEN` — required bearer credential for the Directus identity authorized to create Work Order Intake records.

The bearer credential must not be committed to Git or exposed to the browser. Cloudflare service-token headers are not required for the local host-to-Directus call on the Production server.


## October 20, 2026 — Native V1 operator browser review: required corrections (NOT ACCEPTED)

This controlled requirement derives from the operator's first native V1 Manager browser review of draft PR #420 (reviewed candidate `efb0cac290920e84e949b8f9c7f63a00683df5da`). The native disposable SQL validation previously PASSED, and the operator subsequently reported `WO419 V1 native browser tunnel: CLEAN EXIT`. These prove neither application acceptance nor production-readiness. The native browser remains **CHANGES REQUIRED**.

1. **Predictable work navigation.** Present logically grouped, ordered personal, Work Order/all-ticket search, and Manager-only views; avoid a long unsorted mixture. Keep actual Work Order language for Work Order-specific screens, and reserve “all tickets” for the unified Work Order + Intake/Feedback search. Distinguish their coverage in UI.
2. **Role-based visibility and authorization.** Manager-only global/aging/urgent/unassigned/Testing/Public Intake/Task Feedback triage and native Create must be absent for ordinary Production Crew, with matching server-side denial for protected operations. Crew retains assigned work and public Work Order Request. Do not infer Crew acceptance from an admin account. The established **disposable** runner has `-V1Browser -V1ReviewerRole Manager|Crew` modes and can exercise separate simulated reviewer capabilities without provisioning a new real volunteer, but test results must state that this is an isolated reviewer-role simulation, not proof of actual Production identity mapping. Execute sequentially on the existing shared 8898 and separately check API authorization. Lack of a real Crew test account is **not** a reason to block ongoing Manager usability iteration; Production release still requires verified access control.
3. **Search by Task Type.** Supply a real catalog-backed Task Type filter/search for Work Orders alongside text/number, with well-defined applicability to Intake and feedback and no guessed raw-to-ID mapping.
4. **Controls and language.** Remove duplicative priority help text when option descriptions already communicate priority semantics; retain necessary guidance for ambiguous cases. Render the public `Submit Work Order Request` as a clear button/action rather than a bare text link. Managers have a distinct `+ Create Work Order` native action; Crew must not directly create active Work Orders.
5. **Intake review before promotion.** Show original request/raw submitted values **read-only** beside proposed real Work Order fields; safely prefill catalog identities when resolvable and explicitly flag unmapped/ambiguous values. Let an authorized Manager compare, adjust and confirm normalized urgency, Task Type, Stage/Work Area and applicable context before promotion. Examples observed: raw Priority `2` alongside blank Urgency ID, raw Task Type `Repair` alongside blank Task Type ID, raw Stage `06-Post Office-PO` alongside blank Stage ID. Do not invent IDs or overwrite the original request.
6. **Full, non-destructive triage disposition.** Not every Intake becomes a Work Order. Expose explicit `Promote to Work Order`, `Request More Information`, `Reject / No Action`, `Defer`, and governed non-repair correction/feedback routing. Require substantive reasons/ownership/next action as appropriate. Preserve source Intake and reporter provenance. Clarification, response and final outcome events must stay linked to the original reporter and honor the existing notification/held-mail cutover design. The legacy destructive raw Intake dropdown is not the lifecycle contract.
7. **Acceptance gates.** Update application/acceptance documents and regression on this existing PR; test Manager native Create, comparison/correction/promotion, nonpromotion outcomes, Task Type search and naming, sequential disposable Crew view and protected API denials, no-send, clean server teardown and unchanged Production fingerprint. Draft PR remains unmerged and no Production SQL, app service, mail or Directus Flow change is authorized by this browser review.

The operator may prioritize rapid UI iteration now; record deferred production-only identity verification explicitly rather than silently declaring all role acceptance complete.


## October 20 — second native V1 operator browser review: Work Order edit/cancel and Intake discoverability (CHANGES REQUIRED)

Operator submitted six screenshots and reported `WO419 V1 native browser tunnel: CLEAN EXIT`. CLEAN EXIT confirms teardown, **not** browser acceptance. Existing draft PR #420 remains unmerged; no Production Work Order/Intake mutation, mail send or Directus cutover is authorized by this finding.

1. **Distinct action navigation:** Keep the prominent Manager Public Intake and Task Feedback review buttons in the Manager attention banner. Do not duplicate those same queues inside the generic `Show work for` selector; scope selector should focus on finding and managing Work Orders, with personal/Manager Work Order views clearly grouped. The existing public request entry remains a distinct button.
2. **Current public Intake discoverability:** An actual legacy Work Order Request triage email for Intake **#65** was observed, referring to a newly submitted request about recording weld repair observations during takedown. It is **Intake, not yet an active Work Order**; an All Work Orders-only view must not show it as a newly created WO. The dedicated Public Intake queue and unified search must expose `INTAKE-65` if that unpromoted row is present in the current restored source snapshot, and show its original received time/raw provenance/status. Reconcile the actual Production snapshot timing and legacy Directus triage state before inferring data loss. Do not fabricate a new WO to make it visible. If it was already processed in Production, preserve and report the resulting linked WO or disposition; give a clear not-found/snapshot boundary if it did not exist at clone creation.
3. **Governed Manager edit on existing Work Order:** Provide a distinct Manager-only Edit action for correcting problem/description, Task Type, urgency, Stage vs Work Area and target Planning year with validation against current catalogs, original and corrected values, actor, time and reason in durable audit. Ex: WO-123 describes a 2026 rebuilding proposal and was recorded Priority 4; operator believes this should be **Priority 5 / Planning**. This is a requested correction, not permission to mutate the real record without operator approval; ensure Planning year is required only with Priority 5 and preserve source ownership/links. Protect completed and linked Testing/Setup WO semantics against unauthorized retroactive edits.
4. **Cancel direct Create:** Provide a Cancel button to abandon unsaved Manager Create without creating Intake or Work Order, restoring prior list/detail/scroll, with appropriate unsaved-change guard.
5. **Existing WO cancel/reject/no-action lifecycle:** Distinct authorized Manager action for an inappropriate/no-longer-actionable existing Work Order, with mandatory substantive reason and actor/history. WO-47 is the operator's example of a potentially damaging suggestion to use a pick axe/hatchet near frozen lighting cords; retain the original request, do not mark physically completed, and ensure it no longer appears as active repair work. Do not treat `repair_complete` or `date_completed` as synonyms for cancelled. Reconcile existing status catalog/history, assignment effects, Setup prerequisite release, Testing result semantics, legacy Directus Flows and eventual reporter closure notices before defining native SQL command. No destructive deletion. Also distinguish Intake rejected before promotion from an existing WO cancelled after creation.
6. **Disposition & acceptance:** V1 browser acceptance remains CHANGES REQUIRED. Build only in the same #419 PR using existing Work Order authority and guarded native SQL commands. Require regression, real current-Production disposable SQL acceptance, Manager and Crew browser/authorization tests, no-send audit and full owned CLEAN EXIT. Do not require creation of a real Crew identity just to continue the Manager functional review, but do not waive final authorization proof for Production.


## October 20 — browser Manager queue routing and verified Intake #65 reconciliation

The operator's read-only Production query confirmed `stage.work_order_intake.intake_id=65`, `source_form_name='SETUP_CORRECTION'`, source `SETUP`, Tom Shircel (Person 31), `triage_dropdown='1'`, updated `2026-10-19 21:23:59.902 -0500`, Stage 56, Setup Task WO 372 Magic Igloo Weld Repairs; **no linked `ops.work_order`**. This is a pending Task Feedback record, not a newly created Work Order. The legacy triage email wording saying “Work Order Request” does not change its actual source/identity. Presence in the later disposable clone remains a separate restore-time question, not established by the Production query.

**Operator UI defect:** The separated Manager Public Intake and Task Feedback banner buttons continued setting the HTML `#scope` dropdown to `intake` or `feedback` even after those options were deliberately removed. Setting a select to a nonexistent option makes its value empty; `/api/work-orders/tickets?scope=` fails with `Unknown Work Order scope`, leaving the list empty and the selector blank.

**Design requirement and fix:** Maintain independent, authorized Manager queue state separate from the visible Work Order scope selector. Dedicated buttons change the *effective* server query scope, not the select's value. Browser navigation/back/forward persist the effective queue, Manager role checks remain enforced in the backend, a user choosing an ordinary Work Order scope exits the dedicated Manager queue, and Task Type/text filters are reset on entering the feedback queue so unrelated Work Order-only filters cannot suppress Intake records. The read model must preserve discoverability of pending `SETUP_CORRECTION` without generating a duplicate Work Order.

**Acceptance:** Run source regression and existing current-Production disposable Manager browser. Public Intake button shows the Public Intake list; Task Feedback button shows pending Task Feedback including `INTAKE-65` *if the clone includes that row*. A clone produced before the record existed cannot show it; compare restore timestamps rather than assume submission failed. No Production mutation or real mail sending from the preview. PR #420 remains draft / CHANGES REQUIRED until operator acceptance.


## October 20 — triage decision-first presentation: preserve original Intake evidence

Operator review of `INTAKE-65` (Tom's Setup Task Feedback) showed original finding and submitted notes only after scrolling below the action area; selecting **Promote & Assign** then displayed an apparent “New internal Work Order” form, causing the impression that the original finding disappeared and making a decision appear to require promotion. The same defect affects public Intake.

**Authoritative UX requirement:** selecting any Public Intake or Task Feedback item must immediately show the original submitted finding, raw notes, reporter, source and context **above** the available Manager decisions, with no Promote prerequisite. Original source evidence is immutable in the triage UI and remains visible through clarification, owner assignment, disposition and promotion. Promotion is optional, only for genuinely actionable Work Orders; Setup Task Feedback can be clarified or disposed of without creating one. Proposed Work Order fields appear only when Promote is selected and are explicitly labeled *Proposed Work Order*, not *New internal Work Order*. Do not hide or rewrite submitted evidence as an operator moves among actions; no second source record or direct Production write.

Implementation remains on existing draft PR #420, using current authorized Intake detail fields `problem_raw`, `notes_raw`, reporter and source. Full-width selected Intake/Feedback review and return-to-queue behavior from the earlier checkpoint still govern. Operator browser acceptance and disposable SQL/no-send/clean teardown remain outstanding; no deployment approval inferred.


## October 20 — operator Phase 1 conditional launch acceptance and Phase 2 reporter communication plan

**Operator decision:** After repeated disposable browser reviews and a reported `WO419 V1 native browser tunnel: CLEAN EXIT`, the Manager has stated that the current functional Work Management system is **good enough for Phase 1 launch preparation**. This is acceptance of the *functional scope for progressing toward release*, **not** authorization to execute Production SQL, merge, start a permanent service, change protected routing, remove all Directus Flows, or send new notifications without an approved deployment plan. Earlier concurrent-Production fingerprint HOLD must be reconciled under Server Management standards rather than discarded. Draft PR #420 remains the implementation candidate until controlled release gates pass.

### Phase 1 — new application with NO loss of current notification functionality

1. **User entry:** Publish a single visible `Work Orders` link/tile in the established protected MSB application portal, leading to the dedicated Work Management WSGI application behind current Cloudflare Access/reverse-proxy identity controls. Managers and Production Crew use the same entry point but the server resolves their distinct permissions; never use the localhost disposable `8898` allocation as Production. Existing protected Setup/Testing routes and public Work Order Request Google Form remain separate valid entry paths. Coordinate portal source with its owning repository/PR; do not add a competing navigation page.
2. **Server Management prerequisite:** In `Gregovate/MSB-Server-Management` inventory the existing app/proxy/systemd/runtime pattern, allocate a permanent registered loopback listener and protected route/domain, secret handling, service account and dedicated `work_management_app` database login, TLS/Cloudflare identity, health checks, process monitoring, backups, snapshot/rollback, and release/maintenance evidence. Record the permanent URL and link ownership *before* changing portal navigation or operator SOP. A green PR check, localhost preview, or 8898 proof is not Production service approval.
3. **Database safety:** Keep authoritative `ops.work_order`, `ops.work_order_assignment`, `stage.work_order_intake`, Testing/Setup relationships. Apply reviewed V1 schema/SECURITY DEFINER commands only with explicit Production DB-maintenance approval, backup and rollback under Server Management; named Work Order Manager grants not broad inherited Setup administrator assumptions. Verify Crew 403 protections and identity mappings.
4. **Intake Manager email continuity is non-negotiable:** The existing Directus `WOI Request Triage Email` Flow is the *current* production owner for Manager notification on newly created Work Order Intake (public Google Form and Setup correction submissions). **Leave this Flow enabled for Phase 1** until an independently accepted equivalent is shown with the exact intended Manager recipients, message contents, single delivery, failure behavior and real authorized test. The current V1 outbox has `PENDING_CUTOVER` intent only; it does NOT replace actual delivery. Preserve the Google Form/Apps Script intake processing and Setup → Directus Intake create event: a direct PostgreSQL insert does not reproduce the existing Directus items.create notification.
5. **Other Directus Flow matrix:** Inventory and document `Create Repair Work Order`, `Work Order Email Assignees`, `Work Order Complete-Update Display Test Session` and `WOI Request Triage Email` by exact trigger, filters, actions, recipients and side effects. In particular the Testing completion Flow's non-email writes must continue unless a verified equivalent is deployed. Classify each Flow separately as RETAIN, REPLACE AFTER TEST or DISABLE AT APPROVED CUTOVER. Never shut down all Flows as a batch. Before any disablement require test evidence for zero missing AND zero duplicate effects, rollback/re-enable instruction, and direct Manager acceptance.
6. **Directus bookmark retirement:** The operator intends to hide old Work Order table bookmarks to stop volunteers initiating old workflows. Do **not** remove them before the new protected portal link/permissions and the existing Directus Flow-dependent Intake paths are proven. Bookmarks are navigation conveniences, **not** permission or execution controls: removing one does not turn off an active Flow, block a direct link or deny Directus API access. First publish/validate portal and feature-equivalent Work Management links; then revise old bookmarks per the existing Directus/portal owner and SOP, retaining a guarded Manager fallback during rollback. Handle `work_order_assignment?bookmark=100` according to the already-documented equal-or-better My Work acceptance boundary.
7. **Acceptance/go-live smoke test:** Manager opens portal app, sees current public Intake and Setup Task Feedback (including real-shape records), creates one authorized governed test through a safe validated boundary, triages/assigns, checks urgent/planning and aging search; Crew sees only assigned work and required note/Complete, protected operations return 403; current Google Form generates one Intake and **one** Manager triage email using retained Directus Flow, with no duplicate Work Order. Verify Testing repair effects and existing Setup gate. Validate full rollback, healthy permanent service and no unsanctioned outbound mail. Obtain explicit Production go-live approval after all checks.
8. **Operational state:** During Phase 1, Manager/assignee app edits and underlying Directus Flows remain authoritative as currently inventoried. Any new reporter clarification/resolution notification is **not promised delivered** until Phase 2; UI and SOP must say emails are held/not sent and show the pending follow-up responsibility.

### Phase 2 — reporter-facing clarification, disposition and completion emails (documented procedure)

A. **Reporter identity:** Work Management resolves the original `submitter_person_id`/contact and source Intake identity without changing original text. Distinguish original reporter from Manager triage coordinator and assigned repair/correction owner. Do not send to the general Manager list or a default proxy when the reporter is known.

B. **Request More Information:** Assigned authorized correction owner/Manager writes a substantive specific question on the existing Intake/ticket, stored with actor/time, recipient, source and stable event key. Status becomes `Waiting on Reporter`, retaining accountable owner. Send one targeted email to the original reporter with the safe protected response link. Reporter answers on that **same** record and the answer notifies the owner. For reporters without linked identity/contact, surface `Reporter could not be notified`, assign Manager manual follow-up, and never falsely label it SENT.

C. **Resolved/Verified, Deferred, Rejected/No Action, Duplicate/Linked:** Authorized owner records substantive reason and actual outcome; only then queue original-reporter email containing understandable decision/work performed, reason, owner and protected ticket link. **Promotion to Work Order alone is not resolution.** When subsequent linked WO is genuinely completed, send the traceable final outcome to the original Intake reporter. Cancellation/no physical work must not be worded as repaired/completed. Respect Testing/Setup lifecycle distinctions and the existing accountable no-action audit.

D. **Durable email pipeline:** Reconcile Google Workspace/MSB server transport and current Directus Flow inventory first; single governed sender of record, stable per-event/recipient keys, audited QUEUED/SENT/FAILED/MISSING_RECIPIENT, retry without duplicates, and provider send evidence. A PostgreSQL `PENDING_CUTOVER` row or DB commit is NOT proof of delivery. Never enable sender and old equivalent Directus mail Flow simultaneously without proved dedup/cutover protection.

E. **Manager instructions and operator training:** Publish an SOP that explains: (1) when to request clarification; (2) what information is included; (3) how a volunteer replies without accessing unrelated tickets; (4) that the **original reporter will receive** approved requests and final outcomes *once Phase 2 email is activated*; (5) that the owner is responsible until final outcome, even while Waiting on Reporter; (6) how to spot/respond to FAILED or MISSING_RECIPIENT; and (7) how to avoid saying a repair was completed when a request was deferred, rejected or cancelled. Before Phase 2 cutover, Manager preview/no-send templates and recipient list must be approved. Then test reporter receipt, reply, final closure, deferral, cancellation, idempotent retry, missing recipient, authorization and rollback end-to-end on a controlled transport boundary.

F. **Controlled cutover:** Inventory exact existing email-generating Flow IDs, freeze new senders, snapshot/export configuration, enable new verified sender only when templates, recipients, role/access, dedup and observability PASS, disable only the individually replaced mail Flow, perform a single controlled test and rollback promptly if duplicate/missing notifications occur. Preserve non-mail side effects. Release notes and staff instructions must identify when Phase 2 emails become active.

**Open external dependency:** Server Management permanent routing/service and mail transport contracts must be read/updated in their owning repository before a deployment command is written. No hostname, port, service name, or sender credential is invented here.


## October 20 — confirmed Apps-index landing entry for Phase 1

The operator supplied the live Apps index screenshot, which already has **Production & People** tiles **Assigned Work Orders** and **Repair Work Orders from Testing**. The intended Phase 1 navigation is to *rename/retarget the existing Assigned Work Orders tile* to **Work Orders** and link it to the new permanent protected Work Management application, not to create a competing landing website. The same portal tile must work for Managers and Production Crew; the application/server enforces role-based landing and permissions (Crew My Work, Manager queues/triage). Retain the Testing-specific tile and flow until the January/February Testing workflow is explicitly corrected and accepted. Current Directus Work Order, assignment, Intake and Person collections were hidden from user navigation only; operator confirmed no permissions, collection metadata/data or Flows were changed.

**Deployment dependency:** The actual Apps index page's owning source/configuration, its existing Assigned Work Orders link, and the new permanent Work Management reverse-proxy URL have not yet been verified here. Do not replace the existing live tile destination with an invented host/port, the temporary localhost 8898 URL, or an unprotected route. Identify the owning site/repository or managed webasset in Server Management, implement the link there after the permanent service exists, and test Manager and Crew access. Preserve existing Manager Intake emails via current Directus Flow.

## October 20 — year-round Work Management independence

**Work Management is a standalone, year-round Production subsystem.** It serves Park, Workshop, maintenance, future planning, Testing repairs, public Intake and Setup-origin feedback. Setup is one integrated source of tasks and correction reports, not the owner or seasonal availability gate. The Production Work Management service, portal route, operational support, access controls, and release lifecycle must be independent of Setup schedules and maintenance state. Testing integrations likewise must not cause the Work Management service to be disabled outside the Testing season. Manager authorization is Work Order-specific; do not grant it merely because a user can manage Setup. Governing permanent-service deployment is MSB-Server-Management issue #81 under #419. Preserve existing PostgreSQL Work Order identities and current Directus Intake Manager emails in Phase 1.

## October 20 — Phase 1 permanent route deployment contract (#81)

Operator approved Phase 1 Production release and selected the public entry
`https://my.sheboyganlights.org/workorder/`. Existing Apps tile changes only after
that route passes authenticated Manager/Crew acceptance. Earlier source-only
approval caveats above are historical; runtime/database gates remain mandatory.

Live operator evidence establishes Synology `192.168.5.4` forwarding directly to
application listeners on `192.168.5.9`, restricted by UFW. No host loopback proxy
is established. Use that existing protected service topology; the earlier
`verified_cloudflare_loopback` requirement is superseded for Production only.

Production WSGI must enforce the actual socket peer as exactly Synology
`192.168.5.4`, the public Host `my.sheboyganlights.org`, and HTTPS forwarded by
that peer. Never trust X-Forwarded-For as the authorization peer or allow client
headers to substitute a trusted peer. Existing Cloudflare Access ingress must
overwrite client identity; verify direct-origin bypass protection before cutover.
Missing identity and untrusted peers remain denied. Disposable loopback identity
behavior is unchanged. Production startup requires the explicit
`verified_synology_access` perimeter attestation, dedicated database account,
release gate and protected command secret. This attestation is configuration,
not proof that external Cloudflare controls have been tested.

Synology strips only the /workorder/ prefix. The WSGI entry sets a fixed SCRIPT_NAME
of /workorder and verified HTTPS scheme. HTML asset URLs and JavaScript fetches
include that prefix; do not publish unrelated root /api or /work-orders routes.
Same-origin POST checks compare against the real HTTPS origin. No new local proxy
daemon is required. The service export remains `production_entry:application`.

This security/routing correction is a materially distinct candidate:
`V1.0.1-production-route`, Updated 2026-10-20. Preserve accepted Phase 1 business
behavior and SQL; test trusted/untrusted peer, spoofed forwarding, missing
identity, wrong Host/scheme, prefixed page/assets/API and CSRF with fake repositories,
then verify actual protected routing/roles before Production acceptance. Existing
Manager Intake mail remains enabled; Phase 2 notification sender remains disabled.

Shared checkout observed clean at 17c522c4f8ec06549bf7a6d9e8530c61276203f7.
Do not advance it merely to install this app. Server Management must use an exact,
persistent independent application checkout with the established runtime account
and Python environment, and maintain the existing #37 database mutation boundary.


## October 20 — correction: Directus is the sole user and role authority

Operator correction supersedes all earlier references to Work Order-specific
Manager grants, named capability rows, or separate Manager approval tables.
Do not create or consume ops.work_management_permission. Work Management must
resolve current active Directus users, roles and policies on every request and
again within each native SQL command. Reuse the existing Directus-backed
ref.setup_browser_capabilities lookup for its role/policy resolution; it does
not depend on a seasonal Setup session. can_manage_setup represents the existing
Directus Manager/Administrator capability and supplies Work Management Manager
rights. Production Crew retains only assigned-work rights. Inactive, missing,
unlinked and ambiguous identities fail closed. Role changes and revocation in
Directus require no app-specific grant, restart or mirrored user list.

Disposable acceptance may change Directus role/policy fixtures only inside the
isolated clone with rollback. The browser reviewer must use actual cloned
Directus permissions, without silently elevating the reviewer. Keep narrow
application SQL EXECUTE privileges and existing Person audit linkage.

Operator clarified the authentication chain: Cloudflare Access authenticates the
Google @sheboyganlights.org account; Directus owns users, roles and policies.
Preserve that established protected-header boundary and exact linked Person
mapping. No Directus session sharing, new login flow or separate role directory
is required. Verify ingress header protection during ordinary release acceptance.
The staged V1.0.1 candidate is superseded and must not be installed.


## October 20 — signed Cloudflare identity correction (#419 / Server Management #81)

Status: design for V1.0.3-signed-access; not installed. Database provisioning
already passed WO81-database-20261020T192926Z. Do not reapply its migration.

Read-only direct-Synology People access returned HTTP 200 with only a supplied
email header; public Cloudflare access returned 302. This proves the tested
origin path accepts an asserted identity, not an Internet write exploit. LAN
administration remains explicitly required. Do not block LAN, SSH, DSM or Directus
as a substitute for verifying application identity.

Work Management Production must verify Cf-Access-Jwt-Assertion with RS256 and
the HTTPS JWKS at the fixed configured team issuer's /cdn-cgi/access/certs.
Require signature, exact issuer, application audience, expiration, issued-at,
subject and a human email; enforce nbf when supplied. Reject unsigned, expired,
wrong-audience/issuer, malformed, machine/service and missing tokens. Never select
a key URL from token claims. Bound fetch time and cache lifetime; key-fetch failure
fails closed without exposing tokens in logs. Derive the existing email header
from the verified claim, replacing any caller-supplied email before backend
authorization. Preserve socket-peer/Host/HTTPS checks, fixed /workorder prefix,
CSRF, native commands and current Directus checks on every operation. A valid
Cloudflare identity never grants Manager rights or creates a Directus user.

Operator supplied issuer https://sheboyganlights.cloudflareaccess.com and My MSB
audience d1ceb76902c00398d70cd07e004bf4c49fdc41f6a00da4f41afb304e637e2dd4.
These are public identifiers, not credentials. No new Cloudflare policy, separate
role store, Directus login flow or session-duration change is part of this fix.

Regression uses generated RSA keys and fake JWKS transport with no Production
contact. Test signed success, forged email replacement, all rejection cases,
key rotation/outage, and continued Directus denial. Production acceptance still
requires real Cloudflare login and Manager/Crew authorization via the existing
Synology route. Existing People/Setup/FieldWiring are not fixed by changing this
entry point; their corresponding boundary follow-up remains under #81.

Server Management must document source-only reconciliation of the clean
uninstalled worktree and isolated runtime dependency installation before service
startup. Preserve shared /opt/fieldwiring and completed SQL/credentials/maintenance
inventory. No database apply retry or shared-environment pip upgrade is authorized
by this source change.


## October 20 — Phase 2 email templates and required Due by (#419)

Operator authorized implementation of four notification types: new Intake to
the existing test Manager mailing list; assignment to the actual assignee;
done/cancelled outcome to the original reporter; and a request for more
information to the original reporter with same-ticket response. Keep
ref.person.is_manager=true, active_flag=true and available email as the interim
Intake mailing-list selector. This is a recipient rule, not an application
permission. Directus remains the sole user/role/policy authority. Do not redesign
Person or change the test recipients during this work.

Email wording must be editable outside Python sending code. Store four reviewed
templates under WorkOrders/Application/email_templates, with subject, HTML and
plain-text alternatives. Use a small documented placeholder vocabulary and
escape inserted ticket values in HTML. Template files cannot set recipients,
credentials, transport or permissions. Validate every template and render no-send
previews before activation. Freeze rendered content and template digest with each
queued delivery so retries do not silently change an already-attempted message.
An invalid template stops enqueue/send visibly; no fallback to misleading mail.
This initial file-based editor is available through GitHub file editing; a
browser rich-text editor is not part of the initial implementation.

Due by is required on Manager Create and Intake Promote, editable by Managers,
visible in work lists/detail and assignment email. Check current native schema
before choosing a new column. Existing undated open work is flagged Due date
required; never manufacture dates or rewrite history. Overdue means active,
unfinished work with a due date before the current America/Chicago calendar date.
Due today is not overdue. Do not block legitimate completion of historical work
merely because it lacks a date. Automatically generated Testing repair work must
remain creatable and show missing-date follow-up for a Manager.

Observed live email Flow inventory:
- ebcde355-32c5-4826-b6fa-360621d0d357: WOI Request Triage Email,
  active, work_order_intake items.create; reads the interim Person list,
  builds an email array, sends Manager triage notice.
- 9a7fb87b-d78e-492b-b2c5-ac3b521b5cf7: Work Order Email Assignees,
  active, work_order_assignment items.create; active assignment, nonempty
  assignee email and unfinished Work Order required.
- 78e3fac3-a616-4c30-a6d8-a7cde33cefbb: Create Repair Work Order,
  retain non-email creation behavior.
- 09276ca9-3409-4f1c-95fe-df5b3edb8eef: Work Order Complete-Update
  Display Test Session, retain non-email Testing completion behavior.
The two inactive Flows stay inactive. Event-hook mail does not cover native SQL
writes; replacement capture must cover both native application actions and
existing public/Setup Intake entry paths. Activation must not flush historical
PENDING_CUTOVER rows indiscriminately. Establish a reviewed event boundary and
explicit backlog disposition, then disable only the two replaced email Flows.

Status: implementation in progress, no Phase 2 sender or due-date migration
installed. Server Management #81 owns mail transport reconnaissance, runtime,
cutover and rollback. Do not infer delivery from a queued database row.


### Confirmed existing SMTP authority — correction to Phase 2 reconnaissance

The October 18 deployed Manager digest already establishes the mail transport.
See [actual activation evidence](https://github.com/Gregovate/MSB-Production-Database-Project/issues/205#issuecomment-6248399405),
application PR #413 (deployed source e53c31069b7354ad7fda78665d6666145942a70d),
and Server Management PR #79, specifically
docs/server/Setup_205_Bounded_Manager_Daily_Mail_2026-10-18.md.
These documents exist on their open PR branches; absence from main does not mean
the installed transport is undocumented or unproven.

Reuse Google Workspace IP-authorized smtp-relay.gmail.com on port 587 with
required STARTTLS and certificate verification, no SMTP password. Reuse the
established sender identity and multipart HTML/plain-text pattern after reading
the exact accepted implementation. Seven Manager messages were SMTP accepted
October 18; this is not proof of Inbox delivery or Work Order sender activation.
Preserve the existing Setup timer, environment and protected attempt receipts.
Work Orders needs its own event delivery records and activation boundary, not
reuse or rerun of the Setup digest's seven-recipient/day-specific send guards.

The earlier request to rediscover transport through Directus environment was
unnecessary. No further Directus SMTP inspection is needed for this design.
Live Work Order schema readback also confirms 31 columns and no due-date field.


### Phase 2 delivery implementation contract

The worker uses a separate restricted work_management_mail database identity.
Each delivery claim must commit immutable subject/text/HTML/template digest and
event/recipient identity before SMTP. A unique event key excludes concurrent or
repeated attempts. Store SMTP_ACCEPTED separately from Inbox delivery evidence.
Keep FAILED_BEFORE_DATA, REJECTED and UNKNOWN distinct. A crash or failed receipt
write leaves IN_PROGRESS for investigation; never automatically reclaim it.
SMTP cannot promise exactly-once delivery after an uncertain DATA response.

The new mail claim functions must refuse dispatch while either exact replaced
Directus email Flow is active or missing. This gate does not itself disable a
Flow or authorize cutover. Existing PENDING_CUTOVER records are never implicitly
promoted to QUEUED. Stop the worker before any rollback/re-enabling old Flows.

Every rendered ticket URL must identify the same WO/INTAKE record via the
existing /workorder/?ticket=... navigation. Verify reporter read/reply scope
before activation; do not substitute the home page or invent public access.
The initial SMTP adapter and delivery-claim migration are source candidates only;
event capture, worker activation, live SQL acceptance and Flow cutover are not
established by offline tests.


### Candidate capture and disposable acceptance

Capture is a disabled-by-default database trigger on new Intake, new active
assignment, and the existing native clarification/outcome activity events. It
writes a snapshot payload to the existing outbox using phase2-prefixed stable
event/recipient keys. Original V1 PENDING_CUTOVER entries remain held and excluded.
The outbox activity link becomes optional for direct Intake/assignment events;
there is no second ticket table. Capture activation and retiring the two exact
mail Flows require one governed cutover boundary; neither migration activates it.

Original reporters may read their own Work Order and activity, without receiving
Manager or assignment/write rights. My Submitted Feedback includes their public
Intake as well as Setup feedback. Existing active Directus linkage remains
required; external/unlinked reporter handling still needs a manual-contact
exception before activation. No public authentication bypass is introduced.

The established WO419 disposable runner applies migrations 001/002/003 only
inside its private restored clone. Its worker role is NOLOGIN; it never starts
the SMTP worker. Reuse the installed independent Work Management Python runtime
documented in Server Management, preserving shared FieldWiring dependencies.
Clone-only tests temporarily enable capture/disable the two cloned Flows and
roll back all data and simulated receipts. Source regression is not SQL proof.
No Production or live-email activation follows automatically from clone PASS.


### Phase 2 deadline navigation — October 20 operator direction

Add Due by sorting (earliest/latest, missing dates last) and Work Order deadline filters: All, Overdue, Due today, Missing due date. Apply database filtering and ordering before the normal list limit; preserve existing actor permissions and other filters. Overdue means active, unfinished, due before today's America/Chicago date; due today is not overdue. Missing-date filter selects active unfinished Work Orders without inventing deadlines. Include the Manager aging report and preserve selections through URL/back navigation. This is candidate behavior pending the Phase 2 migration and acceptance.


### Phase 2 source-specific Intake email — October 20 operator correction

New Intake notices must distinguish Setup Task Feedback (source_form_name=SETUP_CORRECTION) from work requests. Feedback subject names source_payload.task_name and asks for review; it must not call the feedback a Work Order request or imply approval/denial is the only response. Work requests retain received-from wording. Both use the permanent same-ticket Work Management URL. Keep the interim Manager recipient list unchanged. Store source classification and task name in the event snapshot, with a truthful missing-task-name fallback. Maintain a separate editable formatted/plain-text feedback template and include it in offline previews. This replaces wording only after Phase 2 activation; the live Directus Flow is unchanged.


### Manager email-preview utility — October 20 operator direction

Expose the formatted email previews on the Manager Work Orders page as a utility. Enforce existing Directus-derived Manager authorization on the read endpoint as well as hiding the UI for Crew. Render current installed templates with fictional sample data, including Setup feedback and work requests; show subject, formatted body and plain text. Preview must not queue mail, claim deliveries, send SMTP, mutate templates, or grant roles. Isolate preview HTML from the application. Keep the offline preview command using the same rendering function so it cannot drift from the Manager utility.

### Phase 2 completion contract — reporter, deadlines and delivery visibility

Reporter replies remain on the original Intake. Permit a reply only while its
latest clarification/reply/resolution state is an unanswered clarification and
it has not been promoted. Notify the latest explicitly assigned correction owner,
or the Manager who asked the question when no correction owner exists. Keep
recipient identity in the event snapshot. External/unlinked or inactive reporters
must receive a visible manual-contact exception; do not email an unusable protected
response link or invent application access. Email replies are not ingested.

For active Testing-linked Work Orders provide a separate Manager **Set Due by**
command. It changes only the deadline and native audit actor, requires a reason,
and records before/after dates. Keep general Edit/Cancel prohibited for these
records; never change Testing identity, repair completion or status to set a date.
Undated historical work remains completable. The aging report and CSV show Due by
and deadline status independently from creation age; inactive records are never
classified overdue.

Managers can inspect per-ticket notification outcomes through a read-only,
Directus-authorized function. Show queued, held, missing contact, failed,
uncertain/in-progress and SMTP-accepted distinctly. SMTP acceptance does not prove
Inbox delivery. Never expose immutable message bodies or recipient addresses to
other reporters/Crew. No retry or send button is included. Saving an action must
not promise delivery; consult the durable status after the worker runs.

These changes are candidate work in PR #435. They require fresh exact-candidate
CI, disposable SQL and protected browser acceptance. Phase 1 remains installed;
Phase 2 remains off until the separate governed migration and mail cutover.

### Manager Utilities placement — October 20 browser feedback

Keep the Work Order list focused on daily work. A compact Manager-only Utilities
button beside the header controls opens a separate Utilities page with Back to Work Orders. Email template
previews belong on that page, with no permanent full-width home-page bar.
This is also the intended home for future Work Order reference-table tools; do
not imply those editors are implemented or grant new authority. Preserve the
existing no-send renderer and Directus Manager authorization.
