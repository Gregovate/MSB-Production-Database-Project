/*
Schema: lor_snap / ops / ref
Object: Current P2 projected write validation
Filename: 09_current_p2_projected_write_validation.sql
Type: Read-only projected-write validation
Owner: msbadmin

Purpose:
  Project the ref.display changes that a corrected P2 would need to consider for
  the current LOR snapshot, while enforcing the absolute rule that SPARE and
  PHANTOM rows never enter ref.display.

  This script does not execute P2.

Safety:
  SELECT only. Does not call P2, create objects, or modify production data.

Validation focus:
  - Source data comes from the current-view-backed reconciliation layer.
  - SPARE and PHANTOM rows are excluded from every projected ref.display write.
  - Any nonphysical row already associated with ref.display is reported as a
    blocking production defect.
  - Existing display_id values are preserved.
  - Exact matches do not appear unless a genuinely LOR-owned value differs.
  - Display status is not projected from LOR.
  - Name, UUID, stage, and new-display changes retain their reconciliation
    classification for operator approval or deterministic handling.

Result:
  Returns only:
  - blocking nonphysical rows already associated with ref.display; and
  - genuine projected ref.display inserts or updates for physical displays.

  A completely unchanged current snapshot returns zero rows.

Revision History:
  2026-08-01  GAL / OpenAI  Correct nonphysical handling: SPARE and PHANTOM
                           rows are never projected as ref.display writes.
  2026-08-01  GAL / OpenAI  Initial current P2 projected-write validation.
*/

