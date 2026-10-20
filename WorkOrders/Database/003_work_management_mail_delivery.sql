-- #419 Phase 2 candidate, NOT DEPLOYED. Requires #37 snapshot/maintenance.
-- This creates delivery bookkeeping only. It does not queue historical mail,
-- disable a Flow, create credentials, enable a worker or send a message.
BEGIN;
DO $preflight$
BEGIN
  IF current_database() NOT IN ('msb', 'msb_wo419_preview') THEN
    RAISE EXCEPTION 'WO419 V1: unrecognized database, refusing migration';
  END IF;
  IF current_database() = 'msb' AND
     current_setting('msb.wo419_v1_migration_approved', true)
       IS DISTINCT FROM 'approved_maintenance_snapshot' THEN
    RAISE EXCEPTION 'WO419 V1: Production maintenance snapshot/approval marker required';
  END IF;
  IF current_database() = 'msb_wo419_preview' AND
     current_setting('msb.wo419_preview_authorized', true)
       IS DISTINCT FROM 'approved_disposable_clone' THEN
    RAISE EXCEPTION 'WO419 V1: disposable clone authorization marker required';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'work_management_app') THEN
    RAISE EXCEPTION 'WO419 V1: dedicated work_management_app role absent; create by reviewed server mechanism';
  END IF;
  IF to_regclass('ops.work_order') IS NULL OR
     to_regclass('ops.work_order_assignment') IS NULL OR
     to_regclass('stage.work_order_intake') IS NULL OR
     to_regclass('ref.person') IS NULL OR
     to_regprocedure('ref.setup_browser_capabilities(text)') IS NULL THEN
    RAISE EXCEPTION 'WO419 V1: expected native tables or Setup identity authority absent';
  END IF;
  IF EXISTS (
    SELECT 1 FROM (VALUES
      ('ops','work_order','work_order_id'),
      ('ops','work_order','date_completed'),
      ('ops','work_order','completion_notes'),
      ('ops','work_order','completed_by_person_id'),
      ('ops','work_order','repair_complete'),
      ('ops','work_order','source_intake_id'),
      ('ops','work_order','source_system'),
      ('ops','work_order','source_form_name'),
      ('ops','work_order','submitted_by_person_id'),
      ('ops','work_order','created_by_person_id'),
      ('ops','work_order','updated_by_person_id'),
      ('ops','work_order','urgency_id'),
      ('ops','work_order','target_year'),
      ('ops','work_order','notes'),
      ('ops','work_order','display_test_session_id'),
      ('ops','work_order_assignment','work_order_assignment_id'),
      ('ops','work_order_assignment','active_flag'),
      ('ops','work_order_assignment','unassigned_at'),
      ('stage','work_order_intake','submitter_person_id'),
      ('stage','work_order_intake','source_form_name'),
      ('ref','person','directus_user_id')
    ) AS required(s,t,c)
    WHERE NOT EXISTS (
      SELECT 1 FROM information_schema.columns col
      WHERE col.table_schema=required.s AND col.table_name=required.t
        AND col.column_name=required.c
    )
  ) THEN
    RAISE EXCEPTION 'WO419 V1: native schema differs; stop before any migration';
  END IF;
END $preflight$;


DO $worker$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='work_management_mail') THEN
    RAISE EXCEPTION 'Dedicated mail worker role must be provisioned by Server Management';
  END IF;
END $worker$;

CREATE TABLE ops.work_management_mail_delivery (
  delivery_key text PRIMARY KEY CHECK (delivery_key ~ '^[a-f0-9]{64}$'),
  event_key text NOT NULL UNIQUE REFERENCES ops.work_management_outbox(event_key),
  recipient_email text NOT NULL,
  content jsonb NOT NULL,
  status text NOT NULL CHECK (status IN ('IN_PROGRESS','SMTP_ACCEPTED',
    'FAILED_BEFORE_DATA','REJECTED','UNKNOWN')),
  evidence text,
  claimed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  finished_at timestamptz
);
REVOKE ALL ON ops.work_management_mail_delivery FROM PUBLIC;
COMMENT ON TABLE ops.work_management_mail_delivery IS
  'Immutable per-event mail attempt; SMTP_ACCEPTED is not Inbox proof. Retain uncertain claims; no automatic retry.';

