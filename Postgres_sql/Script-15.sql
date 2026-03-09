-- DIFF: which expected rows are missing from ops.display_test_session
WITH expected AS (
  SELECT
    ts.test_session_id,
    ts.container_id,
    d.display_id
  FROM ops.test_session ts
  JOIN ref.display d
    ON d.container_id = ts.container_id
  WHERE ts.season_year = 2026
),
missing AS (
  SELECT e.*
  FROM expected e
  LEFT JOIN ops.display_test_session dts
    ON dts.test_session_id = e.test_session_id
   AND dts.display_id      = e.display_id
  WHERE dts.display_test_session_id IS NULL
)
SELECT
  COUNT(*) AS missing_in_ops
FROM missing;