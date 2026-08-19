# Controller Inventory

This subsystem documents the permanent inventory and lifecycle of physical controller hardware.

## Current State

Controller inventory remains spreadsheet-based and has not yet been implemented as a PostgreSQL subsystem.

The 2025 working source has now been inspected directly from:

```text
Controller Inventory & Firmware 2025 - Inventory.csv
Controller Inventory & Firmware 2025 - Lookup Table.csv
```

The source is useful physical/deployment/firmware evidence, but it is not a finished current permanent asset register. Most populated inventory rows are still marked incomplete, current 2026 RGB hardware is missing in several areas, E1.31 rows include older IP/configuration evidence, and the source has no durable per-controller asset key independent of LOR addressing or deployment.

See [Controller Inventory 2025 Source Audit — 2026-08-19](Controller_Inventory_2025_Source_Audit_2026-08-19.md).

LOR identifies controllers used by current Previews, but LOR addressing likewise does not constitute permanent physical controller identity.

## Design Intent

Create durable controller identities and preserve lifecycle history independently of annual LOR assignments while linking physical controllers to the systems that use them.

## Current/Future Responsibilities

- permanent controller identity
- controller type and capabilities
- status and lifecycle
- deployment/location history
- current LOR addressing relationship without making LOR Unit ID the asset key
- E1.31/IP configuration relationships where applicable
- repair/history relationships
- labeling/scanning relationships
- relationships to Wiring, Network Infrastructure, Site Infrastructure/GIS, and Work Orders

## Boundaries

LOR remains authoritative for show controller assignments, channel numbers, DMX/network assignments, and show topology.

Controller Inventory tracks the physical hardware asset and its history. It must not become a competing LOR topology-authoring system.

Unit ID, Unit-ID range, network, IP address, Display assignment, and Park Location are deployment/configuration attributes. None should be assumed to be the permanent physical controller identity.

## Authoritative / Source Evidence

Current source evidence now includes:

- the 2025 Controller Inventory / Firmware CSV export;
- its companion controller-model / firmware lookup table;
- `DMX Control Addressing.xlsx` for historical/current E1.31 universe/output/IP mapping evidence; and
- current V7/PostgreSQL LOR topology for current show addressing.

These sources must be reconciled rather than silently merged. Current physical inventory and current LOR topology do not yet align perfectly in all areas.

## Related Systems

- [Controller Inventory and Labeling Plan](Controller_Inventory_and_Labeling_Plan.md)
- [Controller Inventory 2025 Source Audit — 2026-08-19](Controller_Inventory_2025_Source_Audit_2026-08-19.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Wiring System](../09_Wiring_System/README.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md)

## Resume Development

Do not design the final PostgreSQL schema from assumptions.

The next controller-inventory work is reconciliation: compare the 2025 inventory against current 2026 LOR/V7 topology and the E1.31 addressing workbook, identify missing/new controllers and source conflicts, normalize model terminology, then define permanent controller identity and deployment/history relationships.
