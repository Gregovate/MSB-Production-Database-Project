# Work Orders

This subsystem documents the Production Database work-order system, including intake, triage, assignment, notification, repair integration, completion, and the database relationships that make work orders part of the larger production system.

## Current State

Work Orders are implemented and actively evolving. PostgreSQL is the system of record. A public Google Form participates in intake. Directus currently handles triage/completion interaction and several workflow automations.

Directus is not required to remain the permanent operator interface. Its general-purpose data interface is inadequate for some repeated Work Order tasks, particularly helping assigned volunteers reliably find and complete their work.

A dedicated task-focused Work Order application may replace parts of the Directus user experience without changing the PostgreSQL ownership model.

## Start Here

- [Work Order System Design](Work_Order_System_Design.md) — current engineering contract for Work Order identity, intake, triage, assignment, completion, testing integration, and application boundaries.
- [Work Order Operational SOPs](../../02_Operational_SOPs/Work_Orders/README.md) — current operator procedures.

## System Boundary

**Relationship Class:** Core Database Subsystem with a future Dedicated Database-Backed Operational Application.

PostgreSQL owns the Work Order identity, relationships, lifecycle state, and database-enforced business rules. A dedicated Work Order application may live in a separate repository and provide the operator/manager user experience while continuing to use the Production Database as the system of record.

A dedicated Work Order application must not create a second Work Order database or competing lifecycle model.

### Production Database responsibility

- Work Order identity and lifecycle
- Work Order relationships to People, Testing, Displays, Stages, and Work Areas
- database constraints, procedures, triggers, and shared workflow rules
- durable history and audit attribution
- integration contract consumed by the operator application

### Dedicated Work Order application responsibility

- task-focused operator and manager UI
- finding assigned work reliably
- guided intake/triage/assignment/completion workflows as approved
- application-specific API/client code
- application deployment, configuration, and tests

If the dedicated application is unavailable, the Production Database remains authoritative and internally consistent. Operators may temporarily lose the preferred task interface, but Work Order data is not lost or transferred to another source of truth.

## Dependencies

- [Database Foundation](../01_Database_Foundation/README.md)
- [People and Identity](../03_People_and_Identity/README.md)
- [Testing System](../05_Testing_System/README.md) for repair-generated and repair-completion integration

## Current Responsibilities

- work-order identity and lifecycle
- stage/work-area location model
- task type, urgency, and target year
- assignee relationships
- public Google Form intake and manager triage
- assignment and notification behavior
- display/test-session linkage
- completion and repair feedback
- current work-order visibility/navigation limitations

## Public Intake Integration

The public **Work Order Request** is available from the top of `my.sheboyganlights.org` and may be used by anyone. It has two current paths: **Park** and **Workshop**.

Current intake flow:

**my.sheboyganlights.org -> Google Work Order Request Form -> attached Apps Script -> Work Order Intake -> manager triage -> active Work Order**

The form currently stores Priority as a number from 1 through 5. That number is an intake estimate. During triage, a manager reviews it and assigns the appropriate Work Order Urgency.

The Google Form has an attached **Apps Script**. Before changing form question titles, answer values, branching, or other structure, inspect the attached script for dependencies on the current form fields. In particular, preserve the existing Priority values unless the script and downstream intake behavior have first been reviewed.

A planned usability improvement is to add the urgency meanings directly to the form while retaining the current numeric values:

- 1 — Immediate / Critical
- 2 — High
- 3 — Normal
- 4 — Low
- 5 — Planning

The authoritative public instructions are [Submit a Work Order Request](../../02_Operational_SOPs/Work_Orders/Submit_a_Work_Order_Request.md). The MSB Backbone should link to that document rather than duplicate its instructions.

## Operational Flow

There are two entry paths:

1. **Public Work Order Request Form -> manager triage -> active Work Order**
2. **Test Session -> automatically generated active Work Order**

Test Session-generated Work Orders bypass Work Order Intake triage.

Once an active Work Order exists, the normal operational flow is:

**Assign -> perform work -> add Completion Notes -> mark Complete -> save**

A Work Order generated from a container Test Session must be completed before the related container Test Session can be closed.

## Directus Flow Ownership

Work-order-specific Directus flows belong in this subsystem. Current production flows observed during the documentation audit include:

- Create Repair Work Order
- WOI Request Triage Email
- Work Order Email Assignees
- Work Order completion/update integration

These flows must be documented from the current production configuration rather than reconstructed from legacy design notes.

## Authoritative Sources

- [Work Order System Design](Work_Order_System_Design.md)
- current PostgreSQL work-order tables, constraints, procedures, and triggers
- current production Directus flows
- current Google Form and attached Apps Script/intake workflow
- current operational Work Order SOPs

The former loose `G_Work_Order_Design_Plan.md` has been reconciled into this subsystem and archived as historical engineering evidence.

## Related Systems

- [People and Identity](../03_People_and_Identity/README.md)
- [Testing System](../05_Testing_System/README.md)
- [Operational SOPs](../../02_Operational_SOPs/README.md)
- [System Boundary and Repository Ownership Standard](../../../../System_Documentation/Standards/System_Boundary_and_Repository_Ownership_Standard.md)

## Resume Development

Before changing the public Work Order Request form, inspect its attached Apps Script and document any dependencies on question titles, answer values, branching, or response processing.

For broader Work Order engineering, inspect the current PostgreSQL implementation, current Directus flows, and [Work Order System Design](Work_Order_System_Design.md) before making changes.

When the dedicated Work Order application is started, create or use its separate implementation repository and link it here. Keep the Production Database schema/business contract in this subsystem and application implementation in the application repository.
