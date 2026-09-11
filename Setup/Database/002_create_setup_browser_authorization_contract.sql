/* ============================================================================
MSB Setup Session — browser authorization contract
Issue: #122
Status: IMPLEMENTATION CANDIDATE — DO NOT APPLY TO PRODUCTION WITHOUT REVIEW
Revision: 2026-09-06 V0.3.0

Pattern:
  Reuses the accepted Controller Management boundary:
  - Cloudflare Access authenticates the protected browser user.
  - Directus remains role/policy authority.
  - fieldwiring_app may EXECUTE this narrow lookup but receives no direct read
    access to Directus system tables.

Capabilities:
  Production Crew / Volunteer -> read Setup + Container/Display movement/scanning.
  Manager                     -> movement + manage reusable/annual Setup data.
  Administrator/admin_access  -> Manager capabilities + create annual Setup Session.

Initial conservative rollout:
  - Production Crew / Volunteer may record only governed physical movement
    actions such as Container/Display scans, moves, and unload confirmations.
  - Production Crew / Volunteer may not edit reusable task definitions,
    dependencies, annual verification/actuals, planning/schedule data, or
    Procedure-maintenance data.
  - Generic task-completion writes are NOT granted to Production Crew /
    Volunteer by this contract. That may be added later as a separate reviewed
    capability if field experience supports it.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('public.directus_users') IS NULL
       OR to_regclass('public.directus_roles') IS NULL
       OR to_regclass('public.directus_access') IS NULL
       OR to_regclass('public.directus_policies') IS NULL THEN
        RAISE EXCEPTION 'Required Directus authorization tables are missing';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required existing application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ref.setup_browser_capabilities(p_email text)
RETURNS TABLE (
    email text,
    display_name text,
    role_name text,
    policy_names text[],
    can_read_setup boolean,
    can_move_setup_assets boolean,
    can_manage_setup boolean,
    can_admin_setup boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
    WITH user_row AS (
        SELECT
            u.id AS user_id,
            u.role AS role_id,
            lower(u.email) AS email,
            nullif(trim(concat_ws(' ', u.first_name, u.last_name)), '') AS display_name,
            r.name AS role_name
        FROM public.directus_users u
        LEFT JOIN public.directus_roles r
          ON r.id = u.role
        WHERE u.status = 'active'
          AND lower(u.email) = lower(trim(p_email))
        LIMIT 1
    ),
    resolved AS (
        SELECT
            u.*,
            ARRAY(
                SELECT DISTINCT p.name
                FROM public.directus_access a
                JOIN public.directus_policies p ON p.id = a.policy
                WHERE a."user" = u.user_id
                   OR (u.role_id IS NOT NULL AND a.role = u.role_id)
                ORDER BY p.name
            ) AS policy_names,
            (
                u.role_name IN ('Manager', 'Administrator')
                OR EXISTS (
                    SELECT 1
                    FROM public.directus_access a
                    JOIN public.directus_policies p ON p.id = a.policy
                    WHERE (a."user" = u.user_id
                           OR (u.role_id IS NOT NULL AND a.role = u.role_id))
                      AND (p.admin_access OR p.name IN ('Manager', 'Administrator'))
                )
            ) AS can_manage,
            (
                u.role_name = 'Administrator'
                OR EXISTS (
                    SELECT 1
                    FROM public.directus_access a
                    JOIN public.directus_policies p ON p.id = a.policy
                    WHERE (a."user" = u.user_id
                           OR (u.role_id IS NOT NULL AND a.role = u.role_id))
                      AND (p.admin_access OR p.name = 'Administrator')
                )
            ) AS can_admin,
            (
                u.role_name IN ('Production Crew', 'Manager', 'Administrator')
                OR EXISTS (
                    SELECT 1
                    FROM public.directus_access a
                    JOIN public.directus_policies p ON p.id = a.policy
                    WHERE (a."user" = u.user_id
                           OR (u.role_id IS NOT NULL AND a.role = u.role_id))
                      AND (
                          p.admin_access
                          OR p.name IN ('Volunteer', 'Production Crew', 'Manager', 'Administrator')
                      )
                )
            ) AS can_field
        FROM user_row u
    )
    SELECT
        r.email,
        coalesce(r.display_name, r.email) AS display_name,
        r.role_name,
        r.policy_names,
        r.can_field AS can_read_setup,
        r.can_field AS can_move_setup_assets,
        r.can_manage AS can_manage_setup,
        r.can_admin AS can_admin_setup
    FROM resolved r;
$function$;

REVOKE ALL ON FUNCTION ref.setup_browser_capabilities(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.setup_browser_capabilities(text) TO fieldwiring_app;

COMMIT;

SELECT
    has_function_privilege(
        'fieldwiring_app',
        'ref.setup_browser_capabilities(text)',
        'EXECUTE'
    ) AS app_can_execute_setup_capability_lookup,
    has_table_privilege(
        'fieldwiring_app',
        'public.directus_users',
        'SELECT'
    ) AS app_direct_directus_user_read;
