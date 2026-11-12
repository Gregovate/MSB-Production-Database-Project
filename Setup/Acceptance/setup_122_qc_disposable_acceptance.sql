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
  v_batch jsonb;
  v_batch_before bigint;
  v_problem text;
  v_index integer;
  v_problems text[] := ARRAY[
    'arch 3 - blue lights 21" to 28" and 76" to 80" from bottom',
    'arch 3 - all red lights', 'arch 4 - all red lights',
    'arch 8 - yellow lights 12" to 20" from top',
    'arch 9 - blue lights from top to @1 foot down', 'arch 11 - all blue lights'];
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
  -- Free-form batch: same exact area, one line per repair identity, no partial save.
  SELECT count(*) INTO v_batch_before FROM ops.setup_qc_finding;
  BEGIN
    PERFORM ops.setup_qc_command(v_crew,'REPORT_LINES',598,NULL,E'Valid first problem\nx');
    RAISE EXCEPTION 'Invalid batch was accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
  IF (SELECT count(*) FROM ops.setup_qc_finding)<>v_batch_before THEN
    RAISE EXCEPTION 'Invalid batch left partially saved findings';
  END IF;
  v_batch := ops.setup_qc_command(v_crew,'REPORT_LINES',598,NULL,
    array_to_string(v_problems,E'\r\n\r\n'));
  IF jsonb_array_length(v_batch->'finding_ids')<>6 THEN
    RAISE EXCEPTION 'Six problem lines did not produce six findings';
  END IF;
  FOR v_index IN 1..6 LOOP
    IF NOT EXISTS (SELECT 1 FROM ops.setup_qc_finding f
      JOIN ops.setup_qc_event e USING(qc_finding_id)
      WHERE f.qc_finding_id=(v_batch->'finding_ids'->>(v_index-1))::bigint
        AND f.setup_session_task_id=598 AND e.event_type='REPORTED'
        AND e.note=v_problems[v_index]) THEN
      RAISE EXCEPTION 'Batch problem %, exact area, text or order lost',v_index;
    END IF;
  END LOOP;
  -- Long free-form lines retain complete evidence beyond their compact title.
  v_problem := repeat('Measured string section ',20);
  v_batch := ops.setup_qc_command(v_crew,'REPORT_LINES',598,NULL,v_problem);
  IF NOT EXISTS (SELECT 1 FROM ops.setup_qc_event e
    WHERE e.qc_finding_id=(v_batch->'finding_ids'->>0)::bigint
      AND e.event_type='REPORTED' AND e.note=btrim(v_problem)) THEN
    RAISE EXCEPTION 'Long free-form evidence was truncated';
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
-- Purpose: final annual signoff positive/negative tests, clone-only fixture setup.
-- Scope: fixture readiness/completion changes are rolled back in a subtransaction;
-- these are software acceptance records, not actual physical test evidence.
DO $signoff_test$
DECLARE
  v_task bigint; v_crew text; v_required bigint; v_gate jsonb; v_finding bigint;
  v_before jsonb; v_after_fixture jsonb; v_annual_before jsonb; v_result jsonb;
  v_person integer; v_status text;
