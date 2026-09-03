# Asset Identity and Scan Payload Standard

## Purpose

This document preserves the durable identity, label, and scanning contracts for MSB assets and locations while distinguishing implemented behavior from workflows that are still planned or evolving.

## Core Rule

Machine-readable labels must identify an MSB asset or discrete operational location by a durable Production Database identity. They must not depend on a copied Directus admin URL, annual workflow state, or another application-specific destination that may change.

The human-readable label and machine-readable payload should identify the same object without creating another competing identity system.

## Approved Canonical Payload Pattern

The approved machine-readable identifier pattern is:

`TYPE:KEY`

Current approved prefixes include:

| Object Type | Prefix | Example |
|---|---|---|
| Container | `CONT` | `CONT:587` |
| Storage Location | `LOC` | `LOC:RA-01-A-03` |
| Display | `DISP` | `DISP:251` |
| Controller | `CTRL` | `CTRL:1014` |

Rules:

- use the stable internal Production Database identifier for Displays and Containers;
- use the operational location code for labeled discrete Storage Locations;
- controller identity uses permanent `ref.controller.controller_id` from the deployed Controller Inventory;
- do not use LOR UUIDs as Production asset identity;
- do not use raw GPS coordinates as a permanent location identity;
- do not use single-letter prefixes for new machine-readable identifiers.

Before changing existing deployed label payloads, verify the current label templates and LabelPrintService implementation. This document records the approved identity contract; it does not assert that every planned object type has already been deployed.

## Container-First Compact Payload Migration

The first approved migration from deployed full scan URLs to the canonical `TYPE:KEY` payload is **Container labels**.

Operational reason:

```text
phone camera
    full https://db.sheboyganlights.org/... QR
    -> convenient because the camera can open the browser route directly

Zebra Bluetooth HID scanner
    full URL
    -> slow because every URL character is transmitted as keyboard input

Zebra Bluetooth HID scanner
    CONT:587
    -> much shorter/faster keyboard input
```

Containers are expected to be the highest-volume Setup scanning workflow, so newly printed/replacement Container labels migrate first to:

```text
CONT:<container_id>
```

Examples:

```text
CONT:216
CONT:587
```

Migration rules:

- existing deployed Container labels containing full `https://db.sheboyganlights.org/scan/CONT/<id>` URLs remain valid and must continue to resolve;
- there is no mass-relabel requirement solely to convert existing Container labels;
- LabelPrintService v4 is the first print path approved to use compact `CONT:<container_id>` for newly printed/replacement Container QR labels;
- LabelPrintService v3.4 rollback retains its existing full-URL Container payload behavior;
- Display QR payloads remain full scan URLs for now; a Display compact-payload migration requires a separate accepted decision because direct phone-camera opening remains useful for Display labels;
- the Scan workflow must resolve full-URL and compact Container inputs to the same durable Container identity and business workflow;
- scanner-side formatting may optimize legacy full-URL labels, but scanner configuration must not become the only authority for the Container identity rule.

This is a staged physical-payload migration only. The durable Container identity remains the same Production Database `container_id`.

## Controller QR Wrapper and Compact HID Input

The canonical Controller identifier is:

```text
CTRL:<controller_id>
```

The accepted new Controller QR payload wraps that permanent identity in the stable Scan route so a phone/tablet camera can open it directly:

```text
https://db.sheboyganlights.org/scan/CTRL/<controller_id>
```

The Zebra ADF emits the compact value `CTRL:<controller_id>` instead of typing the full URL. Manual entry may use the compact value or the supported full Scan URL. Both forms must converge on `/scan/CTRL/<controller_id>` and then hand the identity to the existing Controller Inventory:

```text
https://my.sheboyganlights.org/fieldwiring/controllers?controller_id=<controller_id>
```

The URL is a replaceable Scan wrapper, not a second identity. Controller Inventory owns Controller details/actions; Scan does not duplicate that application. The route remains subject to production deployment and real-label acceptance before Controller labels are printed in volume.

## Storage Location Versus Park GIS Location

`LOC:<location_code>` is the approved machine-readable pattern for **discrete labeled operational locations**, especially workshop/rack/storage locations.

A park destination does not automatically require a physical `LOC:` label.

Park placement is expected to use a durable site/location identity owned with the Site Infrastructure/GIS and Setup/Deployment contracts, with GPS coordinates as spatial evidence/context.

Important distinction:

```text
Workshop rack position
    -> discrete Production Database Storage Location
    -> LOC:<location_code> label is appropriate

Park destination
    -> durable site/location identity
    -> GIS/reference coordinates
    -> mobile GPS/proximity context where operationally useful
```

Raw latitude/longitude must not become the physical QR/barcode payload merely because the park workflow uses GPS.

## QR Lookup Rule

