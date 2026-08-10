# Setup and Deployment

## Current State

**Status: DOCUMENTATION ACTIVE / OPERATIONAL ENGINEERING MOSTLY PLANNED**

This subsystem covers the documentation and future operational engineering for planning, scheduling, staging, loading, scanning, and moving tested displays and containers from storage to the park for annual setup, plus takedown-related field documentation where it belongs with the same Stage material.

The Stage-oriented folder structure already exists. Setup/Takedown instructions are being organized into those existing Stage folders and use the same Stage `folder_path` convention already used for Wiring documentation. That documentation work is active now even though the database workflow for scheduling, pick lists, load order, and forklift scanning is not yet fully engineered.

The Production Database does not yet contain the complete engineered workflow for this subsystem. No operator procedure should imply that planned scheduling, pick-list, load-order, or forklift-scanning functions are implemented unless verified from the current database/application.

## Design Intent

The Setup and Deployment subsystem will provide a repeatable operational plan for moving displays and containers from storage to the park while keeping field instructions easy to find from the same Stage-oriented folder structure used by Wiring.

Testing answers:

> Is this display/container ready?

Setup and Deployment answers:

> When should it move, what should move with it, in what order, and what instructions does the crew need at the Stage?

The intended high-level workflow remains:

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

The goal is to replace informal yearly scheduling and remembered load sequences with a durable, repeatable operational process without disrupting the existing Stage-folder documentation crews already use.

## Stage Folder Documentation Contract

The existing Stage folder structure is the human-facing documentation anchor for setup work.

- Wiring and Setup/Takedown documentation share the same Stage-oriented folder/path convention.
- `ref.stage.folder_path` is the intended database reference to that established Stage documentation location where applicable.
- Setup instructions should be placed and maintained within the existing Stage structure rather than creating a separate unrelated setup-document tree.
- [Wiring System](../09_Wiring_System/README.md) owns wiring content in that structure.
- Setup and Deployment owns setup/takedown instructions in that structure.
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md) may later provide QR-based routing to this information, but QR lookup does not become the content authority.

This framework is documentation/navigation work. It does not by itself define or approve a new database schema.

## Annual Operating Cycle

`ref.season` remains the annual operational context. The documented working cycle is approximately:

- Testing begins in January.
- Setup/show preparation begins around the end of September.
- Takedown begins around January 1.
- After takedown, the next testing cycle begins again.

Detailed testing-season procedures belong with [Testing System](../05_Testing_System/README.md); detailed setup/takedown procedures belong here once they are captured and verified.

## Design Principles

### PostgreSQL remains the system of record

Scheduling, operational movement events, load grouping, scan confirmations, and deployment status should be stored in the Production Database rather than in an independent spreadsheet or application database when those workflows are engineered.

Generic container movement history is not a goal. Movement/history should be recorded only when the Setup/Deployment workflow actually needs a reconstructable event trail.

### Directus is the initial management interface

The scheduling and management portion of this subsystem is expected to be controlled through Directus initially where practical.

A dedicated task-focused field interface may be added later if Directus is not suitable for forklift/scanning work. Any such application must continue to use the Production Database as the authoritative data source.

### Testing remains a separate subsystem

Testing and Setup/Deployment are related but distinct workflows.

A successful test may establish that an item is ready for setup, but the Testing subsystem does not own deployment dates, load order, transport grouping, or park delivery.

### Preserve useful yearly deployment history

The system should preserve the actual sequence used each year when that history is useful for planning the next season. Historical deployment records should not be overwritten merely because a new year's schedule is created.

## Planned Responsibilities

The subsystem is expected to eventually support:

- setup season/session context;
- calendar pull scheduling;
- pick lists;
- load/trip grouping and sequence;
- forklift scanning;
- meaningful pull/stage/load/delivery confirmations;
- prior-year sequence reference;
- Stage-based setup/takedown documentation.

These are design targets, not implemented schema commitments unless verified in the current database.

## System Boundaries and Dependencies

This subsystem depends on existing Production Database identities and relationships, including where applicable:

- containers and storage locations;
- displays and their container assignments;
- testing readiness/state;
- people/volunteer identity;
- labeling and scanning infrastructure;
- Stage folder/path information; and
- site/stage/location information needed for deployment planning.

It must not redefine permanent Display IDs, Container IDs, storage identities, LOR wiring/topology, or other identities already owned by existing subsystems.

Containers of type **KIT** already exist and may hold loose setup materials instead of Displays. Detailed kit-contents inventory is a known future need but is not being engineered as part of this documentation audit.

## Known Limitations / Open Work

The operational database workflow is intentionally not fully engineered yet.

Current priority is to document the real setup/takedown instructions in the existing Stage folders and establish clear navigation before deeper workflow engineering.

Future engineering still needs to determine from the real setup process:

- what entity should be the primary scheduled object: display, container, or both;
- how readiness from Testing becomes eligible for Setup/Deployment;
- how park destination/stage affects load order;
- how loads/trips should be identified and sequenced;
- how changes on setup day are recorded without destroying useful planned history;
- what forklift scanning must confirm at each movement step;
- which statuses are useful versus burdensome;
- how prior-year actual order is reused; and
- what Directus views/Flows are sufficient versus what requires a dedicated field application.

## Resume Development

For documentation work, begin with the existing Stage folder structure and the real wiring/setup material already used by the crew. Preserve the shared Stage `folder_path` convention and make each Stage's setup/takedown instructions easy to find.

For future database/application engineering, begin by documenting the real setup-day process from the people who schedule, pull, load, drive the forklift, and receive displays at the park. Define business rules before designing schema, Directus Flows, or a dedicated field application.

## Related Systems

- [Testing System](../05_Testing_System/README.md) — establishes testing state/readiness before deployment.
- [Containers and Storage](../04_Containers_and_Storage/README.md) — owns container identity, assignments, storage-location relationships, and KIT container identity.
- [Wiring System](../09_Wiring_System/README.md) — shares the existing Stage folder/path convention for field documentation.
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md) — owns permanent labels and QR/scanning integration patterns.
- [People and Identity](../03_People_and_Identity/README.md) — provides durable person/user identity and audit attribution.
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md) — may provide destination/location context where applicable.

## Related Operational Documentation

Setup/Deployment operator procedures should be created under:

```text
Docs/02_Production_Database/02_Operational_SOPs/Setup_and_Deployment/
```

following the current Operational SOP Standard as real procedures are captured and verified.