BEGIN
  v_before := pg_temp.qc_protected_rows();
  SELECT lower(u.email),p.person_id INTO v_crew,v_person
  FROM public.directus_users u JOIN ref.person p ON p.directus_user_id=u.id
  CROSS JOIN LATERAL ref.setup_browser_capabilities(lower(u.email)) c
  WHERE u.status='active' AND c.can_read_setup AND NOT c.can_manage_setup
    AND (c.role_name='Production Crew' OR 'Production Crew'=ANY(coalesce(c.policy_names,ARRAY[]::text[])))
  ORDER BY lower(u.email),p.person_id LIMIT 1;
  SELECT t.setup_session_task_id INTO v_task
  FROM ops.setup_session_task t JOIN ops.setup_session ss USING(setup_session_id)
  CROSS JOIN LATERAL (SELECT ops.setup_qc_final_gate(t.setup_session_task_id) g) gate
  WHERE ss.season_year=2026 AND t.included_flag AND t.annual_lor_scene_id IS NOT NULL
    AND t.annual_task_name ~* 'plug[[:space:]]+in[[:space:]]+network[[:space:]]+to[[:space:]]+controller.*2[[:space:]]+minute[[:space:]]+test[[:space:]]+show'
    AND jsonb_array_length(gate.g->'required_work')>0
    AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(gate.g->'required_work') w
      WHERE w->>'id' IS NULL OR w->>'name' ~* 'plug[[:space:]]+in[[:space:]]+network[[:space:]]+to[[:space:]]+controller.*2[[:space:]]+minute[[:space:]]+test[[:space:]]+show')
  ORDER BY t.setup_session_task_id LIMIT 1;
  IF v_task IS NULL OR v_crew IS NULL THEN
    RAISE EXCEPTION 'Final QC acceptance needs a scene QC list with existing ordinary required work and mapped Crew';
  END IF;
  BEGIN
    -- Prepare only the disposable test scenario; preserve every source on rollback.
    v_gate := ops.setup_qc_final_gate(v_task);
    UPDATE ops.setup_session_task SET execution_status='COMPLETE'
      WHERE setup_session_task_id IN (SELECT (w->>'id')::bigint
        FROM jsonb_array_elements(v_gate->'required_work') w);
    UPDATE ops.setup_session_task SET annual_readiness_state='READY' WHERE setup_session_task_id=v_task;
    SELECT min((w->>'id')::bigint) INTO v_required FROM jsonb_array_elements(v_gate->'required_work') w;
    BEGIN
      PERFORM ops.setup_qc_ready_for_production(v_crew,v_task,'Fixture only',120,'Fixture sequence');
      RAISE EXCEPTION 'Unclaimed auditor signed off';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    PERFORM ops.setup_qc_command(v_crew,'CLAIM_AUDIT',v_task);
    BEGIN
      PERFORM ops.setup_qc_ready_for_production('no-such-qc-user@example.test',v_task,'Fixture only',120,'Fixture sequence');
      RAISE EXCEPTION 'Unauthorized identity signed off';
    EXCEPTION WHEN insufficient_privilege THEN NULL; END;
    BEGIN
      PERFORM ops.setup_qc_ready_for_production(v_crew,v_task,'Fixture only',119,'Fixture sequence');
      RAISE EXCEPTION 'Short test signed off';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    BEGIN
      PERFORM ops.setup_qc_ready_for_production(v_crew,v_task,NULL,120,'Fixture sequence');
      RAISE EXCEPTION 'Missing evidence signed off';
    EXCEPTION WHEN invalid_parameter_value THEN NULL; END;
    UPDATE ops.setup_session_task SET annual_readiness_state='NOT_READY' WHERE setup_session_task_id=v_task;
    BEGIN
      PERFORM ops.setup_qc_ready_for_production(v_crew,v_task,'Fixture only',120,'Fixture sequence');
      RAISE EXCEPTION 'NOT_READY annual task signed off';
    EXCEPTION WHEN check_violation THEN NULL; END;
    UPDATE ops.setup_session_task SET annual_readiness_state='READY' WHERE setup_session_task_id=v_task;
    UPDATE ops.setup_session_task SET execution_status='NOT_READY',linked_work_order_gate=false
      WHERE setup_session_task_id=v_required;
    BEGIN
      PERFORM ops.setup_qc_ready_for_production(v_crew,v_task,'Fixture only',120,'Fixture sequence');
      RAISE EXCEPTION 'Unfinished required task signed off';
    EXCEPTION WHEN check_violation THEN NULL; END;
    UPDATE ops.setup_session_task SET execution_status='COMPLETE' WHERE setup_session_task_id=v_required;
    v_finding := (ops.setup_qc_command(v_crew,'REPORT',v_task,NULL,'Fixture failure',
      'Fixture failure','OTHER')->>'finding_id')::bigint;
    FOREACH v_status IN ARRAY ARRAY['OPEN','CLAIMED','AWAITING_RETEST'] LOOP
      IF v_status='CLAIMED' THEN PERFORM ops.setup_qc_command(v_crew,'CLAIM_REPAIR',v_task,v_finding); END IF;
      IF v_status='AWAITING_RETEST' THEN PERFORM ops.setup_qc_command(v_crew,'REPAIRED',v_task,v_finding,'Fixture repair'); END IF;
      BEGIN
        PERFORM ops.setup_qc_ready_for_production(v_crew,v_task,'Fixture only',120,'Fixture sequence');
        RAISE EXCEPTION 'Unresolved % finding allowed final signoff',v_status;
      EXCEPTION WHEN check_violation THEN NULL; END;
    END LOOP;
    PERFORM ops.setup_qc_command(v_crew,'RETEST_PASS',v_task,v_finding,'Fixture retest');
    v_after_fixture := pg_temp.qc_protected_rows();
    SELECT to_jsonb(t) INTO v_annual_before FROM ops.setup_session_task t WHERE setup_session_task_id=v_task;
    v_result := ops.setup_qc_ready_for_production(v_crew,v_task,'Disposable fixture only; not real show approval',120,'Acceptance fixture sequence');
    IF v_result->>'status'<>'READY_FOR_PRODUCTION' OR NOT EXISTS (
      SELECT 1 FROM ops.setup_qc_signoff q JOIN ops.setup_session_task t USING(setup_session_task_id)
      WHERE q.setup_session_task_id=v_task AND q.auditor_person_id=v_person
        AND q.test_seconds=120 AND t.execution_status='COMPLETE'
        AND t.completed_by_person_id=v_person AND t.actual_completed_at=q.signed_at) THEN
      RAISE EXCEPTION 'Final evidence or annual completion lost';
    END IF;
    IF (pg_temp.qc_protected_rows()-'ops.setup_session_task') IS DISTINCT FROM
       (v_after_fixture-'ops.setup_session_task') THEN
      RAISE EXCEPTION 'Signoff changed Intake, Work Order, schedule or ordinary progress';
    END IF;
    IF (SELECT to_jsonb(t)-ARRAY['execution_status','actual_completed_at','completed_by_person_id','completion_note','updated_at','updated_by','updated_by_person_id']
        FROM ops.setup_session_task t WHERE setup_session_task_id=v_task) IS DISTINCT FROM
       (v_annual_before-ARRAY['execution_status','actual_completed_at','completed_by_person_id','completion_note','updated_at','updated_by','updated_by_person_id']) THEN
      RAISE EXCEPTION 'Signoff changed unrelated annual task fields';
    END IF;
    BEGIN
      PERFORM ops.setup_qc_command(v_crew,'REPORT',v_task,NULL,'Future problem','Future problem','OTHER');
      RAISE EXCEPTION 'Finalized area accepted a new QC problem';
    EXCEPTION WHEN check_violation THEN NULL; END;
    BEGIN
      PERFORM ops.setup_qc_command(v_crew,'REOPEN',v_task,v_finding,'Future recurrence');
      RAISE EXCEPTION 'Finalized area reopened QC instead of Work Orders';
    EXCEPTION WHEN check_violation THEN NULL; END;
    BEGIN
      PERFORM ops.setup_qc_ready_for_production(v_crew,v_task,'Overwrite evidence',120,'Other sequence');
      RAISE EXCEPTION 'Final evidence was overwritten';
    EXCEPTION WHEN check_violation THEN NULL; END;
    RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE='Rollback final-signoff acceptance fixture';
  EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL; END;
  IF pg_temp.qc_protected_rows() IS DISTINCT FROM v_before THEN
    RAISE EXCEPTION 'Final acceptance fixture did not restore protected source rows';
  END IF;
  RAISE NOTICE 'Final QC signoff acceptance PASS: claimed Crew auditor, all work, findings, evidence, annual completion and WO handoff guard';
END
$signoff_test$;
ROLLBACK;
