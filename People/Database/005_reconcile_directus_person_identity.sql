/* ============================================================================
People / Identity — durable Directus <-> Person exact-email reconciliation
Issue: #385
Revision: 2026-10-13 V0.2.2

Purpose:
  Eliminate the recurring failure where an authenticated/authorized Google
  Directus user exists but ref.person.directus_user_id is still NULL.

Permanent rules:
  - Exact normalized Sheboygan Lights email is the only automatic match key.
  - The Directus user must be active, provider=google, and external_identifier
    must equal the same email.
  - The Person must already exist, be active, and carry that exact real MSB email.
  - No Person is auto-created.
  - No Directus role/policy is changed.
  - Conflicts fail closed.
  - Shared tablet service accounts (tablet-*@sheboyganlights.org) are non-human,
    Browser-only identities and are never reconciled to ref.person.
  - A safe NULL link is reconciled before protected application writes continue.
  - The reconciliation update is attributed to the same authenticated Person.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.person') IS NULL
       OR to_regclass('public.directus_users') IS NULL THEN
        RAISE EXCEPTION 'People/Directus identity tables are required';
    END IF;

    IF to_regprocedure('ref.resolve_actor()') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL THEN
        RAISE EXCEPTION 'Shared audit actor functions are required';
    END IF;

    IF to_regprocedure('ref.setup_management_actor(text,boolean)') IS NULL
       OR to_regprocedure('ref.setup_movement_actor(text)') IS NULL
       OR to_regprocedure('ref.setup_execution_actor(text,bigint)') IS NULL
       OR to_regprocedure('ref.setup_inventory_actor(text,boolean)') IS NULL
       OR to_regprocedure('ref.people_management_actor(text)') IS NULL
       OR to_regprocedure('ref.controller_management_actor(text)') IS NULL
       OR to_regprocedure('ref.request_controller_label(text,bigint)') IS NULL THEN
        RAISE EXCEPTION 'One or more protected application actor boundaries are missing';
    END IF;
END
$preflight$;


/* --------------------------------------------------------------------------
   Shared audit resolver: retain the durable UUID link as first authority.
   Add a narrowly bounded exact-email fallback only for an active Google user
   whose Person link is currently NULL and conflict-free. This fallback exists
   so the reconciliation UPDATE itself can be audited to the real Person.
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ref.resolve_actor()
RETURNS TABLE (
    person_id integer,
    actor_name text
)
LANGUAGE plpgsql
AS $function$
DECLARE
    v_directus_uuid text;
    v_reconcile_email text;
BEGIN
    v_directus_uuid := current_setting('app.directus_user_uuid', true);
    v_reconcile_email := lower(nullif(btrim(current_setting('app.identity_reconcile_email', true)), ''));

    /* 1) Normal durable Directus UUID -> Person mapping. */
    IF v_directus_uuid IS NOT NULL AND btrim(v_directus_uuid) <> '' THEN
        SELECT
            p.person_id,
            coalesce(
                nullif(btrim(p.preferred_name), ''),
                nullif(btrim(pg_catalog.concat_ws(' ', p.first_name, p.last_name)), ''),
                nullif(btrim(p.email), '')
            )
          INTO person_id, actor_name
        FROM ref.person AS p
        WHERE p.directus_user_id::text = v_directus_uuid
        LIMIT 1;

        IF person_id IS NOT NULL THEN
            IF actor_name IS NULL THEN
                RAISE EXCEPTION
                    'Mapped Directus actor % has no usable person display identity',
                    person_id;
            END IF;
            RETURN NEXT;
            RETURN;
        END IF;

        /*
          1b) Reconciliation-only audit bootstrap. The special transaction-local
          email setting is written only by ref.reconcile_directus_person_identity().
          Ordinary governed writes cannot use exact email as an audit shortcut.
        */
        IF v_reconcile_email IS NOT NULL THEN
            SELECT
                p.person_id,
                coalesce(
                    nullif(btrim(p.preferred_name), ''),
                    nullif(btrim(pg_catalog.concat_ws(' ', p.first_name, p.last_name)), ''),
                    nullif(btrim(p.email), '')
                )
              INTO person_id, actor_name
            FROM public.directus_users AS u
            JOIN ref.person AS p
              ON lower(p.email) = lower(u.email)
            WHERE u.id::text = v_directus_uuid
              AND lower(u.email) = v_reconcile_email
              AND u.status = 'active'
              AND lower(coalesce(u.provider, '')) = 'google'
              AND lower(coalesce(u.external_identifier, '')) = v_reconcile_email
              AND p.active_flag
              AND p.directus_user_id IS NULL
              AND NOT EXISTS (
                  SELECT 1
                  FROM ref.person AS owner
                  WHERE owner.directus_user_id = u.id
              )
            LIMIT 1;

            IF person_id IS NOT NULL THEN
                IF actor_name IS NULL THEN
                    RAISE EXCEPTION
                        'Exact-email Directus actor % has no usable person display identity',
                        person_id;
                END IF;
                RETURN NEXT;
                RETURN;
            END IF;
        END IF;
    END IF;

    /* 2) PostgreSQL mapped login. */
    SELECT
        p.person_id,
        coalesce(
            nullif(btrim(p.preferred_name), ''),
            nullif(btrim(pg_catalog.concat_ws(' ', p.first_name, p.last_name)), ''),
            nullif(btrim(p.email), '')
        )
      INTO person_id, actor_name
    FROM ref.person AS p
    WHERE p.pg_login_name = current_user
    LIMIT 1;

    IF person_id IS NOT NULL THEN
        IF actor_name IS NULL THEN
            RAISE EXCEPTION
                'Mapped PostgreSQL actor % has no usable person display identity',
                person_id;
        END IF;
        RETURN NEXT;
        RETURN;
    END IF;

    /* 3) Established database-side fallback for an unmapped PostgreSQL login. */
    person_id := NULL;
    actor_name := current_user;

    RETURN NEXT;
    RETURN;
