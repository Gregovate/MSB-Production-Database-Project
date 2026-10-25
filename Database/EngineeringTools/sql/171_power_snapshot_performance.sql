-- #171/#230 under #122: request-local reuse of measured expensive projections.
-- Incremental after PR457 only; no table, command, source import or privilege changes.
BEGIN;
DO $migration$
DECLARE definition text;
BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='ref.site_power_snapshot(text)'::regprocedure)
    <> '90d9a9a08645e6611e1216f80bdc774c' THEN
  RAISE EXCEPTION 'Unexpected site_power_snapshot baseline; reconcile drift or completed migration';
 END IF;
 SELECT pg_get_functiondef('ref.site_power_snapshot(text)'::regprocedure) INTO definition;
 definition:=replace(definition,$old$ result:=result||jsonb_build_object('network_requirements',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM ref.site_controller_network_requirement t),'[]'::jsonb));
 result:=result||jsonb_build_object('placement_eligibility',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM ref.site_controller_placement_eligibility t),'[]'::jsonb));$old$,$new$ -- One request-local evaluation of each expensive projection; no persistent cache.
 WITH snapshot_networks AS MATERIALIZED (
  SELECT * FROM ref.site_network_availability
 ), snapshot_requirements AS MATERIALIZED (
  SELECT * FROM ref.site_controller_network_requirement
 ), snapshot_eligibility AS (
  SELECT DISTINCT r.controller_id,a.site_waypoint_id,r.required_network,a.site_network_id
  FROM snapshot_requirements r JOIN snapshot_networks a
   ON ref.site_network_key(a.network_code)=r.required_network
  JOIN ref.site_network n USING(site_network_id)
  WHERE r.requirement_status='CONFIRMED' AND n.network_kind='LOR'
   AND (SELECT count(*) FROM ref.site_network x WHERE ref.site_network_key(x.network_code)=r.required_network)=1
 )
 SELECT result||jsonb_build_object(
 'network_requirements',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM snapshot_requirements t),'[]'::jsonb),
 'placement_eligibility',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM snapshot_eligibility t),'[]'::jsonb),
 'networks',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY 1) FROM snapshot_networks t),'[]'::jsonb),
 'waypoints',coalesce((SELECT jsonb_agg(jsonb_build_object('id',w.site_waypoint_id,'name',w.canonical_label,'type',w.waypoint_type,'network_capable',(n.site_waypoint_id IS NOT NULL),
 'aliases',coalesce((SELECT jsonb_agg(a.alias_text) FROM ref.site_waypoint_alias a WHERE a.site_waypoint_id=w.site_waypoint_id AND a.accepted_at IS NOT NULL AND a.accepted_by IS NOT NULL),'[]'::jsonb)) ORDER BY w.canonical_label) FROM ref.site_waypoint w LEFT JOIN (SELECT DISTINCT site_waypoint_id FROM snapshot_networks) n USING(site_waypoint_id)),'[]'::jsonb)
 ) INTO result;
$new$);
 definition:=replace(definition,$old$ result:=result||jsonb_build_object('networks',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY 1) FROM ref.site_network_availability t),'[]'::jsonb));$old$,$new$$new$);
 definition:=replace(definition,$old$ 'waypoints',coalesce((SELECT jsonb_agg(jsonb_build_object('id',w.site_waypoint_id,'name',w.canonical_label,'type',w.waypoint_type,'network_capable',EXISTS(SELECT 1 FROM ref.site_network_availability n WHERE n.site_waypoint_id=w.site_waypoint_id),
 'aliases',coalesce((SELECT jsonb_agg(a.alias_text) FROM ref.site_waypoint_alias a WHERE a.site_waypoint_id=w.site_waypoint_id AND a.accepted_at IS NOT NULL AND a.accepted_by IS NOT NULL),'[]'::jsonb)) ORDER BY w.canonical_label) FROM ref.site_waypoint w),'[]'::jsonb),
$old$,$new$$new$);
 EXECUTE definition;
END $migration$;
COMMIT;
