# Setup and Deployment

## Current State

**Status: DOCUMENTATION ACTIVE / OPERATIONAL ENGINEERING MOSTLY PLANNED**

This subsystem covers the documentation and future operational engineering for planning, scheduling, staging, loading, scanning, and moving tested displays and containers from storage to the park for annual setup, plus takedown-related field documentation where it belongs with the same Stage material.

The Stage-oriented folder structure already exists. Setup/Takedown instructions are being organized into those existing Stage folders and use the same Stage-oriented convention already used for Wiring documentation. That documentation work is active now even though the database workflow for scheduling, pick lists, load order, and forklift scanning is not yet fully engineered.

The Production Database does not yet contain the complete engineered workflow for this subsystem. No operator procedure should imply that planned scheduling, pick-list, load-order, or forklift-scanning functions are implemented unless verified from the current database/application.

## Design Intent

The Setup and Deployment subsystem will provide a repeatable operational plan for moving displays and containers from storage to the park while keeping field instructions easy to find from the same established Stage organization used by Wiring.

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

## Stage Setup Documentation Boundary

Field-facing **Stage Setup Instructions are a separate document class from repository Operational SOPs**.

They are used by volunteers physically setting up Stages/Scenes in the park and should remain simple, visual, and Stage-oriented. Their normal published experience may be a PDF or other rendered field document even when the editable source is a Google Doc or controlled repository source/template.

The project-specific governance for these documents is defined in the [Stage Setup Documentation Standard](../../../../System_Documentation/Project_Rules/Stage_Setup_Documentation_Standard.md).

The controlled structural starting point is the [Stage Setup Instruction Template](../../../../System_Documentation/Templates/Stage_Setup_Instruction_Template.md).

A separate contributor/operator procedure is still required for creating, revising, archiving, publishing, and verifying Setup Instructions from that template/source. That contributor workflow should not be confused with the field instruction itself.

## Stage Folder Documentation Contract

The existing Google Shared Drive Stage/Scene folder structure is the human-facing organizational anchor for setup work.

- Wiring and Setup/Takedown documentation share the same Stage-oriented organizational model.
- The existing Google Drive document-organization and Folder Alignment work controls the actual folder structure and migration of legacy material.
- Setup instructions should be placed and maintained within the existing Stage/Scene structure rather than creating a separate unrelated setup-document tree.
- [Wiring System](../09_Wiring_System/README.md) owns wiring content in that structure.
- Setup and Deployment owns setup/takedown instruction behavior and the database/application integration contract for finding applicable Setup documents.
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md) owns permanent QR/scanning integration patterns, but QR lookup does not become the content authority.

This framework does not by itself define or approve a new database schema.

## Document Resolution and Field UX

The intended field-access path is:

```text
Display QR
    ↓
Permanent Display identity
    ↓
Production Database relationships
    ↓
Applicable Stage / Scene
    ↓
Current Setup document reference(s)
    ↓
my.sheboyganlights.org
    ↓
Current field PDF / rendered instruction
```

The QR code identifies the asset. It should not need to contain a Google Drive folder path or manually maintained direct Setup-document URL.

The Production Database owns the durable identities and relationships used to determine which instructions apply. The database does not need to become the editing system for the Setup content itself.

The exact PostgreSQL location for durable Google Doc IDs, published PDF references, or other document identifiers remains an engineering decision that must be based on the current schema rather than guessed.

`my.sheboyganlights.org` is the intended normal field presentation layer. Field volunteers should not need to understand the GitHub repository, database schema, Google Drive organization, or source-document mechanics to reach the current Setup instruction.

## Annual Operating Cycle

`ref.season` remains the annual operational context. The documented working cycle is approximately:

- Testing begins in January.
- Setup/show preparation begins around the end of September.
- Takedown begins around January 1.
- After takedown, the next testing cycle begins again.

Detailed testing-season procedures belong with [Testing System](../05_Testing_System/README.md); detailed Setup field instructions live with the established Stage/Scene documentation structure.

## Design Principles

### PostgreSQL remains the operational system of record

Scheduling, operational movement events, load grouping, scan confirmations, deployment status, and the durable relationships required to resolve applicable field documentation should remain in the Production Database when those workflows are engineered.

Generic container movement history is not a goal. Movement/history should be recorded only when the Setup/Deployment workflow actually needs a reconstructable event trail.

### Field document content remains separate from database internals

The database may identify and resolve the correct Setup instruction without requiring field volunteers to operate inside PostgreSQL, Directus, GitHub, or Google Drive.

A simple PDF/rendered instruction at the Stage level is preferred when that gives the crew the best user experience.

### Directus is an initial management interface, not the field-document UX requirement

The scheduling and management portion of this subsystem is expected to be controlled through Directus initially where practical.

A dedicated task-focused field interface may be added where Directus is not suitable. Any such application must continue to use the Production Database as the authoritative operational data source.

