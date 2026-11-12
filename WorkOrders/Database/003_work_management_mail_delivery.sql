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
-- New-event capture is OFF until a separately governed atomic cutover.
-- No historic PENDING_CUTOVER intent is automatically queued.
ALTER TABLE ops.work_management_outbox ALTER COLUMN activity_id DROP NOT NULL;
ALTER TABLE ops.work_management_outbox ADD COLUMN message_kind text
  CHECK (message_kind IN ('new_request','assignment','outcome','more_info','reporter_reply'));
ALTER TABLE ops.work_management_outbox ADD COLUMN payload jsonb;
ALTER TABLE ops.work_management_outbox ADD COLUMN failure_reason text;
CREATE TABLE ops.work_management_mail_control (
  singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),
  capture_enabled boolean NOT NULL DEFAULT false
);
INSERT INTO ops.work_management_mail_control(singleton) VALUES(true);
REVOKE ALL ON ops.work_management_mail_control FROM PUBLIC;

CREATE FUNCTION ops.work_management_capture_mail() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ops,ref,stage AS $capture$
DECLARE
  v_ticket text; v_kind text; v_event text; v_title text;
  v_reporter integer; v_access boolean; v_recipients integer[]; v_person integer;
  v_email text; v_name text; v_reporter_name text; v_payload jsonb; v_wo ops.work_order%ROWTYPE;
  v_intake stage.work_order_intake%ROWTYPE;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM ops.work_management_mail_control WHERE capture_enabled) THEN
    RETURN NEW;
  END IF;
  IF TG_TABLE_NAME='work_order_intake' THEN
    v_ticket := 'INTAKE-' || NEW.intake_id;
    v_event := 'phase2:intake:' || NEW.intake_id;
    v_kind := 'new_request'; v_title := NEW.problem_raw;
    v_reporter := NEW.submitter_person_id;
    SELECT array_agg(person_id) INTO v_recipients FROM ref.person
      WHERE is_manager AND active_flag AND nullif(btrim(email),'') IS NOT NULL;
    SELECT coalesce(nullif(btrim(concat_ws(' ',coalesce(nullif(preferred_name,''),first_name),last_name)),''),'Reporter')
      INTO v_reporter_name FROM ref.person WHERE person_id=v_reporter;
    v_payload := jsonb_build_object('reporter',coalesce(v_reporter_name,
      nullif(NEW.submitter_name_raw,''),nullif(NEW.submitter_email_raw,''),'Not recorded'),
      'source_form_name',NEW.source_form_name,
      'task_name',coalesce(nullif(btrim(NEW.source_payload->>'task_name'),''),
                          'Setup task (name not recorded)'));
  ELSIF TG_TABLE_NAME='work_order_assignment' THEN
    IF NOT NEW.active_flag THEN RETURN NEW; END IF;
    SELECT * INTO STRICT v_wo FROM ops.work_order WHERE work_order_id=NEW.work_order_id;
    IF v_wo.date_completed IS NOT NULL OR NOT v_wo.is_active THEN RETURN NEW; END IF;
    v_ticket := 'WO-' || NEW.work_order_id;
    v_event := 'phase2:assignment:' || NEW.work_order_assignment_id;
    v_kind := 'assignment'; v_title := v_wo.problem;
    v_recipients := ARRAY[NEW.person_id::integer];
    v_payload := jsonb_build_object('due_by',coalesce(v_wo.due_by::text,'Due date required'));
  ELSIF TG_TABLE_NAME='work_management_activity' THEN
    IF NEW.event_kind NOT IN ('clarify','reply','resolve','complete','cancel') THEN RETURN NEW; END IF;
    v_ticket := NEW.ticket_key;
    v_event := 'phase2:activity:' || NEW.activity_id;
    IF v_ticket LIKE 'INTAKE-%' THEN
      SELECT * INTO STRICT v_intake FROM stage.work_order_intake
        WHERE intake_id=split_part(v_ticket,'-',2)::bigint;
      v_title := v_intake.problem_raw; v_reporter := v_intake.submitter_person_id;
    ELSE
      SELECT * INTO STRICT v_wo FROM ops.work_order
        WHERE work_order_id=split_part(v_ticket,'-',2)::bigint;
      v_title := v_wo.problem;
      SELECT submitter_person_id INTO v_reporter FROM stage.work_order_intake
        WHERE intake_id=v_wo.source_intake_id;
      v_reporter := coalesce(v_reporter,v_wo.submitted_by_person_id);
    END IF;
    IF NEW.event_kind='reply' THEN
      -- The explicit owner remains responsible; otherwise notify the question author.
      SELECT target_person_id INTO v_reporter FROM ops.work_management_activity
        WHERE ticket_key=v_ticket AND event_kind='correction_owner'
        ORDER BY activity_id DESC LIMIT 1;
      IF v_reporter IS NULL THEN
        SELECT actor_person_id INTO v_reporter FROM ops.work_management_activity
          WHERE ticket_key=v_ticket AND event_kind='clarify'
          ORDER BY activity_id DESC LIMIT 1;
      END IF;
    END IF;
    v_recipients := ARRAY[v_reporter];
    v_kind := CASE NEW.event_kind WHEN 'clarify' THEN 'more_info' WHEN 'reply' THEN 'reporter_reply' ELSE 'outcome' END;
    v_payload := jsonb_build_object('question',NEW.note,'reason',NEW.note,
      'outcome',CASE NEW.event_kind WHEN 'complete' THEN 'Done'
         WHEN 'cancel' THEN 'Canceled — no work performed'
         ELSE coalesce(NEW.details->>'disposition','Decision recorded') END);
  ELSE
    RAISE EXCEPTION 'Unrecognized mail capture source';
  END IF;
  -- Retain an actionable missing-recipient record instead of silently dropping it.
  IF coalesce(cardinality(v_recipients),0)=0 THEN v_recipients:=ARRAY[NULL::integer]; END IF;
  FOREACH v_person IN ARRAY v_recipients LOOP
    SELECT email,coalesce(nullif(btrim(concat_ws(' ',coalesce(nullif(preferred_name,''),first_name),last_name)),''),'Volunteer')
      INTO v_email,v_name FROM ref.person WHERE person_id=v_person;
    -- Protected response links are useful only to an existing authorized identity.
    -- Authorization failure becomes a manual-contact exception, never a new role.
    v_access := true;
    IF v_kind='more_info' THEN
      BEGIN
        SELECT EXISTS(SELECT 1 FROM ops.work_management_v1_actor(v_email)
          WHERE person_id=v_person) INTO v_access;
      EXCEPTION WHEN insufficient_privilege THEN v_access := false;
      END;
    END IF;
    IF NOT EXISTS(SELECT 1 FROM ref.person WHERE person_id=v_person AND active_flag) THEN
      v_access := false;
    END IF;
    INSERT INTO ops.work_management_outbox
      (event_key,ticket_key,recipient_person_id,recipient_email,delivery_status,message_kind,payload)
    VALUES (v_event || ':' || coalesce(v_person::text,'missing'),v_ticket,v_person,v_email,
      CASE WHEN nullif(btrim(v_email),'') IS NULL OR NOT v_access THEN 'MISSING_RECIPIENT' ELSE 'QUEUED' END,
      v_kind,coalesce(v_payload,'{}'::jsonb) || jsonb_build_object('ticket',v_ticket,
         'title',coalesce(nullif(v_title,''),'Description not recorded'),
         'assignees',coalesce(v_name,'No contact recorded'),
         'ticket_url','https://my.sheboyganlights.org/workorder/?ticket=' || v_ticket))
    ON CONFLICT(event_key) DO NOTHING;
  END LOOP;
  RETURN NEW;
