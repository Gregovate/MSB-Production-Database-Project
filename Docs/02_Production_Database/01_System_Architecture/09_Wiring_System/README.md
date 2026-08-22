# Wiring System

This subsystem documents how MSB presents, enriches, and operationally uses wiring information derived from LOR-authoritative show topology.

## Current State

FormView remains the transitional production fallback/reference. Draw.io remains part of the wiring-diagram authoring workflow. PostgreSQL contains the current LOR-derived wiring snapshot.

The active browser replacement is **FieldWiring**. FieldWiring is now at **release-candidate status for server/tablet/phone testing**: the parser/PostgreSQL data path, browser application, device-family presentation, Drive scope behavior, image/table workspace, and laptop acceptance have all been exercised against current production-derived data.

The current proven production data baseline is:

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

PostgreSQL migration `0037_add_dmx_source_detail.sql` is installed in production, Run 51 was ingested successfully, and the current DMX source-detail validation passed with all 508 rows populated. The legacy `preview_wiring_*_v6` compatibility views remain unchanged for FormView/regression compatibility.

The FieldWiring browser application is implemented under:

```text
FieldWiring/Application/
```

Start/resume with these current documents:

- [FieldWiring Release Candidate Handoff and Development Runbook — 2026-08-21](FieldWiring_Release_Candidate_Handoff_and_Development_Runbook_2026-08-21.md)
- [FieldWiring Server Deployment and Scan Integration Plan — 2026-08-21](FieldWiring_Server_Deployment_and_Scan_Integration_Plan_2026-08-21.md)
- [FieldWiring Application README](../../../../FieldWiring/Application/README.md)
- [FieldWiring Engineering Recovery and Compatibility Contract](FieldWiring_Engineering_Recovery_and_Compatibility_Contract.md)
- [FieldWiring PostgreSQL DMX Propagation Production Acceptance](FieldWiring_PostgreSQL_DMX_Propagation_Production_Acceptance_2026-08-21.md)
- [FieldWiring V7.0.11 Production SQLite Acceptance](FieldWiring_V7.0.11_Production_SQLite_Acceptance_2026-08-21.md)
- [FieldWiring Drive Context Resolver Engineering Design](FieldWiring_Drive_Context_Resolver_Engineering_Design.md)
- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Physical Controller / Output Presentation Contract](FieldWiring_Physical_Controller_Output_Presentation_Contract.md)
- [FieldWiring DMX / DumbRGB Field Presentation Contract](FieldWiring_DMX_DumbRGB_Field_Presentation_Contract.md)
- [FieldWiring E1.31 Dense RGB Field Presentation Contract](FieldWiring_E131_Dense_RGB_Field_Presentation_Contract.md)
- [FieldWiring Scene Scope and Offline Report Requirements](FieldWiring_Scene_Scope_and_Offline_Report_Requirements.md)
- [FieldWiring Controller Inventory Handoff](FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)
- [Shared Field Context Resolution Contract](../07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)
- [Deployed Display Scan Runtime Boundary](../07_Labeling_and_Scanning/Deployed_Display_Scan_Runtime_Boundary.md)
- [FormView Engineering Architecture](../../../01_LOR_System/04_FormView/FormView_Engineering_Architecture.md)

The repository remains the durable engineering record. Conversation history is not the recovery mechanism.

## Design Intent

Provide task-focused field hookup information without creating a second topology-authoring system.

The intended data path is:

```text
Existing Display QR / operator lookup
    -> existing authenticated Display scan hub
        -> permanent display_id
            -> shared Field Context resolver
                -> operator chooses Field Wiring
                    -> current PostgreSQL/LOR wiring contract
                        -> device-family presentation
                            -> browser / tablet / phone
```

FieldWiring translates technical LOR topology into the physical connection model the installer sees.

Current accepted presentation families are:

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

LOR remains the upstream authority for show topology and enters PostgreSQL through the controlled LOR2DB pipeline.

## System Boundary

**Relationship Class:** Dedicated Database-Backed Presentation / Field Application over a Production Database subsystem with an Integrated Upstream Dependency on LOR/LOR2DB and an Existing Deployed Scan-Runtime Dependency.

### Authority Boundary