END;
$function$;


/* --------------------------------------------------------------------------
   Shared exact-email identity reconciliation.
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ref.reconcile_directus_person_identity(
    p_email text
)
RETURNS TABLE (
    directus_user_id uuid,
    person_id integer,
    display_name text,
    link_reconciled boolean
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_email text := lower(nullif(btrim(p_email), ''));
    v_user_count integer;
    v_directus_user_id uuid;
    v_directus_email text;
    v_provider text;
    v_external_identifier text;
    v_directus_display text;
    v_person_id integer;
    v_person_active boolean;
    v_person_directus_user_id uuid;
    v_person_display text;
BEGIN
    IF v_email IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Authenticated email is required for identity reconciliation';
    END IF;

    IF v_email LIKE 'tablet-%@sheboyganlights.org' THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Shared tablet accounts are Browser-only device identities and cannot act as an MSB person';
    END IF;

    SELECT count(*)
      INTO v_user_count
    FROM public.directus_users AS u
    WHERE u.status = 'active'
      AND lower(u.email) = v_email;

    IF v_user_count <> 1 THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = CASE
                WHEN v_user_count = 0
                    THEN 'No active Directus user exists for the authenticated email'
                ELSE 'Multiple active Directus users exist for the authenticated email'
            END;
    END IF;

    SELECT
        u.id,
        lower(u.email),
        lower(coalesce(u.provider, '')),
        lower(coalesce(u.external_identifier, '')),
        nullif(btrim(pg_catalog.concat_ws(' ', u.first_name, u.last_name)), '')
      INTO
        v_directus_user_id,
        v_directus_email,
        v_provider,
        v_external_identifier,
        v_directus_display
    FROM public.directus_users AS u
    WHERE u.status = 'active'
      AND lower(u.email) = v_email
    LIMIT 1;

    IF v_provider <> 'google' THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Directus identity reconciliation requires a Google-backed user';
    END IF;

    IF v_external_identifier <> v_email THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Directus Google external identifier does not match the authenticated email';
    END IF;

    SELECT
        p.person_id,
        p.active_flag,
        p.directus_user_id,
        coalesce(
            nullif(btrim(p.preferred_name), ''),
            nullif(btrim(pg_catalog.concat_ws(' ', p.first_name, p.last_name)), ''),
            nullif(btrim(p.email), '')
        )
      INTO
        v_person_id,
        v_person_active,
        v_person_directus_user_id,
        v_person_display
    FROM ref.person AS p
    WHERE lower(p.email) = v_email
    LIMIT 1;

    IF v_person_id IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'No MSB Person exists with the authenticated Sheboygan Lights email';
    END IF;

    IF coalesce(v_person_active, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'The MSB Person matching the authenticated email is inactive';
    END IF;

    IF v_person_directus_user_id IS NOT NULL
       AND v_person_directus_user_id <> v_directus_user_id THEN
        RAISE EXCEPTION USING
            ERRCODE = '23505',
            MESSAGE = 'The MSB Person is already linked to a different Directus identity';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.person AS owner
        WHERE owner.directus_user_id = v_directus_user_id
          AND owner.person_id <> v_person_id
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23505',
            MESSAGE = 'The Directus identity is already linked to a different MSB Person';
    END IF;

    /* Already correct: idempotent no-op. */
    IF v_person_directus_user_id = v_directus_user_id THEN
        PERFORM pg_catalog.set_config(
            'app.directus_user_uuid',
            v_directus_user_id::text,
            true
        );

        RETURN QUERY SELECT
            v_directus_user_id,
            v_person_id,
            coalesce(v_person_display, v_directus_display, v_email),
            false;
        RETURN;
    END IF;

    /*
      The shared audit resolver now recognizes this exact conflict-free email
      match before the durable link exists, allowing the normal ref.person
      update trigger to attribute this reconciliation to the same human.
    */
    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );
    PERFORM pg_catalog.set_config(
        'app.identity_reconcile_email',
        v_email,
        true
    );

    UPDATE ref.person AS p
       SET directus_user_id = v_directus_user_id
     WHERE p.person_id = v_person_id
       AND p.directus_user_id IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = '40001',
            MESSAGE = 'MSB Person identity changed during reconciliation; retry after refresh';
    END IF;

    RETURN QUERY SELECT
        v_directus_user_id,
        v_person_id,
        coalesce(v_person_display, v_directus_display, v_email),
        true;
