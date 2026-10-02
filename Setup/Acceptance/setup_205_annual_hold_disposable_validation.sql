\set ON_ERROR_STOP on

BEGIN;

DO $validation$
DECLARE
    v_email text;
    v_person_id integer;
    v_session_task_id bigint;
    v_state text;
    v_note text;
    v_updated_by_person_id integer;
    v_operator_display_name text;
BEGIN
    IF to_regprocedure('ops.set_setup_annual_hold(text,bigint,boolean,text)') IS NULL THEN
        RAISE EXCEPTION 'Governed annual hold command is missing';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ops.set_setup_annual_hold(text,bigint,boolean,text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute governed annual hold command';
    END IF;

    IF has_table_privilege('fieldwiring_app','ops.setup_session_task','UPDATE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad UPDATE on ops.setup_session_task';
    END IF;

    SELECT u.email, p.person_id
      INTO v_email, v_person_id
    FROM public.directus_users u
    JOIN ref.person p
      ON p.directus_user_id = u.id
    JOIN LATERAL ref.setup_browser_capabilities(u.email) caps
      ON true
    WHERE u.email IS NOT NULL
      AND caps.can_manage_setup
    ORDER BY p.person_id
    LIMIT 1;

    IF v_email IS NULL OR v_person_id IS NULL THEN
        RAISE EXCEPTION 'No governed Setup Manager actor is available for annual hold validation';
    END IF;

    SELECT st.setup_session_task_id
      INTO v_session_task_id
    FROM ops.setup_session_task st
    JOIN ops.setup_session ss
      ON ss.setup_session_id = st.setup_session_id
    WHERE ss.session_status IN ('PLANNING','ACTIVE')
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
        RAISE EXCEPTION 'No untouched annual task is available for annual hold validation';
    END IF;

    SELECT annual_readiness_state, annual_readiness_note, operator_display_name
      INTO v_state, v_note, v_operator_display_name
    FROM ops.set_setup_annual_hold(
        v_email,
        v_session_task_id,
        false,
        '__#205 annual hold validation__'
    );

    IF v_state <> 'NOT_READY' OR v_note <> '__#205 annual hold validation__' THEN
        RAISE EXCEPTION 'Annual hold NOT_READY mutation failed: state %, note %', v_state, v_note;
    END IF;

    SELECT st.annual_readiness_state,
           st.annual_readiness_note,
           st.updated_by_person_id
      INTO v_state, v_note, v_updated_by_person_id
    FROM ops.setup_session_task st
    WHERE st.setup_session_task_id = v_session_task_id;

    IF v_state <> 'NOT_READY'
       OR v_note <> '__#205 annual hold validation__'
       OR v_updated_by_person_id <> v_person_id THEN
        RAISE EXCEPTION
            'Annual hold persisted state/audit mismatch: state %, note %, person % expected %',
            v_state, v_note, v_updated_by_person_id, v_person_id;
    END IF;

    /* A Manager may explicitly mark the condition READY while retaining the
       annual note. The existing note-invariant trigger must not erase that
       explicit state once the note itself is unchanged. */
    SELECT annual_readiness_state, annual_readiness_note, operator_display_name
      INTO v_state, v_note, v_operator_display_name
    FROM ops.set_setup_annual_hold(
        v_email,
        v_session_task_id,
        true,
        '__#205 annual hold validation__'
    );

    IF v_state <> 'READY' OR v_note <> '__#205 annual hold validation__' THEN
        RAISE EXCEPTION 'Annual hold READY-with-note mutation failed: state %, note %', v_state, v_note;
    END IF;
END
$validation$;

ROLLBACK;

SELECT 'SETUP_205_ANNUAL_HOLD_DISPOSABLE_VALIDATION_PASS' AS result;
