-- Native PostgreSQL proof in the existing owned clone; all fixtures rolled back.
BEGIN;
DO $test$
DECLARE
  v_email text:=current_setting('msb.wo419_v1_reviewer_email');
  v_manager record; v_other record; v_candidate record; v_other_email text;
  v_body jsonb; v_result jsonb; v_ticket text; v_id integer;
  v_key uuid:=gen_random_uuid(); v_event bigint; v_count integer;
  v_before jsonb; v_after jsonb; v_duplicate text; v_duplicate_key uuid:=gen_random_uuid();
BEGIN
  IF current_database()<>'msb_wo419_preview' OR
     current_setting('msb.wo419_preview_authorized',true) IS DISTINCT FROM 'approved_disposable_clone' THEN
    RAISE EXCEPTION 'Owned disposable clone required';
  END IF;
  SELECT * INTO STRICT v_manager FROM ops.work_management_v1_actor(v_email);
  IF NOT v_manager.can_manage THEN RAISE EXCEPTION 'Manager reviewer required'; END IF;
  -- A distinct real authorized Crew identity proves assignee permission, not just Manager bypass.
  FOR v_candidate IN SELECT email FROM ref.person WHERE active_flag AND email IS NOT NULL LOOP
    BEGIN
      SELECT * INTO v_other FROM ops.work_management_v1_actor(v_candidate.email);
      IF FOUND AND v_other.person_id<>v_manager.person_id AND NOT v_other.can_manage THEN
        v_other_email:=v_candidate.email; EXIT;
      END IF;
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
  END LOOP;
  IF v_other_email IS NULL THEN RAISE EXCEPTION 'Authorized distinct Crew fixture required'; END IF;
  UPDATE ops.work_management_mail_control SET capture_enabled=true;
  SELECT jsonb_build_object('problem','Disposable reporter follow-up acceptance only',
    'task_type_id',(SELECT task_type_id FROM ref.task_type WHERE active_flag ORDER BY task_type_id LIMIT 1),
    'stage_id',(SELECT stage_id FROM ref.stage ORDER BY stage_id LIMIT 1),
    'urgency','3','due_by','2026-11-09','person_ids',jsonb_build_array(v_other.person_id)) INTO v_body;
  v_result:=ops.work_management_v1_command(v_email,'create',NULL,v_body,gen_random_uuid());
  v_ticket:=v_result->>'ticket'; v_id:=split_part(v_ticket,'-',2)::integer;
  SELECT to_jsonb(w) INTO v_before FROM ops.work_order w WHERE work_order_id=v_id;
  v_body:=jsonb_build_object('response','Please identify the intended channel and display.');
  -- Non-assigned reporter cannot ask as assignee (Manager remains separately authorized).
  v_result:=ops.work_management_wo_followup(v_other_email,'clarify',v_ticket,v_body,v_key);
  v_event:=(v_result->>'activity_id')::bigint;
  IF NOT EXISTS (SELECT 1 FROM ops.work_management_outbox
    WHERE event_key='phase2:activity:'||v_event||':'||v_manager.person_id
      AND message_kind='more_info' AND delivery_status='QUEUED'
      AND payload->>'ticket'=v_ticket) THEN RAISE EXCEPTION 'Question recipient/link incorrect'; END IF;
  PERFORM ops.work_management_wo_followup(v_other_email,'clarify',v_ticket,v_body,v_key);
  SELECT count(*) INTO v_count FROM ops.work_management_activity WHERE request_key=v_key;
  IF v_count<>1 THEN RAISE EXCEPTION 'Replay duplicated question'; END IF;
  BEGIN
    PERFORM ops.work_management_wo_followup(v_other_email,'reply',v_ticket,
      '{"response":"Wrong reporter must not answer this."}',gen_random_uuid());
    RAISE EXCEPTION 'Wrong reporter accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM ops.work_management_wo_followup(v_other_email,'clarify',v_ticket,v_body,gen_random_uuid());
    RAISE EXCEPTION 'Second outstanding question accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  -- Original reporter can read the question without receiving assignment rights.
  IF NOT EXISTS (SELECT 1 FROM ops.work_management_v1_activity(v_email,v_ticket)
                 WHERE event_kind='clarify') THEN RAISE EXCEPTION 'Question not readable'; END IF;
  v_result:=ops.work_management_wo_followup(v_email,'reply',v_ticket,
    '{"response":"Use channel fourteen for the second display."}',gen_random_uuid());
  v_event:=(v_result->>'activity_id')::bigint;
  IF NOT EXISTS (SELECT 1 FROM ops.work_management_outbox
    WHERE event_key='phase2:activity:'||v_event||':'||v_other.person_id
      AND message_kind='reporter_reply' AND delivery_status='QUEUED') THEN
    RAISE EXCEPTION 'Reply must notify question author'; END IF;
  BEGIN
    PERFORM ops.work_management_wo_followup(v_email,'reply',v_ticket,
      '{"response":"Duplicate response must be rejected."}',gen_random_uuid());
    RAISE EXCEPTION 'Reply without pending question accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  SELECT to_jsonb(w) INTO v_after FROM ops.work_order w WHERE work_order_id=v_id;
  IF v_before IS DISTINCT FROM v_after THEN RAISE EXCEPTION 'Follow-up changed Work Order'; END IF;
  IF NOT EXISTS (SELECT 1 FROM ops.work_order_assignment WHERE work_order_id=v_id
    AND person_id=v_other.person_id AND active_flag) THEN RAISE EXCEPTION 'Assignment lost'; END IF;
  -- Duplicate resolution keeps the canonical record and its historical Stage untouched.
  v_body:=jsonb_build_object('problem','Disposable duplicate review acceptance only',
    'task_type_id',(SELECT task_type_id FROM ref.task_type WHERE active_flag ORDER BY task_type_id LIMIT 1),
    'stage_id',(SELECT stage_id FROM ref.stage ORDER BY stage_id LIMIT 1),
    'urgency','3','due_by','2026-11-09','person_ids',jsonb_build_array(v_other.person_id));
  v_result:=ops.work_management_v1_command(v_email,'create',NULL,v_body,gen_random_uuid());
  v_duplicate:=v_result->>'ticket';
  v_body:=jsonb_build_object('duplicate_of',v_ticket,'response','Same fault already tracked by original Work Order.');
  BEGIN
    PERFORM ops.work_management_duplicate(v_other_email,'duplicate',v_duplicate,v_body,gen_random_uuid());
    RAISE EXCEPTION 'Crew duplicate action unexpectedly accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM ops.work_management_duplicate(v_email,'duplicate',v_ticket,v_body,gen_random_uuid());
    RAISE EXCEPTION 'Self duplicate unexpectedly accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  PERFORM ops.work_management_duplicate(v_email,'duplicate',v_duplicate,v_body,v_duplicate_key);
  PERFORM ops.work_management_duplicate(v_email,'duplicate',v_duplicate,v_body,v_duplicate_key);
  IF (SELECT count(*) FROM ops.work_management_duplicate_link WHERE source_ticket=v_duplicate)<>1 THEN
    RAISE EXCEPTION 'Duplicate link missing or repeated'; END IF;
  IF NOT EXISTS (SELECT 1 FROM ops.work_order WHERE work_order_id=split_part(v_duplicate,'-',2)::integer
    AND NOT is_active AND date_completed IS NULL AND NOT repair_complete) THEN
    RAISE EXCEPTION 'Duplicate incorrectly recorded repair completion'; END IF;
  BEGIN
    PERFORM ops.work_management_duplicate(v_email,'duplicate',v_ticket,
      jsonb_build_object('duplicate_of',v_duplicate,'response','Invalid reverse link must be rejected.'),gen_random_uuid());
    RAISE EXCEPTION 'Duplicate cycle unexpectedly accepted';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  SELECT to_jsonb(w) INTO v_after FROM ops.work_order w WHERE work_order_id=v_id;
  IF v_before IS DISTINCT FROM v_after THEN RAISE EXCEPTION 'Duplicate altered original Work Order'; END IF;
END $test$;
ROLLBACK;
