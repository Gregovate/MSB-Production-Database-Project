# Setup and Deployment

## Current State

**Status: DOCUMENTATION ACTIVE / PROCEDURE RESOLVER ENGINEERING READY**

This subsystem covers planning, scheduling, staging, loading, scanning, and moving tested displays and containers from storage to the park for annual setup, plus takedown-related field documentation where it belongs with the same Stage material.

The Stage-oriented folder structure already exists. Setup/Takedown instructions are being organized into those existing Stage folders and use the same Stage-oriented convention already used by Wiring documentation.

The operational database/application workflow for scheduling, pick lists, load order, and forklift scanning is not yet fully engineered. No operator procedure should imply those planned functions are implemented until verified from the current database/application.

**FieldWiring and the Display Scan integration are now accepted production baselines.** Procedure resolver engineering does not need to wait for, rediscover, or redesign either system. Start with [Procedure System Field Context Handoff — 2026-08-22](00_Procedure_System_Field_Context_Handoff_2026-08-22.md), which resolves older documentation conflicts and defines how Setup/Takedown/Inspection reuse the proven FieldWiring structured Stage/Sub-stage/Scene resolver.

MSB has purchased a **Zebra DS3678-HD cordless ultra-rugged 1-D/2-D scanner kit** for the workshop forklift. It uses the Zebra 3600-series USB cradle and supports USB HID keyboard input. Because this is the **HD (High Density)** variant rather than an ER/XR extended-range model, its actual suitability from the forklift seat must be tested with real MSB Container and Storage Location labels before it is accepted as the final forklift-distance standard. See [Scanner Hardware and Tablet Integration](../07_Labeling_and_Scanning/Scanner_Hardware_and_Tablet_Integration.md).

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
- Setup and Deployment owns setup/takedown instruction behavior and the application integration contract for finding applicable Procedure documents.
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md) owns permanent QR/scanning integration patterns, but QR lookup does not become the content authority.
- [Procedure System Field Context Handoff](00_Procedure_System_Field_Context_Handoff_2026-08-22.md) owns the current initial resolver/runtime handoff where older documents conflict.

This framework does not by itself define or approve a new database schema.

## Document Resolution and Field UX

The accepted initial field-access path is:

```text
Display QR or manual Display/Stage/Scene lookup
    ↓
Permanent Display identity when applicable
    ↓
Production Database relationships
    ↓
shared/proven FieldWiring structured Stage / Sub-stage / Scene resolver
    ↓
fixed applicable structured root
    ↓
validate structured-root marker
    ↓
validate <scope>/Procedures marker
    ↓
Procedure task adapter selects fixed child
    ↓
<scope>/Procedures/Setup
or <scope>/Procedures/Takedown
or <scope>/Procedures/Inspection
    ↓
bounded current-document discovery from the read-only Google filesystem
    ↓
my.sheboyganlights.org
    ↓
current field PDF / rendered instruction
```

The QR code identifies the asset. It does not contain a Google Drive folder path or manually maintained direct Procedure-document URL.

The Production Database owns the durable identities and relationships used to determine the structured Stage/Scene context. The database does not become the editing system for Procedure content.

For the **initial read-only Procedure browser**, a PostgreSQL row or stored Google document ID for every current published PDF is **not a prerequisite**. Once the current structured root and marked `Procedures` subsystem root are validated, the application selects the exact known `Setup`, `Takedown`, or `Inspection` child and may enumerate the current published files directly in that task folder while excluding `Archive` and `SourceDocs`.

Durable per-document metadata remains a future engineering option when approval workflow, revision history, source-to-publication lineage, supersession, audit, or stable document identity demonstrates a need for it. Do not create schema merely because older documentation listed document-ID storage as unresolved.

`my.sheboyganlights.org` is the intended normal field presentation layer. Field volunteers should not need to understand the GitHub repository, database schema, Google Drive organization, or source-document mechanics to reach the current Setup instruction.

## Resolver Reuse Boundary

Procedures must **reuse or extract the proven FieldWiring structured-scope resolver** rather than create a second independent Display-to-Stage/Scene algorithm.

The shared resolver answers:

> Which current marked Stage / Sub-stage / Scene root owns this context?

The Procedure adapter then answers:

> Which current documents are published in the selected Procedure task branch beneath that already-resolved root?

This means Wiring and Procedures share scope resolution but do not share task-specific content rules:

```text
resolved structured root
    |
    +--> FieldWiring -> marked Wiring root -> BackgroundStage or MusicalStage
    |
    +--> Procedures  -> marked Procedures root -> Setup, Takedown, or Inspection
```

Both systems use the same subsystem-root marker pattern: the resolved structured scope is marked, then the owning application subsystem root (`Wiring` or `Procedures`) is marked. Their fixed child branches are selected by folder name and do not require a second marker layer. `Archive` and `SourceDocs` remain excluded from normal field presentation.

## Scan / Forklift Direction

The permanent Display scan platform is already production-operational and resolves `DISP:<display_id>` using permanent Production Database identity. Future Procedure scan actions should consume that existing identity contract; no physical Display QR redesign is required.

