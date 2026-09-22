/* ============================================================================
MSB Setup Session — #145 stale Display ownership cleanup
Issue: #145
Revision: 2026-09-22 V0.1.0

Purpose:
  Add one narrow Manager command for removing an exact obsolete
  ref.setup_task_display row after the application has re-resolved the current
  LOR source set and classified that Display/owner pair as stale.

Safety:
  - this command does not decide whether a row is stale;
  - application resolver validation must happen immediately before invocation;
  - expected-current-owner provides a concurrency guard;
  - no LOR membership, Display status, Container assignment, task material
    flag, annual Setup state, or 2026 Setup Session state is changed.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task_display') IS NULL
       OR to_regclass('ref.setup_task') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Accepted Setup Display ownership foundation is required before migration 052';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ref.clear_stale_setup_task_display_owner(
    p_email text,
    p_display_id bigint,
    p_expected_setup_task_id bigint
)
RETURNS TABLE (
    display_id bigint,
    previous_setup_task_id bigint,
    removed boolean,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_current_setup_task_id bigint;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF p_display_id IS NULL OR p_expected_setup_task_id IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Display and expected current Setup-task owner are required';
    END IF;

    SELECT td.setup_task_id
      INTO v_current_setup_task_id
    FROM ref.setup_task_display AS td
    WHERE td.display_id = p_display_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Display ownership row no longer exists; refresh ownership';
    END IF;

    IF v_current_setup_task_id IS DISTINCT FROM p_expected_setup_task_id THEN
        RAISE EXCEPTION USING
            ERRCODE = '23505',
            MESSAGE = 'Display owner changed since it was loaded; refresh ownership before removing the stale row';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    DELETE FROM ref.setup_task_display AS td
    WHERE td.display_id = p_display_id
      AND td.setup_task_id = p_expected_setup_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = '23505',
            MESSAGE = 'Display ownership changed during stale-row cleanup; refresh ownership';
    END IF;

    RETURN QUERY
    SELECT
        p_display_id,
        v_current_setup_task_id,
        true,
        v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.clear_stale_setup_task_display_owner(text,bigint,bigint)
    FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.clear_stale_setup_task_display_owner(text,bigint,bigint)
    TO fieldwiring_app;

COMMIT;

SELECT
    '2026-09-22-setup-stale-display-ownership-cleanup-v0.1.0' AS applied_revision,
    current_user AS applied_by,
    has_function_privilege(
        'fieldwiring_app',
        'ref.clear_stale_setup_task_display_owner(text,bigint,bigint)',
        'EXECUTE'
    ) AS app_can_clear_stale_display_owner;
