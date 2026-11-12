/* ============================================================================
Controller Inventory — protected browser maintenance commands
Issue: #110
Revision: 2026-09-02 V0.1.0

Purpose:
  Add the permanent browser-native Controller maintenance command boundary for
  Add/Edit Controller and Controller-to-Display assignment management.

Security / identity boundary:
  - Cloudflare Access authenticates the browser user.
  - Directus current role/policy data remains Controller authorization authority.
  - Human writes fail closed unless the active Directus user maps to ref.person.
  - fieldwiring_app receives EXECUTE only on narrow SECURITY DEFINER commands.
  - No broad INSERT/UPDATE/DELETE grant is added on ref.controller*.
  - Existing ref.set_actor_on_insert/update -> ref.resolve_actor() triggers remain
    the audit authority through transaction-local app.directus_user_uuid.

Identity / data rules:
  - controller_id remains PostgreSQL-generated permanent identity.
  - Network/UID/IP/Stage/Display are mutable facts, never identity.
  - Controller-to-Display remains current-snapshot M:N.
  - Duplicate Network/UID programming remains valid.
  - Stage remains derived through Display assignment.
  - No normal Controller DELETE command is created.
============================================================================ */

BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.controller') IS NULL
       OR to_regclass('ref.controller_model') IS NULL
       OR to_regclass('ref.controller_status') IS NULL
       OR to_regclass('ref.controller_firmware_version') IS NULL
       OR to_regclass('ref.controller_display') IS NULL
       OR to_regclass('ref.controller_firmware_history') IS NULL
       OR to_regclass('ref.person') IS NULL
       OR to_regclass('ref.storage_location') IS NULL
       OR to_regclass('ref.display') IS NULL THEN
        RAISE EXCEPTION 'Permanent Controller maintenance dependencies are missing';
    END IF;

    IF to_regprocedure('ref.controller_browser_capabilities(text)') IS NULL THEN
        RAISE EXCEPTION 'ref.controller_browser_capabilities(text) is required first';
    END IF;

    IF to_regprocedure('ref.resolve_actor()') IS NULL
       OR to_regprocedure('ref.set_actor_on_insert()') IS NULL
       OR to_regprocedure('ref.set_actor_on_update()') IS NULL THEN
        RAISE EXCEPTION 'Existing MSB actor/audit functions are required';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

