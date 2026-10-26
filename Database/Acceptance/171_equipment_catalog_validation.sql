-- Read-only: compare optimized output with the unchanged authoritative projections.
BEGIN READ ONLY;
DO $validation$
DECLARE email text; snapshot jsonb; expected jsonb; actual jsonb; started timestamptz;
BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='ref.site_power_snapshot(text)'::regprocedure)
    <> 'ff77cdf2081a3828996e67f452acb7ba' THEN
  RAISE EXCEPTION 'Unexpected optimized snapshot definition';
 END IF;
 IF NOT has_function_privilege('fieldwiring_app','ref.site_power_snapshot(text)','EXECUTE')
 OR EXISTS(SELECT 1 FROM pg_proc p JOIN LATERAL aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a ON true
   WHERE p.oid='ref.site_power_snapshot(text)'::regprocedure AND a.grantee=0 AND a.privilege_type='EXECUTE') THEN
  RAISE EXCEPTION 'Snapshot execute boundary changed';
 END IF;
 BEGIN
  PERFORM ref.site_power_snapshot('snapshot-denial-'||gen_random_uuid()||'@example.invalid');
  RAISE EXCEPTION 'Unknown identity accepted';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
 END;
 SELECT u.email INTO email FROM public.directus_users u
 WHERE u.status='active' AND coalesce((ref.site_power_access(u.email)->>'can_read')::boolean,false)
 ORDER BY u.email LIMIT 1;
 IF email IS NULL THEN RAISE EXCEPTION 'No authorized existing identity available for snapshot validation'; END IF;
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure)<>'43bed006ec8402b74fd3e27d006b6e06'
 OR has_table_privilege('fieldwiring_app','ops.site_equipment_event','INSERT,UPDATE,DELETE') THEN
  RAISE EXCEPTION 'Equipment command or direct-write boundary changed'; END IF;
 IF (SELECT pg_get_expr(indpred,indrelid) FROM pg_index WHERE indexrelid='ref.site_power_circuit_panel_code_uq'::regclass) IS DISTINCT FROM 'active' THEN
  RAISE EXCEPTION 'Deployed active circuit designation index missing'; END IF;
 IF has_table_privilege('fieldwiring_app','ref.site_equipment_type','INSERT,UPDATE,DELETE') OR has_table_privilege('fieldwiring_app','ref.site_equipment_model','INSERT,UPDATE,DELETE') THEN RAISE EXCEPTION 'Catalog direct-write boundary changed'; END IF;
 started:=clock_timestamp(); snapshot:=ref.site_power_snapshot(email);
 IF jsonb_array_length(snapshot->'equipment_types')<>(SELECT count(*) FROM ref.site_equipment_type WHERE additional_equipment) OR jsonb_array_length(snapshot->'equipment_models')<>(SELECT count(*) FROM ref.site_equipment_model) THEN RAISE EXCEPTION 'Catalog snapshot content omitted'; END IF;
 IF jsonb_array_length(snapshot->'equipment_events')<>(SELECT count(*) FROM ops.site_equipment_event) THEN RAISE EXCEPTION 'Equipment history omitted'; END IF;
 RAISE NOTICE 'Optimized snapshot: % ms, % bytes, waypoints %, requirements %, eligibility %',
  extract(epoch FROM clock_timestamp()-started)*1000,octet_length(snapshot::text),
  jsonb_array_length(snapshot->'waypoints'),jsonb_array_length(snapshot->'network_requirements'),jsonb_array_length(snapshot->'placement_eligibility');
 SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)),'[]') INTO expected FROM ref.site_controller_network_requirement t;
 SELECT coalesce(jsonb_agg(v ORDER BY v),'[]') INTO actual FROM jsonb_array_elements(snapshot->'network_requirements') v;
 IF actual<>expected THEN RAISE EXCEPTION 'Controller requirement content differs'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)),'[]') INTO expected FROM ref.site_controller_placement_eligibility t;
 SELECT coalesce(jsonb_agg(v ORDER BY v),'[]') INTO actual FROM jsonb_array_elements(snapshot->'placement_eligibility') v;
 IF actual<>expected THEN RAISE EXCEPTION 'Controller eligibility content differs'; END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)),'[]') INTO expected FROM ref.site_network_availability t;
 SELECT coalesce(jsonb_agg(v ORDER BY v),'[]') INTO actual FROM jsonb_array_elements(snapshot->'networks') v;
 IF actual<>expected THEN RAISE EXCEPTION 'Network availability content differs'; END IF;
 -- Check every waypoint, retaining missing-network false, multiple-network uniqueness,
 -- accepted aliases and existing canonical-label ordering. No fixed Production counts.
 WITH networks AS MATERIALIZED (SELECT * FROM ref.site_network_availability)
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',w.site_waypoint_id,'name',w.canonical_label,'type',w.waypoint_type,
  'network_capable',EXISTS(SELECT 1 FROM networks n WHERE n.site_waypoint_id=w.site_waypoint_id),
  'aliases',coalesce((SELECT jsonb_agg(a.alias_text) FROM ref.site_waypoint_alias a WHERE a.site_waypoint_id=w.site_waypoint_id AND a.accepted_at IS NOT NULL AND a.accepted_by IS NOT NULL),'[]'::jsonb)) ORDER BY w.canonical_label),'[]') INTO expected FROM ref.site_waypoint w;
 IF snapshot->'waypoints'<>expected THEN RAISE EXCEPTION 'Waypoint content/order differs'; END IF;
END $validation$;
ROLLBACK;
