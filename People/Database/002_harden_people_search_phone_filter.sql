/* ============================================================================
People Manager — harden phone token in person search
Issue: #130
Revision: 2026-09-09 V0.1.1

Purpose:
  Prevent a non-numeric search term from producing an empty normalized phone
  token and therefore matching every row through LIKE '%%'.

Boundary:
  This replaces only ref.people_search(text,text,boolean). It does not change
  People Manager authorization, write behavior, identity fields, or Production
  data.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regprocedure('ref.people_management_actor(text)') IS NULL THEN
        RAISE EXCEPTION 'ref.people_management_actor(text) is required first';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'people_app') THEN
        RAISE EXCEPTION 'Required role people_app does not exist';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ref.people_search(
    p_operator_email text,
    p_query text,
    p_include_inactive boolean DEFAULT false
)
RETURNS TABLE (
    person_id integer,
    first_name text,
    last_name text,
    preferred_name text,
    email text,
    personal_email text,
    cell_phone text,
    active_flag boolean,
    directus_linked boolean,
    postgres_login_linked boolean,
    updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_query text := btrim(coalesce(p_query, ''));
    v_like text;
    v_phone_query text := regexp_replace(coalesce(p_query, ''), '[^0-9]+', '', 'g');
BEGIN
    PERFORM 1 FROM ref.people_management_actor(p_operator_email);
    v_like := '%' || v_query || '%';

    RETURN QUERY
    SELECT
        p.person_id,
        p.first_name,
        p.last_name,
        p.preferred_name,
        p.email,
        p.personal_email,
        p.cell_phone,
        p.active_flag,
        p.directus_user_id IS NOT NULL,
        nullif(btrim(p.pg_login_name), '') IS NOT NULL,
        p.updated_at
    FROM ref.person p
    WHERE (coalesce(p_include_inactive, false) OR p.active_flag)
      AND (
          v_query = ''
          OR p.person_id::text = v_query
          OR p.first_name ILIKE v_like
          OR coalesce(p.preferred_name, '') ILIKE v_like
          OR coalesce(p.last_name, '') ILIKE v_like
          OR coalesce(p.email, '') ILIKE v_like
          OR coalesce(p.personal_email, '') ILIKE v_like
          OR (
              v_phone_query <> ''
              AND coalesce(p.cell_phone, '') LIKE '%' || v_phone_query || '%'
          )
      )
    ORDER BY
        CASE WHEN p.active_flag THEN 0 ELSE 1 END,
        coalesce(nullif(p.last_name, ''), p.first_name),
        p.first_name,
        p.person_id
    LIMIT 200;
END;
$function$;

REVOKE ALL ON FUNCTION ref.people_search(text, text, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.people_search(text, text, boolean) TO people_app;

COMMIT;

SELECT
    '2026-09-09-people-search-phone-filter-v0.1.1' AS applied_revision,
    current_user AS applied_by;
