# Wiring System

This subsystem documents how MSB presents, enriches, and operationally uses wiring information derived from LOR-authoritative show topology.

## Current State

FormView currently provides wiring presentation and generated field documentation from parser-produced SQLite data. Draw.io is also used for wiring diagrams. PostgreSQL contains wiring-related data derived from LOR snapshots.

The active replacement/recovery sub-project is named **FieldWiring**. FieldWiring is intended to be a PostgreSQL-backed, browser-accessible field application that preserves the proven field outcome while improving Scene awareness, Google Drive document resolution, and physical hookup presentation.

Start with:

- [FieldWiring Engineering Recovery and Compatibility Contract](FieldWiring_Engineering_Recovery_and_Compatibility_Contract.md)
- [FieldWiring Drive Context Resolver Engineering Design](FieldWiring_Drive_Context_Resolver_Engineering_Design.md)
- [FieldWiring PostgreSQL Readiness Audit](FieldWiring_PostgreSQL_Readiness_Audit.md)
- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [FieldWiring DMX / DumbRGB Field Presentation Contract](FieldWiring_DMX_DumbRGB_Field_Presentation_Contract.md)
- [FieldWiring E1.31 Dense RGB Field Presentation Contract](FieldWiring_E131_Dense_RGB_Field_Presentation_Contract.md)
- [FieldWiring Scene Scope and Offline Report Requirements](FieldWiring_Scene_Scope_and_Offline_Report_Requirements.md)
- [Shared Field Context Resolution Contract](../07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)
- [FormView Engineering Architecture](../../../01_LOR_System/04_FormView/FormView_Engineering_Architecture.md)

The shared Field Context resolver owns scan-to-Display/hierarchy resolution. FieldWiring consumes that resolved context after the operator chooses **Field Wiring**; it must not create a second QR/Stage/Scene resolution engine.

FormView remains a transitional production application until FieldWiring has proven the operational behavior it replaces and an explicit cutover is accepted.

FieldWiring should use PostgreSQL as its operational data source rather than maintaining a second independent SQLite operational database.

## Design Intent

Provide task-focused field hookup information without creating a second topology-authoring system.

The intended data path is:

```text
Display QR / operator lookup
    -> shared Field Context resolver
        -> operator chooses Field Wiring
            -> current PostgreSQL/LOR wiring contract
                -> device-family presentation
                    -> browser / tablet / phone
                    -> self-contained offline HTML when needed
```

FieldWiring must translate technical topology into the physical connection model the installer sees.

Current accepted presentation families include:

```text
Traditional LOR
    -> conventional A/C controller / numbered output

RGB LOR
    -> Pixie controller / numbered RGB output

DMX + DumbRGB
    -> DMX network / fixture hookup

DMX + RGB — reviewed dense RGB cases
    -> E1.31 network / intelligent pixel-controller hookup
```

The generic compatibility-view `Controller` and `StartChannel` columns do not have one universal physical meaning across these families.

In particular, the current parser uses DMX/universe materialization for both the reviewed DumbRGB/DMX fixture cases and the reviewed dense RGB/E1.31 cases. FieldWiring must use the current device/string metadata plus physical controller relationships to distinguish the field task.

LOR remains the upstream authority for show topology and enters PostgreSQL through the controlled LOR2DB pipeline.

## System Boundary

**Relationship Class:** Dedicated Database-Backed Presentation / Field Application over a Production Database subsystem with an Integrated Upstream Dependency on LOR/LOR2DB.

### Authority Boundary

LOR remains authoritative for:

- controller and addressing assignments;
- channel numbers/ranges;
- DMX/E1.31/network assignments; and
- show wiring topology.

PostgreSQL provides the shared operational snapshot used by FieldWiring and may add database-owned permanent identities, controller inventory relationships, field notes, and other operational relationships.

FieldWiring interprets and presents that topology. It does not independently redefine it.

### Production Database responsibility

- storing the controlled LOR-derived wiring snapshot needed by downstream systems;
- linking wiring information to permanent Production Database identities and related inventory;
- preserving database-owned operational data and relationships; and
- providing the integration contract consumed by FieldWiring.

### FieldWiring application responsibility

- task-focused hookup lookup and presentation after shared context resolution;
- Stage/Sub-stage/Scene-aware data and image scoping;
- device-family-aware physical hookup presentation;
- multiple-image paging within the resolved wiring scope;
- field-friendly browser navigation and documentation;
- self-contained offline HTML suitable for disconnected field use;
- conspicuous generation/currentness and hard-copy expiration information; and
- application-specific API/client code, deployment, configuration, and tests.

FieldWiring must not become an independent topology-authoring system.

## Stage Folder / Documentation Boundary

The established Stage/Sub-stage/Scene Google Drive structure remains the human-facing source for published wiring images and related field documentation.

The common Drive resolver identifies the structured scope. The FieldWiring adapter then inspects only the applicable same-scope published Wiring branch. It must not borrow a parent Stage wiring image for a resolved Scene/Sub-stage merely because the more-specific wiring image is missing.

Wiring images are supplemental rough-location guidance. The hookup data remains the primary product and must stay usable when no image exists.

## Dependencies

- [LOR2DB Ingest](../02_LOR2DB_Ingest/README.md)
- [Database Foundation](../01_Database_Foundation/README.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)

## Current Responsibilities

- field wiring/hookup presentation;
- display/controller/network lookup;
- Scene-aware field package resolution;
- physical-output interpretation for A/C and Pixie controllers;
- DMX/DumbRGB presentation that does not confuse universe/channel addressing with physical plugs;
- E1.31 dense RGB presentation that does not confuse universes with physical AlphaPix/PixCon controllers;
- generated HTML/PDF field documentation;
- disconnected/offline field-document support; and
- FieldWiring recovery, data-contract definition, and future task-focused browser workflow.

## Related Systems

- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md)
- [System Boundary and Repository Ownership Standard](../../../../System_Documentation/Standards/System_Boundary_and_Repository_Ownership_Standard.md)

## Resume Development

The FormView architecture has been recovered, the V7/PostgreSQL wiring layer has been compared against known FormView output, and the V7+ Scene `BackgroundFile` navigation model has been proven against the controlled Google Drive hierarchy.

The Drive image-discovery mechanism is working: current images added to marked `Wiring\BackgroundStage` or `Wiring\MusicalStage` source locations become visible to the resolver without a parser/database update.

Current engineering focus is now the **operator read/presentation layer**:

1. keep current V7 wiring/topology data authoritative;
2. resolve the correct Stage/Sub-stage/Scene and Background/Musical context;
3. classify the physical presentation family from current device/string metadata;
4. translate raw topology into the hookup terms the field installer sees;
5. keep raw Unit ID, DMX/E1.31 universe/channel, Source, DeviceType, and similar engineering values available under details; and
6. integrate permanent Controller Inventory identities later without blocking current FieldWiring development.

Current acceptance examples include Church A/C + Pixie patterns, Candyland repeated Pixie 4 blocks, Who Forest Pixie 8 blocks, Santa's Workshop Pixie 8 blocks, Northern Lights as the first DMX/DumbRGB network-hookup case, and the dense RGB E1.31 cases: Mega Tree, Mega Ball, Mega Cube, Mega Star, and Mt. Crumpit Matrix.

Do not change FormView or database schema merely to simplify the browser implementation. Demonstrate any real schema gap before proposing a migration.
