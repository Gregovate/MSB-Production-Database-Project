# MSB Work Management — Phase 1 release preparation

## Current checkpoint — V1.0.1-production-route, October 20

Operator accepted Phase 1 business workflows and authorized release. Not installed.
PR #420 reconciled main a770e755 at bad1b591; the six missing governance commits
are retained. Prior dated review states below are historical, not current approval.

The permanent public mount is /workorder/. Production WSGI validates actual
Synology socket peer 192.168.5.4, exact public Host and forwarded HTTPS before
serving the application. Client forwarding headers cannot grant peer trust.
All assets and API calls stay beneath the mount; same-origin CSRF remains active.
Preview behavior remains loopback-only. See the [owning design](../../Docs/02_Production_Database/01_System_Architecture/06_Work_Orders/Work_Order_System_Design.md#october-20--phase-1-permanent-route-deployment-contract-81).

Local fake-repository app/read-model tests: 86 PASS. Acceptance-profile tests:
17 PASS; one existing process-cleanup test cannot complete here because netlink
access is prohibited. CI on Linux remains required; this is not live acceptance.
SQL/business commands and Phase 1 Directus mail ownership are unchanged.
Server Management #81 owns allocation, independent pinned checkout, service,
protected environment, database window, external identity verification and cutover.
No root /api route or new local proxy daemon is required.

## Historical source and review checkpoints

**Status: DRAFT PR #420 / V0.3.2 SOURCE CANDIDATE; new disposable functional browser acceptance pending.** The previous Manager disposable browser ran and ended workstation tunnel CLEAN EXIT, but the operator reported CHANGES REQUIRED for navigation, work/complete, assignment, Create, planning ideas and readability. No Production deployment or notifications.

## V1 engineering checkpoint — governed native command path (source candidate, not deployed)

Following Tom's live workflow corrections, engineering has begun the **actual Production path** on the **existing #419 draft PR #420**, not a new ticket system. Three source artifacts are now present:

- `WorkOrders/Database/001_work_management_v1_governed_commands.sql` — proposed *source-only* native PostgreSQL contract, to be tested **first on the current-Production disposable clone**. Uses existing `ops.work_order`, `ops.work_order_assignment` and `stage.work_order_intake` (no second ticket authority). Additional `ops.work_management_activity` and `ops.work_management_outbox` tables provide durable action/idempotency provenance and notification **intent**. Directus alone supplies users, roles and policies; no Work Management permission table is created. SECURITY DEFINER functions perform verified Create, Promote, Assign, Progress, Complete and correction follow-up; no direct `INSERT/UPDATE/DELETE` grant on native WOs to the browser's dedicated `work_management_app` role. The role must be created through the server runbook; **no separate Manager grants exist**. No mail sender is installed.
- `WorkOrders/Application/v1_runtime.py` — disabled-by-default Production native adapter. Requires explicit runtime mode, separate `WORK_MGMT_PRODUCTION_DSN` and a reviewed release-write gate; verifies `current_database() = msb` and `session_user = work_management_app`, and re-resolves the active Person/approved Work Order role before sending command requests to native SQL. Existing `repository.py` uses `wo419_preview.activity` during disposable review and `ops.work_management_activity` in V1 only, preserving unified Intake/Feedback queues.
- `WorkOrders/Application/production_entry.py` — **WSGI only**: refuses startup without registered protected loopback reverse-proxy/Cloudflare identity approval, native write-release gate and a private command secret. Does not choose a Production port, touch services or launch Flask automatically. Existing `backend.py` selects the runtime explicitly and requires same-origin CSRF and an additional custom command header. UI labels distinguish disposable changes from permanent Production changes and never claim notification delivery.

**Unchanged:** existing disposable preview runner/port **8898**, native Testing Work Order triggers, Work Order and Intake IDs, Google Form/Apps Script public submission, Directus business Flows, Production data and actual operator/Manager roles. The live reviewer still has to accept Manager and Crew behavior. The new SQL has **not** been executed on a current-Production clone, and its compatibility with exact current Work Order columns/triggers/assignments is **not yet established**. Green GitHub tests mean static/source and local unit acceptance only.

**Explicit release blockers before calling this V1 deployable:** (1) disposable current-Production SQL migration/schema/trigger validation with rollback/no-send and manager/crew negative access; (2) review exact dedicated database role creation and current Directus Manager/Crew authorization (Randy's current privileges are **not** changed); (3) govern durable Intake status closure vs current Directus triage and ensure feedback/WO completion sends exactly one approved reporter notification later—current `PENDING_CUTOVER` outbox is not mail; (4) Server Management assigns/reviews **Production WSGI service/proxy route/port**, final secret handling, access headers, health and rollback (do not borrow 8898); (5) functional disposable/browser acceptance of actual action saves and **clean automatic teardown without manual 8898 cleanup**; (6) operator authorization to merge, controlled DB maintenance/snapshot/deploy and *separate* mail/Flow cutover.

**RUNBOOK GAP FOUND (implementation, not authority bypass):** Server Management's existing Work Orders allocation is for a sequential **disposable browser review** on 8898. No approved **permanent Work Orders Production service/proxy/port** contract has been established in this issue; this must be defined in the owning `Gregovate/MSB-Server-Management` runbook before a deploy command is prepared. No imagined port, competing runner, broad database privileges or automatic Google/Directus Flow changes are acceptable.

---
## V1 launch scope and release gates — agreed direction after Tom's October 19 review

**Goal:** Put the **existing** PostgreSQL Work Orders, Testing repairs, existing Google Park/Workshop Intake, Manager triage and Crew completion into one usable protected Work Management application. This is **not** a new Work Order store or a competing Directus workflow. Production installation/release has NOT been authorized by passing disposable tests; it requires the separate Server Management deployment gate and operator acceptance. Existing Directus/Testing and public Intake must remain functional until the governed cutover.

### V1 minimum operating contract

| Operational capability | Tom/operator decision | Source status / required acceptance |
| --- | --- | --- |
| Volunteer requests | Anyone, including non-Manager Crew, uses existing Park/Workshop [Work Order Request](https://forms.gle/Gve4ZbXHDWxs43yh6); always enters current `stage.work_order_intake` | Link and native Create denial coded; **verify actual Google Form → Apps Script → Intake** before cutover; don't invent parallel Intake |
| Triage | Manager investigates Public Intake, asks for clarification, approves/promotes/assigns or closes/rejects with audit | Disposable workflow candidate exists; verify real existing Intake status semantics, mapping and persistence |
| Manager Create | Manager may create an approved native Work Order directly, no Intake required | Source authorization checks; actual click → complete form → save still needs browser acceptance |
| Assignment | Multi-person Person-based Assign/Reassign at promotion or after approved native WO creation; no assignments/target year on Intake | Existing normalized `ops.work_order_assignment` and historical audit remain authoritative |
| Urgency and Planning | New approved Work Order default urgency 3; only urgency 5 Planning gets required target year | Source coded; confirm no non-Planning year leaks and public request priority is merely suggested |
| Crew execution | Assigned Crew can Add Work Note and Complete with substantive actual-work notes, verified completer and server-side time; Manager retains authorized correction | Candidate clone writes only. Reconcile WO-372/402/107/147/400/416 examples, testing dependencies and existing completion triggers; **do not pre-close Production** |
| Testing repairs | Dedicated Manager Testing queue and automatically created repair WOs continue existing Production testing process | Must exercise real test-origin WO on disposable current-Production clone; preserve testing closure prerequisites |
| Feedback | Task Feedback correction/clarification/disposition separate from public request triage | Existing preview clone-only activity; govern durable Production activity/notifications before release |
| Work queues | My Work, Manager urgency/routine/Testing/unassigned/Intake/Feedback, filter/search, planning visibility, numeric sorting, full aging report | Source present; operator visual + functional review still CHANGES REQUIRED |
| Reference/location maintenance | Rack assignment and storage-reference corrections **#230**, movement events **#88** | No forced Work Order for container C213/rack RD04-B-03; do not build competing location editor |
| Public portal | Button text **Submit Work Order Request**, not direct WO creation | Source-only in owning [MSB Internal Web Backbone draft PR #26](https://github.com/Gregovate/MSB-Internal-Web-Backbone/pull/26); separately publish with approval |
| Roles | Manager-only native create/triage/assign; Crew work assigned, submit requests; avoid personal flags as grants | Current app infers `can_manage` from existing Setup capabilities; **Directus remains the sole role/policy authority**. Named person's permissions not changed |

### V1 release blockers (must close, in this order)

1. **Runtime and identity:** Work Orders currently has only `preview_entry.py`, a localhost temporary app identity injected by the disposable launcher. Build the **protected Production routing/Cloudflare Access → verified Person identity** using existing server/application patterns, with separate intended permission for Work Order Manager versus ordinary Crew; no browser/client-provided identity, and no alteration of global Setup Manager role as a shortcut.
2. **Production persistence authority:** `WorkOrders/Application/repository.py` requires `WORK_MGMT_PREVIEW_MODE=disposable`, and `commands.py` requires clone token and clone-only `wo419_preview` schema. These are **deliberately not Production-safe**. Before any release, design/review **existing native ops.work_order + ops.work_order_assignment writes** behind least-privilege SQL/database commands or an approved server API, with durable actor/assignment/completion/activity provenance. Use the existing PostgreSQL authority, existing Directus/Testing triggers and governed migrations; never run `wo419_disposable_actions.sql` or `wo419_preview_clone_read_grants.sql` against Production.
3. **Manager triage + reliable notification:** Current preview only records **NO_SEND** in an isolated clone. V1 needs exactly one approved notification path for new public Intake, clarification, approved assignments and completion. Reconcile existing Google Apps Script / Directus `items.create` flows, avoid duplicate mail and preserve no-send during disposable tests. **No Production Flow cutover/mail activation before explicit authorization.**
4. **Release preflight and functional acceptance:** Run full Setup/FieldWiring/Work Orders suites; current-Production **disposable** database migration/write/trigger/role tests; real interactive protected Manager + distinct Crew browser sessions; record screenshots/evidence and operator verdict. Must prove Create, Intake→triage→promotion, assignment/reassignment, notes/completion, Testing, feedback, priority/year, full aging, Browser Back, and exact-source no-send. Current browser verdict is **CHANGES REQUIRED**.
5. **Lifecycle/cleanup:** Existing #419 runner at `WorkOrders/Acceptance/work_management_disposable_browser_preview_server.sh` has now been source-corrected for `setsid` PID mismatch. Test that the actual server returns `WO419 DISPOSABLE BROWSER REVIEW: CLEAN EXIT`, with listener off 8898, disposable DB/worktree/state gone and unchanged Production fingerprint. **Local CI success is not evidence of this live server condition**. No recurring manual cleanup.
6. **Deployment/rollback and acceptance:** After the operator accepts exact candidate, follow the owning [MSB-Server-Management Production Deployment Runbook](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/server/Production_Database_Change_Deployment_Runbook.md). Retain pre-change snapshots, migrations/grants review, route/service manifest, no-regression Production checks, health/role verification, rollback and operations SOP updates. Production merge, deployment, and Flow/email cutover are **separate explicit approvals**. Never switch shared `main` or Production Work Order data during reconnaissance.

### V1 first-day operational verification

An authorized Manager can see pending Intake, identify what must be investigated, promote and assign one existing Person; Crew can see only their authorized work, record actual progress and Complete with notes; the native Work Order appears in Manager queues/aging with correct status and assigned people; Testing remains usable; public form creates Intake and sends Manager notification through the **single approved current flow**; no stale duplicate WOs or unauthorized changes. After controlled publication, use WO-372, WO-402, WO-400, WO-107, WO-147, WO-389 and WO-416 as individually verified case reviews—not automatic Production data corrections.

**Honest current readiness:** Draft PR #420 implements the candidate UI plus clone-only workflows and corrected SSH teardown source, but **cannot be marked V1 deployable today** until the six release blockers above are resolved. Progress belongs to this PR and owning repository engineering documents; don't open a competing work-order subsystem or runner.

---
## V0.3.2 — next test is the *actual operator workflow*

The next source candidate corrects the latest operator-rejected Manager preview in the same application and PR. Read the [governing Work Order design](../../Docs/02_Production_Database/01_System_Architecture/06_Work_Orders/Work_Order_System_Design.md#october-19--work-management-disposable-operator-browser-acceptance-changes-required) and [acceptance checklist](../Acceptance/README.md#october-19--manager-disposable-browser-review-changes-required-source-candidate-underway) before changes.

- **Assigned Work Order:** direct **Add Work Note** and **Complete Work Order** action buttons appear at top of ticket detail, above original descriptions. Notes and completion are genuine isolated-clone writes; substantive work notes required. Server owns verified Person completion identity/date and preserves Testing source behavior. The Manager-only **Assign / Reassign** button is deliberately separate in the heading, not a Crew work dropdown.
- **Create:** one top **+ Create Work Order** click reveals the actual blank native entry form without an additional selection step or previous ticket data. Crew creation does not silently assign anyone; Manager can dispatch via the existing normalized assignment model.
- **Navigation:** built-in Back to Work Order list and browser Back/Forward restore in-app scope, ticket, search, sort, Show completed, planning flag and list scroll. Does not navigate into another browser application simply for viewing a ticket.
- **Planning:** important long-term WOs such as WO-105 are not deleted or automatically assigned. The existing **Priority 5 = Planning** category supports a reversible **Show planning work (Priority 5)** boolean filter, default off. It applies to every authorized list **and Manager aging report**, before normal list LIMIT, while leaving NULL priorities visible. Toggle on to recover full original entries; no Production classification migration has been authorized.
- **Sorting:** clear Most urgent (1→5) / Least urgent (5→1), numeric WO/Intake number and creation dates instead of cryptic Critical/Planning first. The common light/dark palette follows existing [#159](https://github.com/Gregovate/MSB-Production-Database-Project/issues/159), and semantic business meaning follows [#140](https://github.com/Gregovate/MSB-Production-Database-Project/issues/140); the new text defaults target 15–17px rather than a browser-level zoom workaround.

**Preserved:** Original public Google Form, Manager Intake banner, complete native Work Order aging report/CSV and inactivity exceptions (all open remains accessible with planning toggle on), authentic Testing repair source, annual Setup link, normalized people relationships, clone-only no-send notifications, strict CSRF and Docker-private clone guards. Existing physical reports WO-402 completed and WO-105 future proposal are **operator observations only** and do not authorize live data correction.

**Next gate:** Source CI, one fresh current-Production disposable clone through the **existing** server runner/registered 8898 port, Manager and real Crew browser tests, persisted disposable Work Note/Complete/Create/Assign, browser Back/Forward and planning toggles, no-send and server-clean exit/fingerprint. Keep PR draft until acceptance.

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

## October 19 — native season-only Setup integration (candidate, not accepted)

- **Purpose:** Park repair Work Orders created during Setup can also create a linked **season-only** Setup obligation without a second screen, using existing `ops.create_setup_season_task` and `ops.setup_session_task.linked_work_order_id`. This does not create `ref.setup_task` or duplicate work-completion reporting.
- **Crew:** direct Create may flag **Setup review requested**. That request stays on the Work Order's attributed candidate activity; Crew cannot run Manager Setup commands.
- **Manager:** at Create/Intake Promote, choose **Create linked Setup task now**, a real open Setup season, and Stage; native WO + annual `GATE` are one PostgreSQL transaction. Alternatively choose **Add this Work Order to seasonal Setup** on an existing Stage WO created by Crew. The latter creates no duplicate Work Order.
- **Authority:** Setup's existing Manager command checks the authenticated Directus identity, season and Stage; Work Management requires Manager role and clone write marker. Board status is already `WAITING_ON_WORK_ORDER` until native WO is marked complete, then effectively `COMPLETE`. Planned dates, crews and annual Report Work remain solely Setup-owned.
- **Tests:** new source contracts and a rollback-only connected current-Production disposable clone test for season-only identity and WO linkage. Browser acceptance still pending. Non-Setup WOs are unchanged; never auto-create annual tasks from free text or Stage inference.
- **2027 takedown:** [#423](https://github.com/Gregovate/MSB-Production-Database-Project/issues/423) is a distinct #122 container-first release due before January 1, 2027. It may send actual repair findings into Work Management, but must use #88 movement, #230 Container/storage and #231 Testing authority.

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



## V1.0.2 Directus role correction — not deployed

Native SQL and browser reads use current Directus-backed capabilities on every
operation. No separate Manager approval table or named grants. Role revocation
and inactive users are covered by isolated-clone acceptance. Existing staged
V1.0.1 is superseded. Cloudflare Access authenticates the Google
@sheboyganlights.org account; Directus owns users, roles and policies. Preserve
the existing protected identity-header boundary; no second login is introduced.


## V1.0.3 signed Access identity — candidate, not deployed

Production now requires WORK_MGMT_ACCESS_ISSUER and WORK_MGMT_ACCESS_AUDIENCE
and verifies Cf-Access-Jwt-Assertion before all routes. A supplied email alone
cannot authenticate. Signed identity still requires current Directus authorization;
roles, native SQL and Phase 1 email behavior are unchanged. See the October 20
signed identity section in the owning Work Order System Design.

Install requirements-auth.txt only into the independent Work Management runtime
under the Server Management #81 procedure. Do not pip-upgrade the shared runtime.
Source regression uses generated local RSA keys and fake JWKS; no real tokens,
Cloudflare session changes or Production contact. Real protected-route acceptance
and service installation remain pending. Completed database provisioning is not
repeated for this application-only correction.
