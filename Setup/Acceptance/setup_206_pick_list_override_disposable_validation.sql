\set ON_ERROR_STOP on

BEGIN;

DO $validation$
DECLARE
    v_session_id bigint;
    v_container_id integer;
    v_workshop_container_id integer;
    v_destination_stage_id integer;
    v_override_id bigint;
    v_updated_override_id bigint;
    v_operator text;
    v_movement_event_id bigint;
    v_movement_uuid uuid;
BEGIN
    IF to_regclass('ops.setup_pick_list_override') IS NULL THEN
        RAISE EXCEPTION 'Pick List override table is missing';
    END IF;

    IF to_regprocedure(
        'ops.set_setup_pick_list_override(text,integer,integer,date,date,integer,text,boolean)'
    ) IS NULL THEN
        RAISE EXCEPTION 'Pick List override command is missing';
    END IF;

    IF to_regprocedure(
        'ops.record_setup_movement_event(text,integer,uuid,text,bigint,text,timestamptz,text,text,text,boolean,numeric,numeric,numeric,integer,text,text,bigint[],timestamptz,integer,text,text)'
    ) IS NULL THEN
        RAISE EXCEPTION 'Setup movement command is required for override-cancel preservation validation';
    END IF;

    SELECT ss.setup_session_id
      INTO v_session_id
    FROM ops.setup_session ss
    WHERE ss.season_year = 2026
      AND ss.session_status <> 'COMPLETE';

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION 'Open 2026 Setup Session is required for #206 validation';
    END IF;

    SELECT c.container_id
      INTO v_workshop_container_id
    FROM ref.container c
    WHERE c.goes_to_endpoint_id = 1
    ORDER BY c.container_id
    LIMIT 1;

    IF v_workshop_container_id IS NULL THEN
        RAISE EXCEPTION 'A Workshop-marked Container is required for #206 override exclusion validation';
    END IF;

    SELECT c.container_id
      INTO v_container_id
    FROM ref.container c
    WHERE c.goes_to_endpoint_id IS DISTINCT FROM 1
      AND NOT EXISTS (
        SELECT 1
        FROM ops.setup_container_state cs
        WHERE cs.setup_session_id = v_session_id
          AND cs.container_id = c.container_id
          AND cs.last_movement_event_id IS NOT NULL
    )
    ORDER BY c.container_id
    LIMIT 1;

    IF v_container_id IS NULL THEN
        RAISE EXCEPTION 'No unobserved Container is available for disposable override validation';
    END IF;

    SELECT s.stage_id
      INTO v_destination_stage_id
    FROM ref.stage s
    WHERE s.stage_key IS NOT NULL
    ORDER BY s.park_order NULLS LAST, s.sub_order NULLS LAST, s.stage_key
    LIMIT 1;

    IF v_destination_stage_id IS NULL THEN
        RAISE EXCEPTION 'No governed destination Stage is available for disposable override validation';
    END IF;

    BEGIN
        PERFORM ops.set_setup_pick_list_override(
            'gliebig@sheboyganlights.org',
            2026,
            v_workshop_container_id,
            DATE '2026-12-29',
            DATE '2026-12-30',
            v_destination_stage_id,
            '[PREVIEW ONLY] Workshop Container rejection',
            true
        );
        RAISE EXCEPTION 'Workshop-marked Container was incorrectly accepted as Manager Pick List demand';
    EXCEPTION
        WHEN SQLSTATE '23514' THEN
            IF SQLERRM NOT LIKE '%Workshop Containers cannot be added%' THEN
                RAISE;
            END IF;
    END;

    BEGIN
        PERFORM ops.set_setup_pick_list_override(
            'gliebig@sheboyganlights.org',
            2026,
            v_container_id,
            DATE '2026-09-27',
            DATE '2026-09-28',
            v_destination_stage_id,
            '[PREVIEW ONLY] Sunday Pick By rejection',
            true
        );
        RAISE EXCEPTION 'Sunday Pick By was incorrectly accepted';
    EXCEPTION
        WHEN SQLSTATE '22023' THEN
            IF SQLERRM NOT LIKE '%Pick By cannot be Sunday%' THEN
                RAISE;
            END IF;
    END;

    SELECT r.setup_pick_list_override_id, r.operator_display_name
      INTO v_override_id, v_operator
    FROM ops.set_setup_pick_list_override(
        'gliebig@sheboyganlights.org',
        2026,
        v_container_id,
        DATE '2026-10-01',
        DATE '2026-10-01',
        v_destination_stage_id,
        '[PREVIEW ONLY] #206 Manager early-pick override validation',
        true
    ) r;

    IF v_override_id IS NULL OR v_operator IS NULL THEN
        RAISE EXCEPTION 'Manager override command returned incomplete evidence';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_pick_list_override o
        WHERE o.setup_pick_list_override_id = v_override_id
          AND o.setup_session_id = v_session_id
          AND o.container_id = v_container_id
          AND o.pick_by_date = DATE '2026-10-01'
          AND o.needed_for_date = DATE '2026-10-01'
          AND o.destination_stage_id = v_destination_stage_id
          AND o.active_flag
          AND o.created_by_person_id IS NOT NULL
          AND o.updated_by_person_id IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'Manager override row did not retain required session/container/timing/audit state';
    END IF;

    SELECT r.setup_pick_list_override_id
      INTO v_updated_override_id
    FROM ops.set_setup_pick_list_override(
        'gliebig@sheboyganlights.org',
        2026,
        v_container_id,
        DATE '2026-10-05',
        DATE '2026-10-05',
        v_destination_stage_id,
        '[PREVIEW ONLY] #206 corrected Manager pick timing',
        true
    ) r;

    IF v_updated_override_id IS DISTINCT FROM v_override_id THEN
        RAISE EXCEPTION 'Editing Manager override timing created a second override identity';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_pick_list_override o
        WHERE o.setup_pick_list_override_id = v_override_id
          AND o.setup_session_id = v_session_id
          AND o.container_id = v_container_id
          AND o.pick_by_date = DATE '2026-10-05'
          AND o.needed_for_date = DATE '2026-10-05'
          AND o.override_reason = '[PREVIEW ONLY] #206 corrected Manager pick timing'
          AND o.active_flag
    ) THEN
        RAISE EXCEPTION 'Manager override timing edit did not update the existing demand row';
    END IF;

    IF (
        SELECT count(*)
        FROM ops.setup_pick_list_override o
        WHERE o.setup_session_id = v_session_id
          AND o.container_id = v_container_id
    ) <> 1 THEN
        RAISE EXCEPTION 'Manager override timing edit produced duplicate Container demand rows';
    END IF;

    v_movement_uuid := md5(clock_timestamp()::text || random()::text)::uuid;

    SELECT r.setup_movement_event_id
      INTO v_movement_event_id
    FROM ops.record_setup_movement_event(
        p_email => 'gliebig@sheboyganlights.org',
        p_season_year => 2026,
        p_client_event_id => v_movement_uuid,
        p_asset_type => 'CONTAINER',
        p_asset_id => v_container_id,
        p_movement_action => 'PICKED',
        p_occurred_at => clock_timestamp(),
        p_device_id => 'DISPOSABLE-OVERRIDE-CANCEL',
        p_captured_operator_email => 'gliebig@sheboyganlights.org',
        p_capture_method => 'MANUAL_ENTRY',
        p_notes => '[PREVIEW ONLY] prove physical movement survives override cancellation'
    ) r;

    IF v_movement_event_id IS NULL THEN
        RAISE EXCEPTION 'Disposable movement evidence was not created before override cancellation';
    END IF;

    PERFORM ops.set_setup_pick_list_override(
        'gliebig@sheboyganlights.org',
        2026,
        v_container_id,
        NULL,
        NULL,
        NULL,
        NULL,
        false
    );

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_movement_event me
        WHERE me.setup_movement_event_id = v_movement_event_id
          AND me.container_id = v_container_id
          AND me.event_type = 'PICKED'
    ) THEN
        RAISE EXCEPTION 'Canceling Manager override incorrectly removed physical movement history';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_container_state cs
        WHERE cs.setup_session_id = v_session_id
          AND cs.container_id = v_container_id
          AND cs.last_movement_event_id = v_movement_event_id
          AND cs.movement_status = 'PICKED'
    ) THEN
        RAISE EXCEPTION 'Canceling Manager override incorrectly changed current Container movement state';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_pick_list_override o
        WHERE o.setup_pick_list_override_id = v_override_id
          AND o.active_flag
    ) THEN
        RAISE EXCEPTION 'Manager override cancel did not clear active demand';
    END IF;
END;
$validation$;

DO $privilege$
BEGIN
    IF has_table_privilege(
        'fieldwiring_app',
        'ops.setup_pick_list_override',
        'INSERT'
    ) OR has_table_privilege(
        'fieldwiring_app',
        'ops.setup_pick_list_override',
        'UPDATE'
    ) OR has_table_privilege(
        'fieldwiring_app',
        'ops.setup_pick_list_override',
        'DELETE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app has forbidden broad Pick List override DML';
    END IF;

    IF NOT has_table_privilege(
        'fieldwiring_app',
        'ops.setup_pick_list_override',
        'SELECT'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot read Pick List overrides';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ops.set_setup_pick_list_override(text,integer,integer,date,date,integer,text,boolean)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute governed Pick List override command';
    END IF;
END;
$privilege$;

ROLLBACK;

SELECT 'SETUP_206_PICK_LIST_OVERRIDE_DISPOSABLE_VALIDATION_PASS' AS result;
