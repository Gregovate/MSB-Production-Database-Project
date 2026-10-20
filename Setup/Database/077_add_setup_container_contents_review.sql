-- #88 Manager contents review. Movement/location truth remains in the existing
-- event/effect/state model; this append-only ledger records review dispositions.
BEGIN;
CREATE TABLE ops.setup_container_review_event (
    setup_container_review_event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    setup_session_id bigint NOT NULL REFERENCES ops.setup_session,
    container_id integer NOT NULL REFERENCES ref.container,
    client_event_id uuid NOT NULL UNIQUE,
    action text NOT NULL CHECK (action IN ('NEEDS_FIELD_CHECK','CONFIRM','LOCATION','PRIOR_PARK','ATTACH')),
    display_ids bigint[] NOT NULL,
    flag_ids bigint[] NOT NULL,
    resolved_flag_ids bigint[] NOT NULL,
    evidence text NOT NULL CHECK (length(btrim(evidence)) >= 5),
    observed_at timestamptz NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    reviewer_email text NOT NULL,
    reviewer_person_id integer NOT NULL REFERENCES ref.person,
    snapshot jsonb NOT NULL,
    request jsonb NOT NULL,
    movement_event_ids bigint[] NOT NULL DEFAULT '{}'
);
CREATE INDEX ON ops.setup_container_review_event(setup_session_id,container_id,setup_container_review_event_id);
REVOKE ALL ON ops.setup_container_review_event FROM PUBLIC, fieldwiring_app;
GRANT SELECT ON ops.setup_container_review_event TO fieldwiring_app;

CREATE FUNCTION ops.setup_container_review_snapshot(p_session bigint,p_container integer)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=pg_catalog,ops,ref AS $fn$
 SELECT jsonb_build_object(
  'container',to_jsonb(c), 'state',to_jsonb(cs),
  'displays',coalesce((SELECT jsonb_agg(jsonb_build_object(
    'display_id',d.display_id,'display_name',d.display_name,
    'position_mode',coalesce(ds.position_mode,'WITH_CONTAINER'),
    'state',to_jsonb(ds)) ORDER BY d.display_id)
   FROM ref.display d JOIN ref.display_status st USING(display_status_id)
   LEFT JOIN ops.setup_display_state ds ON ds.setup_session_id=p_session AND ds.display_id=d.display_id
   WHERE d.container_id=p_container AND upper(st.display_status_name)='ACTIVE'),'[]'::jsonb),
  'movement_watermark',(SELECT coalesce(max(e.setup_movement_event_id),0) FROM ops.setup_movement_event e
    WHERE e.setup_session_id=p_session AND (e.container_id=p_container OR EXISTS(
      SELECT 1 FROM ops.setup_movement_event_display med JOIN ref.display d USING(display_id)
      WHERE med.setup_movement_event_id=e.setup_movement_event_id AND d.container_id=p_container))),
  'review_watermark',(SELECT coalesce(max(r.setup_container_review_event_id),0)
    FROM ops.setup_container_review_event r WHERE r.setup_session_id=p_session AND r.container_id=p_container))
 FROM (SELECT c.container_id,c.container_type_id,ct.container_type_name,c.location_code,c.description
       FROM ref.container c JOIN ref.container_type ct USING(container_type_id) WHERE c.container_id=p_container) c
 LEFT JOIN ops.setup_container_state cs ON cs.setup_session_id=p_session AND cs.container_id=c.container_id;
