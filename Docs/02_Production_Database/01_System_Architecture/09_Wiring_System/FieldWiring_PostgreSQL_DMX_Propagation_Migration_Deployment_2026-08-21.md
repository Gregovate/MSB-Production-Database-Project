# FieldWiring PostgreSQL DMX Propagation — Migration 0037 Production Deployment

| Item | Value |
|---|---|
| Status | DEPLOYED AND VALIDATED — SCHEMA ONLY |
| Date | 2026-08-21 |
| Sub-project | FieldWiring / Engineering Recovery |
| Branch | `agent/fieldwiring-engineering-recovery` |
| Migration | `0037_add_dmx_source_detail.sql` |
| Installed revision | `2026-08-21-dmx-source-detail-v1` |
| Current production snapshot after migration | Run 50 / parser V7.0.10 / ingest V0.4.1 |
| Production ingest after migration | NOT RUN |
| FieldWiring browser renderer | UNCHANGED |
| FormView compatibility | PRESERVED |

## Purpose

This record captures the production installation and post-install validation of the additive PostgreSQL schema required to receive parser V7.0.11 grouped-DMX source detail.

Migration 0037 changed the PostgreSQL schema/current-DMX view only. It did not run the parser, create a new `lor_snap.import_run`, ingest a V7.0.11 snapshot, alter the legacy `preview_wiring_*_v6` compatibility views, modify Controller Inventory, change FieldWiring presentation, or merge the FieldWiring branch to `main`.

## Installed Schema Change

`lor_snap.dmx_channels` now contains the legacy nine columns followed by three nullable V7.0.11 source-detail fields:

```text
1  import_run_id             bigint   NOT NULL
2  int_dmx_channel_id        bigint   NOT NULL
3  prop_id                   text     NULL
4  network                   text     NULL
5  start_universe            integer  NULL
6  start_channel             integer  NULL
7  end_channel               integer  NULL
8  unknown                   text     NULL
9  preview_id                text     NULL
10 raw_prop_id               text     NULL
11 channel_name              text     NULL
12 channel_grid_row_number   integer  NULL
```

`lor_snap.v_current_dmx_channels` exposes the same twelve fields in the same order.

The three additive fields remain nullable so historical snapshots such as Run 50 remain valid.

## Historical Run 50 Validation

Immediately after migration installation:

```text
current_dmx_rows                    508
current_rows_with_raw_prop_id       0
current_rows_with_channel_name      0
current_rows_with_grid_row_number   0
```

This is the expected state because Run 50 was produced by parser V7.0.10, before these fields existed.

No historical backfill was performed.

Post-install current-snapshot validation returned:

```text
import_run_id                 50
parser_version                V7.0.10
dmx_rows                      508
rows_with_raw_prop_id         0
rows_with_channel_name        0
rows_with_grid_row_number     0
dmx_source_detail_required    false
blank_raw_prop_id             0
blank_channel_name            0
invalid_channel_grid_row_number 0
```

The final three violation counts are correctly zero because the V7.0.11 completeness rule is version-gated and does not falsely classify historical V7.0.10 NULL values as errors.

## Ownership and Privilege Validation

`lor_snap.v_current_dmx_channels` remains owned by:

```text
msbadmin
```

and:

```text
directus_app_can_select_current_dmx = true
```

Migration 0037 explicitly reasserts both conventions.

## Constraint Validation

The established DMX relationships remain unchanged:

```text
dmx_channels_pkey
    PRIMARY KEY (import_run_id, int_dmx_channel_id)

dmx_channels_import_run_id_fkey
    FOREIGN KEY (import_run_id)
    -> lor_snap.import_run(import_run_id)
    ON DELETE CASCADE

dmx_channels_import_run_id_preview_id_fkey
    FOREIGN KEY (import_run_id, preview_id)
    -> lor_snap.previews(import_run_id, id)
    ON DELETE RESTRICT

dmx_channels_import_run_id_prop_id_fkey
    FOREIGN KEY (import_run_id, prop_id)
    -> lor_snap.props(import_run_id, prop_id)
    ON DELETE RESTRICT
```

No foreign key was added for `raw_prop_id`.

The identity boundary therefore remains:

