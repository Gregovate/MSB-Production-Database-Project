/* ============================================================================
MSB Setup Session — reusable task Captain / knowledge-owner management
Issue: #122
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-08 V0.1.0

Purpose:
  Make the existing ref.setup_task_captain relationship usable from the
  protected Setup Manager UI so tribal Setup knowledge can be deliberately
  distributed among Captains, Alternates, and Advisors.

Rules:
  - Captain assignments are reusable task knowledge, not annual crew history.
  - Spreadsheet/work-day participant names never infer Captain assignment.
  - People come only from ref.person; no free-text Captain identities.
  - CAPTAIN, ALTERNATE, and ADVISOR remain the existing allowed roles.
  - Browser writes call one narrow SECURITY DEFINER command.
  - fieldwiring_app receives EXECUTE only and no broad ref.person/table DML.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_task') IS NULL
       OR to_regclass('ref.setup_task_captain') IS NULL
       OR to_regclass('ref.person') IS NULL THEN
        RAISE EXCEPTION 'Setup task, Captain, and person tables are required';
    END IF;

    IF to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'ref.setup_management_actor(text,boolean) is required first';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

/* Reader-safe projection of assigned reusable-task leadership. Authorization is
   still checked by the protected Setup API before calling this function. */
CREATE OR REPLACE FUNCTION ref.setup_task_captain_list(
    p_setup_task_id bigint
)
RETURNS TABLE (
    setup_task_id bigint,
    person_id integer,
    display_name text,
    email text,
    captain_role text,
    sort_order integer,
    notes text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
    SELECT
        c.setup_task_id,
        c.person_id,
        coalesce(
            nullif(btrim(pg_catalog.concat_ws(' ', p.first_name, p.last_name)), ''),
            nullif(btrim(p.email), ''),
            'Person ' || p.person_id::text
        ) AS display_name,
        p.email,
        c.captain_role,
        c.sort_order,
        c.notes
    FROM ref.setup_task_captain c
    JOIN ref.person p
      ON p.person_id = c.person_id
    WHERE c.setup_task_id = p_setup_task_id
    ORDER BY c.sort_order, c.captain_role, display_name, c.person_id;
$function$;

REVOKE ALL ON FUNCTION ref.setup_task_captain_list(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.setup_task_captain_list(bigint) TO fieldwiring_app;

/* Manager-only candidate list. The protected API applies require_manager()
   before exposing this projection. */
CREATE OR REPLACE FUNCTION ref.setup_captain_person_list()
RETURNS TABLE (
    person_id integer,
    display_name text,
    email text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
    SELECT
        p.person_id,
        coalesce(
            nullif(btrim(pg_catalog.concat_ws(' ', p.first_name, p.last_name)), ''),
            nullif(btrim(p.email), ''),
            'Person ' || p.person_id::text
        ) AS display_name,
        p.email
    FROM ref.person p
    WHERE nullif(btrim(pg_catalog.concat_ws(' ', p.first_name, p.last_name, p.email)), '') IS NOT NULL
    ORDER BY display_name, p.person_id;
$function$;

REVOKE ALL ON FUNCTION ref.setup_captain_person_list() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.setup_captain_person_list() TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ref.set_setup_task_captain(
    p_email text,
    p_setup_task_id bigint,
    p_person_id integer,
    p_captain_role text,
    p_sort_order integer DEFAULT 100,
    p_notes text DEFAULT NULL,
    p_active boolean DEFAULT true
)
RETURNS TABLE (
    setup_task_id bigint,
    person_id integer,
    captain_role text,
    active boolean,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_actor_person_id integer;
    v_display_name text;
    v_role text := upper(btrim(coalesce(p_captain_role, 'CAPTAIN')));
    v_sort integer := coalesce(p_sort_order, 100);
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_actor_person_id, v_display_name
    FROM ref.setup_management_actor(p_email, false) AS a;

    IF NOT EXISTS (
        SELECT 1 FROM ref.setup_task t WHERE t.setup_task_id = p_setup_task_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Setup task was not found';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.person p WHERE p.person_id = p_person_id
    ) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Selected person was not found';
    END IF;

    IF v_role NOT IN ('CAPTAIN', 'ALTERNATE', 'ADVISOR') THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Captain role must be CAPTAIN, ALTERNATE, or ADVISOR';
    END IF;

    IF v_sort < 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Captain sort order cannot be negative';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    IF coalesce(p_active, true) THEN
        INSERT INTO ref.setup_task_captain(
            setup_task_id,
            person_id,
            captain_role,
            sort_order,
            notes
        ) VALUES (
            p_setup_task_id,
            p_person_id,
            v_role,
            v_sort,
            nullif(btrim(p_notes), '')
        )
        ON CONFLICT (setup_task_id, person_id)
        DO UPDATE SET
            captain_role = EXCLUDED.captain_role,
            sort_order = EXCLUDED.sort_order,
            notes = EXCLUDED.notes;
    ELSE
        DELETE FROM ref.setup_task_captain c
        WHERE c.setup_task_id = p_setup_task_id
          AND c.person_id = p_person_id;
    END IF;

    RETURN QUERY
    SELECT
        p_setup_task_id,
        p_person_id,
        v_role,
        coalesce(p_active, true),
        v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.set_setup_task_captain(text,bigint,integer,text,integer,text,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.set_setup_task_captain(text,bigint,integer,text,integer,text,boolean) TO fieldwiring_app;

COMMIT;
