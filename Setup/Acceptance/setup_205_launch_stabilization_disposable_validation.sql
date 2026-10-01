\set ON_ERROR_STOP on

BEGIN;

DO $preflight$
BEGIN
    IF to_regprocedure('ops.set_setup_annual_hold(text,bigint,boolean,text)') IS NULL THEN
        RAISE EXCEPTION 'ops.set_setup_annual_hold(...) is missing';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ops.set_setup_annual_hold(text,bigint,boolean,text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute governed annual readiness command';
    END IF;

    IF NOT has_table_privilege(
        'fieldwiring_app',
        'ops.setup_session_task',
        'SELECT'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app lost required annual Setup read access';
    END IF;

    IF has_table_privilege(
        'fieldwiring_app',
        'ops.setup_session_task',
        'UPDATE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad setup_session_task UPDATE';
    END IF;
END
$preflight$;

SELECT lower(u.email) AS admin_email
FROM public.directus_users u
JOIN ref.person p
  ON p.directus_user_id = u.id
JOIN LATERAL ref.setup_browser_capabilities(u.email) c ON true
WHERE u.status = 'active'
  AND c.can_admin_setup
ORDER BY u.email
LIMIT 1
\gset

SELECT st.setup_session_task_id AS target_id
FROM ops.setup_session_task st
JOIN ops.setup_session ss
  ON ss.setup_session_id = st.setup_session_id
WHERE ss.season_year = 2026
  AND st.included_flag
  AND st.actual_started_at IS NULL
  AND st.actual_completed_at IS NULL
  AND NOT EXISTS (
      SELECT 1
      FROM ops.setup_task_progress p
      WHERE p.setup_session_task_id = st.setup_session_task_id
  )
ORDER BY st.setup_session_task_id
LIMIT 1
\gset

SET LOCAL ROLE fieldwiring_app;

SELECT *
FROM ops.set_setup_annual_hold(
    :'admin_email',
    :'target_id'::bigint,
    false,
    '[DISPOSABLE #205] readiness condition'
);

DO $verify_not_ready$
DECLARE
    v_id bigint := :'target_id'::bigint;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_session_task st
        WHERE st.setup_session_task_id = v_id
          AND st.annual_readiness_state = 'NOT_READY'
          AND st.annual_readiness_note = '[DISPOSABLE #205] readiness condition'
    ) THEN
        RAISE EXCEPTION 'Governed annual hold did not persist NOT_READY + note';
    END IF;
END
$verify_not_ready$;

SELECT *
FROM ops.set_setup_annual_hold(
    :'admin_email',
    :'target_id'::bigint,
    true,
    '[DISPOSABLE #205] readiness condition'
);

DO $verify_ready$
DECLARE
    v_id bigint := :'target_id'::bigint;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_session_task st
        WHERE st.setup_session_task_id = v_id
          AND st.annual_readiness_state = 'READY'
          AND st.annual_readiness_note = '[DISPOSABLE #205] readiness condition'
    ) THEN
        RAISE EXCEPTION 'Explicit READY did not retain annual readiness note';
    END IF;
END
$verify_ready$;

ROLLBACK;

SELECT
    'SETUP_205_LAUNCH_STABILIZATION_DISPOSABLE_VALIDATION_PASS' AS validation_status,
    has_function_privilege(
        'fieldwiring_app',
        'ops.set_setup_annual_hold(text,bigint,boolean,text)',
        'EXECUTE'
    ) AS governed_hold_execute,
    NOT has_table_privilege(
        'fieldwiring_app',
        'ops.setup_session_task',
        'UPDATE'
    ) AS no_broad_annual_update;
