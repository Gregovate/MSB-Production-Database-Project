# FieldWiring PostgreSQL DMX Propagation Production Acceptance — 2026-08-21

| Item | Accepted value |
|---|---|
| Status | **PRODUCTION ACCEPTED** |
| Branch | `agent/fieldwiring-engineering-recovery` |
| PostgreSQL migration | `0037_add_dmx_source_detail.sql` |
| Current import run | `51` |
| Parser | `V7.0.11` |
| LOR version | `6.6.10` |
| SQLite SHA-256 | `eb3d20bb5dc5c0433903f0081fb658b4e5a788c66caa2a9497f10b07dcf8794a` |
| Ingest | `V0.4.2` |
| Reconciliation | **NOT STARTED AS PART OF THIS ACCEPTANCE** |
| Legacy FormView views | Preserved |

## Purpose

This checkpoint closes the production propagation gate for parser V7.0.11 grouped-DMX source detail from the approved LOR SQLite snapshot into PostgreSQL.

It records successful migration installation, production parser generation, reviewed SQLite acceptance, PostgreSQL ingest Run 51, and read-only post-ingest validation.

This checkpoint does **not** authorize merging the FieldWiring feature branch to `main`, replacing FormView, redesigning the legacy compatibility views, or treating LOR universe/IP/name values as permanent controller identity.

## Production Parser Artifact

The approved production parser run completed with:

```text
Parser: V7.0.11
Run mode: PRODUCTION
Source LOR version: 6.6.10
Preview files: 33
Scenes: 92
Props: 1157
SubProps: 1312
DMX rows: 508
Scene/Prop memberships: 2260
ValidationStatus: PASSED
```

Reviewed SQLite digest:

```text
eb3d20bb5dc5c0433903f0081fb658b4e5a788c66caa2a9497f10b07dcf8794a
```

The digest was verified before ingest and matched the production SQLite exactly.

## SQLite DMX Source-Detail Acceptance

The V7.0.11 `dmxChannels` table contains the legacy eight columns followed by:

```text
RawPropID
ChannelName
ChannelGridRowNumber
```

Production acceptance results:

```text
total_rows = 508
blank_raw_prop_id = 0
blank_channel_name = 0
invalid_grid_row_number = 0
distinct_source_props = 91
```

Representative Mega Star rows proved that:

- source Channel Names are preserved;
- source RawPropID is preserved;
- Channel Grid Row Number is local to each source PropClass and restarts at 1; and
- dense E1.31 rows retain the original universe/channel topology.

Northern Lights / CR50 validation proved the accepted fixture contract exactly:

```text
source rows = 198
fixture groups = 66
Universe 145 = 32 fixtures / 96 rows
Universe 146 = 34 fixtures / 102 rows
```

Each CR50 fixture has exactly three represented RGB source rows with local Channel Grid Row Numbers `1,2,3`, while physical addressing advances in five-channel steps. The intentionally omitted two CR50 function channels remain omitted and were not fabricated.

## PostgreSQL Migration Acceptance

Migration `0037_add_dmx_source_detail.sql` installed successfully and added nullable fields to `lor_snap.dmx_channels`:

```text
raw_prop_id TEXT
channel_name TEXT
channel_grid_row_number INTEGER
```

`lor_snap.v_current_dmx_channels` exposes the legacy nine columns first and the three new fields in positions 10-12.

Post-migration contract validation confirmed:

- view owner remains `msbadmin`;
- `directus_app` retains SELECT access;
- existing DMX foreign keys remain unchanged;
- no foreign key was added from source `raw_prop_id` to canonical props; and
- historical Run 50 / V7.0.10 remained valid with NULL source-detail fields before Run 51 became current.

## Production Ingest Run 51

The production ingest completed successfully with the exact reviewed SQLite digest.

Observed ingest evidence:

```text
import_run_id = 51
parser = V7.0.11
lor = 6.6.10
sqlite_sha256 = eb3d20bb5dc5c0433903f0081fb658b4e5a788c66caa2a9497f10b07dcf8794a
previews = 33
scenes = 92
props = 1157
sub_props = 1312
dmx_channels = 508
scene_lor_props = 2260
field_wiring = 2189
```

The ingest reported all of the following PASS conditions before commit:

- raw PropClass UUID source schema contract;
- SQLite raw PropClass UUID completeness;
- V7.0.11+ DMX source-detail source schema contract;
- SQLite V7.0.11+ DMX source-detail completeness;
- PostgreSQL raw PropClass UUID completeness; and
- PostgreSQL V7.0.11+ DMX source-detail completeness.

## Post-Ingest PostgreSQL Validation

