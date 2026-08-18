# Labeling and Scanning

This subsystem documents permanent asset labeling, QR/barcode payloads, label-printing integration, scan behavior, and scanner/tablet workflows.

## Current State

Display and container label printing is an implemented production capability used to connect physical assets to Production Database records. Scanning and field workflows continue to evolve.

Label printing crosses a repository and service boundary:

- the **Production Database** owns the asset records and the request to print;
- **Directus** provides the current operator interface for selecting records and enabling `Print Label`;
- the separate **MSB_LabelPrintService** consumes those requests and performs the physical printing on the dedicated print server.

The LabelPrintService is an external supporting subsystem. If it is unavailable, printing stops, but the Production Database remains authoritative and usable.

## Start Here

- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md) — durable asset/payload rules and the boundary between implemented label printing and planned/evolving scanning workflows.
- [Field Context Resolution Contract](Field_Context_Resolution_Contract.md) — shared scan-to-Display/hierarchy contract used by Work Orders, FieldWiring, Setup, Takedown, Testing, and future field functions.
- [Operational Label Printing SOPs](../../02_Operational_SOPs/Label_Printing/README.md) — current operator instructions.

## Design Intent

Labels must use durable Production Database identities rather than brittle application-specific URLs. Printing and scanning should remain usable by non-technical volunteers while preserving traceability and reprint control.

The operator-facing Production Database procedure should stop at requesting labels and basic first-line checks. Service startup/restart, print-server operation, and service-specific troubleshooting belong in the LabelPrintService repository.

Display-linked documents and field information are not intended to become a generic database document-management system. Their operational purpose is to support QR-based lookup from the physical Display or Container to the information needed in the field. The subsystem that owns the actual content remains authoritative for that content.

A Display scan should establish the permanent Display identity and current field context, then allow the operator to choose the task they need. Work Orders, FieldWiring, Setup, Takedown, Testing, and future field functions consume that shared context rather than maintaining separate QR-resolution logic.

For example, Wiring owns wiring information, Setup and Deployment owns setup/takedown instructions, Work Orders owns the Work Order lifecycle, Testing owns testing procedures/state, and Site Infrastructure/GIS owns location/GPS context. Labeling and Scanning owns the QR/payload and shared lookup boundary that connects the physical asset to those systems.

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
- shared Display/field-context resolution for task routing
- scanner and rugged-tablet integration
- forklift/field scan workflows
- routing scanned assets to authoritative operational information without duplicating that content in a generic document registry

## Label Print Request and Actor Contract

The current operator flow is:

**Directus -> select Display or Container records -> enable Print Label -> save -> LabelPrintService processes the request**

The print batch must preserve who requested the print operation at the time the batch is created. The previous combined operator/engineering document identified the intended batch attribution fields as:

- `requested_by`
- `requested_by_person_id`
- `requested_at`

The durable rule is that actor attribution is captured on the batch itself rather than inferred later by the print service or logs from subsequently changing records.

Before changing these fields or their implementation, verify the current database objects and current LabelPrintService behavior.

## System Boundary

**Relationship Class:** External Supporting Subsystem — LabelPrintService.

### Production Database responsibility

- authoritative Display and Container identity
- label-print request state
- database-side batch/request creation and audit attribution
- integration contract consumed by LabelPrintService
- authoritative relationships used by shared field-context resolution

### LabelPrintService responsibility

- dedicated print-server service
- reading/processing queued print batches
- rendering and sending labels to the physical printer
- print-service logs and service-specific recovery/troubleshooting

A failure of LabelPrintService must not transfer data authority to the service or require a second source of truth.

## Authoritative Sources

- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md)
- [Field Context Resolution Contract](Field_Context_Resolution_Contract.md)
- current PostgreSQL label-printing objects and request/batch records
- current Directus Display and Container print workflows
- current `MSB_LabelPrintService` implementation and operator documentation
- current field scanning workflows

The former loose `H_Asset_ID_Labeling_and_Scanning_Plan.md` has been reconciled into this subsystem and archived as historical planning evidence.

## Related Systems

- [Containers and Storage](../04_Containers_and_Storage/README.md)
- [Work Orders](../06_Work_Orders/README.md)
- [Testing System](../05_Testing_System/README.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [Wiring System](../09_Wiring_System/README.md)
- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md)
- [Operational Label Printing SOPs](../../02_Operational_SOPs/Label_Printing/README.md)
- [Operational SOPs](../../02_Operational_SOPs/README.md)
- [LabelPrintService Operator Guide](https://github.com/Gregovate/MSB_LabelPrintService/blob/main/docs/Operator_Label_Printing.md)

## Resume Development

For label printing, begin with the current PostgreSQL request/batch objects, [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md), and the current LabelPrintService implementation. Verify the actor-attribution contract and any retry/reprint behavior before changing the database or service.

For scanning, use the [Field Context Resolution Contract](Field_Context_Resolution_Contract.md) as the common Display-scan/navigation boundary. Preserve existing working task destinations such as Work Orders and add new task consumers without embedding task-specific destinations in the physical QR identity.

Treat planned/evolving scan behavior as planned until the actual field application and deployed scan behavior are verified. Any future asset lookup should route to authoritative subsystem information instead of rebuilding a generic document registry in the database.
