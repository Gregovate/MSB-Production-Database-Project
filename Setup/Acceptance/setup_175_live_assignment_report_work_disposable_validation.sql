/* ============================================================================
MSB Setup #175/#132 — live scheduled-assignment Report Work validation
Issues: #175, #132, #122
Scope: DISPOSABLE CURRENT-PRODUCTION CLONE ONLY

Proves the live continuation loop without changing Production:
  prior unworked scheduled assignment
    -> exact-assignment partial Report Work
    -> annual task IN_PROGRESS
    -> original assignment historical / immovable
    -> no remaining unworked assignment
    -> new continuation assignment on 2026-09-28
============================================================================ */

\set ON_ERROR_STOP on

DO $validation$
DECLARE
    v_manager_email text;
    v_assignment_id bigint;
    v_session_task_id bigint;
    v_work_day_id bigint;
    v_old_work_date date;
    v_shift text;
    v_crew_id bigint;
    v_sort_order integer;
    v_progress_id bigint;
    v_new_day_id bigint;
    v_new_crew_id bigint;
    v_new_assignment_id bigint;
    v_lock_blocked boolean := false;
    v_unworked_count integer;
    v_execution_status text;
BEGIN
    SELECT lower(u.email)
      INTO v_manager_email
    FROM public.directus_users u
    JOIN LATERAL ref.setup_browser_capabilities(u.email) c ON true
    WHERE u.status = 'active'
      AND u.email IS NOT NULL
      AND c.can_manage_setup
    ORDER BY u.id
    LIMIT 1;

    IF v_manager_email IS NULL THEN
        RAISE EXCEPTION 'Disposable validation could not find an active Setup Manager';
    END IF;

    /*
      Select one real current-Production-clone assignment whose work date has
      passed, has no actual evidence yet, and is the only remaining unworked
      assignment for its annual task. The live 9/23 blocker is this shape.
    */
    SELECT
        wdt.setup_work_day_task_id,
        wdt.setup_session_task_id,
        wdt.setup_work_day_id,
        wd.work_date,
        wdt.shift_code,
        wdt.setup_work_day_crew_id,
        wdt.sort_order
      INTO
        v_assignment_id,
        v_session_task_id,
        v_work_day_id,
        v_old_work_date,
        v_shift,
        v_crew_id,
        v_sort_order
    FROM ops.setup_work_day_task wdt
    JOIN ops.setup_work_day wd
      ON wd.setup_work_day_id = wdt.setup_work_day_id
    JOIN ops.setup_session ss
      ON ss.setup_session_id = wd.setup_session_id
    JOIN ops.setup_session_task st
      ON st.setup_session_task_id = wdt.setup_session_task_id
    WHERE ss.season_year = 2026
      AND wd.day_status <> 'CANCELLED'
      AND wd.work_date < current_date
      AND st.execution_status <> 'COMPLETE'
      AND wdt.actual_crew_count IS NULL
      AND wdt.started_at IS NULL
      AND wdt.completed_at IS NULL
      AND NOT EXISTS (
          SELECT 1
          FROM ops.setup_task_progress p
          WHERE p.setup_work_day_task_id = wdt.setup_work_day_task_id
             OR (
                 p.setup_work_day_task_id IS NULL
                 AND p.setup_work_day_id = wdt.setup_work_day_id
                 AND p.setup_session_task_id = wdt.setup_session_task_id
                 AND p.shift_code = wdt.shift_code
             )
      )
      AND NOT EXISTS (
          SELECT 1
          FROM ops.setup_work_day_task other
          JOIN ops.setup_work_day other_day
            ON other_day.setup_work_day_id = other.setup_work_day_id
          WHERE other.setup_session_task_id = wdt.setup_session_task_id
            AND other.setup_work_day_task_id <> wdt.setup_work_day_task_id
            AND other_day.day_status <> 'CANCELLED'
            AND other.actual_crew_count IS NULL
            AND other.started_at IS NULL
            AND other.completed_at IS NULL
            AND NOT EXISTS (
                SELECT 1
                FROM ops.setup_task_progress p2
                WHERE p2.setup_work_day_task_id = other.setup_work_day_task_id
                   OR (
                       p2.setup_work_day_task_id IS NULL
                       AND p2.setup_work_day_id = other.setup_work_day_id
                       AND p2.setup_session_task_id = other.setup_session_task_id
                       AND p2.shift_code = other.shift_code
                   )
            )
      )
    ORDER BY wd.work_date DESC, wdt.setup_work_day_task_id
    LIMIT 1;

    IF v_assignment_id IS NULL THEN
        RAISE EXCEPTION
            'Disposable validation needs one past unworked 2026 assignment with no other unworked continuation';
    END IF;

    SELECT setup_task_progress_id
      INTO v_progress_id
    FROM ops.record_setup_task_progress(
        v_manager_email,
        v_session_task_id,
        2,                  -- actual crew
        45,                 -- elapsed minutes
        50,                 -- cumulative percent complete
        NULL,
        NULL,
        'Disposable validation: partial work recorded; remaining work needs continuation.',
        v_assignment_id,
        NULL,
        NULL
    );

    IF v_progress_id IS NULL THEN
        RAISE EXCEPTION 'Partial Report Work did not return a progress identity';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_task_progress p
        WHERE p.setup_task_progress_id = v_progress_id
          AND p.setup_session_task_id = v_session_task_id
          AND p.setup_work_day_task_id = v_assignment_id
          AND p.setup_work_day_id = v_work_day_id
          AND p.shift_code = v_shift
          AND p.crew_count = 2
          AND p.duration_minutes = 45
          AND p.percent_complete = 50
          AND p.marks_task_complete IS FALSE
    ) THEN
        RAISE EXCEPTION 'Progress row did not preserve exact assignment / duration / percent evidence';
    END IF;

    SELECT st.execution_status
      INTO v_execution_status
    FROM ops.setup_session_task st
    WHERE st.setup_session_task_id = v_session_task_id;

    IF v_execution_status <> 'IN_PROGRESS' THEN
        RAISE EXCEPTION 'Partial work did not leave annual task IN_PROGRESS: %', v_execution_status;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_work_day_task wdt
        JOIN ops.setup_work_day wd
          ON wd.setup_work_day_id = wdt.setup_work_day_id
        WHERE wdt.setup_work_day_task_id = v_assignment_id
          AND wdt.setup_work_day_id = v_work_day_id
          AND wd.work_date = v_old_work_date
          AND wdt.actual_crew_count = 2
          AND wdt.started_at IS NOT NULL
          AND wdt.completed_at IS NULL
    ) THEN
        RAISE EXCEPTION 'Original assignment did not become partial historical evidence';
    END IF;

    /*
      Historical stickiness: after actual work exists, the old assignment may
      not be moved even to its current placement.
    */
    BEGIN
        PERFORM *
        FROM ops.update_setup_work_day_assignment(
            v_manager_email,
            v_assignment_id,
            v_work_day_id,
            v_shift,
            v_crew_id,
            v_sort_order
        );
    EXCEPTION
        WHEN SQLSTATE '23514' THEN
            v_lock_blocked := true;
    END;

    IF NOT v_lock_blocked THEN
        RAISE EXCEPTION 'Historical assignment remained movable after partial work';
    END IF;

    SELECT count(*)
      INTO v_unworked_count
    FROM ops.setup_work_day_task wdt
    JOIN ops.setup_work_day wd
      ON wd.setup_work_day_id = wdt.setup_work_day_id
    WHERE wdt.setup_session_task_id = v_session_task_id
      AND wd.day_status <> 'CANCELLED'
      AND wdt.actual_crew_count IS NULL
      AND wdt.started_at IS NULL
      AND wdt.completed_at IS NULL
      AND NOT EXISTS (
          SELECT 1
          FROM ops.setup_task_progress p
          WHERE p.setup_work_day_task_id = wdt.setup_work_day_task_id
      );

    IF v_unworked_count <> 0 THEN
        RAISE EXCEPTION
            'Partial task still has % unworked assignment(s); expected continuation candidate state',
            v_unworked_count;
    END IF;

    /*
      Prove the continuation can be a distinct assignment on 9/28 while the
      old worked assignment remains untouched.
    */
    SELECT setup_work_day_id
      INTO v_new_day_id
    FROM ops.upsert_setup_work_day(
        v_manager_email,
        2026,
        DATE '2026-09-28',
        NULL,
        'PLANNED',
        NULL,
        NULL,
        'Disposable #175/#132 continuation proof'
    );

    SELECT c.setup_work_day_crew_id
      INTO v_new_crew_id
    FROM ops.setup_work_day_crew c
    WHERE c.setup_work_day_id = v_new_day_id
    ORDER BY c.crew_number
    LIMIT 1;

    IF v_new_crew_id IS NULL THEN
        RAISE EXCEPTION '9/28 continuation day has no schedulable crew';
    END IF;

    SELECT setup_work_day_task_id
      INTO v_new_assignment_id
    FROM ops.create_setup_work_day_assignment(
        v_manager_email,
        v_new_day_id,
        v_session_task_id,
        'MORNING',
        v_new_crew_id,
        100
    );

    IF v_new_assignment_id IS NULL OR v_new_assignment_id = v_assignment_id THEN
        RAISE EXCEPTION 'Continuation did not create a distinct scheduled assignment';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_work_day_task wdt
        JOIN ops.setup_work_day wd
          ON wd.setup_work_day_id = wdt.setup_work_day_id
        WHERE wdt.setup_work_day_task_id = v_new_assignment_id
          AND wdt.setup_session_task_id = v_session_task_id
          AND wd.work_date = DATE '2026-09-28'
          AND wdt.shift_code = 'MORNING'
    ) THEN
        RAISE EXCEPTION 'Distinct 9/28 continuation assignment was not preserved';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_work_day_task wdt
        JOIN ops.setup_work_day wd
          ON wd.setup_work_day_id = wdt.setup_work_day_id
        WHERE wdt.setup_work_day_task_id = v_assignment_id
          AND wd.work_date = v_old_work_date
          AND wdt.started_at IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'Creating the continuation rewrote the original historical assignment';
    END IF;

    RAISE NOTICE
        'PASS: assignment % on % -> 50%% IN_PROGRESS -> distinct 9/28 continuation %',
        v_assignment_id,
        v_old_work_date,
        v_new_assignment_id;
END
$validation$;

SELECT
    'SETUP_175_LIVE_ASSIGNMENT_REPORT_WORK_DISPOSABLE_PASS' AS result;
