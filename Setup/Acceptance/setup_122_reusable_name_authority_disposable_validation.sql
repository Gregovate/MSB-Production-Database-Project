/* ============================================================================
Setup #122 — reusable task name authority disposable validation
Current-Production clone only.

Proves:
  1. the newest non-historical annual Setup Session matches ref.setup_task names;
  2. a governed reusable rename synchronizes that current annual occurrence;
  3. older annual Sessions and HISTORICAL_VERIFICATION are not rewritten;
  4. the transaction rolls back the clone-only rename fixture.
============================================================================ */

\set ON_ERROR_STOP on

BEGIN;

DO $validation$
DECLARE
    v_manager_email text;
    v_task_id bigint;
    v_original_name text;
    v_test_name text;
    v_stage_id integer;
    v_action text;
    v_display_order integer;
    v_active boolean;
    v_crew_min integer;
    v_crew_max integer;
    v_duration integer;
    v_completion text;
    v_readiness text;
    v_weather text;
    v_notes text;
    v_historical_before text;
    v_historical_after text;
BEGIN
    IF EXISTS (
        SELECT 1
        FROM ops.setup_session_task st
        JOIN ops.setup_session ss
          ON ss.setup_session_id = st.setup_session_id
        JOIN ref.setup_task t
          ON t.setup_task_id = st.setup_task_id
        WHERE st.task_origin = 'REUSABLE'
          AND ss.session_status <> 'HISTORICAL_VERIFICATION'
          AND NOT EXISTS (
              SELECT 1
              FROM ops.setup_session newer
              WHERE newer.session_status <> 'HISTORICAL_VERIFICATION'
                AND newer.season_year > ss.season_year
          )
          AND st.annual_task_name IS DISTINCT FROM t.task_name
    ) THEN
        RAISE EXCEPTION 'Current annual reusable task-name drift exists before rename fixture';
    END IF;

    SELECT lower(u.email)
      INTO v_manager_email
    FROM public.directus_users u
    JOIN ref.person p
      ON p.directus_user_id = u.id
    JOIN LATERAL ref.setup_browser_capabilities(lower(u.email)) c ON true
    WHERE u.status = 'active'
      AND c.can_manage_setup
    ORDER BY lower(u.email)
    LIMIT 1;

    IF v_manager_email IS NULL THEN
        RAISE EXCEPTION 'No active Setup Manager with ref.person mapping was found';
    END IF;

    SELECT
        t.setup_task_id,
        t.task_name,
        t.stage_id,
        t.task_action_type,
        t.display_order,
        t.active_flag,
        t.normal_crew_min,
        t.normal_crew_max,
        t.expected_duration_minutes,
        t.completion_point,
        t.readiness_note,
        t.weather_note,
        t.reusable_notes
      INTO
        v_task_id,
        v_original_name,
        v_stage_id,
        v_action,
        v_display_order,
        v_active,
        v_crew_min,
        v_crew_max,
        v_duration,
        v_completion,
        v_readiness,
        v_weather,
        v_notes
    FROM ref.setup_task t
    WHERE EXISTS (
        SELECT 1
        FROM ops.setup_session_task st
        JOIN ops.setup_session ss
          ON ss.setup_session_id = st.setup_session_id
        WHERE st.setup_task_id = t.setup_task_id
          AND st.task_origin = 'REUSABLE'
          AND ss.session_status <> 'HISTORICAL_VERIFICATION'
          AND NOT EXISTS (
              SELECT 1
              FROM ops.setup_session newer
              WHERE newer.session_status <> 'HISTORICAL_VERIFICATION'
                AND newer.season_year > ss.season_year
          )
    )
    ORDER BY t.setup_task_id
    LIMIT 1;

    IF v_task_id IS NULL THEN
        RAISE EXCEPTION 'No reusable task linked to the current annual Setup Session was found';
    END IF;

    SELECT st.annual_task_name
      INTO v_historical_before
    FROM ops.setup_session_task st
    JOIN ops.setup_session ss
      ON ss.setup_session_id = st.setup_session_id
    WHERE st.setup_task_id = v_task_id
      AND st.task_origin = 'REUSABLE'
      AND ss.session_status = 'HISTORICAL_VERIFICATION'
    ORDER BY ss.season_year DESC, st.setup_session_task_id DESC
    LIMIT 1;

    v_test_name := v_original_name || ' [DISPOSABLE NAME SYNC]';

    PERFORM *
    FROM ref.update_setup_task(
        v_manager_email,
        v_task_id,
        v_test_name,
        v_stage_id,
        v_action,
        v_display_order,
        v_active,
        v_crew_min,
        v_crew_max,
        v_duration,
        v_completion,
        v_readiness,
        v_weather,
        v_notes
    );

    IF EXISTS (
        SELECT 1
        FROM ops.setup_session_task st
        JOIN ops.setup_session ss
          ON ss.setup_session_id = st.setup_session_id
        WHERE st.setup_task_id = v_task_id
          AND st.task_origin = 'REUSABLE'
          AND ss.session_status <> 'HISTORICAL_VERIFICATION'
          AND NOT EXISTS (
              SELECT 1
              FROM ops.setup_session newer
              WHERE newer.session_status <> 'HISTORICAL_VERIFICATION'
                AND newer.season_year > ss.season_year
          )
          AND st.annual_task_name IS DISTINCT FROM v_test_name
    ) THEN
        RAISE EXCEPTION 'Governed reusable rename did not synchronize the current annual occurrence';
    END IF;

    IF v_historical_before IS NOT NULL THEN
        SELECT st.annual_task_name
          INTO v_historical_after
        FROM ops.setup_session_task st
        JOIN ops.setup_session ss
          ON ss.setup_session_id = st.setup_session_id
        WHERE st.setup_task_id = v_task_id
          AND st.task_origin = 'REUSABLE'
          AND ss.session_status = 'HISTORICAL_VERIFICATION'
        ORDER BY ss.season_year DESC, st.setup_session_task_id DESC
        LIMIT 1;

        IF v_historical_after IS DISTINCT FROM v_historical_before THEN
            RAISE EXCEPTION 'Historical Verification annual name was rewritten by current-season rename';
        END IF;
    END IF;

    RAISE NOTICE
        'SETUP_122_REUSABLE_NAME_AUTHORITY_DISPOSABLE_VALIDATION_PASS task=% original=% test=%',
        v_task_id, v_original_name, v_test_name;
END
$validation$;

ROLLBACK;

SELECT 'SETUP_122_REUSABLE_NAME_AUTHORITY_DISPOSABLE_VALIDATION_PASS' AS validation_status;
