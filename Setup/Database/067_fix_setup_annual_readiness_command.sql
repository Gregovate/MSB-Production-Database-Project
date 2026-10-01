/* ============================================================================
MSB Setup Session — #205 launch stabilization annual readiness command
Issue: #205
Status: IMPLEMENTATION CANDIDATE — DISPOSABLE ACCEPTANCE REQUIRED
Revision: 2026-10-01 V0.1.0

Purpose:
  Keep annual readiness/hold edits inside the existing least-privilege command
  boundary. The protected app role must not require direct UPDATE privilege on
  ops.setup_session_task merely to acquire a row lock.

Contract:
  - Manager/Admin identity is resolved through ref.setup_management_actor(...).
  - The target annual row is locked inside this SECURITY DEFINER command.
  - Actual/progress evidence makes annual readiness historical and blocks edits.
  - Annual readiness note and READY / NOT_READY state are changed atomically.
  - A retained nonblank note may be explicitly marked READY.
  - No broad table DML is granted to fieldwiring_app.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ops.setup_session_task') IS NULL
       OR to_regclass('ops.setup_task_progress') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Current Setup annual planning/authorization foundation is required';
    END IF;
END
$preflight$;

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
    v_actual_started_at timestamptz;
    v_actual_completed_at timestamptz;
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
      INTO v_actual_started_at, v_actual_completed_at, v_has_progress
    FROM ops.setup_session_task st
    WHERE st.setup_session_task_id = p_setup_session_task_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Annual Setup task was not found';
    END IF;

    IF v_actual_started_at IS NOT NULL
       OR v_actual_completed_at IS NOT NULL
       OR coalesce(v_has_progress, false) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Actual work exists for this annual task; annual readiness is historical.';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    /* Migration 056 derives state whenever the note itself changes. Update the
       note first, then apply the Manager's explicit state as a second update.
       The second update retains the note and is therefore not re-derived. */
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

REVOKE ALL ON FUNCTION ops.set_setup_annual_hold(text,bigint,boolean,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.set_setup_annual_hold(text,bigint,boolean,text)
TO fieldwiring_app;

COMMIT;

SELECT
    '2026-10-01-setup-205-annual-hold-v0.1.0' AS applied_revision,
    current_user AS applied_by;
