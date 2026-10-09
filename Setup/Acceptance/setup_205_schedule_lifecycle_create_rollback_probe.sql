-- #205 / 072: disposable-only INSERT audit and actor attribution proof.
-- Must run on current-production disposable clone after migration 072.
-- Entire transaction is rolled back. NEVER execute against Production.
\set ON_ERROR_STOP on
BEGIN;

DO $probe$
DECLARE
  v_source ops.setup_work_day_task%ROWTYPE;
  v_new_id bigint;
  v_event_id bigint;
  v_actor integer;
  v_session_id bigint;
BEGIN
  -- Clone an existing, unworked assignment onto a distinct task/day pair.
  -- Avoid duplicate scheduling constraints and any real progress evidence.
  SELECT wdt.* INTO v_source
  FROM ops.setup_work_day_task wdt
  WHERE wdt.actual_crew_count IS NULL
    AND wdt.started_at IS NULL
    AND wdt.completed_at IS NULL
    AND NOT EXISTS (
      SELECT 1 FROM ops.setup_task_progress p
      WHERE p.setup_work_day_task_id = wdt.setup_work_day_task_id
    )
  ORDER BY wdt.setup_work_day_task_id DESC
  LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No unworked source assignment for disposable creation probe';
  END IF;

  -- Keep this insert limited to known schedule columns; the candidate task
  -- must not already occupy this workday.
  SELECT wd.setup_session_id INTO v_session_id
  FROM ops.setup_work_day wd WHERE wd.setup_work_day_id = v_source.setup_work_day_id;

  -- Create a disposable assignment for a different unscheduled annual task.
  SELECT st.setup_session_task_id INTO v_source.setup_session_task_id
  FROM ops.setup_session_task st
  WHERE st.setup_session_id = v_session_id
    AND NOT EXISTS (
      SELECT 1 FROM ops.setup_work_day_task x
      WHERE x.setup_work_day_id = v_source.setup_work_day_id
        AND x.setup_session_task_id = st.setup_session_task_id
    )
  ORDER BY st.setup_session_task_id DESC LIMIT 1;
  IF v_source.setup_session_task_id IS NULL THEN
    RAISE EXCEPTION 'No candidate annual task for disposable creation probe';
  END IF;

  INSERT INTO ops.setup_work_day_task (
    setup_work_day_id, setup_session_task_id, shift_code, crew_lane,
    setup_work_day_crew_id, sort_order
  ) VALUES (
    v_source.setup_work_day_id, v_source.setup_session_task_id,
    v_source.shift_code, v_source.crew_lane,
    v_source.setup_work_day_crew_id, 99999
  )
  RETURNING setup_work_day_task_id INTO v_new_id;

  SELECT e.setup_schedule_event_id, e.created_by_person_id
    INTO v_event_id, v_actor
  FROM ops.setup_schedule_event e
  WHERE e.setup_work_day_task_id = v_new_id
    AND e.event_type = 'ASSIGNMENT_CREATED'
  ORDER BY e.setup_schedule_event_id DESC LIMIT 1;

  IF v_event_id IS NULL OR v_actor IS NULL THEN
    RAISE EXCEPTION 'INSERT lifecycle audit missing event or actor (event %, actor %)', v_event_id, v_actor;
  END IF;
  RAISE NOTICE 'PASS: disposable creation event %, actor %, assignment %; ROLLBACK follows',
    v_event_id, v_actor, v_new_id;
END
$probe$;
ROLLBACK;
