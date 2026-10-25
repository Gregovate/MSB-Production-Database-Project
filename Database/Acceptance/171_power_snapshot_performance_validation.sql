-- Read-only: compare optimized output with the unchanged authoritative projections.
BEGIN READ ONLY;
DO $validation$
DECLARE email text; snapshot jsonb; expected jsonb; actual jsonb; started timestamptz;
BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='ref.site_power_snapshot(text)'::regprocedure)
    <> '1409b5a8bada107ecfd5954c8f49a18d' THEN
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
 started:=clock_timestamp(); snapshot:=ref.site_power_snapshot(email);
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