$fn$;
REVOKE ALL ON FUNCTION ops.setup_container_review_snapshot(bigint,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.setup_container_review_snapshot(bigint,integer) TO fieldwiring_app;

CREATE FUNCTION ops.review_setup_container_contents(
 p_email text,p_season_year integer,p_container integer,p_client_event_id uuid,
 p_expected jsonb,p_request jsonb)
RETURNS ops.setup_container_review_event LANGUAGE plpgsql SECURITY DEFINER
SET search_path=pg_catalog,ops,ref AS $fn$
DECLARE
 v_person integer; v_user uuid; v_session bigint; v_snapshot jsonb; v_existing ops.setup_container_review_event;
 v_action text := p_request->>'action'; v_ids bigint[]; v_flags bigint[]; v_close bigint[];
 v_all bigint[]; v_accounted bigint[]; v_scope bigint[]; v_flag bigint; v_json jsonb;
 v_protected boolean; v_return ops.setup_movement_event; v_prior ops.setup_movement_event;
 v_cs ops.setup_container_state; v_ds ops.setup_display_state; v_id bigint; v_event bigint;
 v_events bigint[] := '{}'; v_now timestamptz := clock_timestamp(); v_observed timestamptz;
 v_evidence text := btrim(p_request->>'evidence'); v_stage integer; v_note text; v_notes text;
BEGIN
 -- Recheck Manager authority in PostgreSQL, independent of browser/API controls.
 SELECT a.person_id,a.directus_user_id INTO v_person,v_user FROM ref.setup_management_actor(p_email,false) a;
 SELECT ss.setup_session_id INTO v_session FROM ops.setup_session ss
 WHERE ss.season_year=p_season_year AND ss.session_status NOT IN ('COMPLETE','HISTORICAL_VERIFICATION');
 IF v_session IS NULL THEN RAISE EXCEPTION 'Open Setup Session required' USING ERRCODE='P0002'; END IF;
 PERFORM 1 FROM ref.container c WHERE c.container_id=p_container FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Container not found' USING ERRCODE='P0002'; END IF;
 SELECT * INTO v_existing FROM ops.setup_container_review_event r WHERE r.client_event_id=p_client_event_id;
 IF FOUND THEN
  IF v_existing.setup_session_id<>v_session OR v_existing.container_id<>p_container
     OR v_existing.request IS DISTINCT FROM p_request OR v_existing.snapshot IS DISTINCT FROM p_expected
     OR v_existing.reviewer_email<>lower(btrim(p_email)) THEN
   RAISE EXCEPTION 'Review request identity already used for different evidence' USING ERRCODE='23505';
  END IF;
  RETURN v_existing;
 END IF;
 IF p_client_event_id IS NULL OR jsonb_typeof(p_request) IS DISTINCT FROM 'object'
    OR v_action IS NULL OR v_action NOT IN ('NEEDS_FIELD_CHECK','CONFIRM','LOCATION','PRIOR_PARK','ATTACH')
    OR length(coalesce(v_evidence,''))<5 THEN
  RAISE EXCEPTION 'Review action and evidence/source are required' USING ERRCODE='22023';
 END IF;
 v_observed := (p_request->>'observed_at')::timestamptz;
 IF v_observed IS NULL OR v_observed>v_now+interval '5 minutes' THEN
  RAISE EXCEPTION 'Evidence observation time must be supplied and cannot be in the future' USING ERRCODE='22023';
 END IF;
 -- Same parent lock as #88 movement/reconciliation, plus permanent membership.
 PERFORM 1 FROM ref.display d WHERE d.container_id=p_container ORDER BY d.display_id FOR UPDATE;
 PERFORM 1 FROM ops.setup_display_state ds JOIN ref.display d USING(display_id)
 WHERE ds.setup_session_id=v_session AND d.container_id=p_container FOR UPDATE OF ds;
 v_snapshot := ops.setup_container_review_snapshot(v_session,p_container);
 IF p_expected IS DISTINCT FROM v_snapshot THEN
  RAISE EXCEPTION 'Container or Display evidence changed. Refresh and review again.' USING ERRCODE='40001';
 END IF;
 SELECT coalesce(array_agg(DISTINCT x::bigint ORDER BY x::bigint),'{}') INTO v_ids
 FROM jsonb_array_elements_text(p_request->'display_ids') x;
 SELECT coalesce(array_agg(DISTINCT x::bigint ORDER BY x::bigint),'{}') INTO v_flags
 FROM jsonb_array_elements_text(p_request->'flag_ids') x;
 SELECT coalesce(array_agg(DISTINCT x::bigint ORDER BY x::bigint),'{}') INTO v_close
 FROM jsonb_array_elements_text(p_request->'resolve_flag_ids') x;
 SELECT coalesce(array_agg((x->>'display_id')::bigint ORDER BY (x->>'display_id')::bigint),'{}') INTO v_all
 FROM jsonb_array_elements(v_snapshot->'displays') x;
 IF NOT(v_ids<@v_all) OR NOT(v_close<@v_flags) THEN
  RAISE EXCEPTION 'Review selection is outside this Container or review scope' USING ERRCODE='23514';
 END IF;
 IF v_action<>'NEEDS_FIELD_CHECK' AND cardinality(v_ids)=0 AND NOT(v_action='CONFIRM' AND cardinality(v_all)=0 AND p_request->>'whole_case_confirmed'='true') THEN
  RAISE EXCEPTION 'Select the Display Names reviewed' USING ERRCODE='22023';
 END IF;
 IF v_action='NEEDS_FIELD_CHECK' AND cardinality(v_close)>0 THEN
  RAISE EXCEPTION 'Field check remains unresolved' USING ERRCODE='23514';
 END IF;
 FOREACH v_flag IN ARRAY v_flags LOOP
  IF NOT EXISTS(SELECT 1 FROM ops.setup_movement_event e WHERE e.setup_movement_event_id=v_flag
    AND e.setup_session_id=v_session AND e.container_id=p_container
    AND e.notes LIKE '%contents_review_required=true%') THEN
   RAISE EXCEPTION 'Original review flag does not belong to this Container/Session' USING ERRCODE='23514';
  END IF;
 END LOOP;
 SELECT * INTO v_cs FROM ops.setup_container_state cs WHERE cs.setup_session_id=v_session AND cs.container_id=p_container;
 v_protected := v_snapshot->'container'->>'container_type_name'='Standalone Display' OR
   (v_snapshot->'container'->>'container_type_name' IN ('Display Pallet','Display-Pallet') AND cardinality(v_all)=1);
 IF v_action IN ('LOCATION','PRIOR_PARK') AND v_protected THEN
  RAISE EXCEPTION 'Standalone/single-Display Pallet stays attached; correct its Container location' USING ERRCODE='23514';
 END IF;
 IF v_action='ATTACH' AND v_cs.movement_status='RETURNED' THEN
  RAISE EXCEPTION 'A returned Container must stay empty' USING ERRCODE='23514';
 END IF;
 IF v_action='PRIOR_PARK' THEN
  SELECT * INTO v_return FROM ops.setup_movement_event e
  WHERE e.setup_movement_event_id=v_cs.last_movement_event_id AND e.event_type='RETURNED';
  IF NOT FOUND THEN RAISE EXCEPTION 'Prior park correction requires the current Home return' USING ERRCODE='23514'; END IF;
  SELECT * INTO v_prior FROM ops.setup_movement_event e
  WHERE e.setup_session_id=v_session AND e.container_id=p_container
    AND (e.occurred_at,e.setup_movement_event_id)<(v_return.occurred_at,v_return.setup_movement_event_id)
    AND e.event_type NOT IN ('RETURNED','PICKED','LOADED','IN_TRANSIT')
    AND (e.gps_latitude IS NOT NULL OR e.destination_stage_id IS NOT NULL OR nullif(btrim(e.destination_location_note),'') IS NOT NULL)
    AND NOT EXISTS(SELECT 1 FROM ops.setup_movement_event r WHERE r.setup_session_id=v_session
      AND r.container_id=p_container AND r.event_type='RETURNED'
      AND (r.occurred_at,r.setup_movement_event_id)>(e.occurred_at,e.setup_movement_event_id)
      AND (r.occurred_at,r.setup_movement_event_id)<(v_return.occurred_at,v_return.setup_movement_event_id))
  ORDER BY e.occurred_at DESC,e.setup_movement_event_id DESC LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'No prior park observation in this trip. Keep unresolved or choose verified location.' USING ERRCODE='23514'; END IF;
  v_stage:=v_prior.destination_stage_id; v_note:=v_prior.destination_location_note;
 ELSIF v_action='LOCATION' THEN
  v_stage:=(p_request->>'stage_id')::integer; v_note:=nullif(btrim(p_request->>'location_note'),'');
  IF v_stage IS NULL AND v_note IS NULL THEN RAISE EXCEPTION 'Verified Stage or location is required' USING ERRCODE='22023'; END IF;
 END IF;
 PERFORM set_config('app.directus_user_uuid',v_user::text,true);
 v_notes:='manager_contents_review='||p_client_event_id::text||'; evidence_time='||v_observed::text||'; evidence='||v_evidence;
 IF v_action='PRIOR_PARK' THEN v_notes:=v_notes||'; inferred_unload=true; prior_event_id='||v_prior.setup_movement_event_id::text; END IF;
 FOREACH v_id IN ARRAY v_ids LOOP
  SELECT * INTO v_ds FROM ops.setup_display_state ds WHERE ds.setup_session_id=v_session AND ds.display_id=v_id;
  IF v_action IN ('LOCATION','PRIOR_PARK','ATTACH') AND v_ds.last_movement_at>=v_now THEN
   RAISE EXCEPTION 'Display has future-dated movement evidence; keep unresolved for review' USING ERRCODE='23514';
  END IF;
  IF v_action='PRIOR_PARK' AND coalesce(v_ds.position_mode,'WITH_CONTAINER')<>'WITH_CONTAINER' THEN
   RAISE EXCEPTION 'Display already has independent placement; preserve it and review separately' USING ERRCODE='23514';
  END IF;
  IF v_action IN ('LOCATION','PRIOR_PARK') THEN
   SELECT r.setup_movement_event_id INTO v_event FROM ops.record_setup_movement_event(
    p_email,p_season_year,md5(p_client_event_id::text||':'||v_id::text)::uuid,'DISPLAY',v_id,'TASK_UNLOAD',v_now,
    NULL,p_email,'MANUAL_ENTRY',false,v_prior.gps_latitude,v_prior.gps_longitude,v_prior.gps_accuracy_m,
    v_stage,v_note,v_notes,'{}',v_prior.gps_fix_at,v_prior.gps_fix_age_ms,coalesce(v_prior.gps_quality,'UNASSESSED'),v_prior.gps_quality_note) r;
   v_events:=array_append(v_events,v_event);
  ELSIF v_action='ATTACH' THEN
   IF coalesce(v_ds.position_mode,'WITH_CONTAINER')<>'DETACHED' THEN
    RAISE EXCEPTION 'Only an erroneous current detachment can be restored' USING ERRCODE='23514';
   END IF;
   -- Existing enum/effect/state semantics; this is an audited correction, not
   -- implementation of takedown loading or permanent Container reassignment.
   INSERT INTO ops.setup_movement_event(setup_session_id,event_type,occurred_at,notes,client_event_id,
    received_at,captured_operator_email,captured_operator_person_id,capture_method,destination_location_note)
   VALUES(v_session,'DISPLAY_REATTACH',v_now,v_notes,md5(p_client_event_id::text||':'||v_id::text)::uuid,
    v_now,lower(btrim(p_email)),v_person,'MANUAL_ENTRY','Attachment correction to assigned Container')
   RETURNING setup_movement_event_id INTO v_event;
   INSERT INTO ops.setup_movement_event_display(setup_movement_event_id,display_id,movement_effect) VALUES(v_event,v_id,'REATTACHED');
   UPDATE ops.setup_display_state SET position_mode='WITH_CONTAINER',current_stage_id=NULL,current_location_note=NULL,
    last_movement_event_id=v_event,movement_status=NULL,last_movement_at=v_now
   WHERE setup_session_id=v_session AND display_id=v_id;
   v_events:=array_append(v_events,v_event);
  END IF;
 END LOOP;
 -- A note may not dismiss a live movement contradiction.
 IF cardinality(v_close)>0 OR v_action='CONFIRM' THEN
  IF EXISTS(SELECT 1 FROM ref.display d LEFT JOIN ops.setup_display_state ds
     ON ds.setup_session_id=v_session AND ds.display_id=d.display_id
     WHERE d.display_id=ANY(v_ids) AND
       ((v_cs.movement_status='RETURNED' AND coalesce(ds.position_mode,'WITH_CONTAINER')='WITH_CONTAINER') OR
        (v_protected AND ds.position_mode='DETACHED') OR
        (ds.position_mode='DETACHED' AND lower(coalesce(ds.current_location_note,'')) LIKE '%unresolved%'))) THEN
   RAISE EXCEPTION 'Correct the selected movement contradiction before confirming or resolving it' USING ERRCODE='23514';
  END IF;
 END IF;
 FOREACH v_flag IN ARRAY v_close LOOP
  -- Capture snapshots are optional on legacy flags. Missing scope requires an
  -- explicit whole-case attestation; partial confirmations never silently close.
  SELECT e.notes INTO v_note FROM ops.setup_movement_event e WHERE e.setup_movement_event_id=v_flag;
  BEGIN
   v_json:=split_part(split_part(v_note,'contents_reconciliation=',2),'; contents_review_required=true',1)::jsonb;
  EXCEPTION WHEN OTHERS THEN v_json:=NULL;
  END;
  v_scope:=NULL;
  IF v_json->'review_context'->>'context_available'='true' AND jsonb_typeof(v_json->'review_context'->'expected_displays')='array' THEN
   SELECT coalesce(array_agg((x->>'display_id')::bigint),'{}') INTO v_scope
   FROM jsonb_array_elements(v_json->'review_context'->'expected_displays') x;
  END IF;
  SELECT coalesce(array_agg(DISTINCT id),'{}') INTO v_accounted FROM (
   SELECT unnest(v_ids) id UNION ALL SELECT unnest(r.display_ids) FROM ops.setup_container_review_event r
   WHERE r.setup_session_id=v_session AND r.container_id=p_container AND v_flag=ANY(r.flag_ids)
    AND r.action<>'NEEDS_FIELD_CHECK') q;
  IF v_scope IS NULL THEN
   IF p_request->>'whole_case_confirmed' IS DISTINCT FROM 'true' OR NOT(v_all<@v_accounted) THEN
    RAISE EXCEPTION 'Legacy review has no captured scope. Confirm the whole case explicitly or keep it open.' USING ERRCODE='23514';
   END IF;
  ELSIF NOT(v_scope<@v_accounted) THEN
   RAISE EXCEPTION 'Some captured Display Names are still unresolved. Save partial work without closing this flag.' USING ERRCODE='23514';
  END IF;
 END LOOP;
 INSERT INTO ops.setup_container_review_event(setup_session_id,container_id,client_event_id,action,display_ids,flag_ids,
  resolved_flag_ids,evidence,observed_at,reviewer_email,reviewer_person_id,snapshot,request,movement_event_ids)
 VALUES(v_session,p_container,p_client_event_id,v_action,v_ids,v_flags,v_close,v_evidence,v_observed,
  lower(btrim(p_email)),v_person,v_snapshot,p_request,v_events) RETURNING * INTO v_existing;
 RETURN v_existing;
END;
$fn$;
REVOKE ALL ON FUNCTION ops.review_setup_container_contents(text,integer,integer,uuid,jsonb,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.review_setup_container_contents(text,integer,integer,uuid,jsonb,jsonb) TO fieldwiring_app;
COMMIT;
