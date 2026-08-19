# Wiring System

This subsystem documents how MSB presents, enriches, and operationally uses wiring information derived from LOR-authoritative show topology.

## Current State

FormView currently provides wiring presentation and generated field documentation from parser-produced SQLite data. Draw.io is also used for wiring diagrams. PostgreSQL contains wiring-related data derived from LOR snapshots.

The active replacement/recovery sub-project is named **FieldWiring**. FieldWiring is intended to be a PostgreSQL-backed, browser-accessible field application, but implementation is gated on documenting and validating the proven FormView contract first.

Start with:

- [FieldWiring Engineering Recovery and Compatibility Contract](FieldWiring_Engineering_Recovery_and_Compatibility_Contract.md)
- [FieldWiring Drive Context Resolver Engineering Design](FieldWiring_Drive_Context_Resolver_Engineering_Design.md)
- [FieldWiring PostgreSQL Readiness Audit](FieldWiring_PostgreSQL_Readiness_Audit.md)
- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [FieldWiring Scene Scope and Offline Report Requirements](FieldWiring_Scene_Scope_and_Offline_Report_Requirements.md)
- [Shared Field Context Resolution Contract](../07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)
- [FormView Engineering Architecture](../../../01_LOR_System/04_FormView/FormView_Engineering_Architecture.md)

The shared Field Context resolver owns scan-to-Display/hierarchy resolution. FieldWiring consumes that resolved context after the operator chooses **Field Wiring**; it must not create a second QR/Stage/Scene resolution engine.

FormView remains an active transitional production application and must remain available until FieldWiring has proven the operational behavior it replaces and an explicit cutover is accepted.

FieldWiring should use PostgreSQL as its operational data source rather than maintaining a second independent SQLite operational database.

A dedicated PostgreSQL-backed FieldWiring application may live in a separate repository while the Production Database repository continues to own the database integration and authority contract.

The existing Stage-oriented folder structure is also part of the current documentation workflow. Wiring material and Setup/Takedown instructions use the same Stage-oriented convention already used by field documentation so field information is organized around the physical area crews work in rather than split into unrelated document trees.

## Design Intent

Provide task-focused wiring documentation and field access without creating a second topology-authoring system.

The intended data path is:

```text
Display QR
    -> shared Field Context resolver
        -> operator chooses Field Wiring
            -> PostgreSQL Production Database wiring contract
                -> FieldWiring
                    -> browser / tablet / phone
                    -> self-contained offline HTML when needed
```

When the resolved Display belongs to a defined Scene, the normal FieldWiring package should be Scene scoped: the same Scene wiring rows and Scene wiring image set are presented regardless of which Display in that Scene was scanned. Multiple images within that Scene remain paginated. Displays without a defined Scene use the controlled Sub-stage/Stage fallback.

LOR remains the upstream authority for wiring topology and enters PostgreSQL through the controlled LOR2DB pipeline.

## System Boundary

**Relationship Class:** Dedicated Database-Backed Presentation / Field Application over a Production Database subsystem with an Integrated Upstream Dependency on LOR/LOR2DB.

### Authority Boundary

LOR remains authoritative for:

- controller assignments
- channel numbers/ranges
- DMX/network assignments
- show wiring topology

LOR2DB is the controlled path that brings this topology into PostgreSQL.

PostgreSQL becomes the shared operational source used by FieldWiring and may add database-owned information such as permanent identities, inventory relationships, field notes, and other operational relationships.

FormView, PostgreSQL, Draw.io, and FieldWiring consume, enrich, visualize, and present LOR-authoritative topology. They do not independently redefine it.

### Production Database responsibility

- storing the controlled LOR-derived wiring snapshot needed by downstream systems
- linking wiring information to permanent Production Database identities and related inventory
- preserving database-owned operational data and relationships
- providing the integration contract consumed by FieldWiring

### FieldWiring application responsibility

