/* ============================================================================
MSB Setup Session — fix Kit Box assignment upsert ambiguity
Issue: #141
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-12 V0.2.1

Purpose:
  Correct the Kit Box assignment command added by migration 029. PostgreSQL
  PL/pgSQL exposes RETURNS TABLE column names as variables, so the unqualified
  ON CONFLICT (setup_task_id, container_id) target in the first candidate is
  ambiguous inside the function. Use the existing named primary-key constraint
  instead.

Authority boundaries are unchanged from migration 029.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task_container_support') IS NULL
       OR to_regclass('ref.container') IS NULL THEN
        RAISE EXCEPTION 'Setup Kit Box assignment prerequisites are missing';
    END IF;

    IF to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Setup Manager command boundary is required first';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint AS c
        JOIN pg_class AS r
          ON r.oid = c.conrelid
        JOIN pg_namespace AS n
          ON n.oid = r.relnamespace
        WHERE n.nspname = 'ref'
          AND r.relname = 'setup_task_container_support'
          AND c.conname = 'pk_setup_task_container_support'
          AND c.contype = 'p'
    ) THEN
        RAISE EXCEPTION 'Expected primary key pk_setup_task_container_support is missing';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ref.set_setup_task_kit_box_assignment(
    p_email text,
    p_setup_task_id bigint,
    p_container_id integer,
    p_assigned boolean,
    p_notes text
)
RETURNS TABLE (
    setup_task_id bigint,
    container_id integer,
    assigned boolean,
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
    v_task_valid boolean;
    v_container_type_id integer;
    v_existing_relationship text;
    v_assigned boolean := coalesce(p_assigned, false);
    v_notes text := coalesce(nullif(btrim(p_notes), ''), 'Reusable Setup Kit Box assignment.');
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF p_setup_task_id IS NULL OR p_container_id IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Setup task and Kit Box container are required';
    END IF;

    SELECT EXISTS (
        SELECT 1
        FROM ref.setup_task AS t
        WHERE t.setup_task_id = p_setup_task_id
          AND t.active_flag
          AND t.stage_id IS NOT NULL
    )
      INTO v_task_valid;

    IF NOT v_task_valid THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Kit Box assignment requires an active Stage or Scene-scoped Setup task';
    END IF;

    SELECT c.container_type_id
      INTO v_container_type_id
    FROM ref.container AS c
    WHERE c.container_id = p_container_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = 'Container was not found';
    END IF;

    IF v_container_type_id <> 2 THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'Only ref.container rows with container_type_id=2 (Kit Box) may receive a KIT assignment';
    END IF;

    SELECT tc.relationship_type
      INTO v_existing_relationship
    FROM ref.setup_task_container_support AS tc
    WHERE tc.setup_task_id = p_setup_task_id
      AND tc.container_id = p_container_id
    FOR UPDATE;

    IF v_existing_relationship IS NOT NULL
       AND v_existing_relationship <> 'KIT' THEN
        RAISE EXCEPTION USING
            ERRCODE = '23514',
            MESSAGE = 'This task/container pair already has a non-KIT support relationship and will not be overwritten';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    IF v_assigned THEN
        INSERT INTO ref.setup_task_container_support(
            setup_task_id,
            container_id,
            relationship_type,
            notes
        )
        VALUES (
            p_setup_task_id,
            p_container_id,
            'KIT',
            v_notes
        )
        ON CONFLICT ON CONSTRAINT pk_setup_task_container_support
        DO UPDATE SET
            relationship_type = 'KIT',
            notes = EXCLUDED.notes;
    ELSE
        DELETE FROM ref.setup_task_container_support AS tc
        WHERE tc.setup_task_id = p_setup_task_id
          AND tc.container_id = p_container_id
          AND tc.relationship_type = 'KIT';
    END IF;

    RETURN QUERY
    SELECT p_setup_task_id, p_container_id, v_assigned, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.set_setup_task_kit_box_assignment(text,bigint,integer,boolean,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_kit_box_assignment(text,bigint,integer,boolean,text) TO fieldwiring_app;

COMMIT;

SELECT
    '2026-09-12-setup-kit-box-upsert-fix-v0.2.1' AS applied_revision,
    current_user AS applied_by,
    has_function_privilege(
        'fieldwiring_app',
        'ref.set_setup_task_kit_box_assignment(text,bigint,integer,boolean,text)',
        'EXECUTE'
    ) AS app_can_set_kit_box_assignment;
