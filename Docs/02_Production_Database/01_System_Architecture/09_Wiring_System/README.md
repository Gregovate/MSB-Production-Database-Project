# Wiring System

This subsystem documents how MSB presents, enriches, and operationally uses wiring information derived from LOR-authoritative show topology.

## Current State

**FieldWiring is production-operational as of 2026-08-22.**

Current accepted production state:

- browser application published at `https://my.sheboyganlights.org/fieldwiring/`;
- live read-only PostgreSQL backend;
- systemd-hosted backend operational on `192.168.5.9:8790`;
- persistent read-only Google `Display Folders` filesystem operational;
- protected Synology reverse proxy operational;
- desktop and phone acceptance passed;
- Display search repaired and production-tested;
- FieldWiring remains read-only;
- FormView remains available as fallback/reference.

The current remaining cutover milestone is **Display Scan Integration**: add one independent **Field Wiring** action to the existing `/scan/DISP/:key` hub using the already-resolved permanent `ref.display.display_id`.

The verified deep link is:

```text
/fieldwiring/wiring.html?display_id=<permanent display_id>
```

The originally conceptual `/fieldwiring/?display_id=...` route is not the current direct-entry contract. The landing page does not consume `display_id`; the wiring page does.

The existing Display scan runtime has now been reconstructed and documented before modification. Current production `dist/index.js` SHA-256 is:

```text
824aa56857c3d52c3ba9186c4721313e2172dc24ec32653045bb7bf3b008d7af
```

The deployed scan extension currently lacks the `src/index.js` declared by its `package.json`. Preserve/recover the accepted scan implementation into Git before substantial scan-platform expansion.

## Start Here

For the current work, begin with:

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
- CR50/DumbRGB fixture aggregation for technician presentation while retaining atomic source rows underneath;
- reviewed E1.31 physical-controller presentation for accepted dense RGB cases;
- collapsible controller/presentation groups;
- long-list sticky controller context;
- shared image + Field Hookup workspace on desktop/laptop;
- field-appropriate mobile/phone behavior;
- same-scope wiring/context image resolution;
- conspicuous context-only image warning;
- Engineering Details for raw/troubleshooting data;
- generated/printed currentness and expiration information.

## Stage Folder / Image Boundary

The established Stage/Sub-stage/Scene Google Drive structure remains the human-facing source for published wiring images and related field documentation.

FieldWiring uses the structured scope and inspects only the applicable same-scope published Wiring branch. It must not borrow a parent Stage wiring image for a resolved Scene/Sub-stage merely because a more-specific wiring image is missing.

Wiring images are supplemental rough-location guidance. Hookup data remains primary and must stay usable when no image exists.

Production server access to this hierarchy is provided through the persistent read-only Display Folders filesystem documented by MSB-Server-Management.

## Existing Display Scan Runtime

The current Display QR lookup is implemented outside FieldWiring as a deployed Directus endpoint on `msb-prod-db`:

```text
/opt/directus/extensions/directus-extension-scan/
```

Current verified routes include:

```text
/scan/
/scan/DISP/:key
/scan/CONT/:key
/scan/DISP/:key/test
/scan/DISP/:key/container
/scan/DISP/:key/work-orders
```

`/scan/DISP/:key` already resolves permanent `ref.display.display_id`.

FieldWiring must consume that identity rather than creating a second scanner route or duplicating Testing/Work Order/Container logic.

The required action is:

```text
Field Wiring
    -> /fieldwiring/wiring.html?display_id=<display_id>
```

No FieldWiring API call should occur merely to render the scan hub. A FieldWiring outage must not disable existing scan functions.

See [FieldWiring Scan Integration Engineering Handoff](../07_Labeling_and_Scanning/FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md).

## Controller Inventory Boundary

FieldWiring currently contains explicit reviewed temporary physical presentation mappings for known controller cases.

These are not permanent controller asset identities.

Controller Inventory remains responsible for permanent controller identity, normalized model/family, current assignment, output capacity, network/IP configuration where operationally needed, and deployment/history.

Do not infer permanent controller identity from universe, IP address, Unit ID, Display Name, or source row position.

## System Boundary

**Relationship Class:** Dedicated Database-Backed Presentation / Field Application over a Production Database subsystem with an Integrated Upstream Dependency on LOR/LOR2DB and an Existing Deployed Scan-Runtime Dependency.

### Production Database responsibility

- controlled current LOR-derived wiring snapshot;
- permanent Display identity and database-owned relationships;
- FieldWiring read/data contracts;
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
- internal listener/service management;
- persistent Display Folders mount;
- protected reverse proxy;
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

Current priority:

- recover/preserve the accepted Display scan implementation in a Git-controlled source/deployment boundary;
- add the independent Field Wiring scan action;
- verify all existing scan actions plus the FieldWiring deep link with a real permanent Display QR;
- close the Production Database and Server Management handoffs after acceptance.

Separate future work:

- Controller Inventory replacement of temporary presentation mappings;
- Mega Cube and Whoville Matrix compact CustomGrid expansion remains a separate parser-materialization limitation; FieldWiring must not fabricate absent rows;
- plug/channel-label request integration;
- offline/self-contained field copy.

## FormView Cutover Rule

FieldWiring production operation does **not** automatically retire FormView.

Keep FormView available as fallback/reference until a separate cutover decision is accepted after the scan integration and any remaining field acceptance concerns are resolved.

## Resume Development

### Current work — Scan Integration

1. Read [FieldWiring Scan Integration Engineering Handoff](../07_Labeling_and_Scanning/FieldWiring_Scan_Integration_Engineering_Handoff_2026-08-22.md).
2. Read [Deployed Display Scan Runtime Boundary](../07_Labeling_and_Scanning/Deployed_Display_Scan_Runtime_Boundary.md).
3. Read the corresponding MSB-Server-Management Directus/FieldWiring runtime handoffs.
4. Preserve/recover the current camera-enabled scan implementation in Git.
5. Add the minimal Field Wiring action using only permanent `display_id`.
6. Run the complete existing-route regression/FieldWiring acceptance matrix.
7. Update both repository handoffs and merge through the normal workflow.

### Next project — Setup/Deployment

After Scan Integration closes, begin a separate Setup/Deployment engineering thread/branch from [Setup and Deployment](../12_Setup_and_Deployment/README.md).

That work is expected to involve substantial Container and Storage Location scanning for setup season. Reconstruct the real pull/stage/load/delivery process before designing schema, scan-session state, or a broader scan-platform refactor.

## Related Systems

- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md)
- [MSB-Server-Management](https://github.com/Gregovate/MSB-Server-Management)
- [System Boundary and Repository Ownership Standard](../../../../System_Documentation/Standards/System_Boundary_and_Repository_Ownership_Standard.md)
