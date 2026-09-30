BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ops.setup_movement_event') IS NULL
       OR to_regclass('ops.setup_container_state') IS NULL
       OR to_regclass('ops.setup_display_state') IS NULL
       OR to_regprocedure('ref.setup_browser_capabilities(text)') IS NULL THEN
        RAISE EXCEPTION 'Setup movement core and browser capability contract are required';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'fieldwiring_app') THEN
        RAISE EXCEPTION 'Required existing application role fieldwiring_app does not exist';
    END IF;
END
$preflight$;

/* --------------------------------------------------------------------------
   MOVEMENT ACTOR — FIELD/MATERIAL HANDLERS, NOT MANAGER-ONLY
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ref.setup_movement_actor(p_email text)
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
    v_can_move boolean := false;
BEGIN
    IF v_email IS NULL OR v_email = '' THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Authenticated Setup movement operator email is required';
    END IF;

    SELECT
        u.id,
        c.display_name,
        c.can_move_setup_assets
      INTO
        v_directus_user_id,
        v_display_name,
        v_can_move
    FROM public.directus_users AS u
    JOIN LATERAL ref.setup_browser_capabilities(v_email) AS c ON true
    WHERE u.status = 'active'
      AND lower(u.email) = v_email
    LIMIT 1;

    IF v_directus_user_id IS NULL OR coalesce(v_can_move, false) IS NOT TRUE THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Setup asset movement is not authorized for this account';
    END IF;

    SELECT p.person_id
      INTO v_person_id
    FROM ref.person AS p
    WHERE p.directus_user_id = v_directus_user_id
    LIMIT 1;

    IF v_person_id IS NULL THEN
        RAISE EXCEPTION USING
            ERRCODE = '42501',
            MESSAGE = 'Authenticated Setup movement operator is not mapped to an MSB person';
    END IF;

    RETURN QUERY
    SELECT
        v_directus_user_id,
        v_person_id,
        coalesce(nullif(btrim(v_display_name), ''), v_email);
END;
$function$;

REVOKE ALL ON FUNCTION ref.setup_movement_actor(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.setup_movement_actor(text) FROM fieldwiring_app;

/* --------------------------------------------------------------------------
   EVENT EVIDENCE
   -------------------------------------------------------------------------- */

ALTER TABLE ops.setup_movement_event
    ADD COLUMN IF NOT EXISTS client_event_id uuid,
    ADD COLUMN IF NOT EXISTS received_at timestamptz NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS device_id text,
    ADD COLUMN IF NOT EXISTS capture_method text,
    ADD COLUMN IF NOT EXISTS offline_captured boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS gps_latitude numeric(9,6),
    ADD COLUMN IF NOT EXISTS gps_longitude numeric(9,6),
    ADD COLUMN IF NOT EXISTS gps_accuracy_m numeric(10,2),
    ADD COLUMN IF NOT EXISTS source_location_code text;

CREATE UNIQUE INDEX IF NOT EXISTS uq_setup_movement_event_client_event
    ON ops.setup_movement_event(client_event_id)
    WHERE client_event_id IS NOT NULL;

ALTER TABLE ops.setup_movement_event
    DROP CONSTRAINT IF EXISTS ck_setup_movement_event_type;

ALTER TABLE ops.setup_movement_event
    ADD CONSTRAINT ck_setup_movement_event_type CHECK (
        event_type IN (
            'CONTAINER_MOVE',
            'TASK_UNLOAD',
            'DISPLAY_MOVE',
            'DISPLAY_REATTACH',
            'TASK_COMPLETION_RECONCILE',
            'PICKED',
            'LOADED',
            'IN_TRANSIT',
            'DELIVERED',
            'UNLOADED',
            'STAGED',
            'PLACED',
            'RELOCATED',
            'RETURNED'
        )
    );

ALTER TABLE ops.setup_movement_event
    DROP CONSTRAINT IF EXISTS ck_setup_movement_event_destination;

ALTER TABLE ops.setup_movement_event
    ADD CONSTRAINT ck_setup_movement_event_destination CHECK (
        event_type IN (
            'PICKED',
            'LOADED',
            'IN_TRANSIT',
            'RETURNED',
            'TASK_COMPLETION_RECONCILE'
        )
        OR destination_stage_id IS NOT NULL
        OR nullif(btrim(destination_location_note), '') IS NOT NULL
        OR (gps_latitude IS NOT NULL AND gps_longitude IS NOT NULL)
    );

