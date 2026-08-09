# Labeling and Scanning

This subsystem documents permanent asset labeling, QR/barcode payloads, label-printing integration, scan behavior, and scanner/tablet workflows.

## Current State

Display and container label printing is an implemented production capability used to connect physical assets to Production Database records. Scanning and field workflows continue to evolve.

Label printing crosses a repository and service boundary:

- the **Production Database** owns the asset records and the request to print;
- **Directus** provides the current operator interface for selecting records and enabling `Print Label`;
- the separate **MSB_LabelPrintService** consumes those requests and performs the physical printing on the dedicated print server.

The LabelPrintService is an external supporting subsystem. If it is unavailable, printing stops, but the Production Database remains authoritative and usable.

## Design Intent

Labels must use durable Production Database identities rather than brittle application-specific URLs. Printing and scanning should remain usable by non-technical volunteers while preserving traceability and reprint control.

The operator-facing Production Database procedure should stop at requesting labels and basic first-line checks. Service startup/restart, print-server operation, and service-specific troubleshooting belong in the LabelPrintService repository.

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

### LabelPrintService responsibility

- dedicated print-server service
- reading/processing queued print batches
- rendering and sending labels to the physical printer
- print-service logs and service-specific recovery/troubleshooting

A failure of LabelPrintService must not transfer data authority to the service or require a second source of truth.

## Authoritative Sources

- current PostgreSQL label-printing objects and request/batch records
- current Directus Display and Container print workflows
- current `MSB_LabelPrintService` implementation and operator documentation
- current field scanning workflows

The legacy `H_Asset_ID_Labeling_and_Scanning_Plan.md` still requires reconciliation into this subsystem before archival/removal. It is not automatically obsolete merely because current label printing is already implemented.

## Related Systems

- [Containers and Storage](../04_Containers_and_Storage/README.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [Operational Label Printing SOPs](../../02_Operational_SOPs/Label_Printing/README.md)
- [Operational SOPs](../../02_Operational_SOPs/README.md)
- [LabelPrintService Operator Guide](https://github.com/Gregovate/MSB_LabelPrintService/blob/main/docs/Operator_Label_Printing.md)

## Resume Development

For label printing, begin with the current PostgreSQL request/batch objects and the current LabelPrintService implementation. Verify the actor-attribution contract and any retry/reprint behavior before changing the database or service.

For scanning, continue by reconciling scanner/tablet workflows and the remaining valid contracts from `H_Asset_ID_Labeling_and_Scanning_Plan.md`.
