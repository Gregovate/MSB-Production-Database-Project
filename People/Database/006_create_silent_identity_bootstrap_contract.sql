/* ============================================================================
People / Identity — silent human Directus identity bootstrap contract
Issue: #395
Revision: 2026-10-15 V0.2.3 candidate

Purpose:
  Support a central server-side bootstrap for real human users who authenticate
  to my.sheboyganlights.org through Cloudflare Access but do not yet have a
  Directus identity.

Permanent rules:
  - Exact normalized Sheboygan Lights email is the only automatic identity key.
  - An active existing ref.person row is required before a human Directus user
    may be initialized.
  - Shared tablet/device/service identities remain non-human and are never
    bootstrapped into ref.person.
  - A new Directus identity must be created by the supported Directus Users API,
    not by direct INSERT from the People application.
  - New identities start at the existing MSB Browser role only.
  - Existing Directus roles are never changed by bootstrap.
  - Missing/inactive/conflicting Person or Directus state fails closed.
  - Exact safe Person linkage reuses the accepted #385 reconciliation helper.
============================================================================ */

BEGIN;

DO $preflight$
DECLARE
    v_browser_roles integer;
BEGIN
    IF to_regclass('ref.person') IS NULL
       OR to_regclass('public.directus_users') IS NULL
       OR to_regclass('public.directus_roles') IS NULL THEN
        RAISE EXCEPTION 'People/Directus identity tables are required';
    END IF;

    IF to_regprocedure('ref.reconcile_directus_person_identity(text)') IS NULL THEN
        RAISE EXCEPTION 'People identity reconciliation contract #385 is required';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'people_app') THEN
        RAISE EXCEPTION 'Required role people_app does not exist';
    END IF;

    SELECT count(*)
      INTO v_browser_roles
    FROM public.directus_roles
    WHERE name = 'MSB Browser';

    IF v_browser_roles <> 1 THEN
        RAISE EXCEPTION 'Expected exactly one Directus role named MSB Browser; found %',
            v_browser_roles;
    END IF;
END
$preflight$;


