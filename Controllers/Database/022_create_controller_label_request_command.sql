/* ============================================================================
Controller Inventory — protected Controller label request command
Issue: #110
Revision: 2026-08-31 V0.1.0

Purpose:
  Allow the protected Controller browser to request a Controller label without
  granting fieldwiring_app direct UPDATE access to ref.controller.

Identity / authorization:
  - Browser authentication is Cloudflare Access.
  - The backend supplies only the trusted Cloudflare-authenticated email.
  - This SECURITY DEFINER command resolves the active Directus user and current
    Controller capability server-side.
  - The Directus UUID is set transaction-locally in app.directus_user_uuid so
    the existing ref.set_actor_on_update() -> ref.resolve_actor() audit path
    stamps the corresponding ref.person identity.
  - The command fails closed if the Directus user is not mapped to ref.person.

Write boundary:
  - fieldwiring_app receives EXECUTE only.
  - fieldwiring_app receives no direct UPDATE on ref.controller.
  - The only state change performed here is ref.controller.print_label = true.
  - Repeated requests while print_label is already true are idempotent and do
    not touch audit fields again.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.controller') IS NULL THEN
        RAISE EXCEPTION 'ref.controller is required';
    END IF;
    IF to_regclass('ref.person') IS NULL THEN
        RAISE EXCEPTION 'ref.person is required';
    END IF;
    IF to_regclass('public.directus_users') IS NULL THEN
        RAISE EXCEPTION 'public.directus_users is required';
    END IF;
    IF to_regprocedure('ref.controller_browser_capabilities(text)') IS NULL THEN
        RAISE EXCEPTION 'ref.controller_browser_capabilities(text) is required first';
    END IF;
    IF to_regprocedure('ref.resolve_actor()') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL THEN
        RAISE EXCEPTION 'Existing MSB Controller audit actor functions are required';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ref.request_controller_label(
    p_email text,
    p_controller_id bigint
)
RETURNS TABLE (
    controller_id bigint,
    print_label boolean,
    request_already_pending boolean,
    updated_at timestamptz,
    updated_by text,
    updated_by_person_id integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, ref
AS $function$
DECLARE
    v_email text := lower(trim(p_email));
    v_directus_user_id uuid;
    v_person_id integer;
    v_can_print_label boolean := false;
    v_existing_pending boolean;
BEGIN
    IF v_email IS NULL OR v_email = '' THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Authenticated Controller operator email is required';
    END IF;

    SELECT u.id
      INTO v_directus_user_id
    FROM public.directus_users AS u
    WHERE u.status = 'active'
      AND lower(u.email) = v_email
    LIMIT 1;

    IF v_directus_user_id IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Controller label request is not authorized for this account';
    END IF;

    SELECT c.can_print_label
      INTO v_can_print_label
    FROM ref.controller_browser_capabilities(v_email) AS c;

    IF coalesce(v_can_print_label, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Controller label request is not authorized for this account';
    END IF;

    SELECT p.person_id
      INTO v_person_id
    FROM ref.person AS p
    WHERE p.directus_user_id = v_directus_user_id
    LIMIT 1;

    IF v_person_id IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Authenticated Controller operator is not mapped to an MSB person';
    END IF;

    SELECT c.print_label
      INTO v_existing_pending
    FROM ref.controller AS c
    WHERE c.controller_id = p_controller_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = format('Controller %s was not found', p_controller_id);
    END IF;

    IF v_existing_pending IS TRUE THEN
        RETURN QUERY
        SELECT
            c.controller_id,
            c.print_label,
            true AS request_already_pending,
            c.updated_at,
            c.updated_by,
            c.updated_by_person_id
        FROM ref.controller AS c
        WHERE c.controller_id = p_controller_id;
        RETURN;
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    RETURN QUERY
    UPDATE ref.controller AS c
       SET print_label = true
     WHERE c.controller_id = p_controller_id
    RETURNING
        c.controller_id,
        c.print_label,
        false AS request_already_pending,
        c.updated_at,
        c.updated_by,
        c.updated_by_person_id;
END;
$function$;

REVOKE ALL ON FUNCTION ref.request_controller_label(text, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.request_controller_label(text, bigint) TO fieldwiring_app;

COMMIT;

SELECT
    has_function_privilege(
        'fieldwiring_app',
        'ref.request_controller_label(text,bigint)',
        'EXECUTE'
    ) AS fieldwiring_can_request_controller_label,
    has_table_privilege('fieldwiring_app', 'ref.controller', 'UPDATE')
        AS fieldwiring_direct_controller_update;
