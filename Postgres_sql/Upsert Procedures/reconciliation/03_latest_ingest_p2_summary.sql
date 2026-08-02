/*
Schema: ops / lor_snap
Object: Current-ingest P2 reconciliation summary
Filename: 03_latest_ingest_p2_summary.sql
Type: Read-only preflight query
Owner: msbadmin

Purpose:
  Return one exportable summary row for the current LOR snapshot.

Safety:
  SELECT only. Does not call P2 and does not modify any object.

Source contract:
  The current run comes only from lor_snap.v_current_run. Display evidence is
  supplied by the installed reconciliation view for that same import_run_id.

Revision History:
  2026-08-02  GAL / OpenAI  Remove obsolete preview-relocation identity class;
                           raw_prop_id is independent of preview scope.
  2026-08-01  GAL / OpenAI  Use lor_snap.v_current_run as the shared current-run source.
  2026-08-01  GAL / OpenAI  Initial latest-ingest version.
*/

WITH classification_counts AS (
    SELECT
        v.import_run_id,
        count(*) FILTER (WHERE v.classification_code = 'EXACT_MATCH') AS exact_match_count,
        count(*) FILTER (WHERE v.classification_code = 'EXCLUDED_NONPHYSICAL') AS excluded_nonphysical_count,
        count(*) FILTER (
            WHERE v.classification_code NOT IN (
                'EXACT_MATCH', 'EXCLUDED_NONPHYSICAL'
            )
        ) AS action_or_review_count,
        count(*) FILTER (WHERE v.is_blocking) AS blocking_count,
        count(*) AS total_count
    FROM ops.v_lor_display_reconciliation AS v
    JOIN lor_snap.v_current_run AS cr ON cr.import_run_id = v.import_run_id
    GROUP BY v.import_run_id
)
SELECT
    cr.import_run_id,
    cr.run_ts AS ingest_timestamp,
    cc.total_count,
    cc.exact_match_count,
    cc.excluded_nonphysical_count,
    cc.action_or_review_count,
    cc.blocking_count,
    CASE
        WHEN cc.blocking_count > 0 THEN 'BLOCKED_ITEMS_PRESENT'
        WHEN cc.action_or_review_count > 0 THEN 'REVIEW_REQUIRED'
        ELSE 'NO_REF_DISPLAY_CHANGES'
    END AS preflight_result
FROM lor_snap.v_current_run AS cr
LEFT JOIN classification_counts AS cc ON cc.import_run_id = cr.import_run_id;