END $capture$;
REVOKE ALL ON FUNCTION ops.work_management_capture_mail() FROM PUBLIC;
CREATE TRIGGER work_management_intake_mail AFTER INSERT ON stage.work_order_intake
  FOR EACH ROW EXECUTE FUNCTION ops.work_management_capture_mail();
CREATE TRIGGER work_management_assignment_mail AFTER INSERT ON ops.work_order_assignment
  FOR EACH ROW EXECUTE FUNCTION ops.work_management_capture_mail();
CREATE TRIGGER work_management_activity_mail AFTER INSERT ON ops.work_management_activity
  FOR EACH ROW EXECUTE FUNCTION ops.work_management_capture_mail();

CREATE FUNCTION ops.work_management_mail_candidates()
RETURNS TABLE(event_key text,recipient_email text,message_kind text,payload jsonb)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=pg_catalog,ops AS $candidates$
  SELECT o.event_key,o.recipient_email,o.message_kind,o.payload
  FROM ops.work_management_outbox o
  WHERE o.delivery_status='QUEUED' AND o.message_kind IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM ops.work_management_mail_delivery d WHERE d.event_key=o.event_key)
  ORDER BY o.outbox_id LIMIT 50
$candidates$;
REVOKE ALL ON FUNCTION ops.work_management_mail_candidates() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.work_management_mail_candidates() TO work_management_mail;


