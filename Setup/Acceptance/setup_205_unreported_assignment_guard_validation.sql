-- #205 / #122 | DISPOSABLE CLONE ONLY | Migration080 behavior validation.
-- Existing runner supplies the isolated clone. Every attempted mutation rolls back.
\set ON_ERROR_STOP on
BEGIN;
SET LOCAL statement_timeout = '30s';
SET LOCAL lock_timeout = '3s';
DO $validation$
DECLARE
    v record;
    v_assignments bigint;
    v_reports bigint;
    v_rejected boolean := false;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger
        WHERE tgrelid = 'ops.setup_work_day_task'::regclass
          AND tgname = 'reject_unresolved_setup_assignment_insert'
          AND tgenabled = 'O'
    ) THEN RAISE EXCEPTION 'Migration080 trigger missing or disabled'; END IF;

    SELECT count(*) INTO v_assignments FROM ops.setup_work_day_task;
    SELECT count(*) INTO v_reports FROM ops.setup_task_progress;
    -- Use a real unresolved occurrence and an existing other-day crew in this clone.
    SELECT prior.setup_session_task_id, dest.setup_work_day_id,
           c.setup_work_day_crew_id, c.crew_code
    INTO v
    FROM ops.setup_work_day_task prior
    JOIN ops.setup_session_task st USING (setup_session_task_id)
    JOIN ops.setup_work_day old_day ON old_day.setup_work_day_id = prior.setup_work_day_id
    JOIN ops.setup_work_day dest ON dest.setup_session_id = st.setup_session_id
    JOIN ops.setup_work_day_crew c ON c.setup_work_day_id = dest.setup_work_day_id
    WHERE st.execution_status NOT IN ('COMPLETE','DEFERRED')
      AND old_day.day_status <> 'CANCELLED' AND dest.day_status <> 'CANCELLED'
      AND c.crew_code IN ('A','B','C','D')
      AND dest.work_date >= (now() AT TIME ZONE 'America/Chicago')::date
      AND NOT EXISTS (SELECT 1 FROM ops.setup_work_day_task x
          WHERE x.setup_session_task_id = st.setup_session_task_id
            AND x.setup_work_day_id = dest.setup_work_day_id)
      AND NOT EXISTS (SELECT 1 FROM ops.setup_task_progress p
          WHERE p.setup_work_day_task_id = prior.setup_work_day_task_id
             OR (p.setup_work_day_task_id IS NULL
                 AND p.setup_session_task_id = prior.setup_session_task_id
                 AND p.setup_work_day_id = prior.setup_work_day_id
                 AND p.shift_code = prior.shift_code))
    ORDER BY prior.setup_work_day_task_id, dest.work_date
    LIMIT 1;
    IF NOT FOUND THEN RAISE EXCEPTION 'No unresolved clone fixture with another-day crew; review fixture, do not skip'; END IF;

    BEGIN
        PERFORM ops.create_setup_work_day_assignment('gliebig@sheboyganlights.org',
            v.setup_work_day_id, v.setup_session_task_id, 'MORNING',
            v.setup_work_day_crew_id, 100);
    EXCEPTION WHEN check_violation THEN
        IF SQLERRM NOT LIKE 'Assignment % needs resolution:%' THEN RAISE; END IF;
        v_rejected := true;
    END;
    IF NOT v_rejected THEN RAISE EXCEPTION 'New crew-ID assignment bypassed unresolved work guard'; END IF;

    -- The legacy creation signature must not bypass the common INSERT boundary.
    v_rejected := false;
    IF v.crew_code IN ('A','B','C','D') THEN
        BEGIN
            PERFORM ops.create_setup_work_day_assignment('gliebig@sheboyganlights.org',
                v.setup_work_day_id, v.setup_session_task_id, 'MORNING',
                v.crew_code::text, 100, NULL::integer);
        EXCEPTION WHEN check_violation THEN
            IF SQLERRM NOT LIKE 'Assignment % needs resolution:%' THEN RAISE; END IF;
            v_rejected := true;
        END;
        IF NOT v_rejected THEN RAISE EXCEPTION 'Legacy assignment bypassed unresolved work guard'; END IF;
    ELSE RAISE EXCEPTION 'Fixture crew must be A-D to test both signatures'; END IF;

    -- Reported partial work with no outstanding occurrence may continue.
    SELECT st.setup_session_task_id, dest.setup_work_day_id, c.setup_work_day_crew_id
    INTO v
    FROM ops.setup_session_task st
    JOIN ops.setup_work_day dest ON dest.setup_session_id = st.setup_session_id
    JOIN ops.setup_work_day_crew c ON c.setup_work_day_id = dest.setup_work_day_id
    WHERE st.execution_status = 'IN_PROGRESS'
      AND dest.day_status <> 'CANCELLED'
      AND dest.work_date >= (now() AT TIME ZONE 'America/Chicago')::date
      AND EXISTS (SELECT 1 FROM ops.setup_task_progress p
                  WHERE p.setup_session_task_id = st.setup_session_task_id)
      AND NOT EXISTS (SELECT 1 FROM ops.setup_work_day_task x
          WHERE x.setup_session_task_id = st.setup_session_task_id
            AND x.setup_work_day_id = dest.setup_work_day_id)
      AND NOT EXISTS (
          SELECT 1 FROM ops.setup_work_day_task x
          JOIN ops.setup_work_day d ON d.setup_work_day_id = x.setup_work_day_id
          WHERE x.setup_session_task_id = st.setup_session_task_id
            AND d.day_status <> 'CANCELLED'
            AND NOT EXISTS (SELECT 1 FROM ops.setup_task_progress p
                WHERE p.setup_work_day_task_id = x.setup_work_day_task_id
                   OR (p.setup_work_day_task_id IS NULL
                       AND p.setup_session_task_id = x.setup_session_task_id
                       AND p.setup_work_day_id = x.setup_work_day_id
                       AND p.shift_code = x.shift_code)))
    ORDER BY st.setup_session_task_id, dest.work_date LIMIT 1;
    IF NOT FOUND THEN RAISE EXCEPTION 'No reported partial clone fixture for positive continuation test'; END IF;
    BEGIN
        PERFORM ops.create_setup_work_day_assignment('gliebig@sheboyganlights.org',
            v.setup_work_day_id, v.setup_session_task_id, 'MORNING',
            v.setup_work_day_crew_id, 100);
        -- Deliberately undo the successful insert and all schedule-state effects.
        RAISE EXCEPTION USING ERRCODE = 'ZP001', MESSAGE = 'Rollback successful continuation test';
    EXCEPTION WHEN SQLSTATE 'ZP001' THEN NULL;
    END;

    IF (SELECT count(*) FROM ops.setup_work_day_task) <> v_assignments
       OR (SELECT count(*) FROM ops.setup_task_progress) <> v_reports THEN
        RAISE EXCEPTION 'Guard test unexpectedly changed assignment/report counts';
    END IF;
    RAISE NOTICE 'PASS migration080: crew-ID and legacy creation reject unresolved prior work; counts unchanged';
END;
$validation$;
ROLLBACK;
