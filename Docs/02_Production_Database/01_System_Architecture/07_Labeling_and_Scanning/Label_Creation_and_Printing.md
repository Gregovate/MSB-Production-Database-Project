# MSB Label Creation and Printing

**Status:** Active design reference; reconcile against current LabelPrintService implementation  
**Current revision:** 2026-09-03  
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

Current asset label printing supports Displays, Containers, and Storage Locations. Controller labeling is part of the Controller Inventory subsystem and uses the same shared identity/label conventions where applicable.

FieldWiring also uses a **Channel / Plug / Wire label class**. These labels are configuration/hookup labels derived from current approved FieldWiring data; they are not permanent asset-identity labels.

See [FieldWiring Channel / Plug Label Printing Requirements](../09_Wiring_System/FieldWiring_Channel_Plug_Label_Printing_Requirements.md) for the controlling FieldWiring request/content contract.

## 3. Core Requirements

The label system must support selected-item and batch printing, durable labels, intentional reprints, clear failure handling, and a simple volunteer-facing workflow. Manual CSV export or hand-keying label text into printer software is not the intended operator workflow.

## 4. Printer Hardware

The established laminated-tape printer is the Brother P-Touch PT-P950NW. Current printer-specific implementation details are owned by LabelPrintService and current deployment documentation.

The accepted FieldWiring Wire label family uses **1/2-inch / 12 mm laminated label stock** and the logical family:

```text
WIRING_12MM_HORIZONTAL
```

The approved V4 physical format is a double-sided fold-around wire label. LabelPrintService owns the physical Brother template, media/preflight behavior, and printer mapping.

## 5. Machine-Readable Identity

Permanent asset labels use stable machine-readable identifiers based on the `TYPE:KEY` convention where that convention remains current for the asset type.

Examples historically used include:

- `CONT:587`
- `LOC:RA-01-A-03`
- `DISP:251`
- `CTRL:CL-042`

The encoded identity must resolve to a stable MSB asset identity, not a brittle Directus admin URL.

FieldWiring Wire labels are different. Their purpose is physical hookup identification using a controller output number plus current human-readable wiring description. They are not permanent machine-readable asset identities and must not be treated as the permanent identity key for a Display, Controller, or wiring relationship.

## 6. Quantity Rules

- Containers: 2 labels by default so identification remains visible regardless of storage orientation.
- Displays: 1 permanent asset label by default.
- Storage Locations: 1 label by default.
- Controllers: quantity and final layout belong to the Controller Inventory subsystem.
- FieldWiring Wire labels: **one physical fold-around label per selected Display / physical-controller-output relationship**.

For FieldWiring this means:

- one Display using multiple physical outputs receives one wire label for each output;
- two Displays sharing the same programmed channel/output each receive their own wire label using that Display's own current `channel_name`; and
- E1.31/DMX-controlled devices are counted by resolved physical controller outputs, not raw universe/channel count. For example, a Pixie4D has four output labels when all four outputs are used; a Pixie2D has two when both outputs are used.

The double-sided fold-around rendering repeats one logical label on both sides of the same physical label; it does not double the request quantity.

The application should enforce established quantity rules rather than relying on the operator to remember them.

## 7. FieldWiring Label Content

The current approved FieldWiring `channel_name` is the descriptive source for the wire label.

FieldWiring normalization removes only the technical prefix at the beginning of the name:

```text
<Stage/area short code> + <UID-channel prefix>
```

The remainder is retained as the descriptive label content.

Example:

```text
TC 7B-10 Caroler P2 Mouth Closed 1
    -> Caroler P2 Mouth Closed 1
```

Tokens such as `P1` or `P2` that occur after the accepted leading prefix are retained. The workflow must not independently strip arbitrary later tokens or require the operator to retype the description.

FieldWiring supplies:

```text
resolved physical output
normalized channel_name description
```

LabelPrintService V4 owns the subsequent line split/rendering for the physical fold-around template.

## 8. Controlled Printing Workflow

Labels are generated from controlled data records through the application/print service rather than manually typed into printer software.

Conceptual flow:

```text
User selects assets / FieldWiring Display-output relationships
    ↓
Application creates controlled print request
    ↓
LabelPrintService consumes governed pending work
    ↓
LabelPrintService renders labels
    ↓
Brother printer
    ↓
Print result recorded
```

