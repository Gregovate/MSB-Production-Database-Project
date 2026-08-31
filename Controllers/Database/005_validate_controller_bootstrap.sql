/* ============================================================================
Controller Inventory bootstrap validation / review report
Issue: #110
Read-only.
============================================================================ */

SELECT
    count(*) AS staging_rows,
    count(*) FILTER (WHERE review_state = 'READY') AS ready_rows,
    count(*) FILTER (WHERE review_state = 'REVIEW_REQUIRED') AS review_required_rows,
    count(*) FILTER (WHERE review_state = 'SKIPPED') AS skipped_rows,
    count(*) FILTER (WHERE year_deployed IS NULL) AS missing_year_rows,
    count(*) FILTER (WHERE controller_model_id IS NULL) AS missing_model_rows,
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
    for_what_evidence,
    source_row_num
FROM stage.controller_bootstrap
WHERE review_state = 'READY'
ORDER BY bootstrap_order NULLS LAST,
         year_deployed,
         lower(coalesce(network_evidence, '')),
         lower(coalesce(uid_evidence, '')),
         source_row_num;

SELECT
    count(*) AS permanent_controller_rows,
    min(controller_id) AS first_controller_id,
    max(controller_id) AS last_controller_id,
    count(*) FILTER (WHERE print_label) AS pending_label_requests,
    count(*) FILTER (WHERE label_print_count_cached <> 0) AS rows_with_print_history
FROM ref.controller;

SELECT
    cs.controller_status_name,
    count(*) AS controller_count
FROM ref.controller AS c
JOIN ref.controller_status AS cs
  ON cs.controller_status_id = c.controller_status_id
GROUP BY cs.controller_status_name
ORDER BY cs.controller_status_name;

SELECT
    c.controller_id,
    c.year_deployed,
    m.model_code,
    fv.firmware_version,
    count(cd.display_id) AS display_count,
    string_agg(d.display_name, ' | ' ORDER BY d.display_name) AS displays
FROM ref.controller AS c
JOIN ref.controller_model AS m
  ON m.controller_model_id = c.controller_model_id
LEFT JOIN ref.controller_firmware_version AS fv
  ON fv.controller_firmware_version_id = c.installed_firmware_version_id
LEFT JOIN ref.controller_display AS cd
  ON cd.controller_id = c.controller_id
LEFT JOIN ref.display AS d
  ON d.display_id = cd.display_id
GROUP BY c.controller_id, c.year_deployed, m.model_code, fv.firmware_version
ORDER BY c.controller_id;
