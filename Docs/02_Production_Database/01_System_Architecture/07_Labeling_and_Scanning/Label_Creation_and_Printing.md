# MSB Label Creation and Printing

**Status:** Active design reference; reconcile against current LabelPrintService implementation  
**Purpose:** Define label creation, printing, tracking, quantities, duplicate prevention, and failure handling.

## 1. Purpose

This document defines the engineering requirements for creating and printing asset labels for MSB operations.

It covers:

- which assets receive labels
- how labels are generated
- quantity rules
- print-job tracking
- duplicate prevention
- reprints and failure recovery
- printer integration

Operator instructions remain in the separate Operational SOP tree.

## 2. Asset Scope

Label printing supports Displays, Containers, and Storage Locations. Controller labeling is part of the Controller Inventory subsystem and uses the same shared identity/label conventions where applicable.

## 3. Core Requirements

The label system must support selected-item and batch printing, durable labels, intentional reprints, clear failure handling, and a simple volunteer-facing workflow. Manual CSV export is not the intended operator workflow.

## 4. Printer Hardware

The established printer is the Brother P-Touch PT-P950NW network label printer using laminated label stock. Current implementation details are owned by the LabelPrintService and current deployment documentation.

## 5. Machine-Readable Identity

Labels use stable machine-readable identifiers based on the `TYPE:KEY` convention where that convention remains current for the asset type.

Examples historically used include:

- `CONT:587`
- `LOC:RA-01-A-03`
- `DISP:251`
- `CTRL:CL-042`

The encoded identity must resolve to a stable MSB asset identity, not a brittle Directus admin URL.

## 6. Quantity Rules

- Containers: 2 labels by default so identification remains visible regardless of storage orientation.
- Displays: 1 label by default.
- Storage Locations: 1 label by default.
- Controllers: quantity and final layout belong to the Controller Inventory subsystem.

The application should enforce quantity rules rather than relying on the operator to remember them.

## 7. Label Content

Each label should contain a human-readable identifier and the appropriate machine-readable barcode or QR code, with sufficient contrast, size, and durability for its operating environment.

## 8. Controlled Printing Workflow

Labels are generated from database records through the application/print service rather than manually typed into printer software.

Conceptual flow:

```text
User selects assets
    ↓
Application creates controlled print request
    ↓
LabelPrintService renders labels
    ↓
Brother printer
    ↓
Print result recorded
```

## 9. Batch Printing

The system must support single-item and multi-item batches and operationally useful groupings such as display labels by container.

## 10. Print Tracking

Printing must be auditable. The system should retain enough information to determine:

- who requested printing
- when it was requested
- what assets were included
- requested quantities
- printer/template context where applicable
- overall and per-item result
- failure details when available

## 11. Duplicate Prevention and Reprints

Accidental duplicate printing should be prevented. Intentional reprints must remain possible and should capture a reason such as damaged/lost label, printer failure, bad application, changed data, or test print.

A previously printed label does not prove that a valid physical label is still present on the asset.

## 12. Failure Handling

A failed or partially completed job must not mark all requested labels successful. The implementation must preserve enough per-item state to retry failed items without blindly reprinting successful ones.

## 13. Label Layout Management

Layouts should be centrally controlled by the print service. Operators should not need to select templates or modify printer configuration as part of normal use.

## 14. Engineering Boundary

This document defines label-printing requirements. Current executable behavior is owned by the LabelPrintService and associated database/application integration. Any older Directus-Flow-as-printer-orchestrator assumption must be verified before being treated as current.

## Related Documentation

- [`Scanner_Hardware_and_Tablet_Integration.md`](Scanner_Hardware_and_Tablet_Integration.md)
- [`Scan_Workflows_and_Forklift_Operations.md`](Scan_Workflows_and_Forklift_Operations.md)
- [Operational Label Printing SOPs](../../02_Operational_SOPs/Label_Printing/)