ALTER TABLE ops.setup_movement_event
    DROP CONSTRAINT IF EXISTS ck_setup_movement_event_gps_pair;
ALTER TABLE ops.setup_movement_event
    ADD CONSTRAINT ck_setup_movement_event_gps_pair CHECK (
        (gps_latitude IS NULL) = (gps_longitude IS NULL)
    );

ALTER TABLE ops.setup_movement_event
    DROP CONSTRAINT IF EXISTS ck_setup_movement_event_gps_latitude;
ALTER TABLE ops.setup_movement_event
    ADD CONSTRAINT ck_setup_movement_event_gps_latitude CHECK (
        gps_latitude IS NULL OR gps_latitude BETWEEN -90 AND 90
    );

ALTER TABLE ops.setup_movement_event
    DROP CONSTRAINT IF EXISTS ck_setup_movement_event_gps_longitude;
ALTER TABLE ops.setup_movement_event
    ADD CONSTRAINT ck_setup_movement_event_gps_longitude CHECK (
        gps_longitude IS NULL OR gps_longitude BETWEEN -180 AND 180
    );

ALTER TABLE ops.setup_movement_event
    DROP CONSTRAINT IF EXISTS ck_setup_movement_event_gps_accuracy;
ALTER TABLE ops.setup_movement_event
    ADD CONSTRAINT ck_setup_movement_event_gps_accuracy CHECK (
        gps_accuracy_m IS NULL OR gps_accuracy_m >= 0
    );

/* --------------------------------------------------------------------------
   EXPLICIT CURRENT MOVEMENT STATE, SEPARATE FROM LOCATION
   -------------------------------------------------------------------------- */

ALTER TABLE ops.setup_container_state
    ADD COLUMN IF NOT EXISTS movement_status text,
    ADD COLUMN IF NOT EXISTS last_movement_at timestamptz;

ALTER TABLE ops.setup_display_state
    ADD COLUMN IF NOT EXISTS movement_status text,
    ADD COLUMN IF NOT EXISTS last_movement_at timestamptz;

ALTER TABLE ops.setup_container_state
    DROP CONSTRAINT IF EXISTS ck_setup_container_state_movement_status;
ALTER TABLE ops.setup_container_state
    ADD CONSTRAINT ck_setup_container_state_movement_status CHECK (
        movement_status IS NULL OR movement_status IN (
            'PICKED','LOADED','IN_TRANSIT','DELIVERED','UNLOADED',
            'STAGED','PLACED','RELOCATED','RETURNED',
            'CONTAINER_MOVE','TASK_UNLOAD'
        )
    );

ALTER TABLE ops.setup_display_state
    DROP CONSTRAINT IF EXISTS ck_setup_display_state_movement_status;
ALTER TABLE ops.setup_display_state
    ADD CONSTRAINT ck_setup_display_state_movement_status CHECK (
        movement_status IS NULL OR movement_status IN (
            'PICKED','LOADED','IN_TRANSIT','DELIVERED','UNLOADED',
            'STAGED','PLACED','RELOCATED','RETURNED',
            'DISPLAY_MOVE','DISPLAY_REATTACH','TASK_UNLOAD'
        )
    );

/* Preserve any existing movement truth rather than converting old evidence to NULL. */
UPDATE ops.setup_container_state cs
SET movement_status = me.event_type,
    last_movement_at = me.occurred_at
FROM ops.setup_movement_event me
WHERE cs.last_movement_event_id = me.setup_movement_event_id
  AND cs.movement_status IS NULL
  AND me.event_type IN ('CONTAINER_MOVE','TASK_UNLOAD');

UPDATE ops.setup_display_state ds
SET movement_status = me.event_type,
    last_movement_at = me.occurred_at
FROM ops.setup_movement_event me
WHERE ds.last_movement_event_id = me.setup_movement_event_id
  AND ds.movement_status IS NULL
  AND me.event_type IN ('DISPLAY_MOVE','DISPLAY_REATTACH','TASK_UNLOAD');

