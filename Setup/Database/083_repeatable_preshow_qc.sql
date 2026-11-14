-- #122/#205: repeatable pre-show QC; no existing task/finding identity changes.
BEGIN;
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='60s';
-- Current signoff remains compatible with existing readers. Superseded evidence
-- is copied intact before removing only the current-readiness marker.
CREATE TABLE ops.setup_qc_signoff_history (
 history_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 setup_session_task_id bigint NOT NULL REFERENCES ops.setup_session_task(setup_session_task_id),
 evidence jsonb NOT NULL,
 invalidated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 invalidated_by_person_id integer NOT NULL REFERENCES ref.person(person_id),
 reason text NOT NULL
);
REVOKE ALL ON ops.setup_qc_signoff_history FROM PUBLIC,fieldwiring_app;
CREATE OR REPLACE FUNCTION ops.setup_qc_invalidate_signoff(p_task bigint,p_actor integer,p_reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ops AS $invalidate$
BEGIN
 -- Caller already holds this lock; retain the helper's invariant independently.
 PERFORM 1 FROM ops.setup_session_task WHERE setup_session_task_id=p_task FOR UPDATE;
 INSERT INTO ops.setup_qc_signoff_history(setup_session_task_id,evidence,invalidated_by_person_id,reason)
 SELECT p_task,to_jsonb(q),p_actor,p_reason FROM ops.setup_qc_signoff q WHERE setup_session_task_id=p_task;
 IF FOUND THEN
   DELETE FROM ops.setup_qc_signoff WHERE setup_session_task_id=p_task;
   UPDATE ops.setup_session_task SET execution_status='IN_PROGRESS',
     actual_completed_at=NULL,completed_by_person_id=NULL,completion_note=NULL
   WHERE setup_session_task_id=p_task;
 END IF;
END
$invalidate$;
REVOKE ALL ON FUNCTION ops.setup_qc_invalidate_signoff(bigint,integer,text) FROM PUBLIC,fieldwiring_app;
-- Reuse existing Show Animation final tests; wiring tasks are not final QC.
CREATE OR REPLACE FUNCTION ops.setup_qc_is_final_task(p_task bigint)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=pg_catalog,ops,ref
AS $eligible$
SELECT EXISTS (
  SELECT 1 FROM ops.setup_session_task t
  LEFT JOIN ref.stage s ON s.stage_id=t.annual_stage_id
  WHERE t.setup_session_task_id=p_task AND t.included_flag
    AND (t.annual_task_name ~* '(plug[[:space:]]+in[[:space:]]+network[[:space:]]+to[[:space:]]+controller.*2[[:space:]]+minute[[:space:]]+test[[:space:]]+show|^QC Check - Verify Stage/Scene sequence lights during the 2 minute test sequence$)'
      OR (s.stage_name ~* '^Show[[:space:]]+Animation([[:space:]]|$)'
        AND btrim(t.annual_task_name) ~* '^Plug[[:space:]]+in[[:space:]]+Network[[:space:]]*&[[:space:]]*Test$'))
);
$eligible$;
REVOKE ALL ON FUNCTION ops.setup_qc_is_final_task(bigint) FROM PUBLIC,fieldwiring_app;

CREATE OR REPLACE FUNCTION ops.setup_qc_command(
  p_email text, p_action text, p_annual_task bigint,
  p_finding bigint DEFAULT NULL, p_note text DEFAULT NULL,
  p_title text DEFAULT NULL, p_phase text DEFAULT NULL,
  p_location text DEFAULT NULL, p_intake_id integer DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog,ops,ref,stage
AS $function$
DECLARE
  v_reusable bigint;
  v_task_name text;
  v_person integer;
  v_manager boolean;
  v_status text;
  v_finding_task bigint;
  v_id bigint;
  v_line record;
  v_ids jsonb := '[]'::jsonb;
  v_note text := nullif(btrim(p_note),'');
  v_action text := upper(btrim(p_action));
BEGIN
  -- Lock annual identity; never create work-day or scheduling rows.
  SELECT t.setup_task_id,t.annual_task_name
    INTO v_reusable,v_task_name
    FROM ops.setup_session_task t
    WHERE t.setup_session_task_id=p_annual_task AND t.included_flag
    FOR UPDATE;
  IF NOT FOUND OR v_reusable IS NULL OR
     NOT ops.setup_qc_is_final_task(p_annual_task)
  THEN
    RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Exact final QC annual task is required';
  END IF;
  SELECT a.person_id,a.can_manage_setup INTO v_person,v_manager
    FROM ref.setup_execution_actor(p_email,v_reusable) a;
  IF v_person IS NULL THEN
    RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authenticated Production Crew identity required';
  END IF;
  -- Serialize every QC change with final signoff on the annual row.
  -- Reporting can reopen pre-show QC. Other mutations cannot alter a green area.
  IF v_action NOT IN ('REPORT','REPORT_LINES','REOPEN','OBSERVATION','CLAIM_AUDIT')
     AND EXISTS (SELECT 1 FROM ops.setup_qc_signoff WHERE setup_session_task_id=p_annual_task) THEN
    RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='Report a new problem or reopen the failed finding before recording a repair';
  END IF;
  IF v_action='REPORT_LINES' THEN
    -- One transaction saves one finding per nonblank line in input order.
    -- Reuse REPORT authorization and persistence; never create Intake or work.
    IF v_note IS NULL OR length(v_note)>6000 THEN
      RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Enter problems (1-6000 characters), one per line';
    END IF;
    FOR v_line IN
      SELECT btrim(value, E' \t\r') AS problem, ordinal
      FROM string_to_table(v_note,E'\n') WITH ORDINALITY AS lines(value,ordinal)
      WHERE btrim(value,E' \t\r')<>'' ORDER BY ordinal
    LOOP
      IF length(v_line.problem)<3 THEN
        RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Each problem must contain at least 3 characters; nothing saved';
      END IF;
      SELECT (ops.setup_qc_command(p_email,'REPORT',p_annual_task,NULL,
        v_line.problem,left(v_line.problem,200),'OTHER',NULL,NULL)->>'finding_id')::bigint
        INTO v_id;
      v_ids := v_ids || jsonb_build_array(v_id);
    END LOOP;
    IF jsonb_array_length(v_ids)=0 THEN
      RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Enter at least one problem';
    END IF;
    RETURN jsonb_build_object('action',v_action,'finding_ids',v_ids);
  END IF;
  IF v_action='CLAIM_AUDIT' THEN
    INSERT INTO ops.setup_qc_auditor(setup_session_task_id,person_id)
    VALUES(p_annual_task,v_person)
    ON CONFLICT DO NOTHING;
    RETURN jsonb_build_object('action',v_action,'task_id',p_annual_task,'person_id',v_person);
  ELSIF v_action='REPORT' THEN
    IF length(btrim(coalesce(p_title,''))) NOT BETWEEN 3 AND 200
       OR v_note IS NULL OR length(v_note)>6000
       OR coalesce(p_phase,'OTHER') NOT IN ('INSTALLATION','INITIAL_POWER','FINAL_TEST','OTHER')
       OR length(coalesce(p_location,''))>500 THEN
      RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Finding requires title (3-200) and description (1-6000)';
    END IF;
    PERFORM ops.setup_qc_invalidate_signoff(p_annual_task,v_person,v_note);
    INSERT INTO ops.setup_qc_finding(
      setup_session_task_id,title,location_detail,discovery_phase,created_by_person_id)
      VALUES(p_annual_task,btrim(p_title),nullif(btrim(p_location),''),
        coalesce(p_phase,'OTHER'),v_person)
      RETURNING qc_finding_id INTO v_id;
    INSERT INTO ops.setup_qc_event(qc_finding_id,event_type,person_id,note)
      VALUES(v_id,'REPORTED',v_person,v_note);
    RETURN jsonb_build_object('action',v_action,'finding_id',v_id);
  END IF;
  IF p_finding IS NULL THEN
    RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Existing QC finding ID is required';
  END IF;
  SELECT f.setup_session_task_id,f.status INTO v_finding_task,v_status
    FROM ops.setup_qc_finding f WHERE f.qc_finding_id=p_finding FOR UPDATE;
  IF NOT FOUND OR v_finding_task<>p_annual_task THEN
    RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Finding is not attached to this exact QC task';
  END IF;
  IF v_action='LINK_INTAKE' THEN
    IF NOT v_manager OR p_intake_id IS NULL OR v_note IS NULL
       OR length(v_note)>2000 THEN
      RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Manager-reviewed Intake link and rationale required';
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM stage.work_order_intake i
      JOIN ops.setup_session_task t ON t.setup_session_task_id=p_annual_task
      JOIN ops.setup_session ss ON ss.setup_session_id=t.setup_session_id
      WHERE i.intake_id=p_intake_id
        -- Missing historical classification is not a contradictory Stage.
        -- Manager chooses the exact task and records the required rationale;
        -- populated conflicting Stages still fail, and source stays untouched.
        AND (i.stage_id IS NULL OR i.stage_id=t.annual_stage_id)
        AND (i.target_year=ss.season_year OR
          (i.target_year IS NULL AND extract(year FROM i.updated_at
            AT TIME ZONE 'America/Chicago')::integer=ss.season_year))
    ) THEN
      RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Intake must match the Setup season and have no conflicting assigned Stage';
    END IF;
    IF EXISTS (SELECT 1 FROM ops.work_order w WHERE w.source_intake_id=p_intake_id) THEN
      RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='Promoted Work Order Intake cannot become a QC repair duplicate';
    END IF;
    -- Intake remains intact; never duplicate its original message as a new WO.
    INSERT INTO ops.setup_qc_intake_link(intake_id,qc_finding_id,linked_by_person_id,rationale)
      VALUES(p_intake_id,p_finding,v_person,v_note)
      ON CONFLICT DO NOTHING;
    IF FOUND THEN
      INSERT INTO ops.setup_qc_event(qc_finding_id,event_type,person_id,note)
        VALUES(p_finding,'INTAKE_LINK',v_person,'INTAKE-'||p_intake_id||': '||v_note);
    END IF;
  ELSE
    -- Claim records intent, not performed work; create its audit note here.
    -- Repair, retest and observation still require the operator's evidence.
    IF v_action='CLAIM_REPAIR' AND v_note IS NULL THEN
      v_note := 'Claimed repair';
    END IF;
    IF v_action NOT IN ('OBSERVATION','CLAIM_REPAIR','REPAIRED','RETEST_PASS','RETEST_FAIL','REOPEN')
       OR v_note IS NULL OR length(v_note)>6000 THEN
      RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Known QC action and note (1-6000) required';
    END IF;
    IF v_action='CLAIM_REPAIR' THEN
      IF v_status NOT IN ('OPEN','CLAIMED') THEN
        RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='Only open findings can be claimed';
      END IF;
      IF v_status='CLAIMED' AND NOT EXISTS (
        SELECT 1 FROM ops.setup_qc_finding WHERE qc_finding_id=p_finding
        AND claimed_by_person_id=v_person
      ) THEN
        RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='Repair already claimed by someone else';
      END IF;
      UPDATE ops.setup_qc_finding SET status='CLAIMED',
        claimed_by_person_id=v_person,updated_at=clock_timestamp()
        WHERE qc_finding_id=p_finding;
    ELSIF v_action='REPAIRED' THEN
      -- Claims record intent, not exclusive permission to complete a repair.
      -- Preserve the claimant; the REPAIRED event records the actual actor.
      IF v_status NOT IN ('OPEN','CLAIMED') THEN
        RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='Only an outstanding repair can be marked repaired';
      END IF;
      UPDATE ops.setup_qc_finding SET status='AWAITING_RETEST',
        updated_at=clock_timestamp() WHERE qc_finding_id=p_finding;
    ELSIF v_action='REOPEN' THEN
      IF v_status<>'VERIFIED' THEN
        RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='Only a previously verified finding may be reopened';
      END IF;
      PERFORM ops.setup_qc_invalidate_signoff(p_annual_task,v_person,v_note);
      UPDATE ops.setup_qc_finding SET status='OPEN',claimed_by_person_id=NULL,
        updated_at=clock_timestamp() WHERE qc_finding_id=p_finding;
    ELSIF v_action IN ('RETEST_PASS','RETEST_FAIL') THEN
      IF v_status<>'AWAITING_RETEST' THEN
        RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='Repair must await retest before verification';
      END IF;
      -- Field verification is an auditor action, not a worker repair toggle.
      IF NOT EXISTS (
        SELECT 1 FROM ops.setup_qc_auditor a
        WHERE a.setup_session_task_id=p_annual_task AND a.person_id=v_person
      ) THEN
        RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Claim this annual QC task as auditor before recording retest';
      END IF;
      -- Retest cannot be self-certification of final annual QC completion.
      UPDATE ops.setup_qc_finding
        SET status=CASE WHEN v_action='RETEST_PASS' THEN 'VERIFIED' ELSE 'OPEN' END,
            claimed_by_person_id=NULL,updated_at=clock_timestamp()
        WHERE qc_finding_id=p_finding;
    END IF;
    INSERT INTO ops.setup_qc_event(qc_finding_id,event_type,person_id,note)
      VALUES(p_finding,CASE v_action WHEN 'CLAIM_REPAIR' THEN 'CLAIMED'
        WHEN 'REPAIRED' THEN 'REPAIRED'
        WHEN 'RETEST_PASS' THEN 'RETEST_PASS'
        WHEN 'RETEST_FAIL' THEN 'RETEST_FAIL'
        WHEN 'REOPEN' THEN 'REOPEN'
        ELSE 'OBSERVATION' END,v_person,v_note);
  END IF;
  RETURN jsonb_build_object('action',v_action,'finding_id',p_finding,'person_id',v_person);
END
$function$;

CREATE OR REPLACE FUNCTION ops.setup_qc_final_gate(p_task bigint)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=pg_catalog,ops,ref
AS $gate$
WITH target AS (
  SELECT * FROM ops.setup_session_task WHERE setup_session_task_id=p_task
), required AS (
  SELECT pst.setup_session_task_id AS id
  FROM target t JOIN ref.setup_task_dependency rd ON rd.setup_task_id=t.setup_task_id
  LEFT JOIN ops.setup_session_task pst ON pst.setup_session_id=t.setup_session_id
    AND pst.setup_task_id=rd.prerequisite_setup_task_id
  WHERE t.task_origin='REUSABLE'
  UNION
  SELECT ad.prerequisite_setup_session_task_id
  FROM target t JOIN ops.setup_session_task_dependency ad ON ad.setup_session_task_id=p_task
  LEFT JOIN ops.setup_session_task pst ON pst.setup_session_task_id=ad.prerequisite_setup_session_task_id
  WHERE t.task_origin='SEASON_ONLY' OR (ad.dependency_origin='ANNUAL' AND NOT EXISTS (
    SELECT 1 FROM ref.setup_task_dependency rd WHERE rd.setup_task_id=t.setup_task_id
      AND rd.prerequisite_setup_task_id=pst.setup_task_id))
  UNION
  SELECT pst.setup_session_task_id FROM target t
  JOIN ops.setup_session_task pst ON pst.setup_session_id=t.setup_session_id
    AND pst.annual_stage_id IS NOT DISTINCT FROM t.annual_stage_id
  WHERE pst.included_flag AND pst.setup_session_task_id<>p_task
    AND (t.annual_lor_scene_id IS NULL OR pst.annual_lor_scene_id=t.annual_lor_scene_id)
), work AS (
  SELECT r.id,coalesce(pst.annual_task_name,'Missing annual prerequisite') AS name,
    CASE WHEN ops.setup_qc_is_final_task(pst.setup_session_task_id)
      THEN EXISTS (SELECT 1 FROM ops.setup_qc_signoff q WHERE q.setup_session_task_id=pst.setup_session_task_id)
      ELSE coalesce(pst.execution_status='COMPLETE' OR
        (pst.linked_work_order_gate AND wo.date_completed IS NOT NULL),false)
    END AS complete
  FROM required r LEFT JOIN ops.setup_session_task pst ON pst.setup_session_task_id=r.id
  LEFT JOIN ops.setup_scheduling_work_order_gate wo ON wo.work_order_id=pst.linked_work_order_id
)
SELECT jsonb_build_object(
  'task_id',p_task,
  'readiness_met',coalesce((SELECT annual_readiness_state='READY' FROM target),false),
  'required_work',coalesce((SELECT jsonb_agg(to_jsonb(w) ORDER BY w.id NULLS FIRST) FROM work w),'[]'::jsonb),
  'unfinished_work',coalesce((SELECT jsonb_agg(to_jsonb(w) ORDER BY w.id NULLS FIRST) FROM work w WHERE NOT complete),'[]'::jsonb),
  'unrepaired_findings',(SELECT count(*) FROM ops.setup_qc_finding f WHERE f.setup_session_task_id=p_task AND f.status IN ('OPEN','CLAIMED')),
  'unresolved_findings',(SELECT count(*) FROM ops.setup_qc_finding f WHERE f.setup_session_task_id=p_task AND f.status<>'VERIFIED')
);
$gate$;

CREATE OR REPLACE FUNCTION ops.setup_qc_ready_for_production(
  p_email text,p_task bigint,p_evidence text,p_test_seconds integer,p_sequence text
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,ops,ref
AS $final$
DECLARE v_task ops.setup_session_task%ROWTYPE; v_person integer; v_gate jsonb; v_at timestamptz;
BEGIN
  -- Freeze authoritative work/graph evidence during the short final transaction.
  -- Acquire table locks before row locks; all QC commands then serialize on task.
  LOCK TABLE ops.setup_session_task IN SHARE ROW EXCLUSIVE MODE;
  LOCK TABLE ref.setup_task_dependency,ops.setup_session_task_dependency,ops.work_order IN SHARE MODE;
  SELECT * INTO v_task FROM ops.setup_session_task WHERE setup_session_task_id=p_task FOR UPDATE;
  IF NOT FOUND OR NOT v_task.included_flag OR NOT ops.setup_qc_is_final_task(p_task) THEN
    RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Exact final QC annual task required';
  END IF;
  SELECT person_id INTO v_person FROM ref.setup_execution_actor(p_email,v_task.setup_task_id);
  IF v_person IS NULL OR NOT EXISTS (SELECT 1 FROM ops.setup_qc_auditor
    WHERE setup_session_task_id=p_task AND person_id=v_person) THEN
    RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Only an auditor who claimed this QC task may sign off';
  END IF;
  IF EXISTS (SELECT 1 FROM ops.setup_qc_signoff WHERE setup_session_task_id=p_task) THEN
    RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='Already Ready for Production; report any new problem in QC Check';
  END IF;
  IF p_test_seconds IS NULL OR p_test_seconds<120
    OR length(btrim(coalesce(p_evidence,''))) NOT BETWEEN 3 AND 6000
    OR length(btrim(coalesce(p_sequence,''))) NOT BETWEEN 3 AND 500 THEN
    RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Record the actual two-minute test, sequence reference and observed result';
  END IF;
  v_gate := ops.setup_qc_final_gate(p_task);
  IF NOT (v_gate->>'readiness_met')::boolean OR jsonb_array_length(v_gate->'unfinished_work')>0
    OR (v_gate->>'unrepaired_findings')::integer>0 THEN
    RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='Signoff blocked: required work and readiness must be complete; every problem must be repaired';
  END IF;
  v_at := clock_timestamp();
  -- One area observation verifies repaired findings atomically with final signoff.
  -- Never close an OPEN/CLAIMED defect; the locked gate above rejects those.
  INSERT INTO ops.setup_qc_event(qc_finding_id,event_type,person_id,note,created_at)
    SELECT qc_finding_id,'RETEST_PASS',v_person,btrim(p_evidence),v_at
    FROM ops.setup_qc_finding WHERE setup_session_task_id=p_task AND status='AWAITING_RETEST'
    ORDER BY qc_finding_id;
  UPDATE ops.setup_qc_finding SET status='VERIFIED',updated_at=v_at
    WHERE setup_session_task_id=p_task AND status='AWAITING_RETEST';
  INSERT INTO ops.setup_qc_signoff(setup_session_task_id,auditor_person_id,signed_at,
    test_seconds,sequence_reference,test_evidence,required_work_evidence)
  VALUES(p_task,v_person,v_at,p_test_seconds,btrim(p_sequence),btrim(p_evidence),v_gate);
  UPDATE ops.setup_session_task SET execution_status='COMPLETE',actual_completed_at=v_at,
    completed_by_person_id=v_person,completion_note='QC Ready for Production: '||btrim(p_evidence)
    WHERE setup_session_task_id=p_task;
  RETURN jsonb_build_object('task_id',p_task,'status','READY_FOR_PRODUCTION','signed_at',v_at,'auditor_person_id',v_person);
END
$final$;

CREATE OR REPLACE FUNCTION ops.setup_qc_snapshot(p_email text,p_year integer)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = pg_catalog,ops,ref
AS $function$
DECLARE v_result jsonb;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM ref.setup_browser_capabilities(p_email) c
      WHERE c.can_read_setup) THEN
    RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='QC read requires authenticated Setup access';
  END IF;
  SELECT jsonb_build_object(
    'viewer_person_id',(SELECT p.person_id FROM ref.person p
      JOIN public.directus_users u ON u.id=p.directus_user_id
      WHERE lower(u.email)=lower(btrim(p_email)) AND u.status='active' ORDER BY p.person_id LIMIT 1),
    'signoff_history',coalesce((SELECT jsonb_agg(to_jsonb(h) ORDER BY h.invalidated_at,h.history_id)
      FROM ops.setup_qc_signoff_history h JOIN ops.setup_session_task t USING(setup_session_task_id)
      JOIN ops.setup_session ss USING(setup_session_id) WHERE ss.season_year=p_year),'[]'::jsonb),
    'signoffs',coalesce((SELECT jsonb_agg(to_jsonb(q) ORDER BY q.setup_session_task_id)
      FROM ops.setup_qc_signoff q JOIN ops.setup_session_task t USING(setup_session_task_id)
      JOIN ops.setup_session ss USING(setup_session_id) WHERE ss.season_year=p_year),'[]'::jsonb),
    'final_gates',coalesce((SELECT jsonb_agg(ops.setup_qc_final_gate(t.setup_session_task_id) ORDER BY t.setup_session_task_id)
      FROM ops.setup_session_task t JOIN ops.setup_session ss USING(setup_session_id)
      WHERE ss.season_year=p_year AND t.included_flag AND ops.setup_qc_is_final_task(t.setup_session_task_id)),'[]'::jsonb),
    'findings',coalesce((
      SELECT jsonb_agg(row_to_json(rows)::jsonb ORDER BY rows.stage_key,rows.qc_finding_id)
      FROM (
        SELECT f.qc_finding_id,f.setup_session_task_id,f.title,f.location_detail,
          f.discovery_phase,f.status,f.created_at,f.updated_at,
          f.created_by_person_id,f.claimed_by_person_id,
          coalesce(nullif(btrim(concat_ws(' ',cp.first_name,cp.last_name)),''),cp.email) AS reporter,
          coalesce(nullif(btrim(concat_ws(' ',rp.first_name,rp.last_name)),''),rp.email) AS repair_owner,
          t.annual_task_name AS task_name,s.stage_key,s.stage_name,ls.scene_name,
          coalesce((
            SELECT jsonb_agg(jsonb_build_object(
              'id',e.qc_event_id,'type',e.event_type,'note',e.note,
              'person_id',e.person_id,'at',e.created_at,
              'person',coalesce(nullif(btrim(concat_ws(' ',p.first_name,p.last_name)),''),p.email))
              ORDER BY e.created_at,e.qc_event_id)
            FROM ops.setup_qc_event e
            LEFT JOIN ref.person p ON p.person_id=e.person_id
            WHERE e.qc_finding_id=f.qc_finding_id
          ),'[]'::jsonb) AS events,
          coalesce((
            SELECT jsonb_agg(l.intake_id ORDER BY l.intake_id)
            FROM ops.setup_qc_intake_link l
            WHERE l.qc_finding_id=f.qc_finding_id
          ),'[]'::jsonb) AS linked_intake_ids,
          -- Crew repairing a finding must see its actual historical source,
          -- not just an Intake number. Never mutate original Intake rows.
          coalesce((
            SELECT jsonb_agg(jsonb_build_object(
              'intake_id',i.intake_id,'submitter_name_raw',i.submitter_name_raw,
              'problem_raw',i.problem_raw,'notes_raw',i.notes_raw,
              'updated_at',i.updated_at,
              'photo_url_raw',to_jsonb(i)->>'photo_url_raw')
              ORDER BY i.intake_id)
            FROM ops.setup_qc_intake_link l
            JOIN stage.work_order_intake i ON i.intake_id=l.intake_id
            WHERE l.qc_finding_id=f.qc_finding_id
          ),'[]'::jsonb) AS linked_intake_records
        FROM ops.setup_qc_finding f
        JOIN ops.setup_session_task t ON t.setup_session_task_id=f.setup_session_task_id
        JOIN ops.setup_session ss ON ss.setup_session_id=t.setup_session_id
        LEFT JOIN ref.stage s ON s.stage_id=t.annual_stage_id
        LEFT JOIN ref.lor_scene ls ON ls.lor_scene_id=t.annual_lor_scene_id
        LEFT JOIN ref.person cp ON cp.person_id=f.created_by_person_id
        LEFT JOIN ref.person rp ON rp.person_id=f.claimed_by_person_id
        WHERE ss.season_year=p_year
      ) rows
    ),'[]'::jsonb),
    'auditors',coalesce((
      SELECT jsonb_agg(jsonb_build_object(
          'setup_session_task_id',a.setup_session_task_id,'person_id',a.person_id,
          'claimed_at',a.claimed_at,
          'auditor',coalesce(nullif(btrim(concat_ws(' ',p.first_name,p.last_name)),''),p.email))
          ORDER BY a.setup_session_task_id,a.claimed_at,a.person_id)
      FROM ops.setup_qc_auditor a
      JOIN ops.setup_session_task t ON t.setup_session_task_id=a.setup_session_task_id
      JOIN ops.setup_session ss ON ss.setup_session_id=t.setup_session_id
      JOIN ref.person p ON p.person_id=a.person_id
      WHERE ss.season_year=p_year
    ),'[]'::jsonb),
    -- Unclassified legacy reports are not area findings. Manual cleanup is separate.
    'unreconciled_intake','[]'::jsonb
  ) INTO v_result;
  RETURN v_result;
END
$function$;
COMMIT;
