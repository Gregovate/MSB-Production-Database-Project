/* ============================================================================
MSB Setup Session — automatic Display/container material applicability
Issue: #122
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-10 V0.1.1

Purpose:
  Record the one reusable-task fact needed by automatic LOR material resolution:
  whether the Setup task requires Display/container material at all.

Authority boundaries:
  - LOR/LOR2DB remains authoritative for current Display grouping/membership.
  - ref.display.container_id remains authoritative for the current home Container.
  - This migration does not create a task-owned LOR material-source selector.
  - This migration does not backfill guesses from task names, Stage, Scene, or type.
  - Existing Setup task Stage/Scene work scope is unchanged.
  - Existing task audit/update state is not touched merely to establish false.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task') IS NULL
       OR to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Setup reusable task and management authority are required before migration 025';
    END IF;

    IF to_regclass('ref.lor_scene') IS NULL
       OR to_regclass('ref.lor_scene_display') IS NULL
       OR to_regclass('ref.display') IS NULL
       OR to_regclass('ref.container') IS NULL THEN
        RAISE EXCEPTION 'Current LOR Scene/Display and Display/Container authority are required before migration 025';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

/*
PostgreSQL applies this constant default to existing rows as part of the schema
change. Do not run a mass UPDATE: reusable task audit timestamps/person fields
must remain unchanged simply because this new fact defaults to false.
*/
ALTER TABLE ref.setup_task
    ADD COLUMN IF NOT EXISTS requires_display_material boolean NOT NULL DEFAULT false;

ALTER TABLE ref.setup_task
    ALTER COLUMN requires_display_material SET DEFAULT false;

DO $column_guard$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM ref.setup_task
        WHERE requires_display_material IS NULL
    ) THEN
        RAISE EXCEPTION
            'requires_display_material contains NULL after schema add; stop rather than rewriting existing task rows';
    END IF;
END
$column_guard$;

ALTER TABLE ref.setup_task
    ALTER COLUMN requires_display_material SET NOT NULL;

COMMENT ON COLUMN ref.setup_task.requires_display_material IS
    'Reusable Setup fact only: true when this task requires automatic current LOR-derived Display/container material; false means no LOR-derived Display material.';

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
    v_requires boolean := coalesce(p_requires_display_material, false);
    v_stage_id integer;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    SELECT t.stage_id
      INTO v_stage_id
    FROM ref.setup_task AS t
    WHERE t.setup_task_id = p_setup_task_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Setup task was not found';
    END IF;

    IF v_requires AND v_stage_id IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Display/container material requires a Stage or Scene-scoped Setup task';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    UPDATE ref.setup_task AS t
       SET requires_display_material = v_requires
     WHERE t.setup_task_id = p_setup_task_id;

    RETURN QUERY
    SELECT p_setup_task_id, v_requires, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.set_setup_task_display_material_requirement(text,bigint,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_display_material_requirement(text,bigint,boolean) TO fieldwiring_app;

COMMIT;

SELECT
    '2026-09-10-setup-display-material-requirement-v0.1.1' AS applied_revision,
    current_user AS applied_by;
