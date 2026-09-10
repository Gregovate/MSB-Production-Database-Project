/* ============================================================================
MSB Setup Session — reusable Display Setup/material metadata
Issue: #122
Related: #141
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-10 V0.3.5

Purpose:
  Record two separate reusable-task facts:

  1. is_display_setup_step
     Visual/operational classification that this task is physical Display Setup
     work. Multiple tasks in one Stage/Scene may legitimately be true.

  2. requires_display_material
     Enables the current whole Stage/Scene Display-material resolver for this
     task. This is not task-specific component allocation or staged pick timing.

Boundary:
  - Both values default FALSE. No task-name inference or automatic backfill.
  - Neither value creates task-specific Display membership. LOR remains the
    authority for current Stage/Scene Display membership.
  - Task-specific component/KIT subdivision and staged pick timing remain
    intentionally deferred to Issue #141.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task') IS NULL THEN
        RAISE EXCEPTION 'ref.setup_task is required before migration 025';
    END IF;

    IF to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'ref.setup_management_actor(text,boolean) is required before migration 025';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

ALTER TABLE ref.setup_task
    ADD COLUMN IF NOT EXISTS is_display_setup_step boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS requires_display_material boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN ref.setup_task.is_display_setup_step IS
    'Reusable classification for a physical Display Setup work step. Drives visual identification; does not by itself release or assign material.';

COMMENT ON COLUMN ref.setup_task.requires_display_material IS
    'Enables whole Stage/Scene Display material context from current LOR membership. Does not define task-specific component/KIT allocation or staged pick timing; see Issue #141.';

CREATE OR REPLACE FUNCTION ref.set_setup_task_display_setup_step(
    p_email text,
    p_setup_task_id bigint,
    p_is_display_setup_step boolean
)
RETURNS TABLE (
    setup_task_id bigint,
    is_display_setup_step boolean,
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
    v_is_display_setup_step boolean := coalesce(p_is_display_setup_step, false);
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    UPDATE ref.setup_task AS t
       SET is_display_setup_step = v_is_display_setup_step
     WHERE t.setup_task_id = p_setup_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Setup task was not found';
    END IF;

    RETURN QUERY
    SELECT p_setup_task_id, v_is_display_setup_step, v_display_name;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.set_setup_task_display_material_requirement(
    p_email text,
    p_setup_task_id bigint,
    p_requires_display_material boolean
)
RETURNS TABLE (
    setup_task_id bigint,
    requires_display_material boolean,
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
    v_required boolean := coalesce(p_requires_display_material, false);
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    UPDATE ref.setup_task AS t
       SET requires_display_material = v_required
     WHERE t.setup_task_id = p_setup_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Setup task was not found';
    END IF;

    RETURN QUERY
    SELECT p_setup_task_id, v_required, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.set_setup_task_display_setup_step(
    text, bigint, boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_display_setup_step(
    text, bigint, boolean
) TO fieldwiring_app;

REVOKE ALL ON FUNCTION ref.set_setup_task_display_material_requirement(
    text, bigint, boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_display_material_requirement(
    text, bigint, boolean
) TO fieldwiring_app;

COMMIT;

SELECT
    '2026-09-10-add-setup-display-material-metadata-v0.3.5' AS applied_revision,
    current_user AS applied_by;