- task-focused wiring lookup and presentation after shared scan/context resolution
- field-friendly browser navigation and documentation
- Scene-aware wiring/image scoping with controlled Stage/Sub-stage fallback
- physical-controller/output presentation that does not expose raw LOR addressing as though it were always the physical hookup model
- multiple-image paging within the resolved wiring scope
- generated field views/documents as required
- self-contained offline HTML suitable for disconnected field use
- conspicuous generation/currentness and hard-copy expiration information
- application-specific API/client code
- application deployment, configuration, and tests

FieldWiring must not become an independent topology-authoring system and must not maintain a competing operational copy of wiring truth when PostgreSQL already provides the shared operational source.

If FieldWiring is unavailable, PostgreSQL and the imported LOR-derived data remain intact. During the transition, FormView also remains available as the proven field-wiring fallback until its replaced functions are formally accepted in FieldWiring.

## Stage Folder / Documentation Boundary

The existing Stage folder structure is the shared human-facing location for wiring and setup documentation. The Stage `folder_path` convention should remain the navigation anchor rather than creating separate unrelated paths for Wiring and Setup.

Wiring owns wiring content placed or referenced there. [Setup and Deployment](../12_Setup_and_Deployment/README.md) owns setup/takedown instructions placed or referenced in the same Stage-oriented structure. [Labeling and Scanning](../07_Labeling_and_Scanning/README.md) owns the scan/payload boundary and shared field-context resolution contract. QR/scanning does not become the content authority.

## Dependencies

- [LOR2DB Ingest](../02_LOR2DB_Ingest/README.md)
- [Database Foundation](../01_Database_Foundation/README.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)

## Current Responsibilities

- field wiring presentation
- display/controller wiring lookup
- physical-output presentation for conventional A/C and RGB/Pixie controller models
- Scene-aware field package resolution
- generated HTML/PDF field documentation
- disconnected/offline field-document support
- links to schematics and supporting engineering information
- shared Stage-folder documentation convention with Setup and Deployment
- FieldWiring recovery, data-contract definition, and future task-focused browser workflow

## Related Systems

- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md)
- [System Boundary and Repository Ownership Standard](../../../../System_Documentation/Standards/System_Boundary_and_Repository_Ownership_Standard.md)

## Resume Development

The FormView architecture has now been recovered into the FieldWiring compatibility contract, the repository-defined PostgreSQL wiring layer has been compared against the current V7 parser, scan-to-Display/hierarchy behavior is owned by the shared Field Context Resolution contract, Scene-aware image/report behavior is captured in the FieldWiring presentation requirements, and the V7+ Scene `BackgroundFile` navigation-pointer model is now captured in the [FieldWiring Drive Context Resolver Engineering Design](FieldWiring_Drive_Context_Resolver_Engineering_Design.md).

The Drive resolver has demonstrated current marked-folder discovery and live wiring-image pickup. The next field-presentation work must preserve the reduced field wiring data while translating raw LOR addressing into physical controller/output terms. In particular, [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md) records that current V7 `string_type` distinguishes conventional `Traditional` LOR hookup from `RGB` Pixie/pixel hookup, while Controller Inventory remains necessary for permanent physical-controller identity and authoritative grouping of address ranges across Displays.

After the resolver gate, verify the **live** PostgreSQL objects that satisfy the read contract, define the read-only application data/query surface, and define how the resolved Google Drive wiring images will be securely served to browsers and embedded in offline exports.

Do not change FormView or database schema merely to simplify the browser implementation. Preserve the LOR authority boundary and demonstrate any real schema gap before proposing a migration.

When working on human-facing field documentation, preserve the existing Stage folder/path convention shared with Setup/Takedown documentation rather than creating a parallel folder system.

When the dedicated FieldWiring application implementation is started, create or use its separate implementation repository if that remains the selected boundary and link it here. Keep the Production Database integration/authority contract in this subsystem and application implementation in the application repository.
