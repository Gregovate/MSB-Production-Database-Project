\set ON_ERROR_STOP on

BEGIN;

DO $validation$
DECLARE
    v_admin_email text;
    v_session_id bigint;
    v_year integer;
    v_past_date date;
    v_move_date_a date;
    v_move_date_b date;
    v_day_id bigint;
    v_deleted_day_number integer;
    v_day_a bigint;
    v_day_b bigint;
    v_crew_a bigint;
    v_crew_b bigint;
    v_task_id bigint;
    v_assignment_id bigint;
    v_blocked boolean := false;
BEGIN
    SELECT lower(u.email)
      INTO v_admin_email
    FROM public.directus_users u
    JOIN ref.person p
      ON p.directus_user_id = u.id
    JOIN LATERAL ref.setup_browser_capabilities(u.email) c ON true
    WHERE u.status = 'active'
      AND c.can_manage_setup
    ORDER BY c.can_admin_setup DESC, u.email
    LIMIT 1;

    IF v_admin_email IS NULL THEN
        RAISE EXCEPTION 'No active Setup Manager is available for #205 disposable validation';
    END IF;

    SELECT ss.setup_session_id, ss.season_year
      INTO v_session_id, v_year
    FROM ops.setup_session ss
    WHERE ss.session_status <> 'HISTORICAL_VERIFICATION'
    ORDER BY ss.season_year DESC, ss.setup_session_id DESC
    LIMIT 1;

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION 'No open annual Setup Session is available for #205 disposable validation';
    END IF;

    /* Migration normalization must make retained Work Days exactly 1..N in
       chronological order. Stable row identity is not part of this display
       sequence and is intentionally untouched. */
    IF EXISTS (
        SELECT 1
        FROM (
            SELECT
                wd.setup_work_day_id,
                wd.setup_day_number,
                row_number() OVER (
                    ORDER BY wd.work_date, wd.setup_work_day_id
                )::integer AS expected_day_number
            FROM ops.setup_work_day wd
            WHERE wd.setup_session_id = v_session_id
        ) ranked
        WHERE ranked.setup_day_number <> ranked.expected_day_number
    ) THEN
        RAISE EXCEPTION 'Open annual Setup Day numbers are not contiguous chronological 1..N after migration 069';
    END IF;

    IF to_regclass('ops.setup_schedule_event') IS NULL
       OR to_regprocedure('ops.add_historical_setup_work_day(text,integer,date,text)') IS NULL
       OR to_regprocedure('ops.remove_empty_setup_work_day(text,bigint,text)') IS NULL THEN
        RAISE EXCEPTION 'Migration 069 objects are incomplete';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ops.add_historical_setup_work_day(text,integer,date,text)',
        'EXECUTE'
    ) OR NOT has_function_privilege(
        'fieldwiring_app',
        'ops.remove_empty_setup_work_day(text,bigint,text)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app lacks one or more governed #205 correction commands';
    END IF;

    IF has_table_privilege('fieldwiring_app', 'ops.setup_schedule_event', 'INSERT')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_schedule_event', 'UPDATE')
       OR has_table_privilege('fieldwiring_app', 'ops.setup_schedule_event', 'DELETE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has direct schedule-event DML';
    END IF;

    /* Ordinary work-day creation must still reject a past date. */
    SELECT d::date
      INTO v_past_date
    FROM generate_series(
        make_date(v_year, 1, 1),
        least(make_date(v_year, 12, 31), current_date - 1),
        interval '1 day'
    ) AS g(d)
    WHERE NOT EXISTS (
        SELECT 1
        FROM ops.setup_work_day wd
        WHERE wd.setup_session_id = v_session_id
          AND wd.work_date = d::date
    )
    ORDER BY d
    LIMIT 1;

    IF v_past_date IS NULL THEN
        RAISE EXCEPTION 'No unused past date is available for historical-correction validation';
    END IF;

    v_blocked := false;
    BEGIN
        PERFORM *
        FROM ops.upsert_setup_work_day(
            v_admin_email,
            v_year,
            v_past_date,
            NULL,
            'PLANNED',
            NULL,
            NULL,
            NULL
        );
    EXCEPTION
        WHEN invalid_parameter_value THEN
            v_blocked := true;
    END;
    IF NOT v_blocked THEN
        RAISE EXCEPTION 'Ordinary Add Work Days unexpectedly accepted a past date';
    END IF;

    /* Manager historical correction intentionally bypasses only that trigger. */
    SELECT setup_work_day_id
      INTO v_day_id
    FROM ops.add_historical_setup_work_day(
        v_admin_email,
        v_year,
        v_past_date,
        'Disposable historical correction'
    );

    IF v_day_id IS NULL THEN
        RAISE EXCEPTION 'Historical work-day correction returned no identity';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_schedule_event e
        WHERE e.setup_session_id = v_session_id
          AND e.event_type = 'HISTORICAL_WORK_DAY_ADDED'
          AND e.to_work_day_id = v_day_id
          AND e.to_work_date = v_past_date
          AND e.event_note = 'Disposable historical correction'
    ) THEN
        RAISE EXCEPTION 'Historical work-day addition was not passively audited';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM (
            SELECT
                wd.setup_day_number,
                row_number() OVER (
                    ORDER BY wd.work_date, wd.setup_work_day_id
                )::integer AS expected_day_number
            FROM ops.setup_work_day wd
            WHERE wd.setup_session_id = v_session_id
        ) ranked
        WHERE ranked.setup_day_number <> ranked.expected_day_number
    ) THEN
        RAISE EXCEPTION 'Historical work-day insertion did not renumber retained days chronologically';
    END IF;

    SELECT wd.setup_day_number
      INTO v_deleted_day_number
    FROM ops.setup_work_day wd
    WHERE wd.setup_work_day_id = v_day_id;

    PERFORM *
    FROM ops.remove_empty_setup_work_day(
        v_admin_email,
        v_day_id,
        'Required lift unavailable'
    );

    IF EXISTS (
        SELECT 1
        FROM ops.setup_work_day wd
        WHERE wd.setup_work_day_id = v_day_id
    ) THEN
        RAISE EXCEPTION 'Historical correction day was not removed';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_schedule_event e
        WHERE e.setup_session_id = v_session_id
          AND e.event_type = 'WORK_DAY_DELETED'
          AND e.from_work_day_id = v_day_id
          AND e.from_work_date = v_past_date
          AND e.from_setup_day_number = v_deleted_day_number
          AND e.event_note = 'Required lift unavailable'
    ) THEN
        RAISE EXCEPTION 'Deleted Work Day note/date/day-number evidence was not retained';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM (
            SELECT
                wd.setup_day_number,
                row_number() OVER (
                    ORDER BY wd.work_date, wd.setup_work_day_id
                )::integer AS expected_day_number
            FROM ops.setup_work_day wd
            WHERE wd.setup_session_id = v_session_id
        ) ranked
        WHERE ranked.setup_day_number <> ranked.expected_day_number
    ) THEN
        RAISE EXCEPTION 'Work-day deletion did not collapse Setup Day numbers chronologically';
    END IF;

    /* Prove passive move history without asking the operator for a reason. */
    SELECT min(d)::date
      INTO v_move_date_a
    FROM generate_series(
        greatest(current_date + 7, make_date(v_year, 1, 1)),
        make_date(v_year, 12, 30),
        interval '1 day'
    ) AS g(d)
    WHERE NOT EXISTS (
        SELECT 1
        FROM ops.setup_work_day wd
        WHERE wd.setup_session_id = v_session_id
          AND wd.work_date = d::date
    );

    IF v_move_date_a IS NULL THEN
        RAISE EXCEPTION 'No unused future date is available for assignment-move validation';
    END IF;

    SELECT min(d)::date
      INTO v_move_date_b
    FROM generate_series(
        v_move_date_a + 1,
        make_date(v_year, 12, 31),
        interval '1 day'
    ) AS g(d)
    WHERE NOT EXISTS (
        SELECT 1
        FROM ops.setup_work_day wd
        WHERE wd.setup_session_id = v_session_id
          AND wd.work_date = d::date
    );

    IF v_move_date_b IS NULL THEN
        RAISE EXCEPTION 'No second unused future date is available for assignment-move validation';
    END IF;

    SELECT setup_work_day_id INTO v_day_a
    FROM ops.upsert_setup_work_day(
        v_admin_email, v_year, v_move_date_a, NULL, 'PLANNED', NULL, NULL, NULL
    );
    SELECT setup_work_day_id INTO v_day_b
    FROM ops.upsert_setup_work_day(
        v_admin_email, v_year, v_move_date_b, NULL, 'PLANNED', NULL, NULL, NULL
    );

    SELECT c.setup_work_day_crew_id INTO v_crew_a
    FROM ops.setup_work_day_crew c
    WHERE c.setup_work_day_id = v_day_a
      AND c.crew_number = 1;
    SELECT c.setup_work_day_crew_id INTO v_crew_b
    FROM ops.setup_work_day_crew c
    WHERE c.setup_work_day_id = v_day_b
      AND c.crew_number = 1;

    SELECT setup_session_task_id
      INTO v_task_id
    FROM ops.create_setup_season_task(
        v_admin_email,
        v_year,
        '[DISPOSABLE #205] Passive Move Audit',
        NULL,
        NULL,
        'WORK',
        999999,
        1,
        1,
        15,
        'LIGHT',
        NULL,
        NULL,
        NULL,
        NULL,
        false,
        'Disposable validation only.'
    );

    SELECT setup_work_day_task_id
      INTO v_assignment_id
    FROM ops.create_setup_work_day_assignment(
        v_admin_email,
        v_day_a,
        v_task_id,
        'MORNING',
        v_crew_a,
        10
    );

    PERFORM *
    FROM ops.update_setup_work_day_assignment(
        v_admin_email,
        v_assignment_id,
        v_day_b,
        'AFTERNOON',
        v_crew_b,
        20
    );

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_schedule_event e
        WHERE e.setup_session_id = v_session_id
          AND e.event_type = 'ASSIGNMENT_MOVED'
          AND e.setup_work_day_task_id = v_assignment_id
          AND e.setup_session_task_id = v_task_id
          AND e.from_work_day_id = v_day_a
          AND e.to_work_day_id = v_day_b
          AND e.from_shift_code = 'MORNING'
          AND e.to_shift_code = 'AFTERNOON'
          AND e.event_note IS NULL
    ) THEN
        RAISE EXCEPTION 'Assignment move was not passively audited';
    END IF;
END
$validation$;

ROLLBACK;

SELECT 'SETUP_205_DAY_SEQUENCE_HISTORY_VALIDATION_PASS' AS result;
