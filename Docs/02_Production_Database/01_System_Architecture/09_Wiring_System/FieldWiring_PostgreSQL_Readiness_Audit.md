# FieldWiring PostgreSQL Readiness Audit

| Document control | Value |
|---|---|
| Status | DRAFT — repository-definition audit only |
| Current revision | 2026-08-17 |
| Sub-project | FieldWiring |
| Owner | MSB Database Administrator |
| Live database verification | NOT YET PERFORMED IN THIS AUDIT |
| Schema/code change status | HOLD |

## Purpose

This audit compares the proven/current FormView wiring contract with the current V7 parser and repository-defined PostgreSQL objects to determine what is already available for a browser-based FieldWiring replacement and what still requires verification.

This is not a migration and does not authorize schema changes.

## Sources Compared

Primary sources inspected:

- `LOR/FormView/FormView.py` — FormView 0.3.1 application queries and behavior;
- `Docs/01_LOR_System/02_Data_Extraction/Parser/parse_props_v7_scene_parser.py` — current V7.0.10 parser and SQLite wiring-view definitions;
- `Database/Basic_Query_Tools_Dev/postgres_create_views_lor_snap.sql` — repository-defined PostgreSQL wiring/report view stack;
- `LOR2DB/02_Reconciliation/reconciliation/migrations/0020_expose_current_snapshot_provenance.sql` — current-snapshot Preview/provenance interface;
- `LOR2DB/02_Reconciliation/reconciliation/current_procedures/P2_display_promotion.sql` — permanent Display/Stage promotion contract;
- `LOR2DB/02_Reconciliation/reconciliation/current_procedures/P3_scene_promotion.sql` — current Scene promotion contract;
- `LOR2DB/02_Reconciliation/reconciliation/current_procedures/P4_scene_display_promotion.sql` — permanent Display-to-Scene membership contract;
- `Docs/01_LOR_System/02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md` — deterministic field-documentation scope rules.

## Current V7 Parser Wiring Contract

The current parser creates these compatibility views in SQLite:

```text
preview_wiring_map_v6
preview_wiring_sorted_v6
preview_wiring_fieldmap_v6
preview_wiring_fieldlead_v6
preview_wiring_circuit_rollup_v6
preview_wiring_fieldonly_v6
```

The `_v6` suffixes are compatibility names. The current parser is V7.

### Base wiring map

The current parser materializes:

- master Prop rows from `props`;
- subordinate/multi-grid legs from `subProps`;
- DMX legs from `dmxChannels`; and
- Preview context from `previews`.

For SubProp wiring rows, the current V7 parser uses:

```text
subProps.Name -> LORName / Channel_Name
```

This is important because an older parser revision used the master Prop channel name for SubProp rows. The current V7 definition is the compatibility target for future database/browser work.

### Field-lead reduction

The parser's `preview_wiring_fieldlead_v6` selects one practical lead per:

```text
PreviewName
+ Network
+ Controller
+ StartChannel
+ Display_Name
```

It does **not** reduce the data to one row per physical circuit alone.

Therefore two Displays that legitimately share the same controller/channel remain two field-lead rows.

This behavior must be preserved.

## Repository PostgreSQL Wiring Stack

`Database/Basic_Query_Tools_Dev/postgres_create_views_lor_snap.sql` defines PostgreSQL equivalents:

```text
lor_snap.preview_wiring_map_v6
lor_snap.preview_wiring_sorted_v6
lor_snap.preview_wiring_fieldmap_v6
lor_snap.preview_wiring_fieldlead_v6
lor_snap.preview_wiring_circuit_rollup_v6
lor_snap.preview_wiring_fieldonly_v6
```

The PostgreSQL stack reads the current imported snapshot through `lor_snap.v_current_*` sources.

## Parser / PostgreSQL Semantic Comparison

### Preview name

SQLite:

```text
previews.Name -> PreviewName
```

PostgreSQL:

```text
v_current_previews.name -> preview_name
```

Status: **semantically aligned**.

### Display name

Both implementations derive the displayed wiring Display name from LOR `Comment` / `lor_comment` and dashify spaces in the compatibility wiring map.

Status: **semantically aligned**.

### Master Prop channel name

Both use the master Prop `Name` as the channel/sequencer label.

Status: **semantically aligned**.

### SubProp channel name

Current V7 SQLite uses `sp.Name`.

Repository PostgreSQL uses `sp.name`.

Status: **semantically aligned**.

### Controller and channel

Both use the LOR network, controller UID, StartChannel, and EndChannel for LOR rows and DMX universe/channel values for DMX rows.

Status: **semantically aligned at repository-definition level**.

### Field/Internal classification

Both rank rows by:

```text
Preview
+ Network
+ Controller
+ StartChannel
+ Display
```

with a Prop row preferred when available.

Status: **semantically aligned**.

### Shared-circuit preservation

Both compute field leads per Display/circuit rather than collapsing all Displays on one physical circuit.

Status: **semantically aligned**.

## Current Preview / Background Data in PostgreSQL

`lor_snap.v_current_previews` exposes the current imported Preview including:

```text
id
stage_id
name
revision
background_file
source_filename
import_run_id
```

