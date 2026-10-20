# Work Order System Design

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
- **Existing cross-system boundaries:** #172 Setup Task Feedback remains its existing free-form entry point; Testing owns generation/feedback of test repair events; Setup #205 consumes real Work Order completion gates; Directus automation must be deconflicted at the approved launch. Each remains an integration with the existing Work Orders subsystem, not evidence that #419 needs a new repository.
- **Current operator-provided Intake:** three retained records were visible in the October 18 read-only DBeaver snapshot: `INTAKE-60` (Setup correction), `INTAKE-40` and `INTAKE-57` (public form). Use the **actual existing** Intake rows in the disposable clone; preserve their original IDs/provenance and never treat a historical count as proof that Production still has exactly three later.

This is an explicit repository placement decision within the current [System Boundary and Repository Ownership Standard](../../../../System_Documentation/Standards/System_Boundary_and_Repository_Ownership_Standard.md), whose "may live in its own repository" language permits but does **not** mandate a split. This subsection governs #419 implementation placement; do not rewrite the underlying Work Order schema or broader standards merely to justify previously proposed separate-repository code.

### Existing Work Order engineering to preserve — pre-#419 authority reconciliation

The current Work Order subsystem **predates** #419 and is **not** a new design project. Before changing or implementing the #419 application, use the following accepted engineering lineage:

- **Current controlling subsystem design:** this `Work_Order_System_Design.md` together with the [Work Orders README](README.md) and [current task-sized Work Order operator SOPs](../../02_Operational_SOPs/Work_Orders/README.md). These own present PostgreSQL identity, approved operator flows and current authoritative intent.
- **Prior approved design evidence, now archived:** [MSB Work Order System — Database Design Spec v1.1](../../../../archive/architecture/G_Work_Order_Design_Plan.md) was marked Final/approved for DDL/import in March 2026. It already specified PostgreSQL ownership; Work Orders for repairs, facilities and future work; Stage XOR Work Area; independent urgency/target year; normalized multi-volunteer assignments; permanent Display linkage; `date_completed` completion truth; actor/notes history; Google Sheet To Do/Completed migration; and automated testing repair generation/completion feedback. It records Testing repair workflow operational on March 10. **Use this for rationale, not as a replacement for later live schema or current procedures**; e.g., its original `work_order_assignee` name is superseded by live `ops.work_order_assignment`.
- **Prior approved operational model, now archived:** [Work Order System Operational SOP v3](../../../../archive/operational_sops/Work_Orders/B_Work_Order_System_SOP.md) already describes Manager-created Work Orders, public Intake→Manager triage→Promote, Manager assignment with email, volunteer progress/completion, Testing-generated repairs and existing curated Directus views for assigned, unassigned and aging work. This is **historical operational design**; present task-sized SOPs and current Production behavior govern exact current steps. Do not assume an already-designed Manager function is a new feature or that its current safe/direct implementation has been verified merely because the old SOP describes it.
- **Accepted Setup integration:** the existing #172 Report Correction bridge under `Setup/Database/062_add_setup_context_work_order_intake.sql` and `Setup/Application/setup_work_order_intake_api.py` authorizes and submits free-form findings into existing Intake via Directus, preserving the Manager notification event. Reuse this entry point, don't recreate feedback forms or invent replacement state.

**#419 is controlled improvement of the existing subsystem**, concentrating on a usable protected list/detail interface, reliable access to My Work/All/other assignee, integrated Intake promotion/assignment UX, missing durable feedback clarification/owner/outcome response, governed notification reliability, and deconflicting old Directus Flows at launch. This reconciliation is not authority to change existing PostgreSQL semantics, historical records, role policy or accepted Testing workflows.

**Key source/permission distinctions to verify rather than overwrite:** The original March design mentions broad authenticated creation, the archived SOP describes direct Manager creation, and the current task-sized SOP documents Manager triage/assignment. These should not be flattened into an invented permission rule without inspecting current Directus roles/actual database capability. Current live read-only evidence establishes `ops.work_order_assignment`, the Intake processor, and current Flow statuses, but not the full current authorized Manager-direct-create command or exact Flow operation graphs.

### Why Work Management must improve the existing Directus experience

**Design rationale and problem statement — October 18 operator direction.** The PostgreSQL Work Order system and its integration with Testing, People, Setup and Intake were deliberately engineered and are largely present. The problem is **not a missing replacement database**. It is that the general-purpose Directus interface separates actions, makes an ordinary volunteer's work difficult to find, and fails to close the communication loop when someone reports a problem. The purpose of #419 is to **realize the existing operational design through a unified task-focused experience**, use the groundwork already developed, and eliminate the navigation/accountability weaknesses seen during 2026 setup. Do not redesign the database simply to make a new UI easier to write.

**Evidence hierarchy for this rationale:** The [current Work Order operator SOPs](../../02_Operational_SOPs/Work_Orders/README.md) document the released Intake → triage → assignment → completion flow. The [prior operational model](../../../../archive/operational_sops/Work_Orders/B_Work_Order_System_SOP.md) documents the deliberately curated Directus Intake, assignment, unassigned, urgent and aging views, plus direct Manager work entry and Testing repair integration. The [repository documentation audit](../../../../System_Documentation/Repository_Documentation_Audit.md) explicitly describes **assignee visibility**, Work Order links and the Directus navigation limitation as existing work. Operator experience in #419 and real October 18 DBeaver/trigger evidence establish the further shortcomings below. Historical documents are **design/rationale evidence**, not proof that every historical button or permission still works unchanged in current Production.

| Existing capability / operator pain | Why it matters | #419 design response and acceptance intent |
| --- | --- | --- |
| The Work Order system already holds normalized multi-person assignments, but volunteers are sent to curated Directus links/bookmarks and must navigate or filter to find the relevant work. Multi-assignee rows may be repeated in historical views. | **Finding your job should be easier than changing database filters.** An assignment is ineffective if the worker cannot reliably open it or report completion. | Open **My Work** for the signed-in assignee; allow deliberate **All** or another person's assignments as in accepted Setup **Perform Work**, with independent **Show completed**. Display each authoritative Work Order once with all active assignees. Preserve the existing personalized Directus bookmark #100 during migration; don't alter its user-specific filter. |
| Manager triage and post-promotion assignment occur on different Directus records/screens. Actual `stage.p_process_work_order_intake` returns `assignee_count = 0`. | A valid approved request can be left unassigned and invisible to the intended worker. Extra navigation encourages work to fall between steps. | **Review, correct, choose assignees, Promote/Release** as one governed accountable Manager action, while reusing actual Intake, Work Order, Person and assignment relations. Verify idempotency and rollback; do not introduce a new Intake entry system. |
| Submitted Intake can remain pending or be **deleted** when rejected; Promote creates a Work Order then **deletes original Intake**. Approved #172 free-form Task Feedback is received, but its reporter has no proven clarification/closure loop. | Valuable procedure/material/field findings can be lost or never acknowledged. Volunteers lose confidence when they cannot see what happened to their report; the January reusable-Catalog review lacks durable outcome evidence. | Preserve original report/evidence, accountable correction owner, conversation, route, outcome and source link; permit **request clarification → reporter answers → verified resolution/deferral/denial with reason**; send the correct reporter an email at the required points. Do not auto-create a repair Work Order for a correction or use destructive raw Intake triage as closure. |
| Rick and other experienced volunteers can become de facto catch-all coordinators when handwritten/field notes and tickets have no visible owner/next action. | Work depends on individuals remembering outstanding items; overload and handoff failure undermine continuity. | Separate **reporter**, **triage coordinator** and **assigned correction/repair owner**. Provide visible unassigned, aging, awaiting clarification and blocked queues so someone can take responsibility without everything defaulting to one volunteer. |
| The prior SOP already describes **Manager-created Work Orders**, but the current governed direct-create command and permissions were not established in this reconnaissance. | Managers should not have to submit their own public request and then promote it merely to record known operational work. Equally, a historical SOP is not proof the live command works. | Reuse a verified authorized direct-create path if it exists; otherwise implement only the missing narrow Manager capability, with real assignees and audit. Do not presume absence or invent a second creation model. |
| Test Session failures already create repair Work Orders automatically and completing one feeds notes/results back to Testing. | Testing must remain truthful and cannot be broken or duplicated by a better-looking Work Order screen. | Present generated repairs in normal assignee/All views, link to the exact Test Session and keep existing completion/test-history/closure effects. **Testing feedback is not automatically an email to an Intake reporter** when no human reporter exists. |
| Status catalog/history exists, but the October 18 read model found **no joined status-history records**, while `date_completed` populated many WOs. `is_active` is not the same as open. | Labeling undated work `IN_PROGRESS` or treating missing history as a missing Work Order lifecycle would misrepresent established operation. | Use the original design's **`date_completed`** test for open/completed until real status events are available; distinguish record changes from physical work. Make status provenance and exceptions visible without silently backfilling invented workflow history. |
| Active Directus Flows currently send Intake/assignment mail and create/close Testing repairs through different triggers; no reporter follow-up service is yet proven. | A replacement UI with overlapping event handlers can double-email, double-create repairs or break Testing; missing send audit can falsely suggest the reporter was notified. | Design a single event owner and notification producer per accepted event; inspect each Flow's actual operations; replace **only** accepted superseded behavior at a controlled cutover, with durable delivery evidence and tested restoration. Preserve all required Intake/Testing side effects throughout. |

**Why one application:** Work Orders, human requests, Setup Task Feedback and Testing repairs are related operator work, but they have different authoritative source lifecycles. A unified list/detail/navigation and consistent action language makes them discoverable together **without** mixing their identities, collapsing distinct correction versus repair outcomes, or establishing a competing master ticket database.

**Why keep the current operator SOPs during implementation:** Those documents describe what volunteers and Managers can do in the presently released system; they must not be rewritten to describe a future screen before disposable/browser acceptance and actual Production deployment. Once accepted, update the existing task-sized SOPs with the new buttons, navigation, security limitations and real procedures, while leaving the rationale and design/DB semantics **here**.

**Success criterion:** A volunteer or Manager can sign in, immediately find the right assigned or submitted item, understand what remains, perform only the actions authorized for that actor, see the disposition and the correct underlying Setup/Testing result, and know that questions and completion outcomes have actually reached the relevant people. The test is **reduced operational fragmentation and reliable accountability**, not merely a technically correct SQL union or an attractive dashboard.

