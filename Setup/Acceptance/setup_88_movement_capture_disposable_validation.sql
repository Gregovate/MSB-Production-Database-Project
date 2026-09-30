\set ON_ERROR_STOP on

BEGIN;

DO $validation$
DECLARE
    v_session_id bigint;
    v_operator_email text;
    v_container_id integer;
    v_container_home text;
    v_container_home_after text;
    v_unload_display_id bigint;
    v_follow_display_id bigint;
    v_display_container_before integer;
    v_display_container_after integer;
    v_pick_uuid uuid := '88000000-0000-4000-8000-000000000101'::uuid;
    v_move1_uuid uuid := '88000000-0000-4000-8000-000000000102'::uuid;
    v_move2_uuid uuid := '88000000-0000-4000-8000-000000000103'::uuid;
    v_display_uuid uuid := '88000000-0000-4000-8000-000000000104'::uuid;
    v_return_uuid uuid := '88000000-0000-4000-8000-000000000105'::uuid;
    v_pre_oct_uuid uuid := '88000000-0000-4000-8000-000000000106'::uuid;
    v_missing_location_uuid uuid := '88000000-0000-4000-8000-000000000107'::uuid;
    v_event_id bigint;
    v_move1_event_id bigint;
    v_move2_event_id bigint;
    v_duplicate boolean;
    v_status text;
    v_unloaded_count integer;
