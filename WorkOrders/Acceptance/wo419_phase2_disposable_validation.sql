-- #419 Phase 2: clone-only behavioral checks; no network or email sender.
-- Flow-status changes and all sample data below are rolled back.
BEGIN;
DO $test$
DECLARE
  v_email text := current_setting('msb.wo419_v1_reviewer_email');
  v_intake bigint; v_testing bigint; v_session bigint; v_before jsonb; v_after jsonb;
  v_session_before jsonb;
  v_actor record; v_body jsonb; v_result jsonb; v_ticket text;
  v_event text; v_recipient text; v_key text := repeat('a',64);
BEGIN
  IF current_database()<>'msb_wo419_preview' OR
     current_setting('msb.wo419_preview_authorized',true) IS DISTINCT FROM 'approved_disposable_clone' THEN
    RAISE EXCEPTION 'Disposable database authorization required';
  END IF;
  SELECT * INTO STRICT v_actor FROM ops.work_management_v1_actor(v_email);
  IF NOT v_actor.can_manage THEN RAISE EXCEPTION 'Actual Manager required'; END IF;
  SELECT jsonb_build_object('problem','Phase 2 disposable deadline and mail validation',
    'task_type_id',(SELECT task_type_id FROM ref.task_type WHERE active_flag ORDER BY task_type_id LIMIT 1),
    'stage_id',(SELECT stage_id FROM ref.stage ORDER BY stage_id LIMIT 1),
    'urgency','3','person_ids',jsonb_build_array(v_actor.person_id)) INTO v_body;
  BEGIN
    PERFORM ops.work_management_v1_command(v_email,'create',NULL,v_body,gen_random_uuid());
    RAISE EXCEPTION 'Missing Due by was accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;
  BEGIN
    PERFORM ops.work_management_v1_command(v_email,'create',NULL,
      v_body || '{"due_by":"2026-02-30"}'::jsonb,gen_random_uuid());
    RAISE EXCEPTION 'Invalid Due by was accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
  END;
  -- Capture activation is confined to this rolled-back clone transaction.
  UPDATE ops.work_management_mail_control SET capture_enabled=true;
  v_result := ops.work_management_v1_command(v_email,'create',NULL,
    v_body || '{"due_by":"2026-10-25"}'::jsonb,gen_random_uuid());
  v_ticket := v_result->>'ticket';
  IF NOT EXISTS (SELECT 1 FROM ops.work_order WHERE 'WO-'||work_order_id=v_ticket
                 AND due_by=DATE '2026-10-25') THEN
    RAISE EXCEPTION 'Deadline not persisted';
  END IF;
  SELECT event_key,recipient_email INTO STRICT v_event,v_recipient
    FROM ops.work_management_outbox WHERE ticket_key=v_ticket
      AND message_kind='assignment' AND delivery_status='QUEUED';
  -- Claims must fail while either old Flow is active.
  UPDATE public.directus_flows SET status='active'
    WHERE id='ebcde355-32c5-4826-b6fa-360621d0d357'::uuid;
  BEGIN
    PERFORM ops.work_management_mail_claim(v_key,v_event,v_recipient,
      '{"subject":"test","text":"test","html":"test","template_sha256":"test"}'::jsonb);
    RAISE EXCEPTION 'Expected cutover denial was absent' USING ERRCODE='XX000';
  EXCEPTION WHEN SQLSTATE 'P0001' THEN
    IF SQLERRM <> 'Work Order email cutover is not active' THEN RAISE; END IF;
  END;
  UPDATE public.directus_flows SET status='inactive' WHERE id IN (
    'ebcde355-32c5-4826-b6fa-360621d0d357'::uuid,
    '9a7fb87b-d78e-492b-b2c5-ac3b521b5cf7'::uuid);
  IF NOT ops.work_management_mail_claim(v_key,v_event,v_recipient,
      '{"subject":"test","text":"test","html":"test","template_sha256":"test"}'::jsonb) THEN
    RAISE EXCEPTION 'Initial claim failed';
  END IF;
  IF ops.work_management_mail_claim(v_key,v_event,v_recipient,
      '{"subject":"test","text":"test","html":"test","template_sha256":"test"}'::jsonb) THEN
    RAISE EXCEPTION 'Duplicate claim accepted';
  END IF;
  -- Simulated uncertainty, not an SMTP send or delivery proof.
  PERFORM ops.work_management_mail_finish(v_key,'UNKNOWN','clone_simulation_no_send');
  IF EXISTS (SELECT 1 FROM ops.work_management_outbox WHERE event_key=v_event
              AND delivery_status='SENT') THEN
    RAISE EXCEPTION 'Uncertain attempt falsely marked sent';
  END IF;
  PERFORM ops.work_management_v1_command(v_email,'cancel',v_ticket,
    '{"cancel_reason":"Disposable cancellation; no physical work performed"}'::jsonb,gen_random_uuid());
  IF NOT EXISTS (SELECT 1 FROM ops.work_management_outbox WHERE ticket_key=v_ticket
    AND message_kind='outcome' AND payload->>'outcome'='Canceled — no work performed') THEN
    RAISE EXCEPTION 'Cancellation notification is missing or misleading';
  END IF;
  -- Create our own open work in this rollback-only clone transaction. Production
  -- may legitimately have no open Testing repairs; that is not a test failure.
  -- Reuse only the foreign-key identity of an existing Testing session, preserving
  -- its complete row as an assertion below. Never reopen a real completed WO.
  SELECT display_test_session_id, to_jsonb(d) INTO v_session, v_session_before
    FROM ops.display_test_session d ORDER BY display_test_session_id LIMIT 1;
  IF v_session IS NULL THEN
    RAISE EXCEPTION 'Testing session prerequisite absent from restored clone';
  END IF;
  v_result := ops.work_management_v1_command(v_email,'create',NULL,
    v_body || '{"due_by":"2026-10-25","problem":"Disposable Testing deadline fixture"}'::jsonb,
    gen_random_uuid());
  v_testing := split_part(v_result->>'ticket','-',2)::bigint;
  UPDATE ops.work_order SET display_test_session_id=v_session
    WHERE work_order_id=v_testing;
  SELECT to_jsonb(w)-ARRAY['due_by','updated_by_person_id','updated_at','updated_by']
    INTO v_before FROM ops.work_order w WHERE work_order_id=v_testing;
  PERFORM ops.work_management_v1_command(v_email,'due_date','WO-'||v_testing,
    '{"due_by":"2026-10-26","edit_reason":"Manager selected a Testing repair deadline"}',gen_random_uuid());
  SELECT to_jsonb(w)-ARRAY['due_by','updated_by_person_id','updated_at','updated_by']
    INTO v_after FROM ops.work_order w WHERE work_order_id=v_testing;
  IF v_before IS DISTINCT FROM v_after OR NOT EXISTS (
    SELECT 1 FROM ops.work_order WHERE work_order_id=v_testing AND due_by=DATE '2026-10-26') THEN
    RAISE EXCEPTION 'Testing deadline update changed unrelated work fields';
  END IF;
  IF v_session_before IS DISTINCT FROM (
    SELECT to_jsonb(d) FROM ops.display_test_session d WHERE display_test_session_id=v_session
  ) THEN
    RAISE EXCEPTION 'Testing deadline fixture changed its Testing session';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM ops.work_management_mail_status(v_email,v_ticket) WHERE status='UNKNOWN') THEN
    RAISE EXCEPTION 'Manager cannot see uncertain delivery';
  END IF;

  SELECT i.intake_id INTO v_intake FROM stage.work_order_intake i
    WHERE NOT EXISTS(SELECT 1 FROM ops.work_order WHERE source_intake_id=i.intake_id)
      AND NOT EXISTS(SELECT 1 FROM ops.work_management_activity WHERE ticket_key='INTAKE-'||i.intake_id)
    ORDER BY i.intake_id LIMIT 1;
  IF v_intake IS NULL THEN RAISE EXCEPTION 'Unpromoted clarification fixture absent'; END IF;
  -- Change reporter identity in the clone only; outer ROLLBACK restores all evidence.
  UPDATE stage.work_order_intake SET submitter_person_id=v_actor.person_id WHERE intake_id=v_intake;
  BEGIN
    PERFORM ops.work_management_v1_command(v_email,'reply','INTAKE-'||v_intake,
      '{"response":"Unsolicited reply must not be accepted"}',gen_random_uuid());
    RAISE EXCEPTION 'Unsolicited reply accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM ops.work_management_v1_command(v_email,'clarify','INTAKE-'||v_intake,
    '{"response":"Which connector needs replacement on this display?"}',gen_random_uuid());
  PERFORM ops.work_management_v1_command(v_email,'reply','INTAKE-'||v_intake,
    '{"response":"The left connector has the damaged cable"}',gen_random_uuid());
  IF NOT EXISTS(SELECT 1 FROM ops.work_management_outbox WHERE ticket_key='INTAKE-'||v_intake
    AND message_kind='reporter_reply' AND recipient_person_id=v_actor.person_id AND delivery_status='QUEUED') THEN
    RAISE EXCEPTION 'Reporter answer did not notify question owner';
  END IF;
  BEGIN
    PERFORM ops.work_management_v1_command(v_email,'reply','INTAKE-'||v_intake,
      '{"response":"Second reply without another question must fail"}',gen_random_uuid());
    RAISE EXCEPTION 'Repeated answer accepted';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  -- Existing Directus role simulation proves the endpoint's database authorization.
  UPDATE public.directus_users SET role=(SELECT id FROM public.directus_roles WHERE name='Production Crew')
    WHERE id=v_actor.directus_user_id;
  DELETE FROM public.directus_access WHERE "user"=v_actor.directus_user_id;
  BEGIN
    PERFORM ops.work_management_mail_status(v_email,v_ticket);
    RAISE EXCEPTION 'Crew read Manager notification receipts';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM ops.work_management_v1_command(v_email,'due_date','WO-'||v_testing,
      '{"due_by":"2026-10-27","edit_reason":"Crew deadline must remain unauthorized"}',gen_random_uuid());
    RAISE EXCEPTION 'Crew changed Testing deadline';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RAISE NOTICE 'Phase 2 Testing preservation, reporter reply and receipt authorization PASS';
  RAISE NOTICE 'Phase 2 due date, capture, cutover gate, deduplication and uncertainty checks PASS; NO SMTP';
END $test$;
ROLLBACK;
