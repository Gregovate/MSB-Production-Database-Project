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

## Work Entry Paths

There are two current operational entry paths.

### Public Work Order Request

`my.sheboyganlights.org -> Google Work Order Request Form -> attached Apps Script -> Work Order Intake -> manager triage -> active Work Order`

The public form is an intake mechanism, not the Work Order system of record. A submitted request becomes an active Work Order only after manager triage and promotion.

The form currently uses numeric Priority values 1 through 5 as an intake estimate. The manager assigns/corrects the Work Order Urgency during triage.

The attached Google Apps Script is part of this integration. Before changing question titles, answer values, branching, or form structure, inspect that script and the downstream intake mapping.

### Test Session Repair

A display Test Session can generate a repair Work Order automatically. That Work Order is already active and does not pass through Work Order Intake triage.

A Test Session-generated Work Order must be completed before the related container Test Session can be closed.

## Triage

Manager triage applies only to Work Order Requests submitted through the public form.

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
