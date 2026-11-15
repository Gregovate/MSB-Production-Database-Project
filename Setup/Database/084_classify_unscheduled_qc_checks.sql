-- #122/#205: QC remains included in Setup, but is not scheduled crew work.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
ALTER TABLE ref.setup_task ADD COLUMN qc_check_flag boolean NOT NULL DEFAULT false;
ALTER TABLE ops.setup_session_task ADD COLUMN qc_check_flag boolean NOT NULL DEFAULT false;
-- Capture the installed083 eligibility before replacing its name-based predicate.
UPDATE ops.setup_session_task t SET qc_check_flag=true
WHERE ops.setup_qc_is_final_task(t.setup_session_task_id);
UPDATE ref.setup_task r SET qc_check_flag=true
WHERE EXISTS(SELECT 1 FROM ops.setup_session_task t
             WHERE t.setup_task_id=r.setup_task_id AND t.qc_check_flag);
COMMENT ON COLUMN ref.setup_task.qc_check_flag IS
 'QC managed outside scheduling; remains active in the reusable catalog.';
COMMENT ON COLUMN ops.setup_session_task.qc_check_flag IS
 'Annual QC classification; excluded from scheduling and ordinary work totals.';
GRANT SELECT(qc_check_flag) ON ref.setup_task,ops.setup_session_task TO fieldwiring_app;

-- Future annual tasks inherit catalog classification without changing historical
-- snapshots when someone later edits the reusable task name or classification.
CREATE FUNCTION ops.setup_inherit_qc_classification() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ops,ref AS $inherit$
BEGIN
 IF NEW.setup_task_id IS NOT NULL THEN
   SELECT r.qc_check_flag INTO NEW.qc_check_flag FROM ref.setup_task r
   WHERE r.setup_task_id=NEW.setup_task_id;
   NEW.qc_check_flag := coalesce(NEW.qc_check_flag,false);
 END IF;
 RETURN NEW;
END $inherit$;
REVOKE ALL ON FUNCTION ops.setup_inherit_qc_classification() FROM PUBLIC,fieldwiring_app;
CREATE TRIGGER setup_session_task_inherit_qc
BEFORE INSERT ON ops.setup_session_task FOR EACH ROW
EXECUTE FUNCTION ops.setup_inherit_qc_classification();

CREATE OR REPLACE FUNCTION ops.setup_qc_is_final_task(p_task bigint)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=pg_catalog,ops,ref AS $eligible$
SELECT EXISTS(SELECT 1 FROM ops.setup_session_task t
 WHERE t.setup_session_task_id=p_task AND t.included_flag AND t.qc_check_flag);
$eligible$;

-- All scheduling commands ultimately write this table. Retain existing rows,
-- allow removal/other history operations, but reject new or moved QC assignments.
CREATE FUNCTION ops.setup_reject_qc_scheduling() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ops AS $guard$
BEGIN
 IF TG_OP='UPDATE' THEN
   IF NEW.setup_session_task_id IS NOT DISTINCT FROM OLD.setup_session_task_id
      AND NEW.setup_work_day_id IS NOT DISTINCT FROM OLD.setup_work_day_id
      AND NEW.setup_work_day_crew_id IS NOT DISTINCT FROM OLD.setup_work_day_crew_id
      AND NEW.shift_code IS NOT DISTINCT FROM OLD.shift_code THEN RETURN NEW; END IF;
 END IF;
 IF EXISTS(SELECT 1 FROM ops.setup_session_task t
           WHERE t.setup_session_task_id=NEW.setup_session_task_id AND t.qc_check_flag) THEN
   RAISE EXCEPTION USING ERRCODE='22023',
     MESSAGE='QC checks are managed in QC Check and cannot be scheduled';
 END IF;
 RETURN NEW;
END $guard$;
REVOKE ALL ON FUNCTION ops.setup_reject_qc_scheduling() FROM PUBLIC,fieldwiring_app;
CREATE TRIGGER setup_work_day_task_no_qc_schedule
BEFORE INSERT OR UPDATE ON ops.setup_work_day_task FOR EACH ROW
EXECUTE FUNCTION ops.setup_reject_qc_scheduling();
COMMIT;