Run 51 is now current and the current DMX projection reports:

```text
import_run_id = 51
parser_version = V7.0.11
dmx_rows = 508
rows_with_raw_prop_id = 508
rows_with_channel_name = 508
rows_with_grid_row_number = 508
```

The V7.0.11+ completeness gate reports:

```text
dmx_source_detail_required = true
blank_raw_prop_id = 0
blank_channel_name = 0
invalid_channel_grid_row_number = 0
```

Status: **PASS**.

## Legacy Compatibility Layer Preservation

All protected view definitions remained fingerprint-identical to the frozen pre-migration baseline:

```text
preview_wiring_circuit_rollup_v6  d45ec60cfe1a8a07cbebf14941577c08
preview_wiring_fieldlead_v6       eb4d412ade972d2a2dece75abe3b83a5
preview_wiring_fieldmap_v6        85383f11ba7adb37f5122177c2dca89b
preview_wiring_fieldonly_v6       d9f4bd14533b1ac404d9430bfbf851e7
preview_wiring_map_v6             72ede1bbe0de6f00edd9a7b94a71fab3
preview_wiring_sorted_v6          9d7b461a48ef851111d3998ea98a5689
stage_display_assets_v1           402410c56a0924d3e85f2963dd84ee8f
```

Protected row counts also remained exactly unchanged from Run 50:

```text
preview_wiring_map_v6       = 2686
preview_wiring_fieldlead_v6 = 2189
preview_wiring_fieldonly_v6 = 2189
stage_display_assets_v1     = 2686
```

This proves the additive V7.0.11 source-detail propagation did not alter the legacy FormView-compatible projection.

## Accepted Identity Boundary

The production result preserves the intended identity model:

```text
dmx_channels.prop_id
    -> canonical/materialized Display master relationship

dmx_channels.raw_prop_id
    -> source PropClass provenance only
```

No permanent Display or Controller identity is derived from universe, IP address, Channel Name, network alias, source row number, or source RawPropID.

Permanent physical controller identity remains owned by Controller Inventory.

## Motion FX Guard Correction During Acceptance

Routine production parsing initially stopped on an authored `MotionRowDefault.subc` change in the Master Musical Preview.

That was confirmed to be normal Motion FX authoring data, including substantial Mt. Crumpit authoring work, not a parser-contract change.

Checker V1.3.1 now retains same-version Motion FX structural differences as informational evidence without treating them as parser-breaking. Different-LOR-version compatibility review remains strict.

Operator-run regression evidence after the correction:

```text
test_lor_version_checker.py             8 PASS
test_lor_version_checker_motion_fx.py   2 PASS
test_lor_operator_runner.py            18 PASS
Total                                   28 PASS
```

## Production Acceptance Decision

The V7.0.11 grouped-DMX source-detail propagation is **accepted in production**.

The propagation milestone is closed because:

1. parser V7.0.11 production output passed;
2. the exact SQLite artifact was reviewed and digest-locked;
3. all 508 DMX rows contain complete source detail;
4. representative dense RGB and CR50 topologies were validated;
5. migration 0037 installed safely;
6. ingest V0.4.2 completed as Run 51;
7. PostgreSQL source-detail completeness is 508/508/508 with zero violations; and
8. legacy compatibility views and row counts remain unchanged.

## Next FieldWiring Gate

Do **not** redesign or repurpose the legacy `preview_wiring_*_v6` views.

The next FieldWiring engineering step is to define and implement a **new richer read surface / application adapter** that can consume atomic DMX source-detail rows from the current snapshot while preserving the legacy compatibility path for FormView.

Expected sequence:

1. define the FieldWiring-specific read contract;
2. expose source `RawPropID`, `ChannelName`, and `ChannelGridRowNumber` without changing legacy view semantics;
3. regenerate the development snapshot using the existing dynamic exporter;
4. update `FieldWiring/Application/wiring_data.py` to consume the new read path;
5. add family-aware presentation logic for dense E1.31 and DMX/DumbRGB/CR50;
6. validate against Mega Star, Mega Tree, Northern Lights, Mega Cube / Matrix limitations, and existing traditional wiring cases; and
7. keep FormView operational until FieldWiring is proven.

Reconciliation is a separate production workflow and was not part of this propagation acceptance.

## Revision History

| Date | Author | Change |
|---|---|---|
| 2026-08-21 | GAL / OpenAI | Recorded final production acceptance of parser V7.0.11, migration 0037, ingest V0.4.2 Run 51, 508/508/508 PostgreSQL source-detail completeness, protected-view fingerprint/row-count preservation, CR50 acceptance, and Motion FX guard correction. |
