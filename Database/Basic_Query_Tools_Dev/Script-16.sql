WITH roll AS (
  SELECT
    ts.test_session_id,
    ts.container_id,
    COUNT(*) AS child_total,
    COUNT(*) FILTER (WHERE dts.checked_at IS NOT NULL) AS child_checked,

    EXISTS (
      SELECT 1
      FROM ops.work_order wo
      JOIN ref.task_type tt
        ON tt.task_type_id = wo.task_type_id
      WHERE wo.date_completed IS NULL
        AND tt.task_type_key = 'REPAIR'
        AND wo.display_test_session_id IN (
          SELECT dts2.display_test_session_id
          FROM ops.display_test_session dts2
          WHERE dts2.test_session_id = ts.test_session_id
        )
    ) AS any_open_repair_work_order,

    MIN(dts.checked_at) AS first_checked_at,
    MAX(dts.checked_at) AS last_checked_at

  FROM ops.test_session ts
  JOIN ops.display_test_session dts
    ON dts.test_session_id = ts.test_session_id
  WHERE ts.season_year = 2026
  GROUP BY ts.test_session_id, ts.container_id
)
SELECT
  *,
  CASE
    WHEN child_checked = 0 THEN 'NOT_STARTED'
    WHEN child_checked < child_total THEN 'IN_PROGRESS'
    ELSE 'DONE'
  END AS would_status,
  CASE
    WHEN child_checked < child_total THEN 'YELLOW'
    WHEN any_open_repair_work_order THEN 'YELLOW'
    ELSE 'GREEN'
  END AS would_tag_state
FROM roll
ORDER BY container_id;