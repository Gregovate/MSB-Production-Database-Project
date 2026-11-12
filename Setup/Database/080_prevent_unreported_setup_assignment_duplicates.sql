-- #205 / #122 | Candidate migration | Prevent new unresolved work occurrences.
-- Existing assignments, reports and actual effort are not repaired or deleted.
BEGIN;
CREATE OR REPLACE FUNCTION ops.reject_unresolved_setup_assignment_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $function$
DECLARE
    v_status text;
    v_assignment bigint;
    v_date date;
BEGIN
    -- Serialize new occurrences of the same annual task, across all writers.
    SELECT st.execution_status INTO v_status
    FROM ops.setup_session_task st
    WHERE st.setup_session_task_id = NEW.setup_session_task_id
    FOR UPDATE;
    IF v_status = 'COMPLETE' THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = 'This task is complete. Review its work report instead of scheduling it again.';
    END IF;

    SELECT prior.setup_work_day_task_id, wd.work_date
    INTO v_assignment, v_date
    FROM ops.setup_work_day_task prior
    JOIN ops.setup_work_day wd ON wd.setup_work_day_id = prior.setup_work_day_id
    WHERE prior.setup_session_task_id = NEW.setup_session_task_id
      AND wd.day_status <> 'CANCELLED'
      AND NOT EXISTS (
          SELECT 1 FROM ops.setup_task_progress p
          WHERE p.setup_work_day_task_id = prior.setup_work_day_task_id
             OR (p.setup_work_day_task_id IS NULL
                 AND p.setup_session_task_id = prior.setup_session_task_id
                 AND p.setup_work_day_id = prior.setup_work_day_id
                 AND p.shift_code = prior.shift_code)
      )
    ORDER BY wd.work_date, prior.setup_work_day_task_id
    LIMIT 1;
    IF FOUND THEN
        RAISE EXCEPTION USING ERRCODE = '23514',
            MESSAGE = format('Assignment %s on %s needs resolution: report the work, or move/unschedule it if no work occurred.', v_assignment, v_date);
    END IF;
    RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION ops.reject_unresolved_setup_assignment_insert() FROM PUBLIC;
DROP TRIGGER IF EXISTS reject_unresolved_setup_assignment_insert ON ops.setup_work_day_task;
CREATE TRIGGER reject_unresolved_setup_assignment_insert
BEFORE INSERT ON ops.setup_work_day_task
FOR EACH ROW EXECUTE FUNCTION ops.reject_unresolved_setup_assignment_insert();
COMMIT;
