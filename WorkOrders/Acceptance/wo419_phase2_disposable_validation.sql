-- #419 Phase 2: clone-only behavioral checks; no network or email sender.
-- Flow-status changes and all sample data below are rolled back.
BEGIN;
DO $test$
DECLARE
  v_email text := current_setting('msb.wo419_v1_reviewer_email');
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
  RAISE NOTICE 'Phase 2 due date, capture, cutover gate, deduplication and uncertainty checks PASS; NO SMTP';
END $test$;
ROLLBACK;
