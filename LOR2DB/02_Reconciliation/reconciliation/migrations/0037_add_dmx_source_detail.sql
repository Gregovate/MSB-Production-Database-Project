/* ============================================================================
Migration: 0037_add_dmx_source_detail.sql
Revision:  2026-08-21-dmx-source-detail-v1

Purpose:
  Add the three V7.0.11 grouped-DMX source-detail fields to the append-only
  PostgreSQL snapshot table and expose them through the established current-run
  view without changing any legacy preview_wiring_*_v6 compatibility view.

Source contract:
  SQLite dmxChannels.RawPropID
      -> lor_snap.dmx_channels.raw_prop_id
  SQLite dmxChannels.ChannelName
      -> lor_snap.dmx_channels.channel_name
  SQLite dmxChannels.ChannelGridRowNumber
      -> lor_snap.dmx_channels.channel_grid_row_number

Identity boundary:
  dmx_channels.prop_id remains the canonical/materialized Display-master parser
  relationship.  dmx_channels.raw_prop_id is only the originating LOR PropClass
  identity for that DMX source row.  It is not permanent Display identity and
  intentionally has no foreign key to lor_snap.props.

Safety:
  - Additive nullable columns only; historical snapshots remain valid with NULL.
  - No historical backfill.
  - No change to existing primary/foreign keys.
  - No change to preview_wiring_*_v6 or stage/report compatibility views.
  - Reasserts established current-snapshot view owner/read-grant conventions.
  - No controller-inventory identity or mapping is introduced here.
============================================================================ */

BEGIN;

ALTER TABLE lor_snap.dmx_channels
    ADD COLUMN IF NOT EXISTS raw_prop_id TEXT,
    ADD COLUMN IF NOT EXISTS channel_name TEXT,
    ADD COLUMN IF NOT EXISTS channel_grid_row_number INTEGER;

COMMENT ON COLUMN lor_snap.dmx_channels.raw_prop_id IS
'Originating raw LOR PropClass.id for this DMX Channel Grid Row. Source wiring provenance only; not permanent Display or controller identity and intentionally not foreign-keyed to lor_snap.props.';

COMMENT ON COLUMN lor_snap.dmx_channels.channel_name IS
'Originating LOR PropClass.Name (Channel Name) that supplied this DMX Channel Grid Row.';

COMMENT ON COLUMN lor_snap.dmx_channels.channel_grid_row_number IS
'1-based serialized Channel Grid Row Number local to the originating PropClass. Restarts for each source PropClass; gaps may exist when a nonblank serialized row is invalid and therefore not materialized.';

CREATE OR REPLACE VIEW lor_snap.v_current_dmx_channels AS
SELECT
    dc.import_run_id,
    dc.int_dmx_channel_id,
    dc.prop_id,
    dc.network,
    dc.start_universe,
    dc.start_channel,
    dc.end_channel,
    dc.unknown,
    dc.preview_id,
    dc.raw_prop_id,
    dc.channel_name,
    dc.channel_grid_row_number
FROM lor_snap.dmx_channels AS dc
JOIN lor_snap.v_current_run AS r
  ON r.import_run_id = dc.import_run_id;

ALTER VIEW lor_snap.v_current_dmx_channels OWNER TO msbadmin;
GRANT SELECT ON lor_snap.v_current_dmx_channels TO directus_app;

COMMENT ON VIEW lor_snap.v_current_dmx_channels IS
'Current imported DMX rows. prop_id remains the canonical Display-master parser relationship; raw_prop_id/channel_name/channel_grid_row_number preserve V7.0.11 originating source-row detail. Historical pre-V7.0.11 snapshots may contain NULL source-detail values.';

COMMIT;

SELECT
    '2026-08-21-dmx-source-detail-v1'::text AS installed_revision,
    count(*) AS current_dmx_rows,
    count(*) FILTER (WHERE raw_prop_id IS NOT NULL) AS current_rows_with_raw_prop_id,
    count(*) FILTER (WHERE channel_name IS NOT NULL) AS current_rows_with_channel_name,
    count(*) FILTER (WHERE channel_grid_row_number IS NOT NULL) AS current_rows_with_grid_row_number
FROM lor_snap.v_current_dmx_channels;