### Product boundary — one operator experience, two distinct lifecycles

The next major application after the accepted Setup Scheduling Board work is **MSB Work Management**, a single, ticket-style interface for existing Work Orders and Task Feedback. A volunteer or Manager should not need to navigate raw Directus collections or change personalized bookmark filters to learn what was reported, assigned, done, or still outstanding.

- **One searchable Inbox / All Tickets, My Work, My Submitted Feedback, and Manager follow-up** with common detail presentation (human description, original source/reporter, Stage or Work Area, owners, evidence, time, next action, outcome, history). Provide direct, authorized links into the owning Setup task/Stage, Work Order, Testing or Procedure.
- **One UI does not create a new authoritative ticket table.** The native permanent Work Order identity remains `ops.work_order.work_order_id`; pending Intake and correction submissions remain `stage.work_order_intake.intake_id` until governed disposition. Display aliases such as `WO-372` and `INTAKE-60` are not new identities. Cross-links must preserve both source and outcome identities.
- **Work Orders** cover actionable repair, build/maintenance and related work. **Task Feedback** covers a reported observation or correction requiring review; it is not automatically a Work Order. The Manager may explicitly promote/link a real repair while preserving the original reporter and source, or route the correction to the authorized Procedure, Catalog, Kit/material, inventory, GIS, Testing or engineering owner. A report is not proof work occurred.
- The approved **#172 free-form Task Feedback entry** must remain simple: `What did you find?` plus optional suggestion/evidence. Capture known annual task, Stage/Scene, scheduled assignment, Crew/Captain, Procedure, authenticated reporter/time automatically where available. An unscheduled observation requires a truthful route **without fabricating a workday or Report Work**.
- **#209** owns annual experience → reusable Catalog review: distinguish proposed, verified, accepted, rejected and deferred improvements, and never modify reusable records without the governed confirmation. Work Management makes reports and their outcomes available to that review; it does not replace #209.

### Work Order landing view — default My Work, optional broader assignee scope

**Operator decision (October 18):** Opening **Work Orders** or **Open Work Orders** must resemble the existing accepted Setup **Perform Work / Report Work** experience, which starts from the signed-in Captain and permits an explicit **All scheduled work** or another Captain selection. This is a Work Management **operator-navigation requirement**, not an instruction to expose private contact data or alter an individual's Directus bookmark.

- **Default: My Work.** Resolve the authenticated Google/Cloudflare-backed human identity through the existing trusted `ref.person.person_id` mapping; find **active** `ops.work_order_assignment` rows by that exact `person_id`, not by name, email substring, `submitted_by_person_id` or `created_by`. Initially show that person's **outstanding** active Work Orders: not recorded complete (`date_completed IS NULL`) and `is_active=true`. If the user has none, show an explicit empty state with options to choose All or another assignee rather than silently showing somebody else's work. Do not assume an assigned Work Order has a populated status-history event.
- **Assignee selector:** `My Work` / `All Work Orders` / authorized individual volunteer choices from the existing Person/assignment records. An individual selection shows **that person's** active assigned Work Orders; All shows every Work Order within the reader's approved scope, including ones unassigned. Show the current selector visibly and provide an unambiguous way back to My Work. Names are for display; selection/filtering uses permanent `ref.person.person_id`.
- **Completion visibility is independent.** `Show completed` adds dated-completed Work Orders within whichever assignee scope is selected; turning it off restores the open-only view. Completed-but-inactive and other inactive/archived work must remain discoverable through an explicit broader history/review control where authorized. Never interpret `is_active=true` as meaning incomplete. The backend may surface cases of status-history/completion-date disagreement for Manager review without inventing a transition.
- **Identity and preferences:** On a fresh authenticated session, prefer My Work exactly as Report Work prefers the signed-in Captain; later explicit assignee/All choices apply to the current view. Do not let a stale saved All scope silently override the fresh signed-in-person default. When returning from a detail link, preserve the current selector/filter context if safe.
- **Permission model:** Distinguish **visibility** from **action authority**. The product requires broad, permission-appropriate operational visibility analogous to Report Work, including another person's assignments and All Work Orders; it must not assume all volunteers can edit everyone else's work. Reconcile the exact existing Production Crew/Manager view capabilities before implementation: viewers may see job status, human description, Stage/Work Area, names of assigned volunteers and non-sensitive progress, while only explicitly authorized actors can triage, assign, correct, or complete. The protected API must enforce the relevant reader scope server-side and must not disclose private contact details or privileged internal notes because someone changed a UI filter.
- **My Work and My Feedback are distinct:** Work Orders assigned to the signed-in person appear under My Work; feedback they originally submitted appears under My Submitted Feedback regardless of its correction owner. Being a **reporter** never implies being the **assignee**.

**Acceptance:** A signed-in assignee of WO372 sees the still-undated Magic Igloo Work Order in My Work; changing to another person's assignments and then All changes only the displayed scope and preserves correct multi-assignee semantics; Show completed independently includes dated completions; a volunteer can browse another assignee's permitted operational summary without acquiring Manager mutation capabilities. Non-assignees do not silently see another person selected by default.

### Test Session-generated Work Orders — feedback and ownership

**Observed current Production context:** The initial #419 ledger includes Work Orders whose source is `Container Testing`, both dated-completed and without recorded completion. The Work Order table has an optional `display_test_session_id` and `display_id`. Testing's current [engineering README](../05_Testing_System/README.md) and [Complete a Work Order SOP](../../02_Operational_SOPs/Work_Orders/Complete_a_Work_Order.md) establish the accepted contract: a governed testing failure creates an **active repair Work Order directly** without public Intake; Work Order completion feeds the repair result and notes back into the linked display testing record, and outstanding repair orders can block closing the related container Test Session.

- **Same work queue, identified source.** A testing-generated repair participates in My Work, another assignee's view and All Work Orders on exactly the same assignment/status criteria as any other Work Order. Its detail must clearly identify `Test Session repair` (using **verified source and related Test Session identity**, not simply a text substring), associated Display in **human display name** where authoritative, relevant Container and test status when verified by Testing, and a direct authorized route back to the **exact display/parent Test Session**. Do not create a duplicate Work Order Request or a fabricated Intake item for test-generated repairs.
- **Assignment:** A generated Work Order may initially be unassigned. It must appear in All/unassigned Manager review, and once assigned it appears in each actual assignee's My Work. Do not infer a responsible repair person from the tester or `created_by_person_id`.
- **Completion:** Apply the existing guarded Work Order completion and preserve the `Work Order Complete-Update Display Test Session` integration and testing repair notes/history; verify linked Test Session behavior in a disposable clone before changing Directus Flow ownership. Do not mark test results fixed from a mere note, ticket email, or assumed physical repair.
- **Who gets feedback?** Unlike free-form Task Feedback, a Test Session-generated WO does **not** automatically have an original Intake reporter to notify. The desired feedback is (a) testing state updated and visible in the originating testing workflow, (b) outcome and notes visible on the linked repair Work Order, and (c) where an actual tester/Testing coordinator or responsible Person can be **authoritatively resolved**, a **role-appropriate** assignment/completion notification. Do not send a correction-close email to `submitted_by_person_id` when NULL, choose an arbitrary `created_by` service actor, or email all test operators merely because a technical test caused the Work Order. Recipient resolution, subscriptions and needed Test Session follow-up confirmation remain engineering questions to validate against live Testing provenance and role/notification contracts.
- **No competing communication model.** Test Session feedback and original-volunteer Task Feedback use the common ticket detail/comment/audit conventions where useful, but their workflow-specific results stay owned by Testing and the correction Intake respectively. Reporter clarification/closed-loop email remains mandatory for actual human-originated feedback when a valid reporter can be resolved; machine-generated repair creation is not itself a human report.

**Acceptance:** A generated repair with no assignee appears in Manager All/unassigned; after assignment it appears in the selected volunteer's My Work. Opening the ticket shows its actual Test Session reference. On authorized disposable completion, the original Testing status/repair notes update as currently accepted and the Test Session closure constraint is respected. No fake `stage.work_order_intake` row or notification to an unverified reporter is generated.

### Entry paths — existing and new

| Entry | Existing/current Production behavior | Intended Work Management behavior |
| --- | --- | --- |
| Public Work Order Request | Google form / Apps Script → Work Order Intake → Manager triage | Preserve the form and current Intake. Correct details, **choose assignees before** a guarded single Promote/Release action, preserve request provenance, and send accountable notifications |
| Production Crew Task Feedback | Authenticated #172 free-form submission → `SETUP_CORRECTION` Intake, initially Submitted | Same free-form entry and provenance; Manager routes/assigns a correction, requests clarification and records outcome; only explicitly promotes to a Work Order for actual repair/action |
| Manager-created internal Work Order (existing design, improved UI) | The approved historical operational SOP already specifies direct Manager creation, but its currently governed command and permissions have **not yet been proven** from live code/roles | Reuse any verified current capability; otherwise implement only the missing governed direct-create-and-assign operation, including Stage/Work Area, type, urgency/year, problem, related Display where valid and actual assignees. Do **not** manufacture a public request or Intake row to create it |
| Test Session repair | Governed testing failure creates an active Work Order without Intake | Keep the same Test Session repair creation, downstream repair completion feedback, and closure blocking rules |

Work Orders use the existing Stage **or** Work Area location rule, People identities and normalized assignment relationships. The application must not grant broad browser DML rights, change the Test Session repair truth, automatically complete annual Setup tasks, or bypass existing audit, validation and authorization.

### Current Production model — verified read-only, October 18, 2026

The following observations are **current live database evidence**, not assumptions based on archived migration files:

