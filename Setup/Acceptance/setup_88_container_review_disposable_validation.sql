\set ON_ERROR_STOP on
-- Current-Production clone only, after077. Real mapped Manager/constraints/audit;
-- all review evidence rolls back. This does not repair the captured Production data.
BEGIN;
DO $validation$
DECLARE
 v_email text; v_session bigint; v_year integer; v_container integer; v_snapshot jsonb;
 v_req jsonb; v_id uuid := '88000000-0000-4000-8000-000000007701'; v_first bigint;
 v_before text; v_after text; v_result ops.setup_container_review_event;
 v_display bigint; v_state jsonb; v_parent integer;
BEGIN
 SELECT u.email INTO v_email FROM public.directus_users u
 JOIN ref.person p ON p.directus_user_id=u.id
 JOIN LATERAL ref.setup_browser_capabilities(u.email) caps ON true
 WHERE u.status='active' AND caps.can_manage_setup AND caps.can_move_setup_assets ORDER BY lower(u.email) LIMIT 1;
 SELECT setup_session_id,season_year INTO v_session,v_year FROM ops.setup_session
 WHERE session_status NOT IN ('COMPLETE','HISTORICAL_VERIFICATION') ORDER BY season_year DESC LIMIT 1;
 SELECT container_id INTO v_container FROM ref.container ORDER BY container_id LIMIT 1;
 IF v_email IS NULL OR v_session IS NULL OR v_container IS NULL THEN
  RAISE EXCEPTION 'Mapped Manager, open Session and Container required for clone validation';
 END IF;
 SELECT md5(coalesce(string_agg(row_to_json(x)::text,'|' ORDER BY setup_movement_event_id),''))
 INTO v_before FROM ops.setup_movement_event x WHERE setup_session_id=v_session;
 v_snapshot:=ops.setup_container_review_snapshot(v_session,v_container);
 v_req:=jsonb_build_object('action','NEEDS_FIELD_CHECK','display_ids','[]'::jsonb,'flag_ids','[]'::jsonb,
  'resolve_flag_ids','[]'::jsonb,'evidence','Disposable-only Manager field-check request',
  'observed_at',clock_timestamp(),'whole_case_confirmed',false);
 PERFORM set_config('role','fieldwiring_app',true);
 SELECT * INTO v_result FROM ops.review_setup_container_contents(v_email,v_year,v_container,v_id,v_snapshot,v_req);
 v_first:=v_result.setup_container_review_event_id;
 SELECT * INTO v_result FROM ops.review_setup_container_contents(v_email,v_year,v_container,v_id,v_snapshot,v_req);
 IF v_result.setup_container_review_event_id<>v_first THEN RAISE EXCEPTION 'Review retry duplicated evidence'; END IF;
 BEGIN
  PERFORM * FROM ops.review_setup_container_contents(v_email,v_year,v_container,
   '88000000-0000-4000-8000-000000007702',v_snapshot,v_req);
  RAISE EXCEPTION 'Stale review was accepted';
 EXCEPTION WHEN serialization_failure THEN NULL;
 END;
 BEGIN
  UPDATE ops.setup_container_review_event SET evidence='Not allowed' WHERE setup_container_review_event_id=v_first;
  RAISE EXCEPTION 'App role can update review history';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 SELECT md5(coalesce(string_agg(row_to_json(x)::text,'|' ORDER BY setup_movement_event_id),''))
 INTO v_after FROM ops.setup_movement_event x WHERE setup_session_id=v_session;
 IF v_before<>v_after THEN RAISE EXCEPTION 'Field-check review changed movement history'; END IF;
 RAISE NOTICE 'PASS: real Manager/role, current snapshot, field-check audit, retry, stale guard, no direct DML or movement changes';
 -- Prove the location-correction path with real identity/audit/constraints, not
 -- invented Person rows or disabled triggers. The entire transaction rolls back.
 SELECT c.container_id,d.display_id INTO v_container,v_display
 FROM ref.container c JOIN ref.container_type ct USING(container_type_id)
 JOIN ref.display d USING(container_id) JOIN ref.display_status st USING(display_status_id)
 LEFT JOIN ops.setup_container_state cs ON cs.setup_session_id=v_session AND cs.container_id=c.container_id
 LEFT JOIN ops.setup_display_state ds ON ds.setup_session_id=v_session AND ds.display_id=d.display_id
 WHERE upper(st.display_status_name)='ACTIVE' AND ct.container_type_name<>'Standalone Display'
  AND coalesce(cs.movement_status,'')<>'RETURNED'
  AND (ds.last_movement_at IS NULL OR ds.last_movement_at<clock_timestamp())
  AND (ct.container_type_name NOT IN ('Display Pallet','Display-Pallet') OR
   (SELECT count(*) FROM ref.display x JOIN ref.display_status xs USING(display_status_id)
    WHERE x.container_id=c.container_id AND upper(xs.display_status_name)='ACTIVE')>1)
 ORDER BY c.container_id,d.display_id LIMIT 1;
 IF v_display IS NULL THEN RAISE EXCEPTION 'Ordinary Container Display required for clone correction proof'; END IF;
 v_snapshot:=ops.setup_container_review_snapshot(v_session,v_container);
 v_state:=v_snapshot->'state';
 v_req:=jsonb_build_object('action','LOCATION','display_ids',jsonb_build_array(v_display),'flag_ids','[]'::jsonb,
  'resolve_flag_ids','[]'::jsonb,'evidence','Disposable-only verified-location correction; all changes roll back',
  'observed_at',clock_timestamp(),'location_note','Disposable verified field location','whole_case_confirmed',false);
 SELECT * INTO v_result FROM ops.review_setup_container_contents(v_email,v_year,v_container,
  '88000000-0000-4000-8000-000000007703',v_snapshot,v_req);
 IF NOT EXISTS(SELECT 1 FROM ops.setup_display_state ds JOIN ops.setup_movement_event e
  ON e.setup_movement_event_id=ds.last_movement_event_id WHERE ds.setup_session_id=v_session
  AND ds.display_id=v_display AND ds.position_mode='DETACHED'
  AND ds.current_location_note='Disposable verified field location'
  AND e.setup_movement_event_id=ANY(v_result.movement_event_ids)
  AND e.notes LIKE 'manager_contents_review=%') THEN RAISE EXCEPTION 'Verified-location correction/evidence failed'; END IF;
 IF ops.setup_container_review_snapshot(v_session,v_container)->'state' IS DISTINCT FROM v_state THEN
  RAISE EXCEPTION 'Display correction changed Container state';
 END IF;
 SELECT container_id INTO v_parent FROM ref.display WHERE display_id=v_display;
 IF v_parent<>v_container THEN RAISE EXCEPTION 'Correction changed permanent assignment'; END IF;
 RAISE NOTICE 'PASS: real-role Display correction, movement provenance, Container and permanent assignment preservation';
END;
$validation$;
ROLLBACK;