Setup is also expected to become a high-volume scan workflow for deployment operations rather than only document lookup.

Durable physical identities remain the starting point:

```text
DISP:<permanent display_id>
CONT:<permanent container_id>
LOC:<operational storage/location code>
```

Annual setup dates, load numbers, staging status, and other transient workflow state must not be encoded into the permanent labels.

The application should be designed so both of these input paths produce the same canonical asset/location payload:

```text
industrial scanner -> HID keyboard input
phone/tablet camera -> camera decoder
```

The purchased Zebra DS3678-HD gives the project a real industrial hardware acceptance target. Its USB HID behavior fits the browser-first design, but the hardware must be tested against actual label size/density and actual forklift position before deciding whether HD range is adequate or an ER/XR scanner is required for some tasks.

Likely setup interactions may include both scan orders:

```text
Container -> Location
Location -> Container
```

The real setup-day process must determine what each pair means: pull confirmation, staging, load assignment, destination validation, storage relocation, or another business event. Do not invent transaction semantics from the scanner hardware.

## Annual Operating Cycle

`ref.season` remains the annual operational context. The documented working cycle is approximately:

- Testing begins in January.
- Setup/show preparation begins around the end of September.
- Takedown begins around January 1.
- After takedown, the next testing cycle begins again.

Detailed testing-season procedures belong with [Testing System](../05_Testing_System/README.md); detailed Setup field instructions live with the established Stage/Scene documentation structure.

## Design Principles

### PostgreSQL remains the operational system of record

Scheduling, operational movement events, load grouping, scan confirmations, deployment status, and durable Stage/Scene/asset relationships remain in the Production Database when those workflows are engineered.

Generic container movement history is not a goal. Movement/history should be recorded only when the Setup/Deployment workflow actually needs a reconstructable event trail.

### Google Shared Drive remains the field-document repository

The shared read-only server filesystem exists so Procedure applications can consume the same human-maintained `Display Folders` hierarchy already used by FieldWiring.

Do not create a second Procedure-only Google hierarchy, duplicate mount, downloaded mirror, or database binary-document store merely to present current procedures.

### Field document content remains separate from database internals

The database resolves the current physical context without requiring field volunteers to operate inside PostgreSQL, Directus, GitHub, or Google Drive.

A simple PDF/rendered instruction at the Stage/Scene level is preferred when that gives the crew the best user experience.

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

- current Setup/Takedown/Inspection document lookup by Display/Stage/Scene;
- field-friendly Procedure presentation through `my.sheboyganlights.org`;
- Procedure actions from the existing Display scan hub after standalone Procedure acceptance;
- setup season/session context;
- calendar pull scheduling;
- pick lists;
- load/trip grouping and sequence;
- forklift scanning;
- Container/Location validation;
- meaningful pull/stage/load/delivery confirmations;
- prior-year sequence reference;
- optional durable per-document publication metadata when a demonstrated workflow requires it.

These are design targets, not implemented schema commitments unless verified in the current database.

## System Boundaries and Dependencies

This subsystem depends on existing Production Database identities and relationships, including where applicable:

- permanent Display identity and Stage/Scene relationships;
- the accepted FieldWiring structured-context behavior;
- the accepted Display scan platform;
- the shared read-only Google `Display Folders` filesystem;
- containers and storage locations;
- testing readiness/state;
- people/volunteer identity;
- rugged tablet/industrial scanner hardware;
- Stage/Scene identity and established documentation organization; and
- site/stage/location information needed for deployment planning.

It must not redefine permanent Display IDs, Container IDs, storage identities, LOR wiring/topology, or other identities already owned by existing subsystems.

Containers of type **KIT** already exist and may hold loose setup materials instead of Displays. Detailed kit-contents inventory is a known future need but is not part of the first Procedure document-resolution proof.

## Known Limitations / Open Work

**FieldWiring and Display Scan are no longer open prerequisites.** The immediate Procedure-document engineering work may proceed from their accepted production baseline.

Open Procedure-document work includes:

- inspect/extract the reusable FieldWiring structured-scope boundary without changing its accepted behavior;
- prove one read-only current Setup PDF lookup end-to-end from current PostgreSQL Stage/Scene context;
- validate the resolved Stage/Sub-stage/Scene marker and the `Procedures` subsystem-root marker;
- enforce `Archive` and `SourceDocs` exclusion at the normal Procedure endpoint;
- define supported current field-document formats, beginning with PDF;
- define the simple list behavior when more than one current Procedure applies;
- define the missing-current-document user experience;
- define the protected `my.sheboyganlights.org` Procedure route;
- test PC/phone/tablet and print/offline behavior;
- add a Procedure action to the existing Display scan hub only after standalone Procedure presentation is accepted;
- complete the legacy Setup-document alignment/archive procedure already underway;
- finalize the Stage Setup Instruction template and contributor/operator procedure;
- determine the editable-source versus published-PDF relationship where Google Docs remain in use;
- engineer durable Google document IDs / published references only if a demonstrated publication/history workflow requires them.

