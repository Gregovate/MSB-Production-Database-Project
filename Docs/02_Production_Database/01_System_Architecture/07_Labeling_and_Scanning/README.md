# Labeling and Scanning

This subsystem documents permanent asset labeling, QR/barcode payloads, label-printing integration, scan behavior, and scanner/tablet workflows.

## Boundary — Do Not Collapse These Systems

**Repository location is not subsystem ownership.**

Labeling and Scanning is its own MSB subsystem even though its controlled engineering documentation and some current Scan implementation source live inside `Gregovate/MSB-Production-Database-Project`.

Keep these boundaries separate in every new thread, branch, issue, PR, and design decision:

```text
Labeling and Scanning subsystem
    = cross-system labeling / payload / scanning contract

MSB Production Database
    = authoritative database records and database implementation

MSB Label Print Service / PRINT-SERVER
    = external physical-printing runtime and Brother implementation
```

A file living in the Production Database repository does not automatically make its engineering responsibility a Production Database responsibility.

Read [Labeling and Scanning — Subsystem and Repository Boundary](Subsystem_and_Repository_Boundary.md) before changing QR payloads, scanner behavior, label profiles, Scan normalization/routing, print-request integration, Brother templates, or printer/runtime behavior.

## Current State

Display and container label printing is an implemented production capability used to connect physical assets to Production Database records.

**Display QR lookup is also an implemented production capability.** The current Display scan route is deployed as a Directus endpoint extension on `msb-prod-db` under `/opt/directus/extensions/directus-extension-scan/`. It resolves the permanent Production Database `display_id` and presents the existing Display scan hub.

The accepted camera-enabled scan implementation has been recovered into Git-controlled application source under:

```text
Scan/directus-extension-scan/
    package.json
    src/index.js
    dist/index.js
```

The source is stored in the Production Database repository because it operates directly against Production Database identities/data. Its label/payload/scan behavior still implements the Labeling and Scanning subsystem contract.

The detailed deployed runtime hash, rollback artifacts, restart/recovery sequence, and Synology `/scan/` proxy behavior are maintained in `Gregovate/MSB-Server-Management`.

**FieldWiring Scan Integration is accepted production work.** The Display scan hub currently includes the additive **Field Wiring** action using only the already-resolved permanent `display_id`:

```text
/fieldwiring/wiring.html?display_id=<permanent display_id>
```

The scan hub remains independent of FieldWiring for Display Record, Testing, Container, Work Order, and other existing actions. FieldWiring does not have to be healthy merely for the Display hub to render.

**Procedure is also production-operational independently at `https://my.sheboyganlights.org/procedures/`.** The Procedure Display Scan source candidate is implemented on branch `agent/procedure-scan-action` from current `main`. The agreed Scan UX is one additive **Procedures** button on the Display hub:

```text
/procedures/?display_id=<permanent display_id>
```

The Scan hub passes only the permanent `display_id`. Setup, Takedown, and Inspection selection remains inside the existing Procedure application, which already presents those three operator task choices. This avoids duplicating Procedure task-selection UI in Scan and does not add a Procedure API/health dependency merely to render the Display hub.

Application-source implementation commit:

```text
333f7c20a26e8ed2a0460ddbf309c167bffa2992
```

This source candidate is **not yet a production-runtime acceptance record**. Until the documented Server Management deployment gate is executed and accepted, the current live Scan runtime remains the previously accepted FieldWiring-enabled artifact and hash.

No physical QR redesign, second resolver, Procedure schema, alternate Google hierarchy, or duplicate document registry is part of this integration.

The broader Setup/Deployment scan workflow remains separate engineering scope. High-volume Container and Storage Location scanning is expected during setup season, but the real pull/stage/load/delivery process must be reconstructed before broader scan-platform refactoring or transaction semantics are approved.

The deployed scan runtime predates the current documentation structure. Its server-side deployment, restart, hash, backup, recovery, and reverse-proxy details are maintained through the separate [MSB-Server-Management](https://github.com/Gregovate/MSB-Server-Management) project.

Label printing crosses a repository and service boundary:

- **Labeling and Scanning** owns the cross-system label/payload/scan contract;
- the **Production Database** owns the authoritative asset records and database-backed request/batch state;
- **Directus** provides the current operator interface for selecting records and enabling `Print Label`;
- the separate **MSB_LabelPrintService** consumes the approved database contract and performs physical printing on the dedicated print server.

The LabelPrintService is an external supporting subsystem. If it is unavailable, printing stops, but the Production Database remains authoritative and usable.

## Start Here

- [Subsystem and Repository Boundary](Subsystem_and_Repository_Boundary.md) — controlling separation among Labeling and Scanning, the Production Database, and LabelPrintService/PRINT-SERVER.
- [Label Payload and Profile Architecture](Label_Payload_and_Profile_Architecture.md) — current QR-generation/profile reconnaissance and implementation gates.
- [FieldWiring Scan Integration Engineering Handoff — 2026-08-22](FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md) — accepted production Scan/FieldWiring baseline, permanent `display_id` handoff, source-control boundary, failure boundary, acceptance matrix, and deferred regression cases.
- [Deployed Display Scan Runtime Boundary](Deployed_Display_Scan_Runtime_Boundary.md) — current Directus scan endpoint, application/runtime ownership boundary, Procedure source-candidate state, and current scan-extension resume point.
- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md) — durable asset/payload rules.
- [Field Context Resolution Contract](Field_Context_Resolution_Contract.md) — shared scan-to-Display/hierarchy contract used by Work Orders, FieldWiring, Procedures, Testing, and future field functions.
- [Field Document Publication and Currentness Contract](Field_Document_Publication_and_Currentness_Contract.md) — shared browser/PDF/offline/currentness rules for field documents reached through the scan/task workflow.
- [Operational Label Printing SOPs](../../02_Operational_SOPs/Label_Printing/README.md) — current operator instructions.

