/* ============================================================================
Filename: 004_stop_automatic_msb_email_generation.sql

Purpose:
  Stop People Manager from inventing/reserving a Sheboygan Lights email when
  a Person does not have a real Google Workspace account.

Contract:
  - ref.person.email may remain NULL.
  - A supplied ref.person.email must be a sheboyganlights.org address.
  - A supplied email remains collision-protected across ref.person and Directus.
  - Directus-linked MSB email remains protected from ordinary contact editing.
  - Blank email on an unlinked Person stays NULL; it is not synthesized.
  - Blank email on a Directus-linked Person preserves the existing linked email.

Safety:
  Replaces only the two governed People Manager contact-write functions.
  Does not update any existing ref.person rows.
============================================================================ */

BEGIN;

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

    IF v_reserved IS NOT NULL
       AND v_reserved !~ '^[a-z0-9][a-z0-9._-]*@sheboyganlights[.]org$' THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Sheboygan Lights email must use the sheboyganlights.org domain';
    END IF;

    IF v_reserved IS NOT NULL
       AND (
           EXISTS (SELECT 1 FROM ref.person p WHERE lower(p.email) = v_reserved)
           OR EXISTS (SELECT 1 FROM public.directus_users u WHERE lower(u.email) = v_reserved)
       ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23505',
            MESSAGE = 'Sheboygan Lights email is already in use';
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

    /* Ordinary People editing cannot clear or replace an established
       Directus-linked Google identity. */
    IF v_old.directus_user_id IS NOT NULL THEN
        IF v_reserved IS NULL THEN
            v_reserved := nullif(lower(btrim(coalesce(v_old.email, ''))), '');
        ELSIF lower(btrim(coalesce(v_old.email, ''))) IS DISTINCT FROM v_reserved THEN
            RAISE EXCEPTION USING
                ERRCODE = '22023',
                MESSAGE = 'Directus-linked MSB email is protected; use the governed identity-change workflow';
        END IF;
    END IF;

    IF v_reserved IS NOT NULL
       AND v_reserved !~ '^[a-z0-9][a-z0-9._-]*@sheboyganlights[.]org$' THEN
        RAISE EXCEPTION USING
            ERRCODE = '22023',
            MESSAGE = 'Sheboygan Lights email must use the sheboyganlights.org domain';
    END IF;

    IF v_reserved IS NOT NULL
       AND (
           EXISTS (
               SELECT 1
               FROM ref.person p
               WHERE p.person_id <> p_person_id
                 AND lower(p.email) = v_reserved
           )
           OR EXISTS (
               SELECT 1
               FROM public.directus_users u
               WHERE lower(u.email) = v_reserved
                 AND (v_old.directus_user_id IS NULL OR u.id <> v_old.directus_user_id)
           )
       ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23505',
            MESSAGE = 'Sheboygan Lights email is already in use';
    END IF;

    v_identity_changed :=
        v_old.first_name IS DISTINCT FROM v_first
        OR coalesce(v_old.last_name, '') IS DISTINCT FROM v_last
        OR coalesce(v_old.email, '') IS DISTINCT FROM coalesce(v_reserved, '')
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

COMMIT;

SELECT
    '2026-10-01-stop-automatic-msb-email-generation-v0.2.1' AS applied_revision,
    current_user AS applied_by;
