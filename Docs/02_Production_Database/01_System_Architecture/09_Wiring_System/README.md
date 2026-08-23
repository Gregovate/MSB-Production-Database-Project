# Wiring System

This subsystem documents how MSB presents, enriches, and operationally uses wiring information derived from LOR-authoritative show topology.

## Current State

**FieldWiring and its Display Scan integration are production-operational as of 2026-08-22 local / 2026-08-23 UTC.**

Accepted production state:

- FieldWiring browser application: `https://my.sheboyganlights.org/fieldwiring/`;
- Display Scan application: `https://my.sheboyganlights.org/scan/`;
- live read-only PostgreSQL backend;
- systemd-hosted FieldWiring backend on `192.168.5.9:8790`;
- persistent read-only Google `Display Folders` filesystem operational;
- protected Synology reverse proxies operational;
- desktop and phone FieldWiring acceptance passed;
- FieldWiring Display search repaired and production-tested;
- existing Display QR/scan hub includes the independent **Field Wiring** action;
- Directus-facing Scan actions use the established `https://db.sheboyganlights.org/` origin;
- FormView remains available as fallback/reference.

The accepted FieldWiring deep link is:

```text
/fieldwiring/wiring.html?display_id=<permanent display_id>
```

The scan hub passes only the permanent `ref.display.display_id`. No LOR UUID, Stage key, Scene UUID, controller address, or Google Drive path is part of the QR-to-FieldWiring identity contract.

The accepted current Scan runtime artifact SHA-256 is:

```text
b4f6c27f4880a8eaf8a90d8d55c7939c5bd190645dca9329344a86c3175cb20f
```

## Start Here

For current production/recovery state, begin with:

- [FieldWiring Scan Integration Engineering Handoff — 2026-08-22](../07_Labeling_and_Scanning/FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md)
- [Deployed Display Scan Runtime Boundary](../07_Labeling_and_Scanning/Deployed_Display_Scan_Runtime_Boundary.md)
- [FieldWiring Application README](../../../../FieldWiring/Application/README.md)
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

LOR remains authoritative for show topology, controller/address assignments, channels, DMX/E1.31/network assignments, and related source wiring configuration.

PostgreSQL provides the controlled current snapshot plus permanent Production Database identities and database-owned relationships.

FieldWiring interprets and presents that information for field use. It must not become a competing topology-authoring system.

## Current Production Data Baseline

The accepted FieldWiring data path was established against:

```text
import_run_id          51
parser_version         V7.0.11
ingest_script_version  V0.4.2
current DMX rows       508
```

Parser V7.0.11 additively preserves grouped-DMX source detail on every current DMX row:

```text
RawPropID
ChannelName
ChannelGridRowNumber
```

PostgreSQL migration `0037_add_dmx_source_detail.sql` is installed in production. The legacy `preview_wiring_*_v6` compatibility views remain unchanged for FormView/regression compatibility.

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

Current reviewed temporary E1.31 physical mappings remain presentation recovery evidence, not permanent Controller Inventory identity.

## Current Browser/Application Behavior

The production application supports:

- permanent Display search and Stage/Scene browse;
- Display-ID-driven current context resolution;
- Scene-aware package resolution;
- A/C controller/output presentation;
- reviewed Pixie physical-output presentation;
- atomic V7.0.11 DMX source-row consumption;
- CR50/DumbRGB fixture aggregation while retaining atomic source rows underneath;
- reviewed E1.31 physical-controller presentation for accepted dense RGB cases;
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

The marker on `Wiring` guards the selected `BackgroundStage` or `MusicalStage` child branch. The production FieldWiring implementation already matches this contract; no child-marker code change is required.

The future Procedure system has a separate deeper marker contract for `Procedures`, task branches, and Setup/Takedown `images`. Do not project that Procedure rule onto FieldWiring child Wiring branches.

Production server access to the Google hierarchy is provided through the persistent read-only Display Folders filesystem documented by MSB-Server-Management.

## Existing Display Scan Runtime

The Display QR lookup is a Directus endpoint deployed on `msb-prod-db`:

```text
/opt/directus/extensions/directus-extension-scan/
```

Git-controlled application source is now preserved at:

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

See [FieldWiring Scan Integration Engineering Handoff](../07_Labeling_and_Scanning/FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md).

## Scan Acceptance Summary

Accepted regression evidence includes:

- public `/scan/` HTTP 200 and `/scan` redirect;
- manual `DISP:141` -> `TC-ChristmasHippo`;
- Open Display Record -> correct Directus record;
- Open Container -> correct assigned Container;
- positive Testing redirect using `QV-SHRStocking`;
- Work Orders = 0 disabled state;
- Field Wiring -> correct `TC-ChristmasHippo` wiring package;
- phone camera initialization and live preview;
- final deployed Scan hash `b4f6c27f...175cb20f`.

Physical QR decode and positive one/multiple Work Order cases were not available during acceptance and remain explicitly deferred regression cases.

## Controller Inventory Boundary

FieldWiring currently contains explicit reviewed temporary physical presentation mappings for known controller cases.

These are not permanent controller asset identities.

Controller Inventory remains responsible for permanent controller identity, normalized model/family, current assignment, output capacity, network/IP configuration where operationally needed, and deployment/history.

Do not infer permanent controller identity from universe, IP address, Unit ID, Display Name, or source row position.

## System Boundary

### Production Database responsibility

- controlled current LOR-derived wiring snapshot;
- permanent Display identity and database-owned relationships;
- FieldWiring and Scan application/business source;
- scan-to-FieldWiring `display_id` contract;
- Wiring/Controller Inventory/Setup integration boundaries.

### FieldWiring responsibility

- task-focused field hookup lookup/presentation;
- Stage/Sub-stage/Scene-aware scope resolution;
- device-family-aware physical hookup presentation;
- current image/context presentation;
- browser/desktop/phone UX;
- currentness/expiration presentation;
- application-specific API/client code and tests.

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

Separate future work includes:

- Controller Inventory replacement of temporary presentation mappings;
- Mega Cube and Whoville Matrix compact CustomGrid expansion, which remains a separate parser-materialization limitation;
- plug/channel-label request integration;
- offline/self-contained field copy;
- deferred Scan regression cases when suitable physical/data examples are available.

## FormView Cutover Rule

FieldWiring production operation does **not** automatically retire FormView.

Keep FormView available as fallback/reference until a separate cutover decision is accepted.

## Resume Development

FieldWiring Scan Integration is closed as accepted production work. Before merging this engineering branch, reconcile it with current `main` and preserve the accepted marker contract above.

The next major Production Database project is [Setup and Deployment](../12_Setup_and_Deployment/README.md). Reconstruct the real Container/Location pull, staging, load, delivery, and park-placement workflow before designing new schema, scan-session state, or a broader scan-platform refactor.

## Related Systems

- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md)
- [MSB-Server-Management](https://github.com/Gregovate/MSB-Server-Management)
- [System Boundary and Repository Ownership Standard](../../../../System_Documentation/Standards/System_Boundary_and_Repository_Ownership_Standard.md)
