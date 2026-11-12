# FieldWiring PostgreSQL DMX Migration 0037 — Production Preflight Baseline

| Item | Value |
|---|---|
| Date | 2026-08-21 |
| Sub-project | FieldWiring / Engineering Recovery |
| Branch | `agent/fieldwiring-engineering-recovery` |
| Migration under review | `0037_add_dmx_source_detail.sql` |
| Status | PRE-MIGRATION PRODUCTION BASELINE CAPTURED — MIGRATION NOT YET APPLIED |

## Purpose

This document freezes the production database state immediately before migration `0037_add_dmx_source_detail.sql` is considered for installation.

It is the before-state for the required post-migration comparison. It does not itself authorize a V7.0.11 production ingest, FieldWiring renderer change, FormView cutover, or branch merge.

## Current DMX Access Baseline

`directus_app` can currently read the established current-DMX view:

```text
directus_app_can_select_current_dmx = true
```

Migration `0037` must preserve that read access.

## Pre-Migration `lor_snap.dmx_channels` Shape

The production table currently contains exactly the legacy nine columns:

```text
1  import_run_id       bigint   NOT NULL
2  int_dmx_channel_id bigint   NOT NULL
3  prop_id             text     NULL
4  network             text     NULL
5  start_universe      integer  NULL
6  start_channel       integer  NULL
7  end_channel         integer  NULL
8  unknown             text     NULL
9  preview_id          text     NULL
```

The proposed source-detail fields are absent before migration:

```text
raw_prop_id
channel_name
channel_grid_row_number
```

The preflight query returned zero rows when searching for those fields in either `lor_snap.dmx_channels` or `lor_snap.v_current_dmx_channels`.

## Pre-Migration `lor_snap.v_current_dmx_channels` Shape

The current production view exposes the same legacy nine columns in the same order:

```text
1  import_run_id
2  int_dmx_channel_id
3  prop_id
4  network
5  start_universe
6  start_channel
7  end_channel
8  unknown
9  preview_id
```

Migration `0037` is expected to append, not reorder or reinterpret, the three V7.0.11 source-detail fields.

## Primary / Foreign Key Baseline

The production `lor_snap.dmx_channels` constraints before migration are:

```text
PRIMARY KEY
  dmx_channels_pkey
  (import_run_id, int_dmx_channel_id)

FOREIGN KEY
  dmx_channels_import_run_id_fkey
  (import_run_id)
    -> lor_snap.import_run(import_run_id)
    ON DELETE CASCADE

FOREIGN KEY
  dmx_channels_import_run_id_preview_id_fkey
  (import_run_id, preview_id)
    -> lor_snap.previews(import_run_id, id)
    ON DELETE RESTRICT

FOREIGN KEY
  dmx_channels_import_run_id_prop_id_fkey
  (import_run_id, prop_id)
    -> lor_snap.props(import_run_id, prop_id)
    ON DELETE RESTRICT
```

Migration `0037` must leave these unchanged and must not add a foreign key involving `raw_prop_id`.

## Direct View Dependencies on `v_current_dmx_channels`

Production dependency inspection found exactly these direct view dependents:

```text
lor_snap.preview_wiring_map_v6
lor_snap.stage_display_assets_v1
```

Both are protected by before/after definition and column-signature fingerprints.

## Protected View Fingerprints

The following production definitions and column signatures are frozen before migration.

| View | Pre-migration `pg_get_viewdef()` MD5 | Column signature |
|---|---|---|
| `preview_wiring_circuit_rollup_v6` | `d45ec60cfe1a8a07cbebf14941577c08` | `preview_name:text,network:text,controller:text,start_channel:integer,display_count:bigint,displays:text` |
| `preview_wiring_fieldlead_v6` | `eb4d412ade972d2a2dece75abe3b83a5` | `preview_name:text,source:text,channel_name:text,display_name:text,network:text,controller:text,start_channel:integer,end_channel:integer,color:text,device_type:text,lor_tag:text,connection_type:text,cross_display:integer,lead_rank:bigint` |
| `preview_wiring_fieldmap_v6` | `85383f11ba7adb37f5122177c2dca89b` | `preview_name:text,source:text,channel_name:text,display_name:text,network:text,controller:text,start_channel:integer,end_channel:integer,color:text,device_type:text,lor_tag:text,connection_type:text,cross_display:integer` |
| `preview_wiring_fieldonly_v6` | `d9f4bd14533b1ac404d9430bfbf851e7` | `preview_name:text,source:text,channel_name:text,display_name:text,network:text,controller:text,start_channel:integer,end_channel:integer,color:text,device_type:text,lor_tag:text,connection_type:text,cross_display:integer` |
| `preview_wiring_map_v6` | `72ede1bbe0de6f00edd9a7b94a71fab3` | `preview_name:text,display_name:text,lor_name:text,network:text,controller:text,start_channel:integer,end_channel:integer,device_type:text,source:text,lor_tag:text` |
| `preview_wiring_sorted_v6` | `9d7b461a48ef851111d3998ea98a5689` | `preview_name:text,display_name:text,lor_name:text,network:text,controller:text,start_channel:integer,end_channel:integer,device_type:text,source:text,lor_tag:text` |
| `stage_display_assets_v1` | `402410c56a0924d3e85f2963dd84ee8f` | `stage_id:text,preview_name:text,display_name:text,channel_name:text,device_type:text,network:text,uid:text,start_channel:integer,end_channel:integer,has_wiring:integer,source:text` |

The post-migration validation must reproduce these exact MD5 values and column signatures while Run 50 remains current.

## Protected Row-Count Baseline

The following production row counts were frozen before migration:

```text
preview_wiring_map_v6       2686
preview_wiring_fieldlead_v6 2189
preview_wiring_fieldonly_v6 2189
stage_display_assets_v1     2686
```

Migration `0037` changes metadata/view projection only. While the current snapshot remains Run 50, these row counts must remain unchanged after installation.

## Migration Acceptance Conditions

Migration `0037` is accepted only if post-migration validation confirms all of the following:

1. `lor_snap.dmx_channels` has the three new nullable columns appended after the legacy nine columns;
2. `lor_snap.v_current_dmx_channels` exposes the same three fields after the legacy nine columns;
3. historical Run 50 DMX rows remain present and the new fields are NULL for that V7.0.10 snapshot;
4. existing primary and foreign keys are unchanged;
5. no foreign key is added from `raw_prop_id`;
6. `v_current_dmx_channels` remains owned by `msbadmin`;
7. `directus_app` retains SELECT access;
8. every protected view fingerprint and column signature above remains unchanged;
9. protected row counts remain `2686 / 2189 / 2189 / 2686`; and
10. no V7.0.11 ingest is performed until the migration itself has passed validation.

## Separate Boundaries Still in Force

This migration does not solve or authorize:

- Mega Cube / Who Matrix compact Channel Grid expansion;
- Controller Inventory schema or permanent controller identity;
- physical E1.31 output mapping;
- FieldWiring browser presentation changes;
- FormView retirement;
- branch merge to `main`.

## Source Evidence

This baseline was captured by running the repository-controlled read-only preflight:

```text
LOR2DB/02_Reconciliation/reconciliation/operator_queries/preflight/
10_fieldwiring_dmx_0037_preflight.sql
```

against production on 2026-08-21 before migration `0037` was applied.