A QR code used for record lookup must not encode a raw Directus admin URL such as a collection/bookmark path.

A stable application/redirect route may wrap the canonical asset identity so the eventual destination can change without requiring physical labels to be replaced.

For Displays, that design is a verified deployed capability. The current production Directus scan extension on `msb-prod-db` implements a stable Display lookup hub including:

```text
/scan/
/scan/DISP/:key
/scan/CONT/:key
/scan/DISP/:key/test
/scan/DISP/:key/container
/scan/DISP/:key/work-orders
```

`/scan/DISP/:key` resolves permanent `ref.display.display_id` and then presents task destinations. New Display field applications such as FieldWiring must extend that existing resolved-identity hub rather than creating another Display QR payload or lookup engine.

The Container route is also deployed and opens the authoritative Directus Container record, where assigned Displays are available. The `CTRL` route and Controller Inventory search handoff are implemented in the current Git source candidate but are not production behavior until deployed and physically accepted. `LOC` and broader Setup movement behavior remain future work; do not infer that they exist merely because Display and Container scanning work.

See [Deployed Display Scan Runtime Boundary](Deployed_Display_Scan_Runtime_Boundary.md) for the verified Display implementation boundary.

## Current Label Quantities

The implemented operator contract currently includes:

- **Display:** 1 label per display;
- **Container:** 2 labels per container.

These quantities are handled by the printing system; operators should not have to manually create duplicate Container print requests.

Storage Location and Controller label quantities/designs remain subject to their current implementation state and must be verified before being documented as deployed behavior.

## Printing Boundary

Current printing architecture is:

**Production Database / Directus print request -> database batch/request state -> MSB_LabelPrintService -> physical printer**

The Production Database owns the asset identity and request state. The LabelPrintService owns rendering, printer communication, and print-service-specific runtime behavior.

The user should not need to export CSV files, open label-design software, choose templates, or perform printer-specific technical configuration for normal label printing.

## Print History and Reprint Design

The durable design requires enough history to distinguish a requested/attempted print from the physical belief that a usable label is present on the asset.

Important engineering goals include:

- preserve print request/batch history;
- preserve who requested a batch;
- support intentional reprints;
- distinguish failed or partial printing from successful printing;
- avoid accidental duplicate printing.

The exact current database states and retry/reprint behavior must be verified against the current PostgreSQL objects and LabelPrintService implementation before changes are made.

## Scanning — Implemented and Planned Boundaries

The Display QR lookup hub is implemented and verified as described above.

Other scan-driven field workflows are not documented here as fully implemented simply because they are approved directions.

The approved direction is to support both 1-D and 2-D scanning where the workflow benefits from them:

- Code 128 for fast logistics-style identification such as Containers and labeled Storage Locations;
- QR where phone/tablet lookup or deeper record navigation is useful;
- rugged tablets as field display/workstation devices;
- cordless industrial scanners for high-volume workshop/forklift workflows;
- mobile GPS/site context for park placement where scanning a physical location label is not appropriate.

Planned workshop workflow concepts include:

- scan Container -> show Home Location;
- scan Location -> show assigned Container(s);
- scan Location + Container -> validate whether the relationship matches;
- support either scan order when the field application maintains temporary scan state.

Planned park workflow concepts are different:

- scan Display or Container when asset confirmation is needed;
- resolve its expected park destination;
- use GPS/map context to guide or validate placement;
- retain Setup/Deployment as the owner of the actual movement/delivery/install state transition.

These remain engineering directions until implemented and accepted.

## Input-Method Independence

The business resolver must not depend on how an identifier was captured.

For example:

```text
Zebra HID scan of CONT:587
manual entry of CONT:587
camera scan resolving CONT:587
```

must identify the same Container and enter the same business workflow.

The same rule applies during the Container payload migration:

```text
legacy full URL for Container 587
new compact CONT:587
```

must resolve to the same Container identity and workflow.

For Controllers, the full Scan URL in the camera-readable QR and compact `CTRL:<controller_id>` from Zebra HID/manual entry must likewise resolve to the same permanent Controller Inventory identity and result.

GPS is additional location context. It is not a different Container identity path.

## Related Systems

- [Labeling and Scanning engineering handoff](README.md)
- [Deployed Display Scan Runtime Boundary](Deployed_Display_Scan_Runtime_Boundary.md)
- [Scan Workflows and Forklift Operations](Scan_Workflows_and_Forklift_Operations.md)
- [Scanner Hardware and Tablet Integration](Scanner_Hardware_and_Tablet_Integration.md)
- [Wiring System](../09_Wiring_System/README.md)
- [Containers and Storage](../04_Containers_and_Storage/README.md)
- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [Operational Label Printing SOPs](../../02_Operational_SOPs/Label_Printing/README.md)