/* --------------------------------------------------------------------------
   Read-only bootstrap decision/status contract.

   The People application can call this function using people_app without
   receiving direct SELECT privilege on ref.person or Directus system tables.
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ref.people_identity_bootstrap_status(
    p_email text
)
RETURNS TABLE (
    email text,
    person_id integer,
    first_name text,
    last_name text,
    person_active boolean,
    person_directus_user_id uuid,
    directus_user_id uuid,
    directus_status text,
    provider text,
    external_identifier text,
    role_id uuid,
    role_name text,
    baseline_role_id uuid,
    disposition text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_email text := lower(nullif(btrim(p_email), ''));
    v_person_count integer := 0;
    v_directus_count integer := 0;
    v_baseline_role_count integer := 0;
    v_baseline_role_id uuid;

    v_person_id integer;
    v_first_name text;
    v_last_name text;
    v_person_active boolean;
    v_person_directus_user_id uuid;

    v_directus_user_id uuid;
    v_directus_status text;
    v_provider text;
    v_external_identifier text;
    v_role_id uuid;
    v_role_name text;
BEGIN
    SELECT count(*)
      INTO v_baseline_role_count
    FROM public.directus_roles
    WHERE name = 'MSB Browser';

    IF v_baseline_role_count = 1 THEN
        SELECT id
          INTO v_baseline_role_id
        FROM public.directus_roles
        WHERE name = 'MSB Browser';
    END IF;

    IF v_email IS NULL
       OR split_part(v_email, '@', 1) = ''
       OR split_part(v_email, '@', 2) <> 'sheboyganlights.org'
       OR split_part(v_email, '@', 3) <> '' THEN
        RETURN QUERY SELECT
            v_email,
            NULL::integer,
            NULL::text,
            NULL::text,
            NULL::boolean,
            NULL::uuid,
            NULL::uuid,
            NULL::text,
            NULL::text,
            NULL::text,
            NULL::uuid,
            NULL::text,
            v_baseline_role_id,
            'INVALID_EMAIL'::text;
        RETURN;
    END IF;

    IF v_email LIKE 'tablet-%@sheboyganlights.org'
       OR v_email IN (
            'printservice@sheboyganlights.org',
            'production-1@sheboyganlights.org'
       ) THEN
        RETURN QUERY SELECT
            v_email,
            NULL::integer,
            NULL::text,
            NULL::text,
            NULL::boolean,
            NULL::uuid,
            NULL::uuid,
            NULL::text,
            NULL::text,
            NULL::text,
            NULL::uuid,
            NULL::text,
            v_baseline_role_id,
            'NONHUMAN_ACCOUNT'::text;
        RETURN;
    END IF;

    IF v_baseline_role_count <> 1 OR v_baseline_role_id IS NULL THEN
        RETURN QUERY SELECT
            v_email,
            NULL::integer,
            NULL::text,
            NULL::text,
            NULL::boolean,
            NULL::uuid,
            NULL::uuid,
            NULL::text,
            NULL::text,
            NULL::text,
            NULL::uuid,
            NULL::text,
            v_baseline_role_id,
            'BASELINE_ROLE_CONFLICT'::text;
        RETURN;
    END IF;

    SELECT count(*)
      INTO v_person_count
    FROM ref.person AS p
    WHERE lower(p.email) = v_email;

    IF v_person_count = 0 THEN
        RETURN QUERY SELECT
            v_email,
            NULL::integer,
            NULL::text,
            NULL::text,
            NULL::boolean,
            NULL::uuid,
            NULL::uuid,
            NULL::text,
            NULL::text,
            NULL::text,
            NULL::uuid,
            NULL::text,
            v_baseline_role_id,
            'NO_PERSON'::text;
        RETURN;
    ELSIF v_person_count <> 1 THEN
        RETURN QUERY SELECT
            v_email,
            NULL::integer,
            NULL::text,
            NULL::text,
            NULL::boolean,
            NULL::uuid,
            NULL::uuid,
            NULL::text,
            NULL::text,
            NULL::text,
            NULL::uuid,
            NULL::text,
            v_baseline_role_id,
            'MULTIPLE_PERSON'::text;
        RETURN;
    END IF;

    SELECT
        p.person_id,
        p.first_name,
        p.last_name,
        p.active_flag,
        p.directus_user_id
      INTO
        v_person_id,
        v_first_name,
        v_last_name,
        v_person_active,
        v_person_directus_user_id
    FROM ref.person AS p
    WHERE lower(p.email) = v_email
    LIMIT 1;

    IF coalesce(v_person_active, false) IS NOT TRUE THEN
        RETURN QUERY SELECT
            v_email,
            v_person_id,
            v_first_name,
            v_last_name,
            v_person_active,
            v_person_directus_user_id,
            NULL::uuid,
            NULL::text,
            NULL::text,
            NULL::text,
            NULL::uuid,
            NULL::text,
            v_baseline_role_id,
            'PERSON_INACTIVE'::text;
        RETURN;
    END IF;

    SELECT count(*)
      INTO v_directus_count
    FROM public.directus_users AS u
    WHERE lower(u.email) = v_email;

    IF v_directus_count = 0 THEN
        RETURN QUERY SELECT
            v_email,
            v_person_id,
            v_first_name,
            v_last_name,
            v_person_active,
            v_person_directus_user_id,
            NULL::uuid,
            NULL::text,
            NULL::text,
            NULL::text,
            NULL::uuid,
            NULL::text,
            v_baseline_role_id,
            CASE
                WHEN v_person_directus_user_id IS NULL
                    THEN 'READY_CREATE'
                ELSE 'PERSON_LINK_ORPHAN'
            END::text;
        RETURN;
    ELSIF v_directus_count <> 1 THEN
        RETURN QUERY SELECT
            v_email,
            v_person_id,
            v_first_name,
            v_last_name,
            v_person_active,
            v_person_directus_user_id,
            NULL::uuid,
            NULL::text,
            NULL::text,
            NULL::text,
            NULL::uuid,
            NULL::text,
            v_baseline_role_id,
            'MULTIPLE_DIRECTUS'::text;
        RETURN;
    END IF;

    SELECT
        u.id,
        u.status,
        lower(coalesce(u.provider, '')),
        lower(coalesce(u.external_identifier, '')),
        u.role,
        r.name
      INTO
        v_directus_user_id,
        v_directus_status,
        v_provider,
        v_external_identifier,
        v_role_id,
        v_role_name
    FROM public.directus_users AS u
    LEFT JOIN public.directus_roles AS r
      ON r.id = u.role
    WHERE lower(u.email) = v_email
    LIMIT 1;

    IF v_directus_status <> 'active' THEN
        disposition := 'DIRECTUS_INACTIVE';
    ELSIF v_provider <> 'google' THEN
        disposition := 'PROVIDER_CONFLICT';
    ELSIF v_external_identifier <> v_email THEN
        disposition := 'EXTERNAL_IDENTIFIER_CONFLICT';
    ELSIF EXISTS (
        SELECT 1
        FROM ref.person AS owner
        WHERE owner.directus_user_id = v_directus_user_id
          AND owner.person_id <> v_person_id
    ) THEN
        disposition := 'DIRECTUS_UUID_CONFLICT';
    ELSIF v_person_directus_user_id IS NULL THEN
        disposition := 'SAFE_EXISTING_LINK';
    ELSIF v_person_directus_user_id = v_directus_user_id THEN
        disposition := 'EXISTING_OK';
    ELSE
        disposition := 'PERSON_LINK_CONFLICT';
    END IF;

    RETURN QUERY SELECT
        v_email,
        v_person_id,
        v_first_name,
        v_last_name,
        v_person_active,
        v_person_directus_user_id,
        v_directus_user_id,
        v_directus_status,
        v_provider,
        v_external_identifier,
        v_role_id,
        v_role_name,
        v_baseline_role_id,
        disposition;
END;
$function$;

REVOKE ALL ON FUNCTION ref.people_identity_bootstrap_status(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.people_identity_bootstrap_status(text) TO people_app;


/* --------------------------------------------------------------------------
   Narrow bootstrap reconciliation wrapper.

   The application never receives direct EXECUTE on the shared #385 helper.
   This wrapper allows only the already-safe exact-email existing-Directus
   states surfaced by the status function.
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ref.people_identity_bootstrap_reconcile(
    p_email text
)
RETURNS TABLE (
    directus_user_id uuid,
    person_id integer,
    display_name text,
    link_reconciled boolean,
    role_name text
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_status record;
    v_reconciled record;
    v_role_name text;
BEGIN
    SELECT *
      INTO v_status
    FROM ref.people_identity_bootstrap_status(p_email);

    IF v_status.disposition NOT IN ('SAFE_EXISTING_LINK', 'EXISTING_OK') THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = format(
                'Identity bootstrap reconciliation is not allowed from state %s',
                coalesce(v_status.disposition, 'UNKNOWN')
            );
    END IF;

    SELECT *
      INTO v_reconciled
    FROM ref.reconcile_directus_person_identity(v_status.email);

    SELECT r.name
      INTO v_role_name
    FROM public.directus_users AS u
    LEFT JOIN public.directus_roles AS r
      ON r.id = u.role
    WHERE u.id = v_reconciled.directus_user_id;

    RETURN QUERY SELECT
        v_reconciled.directus_user_id,
        v_reconciled.person_id,
        v_reconciled.display_name,
        v_reconciled.link_reconciled,
        v_role_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.people_identity_bootstrap_reconcile(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.people_identity_bootstrap_reconcile(text) TO people_app;


/* Preserve direct-table least privilege. */
REVOKE ALL ON TABLE ref.person FROM people_app;
REVOKE ALL ON TABLE public.directus_users FROM people_app;
REVOKE ALL ON TABLE public.directus_roles FROM people_app;

COMMIT;

SELECT
    '2026-10-15-silent-human-identity-bootstrap-v0.2.3-candidate' AS applied_revision,
    current_user AS applied_by;
