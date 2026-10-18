# Work Orders

This subsystem documents the Production Database work-order system, including intake, triage, assignment, notification, repair integration, completion, and the database relationships that make work orders part of the larger production system.

## Current State

**Engineering lineage:** Work Orders were designed and implemented well before #419. The [Work Order System Design](Work_Order_System_Design.md#existing-work-order-engineering-to-preserve--pre-419-authority-reconciliation) identifies the prior approved v1.1 database design and v3 operational model, the current task-sized SOPs, existing Directus navigation/Flows, Testing repair loop and #172 free-form correction integration. **Read those existing records before adding structures or changing behavior.** #419 is a usability/accountability improvement to that subsystem, not a new Work Order system or new repository.

Work Orders and Setup Task Feedback are implemented on the existing PostgreSQL Production Database. The public Google Form and accepted #172 free-form Task Feedback enter governed Work Order Intake; Test Session failures can create active repair Work Orders directly. Directus currently presents Intake triage, assignment and completion and runs selected notification/testing Flows.

**Next engineering priority — #419 unified MSB Work Management:** one ticket-style protected application for all Work Orders and Task Feedback, preserving each database identity and business lifecycle rather than creating a competing ticket table. The **original** read-only ledger SELECT was **successfully run against Production via authorized DBeaver on October 18**; the **revised assignee-scope and Testing-origin query has not been re-run** and neither revision has protected app/browser acceptance. New internal Manager Work Order creation, one-step Triage→Assign→Release, correction owners/replies, reporter clarification and outcome emails, and controlled mail-flow replacement remain **unimplemented**. **Launch blocker:** the [governing per-event Directus Flow retirement and one-authority cutover](Work_Order_System_Design.md#directus-flow-retirement-and-one-authority-production-cutover--mandatory-release-gate) must prevent duplicate Work Orders/emails and preserve Testing repair creation/completion. The four currently active Work Order-related Flows remain untouched until a separately approved cutover. Draft PR #420 is **source-only and unmerged**, not a Production application.

The [Work Order System Design](Work_Order_System_Design.md) is the **governing engineering authority** for #419 and the accepted underlying Work Order/Intake system. [GitHub issue #419](https://github.com/Gregovate/MSB-Production-Database-Project/issues/419) tracks unfinished work; [draft PR #420](https://github.com/Gregovate/MSB-Production-Database-Project/pull/420) protects candidate implementation and tests. Neither issue commentary nor the PR substitutes for the design.

**#419 P0 first-release acceptance:** The unified Work Management screen must support (1) **Request More Information** from the original reporter by a one-button question action, a verified outbound email, and a safe on-ticket reply; (2) a truthful **completion or final disposition email back to the original reporter** with durable audit and no false sent status; and (3) **triage → Promote & Assign together in one Manager screen and one guarded commit**, with real assignees, preserved source evidence and no half-promoted/doubled Work Orders. All three must pass the **disposable-clone/browser acceptance** before a Production cutover. The existing [engineering design](Work_Order_System_Design.md#p0-first-release-gate--reporter-clarification-outcome-email-and-one-step-triage) controls exact workflow, reasons, event ownership, no-send test cases, and failures. **None of these P0 actions has been implemented or browser-accepted yet.**

**#419 Setup Task Feedback consumer (P0):** Work Management must **consume the already-accepted #172 `SETUP_CORRECTION` Work Order Intake records** and provide a distinct **Setup correction/review workflow** when the finding belongs to Procedure, Kit/material, Setup data, Catalog, GIS or another accountable subsystem—not automatically a repair Work Order. Managers can assign a correction owner, ask the original reporter for clarification, record an evidenced/verified outcome, and send the reporter the disposition email. Genuine physical jobs use the existing **Triage → Promote & Assign** Work Order branch, preserving the originating Setup context. Neither branch may delete unresolved reporter evidence or fabricate Report Work. The [governing consumption/alternate-workflow contract](Work_Order_System_Design.md#setup-task-feedback-consumption--alternate-correction-workflow-p0) includes Intake #60 and disposable acceptance cases. **The Setup submission is deployed; the Work Management consumer and alternate correction workflow are not.**

