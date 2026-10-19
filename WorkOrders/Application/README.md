# MSB Work Management — V0.3 disposable-save browser candidate

**Status: DRAFT PR #420 / V0.3 SOURCE TESTING; disposable clone-write and new browser acceptance pending.** V0.2 was operator-reviewed as CHANGES REQUIRED. Not deployed.

## Governing authority

This application belongs to the **existing Work Orders subsystem** of Gregovate/MSB-Production-Database-Project. Its governing engineering design is:

[Work Order System Design](../../Docs/02_Production_Database/01_System_Architecture/06_Work_Orders/Work_Order_System_Design.md)

The design and released [Work Order SOPs](../../Docs/02_Production_Database/02_Operational_SOPs/Work_Orders/README.md) already establish the database identities, intake, triage, assignment, repair and completion semantics. Do not create a separate GitHub repository or master ticket database.


## October 18 continuation — post-review CHANGES REQUIRED (source-only slice)

The operator's first actual read-only disposable browser review returned **CHANGES REQUIRED**, not accepted. This supersedes earlier README language that the browser had never been reviewed; the October 18 browser finding is preserved in the governing design. The subsequent clone restore readiness HOLD is separately documented in PR #420 and does not erase the first review.

**This continuation implements only an incremental UI/read-path correction:**
- The existing unified SQL ledger and native Work Order, Intake and Testing identities remain unchanged.
- Manager-only server-authorized filtered views: active/general Work Order repairs, Testing-origin repairs, public Work Order Intake triage, and Setup Task Feedback. Testing repairs remain the same authoritative Work Orders and never become fake Intake requests.
- Backend SQL orders incomplete Work Orders first, by authoritative urgency ID ascending (1 critical, 2 high, 3 normal, 4 low, 5 planning), before recent activity and before the 80-row limit. Unrecorded urgency sorts last. The UI still labels actual recorded completion only; assignment does not assert notification or acknowledgment. This is a first read-only queue, not the full overdue/unassigned dispatch workflow.
- An accessible header light/dark theme switch for this candidate. Visual styling is an original MSB Work Management theme; no claim of compliance with a separately approved brand asset or theme library is made.

**New test coverage:** Manager scope gates, queue routing and SQL urgency-sort source assertions in `test_work_management_preview.py`. CI results and clone/database/browser behavior must be recorded only after actually observed.

**NOT YET IMPLEMENTED:** Manager direct Create; atomic Intake Promote & multi-person Assign; reassignment history/notification; authenticated completion with required notes and Testing feedback; correction owner, clarification, response, disposition/closure; no-send durable mail/audit; search/urgency/overdue pagination and full operational backlog handling. The public Park/Workshop Google Form and attached Apps Script are not changed. No Production Work Order or Intake cleanup is approved, including WO-372/400/107/147/389/416. Existing Directus Flows and Setup/Testing are untouched.

**Next gated work:** Establish reviewed schema/command authorization on current-Production disposable PostgreSQL; implement transaction-safe write routes with actor/role checks and no-send notification outbox; add browser functional tests; execute current full source regression and guarded server clone/8898 review, recording fingerprint and clean exit. Remain on draft PR #420. Never deploy or cut over without separate authorization.

## October 19 — all-open Work Order aging report (Manager)

The operator additionally requires an **aging report for every open Work Order by original creation date**. This is now source-implemented in the same WorkOrders/Application browser and PostgreSQL WO419-M01 projection; no competing reporter system or migration. For this report, "open" means `ops.work_order.date_completed IS NULL`, even if the record is inactive and needs reconciliation. Last-update timestamp, assignment date, or absent status events are **not** age-start dates.

The Manager's explicit **Open Work Order Aging Report** view shows numeric Work Order ID, original creation date, full 24-hour days open, priority, problem/location, active assignees and inactive exceptions. By default it is **oldest created first**, with newest-created, highest/lowest priority and numeric-ID sorts available. It includes **all recorded-open rows**, not just the normal Work Order list's first 80, and offers a complete guarded CSV export with spreadsheet-injection escaping. Counters group 0–7, 8–30, 31–60, 61+ day ages, plus unassigned and inactive-but-undated exceptions. Clicking a row opens its existing Work Order detail. It does not change any Work Order records.

