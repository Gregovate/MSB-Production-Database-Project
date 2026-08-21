# Wiring System

This subsystem documents how MSB presents, enriches, and operationally uses wiring information derived from LOR-authoritative show topology.

## Current State

FormView currently provides wiring presentation and generated field documentation from parser-produced SQLite data. Draw.io is also used for wiring diagrams. PostgreSQL contains wiring-related data derived from LOR snapshots.

The active replacement/recovery sub-project is named **FieldWiring**. FieldWiring is intended to be a PostgreSQL-backed, browser-accessible field application that preserves the proven field outcome while improving Scene awareness, Google Drive document resolution, and physical hookup presentation.

Dense-RGB engineering recovery has now proven one parser data-preservation gap before the browser presentation layer can be considered complete: grouped DMX rows retain the canonical Display/master relationship but do not currently retain the originating LOR PropClass/Channel Name and local Channel Grid Row Number for every `dmxChannels` row. The exact additive change boundary is documented and **V7.0.10 remains unchanged**. A grouped-DMX baseline regression fixture has been added, but it must be run successfully against unchanged V7.0.10 before the parser/schema is modified.

Start with:

- [FieldWiring Engineering Recovery and Compatibility Contract](FieldWiring_Engineering_Recovery_and_Compatibility_Contract.md)
- [FieldWiring Dense RGB Parser Extension Checkpoint](FieldWiring_Dense_RGB_Parser_Extension_Checkpoint_2026-08-21.md)
- [FieldWiring Dense RGB DMX Additive Change Map](FieldWiring_Dense_RGB_DMX_Additive_Change_Map_2026-08-21.md)
- [Grouped-DMX V7.0.10 Regression Test](../../../01_LOR_System/02_Data_Extraction/Parser/test_parse_props_grouped_dmx.py)
- [LOR XML to MSB Terminology Contract](../../../01_LOR_System/02_Data_Extraction/LOR_XML_to_MSB_Terminology_Contract.md)
- [FieldWiring Drive Context Resolver Engineering Design](FieldWiring_Drive_Context_Resolver_Engineering_Design.md)
- [FieldWiring PostgreSQL Readiness Audit](FieldWiring_PostgreSQL_Readiness_Audit.md)
- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [FieldWiring DMX / DumbRGB Field Presentation Contract](FieldWiring_DMX_DumbRGB_Field_Presentation_Contract.md)
- [FieldWiring E1.31 Dense RGB Field Presentation Contract](FieldWiring_E131_Dense_RGB_Field_Presentation_Contract.md)
- [FieldWiring Channel / Plug Label Printing Requirements](FieldWiring_Channel_Plug_Label_Printing_Requirements.md)
- [FieldWiring Scene Scope and Offline Report Requirements](FieldWiring_Scene_Scope_and_Offline_Report_Requirements.md)
- [Shared Field Context Resolution Contract](../07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)
- [Deployed Display Scan Runtime Boundary](../07_Labeling_and_Scanning/Deployed_Display_Scan_Runtime_Boundary.md)
- [FormView Engineering Architecture](../../../01_LOR_System/04_FormView/FormView_Engineering_Architecture.md)

The shared Field Context resolver owns scan-to-Display/hierarchy resolution. FieldWiring consumes that resolved context after the operator chooses **Field Wiring**; it must not create a second QR/Stage/Scene resolution engine.

