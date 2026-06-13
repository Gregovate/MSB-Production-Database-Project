-- PREVIEW: compute 2026 parent status + tag_state from child checked_at and open WOs
WITH roll AS (
  SELECT
    ts.test_session_id,
    ts.container_id,
    COUNT(*) AS child_total,
    COUNT(*) FILTER (WHERE dts.checked_at IS NOT NULL) AS child_checked,
    BOOL_OR(wo.work_order_id IS NOT NULL) AS any_open_work_order,
    CASE
      WHEN COUNT(*) FILTER (WHERE dts.checked_at IS NOT NULL) = 0 THEN 'NOT_STARTED'
      WHEN COUNT(*) FILTER (WHERE dts.checked_at IS NOT NULL) < COUNT(*) THEN 'IN_PROGRESS'
      ELSE 'DONE'
    END AS computed_status,
    CASE
      WHEN BOOL_OR(wo.work_order_id IS NOT NULL) THEN 'YELLOW'
      WHEN COUNT(*) FILTER (WHERE dts.checked_at IS NOT NULL) = COUNT(*) THEN 'GREEN'
      ELSE 'YELLOW'
    END AS computed_tag_state
  FROM ops.test_session ts
  LEFT JOIN ops.display_test_session dts
    ON dts.test_session_id = ts.test_session_id
  LEFT JOIN ops.work_order wo
    ON wo.display_test_session_id = dts.display_test_session_id
   AND wo.date_completed IS NULL
  WHERE ts.season_year = 2026
  GROUP BY ts.test_session_id, ts.container_id
)
SELECT
  computed_status,
  computed_tag_state,
  COUNT(*) AS sessions
FROM roll
GROUP BY computed_status, computed_tag_state
ORDER BY computed_status, computed_tag_state;