Backend `GET /api/work-orders/aging` strictly requires Manager authorization. The Crew browser does not expose the view. The current-Production disposable validator compares the full aging-result count and inactive-exception count against native `ops.work_order` and checks created-date sort order before browser READY; negative Crew access is tested. No Production database was mutated and no mail was sent. Source CI and actual disposable browser acceptance are distinct gates.

## October 19 V0.3.1 — Role-oriented home and sortable queues

**Operator directive:** Separate Production Crew and Manager screens/actions, not just a shared dropdown. Public Google Work Order Request remains at the existing MSB portal for any reporter, using current Park/Workshop Google Form and Apps Script. Internal authenticated Production Crew may also create **direct native Work Orders** without Intake. Manager controls current Work Order assignments and public Intake triage.

**Crew landing:** My Assigned Work Orders defaults to exact current Person assignments and actual non-complete status; independent Show completed; Work Orders I Created for directly submitted, as-yet-unassigned native WOs; My Submitted Feedback to see original findings; top Create Work Order; an existing public form link. Crew Create records actual linked creator/reporter and starts without an assignment. Crew can Complete only assigned WOs, with substantive completion notes. Crew cannot see Manager Intake counts, Manager queue selectors, assignment controls, or triage commands; these are blocked by backend, not only by hidden HTML.

**Manager landing:** Distinct All Work Orders (native WO only), All Tickets unified search, Create, Manager-only multi-person Assign/Reassign, public Park/Workshop Intake triage, separate Feedback corrections, Testing repairs and urgent/unassigned queues. On home load the API evaluates **unpromoted public Intake** and **unresolved Task Feedback** counts with Manager-only access; a visible clickable banner appears when either count is nonzero. Promoted original Intake stays preserved but is not counted as awaiting triage, and resolved feedback does not remain in the actionable queue.

**Sorting:** Every authorized view uses the same select: Priority Critical-first or Planning-first, Work Order/Intake number lowest-first or highest-first. Query ORDER BY is selected only from four fixed server-side expressions using native numeric IDs and existing `urgency`, **before LIMIT**. On unpromoted public Intake urgency is only the original reporter estimate, subject to Manager review; no new priority schema or Work Order identity was introduced.

**Authorization model:** Preview reuses the current protected Setup browse/Manager capability as an interim Work Management role gate, with exact active linked `ref.person`, with direct Create requiring an actual Directus Production Crew/Manager/Administrator role or equivalent policy; generic Volunteer and Browser cannot create internally. Public form access does not confer internal create or assignment permission. This is a **pre-Production** contract pending a specific Work Order permission review. All write tests remain on the isolated disposable clone and notifications remain NO_SEND; no Production / Directus / public form change.

**Acceptance:** Test Manager and Production Crew **as distinct approved reviewer sessions** through the existing sequential 8898 disposable profile, each with an isolated new clone; verify the Crew Create → unassigned → personal Created view, Manager pending Intake banner and eventual Manager assignment, Crew assigned-note completion, priority/numeric number sorts in every scope, and manager-only API denial for Crew. Never infer Production role cutover from source-only tests.

## October 19 V0.3 — disposable SAVE review candidate (not browser accepted)

**Decision superseding V0.2 no-save:** Greg requires actual saves in the current-Production disposable clone, no notifications, and ticket actions **within the selected detail** rather than at the bottom. Work Management must reuse the exact existing MSB Setup logo and light/dark themes (source authority: Setup/Application/setup_theme.js and setup.css). The first V0.2 operator review remains **CHANGES REQUIRED**.

**Implemented source:** Top-bar Manager New Work Order; embedded ticket-detail actions for Create, multi-person Assign/Reassign, authenticated required-note Complete, Intake Promote & Assign, correction ownership/clarification/reply/verified disposition; original Setup MSB SVG logos, palette and msb-theme shared preference; clone-only event/activity display. Native Work Order/assignment DML is bounded by verified Person and Manager permissions, exact private clone IP/database, separate server-generated 48-character write-token plus CSRF secret, and transactional idempotent action UUID. Existing Intake is preserved on promotion (no destructive triage trigger). No new Production master ticket table.

**Isolation:** ONLY the established #419 Server Management disposable runner installs WorkOrders/Acceptance/wo419_disposable_actions.sql on the private clone with a session approval marker. It creates clone-only attributed wo419_preview.activity and NO_SEND outbox. There is no email transport, Directus Flow invocation, live service restart, Production mutation or Flow cutover. Each preview write disappears at cleanup.

