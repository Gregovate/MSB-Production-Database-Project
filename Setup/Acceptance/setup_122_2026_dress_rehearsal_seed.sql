\set ON_ERROR_STOP on

/* ============================================================================
#122 disposable 2026 Setup dress-rehearsal seed

Acceptance-only preparation for the reusable disposable browser preview.

This file creates the annual 2026 Setup Session from the current reusable
Catalog inside the disposable current-Production clone. It deliberately does
NOT create work days, crews, scheduled assignments, progress rows, movement
events, or Work Order Intake records.

Those are operator actions under test in the dress rehearsal.

NEVER APPLY THIS FILE TO PRODUCTION.
============================================================================ */

DO $rehearsal$
DECLARE
    v_admin_email text;
    v_session_id bigint;
    v_task_count integer;
    v_work_day_count integer;
    v_assignment_count integer;
    v_progress_count integer;
BEGIN
    SELECT lower(u.email)
      INTO v_admin_email
    FROM public.directus_users u
    JOIN ref.person p
      ON p.directus_user_id = u.id
    JOIN LATERAL ref.setup_browser_capabilities(lower(u.email)) AS c ON true
    WHERE u.status = 'active'
      AND c.can_admin_setup
    ORDER BY u.email
    LIMIT 1;

    IF v_admin_email IS NULL THEN
        RAISE EXCEPTION
            'Disposable #122 dress rehearsal requires an active Setup Administrator';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.season
        WHERE season_year = 2026
    ) THEN
        RAISE EXCEPTION
            'Disposable #122 dress rehearsal requires ref.season 2026';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ops.setup_session
        WHERE season_year = 2026
    ) THEN
        RAISE EXCEPTION
            'Disposable #122 dress rehearsal expected no pre-existing 2026 Setup Session';
    END IF;

    SELECT setup_session_id
      INTO v_session_id
    FROM ops.create_setup_session(v_admin_email, 2026, 'PLANNING');

    SELECT count(*)
      INTO v_task_count
    FROM ops.setup_session_task
    WHERE setup_session_id = v_session_id;

    IF v_task_count = 0 THEN
        RAISE EXCEPTION
            'Disposable #122 dress rehearsal created an empty 2026 annual task snapshot';
    END IF;

    SELECT count(*)
      INTO v_work_day_count
    FROM ops.setup_work_day
    WHERE setup_session_id = v_session_id;

    SELECT count(*)
      INTO v_assignment_count
    FROM ops.setup_work_day_task wdt
    JOIN ops.setup_work_day wd
      ON wd.setup_work_day_id = wdt.setup_work_day_id
    WHERE wd.setup_session_id = v_session_id;

    SELECT count(*)
      INTO v_progress_count
    FROM ops.setup_task_progress p
    JOIN ops.setup_session_task st
      ON st.setup_session_task_id = p.setup_session_task_id
    WHERE st.setup_session_id = v_session_id;

    IF v_work_day_count <> 0
       OR v_assignment_count <> 0
       OR v_progress_count <> 0 THEN
        RAISE EXCEPTION
            'Disposable #122 dress rehearsal must begin with no prebuilt schedule or progress';
    END IF;

    RAISE NOTICE
        'DISPOSABLE #122 2026 DRESS REHEARSAL READY session=% annual_tasks=% work_days=% assignments=% progress=%',
        v_session_id, v_task_count, v_work_day_count, v_assignment_count, v_progress_count;
END
$rehearsal$;

SELECT
    ss.season_year,
    ss.setup_session_id,
    ss.session_status,
    count(DISTINCT st.setup_session_task_id) AS annual_tasks,
    count(DISTINCT wd.setup_work_day_id) AS work_days,
    count(DISTINCT wdt.setup_work_day_task_id) AS assignments,
    count(DISTINCT p.setup_task_progress_id) AS progress_entries
FROM ops.setup_session ss
LEFT JOIN ops.setup_session_task st
  ON st.setup_session_id = ss.setup_session_id
LEFT JOIN ops.setup_work_day wd
  ON wd.setup_session_id = ss.setup_session_id
LEFT JOIN ops.setup_work_day_task wdt
  ON wdt.setup_work_day_id = wd.setup_work_day_id
LEFT JOIN ops.setup_task_progress p
  ON p.setup_session_task_id = st.setup_session_task_id
WHERE ss.season_year = 2026
GROUP BY ss.season_year, ss.setup_session_id, ss.session_status;
