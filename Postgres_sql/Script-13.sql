SELECT to_regclass('ops._expected_display_test_session_2026') AS expected_table;
-- ROLLBACK;SELECT COUNT(*) AS expected_child_lines
FROM ops._expected_display_test_session_2026;SELECT COUNT(*) AS missing_in_ops
FROM ops._expected_display_test_session_2026 e
LEFT JOIN ops.display_test_session dts
  ON dts.test_session_id = e.test_session_id
 AND dts.display_id      = e.display_id
WHERE dts.display_test_session_id IS NULL;