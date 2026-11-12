-- #122/#205 Migration 081: task-scoped QC findings, no scheduled work.
-- Purpose: persist annual QC findings and audited repair/retest evidence.
-- Scope: supplemental QC objects/functions only; no Intake, Work Order,
-- scheduling, ordinary work-report, or annual completion writes.
-- Candidate only: disposable current-Production clone before any release.
BEGIN;
DO $preflight$
BEGIN
  IF to_regclass('ops.setup_session_task') IS NULL OR
     to_regclass('ops.setup_session') IS NULL OR
     to_regclass('ref.person') IS NULL OR
     to_regclass('stage.work_order_intake') IS NULL OR
     to_regprocedure('ref.setup_execution_actor(text,bigint)') IS NULL THEN
    RAISE EXCEPTION 'QC 081 requires the installed Setup, People and Intake contracts';
  END IF;
END
$preflight$;

CREATE TABLE IF NOT EXISTS ops.setup_qc_auditor (
  setup_session_task_id bigint NOT NULL REFERENCES ops.setup_session_task(setup_session_task_id),
  person_id integer NOT NULL REFERENCES ref.person(person_id),
  claimed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  PRIMARY KEY (setup_session_task_id,person_id)
);
CREATE TABLE IF NOT EXISTS ops.setup_qc_finding (
  qc_finding_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  setup_session_task_id bigint NOT NULL REFERENCES ops.setup_session_task(setup_session_task_id),
  title text NOT NULL CHECK (length(btrim(title)) BETWEEN 3 AND 200),
  location_detail text,
  discovery_phase text NOT NULL DEFAULT 'OTHER'
    CHECK (discovery_phase IN ('INSTALLATION','INITIAL_POWER','FINAL_TEST','OTHER')),
  status text NOT NULL DEFAULT 'OPEN'
    CHECK (status IN ('OPEN','CLAIMED','AWAITING_RETEST','VERIFIED')),
  claimed_by_person_id integer REFERENCES ref.person(person_id),
  created_by_person_id integer NOT NULL REFERENCES ref.person(person_id),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS setup_qc_finding_task_idx
  ON ops.setup_qc_finding(setup_session_task_id,qc_finding_id);
CREATE INDEX IF NOT EXISTS setup_qc_finding_open_idx
  ON ops.setup_qc_finding(status,setup_session_task_id);
CREATE TABLE IF NOT EXISTS ops.setup_qc_event (
  qc_event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  qc_finding_id bigint NOT NULL REFERENCES ops.setup_qc_finding(qc_finding_id),
  event_type text NOT NULL CHECK (event_type IN
    ('REPORTED','OBSERVATION','CLAIMED','REPAIRED','RETEST_PASS','RETEST_FAIL','REOPEN','INTAKE_LINK')),
  person_id integer NOT NULL REFERENCES ref.person(person_id),
  note text NOT NULL CHECK (length(btrim(note)) BETWEEN 1 AND 6000),
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS setup_qc_event_finding_idx
  ON ops.setup_qc_event(qc_finding_id,created_at,qc_event_id);
CREATE TABLE IF NOT EXISTS ops.setup_qc_intake_link (
  intake_id integer NOT NULL REFERENCES stage.work_order_intake(intake_id),
  qc_finding_id bigint NOT NULL REFERENCES ops.setup_qc_finding(qc_finding_id),
  linked_by_person_id integer NOT NULL REFERENCES ref.person(person_id),
  linked_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  rationale text NOT NULL CHECK (length(btrim(rationale)) BETWEEN 3 AND 2000),
  PRIMARY KEY (intake_id,qc_finding_id)
);
-- No direct application writes: only SECURITY DEFINER function.
REVOKE ALL ON ops.setup_qc_auditor,ops.setup_qc_finding,
  ops.setup_qc_event,ops.setup_qc_intake_link FROM PUBLIC,fieldwiring_app;
REVOKE ALL ON SEQUENCE ops.setup_qc_finding_qc_finding_id_seq,
  ops.setup_qc_event_qc_event_id_seq FROM PUBLIC,fieldwiring_app;

CREATE FUNCTION ops.setup_qc_command(
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
    FOR SHARE;
  IF NOT FOUND OR v_reusable IS NULL OR
     v_task_name !~* 'plug[[:space:]]+in[[:space:]]+network[[:space:]]+to[[:space:]]+controller.*2[[:space:]]+minute[[:space:]]+test[[:space:]]+show'
  THEN
    RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Exact final QC annual task is required';
  END IF;
  SELECT a.person_id,a.can_manage_setup INTO v_person,v_manager
    FROM ref.setup_execution_actor(p_email,v_reusable) a;
  IF v_person IS NULL THEN
    RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Authenticated Production Crew identity required';
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
      -- A repair must be made by the worker who explicitly claimed this
      -- exact finding. Never silently claim or overwrite another technician.
      IF v_status<>'CLAIMED' OR NOT EXISTS (
        SELECT 1 FROM ops.setup_qc_finding WHERE qc_finding_id=p_finding
          AND claimed_by_person_id=v_person
      ) THEN
        RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='Claim this QC finding before marking your repair complete';
      END IF;
      UPDATE ops.setup_qc_finding SET status='AWAITING_RETEST',
        updated_at=clock_timestamp() WHERE qc_finding_id=p_finding;
    ELSIF v_action='REOPEN' THEN
      IF v_status<>'VERIFIED' THEN
        RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='Only a previously verified finding may be reopened';
      END IF;
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
REVOKE ALL ON FUNCTION ops.setup_qc_command(text,text,bigint,bigint,text,text,text,text,integer)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.setup_qc_command(text,text,bigint,bigint,text,text,text,text,integer)
  TO fieldwiring_app;

-- Views are narrowly exposed by authenticated functions; the application
-- role has NO direct SELECT privileges on QC/Intake tables.
CREATE FUNCTION ops.setup_qc_snapshot(p_email text,p_year integer)
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
REVOKE ALL ON FUNCTION ops.setup_qc_snapshot(text,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.setup_qc_snapshot(text,integer) TO fieldwiring_app;

CREATE FUNCTION ops.setup_qc_intake_candidates(p_email text,p_year integer)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,ops,ref,stage
AS $function$
DECLARE v_result jsonb;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM ref.setup_browser_capabilities(p_email) c
      WHERE c.can_manage_setup) THEN
    RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='Only Setup Managers can review Intake';
  END IF;
  SELECT coalesce(jsonb_agg(row_to_json(rows)::jsonb ORDER BY rows.intake_id DESC),'[]'::jsonb)
    INTO v_result
  FROM (
    SELECT i.intake_id,i.problem_raw,i.notes_raw,i.stage_id,
      s.stage_name,s.stage_key,i.submitter_name_raw,
      (to_jsonb(i)->>'photo_url_raw') AS photo_url_raw,
      i.source_form_name,i.updated_at,
      coalesce((
        SELECT jsonb_agg(l.qc_finding_id ORDER BY l.qc_finding_id)
        FROM ops.setup_qc_intake_link l WHERE l.intake_id=i.intake_id
      ),'[]'::jsonb) AS linked_findings
    FROM stage.work_order_intake i
    LEFT JOIN ref.stage s ON s.stage_id=i.stage_id
    WHERE (i.target_year=p_year OR
        (i.target_year IS NULL AND extract(year FROM i.updated_at AT TIME ZONE
          'America/Chicago')::integer=p_year))
      AND NOT EXISTS (
        SELECT 1 FROM ops.work_order w WHERE w.source_intake_id=i.intake_id)
    ORDER BY i.intake_id DESC LIMIT 300
  ) rows;
  RETURN v_result;
END
$function$;
REVOKE ALL ON FUNCTION ops.setup_qc_intake_candidates(text,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.setup_qc_intake_candidates(text,integer) TO fieldwiring_app;

COMMIT;