**Browser READY gate:** Full Setup/FieldWiring/#419 source tests; PostGIS final PID1 readiness; current-Production pg_dump/private restore and original read ledger; authorized reviewer/Manager catalog; clone-only native Create/Assign/Complete preflight inside a rolled-back savepoint; CSRF negative route; verified localhost listener. Any schema/actor/assignment/trigger failure is HOLD, not acceptance. Full actual Testing writeback/notification equivalence still requires a documented disposable browser test.

**Known review targets (no Production cleanup authorized):** WO-372, WO-400, WO-107, WO-147, WO-389 (#230 dependency), WO-416, Testing repairs, Intake-60/40/57. Operator acceptance and a server CLEAN EXIT with unchanged fingerprints are still pending on the new SHA.

## October 18 V0.2 — new UX/browser review candidate (NOT P0 functional acceptance)

**Disposition remains CHANGES REQUIRED.** The existing first browser review proved the V0.1 read-only shell but exposed lack of operational Manager, Testing, urgency and feedback workflows. This source-only continuation is a **second disposable browser candidate** for reviewing the proposed UX, not a claim of live Write acceptance. It stays on draft PR #420 and uses the same Server Management 8898 sequential profile, same PostgreSQL ledger, same Work Order/Intake identities, and same standalone preview process. It **does not** introduce a ticket database, competing application, mail transport or runner.

**Available in the V0.2 browser:**
- Distinct Manager views: Immediate/Critical, Unassigned, General Work Orders/park repair, Testing repairs, public Park/Workshop Intake triage, Setup Task Feedback. Volunteer view: My Work, All/another Person, and My Submitted Feedback. Incomplete Work Orders sort by existing urgency IDs 1 through 5 **in SQL before the result limit**; there is no claim that incomplete means physically unperformed.
- Search works with existing ticket aliases including `WO372`/`WO-372` and `Intake60`/`INTAKE-60`, human description, location, owner, reporter, state and source.
- Manager catalog endpoint reads actual active Person, Task Type, Stage and Work Area choices from the **isolated clone only**, without email/Directus token exposure. Clone validation now fails closed if those catalogs cannot be read. This is not a new editing grant.
- **No-save operator action rehearsal** offers direct Manager Create, multiple exact-Person Assign/Reassign, required-note Complete, public Intake Promote & Assign, and Feedback choose owner/request clarification/verified disposition. The forms enforce required description, a genuine Task Type and exactly one Stage or Work Area, catalog urgency, assignee(s) where required and substantive completion/question/disposition notes. The selected Work Order's source details remain in view. These forms create an explicit validation message **but do not POST, commit database state, send email or claim that a Testing repair was closed**.
- CSS light/dark theme toggle and consistent styling for the review workbench. This is a candidate MSB presentation, not a claim that the final approved image/logo assets were identified or installed.

**Provenance examples to inspect:** WO-372 physically reportedly welded but database open; WO-400 reassignment to exact verified Adam; WO-107 and WO-147 reported physically finished; WO-389 #230 dependency deferred to Dec/Jan; WO-416 Light Pole 8 damaged outlet critical punch-list; current Testing-created repair WOs; original retained public INTAKE-40/57 and Setup Task Feedback INTAKE-60. Do not mutate these Production records as part of browser review. If a record is no longer present, do not fabricate it or treat a historical count as fresh Production truth.

**Still P0 blockers:** Real authenticated/create, transactional multi-person assignment with history and notification accountability, authoritative completion and Testing writeback, atomic Intake Promote & Assign preserving source evidence, correction owner/disposition persistence, reporter clarification/reply/closure and audited no-send outbox with deterministic recipient and idempotence. Inspect actual current schema, audit actor trigger, Directus operations, public Google Form Apps Script and Server Management mail path before producing these write commands. Prototype validation is not the same as functional transaction acceptance. Production records, public forms, Directus bookmark #100 and all Flows remain unchanged. No Production deployment/Flow cutover is authorized.

**Acceptance gate:** After CI passes, execute the exact-SHA existing Windows wrapper; the server runner must pass full Setup/FieldWiring/#419 regression, current Production dump/isolated PostGIS clone restore, current source ledger query, identity/Manager catalog preflight and protected localhost browser READY before review. Operator reviews layout, role gates, routing, form validation and no-save truth, then the runner must report CLEAN EXIT and unchanged Production fingerprint. **Do not label V0.2 as full P0 accepted even if the UX looks correct.**

## Currently implemented source

- Protected, **read-only** Flask ticket browser backed by the existing WO419-M01 database-owned SQL projection.
- **My Work** first, with optional All and another actual Person, searchable tickets and independent Show completed.
- Native Work Order and Intake detail views; human original problem, owner, source and saved Setup context.
- **Related Information** is collapsed by default and fetched only on expansion. It uses existing Setup relationships to suggest directly assigned task containers, Stage-related Kit Boxes and Containers, Stage Displays, Setup materials and submitted Procedure document context. Distinguishes direct task links, Stage candidates and original submitted context; Stage candidates are not automatic task assignments.
- No POST, PATCH, DELETE or email actions; no Directus Flow changes.

Source files: backend.py (protected Flask app), repository.py (existing-schema readers), index.html, app.js, app.css (operator screen), test_work_management_preview.py (isolated source/API tests).

Protected GET endpoints: /work-orders/, /api/work-orders/access, /api/work-orders/assignees, /api/work-orders/tickets, /api/work-orders/tickets/<ticket-key> and /api/work-orders/tickets/<ticket-key>/related-information.

## Explicitly NOT yet implemented or accepted

The **mandatory P0** Work Management workflows remain: correction ownership and verified outcome; original reporter Request More Information email and same-ticket reply; reporter closure/completion email; **one atomic Triage → Promote & Assign**; direct Manager Work Order creation; permission-authorized progress/completion; Testing write feedback; durable confirmed correction references; complete Stage/Procedure context resolution; and noncompeting Directus Flow cutover. Do not call this a completed application.

## Disposable-only safety

The accepted [Server Management Pre-Production Browser Review Runbook](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Pre_Production_Browser_Review_Runbook.md) controls port allocation, clone isolation, protected operator identity, exact app SHA and cleanup. **No Work Management preview port has been allocated.** Do not borrow Setup's 8898 port or deploy/restart a live service.

The candidate requires WORK_MGMT_PREVIEW_MODE=disposable and WORK_MGMT_DATABASE_DSN. It refuses the known live PostgreSQL database name msb and makes all database connections read-only. This does not substitute for the governed clone/proxy/secret verification in the launcher: a differently named live database is not automatically a safe disposable clone.

The protected Cloudflare Access email header must come only from the trusted perimeter. The candidate also checks the existing Directus-backed Setup browse capability and exact active linked Person identity. Final Work Order-specific read permissions remain an acceptance item. There is no outgoing email transport or mutation route in this slice.

## Prepared disposable review profile (not executed)

The Work Orders subsystem now contains [WorkOrders/Acceptance](../Acceptance/README.md) with a feature-owned clone-only SQL/grants validator, source-only Bash/PostGIS/Flask profile runner, an exact-SHA Windows SSH launcher, negative-identity/write assertions and clean-exit procedures. This follows the existing MSB Server Management current-Production disposable standard rather than changing or reusing the hard-coded Setup runner.

[Server Management PR #80](https://github.com/Gregovate/MSB-Server-Management/pull/80) **merged** and authorized explicitly **sequential pre-Production #419 reviews** on the existing localhost 8898 profile. The exact clone/source runner has **not been executed on the server**, the listener has not been checked, and no BROWSER REVIEW READY output exists. The feature-owned acceptance launcher may now be run by the operator from the clean laptop #419 worktree with an exact pinned SHA and selected existing MSB reviewer, subject to all runtime/port/clone safety gates; it must stop on a conflicting 8898 listener. The Linux GitHub Actions source-only gate passed at commit `8871a796` (run 39127213541); that is not a browser acceptance. Production remains unchanged.

## Next validation and handoff

Run Python/JavaScript source tests and the amended ledger SQL against the approved current-Production clone. Inspect actual My Work/All/person scope, Intake #60/#40/#57, WO372, Testing repairs, no-Person/unauthorized paths, and the collapsed Related Information panel for tasks with and without direct Kit assignments. Correct any discovered SQL or navigation drift before operator browser acceptance. **No executable test or browser PASS is asserted from this source-only commit.**

After the initial browser shell is reviewed, implement and test **all P0 actions** against clone-only commands and captured no-send email, without touching Production or disabling any current Directus Flow. Record source SHA, actual validation evidence and resume point in this application README and governing subsystem design.
