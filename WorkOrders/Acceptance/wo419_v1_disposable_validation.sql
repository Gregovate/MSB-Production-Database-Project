-- #419 V1: SOURCE-ONLY functional PostgreSQL acceptance on an isolated clone.
-- This file NEVER runs against Production. The governing existing #419
-- disposable runner creates/restores the clone first and destroys it afterward.
-- Caller must set msb.wo419_v1_reviewer_email before this file is streamed.
-- All fixture changes are rolled back, even inside the throwaway clone.
\set ON_ERROR_STOP on
BEGIN;
DO $v1test$
DECLARE
  v_email text := current_setting('msb.wo419_v1_reviewer_email',true);
  v_db text := current_database();
  v_actor integer;
  v_task_type bigint;
  v_stage bigint;
  v_intake bigint;
  v_wo bigint;
  v_promoted bigint;
  v_result jsonb;
  v_key uuid;
  v_persona record;
  v_worecord record;
  v_forbidden boolean := false;
BEGIN
  IF v_db <> 'msb_wo419_preview' OR
     current_setting('msb.wo419_preview_authorized',true)
       IS DISTINCT FROM 'approved_disposable_clone' THEN
    RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: disposable clone marker/database required';
  END IF;
  IF v_email IS NULL OR v_email !~ '^[a-z0-9._%+-]+@sheboyganlights[.]org$' THEN
    RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: one named reviewer email required';
  END IF;
  IF to_regprocedure('ops.work_management_v1_command(text,text,text,jsonb,uuid)')
     IS NULL OR to_regprocedure('ops.work_management_v1_actor(text)') IS NULL THEN
    RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: governed SQL commands not installed';
  END IF;
  IF has_table_privilege('work_management_app','ops.work_order','INSERT') OR
     has_table_privilege('work_management_app','ops.work_order','UPDATE') OR
     has_table_privilege('work_management_app','ops.work_order_assignment','INSERT') OR
     has_table_privilege('work_management_app','ops.work_order_assignment','UPDATE') THEN
    RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: web role has forbidden native WO table DML';
  END IF;
  SELECT p.person_id INTO STRICT v_actor FROM ref.person p
  JOIN public.directus_users u ON u.id=p.directus_user_id
  WHERE lower(p.email)=v_email AND p.active_flag AND u.status='active'
    AND lower(u.email)=v_email;
  SELECT t.task_type_id INTO v_task_type FROM ref.task_type t
  WHERE t.active_flag ORDER BY t.task_type_id LIMIT 1;
  SELECT s.stage_id INTO v_stage FROM ref.stage s ORDER BY s.stage_id LIMIT 1;
  IF v_task_type IS NULL OR v_stage IS NULL THEN
    RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: stage/task-type catalog unavailable';
  END IF;

  -- Require the actual cloned Directus Manager role, without an app grant.
  SELECT * INTO v_persona FROM ops.work_management_v1_actor(v_email);
  IF v_persona.person_id IS DISTINCT FROM v_actor OR
     v_persona.can_manage IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: Directus Manager identity resolution failed';
  END IF;

  -- Actual native Manager Create, idempotency and Priority 3/NULL year.
  v_key := gen_random_uuid();
  v_result := ops.work_management_v1_command(
    v_email,'create',NULL,
    jsonb_build_object('problem','Disposable V1 regression: inspect and repair light strand',
                       'task_type_id',v_task_type,'stage_id',v_stage,
                       'urgency','3','person_ids',jsonb_build_array(v_actor)),
    v_key);
  IF v_result->>'saved' <> 'true' THEN
    RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: native Manager Create failed';
  END IF;
  v_wo := split_part(v_result->>'ticket','-',2)::bigint;
  SELECT w.urgency_id,w.target_year,w.date_completed,w.created_by_person_id,
         w.source_intake_id INTO STRICT v_worecord
  FROM ops.work_order w WHERE w.work_order_id=v_wo;
  IF v_worecord.urgency_id<>3 OR v_worecord.target_year IS NOT NULL OR
     v_worecord.date_completed IS NOT NULL OR
     v_worecord.created_by_person_id<>v_actor OR
     v_worecord.source_intake_id IS NOT NULL OR
     NOT EXISTS (SELECT 1 FROM ops.work_order_assignment a
                 WHERE a.work_order_id=v_wo AND a.person_id=v_actor AND a.active_flag) THEN
    RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: native Create/assignment provenance differs';
  END IF;
  v_result := ops.work_management_v1_command(
    v_email,'create',NULL,
    jsonb_build_object('problem','Disposable V1 regression: inspect and repair light strand',
                       'task_type_id',v_task_type,'stage_id',v_stage,
                       'urgency','3','person_ids',jsonb_build_array(v_actor)),v_key);
  IF v_result->>'repeat' <> 'true' OR
     v_result->>'ticket' <> 'WO-'||v_wo::text THEN
    RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: request-key duplicate created second WO';
  END IF;

  -- Manager correction must preserve identity and record before/after fields.
  v_result := ops.work_management_v1_command(
    v_email,'edit','WO-'||v_wo,
    jsonb_build_object(
      'problem','Disposable V1 corrected light strand planning scope',
      'task_type_id',v_task_type,'stage_id',v_stage,
      'urgency','5','target_year','2027',
      'edit_reason','Manager corrected this job to a future Planning priority'),
    gen_random_uuid());
  IF v_result->>'saved' <> 'true' OR NOT EXISTS (
    SELECT 1 FROM ops.work_order
    WHERE work_order_id=v_wo AND urgency_id=5 AND target_year=2027
  ) OR NOT EXISTS (
    SELECT 1 FROM ops.work_management_activity
    WHERE ticket_key='WO-'||v_wo AND event_kind='edit'
      AND details->'before'->>'urgency_id'='3'
      AND details->'after'->>'urgency_id'='5'
  ) THEN
    RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: Manager edit audit and Planning fields failed';
  END IF;
  -- Return the same test WO to Routine so existing Progress/Complete tests
  -- remain independent of this new correction fixture.
  PERFORM ops.work_management_v1_command(
    v_email,'edit','WO-'||v_wo,
    jsonb_build_object(
      'problem','Disposable V1 corrected light strand routine repair',
      'task_type_id',v_task_type,'stage_id',v_stage,
      'urgency','3',
      'edit_reason','Manager returned job to current routine scope for repair'),
    gen_random_uuid());

  -- Cancellation must not masquerade as physical completion or permit new work.
  -- Roll back this nested fixture to keep the existing Progress/Complete gate.
  BEGIN
    PERFORM ops.work_management_v1_command(
      v_email,'cancel','WO-'||v_wo,
      jsonb_build_object('cancel_reason',
        'Safety review: this procedure would damage frozen wiring; no physical work approved'),
      gen_random_uuid());
    IF NOT EXISTS (
      SELECT 1 FROM ops.work_order
      WHERE work_order_id=v_wo AND NOT is_active AND date_completed IS NULL
    ) OR NOT EXISTS (
      SELECT 1 FROM ops.work_management_activity
      WHERE ticket_key='WO-'||v_wo AND event_kind='cancel'
        AND details->>'physical_work_completed'='false'
    ) THEN
      RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: cancellation did not preserve noncompletion';
    END IF;
    RAISE EXCEPTION 'WO419_CANCEL_FIXTURE_ROLLBACK' USING ERRCODE='P0002';
  EXCEPTION WHEN SQLSTATE 'P0002' THEN
    RAISE NOTICE 'WO419 V1 Manager correction/Cancel-No-Action audit and noncompletion PASS';
  END;

  -- Change Directus fixtures ONLY in the isolated clone. The subtransaction
  -- rolls back role/access changes and Crew command fixtures together.
  BEGIN
  UPDATE public.directus_users SET role=(
    SELECT id FROM public.directus_roles WHERE name='Production Crew'
  ) WHERE id=(SELECT directus_user_id FROM ref.person WHERE person_id=v_actor);
  DELETE FROM public.directus_access
  WHERE "user"=(SELECT directus_user_id FROM ref.person WHERE person_id=v_actor);
  SELECT * INTO v_persona FROM ops.work_management_v1_actor(v_email);
  IF v_persona.can_manage IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: Directus role revocation failed';
  END IF;
  BEGIN
    PERFORM ops.work_management_v1_command(
      v_email,'create',NULL,
      jsonb_build_object('problem','Unauthorized V1 create must be rejected',
                         'task_type_id',v_task_type,'stage_id',v_stage,
                         'urgency','3','person_ids','[]'::jsonb),gen_random_uuid());
  EXCEPTION WHEN insufficient_privilege THEN
    v_forbidden := true;
  END;
  IF NOT v_forbidden THEN
    RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: non-Manager native create accepted';
  END IF;

  -- Active assigned Crew retains authenticated Progress and Complete rights.
  -- Directus role change does not remove the existing work assignment.
  PERFORM ops.work_management_v1_command(
    v_email,'progress','WO-'||v_wo,
    jsonb_build_object('progress_note','Inspected power and repaired one damaged connection'),
    gen_random_uuid());
  IF NOT EXISTS (SELECT 1 FROM ops.work_order w
                 WHERE w.work_order_id=v_wo AND w.date_completed IS NULL
                   AND w.notes LIKE '%repaired one damaged connection%') THEN
    RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: progress unexpectedly closed or not recorded';
  END IF;
  PERFORM ops.work_management_v1_command(
    v_email,'complete','WO-'||v_wo,
    jsonb_build_object('completion_notes','Verified repaired connection and test illumination'),
    gen_random_uuid());
  IF NOT EXISTS (SELECT 1 FROM ops.work_order w
                 WHERE w.work_order_id=v_wo AND w.date_completed IS NOT NULL
                   AND w.completed_by_person_id=v_actor
                   AND w.completion_notes LIKE 'Verified repaired connection%') THEN
    RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: completion audit/date/notes missing';
  END IF;

  RAISE EXCEPTION 'WO419_ROLE_FIXTURE_ROLLBACK' USING ERRCODE='P0002';
  EXCEPTION WHEN SQLSTATE 'P0002' THEN
    RAISE NOTICE 'WO419 Directus Manager revocation / Crew assignment rights PASS';
  END;

  -- Suspended Directus users lose access immediately, even if still Managers.
  BEGIN
    UPDATE public.directus_users SET status='suspended'
    WHERE id=(SELECT directus_user_id FROM ref.person WHERE person_id=v_actor);
    v_forbidden := false;
    BEGIN
      PERFORM ops.work_management_v1_actor(v_email);
    EXCEPTION WHEN insufficient_privilege THEN
      v_forbidden := true;
    END;
    IF NOT v_forbidden THEN
      RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: suspended Directus user accepted';
    END IF;
    RAISE EXCEPTION 'WO419_SUSPEND_FIXTURE_ROLLBACK' USING ERRCODE='P0002';
  EXCEPTION WHEN SQLSTATE 'P0002' THEN
    RAISE NOTICE 'WO419 suspended Directus user denied PASS';
  END;

  -- Native public Intake promotion uses restored Directus Manager rights.
  SELECT i.intake_id INTO v_intake FROM stage.work_order_intake i
  WHERE i.source_form_name IS DISTINCT FROM 'SETUP_CORRECTION'
    AND NOT EXISTS (SELECT 1 FROM ops.work_order w
                    WHERE w.source_intake_id=i.intake_id)
  ORDER BY i.intake_id LIMIT 1;
  IF v_intake IS NULL THEN
    RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: no current unpromoted public Intake fixture';
  END IF;
  -- Exercise nonpromotion disposition on this same real-shape Intake in a
  -- PL/pgSQL subtransaction, then deliberately discard only that fixture
  -- so the established promotion assertion can still run afterward.
  BEGIN
    v_result := ops.work_management_v1_command(
      v_email,'resolve','INTAKE-'||v_intake,
      jsonb_build_object('response',
          'Request reviewed; no work order required because issue is not a repair',
          'disposition','rejected'),
      gen_random_uuid());
    IF v_result->>'saved' <> 'true' OR
       NOT EXISTS (
         SELECT 1 FROM ops.work_management_activity a
         WHERE a.ticket_key='INTAKE-'||v_intake
           AND a.event_kind='resolve'
           AND a.details->>'disposition'='rejected'
       ) OR
       NOT EXISTS (
         SELECT 1 FROM stage.work_order_intake i WHERE i.intake_id=v_intake
       ) THEN
      RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: non-destructive Intake rejection failed';
    END IF;
    v_forbidden:=false;
    BEGIN
      PERFORM ops.work_management_v1_command(
        v_email,'promote','INTAKE-'||v_intake,
        jsonb_build_object('problem','Rejected Intake must never be promoted',
          'task_type_id',v_task_type,'stage_id',v_stage,
          'urgency','3','person_ids',jsonb_build_array(v_actor)),
        gen_random_uuid());
    EXCEPTION WHEN unique_violation THEN
      v_forbidden:=true;
    END;
    IF NOT v_forbidden THEN
      RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: rejected Intake was promoted';
    END IF;
    RAISE EXCEPTION 'WO419_DISPOSITION_FIXTURE_ROLLBACK' USING ERRCODE='P0002';
  EXCEPTION WHEN SQLSTATE 'P0002' THEN
    RAISE NOTICE 'WO419 V1 non-destructive public Intake disposition/deny-promote PASS';
  END;

  v_result := ops.work_management_v1_command(
    v_email,'promote','INTAKE-'||v_intake,
    jsonb_build_object('problem','Disposable public Intake promotion test and assign',
                       'task_type_id',v_task_type,'stage_id',v_stage,
                       'urgency','3','person_ids',jsonb_build_array(v_actor)),
    gen_random_uuid());
  v_promoted := split_part(v_result->>'ticket','-',2)::bigint;
  IF NOT EXISTS (SELECT 1 FROM ops.work_order
                 WHERE work_order_id=v_promoted AND source_intake_id=v_intake) OR
     NOT EXISTS (SELECT 1 FROM ops.work_management_activity
                 WHERE ticket_key='INTAKE-'||v_intake AND event_kind='promoted_source') THEN
    RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: Intake provenance not retained';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM ops.work_management_outbox
                 WHERE ticket_key='WO-'||v_promoted
                   AND delivery_status='PENDING_CUTOVER') THEN
    RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: missing durable no-send notification intent';
  END IF;
  IF EXISTS (SELECT 1 FROM ops.work_management_outbox
             WHERE delivery_status='SENT') THEN
    RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: unsanctioned mail SENT state';
  END IF;

  RAISE NOTICE 'WO419 V1 disposable validation: Manager Create, native assignee Progress/Complete, non-Manager denial, Intake nonpromotion disposition, Intake promotion, and no-send intent PASS';
END $v1test$;
ROLLBACK;
-- Rollback is intentional; no fixture Work Order, Manager grant or activity
-- survives even inside this disposable database.