CREATE OR REPLACE FUNCTION ref.controller_management_actor(p_email text)
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
            MESSAGE = 'Authenticated Controller operator email is required';
    END IF;

    SELECT
        u.id,
        c.display_name,
        c.can_manage_controllers
      INTO
        v_directus_user_id,
        v_display_name,
        v_can_manage
    FROM public.directus_users AS u
    JOIN LATERAL ref.controller_browser_capabilities(v_email) AS c
      ON true
    WHERE u.status = 'active'
      AND lower(u.email) = v_email
    LIMIT 1;

    IF v_directus_user_id IS NULL OR coalesce(v_can_manage, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Controller maintenance is not authorized for this account';
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

    RETURN QUERY
    SELECT
        v_directus_user_id,
        v_person_id,
        coalesce(nullif(btrim(v_display_name), ''), v_email);
END;
$function$;

REVOKE ALL ON FUNCTION ref.controller_management_actor(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.controller_management_actor(text) FROM fieldwiring_app;

CREATE OR REPLACE FUNCTION ref.controller_management_options(p_email text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $function$
DECLARE
    v_result jsonb;
BEGIN
    -- Authorization is checked even though this function only returns controlled
    -- reference choices used by the Manager maintenance form.
    PERFORM 1 FROM ref.controller_management_actor(p_email);

    SELECT jsonb_build_object(
        'models', coalesce((
            SELECT jsonb_agg(x.item ORDER BY x.sort_key)
            FROM (
                SELECT
                    m.model_code AS sort_key,
                    jsonb_build_object(
                        'controller_model_id', m.controller_model_id,
                        'model_code', m.model_code,
                        'manufacturer', m.manufacturer,
                        'model_name', m.model_name,
                        'device_family', m.device_family,
                        'display_assignment_capable', m.display_assignment_capable,
                        'lor_uid_capacity', m.lor_uid_capacity,
                        'lor_uid_requires_full_capacity',
                            coalesce(m.lor_uid_requires_full_capacity, false)
                    ) AS item
                FROM ref.controller_model AS m
            ) AS x
        ), '[]'::jsonb),
        'statuses', coalesce((
            SELECT jsonb_agg(x.item ORDER BY x.sort_key)
            FROM (
                SELECT
                    s.controller_status_id AS sort_key,
                    jsonb_build_object(
                        'controller_status_id', s.controller_status_id,
                        'controller_status_name', s.controller_status_name,
                        'description', s.description
                    ) AS item
                FROM ref.controller_status AS s
            ) AS x
        ), '[]'::jsonb),
        'firmware_versions', coalesce((
            SELECT jsonb_agg(x.item ORDER BY x.model_key, x.version_key)
            FROM (
                SELECT
                    m.model_code AS model_key,
                    fv.firmware_version AS version_key,
                    jsonb_build_object(
                        'controller_firmware_version_id', fv.controller_firmware_version_id,
                        'controller_model_id', fv.controller_model_id,
                        'firmware_version', fv.firmware_version,
                        'is_current_recommended', fv.is_current_recommended
                    ) AS item
                FROM ref.controller_firmware_version AS fv
                JOIN ref.controller_model AS m
                  ON m.controller_model_id = fv.controller_model_id
            ) AS x
        ), '[]'::jsonb),
        'locations', coalesce((
            SELECT jsonb_agg(x.item ORDER BY x.sort_key)
            FROM (
                SELECT
                    l.location_code AS sort_key,
                    jsonb_build_object('location_code', l.location_code) AS item
                FROM ref.storage_location AS l
                WHERE l.location_code IS NOT NULL
            ) AS x
        ), '[]'::jsonb)
    ) INTO v_result;

    RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION ref.controller_management_options(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.controller_management_options(text) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ref.create_controller(
    p_email text,
    p_controller_model_id integer,
    p_controller_status_id integer,
    p_hardware_revision text,
    p_installed_firmware_version_id integer,
    p_firmware_verification_state text,
    p_firmware_verification_note text,
    p_serial_number text,
    p_year_deployed integer,
    p_current_location_code text,
    p_is_display_attached boolean,
    p_verification_state text,
    p_notes text,
    p_label_required boolean,
    p_lor_network text,
    p_lor_uid_start integer,
    p_lor_uid_count integer,
    p_management_ip text,
    p_programmed_config_verification_state text,
    p_programmed_config_source_note text
)
RETURNS TABLE (
    controller_id bigint,
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
    v_controller_id bigint;
    v_firmware_state text := upper(btrim(coalesce(p_firmware_verification_state, 'UNKNOWN')));
    v_programmed_state text := upper(btrim(coalesce(p_programmed_config_verification_state, 'UNKNOWN')));
    v_verification_state text := upper(btrim(coalesce(p_verification_state, 'FIELD_VERIFICATION_REQUIRED')));
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.controller_management_actor(p_email) AS a;

    IF p_controller_model_id IS NULL OR p_controller_status_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Controller Model and Status are required';
    END IF;

    IF p_installed_firmware_version_id IS NULL AND v_firmware_state <> 'UNKNOWN' THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Firmware state must be UNKNOWN when no installed firmware version is selected';
    END IF;

    IF p_installed_firmware_version_id IS NOT NULL
       AND v_firmware_state NOT IN ('RECORDED_UNVERIFIED', 'VERIFIED') THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Selected installed firmware must be RECORDED_UNVERIFIED or VERIFIED';
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    INSERT INTO ref.controller (
        controller_model_id,
        controller_status_id,
        hardware_revision,
        installed_firmware_version_id,
        firmware_verification_state,
        firmware_verified_at,
        firmware_verified_by_person_id,
        firmware_verification_note,
        serial_number,
        year_deployed,
        current_location_code,
        is_display_attached,
        verification_state,
        notes,
        label_required,
        lor_network,
        lor_uid_start,
        lor_uid_count,
        management_ip,
        programmed_config_verification_state,
        programmed_config_verified_at,
        programmed_config_verified_by_person_id,
        programmed_config_source_note
    )
    VALUES (
        p_controller_model_id,
        p_controller_status_id,
        nullif(btrim(p_hardware_revision), ''),
        p_installed_firmware_version_id,
        v_firmware_state,
        CASE WHEN v_firmware_state = 'VERIFIED' THEN now() ELSE NULL END,
        CASE WHEN v_firmware_state = 'VERIFIED' THEN v_person_id ELSE NULL END,
        nullif(btrim(p_firmware_verification_note), ''),
        nullif(btrim(p_serial_number), ''),
        p_year_deployed,
        nullif(btrim(p_current_location_code), ''),
        p_is_display_attached,
        v_verification_state,
        nullif(btrim(p_notes), ''),
        coalesce(p_label_required, true),
        nullif(btrim(p_lor_network), ''),
        p_lor_uid_start,
        p_lor_uid_count,
        CASE
            WHEN nullif(btrim(p_management_ip), '') IS NULL THEN NULL
            ELSE btrim(p_management_ip)::inet
        END,
        v_programmed_state,
        CASE WHEN v_programmed_state = 'VERIFIED' THEN now() ELSE NULL END,
        CASE WHEN v_programmed_state = 'VERIFIED' THEN v_person_id ELSE NULL END,
        nullif(btrim(p_programmed_config_source_note), '')
    )
    RETURNING ref.controller.controller_id INTO v_controller_id;

    IF p_installed_firmware_version_id IS NOT NULL THEN
        INSERT INTO ref.controller_firmware_history (
            controller_id,
            controller_firmware_version_id,
            verification_state,
            verified_at,
            verified_by_person_id,
            source_note
        ) VALUES (
            v_controller_id,
            p_installed_firmware_version_id,
            CASE WHEN v_firmware_state = 'VERIFIED'
                THEN 'VERIFIED' ELSE 'RECORDED_UNVERIFIED' END,
            CASE WHEN v_firmware_state = 'VERIFIED' THEN now() ELSE NULL END,
            CASE WHEN v_firmware_state = 'VERIFIED' THEN v_person_id ELSE NULL END,
            'Controller Management browser'
        );
    END IF;

    RETURN QUERY SELECT v_controller_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.create_controller(
    text, integer, integer, text, integer, text, text, text, integer, text,
    boolean, text, text, boolean, text, integer, integer, text, text, text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.create_controller(
    text, integer, integer, text, integer, text, text, text, integer, text,
    boolean, text, text, boolean, text, integer, integer, text, text, text
) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ref.update_controller(
    p_email text,
    p_controller_id bigint,
    p_controller_model_id integer,
    p_controller_status_id integer,
    p_hardware_revision text,
    p_installed_firmware_version_id integer,
    p_firmware_verification_state text,
    p_firmware_verification_note text,
    p_serial_number text,
    p_year_deployed integer,
    p_current_location_code text,
    p_is_display_attached boolean,
    p_verification_state text,
    p_notes text,
    p_label_required boolean,
    p_lor_network text,
    p_lor_uid_start integer,
    p_lor_uid_count integer,
    p_management_ip text,
    p_programmed_config_verification_state text,
    p_programmed_config_source_note text
)
RETURNS TABLE (
    controller_id bigint,
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
    v_old ref.controller%ROWTYPE;
    v_firmware_state text := upper(btrim(coalesce(p_firmware_verification_state, 'UNKNOWN')));
    v_programmed_state text := upper(btrim(coalesce(p_programmed_config_verification_state, 'UNKNOWN')));
    v_verification_state text := upper(btrim(coalesce(p_verification_state, 'FIELD_VERIFICATION_REQUIRED')));
    v_config_changed boolean;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.controller_management_actor(p_email) AS a;

    SELECT c.* INTO v_old
    FROM ref.controller AS c
    WHERE c.controller_id = p_controller_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = format('Controller %s was not found', p_controller_id);
    END IF;

    IF p_controller_model_id IS NULL OR p_controller_status_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Controller Model and Status are required';
    END IF;

    IF p_installed_firmware_version_id IS NULL AND v_firmware_state <> 'UNKNOWN' THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Firmware state must be UNKNOWN when no installed firmware version is selected';
    END IF;

    IF p_installed_firmware_version_id IS NOT NULL
       AND v_firmware_state NOT IN ('RECORDED_UNVERIFIED', 'VERIFIED') THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Selected installed firmware must be RECORDED_UNVERIFIED or VERIFIED';
    END IF;

    v_config_changed :=
        v_old.lor_network IS DISTINCT FROM nullif(btrim(p_lor_network), '')
        OR v_old.lor_uid_start IS DISTINCT FROM p_lor_uid_start
        OR v_old.lor_uid_count IS DISTINCT FROM p_lor_uid_count
        OR host(v_old.management_ip) IS DISTINCT FROM nullif(btrim(p_management_ip), '');

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    UPDATE ref.controller AS c
       SET controller_model_id = p_controller_model_id,
           controller_status_id = p_controller_status_id,
           hardware_revision = nullif(btrim(p_hardware_revision), ''),
           installed_firmware_version_id = p_installed_firmware_version_id,
           firmware_verification_state = v_firmware_state,
           firmware_verified_at = CASE
               WHEN v_firmware_state <> 'VERIFIED' THEN NULL
               WHEN v_old.installed_firmware_version_id IS DISTINCT FROM p_installed_firmware_version_id
                    OR v_old.firmware_verification_state IS DISTINCT FROM 'VERIFIED'
                   THEN now()
               ELSE v_old.firmware_verified_at
           END,
           firmware_verified_by_person_id = CASE
               WHEN v_firmware_state <> 'VERIFIED' THEN NULL
               WHEN v_old.installed_firmware_version_id IS DISTINCT FROM p_installed_firmware_version_id
                    OR v_old.firmware_verification_state IS DISTINCT FROM 'VERIFIED'
                   THEN v_person_id
               ELSE v_old.firmware_verified_by_person_id
           END,
           firmware_verification_note = nullif(btrim(p_firmware_verification_note), ''),
           serial_number = nullif(btrim(p_serial_number), ''),
           year_deployed = p_year_deployed,
           current_location_code = nullif(btrim(p_current_location_code), ''),
           is_display_attached = p_is_display_attached,
           verification_state = v_verification_state,
           notes = nullif(btrim(p_notes), ''),
           label_required = coalesce(p_label_required, c.label_required),
           lor_network = nullif(btrim(p_lor_network), ''),
           lor_uid_start = p_lor_uid_start,
           lor_uid_count = p_lor_uid_count,
           management_ip = CASE
               WHEN nullif(btrim(p_management_ip), '') IS NULL THEN NULL
               ELSE btrim(p_management_ip)::inet
           END,
           programmed_config_verification_state = v_programmed_state,
           programmed_config_verified_at = CASE
               WHEN v_programmed_state <> 'VERIFIED' THEN NULL
               WHEN v_config_changed
                    OR v_old.programmed_config_verification_state IS DISTINCT FROM 'VERIFIED'
                   THEN now()
               ELSE v_old.programmed_config_verified_at
           END,
           programmed_config_verified_by_person_id = CASE
               WHEN v_programmed_state <> 'VERIFIED' THEN NULL
               WHEN v_config_changed
                    OR v_old.programmed_config_verification_state IS DISTINCT FROM 'VERIFIED'
                   THEN v_person_id
               ELSE v_old.programmed_config_verified_by_person_id
           END,
           programmed_config_source_note = nullif(btrim(p_programmed_config_source_note), '')
     WHERE c.controller_id = p_controller_id;

    IF p_installed_firmware_version_id IS NOT NULL
       AND (
           v_old.installed_firmware_version_id IS DISTINCT FROM p_installed_firmware_version_id
           OR v_old.firmware_verification_state IS DISTINCT FROM v_firmware_state
       ) THEN
        INSERT INTO ref.controller_firmware_history (
            controller_id,
            controller_firmware_version_id,
            verification_state,
            verified_at,
            verified_by_person_id,
            source_note
        ) VALUES (
            p_controller_id,
            p_installed_firmware_version_id,
            CASE WHEN v_firmware_state = 'VERIFIED'
                THEN 'VERIFIED' ELSE 'RECORDED_UNVERIFIED' END,
            CASE WHEN v_firmware_state = 'VERIFIED' THEN now() ELSE NULL END,
            CASE WHEN v_firmware_state = 'VERIFIED' THEN v_person_id ELSE NULL END,
            'Controller Management browser'
        );
    END IF;

    RETURN QUERY SELECT p_controller_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.update_controller(
    text, bigint, integer, integer, text, integer, text, text, text, integer,
    text, boolean, text, text, boolean, text, integer, integer, text, text, text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.update_controller(
    text, bigint, integer, integer, text, integer, text, text, text, integer,
    text, boolean, text, text, boolean, text, integer, integer, text, text, text
) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ref.assign_controller_display(
    p_email text,
    p_controller_id bigint,
    p_display_id bigint,
    p_wiring_source_display_id bigint,
    p_placement_note text,
    p_notes text,
    p_mark_deployed boolean DEFAULT true
)
RETURNS TABLE (
    controller_id bigint,
    display_id bigint,
    controller_status_name text,
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
    v_status text;
    v_deployed_status_id integer;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.controller_management_actor(p_email) AS a;

    SELECT s.controller_status_name
      INTO v_status
    FROM ref.controller AS c
    JOIN ref.controller_status AS s
      ON s.controller_status_id = c.controller_status_id
    WHERE c.controller_id = p_controller_id
    FOR UPDATE OF c;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = format('Controller %s was not found', p_controller_id);
    END IF;

    IF v_status IN ('REPAIR', 'RETIRED') THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = format('Controller %s is %s and cannot be assigned until status is changed explicitly',
                             p_controller_id, v_status);
    END IF;

    PERFORM 1 FROM ref.display AS d
    WHERE d.display_id = p_display_id
      AND d.display_status_id = 1;
    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = format('Display %s is not an active assignable Display', p_display_id);
    END IF;

    IF p_wiring_source_display_id = p_display_id THEN
        p_wiring_source_display_id := NULL;
    END IF;

    IF p_wiring_source_display_id IS NOT NULL THEN
        PERFORM 1 FROM ref.display AS d
        WHERE d.display_id = p_wiring_source_display_id
          AND d.display_status_id = 1;
        IF NOT FOUND THEN
            RAISE EXCEPTION USING ERRCODE = '22023',
                MESSAGE = format('Wiring source Display %s is not active', p_wiring_source_display_id);
        END IF;
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    INSERT INTO ref.controller_display (
        controller_id,
        display_id,
        wiring_source_display_id,
        placement_note,
        notes
    ) VALUES (
        p_controller_id,
        p_display_id,
        p_wiring_source_display_id,
        nullif(btrim(p_placement_note), ''),
        nullif(btrim(p_notes), '')
    );

    IF v_status = 'AVAILABLE' AND coalesce(p_mark_deployed, true) THEN
        SELECT s.controller_status_id INTO v_deployed_status_id
        FROM ref.controller_status AS s
        WHERE s.controller_status_name = 'DEPLOYED';

        UPDATE ref.controller
           SET controller_status_id = v_deployed_status_id
         WHERE ref.controller.controller_id = p_controller_id;
        v_status := 'DEPLOYED';
    END IF;

    RETURN QUERY SELECT p_controller_id, p_display_id, v_status, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.assign_controller_display(
    text, bigint, bigint, bigint, text, text, boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.assign_controller_display(
    text, bigint, bigint, bigint, text, text, boolean
) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ref.update_controller_display_assignment(
    p_email text,
    p_controller_id bigint,
    p_display_id bigint,
    p_wiring_source_display_id bigint,
    p_placement_note text,
    p_notes text
)
RETURNS TABLE (
    controller_id bigint,
    display_id bigint,
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
    FROM ref.controller_management_actor(p_email) AS a;

    IF p_wiring_source_display_id = p_display_id THEN
        p_wiring_source_display_id := NULL;
    END IF;

    IF p_wiring_source_display_id IS NOT NULL THEN
        PERFORM 1 FROM ref.display AS d
        WHERE d.display_id = p_wiring_source_display_id
          AND d.display_status_id = 1;
        IF NOT FOUND THEN
            RAISE EXCEPTION USING ERRCODE = '22023',
                MESSAGE = format('Wiring source Display %s is not active', p_wiring_source_display_id);
        END IF;
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    UPDATE ref.controller_display AS cd
       SET wiring_source_display_id = p_wiring_source_display_id,
           placement_note = nullif(btrim(p_placement_note), ''),
           notes = nullif(btrim(p_notes), '')
     WHERE cd.controller_id = p_controller_id
       AND cd.display_id = p_display_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = format('Controller %s is not assigned to Display %s',
                             p_controller_id, p_display_id);
    END IF;

    RETURN QUERY SELECT p_controller_id, p_display_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.update_controller_display_assignment(
    text, bigint, bigint, bigint, text, text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.update_controller_display_assignment(
    text, bigint, bigint, bigint, text, text
) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ref.reassign_controller_display(
    p_email text,
    p_controller_id bigint,
    p_old_display_id bigint,
    p_new_display_id bigint,
    p_wiring_source_display_id bigint,
    p_placement_note text,
    p_notes text
)
RETURNS TABLE (
    controller_id bigint,
    old_display_id bigint,
    new_display_id bigint,
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
    FROM ref.controller_management_actor(p_email) AS a;

    IF p_old_display_id = p_new_display_id THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Replacement Display must be different from the current Display';
    END IF;

    PERFORM 1 FROM ref.controller_display AS cd
    WHERE cd.controller_id = p_controller_id
      AND cd.display_id = p_old_display_id
    FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = format('Controller %s is not assigned to Display %s',
                             p_controller_id, p_old_display_id);
    END IF;

    PERFORM 1 FROM ref.display AS d
    WHERE d.display_id = p_new_display_id
      AND d.display_status_id = 1;
    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = format('Display %s is not an active assignable Display', p_new_display_id);
    END IF;

    IF p_wiring_source_display_id = p_new_display_id THEN
        p_wiring_source_display_id := NULL;
    END IF;

    IF p_wiring_source_display_id IS NOT NULL THEN
        PERFORM 1 FROM ref.display AS d
        WHERE d.display_id = p_wiring_source_display_id
          AND d.display_status_id = 1;
        IF NOT FOUND THEN
            RAISE EXCEPTION USING ERRCODE = '22023',
                MESSAGE = format('Wiring source Display %s is not active', p_wiring_source_display_id);
        END IF;
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    INSERT INTO ref.controller_display (
        controller_id,
        display_id,
        wiring_source_display_id,
        placement_note,
        notes
    ) VALUES (
        p_controller_id,
        p_new_display_id,
        p_wiring_source_display_id,
        nullif(btrim(p_placement_note), ''),
        nullif(btrim(p_notes), '')
    );

    DELETE FROM ref.controller_display AS cd
    WHERE cd.controller_id = p_controller_id
      AND cd.display_id = p_old_display_id;

    RETURN QUERY SELECT p_controller_id, p_old_display_id, p_new_display_id, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.reassign_controller_display(
    text, bigint, bigint, bigint, bigint, text, text
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.reassign_controller_display(
    text, bigint, bigint, bigint, bigint, text, text
) TO fieldwiring_app;

CREATE OR REPLACE FUNCTION ref.unassign_controller_display(
    p_email text,
    p_controller_id bigint,
    p_display_id bigint,
    p_return_available boolean DEFAULT true
)
RETURNS TABLE (
    controller_id bigint,
    display_id bigint,
    remaining_assignment_count integer,
    controller_status_name text,
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
    v_remaining integer;
    v_status text;
    v_available_status_id integer;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.controller_management_actor(p_email) AS a;

    SELECT s.controller_status_name
      INTO v_status
    FROM ref.controller AS c
    JOIN ref.controller_status AS s
      ON s.controller_status_id = c.controller_status_id
    WHERE c.controller_id = p_controller_id
    FOR UPDATE OF c;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = format('Controller %s was not found', p_controller_id);
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    DELETE FROM ref.controller_display AS cd
    WHERE cd.controller_id = p_controller_id
      AND cd.display_id = p_display_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING
            ERRCODE = 'P0002',
            MESSAGE = format('Controller %s is not assigned to Display %s',
                             p_controller_id, p_display_id);
    END IF;

    SELECT count(*)::integer INTO v_remaining
    FROM ref.controller_display AS cd
    WHERE cd.controller_id = p_controller_id;

    IF v_remaining = 0
       AND v_status = 'DEPLOYED'
       AND coalesce(p_return_available, true) THEN
        SELECT s.controller_status_id INTO v_available_status_id
        FROM ref.controller_status AS s
        WHERE s.controller_status_name = 'AVAILABLE';

        UPDATE ref.controller
           SET controller_status_id = v_available_status_id
         WHERE ref.controller.controller_id = p_controller_id;
        v_status := 'AVAILABLE';
    END IF;

    RETURN QUERY
    SELECT p_controller_id, p_display_id, v_remaining, v_status, v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ref.unassign_controller_display(
    text, bigint, bigint, boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.unassign_controller_display(
    text, bigint, bigint, boolean
) TO fieldwiring_app;

COMMIT;

SELECT
    has_function_privilege('fieldwiring_app', 'ref.controller_management_options(text)', 'EXECUTE')
        AS can_read_controller_management_options,
    has_function_privilege(
        'fieldwiring_app',
        'ref.create_controller(text,integer,integer,text,integer,text,text,text,integer,text,boolean,text,text,boolean,text,integer,integer,text,text,text)',
        'EXECUTE'
    ) AS can_create_controller,
    has_function_privilege(
        'fieldwiring_app',
        'ref.update_controller(text,bigint,integer,integer,text,integer,text,text,text,integer,text,boolean,text,text,boolean,text,integer,integer,text,text,text)',
        'EXECUTE'
    ) AS can_update_controller,
    has_function_privilege(
        'fieldwiring_app',
        'ref.assign_controller_display(text,bigint,bigint,bigint,text,text,boolean)',
        'EXECUTE'
    ) AS can_assign_controller,
    has_function_privilege(
        'fieldwiring_app',
        'ref.unassign_controller_display(text,bigint,bigint,boolean)',
        'EXECUTE'
    ) AS can_unassign_controller,
    has_table_privilege('fieldwiring_app', 'ref.controller', 'UPDATE')
        AS forbidden_direct_controller_update,
    has_table_privilege('fieldwiring_app', 'ref.controller', 'INSERT')
        AS forbidden_direct_controller_insert,
    has_table_privilege('fieldwiring_app', 'ref.controller_display', 'INSERT')
        AS forbidden_direct_assignment_insert,
    has_table_privilege('fieldwiring_app', 'ref.controller_display', 'DELETE')
        AS forbidden_direct_assignment_delete;
