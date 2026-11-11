-- #122 QC / 081, disposable current-Production clone ONLY.
-- ROLLBACK all test rows. Do not send notifications / create WO / schedule.
BEGIN;
DO $test$
DECLARE
  v_task bigint;
  v_year integer;
  v_before bigint;
  v_after bigint;
  v_report jsonb;
  v_finding bigint;
  v_actor text := 'gliebig@sheboyganlights.org';
BEGIN
  SELECT t.setup_session_task_id,ss.season_year
    INTO v_task,v_year
  FROM ops.setup_session_task t
  JOIN ops.setup_session ss ON ss.setup_session_id=t.setup_session_id
  WHERE ss.season_year=2026
    AND t.annual_task_name ~* 'plug[[:space:]]+in[[:space:]]+network[[:space:]]+to[[:space:]]+controller.*2[[:space:]]+minute[[:space:]]+test[[:space:]]+show'
    AND NOT EXISTS (
      SELECT 1 FROM ops.setup_work_day_task w
      WHERE w.setup_session_task_id=t.setup_session_task_id
    )
  ORDER BY t.setup_session_task_id DESC LIMIT 1;
  IF v_task IS NULL THEN
    RAISE EXCEPTION 'QC fixture unavailable: 2026 unscheduled final QC task';
  END IF;
  SELECT count(*) INTO v_before FROM ops.setup_work_day_task;
  SELECT ops.setup_qc_command(v_actor,'CLAIM_AUDIT',v_task)
    INTO v_report;
  IF (v_report->>'task_id')::bigint<>v_task THEN
    RAISE EXCEPTION 'Self assignment did not preserve exact annual task';
  END IF;
  SELECT ops.setup_qc_command(v_actor,'REPORT',v_task,NULL,
    'Observed during initial power-up; red channel out',
    'Disposable QC acceptance red channel',
    'INITIAL_POWER','Arch 3 left to right channel 3',NULL)
    INTO v_report;
  v_finding := (v_report->>'finding_id')::bigint;
  IF v_finding IS NULL THEN RAISE EXCEPTION 'Report did not persist finding'; END IF;
  PERFORM ops.setup_qc_command(v_actor,'OBSERVATION',v_task,v_finding,
    'Second auditor confirms same missing channel');
  PERFORM ops.setup_qc_command(v_actor,'CLAIM_REPAIR',v_task,v_finding,
    'Claimed on unscheduled QC');
  PERFORM ops.setup_qc_command(v_actor,'REPAIRED',v_task,v_finding,
    'Repaired wiring termination; awaiting functional retest');
  IF (SELECT status FROM ops.setup_qc_finding WHERE qc_finding_id=v_finding)
     <> 'AWAITING_RETEST' THEN
    RAISE EXCEPTION 'Repair incorrectly marked verified';
  END IF;
  PERFORM ops.setup_qc_command(v_actor,'RETEST_FAIL',v_task,v_finding,
    'Functional channel still off');
  IF (SELECT status FROM ops.setup_qc_finding WHERE qc_finding_id=v_finding)
     <> 'OPEN' THEN
    RAISE EXCEPTION 'Failed retest did not reopen finding';
  END IF;
  PERFORM ops.setup_qc_command(v_actor,'REPAIRED',v_task,v_finding,
    'Second repair completed');
  PERFORM ops.setup_qc_command(v_actor,'RETEST_PASS',v_task,v_finding,
    'Field observer confirms channel illuminates');
  IF (SELECT status FROM ops.setup_qc_finding WHERE qc_finding_id=v_finding)
     <> 'VERIFIED' THEN
    RAISE EXCEPTION 'Verified finding not recorded';
  END IF;
  SELECT count(*) INTO v_after FROM ops.setup_work_day_task;
  IF v_before<>v_after THEN
    RAISE EXCEPTION 'QC unexpectedly scheduled work';
  END IF;
  IF EXISTS (SELECT 1 FROM ops.setup_task_progress p
     WHERE p.setup_session_task_id=v_task
       AND p.progress_note LIKE '%Disposable QC acceptance%') THEN
    RAISE EXCEPTION 'QC silently created ordinary work report';
  END IF;
  RAISE NOTICE 'QC 081 CLONE acceptance PASS: unscheduled %, report, observation, repair, failed and passed retest; no scheduling',v_task;
END
$test$;
ROLLBACK;
