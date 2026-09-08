/* ============================================================================
MSB Setup Session — reusable task creation command correction
Issue: #122
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-07 V0.3.2

Purpose:
  Correct ref.create_setup_task() after browser acceptance exposed PostgreSQL
  ambiguity in the column-list ON CONFLICT target. The function RETURNS a
  column named setup_task_id, so a bare two-column conflict target can be parsed
  as ambiguous inside PL/pgSQL.

Correction:
  Target the already-governed uq_setup_session_task constraint by name.
  No schema shape or authorization expansion is introduced.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regprocedure(
        'ref.create_setup_task(text,text,integer,text,integer,integer,integer,integer,text,text,text,text)'
    ) IS NULL THEN
        RAISE EXCEPTION 'Existing ref.create_setup_task command is required before migration 013';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE n.nspname = 'ops'
          AND t.relname = 'setup_session_task'
          AND c.conname = 'uq_setup_session_task'
    ) THEN
        RAISE EXCEPTION 'Required ops.setup_session_task constraint uq_setup_session_task is missing';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ref.create_setup_task(
    p_email text,
    p_task_name text,
    p_stage_id integer,
    p_task_action_type text,
    p_display_order integer,
    p_normal_crew_min integer,
    p_normal_crew_max integer,
    p_expected_duration_minutes integer,
    p_completion_point text,
    p_readiness_note text,
    p_weather_note text,
    p_reusable_notes text
)
RETURNS TABLE (
    setup_task_id bigint,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref, ops
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_task_id bigint;
    v_name text := nullif(btrim(p_task_name), '');
    v_action text := upper(btrim(coalesce(p_task_action_type, 'WORK')));
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF v_name IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Setup task name is required';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    INSERT INTO ref.setup_task(
        task_name,
        stage_id,
        task_action_type,
        display_order,
        normal_crew_min,
        normal_crew_max,
        expected_duration_minutes,
        completion_point,
        readiness_note,
        weather_note,
        reusable_notes
    ) VALUES (
        v_name,
        p_stage_id,
        v_action,
        coalesce(p_display_order, 100),
        p_normal_crew_min,
        p_normal_crew_max,
        p_expected_duration_minutes,
        nullif(btrim(p_completion_point), ''),
        nullif(btrim(p_readiness_note), ''),
        nullif(btrim(p_weather_note), ''),
        nullif(btrim(p_reusable_notes), '')
    )
    RETURNING ref.setup_task.setup_task_id INTO v_task_id;

    /* New reusable work is automatically presented in any still-open Setup
       Session. Naming the unique constraint avoids PL/pgSQL output-column
       ambiguity while retaining the original idempotent behavior. */
    INSERT INTO ops.setup_session_task(setup_session_id, setup_task_id)
    SELECT s.setup_session_id, v_task_id
    FROM ops.setup_session s
    WHERE s.session_status <> 'COMPLETE'
    ON CONFLICT ON CONSTRAINT uq_setup_session_task DO NOTHING;

    RETURN QUERY SELECT v_task_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.create_setup_task(
    text, text, integer, text, integer, integer, integer, integer,
    text, text, text, text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.create_setup_task(
    text, text, integer, text, integer, integer, integer, integer,
    text, text, text, text
) TO fieldwiring_app;

COMMIT;

SELECT
    '2026-09-07-fix-setup-create-task-command-v0.3.2' AS applied_revision,
    current_user AS applied_by;
