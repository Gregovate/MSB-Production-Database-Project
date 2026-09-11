/* ============================================================================
MSB Setup Session — 2025 reconciliation ASSIGNED state
Issue: #122
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-08 V0.1.0

Purpose:
  Distinguish annual reconstruction items that still need Manager attention from
  items whose current reusable-task identity has been accepted. ASSIGNED is a
  reconciliation state, not an execution/completion state.

Manager workflow:
  - UNVERIFIED / NEEDS_CORRECTION / VERIFIED remain active review states.
  - ASSIGNED means the annual item is accepted as belonging to its current
    reusable task definition.
  - ASSIGNED items are preserved but leave the default active Verification
    Queue; Managers can deliberately filter to ASSIGNED to review history.
  - This migration does not yet implement merging/reassigning an annual item to
    a different reusable task. That remains a separate controlled workflow.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ops.setup_session_task') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Setup annual task and management authority are required';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

ALTER TABLE ops.setup_session_task
    DROP CONSTRAINT IF EXISTS ck_setup_session_task_verification;
ALTER TABLE ops.setup_session_task
    ADD CONSTRAINT ck_setup_session_task_verification CHECK (
        verification_state IN (
            'UNVERIFIED',
            'VERIFIED',
            'NEEDS_CORRECTION',
            'ASSIGNED'
        )
    );

CREATE OR REPLACE FUNCTION ops.update_setup_session_task_review(
    p_email text,
    p_setup_session_task_id bigint,
    p_verification_state text,
    p_actual_started_at timestamptz,
    p_actual_completed_at timestamptz,
    p_actual_crew_count integer,
    p_actual_duration_minutes integer,
    p_annual_notes text
)
RETURNS TABLE (
    setup_session_task_id bigint,
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
    v_verification text := upper(btrim(coalesce(p_verification_state, 'UNVERIFIED')));
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF v_verification NOT IN (
        'UNVERIFIED', 'VERIFIED', 'NEEDS_CORRECTION', 'ASSIGNED'
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Invalid Setup verification/reconciliation state';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    UPDATE ops.setup_session_task st
       SET verification_state = v_verification,
           actual_started_at = p_actual_started_at,
           actual_completed_at = p_actual_completed_at,
           actual_crew_count = p_actual_crew_count,
           actual_duration_minutes = p_actual_duration_minutes,
           annual_notes = nullif(btrim(p_annual_notes), '')
     WHERE st.setup_session_task_id = p_setup_session_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Setup annual task was not found';
    END IF;

    RETURN QUERY SELECT p_setup_session_task_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.update_setup_session_task_review(
    text, bigint, text, timestamptz, timestamptz, integer, integer, text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.update_setup_session_task_review(
    text, bigint, text, timestamptz, timestamptz, integer, integer, text
) TO fieldwiring_app;

COMMIT;
