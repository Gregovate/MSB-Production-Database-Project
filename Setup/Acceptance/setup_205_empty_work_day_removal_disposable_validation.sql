\set ON_ERROR_STOP on

BEGIN;

DO $validation$
DECLARE
    v_admin_email text;
    v_session_id bigint;
    v_year integer;
    v_date date;
    v_day_id bigint;
    v_readded_day_id bigint;
    v_crew_a_id bigint;
    v_crew_b_id bigint;
    v_captain_person_id integer;
    v_task_id bigint;
    v_assignment_id bigint;
    v_blocked boolean;
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
        RAISE EXCEPTION 'No active Setup Manager is available for disposable empty-day validation';
    END IF;

    SELECT ss.setup_session_id, ss.season_year
      INTO v_session_id, v_year
    FROM ops.setup_session ss
    WHERE ss.season_year = 2026
    LIMIT 1;

    IF v_session_id IS NULL THEN
        RAISE EXCEPTION '2026 Setup Session is required for disposable empty-day validation';
    END IF;

    IF NOT has_function_privilege(
        'fieldwiring_app',
        'ops.remove_empty_setup_work_day(text,bigint)',
        'EXECUTE'
    ) THEN
        RAISE EXCEPTION 'fieldwiring_app cannot execute guarded empty-day removal command';
    END IF;

    IF has_table_privilege('fieldwiring_app', 'ops.setup_work_day', 'DELETE') THEN
        RAISE EXCEPTION 'fieldwiring_app unexpectedly has broad Setup work-day DELETE';
    END IF;

    SELECT d::date
      INTO v_date
    FROM generate_series(
        make_date(v_year, 1, 1),
        make_date(v_year, 12, 31),
        interval '1 day'
    ) AS g(d)
    WHERE NOT EXISTS (
        SELECT 1
        FROM ops.setup_work_day wd
        WHERE wd.setup_session_id = v_session_id
          AND wd.work_date = d::date
    )
    ORDER BY d DESC
    LIMIT 1;

    IF v_date IS NULL THEN
        RAISE EXCEPTION 'No unused date is available for disposable empty-day validation';
    END IF;

    SELECT setup_work_day_id
      INTO v_day_id
    FROM ops.upsert_setup_work_day(
        v_admin_email,
        v_year,
        v_date,
        NULL,
        'PLANNED',
        'Disposable weather planning note',
        'Disposable volunteer planning note',
        'Disposable day note'
    );

    SELECT c.setup_work_day_crew_id
      INTO v_crew_a_id
    FROM ops.setup_work_day_crew c
    WHERE c.setup_work_day_id = v_day_id
      AND c.crew_number = 1;

    PERFORM *
    FROM ops.update_setup_work_day_crew(
        v_admin_email,
        v_crew_a_id,
        2,
        NULL,
        NULL
    );

    /* Planning metadata is not historical evidence: deletion must still work. */
    PERFORM *
    FROM ops.remove_empty_setup_work_day(v_admin_email, v_day_id);

    IF EXISTS (
        SELECT 1
        FROM ops.setup_work_day wd
        WHERE wd.setup_work_day_id = v_day_id
    ) THEN
        RAISE EXCEPTION 'Guarded empty-day removal did not delete the eligible work day';
    END IF;

    /* Re-adding the same calendar date must be supported after deletion. */
    SELECT setup_work_day_id
      INTO v_readded_day_id
    FROM ops.upsert_setup_work_day(
        v_admin_email,
        v_year,
        v_date,
        NULL,
        'PLANNED',
        NULL,
        NULL,
        NULL
    );

    IF v_readded_day_id IS NULL OR v_readded_day_id = v_day_id THEN
        RAISE EXCEPTION 'Deleted Setup date was not re-addable as a new work day';
    END IF;

    SELECT c.setup_work_day_crew_id
      INTO v_crew_a_id
    FROM ops.setup_work_day_crew c
    WHERE c.setup_work_day_id = v_readded_day_id
      AND c.crew_number = 1;

    SELECT p.person_id
      INTO v_captain_person_id
    FROM ref.setup_captain_person_list() p
    ORDER BY p.display_name, p.person_id
    LIMIT 1;

    IF v_captain_person_id IS NULL THEN
        RAISE EXCEPTION 'No active Captain candidate is available for disposable guard validation';
    END IF;

    PERFORM *
    FROM ops.update_setup_work_day_crew(
        v_admin_email,
        v_crew_a_id,
        NULL,
        NULL,
        v_captain_person_id
    );

    v_blocked := false;
    BEGIN
        PERFORM *
        FROM ops.remove_empty_setup_work_day(v_admin_email, v_readded_day_id);
    EXCEPTION
        WHEN check_violation THEN
            v_blocked := true;
    END;
    IF NOT v_blocked THEN
        RAISE EXCEPTION 'Work day with assigned Captain was unexpectedly removable';
    END IF;

    PERFORM *
    FROM ops.update_setup_work_day_crew(
        v_admin_email,
        v_crew_a_id,
        NULL,
        NULL,
        NULL
    );

    SELECT setup_work_day_crew_id
      INTO v_crew_b_id
    FROM ops.add_setup_work_day_crew(v_admin_email, v_readded_day_id);

    v_blocked := false;
    BEGIN
        PERFORM *
        FROM ops.remove_empty_setup_work_day(v_admin_email, v_readded_day_id);
    EXCEPTION
        WHEN check_violation THEN
            v_blocked := true;
    END;
    IF NOT v_blocked THEN
        RAISE EXCEPTION 'Work day with more than one Crew was unexpectedly removable';
    END IF;

    PERFORM *
    FROM ops.remove_setup_work_day_crew(v_admin_email, v_crew_b_id);

    SELECT setup_session_task_id
      INTO v_task_id
    FROM ops.create_setup_season_task(
        v_admin_email,
        v_year,
        '[DISPOSABLE #205] Empty Day Guard',
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
        v_readded_day_id,
        v_task_id,
        'MORNING',
        v_crew_a_id,
        10
    );

    v_blocked := false;
    BEGIN
        PERFORM *
        FROM ops.remove_empty_setup_work_day(v_admin_email, v_readded_day_id);
    EXCEPTION
        WHEN check_violation THEN
            v_blocked := true;
    END;
    IF NOT v_blocked THEN
        RAISE EXCEPTION 'Work day with a scheduled task was unexpectedly removable';
    END IF;

    PERFORM *
    FROM ops.remove_setup_work_day_assignment(v_admin_email, v_assignment_id);

    PERFORM *
    FROM ops.remove_empty_setup_work_day(v_admin_email, v_readded_day_id);

    IF EXISTS (
        SELECT 1
        FROM ops.setup_work_day wd
        WHERE wd.work_date = v_date
          AND wd.setup_session_id = v_session_id
    ) THEN
        RAISE EXCEPTION 'Final disposable empty-day removal did not clear validation date';
    END IF;
END
$validation$;

ROLLBACK;

SELECT 'SETUP_205_EMPTY_WORK_DAY_REMOVAL_DISPOSABLE_VALIDATION_PASS' AS result;
