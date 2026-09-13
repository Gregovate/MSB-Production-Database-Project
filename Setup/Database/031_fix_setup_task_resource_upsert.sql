/* ============================================================================
MSB Setup Session — repair task-resource upsert conflict target
Issue: #152
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-13

Purpose:
  Restore the named primary-key ON CONFLICT target for
  ref.set_setup_task_resource(...).

  Migration 015 previously hardened this function against PL/pgSQL ambiguity.
  Migration 027 later recreated the function with the ambiguous bare-column
  conflict target. This forward migration preserves the current migration-027
  behavior while restoring the named constraint target.

Security / scope:
  - same function signature;
  - same current inactive-resource removal behavior;
  - same SECURITY DEFINER boundary;
  - fieldwiring_app retains narrow EXECUTE only;
  - no broad table DML;
  - no Resource Catalog redesign;
  - no application-source change.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ref.setup_resource') IS NULL
       OR to_regclass('ref.setup_task_resource') IS NULL THEN
        RAISE EXCEPTION 'Setup task/resource tables are required before migration 031';
    END IF;

    IF to_regprocedure(
        'ref.setup_management_actor(text,boolean)'
    ) IS NULL THEN
        RAISE EXCEPTION 'Setup Manager command boundary is required before migration 031';
    END IF;

    IF to_regprocedure(
        'ref.set_setup_task_resource(text,bigint,integer,integer,text,text,boolean)'
    ) IS NULL THEN
        RAISE EXCEPTION 'Current task-resource command is required before migration 031';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'fieldwiring_app'
    ) THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint AS c
        JOIN pg_class AS r
          ON r.oid = c.conrelid
        JOIN pg_namespace AS n
          ON n.oid = r.relnamespace
        WHERE n.nspname = 'ref'
          AND r.relname = 'setup_task_resource'
          AND c.conname = 'pk_setup_task_resource'
          AND c.contype = 'p'
    ) THEN
        RAISE EXCEPTION 'Expected primary key pk_setup_task_resource is missing';
    END IF;
END
$preflight$;

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
    v_resource_active boolean;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF p_setup_task_id IS NULL
       OR NOT EXISTS (
            SELECT 1
            FROM ref.setup_task t
            WHERE t.setup_task_id = p_setup_task_id
       ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Setup task was not found';
    END IF;

    SELECT r.active_flag
      INTO v_resource_active
    FROM ref.setup_resource r
    WHERE r.setup_resource_id = p_setup_resource_id;

    IF p_setup_resource_id IS NULL OR v_resource_active IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Setup resource was not found';
    END IF;

    IF v_active AND NOT v_resource_active THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Inactive Setup resource cannot be assigned to a task';
    END IF;

    IF NOT v_active
       AND NOT EXISTS (
            SELECT 1
            FROM ref.setup_task_resource tr
            WHERE tr.setup_task_id = p_setup_task_id
              AND tr.setup_resource_id = p_setup_resource_id
       ) THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Setup task resource relationship was not found';
    END IF;

    IF p_quantity_required IS NULL OR p_quantity_required <= 0 THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Setup resource quantity must be greater than zero';
    END IF;

    IF v_requirement NOT IN ('REQUIRED', 'PREFERRED') THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Setup resource requirement must be REQUIRED or PREFERRED';
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
    )
    VALUES (
        p_setup_task_id,
        p_setup_resource_id,
        p_quantity_required,
        v_requirement,
        nullif(btrim(p_notes), ''),
        v_active
    )
    ON CONFLICT ON CONSTRAINT pk_setup_task_resource
    DO UPDATE SET
        quantity_required = EXCLUDED.quantity_required,
        requirement_type = EXCLUDED.requirement_type,
        notes = EXCLUDED.notes,
        active_flag = EXCLUDED.active_flag;

    RETURN QUERY
    SELECT
        p_setup_task_id,
        p_setup_resource_id,
        v_active,
        v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.set_setup_task_resource(
    text,bigint,integer,integer,text,text,boolean
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ref.set_setup_task_resource(
    text,bigint,integer,integer,text,text,boolean
) TO fieldwiring_app;

COMMIT;

SELECT
    pg_get_functiondef(
        'ref.set_setup_task_resource(text,bigint,integer,integer,text,text,boolean)'::regprocedure
    ) LIKE '%ON CONFLICT ON CONSTRAINT pk_setup_task_resource%'
        AS named_constraint_fix_present,

    pg_get_functiondef(
        'ref.set_setup_task_resource(text,bigint,integer,integer,text,text,boolean)'::regprocedure
    ) LIKE '%ON CONFLICT (setup_task_id, setup_resource_id)%'
        AS ambiguous_bare_columns_present,

    has_function_privilege(
        'fieldwiring_app',
        'ref.set_setup_task_resource(text,bigint,integer,integer,text,text,boolean)',
        'EXECUTE'
    ) AS app_can_set_task_resource,

    has_table_privilege(
        'fieldwiring_app',
        'ref.setup_task_resource',
        'INSERT'
    ) AS broad_task_resource_insert,

    has_table_privilege(
        'fieldwiring_app',
        'ref.setup_task_resource',
        'UPDATE'
    ) AS broad_task_resource_update,

    has_table_privilege(
        'fieldwiring_app',
        'ref.setup_task_resource',
        'DELETE'
    ) AS broad_task_resource_delete;