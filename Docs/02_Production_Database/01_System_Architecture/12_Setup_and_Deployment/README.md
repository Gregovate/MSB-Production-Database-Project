# Setup and Deployment

## Current State

**Status: PLANNED / NOT YET ENGINEERED**

This subsystem is reserved for planning, scheduling, staging, loading, scanning, and moving tested displays and containers from storage to the park for annual setup.

The Production Database does not yet contain the complete engineered workflow for this subsystem. No current operator procedure should assume that the scheduling, pick-list, load-order, or forklift-scanning functions described here are implemented.

## Design Intent

The Setup and Deployment subsystem will provide a repeatable operational plan for moving displays and containers from storage to the park.

Testing answers:

> Is this display/container ready?

Setup and Deployment answers:

> When should it move, what should move with it, and in what order?

The intended high-level workflow is:

```text
Testing Complete / Ready for Setup
            ↓
Schedule Display / Container
            ↓
Assign Calendar Pull Date
            ↓
Build Pick / Load List
            ↓
Forklift Driver Queue
            ↓
Scan / Confirm Container or Display
            ↓
Load in Planned Order
            ↓
Deliver to Park
            ↓
Confirm Movement / Destination
```

The goal is to replace informal yearly scheduling and remembered load sequences with a durable, repeatable operational process.

## Design Principles

### PostgreSQL remains the system of record

Scheduling, movement history, load grouping, scan confirmations, and deployment status should be stored in the Production Database rather than in an independent spreadsheet or application database.

### Directus is the initial management interface

The scheduling and management portion of this subsystem is expected to be controlled through Directus, similar to Test Sessions.

Directus may provide:

- setup-session records;
- calendar/pull-date assignment;
- management views and bookmarks;
- load/trip grouping;
- status changes;
- operator assignment where appropriate; and
- Directus Flows for notifications or lifecycle automation when useful.

A dedicated task-focused field interface may be added later if Directus is not suitable for forklift/scanning work. Any such application must continue to use the Production Database as the authoritative data source.

### Testing remains a separate subsystem

Testing and Setup/Deployment are related but distinct workflows.

A successful test may establish that an item is ready for setup, but the Testing subsystem does not own deployment dates, load order, transport grouping, or park delivery.

### Preserve yearly deployment history

The system should preserve the actual sequence used each year so a future setup season can begin from a proven prior-year order rather than reconstructing the process from memory.

Historical deployment records should not be overwritten merely because a new year's schedule is created.

## Planned Responsibilities

The subsystem is expected to eventually support the following areas. These are design targets, not implemented schema commitments.

### Setup Season / Session

A yearly or otherwise bounded setup session should provide the operational context for scheduling and deployment.

Potential responsibilities include:

- setup year/season;
- active planning window;
- start/end dates;
- status such as planning, active, and complete; and
- audit identity for who created or changed the plan.

### Calendar Pull Scheduling

Displays and/or containers should be assignable to calendar dates indicating when they are expected to be pulled from storage.

The schedule should support management planning without requiring forklift operators to interpret engineering data.

### Pick Lists

The system should be able to present the containers/displays that need to be pulled for a particular date, load, trip, stage, or other approved operational grouping.

Pick lists should be derived from authoritative database relationships rather than maintained as a competing manual list.

### Load / Trip Grouping and Sequence

Items should be groupable into a repeatable load or trip sequence.

The exact model is not yet engineered, but it should support recording the order in which items are expected to be pulled, loaded, and delivered.

This sequence should be retained as history so it can inform future years.

### Forklift Scanning

A future scanning workflow should allow a forklift driver to confirm the item being handled against the planned pick/load list.

Scanning should help answer practical field questions such as:

- Is this the correct container/display?
- Is it scheduled to move now?
- Which load or destination does it belong to?
- Has it already been pulled or loaded?

Scanning is an operational confirmation layer. It must not create an independent inventory or deployment source of truth.

### Movement and Delivery Confirmation

The subsystem should preserve important movement milestones such as pulled, staged, loaded, delivered, or otherwise confirmed at the destination when those states become part of the engineered workflow.

The exact status model remains unresolved and must be designed from the real setup process before implementation.

## System Boundaries and Dependencies

This subsystem depends on existing Production Database identities and relationships, including where applicable:

- containers and storage locations;
- displays and their container assignments;
- testing readiness/state;
- people/volunteer identity;
- labeling and scanning infrastructure; and
- site/stage/location information needed for deployment planning.

It must not redefine permanent Display IDs, Container IDs, storage identities, or other identities already owned by existing subsystems.

## Known Limitations / Open Work

The subsystem is intentionally not engineered yet.

Before implementation, the actual annual setup process must be observed and converted into explicit business rules. Important unresolved design questions include:

- what entity should be the primary scheduled object: display, container, or both;
- how readiness from Testing becomes eligible for Setup/Deployment;
- whether one container may serve multiple loads or dates;
- how park destination/stage affects load order;
- how loads/trips should be identified and sequenced;
- how changes on setup day are recorded without destroying the planned order;
- what forklift scanning must confirm at each movement step;
- which statuses are useful versus burdensome;
- how prior-year actual order is copied or used to seed a new season; and
- what Directus views/Flows are sufficient versus what requires a dedicated field application.

No database schema, trigger, stored procedure, Directus Flow, or operator SOP should be treated as approved until these questions are resolved from the real workflow.

## Resume Development

When development resumes, begin by documenting the real setup-day process from the people who schedule, pull, load, drive the forklift, and receive displays at the park.

Recommended first engineering steps:

1. Document the current manual scheduling and loading process.
2. Identify the minimum durable records the Production Database must preserve.
3. Define the Setup Session / season boundary.
4. Define scheduling and load-order business rules.
5. Define how Testing readiness feeds Setup/Deployment eligibility.
6. Define scan events and the minimum forklift-driver interface.
7. Model history so planned order and actual order can both be preserved if needed.
8. Design PostgreSQL schema/constraints before building Directus views or Flows.
9. Build the management workflow in Directus first where practical.
10. Add task-focused scanning UI only if field use demonstrates that Directus is inadequate for that part of the workflow.
11. Create Operational SOPs only after the implemented workflow can be tested.

## Related Systems

- [Testing System](../05_Testing_System/README.md) — establishes testing state/readiness before deployment.
- [Containers and Storage](../04_Containers_and_Storage/README.md) — owns container identity, assignments, and storage-location relationships.
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md) — owns permanent labels and scanning integration patterns.
- [People and Identity](../03_People_and_Identity/README.md) — provides durable person/user identity and audit attribution.
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md) — may provide destination/location context where applicable.

## Related Operational Documentation

Operator procedures do not exist yet for this subsystem because the workflow has not been engineered or tested.

When the subsystem becomes operational, its procedures should be created under:

```text
Docs/02_Production_Database/02_Operational_SOPs/Setup_and_Deployment/
```

following the current Operational SOP Standard.
