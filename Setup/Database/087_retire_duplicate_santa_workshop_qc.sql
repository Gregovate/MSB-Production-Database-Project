-- #122/#205: Greg confirmed QC590 was a workaround duplicate of QC588.
-- Retain the annual row and all history; only remove the empty duplicate from
-- this season's active board. Do not infer duplicates from matching names.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
LOCK TABLE ops.setup_session_task,ops.setup_qc_finding,
  ops.setup_session_task_dependency,ref.setup_task_dependency IN SHARE ROW EXCLUSIVE MODE;
DO $cleanup$
BEGIN
 IF NOT EXISTS (
   SELECT 1 FROM ops.setup_session_task keep
   JOIN ops.setup_session_task duplicate ON duplicate.setup_session_task_id=590
   JOIN ops.setup_session s ON s.setup_session_id=keep.setup_session_id
   JOIN ref.stage stage ON stage.stage_id=keep.annual_stage_id
   WHERE keep.setup_session_task_id=588 AND keep.included_flag
     AND keep.qc_check_flag AND duplicate.qc_check_flag
     AND s.season_year=2026 AND stage.stage_name='19-Santa''s Workshop-SW'
     AND duplicate.setup_session_id=keep.setup_session_id
     AND duplicate.annual_stage_id=keep.annual_stage_id
     AND keep.annual_lor_scene_id IS NULL AND duplicate.annual_lor_scene_id IS NULL
 ) THEN
   RAISE EXCEPTION 'HOLD: expected 2026 Santa Workshop QC588/QC590 identity differs';
 END IF;
 IF EXISTS(SELECT 1 FROM ops.setup_qc_finding WHERE setup_session_task_id=590) THEN
   RAISE EXCEPTION 'HOLD: QC590 has findings; review and preserve them before retirement';
 END IF;
 IF EXISTS(SELECT 1 FROM ops.setup_session_task_dependency
           WHERE prerequisite_setup_session_task_id=590)
 OR EXISTS(SELECT 1 FROM ref.setup_task_dependency d
           JOIN ops.setup_session_task t ON t.setup_task_id=d.prerequisite_setup_task_id
           WHERE t.setup_session_task_id=590) THEN
   RAISE EXCEPTION 'HOLD: QC590 has explicit dependents; review before retirement';
 END IF;
 -- No completion or test evidence is manufactured; QC588 still requires the
 -- auditor's observed test. Existing audit triggers record this bounded change.
 UPDATE ops.setup_session_task SET included_flag=false
 WHERE setup_session_task_id=590 AND included_flag;
END
$cleanup$;
COMMIT;
