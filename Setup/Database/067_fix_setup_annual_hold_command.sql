/* ============================================================================
MSB Setup Session — governed annual readiness hold command
Issue: #205 / commanding #122
Revision: 2026-10-01

Purpose:
  Repair the Annual Readiness write path without granting broad UPDATE on
  ops.setup_session_task.

  The protected application role may execute this SECURITY DEFINER command.
  The command owns the row lock, actual/progress guard, annual-only readiness
  note/state mutation, and audit actor attribution.

  Reusable Catalog readiness knowledge is not changed here.
============================================================================ */

BEGIN;

CREATE OR REPLACE FUNCTION ops.set_setup_annual_hold(
    p_email text,
    p_setup_session_task_id bigint,
    p_ready boolean,
    p_readiness_note text
)
RETURNS TABLE (
    setup_session_task_id bigint,
    annual_readiness_state text,
    annual_readiness_note text,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_state text := CASE
        WHEN coalesce(p_ready, false) THEN 'READY'
        ELSE 'NOT_READY'
    END;
    v_note text := nullif(btrim(p_readiness_note), '');
    v_started timestamptz;
    v_completed timestamptz;
    v_has_progress boolean;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) a;

    SELECT
        st.actual_started_at,
        st.actual_completed_at,
        EXISTS (
            SELECT 1
            FROM ops.setup_task_progress p
            WHERE p.setup_session_task_id = st.setup_session_task_id
        )
      INTO v_started, v_completed, v_has_progress
    FROM ops.setup_session_task st
    WHERE st.setup_session_task_id = p_setup_session_task_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Annual Setup task was not found';
    END IF;

    IF v_started IS NOT NULL
       OR v_completed IS NOT NULL
       OR coalesce(v_has_progress, false) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'Actual work exists for this annual task; annual readiness is historical.';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    /* The existing readiness-note invariant intentionally derives a baseline
       state whenever the note itself changes. Update the note first, then set
       the Manager's explicit READY / NOT_READY state in a second UPDATE where
       the note is unchanged. This preserves the accepted ability to retain a
       readiness note while explicitly marking the condition READY. */
    UPDATE ops.setup_session_task st
       SET annual_readiness_note = v_note
     WHERE st.setup_session_task_id = p_setup_session_task_id;

    UPDATE ops.setup_session_task st
       SET annual_readiness_state = v_state
     WHERE st.setup_session_task_id = p_setup_session_task_id;

    RETURN QUERY
    SELECT
        p_setup_session_task_id,
        v_state,
        v_note,
        v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.set_setup_annual_hold(
    text,bigint,boolean,text
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ops.set_setup_annual_hold(
    text,bigint,boolean,text
) TO fieldwiring_app;

COMMIT;