**#419 correction categories and source links (P0):** **Repair / Work Order** and **Correction / Task Feedback** are separate operational categories in the existing unified Work Management subsystem. Corrections also identify their subject (e.g., **Kit Inventory** or **Procedure**) and preserve clickable, typed source references: actual **Kit Box / Container ID**, any other Container, real **Display ID/name**, and the original/current **Procedure context** when known. A Kit Box is already a Container in Setup (`ref.container.container_type_id=2`); don't invent a second Kit identity. Source #172 already supplies Setup task and Procedure context; additional Kit/Container/Display references are a **P0 consumer/capture improvement**, not yet implemented. Keep volunteer entry simple and let the Manager confirm missing links. See the [controlling engineering contract](Work_Order_System_Design.md#correction-category-and-linked-references--p0) for actual source identities, preservation, correction routing, security and disposable/browser acceptance.

**#419 Stage-first relevant resources (P0):** Feedback already has real Stage/Scene/annual-task context from accepted #172. Work Management presents an optional **Related Information** expandable section, **collapsed by default**, that loads relevant existing Stage/Scene/Task resources only if needed—without requiring the reporter to know Kit, Container, Display or Procedure IDs. Use existing Setup task-support, Kit Inventory, LOR Scene/Stage Display membership, Extra Materials and Procedure context/read APIs. Present **Directly linked to this task**, **Related to this Scene/Stage (not confirmed for the task)**, and **Confirmed for this correction** as different states, with human names, real IDs and protected **Open** links. A shared Kit linked to another task in the same Stage may be a valid candidate, not an existing link to the reporting task. Read-only discovery **never mutates Kit contents, Display ownership or Setup assignments**. The [governing Stage-first context contract](Work_Order_System_Design.md#stage-first-relevant-resources--no-scavenger-hunt-p0) specifies relevance, provenance, user review and disposable/browser acceptance. **A read-only Stage resource aggregation and collapsed Related Information UI are now committed as an untested V0.1 source candidate; actual browser acceptance, deep-link coverage, and confirmed-case persistence remain undone.**

## Start Here

