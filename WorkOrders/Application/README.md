# MSB Work Management — V0.1 read-only disposable candidate

**Status: SOURCE-ONLY.** Draft PR #420, unmerged, not executed on a disposable PostgreSQL clone, and not browser-accepted or deployed.

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