```text
dmx_channels.prop_id
    -> canonical/materialized Prop relationship
    -> permanent Display reconciliation path

raw_prop_id
    -> originating LOR PropClass source-row provenance only
```

## Protected View Before/After Validation

The production preflight froze all direct/legacy dependent definitions before migration 0037. Post-migration validation returned the same MD5 values and column signatures.

| Protected view | Definition MD5 after migration | Result |
|---|---|---|
| `preview_wiring_circuit_rollup_v6` | `d45ec60cfe1a8a07cbebf14941577c08` | MATCH |
| `preview_wiring_fieldlead_v6` | `eb4d412ade972d2a2dece75abe3b83a5` | MATCH |
| `preview_wiring_fieldmap_v6` | `85383f11ba7adb37f5122177c2dca89b` | MATCH |
| `preview_wiring_fieldonly_v6` | `d9f4bd14533b1ac404d9430bfbf851e7` | MATCH |
| `preview_wiring_map_v6` | `72ede1bbe0de6f00edd9a7b94a71fab3` | MATCH |
| `preview_wiring_sorted_v6` | `9d7b461a48ef851111d3998ea98a5689` | MATCH |
| `stage_display_assets_v1` | `402410c56a0924d3e85f2963dd84ee8f` | MATCH |

The direct dependencies discovered in production remain valid:

```text
lor_snap.preview_wiring_map_v6
lor_snap.stage_display_assets_v1
```

## Protected Row-Count Validation

Before and after migration 0037, while Run 50 remained current:

```text
preview_wiring_map_v6       2686
preview_wiring_fieldlead_v6 2189
preview_wiring_fieldonly_v6 2189
stage_display_assets_v1     2686
```

Result: **UNCHANGED**.

This confirms that the schema/view extension did not alter FormView-compatible wiring output or the directly dependent stage/display asset view.

## Migration Acceptance

Production migration 0037 acceptance is **PASS**.

The production database is now capable of receiving V7.0.11 DMX source-detail values, but no V7.0.11 source-detail data is present yet because the current snapshot remains Run 50 / V7.0.10.

## Next Controlled Gate

The next step is not another schema change.

The next controlled gate is:

1. align the Windows LOR operator runner with ingest V0.4.2 and parser V7.0.11;
2. generate a normal controlled **PRODUCTION** parser artifact from the currently approved LOR 6.6.10 Preview folder;
3. inspect and hash that exact SQLite artifact;
4. verify V7.0.11 source-detail completeness and representative Mega Tree / Mega Star / Northern Lights rows in the production-mode SQLite;
5. only then authorize the digest-locked PostgreSQL ingest.

Do not ingest the earlier VERSION_CHECK acceptance database.

Do not change the browser renderer at this gate.

## Controller Inventory Boundary

Migration 0037 added no physical-controller identity or assignment data.

The ongoing FieldWiring / Controller Inventory handoff remains in force. Any controller-related discovery made while implementing the subsequent FieldWiring read/presentation layer must be reflected into the Controller Inventory integration documentation before the corresponding FieldWiring milestone is considered fully documented.

## Known Separate Limitation

The Mega Cube / Mt. Crumpit / Who Matrix compact-ChannelGrid expansion issue remains separate and unresolved. PostgreSQL must continue to preserve only materialized parser rows and must not synthesize missing compact rows.

## Related Records

- [DMX Propagation Change Map](FieldWiring_PostgreSQL_DMX_Propagation_Change_Map_2026-08-21.md)
- [Implementation Checkpoint](FieldWiring_PostgreSQL_DMX_Propagation_Implementation_Checkpoint_2026-08-21.md)
- [Production Pre-Migration Baseline](FieldWiring_PostgreSQL_DMX_0037_Production_Preflight_Baseline_2026-08-21.md)
- [PostgreSQL Readiness Audit](FieldWiring_PostgreSQL_Readiness_Audit.md)
- [Controller Inventory Handoff](FieldWiring_Controller_Inventory_Handoff_2026-08-20.md)

## Revision History

| Date | Author | Change |
|---|---|---|
| 2026-08-21 | GAL / OpenAI | Recorded successful production installation and validation of migration 0037. Run 50 remained current; all protected view fingerprints and row counts were unchanged; no parser or ingest was run. |