## Design Intent

Labels must use durable Production Database identities rather than brittle application-specific URLs. Printing and scanning should remain usable by non-technical volunteers while preserving traceability and reprint control.

Labeling and Scanning governs the cross-system representation and scan contract. The Production Database supplies authoritative identities/data and database-side implementation. LabelPrintService owns Brother/PRINT-SERVER implementation.

The operator-facing Production Database procedure should stop at requesting labels and basic first-line checks. Service startup/restart, print-server operation, and service-specific troubleshooting belong in the LabelPrintService repository.

Display-linked documents and field information are not intended to become a generic database document-management system. Their operational purpose is to support QR-based lookup from the physical Display or Container to the information needed in the field. The subsystem that owns the actual content remains authoritative for that content.

A Display scan establishes the permanent Display identity through the existing deployed Directus scan endpoint. The resulting Display scan hub then allows the operator to choose the task they need. Work Orders, FieldWiring, Procedures, Testing, and future field functions must consume that resolved identity/context rather than maintaining separate QR-resolution logic. Procedure-specific Setup/Takedown/Inspection task selection remains inside the Procedure application.

For document-style task results, the shared field publication contract defines the common current browser presentation, self-contained PDF/offline direction, visible expiration/currentness metadata, and supersession behavior. The responsible subsystem still owns the actual document/data content and its task-specific expiration interval.

For example, Wiring owns wiring information, Setup and Deployment owns setup/takedown instructions, Work Orders owns the Work Order lifecycle, Testing owns testing procedures/state, and Site Infrastructure/GIS owns location/GPS context. Labeling and Scanning owns the QR/payload and shared lookup boundary that connects the physical asset to those systems.

## Dependencies

