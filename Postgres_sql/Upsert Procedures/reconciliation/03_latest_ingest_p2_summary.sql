/*
Schema: ops / lor_snap
Object: Current-ingest P2 reconciliation summary
Filename: 03_latest_ingest_p2_summary.sql
Type: Read-only preflight query
Owner: msbadmin

Purpose:
  Return one exportable summary row for the current LOR snapshot. Identity
  classifications and actual projected ref.display changes are counted
  separately so an EXACT_MATCH cannot hide a stage or string-type change.

Safety:
  SELECT only. Does not call P2 and does not modify any object.

Source contract:
  The current run comes only from lor_snap.v_current_run. Display evidence is
  supplied by the installed reconciliation view for that same import_run_id.

Revision History:
  2026-08-02  GAL / OpenAI  Removed a redundant second evaluation of the
                           canonical source view; read string_type from the
                           already exact-matched raw prop row.
  2026-08-02  GAL / OpenAI  Added projected-write counts based on the same
                           LOR-owned fields as query 09; excluded color and
                           exposed changes hidden by EXACT_MATCH identity.
  2026-08-02  GAL / OpenAI  Remove obsolete preview-relocation identity class;
                           raw_prop_id is independent of preview scope.
  2026-08-01  GAL / OpenAI  Use lor_snap.v_current_run as the shared current-run source.
  2026-08-01  GAL / OpenAI  Initial latest-ingest version.
*/

WITH current_run AS (
    SELECT import_run_id, run_ts
    FROM lor_snap.v_current_run
),
classification_counts AS (
    SELECT
        v.import_run_id,
        count(*) FILTER (WHERE v.classification_code = 'EXACT_MATCH') AS exact_match_count,
        count(*) FILTER (WHERE v.classification_code = 'EXCLUDED_NONPHYSICAL') AS excluded_nonphysical_count,
        count(*) FILTER (
            WHERE v.classification_code NOT IN (
                'EXACT_MATCH', 'EXCLUDED_NONPHYSICAL'
            )
        ) AS action_or_review_count,
        count(*) FILTER (
            WHERE v.classification_code NOT IN (
                'EXACT_MATCH',
                'EXCLUDED_NONPHYSICAL',
                'NAME_CHANGED_SAME_UUID',
                'UUID_CHANGED_SAME_NAME',
                'NEW_DISPLAY_CANDIDATE',
                'ACTIVE_DISPLAY_MISSING_FROM_LOR',
                'NONACTIVE_DISPLAY_PRESENT_IN_LOR'
            )
        ) AS blocking_count,
        count(*) AS total_count
    FROM ops.v_lor_display_reconciliation AS v
    JOIN current_run AS cr ON cr.import_run_id = v.import_run_id
    GROUP BY v.import_run_id
),
projected_changes AS (
    SELECT
        v.import_run_id,
        v.classification_code,
        v.display_id,
        ARRAY_REMOVE(ARRAY[
            CASE WHEN v.display_id IS NULL THEN 'new_display' END,
            CASE WHEN d.display_name IS DISTINCT FROM v.lor_display_name THEN 'display_name' END,
            CASE WHEN d.lor_prop_id IS DISTINCT FROM v.lor_prop_id THEN 'lor_prop_id' END,
            CASE WHEN d.stage_id IS DISTINCT FROM st.stage_id THEN 'stage_id' END,
            CASE WHEN d.string_type IS DISTINCT FROM raw.string_type THEN 'string_type' END
        ]::text[], NULL) AS changed_fields
    FROM ops.v_lor_display_reconciliation AS v
    JOIN current_run AS cr
      ON cr.import_run_id = v.import_run_id
    JOIN lor_snap.props AS raw
      ON raw.import_run_id = v.import_run_id
     AND raw.prop_id = v.source_prop_id
     AND raw.raw_prop_id = v.lor_prop_id
    LEFT JOIN ref.display AS d
      ON d.display_id = v.display_id
    LEFT JOIN ref.stage AS st
      ON st.stage_key = lower(btrim(v.preview_stage_id))
    WHERE v.classification_code IN (
        'EXACT_MATCH',
        'NAME_CHANGED_SAME_UUID',
        'UUID_CHANGED_SAME_NAME',
        'NAME_AND_UUID_CHANGED',
        'NEW_DISPLAY_CANDIDATE'
    )
      AND nullif(btrim(raw.lor_comment), '') IS NOT NULL
),
projected_counts AS (
    SELECT
        import_run_id,
        count(*) FILTER (WHERE cardinality(changed_fields) > 0)
            AS projected_change_count,
        count(*) FILTER (
            WHERE classification_code = 'EXACT_MATCH'
              AND cardinality(changed_fields) > 0
        ) AS exact_match_projected_change_count,
        count(*) FILTER (
            WHERE classification_code = 'NAME_AND_UUID_CHANGED'
              AND cardinality(changed_fields) > 0
        ) AS unresolved_reassociation_count
    FROM projected_changes
    GROUP BY import_run_id
)
SELECT
    cr.import_run_id,
    cr.run_ts AS ingest_timestamp,
    cc.total_count,
    cc.exact_match_count,
    cc.excluded_nonphysical_count,
    cc.action_or_review_count,
    cc.blocking_count,
    coalesce(pc.projected_change_count, 0) AS projected_change_count,
    coalesce(pc.exact_match_projected_change_count, 0)
        AS exact_match_projected_change_count,
    coalesce(pc.unresolved_reassociation_count, 0)
        AS unresolved_reassociation_count,
    CASE
        WHEN cc.blocking_count > 0 THEN 'BLOCKED_ITEMS_PRESENT'
        WHEN cc.action_or_review_count > 0
          OR coalesce(pc.projected_change_count, 0) > 0 THEN 'REVIEW_REQUIRED'
        ELSE 'NO_REF_DISPLAY_CHANGES'
    END AS preflight_result
FROM current_run AS cr
LEFT JOIN classification_counts AS cc ON cc.import_run_id = cr.import_run_id
LEFT JOIN projected_counts AS pc ON pc.import_run_id = cr.import_run_id;
