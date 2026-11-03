-- #419: continue reporter communication after Intake promotion.
-- Governed release only; existing mail capture/worker remains the sole sender.
BEGIN;
DO $gate$
BEGIN
  IF ((current_database()='msb' AND
    current_setting('msb.wo419_v1_migration_approved',true)='approved_maintenance_snapshot') OR
    (current_database()='msb_wo419_preview' AND
    current_setting('msb.wo419_preview_authorized',true)='approved_disposable_clone')) IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'WO419: approved migration boundary required';
  END IF;
  IF to_regprocedure('ops.work_management_capture_mail()') IS NULL THEN
    RAISE EXCEPTION 'WO419: installed Phase 2 mail capture required';
  END IF;
END $gate$;

CREATE FUNCTION ops.work_management_wo_followup(
  p_email text,p_action text,p_ticket text,p_body jsonb,p_request_key uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,ops,ref,stage AS $followup$
DECLARE
  v_actor record; v_wo ops.work_order%ROWTYPE; v_prior record;
  v_reporter integer; v_note text; v_last text; v_event bigint;
BEGIN
  SELECT a.* INTO STRICT v_actor FROM ops.work_management_v1_actor(p_email) a;
  IF p_action IS NULL OR p_action NOT IN ('clarify','reply') OR
     p_ticket IS NULL OR p_ticket !~ '^WO-[1-9][0-9]*$' OR
     p_body IS NULL OR jsonb_typeof(p_body)<>'object' OR p_request_key IS NULL THEN
    RAISE EXCEPTION 'Work Orders: invalid follow-up' USING ERRCODE='22023';
  END IF;
  v_note:=btrim(coalesce(p_body->>'response',''));
  IF length(v_note)<10 OR length(v_note)>5000 THEN
    RAISE EXCEPTION 'Work Orders: substantive response/reason required' USING ERRCODE='22023';
  END IF;
  -- Match existing command locking order. Same request cannot create two events.
  PERFORM pg_advisory_xact_lock(hashtextextended(p_request_key::text,0));
  SELECT * INTO v_prior FROM ops.work_management_activity WHERE request_key=p_request_key;
  IF FOUND THEN
    IF v_prior.ticket_key<>p_ticket OR v_prior.event_kind<>p_action OR
       v_prior.actor_person_id<>v_actor.person_id OR v_prior.note<>v_note THEN
      RAISE EXCEPTION 'Work Orders: follow-up request key conflict' USING ERRCODE='23505';
    END IF;
    RETURN jsonb_build_object('saved',true,'repeat',true,'ticket',p_ticket,
      'activity_id',v_prior.activity_id);
  END IF;
  SELECT * INTO v_wo FROM ops.work_order
    WHERE work_order_id=split_part(p_ticket,'-',2)::integer FOR UPDATE;
  IF NOT FOUND OR NOT v_wo.is_active OR v_wo.date_completed IS NOT NULL THEN
    RAISE EXCEPTION 'Work Orders: follow-up requires an open Work Order' USING ERRCODE='23514';
  END IF;
  SELECT i.submitter_person_id INTO v_reporter FROM stage.work_order_intake i
    WHERE i.intake_id=v_wo.source_intake_id;
  v_reporter:=coalesce(v_reporter,v_wo.submitted_by_person_id);
  IF p_action='clarify' AND NOT (v_actor.can_manage OR EXISTS (
    SELECT 1 FROM ops.work_order_assignment a WHERE a.work_order_id=v_wo.work_order_id
      AND a.person_id=v_actor.person_id AND a.active_flag)) THEN
    RAISE EXCEPTION 'Work Orders: active assignee or Manager required' USING ERRCODE='42501';
  END IF;
  IF p_action='reply' AND v_reporter IS DISTINCT FROM v_actor.person_id THEN
    RAISE EXCEPTION 'Work Orders: only original reporter may reply' USING ERRCODE='42501';
  END IF;
  SELECT a.event_kind INTO v_last FROM ops.work_management_activity a
    WHERE a.ticket_key=p_ticket AND a.event_kind IN ('clarify','reply')
    ORDER BY a.activity_id DESC LIMIT 1;
  IF (p_action='reply' AND v_last IS DISTINCT FROM 'clarify') OR
     (p_action='clarify' AND v_last='clarify') THEN
    RAISE EXCEPTION 'Work Orders: follow-up state changed; refresh this Work Order' USING ERRCODE='23514';
  END IF;
  -- Existing trigger snapshots recipients and queues once in this transaction.
  INSERT INTO ops.work_management_activity
    (request_key,ticket_key,event_kind,actor_person_id,note,details)
  VALUES(p_request_key,p_ticket,p_action,v_actor.person_id,v_note,
    jsonb_build_object('reporter_person_id',v_reporter)) RETURNING activity_id INTO v_event;
  RETURN jsonb_build_object('saved',true,'repeat',false,'ticket',p_ticket,
    'activity_id',v_event,'notifications',CASE WHEN EXISTS (
      SELECT 1 FROM ops.work_management_outbox WHERE event_key LIKE
        'phase2:activity:'||v_event||':%' AND delivery_status='MISSING_RECIPIENT'
    ) THEN 'MISSING_RECIPIENT' ELSE 'QUEUED' END);
END $followup$;
REVOKE ALL ON FUNCTION ops.work_management_wo_followup(text,text,text,jsonb,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.work_management_wo_followup(text,text,text,jsonb,uuid) TO work_management_app;

-- Original reporters can read the response history on their own WO.
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
        SELECT 1 FROM ops.work_order w LEFT JOIN stage.work_order_intake i
          ON i.intake_id=w.source_intake_id
        WHERE w.work_order_id=v_id AND
          coalesce(i.submitter_person_id,w.submitted_by_person_id)=v_actor.person_id
      ) THEN
        RAISE EXCEPTION 'Work Orders: ticket activity not assigned'
          USING ERRCODE='42501';
      END IF;
    ELSE
      IF NOT EXISTS (
        SELECT 1 FROM stage.work_order_intake i
        WHERE i.intake_id=v_id AND i.submitter_person_id=v_actor.person_id
      ) THEN
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


-- Keep canonical repair identity without altering original reports or repair truth.
CREATE TABLE ops.work_management_duplicate_link (
  source_ticket text PRIMARY KEY CHECK(source_ticket ~ '^(WO|INTAKE)-[1-9][0-9]*$'),
  target_work_order_id integer NOT NULL REFERENCES ops.work_order(work_order_id),
  activity_id bigint NOT NULL UNIQUE REFERENCES ops.work_management_activity(activity_id),
  CHECK(source_ticket <> 'WO-' || target_work_order_id)
);
REVOKE ALL ON ops.work_management_duplicate_link FROM PUBLIC;
GRANT SELECT ON ops.work_management_duplicate_link TO work_management_app;

CREATE FUNCTION ops.work_management_duplicate(
  p_email text,p_action text,p_ticket text,p_body jsonb,p_request_key uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,ops,ref,stage AS $duplicate$
DECLARE
  v_actor record; v_target integer; v_reason text; v_saved jsonb;
  v_prior record; v_native_action text; v_native_body jsonb;
BEGIN
  SELECT a.* INTO STRICT v_actor FROM ops.work_management_v1_actor(p_email) a;
  IF NOT v_actor.can_manage THEN
    RAISE EXCEPTION 'Work Orders: Manager authorization required' USING ERRCODE='42501';
  END IF;
  IF p_action IS DISTINCT FROM 'duplicate' OR p_ticket IS NULL OR
     p_ticket !~ '^(WO|INTAKE)-[1-9][0-9]*$' OR p_request_key IS NULL OR
     p_body IS NULL OR jsonb_typeof(p_body)<>'object' OR
     coalesce(p_body->>'duplicate_of','') !~ '^WO-[1-9][0-9]{0,8}$' THEN
    RAISE EXCEPTION 'Work Orders: valid original Work Order required' USING ERRCODE='22023';
  END IF;
  v_target:=split_part(p_body->>'duplicate_of','-',2)::integer;
  v_reason:=btrim(coalesce(p_body->>'response',''));
  IF length(v_reason)<10 OR length(v_reason)>4500 OR p_ticket='WO-'||v_target THEN
    RAISE EXCEPTION 'Work Orders: duplicate needs a different original and a reason' USING ERRCODE='22023';
  END IF;
  -- Graph operations serialize; normal WO writes still use their existing locks.
  PERFORM pg_advisory_xact_lock(hashtextextended('wo419:duplicate-links',0));
  PERFORM pg_advisory_xact_lock(hashtextextended(p_request_key::text,0));
  SELECT a.* INTO v_prior FROM ops.work_management_activity a WHERE request_key=p_request_key;
  IF FOUND THEN
    IF v_prior.ticket_key<>p_ticket OR v_prior.actor_person_id<>v_actor.person_id OR
       v_prior.details->>'duplicate_of' IS DISTINCT FROM 'WO-'||v_target OR
       v_prior.details->>'duplicate_reason' IS DISTINCT FROM v_reason THEN
      RAISE EXCEPTION 'Work Orders: duplicate request key conflict' USING ERRCODE='23505';
    END IF;
    RETURN jsonb_build_object('saved',true,'repeat',true,'ticket',p_ticket,'activity_id',v_prior.activity_id);
  END IF;
  IF NOT EXISTS(SELECT 1 FROM ops.work_order WHERE work_order_id=v_target) THEN
    RAISE EXCEPTION 'Work Orders: original Work Order not found' USING ERRCODE='22023';
  END IF;
  IF EXISTS(SELECT 1 FROM ops.work_management_duplicate_link
    WHERE source_ticket IN (p_ticket,'WO-'||v_target) OR 'WO-'||target_work_order_id=p_ticket) THEN
    RAISE EXCEPTION 'Work Orders: duplicate relationship already exists; review the original' USING ERRCODE='23505';
  END IF;
  v_native_action:=CASE WHEN p_ticket LIKE 'WO-%' THEN 'cancel' ELSE 'resolve' END;
  v_native_body:=jsonb_build_object('disposition','duplicate',
    'response','Duplicate of WO-'||v_target||': '||v_reason,
    'cancel_reason','Duplicate of WO-'||v_target||': '||v_reason);
  -- Preserve existing completion/Testing/promoted-Intake and actor audit guards.
  v_saved:=ops.work_management_v1_command(p_email,v_native_action,p_ticket,v_native_body,p_request_key);
  UPDATE ops.work_management_activity SET details=details||jsonb_build_object(
    'duplicate_of','WO-'||v_target,'duplicate_reason',v_reason)
    WHERE activity_id=(v_saved->>'activity_id')::bigint;
  INSERT INTO ops.work_management_duplicate_link VALUES
    (p_ticket,v_target,(v_saved->>'activity_id')::bigint);
  RETURN v_saved;
END $duplicate$;
REVOKE ALL ON FUNCTION ops.work_management_duplicate(text,text,text,jsonb,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.work_management_duplicate(text,text,text,jsonb,uuid) TO work_management_app;

-- Preserve recipient routing; correlate new assignment messages to their Intake.
CREATE OR REPLACE FUNCTION ops.work_management_capture_mail() RETURNS trigger
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
    v_payload := jsonb_build_object('due_by',coalesce(v_wo.due_by::text,'Due date required'),
      'source_request',CASE WHEN v_wo.source_intake_id IS NULL THEN 'No source request recorded'
        ELSE 'INTAKE-'||v_wo.source_intake_id END);
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

COMMIT;
