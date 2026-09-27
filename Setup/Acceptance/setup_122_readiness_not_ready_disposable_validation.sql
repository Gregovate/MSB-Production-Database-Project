\set ON_ERROR_STOP on

BEGIN;

DO $validation$
DECLARE
    v_session_id bigint;
    v_session_task_id bigint;
    v_setup_task_id bigint;
    v_state text;
    v_note text;
BEGIN
    IF to_regprocedure('ops.enforce_setup_readiness_note_state()') IS NULL
       OR to_regprocedure('ops.sync_reusable_readiness_to_current_sessions()') IS NULL THEN
        RAISE EXCEPTION 'Readiness invariant functions are missing';
    END IF;

    SELECT st.setup_session_id,
           st.setup_session_task_id,
           st.setup_task_id
      INTO v_session_id,
           v_session_task_id,
           v_setup_task_id
    FROM ops.setup_session_task st
    JOIN ops.setup_session ss
      ON ss.setup_session_id = st.setup_session_id
    WHERE st.task_origin = 'REUSABLE'
      AND st.setup_task_id IS NOT NULL
      AND st.actual_started_at IS NULL
      AND st.actual_completed_at IS NULL
      AND NOT EXISTS (
          SELECT 1
          FROM ops.setup_task_progress p
          WHERE p.setup_session_task_id = st.setup_session_task_id
      )
    ORDER BY st.setup_session_task_id
    LIMIT 1;

    IF v_session_task_id IS NULL THEN
        RAISE EXCEPTION 'No untouched reusable annual task is available for readiness validation';
    END IF;

    /* Simulate a current planning Session. Transaction rolls back below. */
    UPDATE ops.setup_session
       SET session_status = 'PLANNING'
     WHERE setup_session_id = v_session_id;

    /* Catalog add -> annual NOT_READY. */
    UPDATE ref.setup_task
       SET readiness_note = '__B1A readiness acceptance condition__'
     WHERE setup_task_id = v_setup_task_id;

    SELECT st.annual_readiness_note, st.annual_readiness_state
      INTO v_note, v_state
    FROM ops.setup_session_task st
    WHERE st.setup_session_task_id = v_session_task_id;

    IF v_note <> '__B1A readiness acceptance condition__'
       OR v_state <> 'NOT_READY' THEN
        RAISE EXCEPTION 'Catalog readiness add did not synchronize annual NOT_READY: note=%, state=%',
            v_note, v_state;
    END IF;

    /* Catalog change -> reset annual NOT_READY again. */
    UPDATE ops.setup_session_task
       SET annual_readiness_state = 'READY'
     WHERE setup_session_task_id = v_session_task_id;

    UPDATE ref.setup_task
       SET readiness_note = '__B1A readiness acceptance changed__'
     WHERE setup_task_id = v_setup_task_id;

    SELECT st.annual_readiness_note, st.annual_readiness_state
      INTO v_note, v_state
    FROM ops.setup_session_task st
    WHERE st.setup_session_task_id = v_session_task_id;

    IF v_note <> '__B1A readiness acceptance changed__'
       OR v_state <> 'NOT_READY' THEN
        RAISE EXCEPTION 'Catalog readiness change did not reset annual NOT_READY: note=%, state=%',
            v_note, v_state;
    END IF;

    /* Catalog clear -> annual READY baseline. */
    UPDATE ref.setup_task
       SET readiness_note = NULL
     WHERE setup_task_id = v_setup_task_id;

    SELECT st.annual_readiness_note, st.annual_readiness_state
      INTO v_note, v_state
    FROM ops.setup_session_task st
    WHERE st.setup_session_task_id = v_session_task_id;

    IF v_note IS NOT NULL OR v_state <> 'READY' THEN
        RAISE EXCEPTION 'Catalog readiness clear did not restore annual READY baseline: note=%, state=%',
            v_note, v_state;
    END IF;

    /* Annual/season planning add/change/clear follows the same invariant. */
    UPDATE ops.setup_session_task
       SET annual_readiness_note = '__Annual readiness acceptance__'
     WHERE setup_session_task_id = v_session_task_id;

    SELECT annual_readiness_state INTO v_state
    FROM ops.setup_session_task
    WHERE setup_session_task_id = v_session_task_id;
    IF v_state <> 'NOT_READY' THEN
        RAISE EXCEPTION 'Annual readiness add did not set NOT_READY: %', v_state;
    END IF;

    UPDATE ops.setup_session_task
       SET annual_readiness_state = 'READY'
     WHERE setup_session_task_id = v_session_task_id;

    UPDATE ops.setup_session_task
       SET annual_readiness_note = '__Annual readiness acceptance changed__'
     WHERE setup_session_task_id = v_session_task_id;

    SELECT annual_readiness_state INTO v_state
    FROM ops.setup_session_task
    WHERE setup_session_task_id = v_session_task_id;
    IF v_state <> 'NOT_READY' THEN
        RAISE EXCEPTION 'Annual readiness change did not reset NOT_READY: %', v_state;
    END IF;

    UPDATE ops.setup_session_task
       SET annual_readiness_note = NULL
     WHERE setup_session_task_id = v_session_task_id;

    SELECT annual_readiness_state INTO v_state
    FROM ops.setup_session_task
    WHERE setup_session_task_id = v_session_task_id;
    IF v_state <> 'READY' THEN
        RAISE EXCEPTION 'Annual readiness clear did not restore READY baseline: %', v_state;
    END IF;
END
$validation$;

ROLLBACK;

SELECT 'SETUP_122_READINESS_NOT_READY_DISPOSABLE_VALIDATION_PASS' AS result;
