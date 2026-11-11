-- #122/#205 Migration 081: task-scoped QC findings, no scheduled work.
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
    ('REPORTED','OBSERVATION','CLAIMED','REPAIRED','RETEST_PASS','RETEST_FAIL','INTAKE_LINK')),
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
        AND i.target_year=ss.season_year
    ) THEN
      RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Intake must belong to the same Setup season';
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
    IF v_action NOT IN ('OBSERVATION','CLAIM_REPAIR','REPAIRED','RETEST_PASS','RETEST_FAIL')
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
      IF v_status NOT IN ('OPEN','CLAIMED') THEN
        RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='Finding is not open for repair';
      END IF;
      UPDATE ops.setup_qc_finding SET status='AWAITING_RETEST',
        claimed_by_person_id=v_person,updated_at=clock_timestamp()
        WHERE qc_finding_id=p_finding;
    ELSIF v_action IN ('RETEST_PASS','RETEST_FAIL') THEN
      IF v_status<>'AWAITING_RETEST' THEN
        RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='Repair must await retest before verification';
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
        ELSE 'OBSERVATION' END,v_person,v_note);
  END IF;
  RETURN jsonb_build_object('action',v_action,'finding_id',p_finding,'person_id',v_person);
END
$function$;
REVOKE ALL ON FUNCTION ops.setup_qc_command(text,text,bigint,bigint,text,text,text,text,integer)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.setup_qc_command(text,text,bigint,bigint,text,text,text,text,integer)
  TO fieldwiring_app;
COMMIT;
