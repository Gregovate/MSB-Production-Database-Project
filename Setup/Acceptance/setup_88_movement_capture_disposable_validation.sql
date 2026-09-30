\set ON_ERROR_STOP on

BEGIN;

DO $validation$
DECLARE
    v_session_id bigint;
    v_operator_email text;
    v_container_id integer;
    v_container_home text;
    v_container_home_after text;
    v_display_id bigint;
    v_display_container_before integer;
    v_display_container_after integer;
    v_stage_id integer;
    v_pick_uuid uuid := '88000000-0000-4000-8000-000000000001'::uuid;
    v_load_uuid uuid := '88000000-0000-4000-8000-000000000002'::uuid;
    v_return_uuid uuid := '88000000-0000-4000-8000-000000000003'::uuid;
    v_display_uuid uuid := '88000000-0000-4000-8000-000000000004'::uuid;
    v_park_uuid uuid := '88000000-0000-4000-8000-000000000005'::uuid;
    v_event_id bigint;
    v_duplicate boolean;
    v_status text;
BEGIN
    IF to_regprocedure(
        'ref.setup_movement_actor(text)'
    ) IS NULL THEN
        RAISE EXCEPTION 'Setup movement actor function is missing';
    END IF;

    IF to_regprocedure(
        'ops.record_setup_movement_event(text,integer,uuid,text,bigint,text,timestamptz,text,text,boolean,numeric,numeric,numeric,integer,text,text)'
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

    SELECT c.container_id, c.location_code
      INTO v_container_id, v_container_home
    FROM ref.container c
    ORDER BY c.container_id
    LIMIT 1;

    IF v_container_id IS NULL THEN
        RAISE EXCEPTION 'Container is required for movement validation';
    END IF;

    SELECT r.setup_movement_event_id, r.duplicate_event, r.movement_status
      INTO v_event_id, v_duplicate, v_status
    FROM ops.record_setup_movement_event(
        v_operator_email,
        2026,
        v_pick_uuid,
        'CONTAINER',
        v_container_id,
        'PICKED',
        '2026-09-30T08:00:00-05:00'::timestamptz,
        'DISPOSABLE-VALIDATION',
        'HID_SCAN',
        false,
        43.750000,
        -87.800000,
        5.0,
        NULL,
        NULL,
        '[PREVIEW ONLY] #88 PICKED validation'
    ) r;

    IF v_event_id IS NULL OR v_duplicate OR v_status <> 'PICKED' THEN
        RAISE EXCEPTION 'PICKED movement did not return expected evidence';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_container_state cs
        WHERE cs.setup_session_id = v_session_id
          AND cs.container_id = v_container_id
          AND cs.movement_status = 'PICKED'
          AND cs.last_movement_event_id = v_event_id
          AND cs.last_movement_at = '2026-09-30T08:00:00-05:00'::timestamptz
    ) THEN
        RAISE EXCEPTION 'PICKED movement did not update explicit current Container state';
    END IF;

    SELECT r.duplicate_event
      INTO v_duplicate
    FROM ops.record_setup_movement_event(
        v_operator_email,
        2026,
        v_pick_uuid,
        'CONTAINER',
        v_container_id,
        'PICKED',
        '2026-09-30T08:00:00-05:00'::timestamptz,
        'DISPOSABLE-VALIDATION',
        'HID_SCAN',
        true,
        43.750000,
        -87.800000,
        5.0,
        NULL,
        NULL,
        '[PREVIEW ONLY] idempotent replay'
    ) r;

    IF NOT v_duplicate THEN
        RAISE EXCEPTION 'Same client event identity was not treated as idempotent replay';
    END IF;

    PERFORM ops.record_setup_movement_event(
        v_operator_email,
        2026,
        v_load_uuid,
        'CONTAINER',
        v_container_id,
        'LOADED',
        '2026-09-30T08:05:00-05:00'::timestamptz,
        'DISPOSABLE-VALIDATION',
        'HID_SCAN',
        false,
        NULL,NULL,NULL,NULL,NULL,
        '[PREVIEW ONLY] #88 LOADED validation'
    );

    SELECT cs.movement_status
      INTO v_status
    FROM ops.setup_container_state cs
    WHERE cs.setup_session_id = v_session_id
      AND cs.container_id = v_container_id;

    IF v_status <> 'LOADED' THEN
        RAISE EXCEPTION 'LOADED movement did not become current explicit state';
    END IF;

    PERFORM ops.record_setup_movement_event(
        v_operator_email,
        2026,
        v_return_uuid,
        'CONTAINER',
        v_container_id,
        'RETURNED',
        '2026-09-30T08:10:00-05:00'::timestamptz,
        'DISPOSABLE-VALIDATION',
        'HID_SCAN',
        false,
        NULL,NULL,NULL,NULL,NULL,
        '[PREVIEW ONLY] #88 RETURNED validation'
    );

    SELECT cs.movement_status
      INTO v_status
    FROM ops.setup_container_state cs
    WHERE cs.setup_session_id = v_session_id
      AND cs.container_id = v_container_id;

    IF v_status <> 'RETURNED' THEN
        RAISE EXCEPTION 'RETURNED did not reset explicit current movement state';
    END IF;

    SELECT c.location_code
      INTO v_container_home_after
    FROM ref.container c
    WHERE c.container_id = v_container_id;

    IF v_container_home_after IS DISTINCT FROM v_container_home THEN
        RAISE EXCEPTION 'Movement rewrote permanent Container Home Location';
    END IF;

    SELECT d.display_id, d.container_id
      INTO v_display_id, v_display_container_before
    FROM ref.display d
    ORDER BY d.display_id
    LIMIT 1;

    IF v_display_id IS NULL THEN
        RAISE EXCEPTION 'Display is required for movement validation';
    END IF;

    SELECT r.setup_movement_event_id
      INTO v_event_id
    FROM ops.record_setup_movement_event(
        v_operator_email,
        2026,
        v_display_uuid,
        'DISPLAY',
        v_display_id,
        'PICKED',
        '2026-09-30T08:15:00-05:00'::timestamptz,
        'DISPOSABLE-VALIDATION',
        'HID_SCAN',
        false,
        NULL,NULL,NULL,NULL,NULL,
        '[PREVIEW ONLY] #88 Display PICKED validation'
    ) r;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_movement_event_display med
        WHERE med.setup_movement_event_id = v_event_id
          AND med.display_id = v_display_id
          AND med.movement_effect = 'MOVED'
    ) THEN
        RAISE EXCEPTION 'Display movement did not retain explicit Display event evidence';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_movement_event me
        WHERE me.setup_movement_event_id = v_event_id
          AND me.container_id IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'Display movement incorrectly fabricated Container movement evidence';
    END IF;

    SELECT d.container_id
      INTO v_display_container_after
    FROM ref.display d
    WHERE d.display_id = v_display_id;

    IF v_display_container_after IS DISTINCT FROM v_display_container_before THEN
        RAISE EXCEPTION 'Display movement rewrote permanent Display-to-Container assignment';
    END IF;

    SELECT s.stage_id
      INTO v_stage_id
    FROM ref.stage s
    WHERE s.stage_key IS NOT NULL
    ORDER BY s.park_order NULLS LAST, s.sub_order NULLS LAST, s.stage_key
    LIMIT 1;

    BEGIN
        PERFORM ops.record_setup_movement_event(
            v_operator_email,
            2026,
            v_park_uuid,
            'CONTAINER',
            v_container_id,
            'DELIVERED',
            '2026-10-04T12:00:00-05:00'::timestamptz,
            'DISPOSABLE-VALIDATION',
            'HID_SCAN',
            false,
            NULL,NULL,NULL,v_stage_id,NULL,
            '[PREVIEW ONLY] pre-Oct-5 park guard'
        );
        RAISE EXCEPTION 'Pre-2026-10-05 park delivery was incorrectly accepted';
    EXCEPTION
        WHEN SQLSTATE '23514' THEN
            IF SQLERRM NOT LIKE '%material-access date%' THEN
                RAISE;
            END IF;
    END;
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
        'ops.record_setup_movement_event(text,integer,uuid,text,bigint,text,timestamptz,text,text,boolean,numeric,numeric,numeric,integer,text,text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute governed movement command';
    END IF;
END;
$privilege$;

ROLLBACK;

SELECT 'SETUP_88_MOVEMENT_CAPTURE_DISPOSABLE_VALIDATION_PASS' AS result;
