/* ============================================================================
MSB Setup Session — prerequisite cycle-check ambiguity correction
Issue: #122
Status: PRODUCTION CANDIDATE — REVIEW BEFORE APPLY
Revision: 2026-09-08 V0.3.5

Purpose:
  Correct the remaining PL/pgSQL ambiguity in
  ref.set_setup_task_dependency(text,bigint,bigint,text,boolean).

  The function RETURNS TABLE includes an output variable named setup_task_id.
  Migration 015 qualified the base-table existence checks and hardened the
  conflict target, but the recursive cycle-prevention SELECT still referenced
  setup_task_id without a relation alias. PostgreSQL can therefore interpret
  that name as either the CTE column or the PL/pgSQL output variable.

Security / behavior:
  - function signature and authorization remain unchanged;
  - cycle prevention remains unchanged;
  - fieldwiring_app retains EXECUTE only;
  - no broad table DML is granted;
  - no Setup data is changed by this migration.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regprocedure('ref.set_setup_task_dependency(text,bigint,bigint,text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Setup prerequisite command is required before migration 018';
    END IF;

    IF to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Setup management authorization function is required before migration 018';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ref.set_setup_task_dependency(
    p_email text,
    p_setup_task_id bigint,
    p_prerequisite_setup_task_id bigint,
    p_dependency_note text,
    p_active boolean DEFAULT true
)
RETURNS TABLE (
    setup_task_id bigint,
    prerequisite_setup_task_id bigint,
    active boolean,
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
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF p_setup_task_id = p_prerequisite_setup_task_id THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'A Setup task cannot depend on itself';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_task t WHERE t.setup_task_id = p_setup_task_id
    ) OR NOT EXISTS (
        SELECT 1 FROM ref.setup_task t WHERE t.setup_task_id = p_prerequisite_setup_task_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Setup task or prerequisite was not found';
    END IF;

    IF coalesce(p_active, true) THEN
        IF EXISTS (
            WITH RECURSIVE prerequisite_chain(setup_task_id) AS (
                SELECT d.prerequisite_setup_task_id
                FROM ref.setup_task_dependency d
                WHERE d.setup_task_id = p_prerequisite_setup_task_id
                UNION
                SELECT d.prerequisite_setup_task_id
                FROM ref.setup_task_dependency d
                JOIN prerequisite_chain c
                  ON d.setup_task_id = c.setup_task_id
            )
            SELECT 1
            FROM prerequisite_chain c
            WHERE c.setup_task_id = p_setup_task_id
        ) THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
                MESSAGE = 'Prerequisite would create a circular Setup dependency';
        END IF;
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    IF coalesce(p_active, true) THEN
        INSERT INTO ref.setup_task_dependency(
            setup_task_id,
            prerequisite_setup_task_id,
            dependency_note
        ) VALUES (
            p_setup_task_id,
            p_prerequisite_setup_task_id,
            nullif(btrim(p_dependency_note), '')
        )
        ON CONFLICT ON CONSTRAINT pk_setup_task_dependency
        DO UPDATE SET dependency_note = EXCLUDED.dependency_note;
    ELSE
        DELETE FROM ref.setup_task_dependency d
        WHERE d.setup_task_id = p_setup_task_id
          AND d.prerequisite_setup_task_id = p_prerequisite_setup_task_id;
    END IF;

    RETURN QUERY
    SELECT p_setup_task_id,
           p_prerequisite_setup_task_id,
           coalesce(p_active, true),
           v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.set_setup_task_dependency(
    text,bigint,bigint,text,boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_dependency(
    text,bigint,bigint,text,boolean
) TO fieldwiring_app;

COMMIT;
