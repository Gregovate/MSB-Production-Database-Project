\set ON_ERROR_STOP on
-- Run only on the disposable current-Production clone, after migration 070.
-- Real mapped actor, existing Containers/Displays, real audit triggers; rollback
-- all test observations. No historical event edits or master assignment changes.
BEGIN;
DO $validation$
DECLARE
 v_email text; v_container integer; v_ids bigint[]; v_remaining bigint[];
 v_session bigint; v_prior bigint; v_partial bigint; v_return bigint;
 v_home text; v_count integer; v_before bigint; v_child bigint; v_result record;
 v_stage integer; v_direct bigint;
 v_time timestamptz := clock_timestamp()+interval '1 day';
BEGIN
 SELECT u.email INTO v_email FROM public.directus_users u
 JOIN ref.person p ON p.directus_user_id=u.id
 JOIN LATERAL ref.setup_browser_capabilities(u.email) caps ON true
 WHERE u.status='active' AND caps.can_move_setup_assets
 ORDER BY caps.can_manage_setup,lower(u.email) LIMIT 1;
 IF v_email IS NULL THEN RAISE EXCEPTION 'Mapped movement operator required'; END IF;
 SELECT setup_session_id INTO v_session FROM ops.setup_session
 WHERE season_year=2026 AND session_status NOT IN ('COMPLETE','HISTORICAL_VERIFICATION');
 SELECT c.container_id,c.location_code,array_agg(d.display_id ORDER BY d.display_id)
 INTO v_container,v_home,v_ids
 FROM ref.container c JOIN ref.container_type ct USING(container_type_id)
 JOIN ref.display d USING(container_id) JOIN ref.display_status st USING(display_status_id)
 LEFT JOIN ops.setup_display_state ds ON ds.setup_session_id=v_session AND ds.display_id=d.display_id
 WHERE ct.container_type_name<>'Standalone Display' AND c.location_code IS NOT NULL
   AND upper(st.display_status_name)='ACTIVE' AND coalesce(ds.position_mode,'WITH_CONTAINER')='WITH_CONTAINER'
 GROUP BY c.container_id,c.location_code HAVING count(*)>=2 ORDER BY c.container_id LIMIT 1;
 IF v_container IS NULL THEN RAISE EXCEPTION 'Container with two active attached Displays required'; END IF;
 SELECT stage_id INTO v_stage FROM ref.stage ORDER BY stage_key,stage_id LIMIT 1;
 IF v_stage IS NULL THEN RAISE EXCEPTION 'Stage required for direct placement probe'; END IF;
 -- Execute under the real application's narrow role after administrative lookup.
 PERFORM set_config('role','fieldwiring_app',true);
 -- A subtransaction proves direct placement, then restores the original attached
 -- snapshot so the partial/empty probes below can reuse the same real identities.
 BEGIN
  SELECT setup_movement_event_id INTO v_direct FROM ops.record_setup_movement_event(
   v_email,2026,'88000000-0000-4000-8000-000000007091','DISPLAY',v_ids[1],'DISPLAY_MOVE',v_time,
   'disposable-88',v_email,'MANUAL_ENTRY',false,NULL,NULL,NULL,v_stage,'Fixture confirmed actual Stage',
   'display_setup_location_confirmed=true; direct_display_observation=true');
  IF NOT EXISTS(SELECT 1 FROM ops.setup_display_state WHERE setup_session_id=v_session AND display_id=v_ids[1]
    AND position_mode='DETACHED' AND current_stage_id=v_stage) THEN RAISE EXCEPTION 'Direct placement did not detach scanned Display'; END IF;
  IF EXISTS(SELECT 1 FROM ops.setup_display_state WHERE setup_session_id=v_session AND display_id=ANY(v_ids[2:cardinality(v_ids)])
    AND position_mode='DETACHED') THEN RAISE EXCEPTION 'Direct placement detached another Display'; END IF;
  PERFORM * FROM ops.record_setup_movement_event(
   v_email,2026,'88000000-0000-4000-8000-000000007092','CONTAINER',v_container,'CONTAINER_MOVE',v_time+interval '30 seconds',
   'disposable-88',v_email,'MANUAL_ENTRY',false,NULL,NULL,NULL,NULL,'Fixture later Container movement');
  IF (SELECT last_movement_event_id FROM ops.setup_display_state WHERE setup_session_id=v_session
    AND display_id=v_ids[1])<>v_direct THEN RAISE EXCEPTION 'Container dragged directly placed Display'; END IF;
  IF (SELECT container_id FROM ref.display WHERE display_id=v_ids[1])<>v_container THEN
   RAISE EXCEPTION 'Direct placement changed permanent Container assignment'; END IF;
  RAISE EXCEPTION 'Rollback successful direct placement probe' USING ERRCODE='ZX088';
 EXCEPTION WHEN SQLSTATE 'ZX088' THEN NULL;
 END;
 v_remaining := v_ids[1:cardinality(v_ids)-1];
 SELECT setup_movement_event_id INTO v_prior FROM ops.record_setup_movement_event(
  v_email,2026,'88000000-0000-4000-8000-000000007001','CONTAINER',v_container,'CONTAINER_MOVE',v_time,
  'disposable-88',v_email,'MANUAL_ENTRY',false,43.7,-87.7,3,NULL,'Fixture prior park drop');
 SELECT * INTO v_result FROM ops.record_setup_container_reconciliation(
  v_email,2026,'88000000-0000-4000-8000-000000007002','CONTAINER',v_container,'CONTAINER_MOVE',v_time+interval '1 minute',
  'disposable-88',v_email,'MANUAL_ENTRY',true,43.8,-87.8,5.12,NULL,'Fixture new Container location',NULL,ARRAY[]::bigint[],
  NULL,NULL,'UNASSESSED',NULL,jsonb_build_object('decision','NOT_EMPTY','identify_remaining',true,
   'expected_display_ids',to_jsonb(v_ids),'remaining_display_ids',to_jsonb(v_remaining),'prior_event_id',v_prior));
 v_partial := v_result.setup_movement_event_id;
 IF v_result.unloaded_display_count<>1 THEN RAISE EXCEPTION 'Partial complement count incorrect'; END IF;
 SELECT ds.last_movement_event_id INTO v_child FROM ops.setup_display_state ds
 WHERE ds.setup_session_id=v_session AND ds.display_id=v_ids[cardinality(v_ids)] AND ds.position_mode='DETACHED';
 IF NOT EXISTS (SELECT 1 FROM ops.setup_movement_event e WHERE e.setup_movement_event_id=v_child
   AND e.destination_location_note='Fixture prior park drop' AND e.gps_latitude=43.7
   AND e.notes LIKE '%inferred_unload=true%') THEN RAISE EXCEPTION 'Prior unload/provenance not retained'; END IF;
 SELECT count(*) INTO v_before FROM ops.setup_movement_event;
 SELECT * INTO v_result FROM ops.record_setup_container_reconciliation(
  v_email,2026,'88000000-0000-4000-8000-000000007002','CONTAINER',v_container,'CONTAINER_MOVE',v_time+interval '1 minute',
  'disposable-88',v_email,'MANUAL_ENTRY',true,43.8,-87.8,5.12,NULL,'Fixture new Container location',NULL,ARRAY[]::bigint[],
  NULL,NULL,'UNASSESSED',NULL,jsonb_build_object('decision','NOT_EMPTY','identify_remaining',true,
   'expected_display_ids',to_jsonb(v_ids),'remaining_display_ids',to_jsonb(v_remaining),'prior_event_id',v_prior));
 IF NOT v_result.duplicate_event OR (SELECT count(*) FROM ops.setup_movement_event)<>v_before THEN
  RAISE EXCEPTION 'Atomic replay duplicated observations'; END IF;
 BEGIN
  PERFORM * FROM ops.record_setup_container_reconciliation(
   v_email,2026,'88000000-0000-4000-8000-000000007003','CONTAINER',v_container,'RETURNED',v_time+interval '2 minutes',
   NULL,v_email,'MANUAL_ENTRY',false,NULL,NULL,NULL,NULL,NULL,NULL,ARRAY[]::bigint[],NULL,NULL,'UNASSESSED',NULL,
   jsonb_build_object('decision','EMPTY','expected_display_ids',to_jsonb(v_ids),'prior_event_id',v_partial));
  RAISE EXCEPTION 'Stale contents were accepted';
 EXCEPTION WHEN check_violation THEN NULL; END;
 SELECT * INTO v_result FROM ops.record_setup_container_reconciliation(
  v_email,2026,'88000000-0000-4000-8000-000000007004','CONTAINER',v_container,'RETURNED',v_time+interval '2 minutes',
  NULL,v_email,'MANUAL_ENTRY',false,NULL,NULL,NULL,NULL,NULL,NULL,ARRAY[]::bigint[],NULL,NULL,'UNASSESSED',NULL,
  jsonb_build_object('decision','EMPTY','expected_display_ids',to_jsonb(v_remaining),'prior_event_id',v_partial));
 v_return:=v_result.setup_movement_event_id;
 IF v_result.unloaded_display_count<>cardinality(v_remaining) THEN RAISE EXCEPTION 'Empty reconciliation count incorrect'; END IF;
 IF NOT EXISTS(SELECT 1 FROM ops.setup_container_state cs WHERE cs.setup_session_id=v_session
  AND cs.container_id=v_container AND cs.movement_status='RETURNED' AND cs.current_location_note=v_home) THEN
  RAISE EXCEPTION 'Canonical Return Home not projected'; END IF;
 IF EXISTS(SELECT 1 FROM ops.setup_movement_event e WHERE e.setup_movement_event_id=v_return AND e.gps_latitude IS NOT NULL) THEN
  RAISE EXCEPTION 'Return fabricated Workshop GPS'; END IF;
 IF (SELECT last_movement_event_id FROM ops.setup_display_state WHERE setup_session_id=v_session
  AND display_id=v_ids[cardinality(v_ids)])<>v_child THEN RAISE EXCEPTION 'Return dragged previously detached Display'; END IF;
 IF (SELECT location_code FROM ref.container WHERE container_id=v_container) IS DISTINCT FROM v_home THEN
  RAISE EXCEPTION 'Permanent Home was changed'; END IF;
 IF has_table_privilege('fieldwiring_app','ops.setup_display_state','UPDATE') OR
  has_table_privilege('fieldwiring_app','ops.setup_movement_event','INSERT') THEN
  RAISE EXCEPTION 'Application must retain narrow command-only writes'; END IF;
 RAISE NOTICE 'SETUP_88_CONTENTS_RECONCILIATION_DISPOSABLE_PASS Container=%; Displays=%',v_container,cardinality(v_ids);
END;
$validation$;
ROLLBACK;
