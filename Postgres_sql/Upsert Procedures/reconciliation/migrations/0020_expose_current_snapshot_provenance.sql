/* ============================================================================
Object group: Current LOR snapshot provenance interface
Repository:   Postgres_sql/Upsert Procedures/reconciliation/migrations/
Filename:     0020_expose_current_snapshot_provenance.sql
Revision:     2026-08-03-current-snapshot-provenance-v1

Purpose:
  Extend the established lor_snap.v_current_* interface with the parser and
  ingest provenance now stored by V7 parser/ingest, without changing how the
  current import run is selected.

Scope:
  - v_current_run exposes every lor_snap.import_run provenance/count field.
  - v_current_previews exposes the parsed .lorprev source filename.
  - No other v_current_* view requires replacement because no other snapshot
    table received a provenance field.
  - Historical runs remain valid; their new nullable fields return NULL.
  - No snapshot or production data is inserted, updated, or deleted.

Revision history:
  2026-08-03  GAL / OpenAI  Initial current-snapshot provenance interface.
============================================================================ */

BEGIN;

CREATE OR REPLACE VIEW lor_snap.v_current_run AS
SELECT
    ir.import_run_id,
    ir.run_ts,
    ir.notes,
    ir.parser_version,
    ir.parser_started_at,
    ir.parser_completed_at,
    ir.parser_actor,
    ir.parser_host,
    ir.source_preview_folder,
    ir.source_sqlite_path,
    ir.preview_count,
    ir.scene_count,
    ir.prop_count,
    ir.sub_prop_count,
    ir.dmx_channel_count,
    ir.scene_lor_prop_count,
    ir.ingest_script_version,
    ir.ingest_actor,
    ir.ingest_host,
    ir.ingest_started_at,
    ir.ingest_completed_at
FROM lor_snap.import_run AS ir
ORDER BY ir.import_run_id DESC
LIMIT 1;

ALTER VIEW lor_snap.v_current_run OWNER TO msbadmin;
GRANT SELECT ON lor_snap.v_current_run TO directus_app;

COMMENT ON VIEW lor_snap.v_current_run IS
'Latest imported LOR snapshot run with parser, source-folder, ingest, and row-count provenance. Historical nullable provenance remains NULL.';

CREATE OR REPLACE VIEW lor_snap.v_current_previews AS
SELECT
    p.import_run_id,
    p.int_preview_id,
    p.id,
    p.stage_id,
    p.name,
    p.revision,
    p.brightness,
    p.background_file,
    p.source_filename
FROM lor_snap.previews AS p
JOIN lor_snap.v_current_run AS r
  ON r.import_run_id = p.import_run_id;

ALTER VIEW lor_snap.v_current_previews OWNER TO msbadmin;
GRANT SELECT ON lor_snap.v_current_previews TO directus_app;

COMMENT ON VIEW lor_snap.v_current_previews IS
'Preview rows belonging to the latest imported LOR snapshot, including the exact parsed .lorprev source filename.';

COMMIT;

SELECT
    cr.import_run_id,
    cr.parser_version,
    cr.parser_completed_at,
    cr.source_preview_folder,
    cr.ingest_script_version,
    cr.ingest_completed_at,
    count(p.*) AS current_preview_count,
    count(*) FILTER (WHERE p.source_filename IS NOT NULL) AS previews_with_source_filename
FROM lor_snap.v_current_run AS cr
LEFT JOIN lor_snap.v_current_previews AS p
  ON p.import_run_id = cr.import_run_id
GROUP BY
    cr.import_run_id,
    cr.parser_version,
    cr.parser_completed_at,
    cr.source_preview_folder,
    cr.ingest_script_version,
    cr.ingest_completed_at;
