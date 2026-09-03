# MSB Label Creation and Printing

**Status:** Active design reference; reconcile against current LabelPrintService implementation  
**Purpose:** Define label creation, printing, tracking, quantities, duplicate prevention, and failure handling.

## 1. Purpose

This document defines the engineering requirements for creating and printing asset and controlled operational labels for MSB operations.

It covers:

- which records/workflows receive labels
- how labels are generated
- quantity rules
- print-job tracking
- duplicate prevention
- reprints and failure recovery
- printer integration

Operator instructions remain in the separate Operational SOP tree.

## 2. Asset / Label Scope

Current production label printing supports Displays and Containers. Storage Location labels have not been printed, and Controller label polling/printing remains in the separate LabelPrintService workstream. Controller labeling uses the same shared identity/label conventions.

FieldWiring also requires a future **Channel / Plug label class**. Those labels are configuration/hookup labels derived from current wiring Channel Names; they are not permanent asset-identity labels.

See [FieldWiring Channel / Plug Label Printing Requirements](../09_Wiring_System/FieldWiring_Channel_Plug_Label_Printing_Requirements.md).

## 3. Core Requirements

The label system must support selected-item and batch printing, durable labels, intentional reprints, clear failure handling, and a simple volunteer-facing workflow. Manual CSV export or hand-keying label text into printer software is not the intended operator workflow.

## 4. Printer Hardware

The established printer is the Brother P-Touch PT-P950NW network label printer using laminated label stock. Current implementation details are owned by the LabelPrintService and current deployment documentation.

The FieldWiring Channel / Plug label workflow has a field requirement for **1/2-inch laminated label stock**. A dedicated FieldWiring template has not yet been established and must be tested before production use.

## 5. Machine-Readable Identity

Permanent asset labels use stable machine-readable identifiers based on the `TYPE:KEY` convention where that convention remains current for the asset type.

Examples historically used include:

- `CONT:587`
- `LOC:RA-01-A-03`
- `DISP:251`
- `CTRL:1014`

The encoded identity must resolve to a stable MSB asset identity, not a brittle Directus admin URL.

FieldWiring Channel / Plug labels are different: their primary purpose is to reproduce current human-readable wiring Channel Names on physical leads/plugs. They must not be treated as permanent asset-identity keys unless a later reviewed design explicitly adds a separate stable identifier.

## 6. Quantity Rules

- Containers: 2 labels by default so identification remains visible regardless of storage orientation.
- Displays: 1 label by default.
- Storage Locations: 1 label by default.
- Controllers: quantity and final layout belong to the Controller Inventory subsystem.
- FieldWiring Channel / Plug labels: quantity comes from the selected physical hookup/lead set and must be reviewed before printing; no hard-coded global quantity rule is established yet.

The application should enforce established quantity rules rather than relying on the operator to remember them.

## 7. Label Content

Each permanent asset label should contain a human-readable identifier and the appropriate machine-readable barcode or QR code, with sufficient contrast, size, and durability for its operating environment.

FieldWiring Channel / Plug labels use the current approved **Channel Name** as the essential printed text. The exact 1/2-inch template, text wrapping/truncation rules, font size, and any optional additional context must be validated against real Channel Name lengths before production approval.

Normal operators must not be required to retype the Channel Name.

## 8. Controlled Printing Workflow

Labels are generated from controlled data records through the application/print service rather than manually typed into printer software.

Conceptual flow:

```text
User selects assets / wiring leads
    ↓
Application creates controlled print request
    ↓
LabelPrintService renders labels
    ↓
Brother printer
    ↓
Print result recorded
```

For FieldWiring, the request should be created from the currently resolved Stage/Sub-stage/Scene and Background/Musical context so the operator can review the exact Channel Name labels before printing.

## 9. Batch Printing

The system must support single-item and multi-item batches and operationally useful groupings such as display labels by container.

FieldWiring should support selected plug/lead labels and useful controller/output batches without forcing operators to print an entire Stage when only one failed or damaged label needs replacement.

## 10. Print Tracking

Printing must be auditable. The system should retain enough information to determine:

- who requested printing
- when it was requested
- what assets/operational labels were included
- requested quantities
- printer/template context where applicable
- overall and per-item result
- failure details when available

For FieldWiring configuration labels, tracking should additionally retain enough wiring provenance to identify the source approved wiring state/Preview or snapshot that supplied the Channel Name.

## 11. Duplicate Prevention and Reprints

Accidental duplicate printing should be prevented. Intentional reprints must remain possible and should capture a reason such as damaged/lost label, printer failure, bad application, changed data, incorrect media, or test print.

A previously printed label does not prove that a valid physical label is still present on the asset or lead.

FieldWiring must support targeted reprint of selected Channel / Plug labels rather than requiring operators to re-key the text or blindly reprint a whole prior batch.

## 12. Failure Handling

A failed or partially completed job must not mark all requested labels successful. The implementation must preserve enough per-item state to retry failed items without blindly reprinting successful ones.

The current LabelPrintService engineering TODO documents that tape-out detection is not reliable: software/spooler success may occur even when usable tape did not physically print.

Therefore any new FieldWiring workflow requiring 1/2-inch stock must either prove a reliable cartridge/media-width preflight or require explicit operator confirmation of the correct loaded media before printing.

## 13. Label Layout Management

Layouts should be centrally controlled by the print service. Operators should not need to select templates or modify printer configuration as part of normal use.

The current LabelPrintService repository contains Display and Container LBX templates. A dedicated 1/2-inch FieldWiring Channel / Plug template is a future requirement and must be created/tested in the LabelPrintService workstream rather than improvised by field operators.

## 14. Engineering Boundary

This document defines label-printing requirements. Current executable behavior is owned by the LabelPrintService and associated database/application integration. Any older Directus-Flow-as-printer-orchestrator assumption must be verified before being treated as current.

FieldWiring should submit controlled print requests; LabelPrintService remains responsible for Brother-specific template rendering, printer communication, cutter behavior, and printer/media status handling.

## Related Documentation

- [`Scanner_Hardware_and_Tablet_Integration.md`](Scanner_Hardware_and_Tablet_Integration.md)
- [`Scan_Workflows_and_Forklift_Operations.md`](Scan_Workflows_and_Forklift_Operations.md)
- [FieldWiring Channel / Plug Label Printing Requirements](../09_Wiring_System/FieldWiring_Channel_Plug_Label_Printing_Requirements.md)
- [Operational Label Printing SOPs](../../02_Operational_SOPs/Label_Printing/)
