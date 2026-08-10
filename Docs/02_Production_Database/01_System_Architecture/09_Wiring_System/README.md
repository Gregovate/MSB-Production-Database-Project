# Wiring System

This subsystem documents how MSB presents, enriches, and operationally uses wiring information derived from LOR-authoritative show topology.

## Current State

FormView currently provides wiring presentation and generated field documentation from parser-produced SQLite data. Draw.io is also used for wiring diagrams. PostgreSQL contains wiring-related data derived from LOR snapshots.

The future Wiring application should use PostgreSQL as its operational data source rather than maintaining a second independent SQLite operational database. FormView remains important as the existing presentation implementation and must be inventoried before replacement or migration.

A dedicated PostgreSQL-backed Wiring application may live in a separate repository while the Production Database repository continues to own the database integration and authority contract.

The existing Stage-oriented folder structure is also part of the current documentation workflow. Wiring material and Setup/Takedown instructions use the same Stage folder/path convention so field documentation is organized around the physical area crews work in rather than split into unrelated document trees.

## Design Intent

Provide task-focused wiring documentation and field access without creating a second topology-authoring system.

The intended data path is:

```text
Light-O-Rama
    -> LOR2DB
        -> PostgreSQL Production Database
            -> Wiring application
```

## System Boundary

**Relationship Class:** Dedicated Database-Backed Presentation / Field Application over a Production Database subsystem with an Integrated Upstream Dependency on LOR/LOR2DB.

### Authority Boundary

LOR remains authoritative for:

- controller assignments
- channel numbers/ranges
- DMX/network assignments
- show wiring topology

LOR2DB is the controlled path that brings this topology into PostgreSQL.

PostgreSQL becomes the shared operational source used by the Wiring application and may add database-owned information such as permanent identities, inventory relationships, field notes, and other operational relationships.

FormView, PostgreSQL, Draw.io, and future Wiring applications consume, enrich, visualize, and present LOR-authoritative topology. They do not independently redefine it.

### Production Database responsibility

- storing the controlled LOR-derived wiring snapshot needed by downstream systems
- linking wiring information to permanent Production Database identities and related inventory
- preserving database-owned operational data and relationships
- providing the integration contract consumed by the Wiring application

### Dedicated Wiring application responsibility

- task-focused wiring lookup and presentation
- field-friendly navigation and documentation
- generated field views/documents as required
- application-specific API/client code
- application deployment, configuration, and tests

The Wiring application must not become an independent topology-authoring system and must not maintain a competing operational copy of wiring truth when PostgreSQL already provides the shared operational source.

If the Wiring application is unavailable, PostgreSQL and the imported LOR-derived data remain intact. Field users may temporarily lose the preferred presentation interface, but the shared Production Database data remains available to other systems.

## Stage Folder / Documentation Boundary

The existing Stage folder structure is the shared human-facing location for wiring and setup documentation. The Stage `folder_path` convention should remain the navigation anchor rather than creating separate unrelated paths for Wiring and Setup.

Wiring owns wiring content placed or referenced there. [Setup and Deployment](../12_Setup_and_Deployment/README.md) owns setup/takedown instructions placed or referenced in the same Stage-oriented structure. QR-based lookup may route field users to this material, but QR/scanning does not become the content authority.

## Dependencies

- [LOR2DB Ingest](../02_LOR2DB_Ingest/README.md)
- [Database Foundation](../01_Database_Foundation/README.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)

## Current Responsibilities

- field wiring presentation
- display/controller wiring lookup
- generated HTML/PDF field documentation
- links to schematics and supporting engineering information
- shared Stage-folder documentation convention with Setup and Deployment
- future task-focused wiring workflow/application

## Related Systems

- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md)
- [System Boundary and Repository Ownership Standard](../../../../System_Documentation/Standards/System_Boundary_and_Repository_Ownership_Standard.md)

## Resume Development

Before designing a replacement application, inventory current FormView behavior, parser-produced SQLite dependencies, PostgreSQL wiring fields/views, Draw.io artifacts, and LOR-derived topology.

Define the PostgreSQL-backed application data contract before changing FormView or building the replacement UI. Preserve the LOR authority boundary in every design decision.

When working on human-facing field documentation, preserve the existing Stage folder/path convention shared with Setup/Takedown documentation rather than creating a parallel folder system.

When the dedicated Wiring application is started, create or use its separate implementation repository and link it here. Keep the Production Database integration/authority contract in this subsystem and application implementation in the application repository.
