-- #205 / #122 — disposable ONLY validation for migration 075.
-- Run after applying 075 to current-Production disposable clone.
-- Test Crew 22, the recorded failed 2026-10-16 Crew A AM save.
-- Never apply this SQL against Production.
-- The only persistent objects created are session-local temporary tables.
-- The two planning edits and attempted Captain edit are rolled back.

CREATE TEMP TABLE setup205_crew22_original ON COMMIT PRESERVE ROWS AS
SELECT setup_work_day_crew_id, am_planned_crew_count, pm_planned_crew_count,
       captain_person_id
FROM ops.setup_work_day_crew
WHERE setup_work_day_crew_id = 22;

DO $check$
BEGIN
    IF (SELECT count(*) FROM setup205_crew22_original) <> 1 THEN
        RAISE EXCEPTION 'Crew 22 unavailable: cannot certify October 16 historical-plan case';
    END IF;
    IF NOT EXISTS (
        SELECT 1
        FROM ops.setup_work_day_crew c
        JOIN ops.setup_work_day wd ON wd.setup_work_day_id = c.setup_work_day_id
        JOIN ops.setup_work_day_task a ON a.setup_work_day_crew_id = c.setup_work_day_crew_id
        WHERE c.setup_work_day_crew_id = 22 AND wd.work_date = DATE '2026-10-16'
          AND a.shift_code IN ('MORNING','ALL_DAY')
          AND (a.actual_crew_count IS NOT NULL OR a.started_at IS NOT NULL
               OR a.completed_at IS NOT NULL
               OR EXISTS (SELECT 1 FROM ops.setup_task_progress p
                          WHERE p.setup_work_day_task_id = a.setup_work_day_task_id))
    ) THEN
        RAISE EXCEPTION 'Crew 22 morning history was not found; do not claim lock regression tested';
    END IF;
END;
$check$;

CREATE TEMP TABLE setup205_crew22_actual_original ON COMMIT PRESERVE ROWS AS
SELECT a.setup_work_day_task_id, a.setup_work_day_id, a.setup_work_day_crew_id,
       a.shift_code, a.actual_crew_count, a.started_at, a.completed_at,
       (SELECT count(*) FROM ops.setup_task_progress p
        WHERE p.setup_work_day_task_id = a.setup_work_day_task_id) AS progress_count
FROM ops.setup_work_day_task a
WHERE a.setup_work_day_crew_id = 22;

BEGIN;

DO $validation$
DECLARE
    v_am integer;
    v_pm integer;
    v_captain integer;
    v_other_captain integer;
    v_new_am integer;
    v_new_pm integer;
    v_result record;
BEGIN
    SELECT am_planned_crew_count, pm_planned_crew_count, captain_person_id
    INTO STRICT v_am, v_pm, v_captain
    FROM ops.setup_work_day_crew
    WHERE setup_work_day_crew_id = 22;

    v_new_am := coalesce(v_am, 0) + 3;
    v_new_pm := coalesce(v_pm, 0) + 2;
    SELECT * INTO STRICT v_result
    FROM ops.update_setup_work_day_crew(
        'gliebig@sheboyganlights.org', 22, v_new_am, v_new_pm, v_captain
    );

    IF v_result.am_planned_crew_count IS DISTINCT FROM v_new_am
       OR v_result.pm_planned_crew_count IS DISTINCT FROM v_new_pm
       OR v_result.captain_person_id IS DISTINCT FROM v_captain THEN
        RAISE EXCEPTION 'New crew count returned incorrect saved data';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM setup205_crew22_actual_original old
        FULL JOIN (
            SELECT a.setup_work_day_task_id, a.setup_work_day_id,
                   a.setup_work_day_crew_id, a.shift_code, a.actual_crew_count,
                   a.started_at, a.completed_at,
                   (SELECT count(*) FROM ops.setup_task_progress p
                    WHERE p.setup_work_day_task_id = a.setup_work_day_task_id) AS progress_count
            FROM ops.setup_work_day_task a
            WHERE a.setup_work_day_crew_id = 22
        ) actual USING (setup_work_day_task_id)
        WHERE to_jsonb(old) IS DISTINCT FROM to_jsonb(actual)
    ) THEN
        RAISE EXCEPTION 'Changing planned counts rewrote actual assignment/progress history';
    END IF;

    -- Existing Captain historical lock still applies to actual work.
    SELECT person_id INTO v_other_captain
    FROM ref.person
    WHERE active_flag AND person_id IS DISTINCT FROM v_captain
    ORDER BY person_id LIMIT 1;
    IF v_other_captain IS NULL THEN
        RAISE EXCEPTION 'No alternate active Captain for history-lock proof';
    END IF;
    BEGIN
        PERFORM ops.update_setup_work_day_crew(
            'gliebig@sheboyganlights.org',22,v_new_am,v_new_pm,v_other_captain
        );
        RAISE EXCEPTION 'Historical Captain changed without required lock';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'PASS: historical Captain change rejected';
    END;

    RAISE NOTICE 'PASS: Crew 22 AM and PM planning counts updated; actual records preserved';
END;
$validation$;

ROLLBACK;

DO $verify_rollback$
BEGIN
    IF EXISTS (
        SELECT 1 FROM setup205_crew22_original old
        JOIN ops.setup_work_day_crew c USING (setup_work_day_crew_id)
        WHERE old.am_planned_crew_count IS DISTINCT FROM c.am_planned_crew_count
           OR old.pm_planned_crew_count IS DISTINCT FROM c.pm_planned_crew_count
           OR old.captain_person_id IS DISTINCT FROM c.captain_person_id
    ) THEN
        RAISE EXCEPTION 'Disposable SQL validation did not roll back planned crew counts';
    END IF;
    RAISE NOTICE 'PASS: simulated planning writes fully rolled back';
END;
$verify_rollback$;

DROP TABLE setup205_crew22_actual_original;
DROP TABLE setup205_crew22_original;
