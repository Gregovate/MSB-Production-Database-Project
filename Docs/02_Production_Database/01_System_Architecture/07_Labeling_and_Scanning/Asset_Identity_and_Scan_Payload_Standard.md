# Asset Identity and Scan Payload Standard

## Purpose

This document preserves the durable identity, label, and scanning contracts from the original MSB Asset ID, Labeling, and Scanning plan while distinguishing implemented behavior from scanning work that is still planned or evolving.

## Core Rule

Machine-readable labels must identify an MSB asset by a durable Production Database identity. They must not depend on a copied Directus admin URL or other application-specific browser path that may change when the user interface changes.

The human-readable label and the machine-readable payload should identify the same physical asset without creating another competing identity system.

## Approved Canonical Payload Pattern

The approved machine-readable identifier pattern is:

`TYPE:KEY`

The original approved prefixes are:

| Asset Type | Prefix | Example |
|---|---|---|
| Container | `CONT` | `CONT:587` |
| Storage Location | `LOC` | `LOC:RA-01-A-03` |
| Display | `DISP` | `DISP:251` |
| Controller | `CTRL` | `CTRL:CL-042` |

Rules:

- use the stable internal Production Database identifier for Displays and Containers;
- use the operational location code for Storage Locations;
- controller identity must use the permanent Controller Inventory identity once that subsystem is implemented;
- do not use LOR UUIDs as Production asset identity;
- do not use single-letter prefixes for new machine-readable asset identifiers.

Before changing existing deployed label payloads, verify the current label templates and LabelPrintService implementation. This document records the approved identity contract; it does not assert that every planned asset type has already been deployed.

## QR Lookup Rule

A QR code used for record lookup must not encode a raw Directus admin URL such as a collection/bookmark path.

A stable application/redirect route may wrap the canonical asset identity so the eventual destination can change without requiring physical labels to be replaced.

For Displays, that design is now a verified deployed capability. The current production Directus scan extension on `msb-prod-db` implements a stable Display lookup hub including:

```text
/scan/
/scan/DISP/:key
/scan/DISP/:key/test
/scan/DISP/:key/container
/scan/DISP/:key/work-orders
```

`/scan/DISP/:key` resolves permanent `ref.display.display_id` and then presents task destinations. New Display field applications such as FieldWiring must extend that existing resolved-identity hub rather than creating another Display QR payload or lookup engine.

The broader `/scan/<TYPE>/<KEY>` concept still remains partly a design direction for asset types/workflows that have not been verified as deployed. Do not infer that Container, Location, or Controller scan behavior exists merely because Display scanning does.

See [Deployed Display Scan Runtime Boundary](Deployed_Display_Scan_Runtime_Boundary.md) for the verified Display implementation boundary.

## Current Label Quantities

The implemented operator contract currently includes:

- **Display:** 1 label per display
- **Container:** 2 labels per container

These quantities are handled by the printing system; operators should not have to manually create duplicate Container print requests.

Storage Location and Controller label quantities/designs remain subject to their current implementation state and must be verified before being documented as deployed behavior.

## Printing Boundary

Current printing architecture is:

**Production Database / Directus print request -> database batch/request state -> MSB_LabelPrintService -> physical printer**

The Production Database owns the asset identity and request state. The LabelPrintService owns rendering, printer communication, and print-service-specific runtime behavior.

The user should not need to export CSV files, open label-design software, choose templates, or perform printer-specific technical configuration for normal label printing.

## Print History and Reprint Design

The durable design requires enough history to distinguish a requested/attempted print from the physical belief that a usable label is present on the asset.

Important engineering goals from the original plan include:

- preserve print request/batch history;
- preserve who requested a batch;
- support intentional reprints;
- distinguish failed or partial printing from successful printing;
- avoid accidental duplicate printing.

The exact current database states and retry/reprint behavior must be verified against the current PostgreSQL objects and LabelPrintService implementation before changes are made.

## Scanning — Implemented and Planned Boundaries

The Display QR lookup hub is implemented and verified as described above.

Other scan-driven field workflows are not documented here as fully implemented simply because they were approved in the original plan.

The approved direction is to support both 1-D and 2-D scanning where the workflow benefits from them:

- Code 128 for fast logistics-style identification such as Containers and Storage Locations;
- QR where phone/tablet lookup or deeper record navigation is useful;
- rugged tablets as field display/workstation devices;
- cordless industrial scanners for forklift-distance workflows.

Planned workflow concepts include:

- scan Container -> show Home Location;
- scan Location -> show assigned Container(s);
- scan Location + Container -> validate whether the move/placement matches;
- support either scan order when the field application maintains temporary scan state.

These remain engineering directions for future scanning/application work until implemented and tested.

## Related Systems

- [Labeling and Scanning engineering handoff](README.md)
- [Deployed Display Scan Runtime Boundary](Deployed_Display_Scan_Runtime_Boundary.md)
- [Wiring System](../09_Wiring_System/README.md)
- [Containers and Storage](../04_Containers_and_Storage/README.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [Operational Label Printing SOPs](../../02_Operational_SOPs/Label_Printing/README.md)
