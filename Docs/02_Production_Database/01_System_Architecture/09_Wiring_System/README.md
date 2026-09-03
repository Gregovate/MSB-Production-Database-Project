# Wiring System

This subsystem documents how MSB presents, enriches, and operationally uses wiring information derived from LOR-authoritative show topology.

## Current State

**FieldWiring and Controller Inventory V0.4.0 are production-operational.**

Current accepted production checkpoint:

```text
checkout                    72f5b7164f31753a33e5c2a9d83d9a7a6909a417
FieldWiring                  V0.4.0 / postgres / healthy
Procedures                   V0.1.0 / postgres / healthy
Controller fingerprint       578217bcb18e1291ceced673a3de3b27 unchanged at deployment
```

Accepted production state includes:

- FieldWiring browser application: `https://my.sheboyganlights.org/fieldwiring/`;
- Controller Inventory browser: `https://my.sheboyganlights.org/fieldwiring/controllers`;
- Display Scan application: `https://my.sheboyganlights.org/scan/`;
- live PostgreSQL-backed FieldWiring/Controller application;
- systemd-hosted FieldWiring backend on `192.168.5.9:8790`;
- persistent read-only Google `Display Folders` filesystem operational;
- protected Synology reverse proxies operational;
- desktop and phone FieldWiring acceptance passed;
- permanent Display search and Stage/Scene browse;
- Stage/Sub-stage-aware Controller Inventory browse/search;
- current programmed Controller Network/UID/IP presentation;
- permanent Controller ID/model context in FieldWiring where governed relationships resolve the physical device;
- FieldWiring -> Controller Inventory cross-links;
- Controller Inventory -> Field Wiring links from Display assignments;
- Controller capacity planning against current LOR/V7 evidence;
- governed Add/Edit Controller maintenance;
- governed many-to-many Controller-to-Display assignment/edit/reassign/unassign workflow;
- contextual operator help and unsaved-change protection;
- governed Controller Print Label request action, with physical polling/printing owned separately by `MSB_LabelPrintService`;
- existing Display QR/scan hub includes the independent **Field Wiring** action;
- Controller Scan route hands permanent Controller ID to Controller Inventory Search/detail;
- Directus-facing Scan actions use the established `https://db.sheboyganlights.org/` origin;
- FormView remains available as fallback/reference.

The accepted FieldWiring Display deep link is:

```text
/fieldwiring/wiring.html?display_id=<permanent display_id>
```

The scan hub passes only the permanent `ref.display.display_id`. No LOR UUID, Stage key, Scene UUID, controller address, or Google Drive path is part of the QR-to-FieldWiring identity contract.

## Start Here

For current production/recovery state, begin with:

