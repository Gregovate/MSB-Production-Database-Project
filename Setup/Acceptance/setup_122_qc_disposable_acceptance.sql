-- Purpose: #122/#205 QC 081 lifecycle, authorization and preservation proof.
-- Scope: disposable current-Production clone ONLY; all test rows roll back.
-- Existing active Manager/Crew identities are read, never created or modified.
-- ROLLBACK all test rows. Do not send notifications / create WO / schedule.
BEGIN;
-- Hash complete protected rows in deterministic order, not just row counts.
CREATE FUNCTION pg_temp.qc_protected_rows() RETURNS jsonb LANGUAGE plpgsql AS $fn$
DECLARE v_table text; v_hash text; v_result jsonb := '{}'::jsonb;
BEGIN
  FOREACH v_table IN ARRAY ARRAY[
    'ops.setup_session_task','ops.setup_work_day','ops.setup_work_day_task',
    'ops.setup_work_day_crew','ops.setup_task_progress',
    'stage.work_order_intake','ops.work_order'] LOOP
    EXECUTE format($query$SELECT md5(coalesce(string_agg(to_jsonb(t)::text, chr(10)
      ORDER BY to_jsonb(t)::text),'')) FROM %s t$query$,v_table::regclass) INTO v_hash;
    v_result := v_result || jsonb_build_object(v_table,v_hash);
  END LOOP;
  RETURN v_result;
END
$fn$;
DO $test$
DECLARE
  v_task bigint;
  v_year integer;
  v_before bigint;
  v_after bigint;
  v_report jsonb;
  v_finding bigint;
  v_preserved jsonb;
  v_crew text;
  v_other_finding bigint;
  v_snapshot jsonb;
  v_actor text := 'gliebig@sheboyganlights.org';
