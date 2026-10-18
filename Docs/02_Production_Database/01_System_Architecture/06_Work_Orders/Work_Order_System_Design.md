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

## #419 — Unified MSB Work Management Application Contract (October 18, 2026)

**Engineering authority and status:** This section records the agreed operating model and the **verified current Production findings** for [#419](https://github.com/Gregovate/MSB-Production-Database-Project/issues/419). It governs application implementation and regression acceptance; GitHub issues track the work and PRs implement it. **New Work Management screens, correction ownership/replies, and reporter notification workflows are NOT deployed merely because this design or a candidate SQL query is committed.** The earlier production Work Order and Intake data models remain authoritative.

### Product boundary — one operator experience, two distinct lifecycles

The next major application after the accepted Setup Scheduling Board work is **MSB Work Management**, a single, ticket-style interface for existing Work Orders and Task Feedback. A volunteer or Manager should not need to navigate raw Directus collections or change personalized bookmark filters to learn what was reported, assigned, done, or still outstanding.

- **One searchable Inbox / All Tickets, My Work, My Submitted Feedback, and Manager follow-up** with common detail presentation (human description, original source/reporter, Stage or Work Area, owners, evidence, time, next action, outcome, history). Provide direct, authorized links into the owning Setup task/Stage, Work Order, Testing or Procedure.
- **One UI does not create a new authoritative ticket table.** The native permanent Work Order identity remains `ops.work_order.work_order_id`; pending Intake and correction submissions remain `stage.work_order_intake.intake_id` until governed disposition. Display aliases such as `WO-372` and `INTAKE-60` are not new identities. Cross-links must preserve both source and outcome identities.
- **Work Orders** cover actionable repair, build/maintenance and related work. **Task Feedback** covers a reported observation or correction requiring review; it is not automatically a Work Order. The Manager may explicitly promote/link a real repair while preserving the original reporter and source, or route the correction to the authorized Procedure, Catalog, Kit/material, inventory, GIS, Testing or engineering owner. A report is not proof work occurred.
- The approved **#172 free-form Task Feedback entry** must remain simple: `What did you find?` plus optional suggestion/evidence. Capture known annual task, Stage/Scene, scheduled assignment, Crew/Captain, Procedure, authenticated reporter/time automatically where available. An unscheduled observation requires a truthful route **without fabricating a workday or Report Work**.
- **#209** owns annual experience → reusable Catalog review: distinguish proposed, verified, accepted, rejected and deferred improvements, and never modify reusable records without the governed confirmation. Work Management makes reports and their outcomes available to that review; it does not replace #209.

### Entry paths — existing and new

| Entry | Existing/current Production behavior | Intended Work Management behavior |
| --- | --- | --- |
| Public Work Order Request | Google form / Apps Script → Work Order Intake → Manager triage | Preserve the form and current Intake. Correct details, **choose assignees before** a guarded single Promote/Release action, preserve request provenance, and send accountable notifications |
| Production Crew Task Feedback | Authenticated #172 free-form submission → `SETUP_CORRECTION` Intake, initially Submitted | Same free-form entry and provenance; Manager routes/assigns a correction, requests clarification and records outcome; only explicitly promotes to a Work Order for actual repair/action |
| **Internal Work Order (new)** | There is no proven governed Manager direct-create-plus-assign command in the inspected current source | Authorized Manager creates an active Work Order directly, including Stage/Work Area, type, urgency/year, problem, related Display where valid and one or more actual assignees. Do **not** manufacture a public request or Intake row to create it |
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

The #419 read-only `SELECT` candidate [WO419 Unified Ticket Read-Only Candidate](engineering/WO419_Unified_Ticket_Read_Only_Candidate.sql) **executed successfully in authorized DBeaver**. The operator supplied all 389 data rows:

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

### Accountability and two-way reporter communication — required acceptance

**Every actionable item must be discoverable with a truthful status, named responsible owner or an explicit unassigned state, last recorded activity, next action and disposition.** A Manager must be able to find all outstanding repair Work Orders regardless of urgency, assignee or completed status; a Stage view under #205 must link to the authoritative Work Order rather than implementing competing Work Order edits.

The original reporter must see their own Task Feedback, with its current outcome and history. A correction owner can **Request Clarification** from that reporter; the original reporter receives a targeted email with a safe link to answer in the **same ticket**, and the assigned owner sees the reply. On a final verified correction resolution, deferral, denied/no action with reason or linked duplicate, notify the original reporter with the decision and explanation. If Feedback is promoted to a repair Work Order, **promotion is not completion**: source provenance and eventual Work Order closure outcome must remain traceable and communication must not falsely imply the repair occurred. Never default all ownership or notifications to a single experienced volunteer.

Every request/reply, correction owner assignment, next action, disposition, actor/date and notification outcome must be durable and auditable for the January review. The existing raw Intake status/delete/promotion operation cannot meet these requirements by itself. Identify whether narrowly scoped additional correction comment/ownership/outcome and cross-link persistence is necessary; do **not** create an independent master ticket store merely for a common interface. Keep the original free-form report intact and do not grant Crew members controlled Catalog/Procedure write access.

For outgoing email, use the governed MSB/Google Workspace delivery authority after real runtime proof. Record recipient, subject/template/event, QUEUED/SENT/FAILED (or equivalent authoritative states), deduplication and retry outcome. Delivery failure is visible to management, never silently claimed as sent, and does not fabricate ticket completion. Existing active Directus mail Flows may be retired only through explicit duplicate-free acceptance/cutover while preserving test/repair business effects.

### Permission, integration, and engineering sequence

- PostgreSQL owns existing Work Orders, Intake, People relationships, history and business rules. The **database repository owns their integration contract**. A separate dedicated Work Management application repository owns protected API/UI/deployment/tests according to the [System Boundary and Repository Ownership Standard](../../../../System_Documentation/Standards/System_Boundary_and_Repository_Ownership_Standard.md).
- Managers may have whole-system authorized search and triage; volunteers see only their own submitted reports, assigned work and allowed related details. Authorization uses existing trusted Person/Cloudflare/Directus identity mapping rather than a separate Work Management user table; email links must not reveal other people's reports or permit unauthenticated updates.
- Preserve the current user-filtered Directus `work_order_assignment?bookmark=100` as a legacy entry point until an accepted equal-or-better protected `My Work` UI replaces it. Preserve #172 Task Feedback from Perform Work, #132 Report Work as separate actual-work facts, #205 scheduling/Stage progress, #209 reusable review and Testing repair completion.
- **Engineering order:** Read current Project Rules/Standards and *this design* → document new findings here → source-only read model → regression/SQL review against known cases → governed current-Production disposable clone + protected browser acceptance → develop guarded Manager internal Work Order Create; integrated Triage→Assign→Release; My Work/progress/completion; and correction assignment/questions/reporter response/verified closure → tested notification cutover → explicit Production approval and controlled deployment. Do not interpret a PR merge, static validation, browser preview or mail connectivity alone as Production acceptance.
- Current implementation checkpoint: source-only **draft PR #420** contains the read-model spike and checkpoint. The live DBeaver run is **PASS for executing its SELECT**; API/role security, actual browser list/detail, clone acceptance, transactional write actions, reporter notifications, app repo/runtime allocation and Production deployment remain **NOT DONE**. Future implementation must conform to this design, not rewrite it merely to justify code already written.

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
