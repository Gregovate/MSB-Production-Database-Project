/*
Schema: ops / lor_snap
Object: Latest-ingest P2 reconciliation summary
Type: Read-only preflight query
Owner: msbadmin

Purpose:
  Return one exportable summary row for the latest ingest using the installed
  reconciliation view and summary function.

Safety:
  SELECT only. Does not call P2 and does not modify any object.

Revision History:
  2026-08-01  GAL / OpenAI  Initial latest-ingest version.
*/

WITH selected_run AS (
    SELECT ir.import_run_id, ir.run_ts
    FROM lor_snap.import_run AS ir
    ORDER BY ir.import_run_id DESC
    LIMIT 1
),
classification_counts AS (
    SELECT
        v.import_run_id,
        count(*) FILTER (WHERE v.classification_code = 'EXACT_MATCH') AS exact_match_count,
        count(*) FILTER (WHERE v.classification_code = 'EXCLUDED_NONPHYSICAL') AS excluded_nonphysical_count,
        count(*) FILTER (WHERE v.classification_code = 'PREVIEW_RELOCATED_SAME_DISPLAY') AS preview_relocated_count,
        count(*) FILTER (
            WHERE v.classification_code NOT IN (
                'EXACT_MATCH',
                'EXCLUDED_NONPHYSICAL',
                'PREVIEW_RELOCATED_SAME_DISPLAY'
            )
        ) AS action_or_review_count,
        count(*) FILTER (WHERE v.is_blocking) AS blocking_count,
        count(*) AS total_count
    FROM ops.v_lor_display_reconciliation AS v
    JOIN selected_run AS sr ON sr.import_run_id = v.import_run_id
    GROUP BY v.import_run_id
)
SELECT
    sr.import_run_id,
    sr.run_ts AS ingest_timestamp,
    cc.total_count,
    cc.exact_match_count,
    cc.excluded_nonphysical_count,
    cc.preview_relocated_count,
    cc.action_or_review_count,
    cc.blocking_count,
    CASE
        WHEN cc.blocking_count > 0 THEN 'BLOCKED_ITEMS_PRESENT'
        WHEN cc.action_or_review_count > 0 THEN 'REVIEW_REQUIRED'
        ELSE 'NO_REF_DISPLAY_CHANGES'
    END AS preflight_result
FROM selected_run AS sr
LEFT JOIN classification_counts AS cc
  ON cc.import_run_id = sr.import_run_id;
