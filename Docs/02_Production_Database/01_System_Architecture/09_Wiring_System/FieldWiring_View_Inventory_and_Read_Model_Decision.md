# FieldWiring View Inventory and Read-Model Decision

| Document control | Value |
|---|---|
| Status | DRAFT — wiring conversion design evidence |
| Current revision | 2026-08-17 |
| Sub-project | FieldWiring |
| Owner | MSB Database Administrator |
| Code/schema status | Documentation only; no code/schema change authorized |

## Purpose

This document classifies the current V7 parser and PostgreSQL reporting views for the FormView-to-FieldWiring conversion and records the current read-model direction.

The goal is to reuse current snapshot-derived wiring logic without creating a second stored wiring system.

## Accepted Authority Decision

LOR remains authoritative for wiring topology.

The current V7 parser materializes the approved LOR preview set into SQLite, and the LOR2DB ingest copies the normalized snapshot tables into append-only `lor_snap` storage without reinterpreting wiring.

Therefore the current direction is:

```text
DO NOT create ref.wiring
DO NOT create ops.wiring
DO NOT manually copy wiring into a second persistent table
```

FieldWiring should consume controlled read-only views/API contracts over the latest `lor_snap` snapshot plus permanent Production Database identity/Scene relationships.

## FormView V7 Compatibility Test Result

FormView 0.3.1 was manually pointed at:

```text
G:\Shared drives\MSB Database\database\lor_output_v7_scene.db
```

For `Show Background Stage 21 Polar Bears`, FormView successfully loaded the expected Field Wiring table with 79 rows.

This is practical evidence that the V7 parser preserves the FormView wiring-view contract well enough for the Wiring table.

The image portion did not resolve because FormView still relies on its older Preview-level `BackgroundFile` image-resolution behavior. The current Scene/path-depth model is intentionally richer and belongs in FieldWiring rather than being rebuilt inside FormView.

## V7 Parser Wiring Views

### `preview_wiring_map_v6`

Classification: **CORE DERIVED WIRING MODEL**

Role:

- combines master `PROP`, `SUBPROP`, and DMX wiring legs;
- preserves Channel Name separately from Display Name;
- normalizes the source rows needed by both detailed and field-oriented presentation.

Future use:

- retain the logic;
- compatibility name may remain during transition;
- do not treat it as stored wiring authority.

### `preview_wiring_sorted_v6`

Classification: **PRESENTATION / COMPATIBILITY HELPER**

Role:

- sorted projection of the base wiring map;
- currently convenient for FormView detailed mode.

Future use:

- may remain for compatibility;
- FieldWiring does not need to depend on database-level sort order if the new read contract provides deterministic application sorting.

### `preview_wiring_fieldmap_v6`

Classification: **CORE FIELD-WIRING DERIVATION**

Role:

- derives FIELD versus INTERNAL relationships;
- preserves source type, channel/display/network/controller data;
- detects cross-Display circuit use.

Future use:

- retain the logic;
- engineering/details view can expose this richer set when Field Wiring mode is OFF.

### `preview_wiring_fieldlead_v6`

Classification: **PRIMARY FIELDWIRING LOGIC**

Role:

- returns one practical lead per:

```text
Preview + Network + Controller + StartChannel + Display
```

- preserves separate Display relationships when more than one Display legitimately shares a circuit.

Future use:

- this is the core source for normal Field Wiring mode;
- FieldWiring must preserve its semantics even if a new browser-facing view exposes additional identity/context columns.

### `preview_wiring_circuit_rollup_v6`

Classification: **QA / ENGINEERING AUDIT**

Role:

- groups practical field leads by circuit;
- exposes multiple Displays sharing the same network/controller/channel.

Future use:

- retain as QA/audit support;
- useful during FieldWiring validation and troubleshooting;
- not the normal technician table.

### `preview_wiring_fieldonly_v6`

Classification: **CONVENIENCE / LEGACY COMPATIBILITY**

Role:

- filters `preview_wiring_fieldmap_v6` to `ConnectionType='FIELD'`.

Future use:

- may remain for compatibility;
- not necessary as the primary new browser contract when `fieldlead` already represents the practical one-lead-per-Display/circuit result.

## V7 Parser Scene Views

### `scene_displays_vw`

Classification: **CORE SCENE REPORTING / FIELDWIRING SCOPE EVIDENCE**

Role:

- publishes Display-level Scene membership rather than raw parser PropID plumbing;
- includes Preview and Scene identity/context;
- preserves Scene background, Preview background, and effective BackgroundFile behavior;
- is the parser's business-facing Scene reporting contract.

Future use:

- conceptually required for Scene-aware FieldWiring;
- should be represented in the PostgreSQL current-snapshot read layer rather than recreated by text-name matching in the browser.

### `scene_display_count_vw`

Classification: **QA / REPORTING**

Role:

- counts distinct Displays per Scene.

Future use:

- useful for validation and diagnostics;
- not a primary FieldWiring read source.

### Scene validation views

```text
scene_prop_count_vw
scene_duplicate_prop_assignment_vw
scene_null_stage_review_vw
```

Classification: **PARSER QA / VALIDATION**

Future use:

- remain parser/engineering validation tools;
- FieldWiring should not need to query them during normal operation.

## Stage Reporting Views

```text
stage_display_assets_v1
stage_display_inventory_only_v1
stage_display_assets_all_v1
stage_display_list_all_v1
stage_display_unassigned_v1
```

