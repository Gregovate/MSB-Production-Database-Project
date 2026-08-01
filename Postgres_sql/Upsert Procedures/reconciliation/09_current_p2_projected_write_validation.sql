/*
Schema: lor_snap / ops / ref
Object: Current P2 projected write validation
Filename: 09_current_p2_projected_write_validation.sql
Type: Read-only projected-write validation
Owner: msbadmin

Purpose:
  Show the production changes the currently installed legacy P2 logic would
  attempt against the established lor_snap.v_current_* snapshot contract.

  This script does not execute P2. It highlights unsafe or unnecessary writes
  that must be removed before P2 can be rewritten and enabled.

Safety:
  SELECT only. Does not call P2, create objects, or modify production data.

Validation focus:
  - Existing display_id must be preserved.
  - Exact matches must not be rewritten merely because P2 ran.
  - display_status_id must not be forced to ACTIVE.
  - Stage changes must follow resolved reconciliation evidence.
  - Name and LOR UUID changes must be classified before they are written.
  - SPARE and PHANTOM rows must not be written by P2.

Result:
  Returns only rows where the legacy P2 behavior would attempt a production
  insert or update, including the reason the write requires redesign or review.

Revision History:
  2026-08-01  GAL / OpenAI  Initial current P2 projected-write validation.
*/

WITH current_run AS (
    SELECT import_run_id, run_ts
    FROM lor_snap.v_current_run
),
active_status AS (
    SELECT display_status_id
    FROM ref.display_status
    WHERE upper(btrim(display_status_name)) = 'ACTIVE'
    ORDER BY display_status_id
    LIMIT 1
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
        r.classification_code,
        r.display_id,
        r.production_display_name,
        r.lor_display_name,
        r.lor_prop_id AS proposed_lor_prop_id,
        d.lor_prop_id AS current_lor_prop_id,
        d.stage_id AS current_stage_id,
        st.stage_id AS proposed_stage_id,
        d.display_status_id AS current_display_status_id,
        ast.display_status_id AS legacy_proposed_status_id,
        d.string_type AS current_string_type,
        src.string_type AS proposed_string_type,
        d.color AS current_color,
        src.color AS proposed_color,
        CASE
            WHEN r.classification_code = 'EXCLUDED_NONPHYSICAL'
                THEN 'LEGACY_P2_WOULD_ROUTE_NONPHYSICAL_ROW'
            WHEN r.display_id IS NULL
                THEN 'LEGACY_P2_WOULD_INSERT_NEW_DISPLAY'
            WHEN d.display_status_id IS DISTINCT FROM ast.display_status_id
                THEN 'LEGACY_P2_WOULD_FORCE_ACTIVE_STATUS'
            WHEN d.display_name IS DISTINCT FROM r.lor_display_name
                THEN 'LEGACY_P2_WOULD_RENAME_DISPLAY'
            WHEN d.lor_prop_id IS DISTINCT FROM r.lor_prop_id
                THEN 'LEGACY_P2_WOULD_UPDATE_LOR_LINK'
            WHEN d.stage_id IS DISTINCT FROM st.stage_id
                THEN 'LEGACY_P2_WOULD_CHANGE_STAGE'
            WHEN d.string_type IS DISTINCT FROM src.string_type
              OR d.color IS DISTINCT FROM src.color
                THEN 'LEGACY_P2_WOULD_UPDATE_LOR_METADATA'
            ELSE 'NO_PRODUCTION_CHANGE_REQUIRED'
        END AS projected_write_class,
        CASE
            WHEN r.classification_code = 'EXCLUDED_NONPHYSICAL'
                THEN 'SPARE/PHANTOM rows are excluded from ref.display and must not be written by P2.'
            WHEN r.display_id IS NULL
                THEN 'New display insertion requires an approved reconciliation resolution.'
            WHEN d.display_status_id IS DISTINCT FROM ast.display_status_id
                THEN 'Legacy P2 would overwrite the PostgreSQL-owned display status with ACTIVE.'
            WHEN d.display_name IS DISTINCT FROM r.lor_display_name
                THEN 'Display rename must follow the approved reconciliation classification while preserving display_id.'
            WHEN d.lor_prop_id IS DISTINCT FROM r.lor_prop_id
                THEN 'LOR UUID reassociation must follow the approved reconciliation classification while preserving display_id.'
            WHEN d.stage_id IS DISTINCT FROM st.stage_id
                THEN 'Stage reassignment must use the resolved current LOR evidence and preserve display_id.'
            WHEN d.string_type IS DISTINCT FROM src.string_type
              OR d.color IS DISTINCT FROM src.color
                THEN 'LOR-owned metadata differs, but exact matches should update only genuinely changed values.'
            ELSE 'The current production display already matches the projected values.'
        END AS operator_message
    FROM reconciliation AS r
    LEFT JOIN ref.display AS d
      ON d.display_id = r.display_id
    LEFT JOIN lor_snap.v_display_reconciliation_source AS src
      ON src.import_run_id = r.import_run_id
     AND src.lor_prop_id = r.lor_prop_id
     AND src.display_name_normalized = r.lor_display_name_normalized
    LEFT JOIN ref.stage AS st
      ON st.stage_key = lower(btrim(r.preview_stage_id))
    CROSS JOIN active_status AS ast
)
SELECT
    import_run_id,
    classification_code,
    projected_write_class,
    display_id,
    production_display_name,
    lor_display_name,
    current_lor_prop_id,
    proposed_lor_prop_id,
    current_stage_id,
    proposed_stage_id,
    current_display_status_id,
    legacy_proposed_status_id,
    current_string_type,
    proposed_string_type,
    current_color,
    proposed_color,
    operator_message
FROM projected
WHERE projected_write_class <> 'NO_PRODUCTION_CHANGE_REQUIRED'
ORDER BY
    CASE projected_write_class
        WHEN 'LEGACY_P2_WOULD_FORCE_ACTIVE_STATUS' THEN 1
        WHEN 'LEGACY_P2_WOULD_INSERT_NEW_DISPLAY' THEN 2
        WHEN 'LEGACY_P2_WOULD_RENAME_DISPLAY' THEN 3
        WHEN 'LEGACY_P2_WOULD_UPDATE_LOR_LINK' THEN 4
        WHEN 'LEGACY_P2_WOULD_CHANGE_STAGE' THEN 5
        WHEN 'LEGACY_P2_WOULD_UPDATE_LOR_METADATA' THEN 6
        WHEN 'LEGACY_P2_WOULD_ROUTE_NONPHYSICAL_ROW' THEN 7
        ELSE 99
    END,
    coalesce(production_display_name, lor_display_name),
    display_id NULLS LAST,
    proposed_lor_prop_id;
