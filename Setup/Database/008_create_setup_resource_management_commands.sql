/* ============================================================================
MSB Setup Session — governed reusable equipment/resource management
Issue: #122
Status: IMPLEMENTATION CANDIDATE — REVIEW BEFORE PRODUCTION
Revision: 2026-09-06 V0.1.0

Purpose:
  Expose the existing ref.setup_resource / ref.setup_task_resource model to the
  Manager Setup browser without granting broad table writes.

Browser-review driver:
  The first disposable Production browser review showed that required equipment
  (for example SkyTrak / Boom Lift on Front Entrance) was present in seeded
  reusable knowledge but absent from the task-detail UI.

Security / audit:
  - Cloudflare/Directus Manager authorization is rechecked through the existing
    ref.setup_management_actor() helper.
  - app.directus_user_uuid is set transaction-locally before writes so existing
    actor triggers stamp ref.person identity.
  - fieldwiring_app receives EXECUTE only on the narrow commands below.
  - relationships are deactivated rather than deleted so correction/removal
    remains represented by an audited update.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_resource') IS NULL
       OR to_regclass('ref.setup_task_resource') IS NULL
       OR to_regclass('ref.setup_task') IS NULL THEN
        RAISE EXCEPTION 'Setup core resource tables from migration 001 are required first';
    END IF;

    IF to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Setup Manager command boundary from migration 003 is required first';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

ALTER TABLE ref.setup_task_resource
    ADD COLUMN IF NOT EXISTS active_flag boolean NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS ix_setup_task_resource_active
    ON ref.setup_task_resource(setup_task_id, active_flag, setup_resource_id);

CREATE OR REPLACE FUNCTION ref.create_setup_resource(
    p_email text,
    p_resource_name text,
    p_resource_type text DEFAULT 'EQUIPMENT',
    p_notes text DEFAULT NULL
)
RETURNS TABLE (
    setup_resource_id integer,
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
    v_resource_id integer;
    v_name text := nullif(btrim(p_resource_name), '');
    v_type text := upper(btrim(coalesce(p_resource_type, 'EQUIPMENT')));
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF v_name IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Setup resource name is required';
    END IF;

    IF v_type NOT IN ('EQUIPMENT', 'VEHICLE', 'TRAILER', 'TOOL', 'OTHER') THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Invalid Setup resource type';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    INSERT INTO ref.setup_resource(resource_name, resource_type, notes)
    VALUES (v_name, v_type, nullif(btrim(p_notes), ''))
    RETURNING ref.setup_resource.setup_resource_id INTO v_resource_id;

    RETURN QUERY SELECT v_resource_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.create_setup_resource(text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.create_setup_resource(text, text, text, text) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ref.set_setup_task_resource(
    p_email text,
    p_setup_task_id bigint,
    p_setup_resource_id integer,
    p_quantity_required integer DEFAULT 1,
    p_requirement_type text DEFAULT 'REQUIRED',
    p_notes text DEFAULT NULL,
    p_active_flag boolean DEFAULT true
)
RETURNS TABLE (
    setup_task_id bigint,
    setup_resource_id integer,
    active_flag boolean,
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
    v_requirement text := upper(btrim(coalesce(p_requirement_type, 'REQUIRED')));
    v_active boolean := coalesce(p_active_flag, true);
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF p_setup_task_id IS NULL
       OR NOT EXISTS (SELECT 1 FROM ref.setup_task t WHERE t.setup_task_id = p_setup_task_id) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Setup task was not found';
    END IF;

    IF p_setup_resource_id IS NULL
       OR NOT EXISTS (
            SELECT 1
            FROM ref.setup_resource r
            WHERE r.setup_resource_id = p_setup_resource_id
              AND r.active_flag
       ) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Active Setup resource was not found';
    END IF;

    IF p_quantity_required IS NULL OR p_quantity_required <= 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Setup resource quantity must be greater than zero';
    END IF;

    IF v_requirement NOT IN ('REQUIRED', 'PREFERRED') THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Setup resource requirement must be REQUIRED or PREFERRED';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    INSERT INTO ref.setup_task_resource(
        setup_task_id,
        setup_resource_id,
        quantity_required,
        requirement_type,
        notes,
        active_flag
    ) VALUES (
        p_setup_task_id,
        p_setup_resource_id,
        p_quantity_required,
        v_requirement,
        nullif(btrim(p_notes), ''),
        v_active
    )
    ON CONFLICT (setup_task_id, setup_resource_id)
    DO UPDATE SET
        quantity_required = EXCLUDED.quantity_required,
        requirement_type = EXCLUDED.requirement_type,
        notes = EXCLUDED.notes,
        active_flag = EXCLUDED.active_flag;

    RETURN QUERY
    SELECT p_setup_task_id, p_setup_resource_id, v_active, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.set_setup_task_resource(
    text, bigint, integer, integer, text, text, boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_resource(
    text, bigint, integer, integer, text, text, boolean
) TO fieldwiring_app;

COMMIT;

SELECT
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ref'
          AND table_name = 'setup_task_resource'
          AND column_name = 'active_flag'
    ) AS task_resource_active_flag_exists,
    to_regprocedure('ref.create_setup_resource(text,text,text,text)') IS NOT NULL
        AS create_resource_exists,
    to_regprocedure('ref.set_setup_task_resource(text,bigint,integer,integer,text,text,boolean)') IS NOT NULL
        AS set_task_resource_exists,
    has_function_privilege(
        'fieldwiring_app',
        'ref.create_setup_resource(text,text,text,text)',
        'EXECUTE'
    ) AS app_can_create_resource,
    has_function_privilege(
        'fieldwiring_app',
        'ref.set_setup_task_resource(text,bigint,integer,integer,text,text,boolean)',
        'EXECUTE'
    ) AS app_can_set_task_resource,
    has_table_privilege('fieldwiring_app', 'ref.setup_task_resource', 'UPDATE')
        AS broad_task_resource_update;
