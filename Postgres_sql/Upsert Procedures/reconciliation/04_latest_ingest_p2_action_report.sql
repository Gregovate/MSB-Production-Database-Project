/*
Schema: ops / lor_snap / ref
Object: Current-ingest P2 action and review report
Filename: 04_latest_ingest_p2_action_report.sql
Type: Read-only preflight query
Owner: msbadmin

Purpose:
  Return current-ingest display rows requiring a production action, operator
  decision, source correction, or defer decision. Identity matches with a
  projected field change are actions and must not be hidden.

Excluded from detail:
  - EXACT_MATCH with no projected ref.display change
  - EXCLUDED_NONPHYSICAL

Safety:
  SELECT only. Does not call P2 and does not modify any object.

Source contract:
  The current run comes only from lor_snap.v_current_run. Display evidence is
  supplied by the installed reconciliation view for that same import_run_id.

Revision History:
  2026-08-02  GAL / OpenAI  Added projected field comparison so exact identity
                           matches with stage or string-type changes remain
                           visible and available for DEFER; excluded color.
  2026-08-02  GAL / OpenAI  Include source_prop_id so operator evidence and
                           later P2 guards identify the exact snapshot row.
  2026-08-02  GAL / OpenAI  Remove obsolete preview-relocation identity class;
                           raw_prop_id is independent of preview scope.
  2026-08-01  GAL / OpenAI  Correct Filename header and use lor_snap.v_current_run.
  2026-08-01  GAL / OpenAI  Initial latest-ingest version.
*/

WITH current_run AS (
    SELECT import_run_id
    FROM lor_snap.v_current_run
),
reconciliation AS (
    SELECT v.*
    FROM ops.v_lor_display_reconciliation AS v
    JOIN current_run AS cr
      ON cr.import_run_id = v.import_run_id
),
projected AS (
    SELECT
        r.import_run_id,
        r.source_prop_id,
        d.stage_id AS current_stage_id,
        st.stage_id AS proposed_stage_id,
        d.string_type AS current_string_type,
        src.string_type AS proposed_string_type,
        ARRAY_REMOVE(ARRAY[
            CASE WHEN r.display_id IS NULL THEN 'new_display' END,
            CASE WHEN d.display_name IS DISTINCT FROM r.lor_display_name THEN 'display_name' END,
            CASE WHEN d.lor_prop_id IS DISTINCT FROM r.lor_prop_id THEN 'lor_prop_id' END,
            CASE WHEN d.stage_id IS DISTINCT FROM st.stage_id THEN 'stage_id' END,
            CASE WHEN d.string_type IS DISTINCT FROM src.string_type THEN 'string_type' END
        ]::text[], NULL) AS changed_fields
    FROM reconciliation AS r
    JOIN lor_snap.v_display_reconciliation_source AS src
      ON src.import_run_id = r.import_run_id
     AND src.lor_prop_id = r.lor_prop_id
     AND src.display_name_normalized = r.lor_display_name_normalized
    JOIN lor_snap.props AS raw
      ON raw.import_run_id = r.import_run_id
     AND raw.prop_id = r.source_prop_id
     AND raw.raw_prop_id = r.lor_prop_id
    LEFT JOIN ref.display AS d
      ON d.display_id = r.display_id
    LEFT JOIN ref.stage AS st
      ON st.stage_key = lower(btrim(r.preview_stage_id))
    WHERE nullif(btrim(raw.lor_comment), '') IS NOT NULL
),
action_rows AS (
    SELECT
        r.*,
        p.current_stage_id,
        p.proposed_stage_id,
        p.current_string_type,
        p.proposed_string_type,
        coalesce(p.changed_fields, ARRAY[]::text[]) AS changed_fields
    FROM reconciliation AS r
    LEFT JOIN projected AS p
      ON p.import_run_id = r.import_run_id
     AND p.source_prop_id = r.source_prop_id
    WHERE r.classification_code NOT IN ('EXACT_MATCH', 'EXCLUDED_NONPHYSICAL')
       OR (
            r.classification_code = 'EXACT_MATCH'
        AND cardinality(coalesce(p.changed_fields, ARRAY[]::text[])) > 0
       )
)
SELECT
    a.import_run_id,
    a.classification_code,
    CASE
        WHEN a.classification_code = 'NAME_AND_UUID_CHANGED' THEN true
        ELSE a.is_blocking
    END AS is_blocking,
    CASE
        WHEN a.classification_code = 'EXACT_MATCH'
            THEN ARRAY['DEFER']::text[]
        ELSE a.allowed_resolution_paths
    END AS allowed_resolution_paths,
    CASE
        WHEN a.classification_code = 'EXACT_MATCH' THEN format(
            'Identity matches production. Projected fields: %s. The change remains eligible unless the operator records DEFER.',
            array_to_string(a.changed_fields, ', ')
        )
        ELSE a.operator_message
    END AS operator_message,
    a.production_display_name,
    a.lor_display_name,
    current_stage.stage_key AS current_stage_key,
    current_stage.stage_name AS current_stage_name,
    a.preview_stage_id AS proposed_stage_key,
    proposed_stage.stage_name AS proposed_stage_name,
    a.preview_name,
    a.location_summary,
    a.current_string_type,
    a.proposed_string_type,
    a.changed_fields,
    a.display_id,
    a.display_status_id,
    a.display_status_name,
    a.source_prop_id,
    a.lor_prop_id,
    a.preview_id,
    a.uuid_display_id,
    a.name_display_id,
    a.production_uuid_count,
    a.production_name_count,
    a.lor_uuid_row_count,
    a.lor_uuid_name_count,
    a.lor_name_uuid_count
FROM action_rows AS a
LEFT JOIN ref.stage AS current_stage
  ON current_stage.stage_id = a.current_stage_id
LEFT JOIN ref.stage AS proposed_stage
  ON proposed_stage.stage_id = a.proposed_stage_id
ORDER BY
    is_blocking DESC,
    a.classification_code,
    coalesce(a.production_display_name, a.lor_display_name),
    a.display_id NULLS LAST,
    a.lor_prop_id NULLS LAST;
