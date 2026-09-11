/* ============================================================================
MSB Setup Session — governed reusable resource catalog maintenance
Issue: #152
Status: IMPLEMENTATION CANDIDATE — REVIEW BEFORE PRODUCTION
Revision: 2026-09-11 V0.3.10 candidate

Purpose:
  Add operator-controlled presentation order to ref.setup_resource and allow
  authorized Setup Managers to correct existing reusable resource catalog rows
  without changing setup_resource_id or granting broad table DML.

Boundary:
  - Catalog-level fields: name, type, notes, active state, display order.
  - Task-specific quantity / REQUIRED-vs-PREFERRED / notes remain exclusively
    on ref.setup_task_resource and continue through ref.set_setup_task_resource.
  - Existing task-resource relationships remain attached to the same stable
    setup_resource_id when a resource is renamed or otherwise corrected.
  - Existing resources receive the constant schema default 100; no mass UPDATE
    is used. Resource type/name/ID remains the deterministic tie-break until a
    Manager intentionally assigns different display_order values.
  - Existing historical duplicates are not silently merged by this migration.
    New create/update commands reject normalized exact-name duplicates so the
    catalog cannot continue accumulating case/spacing variants.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_resource') IS NULL
       OR to_regclass('ref.setup_task_resource') IS NULL THEN
        RAISE EXCEPTION 'Setup resource tables are required first';
    END IF;

    IF to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Setup Manager command boundary is required first';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

ALTER TABLE ref.setup_resource
    ADD COLUMN IF NOT EXISTS display_order integer NOT NULL DEFAULT 100;

DO $constraint$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'ref.setup_resource'::regclass
          AND conname = 'ck_setup_resource_display_order'
    ) THEN
        ALTER TABLE ref.setup_resource
            ADD CONSTRAINT ck_setup_resource_display_order
            CHECK (display_order >= 0);
    END IF;
END
$constraint$;

CREATE INDEX IF NOT EXISTS ix_setup_resource_catalog_order
    ON ref.setup_resource(
        active_flag,
        display_order,
        resource_type,
        resource_name,
        setup_resource_id
    );

/*
Keep the existing create signature used by the application, but harden it so
case/outer/repeated-space variants cannot create another catalog row.
*/
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
    v_normalized_name text;
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

    v_normalized_name := lower(regexp_replace(v_name, '\s+', ' ', 'g'));

    IF EXISTS (
        SELECT 1
        FROM ref.setup_resource r
        WHERE lower(regexp_replace(btrim(r.resource_name), '\s+', ' ', 'g')) = v_normalized_name
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23505',
            MESSAGE = 'A Setup resource with the same normalized name already exists';
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

CREATE OR REPLACE FUNCTION ref.update_setup_resource(
    p_email text,
    p_setup_resource_id integer,
    p_resource_name text,
    p_resource_type text,
    p_notes text,
    p_active_flag boolean,
    p_display_order integer
)
RETURNS TABLE (
    setup_resource_id integer,
    resource_name text,
    resource_type text,
    active_flag boolean,
    display_order integer,
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
    v_name text := nullif(btrim(p_resource_name), '');
    v_type text := upper(btrim(coalesce(p_resource_type, '')));
    v_active boolean := coalesce(p_active_flag, true);
    v_order integer := coalesce(p_display_order, 100);
    v_normalized_name text;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF p_setup_resource_id IS NULL
       OR NOT EXISTS (
            SELECT 1
            FROM ref.setup_resource r
            WHERE r.setup_resource_id = p_setup_resource_id
       ) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Setup resource was not found';
    END IF;

    IF v_name IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Setup resource name is required';
    END IF;

    IF v_type NOT IN ('EQUIPMENT', 'VEHICLE', 'TRAILER', 'TOOL', 'OTHER') THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Invalid Setup resource type';
    END IF;

    IF v_order < 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Setup resource display order must be zero or greater';
    END IF;

    v_normalized_name := lower(regexp_replace(v_name, '\s+', ' ', 'g'));

    IF EXISTS (
        SELECT 1
        FROM ref.setup_resource r
        WHERE r.setup_resource_id <> p_setup_resource_id
          AND lower(regexp_replace(btrim(r.resource_name), '\s+', ' ', 'g')) = v_normalized_name
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23505',
            MESSAGE = 'A different Setup resource with the same normalized name already exists';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    UPDATE ref.setup_resource r
       SET resource_name = v_name,
           resource_type = v_type,
           notes = nullif(btrim(p_notes), ''),
           active_flag = v_active,
           display_order = v_order
     WHERE r.setup_resource_id = p_setup_resource_id;

    RETURN QUERY
    SELECT
        r.setup_resource_id,
        r.resource_name,
        r.resource_type,
        r.active_flag,
        r.display_order,
        v_display_name
    FROM ref.setup_resource r
    WHERE r.setup_resource_id = p_setup_resource_id;
END;
$function$;

REVOKE ALL ON FUNCTION ref.update_setup_resource(
    text, integer, text, text, text, boolean, integer
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.update_setup_resource(
    text, integer, text, text, text, boolean, integer
) TO fieldwiring_app;

COMMIT;

SELECT
    EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'ref'
          AND table_name = 'setup_resource'
          AND column_name = 'display_order'
          AND is_nullable = 'NO'
    ) AS resource_display_order_exists,
    to_regprocedure(
        'ref.update_setup_resource(text,integer,text,text,text,boolean,integer)'
    ) IS NOT NULL AS update_resource_exists,
    has_function_privilege(
        'fieldwiring_app',
        'ref.update_setup_resource(text,integer,text,text,text,boolean,integer)',
        'EXECUTE'
    ) AS app_can_update_resource,
    has_function_privilege(
        'fieldwiring_app',
        'ref.create_setup_resource(text,text,text,text)',
        'EXECUTE'
    ) AS app_can_create_resource,
    has_table_privilege('fieldwiring_app', 'ref.setup_resource', 'UPDATE')
        AS broad_resource_update,
    has_table_privilege('fieldwiring_app', 'ref.setup_resource', 'DELETE')
        AS broad_resource_delete,
    (
        SELECT count(*)
        FROM (
            SELECT lower(regexp_replace(btrim(resource_name), '\s+', ' ', 'g'))
            FROM ref.setup_resource
            GROUP BY 1
            HAVING count(*) > 1
        ) d
    ) AS preexisting_normalized_duplicate_groups;