- [Database Foundation](../01_Database_Foundation/README.md)
- [Containers and Storage](../04_Containers_and_Storage/README.md)
- [People and Identity](../03_People_and_Identity/README.md) for authenticated operations where applicable
- [Setup and Deployment](../12_Setup_and_Deployment/README.md) for Procedure field-document behavior and the future Container/Location setup-season workflow
- [MSB-Server-Management](https://github.com/Gregovate/MSB-Server-Management) for the deployed `msb-prod-db` runtime, Directus server administration, runtime hashes/recovery, and Synology proxy configuration
- [MSB_LabelPrintService](https://github.com/Gregovate/MSB_LabelPrintService) for Brother/PRINT-SERVER physical-printing implementation

## Current Responsibilities

Labeling and Scanning currently owns/governs:

- asset ID/payload conventions;
- display/container/storage-location label contract;
- label-printing service integration contract;
- logical print/reprint requirements;
- QR/barcode lookup behavior;
- shared Display/field-context resolution for task routing;
- shared field-document publication/currentness contract;
- scanner and rugged-tablet integration;
- forklift/field scan workflows;
- additive scan-task routing without making existing functions dependent on downstream applications;
- routing scanned assets to authoritative operational information without duplicating that content in a generic document registry.

Implementation details remain with the repository/system responsible for them as defined in [Subsystem and Repository Boundary](Subsystem_and_Repository_Boundary.md).

## Label Print Request and Actor Contract

The current operator flow is:

**Directus -> select Display or Container records -> enable Print Label -> save -> LabelPrintService processes the request**

The print batch must preserve who requested the print operation at the time the batch is created. The previous combined operator/engineering document identified the intended batch attribution fields as:

- `requested_by`;
- `requested_by_person_id`;
- `requested_at`.

The durable rule is that actor attribution is captured on the batch itself rather than inferred later by the print service or logs from subsequently changing records.

Before changing these fields or their implementation, verify the current database objects and current LabelPrintService behavior.

## System Boundary

### Display scan runtime

**Relationship Class:** Labeling and Scanning implementation currently hosted as a Directus endpoint on the Production Database server.

The current Display scan endpoint is deployed under:

```text
/opt/directus/extensions/directus-extension-scan/
```

on `msb-prod-db`.

The Production Database repository owns the Git-controlled implementation files and database contracts used by that endpoint. Labeling and Scanning owns the cross-system payload/scan behavior the implementation must satisfy. Server runtime administration, deployment/restart/recovery documentation, runtime hashes, backups, and inspection of the live `/opt/...` implementation are owned by [MSB-Server-Management](https://github.com/Gregovate/MSB-Server-Management).

The live deployment executes `dist/index.js`; it does not need to contain the development `src/` tree. The accepted application source has been recovered under `Scan/directus-extension-scan/` in this repository, so future implementation changes must begin from that source and the current Server Management runtime baseline rather than reconstructing the extension from the live artifact.

See [Deployed Display Scan Runtime Boundary](Deployed_Display_Scan_Runtime_Boundary.md) and [FieldWiring Scan Integration Engineering Handoff](FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md).

### Label printing runtime

**Relationship Class:** External Supporting Subsystem — LabelPrintService.

#### Labeling and Scanning responsibility

- canonical label/payload contract;
- compatibility rules for deployed labels;
- logical label-profile requirements;
- integration behavior between database request state, Scan, and physical printing.

#### Production Database responsibility

- authoritative Display and Container records/identity keys;
- label-print request state;
- database-side batch/history/audit objects;
- database implementation consumed by LabelPrintService;
- authoritative relationships used by shared field-context resolution.

#### LabelPrintService responsibility

- dedicated print-server service;
- reading/processing queued print work;
- rendering and sending labels to physical printers;
- Brother templates/b-PAC/printer mappings;
- print-service logs and service-specific recovery/troubleshooting;
- failed-batch/no-double-print runtime safeguards.

A failure of LabelPrintService must not transfer data authority to the service or require a second source of truth.

## Authoritative Sources

- [Subsystem and Repository Boundary](Subsystem_and_Repository_Boundary.md)
- [Label Payload and Profile Architecture](Label_Payload_and_Profile_Architecture.md)
- [FieldWiring Scan Integration Engineering Handoff](FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md)
- [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md)
- [Deployed Display Scan Runtime Boundary](Deployed_Display_Scan_Runtime_Boundary.md)
- [Field Context Resolution Contract](Field_Context_Resolution_Contract.md)
- [Field Document Publication and Currentness Contract](Field_Document_Publication_and_Currentness_Contract.md)
- current Scan application source under `Scan/directus-extension-scan/`;
- current PostgreSQL label-printing objects and request/batch records;
- current Directus Display and Container print workflows;
- current deployed Display scan extension on `msb-prod-db`;
- current `MSB_LabelPrintService` implementation and operator documentation;
- [MSB-Server-Management — Display Scan Extension Deployment and Recovery](https://github.com/Gregovate/MSB-Server-Management/blob/main/docs/directus/Display_Scan_Extension_Deployment_and_Recovery.md) for server/runtime administration, accepted live hash, backup/rollback evidence, restart, and recovery.

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
- [Operational SOPs](../../02_Production_Database/02_Operational_SOPs/README.md)
- [MSB Label Print Service](https://github.com/Gregovate/MSB_LabelPrintService)
- [MSB-Server-Management](https://github.com/Gregovate/MSB-Server-Management)

## Resume Development

### Procedure Display Scan Integration — source candidate ready; deployment/acceptance pending

Standalone Procedure field access and FieldWiring Scan Integration are accepted production baselines. Procedure Display Scan Integration now has an application-source candidate on branch `agent/procedure-scan-action`.

Agreed operator behavior:

```text
Display scan hub
    -> Procedures
        -> /procedures/?display_id=<permanent display_id>
            -> existing Procedure page
                -> operator chooses Setup, Takedown, or Inspection
```

The source candidate adds exactly one Display-hub link in both Git-controlled `src/index.js` and `dist/index.js`. It does not call Procedure to decide whether to render the button and does not change any existing Scan route.

Application-source commit:

```text
333f7c20a26e8ed2a0460ddbf309c167bffa2992
```

Next step is deployment/acceptance through the current `MSB-Server-Management` Display Scan Extension Deployment and Recovery runbook. Before live replacement, verify the live artifact still matches the documented accepted baseline, create a new timestamped rollback, stage/syntax-check the candidate, and regression-test Display Record, Testing, Container, Work Orders, Field Wiring, manual/camera Scan behavior as applicable, plus the new Procedures action.

Preserve the current physical Display identity/payload contract. Do not add a second resolver, Procedure schema, alternate Google hierarchy, direct Procedure-document URL in the QR, or a Procedure health/API dependency merely to render the Display scan hub.

### Setup/Deployment operational scanning — separate project

The expected setup-season workload includes substantial Container and Storage Location scanning. Reconstruct the real pull/stage/load/delivery workflow before designing schema, scan-session state, transaction semantics, or a broader scan-platform refactor.

### Label printing

For label printing, begin with [Subsystem and Repository Boundary](Subsystem_and_Repository_Boundary.md), [Label Payload and Profile Architecture](Label_Payload_and_Profile_Architecture.md), current PostgreSQL request/batch objects, [Asset Identity and Scan Payload Standard](Asset_Identity_and_Scan_Payload_Standard.md), and the current LabelPrintService implementation.

First classify each proposed change as Labeling and Scanning contract, Production Database implementation, LabelPrintService implementation, or a coordinated cross-boundary change.

Material work is not complete until durable discoveries are recorded in the responsible engineering/runbook documentation for every boundary changed so the next chat can resume from Git without reconstructing settled behavior.
