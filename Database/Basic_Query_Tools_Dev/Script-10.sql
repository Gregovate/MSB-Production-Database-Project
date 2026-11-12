SELECT
  ts.season_year,
  COUNT(*) AS child_rows,
  COUNT(*) FILTER (WHERE dts.stage_id IS NULL) AS stage_nulls
FROM ops.display_test_session dts
JOIN ops.test_session ts
  ON ts.test_session_id = dts.test_session_id
GROUP BY ts.season_year
ORDER BY ts.season_year;