- [Controller Inventory](../08_Controller_Inventory/README.md)
- [Controller Management Application Boundary — 2026-08-31](../08_Controller_Inventory/Controller_Management_Application_Boundary_2026-08-31.md)
- [Controller V0.4.0 Post-Deployment Operational Decisions — 2026-09-03](../08_Controller_Inventory/Controller_V0.4.0_Post_Deployment_Operational_Decisions_2026-09-03.md)
- [FieldWiring / Controller Inventory Handoff — 2026-08-20](FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
- [FieldWiring Application README](../../../../FieldWiring/Application/README.md)
- [FieldWiring Scan Integration Engineering Handoff — 2026-08-22](../07_Labeling_and_Scanning/FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md)
- [Deployed Display Scan Runtime Boundary](../07_Labeling_and_Scanning/Deployed_Display_Scan_Runtime_Boundary.md)
- [FieldWiring Engineering Recovery and Compatibility Contract](FieldWiring_Engineering_Recovery_and_Compatibility_Contract.md)
- [FieldWiring Drive Context Resolver Engineering Design](FieldWiring_Drive_Context_Resolver_Engineering_Design.md)
- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [FieldWiring DMX / DumbRGB Field Presentation Contract](FieldWiring_DMX_DumbRGB_Field_Presentation_Contract.md)
- [FieldWiring E1.31 Dense RGB Field Presentation Contract](FieldWiring_E131_Dense_RGB_Field_Presentation_Contract.md)
- [FieldWiring Scene Scope and Offline Report Requirements](FieldWiring_Scene_Scope_and_Offline_Report_Requirements.md)
- [Shared Field Context Resolution Contract](../07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)
- [FormView Engineering Architecture](../../../01_LOR_System/04_FormView/FormView_Engineering_Architecture.md)

The repository is the durable engineering handoff. Conversation history is not the recovery mechanism.

## Authority Chain

The operational authority chain remains:

```text
Light-O-Rama
    -> Parser V7 / LOR2DB
        -> PostgreSQL Production Database
            -> FieldWiring
```

LOR remains authoritative for current show topology, controller/address assignments, channels, DMX/E1.31/network assignments, and related source wiring configuration.

PostgreSQL provides the controlled current snapshot plus permanent Production Database identities and database-owned relationships.

Permanent identities used by Wiring are:

```text
Display     ref.display.display_id
Controller  ref.controller.controller_id
```

Controller Inventory owns permanent physical Controller identity, current Controller-to-Display relationships, current programmed Controller facts, and Controller operational management.

FieldWiring interprets and presents those facts together with current LOR wiring for field use. It must not become a competing topology-authoring or identity system.

## Controller Management Boundary

Browser-native Controller Management is deployed in FieldWiring V0.4.0.

Authentication/authorization is:

```text
Cloudflare Access authenticated email
    -> protected proxy/origin
    -> Controller backend
    -> current Directus user / role / policy capability data
    -> governed PostgreSQL command
```

Directus is **not** the Controller operational editor and no Directus login/session bridge is required.

The deployed Manager/Administrator workflow is:

```text
Controller Inventory
    -> Plan Capacity
    -> Add Controller
    -> Edit Controller
    -> current programmed Network / UID / IP maintenance
    -> Assign / Edit / Reassign / Unassign Displays
    -> Controller label request action
    -> PostgreSQL validation / audit
```

The application role must not receive broad Controller table DML merely to support these controls. Controlled writes use narrow server-authorized PostgreSQL functions.

The permanent Controller/Display relationship retains:

```text
PRIMARY KEY (controller_id, display_id)
```

The Directus multi-table relationship experiment is closed; do not distort the database model to accommodate Directus UI limitations.

## Current Production Data Baseline

The accepted FieldWiring data path was established on Parser V7/LOR2DB PostgreSQL materialization. Detailed wiring remains current-snapshot authority and Controller Inventory does not replace it.

Parser V7.0.11+ preserves grouped-DMX source detail on current DMX rows, including source Prop/channel/grid information. The legacy `preview_wiring_*_v6` compatibility views remain available for FormView/regression compatibility.

## Current Presentation Families

```text
Traditional LOR
    -> conventional A/C controller / numbered output

LOR + RGB
    -> Pixie controller / numbered RGB output

DMX + DumbRGB
    -> DMX network / fixture hookup

DMX + RGB — reviewed dense RGB cases
    -> E1.31 network / intelligent pixel-controller hookup
```

The generic compatibility-view `Controller` and `StartChannel` columns do not have one universal physical meaning across these families.

Permanent Controller Inventory supplements physical identity/context where governed relationships resolve the device. Remaining temporary E1.31/family-specific mappings are presentation evidence only and must remain centralized/replaceable until permanent Controller evidence fully covers those cases.

## Permanent Controller Resolver Contract

The accepted physical relationship basis is:

```text
physical controller = ref.controller.controller_id
physical Display     = ref.controller_display.display_id
wiring Display       = COALESCE(
    ref.controller_display.wiring_source_display_id,
    ref.controller_display.display_id
)
```

FieldWiring starts from the governed Controller-to-Display relationship. For AC/Pixie rows, current programmed Network/UID may distinguish which already-assigned physical Controller applies. Network/UID is never permanent identity.

For DMX/E1.31 families, do not claim an exact universe-to-physical-controller split unless governed evidence supports it.

## Current Browser/Application Behavior

The production application supports:

- permanent Display search and Stage/Scene browse;
- Display-ID-driven current context resolution;
- Scene-aware package resolution;
- A/C controller/output presentation;
- reviewed Pixie physical-output presentation;
- atomic V7.0.11+ DMX source-row consumption with scope guarding;
- CR50/DumbRGB fixture aggregation while retaining atomic source rows underneath;
- reviewed E1.31 physical-controller presentation for accepted dense RGB cases;
- permanent Controller Inventory browse/detail;
- Stage/Sub-stage-aware Controller filtering and free-text Stage-match confirmation;
- current programmed Controller Network/UID/IP facts;
- current Display assignments, firmware history, and label state;
- permanent Controller ID/model context in FieldWiring;
- bidirectional FieldWiring / Controller Inventory navigation;
- Controller capacity planning;
- Controller Add/Edit and assignment management for authorized roles;
- contextual help for non-obvious Controller fields;
- collapsible controller/presentation groups;
- long-list sticky controller context;
- shared image + Field Hookup workspace on desktop/laptop;
- field-appropriate mobile/phone behavior;
- same-scope wiring/context image resolution;
- conspicuous context-only image warning;
- Engineering Details for raw/troubleshooting data;
- generated/printed currentness and expiration information.

## Stage Folder / Marker Boundary

The established Stage/Sub-stage/Scene Google Drive structure remains the human-facing source for published wiring images and related field documentation.

FieldWiring uses the structured scope and inspects only the applicable same-scope published Wiring branch. It must not borrow a parent Stage wiring image for a resolved Scene/Sub-stage merely because a more-specific wiring image is missing.

Wiring images are supplemental rough-location guidance. Hookup data remains primary and must stay usable when no image exists.

The accepted FieldWiring marker contract is:

```text
<resolved Stage / Sub-stage / Scene root>   marker required
Wiring                                      marker required
PreviewBackground                           marker required when used as controlled same-scope context
Wiring\BackgroundStage                      NO separate marker
Wiring\MusicalStage                         NO separate marker
SourceDocs                                  excluded / no marker
```

The marker on `Wiring` guards the selected `BackgroundStage` or `MusicalStage` child branch.

The Procedure system has a separate deeper marker contract. Do not project that Procedure rule onto FieldWiring child Wiring branches.

Production server access to the Google hierarchy is provided through the persistent read-only Display Folders filesystem documented by MSB-Server-Management.

## Existing Display Scan Runtime

The Display QR lookup is a Directus endpoint deployed on `msb-prod-db`:

```text
/opt/directus/extensions/directus-extension-scan/
```

Git-controlled application source is preserved at:

```text
Scan/directus-extension-scan/
```

Current routes include:

```text
/scan/
/scan/DISP/:key
/scan/CONT/:key
/scan/DISP/:key/test
/scan/DISP/:key/container
/scan/DISP/:key/work-orders
```

`/scan/DISP/:key` resolves permanent `ref.display.display_id` and presents independent Display, Testing, Field Wiring, Container, and Work Order actions.

The Field Wiring action is:

```text
Field Wiring
    -> /fieldwiring/wiring.html?display_id=<display_id>
```

FieldWiring availability is not a prerequisite for rendering the other Scan actions.

Directus record destinations use the existing Directus public origin:

```text
https://db.sheboyganlights.org/
```

rather than root-relative `/admin/...` links under `my.sheboyganlights.org`.

## System Boundary

### Production Database responsibility

- controlled current LOR-derived wiring snapshot;
- permanent Display and Controller identities and database-owned relationships;
- FieldWiring and Scan application/business source;
- scan-to-FieldWiring `display_id` contract;
- Wiring/Controller Inventory/Setup integration boundaries;
- governed request state for workflows implemented in the Production Database.

### FieldWiring responsibility

- task-focused field hookup lookup/presentation;
- Stage/Sub-stage/Scene-aware scope resolution;
- device-family-aware physical hookup presentation;
- permanent Controller context/cross-links;
- Controller Inventory operator UX hosted by the shared FieldWiring application;
- current image/context presentation;
- browser/desktop/phone UX;
- currentness/expiration presentation;
- application-specific API/client code and tests.

### Controller Inventory responsibility

- permanent physical Controller identity;
- current Controller model/status/location/firmware/programmed configuration;
- current Controller-to-Display relationships;
- reviewed duplicated-channel wiring-source relationships;
- browser-native governed operational workflow;
- Controller label request state.

### LabelPrintService responsibility

- polling governed pending print requests that belong to its accepted scope;
- logical-profile-to-runtime printer/template/media mapping;
- Brother/b-PAC physical rendering;
- print-service preflight, finalization, logging, and recovery.

Controller physical print polling belongs in `Gregovate/MSB_LabelPrintService`, not the Controller/FieldWiring application.

### MSB-Server-Management responsibility

- FieldWiring service/runtime deployment;
- persistent Display Folders mount;
- protected reverse proxies;
- Directus scan-extension deployment/restart/recovery;
- runtime hashes and rollback.

## Dependencies

- [LOR2DB Ingest](../02_LOR2DB_Ingest/README.md)
- [Database Foundation](../01_Database_Foundation/README.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [MSB-Server-Management](https://github.com/Gregovate/MSB-Server-Management)

## Known Open Work

Current cross-workstream open work includes:

- Controller physical label polling/printing in `Gregovate/MSB_LabelPrintService`;
- FieldWiring wire/plug/channel-label **request** integration as a separate Production Database subproject, with physical polling/printing remaining in LabelPrintService;
- replacement of remaining temporary FieldWiring physical presentation mappings only when permanent Controller evidence fully covers their real cases;
- Mega Cube and Whoville Matrix compact CustomGrid expansion, which remains a separate parser-materialization limitation;
- offline/self-contained field copy;
- deferred Scan regression cases when suitable physical/data examples are available.

Controller reporting is intentionally deferred until normal crew use establishes actual reporting requirements.

## FormView Cutover Rule

FieldWiring production operation does **not** automatically retire FormView.

Keep FormView available as fallback/reference until a separate cutover decision is accepted.

## Resume Development

The Controller Inventory V0.4.0 implementation is production-deployed and in PR/branch closeout. Do not reopen its completed Add/Edit/assignment work as a Wiring backlog item.

New work should begin as a separate bounded subproject from current repository/runtime evidence. The next known Wiring feature is the governed FieldWiring wire-label request workflow; physical printer polling/rendering remains a separate LabelPrintService responsibility.

For current Controller/Wiring authority use:

- [Controller Inventory](../08_Controller_Inventory/README.md)
- [Controller Management Application Boundary](../08_Controller_Inventory/Controller_Management_Application_Boundary_2026-08-31.md)
- [Controller V0.4.0 Post-Deployment Operational Decisions](../08_Controller_Inventory/Controller_V0.4.0_Post_Deployment_Operational_Decisions_2026-09-03.md)
- [FieldWiring / Controller Inventory Handoff](FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)

Every deployed change affecting FieldWiring or shared resolver code must preserve the FieldWiring + Procedures regression gate. Durable findings and accepted changes must be written into the responsible Controller/Wiring documents during the work rather than reconstructed from conversation history later.

## Related Systems

- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md)
- [MSB-Server-Management](https://github.com/Gregovate/MSB-Server-Management)
- [System Boundary and Repository Ownership Standard](../../../../System_Documentation/Standards/System_Boundary_and_Repository_Ownership_Standard.md)