END;
$function$;

REVOKE ALL ON FUNCTION ref.reconcile_directus_person_identity(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.reconcile_directus_person_identity(text) FROM fieldwiring_app;
REVOKE ALL ON FUNCTION ref.reconcile_directus_person_identity(text) FROM people_app;
REVOKE ALL ON FUNCTION ref.reconcile_directus_person_identity(text) FROM directus_app;


/* --------------------------------------------------------------------------
   Read-only reconciliation report for administrators / acceptance.
   No app role receives EXECUTE.
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ref.directus_person_identity_reconciliation_report()
RETURNS TABLE (
    email text,
    directus_user_id uuid,
    directus_status text,
    provider text,
    external_identifier text,
    directus_role_name text,
    active_directus_user_count integer,
    person_id integer,
    person_active boolean,
    person_directus_user_id uuid,
    disposition text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
    WITH directus_rows AS (
        SELECT
            u.id,
            lower(u.email) AS email,
            u.status,
            u.provider,
            u.external_identifier,
            r.name AS role_name,
            count(*) FILTER (WHERE u.status = 'active')
                OVER (PARTITION BY lower(u.email))::integer AS active_user_count
        FROM public.directus_users AS u
        LEFT JOIN public.directus_roles AS r
          ON r.id = u.role
        WHERE u.email IS NOT NULL
          AND u.email ILIKE '%@sheboyganlights.org'
    ),
    identities AS (
        SELECT
            lower(coalesce(d.email, p.email)) AS email,
            d.id AS directus_user_id,
            d.status AS directus_status,
            d.provider,
            d.external_identifier,
            d.role_name AS directus_role_name,
            coalesce(d.active_user_count, 0) AS active_directus_user_count,
            p.person_id,
            p.active_flag AS person_active,
            p.directus_user_id AS person_directus_user_id
        FROM directus_rows AS d
        FULL OUTER JOIN ref.person AS p
          ON lower(p.email) = d.email
        WHERE
            d.email IS NOT NULL
            OR (p.email IS NOT NULL AND p.email ILIKE '%@sheboyganlights.org')
    )
    SELECT
        i.email,
        i.directus_user_id,
        i.directus_status,
        i.provider,
        i.external_identifier,
        i.directus_role_name,
        i.active_directus_user_count,
        i.person_id,
        i.person_active,
        i.person_directus_user_id,
        CASE
            WHEN i.email LIKE 'tablet-%@sheboyganlights.org'
                THEN 'SHARED_TABLET_ACCOUNT'
            WHEN i.active_directus_user_count > 1
                THEN 'MULTIPLE_ACTIVE_DIRECTUS'
            WHEN i.directus_user_id IS NULL
                THEN 'PERSON_WITHOUT_DIRECTUS'
            WHEN i.person_id IS NULL
                THEN 'DIRECTUS_WITHOUT_PERSON'
            WHEN i.directus_status <> 'active'
                THEN 'DIRECTUS_INACTIVE'
            WHEN lower(coalesce(i.provider, '')) <> 'google'
                THEN 'PROVIDER_CONFLICT'
            WHEN lower(coalesce(i.external_identifier, '')) <> i.email
                THEN 'EXTERNAL_IDENTIFIER_CONFLICT'
            WHEN coalesce(i.person_active, false) IS NOT TRUE
                THEN 'PERSON_INACTIVE'
            WHEN i.person_directus_user_id = i.directus_user_id
                THEN 'LINKED_OK'
            WHEN i.person_directus_user_id IS NULL
                 AND NOT EXISTS (
                     SELECT 1
                     FROM ref.person AS owner
                     WHERE owner.directus_user_id = i.directus_user_id
                       AND owner.person_id <> i.person_id
                 )
                THEN 'SAFE_EXACT_EMAIL_UNLINKED'
            WHEN i.person_directus_user_id IS NOT NULL
                 AND i.person_directus_user_id <> i.directus_user_id
                THEN 'PERSON_LINK_CONFLICT'
            ELSE 'DIRECTUS_UUID_CONFLICT'
        END AS disposition
    FROM identities AS i
    ORDER BY i.email, i.directus_user_id;
$function$;

REVOKE ALL ON FUNCTION ref.directus_person_identity_reconciliation_report() FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.directus_person_identity_reconciliation_report() FROM fieldwiring_app;
REVOKE ALL ON FUNCTION ref.directus_person_identity_reconciliation_report() FROM people_app;
REVOKE ALL ON FUNCTION ref.directus_person_identity_reconciliation_report() FROM directus_app;


/* --------------------------------------------------------------------------
   Protected actor boundaries now all consume the same identity reconciler.
   Authorization is still checked first in each subsystem.
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ref.setup_management_actor(
    p_email text,
    p_require_admin boolean DEFAULT false
)
RETURNS TABLE (
    directus_user_id uuid,
    person_id integer,
    display_name text,
    can_admin_setup boolean
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_email text := lower(btrim(p_email));
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_can_manage boolean := false;
    v_can_admin boolean := false;
BEGIN
    IF v_email IS NULL OR v_email = '' THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'Authenticated Setup operator email is required';
    END IF;

    SELECT u.id, c.display_name, c.can_manage_setup, c.can_admin_setup
      INTO v_directus_user_id, v_display_name, v_can_manage, v_can_admin
    FROM public.directus_users AS u
    JOIN LATERAL ref.setup_browser_capabilities(v_email) AS c ON true
    WHERE u.status = 'active'
      AND lower(u.email) = v_email
    LIMIT 1;

    IF v_directus_user_id IS NULL OR coalesce(v_can_manage, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'Setup maintenance is not authorized for this account';
    END IF;

    IF coalesce(p_require_admin, false) AND coalesce(v_can_admin, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'Setup Session creation requires Administrator access';
    END IF;

    SELECT r.directus_user_id, r.person_id, r.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.reconcile_directus_person_identity(v_email) AS r;

    RETURN QUERY SELECT
        v_directus_user_id,
        v_person_id,
        v_display_name,
        coalesce(v_can_admin, false);
END;
$function$;

CREATE OR REPLACE FUNCTION ref.setup_movement_actor(p_email text)
RETURNS TABLE (
    directus_user_id uuid,
    person_id integer,
    display_name text
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_email text := lower(btrim(p_email));
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_can_move boolean := false;
BEGIN
    IF v_email IS NULL OR v_email = '' THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'Authenticated Setup movement operator email is required';
    END IF;

    SELECT u.id, c.display_name, c.can_move_setup_assets
      INTO v_directus_user_id, v_display_name, v_can_move
    FROM public.directus_users AS u
    JOIN LATERAL ref.setup_browser_capabilities(v_email) AS c ON true
    WHERE u.status = 'active'
      AND lower(u.email) = v_email
    LIMIT 1;

    IF v_directus_user_id IS NULL OR coalesce(v_can_move, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'Setup asset movement is not authorized for this account';
    END IF;

    SELECT r.directus_user_id, r.person_id, r.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.reconcile_directus_person_identity(v_email) AS r;

    RETURN QUERY SELECT v_directus_user_id, v_person_id, v_display_name;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.setup_execution_actor(
    p_email text,
    p_setup_task_id bigint
)
RETURNS TABLE (
    directus_user_id uuid,
    person_id integer,
    display_name text,
    can_manage_setup boolean
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_email text := lower(btrim(p_email));
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_role_name text;
    v_policy_names text[];
    v_can_read boolean := false;
    v_can_manage boolean := false;
    v_can_report boolean := false;
BEGIN
    IF v_email IS NULL OR v_email = '' THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'Authenticated Setup operator email is required';
    END IF;

    SELECT u.id, c.display_name, c.role_name, c.policy_names,
           c.can_read_setup, c.can_manage_setup
      INTO v_directus_user_id, v_display_name, v_role_name, v_policy_names,
           v_can_read, v_can_manage
    FROM public.directus_users u
    JOIN LATERAL ref.setup_browser_capabilities(v_email) c ON true
    WHERE u.status = 'active'
      AND lower(u.email) = v_email
    LIMIT 1;

    IF v_directus_user_id IS NULL OR coalesce(v_can_read, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'Setup execution access is not authorized for this account';
    END IF;

    v_can_report :=
        coalesce(v_can_manage, false)
        OR coalesce(v_role_name = 'Production Crew', false)
        OR 'Production Crew' = ANY(coalesce(v_policy_names, ARRAY[]::text[]));

    IF v_can_report IS NOT TRUE THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'Setup work reporting requires Production Crew or Manager access';
    END IF;

    SELECT r.directus_user_id, r.person_id, r.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.reconcile_directus_person_identity(v_email) AS r;

    RETURN QUERY SELECT
        v_directus_user_id,
        v_person_id,
        v_display_name,
        coalesce(v_can_manage, false);
END;
$function$;

CREATE OR REPLACE FUNCTION ref.setup_inventory_actor(
    p_email text,
    p_require_manager boolean DEFAULT false
)
RETURNS TABLE (
    directus_user_id uuid,
    person_id integer,
    display_name text,
    can_manage_setup boolean
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_email text := lower(btrim(p_email));
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_role_name text;
    v_policy_names text[] := ARRAY[]::text[];
    v_can_inventory boolean := false;
    v_can_manage boolean := false;
BEGIN
    IF v_email IS NULL OR v_email = '' THEN
        RAISE EXCEPTION USING ERRCODE='42501',
            MESSAGE='Authenticated Setup operator email is required';
    END IF;

    SELECT
        u.id,
        nullif(btrim(pg_catalog.concat_ws(' ',u.first_name,u.last_name)),''),
        r.name,
        ARRAY(
            SELECT DISTINCT p.name
            FROM public.directus_access a
            JOIN public.directus_policies p ON p.id=a.policy
            WHERE a."user"=u.id OR (u.role IS NOT NULL AND a.role=u.role)
            ORDER BY p.name
        )
      INTO v_directus_user_id, v_display_name, v_role_name, v_policy_names
    FROM public.directus_users u
    LEFT JOIN public.directus_roles r ON r.id=u.role
    WHERE u.status='active'
      AND lower(u.email)=v_email
    LIMIT 1;

    IF v_directus_user_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE='42501',
            MESSAGE='Setup inventory operator is not an active Directus user';
    END IF;

    v_can_manage :=
        v_role_name IN ('Manager','Administrator')
        OR v_policy_names && ARRAY['Manager','Administrator'];
    v_can_inventory :=
        v_can_manage
        OR v_role_name='Production Crew'
        OR 'Production Crew'=ANY(v_policy_names);

    IF NOT v_can_inventory THEN
        RAISE EXCEPTION USING ERRCODE='42501',
            MESSAGE='Setup Extra Material inventory adjustment is not authorized for this account';
    END IF;

    IF coalesce(p_require_manager,false) AND NOT v_can_manage THEN
        RAISE EXCEPTION USING ERRCODE='42501',
            MESSAGE='Setup Extra Material definition maintenance requires Manager access';
    END IF;

    SELECT r.directus_user_id, r.person_id, r.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.reconcile_directus_person_identity(v_email) AS r;

    RETURN QUERY SELECT
        v_directus_user_id,
        v_person_id,
        v_display_name,
        v_can_manage;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.people_management_actor(p_email text)
RETURNS TABLE (
    directus_user_id uuid,
    person_id integer,
    display_name text
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_email text := lower(btrim(p_email));
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_can_manage boolean := false;
BEGIN
    IF v_email IS NULL OR v_email = '' THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'Authenticated People Manager email is required';
    END IF;

    SELECT u.id, c.display_name, c.can_manage_people
      INTO v_directus_user_id, v_display_name, v_can_manage
    FROM public.directus_users AS u
    JOIN LATERAL ref.people_browser_capabilities(v_email) AS c ON true
    WHERE u.status = 'active'
      AND lower(u.email) = v_email
    LIMIT 1;

    IF v_directus_user_id IS NULL OR coalesce(v_can_manage, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'People Manager is not authorized for this account';
    END IF;

    SELECT r.directus_user_id, r.person_id, r.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.reconcile_directus_person_identity(v_email) AS r;

    RETURN QUERY SELECT v_directus_user_id, v_person_id, v_display_name;
END;
$function$;

CREATE OR REPLACE FUNCTION ref.controller_management_actor(p_email text)
RETURNS TABLE (
    directus_user_id uuid,
    person_id integer,
    display_name text
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_email text := lower(btrim(p_email));
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_can_manage boolean := false;
BEGIN
    IF v_email IS NULL OR v_email = '' THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'Authenticated Controller operator email is required';
    END IF;

    SELECT u.id, c.display_name, c.can_manage_controllers
      INTO v_directus_user_id, v_display_name, v_can_manage
    FROM public.directus_users AS u
    JOIN LATERAL ref.controller_browser_capabilities(v_email) AS c ON true
    WHERE u.status = 'active'
      AND lower(u.email) = v_email
    LIMIT 1;

    IF v_directus_user_id IS NULL OR coalesce(v_can_manage, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'Controller maintenance is not authorized for this account';
    END IF;

    SELECT r.directus_user_id, r.person_id, r.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.reconcile_directus_person_identity(v_email) AS r;

    RETURN QUERY SELECT v_directus_user_id, v_person_id, v_display_name;
END;
$function$;


/* Controller label request has its own actor logic; reconcile after auth. */
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
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_email text := lower(trim(p_email));
    v_directus_user_id uuid;
    v_person_id integer;
    v_can_print_label boolean := false;
    v_existing_pending boolean;
BEGIN
    IF v_email IS NULL OR v_email = '' THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'Authenticated Controller operator email is required';
    END IF;

    SELECT u.id
      INTO v_directus_user_id
    FROM public.directus_users AS u
    WHERE u.status = 'active'
      AND lower(u.email) = v_email
    LIMIT 1;

    IF v_directus_user_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'Controller label request is not authorized for this account';
    END IF;

    SELECT c.can_print_label
      INTO v_can_print_label
    FROM ref.controller_browser_capabilities(v_email) AS c;

    IF coalesce(v_can_print_label, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING ERRCODE = '42501',
            MESSAGE = 'Controller label request is not authorized for this account';
    END IF;

    SELECT r.directus_user_id, r.person_id
      INTO v_directus_user_id, v_person_id
    FROM ref.reconcile_directus_person_identity(v_email) AS r;

    SELECT c.print_label
      INTO v_existing_pending
    FROM ref.controller AS c
    WHERE c.controller_id = p_controller_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
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


/* Preserve current least-privilege actor/helper boundaries. */
REVOKE ALL ON FUNCTION ref.setup_management_actor(text,boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.setup_management_actor(text,boolean) FROM fieldwiring_app;
REVOKE ALL ON FUNCTION ref.setup_movement_actor(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.setup_movement_actor(text) FROM fieldwiring_app;
REVOKE ALL ON FUNCTION ref.setup_execution_actor(text,bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.setup_execution_actor(text,bigint) FROM fieldwiring_app;
REVOKE ALL ON FUNCTION ref.setup_inventory_actor(text,boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.setup_inventory_actor(text,boolean) FROM fieldwiring_app;
REVOKE ALL ON FUNCTION ref.people_management_actor(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.people_management_actor(text) FROM people_app;
REVOKE ALL ON FUNCTION ref.controller_management_actor(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.controller_management_actor(text) FROM fieldwiring_app;

REVOKE ALL ON FUNCTION ref.request_controller_label(text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.request_controller_label(text,bigint) TO fieldwiring_app;

COMMIT;

SELECT
    '2026-10-13-directus-person-self-reconcile-v0.2.2' AS applied_revision,
    current_user AS applied_by;
