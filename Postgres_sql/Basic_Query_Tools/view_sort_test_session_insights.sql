-- 1) Show exactly which display rows are attached to test_session 521
--    and compare them to the current ref.display container assignment.
SELECT
    dts.display_test_session_id,
    dts.test_session_id,
    dts.display_id,
    d.display_name,
    d.container_id AS ref_display_container_id,
    c.description  AS ref_container_description,
    ts.container_id AS test_session_container_id,
    ts.home_location_code,
    ts.created_at  AS test_session_created_at,
    d.updated_at   AS ref_display_updated_at
FROM ops.display_test_session dts
JOIN ref.display d
  ON d.display_id = dts.display_id
LEFT JOIN ref.container c
  ON c.container_id = d.container_id
JOIN ops.test_session ts
  ON ts.test_session_id = dts.test_session_id
WHERE dts.test_session_id = 521
ORDER BY d.display_name;