- `ops.work_order` uses **`urgency_id`**, not historical `urgency`; it also has `source_intake_id`, source submitter and triage provenance, `repair_complete`, `date_completed`, completer, completion notes, `is_active`, related Stage/Work Area/Display/Test Session, and created/updated actor fields.
- **`ops.work_order_assignment`** is the actual relation, not the archived `work_order_assignee`. It has active flags, assignment roles, person identity, assignment/unassignment timestamps/actors and audit columns. The initial read model rolls up only active assignments, preserving the historical rows.
- `ref.work_order_status` currently defines active `SUBMITTED`, `TRIAGED`, `APPROVED`, `DENIED`, `IN_PROGRESS` and `DONE`; `ops.work_order_status_history` stores status events when they exist. **Catalog existence does not mean every Work Order has a status-history event.**
- `stage.work_order_intake` records human form requests and `SETUP_CORRECTION` submissions including raw free-form notes, original source, linked/raw reporter, time and triage details. Its trigger `trg_process_work_order_intake_on_triage` is an **enabled AFTER UPDATE OF triage_dropdown** trigger invoking `stage.tf_process_work_order_intake_on_triage()`.
- Actual `stage.p_process_work_order_intake(bigint)`: `triage_dropdown='1'` keeps Submitted; `'3'` inserts an active `ops.work_order` with source ID/person/time/details then **DELETES the original Intake** and returns **`assignee_count=0`** (so promotion and assignment are separate today); `'4'` **DELETES Intake** with no retained Denied record. It rejects unsupported values. The Directus **Work Order Promote from Intake** Flow is inactive, but database promotion is active. Do **not** use either destructive Intake action as a proposed correction closure mechanism, and do not assume a deleted original `source_payload` survived promotion.
- `ops.work_order` has an enabled completion-autofill trigger; Directus **Create Repair Work Order**, **WOI Request Triage Email**, **Work Order Email Assignees**, and **Work Order Complete-Update Display Test Session** Flows were active in the inspected metadata. Preserve existing non-mail side effects until each is reconciled and accepted.
- `ops.work_order_outbound_message` exists with channel/template/recipient/subject/body preview, `sent_flag`, time/provider/error and actor fields, but **requires `work_order_id`**. It is not, by itself, a queue for unpromoted feedback notifications. A read-only current grouping showed **zero rows** despite active Directus mail Flows. The October 17–18 server-to-Google Workspace SMTP work is promising, but reusable Work Management delivery, retry/dedup and recipient routes are **not yet independently accepted** from these results.

### Actual first unified-ledger result — Production DBeaver, October 18

The **original revision** of the #419 read-only `SELECT` [WO419 Unified Ticket Read-Only Candidate](engineering/WO419_Unified_Ticket_Read_Only_Candidate.sql) **executed successfully in authorized DBeaver**. The operator supplied all 389 data rows. A subsequent source-only revision adds exact assignee Person IDs and testing-link IDs for the newly confirmed My Work and Test Session UX; **that revised SQL has not been executed in DBeaver or a disposable clone yet**:

| Verified measure from supplied query output | Count |
| --- | ---: |
| Existing Work Order rows | 386 |
| Work Orders with non-null `date_completed` | 328 |
| Work Orders with NULL `date_completed` | 58 |
| Active Work Orders without completion date | 57 |
| Active, undated Work Orders with **no active assignee** | 10 |
| Inactive Work Order without completion date | 1 |
| Retained pending Intake | 3 (one `SETUP_CORRECTION`, two public form requests) |
| Work Orders with a status-history state surfaced by this query | 0 |
| Existing outbound-message rows in preceding grouped DBeaver result | 0 |

**Status interpretation:** For this measured snapshot all 386 Work Order rows appear as `DONE_DATE_ONLY` (328) or `STATUS_NOT_RECORDED` (58), because there is no joined status-history event. A real application must label them truthfully as **Completed (date recorded)** or **Not recorded complete (no completion date)** while explicitly indicating missing workflow history. `is_active` is **not** synonymous with open: completed Work Orders may still be active and one undated Work Order is inactive. A `last_at` value from `updated_at` or assignment changes is **last recorded record change**, not proof of physical progress, recent communication or acknowledgement. Avoid artificially labeling a Work Order `IN_PROGRESS`, `APPROVED` or `DONE` in status history unless that event genuinely exists.

**Identity examples grounded in the live result:** WO #372 Magic Igloo broken welds has no completion date and three assigned people; `INTAKE-60` is the retained Command Center cribbing `SETUP_CORRECTION`, still Submitted without a tracked correction owner; WO #418 originated as `SETUP_CORRECTION` Intake #64 and is now a Work Order, demonstrating a transition whose original Intake row was removed. `INTAKE-40` Magic Igloo section P/R and `INTAKE-57` test remain Submitted; the design must not silently delete or promote them.

These numbers are an **October 18 source snapshot**, not durable current KPIs or verified evidence that all dated completions reflect physically completed tasks. Validate against current data during browser review; no write or external mail occurred in this read-only query.

### Correction category and linked references — P0

**Operator design decision (October 18, 2026):** **Repair** and **Correction** must be clearly distinguishable Work Management categories in the same unified inbox, with a correction-specific classification and links back to the real objects being questioned. A Kit inventory correction can need the **Kit number/Kit Box, Container ID, Display ID and Procedure** simultaneously. Do not make the Manager reconstruct these relationships from free-form notes or treat every report as a repair. **Category is operational workflow classification, not a mandate to add a second master ticket table or overwrite `ref.task_type` without inspecting its existing contract.** A correction case may lead to an actual Work Order, but retains its own feedback/review outcome until verification.

**Two levels of classification:**

- **Primary category:** **Repair / Work Order** (physical work, maintenance or actual actionable task) versus **Correction / Task Feedback** (incorrect instructions, source relationships, inventory, location, database information or Setup process). Retain the original source form `SETUP_CORRECTION` and native `intake_id` independent of the displayed category.
- **Correction subject / owning domain:** *Kit Inventory / Extra Materials*, *Procedure / Work Instructions*, *Container or Display Inventory / Assignment*, *Setup Task / Stage / Schedule*, *Wiring / LOR identity*, *Location / GIS*, or *Other / Needs Review* are initial human-facing **routing choices**. Their exact vocabulary and destination permissions must be reconciled with existing Setup/Procedures/Testing/GIS contracts before freezing a new reference catalog. They are not proof that those headings already exist as reference-table rows.
- A report may have **more than one linked object** and more than one eventual action: for example a Kit missing a Display might require both a Kit content correction and a Procedure change. The category controls triage/authorization and the required outcome, **not which links are artificially excluded**. Do not force one mutually exclusive Kit, Container, Display or Procedure when the factual relationship involves several.

**Existing durable identity / reference model — confirmed from repository source:**

| Reference presented in Work Management | Existing authoritative identity and lookup | User-facing behavior |
| --- | --- | --- |
| **Kit number / Kit Box** | Setup Kit Inventory uses **`ref.container.container_id`** as the physical Kit Box identity with `ref.container.container_type_id=2`. **`ref.setup_task_container_support`** uses `relationship_type='KIT'` to associate a Kit Box Container with reusable Setup tasks. `ref.setup_container_extra_material` records expected contents against its `container_id`. These are **not a separately proven `kit_id` or `kit_number` column**. | Show the familiar Kit Box human label (for example, C058 if it is the real current label) and description **and the permanent Container ID**. A Kit choice must resolve a genuine `container_type_id=2` record. Link directly to its approved **Setup Kit Inventory** detail (`/kit-inventory/<container_id>` within the actual protected Setup application base, as supported by `Setup/Application/setup_kit_inventory.js`); do not guess the public origin/port or build a URL from unsanitized text. |
| **Other Container(s)** | Existing **`ref.container.container_id`**, for physical pallets/storage/other source Containers; not all Containers are Kit Boxes. | Select and attach any relevant real Container ID separately from the Kit link; show the human Container tag/name and use the current approved Container detail destination. If the selected Kit Box itself is the only Container, do **not** create two misleading independent objects for the same identity. |
| **Display(s)** | Existing **`ref.display.display_id`** with `display_name` as the human-readable label, linked through current real inventory relationships (e.g., `ref.display.container_id`) when applicable. | Show the real Display **name** first and permanent Display ID as secondary context. Permit multiple Display links where relevant. Open the approved Display/Testing or Setup context using its existing protected resolver; do not use a free-form number or rewrite LOR-owned Display identity. |
| **Procedure / published work instructions** | Accepted #172 `source_payload.procedure_context` includes `status`, `scope_type`, `summary` and current `documents[].name` (where resolved), along with `setup_task_id`, `setup_session_task_id`, Stage/Scene and assignment identity. The current Procedure application uses **context resolution** by authoritative Stage/Display/Task/Scene and published document assets; **a stable `procedure_id` for all such documents has not been verified**. | Show **View Current Procedure** and existing document/context when resolved; preserve which Procedure context or document was being reported *at submission time*. If a published Procedure changes later, retain the historical submitted reference/evidence and separately resolve the current published version. Do not invent a `procedure_id`, use an untrusted raw path or point at arbitrary files. |

**How references enter feedback, without breaking accepted #172:**

1. **Context first:** Setup already knows the scheduled task, Stage/Scene, crew and current Procedure, and accepted #172 persists these in `stage.work_order_intake.source_payload`. Work Management **consumes** those fields as structured context on the feedback detail. Do not make the volunteer retype task/Procedure/Stage. A report launched from a context-aware Kit Inventory, Container or Display screen should also carry those verified permanent IDs when that entry route is implemented; preserve its authorization boundary.
2. **Simple voluntary capture:** Keep the original **What did you find?** plus optional evidence. When a reporter actually knows the relevant Kit/Container/Display, allow an **optional searchable selector** showing human names/tags and resolving IDs, or provide a simple **Add related item** action. Never require the reporter to memorize numeric IDs, complete all reference fields for a general Procedure correction, or select a category they cannot know. No silent auto-inferred ID should be presented as reporter-confirmed fact.
3. **Manager correction triage:** The Manager/authorized correction owner may add, fix, confirm or remove link proposals on the **same Intake-origin correction case**, with attribution and historical trace. Resolve choices through the actual existing `ref.container`, `ref.display`, Kit Box/type and Procedure context/asset APIs. When the user typed an unresolvable label, retain it as **unverified evidence** and request clarification; do not create a fake reference row.
4. **Multiple typed links, safe persistence:** For each relevant link preserve **reference kind, authoritative stable ID or resolver context, readable snapshot label, how it was captured, who confirmed it and when**. A single case may link Kit Box, other Container, multiple Displays, Setup task and Procedure; maintain original `source_payload` and original human report. Determine the **minimal governed extension** to persist these links after checking existing Intake JSONB, Work Order source/provenance, normalized setup/kit tables and current audit policy. A JSONB source field alone is not a reason to copy and diverge from source identities; promotion must not erase the only trace of a referenced object.
5. **Safe navigation and authority:** Related items are **real protected links to the current system**; visibility of a reference does not grant editing rights in Kit Inventory, Procedures, Display inventory, Catalog or GIS. On unavailable/deleted/retired related objects, preserve the source reference and present **unavailable / needs review** rather than linking to the wrong record. Links and deep-link handling must be tested for correct identity, destination and negative-authorization cases.

