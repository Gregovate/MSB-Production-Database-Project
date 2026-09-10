/* ============================================================================
MSB Setup Session — reusable Display material requirement
Issue: #122
Related: #141
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-10 V0.3.5

Purpose:
  Add one explicit reusable-task flag identifying physical Display Setup work
  that should derive current Display/Container context from the task's governed
  Stage/Scene scope.

Boundary:
  - Default is FALSE. No task-name inference or automatic backfill is allowed.
  - The flag does not create task-specific Display membership. LOR remains the
    authority for current Stage/Scene Display membership.
  - The flag does not solve staged component/KIT pick timing. That harder case
    is intentionally deferred to Issue #141.
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
    ADD COLUMN IF NOT EXISTS requires_display_material boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN ref.setup_task.requires_display_material IS
    'Marks physical Display Setup work that derives current Display/Container context from its Stage/Scene scope. Does not define task-specific component/KIT allocation or staged pick timing; see Issue #141.';

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

REVOKE ALL ON FUNCTION ref.set_setup_task_display_material_requirement(
    text, bigint, boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_display_material_requirement(
    text, bigint, boolean
) TO fieldwiring_app;

COMMIT;

SELECT
    '2026-09-10-add-setup-display-material-requirement-v0.3.5' AS applied_revision,
    current_user AS applied_by;