LOR remains authoritative for:

- controller and addressing assignments;
- channel numbers/ranges;
- DMX/E1.31/network assignments; and
- show wiring topology.

PostgreSQL provides the shared current snapshot and permanent Production Database identities. FieldWiring interprets and presents that data. It does not independently redefine topology.

### Existing Display scan runtime

The current Display QR lookup is already implemented outside FieldWiring as a deployed Directus endpoint on `msb-prod-db`:

```text
/opt/directus/extensions/directus-extension-scan/
```

Verified routes include:

```text
/scan/
/scan/DISP/:key
/scan/DISP/:key/test
/scan/DISP/:key/container
/scan/DISP/:key/work-orders
```

FieldWiring must consume the permanent `display_id` resolved by that existing scan hub and add **Field Wiring** as a downstream task destination. It must not create a competing QR payload, scanner route, or duplicate Testing/Work Order scan logic.

See [Deployed Display Scan Runtime Boundary](../07_Labeling_and_Scanning/Deployed_Display_Scan_Runtime_Boundary.md) and the separate [MSB-Server-Management](https://github.com/Gregovate/MSB-Server-Management) repository for runtime administration/recovery.

### Production Database responsibility

- store the controlled current LOR-derived wiring snapshot;
- link current LOR data to permanent Production Database Display identity;
- preserve database-owned operational relationships; and
- provide the read contract consumed by FieldWiring.

### FieldWiring responsibility

- task-focused hookup lookup/presentation;
- Stage/Sub-stage/Scene-aware scope resolution;
- device-family-aware physical hookup presentation;
- current image/context presentation without weakening source-folder rules;
- field-friendly browser/tablet/phone behavior;
- print/PDF currentness and expiration information;
- application-specific API/client code, deployment configuration, and tests.

FieldWiring must not become an independent topology-authoring system.

## Current Browser/Application Behavior

The current release candidate supports:

- permanent Display search and Stage/Scene browse;
- Scene-aware package resolution;
- A/C controller/output presentation;
- reviewed Pixie physical-output presentation;
- atomic V7.0.11 DMX source-row consumption;
- CR50/DumbRGB fixture aggregation for technician presentation while retaining atomic source rows underneath;
- reviewed E1.31 temporary physical-controller maps for Mega Tree, Mega Ball, and Mega Star;
- exact universe/channel range and valid RGB pixel-count presentation;
- collapsible controller/presentation groups;
- long-list sticky controller context;
- shared laptop/desktop image + Field Hookup workspace with `More Image`, `Balanced`, `More Hookup`, and draggable divider;
- normal wiring images without a redundant badge;
- conspicuous warning when a same-scope PreviewBackground image is context only and not wiring;
- Engineering Details for raw/troubleshooting data;
- hard-copy generation/currentness/expiration information.

Tablet/phone field acceptance remains the next device-level gate.

## Stage Folder / Documentation Boundary

The established Stage/Sub-stage/Scene Google Drive structure remains the human-facing source for published wiring images and related field documentation.

The common Drive resolver identifies the structured scope. FieldWiring then inspects only the applicable same-scope published Wiring branch. It must not borrow a parent Stage wiring image for a resolved Scene/Sub-stage merely because the more-specific wiring image is missing.

Wiring images are supplemental rough-location guidance. Hookup data remains primary and must stay usable when no image exists.

The current controlled marker rule requires the standard marker in **every folder used as part of the FieldWiring application path**. For the current wiring path this includes:

```text
<resolved Stage / Sub-stage / Scene root>
Wiring
Wiring\BackgroundStage   (when selected)
Wiring\MusicalStage      (when selected)
PreviewBackground        (when used as same-scope context)
```

The release-candidate `wiring_images.py` currently enforces the root, `Wiring`, and `PreviewBackground` markers but does not yet require the marker in the selected `BackgroundStage` / `MusicalStage` child branch. This is a known implementation gap against the current Google Drive path contract and must be corrected/tested before production deployment acceptance.

The current laptop environment sees that tree through:

```text
G:\Shared drives\Display Folders
```

A Linux production server will need a controlled read-only server-visible equivalent plus deterministic translation of stored Windows `folder_path` / `BackgroundFile` evidence. This is a deployment requirement, not permission to duplicate or flatten the source tree.

## Controller Inventory Boundary

FieldWiring currently contains explicit reviewed **temporary** E1.31 presentation mappings for known cases such as Mega Tree, Mega Ball, and Mega Star.

These are not permanent controller asset identities.

Controller Inventory remains responsible for permanent controller identity, normalized model/family, current assignment, output capacity, network/IP configuration where operationally needed, and deployment/history.

Do not infer permanent controller identity from universe, IP address, Unit ID, Display Name, or source row position.

## Dependencies

- [LOR2DB Ingest](../02_LOR2DB_Ingest/README.md)
- [Database Foundation](../01_Database_Foundation/README.md)
- [Controller Inventory](../08_Controller_Inventory/README.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Deployed Display Scan Runtime Boundary](../07_Labeling_and_Scanning/Deployed_Display_Scan_Runtime_Boundary.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [MSB-Server-Management](https://github.com/Gregovate/MSB-Server-Management)

## Current Responsibilities

- field wiring/hookup presentation;
- Display/controller/network lookup;
- Scene-aware field package resolution;
- physical-output interpretation for A/C and Pixie controllers;
- DMX/DumbRGB presentation that does not confuse universe/channel addressing with physical plugs;
- E1.31 presentation that does not confuse universe with physical controller identity;
- future controlled channel/plug-label requests through LabelPrintService;
- generated browser/PDF field documentation;
- future disconnected/offline field-copy support.

## Resume Development

The parser, PostgreSQL propagation, Run 51 production ingest, FieldWiring DMX read adapter, device-family presentation, and laptop UI acceptance are complete enough for a release candidate.

FieldWiring is now merged to `main`; do not repeat the old pre-merge branch-integration steps from the August 21 checkpoint.

The next engineering sequence is:

1. refresh current `main` before making further FieldWiring changes;
2. update `wiring_images.py` and tests so the selected `BackgroundStage` / `MusicalStage` branch marker is enforced in addition to the existing scope/Wiring markers;
3. run the full FieldWiring application test suite;
4. deploy the backend on `msb-prod-db` using live read-only PostgreSQL;
5. establish the read-only server-visible Display Folders/image source;
6. publish FieldWiring through the protected `my.sheboyganlights.org` origin using the existing Synology/`msb-prod-db` browser-application pattern;
7. test tablets/phones;
8. add **Field Wiring** to the existing Display QR task hub using the already-resolved permanent `display_id`.

Use [FieldWiring Server Deployment and Scan Integration Plan](FieldWiring_Server_Deployment_and_Scan_Integration_Plan_2026-08-21.md) for the deployment sequence, but reconcile any older checkpoint wording against this current README before execution.

## Known Open Work

- enforce the marker on every selected FieldWiring application-path folder, including `BackgroundStage` / `MusicalStage`;
- production server deployment;
- server-visible Display Folders mount/synchronization and Windows-path translation;
- least-privilege production FieldWiring DB role/grants;
- tablet/phone acceptance;
- Display scan-hub Field Wiring action;
- Controller Inventory replacement of temporary E1.31 mappings;
- Mega Cube and Whoville Matrix compact CustomGrid expansion remain a separate parser-materialization limitation; FieldWiring must not fabricate absent rows;
- plug/channel-label request integration;
- offline/self-contained field copy.

## FormView Cutover Rule

Merging FieldWiring to `main` does **not** retire FormView.

Keep FormView available as fallback/reference until FieldWiring is deployed on the server, reachable from the existing Display scan hub, and accepted on the intended field tablets/phones.

## Related Systems

- [Setup and Deployment](../12_Setup_and_Deployment/README.md)
- [Labeling and Scanning](../07_Labeling_and_Scanning/README.md)
- [Network Infrastructure](../10_Network_Infrastructure/README.md)
- [Site Infrastructure / GIS](../11_Site_Infrastructure_GIS/README.md)
- [MSB-Server-Management](https://github.com/Gregovate/MSB-Server-Management)
- [System Boundary and Repository Ownership Standard](../../../../System_Documentation/Standards/System_Boundary_and_Repository_Ownership_Standard.md)
