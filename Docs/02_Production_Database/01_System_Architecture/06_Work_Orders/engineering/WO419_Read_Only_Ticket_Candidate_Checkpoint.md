# #419 — Read-only unified ticket ledger: first engineering candidate

**Status:** SOURCE-ONLY / NOT RUN AGAINST PRODUCTION OR CLONE / NOT BROWSER-ACCEPTED  
**Issue:** [#419 MSB Work Management](https://github.com/Gregovate/MSB-Production-Database-Project/issues/419)  
**Command authority:** [#122 Setup integration](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122) for Setup cross-links only  
**Date:** October 18, 2026  
**Base main observed before branch:** `35f398df1217b85358b6ef72e5cbbeff7a2d9bd2`  
**Read-only SQL:** [WO419_Unified_Ticket_Read_Only_Candidate.sql](WO419_Unified_Ticket_Read_Only_Candidate.sql)

## Why this slice first

MSB already has authoritative Work Orders, Intake, Persons, normalized assignments,
Work Order status history, Test Session repair integration, and Task Feedback
`SETUP_CORRECTION` submissions. The missing capability is a unified, actionable
ticket interface. This query is a narrow **database-owned read-model contract**,
not a proposed second ticket database or an editable Directus screen.

It is deliberately a standalone `SELECT`: no `CREATE VIEW`, no new table,
no security grants, no Work Order/Intake mutation, no email send.
Its future application must live under its own controlled repository/deployment
lifecycle according to the
[repository ownership standard](../../../../../System_Documentation/Standards/System_Boundary_and_Repository_Ownership_Standard.md);
the Production Database repo retains database read/write integration contracts.

## Live DBeaver evidence provided on October 18

- Actual assignment table: `ops.work_order_assignment` with `active_flag`,
  `assignment_role`, `assigned_at`, `unassigned_at`, Person identity and audit.
  The archived `work_order_assignee` is NOT the current table.
- Work Orders have `urgency_id`, `source_intake_id`,
  `date_completed`, `repair_complete` and audited completion person/notes.
- Latest status event can be resolved from
  `ops.work_order_status_history` to `ref.work_order_status`
  (`SUBMITTED`, `TRIAGED`, `APPROVED`, `DENIED`, `IN_PROGRESS`, `DONE`).
  Current events/counts are **not yet verified**; status history and
  `date_completed` are shown separately when their truth differs.
- `stage.work_order_intake` contains the original free-form report,
  submitter Person/source context and triage code. Live current Intake
  grouping: **one SETUP_CORRECTION Submitted** and **two Work Order Form v2
  Submitted**.
- Live `ops.work_order_outbound_message` grouping returned **zero rows**.
  Existence of a table and active Directus mail Flows do **not** prove a
  working durable ticket notification service. Existing message table requires
  a nonnull `work_order_id`; it cannot represent an unpromoted correction
  clarification/closure event by itself.
- Actual `stage.p_process_work_order_intake(bigint)` after-update path:
  triage `1` leaves Submitted; `3` promotes into `ops.work_order`
  then **deletes** the original Intake and returns `assignee_count=0`;
  `4` deletes Intake without a retained Denied record. The enabled
  `AFTER UPDATE OF triage_dropdown` trigger invokes this processor. These
  business transitions must not be invoked from a prototype search action.

## Query output contract

Single row per **existing** Work Order or **retained** Intake record, no
invented master ticket ID. Ticket keys are display aliases
`WO-<work_order_id>` and `INTAKE-<intake_id>` rather than replacements.

Data includes ticket type, original IDs, human description, source, recorded
status and its source, urgency/year, Stage/Work Area, actual active assignee
names and count, original reporter (where recorded), latest known activity,
completion date, original active flag, and a status/date mismatch hint.

The query does not expose raw personal contact emails, Directus tokens or
source JSON payload. **This query is not itself a permission boundary**.
A protected backend must authorize the Manager global view or restrict
volunteer views to their actual assignment/submission rights before returning
data. Source text may contain personal/operational information and must not
be exposed through a public unauthenticated endpoint.

The query shows
`CORRECTION_OWNER_NOT_TRACKED` for Intake because there is currently no
proved correction-assignment lifecycle in the supplied schema. It does NOT
silently infer Rick as the owner, claim email delivery, invent work history,
or treat triage promotion as correction resolution.

## Controlled test/acceptance sequence

1. Review current `main`, the real existing Work Order/Intake schema,
   relevant Live Directus flows and applicable Project/Server Management rules.
2. **DBeaver authorized read-only inspection:** run the source `SELECT`
   only with an approved read identity and confirm it produces one row per
   currently retained Intake + Work Order. Query errors are STOP conditions;
   do not grant broad rights or adapt production schema in place.
3. Verify genuine examples:
   - WO 372 Magic Igloo weld repairs displays current status, real active
     assignees and its original source information; it must not be marked done
     just because the repairs were expected to occur.
   - The actual retained `SETUP_CORRECTION` Intake displays its free-form
     original and source, but no invented correction assignee or closed state.
     Do not assume it is Intake 60 solely from historical acceptance.
   - The two public submitted requests remain unpromoted and discoverable.
4. On a governed current-Production **disposable** PostgreSQL clone,
   exercise read-only search scenarios (ID, title, Stage, assignee, status,
   source, active/completed). Identify and fix any schema/privilege or
   pagination issue before any web endpoint.
5. Implement an authenticated, least-privilege read API and ticket-list/detail
   browser candidate in the **dedicated Work Management application repo**;
   allocate a distinct preview/runtime through Server Management. Reuse the
   established protected disposable browser review process, with approved
   port and clean exit. No guessed port, no Production DB browser writes.
6. Only after read-only browser acceptance: engineer governed transactional
   Triage→Assign→Release, Manager direct internal Work Order creation,
   current status/progress/completion, and correction clarification/owner/
   verified-closure with **reporter-facing email**. Preserve existing
   Test Session repair completion and Setup WO gate behavior.
7. Replace Directus email Flows only when distinct new sender/outbox,
   duplicate-prevention, retry, recipient and delivery evidence is accepted.

## Explicitly outstanding

- The query has **not** been executed against a database; SQL parser/connector
  static inspection is not a substitute for PostgreSQL validation.
- `ref.stage` and `ref.work_area` names are from existing repository
  contracts, not freshly verified Q03 columns; validate their use against live
  catalog during the controlled read-only query test.
- Current Work Order status-event completeness, actual active assignment
  records, existing outbound sender usage, secure reporter link/account
  eligibility, and app-specific read permission require further proof.
- Feedback to the same reporter, two-way clarification and durable correction
  closure are **not** claimed implemented by this slice.

No server maintenance, Production SQL mutation, actual Work Order completion,
real email, Directus Flow update or deployment is authorized by this draft.