**First disposable/browser acceptance examples:**

- **Kit Inventory correction:** Submit or open a disposable `SETUP_CORRECTION` with a real Kit Box Container, a real other Container when involved, an existing Display and Procedure context; classify **Correction → Kit Inventory**. Show clickable verified **Kit / Container / Display / Procedure** references on the same detail, in the Manager's assignment/clarification and reporter's view. Verify the Kit link opens the existing Kit Inventory, the Display label is readable, and all references survive clarification, correction resolution or explicit Work Order promotion. **No other inventory data changes merely because the feedback was linked.**
- **Procedure correction:** Show the original current Procedure context captured by Setup; select **Correction → Procedure**, route to a permitted Procedure owner, retain original document/context while allowing a link to the latest published Procedure, and send the original reporter an evidenced completion/disposition email when actually verified. No synthetic Work Order is required.
- **Repair category comparison:** A real Testing-generated repair or a Manager-promoted physical repair displays as **Repair / Work Order**, not as a Procedure/Kit correction. A single feedback case can retain both its original Correction origin and its promoted WO relationship without counting it as two independent reports.
- **Missing, ambiguous and security cases:** no invented Kit IDs, wrong Container types, arbitrary file URLs, unrelated Display IDs or cross-role edits. When a Kit label/Procedure cannot be resolved, preserve free-form evidence and let an authorized owner clarify rather than silently linking a different asset.

**Implementation status:** The above is **design authority and P0 acceptance**, not an assertion that current `stage.work_order_intake` has separate Kit/Display/Procedure link columns, that Kit Box has its own numeric key, or that any new capture/deep-link/correction metadata commands already exist. The original #172 source payload currently captures **Procedure/Setup context but does not specifically include a Kit Box or Display reference** in its initial JSON structure. Do not rewrite the accepted #172 submission code or install a schema migration until existing reference relationships, change authority and disposable acceptance have been reconciled with this design.

### Stage-first relevant resources — no scavenger hunt (P0)

**Operator clarification (October 18, 2026):** The correction reviewer should **not have to know or manually search for the right Kit, Container, Display or Procedure**. The **Stage Setup context is the starting point**. Much of the information is already connected at the Stage and Scene scope even when a particular annual or reusable task has no direct asset/material assignment. When the operator opens a Setup-origin Task Feedback item, Work Management shall present one **Related Information** expandable section, **collapsed by default**, containing relevant Stage resources **on demand**. Its compact heading remains visible without forcing the operator to read an enormous Stage inventory; expanding it loads the current related records using the preserved Stage/Scene/task context, with clear provenance, bounded results/search and protected **Open** links. Do not make the reviewer leave the correction to find related records. The purpose is to answer *"What associated information should I check?"* rather than "Which separate app do I search, and what ID must I already know?"

**Existing sources inspected, not a new Stage table:**

- The accepted `ops.prepare_setup_work_order_intake` saves authoritative **season, annual/reusable task, Stage/Scene, assignment, reporter and current Procedure context** to `stage.work_order_intake.source_payload`. Stage/Scene identity is known on arrival; the operator must not enter it again.
- The existing `Setup/Application/setup_scheduling_board_repository.py` assembles annual task context from `ops.setup_session_task`, `ref.stage` and `ref.lor_scene`, with task resources, `ref.setup_task_container_support` and `ref.setup_task_extra_material`. This is **already a read pattern** for finding direct task relationships.
- The existing `Setup/Application/setup_kit_inventory_api.py` reads Kit Box `ref.container` records (`container_type_id=2`), their `ref.setup_container_extra_material` expected contents, task-linked Kit assignments (`ref.setup_task_container_support.relationship_type='KIT'` joined to `ref.setup_task.stage_id`) and real `ref.display` inventory. A Kit may support **more than one task**; absence from the reporting task's direct assignment does **not** exclude it from Stage resources.
- The existing `Setup/Application/setup_assignment_layer.py` distinguishes LOR **real Scene** vs **Stage-level** Display scope through `ref.lor_scene_display`, `ref.lor_scene` and permanent `ref.display`, independently of a task's `requires_display_material` flag. Do not conflate a Display's Stage/Scene association with its task ownership, physical Container contents or current 2026 observed park location.
- The existing `Setup/Application/setup_work_order_intake_api.py` resolves current published Procedure context when possible (or states unresolved), and `source_payload.procedure_context` preserves **what was resolved at submission time**. Later current Procedure lookup is a separate read; no invented `procedure_id`.

The Stage Setup view therefore acts as a **context/aggregation boundary**, not proof that all related objects are stored in one `ref.stage` row. Reuse existing source joins/read APIs and current Production relationships first; an additional **scoped read-only aggregation endpoint** may be justified to assemble the panel securely. Do **not** invent a second Stage registry, write new associations as a side effect of browsing, or silently broaden object-authoring permissions.

**Inside the expandable "Related Information" section, show this hierarchy (no large resource list on initial ticket open):**

| Context group | What the reviewer sees automatically | Relationship label / guard |
| --- | --- | --- |
| **This task** | Its exact annual/reusable task, Stage/Scene, direct Kit/required Container assignments, task Extra Materials, task-related Displays **where real task links exist**, and the original submitted Procedure/context | **Directly linked to this task** (or **Captured with this report** for the original Procedure). Empty task-specific links never imply the Stage has no related materials. |
| **This Scene / Stage** | Other Stage/Scene Displays (name first, ID visible), Kit Boxes associated with other reusable tasks in the same Stage, their readable Contents/expected stock, supporting Containers and material/source relationships, current Stage Procedure resources where resolvable | **Related to this Scene** or **Related to this Stage — not confirmed for this task**. Shared Kits and Stage-level assets appear even if they support another task. Do not claim physical presence or confirmed task assignment. |
| **Additional related items** | One **Search other Kits / Containers / Displays / Procedures** control when the target is outside Stage scope, shared with another Stage, or unavailable in normal relationships | **Search result — relationship unverified** until a person confirms it. Do not force a new free-form ID lookup as the starting step. |

**Relevance and display behavior:** Start with **Stage/Scene/season** from the retained feedback, not solely the reusable task ID; use specific task links to rank results first, then same real Scene, then same Stage, with a compact collapsed list/search for large stages. Show the **human Kit/Container tag, Display name, material name, Procedure/document title** and secondary permanent IDs; deduplicate repeated references. Prefer authoritative relationship joins to guessed name matching; show an explicit **Unavailable / source unresolved** state when a lookup fails. A candidate is an aid to inspection **not a finding that an asset is missing, on that task, currently deployed at that Stage, or owned by that reporter**. Show source/relationship evidence where ambiguous.

**Inspect vs identify:** Each relevant record has an **Open** action to its already-established protected Kit Inventory, Container, Display/Testing, material or Procedure page without abandoning the feedback context unnecessarily (preserve return path/selection). These are read-only navigation links for readers unless their role independently permits edits. A Manager or reporter can **Mark relevant to this correction** (or **Remove from correction**) to create an explicit typed **Confirmed for this correction** association in the governed Work Management correction record—with real IDs, attribution and time—without modifying `ref.setup_task_container_support`, Display ownership, Kit contents, Procedure versions, current Container location or reusable Setup Catalog. A Stage suggestion must never silently become an assignment or an inventory correction.

**Category-aware discovery:** For **Correction → Kit Inventory**, surface Stage Kits, expected Kit contents, related Containers, source materials, and Display candidates first. For **Correction → Procedure**, foreground original and current published Stage/Scene Procedures, the task, and materials/Kit resources referenced by that context. A Repair/Work Order screen uses the same link/navigation foundation but keeps repair execution and Testing semantics separate. Categories influence **presentation**, not authority or the set of real records that can be accessed.

**P0 disposable/browser acceptance:** With **Related Information initially collapsed**, expanding once must load the Stage resources without losing the ticket, changing its state, or issuing a write. Collapse/reopen must preserve ticket context without needless repeated database traversal. Using the existing cloned `INTAKE-60` (which has real Stage 40 Command Center context but no pre-confirmed Kit/Display links), open Task Feedback without entering a Kit number. The user sees the known task, original Procedure status, **Stage 40 candidates** from actual clone data where available, plus clear empty states where none exist. Select a Stage-related Kit Box linked to another task, inspect its contents and associated Displays, and confirm it for the feedback—without altering the Kit's task assignments or moving anything. Navigate to a published Procedure where resolvable; open a Display by name. Verify labels **Directly linked**, **Stage-related** and **Confirmed for correction** remain different before/after reload and clarification, that the original report stays intact, that no unauthorized edits occur, and that the reporter can follow permitted links without acquiring Manager rights. On another Stage with richer data, exercise real Scene/Stage vs task associations; the panel must not appear empty just because the single reporting task has no direct Kit assignments. No fabricated candidate or hard-coded inventory fixture is acceptance evidence.

**Release state (October 18 V0.1 candidate):** Source relationships and #172 Task Feedback Stage provenance are verified existing code contracts. A **first read-only source implementation** now exists under [WorkOrders/Application](../../../../WorkOrders/Application/README.md): a ticket screen with **Related Information collapsed by default**, a protected GET endpoint that assembles task/Stage Kit/Container/Display/material candidates and original Procedure context, and source-level tests. **This is not a runnable/accepted browser result yet**: SQL and data-source compatibility on the clone, complete Stage/Scene relevance, working deep links, explicit confirmed associations and all P0 correction communication/actions still require implementation and disposable/browser tests. No Production migration, changed Setup intake payload, mail sender or Directus Flow is authorized by this source commit.

### Setup Task Feedback consumption — alternate correction workflow (P0)

**Operator decision (October 18, 2026):** The unified Work Management subsystem must **consume existing Setup Task Feedback**, not merely list it beside repair Work Orders. **A field correction is not necessarily a repair job.** The Work Management application needs a dedicated, accountable **Setup correction / review branch** as an alternative to **Triage → Promote & Assign**. Both branches share one Management inbox, original reporter identity, case discussion, audit and reporter notifications; they retain distinct business outcomes and authoritative owning systems.

