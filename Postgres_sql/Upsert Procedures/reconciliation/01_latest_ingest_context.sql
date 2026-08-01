/*
Schema: lor_snap
Object: Latest-ingest reconciliation context
Filename: 01_latest_ingest_context.sql
Type: Read-only preflight query
Owner: msbadmin

Purpose:
  Capture the latest LOR ingest automatically and return its timestamp and
  snapshot row counts in one exportable result set.

Safety:
  SELECT only. Does not call P1 or P2 and does not modify any object.

Revision History:
  2026-08-01  GAL / OpenAI  Initial latest-ingest version.
*/

WITH selected_run AS (
    SELECT ir.import_run_id, ir.run_ts, ir.notes
    FROM lor_snap.import_run AS ir
    ORDER BY ir.import_run_id DESC
    LIMIT 1
)
SELECT
    current_database() AS database_name,
    current_user AS database_user,
    now() AS checked_at,
    sr.import_run_id,
    sr.run_ts AS ingest_timestamp,
    sr.notes AS ingest_notes,
    (SELECT count(*) FROM lor_snap.previews p
      WHERE p.import_run_id = sr.import_run_id) AS preview_count,
    (SELECT count(*) FROM lor_snap.scenes s
      WHERE s.import_run_id = sr.import_run_id) AS scene_count,
    (SELECT count(*) FROM lor_snap.props p
      WHERE p.import_run_id = sr.import_run_id) AS prop_count,
    (SELECT count(*) FROM lor_snap.sub_props sp
      WHERE sp.import_run_id = sr.import_run_id) AS sub_prop_count,
    (SELECT count(*) FROM lor_snap.dmx_channels dc
      WHERE dc.import_run_id = sr.import_run_id) AS dmx_channel_count,
    (SELECT count(*) FROM lor_snap.scene_lor_props slp
      WHERE slp.import_run_id = sr.import_run_id) AS scene_lor_prop_count
FROM selected_run AS sr;