/* --------------------------------------------------------------------------
   ONE IDEMPOTENT GOVERNED MOVEMENT COMMAND
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FUNCTION ops.record_setup_movement_event(
    p_email text,
    p_season_year integer,
    p_client_event_id uuid,
    p_asset_type text,
    p_asset_id bigint,
    p_movement_action text,
    p_occurred_at timestamptz,
    p_device_id text DEFAULT NULL,
    p_capture_method text DEFAULT 'HID_SCAN',
    p_offline_captured boolean DEFAULT false,
    p_gps_latitude numeric DEFAULT NULL,
    p_gps_longitude numeric DEFAULT NULL,
    p_gps_accuracy_m numeric DEFAULT NULL,
    p_destination_stage_id integer DEFAULT NULL,
    p_destination_location_note text DEFAULT NULL,
    p_notes text DEFAULT NULL
)
RETURNS TABLE (
    setup_movement_event_id bigint,
    setup_session_id bigint,
    asset_type text,
    asset_id bigint,
    movement_action text,
    occurred_at timestamptz,
    movement_status text,
    home_location_code text,
    duplicate_event boolean,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $function$
DECLARE
    v_directus_user_id uuid;
    v_person_id integer;
    v_display_name text;
    v_session_id bigint;
    v_asset_type text := upper(btrim(coalesce(p_asset_type, '')));
    v_action text := upper(btrim(coalesce(p_movement_action, '')));
    v_capture_method text := upper(btrim(coalesce(p_capture_method, 'HID_SCAN')));
    v_device_id text := nullif(btrim(p_device_id), '');
    v_destination_note text := nullif(btrim(p_destination_location_note), '');
    v_notes text := nullif(btrim(p_notes), '');
    v_home_location text;
    v_event_id bigint;
    v_existing_type text;
    v_existing_container_id integer;
    v_existing_display_id bigint;
    v_existing_session_id bigint;
    v_existing_occurred_at timestamptz;
    v_existing_status text;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_movement_actor(p_email) a;

    IF p_client_event_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Movement client event identity is required';
    END IF;

    IF v_asset_type NOT IN ('CONTAINER', 'DISPLAY') THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Movement asset type must be CONTAINER or DISPLAY';
    END IF;

    IF p_asset_id IS NULL OR p_asset_id <= 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Movement asset identity must be greater than zero';
    END IF;

    IF v_action NOT IN (
        'PICKED','LOADED','IN_TRANSIT','DELIVERED','UNLOADED',
        'STAGED','PLACED','RELOCATED','RETURNED'
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Unsupported Setup movement action';
    END IF;

    IF v_capture_method NOT IN ('HID_SCAN','CAMERA_SCAN','MANUAL_ENTRY','SYSTEM') THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Unsupported Setup movement capture method';
    END IF;

    IF p_occurred_at IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Original movement capture time is required';
    END IF;

    IF (p_gps_latitude IS NULL) <> (p_gps_longitude IS NULL) THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'GPS latitude and longitude must be supplied together';
    END IF;

    SELECT ss.setup_session_id
      INTO v_session_id
    FROM ops.setup_session ss
    WHERE ss.season_year = p_season_year
      AND ss.session_status NOT IN ('COMPLETE', 'HISTORICAL_VERIFICATION');

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = 'P0002',
            MESSAGE = 'Open Setup Session was not found for this season';
    END IF;

    /* Idempotent replay: same client identity returns the original event. */
    SELECT
        me.setup_movement_event_id,
        me.setup_session_id,
        me.event_type,
        me.container_id,
        med.display_id,
        me.occurred_at
      INTO
        v_event_id,
        v_existing_session_id,
        v_existing_type,
        v_existing_container_id,
        v_existing_display_id,
        v_existing_occurred_at
    FROM ops.setup_movement_event me
    LEFT JOIN ops.setup_movement_event_display med
      ON med.setup_movement_event_id = me.setup_movement_event_id
    WHERE me.client_event_id = p_client_event_id
    LIMIT 1;

    IF v_event_id IS NOT NULL THEN
        IF v_existing_session_id <> v_session_id
           OR v_existing_type <> v_action
           OR (v_asset_type = 'CONTAINER' AND v_existing_container_id IS DISTINCT FROM p_asset_id::integer)
           OR (v_asset_type = 'DISPLAY' AND v_existing_display_id IS DISTINCT FROM p_asset_id) THEN
            RAISE EXCEPTION USING ERRCODE = '23505',
                MESSAGE = 'Movement client event identity is already used for different movement evidence';
        END IF;

        IF v_asset_type = 'CONTAINER' THEN
            SELECT cs.movement_status, c.location_code
              INTO v_existing_status, v_home_location
            FROM ref.container c
            LEFT JOIN ops.setup_container_state cs
              ON cs.setup_session_id = v_session_id
             AND cs.container_id = c.container_id
            WHERE c.container_id = p_asset_id::integer;
        ELSE
            SELECT ds.movement_status, c.location_code
              INTO v_existing_status, v_home_location
            FROM ref.display d
            LEFT JOIN ref.container c ON c.container_id = d.container_id
            LEFT JOIN ops.setup_display_state ds
              ON ds.setup_session_id = v_session_id
             AND ds.display_id = d.display_id
            WHERE d.display_id = p_asset_id;
        END IF;

        RETURN QUERY SELECT
            v_event_id,
            v_session_id,
            v_asset_type,
            p_asset_id,
            v_action,
            v_existing_occurred_at,
            v_existing_status,
            v_home_location,
            true,
            v_display_name;
        RETURN;
    END IF;

    IF p_season_year = 2026
       AND (p_occurred_at AT TIME ZONE 'America/Chicago')::date < DATE '2026-10-05'
       AND (
           v_action IN ('IN_TRANSIT','DELIVERED','UNLOADED','PLACED','RELOCATED')
           OR p_destination_stage_id IS NOT NULL
       ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Park movement cannot be recorded before the 2026-10-05 material-access date';
    END IF;

    IF v_asset_type = 'CONTAINER' THEN
        SELECT c.location_code
          INTO v_home_location
        FROM ref.container c
        WHERE c.container_id = p_asset_id::integer;

        IF NOT FOUND THEN
            RAISE EXCEPTION USING ERRCODE = 'P0002',
                MESSAGE = 'Container was not found';
        END IF;

        SELECT cs.movement_status
          INTO v_existing_status
        FROM ops.setup_container_state cs
        WHERE cs.setup_session_id = v_session_id
          AND cs.container_id = p_asset_id::integer
        FOR UPDATE;
    ELSE
        SELECT c.location_code
          INTO v_home_location
        FROM ref.display d
        LEFT JOIN ref.container c ON c.container_id = d.container_id
        WHERE d.display_id = p_asset_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION USING ERRCODE = 'P0002',
                MESSAGE = 'Display was not found';
        END IF;

        SELECT ds.movement_status
          INTO v_existing_status
        FROM ops.setup_display_state ds
        WHERE ds.setup_session_id = v_session_id
          AND ds.display_id = p_asset_id
        FOR UPDATE;
    END IF;

    IF v_action = 'PICKED'
       AND coalesce(v_existing_status, '') IN (
           'PICKED','LOADED','IN_TRANSIT','DELIVERED','UNLOADED',
           'STAGED','PLACED','RELOCATED'
       ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Asset is already picked or currently out of Home Location';
    END IF;

    IF v_existing_status = v_action THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = format('Asset is already in %s movement state', v_action);
    END IF;

    PERFORM pg_catalog.set_config(
        'app.directus_user_uuid',
        v_directus_user_id::text,
        true
    );

    INSERT INTO ops.setup_movement_event(
        setup_session_id,
        event_type,
        container_id,
        destination_stage_id,
        destination_location_note,
        occurred_at,
        notes,
        client_event_id,
        received_at,
        device_id,
        capture_method,
        offline_captured,
        gps_latitude,
        gps_longitude,
        gps_accuracy_m,
        source_location_code
    ) VALUES (
        v_session_id,
        v_action,
        CASE WHEN v_asset_type = 'CONTAINER' THEN p_asset_id::integer ELSE NULL END,
        p_destination_stage_id,
        v_destination_note,
        p_occurred_at,
        v_notes,
        p_client_event_id,
        now(),
        v_device_id,
        v_capture_method,
        coalesce(p_offline_captured, false),
        p_gps_latitude,
        p_gps_longitude,
        p_gps_accuracy_m,
        v_home_location
    )
    RETURNING ops.setup_movement_event.setup_movement_event_id
      INTO v_event_id;

    IF v_asset_type = 'CONTAINER' THEN
        INSERT INTO ops.setup_container_state(
            setup_session_id,
            container_id,
            current_stage_id,
            current_location_note,
            last_movement_event_id,
            movement_status,
            last_movement_at
        ) VALUES (
            v_session_id,
            p_asset_id::integer,
            CASE
                WHEN v_action IN ('DELIVERED','UNLOADED','STAGED','PLACED','RELOCATED')
                THEN p_destination_stage_id
                ELSE NULL
            END,
            CASE
                WHEN v_action = 'RETURNED' THEN v_home_location
                WHEN v_action IN ('DELIVERED','UNLOADED','STAGED','PLACED','RELOCATED')
                THEN v_destination_note
                ELSE NULL
            END,
            v_event_id,
            v_action,
            p_occurred_at
        )
        ON CONFLICT (setup_session_id, container_id)
        DO UPDATE SET
            current_stage_id = EXCLUDED.current_stage_id,
            current_location_note = EXCLUDED.current_location_note,
            last_movement_event_id = EXCLUDED.last_movement_event_id,
            movement_status = EXCLUDED.movement_status,
            last_movement_at = EXCLUDED.last_movement_at;
    ELSE
        INSERT INTO ops.setup_movement_event_display(
            setup_movement_event_id,
            display_id,
            movement_effect
        ) VALUES (
            v_event_id,
            p_asset_id,
            'MOVED'
        );

        INSERT INTO ops.setup_display_state(
            setup_session_id,
            display_id,
            position_mode,
            current_stage_id,
            current_location_note,
            last_movement_event_id,
            movement_status,
            last_movement_at
        ) VALUES (
            v_session_id,
            p_asset_id,
            'DETACHED',
            CASE
                WHEN v_action IN ('DELIVERED','UNLOADED','STAGED','PLACED','RELOCATED')
                THEN p_destination_stage_id
                ELSE NULL
            END,
            CASE
                WHEN v_action = 'RETURNED' THEN v_home_location
                WHEN v_action IN ('DELIVERED','UNLOADED','STAGED','PLACED','RELOCATED')
                THEN v_destination_note
                ELSE NULL
            END,
            v_event_id,
            v_action,
            p_occurred_at
        )
        ON CONFLICT (setup_session_id, display_id)
        DO UPDATE SET
            position_mode = 'DETACHED',
            current_stage_id = EXCLUDED.current_stage_id,
            current_location_note = EXCLUDED.current_location_note,
            last_movement_event_id = EXCLUDED.last_movement_event_id,
            movement_status = EXCLUDED.movement_status,
            last_movement_at = EXCLUDED.last_movement_at;
    END IF;

    RETURN QUERY SELECT
        v_event_id,
        v_session_id,
        v_asset_type,
        p_asset_id,
        v_action,
        p_occurred_at,
        v_action,
        v_home_location,
        false,
        v_display_name;
END;
$function$;

REVOKE ALL ON FUNCTION ops.record_setup_movement_event(
    text,integer,uuid,text,bigint,text,timestamptz,text,text,boolean,
    numeric,numeric,numeric,integer,text,text
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ops.record_setup_movement_event(
    text,integer,uuid,text,bigint,text,timestamptz,text,text,boolean,
    numeric,numeric,numeric,integer,text,text
) TO fieldwiring_app;

GRANT SELECT ON ops.setup_movement_event TO fieldwiring_app;
GRANT SELECT ON ops.setup_movement_event_display TO fieldwiring_app;

COMMENT ON FUNCTION ops.record_setup_movement_event(
    text,integer,uuid,text,bigint,text,timestamptz,text,text,boolean,
    numeric,numeric,numeric,integer,text,text
) IS
'Idempotent governed Setup movement command for field/material handlers. Records explicit movement semantics and current state without rewriting permanent Home Location or Display-to-Container assignment.';

COMMIT;

SELECT
    to_regprocedure(
        'ref.setup_movement_actor(text)'
    ) IS NOT NULL AS movement_actor_ready,
    to_regprocedure(
        'ops.record_setup_movement_event(text,integer,uuid,text,bigint,text,timestamptz,text,text,boolean,numeric,numeric,numeric,integer,text,text)'
    ) IS NOT NULL AS movement_command_ready;