BEGIN
  v_preserved := pg_temp.qc_protected_rows();
  -- Use a real non-Manager Crew member with an existing People link.
  SELECT lower(u.email) INTO v_crew
  FROM public.directus_users u
  JOIN ref.person p ON p.directus_user_id=u.id
  CROSS JOIN LATERAL ref.setup_browser_capabilities(lower(u.email)) c
  WHERE u.status='active' AND c.can_read_setup AND NOT c.can_manage_setup
    AND (c.role_name='Production Crew' OR
      'Production Crew'=ANY(coalesce(c.policy_names,ARRAY[]::text[])))
  ORDER BY lower(u.email),p.person_id LIMIT 1;
  IF v_crew IS NULL THEN RAISE EXCEPTION 'QC acceptance needs existing mapped Production Crew'; END IF;
  SELECT t.setup_session_task_id,ss.season_year
    INTO v_task,v_year
  FROM ops.setup_session_task t
  JOIN ops.setup_session ss ON ss.setup_session_id=t.setup_session_id
  WHERE ss.season_year=2026 AND t.setup_session_task_id=483
    AND t.annual_task_name ~* 'plug[[:space:]]+in[[:space:]]+network[[:space:]]+to[[:space:]]+controller.*2[[:space:]]+minute[[:space:]]+test[[:space:]]+show'
    AND NOT EXISTS (
      SELECT 1 FROM ops.setup_work_day_task w
      WHERE w.setup_session_task_id=t.setup_session_task_id
    )
  ORDER BY t.setup_session_task_id DESC LIMIT 1;
  IF v_task IS NULL THEN
    RAISE EXCEPTION 'QC fixture unavailable: 2026 unscheduled final QC task';
  END IF;
  -- Unauthorized identity must be denied even when caller guesses an exact ID.
  BEGIN
    PERFORM ops.setup_qc_command(
      'no-such-user-qc-check@sheboyganlights.org','CLAIM_AUDIT',v_task);
    RAISE EXCEPTION 'QC unauthorized actor was allowed to claim audit';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
  SELECT count(*) INTO v_before FROM ops.setup_work_day_task;
  SELECT ops.setup_qc_command(v_actor,'REPORT',v_task,NULL,
    'Observed during initial power-up; red channel out',
    'Disposable QC acceptance red channel',
    'INITIAL_POWER','Arch 3 left to right channel 3',NULL)
    INTO v_report;
  v_finding := (v_report->>'finding_id')::bigint;
  IF v_finding IS NULL THEN RAISE EXCEPTION 'Report did not persist finding'; END IF;
  -- Crew reports on #598 without an auditor claim or calendar assignment.
  IF EXISTS (SELECT 1 FROM ops.setup_work_day_task WHERE setup_session_task_id=598) THEN
    RAISE EXCEPTION 'QC #598 unscheduled fixture changed; review before acceptance';
  END IF;
  SELECT (ops.setup_qc_command(v_crew,'REPORT',598,NULL,
    'Early fault before readiness or auditor claim','Crew early fault','INITIAL_POWER')->>'finding_id')::bigint
    INTO v_other_finding;
  v_snapshot := ops.setup_qc_snapshot(v_crew,2026);
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_snapshot->'findings') f
    WHERE (f->>'qc_finding_id')::bigint=v_other_finding
      AND (f->>'setup_session_task_id')::bigint=598) THEN
    RAISE EXCEPTION 'Crew snapshot lost exact finding/task identity';
  END IF;
  IF jsonb_array_length(v_snapshot->'unreconciled_intake')<>0 THEN
    RAISE EXCEPTION 'Manager-only unlinked Intake leaked to Crew';
  END IF;
  BEGIN
    PERFORM ops.setup_qc_intake_candidates(v_crew,2026);
    RAISE EXCEPTION 'Crew obtained Manager Intake candidates';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  -- Historical Intake correction is a separate operator-owned one-shot task.
  -- Normal QC acceptance must not depend on specific old Intake IDs or promotion state.
  BEGIN
    PERFORM ops.setup_qc_command(v_actor,'OBSERVATION',598,v_finding,'Wrong annual task');
    RAISE EXCEPTION 'Finding accepted under another annual task';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  PERFORM ops.setup_qc_command(v_actor,'OBSERVATION',v_task,v_finding,
    'Second auditor confirms same missing channel');
  -- A finding may not be repaired until its technician claims it.
  BEGIN
    PERFORM ops.setup_qc_command(v_actor,'REPAIRED',v_task,v_finding,
      'Improper repair without claim');
    RAISE EXCEPTION 'Unclaimed repair incorrectly accepted';
  EXCEPTION WHEN check_violation THEN
    NULL;
  END;
  -- Claim is one click; only actual repair work requires evidence.
  PERFORM ops.setup_qc_command(v_actor,'CLAIM_REPAIR',v_task,v_finding);
  BEGIN
    PERFORM ops.setup_qc_command(v_crew,'REPAIRED',v_task,v_finding,'Not my repair');
    RAISE EXCEPTION 'Another worker completed the claimed repair';
  EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN
    PERFORM ops.setup_qc_command(v_actor,'REPAIRED',v_task,v_finding);
    RAISE EXCEPTION 'Repair accepted without evidence';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  PERFORM ops.setup_qc_command(v_actor,'REPAIRED',v_task,v_finding,
    'Repaired wiring termination; awaiting functional retest');
  IF (SELECT status FROM ops.setup_qc_finding WHERE qc_finding_id=v_finding)
     <> 'AWAITING_RETEST' THEN
    RAISE EXCEPTION 'Repair incorrectly marked verified';
  END IF;
  BEGIN
    PERFORM ops.setup_qc_command(v_crew,'RETEST_PASS',v_task,v_finding,'No auditor assignment');
    RAISE EXCEPTION 'Retest allowed without auditor assignment';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  SELECT ops.setup_qc_command(v_actor,'CLAIM_AUDIT',v_task)
    INTO v_report;
  IF (v_report->>'task_id')::bigint<>v_task THEN
    RAISE EXCEPTION 'Self assignment did not preserve exact annual task';
  END IF;
  BEGIN
    PERFORM ops.setup_qc_command(v_actor,'RETEST_PASS',v_task,v_finding);
    RAISE EXCEPTION 'Retest accepted without evidence';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  PERFORM ops.setup_qc_command(v_actor,'RETEST_FAIL',v_task,v_finding,
    'Functional channel still off');
  IF (SELECT status FROM ops.setup_qc_finding WHERE qc_finding_id=v_finding)
     <> 'OPEN' THEN
    RAISE EXCEPTION 'Failed retest did not reopen finding';
  END IF;
  PERFORM ops.setup_qc_command(v_actor,'CLAIM_REPAIR',v_task,v_finding,
    'Claimed reopened channel failure');
  PERFORM ops.setup_qc_command(v_actor,'REPAIRED',v_task,v_finding,
    'Second repair completed');
  PERFORM ops.setup_qc_command(v_actor,'RETEST_PASS',v_task,v_finding,
    'Field observer confirms channel illuminates');
  IF (SELECT status FROM ops.setup_qc_finding WHERE qc_finding_id=v_finding)
     <> 'VERIFIED' THEN
    RAISE EXCEPTION 'Verified finding not recorded';
  END IF;
  PERFORM ops.setup_qc_command(v_actor,'REOPEN',v_task,v_finding,
    'Original problem recurred during second power-up');
  IF (SELECT status FROM ops.setup_qc_finding WHERE qc_finding_id=v_finding)
     <> 'OPEN' THEN
    RAISE EXCEPTION 'Reopened failure did not return to repair queue';
  END IF;
  -- Prove the complete operational path under a non-Manager Crew identity.
  -- No Manager command, calendar assignment or Intake source is needed here.
  PERFORM ops.setup_qc_command(v_crew,'OBSERVATION',598,v_other_finding,
    'Crew confirms the same early failure');
  PERFORM ops.setup_qc_command(v_crew,'CLAIM_REPAIR',598,v_other_finding);
  PERFORM ops.setup_qc_command(v_crew,'REPAIRED',598,v_other_finding,
    'Crew repaired the observed connection');
  PERFORM ops.setup_qc_command(v_crew,'CLAIM_AUDIT',598);
  PERFORM ops.setup_qc_command(v_crew,'RETEST_FAIL',598,v_other_finding,
    'Actual retest still shows the failure');
  IF (SELECT status FROM ops.setup_qc_finding WHERE qc_finding_id=v_other_finding)<>'OPEN' THEN
    RAISE EXCEPTION 'Crew failed retest did not reopen the same finding';
  END IF;
  PERFORM ops.setup_qc_command(v_crew,'CLAIM_REPAIR',598,v_other_finding);
  PERFORM ops.setup_qc_command(v_crew,'REPAIRED',598,v_other_finding,
    'Crew corrected the remaining connection');
  PERFORM ops.setup_qc_command(v_crew,'RETEST_PASS',598,v_other_finding,
    'Actual retest confirms the reported channel works');
  v_snapshot := ops.setup_qc_snapshot(v_crew,2026);
  IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(v_snapshot->'findings') f
    WHERE (f->>'qc_finding_id')::bigint=v_other_finding
      AND (f->>'setup_session_task_id')::bigint=598 AND f->>'status'='VERIFIED') THEN
    RAISE EXCEPTION 'Crew lifecycle lost the original finding or verified state';
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
  IF v_preserved IS DISTINCT FROM pg_temp.qc_protected_rows() THEN
    RAISE EXCEPTION 'QC changed protected annual, schedule, work report, Intake or Work Order rows';
  END IF;
  RAISE NOTICE 'QC 081 CLONE acceptance PASS: unscheduled %, report, observation, repair, failed and passed retest; no scheduling',v_task;
END
$test$;
ROLLBACK;
