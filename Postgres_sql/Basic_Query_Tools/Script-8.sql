-- D3: Confirm child rows exist for 2026 sessions (do we even have ops.display_test_session linked to those parents?).
SELECT
  COUNT(*) AS child_rows_joined_to_2026_parents
FROM ops.display_test_session dts
JOIN ops.test_session ts
  ON ts.test_session_id = dts.test_session_id
WHERE ts.season_year = 2026;