Classification: **FORMVIEW STAGE REPORTING / GENERAL REPORTING**

Role:

- support FormView Stage View and Stage/Preview/Display inventory reports.

Future decision:

- these are not part of the minimum first FieldWiring wiring contract;
- FormView cannot be retired completely until Stage View is replaced or explicitly retired;
- do not force these views into FieldWiring merely because they currently live in the same desktop application.

## PostgreSQL Repository View Stack

The repository file:

```text
Database/Basic_Query_Tools_Dev/postgres_create_views_lor_snap.sql
```

defines PostgreSQL equivalents of the six wiring views and the Stage reporting stack over `lor_snap.v_current_*` sources.

This is good evidence that the wiring derivation already has a PostgreSQL implementation path.

However, the repository-defined PostgreSQL view script does **not** currently include a PostgreSQL equivalent of the V7 parser's `scene_displays_vw` / Scene reporting layer.

That is the major current read-model gap for Scene-aware FieldWiring.

## Current Snapshot Inputs Already Present

The ingest and current-snapshot layer already expose the underlying data needed to build the missing Scene-aware read model, including current:

```text
lor_snap.v_current_previews
lor_snap.v_current_scenes
lor_snap.v_current_props
lor_snap.v_current_sub_props
lor_snap.v_current_dmx_channels
lor_snap.v_current_scene_lor_props
lor_snap.v_current_run
```

The ingest also verifies/uses the current wiring views against the latest snapshot.

Therefore the missing Scene-aware browser contract does not imply missing wiring data.

## Permanent Identity Inputs Already Present

Outside `lor_snap`, the Production Database already has permanent identity/context needed for scan/manual lookup:

```text
ref.display
ref.lor_scene
ref.lor_scene_display
ref.stage
```

These objects should supply permanent `display_id`, current Stage, promoted Scene membership, and Preview relationship.

The FieldWiring read model should join controlled identity relationships to snapshot-derived wiring by stable LOR/Preview identity rather than by Display Name alone.

## Minimum Read-Model Direction

The browser-facing FieldWiring contract should expose enough information to support:

```text
Display scan / manual lookup
    -> permanent display_id
    -> current Scene / Stage / Preview context
    -> field wiring rows
    -> Google Drive documentation-root/path evidence
    -> images
    -> report provenance
```

Minimum conceptual fields include:

```text
import_run_id
preview_uuid
preview_name
preview_revision
preview_background_file
scene identity/name when applicable
scene background_file when applicable
permanent stage_id
permanent display_id
Display Name
Channel Name
Network
Controller
StartChannel
EndChannel
Source
ConnectionType / CrossDisplay for engineering detail
DeviceType / LORTag for optional engineering detail
```

The exact SQL object and API surface remain to be designed after live verification.

## No New Wiring Table Decision

Current conclusion:

- wiring topology belongs in the latest `lor_snap` snapshot;
- reusable wiring transformations belong in controlled views/read models;
- permanent identity belongs in `ref`;
- operational records such as Work Orders remain in their own `ops`/subsystem objects;
- FieldWiring presentation state does not justify a new persistent wiring table.

A new table should only be proposed if live verification demonstrates information that cannot be represented safely from current authoritative objects.

## FormView Direction

Do not redesign FormView around Scene-aware resolution.

Current intended role during transition:

```text
FormView
    = known-good Wiring behavior reference
    = V7 SQLite comparison tool
    = temporary fallback where still operationally usable
```

FieldWiring should own the new work:

- Scene-aware scope;
- shared Scan / Find / Browse context;
- Google Drive path-resolution contract;
- browser image delivery;
- multi-image Scene packages;
- self-contained offline PDF/reporting.

A minimal FormView compatibility fix should only be considered if required for the current setup season and proven to be substantially smaller than implementing the same behavior in FieldWiring.

## Next Gate — Live Read-Only Verification

Before creating or changing SQL objects, inspect the deployed PostgreSQL database read-only and answer:

1. Do all six `lor_snap.preview_wiring_*` views exist in production?
2. Do their definitions match the repository/current V7 parser semantics?
3. Do `lor_snap.v_current_scenes` and `lor_snap.v_current_scene_lor_props` exist and expose the expected current snapshot?
4. Is any Scene display/reporting view already deployed but missing from the repository?
5. Does Stage 21 return the same 79 Field Wiring rows in PostgreSQL as the successful V7 FormView/SQLite test?
6. Do shared circuits preserve every Display relationship?
7. What read-only role/grants are available for the future browser service?

Only after those answers should we define or deploy the missing Scene-aware PostgreSQL read view/API contract.

## Related Documents

- [FieldWiring PostgreSQL Readiness Audit](FieldWiring_PostgreSQL_Readiness_Audit.md)
- [FieldWiring Engineering Recovery and Compatibility Contract](FieldWiring_Engineering_Recovery_and_Compatibility_Contract.md)
- [FieldWiring Field Presentation Requirements](FieldWiring_Field_Presentation_Requirements.md)
- [FieldWiring Scene Scope and Offline Report Requirements](FieldWiring_Scene_Scope_and_Offline_Report_Requirements.md)
- [Shared Field Context Resolution Contract](../07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)
- [Google Drive Path Resolution Contract](../../../00_Project_Overview/02-Google_Drive_Path_Resolution_Contract.md)
- [LOR Preview Parser Architecture](../../../01_LOR_System/02_Data_Extraction/LOR_Preview_Parser_Architecture.md)
