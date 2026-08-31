/* ============================================================================
Controller Inventory bootstrap validation / review report — STAGE ONLY
Issue: #110
Read-only.

This script requires only stage.controller_bootstrap* plus existing ref.display.
It does not require ref.controller* to exist.
============================================================================ */

SELECT
    count(*) AS staging_rows,
    count(*) FILTER (WHERE review_state = 'READY') AS ready_rows,
    count(*) FILTER (WHERE review_state = 'REVIEW_REQUIRED') AS review_required_rows,
    count(*) FILTER (WHERE review_state = 'SKIPPED') AS skipped_rows,
    count(*) FILTER (WHERE year_deployed IS NULL) AS missing_year_rows,
    count(*) FILTER (WHERE nullif(btrim(model_evidence), '') IS NULL) AS missing_model_rows,
    count(*) FILTER (WHERE firmware_state_evidence = 'RECORDED') AS firmware_recorded_rows,
    count(*) FILTER (WHERE firmware_state_evidence = 'UNKNOWN_OR_VERIFY') AS firmware_verify_rows,
    count(*) FILTER (WHERE bootstrap_order IS NOT NULL) AS ordered_rows
FROM stage.controller_bootstrap;

SELECT
    controller_bootstrap_id,
    source_row_num,
    display_name_evidence,
    network_evidence,
    uid_evidence,
    model_evidence,
    firmware_evidence,
    firmware_state_evidence,
    serves_count,
    serves_displays,
    year_deployed,
    blockers,
    review_state,
    review_notes
FROM stage.v_controller_bootstrap_review
WHERE review_state = 'REVIEW_REQUIRED'
   OR cardinality(blockers) > 0
ORDER BY source_row_num;

SELECT
    bootstrap_order,
    proposed_controller_id,
    year_deployed,
    network_evidence,
    uid_evidence,
    display_name_evidence,
    model_evidence,
    firmware_evidence,
    firmware_state_evidence,
    for_what_evidence,
    source_row_num
FROM stage.controller_bootstrap
WHERE review_state = 'READY'
ORDER BY bootstrap_order NULLS LAST,
         year_deployed,
         lower(coalesce(network_evidence, '')),
         lower(coalesce(uid_evidence, '')),
         source_row_num;

-- Useful duplicate-address review evidence. Duplicate Network/UID is valid and
-- must not be collapsed; this simply makes the groups visible during review.
SELECT
    network_evidence,
    uid_evidence,
    count(*) AS controller_candidates,
    string_agg(
        source_row_num::text || ':' || display_name_evidence,
        ' | ' ORDER BY source_row_num
    ) AS candidate_rows
FROM stage.controller_bootstrap
GROUP BY network_evidence, uid_evidence
HAVING count(*) > 1
ORDER BY lower(coalesce(network_evidence, '')),
         lower(coalesce(uid_evidence, ''));
