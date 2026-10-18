# MSB Work Management — V0.1 read-only disposable candidate

**Status: SOURCE-ONLY.** Draft PR #420, unmerged, not executed on a disposable PostgreSQL clone, and not browser-accepted or deployed.

## Governing authority

This application belongs to the **existing Work Orders subsystem** of Gregovate/MSB-Production-Database-Project. Its governing engineering design is:

[Work Order System Design](../../Docs/02_Production_Database/01_System_Architecture/06_Work_Orders/Work_Order_System_Design.md)

The design and released [Work Order SOPs](../../Docs/02_Production_Database/02_Operational_SOPs/Work_Orders/README.md) already establish the database identities, intake, triage, assignment, repair and completion semantics. Do not create a separate GitHub repository or master ticket database.

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

## Next validation and handoff

Run Python/JavaScript source tests and the amended ledger SQL against the approved current-Production clone. Inspect actual My Work/All/person scope, Intake #60/#40/#57, WO372, Testing repairs, no-Person/unauthorized paths, and the collapsed Related Information panel for tasks with and without direct Kit assignments. Correct any discovered SQL or navigation drift before operator browser acceptance. **No executable test or browser PASS is asserted from this source-only commit.**

After the initial browser shell is reviewed, implement and test **all P0 actions** against clone-only commands and captured no-send email, without touching Production or disabling any current Directus Flow. Record source SHA, actual validation evidence and resume point in this application README and governing subsystem design.
