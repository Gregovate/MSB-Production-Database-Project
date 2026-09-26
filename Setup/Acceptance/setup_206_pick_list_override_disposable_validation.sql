\set ON_ERROR_STOP on

BEGIN;

DO $validation$
DECLARE
    v_session_id bigint;
    v_container_id integer;
    v_override_id bigint;
    v_operator text;
BEGIN
    IF to_regclass('ops.setup_pick_list_override') IS NULL THEN
        RAISE EXCEPTION 'Pick List override table is missing';
    END IF;

    IF to_regprocedure(
        'ops.set_setup_pick_list_override(text,integer,integer,date,date,text,text,boolean)'
    ) IS NULL THEN
        RAISE EXCEPTION 'Pick List override command is missing';
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
      INTO v_container_id
    FROM ref.container c
    WHERE NOT EXISTS (
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

    BEGIN
        PERFORM ops.set_setup_pick_list_override(
            'gliebig@sheboyganlights.org',
            2026,
            v_container_id,
            DATE '2026-09-27',
            DATE '2026-09-28',
            'Disposable Sunday rejection destination',
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
        DATE '2026-12-29',
        DATE '2026-12-30',
        'Disposable validation destination',
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
          AND o.pick_by_date = DATE '2026-12-29'
          AND o.needed_for_date = DATE '2026-12-30'
          AND o.destination_note = 'Disposable validation destination'
          AND o.active_flag
          AND o.created_by_person_id IS NOT NULL
          AND o.updated_by_person_id IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'Manager override row did not retain required session/container/timing/audit state';
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
        'ops.set_setup_pick_list_override(text,integer,integer,date,date,text,text,boolean)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute governed Pick List override command';
    END IF;
END;
$privilege$;

ROLLBACK;

SELECT 'SETUP_206_PICK_LIST_OVERRIDE_DISPOSABLE_VALIDATION_PASS' AS result;