WITH current_run AS (
    SELECT import_run_id, run_ts
    FROM lor_snap.v_current_run
),
reconciliation AS (
    SELECT v.*
    FROM ops.v_lor_display_reconciliation AS v
    JOIN current_run AS cr
      ON cr.import_run_id = v.import_run_id
),
current_source AS (
    SELECT src.*
    FROM lor_snap.v_display_reconciliation_source AS src
    JOIN current_run AS cr
      ON cr.import_run_id = src.import_run_id
),
nonphysical_in_display AS (
    SELECT DISTINCT
        r.import_run_id,
        r.classification_code,
        'NONPHYSICAL_ALREADY_IN_REF_DISPLAY'::text AS validation_code,
        true AS is_blocking,
        d.display_id,
        d.display_name AS production_display_name,
        r.lor_display_name,
        d.lor_prop_id AS current_lor_prop_id,
        r.lor_prop_id AS proposed_lor_prop_id,
        d.stage_id AS current_stage_id,
        NULL::integer AS proposed_stage_id,
        d.display_status_id AS current_display_status_id,
        d.string_type AS current_string_type,
        src.string_type AS proposed_string_type,
        d.color AS current_color,
        src.color AS proposed_color,
        'A current SPARE/PHANTOM source row is associated with ref.display. No P2 write is permitted; resolve the production record separately.'::text AS operator_message
    FROM reconciliation AS r
    JOIN current_source AS src
      ON src.import_run_id = r.import_run_id
     AND src.lor_prop_id = r.lor_prop_id
     AND src.display_name_normalized = r.lor_display_name_normalized
    JOIN ref.display AS d
      ON d.lor_prop_id = r.lor_prop_id
      OR upper(btrim(d.display_name)) = r.lor_display_name_normalized
    WHERE r.classification_code = 'EXCLUDED_NONPHYSICAL'
),
physical_projection AS (
    SELECT
        r.import_run_id,
        r.classification_code,
        CASE
            WHEN r.display_id IS NULL
                THEN 'INSERT_NEW_DISPLAY'
            WHEN d.display_name IS DISTINCT FROM r.lor_display_name
                THEN 'UPDATE_DISPLAY_NAME'
            WHEN d.lor_prop_id IS DISTINCT FROM r.lor_prop_id
                THEN 'UPDATE_LOR_PROP_ID'
            WHEN d.stage_id IS DISTINCT FROM st.stage_id
                THEN 'UPDATE_STAGE_ID'
            WHEN d.string_type IS DISTINCT FROM src.string_type
              OR d.color IS DISTINCT FROM src.color
                THEN 'UPDATE_LOR_METADATA'
            ELSE 'NO_REF_DISPLAY_CHANGE'
        END AS validation_code,
        r.is_blocking,
        r.display_id,
        d.display_name AS production_display_name,
        r.lor_display_name,
        d.lor_prop_id AS current_lor_prop_id,
        r.lor_prop_id AS proposed_lor_prop_id,
        d.stage_id AS current_stage_id,
        st.stage_id AS proposed_stage_id,
        d.display_status_id AS current_display_status_id,
        d.string_type AS current_string_type,
        src.string_type AS proposed_string_type,
        d.color AS current_color,
        src.color AS proposed_color,
        CASE
            WHEN r.display_id IS NULL
                THEN 'New physical display requires the approved ADD_NEW_DISPLAY path.'
            WHEN d.display_name IS DISTINCT FROM r.lor_display_name
                THEN 'Apply the approved LOR display-name correction while preserving display_id.'
            WHEN d.lor_prop_id IS DISTINCT FROM r.lor_prop_id
                THEN 'Update the current LOR UUID association while preserving display_id.'
            WHEN d.stage_id IS DISTINCT FROM st.stage_id
                THEN 'Update the LOR-owned stage assignment while preserving display_id.'
            WHEN d.string_type IS DISTINCT FROM src.string_type
              OR d.color IS DISTINCT FROM src.color
                THEN 'Update only the changed LOR-owned metadata values.'
            ELSE 'No ref.display change is required.'
        END AS operator_message
    FROM reconciliation AS r
    JOIN current_source AS src
      ON src.import_run_id = r.import_run_id
     AND src.lor_prop_id = r.lor_prop_id
     AND src.display_name_normalized = r.lor_display_name_normalized
    LEFT JOIN ref.display AS d
      ON d.display_id = r.display_id
    LEFT JOIN ref.stage AS st
      ON st.stage_key = lower(btrim(r.preview_stage_id))
    WHERE r.classification_code <> 'EXCLUDED_NONPHYSICAL'
      AND r.classification_code IN (
          'EXACT_MATCH',
          'PREVIEW_RELOCATED_SAME_DISPLAY',
          'NAME_CHANGED_SAME_UUID',
          'UUID_CHANGED_SAME_NAME',
          'NEW_DISPLAY_CANDIDATE',
          'NAME_AND_UUID_CHANGED'
      )
),
report_rows AS (
    SELECT * FROM nonphysical_in_display

    UNION ALL

    SELECT *
    FROM physical_projection
    WHERE validation_code <> 'NO_REF_DISPLAY_CHANGE'
)
SELECT
    import_run_id,
    classification_code,
    validation_code,
    is_blocking,
    display_id,
    production_display_name,
    lor_display_name,
    current_lor_prop_id,
    proposed_lor_prop_id,
    current_stage_id,
    proposed_stage_id,
    current_display_status_id,
    current_string_type,
    proposed_string_type,
    current_color,
    proposed_color,
    operator_message
FROM report_rows
ORDER BY
    is_blocking DESC,
    CASE validation_code
        WHEN 'NONPHYSICAL_ALREADY_IN_REF_DISPLAY' THEN 1
        WHEN 'INSERT_NEW_DISPLAY' THEN 2
        WHEN 'UPDATE_DISPLAY_NAME' THEN 3
        WHEN 'UPDATE_LOR_PROP_ID' THEN 4
        WHEN 'UPDATE_STAGE_ID' THEN 5
        WHEN 'UPDATE_LOR_METADATA' THEN 6
        ELSE 99
    END,
    coalesce(production_display_name, lor_display_name),
    display_id NULLS LAST,
    proposed_lor_prop_id;
