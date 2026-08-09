# Labeling and Scanning

This subsystem documents permanent asset labeling, QR/barcode payloads, label-printing integration, scan behavior, and scanner/tablet workflows.

## Current State

Display and container label printing is an implemented production capability used to connect physical assets to Production Database records. Scanning and field workflows continue to evolve.

## Design Intent

Labels must use durable Production Database identities rather than brittle application-specific URLs. Printing and scanning should remain usable by non-technical volunteers while preserving traceability and reprint control.

## Dependencies

- [Database Foundation](../01_Database_Foundation/README.md)
- [Containers and Storage](../04_Containers_and_Storage/README.md)
- [People and Identity](../03_People_and_Identity/README.md) for authenticated operations where applicable

## Current Responsibilities

- asset ID/payload conventions
- display/container/storage-location labels
- label-printing service integration
- print/reprint state and history
- QR/barcode lookup behavior
- scanner and rugged-tablet integration
- forklift/field scan workflows

## Authoritative Sources

Current LabelPrintService/application behavior, current database objects, and current field workflows are implementation truth. The legacy `H_Asset_ID_Labeling_and_Scanning_Plan.md` and existing labeling/scanning folders must be reconciled into this subsystem before archival/removal.

## Related Systems

- [Containers and Storage](../04_Containers_and_Storage/README.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [Operational SOPs](../../02_Operational_SOPs/README.md)

## Resume Development

Reconcile current implemented label printing first, then scanner/tablet workflows. Preserve valid machine-readable identity contracts while removing obsolete Directus-specific assumptions.
