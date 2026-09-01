/* ============================================================================
Controller Inventory — browser authorization contract
Issue: #110
Revision: 2026-08-31 V0.1.0

Purpose:
  Expose the existing Directus user/role/policy authority to the protected
  Controller browser without granting fieldwiring_app direct access to
  Directus system tables.

Authentication boundary:
  Cloudflare Access authenticates https://my.sheboyganlights.org and supplies
  Cf-Access-Authenticated-User-Email to the protected backend. This function
  does not authenticate a browser request; it maps an already-authenticated
  email to the existing Directus authorization model.

Accepted capabilities:
  - Production Crew / Volunteer: request Controller labels.
  - Manager: label request + Controller maintenance.
  - Administrator/admin_access: label request + Controller maintenance.
  - Read-only / unknown Directus users: no Controller write capability.

Security:
  - SECURITY DEFINER keeps public.directus_* hidden from fieldwiring_app.
  - fieldwiring_app receives EXECUTE only.
  - No table INSERT/UPDATE/DELETE grant is added.
  - This migration enables authorization lookup only; it performs no writes to
    ref.controller*.
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
        RAISE EXCEPTION 'Required role fieldwiring_app does not exist';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.directus_roles WHERE name = 'Production Crew'
    ) THEN
        RAISE EXCEPTION 'Directus Production Crew role is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.directus_roles WHERE name = 'Manager'
    ) THEN
        RAISE EXCEPTION 'Directus Manager role is missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.directus_roles WHERE name = 'Administrator'
    ) THEN
        RAISE EXCEPTION 'Directus Administrator role is missing';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ref.controller_browser_capabilities(p_email text)
RETURNS TABLE (
    email text,
    display_name text,
    role_name text,
    policy_names text[],
    can_print_label boolean,
    can_manage_controllers boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, ref
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
                JOIN public.directus_policies p
                  ON p.id = a.policy
                WHERE a."user" = u.user_id
                   OR (u.role_id IS NOT NULL AND a.role = u.role_id)
                ORDER BY p.name
            ) AS policy_names,
            (
                u.role_name IN ('Manager', 'Administrator')
                OR EXISTS (
                    SELECT 1
                    FROM public.directus_access a
                    JOIN public.directus_policies p
                      ON p.id = a.policy
                    WHERE (
                        a."user" = u.user_id
                        OR (u.role_id IS NOT NULL AND a.role = u.role_id)
                    )
                      AND (p.admin_access OR p.name IN ('Manager', 'Administrator'))
                )
            ) AS can_manage
        FROM user_row u
    )
    SELECT
        r.email,
        coalesce(r.display_name, r.email) AS display_name,
        r.role_name,
        r.policy_names,
        (
            r.can_manage
            OR r.role_name = 'Production Crew'
            OR 'Volunteer' = ANY(r.policy_names)
        ) AS can_print_label,
        r.can_manage AS can_manage_controllers
    FROM resolved r;
$function$;

REVOKE ALL ON FUNCTION ref.controller_browser_capabilities(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.controller_browser_capabilities(text) TO fieldwiring_app;

COMMIT;

SELECT
    p.proname AS function_name,
    has_function_privilege(
        'fieldwiring_app',
        'ref.controller_browser_capabilities(text)',
        'EXECUTE'
    ) AS fieldwiring_can_execute,
    has_table_privilege('fieldwiring_app', 'public.directus_users', 'SELECT')
        AS fieldwiring_direct_directus_user_read,
    has_table_privilege('fieldwiring_app', 'ref.controller', 'UPDATE')
        AS fieldwiring_controller_update
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'ref'
  AND p.proname = 'controller_browser_capabilities';
