# Work Orders

This subsystem documents the Production Database work-order system, including intake, triage, assignment, notification, repair integration, completion, and the database relationships that make work orders part of the larger production system.

## Current State

Work Orders and Setup Task Feedback are implemented on the existing PostgreSQL Production Database. The public Google Form and accepted #172 free-form Task Feedback enter governed Work Order Intake; Test Session failures can create active repair Work Orders directly. Directus currently presents Intake triage, assignment and completion and runs selected notification/testing Flows.

**Next engineering priority — #419 unified MSB Work Management:** one ticket-style protected application for all Work Orders and Task Feedback, preserving each database identity and business lifecycle rather than creating a competing ticket table. The **original** read-only ledger SELECT was **successfully run against Production via authorized DBeaver on October 18**; the **revised assignee-scope and Testing-origin query has not been re-run** and neither revision has protected app/browser acceptance. New internal Manager Work Order creation, one-step Triage→Assign→Release, correction owners/replies, reporter clarification and outcome emails, and controlled mail-flow replacement remain **unimplemented**. Draft PR #420 is **source-only and unmerged**, not a Production application.

The [Work Order System Design](Work_Order_System_Design.md) is the **governing engineering authority** for #419 and the accepted underlying Work Order/Intake system. [GitHub issue #419](https://github.com/Gregovate/MSB-Production-Database-Project/issues/419) tracks unfinished work; [draft PR #420](https://github.com/Gregovate/MSB-Production-Database-Project/pull/420) protects candidate implementation and tests. Neither issue commentary nor the PR substitutes for the design.

## Start Here

- [Work Order System Design](Work_Order_System_Design.md) — **authoritative** current engineering/Work Management contract: existing tables/Flows, #419 decisions, live October 18 evidence, known gaps, acceptance and resume point.
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

Current entry paths are:

1. **Public Work Order Request Form -> Work Order Intake -> manager triage -> active Work Order when promoted**
2. **Authenticated Setup Report Correction -> authorized payload -> Directus Work Order Intake create event -> manager notification/triage -> active Work Order when promoted**
3. **Test Session -> automatically generated active Work Order**

Human-reported findings go through Intake because the report may require clarification, correction, deduplication, or a non-Work-Order disposition. Test Session-generated Work Orders bypass Intake because the governed test result already established a defined failure.

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

**#419 current resume point (October 18):** Read the governing [Work Order System Design](Work_Order_System_Design.md) first, including **Work Order landing view — default My Work** and **Test Session-generated Work Orders — feedback and ownership**. Opening Open Work Orders must default to the authenticated assignee, with explicit All / other-person scope and independent Show completed (same concept as Setup Perform Work); Test Session-generated repairs remain Testing-owned for source feedback and never acquire an invented human Intake reporter. Then read the source-only [WO419 unified read-only ledger](engineering/WO419_Unified_Ticket_Read_Only_Candidate.sql) and its [evidence/checkpoint](engineering/WO419_Read_Only_Ticket_Candidate_Checkpoint.md). The operator-provided DBeaver output established 386 Work Orders (328 with completion dates; 58 without), 3 retained Intake items, 10 active undated Work Orders without active assignees, and no joined Work Order status-history states. Keep completion-date truth separate from status-history and record-update timestamps. **Do not re-run broad schema reconnaissance to rediscover these facts** unless live change or a specific contract question requires it.

Next: execute source regression checks and validate the **revised** Person-ID/Test-Session-aware ledger on a disposable current-Production clone (the earlier original SELECT had DBeaver PASS); confirm authorized read scope and protected browser list/detail, then implement governed business actions and reporter communication. Read current Testing source/Flows before choosing Test Session notification recipients; do not silently mail an absent reporter. No new service or preview port has been allocated and there is no accepted Work Management browser candidate yet.

Before changing public Work Order Request/Intake behavior, inspect the attached Google Apps Script, live PostgreSQL processing functions and active Directus Flows; preserve completed #172 Task Feedback and all Testing completion side effects. A separate **dedicated Work Management application repository** should own user-facing code when started; record its exact source/runtime linkage here and preserve PostgreSQL lifecycle rules in this subsystem.


### Setup Report Correction / Directus notification integration

The current Manager triage email is an active Directus Flow (`WOI Request Triage Email`) triggered by `items.create` on `work_order_intake`. Setup Report Correction therefore enters Intake through the Directus Items API after PostgreSQL has authenticated the reporter and derived authoritative Setup context. A direct PostgreSQL Intake insert would bypass that event and is not the accepted #172 path.