### Testing remains a separate subsystem

Testing and Setup/Deployment are related but distinct workflows.

A successful test may establish that an item is ready for setup, but the Testing subsystem does not own deployment dates, load order, transport grouping, park delivery, or the content of Stage Setup Instructions.

### Preserve useful yearly deployment and documentation history

The system should preserve the actual sequence used each year when that history is useful for planning the next season. Historical deployment records should not be overwritten merely because a new year's schedule is created.

Legacy and superseded Setup instructions should be archived through the established Stage documentation process rather than deleted or left mixed with current field instructions.

## Planned Responsibilities

The subsystem is expected to eventually support:

- setup season/session context;
- calendar pull scheduling;
- pick lists;
- load/trip grouping and sequence;
- forklift scanning;
- meaningful pull/stage/load/delivery confirmations;
- prior-year sequence reference;
- durable Stage/Scene Setup document resolution;
- field-friendly Setup-document presentation through `my.sheboyganlights.org`.

These are design targets, not implemented schema commitments unless verified in the current database.

## System Boundaries and Dependencies

This subsystem depends on existing Production Database identities and relationships, including where applicable:

- containers and storage locations;
- displays and their container assignments;
- testing readiness/state;
- people/volunteer identity;
- labeling and scanning infrastructure;
- Stage/Scene identity and established documentation organization; and
- site/stage/location information needed for deployment planning.

It must not redefine permanent Display IDs, Container IDs, storage identities, LOR wiring/topology, or other identities already owned by existing subsystems.

Containers of type **KIT** already exist and may hold loose setup materials instead of Displays. Detailed kit-contents inventory is a known future need but is not being engineered as part of this documentation work.

## Known Limitations / Open Work

The operational database workflow is intentionally not fully engineered yet.

Current priority is to document the real Setup/Takedown instructions in the existing Stage/Scene locations, finish the document-alignment procedure, define the controlled Setup template/contributor workflow, and establish durable navigation before deeper workflow engineering.

Open work includes:

- complete the legacy Setup-document alignment/archive procedure already underway;
- finalize the Stage Setup Instruction template and contributor/operator procedure;
- finalize the Setup-specific image-location rule within the established Stage folder model;
- determine the editable-source versus published-PDF relationship where Google Docs remain in use;
- determine how durable Google document IDs / published document references are represented in the current PostgreSQL schema;
- define the exact contract consumed by `my.sheboyganlights.org` for Stage/Scene document presentation;
- determine what entity should be the primary scheduled object: display, container, or both;
- define how readiness from Testing becomes eligible for Setup/Deployment;
- define how park destination/stage affects load order;
- define loads/trips and setup-day changes without destroying useful history;
- define what forklift scanning must confirm; and
- determine which management workflows remain in Directus versus a dedicated task-focused interface.

## Resume Development

For Setup-document work, begin with:

1. the [Stage Setup Documentation Standard](../../../../System_Documentation/Project_Rules/Stage_Setup_Documentation_Standard.md);
2. the current [Google Drive Document Organization Procedure](../../../00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md);
3. the current Folder Alignment work/report;
4. the controlled [Stage Setup Instruction Template](../../../../System_Documentation/Templates/Stage_Setup_Instruction_Template.md); and
5. the real Stage/Scene documents currently being reviewed and archived.

Do not redesign the established Stage folder structure while solving document identity, QR resolution, PDF publishing, or intranet UX.

For future database/application engineering, document the real setup-day process from the people who schedule, pull, load, drive the forklift, and receive displays at the park. Define business rules before designing schema, Directus Flows, or a dedicated field application.

## Related Systems

- [Testing System](../05_Testing_System/README.md) — establishes testing state/readiness before deployment.
- [Containers and Storage](../04_Containers_and_Storage/README.md) — owns container identity, assignments, storage-location relationships, and KIT container identity.
- [Wiring System](../09_Wiring_System/README.md) — shares the established Stage-oriented field-documentation model while retaining its own wiring contracts.
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md) — owns permanent labels and QR/scanning integration patterns.
- [People and Identity](../03_People_and_Identity/README.md) — provides durable person/user identity and audit attribution.
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md) — may provide destination/location context where applicable.

## Related Documentation

- [Stage Setup Documentation Standard](../../../../System_Documentation/Project_Rules/Stage_Setup_Documentation_Standard.md)
- [Stage Setup Instruction Template](../../../../System_Documentation/Templates/Stage_Setup_Instruction_Template.md)
- [Google Drive Document Organization Procedure](../../../00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md)
- [Document Control Standard](../../../../System_Documentation/Standards/Document_Control_Standard.md)
- [Linking and Navigation Standard](../../../../System_Documentation/Standards/Linking_and_Navigation_Standard.md)

Repository Operational SOPs remain appropriate for database/application tasks in this subsystem when those tasks are implemented. They are not the storage or format model for the field-facing Stage Setup Instructions themselves.