- [Work Management disposable/preview acceptance profile](../../../../WorkOrders/Acceptance/README.md) — prepared exact-SHA Windows and remote clone-only launcher, SQL read validation and teardown; **not run**. Server Management [PR #80](https://github.com/Gregovate/MSB-Server-Management/pull/80) **merged** and authorized sequential pre-Production 8898 use; current listener availability and browser readiness still require live checks.
- [Work Management V0.1 application source](../../../../WorkOrders/Application/README.md) — **source-only read-only candidate**, My Work/All and ticket detail with lazy Related Information. Not clone/browser accepted. The full P0 triage/feedback/email workflow is not implemented yet.
- [Work Order System Design](Work_Order_System_Design.md) — **authoritative** existing-system contract, including [why the Directus operator experience needs improvement](Work_Order_System_Design.md#why-work-management-must-improve-the-existing-directus-experience), #419 design decisions, real schema/Flow evidence, acceptance requirements and resume point.
- [Work Order Operational SOPs](../../02_Operational_SOPs/Work_Orders/README.md) — current operator procedures.

## System Boundary

**#419 repository placement:** The Work Orders subsystem already exists under this engineering portal. New Work Management code, database contracts and acceptance tests stay in `Gregovate/MSB-Production-Database-Project`; a separate app repository was proposed prematurely and is **not required or approved**. Server Management continues to own its controlled preview/runtime setup. The October 18 Intake snapshot contains three submitted entries: Intake #60 (Setup correction) and #40/#57 (public requests). Use a disposable clone of these actual rows during acceptance; never fabricate or silently process them.

**Relationship Class:** Existing core Work Orders database subsystem, with the Work Management operator application developed inside this same MSB Production Database repository.

PostgreSQL owns Work Order identities, relationships, lifecycle state, and database-enforced business rules. The new Work Management interface is part of this **existing in-repository Work Orders subsystem**; the user-facing application has its own code and protected runtime but does not require another GitHub repository or authoritative database.

A dedicated Work Order application must not create a second Work Order database or competing lifecycle model.

### Production Database responsibility

- Work Order identity and lifecycle
- Work Order relationships to People, Testing, Displays, Stages, and Work Areas
- database constraints, procedures, triggers, and shared workflow rules
- durable history and audit attribution
- integration contract consumed by the operator application

### Work Management application responsibilities

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

**#419 current resume point (October 18):** Read the governing [Work Order System Design](Work_Order_System_Design.md) first, including **Stage-first relevant resources (P0)**, **Correction category and linked references (P0)**, **Setup Task Feedback consumption — alternate correction workflow (P0)**, **Work Order landing view — default My Work** and **Test Session-generated Work Orders — feedback and ownership**. Opening Open Work Orders must default to the authenticated assignee, with explicit All / other-person scope and independent Show completed (same concept as Setup Perform Work); Test Session-generated repairs remain Testing-owned for source feedback and never acquire an invented human Intake reporter. Then read the source-only [WO419 unified read-only ledger](engineering/WO419_Unified_Ticket_Read_Only_Candidate.sql) and its [evidence/checkpoint](engineering/WO419_Read_Only_Ticket_Candidate_Checkpoint.md). The operator-provided DBeaver output established 386 Work Orders (328 with completion dates; 58 without), 3 retained Intake items, 10 active undated Work Orders without active assignees, and no joined Work Order status-history states. Keep completion-date truth separate from status-history and record-update timestamps. **Do not re-run broad schema reconnaissance to rediscover these facts** unless live change or a specific contract question requires it.

**#419 first integrated application review target (P0-inclusive, not list-only):** the governing [Work Order System Design](Work_Order_System_Design.md#419-disposable-end-to-end-browser-acceptance-candidate--next-engineering-milestone) now specifies one coherent disposable-clone/browser acceptance of My Work/All, Work Order details and Testing links, Manager internal Create, Triage→Assign→Release, Task Feedback clarification/reply/verified closure, and a test-only reporter-notification ledger. That is the acceptance scope for the first usable Work Management review—not a cosmetic list prototype. **The contract is documented on draft PR #420's branch, not merged, built or deployed.** The [first read-only Work Management application source](../../../../WorkOrders/Application/README.md) now exists here. Executable tests, approved preview-port allocation, disposable SQL/browser checks, and the P0 write/email workflows are still required.

Next: execute source regression checks and validate the **revised** Person-ID/Test-Session-aware ledger on a disposable current-Production clone (the earlier original SELECT had DBeaver PASS); confirm authorized read scope and protected browser list/detail, then implement governed business actions and reporter communication. **Before enabling any new write or email production path**, inspect the full current Directus Flow graphs, designate a single event writer/sender for each Work Order/Intake/Testing event, and document exact approved per-Flow enable/disable, validation, and rollback under the governing Work Order design and Server Management runtime authority. Read current Testing source/Flows before choosing Test Session notification recipients; do not silently mail an absent reporter. The sequential #419 **pre-Production review profile is approved** in the Server Management port register, but **no live 8898 listener/clone/browser PASS** has been established. The [prepared acceptance runner](../../../../WorkOrders/Acceptance/README.md) must verify current listener ownership, exact candidate SHA, role permissions and disposable isolation at launch. Linux source CI PASS was recorded as run 39127213541; source PASS is not clone or browser acceptance.

Before changing public Work Order Request/Intake behavior, inspect the attached Google Apps Script, live PostgreSQL processing functions and active Directus Flows; preserve completed #172 Task Feedback and all Testing completion side effects. The Work Management UI/API belongs in this existing MSB Database repository, following its established subsystem/application conventions; record its exact source/runtime linkage here while preserving PostgreSQL lifecycle rules in this subsystem.


### Setup Report Correction / Directus notification integration

The current Manager triage email is an active Directus Flow (`WOI Request Triage Email`) triggered by `items.create` on `work_order_intake`. Setup Report Correction therefore enters Intake through the Directus Items API after PostgreSQL has authenticated the reporter and derived authoritative Setup context. A direct PostgreSQL Intake insert would bypass that event and is not the accepted #172 path.