CREATE FUNCTION ops.work_management_mail_claim(
  p_key text,p_event text,p_recipient text,p_content jsonb
) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,ops,public AS $claim$
DECLARE v_out ops.work_management_outbox%ROWTYPE;
BEGIN
  -- Two exact replaced Flows must exist and be inactive. Missing metadata is
  -- not treated as evidence that the old senders were safely retired.
  IF (SELECT count(*) FROM public.directus_flows WHERE id IN (
        'ebcde355-32c5-4826-b6fa-360621d0d357'::uuid,
        '9a7fb87b-d78e-492b-b2c5-ac3b521b5cf7'::uuid)
        AND status='inactive') <> 2 THEN
    RAISE EXCEPTION 'Work Order email cutover is not active';
  END IF;
  SELECT * INTO v_out FROM ops.work_management_outbox
    WHERE event_key=p_event FOR UPDATE;
  IF NOT FOUND OR v_out.delivery_status <> 'QUEUED' THEN
    RETURN false;
  END IF;
  IF lower(v_out.recipient_email) IS DISTINCT FROM lower(p_recipient) OR
     nullif(btrim(p_recipient),'') IS NULL THEN
    RAISE EXCEPTION 'Mail recipient differs from queued event';
  END IF;
  IF jsonb_typeof(p_content) IS DISTINCT FROM 'object' OR
     NOT (p_content ?& ARRAY['subject','text','html','template_sha256']) THEN
    RAISE EXCEPTION 'Rendered immutable mail content required';
  END IF;
  INSERT INTO ops.work_management_mail_delivery
    (delivery_key,event_key,recipient_email,content,status)
  VALUES(p_key,p_event,p_recipient,p_content,'IN_PROGRESS')
  ON CONFLICT DO NOTHING;
  RETURN FOUND;
END $claim$;

CREATE FUNCTION ops.work_management_mail_finish(
  p_key text,p_status text,p_evidence text
) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,ops AS $finish$
DECLARE v_event text;
BEGIN
  IF p_status NOT IN ('SMTP_ACCEPTED','FAILED_BEFORE_DATA','REJECTED','UNKNOWN')
     OR p_status IS NULL OR p_evidence IS NULL OR length(p_evidence)>100 THEN
    RAISE EXCEPTION 'Invalid mail outcome';
  END IF;
  UPDATE ops.work_management_mail_delivery SET status=p_status,
    evidence=p_evidence,finished_at=clock_timestamp()
  WHERE delivery_key=p_key AND status='IN_PROGRESS' RETURNING event_key INTO v_event;
  IF NOT FOUND THEN RAISE EXCEPTION 'Mail attempt is absent or already finished'; END IF;
  UPDATE ops.work_management_outbox SET
    delivery_status=CASE WHEN p_status='SMTP_ACCEPTED' THEN 'SENT' ELSE 'FAILED' END,
    delivered_at=CASE WHEN p_status='SMTP_ACCEPTED' THEN clock_timestamp() ELSE NULL END
  WHERE event_key=v_event;
  RETURN true;
END $finish$;
REVOKE ALL ON FUNCTION ops.work_management_mail_claim(text,text,text,jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION ops.work_management_mail_finish(text,text,text) FROM PUBLIC;
GRANT USAGE ON SCHEMA ops TO work_management_mail;
GRANT EXECUTE ON FUNCTION ops.work_management_mail_claim(text,text,text,jsonb),
  ops.work_management_mail_finish(text,text,text) TO work_management_mail;
COMMIT;