Separate Setup/Deployment operational work still includes scheduling, readiness, pull/load planning, Container/Location movement semantics, forklift workflow, and hardware acceptance. Do not mix those business-process questions into the first Procedure document-resolution proof.

## Resume Development

### Current baseline — FieldWiring and Scan are complete

Begin from current `main`. Do not rediscover the old live-only scan extension, redesign the physical QR, or rebuild the Google filesystem connection.

Read first:

1. [Procedure System Field Context Handoff — 2026-08-22](00_Procedure_System_Field_Context_Handoff_2026-08-22.md)
2. [Field Context Resolution Contract](../07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)
3. [FieldWiring Drive Context Resolver Engineering Design](../09_Wiring_System/FieldWiring_Drive_Context_Resolver_Engineering_Design.md)
4. `FieldWiring/Application/wiring_images.py`
5. `FieldWiring/Application/repository.py`
6. [Google Drive Document Organization Procedure](../../../00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md)
7. [Stage Setup Documentation Standard](../../../../System_Documentation/Project_Rules/Stage_Setup_Documentation_Standard.md)
8. [FieldWiring Scan Integration Engineering Handoff](../07_Labeling_and_Scanning/FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md)

### First Procedure application proof

The first application proof should remain narrow:

```text
Display / Stage / Scene lookup
    -> shared structured-scope resolver
    -> fixed current scope_root
    -> validate scope_root marker
    -> validate Procedures marker
    -> select Procedures/Setup
    -> enumerate current PDF(s)
    -> protected browser presentation
```

Do not begin by creating Procedure schema, a generic document registry, a second resolver, or forklift/deployment transaction logic.

### Setup workflow engineering

Separately document the real setup-day process from the people who:

- schedule pulls;
- operate the forklift;
- identify containers/locations;
- stage material;
- load trailers/trucks;
- receive loads at the park;
- place containers/displays at their destinations.

Define business events and exception handling before designing schema, Directus Flows, scan-session state, or a dedicated deployment application.

### Hardware acceptance

Begin hardware testing with the [Scanner Hardware and Tablet Integration](../07_Labeling_and_Scanning/Scanner_Hardware_and_Tablet_Integration.md) handoff and the purchased Zebra DS3678-HD. Use actual labels and measured working distances rather than theoretical family-level specifications.

### Setup-document authoring work

For Setup-document authoring/alignment work, continue with:

1. the [Stage Setup Documentation Standard](../../../../System_Documentation/Project_Rules/Stage_Setup_Documentation_Standard.md);
2. the current [Google Drive Document Organization Procedure](../../../00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md);
3. the current Folder Alignment work/report;
4. the controlled [Stage Setup Instruction Template](../../../../System_Documentation/Templates/Stage_Setup_Instruction_Template.md); and
5. the real Stage/Scene documents currently being reviewed and archived.

Do not redesign the established Stage folder structure while solving Procedure resolution, QR integration, PDF publishing, or intranet UX.

## Related Systems

- [Testing System](../05_Testing_System/README.md) — establishes testing state/readiness before deployment.
- [Containers and Storage](../04_Containers_and_Storage/README.md) — owns container identity, assignments, storage-location relationships, and KIT container identity.
- [Wiring System](../09_Wiring_System/README.md) — provides the proven structured field-context implementation while retaining its own wiring content rules.
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md) — owns permanent labels and the accepted scan-routing integration pattern.
- [FieldWiring Scan Integration Engineering Handoff](../07_Labeling_and_Scanning/FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md) — accepted production Display scan baseline.
- [Scanner Hardware and Tablet Integration](../07_Labeling_and_Scanning/Scanner_Hardware_and_Tablet_Integration.md) — owns the purchased Zebra scanner baseline and hardware/browser-input acceptance contract.
- [People and Identity](../03_People_and_Identity/README.md) — provides durable person/user identity and audit attribution.
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md) — may provide destination/location context where applicable.

## Related Documentation

- [Procedure System Field Context Handoff — 2026-08-22](00_Procedure_System_Field_Context_Handoff_2026-08-22.md)
- [Stage Setup Documentation Standard](../../../../System_Documentation/Project_Rules/Stage_Setup_Documentation_Standard.md)
- [Stage Setup Instruction Template](../../../../System_Documentation/Templates/Stage_Setup_Instruction_Template.md)
- [Google Drive Document Organization Procedure](../../../00_Project_Overview/01-Google_Drive_Document_Organization_Procedure.md)
- [Field Context Resolution Contract](../07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)
- [FieldWiring Drive Context Resolver Engineering Design](../09_Wiring_System/FieldWiring_Drive_Context_Resolver_Engineering_Design.md)
- [Document Control Standard](../../../../System_Documentation/Standards/Document_Control_Standard.md)
- [Linking and Navigation Standard](../../../../System_Documentation/Standards/Linking_and_Navigation_Standard.md)

Repository Operational SOPs remain appropriate for database/application tasks in this subsystem when those tasks are implemented. They are not the storage or format model for the field-facing Stage Setup Instructions themselves.
