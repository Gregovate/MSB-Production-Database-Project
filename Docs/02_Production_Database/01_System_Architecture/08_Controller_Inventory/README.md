# Controller Inventory

This subsystem documents the permanent inventory and lifecycle of physical controller hardware.

## Current State

Controller inventory remains primarily spreadsheet-based and has not yet been fully implemented as a PostgreSQL subsystem. LOR identifies controllers used by previews, but that does not constitute a complete physical controller inventory.

## Design Intent

Create durable controller identities and preserve lifecycle history independently of annual LOR assignments while linking physical controllers to the systems that use them.

## Current/Future Responsibilities

- permanent controller identity
- controller type and capabilities
- status and lifecycle
- deployment/location history
- repair/history relationships
- labeling/scanning relationships
- relationships to Wiring, Network Infrastructure, Site Infrastructure/GIS, and Work Orders

## Boundaries

LOR remains authoritative for show controller assignments, channel numbers, DMX/network assignments, and show topology. Controller Inventory tracks the physical hardware asset and its history; it must not become a competing LOR topology-authoring system.

## Authoritative Sources

The current controller inventory spreadsheet is an important source artifact until PostgreSQL implementation replaces it as the durable inventory authority. Existing controller inventory/labeling documentation must be reconciled into this subsystem.

## Related Systems

- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Wiring System](../09_Wiring_System/README.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md)

## Resume Development

Do not design the final PostgreSQL schema from assumptions. Inventory the current spreadsheet fields, existing relationships, and physical workflow first, then establish permanent identity and lifecycle requirements.
