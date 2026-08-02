/*
Schema: lor_snap / ops / ref
Object: Current P2 projected write validation
Filename: 09_current_p2_projected_write_validation.sql
Type: Read-only projected-write validation
Owner: msbadmin

Purpose:
  Project the complete ref.display row changes that a corrected P2 would need
  to consider for the current LOR snapshot, while enforcing the absolute rule
  that SPARE, PHANTOM, and null/blank LOR comments never enter ref.display.

  This script does not execute P2.

Safety:
  SELECT only. Does not call P2, create objects, record decisions, or modify
  lor_snap, ref, or ops data.

Validation focus:
  - Source data comes from the current-view-backed reconciliation layer.
  - SPARE, PHANTOM, null, empty, and whitespace-only LOR comments are excluded
    from every projected ref.display write.
  - Any excluded source row already associated with ref.display is reported as
    a blocking production defect.
  - Existing display_id values are preserved.
  - Exact matches do not appear unless a genuinely LOR-owned value differs.
  - Display status is not projected from LOR.
  - Every changed shared field is reported on the same projected row.
  - NAME_AND_UUID_CHANGED never becomes a projected write until an explicit
    reassociation decision identifies the preserved production display_id.

Permitted projected ref.display fields:
  - lor_prop_id
  - display_name
  - stage_id
  - string_type
  - color

Result:
  Returns only:
  - blocking excluded-source rows already associated with ref.display;
  - unresolved reassociation candidates that must not be written; and
  - genuine projected ref.display inserts or updates for physical displays.

  A completely unchanged current snapshot returns zero rows.

Revision History:
  2026-08-02  GAL / OpenAI  Added defense-in-depth exclusion for null, empty,
                           and whitespace-only LOR comments. Such source rows
                           can never create or update ref.display.
  2026-08-02  GAL / OpenAI  Report all changed shared fields on one projected
                           row and block NAME_AND_UUID_CHANGED until a persisted
                           reassociation decision supplies the production row.
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
        ARRAY['NONPHYSICAL_SOURCE']::text[] AS changed_fields,
        'A current SPARE or PHANTOM source row is associated with ref.display. No P2 write is permitted; resolve the production record separately.'::text AS operator_message
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
blank_comment_in_display AS (
    SELECT DISTINCT
        src.import_run_id,
        'EXCLUDED_BLANK_COMMENT'::text AS classification_code,
        'BLANK_COMMENT_ALREADY_IN_REF_DISPLAY'::text AS validation_code,
        true AS is_blocking,
        d.display_id,
        d.display_name AS production_display_name,
        NULL::text AS lor_display_name,
        d.lor_prop_id AS current_lor_prop_id,
        src.lor_prop_id AS proposed_lor_prop_id,
        d.stage_id AS current_stage_id,
        NULL::integer AS proposed_stage_id,
        d.display_status_id AS current_display_status_id,
        d.string_type AS current_string_type,
        src.string_type AS proposed_string_type,
        d.color AS current_color,
        src.color AS proposed_color,
        ARRAY['BLANK_LOR_COMMENT']::text[] AS changed_fields,
        'A current source row with a null, empty, or whitespace-only LOR comment is associated with ref.display. No P2 write is permitted; resolve the production record separately.'::text AS operator_message
    FROM current_source AS src
    JOIN ref.display AS d
      ON d.lor_prop_id = src.lor_prop_id
    WHERE NULLIF(btrim(src.display_name_normalized), '') IS NULL
),
unresolved_reassociation AS (
    SELECT
        r.import_run_id,
        r.classification_code,
        'REASSOCIATION_DECISION_REQUIRED'::text AS validation_code,
        true AS is_blocking,
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
        ARRAY_REMOVE(ARRAY[
            CASE WHEN d.display_name IS DISTINCT FROM r.lor_display_name THEN 'display_name' END,
            CASE WHEN d.lor_prop_id IS DISTINCT FROM r.lor_prop_id THEN 'lor_prop_id' END,
            CASE WHEN d.stage_id IS DISTINCT FROM st.stage_id THEN 'stage_id' END,
            CASE WHEN d.string_type IS DISTINCT FROM src.string_type THEN 'string_type' END,
            CASE WHEN d.color IS DISTINCT FROM src.color THEN 'color' END
        ]::text[], NULL) AS changed_fields,
        'Name and LOR UUID both changed. P2 must not project a write until an explicit reassociation decision identifies the existing display_id to preserve.'::text AS operator_message
    FROM reconciliation AS r
    JOIN current_source AS src
      ON src.import_run_id = r.import_run_id
     AND src.lor_prop_id = r.lor_prop_id
     AND src.display_name_normalized = r.lor_display_name_normalized
    LEFT JOIN ref.display AS d
      ON d.display_id = r.display_id
    LEFT JOIN ref.stage AS st
      ON st.stage_key = lower(btrim(r.preview_stage_id))
    WHERE r.classification_code = 'NAME_AND_UUID_CHANGED'
      AND NULLIF(btrim(r.lor_display_name), '') IS NOT NULL
),
physical_projection_base AS (
    SELECT
        r.import_run_id,
        r.classification_code,
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
        ARRAY_REMOVE(ARRAY[
            CASE WHEN r.display_id IS NULL THEN 'new_display' END,
            CASE WHEN d.display_name IS DISTINCT FROM r.lor_display_name THEN 'display_name' END,
            CASE WHEN d.lor_prop_id IS DISTINCT FROM r.lor_prop_id THEN 'lor_prop_id' END,
            CASE WHEN d.stage_id IS DISTINCT FROM st.stage_id THEN 'stage_id' END,
            CASE WHEN d.string_type IS DISTINCT FROM src.string_type THEN 'string_type' END,
            CASE WHEN d.color IS DISTINCT FROM src.color THEN 'color' END
        ]::text[], NULL) AS changed_fields
    FROM reconciliation AS r
    JOIN current_source AS src
      ON src.import_run_id = r.import_run_id
     AND src.lor_prop_id = r.lor_prop_id
     AND src.display_name_normalized = r.lor_display_name_normalized
    LEFT JOIN ref.display AS d
      ON d.display_id = r.display_id
    LEFT JOIN ref.stage AS st
      ON st.stage_key = lower(btrim(r.preview_stage_id))
    WHERE r.classification_code IN (
        'EXACT_MATCH',
        'PREVIEW_RELOCATED_SAME_DISPLAY',
        'NAME_CHANGED_SAME_UUID',
        'UUID_CHANGED_SAME_NAME',
        'NEW_DISPLAY_CANDIDATE'
    )
      AND NULLIF(btrim(r.lor_display_name), '') IS NOT NULL
      AND NULLIF(btrim(src.display_name_normalized), '') IS NOT NULL
),
physical_projection AS (
    SELECT
        p.import_run_id,
        p.classification_code,
        CASE
            WHEN p.display_id IS NULL THEN 'INSERT_NEW_DISPLAY'
            ELSE 'UPDATE_EXISTING_DISPLAY'
        END AS validation_code,
        p.is_blocking,
        p.display_id,
        p.production_display_name,
        p.lor_display_name,
        p.current_lor_prop_id,
        p.proposed_lor_prop_id,
        p.current_stage_id,
        p.proposed_stage_id,
        p.current_display_status_id,
        p.current_string_type,
        p.proposed_string_type,
        p.current_color,
        p.proposed_color,
        p.changed_fields,
        CASE
            WHEN p.display_id IS NULL THEN
                'New physical display requires the approved ADD_NEW_DISPLAY path.'
            ELSE
                format(
                    'Update only these approved LOR-owned fields while preserving display_id and all other production metadata: %s.',
                    array_to_string(p.changed_fields, ', ')
                )
        END AS operator_message
    FROM physical_projection_base AS p
    WHERE cardinality(p.changed_fields) > 0
),
report_rows AS (
    SELECT * FROM nonphysical_in_display

    UNION ALL

    SELECT * FROM blank_comment_in_display

    UNION ALL

    SELECT * FROM unresolved_reassociation

    UNION ALL

    SELECT * FROM physical_projection
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
    changed_fields,
    operator_message
FROM report_rows
ORDER BY
    is_blocking DESC,
    CASE validation_code
        WHEN 'NONPHYSICAL_ALREADY_IN_REF_DISPLAY' THEN 1
        WHEN 'BLANK_COMMENT_ALREADY_IN_REF_DISPLAY' THEN 2
        WHEN 'REASSOCIATION_DECISION_REQUIRED' THEN 3
        WHEN 'INSERT_NEW_DISPLAY' THEN 4
        WHEN 'UPDATE_EXISTING_DISPLAY' THEN 5
        ELSE 99
    END,
    coalesce(production_display_name, lor_display_name),
    display_id NULLS LAST,
    proposed_lor_prop_id;
