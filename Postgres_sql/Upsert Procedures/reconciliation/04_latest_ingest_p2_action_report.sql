/*
Schema: ops / lor_snap / ref
Object: Current-ingest P2 action and review report
Filename: 04_latest_ingest_p2_action_report.sql
Type: Read-only preflight query
Owner: msbadmin

Purpose:
  Return current-ingest display rows requiring a production action, operator
  decision, source correction, or defer decision.

Excluded from detail:
  - EXACT_MATCH
  - EXCLUDED_NONPHYSICAL
  - PREVIEW_RELOCATED_SAME_DISPLAY

Safety:
  SELECT only. Does not call P2 and does not modify any object.

Source contract:
  The current run comes only from lor_snap.v_current_run. Display evidence is
  supplied by the installed reconciliation view for that same import_run_id.

Revision History:
  2026-08-01  GAL / OpenAI  Correct Filename header and use lor_snap.v_current_run.
  2026-08-01  GAL / OpenAI  Initial latest-ingest version.
*/

SELECT
    v.import_run_id,
    v.classification_code,
    v.is_blocking,
    v.allowed_resolution_paths,
    v.operator_message,
    v.display_id,
    v.production_display_name,
    v.display_status_id,
    v.display_status_name,
    v.lor_display_name,
    v.lor_prop_id,
    v.preview_stage_id AS proposed_stage_key,
    v.preview_name,
    v.preview_id,
    v.location_summary,
    v.uuid_display_id,
    v.name_display_id,
    v.production_uuid_count,
    v.production_name_count,
    v.lor_uuid_row_count,
    v.lor_uuid_name_count,
    v.lor_name_uuid_count
FROM ops.v_lor_display_reconciliation AS v
JOIN lor_snap.v_current_run AS cr ON cr.import_run_id = v.import_run_id
WHERE v.classification_code NOT IN (
    'EXACT_MATCH', 'EXCLUDED_NONPHYSICAL', 'PREVIEW_RELOCATED_SAME_DISPLAY'
)
ORDER BY
    v.is_blocking DESC,
    v.classification_code,
    coalesce(v.production_display_name, v.lor_display_name),
    v.display_id NULLS LAST,
    v.lor_prop_id NULLS LAST;