For FieldWiring, the request is created from the currently resolved Stage/Sub-stage/Scene and Background/Musical wiring context so the operator can review the selected Display/output relationships and normalized label descriptions before requesting printing.

The Production Database/request side does not choose Brother files, printer queues, or b-PAC implementation details.

## 9. Batch Printing

The system must support single-item and multi-item batches and operationally useful groupings.

FieldWiring must support:

- individual Display/output labels;
- multiple selected outputs for one Display;
- useful grouped selections such as a Controller's displayed outputs; and
- targeted reprint of one failed/damaged/missing label.

Convenience grouping must still resolve to one request item per Display/output relationship. A whole Stage print must not be required merely to replace one wire label.

## 10. Print Tracking

Printing must be auditable. The system should retain enough information to determine:

- who requested printing;
- when it was requested;
- what assets/operational labels were included;
- requested quantities;
- logical label family;
- overall and per-item result; and
- failure details when available.

For FieldWiring configuration labels, tracking must additionally retain enough wiring provenance to identify the approved wiring state/Preview or snapshot that supplied the selected Display/output relationship and `channel_name`.

Requester attribution belongs on governed request/batch state rather than being reconstructed later from mutable asset records or service logs.

## 11. Duplicate Prevention and Reprints

Accidental duplicate printing must be prevented. Intentional reprints must remain possible and should capture a reason such as damaged/lost label, printer failure, bad application, changed data, incorrect media, or test print.

A previously printed label does not prove that a valid physical label is still present on the asset or lead.

FieldWiring must support targeted reprint of selected Display/output labels rather than requiring operators to re-key text or blindly reprint a whole prior batch.

If two Displays legitimately share one technical channel/output, their separate Display/output label requests are not duplicates.

## 12. Failure Handling

A failed or partially completed job must not mark all requested labels successful. The implementation must preserve enough per-item state to retry failed items without blindly reprinting successful or physically uncertain items.

LabelPrintService owns 12 mm media preflight, printer readiness, spooler/printer behavior, tape-out handling, and no-double-print runtime safeguards.

A pending FieldWiring request is not proof that a physical label printed.

## 13. Label Layout Management

Layouts are centrally controlled by LabelPrintService. Operators do not select `.lbx` files or modify printer configuration as part of normal use.

For FieldWiring:

```text
Production Database / FieldWiring
    -> logical family WIRING_12MM_HORIZONTAL
    -> physical output
    -> normalized channel_name description

LabelPrintService V4
    -> runtime family mapping
    -> output formatting
    -> line1 / line2 split
    -> double-sided fold-around rendering
    -> printer/media execution
```

Actual `.lbx` names, Windows queue names, local paths, Brother object names, and b-PAC details remain LabelPrintService implementation details.

## 14. Authorization Boundary

FieldWiring wire-label request rights are limited to authenticated users in the accepted Directus roles:

```text
Production Crew
Manager
Administrator
```

Production Crew receives wire-label selection/request rights only. Manager and Administrator retain progressively broader rights under their existing responsible subsystem contracts.

The wire-label workflow must not grant new rights to change:

```text
channel numbers
channel_name values
LOR UID/address values
```

Those values remain controlled by the authoritative LOR/V7 wiring path.

Browser support for label requests must use narrow governed server/database commands rather than granting broad table DML to the FieldWiring application role.

## 15. Engineering Boundary

This document defines label-printing requirements. Executable physical-print behavior is owned by LabelPrintService and associated database/application integration.

FieldWiring should submit controlled semantic print requests; LabelPrintService remains responsible for Brother-specific rendering, printer communication, cutter behavior, media/printer status handling, and successful execution finalization.

FieldWiring must not create a second printer service or polling mechanism.

## Related Documentation

- [`Scanner_Hardware_and_Tablet_Integration.md`](Scanner_Hardware_and_Tablet_Integration.md)
- [`Scan_Workflows_and_Forklift_Operations.md`](Scan_Workflows_and_Forklift_Operations.md)
- [FieldWiring Channel / Plug Label Printing Requirements](../09_Wiring_System/FieldWiring_Channel_Plug_Label_Printing_Requirements.md)
- [Operational Label Printing SOPs](../../02_Operational_SOPs/Label_Printing/)
