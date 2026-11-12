-- #88 / DBG-2026-007/009/010. Function-only migration; no tables, columns,
-- grants for table mutation, event rewrites or Production data repair.
BEGIN;
CREATE OR REPLACE FUNCTION ops.record_setup_movement_event(
    p_email text,
    p_season_year integer,
    p_client_event_id uuid,
    p_asset_type text,
    p_asset_id bigint,
    p_movement_action text,
    p_occurred_at timestamptz,
    p_device_id text DEFAULT NULL,
    p_captured_operator_email text DEFAULT NULL,
    p_capture_method text DEFAULT 'HID_SCAN',
    p_offline_captured boolean DEFAULT false,
    p_gps_latitude numeric DEFAULT NULL,
    p_gps_longitude numeric DEFAULT NULL,
    p_gps_accuracy_m numeric DEFAULT NULL,
    p_destination_stage_id integer DEFAULT NULL,
    p_destination_location_note text DEFAULT NULL,
    p_notes text DEFAULT NULL,
    p_unloaded_display_ids bigint[] DEFAULT NULL,
    p_gps_fix_at timestamptz DEFAULT NULL,
    p_gps_fix_age_ms integer DEFAULT NULL,
    p_gps_quality text DEFAULT 'UNASSESSED',
    p_gps_quality_note text DEFAULT NULL
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
    unloaded_display_count integer,
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
    v_captured_email text := lower(nullif(btrim(p_captured_operator_email), ''));
    v_captured_person_id integer;
    v_destination_note text := nullif(btrim(p_destination_location_note), '');
    v_notes text := nullif(btrim(p_notes), '');
    v_unloaded_display_ids bigint[] := coalesce(p_unloaded_display_ids, ARRAY[]::bigint[]);
    v_gps_quality text := upper(btrim(coalesce(p_gps_quality, 'UNASSESSED')));
    v_gps_quality_note text := nullif(btrim(p_gps_quality_note), '');
    v_unloaded_count integer := 0;
    v_home_location text;
    v_event_id bigint;
    v_existing_type text;
    v_existing_container_id integer;
    v_existing_display_id bigint;
    v_existing_session_id bigint;
    v_existing_occurred_at timestamptz;
    v_existing_status text;
    v_existing_movement_at timestamptz;
BEGIN
    SELECT a.directus_user_id, a.person_id, a.display_name
      INTO v_directus_user_id, v_person_id, v_display_name
    FROM ref.setup_movement_actor(p_email) a;

    v_captured_email := coalesce(v_captured_email, lower(btrim(p_email)));
    SELECT a.person_id
      INTO v_captured_person_id
    FROM ref.setup_movement_actor(v_captured_email) a;

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
        'STAGED','PLACED','RELOCATED','RETURNED',
        'CONTAINER_MOVE','DISPLAY_MOVE','TASK_UNLOAD'
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Unsupported Setup movement action';
    END IF;

    IF v_capture_method NOT IN ('HID_SCAN','CAMERA_SCAN','MANUAL_ENTRY','TOUCH_SELECT','SYSTEM') THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Unsupported Setup movement capture method';
    END IF;

    IF v_gps_quality NOT IN ('UNASSESSED','QUESTIONABLE','BAD') THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Unsupported GPS quality disposition';
    END IF;

    IF p_gps_fix_age_ms IS NOT NULL AND p_gps_fix_age_ms < 0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'GPS fix age cannot be negative';
    END IF;

    IF v_action = 'CONTAINER_MOVE' AND v_asset_type <> 'CONTAINER' THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'CONTAINER_MOVE requires a Container';
    END IF;

    IF v_action IN ('DISPLAY_MOVE','TASK_UNLOAD') AND v_asset_type <> 'DISPLAY' THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'DISPLAY_MOVE requires a Display';
    END IF;

    IF cardinality(v_unloaded_display_ids) > 0
       AND (v_asset_type <> 'CONTAINER' OR v_action <> 'CONTAINER_MOVE') THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Grouped Display unload is valid only with CONTAINER_MOVE';
    END IF;

    IF p_occurred_at IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'Original movement capture time is required';
    END IF;

    IF (p_gps_latitude IS NULL) <> (p_gps_longitude IS NULL) THEN
        RAISE EXCEPTION USING ERRCODE = '22023',
            MESSAGE = 'GPS latitude and longitude must be supplied together';
    END IF;

    IF v_action IN (
            'DELIVERED','UNLOADED','STAGED','PLACED','RELOCATED',
            'CONTAINER_MOVE','DISPLAY_MOVE','TASK_UNLOAD'
       )
       AND p_destination_stage_id IS NULL
       AND v_destination_note IS NULL
       AND p_gps_latitude IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Location evidence is required for this movement action';
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

    -- Serialize Container and child Display commands on the permanent parent.
    PERFORM 1 FROM ref.container c
    WHERE c.container_id = CASE WHEN v_asset_type = 'CONTAINER' THEN p_asset_id::integer
        ELSE (SELECT d.container_id FROM ref.display d WHERE d.display_id = p_asset_id) END
    FOR UPDATE;

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

        SELECT count(*)
          INTO v_unloaded_count
        FROM ops.setup_movement_event_display med
        WHERE med.setup_movement_event_id = v_event_id
          AND med.movement_effect = 'UNLOADED';

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
            v_unloaded_count,
            v_display_name;
        RETURN;
    END IF;

    /* Real movement/location observations are physical evidence. Planned access
       dates do not block recording what an authenticated operator actually
       observed in the field. */

    IF v_asset_type = 'CONTAINER' THEN
        SELECT c.location_code
          INTO v_home_location
        FROM ref.container c
        WHERE c.container_id = p_asset_id::integer;

        IF NOT FOUND THEN
            RAISE EXCEPTION USING ERRCODE = 'P0002',
                MESSAGE = 'Container was not found';
        END IF;

        SELECT cs.movement_status, cs.last_movement_at
          INTO v_existing_status, v_existing_movement_at
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

        SELECT ds.movement_status, ds.last_movement_at
          INTO v_existing_status, v_existing_movement_at
        FROM ops.setup_display_state ds
        WHERE ds.setup_session_id = v_session_id
          AND ds.display_id = p_asset_id
        FOR UPDATE;
    END IF;

    -- Synthetic Standalone wrappers and singular Display Pallets are the object,
    -- not a removable load. Enforce this for legacy grouped and direct Display paths.
    IF (cardinality(v_unloaded_display_ids) > 0 OR (v_asset_type = 'DISPLAY' AND v_action IN ('DISPLAY_MOVE','TASK_UNLOAD','UNLOADED','PLACED','RELOCATED'))) AND EXISTS (
        SELECT 1 FROM ref.container c JOIN ref.container_type ct USING (container_type_id)
        WHERE c.container_id = CASE WHEN v_asset_type = 'CONTAINER' THEN p_asset_id::integer
            ELSE (SELECT d.container_id FROM ref.display d WHERE d.display_id = p_asset_id) END
          AND (ct.container_type_name = 'Standalone Display' OR
              (ct.container_type_name IN ('Display Pallet', 'Display-Pallet') AND
               (SELECT count(*) FROM ref.display d JOIN ref.display_status st USING(display_status_id)
                WHERE d.container_id = c.container_id AND upper(st.display_status_name) = 'ACTIVE') = 1))
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'This Display stays with its Standalone/Display-Pallet identity; record the Container location';
    END IF;

    IF v_action = 'RETURNED' AND v_asset_type = 'CONTAINER' AND EXISTS (
        SELECT 1 FROM ref.display d JOIN ref.display_status st USING(display_status_id)
        LEFT JOIN ops.setup_display_state ds ON ds.setup_session_id = v_session_id AND ds.display_id = d.display_id
        WHERE d.container_id = p_asset_id::integer AND upper(st.display_status_name) = 'ACTIVE'
          AND coalesce(ds.position_mode, 'WITH_CONTAINER') = 'WITH_CONTAINER'
    ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Return Empty requires contents reconciliation first';
    END IF;

    IF cardinality(v_unloaded_display_ids) > 0 THEN
        SELECT count(DISTINCT x.display_id)
          INTO v_unloaded_count
        FROM unnest(v_unloaded_display_ids) AS x(display_id);

        IF EXISTS (
            SELECT 1
            FROM unnest(v_unloaded_display_ids) AS x(display_id)
            LEFT JOIN ref.display d
              ON d.display_id = x.display_id
            LEFT JOIN ops.setup_display_state ds
              ON ds.setup_session_id = v_session_id
             AND ds.display_id = x.display_id
            WHERE d.display_id IS NULL
               OR d.container_id IS DISTINCT FROM p_asset_id::integer
               OR NOT EXISTS (SELECT 1 FROM ref.display_status st WHERE st.display_status_id=d.display_status_id AND upper(st.display_status_name)='ACTIVE')
               OR coalesce(ds.position_mode, 'WITH_CONTAINER') <> 'WITH_CONTAINER'
        ) THEN
            RAISE EXCEPTION USING ERRCODE = '23514',
                MESSAGE = 'Grouped unload contains a Display that is not still WITH_CONTAINER';
        END IF;
    END IF;

    IF v_action = 'RETURNED'
       AND v_home_location IS NULL THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Home Location is missing — Manager correction required before RETURNED';
    END IF;

    IF v_action = 'PICKED'
       AND coalesce(v_existing_status, '') IN (
           'PICKED','LOADED','IN_TRANSIT','DELIVERED','UNLOADED',
           'STAGED','PLACED','RELOCATED','CONTAINER_MOVE','DISPLAY_MOVE'
       )
       AND (
           v_existing_movement_at IS NULL
           OR p_occurred_at >= v_existing_movement_at
       ) THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'Asset is already picked or currently out of Home Location';
    END IF;

    IF v_existing_status = v_action
       AND v_action NOT IN ('CONTAINER_MOVE','DISPLAY_MOVE','TASK_UNLOAD')
       AND (
           v_existing_movement_at IS NULL
           OR p_occurred_at >= v_existing_movement_at
       ) THEN
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
        captured_operator_email,
        captured_operator_person_id,
        capture_method,
        offline_captured,
        gps_latitude,
        gps_longitude,
        gps_accuracy_m,
        gps_fix_at,
        gps_fix_age_ms,
        gps_quality,
        gps_quality_note,
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
        v_captured_email,
        v_captured_person_id,
        v_capture_method,
        coalesce(p_offline_captured, false),
        p_gps_latitude,
        p_gps_longitude,
        p_gps_accuracy_m,
        p_gps_fix_at,
        p_gps_fix_age_ms,
        v_gps_quality,
        v_gps_quality_note,
        CASE WHEN v_action = 'PICKED' THEN v_home_location ELSE NULL END
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
                WHEN v_action IN (
                    'DELIVERED','UNLOADED','STAGED','PLACED','RELOCATED','CONTAINER_MOVE'
                )
                THEN p_destination_stage_id
                ELSE NULL
            END,
            CASE
                WHEN v_action = 'RETURNED' THEN v_home_location
                WHEN v_action IN (
                    'DELIVERED','UNLOADED','STAGED','PLACED','RELOCATED','CONTAINER_MOVE'
                )
                THEN v_destination_note
                ELSE NULL
            END,
            v_event_id,
            v_action,
            p_occurred_at
        )
        ON CONFLICT ON CONSTRAINT pk_setup_container_state
        DO UPDATE SET
            current_stage_id = CASE WHEN v_action = 'RETURNED' THEN NULL
                WHEN v_destination_note IS NOT NULL THEN EXCLUDED.current_stage_id
                ELSE coalesce(EXCLUDED.current_stage_id, ops.setup_container_state.current_stage_id) END,
            current_location_note = CASE WHEN EXCLUDED.current_stage_id IS NOT NULL THEN EXCLUDED.current_location_note
                ELSE coalesce(EXCLUDED.current_location_note, ops.setup_container_state.current_location_note) END,
            last_movement_event_id = EXCLUDED.last_movement_event_id,
            movement_status = EXCLUDED.movement_status,
            last_movement_at = EXCLUDED.last_movement_at
        WHERE ops.setup_container_state.last_movement_at IS NULL
           OR EXCLUDED.last_movement_at >= ops.setup_container_state.last_movement_at;

        IF v_unloaded_count > 0 THEN
            INSERT INTO ops.setup_movement_event_display(
                setup_movement_event_id,
                display_id,
                movement_effect
            )
            SELECT
                v_event_id,
                x.display_id,
                'UNLOADED'
            FROM (
                SELECT DISTINCT display_id
                FROM unnest(v_unloaded_display_ids) AS u(display_id)
            ) AS x;

            INSERT INTO ops.setup_display_state(
                setup_session_id,
                display_id,
                position_mode,
                current_stage_id,
                current_location_note,
                last_movement_event_id,
                movement_status,
                last_movement_at
            )
            SELECT
                v_session_id,
                x.display_id,
                'DETACHED',
                NULL,
                v_destination_note,
                v_event_id,
                'TASK_UNLOAD',
                p_occurred_at
            FROM (
                SELECT DISTINCT display_id
                FROM unnest(v_unloaded_display_ids) AS u(display_id)
            ) AS x
            ON CONFLICT ON CONSTRAINT pk_setup_display_state
            DO UPDATE SET
                position_mode = 'DETACHED',
                current_stage_id = EXCLUDED.current_stage_id,
                current_location_note = EXCLUDED.current_location_note,
                last_movement_event_id = EXCLUDED.last_movement_event_id,
                movement_status = EXCLUDED.movement_status,
                last_movement_at = EXCLUDED.last_movement_at
            WHERE ops.setup_display_state.last_movement_at IS NULL
               OR EXCLUDED.last_movement_at >= ops.setup_display_state.last_movement_at;
        END IF;
    ELSE
        INSERT INTO ops.setup_movement_event_display(
            setup_movement_event_id,
            display_id,
            movement_effect
        ) VALUES (
            v_event_id,
            p_asset_id,
            CASE WHEN v_action='TASK_UNLOAD' THEN 'UNLOADED' ELSE 'MOVED' END
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
                WHEN v_action IN (
                    'DELIVERED','UNLOADED','STAGED','PLACED','RELOCATED','DISPLAY_MOVE','TASK_UNLOAD'
                )
                THEN p_destination_stage_id
                ELSE NULL
            END,
            CASE
                WHEN v_action = 'RETURNED' THEN v_home_location
                WHEN v_action IN (
                    'DELIVERED','UNLOADED','STAGED','PLACED','RELOCATED','DISPLAY_MOVE','TASK_UNLOAD'
                )
                THEN v_destination_note
                ELSE NULL
            END,
            v_event_id,
            v_action,
            p_occurred_at
        )
        ON CONFLICT ON CONSTRAINT pk_setup_display_state
        DO UPDATE SET
            position_mode = 'DETACHED',
            current_stage_id = EXCLUDED.current_stage_id,
            current_location_note = EXCLUDED.current_location_note,
            last_movement_event_id = EXCLUDED.last_movement_event_id,
            movement_status = EXCLUDED.movement_status,
            last_movement_at = EXCLUDED.last_movement_at
        WHERE ops.setup_display_state.last_movement_at IS NULL
           OR EXCLUDED.last_movement_at >= ops.setup_display_state.last_movement_at;
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
        v_unloaded_count,
        v_display_name;
END;
$function$;

CREATE OR REPLACE FUNCTION ops.record_setup_container_reconciliation(
    p_email text,
    p_season_year integer,
    p_client_event_id uuid,
    p_asset_type text,
    p_asset_id bigint,
    p_movement_action text,
    p_occurred_at timestamptz,
    p_device_id text DEFAULT NULL,
    p_captured_operator_email text DEFAULT NULL,
    p_capture_method text DEFAULT 'HID_SCAN',
    p_offline_captured boolean DEFAULT false,
    p_gps_latitude numeric DEFAULT NULL,
    p_gps_longitude numeric DEFAULT NULL,
    p_gps_accuracy_m numeric DEFAULT NULL,
    p_destination_stage_id integer DEFAULT NULL,
    p_destination_location_note text DEFAULT NULL,
    p_notes text DEFAULT NULL,
    p_unloaded_display_ids bigint[] DEFAULT NULL,
    p_gps_fix_at timestamptz DEFAULT NULL,
    p_gps_fix_age_ms integer DEFAULT NULL,
    p_gps_quality text DEFAULT 'UNASSESSED',
    p_gps_quality_note text DEFAULT NULL,
    p_reconciliation jsonb DEFAULT NULL
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
    unloaded_display_count integer,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $function$
DECLARE
    v_session bigint;
    v_last bigint;
    v_snapshot_last bigint;
    v_attached bigint[];
    v_expected bigint[];
    v_remaining bigint[];
    v_detach bigint[];
    v_decision text := p_reconciliation->>'decision';
    v_prior ops.setup_movement_event%ROWTYPE;
    v_named text;
    v_display bigint;
    v_result record;
    v_count integer := 0;
BEGIN
    PERFORM 1 FROM ref.setup_movement_actor(p_email);
    IF upper(p_asset_type) <> 'CONTAINER' OR upper(p_movement_action) NOT IN ('CONTAINER_MOVE','RETURNED')
       OR jsonb_typeof(p_reconciliation) IS DISTINCT FROM 'object'
       OR v_decision NOT IN ('EMPTY','NOT_EMPTY','NOT_SURE') OR v_decision IS NULL THEN
        RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Valid Container contents decision is required';
    END IF;
    SELECT ss.setup_session_id INTO v_session FROM ops.setup_session ss
    WHERE ss.season_year=p_season_year AND ss.session_status NOT IN ('COMPLETE','HISTORICAL_VERIFICATION');
    PERFORM 1 FROM ref.container c WHERE c.container_id=p_asset_id::integer FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE='P0002', MESSAGE='Container was not found';
    END IF;
    -- A committed parent proves the entire atomic reconciliation committed.
    IF EXISTS (SELECT 1 FROM ops.setup_movement_event e WHERE e.client_event_id=p_client_event_id) THEN
        SELECT * INTO v_result FROM ops.record_setup_movement_event(
            p_email,p_season_year,p_client_event_id,p_asset_type,p_asset_id,p_movement_action,p_occurred_at,
            p_device_id,p_captured_operator_email,p_capture_method,p_offline_captured,
            p_gps_latitude,p_gps_longitude,p_gps_accuracy_m,p_destination_stage_id,p_destination_location_note,
            p_notes,ARRAY[]::bigint[],p_gps_fix_at,p_gps_fix_age_ms,p_gps_quality,p_gps_quality_note);
        SELECT count(*) INTO v_count FROM ops.setup_movement_event e
        WHERE e.setup_session_id=v_session AND e.notes LIKE 'reconciliation_parent='||p_client_event_id::text||';%';
    ELSE
        IF upper(p_movement_action)='RETURNED' AND v_decision<>'EMPTY' THEN
            RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='Return Empty requires physical EMPTY confirmation';
        END IF;
        -- Lock identities as well as existing state rows; this protects the
        -- snapshot when a Display has no annual state row yet and prevents a
        -- concurrent master-assignment/reattach change during the complement.
        PERFORM 1 FROM ref.display d WHERE d.container_id=p_asset_id::integer FOR UPDATE;
        PERFORM 1 FROM ops.setup_display_state ds JOIN ref.display d ON d.display_id=ds.display_id
        WHERE ds.setup_session_id=v_session AND d.container_id=p_asset_id::integer FOR UPDATE OF ds;
        SELECT cs.last_movement_event_id INTO v_last FROM ops.setup_container_state cs
        WHERE cs.setup_session_id=v_session AND cs.container_id=p_asset_id::integer;
        SELECT coalesce(array_agg(d.display_id ORDER BY d.display_id),ARRAY[]::bigint[]) INTO v_attached
        FROM ref.display d JOIN ref.display_status st USING(display_status_id)
        LEFT JOIN ops.setup_display_state ds ON ds.setup_session_id=v_session AND ds.display_id=d.display_id
        WHERE d.container_id=p_asset_id::integer AND upper(st.display_status_name)='ACTIVE'
          AND coalesce(ds.position_mode,'WITH_CONTAINER')='WITH_CONTAINER';
        IF v_decision='EMPTY' OR (v_decision='NOT_EMPTY' AND p_reconciliation->>'identify_remaining'='true') THEN
            IF jsonb_typeof(p_reconciliation->'expected_display_ids') IS DISTINCT FROM 'array'
               OR NOT (p_reconciliation ? 'prior_event_id') THEN
                RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='Contents context unavailable; record location only and review later';
            END IF;
            SELECT coalesce(array_agg(x.id ORDER BY x.id),ARRAY[]::bigint[]) INTO v_expected
            FROM (SELECT DISTINCT value::bigint id FROM jsonb_array_elements_text(p_reconciliation->'expected_display_ids')) x;
            IF EXISTS (SELECT 1 FROM ops.setup_movement_event e WHERE e.setup_movement_event_id=v_last
                       AND e.occurred_at>=p_occurred_at) THEN
                RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='Reconciliation capture precedes current state; rescan and review';
            END IF;
            v_snapshot_last := (p_reconciliation->>'prior_event_id')::bigint;
            IF p_reconciliation->>'prior_client_event_id' IS NOT NULL THEN
                SELECT e.setup_movement_event_id INTO v_snapshot_last FROM ops.setup_movement_event e
                WHERE e.client_event_id=(p_reconciliation->>'prior_client_event_id')::uuid
                  AND e.setup_session_id=v_session AND e.container_id=p_asset_id::integer;
                IF v_snapshot_last IS NULL THEN
                    RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='Earlier offline Container observation must sync first';
                END IF;
            END IF;
            IF v_expected IS DISTINCT FROM v_attached OR v_last IS DISTINCT FROM v_snapshot_last THEN
                RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='Container contents or prior location changed; rescan and review before reconciliation';
            END IF;
            IF EXISTS (SELECT 1 FROM ref.container c JOIN ref.container_type ct USING(container_type_id)
                WHERE c.container_id=p_asset_id::integer AND (ct.container_type_name='Standalone Display' OR
                 (ct.container_type_name IN ('Display Pallet','Display-Pallet') AND
                  (SELECT count(*) FROM ref.display d JOIN ref.display_status st USING(display_status_id)
                   WHERE d.container_id=c.container_id AND upper(st.display_status_name)='ACTIVE')=1))) THEN
                RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='Standalone/singular Display-Pallet cannot be emptied or unloaded';
            END IF;
            IF v_decision='EMPTY' THEN
                v_remaining := ARRAY[]::bigint[];
            ELSE
                IF jsonb_typeof(p_reconciliation->'remaining_display_ids') IS DISTINCT FROM 'array' THEN
                    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Select the Display Names still present';
                END IF;
                SELECT coalesce(array_agg(x.id ORDER BY x.id),ARRAY[]::bigint[]) INTO v_remaining
                FROM (SELECT DISTINCT value::bigint id FROM jsonb_array_elements_text(p_reconciliation->'remaining_display_ids')) x;
                IF cardinality(v_remaining)=0 OR NOT (v_remaining <@ v_attached) THEN
                    RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='Not Empty requires at least one known Display still present';
                END IF;
            END IF;
            SELECT coalesce(array_agg(x),ARRAY[]::bigint[]) INTO v_detach FROM unnest(v_attached) x WHERE NOT (x=ANY(v_remaining));
            -- Anchor strictly precedes this capture. Never use the new Workshop scan,
            -- permanent Home metadata, or a later online observation on offline replay.
            SELECT e.* INTO v_prior FROM ops.setup_movement_event e
            WHERE e.setup_session_id=v_session AND e.container_id=p_asset_id::integer
              AND e.occurred_at < p_occurred_at AND e.event_type<>'RETURNED'
              AND (e.gps_latitude IS NOT NULL OR e.destination_stage_id IS NOT NULL OR nullif(btrim(e.destination_location_note),'') IS NOT NULL)
            ORDER BY e.occurred_at DESC,e.setup_movement_event_id DESC LIMIT 1;
            -- A Return/Home observation is a boundary: earlier park evidence cannot
            -- be reused after the Container has actually returned and started again.
            IF EXISTS (SELECT 1 FROM ops.setup_movement_event e WHERE e.setup_session_id=v_session
                AND e.container_id=p_asset_id::integer AND e.event_type='RETURNED'
                AND e.occurred_at<p_occurred_at AND e.occurred_at>=v_prior.occurred_at) THEN
                v_prior := NULL;
            END IF;
            SELECT e.destination_location_note INTO v_named FROM ops.setup_movement_event e
            WHERE e.setup_session_id=v_session AND e.container_id=p_asset_id::integer
              AND e.occurred_at<=v_prior.occurred_at AND nullif(btrim(e.destination_location_note),'') IS NOT NULL
              AND NOT EXISTS (SELECT 1 FROM ops.setup_movement_event r WHERE r.setup_session_id=v_session
                AND r.container_id=p_asset_id::integer AND r.event_type='RETURNED'
                AND r.occurred_at>=e.occurred_at AND r.occurred_at<=v_prior.occurred_at)
            ORDER BY e.occurred_at DESC,e.setup_movement_event_id DESC LIMIT 1;
            FOREACH v_display IN ARRAY v_detach LOOP
                -- Deterministic child identity makes retry/reload exactly once.
                PERFORM * FROM ops.record_setup_movement_event(
                    p_email,p_season_year,md5(p_client_event_id::text||':'||v_display::text)::uuid,
                    'DISPLAY',v_display,'TASK_UNLOAD',p_occurred_at,p_device_id,p_captured_operator_email,
                    p_capture_method,p_offline_captured,v_prior.gps_latitude,v_prior.gps_longitude,v_prior.gps_accuracy_m,
                    v_prior.destination_stage_id,coalesce(v_named,CASE WHEN v_prior.setup_movement_event_id IS NULL
                        THEN 'Unload location unresolved — contents reconciliation' END),
                    'reconciliation_parent='||p_client_event_id::text||'; inferred_unload=true; prior_event_id='||
                        coalesce(v_prior.setup_movement_event_id::text,'none')||'; contents_decision='||v_decision,
                    ARRAY[]::bigint[],v_prior.gps_fix_at,v_prior.gps_fix_age_ms,v_prior.gps_quality,v_prior.gps_quality_note);
            END LOOP;
            v_count := cardinality(v_detach);
        END IF;
        SELECT * INTO v_result FROM ops.record_setup_movement_event(
            p_email,p_season_year,p_client_event_id,p_asset_type,p_asset_id,p_movement_action,p_occurred_at,
            p_device_id,p_captured_operator_email,p_capture_method,p_offline_captured,
            CASE WHEN upper(p_movement_action)='RETURNED' THEN NULL ELSE p_gps_latitude END,
            CASE WHEN upper(p_movement_action)='RETURNED' THEN NULL ELSE p_gps_longitude END,
            CASE WHEN upper(p_movement_action)='RETURNED' THEN NULL ELSE p_gps_accuracy_m END,
            CASE WHEN upper(p_movement_action)='RETURNED' THEN NULL ELSE p_destination_stage_id END,
            CASE WHEN upper(p_movement_action)='RETURNED' THEN NULL ELSE p_destination_location_note END,
            concat_ws('; ',p_notes,'contents_reconciliation='||p_reconciliation::text,
                CASE WHEN v_decision='NOT_SURE' OR (v_decision='NOT_EMPTY' AND p_reconciliation->>'identify_remaining' IS DISTINCT FROM 'true')
                    THEN 'contents_review_required=true' END),
            ARRAY[]::bigint[],CASE WHEN upper(p_movement_action)='RETURNED' THEN NULL ELSE p_gps_fix_at END,
            CASE WHEN upper(p_movement_action)='RETURNED' THEN NULL ELSE p_gps_fix_age_ms END,p_gps_quality,p_gps_quality_note);
    END IF;
    RETURN QUERY SELECT v_result.setup_movement_event_id,v_result.setup_session_id,v_result.asset_type,
        v_result.asset_id,v_result.movement_action,v_result.occurred_at,v_result.movement_status,
        v_result.home_location_code,v_result.duplicate_event,v_count,v_result.operator_display_name;
END;
$function$;
REVOKE ALL ON FUNCTION ops.record_setup_container_reconciliation(
 text,integer,uuid,text,bigint,text,timestamptz,text,text,text,boolean,numeric,numeric,numeric,integer,text,text,bigint[],timestamptz,integer,text,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.record_setup_container_reconciliation(
 text,integer,uuid,text,bigint,text,timestamptz,text,text,text,boolean,numeric,numeric,numeric,integer,text,text,bigint[],timestamptz,integer,text,text,jsonb) TO fieldwiring_app;

COMMIT;