This means the PostgreSQL snapshot already preserves the LOR `BackgroundFile` pointer needed to trace the historical FormView image-resolution contract.

The current snapshot provenance also exposes parser and ingest evidence through `lor_snap.v_current_run`.

## Permanent Display / Stage Context

The current P2 promotion contract writes/maintains the permanent Display relationship:

```text
ref.display.display_id
ref.display.stage_id
ref.display.lor_prop_id
```

This is the permanent asset side of scan-driven FieldWiring navigation.

The QR must resolve the permanent `display_id`; LOR UUIDs remain upstream identities/links rather than the QR's permanent asset identity.

## Permanent Scene Context

The current production Scene model includes:

```text
ref.lor_scene
ref.lor_scene_display
```

P3 promotes approved current Scenes to permanent Stage context.

P4 links permanent `display_id` values to the applicable promoted Scene within a Preview.

A uniqueness rule preserves one current Scene membership per Display within a Preview while allowing the same permanent Display to participate in different valid Preview contexts.

This is useful for the shared Field Context resolver and future FieldWiring routing.

## Important Read-Model Gap

The existing compatibility wiring views are designed around Preview presentation, not scan-driven permanent identity.

`lor_snap.preview_wiring_fieldlead_v6` does **not** currently expose all of these together as one browser-facing contract:

```text
permanent display_id
Preview UUID
Scene identity
permanent Stage identity
Preview revision
BackgroundFile
snapshot provenance
field wiring columns
```

That does not prove a new table is required.

It indicates that FieldWiring will likely need a controlled **read model/query surface** that joins existing authoritative objects by stable identity.

The first design choice should be a read-only view/API contract, not a new independent data store.

## Do Not Join QR Identity by Display Name

A scan begins with permanent `display_id`.

FieldWiring must not resolve a scanned asset into wiring solely through a text comparison on `Display_Name` / `lor_comment`.

Display names can change and are human-facing labels.

The scan-to-context path must use permanent Production Database identity and the controlled LOR reconciliation relationships, then use Preview/Scene context to select the requisite wiring view.

## Preview Identity Gap in Compatibility Views

The current wiring compatibility views expose `PreviewName`, but the stable LOR Preview identity is `PreviewClass.id` / Preview UUID.

The shared Scene membership model already carries `preview_uuid`.

For FieldWiring, a browser-facing read contract should expose the stable Preview identity alongside the human Preview name so context routing is not dependent on a name-only join.

This can potentially be solved with a read-only view over existing objects; no table change is implied.

## Browser Image Delivery Gap

The current `background_file` values are filesystem paths authored by LOR.

FormView can use those paths because it runs on Windows with the shared drive available.

A normal browser cannot safely consume `G:\...` paths directly.

FieldWiring therefore needs a controlled server-side method to resolve the authoritative background/documentation context and serve current published images over the web.

The solution must preserve traceability to the LOR/Stage documentation relationship without exposing mapped-drive paths as the browser's permanent identity contract.

## Folder / Scope Resolution

Folder Alignment already defines deterministic Stage/Sub-stage/Scene classification from current LOR/parser evidence and explicitly treats ambiguity as a review condition.

The shared Field Context resolver and FieldWiring should reuse those accepted scope rules conceptually rather than creating an unrelated Scene/folder classifier.

The browser application must not infer a Scene merely from a fuzzy filename or arbitrary folder segment.

## Current Hard-Report Provenance Available

The current snapshot interfaces already expose useful data for report currentness, including:

- `import_run_id`;
- parser version and timestamps;
- ingest timestamps;
- Preview UUID/name/revision; and
- source Preview filename.

These can support the FieldWiring hard-report rule that every generated report visibly identifies when it was generated, when it expires, and which approved data state it represents.

## Live Database Verification Still Required

This audit compares repository definitions. Before treating the PostgreSQL wiring layer as the actual FieldWiring production API, inspect the deployed database and verify:

1. current view definitions match the repository;
2. current snapshot views return the expected Preview/background data;
3. field-lead row counts match the current V7 SQLite for representative Previews;
4. shared circuits retain every legitimate Display row;
5. current Scene/Display memberships resolve expected permanent `display_id` values;
6. required read-only grants exist for the future service role or API path; and
7. no stale legacy object with the same name is being consumed accidentally.

No write or schema change is required for that verification.

## Recommended Next Engineering Artifact

After live verification, define a **FieldWiring read contract** with the minimum browser-facing fields needed for:

```text
scan context -> Preview/Scene wiring context -> field wiring rows -> images -> report provenance
```

The contract should be designed from existing views/relationships first.

Only demonstrated missing information should become a schema proposal.

## Related Documents

- [FieldWiring Engineering Recovery and Compatibility Contract](FieldWiring_Engineering_Recovery_and_Compatibility_Contract.md)
- [Wiring System](README.md)
- [Shared Field Context Resolution Contract](../07_Labeling_and_Scanning/Field_Context_Resolution_Contract.md)
- [LOR Preview Parser Architecture](../../../01_LOR_System/02_Data_Extraction/LOR_Preview_Parser_Architecture.md)
- [Folder Alignment Engineering Design](../../../01_LOR_System/02_Data_Extraction/Folder_Alignment/Folder_Alignment_Engineering_Design.md)
