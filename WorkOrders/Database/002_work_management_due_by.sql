-- #419 Phase 2 candidate: NOT DEPLOYED. Apply only using #37 maintenance,
-- validated snapshot and current-Production disposable acceptance.
-- Native optional column preserves legacy and automatically generated repairs.
-- Manager Create/Promote/Edit enforce an explicit deadline in the command.
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

ALTER TABLE ops.work_order ADD COLUMN due_by date;
COMMENT ON COLUMN ops.work_order.due_by IS
  'Manager-selected calendar deadline in America/Chicago; NULL legacy work requires Manager follow-up';

-- Extend the existing audit vocabulary for the deadline-only Manager command.
ALTER TABLE ops.work_management_activity DROP CONSTRAINT work_management_activity_event_kind_check;
ALTER TABLE ops.work_management_activity ADD CONSTRAINT work_management_activity_event_kind_check
  CHECK(event_kind IN ('create','assign','progress','complete','promote','promoted_source',
    'correction_owner','clarify','reply','resolve','edit','cancel','due_date'));

CREATE OR REPLACE FUNCTION ops.work_management_v1_command(
  p_email text, p_action text, p_ticket text, p_body jsonb, p_request_key uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog,ops,ref,stage
AS $cmd$
DECLARE
  v_actor record;
  v_existing record;
  v_old record;
  v_intake stage.work_order_intake%ROWTYPE;
  v_wo ops.work_order%ROWTYPE;
  v_wo_id integer;
  v_intake_id integer;
  v_urgency integer;
  v_year integer;
  v_due date;
  v_stage integer;
  v_area integer;
  v_task_type integer;
  v_problem text;
  v_note text;
  v_status text;
  v_disposition text;
  v_delivery text := 'PENDING_CUTOVER';
  v_people integer[];
  v_person integer;
  v_event bigint;
  v_ticket text;
  v_details jsonb := '{}'::jsonb;
  v_replay record;
BEGIN
  IF p_body IS NULL OR jsonb_typeof(p_body) <> 'object' OR
     p_request_key IS NULL OR p_action IS NULL OR
     p_action NOT IN ('create','assign','progress','complete','promote',
                      'correction_owner','clarify','reply','resolve','edit','cancel','due_date') THEN
    RAISE EXCEPTION 'Work Orders: invalid command/request key' USING ERRCODE='22023';
  END IF;
  SELECT a.* INTO v_actor FROM ops.work_management_v1_actor(p_email) a;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Work Orders: actor not verified' USING ERRCODE='42501';
  END IF;
  IF p_action IN ('create','assign','promote','correction_owner','clarify','resolve','edit','cancel','due_date')
     AND NOT v_actor.can_manage THEN
    RAISE EXCEPTION 'Work Orders: Manager authorization required'
      USING ERRCODE='42501';
  END IF;
  IF p_action <> 'create' AND
     (p_ticket IS NULL OR p_ticket !~ '^(WO|INTAKE)-[1-9][0-9]*$') THEN
    RAISE EXCEPTION 'Work Orders: existing ticket required' USING ERRCODE='22023';
  END IF;
  IF p_action = 'create' AND p_ticket IS NOT NULL THEN
    RAISE EXCEPTION 'Work Orders: Create must have no existing ticket'
      USING ERRCODE='22023';
  END IF;

  -- Recheck the human identity and native audit trigger actor per transaction.
  PERFORM set_config('app.directus_user_uuid',
                     v_actor.directus_user_id::text,true);
  -- Serializes simultaneous retries of the same request key.
  PERFORM pg_advisory_xact_lock(hashtextextended(p_request_key::text,0));
  SELECT e.ticket_key,e.event_kind,e.actor_person_id INTO v_replay
  FROM ops.work_management_activity e WHERE e.request_key=p_request_key;
  IF FOUND THEN
    IF v_replay.event_kind<>p_action OR
       v_replay.actor_person_id<>v_actor.person_id THEN
      RAISE EXCEPTION 'Work Orders: idempotency key used by a different action/actor'
        USING ERRCODE='23505';
    END IF;
    RETURN jsonb_build_object('ticket',v_replay.ticket_key,'saved',true,
                              'repeat',true,'notifications','PENDING_CUTOVER');
  END IF;

  -- Manager-entered calendar deadline; never invent dates for legacy work.
  -- Existing request-key replay above preserves the original committed result.
  IF p_action IN ('create','promote','edit','due_date') THEN
    IF coalesce(p_body->>'due_by','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
      RAISE EXCEPTION 'Work Orders: Due by date is required' USING ERRCODE='22023';
    END IF;
    BEGIN
      v_due := (p_body->>'due_by')::date;
    EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow THEN
      RAISE EXCEPTION 'Work Orders: invalid Due by date' USING ERRCODE='22023';
    END;
    IF v_due NOT BETWEEN DATE '2020-01-01' AND DATE '2100-12-31' THEN
      RAISE EXCEPTION 'Work Orders: Due by date out of range' USING ERRCODE='22023';
    END IF;
  END IF;

  -- Multi-person selection is only meaningful on native Create/Promote/Assign.
  IF p_action IN ('create','promote','assign','correction_owner') THEN
    IF jsonb_typeof(coalesce(p_body->'person_ids','[]'::jsonb)) <> 'array' THEN
      RAISE EXCEPTION 'Work Orders: assignees must be an array' USING ERRCODE='22023';
    END IF;
    SELECT coalesce(array_agg(DISTINCT item.value::integer),ARRAY[]::integer[])
    INTO v_people
    FROM jsonb_array_elements_text(coalesce(p_body->'person_ids','[]'::jsonb))
         AS item(value)
    WHERE item.value ~ '^[1-9][0-9]{0,9}$';
    IF jsonb_array_length(coalesce(p_body->'person_ids','[]'::jsonb))>50 OR
       cardinality(v_people)<>jsonb_array_length(
           coalesce(p_body->'person_ids','[]'::jsonb)) THEN
      RAISE EXCEPTION 'Work Orders: invalid or duplicate Person IDs'
        USING ERRCODE='22023';
    END IF;
    IF EXISTS (
      SELECT 1 FROM unnest(v_people) wanted
      LEFT JOIN ref.person p ON p.person_id=wanted AND p.active_flag
      WHERE p.person_id IS NULL
    ) THEN
      RAISE EXCEPTION 'Work Orders: only existing active People may be assigned'
        USING ERRCODE='22023';
    END IF;
  ELSE
    v_people := ARRAY[]::integer[];
  END IF;

  IF p_action IN ('create','promote') THEN
    v_problem := btrim(coalesce(p_body->>'problem',''));
    IF length(v_problem)<10 OR length(v_problem)>5000 THEN
      RAISE EXCEPTION 'Work Orders: work description must be 10 to 5000 characters'
        USING ERRCODE='22023';
    END IF;
    IF coalesce(p_body->>'task_type_id','') !~ '^[1-9][0-9]{0,9}$' THEN
      RAISE EXCEPTION 'Work Orders: valid Task Type required' USING ERRCODE='22023';
    END IF;
    v_task_type := (p_body->>'task_type_id')::integer;
    IF NOT EXISTS (SELECT 1 FROM ref.task_type
                   WHERE task_type_id=v_task_type AND active_flag) THEN
      RAISE EXCEPTION 'Work Orders: Task Type not active' USING ERRCODE='22023';
    END IF;
    IF coalesce(p_body->>'urgency','') NOT IN ('1','2','3','4','5','') THEN
      RAISE EXCEPTION 'Work Orders: urgency must be 1-5' USING ERRCODE='22023';
    END IF;
    v_urgency:=coalesce(nullif(p_body->>'urgency','')::integer,3);
    IF coalesce(p_body->>'stage_id','') ~ '^[1-9][0-9]{0,9}$' THEN
      v_stage:=(p_body->>'stage_id')::integer;
    ELSIF coalesce(p_body->>'stage_id','')<>'' THEN
      RAISE EXCEPTION 'Work Orders: invalid Stage' USING ERRCODE='22023';
    END IF;
    IF coalesce(p_body->>'work_area_id','') ~ '^[1-9][0-9]{0,9}$' THEN
      v_area:=(p_body->>'work_area_id')::integer;
    ELSIF coalesce(p_body->>'work_area_id','')<>'' THEN
      RAISE EXCEPTION 'Work Orders: invalid Work Area' USING ERRCODE='22023';
    END IF;
    IF (v_stage IS NULL)=(v_area IS NULL) OR
       (v_stage IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM ref.stage WHERE stage_id=v_stage)) OR
       (v_area IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM ref.work_area WHERE work_area_id=v_area)) THEN
      RAISE EXCEPTION 'Work Orders: exactly one catalog Stage or Work Area required'
        USING ERRCODE='22023';
    END IF;
    IF v_urgency=5 THEN
      IF coalesce(p_body->>'target_year','') !~ '^[0-9]{4}$' THEN
        RAISE EXCEPTION 'Work Orders: Planning requires target year'
          USING ERRCODE='22023';
      END IF;
      v_year:=(p_body->>'target_year')::integer;
      IF v_year NOT BETWEEN 2020 AND 2100 THEN
        RAISE EXCEPTION 'Work Orders: target year out of range' USING ERRCODE='22023';
      END IF;
    ELSIF nullif(p_body->>'target_year','') IS NOT NULL THEN
      RAISE EXCEPTION 'Work Orders: only Planning may have target year'
        USING ERRCODE='22023';
    END IF;
    IF p_action='promote' THEN
      IF p_ticket !~ '^INTAKE-[1-9][0-9]*$' THEN
        RAISE EXCEPTION 'Work Orders: Promote requires Intake' USING ERRCODE='22023';
      END IF;
      v_intake_id:=split_part(p_ticket,'-',2)::integer;
      SELECT * INTO v_intake FROM stage.work_order_intake
        WHERE intake_id=v_intake_id FOR UPDATE;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'Work Orders: Intake not found' USING ERRCODE='02000';
      END IF;
      IF EXISTS (SELECT 1 FROM ops.work_order WHERE source_intake_id=v_intake_id) THEN
        RAISE EXCEPTION 'Work Orders: Intake already promoted'
          USING ERRCODE='23505';
      END IF;
      IF EXISTS (SELECT 1 FROM ops.work_management_activity
                 WHERE ticket_key=p_ticket AND event_kind='resolve') THEN
        RAISE EXCEPTION 'Work Orders: disposed Intake must not be promoted'
          USING ERRCODE='23505';
      END IF;
    END IF;
    INSERT INTO ops.work_order(
      problem,task_type_id,urgency_id,target_year,stage_id,work_area_id,
      created_by_person_id,updated_by_person_id,repair_complete,
      source_intake_id,submitted_by_person_id,source_system,source_form_name,notes,due_by)
    VALUES (
      v_problem,v_task_type,v_urgency,v_year,v_stage,v_area,
      v_actor.person_id,v_actor.person_id,false,
      v_intake_id,
      CASE WHEN v_intake_id IS NULL THEN v_actor.person_id
           ELSE v_intake.submitter_person_id END,
      CASE WHEN v_intake_id IS NULL THEN 'WORK_MANAGEMENT_INTERNAL'
           ELSE coalesce(v_intake.source_system,'WORK_MANAGEMENT') END,
      CASE WHEN v_intake_id IS NULL THEN NULL ELSE v_intake.source_form_name END,
      CASE WHEN v_intake_id IS NULL THEN NULL ELSE v_intake.notes_raw END,v_due)
    RETURNING work_order_id INTO v_wo_id;
    v_ticket:='WO-'||v_wo_id;
    v_details:=jsonb_build_object('source_intake_id',v_intake_id,'due_by',v_due);
  ELSIF p_action IN ('assign','progress','complete','edit','cancel','due_date') THEN
    IF p_ticket !~ '^WO-[1-9][0-9]*$' THEN
      RAISE EXCEPTION 'Work Orders: active native WO required' USING ERRCODE='22023';
    END IF;
    v_wo_id:=split_part(p_ticket,'-',2)::integer;
    SELECT * INTO v_wo FROM ops.work_order WHERE work_order_id=v_wo_id FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Work Orders: WO not found' USING ERRCODE='02000';
    END IF;
    IF v_wo.date_completed IS NOT NULL THEN
      RAISE EXCEPTION 'Work Orders: completed WO is immutable' USING ERRCODE='23514';
    END IF;
    IF NOT v_wo.is_active THEN
      RAISE EXCEPTION 'Work Orders: inactive/cancelled WO cannot be worked'
        USING ERRCODE='23514';
    END IF;
    IF p_action IN ('edit','cancel') AND
       (NOT v_wo.is_active OR v_wo.display_test_session_id IS NOT NULL) THEN
      RAISE EXCEPTION 'Work Orders: inactive/Testing Work Order requires separate governed review'
        USING ERRCODE='23514';
    END IF;
    IF p_action IN ('progress','complete') AND NOT v_actor.can_manage AND
       NOT EXISTS (SELECT 1 FROM ops.work_order_assignment
                   WHERE work_order_id=v_wo_id AND person_id=v_actor.person_id
                     AND active_flag) THEN
      RAISE EXCEPTION 'Work Orders: active assignee required' USING ERRCODE='42501';
    END IF;
    v_ticket:=p_ticket;
  ELSE
    IF p_ticket !~ '^INTAKE-[1-9][0-9]*$' THEN
      RAISE EXCEPTION 'Work Orders: Intake required' USING ERRCODE='22023';
    END IF;
    v_intake_id:=split_part(p_ticket,'-',2)::integer;
    SELECT * INTO v_intake FROM stage.work_order_intake
      WHERE intake_id=v_intake_id FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Work Orders: Intake not found' USING ERRCODE='02000';
    END IF;
    IF p_action='reply' AND
       v_intake.submitter_person_id IS DISTINCT FROM v_actor.person_id THEN
      RAISE EXCEPTION 'Work Orders: only original reporter may reply'
        USING ERRCODE='42501';
    END IF;
    -- A reply answers an outstanding question on this exact unpromoted Intake.
    IF p_action='reply' AND (EXISTS (
      SELECT 1 FROM ops.work_order WHERE source_intake_id=v_intake_id
    ) OR (SELECT event_kind FROM ops.work_management_activity
      WHERE ticket_key=p_ticket AND event_kind IN ('clarify','reply','resolve')
      ORDER BY activity_id DESC LIMIT 1) IS DISTINCT FROM 'clarify') THEN
      RAISE EXCEPTION 'Work Orders: no outstanding clarification on this Intake'
        USING ERRCODE='23514';
    END IF;
    -- Public Intake may be clarified or disposed of without promotion.
    -- Correction-owner assignment remains specific to Setup feedback.
    IF p_action='correction_owner' AND
       v_intake.source_form_name IS DISTINCT FROM 'SETUP_CORRECTION' THEN
      RAISE EXCEPTION 'Work Orders: correction owner applies to Setup feedback'
        USING ERRCODE='22023';
    END IF;
    IF p_action IN ('clarify','resolve') AND EXISTS (
      SELECT 1 FROM ops.work_order WHERE source_intake_id=v_intake_id
    ) THEN
      RAISE EXCEPTION 'Work Orders: linked Work Order owns the outcome'
        USING ERRCODE='23505';
    END IF;
    v_ticket:=p_ticket;
  END IF;

  IF p_action IN ('create','promote','assign') THEN
    IF p_action='assign' THEN
      UPDATE ops.work_order_assignment SET active_flag=false,unassigned_at=now()
      WHERE work_order_id=v_wo_id AND active_flag
        AND person_id<>ALL(v_people);
    END IF;
    FOREACH v_person IN ARRAY v_people LOOP
      IF NOT EXISTS (SELECT 1 FROM ops.work_order_assignment a
                     WHERE a.work_order_id=v_wo_id AND a.person_id=v_person
                       AND a.active_flag) THEN
        INSERT INTO ops.work_order_assignment(work_order_id,person_id,active_flag)
        VALUES (v_wo_id,v_person,true);
      END IF;
    END LOOP;
    v_note:=CASE WHEN p_action='assign' THEN 'Manager reassigned Work Order'
                 WHEN p_action='promote' THEN 'Manager promoted Intake'
                 ELSE 'Manager created Work Order' END;
    v_details:=v_details||jsonb_build_object('assignees',v_people);
  ELSIF p_action='edit' THEN
    -- Validate catalog and planning constraints for UPDATE, never INSERT.
    v_problem := btrim(coalesce(p_body->>'problem',''));
    IF length(v_problem)<10 OR length(v_problem)>5000 THEN
      RAISE EXCEPTION 'Work Orders: work description must be 10 to 5000 characters'
        USING ERRCODE='22023';
    END IF;
    IF coalesce(p_body->>'task_type_id','') !~ '^[1-9][0-9]{0,9}$' THEN
      RAISE EXCEPTION 'Work Orders: valid Task Type required' USING ERRCODE='22023';
    END IF;
    v_task_type := (p_body->>'task_type_id')::integer;
    IF NOT EXISTS (SELECT 1 FROM ref.task_type
                   WHERE task_type_id=v_task_type AND active_flag) THEN
      RAISE EXCEPTION 'Work Orders: Task Type not active' USING ERRCODE='22023';
    END IF;
    IF coalesce(p_body->>'urgency','') NOT IN ('1','2','3','4','5','') THEN
      RAISE EXCEPTION 'Work Orders: urgency must be 1-5' USING ERRCODE='22023';
    END IF;
    v_urgency:=coalesce(nullif(p_body->>'urgency','')::integer,3);
    IF coalesce(p_body->>'stage_id','') ~ '^[1-9][0-9]{0,9}$' THEN
      v_stage:=(p_body->>'stage_id')::integer;
    ELSIF coalesce(p_body->>'stage_id','')<>'' THEN
      RAISE EXCEPTION 'Work Orders: invalid Stage' USING ERRCODE='22023';
    END IF;
    IF coalesce(p_body->>'work_area_id','') ~ '^[1-9][0-9]{0,9}$' THEN
      v_area:=(p_body->>'work_area_id')::integer;
    ELSIF coalesce(p_body->>'work_area_id','')<>'' THEN
      RAISE EXCEPTION 'Work Orders: invalid Work Area' USING ERRCODE='22023';
    END IF;
    IF (v_stage IS NULL)=(v_area IS NULL) OR
       (v_stage IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM ref.stage WHERE stage_id=v_stage)) OR
       (v_area IS NOT NULL AND NOT EXISTS
           (SELECT 1 FROM ref.work_area WHERE work_area_id=v_area)) THEN
      RAISE EXCEPTION 'Work Orders: exactly one catalog Stage or Work Area required'
        USING ERRCODE='22023';
    END IF;
    IF v_urgency=5 THEN
      IF coalesce(p_body->>'target_year','') !~ '^[0-9]{4}$' THEN
        RAISE EXCEPTION 'Work Orders: Planning requires target year'
          USING ERRCODE='22023';
      END IF;
      v_year:=(p_body->>'target_year')::integer;
      IF v_year NOT BETWEEN 2020 AND 2100 THEN
        RAISE EXCEPTION 'Work Orders: target year out of range' USING ERRCODE='22023';
      END IF;
    ELSIF nullif(p_body->>'target_year','') IS NOT NULL THEN
      RAISE EXCEPTION 'Work Orders: only Planning may have target year'
        USING ERRCODE='22023';
    END IF;
    v_note:=btrim(coalesce(p_body->>'edit_reason',''));
    IF length(v_note)<10 OR length(v_note)>5000 THEN
      RAISE EXCEPTION 'Work Orders: Manager correction reason required'
        USING ERRCODE='22023';
    END IF;
    v_details:=jsonb_build_object(
      'before',jsonb_build_object('due_by',v_wo.due_by,'problem',v_wo.problem,'task_type_id',v_wo.task_type_id,
        'urgency_id',v_wo.urgency_id,'target_year',v_wo.target_year,
        'stage_id',v_wo.stage_id,'work_area_id',v_wo.work_area_id),
      'after',jsonb_build_object('due_by',v_due,'problem',v_problem,'task_type_id',v_task_type,
        'urgency_id',v_urgency,'target_year',v_year,
        'stage_id',v_stage,'work_area_id',v_area));
    UPDATE ops.work_order SET
      due_by=v_due,problem=v_problem,task_type_id=v_task_type,urgency_id=v_urgency,
      target_year=v_year,stage_id=v_stage,work_area_id=v_area,
      updated_by_person_id=v_actor.person_id
    WHERE work_order_id=v_wo_id AND is_active AND date_completed IS NULL;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Work Orders: edit target changed concurrently'
        USING ERRCODE='23514';
    END IF;
  ELSIF p_action='due_date' THEN
    -- Deadline-only correction preserves Testing ownership and repair semantics.
    v_note:=btrim(coalesce(p_body->>'edit_reason',''));
    IF length(v_note)<10 OR length(v_note)>5000 THEN
      RAISE EXCEPTION 'Work Orders: deadline change reason required' USING ERRCODE='22023';
    END IF;
    v_details:=jsonb_build_object('before',jsonb_build_object('due_by',v_wo.due_by),
      'after',jsonb_build_object('due_by',v_due));
    UPDATE ops.work_order SET due_by=v_due,updated_by_person_id=v_actor.person_id
      WHERE work_order_id=v_wo_id;
  ELSIF p_action='cancel' THEN
    v_note:=btrim(coalesce(p_body->>'cancel_reason',''));
    IF length(v_note)<10 OR length(v_note)>5000 THEN
      RAISE EXCEPTION 'Work Orders: cancellation requires a substantive safety/no-action reason'
        USING ERRCODE='22023';
    END IF;
    v_details:=jsonb_build_object('prior_active',v_wo.is_active,
                                  'physical_work_completed',false,
                                  'disposition','CANCELLED_NO_ACTION');
    UPDATE ops.work_order SET is_active=false,
      updated_by_person_id=v_actor.person_id
    WHERE work_order_id=v_wo_id AND is_active AND date_completed IS NULL;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Work Orders: cancellation target changed concurrently'
        USING ERRCODE='23514';
    END IF;
  ELSIF p_action='progress' THEN
    v_note:=btrim(coalesce(p_body->>'progress_note',''));
    IF length(v_note)<10 OR length(v_note)>5000 THEN
      RAISE EXCEPTION 'Work Orders: actual progress notes required' USING ERRCODE='22023';
    END IF;
    UPDATE ops.work_order
    SET notes=concat_ws(E'\n',nullif(btrim(notes),''),
         '['||to_char(clock_timestamp() AT TIME ZONE 'UTC','YYYY-MM-DD HH24:MI')
         ||' UTC | Person #'||v_actor.person_id||'] '||v_note),
        updated_by_person_id=v_actor.person_id
    WHERE work_order_id=v_wo_id AND date_completed IS NULL;
  ELSIF p_action='complete' THEN
    v_note:=btrim(coalesce(p_body->>'completion_notes',''));
    IF length(v_note)<10 OR length(v_note)>5000 THEN
      RAISE EXCEPTION 'Work Orders: actual completion notes required' USING ERRCODE='22023';
    END IF;
    UPDATE ops.work_order
    SET completion_notes=v_note,completed_by_person_id=v_actor.person_id,
        date_completed=now(),repair_complete=true,
        updated_by_person_id=v_actor.person_id
    WHERE work_order_id=v_wo_id AND date_completed IS NULL;
  ELSIF p_action='correction_owner' THEN
    IF cardinality(v_people)<>1 THEN
      RAISE EXCEPTION 'Work Orders: exactly one correction owner required'
        USING ERRCODE='22023';
    END IF;
    v_note:='Manager selected correction owner';
  ELSIF p_action IN ('clarify','reply','resolve') THEN
    v_note:=btrim(coalesce(p_body->>'response',''));
    IF length(v_note)<10 OR length(v_note)>5000 THEN
      RAISE EXCEPTION 'Work Orders: substantive response/reason required'
        USING ERRCODE='22023';
    END IF;
    IF p_action='clarify' AND v_intake.submitter_person_id IS NULL THEN
      v_details:=jsonb_build_object('communication','MISSING_RECIPIENT');
      v_delivery:='MISSING_RECIPIENT';
    END IF;
    IF p_action='resolve' THEN
      v_disposition:=coalesce(p_body->>'disposition','');
      IF v_disposition NOT IN ('resolved','deferred','rejected','duplicate') THEN
        RAISE EXCEPTION 'Work Orders: valid disposition required' USING ERRCODE='22023';
      END IF;
      IF EXISTS (SELECT 1 FROM ops.work_management_activity
                 WHERE ticket_key=v_ticket AND event_kind='resolve') THEN
        RAISE EXCEPTION 'Work Orders: correction already resolved'
          USING ERRCODE='23505';
      END IF;
      v_details:=jsonb_build_object('disposition',v_disposition);
    END IF;
  END IF;

  INSERT INTO ops.work_management_activity
    (request_key,ticket_key,event_kind,actor_person_id,target_person_id,note,details)
  VALUES (p_request_key,v_ticket,p_action,v_actor.person_id,
          CASE WHEN p_action='correction_owner' THEN v_people[1] ELSE NULL END,
          coalesce(v_note,''),v_details)
  RETURNING activity_id INTO v_event;

  IF p_action='promote' THEN
    INSERT INTO ops.work_management_activity
       (request_key,ticket_key,event_kind,actor_person_id,note,details)
    VALUES (gen_random_uuid(),p_ticket,'promoted_source',v_actor.person_id,
            'Promoted to '||v_ticket,
            jsonb_build_object('work_order_id',v_wo_id));
  END IF;

  -- Durable notification intent, NEVER an email send. Assignment and reporter
  -- communication are reconciled to one approved transport before cutover.
  IF p_action IN ('create','promote','assign') THEN
    FOREACH v_person IN ARRAY v_people LOOP
      INSERT INTO ops.work_management_outbox(
        event_key,ticket_key,activity_id,recipient_person_id,recipient_email,
        delivery_status)
      SELECT v_ticket||':assignment:'||v_event||':'||v_person,
             v_ticket,v_event,p.person_id,p.email,
             CASE WHEN nullif(btrim(p.email),'') IS NULL
                  THEN 'MISSING_RECIPIENT' ELSE 'PENDING_CUTOVER' END
      FROM ref.person p WHERE p.person_id=v_person
      ON CONFLICT(event_key) DO NOTHING;
    END LOOP;
  ELSIF p_action IN ('clarify','resolve','complete','cancel') THEN
    v_person:=CASE WHEN p_action IN ('complete','cancel') THEN v_wo.submitted_by_person_id
                   ELSE v_intake.submitter_person_id END;
    IF v_person IS NOT NULL AND
       (p_action<>'complete' OR v_wo.display_test_session_id IS NULL) THEN
      INSERT INTO ops.work_management_outbox(
        event_key,ticket_key,activity_id,recipient_person_id,recipient_email,
        delivery_status)
      SELECT v_ticket||':'||p_action||':'||v_event||':'||v_person,
             v_ticket,v_event,p.person_id,p.email,
             CASE WHEN nullif(btrim(p.email),'') IS NULL
                  THEN 'MISSING_RECIPIENT' ELSE 'PENDING_CUTOVER' END
      FROM ref.person p WHERE p.person_id=v_person
      ON CONFLICT(event_key) DO NOTHING;
    ELSIF v_person IS NULL AND
          (p_action<>'complete' OR v_wo.display_test_session_id IS NULL) THEN
      -- Preserve visible communication exception even without a linked Person.
      INSERT INTO ops.work_management_outbox(
        event_key,ticket_key,activity_id,recipient_person_id,recipient_email,
        delivery_status)
      VALUES (v_ticket||':'||p_action||':'||v_event||':missing',
              v_ticket,v_event,NULL,NULL,'MISSING_RECIPIENT')
      ON CONFLICT(event_key) DO NOTHING;
      v_delivery:='MISSING_RECIPIENT';
    END IF;
    IF v_person IS NOT NULL AND NOT EXISTS (
      SELECT 1 FROM ref.person p WHERE p.person_id=v_person
        AND nullif(btrim(p.email),'') IS NOT NULL
    ) THEN
      v_delivery:='MISSING_RECIPIENT';
    END IF;
  END IF;
  RETURN jsonb_build_object('ticket',v_ticket,'saved',true,'repeat',false,
                            'activity_id',v_event,'notifications',v_delivery);
END
$cmd$;
COMMIT;
-- Rollback procedure: restore the prior v1 command definition from migration
-- 001 under the governed maintenance process. Retain due_by and recorded dates;
-- never DROP the column or erase operator-entered deadlines as a rollback.
