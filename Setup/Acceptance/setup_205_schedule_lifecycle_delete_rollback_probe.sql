-- #205 / 072: disposable-only functional audit probe.
-- Execute against the CURRENT-PRODUCTION DISPOSABLE CLONE after migration 072.
-- DO NOT run on Production. The entire transaction is rolled back.
\set ON_ERROR_STOP on
BEGIN;

DO $probe$
DECLARE
  v_assignment_id bigint;
  v_session_task_id bigint;
  v_session_id bigint;
  v_event_id bigint;
  v_actor integer;
BEGIN
  SELECT wdt.setup_work_day_task_id, wdt.setup_session_task_id, wd.setup_session_id
    INTO v_assignment_id, v_session_task_id, v_session_id
  FROM ops.setup_work_day_task wdt
  JOIN ops.setup_work_day wd ON wd.setup_work_day_id = wdt.setup_work_day_id
  WHERE wdt.actual_crew_count IS NULL
    AND wdt.started_at IS NULL
    AND wdt.completed_at IS NULL
    AND NOT EXISTS (
      SELECT 1 FROM ops.setup_task_progress p
      WHERE p.setup_work_day_task_id = wdt.setup_work_day_task_id
         OR (p.setup_work_day_task_id IS NULL
             AND p.setup_work_day_id = wdt.setup_work_day_id
             AND p.setup_session_task_id = wdt.setup_session_task_id
             AND p.shift_code = wdt.shift_code)
    )
  ORDER BY wd.work_date DESC, wdt.setup_work_day_task_id DESC
  LIMIT 1;

  IF v_assignment_id IS NULL THEN
    RAISE EXCEPTION 'No safe unworked assignment available for disposable delete probe';
  END IF;

  -- Savepoint semantics are supplied by the enclosing ROLLBACK, not by
  -- committing a transient mutation. Audit evidence is inspected in-transaction.
  DELETE FROM ops.setup_work_day_task
  WHERE setup_work_day_task_id = v_assignment_id;

  SELECT e.setup_schedule_event_id, e.created_by_person_id
    INTO v_event_id, v_actor
  FROM ops.setup_schedule_event e
  WHERE e.setup_work_day_task_id = v_assignment_id
    AND e.setup_session_task_id = v_session_task_id
    AND e.setup_session_id = v_session_id
    AND e.event_type = 'ASSIGNMENT_REMOVED'
  ORDER BY e.setup_schedule_event_id DESC
  LIMIT 1;

  IF v_event_id IS NULL THEN
    RAISE EXCEPTION 'DELETE did not append ASSIGNMENT_REMOVED audit event';
  END IF;
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'DELETE audit event missing actor person attribution';
  END IF;
  RAISE NOTICE 'PASS: disposable delete produced event %, actor person % (assignment %); transaction will roll back',
    v_event_id, v_actor, v_assignment_id;
END
$probe$;

ROLLBACK;
