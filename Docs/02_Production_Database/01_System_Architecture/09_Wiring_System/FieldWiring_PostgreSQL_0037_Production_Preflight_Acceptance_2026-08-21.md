# FieldWiring PostgreSQL Migration 0037 Production Preflight Acceptance — 2026-08-21

| Item | Value |
|---|---|
| Status | PRE-MIGRATION BASELINE CAPTURED — ONE DIRECT-DEPENDENCY FINGERPRINT FOLLOW-UP PENDING |
| Migration | `0037_add_dmx_source_detail.sql` |
| Branch | `agent/fieldwiring-engineering-recovery` |
| Production schema changed | NO |
| Production ingest run | NO |
| Current production snapshot | Run 50 / parser V7.0.10 / ingest V0.4.1 |

## Purpose

This document records the operator-run read-only production preflight immediately before any consideration of migration `0037_add_dmx_source_detail.sql`.

The preflight does **not** authorize or record migration execution.

## Read Access Baseline

Production returned:

```text
directus_app_can_select_current_dmx = true
```

Migration `0037` reasserts this established read grant after replacing `lor_snap.v_current_dmx_channels`.

## Pre-Migration DMX Table / Current-View Shape

`lor_snap.dmx_channels` has the legacy nine columns:

```text
1  import_run_id       bigint   NOT NULL
2  int_dmx_channel_id bigint   NOT NULL
3  prop_id             text     nullable
4  network             text     nullable
5  start_universe      integer  nullable
6  start_channel       integer  nullable
7  end_channel         integer  nullable
8  unknown             text     nullable
9  preview_id          text     nullable
```

`lor_snap.v_current_dmx_channels` likewise exposes exactly the legacy nine columns before migration.

The preflight query for proposed fields returned zero rows, confirming these are not already deployed:

```text
raw_prop_id
channel_name
channel_grid_row_number
```

## Existing DMX Constraints

The production baseline contains exactly the established DMX primary/foreign-key relationships:

```text
dmx_channels_pkey
  PRIMARY KEY (import_run_id, int_dmx_channel_id)

dmx_channels_import_run_id_fkey
  FOREIGN KEY (import_run_id)
  REFERENCES lor_snap.import_run(import_run_id)
  ON DELETE CASCADE

dmx_channels_import_run_id_preview_id_fkey
  FOREIGN KEY (import_run_id, preview_id)
  REFERENCES lor_snap.previews(import_run_id, id)
  ON DELETE RESTRICT

dmx_channels_import_run_id_prop_id_fkey
  FOREIGN KEY (import_run_id, prop_id)
  REFERENCES lor_snap.props(import_run_id, prop_id)
  ON DELETE RESTRICT
```

No source-`raw_prop_id` foreign key exists before migration, and migration `0037` is not permitted to add one.

## Direct View Dependencies Discovered Live

Production reports two direct dependent views on `lor_snap.v_current_dmx_channels`:

```text
lor_snap.preview_wiring_map_v6
lor_snap.stage_display_assets_v1
```

Appending the three new columns to the end of `v_current_dmx_channels` must leave both dependent views valid and definition-identical.

`preview_wiring_map_v6` was already included in the original compatibility fingerprint set. `stage_display_assets_v1` was discovered by the live dependency query and is now added to both the durable preflight and post-migration validation fingerprint sets before migration execution.

## Frozen Legacy Wiring View Fingerprints

Operator-run preflight returned:

```text
preview_wiring_circuit_rollup_v6
d45ec60cfe1a8a07cbebf14941577c08

preview_wiring_fieldlead_v6
eb4d412ade972d2a2dece75abe3b83a5

preview_wiring_fieldmap_v6
85383f11ba7adb37f5122177c2dca89b

preview_wiring_fieldonly_v6
d9f4bd14533b1ac404d9430bfbf851e7

preview_wiring_map_v6
72ede1bbe0de6f00edd9a7b94a71fab3

preview_wiring_sorted_v6
9d7b461a48ef851111d3998ea98a5689
```

The corresponding column signatures were also captured and must remain unchanged after migration.

## Frozen Legacy Row Counts

While Run 50 remains current, production returned:

```text
preview_wiring_map_v6       2686 rows
preview_wiring_fieldlead_v6 2189 rows
preview_wiring_fieldonly_v6 2189 rows
```

Migration `0037` is schema/view propagation only and must not change those values while Run 50 remains current.

## Final Follow-Up Before Migration Execution

Because the live dependency query exposed `lor_snap.stage_display_assets_v1` as a direct dependent of `v_current_dmx_channels`, its definition hash, column signature, and current row count must be frozen before executing migration `0037`.

The feature-branch preflight has been tightened so Section 8 now includes `stage_display_assets_v1`, and Section 9 now includes its row count. The post-migration validation has been made symmetric.

Only that added read-only baseline needs to be captured; there is no need to repeat the already-recorded production results unless the current import run changes first.

## Stop Conditions

Do not execute migration `0037` if the follow-up shows:

- a changed current production import run without a new full preflight;
- missing or invalid `stage_display_assets_v1`;
- unexpected additional direct dependencies that are not fingerprinted/reviewed;
- any proposed DMX source-detail column already present from an unknown deployment; or
- loss of `directus_app` SELECT access before migration.

## Related Artifacts

- `LOR2DB/02_Reconciliation/reconciliation/operator_queries/preflight/10_fieldwiring_dmx_0037_preflight.sql`
- `LOR2DB/02_Reconciliation/reconciliation/migrations/0037_add_dmx_source_detail.sql`
- `LOR2DB/02_Reconciliation/reconciliation/validation/32_dmx_source_detail_validation.sql`
- [FieldWiring PostgreSQL DMX Propagation Implementation Checkpoint](FieldWiring_PostgreSQL_DMX_Propagation_Implementation_Checkpoint_2026-08-21.md)

## Revision History

| Date | Author | Change |
|---|---|---|
| 2026-08-21 | GAL / OpenAI | Recorded live read-only production baseline: DMX table/current-view legacy shape, established PK/FKs, direct dependencies, directus_app read privilege, six legacy wiring-view fingerprints, row-count baselines, and absence of proposed 0037 columns. Added `stage_display_assets_v1` fingerprint follow-up after it surfaced as a direct production dependency. |