BEGIN
    IF to_regprocedure('ref.setup_movement_actor(text)') IS NULL THEN
        RAISE EXCEPTION 'Setup movement actor function is missing';
    END IF;

    IF to_regprocedure(
        'ops.record_setup_movement_event(text,integer,uuid,text,bigint,text,timestamptz,text,text,text,boolean,numeric,numeric,numeric,integer,text,text,bigint[],timestamptz,integer,text,text)'
    ) IS NULL THEN
        RAISE EXCEPTION 'Setup movement command is missing';
    END IF;

    SELECT ss.setup_session_id
      INTO v_session_id
    FROM ops.setup_session ss
    WHERE ss.season_year = 2026
      AND ss.session_status NOT IN ('COMPLETE', 'HISTORICAL_VERIFICATION');

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION 'Open 2026 Setup Session is required for #88 validation';
    END IF;

    SELECT u.email
      INTO v_operator_email
    FROM public.directus_users u
    JOIN ref.person p ON p.directus_user_id = u.id
    JOIN LATERAL ref.setup_browser_capabilities(u.email) caps ON true
    WHERE u.status = 'active'
      AND caps.can_move_setup_assets
    ORDER BY caps.can_manage_setup, lower(u.email)
    LIMIT 1;

    IF v_operator_email IS NULL THEN
        RAISE EXCEPTION 'No active mapped Setup movement operator is available';
    END IF;

    PERFORM 1 FROM ref.setup_movement_actor(v_operator_email);

    SELECT
        c.container_id,
        c.location_code,
        (array_agg(d.display_id ORDER BY d.display_id))[1],
        (array_agg(d.display_id ORDER BY d.display_id))[2]
      INTO
        v_container_id,
        v_container_home,
        v_unload_display_id,
        v_follow_display_id
    FROM ref.container c
    JOIN ref.storage_location sl
      ON sl.location_code = c.location_code
     AND sl.is_active
    JOIN ref.display d
      ON d.container_id = c.container_id
    JOIN ref.display_status status
      ON status.display_status_id = d.display_status_id
    LEFT JOIN ops.setup_display_state ds
      ON ds.setup_session_id = v_session_id
     AND ds.display_id = d.display_id
    WHERE nullif(btrim(c.location_code), '') IS NOT NULL
      AND upper(status.display_status_name) = 'ACTIVE'
      AND coalesce(ds.position_mode, 'WITH_CONTAINER') = 'WITH_CONTAINER'
    GROUP BY c.container_id, c.location_code
    HAVING count(*) >= 2
    ORDER BY c.container_id
    LIMIT 1;

    IF v_container_id IS NULL
       OR v_unload_display_id IS NULL
       OR v_follow_display_id IS NULL THEN
        RAISE EXCEPTION 'Container with at least two active WITH_CONTAINER Displays is required';
    END IF;

    SELECT d.container_id
      INTO v_display_container_before
    FROM ref.display d
    WHERE d.display_id = v_follow_display_id;

    SELECT r.setup_movement_event_id, r.duplicate_event, r.movement_status
      INTO v_event_id, v_duplicate, v_status
    FROM ops.record_setup_movement_event(
        p_email => v_operator_email,
        p_season_year => 2026,
        p_client_event_id => v_pick_uuid,
        p_asset_type => 'CONTAINER',
        p_asset_id => v_container_id,
        p_movement_action => 'PICKED',
        p_occurred_at => '2026-09-30T08:00:00-05:00'::timestamptz,
        p_device_id => 'DISPOSABLE-VALIDATION',
        p_captured_operator_email => v_operator_email,
        p_capture_method => 'HID_SCAN',
        p_notes => '[PREVIEW ONLY] workshop Pick validation'
    ) r;

    IF v_event_id IS NULL OR v_duplicate OR v_status <> 'PICKED' THEN
        RAISE EXCEPTION 'PICKED movement did not return expected evidence';
    END IF;

    SELECT r.duplicate_event
      INTO v_duplicate
    FROM ops.record_setup_movement_event(
        p_email => v_operator_email,
        p_season_year => 2026,
        p_client_event_id => v_pick_uuid,
        p_asset_type => 'CONTAINER',
        p_asset_id => v_container_id,
        p_movement_action => 'PICKED',
        p_occurred_at => '2026-09-30T08:00:00-05:00'::timestamptz,
        p_device_id => 'DISPOSABLE-VALIDATION',
        p_captured_operator_email => v_operator_email,
        p_capture_method => 'HID_SCAN',
        p_offline_captured => true,
        p_notes => '[PREVIEW ONLY] idempotent Pick replay'
    ) r;

    IF NOT v_duplicate THEN
        RAISE EXCEPTION 'Same client event identity was not treated as idempotent replay';
    END IF;

    SELECT r.setup_movement_event_id
      INTO v_event_id
    FROM ops.record_setup_movement_event(
        p_email => v_operator_email,
        p_season_year => 2026,
        p_client_event_id => v_pre_oct_uuid,
        p_asset_type => 'CONTAINER',
        p_asset_id => v_container_id,
        p_movement_action => 'CONTAINER_MOVE',
        p_occurred_at => '2026-10-04T12:00:00-05:00'::timestamptz,
        p_device_id => 'DISPOSABLE-VALIDATION',
        p_captured_operator_email => v_operator_email,
        p_capture_method => 'HID_SCAN',
        p_gps_latitude => 43.77636681,
        p_gps_longitude => -87.74226992,
        p_gps_accuracy_m => 4.0
    ) r;

    IF v_event_id IS NULL THEN
        RAISE EXCEPTION 'Real pre-2026-10-05 field observation was not recorded';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_movement_event me
        WHERE me.setup_movement_event_id = v_event_id
          AND me.event_type = 'CONTAINER_MOVE'
          AND me.occurred_at = '2026-10-04T12:00:00-05:00'::timestamptz
          AND me.gps_latitude IS NOT NULL
          AND me.gps_longitude IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'Pre-access-date physical evidence was not preserved truthfully';
    END IF;

    BEGIN
        PERFORM ops.record_setup_movement_event(
            p_email => v_operator_email,
            p_season_year => 2026,
            p_client_event_id => v_missing_location_uuid,
            p_asset_type => 'CONTAINER',
            p_asset_id => v_container_id,
            p_movement_action => 'CONTAINER_MOVE',
            p_occurred_at => '2026-10-05T08:00:00-05:00'::timestamptz,
            p_device_id => 'DISPOSABLE-VALIDATION',
            p_captured_operator_email => v_operator_email,
            p_capture_method => 'HID_SCAN'
        );
        RAISE EXCEPTION 'Container movement was accepted without location evidence';
    EXCEPTION
        WHEN SQLSTATE '23514' THEN
            IF SQLERRM NOT LIKE '%Location evidence is required%' THEN
                RAISE;
            END IF;
    END;

    SELECT
        r.setup_movement_event_id,
        r.unloaded_display_count
      INTO
        v_move1_event_id,
        v_unloaded_count
    FROM ops.record_setup_movement_event(
        p_email => v_operator_email,
        p_season_year => 2026,
        p_client_event_id => v_move1_uuid,
        p_asset_type => 'CONTAINER',
        p_asset_id => v_container_id,
        p_movement_action => 'CONTAINER_MOVE',
        p_occurred_at => '2026-10-05T08:05:00-05:00'::timestamptz,
        p_device_id => 'DISPOSABLE-VALIDATION',
        p_captured_operator_email => v_operator_email,
        p_capture_method => 'HID_SCAN',
        p_gps_latitude => 43.77636681,
        p_gps_longitude => -87.74226992,
        p_gps_accuracy_m => 4.0,
        p_destination_location_note => '25-Racing Arches-RA',
        p_notes => '[PREVIEW ONLY] first Container drop; one Display stays here',
        p_unloaded_display_ids => ARRAY[v_unload_display_id]::bigint[],
        p_gps_fix_at => '2026-10-05T08:04:59.500-05:00'::timestamptz,
        p_gps_fix_age_ms => 500,
        p_gps_quality => 'QUESTIONABLE',
        p_gps_quality_note => 'Disposable validation quality evidence'
    ) r;

    IF v_move1_event_id IS NULL OR v_unloaded_count <> 1 THEN
        RAISE EXCEPTION 'Container move did not retain grouped unload evidence';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_movement_event me
        WHERE me.setup_movement_event_id = v_move1_event_id
          AND me.event_type = 'CONTAINER_MOVE'
          AND me.gps_fix_at = '2026-10-05T08:04:59.500-05:00'::timestamptz
          AND me.gps_fix_age_ms = 500
          AND me.gps_quality = 'QUESTIONABLE'
          AND me.gps_quality_note = 'Disposable validation quality evidence'
          AND me.destination_location_note = '25-Racing Arches-RA'
    ) THEN
        RAISE EXCEPTION 'Raw GPS uncertainty/reference evidence was not preserved';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_movement_event_display med
        WHERE med.setup_movement_event_id = v_move1_event_id
          AND med.display_id = v_unload_display_id
          AND med.movement_effect = 'UNLOADED'
    ) THEN
        RAISE EXCEPTION 'Grouped unload did not retain Display event evidence';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_display_state ds
        WHERE ds.setup_session_id = v_session_id
          AND ds.display_id = v_unload_display_id
          AND ds.position_mode = 'DETACHED'
          AND ds.movement_status = 'TASK_UNLOAD'
          AND ds.last_movement_event_id = v_move1_event_id
    ) THEN
        RAISE EXCEPTION 'Unloaded Display did not detach at the first Container stop';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_display_state ds
        WHERE ds.setup_session_id = v_session_id
          AND ds.display_id = v_follow_display_id
          AND ds.position_mode = 'DETACHED'
    ) THEN
        RAISE EXCEPTION 'Unselected Display was incorrectly detached from the Container';
    END IF;

    SELECT r.setup_movement_event_id
      INTO v_move2_event_id
    FROM ops.record_setup_movement_event(
        p_email => v_operator_email,
        p_season_year => 2026,
        p_client_event_id => v_move2_uuid,
        p_asset_type => 'CONTAINER',
        p_asset_id => v_container_id,
        p_movement_action => 'CONTAINER_MOVE',
        p_occurred_at => '2026-10-05T08:15:00-05:00'::timestamptz,
        p_device_id => 'DISPOSABLE-VALIDATION',
        p_captured_operator_email => v_operator_email,
        p_capture_method => 'TOUCH_SELECT',
        p_gps_latitude => 43.77604286,
        p_gps_longitude => -87.74487442,
        p_gps_accuracy_m => 6.0,
        p_destination_location_note => '21-Polar Bear Playground-PB',
        p_notes => '[PREVIEW ONLY] repeated Container move; prior unload must stay behind',
        p_gps_fix_at => '2026-10-05T08:14:59.250-05:00'::timestamptz,
        p_gps_fix_age_ms => 750,
        p_gps_quality => 'UNASSESSED'
    ) r;

    IF v_move2_event_id IS NULL OR v_move2_event_id = v_move1_event_id THEN
        RAISE EXCEPTION 'Repeated Container move was not recorded as a new observation';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_container_state cs
        WHERE cs.setup_session_id = v_session_id
          AND cs.container_id = v_container_id
          AND cs.movement_status = 'CONTAINER_MOVE'
          AND cs.last_movement_event_id = v_move2_event_id
          AND cs.current_location_note = '21-Polar Bear Playground-PB'
    ) THEN
        RAISE EXCEPTION 'Second Container observation did not become current state';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_display_state ds
        WHERE ds.setup_session_id = v_session_id
          AND ds.display_id = v_unload_display_id
          AND ds.position_mode = 'DETACHED'
          AND ds.last_movement_event_id = v_move1_event_id
    ) THEN
        RAISE EXCEPTION 'Display left at first stop incorrectly followed later Container movement';
    END IF;

    SELECT r.setup_movement_event_id
      INTO v_event_id
    FROM ops.record_setup_movement_event(
        p_email => v_operator_email,
        p_season_year => 2026,
        p_client_event_id => v_display_uuid,
        p_asset_type => 'DISPLAY',
        p_asset_id => v_follow_display_id,
        p_movement_action => 'DISPLAY_MOVE',
        p_occurred_at => '2026-10-05T08:20:00-05:00'::timestamptz,
        p_device_id => 'DISPOSABLE-VALIDATION',
        p_captured_operator_email => v_operator_email,
        p_capture_method => 'MANUAL_ENTRY',
        p_gps_latitude => 43.77577894,
        p_gps_longitude => -87.74294278,
        p_gps_accuracy_m => 20.0,
        p_destination_location_note => '23-Peanuts-PN',
        p_notes => '[PREVIEW ONLY] independent Display move',
        p_gps_fix_at => '2026-10-05T08:19:58.000-05:00'::timestamptz,
        p_gps_fix_age_ms => 2000,
        p_gps_quality => 'BAD',
        p_gps_quality_note => 'Known physical move; GPS intentionally marked bad'
    ) r;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_display_state ds
        WHERE ds.setup_session_id = v_session_id
          AND ds.display_id = v_follow_display_id
          AND ds.position_mode = 'DETACHED'
          AND ds.movement_status = 'DISPLAY_MOVE'
          AND ds.last_movement_event_id = v_event_id
    ) THEN
        RAISE EXCEPTION 'Independent Display move did not detach only that Display';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_movement_event me
        WHERE me.setup_movement_event_id = v_event_id
          AND me.container_id IS NULL
          AND me.gps_quality = 'BAD'
    ) THEN
        RAISE EXCEPTION 'Display move fabricated Container movement or lost GPS quality';
    END IF;

    SELECT d.container_id
      INTO v_display_container_after
    FROM ref.display d
    WHERE d.display_id = v_follow_display_id;

    IF v_display_container_after IS DISTINCT FROM v_display_container_before THEN
        RAISE EXCEPTION 'Display movement rewrote permanent Display-to-Container assignment';
    END IF;

    SELECT r.duplicate_event
      INTO v_duplicate
    FROM ops.record_setup_movement_event(
        p_email => v_operator_email,
        p_season_year => 2026,
        p_client_event_id => v_move2_uuid,
        p_asset_type => 'CONTAINER',
        p_asset_id => v_container_id,
        p_movement_action => 'CONTAINER_MOVE',
        p_occurred_at => '2026-10-05T08:15:00-05:00'::timestamptz,
        p_device_id => 'DISPOSABLE-VALIDATION',
        p_captured_operator_email => v_operator_email,
        p_capture_method => 'TOUCH_SELECT',
        p_offline_captured => true,
        p_gps_latitude => 43.77604286,
        p_gps_longitude => -87.74487442,
        p_gps_accuracy_m => 6.0,
        p_destination_location_note => '21-Polar Bear Playground-PB'
    ) r;

    IF NOT v_duplicate THEN
        RAISE EXCEPTION 'Repeated client UUID did not remain idempotent for Container movement';
    END IF;

    PERFORM ops.record_setup_movement_event(
        p_email => v_operator_email,
        p_season_year => 2026,
        p_client_event_id => v_return_uuid,
        p_asset_type => 'CONTAINER',
        p_asset_id => v_container_id,
        p_movement_action => 'RETURNED',
        p_occurred_at => '2026-10-05T09:00:00-05:00'::timestamptz,
        p_device_id => 'DISPOSABLE-VALIDATION',
        p_captured_operator_email => v_operator_email,
        p_capture_method => 'HID_SCAN',
        p_notes => '[PREVIEW ONLY] returned to show-time Home Location'
    );

    SELECT cs.movement_status
      INTO v_status
    FROM ops.setup_container_state cs
    WHERE cs.setup_session_id = v_session_id
      AND cs.container_id = v_container_id;

    IF v_status <> 'RETURNED' THEN
        RAISE EXCEPTION 'Container return did not finish at RETURNED';
    END IF;

    SELECT c.location_code
      INTO v_container_home_after
    FROM ref.container c
    WHERE c.container_id = v_container_id;

    IF v_container_home_after IS DISTINCT FROM v_container_home THEN
        RAISE EXCEPTION 'Movement rewrote permanent Container Home Location';
    END IF;
END;
$validation$;

DO $privilege$
BEGIN
    IF has_table_privilege('fieldwiring_app','ops.setup_movement_event','INSERT')
       OR has_table_privilege('fieldwiring_app','ops.setup_movement_event','UPDATE')
       OR has_table_privilege('fieldwiring_app','ops.setup_movement_event','DELETE')
       OR has_table_privilege('fieldwiring_app','ops.setup_movement_event_display','INSERT')
       OR has_table_privilege('fieldwiring_app','ops.setup_container_state','UPDATE')
       OR has_table_privilege('fieldwiring_app','ops.setup_display_state','UPDATE') THEN
        RAISE EXCEPTION 'fieldwiring_app retains forbidden broad movement DML';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ops.record_setup_movement_event(text,integer,uuid,text,bigint,text,timestamptz,text,text,text,boolean,numeric,numeric,numeric,integer,text,text,bigint[],timestamptz,integer,text,text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute governed movement command';
    END IF;
END;
$privilege$;

ROLLBACK;

SELECT 'SETUP_88_MOVEMENT_CAPTURE_DISPOSABLE_VALIDATION_PASS' AS result;
