# Wiring System

This subsystem documents how MSB presents, enriches, and operationally uses wiring information derived from LOR-authoritative show topology.

## Current State

FormView currently provides wiring presentation and generated field documentation. Draw.io is also used for wiring diagrams. PostgreSQL contains wiring-related data derived from LOR snapshots. A dedicated PostgreSQL-backed wiring application is expected to replace or extend legacy presentation workflows as requirements mature.

## Design Intent

Provide task-focused wiring documentation and field access without creating a second topology-authoring system.

## Authority Boundary

LOR remains authoritative for:

- controller assignments
- channel numbers/ranges
- DMX/network assignments
- show wiring topology

FormView, PostgreSQL, Draw.io, and future Wiring applications consume, enrich, visualize, and present that topology. They do not independently redefine it.

## Dependencies

- [LOR2DB Ingest](../02_LOR2DB_Ingest/README.md)
- [Database Foundation](../01_Database_Foundation/README.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)

## Current Responsibilities

- field wiring presentation
- display/controller wiring lookup
- generated HTML/PDF field documentation
- links to schematics and supporting engineering information
- future task-focused wiring workflow/application

## Related Systems

- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md)

## Resume Development

Before designing a replacement application, inventory current FormView behavior, PostgreSQL wiring fields, Draw.io artifacts, and LOR-derived topology. Preserve the LOR authority boundary in every design decision.