-- Reporter read access is scoped to their own native Work Order.
CREATE OR REPLACE FUNCTION ops.work_management_v1_activity(
  p_email text,p_ticket text
) RETURNS TABLE (
  event_kind text, actor_person_id integer,target_person_id integer,
  note text,details jsonb,created_at timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,ops,ref,stage
AS $activity$
DECLARE
  v_actor record;
  v_id integer;
BEGIN
  SELECT a.* INTO v_actor FROM ops.work_management_v1_actor(p_email) a;
  IF NOT FOUND OR p_ticket !~ '^(WO|INTAKE)-[1-9][0-9]*$' THEN
    RAISE EXCEPTION 'Work Orders: ticket activity unauthorized' USING ERRCODE='42501';
  END IF;
  v_id:=split_part(p_ticket,'-',2)::integer;
  IF NOT v_actor.can_manage THEN
    IF p_ticket LIKE 'WO-%' THEN
      IF NOT EXISTS (
        SELECT 1 FROM ops.work_order_assignment a
        WHERE a.work_order_id=v_id AND a.person_id=v_actor.person_id
          AND a.active_flag
      ) AND NOT EXISTS (
        SELECT 1 FROM ops.work_order w WHERE w.work_order_id=v_id
          AND coalesce((SELECT i.submitter_person_id FROM stage.work_order_intake i
            WHERE i.intake_id=w.source_intake_id),w.submitted_by_person_id)=v_actor.person_id
      ) THEN
        RAISE EXCEPTION 'Work Orders: ticket activity not assigned'
          USING ERRCODE='42501';
      END IF;
    ELSE
      IF NOT EXISTS (
        SELECT 1 FROM stage.work_order_intake i
        WHERE i.intake_id=v_id AND i.submitter_person_id=v_actor.person_id
      ) AND (SELECT a.target_person_id FROM ops.work_management_activity a
        WHERE a.ticket_key=p_ticket AND a.event_kind='correction_owner'
        ORDER BY a.activity_id DESC LIMIT 1) IS DISTINCT FROM v_actor.person_id THEN
        RAISE EXCEPTION 'Work Orders: not original reporter' USING ERRCODE='42501';
      END IF;
    END IF;
  END IF;
  RETURN QUERY SELECT a.event_kind,a.actor_person_id,a.target_person_id,
    a.note,a.details,a.created_at
  FROM ops.work_management_activity a WHERE a.ticket_key=p_ticket
  ORDER BY a.activity_id;
END
$activity$;
-- A malformed template/envelope is provably unsent and remains visible for repair.
CREATE FUNCTION ops.work_management_mail_render_failure(p_event text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ops AS $renderfail$
BEGIN
  UPDATE ops.work_management_outbox o SET delivery_status='FAILED',
    failure_reason='template_or_envelope_invalid_no_send'
    WHERE o.event_key=p_event AND o.delivery_status='QUEUED' AND o.message_kind IS NOT NULL
      AND NOT EXISTS(SELECT 1 FROM ops.work_management_mail_delivery d WHERE d.event_key=p_event);
  RETURN FOUND;
END $renderfail$;
REVOKE ALL ON FUNCTION ops.work_management_mail_render_failure(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.work_management_mail_render_failure(text) TO work_management_mail;

-- Manager-only receipt inspection; no recipient address or frozen message body exposed.
CREATE FUNCTION ops.work_management_mail_status(p_email text,p_ticket text)
RETURNS TABLE(event_key text,message_kind text,status text,evidence text,
  claimed_at timestamptz,finished_at timestamptz)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,ops AS $status$
BEGIN
  IF NOT EXISTS(SELECT 1 FROM ops.work_management_v1_actor(p_email) WHERE can_manage)
    OR p_ticket !~ '^(WO|INTAKE)-[1-9][0-9]*$' THEN
    RAISE EXCEPTION 'Manager notification review required' USING ERRCODE='42501';
  END IF;
  RETURN QUERY SELECT o.event_key,o.message_kind,coalesce(d.status,o.delivery_status),
    coalesce(d.evidence,o.failure_reason),d.claimed_at,d.finished_at
    FROM ops.work_management_outbox o LEFT JOIN ops.work_management_mail_delivery d USING(event_key)
    WHERE o.ticket_key=p_ticket ORDER BY o.outbox_id DESC;
END $status$;
REVOKE ALL ON FUNCTION ops.work_management_mail_status(text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.work_management_mail_status(text,text) TO work_management_app;
COMMIT;
