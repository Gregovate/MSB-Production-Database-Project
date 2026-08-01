/*
Schema: lor_snap
Object: Current-ingest reconciliation context
Filename: 01_latest_ingest_context.sql
Type: Read-only preflight query
Owner: msbadmin

Purpose:
  Return the current LOR ingest and current snapshot row counts from the
  established lor_snap.v_current_* interface.

Safety:
  SELECT only. Does not call P1, P2, or P3 and does not modify any object.

Source contract:
  All reconciliation scripts 01-07 read the same current snapshot exposed by
  lor_snap.v_current_run and the matching lor_snap.v_current_* views.

Revision History:
  2026-08-01  GAL / OpenAI  Use the established lor_snap.v_current_* snapshot interface.
  2026-08-01  GAL / OpenAI  Initial latest-ingest version.
*/

SELECT
    current_database() AS database_name,
    current_user AS database_user,
    now() AS checked_at,
    cr.import_run_id,
    cr.run_ts AS ingest_timestamp,
    cr.notes AS ingest_notes,
    (SELECT count(*) FROM lor_snap.v_current_previews) AS preview_count,
    (SELECT count(*) FROM lor_snap.v_current_scenes) AS scene_count,
    (SELECT count(*) FROM lor_snap.v_current_props) AS prop_count,
    (SELECT count(*) FROM lor_snap.v_current_sub_props) AS sub_prop_count,
    (SELECT count(*) FROM lor_snap.v_current_dmx_channels) AS dmx_channel_count,
    (SELECT count(*) FROM lor_snap.v_current_scene_lor_props) AS scene_lor_prop_count
FROM lor_snap.v_current_run AS cr;