The Display QR entry point is already a deployed production capability. A Directus endpoint extension on `msb-prod-db` under `/opt/directus/extensions/directus-extension-scan/` resolves the permanent `display_id` and presents the existing Display scan hub. FieldWiring is a downstream consumer of that working scan result, not a replacement for it. Server runtime/deployment/recovery documentation is cross-referenced to the separate [MSB-Server-Management](https://github.com/Gregovate/MSB-Server-Management) project.

FormView remains a transitional production application until FieldWiring has proven the operational behavior it replaces and an explicit cutover is accepted.

FieldWiring should use PostgreSQL as its operational data source rather than maintaining a second independent SQLite operational database.

## Design Intent

Provide task-focused field hookup information without creating a second topology-authoring system.

The intended data path is:

```text
Existing Display QR / operator lookup
    -> existing authenticated Display scan hub
        -> permanent display_id
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

**Relationship Class:** Dedicated Database-Backed Presentation / Field Application over a Production Database subsystem with an Integrated Upstream Dependency on LOR/LOR2DB and an Existing Deployed Scan-Runtime Dependency.

### Authority Boundary

LOR remains authoritative for:

- controller and addressing assignments;
- channel numbers/ranges;
- DMX/E1.31/network assignments; and
- show wiring topology.

PostgreSQL provides the shared operational snapshot used by FieldWiring and may add database-owned permanent identities, controller inventory relationships, field notes, and other operational relationships.

FieldWiring interprets and presents that topology. It does not independently redefine it.

### Existing Display scan runtime

The current Display QR lookup is already implemented outside FieldWiring as a deployed Directus endpoint on `msb-prod-db`.

FieldWiring must consume the permanent `display_id` resolved by that existing scan hub and add Field Wiring as a downstream task destination. It must not create a competing QR payload, scanner route, or duplicate Testing/Work Order scan logic.

See [Deployed Display Scan Runtime Boundary](../07_Labeling_and_Scanning/Deployed_Display_Scan_Runtime_Boundary.md) for the cross-repository boundary. The live server/runtime is inspected and documented through [MSB-Server-Management](https://github.com/Gregovate/MSB-Server-Management), whose engineering workflow includes SSH inspection of live `/opt/...` application directories.

### Production Database responsibility

- storing the controlled LOR-derived wiring snapshot needed by downstream systems;
- linking wiring information to permanent Production Database identities and related inventory;
- preserving database-owned operational data and relationships; and
- providing the integration contract consumed by FieldWiring.

### FieldWiring application responsibility

- task-focused hookup lookup and presentation after shared context resolution;
- Stage/Sub-stage/Scene-aware data and image scoping;
- device-family-aware physical hookup presentation;
- controlled channel/plug label requests sourced from current wiring data;
- multiple-image paging within the resolved wiring scope;
- field-friendly browser navigation and documentation;
- self-contained offline HTML suitable for disconnected field use;
- conspicuous generation/currentness and hard-copy expiration information; and
- application-specific API/client code, deployment, configuration, and tests.

FieldWiring must not become an independent topology-authoring system.

Printer-specific rendering and Brother printer communication remain responsibilities of the existing Labeling / MSB_LabelPrintService subsystem rather than a second printer implementation inside FieldWiring.

## Stage Folder / Documentation Boundary

The established Stage/Sub-stage/Scene Google Drive structure remains the human-facing source for published wiring images and related field documentation.

The common Drive resolver identifies the structured scope. The FieldWiring adapter then inspects only the applicable same-scope published Wiring branch. It must not borrow a parent Stage wiring image for a resolved Scene/Sub-stage merely because the more-specific wiring image is missing.

Wiring images are supplemental rough-location guidance. The hookup data remains the primary product and must stay usable when no image exists.

## Dependencies

- [LOR2DB Ingest](../02_LOR2DB_Ingest/README.md)
- [Database Foundation](../01_Database_Foundation/README.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Deployed Display Scan Runtime Boundary](../07_Labeling_and_Scanning/Deployed_Display_Scan_Runtime_Boundary.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [MSB-Server-Management](https://github.com/Gregovate/MSB-Server-Management) for deployed server/runtime administration and recovery documentation

## Current Responsibilities

- field wiring/hookup presentation;
- display/controller/network lookup;
- Scene-aware field package resolution;
- physical-output interpretation for A/C and Pixie controllers;
- DMX/DumbRGB presentation that does not confuse universe/channel addressing with physical plugs;
- E1.31 dense RGB presentation that does not confuse universes with physical AlphaPix/PixCon controllers;
- future controlled channel/plug label printing through LabelPrintService without hand-keying Channel Names;
- generated HTML/PDF field documentation;
- disconnected/offline field-document support; and
- FieldWiring recovery, data-contract definition, and future task-focused browser workflow.

## Related Systems

- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md)
- [MSB-Server-Management](https://github.com/Gregovate/MSB-Server-Management)
- [System Boundary and Repository Ownership Standard](../../../../System_Documentation/Standards/System_Boundary_and_Repository_Ownership_Standard.md)

## Resume Development

The FormView architecture has been recovered, the V7/PostgreSQL wiring layer has been compared against known FormView output, and the V7+ Scene `BackgroundFile` navigation model has been proven against the controlled Google Drive hierarchy.

The Drive image-discovery mechanism is working: current images added to marked `Wiring\BackgroundStage` or `Wiring\MusicalStage` source locations become visible to the resolver without a parser/database update.

The current Display QR entry is also verified as an existing production dependency. Do not redesign it. FieldWiring should extend the existing Display scan hub after the live scan-extension baseline and its server-management documentation are preserved.

Dense-RGB inspection has established and documented the current grouped-DMX information-loss boundary. V7.0.10 still preserves the correct canonical Display/master relationship, but each `dmxChannels` row does not currently preserve the originating LOR Prop ID, Channel Name, and local Channel Grid Row Number. The proposed extension is additive only and is not yet implemented.

A grouped-DMX baseline regression fixture now exists at `Docs/01_LOR_System/02_Data_Extraction/Parser/test_parse_props_grouped_dmx.py`. It freezes the existing eight-column DMX schema, canonical master relationship, legacy DMX rows, and FormView-compatible view output while recording the expected future source-detail mapping. The fixture has not yet produced a passing CI/connector execution result.

Current engineering focus is therefore **execute the V7.0.10 grouped-DMX baseline test before parser modification**:

1. run `test_parse_props_grouped_dmx.py` against unchanged V7.0.10 and require PASS;
2. if the fixture fails, review/fix the fixture or architecture rather than altering the parser to force a pass;
3. only after baseline PASS, add `RawPropID`, `ChannelName`, and `ChannelGridRowNumber` to `dmxChannels` exactly as documented in the change map;
4. preserve every frozen legacy `PropId`, row-count, universe/channel, Scene, and compatibility-view expectation while adding the new source-detail assertions;
5. validate a new SQLite snapshot directly against Mega Star, Mega Cube, Mega Tree, and Whoville Matrix;
6. preserve the existing PostgreSQL reconciliation identity path and propagate new DMX fields to `lor_snap` only after SQLite acceptance;
7. resume the operator read/presentation layer using the accepted dense-RGB source detail;
8. reuse the existing authenticated Display scan hub and permanent `display_id` entry;
9. resolve the correct Stage/Sub-stage/Scene and Background/Musical context;
10. classify the physical presentation family from current device/string metadata and Controller Inventory relationships; and
11. preserve the future Channel Name -> 1/2-inch plug-label workflow as a controlled LabelPrintService integration rather than a manual printer-software task.

Current acceptance examples include Church A/C + Pixie patterns, Candyland repeated Pixie 4 blocks, Who Forest Pixie 8 blocks, Santa's Workshop Pixie 8 blocks, Northern Lights as the first DMX/DumbRGB network-hookup case, and the dense RGB E1.31 cases: Mega Tree, Mega Ball, Mega Cube, Mega Star, and Mt. Crumpit Matrix.

Do not change FormView or the existing Display QR identity. The dense-RGB parser source-preservation gap is now a demonstrated schema need, but it must not be used as justification for a broader parser, PostgreSQL, reconciliation, or browser redesign. Keep the change additive and prove it at each boundary before propagation.
