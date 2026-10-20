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

  -- The reviewer receives a temporary Manager grant ONLY in the clone.
  -- This grant is rolled back before the disposable DB is discarded.
  INSERT INTO ops.work_management_permission
    (person_id,can_manage,approved_by_person_id)
  VALUES (v_actor,true,v_actor);
  SELECT * INTO v_persona FROM ops.work_management_v1_actor(v_email);
  IF v_persona.person_id IS DISTINCT FROM v_actor OR
     v_persona.can_manage IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: Manager identity grant failed';
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

  -- A Manager with an explicitly revoked grant CANNOT create Work Orders,
  -- even with full form data; this proves native authorization, not UI hiding.
  UPDATE ops.work_management_permission SET can_manage=false
  WHERE person_id=v_actor;
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
  -- Permission toggle does not affect previously authorized assignment.
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

  -- Native public Intake promotion retains original identity and creates a
  -- single linked WO. No assignment ever occurs on the Intake item.
  UPDATE ops.work_management_permission SET can_manage=true
  WHERE person_id=v_actor;
  SELECT i.intake_id INTO v_intake FROM stage.work_order_intake i
  WHERE i.source_form_name IS DISTINCT FROM 'SETUP_CORRECTION'
    AND NOT EXISTS (SELECT 1 FROM ops.work_order w
                    WHERE w.source_intake_id=i.intake_id)
  ORDER BY i.intake_id LIMIT 1;
  IF v_intake IS NULL THEN
    RAISE EXCEPTION 'WO419 V1 VALIDATION HOLD: no current unpromoted public Intake fixture';
  END IF;
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

  RAISE NOTICE 'WO419 V1 disposable validation: Manager Create, native assignee Progress/Complete, non-Manager denial, Intake promotion, and no-send intent PASS';
END $v1test$;
ROLLBACK;
-- Rollback is intentional; no fixture Work Order, Manager grant or activity
-- survives even inside this disposable database.