**Existing implemented source/entry path — preserve it:** Accepted [#172 Production validation](../../../../Setup/Acceptance/Setup_172_Report_Correction_Production_Acceptance_2026-09-27.md), [Setup migration 062](../../../../Setup/Database/062_add_setup_context_work_order_intake.sql) and [protected Setup correction API](../../../../Setup/Application/setup_work_order_intake_api.py) establish:

`Perform Work → Task Feedback / Report Correction → ops.prepare_setup_work_order_intake(...) → protected Setup API → Directus Items API items.create → stage.work_order_intake (source_form_name='SETUP_CORRECTION', triage_dropdown='1') → Manager triage notification`.

The operator supplies **What did you find?** and optional suggested correction/evidence. Existing source preparation authenticates the reporter and records the real annual Setup task, optional reusable task, Stage/Scene, scheduled assignment, Setup Work Day/date/shift/Crew/Captain, Procedure context, reporter identity and submission time in **`source_payload` JSONB**; the record also carries `problem_raw`, `notes_raw`, `submitter_person_id`, source/form and normalized location/year. The source currently requires a real scheduled assignment. **Do not modify this accepted low-friction Setup entry or fabricate a scheduled assignment/Report Work for an unscheduled observation.** Unscheduled capture is a separately governed future input improvement, not a pretext to change #172 on this implementation pass.

**Consumption contract and lifecycle:**

1. **Discover without duplicating.** The Work Management Manager inbox reads **existing** `stage.work_order_intake` rows by native `intake_id` and identifies `source_form_name='SETUP_CORRECTION'` (with source validation), keeping the unaltered report and `source_payload` provenance. Intake #60 is the known retained Production example (Command Center leveling cribbing); Work Order #418 demonstrates a past `SETUP_CORRECTION` Intake #64 promoted to a WO and deleted by legacy processor. The record is **not** resubmitted, copied into a competing master ticket, or interpreted as actual work completed.
2. **Review as a correction first.** Manager reviews the real Setup context and chooses whether the finding concerns a **Procedure/instructions**, reusable task/Catalog, materials/Kit/extra materials, annual Setup scheduling/data, location/GIS, Display/Wiring identity or other existing accountable domain, or actually calls for physical **repair/maintenance Work Order**. These are **routing destinations / review categories**, not asserted existing tables or permissions. The Manager may request clarification from the reporter before routing, assign a responsible correction owner, set a truthful next action and target review, and retain a dated conversation. **Rick/the reporter is not automatically the correction owner.**
3. **Alternate non-Work-Order correction route:** If it is a data, documentation, Procedure, material or Setup-process correction, keep it as an **Intake-origin correction case**, assigned to the authorized owning subsystem/reviewer. That owner acts through that subsystem's existing approved commands and permissions, then records what was changed and where, verified or deferred/rejected/duplicate disposition, evidence, actor and time. A correction is **not complete** just because a Manager assigned it, acknowledged it, forwarded it by email or updated a notes field. Do not auto-edit `ref` data, Procedure, LOR or reusable Setup Catalog, and do not create a synthetic `ops.work_order` to gain an email/outbox link.
4. **Physical-work branch:** Only where the Manager explicitly determines a genuine actionable job is required, use the existing **Work Order Triage → Promote & Assign** contract with real selected assignees. Retain the original `SETUP_CORRECTION` evidence/reporter/Setup relationships, even though today's legacy `stage.p_process_work_order_intake` deletes Intake on promotion. A linked physical Work Order's completion **does not automatically prove** the underlying Procedure/material/Catalog correction is verified; preserve distinct follow-up obligations where both are needed.
5. **Common reporter loop:** For both branches the authorized owner has **Request More Information** from the original reporter, sent through the eventual single governed notification provider to a verified address, and the reporter answers in the **same protected case**. On verified correction resolution, reasoned deferral/rejection/duplicate or actual completed physical work, issue the appropriate reporter **outcome email**, with durable recipient/delivery state, activity/audit and direct safe case link. A promotion notice is **not** an outcome notice.
6. **No destructive disposition:** The existing `triage_dropdown='4'` branch **deletes** original Intake and `'3'` deletes it after promotion. Neither may serve as the normal resolution action for Setup corrections requiring later review or reporter follow-up. Introduce only the **smallest governed durable correction-owner/disposition/conversation/evidence/source-link persistence** proven missing from the current schema. Maintain original Intake provenance and one clear link from Setup-origin report to its accepted outcome. Existing `ref.work_order_status` is a Work Order status catalog, **not automatically the correction-review state machine**.
7. **Review feedback into Setup without altering work history:** The outcome remains visible from the original Setup task/assignment/Procedure context where the accepted Setup interface has a permitted linkage, and available to the season-end **#209 experience → reusable Catalog reconciliation** (accept/modify/reject/defer) without making field feedback itself an authoritative reusable change. A 2026 finding must not mutate or falsify a 2026 Report Work actual, workday, crew, task percent or reusable instructions merely by being triaged.

**P0 browser/disposable acceptance:** Open **existing Intake #60** in the same Work Management inbox as public requests and active WOs; follow its original Setup assignment/Stage/Procedure context; classify and assign a **non-repair correction** without creating a Work Order; use **Request More Information**, see one captured **no-send** mail and a protected original-reporter reply; mark the corrected or explicitly deferred outcome with evidence/verification; show a separate captured outcome email and an audit trail. Then, using a **different disposable Intake fixture** sourced through the accepted path, choose the **repair** branch, Promote & Assign atomically, confirm one WO, retained original report link, eventual completion and exactly one real-reporter outcome notification. Negative tests must prove no duplicate cases/emails, no lost original `source_payload`, no unauthorized correction to Setup/Catalog/Procedure, and no automatic test/repair completion. Production Intake #60 must remain untouched.

**Status / unresolved implementation detail:** The existing #172 producer and Intake source are **Production accepted**. The **alternate correction route, owner/disposition/replies, reporter notification, and consumer API/UI are not yet implemented or Production accepted**. Exact persistence, safe links, actor capabilities and email intent/outbox design require governed reconnaissance and acceptance against the current schema/Directus capabilities. This is **P0 functional design authority** for the first unified browser candidate, not proof the feature exists.

### P0 first-release gate — reporter clarification, outcome email, and one-step triage

**Controlling operator requirement (October 18, 2026):** The first accepted Work Management release MUST close the communication loop for existing Task Feedback and human-originated Work Order requests **and** allow a Manager to **triage, Promote, and assign in one screen and one deliberate action**. These are **P0 release blockers**, not nice-to-have notifications, deferred features or a static-list-only V0.1. The application must improve the existing accepted database workflows, not replace them with a parallel ticket system.

**A. Request more information from the original reporter — practical Manager/owner action**

1. From the **same original Intake/Task Feedback or promoted Work Order detail**, an authorized Manager/correction owner selects a prominent **Request More Information** action. The action opens a focused short question composer already associated with the immutable ticket identity, original reporter, and existing evidence; the operator reviews the question and selects **Send Request**. Do not require navigating a separate generic Directus email Flow or manually copying reporter addresses.
2. Resolve the destination from the **original verified reporter identity/contact** (`stage.work_order_intake.submitter_person_id`, validated original human form contact where applicable, or the persisted `ops.work_order.submitted_by_person_id` from a promoted request). Do not silently substitute the assignee, triaging Manager, `created_by` service user, or a guessed address. If contact is absent/unverified, show an actionable **Cannot send — reporter contact needs review** state and keep the ticket pending clarification; never claim an email was sent.
3. Persist **who requested clarification, when, exact question, destination/contact resolution, ticket linkage, current response-needed state, and send attempt/outcome**. Deliver the email through the **governed MSB Google Workspace notification service** once its application-specific sender/outbox, privacy controls, retry and deduplication are verified. The message includes understandable ticket context, a safe authenticated **View/Respond** link, and the actual question. The reporter's reply is stored as a dated, attributed conversation entry on **that same ticket**, with the original finding unchanged; notify or surface the reply to the responsible owner.
4. A successful HTTP response or a queued message is not proof of delivery. Distinguish **queued, delivered/accepted, failed and awaiting reply** using evidence supported by the real provider; an error/duplicate request must not create duplicate email or contradictory ticket state. Do not promise inbound Gmail reply parsing without a separately inspected, approved inbound-email mechanism. The baseline response channel is the protected app link.

**B. Notify the original reporter of the real outcome**

1. For **Task Feedback** that results in a verified Procedure/Catalog/material/Kit/GIS/data correction, or is deferred, rejected/no action or linked as a duplicate, preserve a meaningful **disposition and explanation** with accountable owner, verifier/decision maker, time, and any affected source record. The **original reporter must receive a final outcome email** and be able to view the retained history. Do not let a destructive `triage_dropdown='4'` delete be treated as disposition; do not automatically rewrite reusable Catalog records on the strength of a submitted note.
2. If a human-originated Intake is **promoted to a Work Order**, retain the original reporter and source evidence. **Promote is not Complete**: the final repair/completion notice to the human reporter occurs only when the actual Work Order is recorded completed and its required notes/verification exist; a separate assignment notice may go to the selected assignees. If the ticket is explicitly deferred, denied or duplicate without repair, send the correctly worded disposition email instead.
3. A **Test Session-generated** repair Work Order has no implicit human Intake reporter; completion **must update the authoritative Testing record and repair notes**, and only sends a human notification when a real Testing subscriber/recipient is authorized and established. Do not send an automatic feedback-closure email to an invented human reporter.
4. Record exactly which triggering transition produced a notification, intended recipient, subject/template, send state, attempt and failure. On missing/unreachable contact, show a visible Manager exception and preserve the resolution/repair truth; a failed message must **not** falsely mark a report acknowledged or cause duplicate Work Orders.

**C. Manager triage → Promote → Assign as one controlled operation**

1. A Manager opens the **existing** Work Order Intake record and sees its original reporter, submitted description, Stage/Work Area, Display where applicable, task type, urgency, target year, evidence and notes on one focused screen. The Manager corrects data, chooses **one or more real `ref.person` assignees before release**, and reviews the result.
2. The Manager selects **Promote & Assign** (one intentional save/commit). The governed server/database command must validate permissions and required fields, create **exactly one** authoritative `ops.work_order`, persist **all chosen active `ops.work_order_assignment` relations**, record true actor/triage/source provenance, and yield the exact Work Order link **as one transaction or an explicitly proven equivalently atomic boundary**. A validation/assignment failure rolls back the *entire* promotion; the original Intake remains actionable, not half-promoted or missing. Repeated clicks, concurrent Manager actions and request retries cannot create duplicate WOs, assignments or email.
3. **Do not use the current `stage.p_process_work_order_intake(bigint)` as-is for this operation.** As proven live, it creates a Work Order with `assignee_count=0` and deletes Intake; adding a second UI call to add assignees repeats the existing failure mode. First inspect the current trigger, constraints, source fields and enabled Directus operation graphs, then implement a narrowly governed compatibility/replacement transaction. Preserve original report evidence/source linkage needed for future reporter communication and January review. Avoid an independently authoritative new ticket table.
4. Assignment mail for the selected people is **one notification per actual assignment event/person**, generated only after authoritative commit. The original reporter is not treated as an assignee or notified that work is complete. A deliberately unassigned exception, if ever approved as a distinct Manager action, must be explicitly labeled and routed to the Manager unassigned queue; it must never be the accidental result of a failed assignee screen.
5. Keep the existing public form/Apps Script intake, approved #172 Task Feedback submission, automatically generated Test Session repairs, current Directus personal bookmarks, Setup Work Order gates and accepted completion flow functioning until protected full-system acceptance. Production Directus Flows are retired **per event** at an approved cutover so the old and new systems cannot both send email or create/complete the same repair.

**Required first disposable browser tests — these must be click-through, not source-token-only checks:**

| Test | Must demonstrate |
| --- | --- |
| `INTAKE-60` Task Feedback (disposable clone) | Manager opens original free-form observation, clicks **Request More Information**, submits a question, sees one **captured no-send test email** to the verified reporter and an awaiting-reply state; reporter opens their scoped reply link, answers, and Manager sees the linked dated reply without losing the original note |
| Feedback resolution / deferral | Manager routes and verifies the real correction or selects an explained deferral/denial; original reporter receives exactly one appropriate **captured no-send outcome email**, and the result remains searchable for January review |
| Existing public Work Order Intake (clone of `INTAKE-40` or `INTAKE-57`) | In **one Manager screen**, correct/classify, choose assignees, click **Promote & Assign** once; obtain **one** assigned WO with original source/reporter preserved, correct Manager actor, pending-vs-completed semantics and **one** test assignment notification per unique person |
| Failure/retry/concurrency | Bad inputs, revoked capability, duplicate submissions, missing reporter address or mail failure cannot leave a half-promoted request, lose original source, duplicate assignment/WO, leak a ticket, or falsely mark an email sent |
| Actual human-originated WO completion | Authorized assignee saves real completion notes and performs governed completion in the clone; the real Work Order completion is recorded, and the **original human reporter** receives exactly one correctly worded **captured no-send completion email** (not at promotion/assignment time) |
| Testing-origin WO completion | Existing Testing repair update and notes occur, with no made-up Intake or reporter notification, and no duplicate legacy Directus side effect |

**Implementation and approval gates:** In-repository Work Orders engineering design → source-owned governed persistence/API/UI → regression and disposable-DB validation → authenticated exact-candidate browser review of **all** P0 actions → accepted no-send messaging and recipient/duplicate evidence → separately approved Production cutover with reliable real MSB email delivery and noncompeting Directus Flows. Do not mark the Work Management browser pilot accepted based only on browsing My Work or a SQL union, and do not deploy with Request More Information, reply capture, verified closure email or one-step Promote & Assign missing.

### Accountability and two-way reporter communication — required acceptance

**Every actionable item must be discoverable with a truthful status, named responsible owner or an explicit unassigned state, last recorded activity, next action and disposition.** A Manager must be able to find all outstanding repair Work Orders regardless of urgency, assignee or completed status; a Stage view under #205 must link to the authoritative Work Order rather than implementing competing Work Order edits.

The original reporter must see their own Task Feedback, with its current outcome and history. A correction owner can **Request Clarification** from that reporter; the original reporter receives a targeted email with a safe link to answer in the **same ticket**, and the assigned owner sees the reply. On a final verified correction resolution, deferral, denied/no action with reason or linked duplicate, notify the original reporter with the decision and explanation. If Feedback is promoted to a repair Work Order, **promotion is not completion**: source provenance and eventual Work Order closure outcome must remain traceable and communication must not falsely imply the repair occurred. Never default all ownership or notifications to a single experienced volunteer.

Every request/reply, correction owner assignment, next action, disposition, actor/date and notification outcome must be durable and auditable for the January review. The existing raw Intake status/delete/promotion operation cannot meet these requirements by itself. Identify whether narrowly scoped additional correction comment/ownership/outcome and cross-link persistence is necessary; do **not** create an independent master ticket store merely for a common interface. Keep the original free-form report intact and do not grant Crew members controlled Catalog/Procedure write access.

For outgoing email, use the governed MSB/Google Workspace delivery authority after real runtime proof. Record recipient, subject/template/event, QUEUED/SENT/FAILED (or equivalent authoritative states), deduplication and retry outcome. Delivery failure is visible to management, never silently claimed as sent, and does not fabricate ticket completion. Existing active Directus mail Flows may be retired only through explicit duplicate-free acceptance/cutover while preserving test/repair business effects.

### Directus Flow retirement and one-authority Production cutover — mandatory release gate

**Operator requirement (October 18, 2026):** Once the accepted Work Management application is launched, **no old Directus Flow may independently duplicate an event already owned by the new application**. Avoid duplicate repair Work Orders, duplicate assignee emails, competing completion updates, and contradictory ticket statuses. Equally important, disabling a flow must not silently remove an operational service that the new application has not yet replaced, particularly Testing repair creation/completion and the accepted #172 Intake notification.

**Ownership is determined per event/side effect, not per product.** For each current Directus Flow, first inspect the real deployed `public.directus_flows` metadata, the full `public.directus_operations` graph, event collection/action/filter, provider/mail behavior, PostgreSQL triggers/functions, actor authority, recipient resolution, and every downstream consumer. **The October 18 DBeaver results proved names and active/inactive flags, not the full operation logic.** Do not equate `inactive` with an unused business capability; the PostgreSQL `stage.p_process_work_order_intake(bigint)` processor is **currently active via its own AFTER UPDATE trigger** even while the Directus `Work Order Promote from Intake` Flow is inactive.

| Directus Flow seen October 18 | Live flag | Cutover requirement; final action must follow inspected source |
| --- | --- | --- |
| `WOI Request Triage Email` | ACTIVE | **Replace notification ownership**, preserving public Google Form and #172 Task Feedback Intake receipt/Manager triage visibility. When the new app's durable intake notification is accepted, stop the old Directus mail sender from producing the **same** new-Intake notice. Do not remove the Intake creation route or falsely assume a direct PostgreSQL insert fires an `items.create` Flow. |
| `Work Order Email Assignees` | ACTIVE | **Replace assignment/reassignment email** with the approved MSB Workspace sender, one ticket-event/recipient idempotency key and auditable send/failure, then disable the competing Directus mail branch. Assigning a Work Order must survive email failure without ghost/duplicate assignments or falsely recorded delivery. |
| `Create Repair Work Order` | ACTIVE | **Preserve automated Testing repair creation** until the replacement is verified end-to-end for exact Test Session cases and duplicate-prevention. Do not blindly disable just because a new general Work Order Create screen exists; Manager internal Create and Test-generated repair are distinct inputs. If the application takes over this event, switch to a single authoritative creator with tested repair identity/history/permissions. |
| `Work Order Complete-Update Display Test Session` | ACTIVE | **Critical Testing integration.** Preserve exactly-once repair completion feedback, repair notes/history, and container Test Session closure restrictions. Disable only **after** the new governed completion path demonstrably delivers equivalent Testing updates without two writers racing. It may need to remain enabled for legacy Directus completion writes until that entry path is deliberately retired. |
| `Work Order – Auto Complete Fields` | INACTIVE | **Leave inactive** unless separately proven required. PostgreSQL currently has an enabled `ops.tf_work_order_autofill_completion_on_repair_complete` trigger; do not conflate this database trigger with the inactive Directus Flow or accidentally run both autofill mechanisms. |
| `Work Order Promote from Intake` | INACTIVE | **Leave inactive.** Existing PostgreSQL `stage.tf_process_work_order_intake_on_triage` invokes `stage.p_process_work_order_intake`; the current processor inserts a Work Order and deletes Intake for Promote and returns zero assignees. The redesigned Triage→Assign→Release needs a governed replacement transaction/compatibility strategy so legacy Directus/DB and new app cannot both promote the same Intake. A new Flow activation is not the solution. |

**Go-live sequencing and rollback contract:**

1. **Inventory and decision matrix before coding or Flow edits:** for each event (`Intake.created`, `Intake.promoted`, `WO.created` including Testing, `WO.assignment.changed`, `WO.completed`, `Testing.repair.updated`, and `Ticket.clarification/resolved`) record the **one authoritative writer** of business state and **one authorized notification producer**, old path, new path, flow ID/status and root operation, existing PostgreSQL trigger/function, event key, downstream effect, operator permissions, acceptance evidence, safe disable moment, and restore action. Where the actual operation graph is not yet inspected, status is **UNKNOWN / HOLD** rather than an invented assertion.
2. **Safe development:** build on a current-Production disposable PostgreSQL/Directus clone, with source-controlled candidate Flow/configuration changes isolated from Production. Use both event entry paths that will exist during transition; test normal, concurrent/double-submit, duplicate/retry, legacy/directus, real Test Session-generated, failure and rollback cases. Current live Directus Flows remain untouched during reconnaissance, source work and browser review.
3. **Separate business transitions from mail transport.** Moving assignment/completion logic out of Directus does not imply mail should be sent by a PostgreSQL trigger; use the approved MSB/Google Workspace server notification boundary only when the **outbox/delivery attempt and recipient contract** is established. `ops.work_order_outbound_message` exists but showed zero entries and requires `work_order_id`; it does not prove a complete sender or support unpromoted Task Feedback. A notification must be emitted **once** for an actual durable accepted event and sent **once per permitted recipient** under a stable deduplication key. Preserve original reporter notification, clarification replies, and Testing feedback without inventing a reporter.
4. **Cutover must be explicitly approved as its own Production change** under the governing Server Management Directus administration and Production Database change/deployment runbooks. Preserve a verified restorable snapshot of the exact live Flow IDs, statuses and operation definitions *in an approved protected location* (no secrets in Git, test output or issue comments). Record before/after production fingerprints where governed, exact deployed new app SHA/version, migration identity if any, responsible operator, affected events and observed test results. **Do not bulk-disable every Work Order Flow** or change Directus global settings, Testing services or unrelated Flows.
5. **Prevent overlap at the switch:** do not allow the existing Directus and new app senders to concurrently dispatch the same event. Where old and new paths must coexist temporarily, define their routing/authoritative event-owner rules so an event is handled by **exactly one** creator/notification producer; fail closed on ambiguous ownership. Disable **only** a specific superseded legacy Flow/operation after its replacement is ready, without a gap in critical Intake/Testing behavior. An active legacy editor link/bookmark must either keep its required Flow behavior or be deliberately retired/redirected after acceptance.
6. **Real production post-switch gate:** exercise a controlled legitimate Intake request, Task Feedback receipt, assigned Work Order, test-generated repair case, guarded completion and reporter clarification/closure under the new application, using approved safe records and exact permitted recipients. Prove the expected **single** Work Order, assignment, delivery attempt, actual Testing update, reporter response and durable audit. Count duplicate Work Orders/emails; zero unexpected duplicates required. Monitor error/audit logs and verify no unprocessed Intake or orphaned Testing repair after switch.
7. **Rollback is two-sided and bounded:** if authorization, creation, email or Testing feedback fails, stop new writes/mail as the runbook permits, restore the exact documented previous Flow/operation state and previous accepted app routing **together**, ensure provider queues cannot replay duplicates, and verify live legacy entry paths work. Do not reactivate old Flows while the new event sender continues processing the same queue. Keep authoritative already-committed Work Orders and audit records; never erase them to simulate a rollback.
8. **Closeout:** update the Work Orders engineering/design, Server Management-owned live Directus/runtime cutover instructions and operator SOPs with exact accepted Flow disposition, receipts, regression/browser outcomes, and resume point; align issues/PRs with the documents. A merged PR or an active new application alone is not proof that a competing Flow was retired safely.

**Runbook gap found (October 18, reconnaissance):** The current [Server Management Directus administration portal](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/directus/README.md) documents general Directus runtime/extension recovery, but the reviewed materials did **not establish an approved, Flow-specific snapshot/disable/restore and two-sided Work Management application cutover procedure**. This is a **RUNBOOK GAP FOUND**, not authorization to improvise a Directus UI toggle or database metadata UPDATE. The Server Management owner must locate or add the accepted Flow cutover/restore procedure (including security-safe snapshot and exact operation inventory) and link it from the responsible runtime portal **before any Production Flow change**. The Production Database repository continues to own the event/business and notification-equivalence contract here; do not copy the entire server execution runbook into this design.

**Acceptance is blocked** until the complete per-event inventory, disposable regression/browser verification, explicit operator-approved Production cutover and rollback evidence establish **no simultaneous writers or mail producers, no lost Intake, no lost Testing repairs or closure feedback, no duplicate notifications, and preserved reporter accountability**. Until then, the existing active Directus Flows remain in service unchanged.

### #419 disposable end-to-end browser acceptance candidate — next engineering milestone

**Decision/status (October 18, 2026):** The established PostgreSQL architecture and DBeaver-proven 389-row unified read model are sufficient to **begin application engineering and an isolated browser candidate**. They are **not** evidence that the application, transactional ticket actions, protected runtime or disposable test harness exists yet. Build toward one coherent **MSB Work Management** operating experience, not two disconnected Work Order and Feedback applications. **This is a complete product-design and test contract**, not a declaration of runtime or Production acceptance.

**First browser-review experience (one cohesive app):**

1. **Work Orders landing:** enter at **My Work** filtered by authenticated `ref.person.person_id` and active `ops.work_order_assignment.person_id`; display undated active orders initially; independent `Show completed`, optional **All Work Orders** and individual-person scope when authorized. Real human problem, assignees, Stage/Work Area, source, latest *recorded database change* (not claimed physical progress), and direct detail.
2. **Search / global follow-up:** one search across WO ID, description, Stage/Work Area, assignee, urgency, source and completion-date/state, including completed and unassigned WOs. Distinguish **no status-history event** from verified complete; provide Manager-oriented unassigned/open/stalled lists, with no invented workflow history.
3. **Unified ticket detail:** retain native `WO` / `INTAKE` identities, original submitter, source and context; show assignments, exact link to annual Setup task/Stage or `display_test_session_id` when present, permitted notes and chronological auditable events. Present allowed actions by ticket type/actor, not a raw Directus record editor.
4. **Inbox / Task Feedback:** keep existing #172 free-form report submission and existing public-form/Apps Script intake untouched. Manager can classify and assign a correction, request specific clarification, record original-reporter reply, route to real repair or responsible domain, and record a verified resolution/deferral with reason. **Retain original report content/provenance**; do not use current destructive `triage_dropdown='4'` as closure or auto-Promote to generate mail.
5. **Work Order actions:** authorized **New Internal Work Order** without public Intake; from reviewed public Intake perform **correct → choose assignees → governed Promote/Release** as one safe operation; change assignments without destroying assignment history; permitted volunteers enter progress/completion notes and complete only actual work. Test Session-generated repair WOs are part of the same My Work/All list but retain the Testing link and completion integration.
6. **Communications:** from an assigned correction, a clarification request creates a durable event and a **test-only outgoing email** for the original reporter. A reply is recorded on that same ticket and surfaces to its owner; final verified outcome produces the correct **test-only reporter completion/deferral** message. Test missing reporter email, failed send, dedup/retry, and promotion not being misrepresented as completion. Real emails are forbidden during disposable browser acceptance unless a separate controlled and specifically authorized one-recipient mail test is approved.
7. **Flow compatibility:** exercise the real logical side effects of current Intake, assignment, testing repair creation, testing closure and active Directus Flows inside isolated test resources. The first browser candidate should make it possible to judge the **whole operator journey**, while any simulated/fake mail delivery must be visibly labeled. Do not claim a live Flow was retired or its equivalence was proven from a screen alone.

**Disposable acceptance environment and security boundary:**

- Start from a governed **current-Production PostgreSQL clone**, not from a blank hand-built Work Order fixture. It may include the exact identified WO372, WO418, retained `SETUP_CORRECTION` Intake60, the two public pending Intakes, and a real existing Testing-sourced repair. All candidate migrations/functions/commands apply **only to the clone**.
- Use the real accepted MSB Person/Cloudflare/Directus capability boundary. The candidate must distinguish a Manager from at least one Crew assignee, an individual feedback reporter and a Testing participant. Test negative unauthorized paths; never grant broad browser SELECT/UPDATE merely to render a list.
- Clone Work Order/Intake schemas and any necessary Directus metadata/operations under isolated credentials. If a true isolated Directus Flow execution requires additional infrastructure, document what it can/cannot prove, and **hold Flow-retirement acceptance** until the full runnable behavior is tested. Never point a browser preview at live PostgreSQL even if the first screen is read-only.
- Draft **narrow, auditable persistence and business commands** for correction owner, comments/replies, disposition, source link and transactional Intake→WO release only where live schema/commands lack them; avoid a second master ticket system. Preserve original Intake rows across correction outcomes and appropriate historic evidence on Promote. Do not reuse the old destructive triage path in normal newly controlled correction closure.
- Capture outgoing email in a **disabled/no-send notification sink** or approved isolated mail provider. Real Production Directus Flows, Google Form, sender, access configuration and Production records remain unchanged throughout candidate validation.
- Host a temporary authenticated Flask/browser instance through the current [Server Management Pre-Production Browser Review Runbook](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Pre_Production_Browser_Review_Runbook.md). A dedicated Work Management test/runtime allocation **must be recorded/approved in the Server Management Application and Test Port Register** before launch; do not assume 8898 belongs to #419, borrow Production service ports or guess an unused port. Require exact source SHA and visible version plus browser candidate readiness, snapshot, acceptance report and **CLEAN EXIT**.
- Implement the user-facing Work Management app/UI/API **inside this existing Production Database repository as part of its established Work Orders subsystem** under the [System Boundary and Repository Ownership Standard](../../../../System_Documentation/Standards/System_Boundary_and_Repository_Ownership_Standard.md). Preserve the existing subsystem engineering design and README, keep governed SQL/acceptance in the project's controlled areas, and add an appropriately named application code area following accepted sibling-app conventions. Link the resulting application and its controlled preview/runtime from this subsystem README. Do not place the app inside an unrelated Setup module or create another repository.

**Operator browser scenarios / gates (test on clone, not Production):**

| Scenario | What the operator must see or prove |
| --- | --- |
| Assigned volunteer opens Work Orders | **My Work** selected by default, open assigned WOs displayed; switch to All/another Person and back; independent Show completed |
| Manager searches WO372 | Magic Igloo, all three actual assignees, not recorded complete; safe detail/back navigation and Setup WO gate link |
| Manager opens a Testing repair | Actual Test Session/Display source context; test repair notes and completed transition update the linked test only through accepted commands |
| Manager finds Intake60 | Original free-form feedback and reporter with Submitted state; no fabricated correction ownership or work completion |
| Manager asks reporter for details | Saved question, intended verified recipient, captured test-mail attempt; reporter can answer in their limited own-ticket view; owner sees answer |
| Manager closes a correction | Authorized resolution/verification note; reporter receives intended **test** closure message, while deferred/rejected reasons remain reviewable for January |
| Manager creates internal repair | No public form or fake Intake; one authoritative new Work Order, selected actual assignees, discoverable immediately; duplicate submission/retry does not make two WOs |
| Manager triages public request | Corrected Intake promoted and assigned without a second editor; original source preserved, one Work Order generated, correct notifications queued once |
| Failure, no-reporter and unauthorized paths | No data leaked, no Work Order double-created, no false success/sent status, no false completion; source stays intact and Manager sees actionable failure |
| Cutover readiness | Reviewed per-Flow event-owner/notification matrix, no duplicate producer in candidate, Testing side effects verified; no Production Flow disabled without separate approved runbook |

**Gate sequence:** (1) update this engineering contract; (2) reconcile draft #420 DB read-model/source + execute new regression checks; (3) confirm the existing in-repository Work Orders subsystem application location, exact preview allocation and runtime authority; (4) implement the **integrated** candidate with governed clone-only writes and no-send notifications; (5) run tests + disposable acceptance; (6) launch exact-candidate browser review and obtain operator feedback/acceptance; (7) document shortcomings and repeat as needed; (8) only after acceptance plan a separately authorized Production DB/application/Directus Flow/email cutover with proven rollback. **Do not call the design complete because SQL selects succeed, or the app complete because a preview screenshot exists.**

**Current STOP / next engineer start (October 18):** The existing MSB Database repository and Work Orders subsystem remain the implementation home; application PR #420 is **draft and unmerged**. [WorkOrders/Application V0.1](../../../../WorkOrders/Application/README.md) and [WorkOrders/Acceptance](../../../../WorkOrders/Acceptance/README.md) contain the source and the feature-specific Windows/Linux disposable profile. The operator's laptop tests passed **29, skipped 1, failed 0** at `8a6d55df`; the Linux GitHub Actions source-only gate **PASSED** at `8871a796` (run `39127213541`), including Bash, Python, JS and regressions. A host-file-in-Docker-psql failure was fixed and regression guarded before the next gate. **Server Management PR #80 merged as `21a631b3`**, recording **sequential localhost 8898 for #419 pre-Production browser reviews**. This does **not** establish a free listener or a running preview. **Next:** update the clean laptop #419 worktree to the exact current PR #420 SHA and run the documented feature-specific browser launcher under the existing Server Management pre-Production/clone standard; stop on an occupied port, unaudited clone, missing reviewer capability or failing SQL. No server-side clone, Flask process, actual read-model clone PASS or browser READY/CLEAN EXIT has yet been observed. Full P0 Setup correction, atomic triage/Promote & Assign, reporter clarification/replies and completed-outcome email remain unimplemented and separately required for Production approval. No Production data/service/Directus Flow was changed by these source/docs actions.

**First #419 real disposable browser attempt — HOLD, October 18, 2026:** Laptop executed exact V0.1 SHA `5bc230a84c998a61740067f74234d998f8616eae` against the governed pre-Production launcher. Its detached source tests passed **25/25**, the Production `pg_dump` and Work Order/Intake fingerprint capture succeeded, but clone `pg_restore` disconnected on a `COMMENT ON COLUMN` statement, before a browser could start. Cleanup returned HOLD (1); Production fingerprint and shared checkout were unchanged, and preview 8898 was no longer listening. Report: `/home/msbadmin/setup-acceptance-reports/WO419_Disposable_Browser_Preview_20261018T131424.txt`. Existing Server Management [PostGIS Disposable Initialization / Readiness Contract](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/PostgreSQL_Disposable_Acceptance_Standard.md#postgis-disposable-initialization--readiness-contract) identifies a **documented temporary-to-final PostgreSQL server shutdown race** when using `pg_isready` alone; the #419 runner violated this already-established rule. Clone shutdown is a supported explanation, not conclusively diagnosed from the retained report. The candidate's startup gate was corrected source-first to require Docker Running + PID1 `postgres` + `pg_isready`, with bounded disposable clone diagnostics on any subsequent restore failure and a regression guard. **Do not alter Work Order schema, Production data, Directus or operator SOP in response to this infrastructure readiness HOLD.** A Linux source CI pass is necessary but not equivalent to clone restore/browser acceptance.

### Permission, integration, and engineering sequence

- PostgreSQL owns existing Work Orders, Intake, People relationships, history and business rules. The **existing MSB Production Database repository owns both the subsystem integration contract and its new Work Management application implementation**, separated by internal source/document ownership and governed by the [System Boundary and Repository Ownership Standard](../../../../System_Documentation/Standards/System_Boundary_and_Repository_Ownership_Standard.md).
- **Work Order browsing follows the My Work / All / other-assignee selector contract above**, with server-enforced read scope and type-appropriate operational details; a volunteer may inspect other assigned work where the approved Production Crew view capability permits it, but cannot gain write/triage/assignment privileges by changing scope. The My Submitted Feedback view remains reporter-restricted and correction replies/owner actions retain separate authorization. Identity uses existing trusted Person/Cloudflare/Directus mapping, not a separate Work Management user table; email links must not reveal others' reports or permit unauthenticated updates.
- Preserve the current user-filtered Directus `work_order_assignment?bookmark=100` as a legacy entry point until an accepted equal-or-better protected `My Work` UI replaces it. Preserve #172 Task Feedback from Perform Work, #132 Report Work as separate actual-work facts, #205 scheduling/Stage progress, #209 reusable review and Testing repair completion.
- **Engineering order:** Read current Project Rules/Standards and *this design* → document new findings here → source-only read model → regression/SQL review against known cases → governed current-Production disposable clone + protected browser acceptance → develop guarded Manager internal Work Order Create; integrated Triage→Assign→Release; My Work/progress/completion; and correction assignment/questions/reporter response/verified closure → tested notification cutover → explicit Production approval and controlled deployment. Do not interpret a PR merge, static validation, browser preview or mail connectivity alone as Production acceptance.
- Current implementation checkpoint: source-only **draft PR #420** contains the governing design, read-model spike, the new [WorkOrders/Application V0.1 read-only candidate](../../../../WorkOrders/Application/README.md), checkpoint, and regression guards. The **original** read-model SELECT had DBeaver PASS; the **revised person-scope/Testing-source SELECT has not been run**. API/role security, actual browser list/detail, clone acceptance, transactional write actions, reporter notifications, in-repository application/runtime allocation and Production deployment remain **NOT DONE**. Future implementation must conform to this design, not rewrite it merely to justify code already written.

## Work Entry Paths

There are two lifecycle classes with multiple intake sources:

1. human-reported findings/requests -> Work Order Intake -> Manager triage -> active Work Order when promoted;
2. governed deterministic Test Session failure -> active Work Order directly.

### Public Work Order Request

`my.sheboyganlights.org -> Google Work Order Request Form -> attached Apps Script -> Work Order Intake -> manager triage -> active Work Order`

The public form is an intake mechanism, not the Work Order system of record. A submitted request becomes an active Work Order only after manager triage and promotion.

The form currently uses numeric Priority values 1 through 5 as an intake estimate. The manager assigns/corrects the Work Order Urgency during triage.

The attached Google Apps Script is part of this integration. Before changing question titles, answer values, branching, or form structure, inspect that script and the downstream intake mapping.

### Authenticated Setup Report Correction

During active Setup work, trusted Production Crew may submit **Report Correction** from the known annual-task/scheduled-assignment context.

The Setup application prepares and authorizes the Intake payload from PostgreSQL, then creates the item through the existing Directus Items API so the current `work_order_intake` `items.create` automation—including the Manager triage email—continues to fire. It does not create an active Work Order directly. It supplies task/Stage/Scene/season/work-day/shift/crew/Captain, current Procedure identity, authenticated reporter, and submission time automatically where known, preserving stable identities in the Intake payload and promotion-surviving notes. The reporter supplies the observation and may optionally suggest a correction.

This is intentionally different from the public form, where the reporter must supply location/context because the application does not already know it.

### Test Session Repair

A display Test Session can generate a repair Work Order automatically. That Work Order is already active and does not pass through Work Order Intake triage.

A Test Session-generated Work Order must be completed before the related container Test Session can be closed.

## Triage

Manager triage applies to human-reported Work Order Intake records, including public Work Order Requests and authenticated Setup Report Correction findings.

A human field finding may be valid evidence but still represent a misunderstanding, duplicate, wrong owner, or a correction that does not justify an active Work Order. Only Manager **Promote** creates the active Work Order.

During triage the manager validates or corrects the information required for an actionable Work Order, including as applicable:

- Stage or Work Area;
- related Display;
- Task Type;
- problem description;
- supporting notes;
- Urgency; and
- Target Year.

Current intake outcomes are **Delete**, **Submitted**, and **Promote**. Promote creates the active Work Order.

## Assignment

Managers assign active Work Orders to one or more volunteers. Assignment data must remain relational rather than a comma-separated text list.

Current production behavior includes assignment notification through Directus workflow automation. The database remains authoritative for the Work Order and assignee relationships even if the notification or UI layer changes.

## Working and Completion

The current operational sequence for an active Work Order is:

**Assign -> perform work -> add Completion Notes -> mark Complete -> save**

Completion Notes are required operational history. Completion records the completion date/time and completing person through the current database/application workflow.

For testing-generated repair Work Orders, completion feeds the repair result back to the linked testing record and preserves repair information in the testing history.

The older design's specific `repair_complete` checkbox wording is historical UI detail and is not the current operator contract. Current operator documentation uses **mark Complete**.

## Directus Role

Directus currently provides Work Order Intake triage, Work Order editing/completion interaction, user/role integration, bookmarks, and selected workflow automation.

Current Work Order-related Flows observed during the documentation audit include:

- Create Repair Work Order
- WOI Request Triage Email
- Work Order Email Assignees
- Work Order completion/update integration

Directus is an implementation layer, not the source of truth for Work Order data. A dedicated task-focused Work Order application may replace parts of the Directus user experience while continuing to use the same PostgreSQL identities, relationships, lifecycle, and business rules.

## Authority and Dependencies

### PostgreSQL owns

- Work Order identity and lifecycle
- Work Order/Display/Test Session/Stage/Work Area/Person relationships
- durable completion and audit history
- database constraints, procedures, and triggers

### Google Form and Apps Script own

- the current public request-entry experience and its submission processing before the request reaches Work Order Intake

They do not own the authoritative Work Order lifecycle.

### Directus owns

- the current general-purpose management UI and selected automation configuration

It does not own the authoritative Work Order data model.

## Authoritative Sources

Before changing this subsystem, inspect:

- current PostgreSQL Work Order tables, constraints, procedures, and triggers;
- current production Directus Work Order Flows;
- current public Google Form and attached Apps Script when intake behavior is involved;
- current Work Order operational SOPs.

## Related Documents

- [Work Orders engineering handoff](README.md)
- [Testing System](../05_Testing_System/README.md)
- [Work Order Operational SOPs](../../02_Operational_SOPs/Work_Orders/README.md)


### Setup Report Correction notification boundary

The existing Manager notification is not a PostgreSQL trigger. Production Directus owns an active Flow named `WOI Request Triage Email` with an `items.create` event trigger on `work_order_intake`.

Accordingly, Setup Report Correction must not directly insert the Intake row and then implement a second email path. PostgreSQL remains responsible for authenticated Setup authorization and authoritative schedule/task/context derivation; the protected Setup backend submits the prepared Intake item through Directus. Directus remains responsible for the existing create-event automation.

The Setup runtime credential for this call is configuration, not source code. It must be stored outside Git and must belong to a Directus identity limited to the Work Order Intake creation capability needed by this workflow.


Runtime configuration for the Setup-to-Directus create boundary:

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
