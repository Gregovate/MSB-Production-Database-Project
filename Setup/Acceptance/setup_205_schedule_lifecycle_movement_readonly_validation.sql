-- #205 / 072: preserve existing assignment-move history.
-- Read-only against disposable clone after migration 072.
\set ON_ERROR_STOP on
DO $verify$
DECLARE
  v_count bigint;
BEGIN
  SELECT count(*) INTO v_count
  FROM ops.setup_schedule_event
  WHERE event_type = 'ASSIGNMENT_MOVED';
  IF v_count < 1 THEN
    RAISE EXCEPTION 'Existing ASSIGNMENT_MOVED evidence missing; stop migration acceptance';
  END IF;
  IF EXISTS (
    SELECT 1 FROM ops.setup_schedule_event
    WHERE event_type = 'ASSIGNMENT_MOVED'
      AND (setup_session_task_id IS NULL OR setup_work_day_task_id IS NULL)
  ) THEN
    RAISE EXCEPTION 'Existing movement event lacks assignment/task identity';
  END IF;
  RAISE NOTICE 'PASS: % existing assignment movement events remain queryable', v_count;
END
$verify$;
SELECT setup_session_task_id, count(*) AS movement_count
FROM ops.setup_schedule_event
WHERE event_type = 'ASSIGNMENT_MOVED'
GROUP BY setup_session_task_id
ORDER BY movement_count DESC, setup_session_task_id
LIMIT 10;
