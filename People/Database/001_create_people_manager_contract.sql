/* ============================================================================
People Manager — Milestone 1 browser command contract
Issue: #130
Revision: 2026-09-09 V0.1.0

Purpose:
  Provide a least-privilege PostgreSQL boundary for the first People Manager
  vertical slice: search, contact maintenance, active/inactive lifecycle,
  duplicate review, reserved Sheboygan Lights email candidates, and relationship
  visibility for ref.person.

Security / identity boundary:
  - Cloudflare Access authenticates the browser user.
  - Directus current role/policy data remains application authorization authority.
  - Only Manager / Administrator / admin_access users may manage People.
  - Human writes fail closed unless the active Directus user maps to ref.person.
  - people_app receives EXECUTE only on narrow SECURITY DEFINER functions.
  - No direct INSERT/UPDATE/DELETE grant is added on ref.person.
  - directus_user_id, pg_login_name, is_manager, is_team, and
    available_for_work_orders are not writable through Milestone 1.
  - Existing ref.person actor/audit triggers remain authoritative through
    transaction-local app.directus_user_uuid.
  - No person DELETE function is created.

Identity rules:
  - ref.person.email is the reserved/current @sheboyganlights.org system identity.
  - ref.person.personal_email is personal/contact email.
  - Manual create reserves the established first-initial + last-name MSB email
    when available. A collision must be reviewed explicitly; it is never
    silently renumbered or reused.
  - A Directus-linked person's MSB email is protected from ordinary contact edit.
  - Inactive people are preserved and may later be reactivated.
============================================================================ */

BEGIN;

DO $preflight$
DECLARE
    v_missing text;
BEGIN
    IF to_regclass('ref.person') IS NULL THEN
        RAISE EXCEPTION 'ref.person is required';
    END IF;

    IF to_regclass('public.directus_users') IS NULL
       OR to_regclass('public.directus_roles') IS NULL
       OR to_regclass('public.directus_access') IS NULL
       OR to_regclass('public.directus_policies') IS NULL THEN
        RAISE EXCEPTION 'Required Directus authorization tables are missing';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'people_app') THEN
        RAISE EXCEPTION
            'Required role people_app does not exist; create the LOGIN separately with a secured password';
    END IF;

    SELECT string_agg(required.column_name, ', ' ORDER BY required.column_name)
      INTO v_missing
    FROM (
        VALUES
            ('person_id'),
            ('first_name'),
            ('last_name'),
            ('preferred_name'),
            ('email'),
            ('personal_email'),
            ('cell_phone'),
            ('active_flag'),
            ('is_manager'),
            ('is_team'),
            ('directus_user_id'),
            ('pg_login_name'),
            ('available_for_work_orders'),
            ('created_at'),
            ('updated_at')
    ) AS required(column_name)
    WHERE NOT EXISTS (
        SELECT 1
        FROM information_schema.columns c
        WHERE c.table_schema = 'ref'
          AND c.table_name = 'person'
          AND c.column_name = required.column_name
    );

    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'ref.person is missing required columns: %', v_missing;
    END IF;

    IF to_regprocedure('ref.resolve_actor()') IS NULL
       OR to_regprocedure('ref.set_actor_on_insert()') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL THEN
        RAISE EXCEPTION 'Existing MSB actor/audit functions are required';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_trigger t
        WHERE t.tgrelid = 'ref.person'::regclass
          AND NOT t.tgisinternal
          AND t.tgname = 'trg_person_set_actor_insert'
    ) OR NOT EXISTS (
        SELECT 1
        FROM pg_trigger t
        WHERE t.tgrelid = 'ref.person'::regclass
          AND NOT t.tgisinternal
          AND t.tgname = 'trg_person_set_actor_update'
    ) THEN
        RAISE EXCEPTION 'Expected ref.person actor/audit triggers are missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes i
        WHERE i.schemaname = 'ref'
          AND i.tablename = 'person'
          AND i.indexdef ILIKE '%UNIQUE%'
          AND replace(lower(i.indexdef), ' ', '') LIKE '%lower(email)%'
    ) THEN
        RAISE EXCEPTION 'Expected case-insensitive unique protection on ref.person.email is missing';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ref.people_browser_capabilities(p_email text)
RETURNS TABLE (
    email text,
    display_name text,
    role_name text,
    policy_names text[],
    can_manage_people boolean
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
        r.can_manage AS can_manage_people
    FROM resolved r;
$function$;

REVOKE ALL ON FUNCTION ref.people_browser_capabilities(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.people_browser_capabilities(text) TO people_app;

CREATE OR REPLACE FUNCTION ref.people_management_actor(p_email text)
RETURNS TABLE (
    directus_user_id uuid,
    person_id integer,
    display_name text
)
LANGUAGE plpgsql
STABLE
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
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Authenticated People Manager email is required';
    END IF;

    SELECT
        u.id,
        c.display_name,
        c.can_manage_people
      INTO
        v_directus_user_id,
        v_display_name,
        v_can_manage
    FROM public.directus_users AS u
    JOIN LATERAL ref.people_browser_capabilities(v_email) AS c
      ON true
    WHERE u.status = 'active'
      AND lower(u.email) = v_email
    LIMIT 1;

    IF v_directus_user_id IS NULL OR coalesce(v_can_manage, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'People Manager is not authorized for this account';
    END IF;

    SELECT p.person_id
      INTO v_person_id
    FROM ref.person AS p
    WHERE p.directus_user_id = v_directus_user_id
    LIMIT 1;

    IF v_person_id IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Authenticated People Manager operator is not mapped to an MSB person';
    END IF;

    RETURN QUERY
    SELECT
        v_directus_user_id,
        v_person_id,
        coalesce(nullif(btrim(v_display_name), ''), v_email);
END;
$function$;

REVOKE ALL ON FUNCTION ref.people_management_actor(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.people_management_actor(text) FROM people_app;

CREATE OR REPLACE FUNCTION ref.people_email_local_part(p_value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
STRICT
SET search_path = pg_catalog
AS $function$
    SELECT regexp_replace(lower(btrim(p_value)), '[^a-z0-9]+', '', 'g');
$function$;

REVOKE ALL ON FUNCTION ref.people_email_local_part(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.people_email_local_part(text) FROM people_app;

CREATE OR REPLACE FUNCTION ref.people_email_candidates(
    p_operator_email text,
    p_first_name text,
    p_last_name text,
    p_exclude_person_id integer DEFAULT NULL
)
RETURNS TABLE (
    candidate_email text,
    candidate_rank integer,
    is_standard boolean,
    is_available boolean,
    conflicting_person_id integer,
    conflicting_source text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_first text;
    v_last text;
    v_excluded_directus uuid;
BEGIN
    PERFORM 1 FROM ref.people_management_actor(p_operator_email);

    v_first := ref.people_email_local_part(p_first_name);
    v_last := ref.people_email_local_part(p_last_name);

    IF coalesce(v_first, '') = '' OR coalesce(v_last, '') = '' THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'First and last name are required to build an MSB email';
    END IF;

    IF p_exclude_person_id IS NOT NULL THEN
        SELECT p.directus_user_id
          INTO v_excluded_directus
        FROM ref.person p
        WHERE p.person_id = p_exclude_person_id;
    END IF;

    RETURN QUERY
    WITH candidates AS (
        SELECT
            (left(v_first, n) || v_last || '@sheboyganlights.org')::text AS email_value,
            n::integer AS rank_value
        FROM generate_series(1, length(v_first)) AS gs(n)
    ),
    evaluated AS (
        SELECT
            c.email_value,
            c.rank_value,
            p.person_id AS person_conflict,
            EXISTS (
                SELECT 1
                FROM public.directus_users u
                WHERE lower(u.email) = lower(c.email_value)
                  AND (v_excluded_directus IS NULL OR u.id <> v_excluded_directus)
            ) AS directus_conflict
        FROM candidates c
        LEFT JOIN LATERAL (
            SELECT p0.person_id
            FROM ref.person p0
            WHERE lower(p0.email) = lower(c.email_value)
              AND (p_exclude_person_id IS NULL OR p0.person_id <> p_exclude_person_id)
            LIMIT 1
        ) p ON true
    )
    SELECT
        e.email_value,
        e.rank_value,
        e.rank_value = 1,
        e.person_conflict IS NULL AND NOT e.directus_conflict,
        e.person_conflict,
        CASE
            WHEN e.person_conflict IS NOT NULL THEN 'PERSON'
            WHEN e.directus_conflict THEN 'DIRECTUS'
            ELSE NULL
        END
    FROM evaluated e
    ORDER BY e.rank_value;
END;
$function$;

REVOKE ALL ON FUNCTION ref.people_email_candidates(text, text, text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.people_email_candidates(text, text, text, integer) TO people_app;

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
          OR coalesce(p.cell_phone, '') ILIKE '%' || regexp_replace(v_query, '[^0-9]+', '', 'g') || '%'
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

CREATE OR REPLACE FUNCTION ref.people_person_detail(
    p_operator_email text,
    p_person_id integer
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
    is_manager boolean,
    is_team boolean,
    available_for_work_orders boolean,
    created_at timestamptz,
    updated_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
BEGIN
    PERFORM 1 FROM ref.people_management_actor(p_operator_email);

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
        p.is_manager,
        p.is_team,
        p.available_for_work_orders,
        p.created_at,
        p.updated_at
    FROM ref.person p
    WHERE p.person_id = p_person_id;
END;
$function$;

REVOKE ALL ON FUNCTION ref.people_person_detail(text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.people_person_detail(text, integer) TO people_app;

CREATE OR REPLACE FUNCTION ref.people_duplicate_candidates(
    p_operator_email text,
    p_first_name text,
    p_last_name text,
    p_email text,
    p_personal_email text,
    p_cell_phone text,
    p_exclude_person_id integer DEFAULT NULL
)
RETURNS TABLE (
    person_id integer,
    display_name text,
    active_flag boolean,
    email text,
    personal_email text,
    cell_phone text,
    match_name boolean,
    match_msb_email boolean,
    match_personal_email boolean,
    match_phone boolean,
    match_level text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_first text := lower(btrim(coalesce(p_first_name, '')));
    v_last text := lower(btrim(coalesce(p_last_name, '')));
    v_email text := lower(btrim(coalesce(p_email, '')));
    v_personal text := lower(btrim(coalesce(p_personal_email, '')));
    v_phone text := regexp_replace(coalesce(p_cell_phone, ''), '[^0-9]+', '', 'g');
BEGIN
    PERFORM 1 FROM ref.people_management_actor(p_operator_email);

    RETURN QUERY
    WITH matches AS (
        SELECT
            p.person_id,
            coalesce(
                nullif(btrim(concat_ws(' ', p.preferred_name, p.last_name)), ''),
                nullif(btrim(concat_ws(' ', p.first_name, p.last_name)), ''),
                p.first_name
            ) AS display_name,
            p.active_flag,
            p.email,
            p.personal_email,
            p.cell_phone,
            (
                v_first <> '' AND v_last <> ''
                AND lower(btrim(p.first_name)) = v_first
                AND lower(btrim(coalesce(p.last_name, ''))) = v_last
            ) AS match_name,
            (
                v_email <> '' AND lower(btrim(coalesce(p.email, ''))) = v_email
            ) AS match_msb_email,
            (
                v_personal <> ''
                AND lower(btrim(coalesce(p.personal_email, ''))) = v_personal
            ) AS match_personal_email,
            (
                length(v_phone) = 10
                AND regexp_replace(coalesce(p.cell_phone, ''), '[^0-9]+', '', 'g') = v_phone
            ) AS match_phone
        FROM ref.person p
        WHERE p_exclude_person_id IS NULL OR p.person_id <> p_exclude_person_id
    )
    SELECT
        m.person_id,
        m.display_name,
        m.active_flag,
        m.email,
        m.personal_email,
        m.cell_phone,
        m.match_name,
        m.match_msb_email,
        m.match_personal_email,
        m.match_phone,
        CASE
            WHEN m.match_msb_email THEN 'CONFLICT'
            WHEN (m.match_personal_email OR m.match_phone) AND m.match_name THEN 'STRONG_WARNING'
            WHEN m.match_personal_email OR m.match_phone THEN 'STRONG_WARNING'
            ELSE 'WARNING'
        END AS match_level
    FROM matches m
    WHERE m.match_name
       OR m.match_msb_email
       OR m.match_personal_email
       OR m.match_phone
    ORDER BY
        CASE
            WHEN m.match_msb_email THEN 0
            WHEN m.match_personal_email OR m.match_phone THEN 1
            ELSE 2
        END,
        m.active_flag DESC,
        m.display_name,
        m.person_id
    LIMIT 50;
END;
$function$;

REVOKE ALL ON FUNCTION ref.people_duplicate_candidates(text, text, text, text, text, text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.people_duplicate_candidates(text, text, text, text, text, text, integer) TO people_app;

CREATE OR REPLACE FUNCTION ref.people_person_dependencies(
    p_operator_email text,
    p_person_id integer
)
RETURNS TABLE (
    schema_name text,
    table_name text,
    column_name text,
    constraint_name text,
    reference_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    r record;
    v_count bigint;
    v_person_attnum smallint;
BEGIN
    PERFORM 1 FROM ref.people_management_actor(p_operator_email);

    IF NOT EXISTS (SELECT 1 FROM ref.person p WHERE p.person_id = p_person_id) THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Person was not found';
    END IF;

    SELECT a.attnum
      INTO v_person_attnum
    FROM pg_attribute a
    WHERE a.attrelid = 'ref.person'::regclass
      AND a.attname = 'person_id'
      AND NOT a.attisdropped;

    FOR r IN
        SELECT
            n.nspname AS schema_name,
            c.relname AS table_name,
            a.attname AS column_name,
            con.conname AS constraint_name
        FROM pg_constraint con
        JOIN pg_class c ON c.oid = con.conrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        JOIN pg_attribute a
          ON a.attrelid = con.conrelid
         AND a.attnum = con.conkey[1]
        WHERE con.contype = 'f'
          AND con.confrelid = 'ref.person'::regclass
          AND array_length(con.conkey, 1) = 1
          AND array_length(con.confkey, 1) = 1
          AND con.confkey[1] = v_person_attnum
        ORDER BY n.nspname, c.relname, a.attname, con.conname
    LOOP
        EXECUTE format(
            'SELECT count(*) FROM %I.%I WHERE %I = $1',
            r.schema_name,
            r.table_name,
            r.column_name
        )
        INTO v_count
        USING p_person_id;

        IF v_count > 0 THEN
            schema_name := r.schema_name;
            table_name := r.table_name;
            column_name := r.column_name;
            constraint_name := r.constraint_name;
            reference_count := v_count;
            RETURN NEXT;
        END IF;
    END LOOP;
END;
$function$;

REVOKE ALL ON FUNCTION ref.people_person_dependencies(text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.people_person_dependencies(text, integer) TO people_app;

CREATE OR REPLACE FUNCTION ref.create_person_from_people_manager(
    p_operator_email text,
    p_first_name text,
    p_last_name text,
    p_preferred_name text,
    p_reserved_email text,
    p_personal_email text,
    p_cell_phone text,
    p_active_flag boolean,
    p_duplicate_review_ack boolean DEFAULT false,
    p_email_exception_ack boolean DEFAULT false
)
RETURNS TABLE (
    person_id integer,
    reserved_email text,
    updated_at timestamptz,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_operator_person_id integer;
    v_operator_display_name text;
    v_first text := btrim(coalesce(p_first_name, ''));
    v_last text := btrim(coalesce(p_last_name, ''));
    v_preferred text := nullif(btrim(coalesce(p_preferred_name, '')), '');
    v_personal text := nullif(lower(btrim(coalesce(p_personal_email, ''))), '');
    v_phone text := nullif(regexp_replace(coalesce(p_cell_phone, ''), '[^0-9]+', '', 'g'), '');
    v_first_slug text;
    v_last_slug text;
    v_standard_email text;
    v_reserved text := nullif(lower(btrim(coalesce(p_reserved_email, ''))), '');
    v_person_id integer;
    v_updated_at timestamptz;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_operator_person_id, v_operator_display_name
    FROM ref.people_management_actor(p_operator_email) a;

    IF v_first = '' OR v_last = '' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'First and last name are required';
    END IF;

    IF v_phone IS NOT NULL AND length(v_phone) <> 10 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Cell phone must contain exactly 10 digits';
    END IF;

    v_first_slug := ref.people_email_local_part(v_first);
    v_last_slug := ref.people_email_local_part(v_last);
    IF coalesce(v_first_slug, '') = '' OR coalesce(v_last_slug, '') = '' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'First and last name cannot build a valid MSB email';
    END IF;
    v_standard_email := left(v_first_slug, 1) || v_last_slug || '@sheboyganlights.org';

    IF v_reserved IS NULL THEN
        v_reserved := v_standard_email;
    END IF;

    IF v_reserved !~ '^[a-z0-9][a-z0-9._-]*@sheboyganlights[.]org$' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'MSB email must use the sheboyganlights.org domain';
    END IF;

    IF v_reserved <> v_standard_email AND coalesce(p_email_exception_ack, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0001',
            MESSAGE = 'Non-standard MSB email requires explicit collision/exception review';
    END IF;

    IF EXISTS (SELECT 1 FROM ref.person p WHERE lower(p.email) = v_reserved)
       OR EXISTS (SELECT 1 FROM public.directus_users u WHERE lower(u.email) = v_reserved) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23505',
            MESSAGE = 'Reserved MSB email is already in use; review an alternate before creating the person';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.people_duplicate_candidates(
            p_operator_email,
            v_first,
            v_last,
            v_reserved,
            v_personal,
            v_phone,
            NULL
        ) d
    ) AND coalesce(p_duplicate_review_ack, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0001',
            MESSAGE = 'Potential duplicate person requires review before create';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    INSERT INTO ref.person (
        first_name,
        last_name,
        preferred_name,
        email,
        personal_email,
        cell_phone,
        active_flag
    ) VALUES (
        v_first,
        v_last,
        v_preferred,
        v_reserved,
        v_personal,
        v_phone,
        coalesce(p_active_flag, true)
    )
    RETURNING ref.person.person_id, ref.person.updated_at
      INTO v_person_id, v_updated_at;

    RETURN QUERY
    SELECT v_person_id, v_reserved, v_updated_at, v_operator_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.create_person_from_people_manager(text, text, text, text, text, text, text, boolean, boolean, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.create_person_from_people_manager(text, text, text, text, text, text, text, boolean, boolean, boolean) TO people_app;

CREATE OR REPLACE FUNCTION ref.update_person_from_people_manager(
    p_operator_email text,
    p_person_id integer,
    p_first_name text,
    p_last_name text,
    p_preferred_name text,
    p_reserved_email text,
    p_personal_email text,
    p_cell_phone text,
    p_active_flag boolean,
    p_expected_updated_at timestamptz,
    p_duplicate_review_ack boolean DEFAULT false,
    p_email_exception_ack boolean DEFAULT false
)
RETURNS TABLE (
    person_id integer,
    reserved_email text,
    updated_at timestamptz,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_operator_person_id integer;
    v_operator_display_name text;
    v_old ref.person%ROWTYPE;
    v_first text := btrim(coalesce(p_first_name, ''));
    v_last text := btrim(coalesce(p_last_name, ''));
    v_preferred text := nullif(btrim(coalesce(p_preferred_name, '')), '');
    v_personal text := nullif(lower(btrim(coalesce(p_personal_email, ''))), '');
    v_phone text := nullif(regexp_replace(coalesce(p_cell_phone, ''), '[^0-9]+', '', 'g'), '');
    v_first_slug text;
    v_last_slug text;
    v_standard_email text;
    v_reserved text := nullif(lower(btrim(coalesce(p_reserved_email, ''))), '');
    v_identity_changed boolean;
    v_updated_at timestamptz;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_operator_person_id, v_operator_display_name
    FROM ref.people_management_actor(p_operator_email) a;

    SELECT p.*
      INTO v_old
    FROM ref.person p
    WHERE p.person_id = p_person_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002', MESSAGE = 'Person was not found';
    END IF;

    IF p_expected_updated_at IS NULL OR v_old.updated_at IS DISTINCT FROM p_expected_updated_at THEN
        RAISE EXCEPTION USING
            ERRCODE = '40001',
            MESSAGE = 'Person changed after this form was loaded; reload before saving';
    END IF;

    IF v_first = '' OR v_last = '' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'First and last name are required';
    END IF;

    IF v_phone IS NOT NULL AND length(v_phone) <> 10 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Cell phone must contain exactly 10 digits';
    END IF;

    v_first_slug := ref.people_email_local_part(v_first);
    v_last_slug := ref.people_email_local_part(v_last);
    IF coalesce(v_first_slug, '') = '' OR coalesce(v_last_slug, '') = '' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'First and last name cannot build a valid MSB email';
    END IF;
    v_standard_email := left(v_first_slug, 1) || v_last_slug || '@sheboyganlights.org';

    IF v_reserved IS NULL THEN
        IF v_old.directus_user_id IS NOT NULL THEN
            v_reserved := lower(btrim(v_old.email));
        ELSE
            v_reserved := v_standard_email;
        END IF;
    END IF;

    IF v_reserved !~ '^[a-z0-9][a-z0-9._-]*@sheboyganlights[.]org$' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'MSB email must use the sheboyganlights.org domain';
    END IF;

    IF v_old.directus_user_id IS NOT NULL
       AND lower(btrim(coalesce(v_old.email, ''))) IS DISTINCT FROM v_reserved THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Directus-linked MSB email is protected; use the governed identity-change workflow';
    END IF;

    IF lower(btrim(coalesce(v_old.email, ''))) IS DISTINCT FROM v_reserved
       AND v_reserved <> v_standard_email
       AND coalesce(p_email_exception_ack, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0001',
            MESSAGE = 'Non-standard MSB email requires explicit collision/exception review';
    END IF;

    IF EXISTS (
        SELECT 1 FROM ref.person p
        WHERE p.person_id <> p_person_id
          AND lower(p.email) = v_reserved
    ) OR EXISTS (
        SELECT 1 FROM public.directus_users u
        WHERE lower(u.email) = v_reserved
          AND (v_old.directus_user_id IS NULL OR u.id <> v_old.directus_user_id)
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23505',
            MESSAGE = 'Reserved MSB email is already in use; review an alternate before saving';
    END IF;

    v_identity_changed :=
        v_old.first_name IS DISTINCT FROM v_first
        OR coalesce(v_old.last_name, '') IS DISTINCT FROM v_last
        OR coalesce(v_old.email, '') IS DISTINCT FROM v_reserved
        OR coalesce(v_old.personal_email, '') IS DISTINCT FROM coalesce(v_personal, '')
        OR coalesce(v_old.cell_phone, '') IS DISTINCT FROM coalesce(v_phone, '');

    IF v_identity_changed AND EXISTS (
        SELECT 1
        FROM ref.people_duplicate_candidates(
            p_operator_email,
            v_first,
            v_last,
            v_reserved,
            v_personal,
            v_phone,
            p_person_id
        ) d
    ) AND coalesce(p_duplicate_review_ack, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0001',
            MESSAGE = 'Potential duplicate person requires review before save';
    END IF;

    PERFORM pg_catalog.set_config('app.directus_user_uuid', v_directus_user_id::text, true);

    UPDATE ref.person p
       SET first_name = v_first,
           last_name = v_last,
           preferred_name = v_preferred,
           email = v_reserved,
           personal_email = v_personal,
           cell_phone = v_phone,
           active_flag = coalesce(p_active_flag, v_old.active_flag)
     WHERE p.person_id = p_person_id
     RETURNING p.updated_at INTO v_updated_at;

    RETURN QUERY
    SELECT p_person_id, v_reserved, v_updated_at, v_operator_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.update_person_from_people_manager(text, integer, text, text, text, text, text, text, boolean, timestamptz, boolean, boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.update_person_from_people_manager(text, integer, text, text, text, text, text, text, boolean, timestamptz, boolean, boolean) TO people_app;

/* Explicit least-privilege boundary. The service role reads/writes ref.person only
   through the functions above. */
GRANT CONNECT ON DATABASE msb TO people_app;
GRANT USAGE ON SCHEMA ref TO people_app;
REVOKE ALL ON TABLE ref.person FROM people_app;
REVOKE ALL ON TABLE public.directus_users FROM people_app;
REVOKE ALL ON TABLE public.directus_roles FROM people_app;
REVOKE ALL ON TABLE public.directus_access FROM people_app;
REVOKE ALL ON TABLE public.directus_policies FROM people_app;

COMMIT;

SELECT
    '2026-09-09-people-manager-contract-v0.1.0' AS applied_revision,
    current_user AS applied_by,
    has_function_privilege('people_app', 'ref.people_search(text,text,boolean)', 'EXECUTE')
        AS people_app_can_search,
    has_function_privilege(
        'people_app',
        'ref.create_person_from_people_manager(text,text,text,text,text,text,text,boolean,boolean,boolean)',
        'EXECUTE'
    ) AS people_app_can_create,
    has_table_privilege('people_app', 'ref.person', 'INSERT') AS people_app_direct_person_insert,
    has_table_privilege('people_app', 'ref.person', 'UPDATE') AS people_app_direct_person_update,
    has_table_privilege('people_app', 'ref.person', 'DELETE') AS people_app_direct_person_delete;
