-- PR470 candidate revision: apply only to a fresh PR463-baseline clone.
-- Panel outlets designate an existing breaker; no additional inventory is created.
BEGIN;
ALTER TABLE ref.site_power_breaker ADD COLUMN panel_outlets boolean NOT NULL DEFAULT false;
ALTER TABLE ref.site_power_breaker ADD CONSTRAINT site_breaker_panel_outlets_ck
 CHECK(NOT panel_outlets OR breaker_role='BRANCH');
DO $migration$
DECLARE definition text; defaults text := 'expected:=jsonb_build_object(''verification_status'',''UNVERIFIED'',''active'',true'; anchor text := '''site_panel_id'',''breaker_name'',''breaker_role''';
BEGIN
 SELECT pg_get_functiondef('ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure) INTO definition;
 IF length(definition)-length(replace(definition,anchor,''))<>length(anchor) THEN
  RAISE EXCEPTION 'PR463 breaker command baseline differs';
 END IF;
 -- The canonical command already owns auth, revision locking, replay and audit.
 -- breaker_schedule delegates its breaker payload to this same allowlisted path.
 definition:=replace(definition,anchor,'''site_panel_id'',''breaker_name'',''panel_outlets'',''breaker_role''');
 IF length(definition)-length(replace(definition,defaults,''))<>length(defaults) THEN
  RAISE EXCEPTION 'PR463 insert defaults differ';
 END IF;
 EXECUTE replace(definition,defaults,defaults||',''panel_outlets'',false');
END $migration$;

-- Small projection for Setup; reuse FLW endpoint resolution without requiring
-- a physical-cable inventory row or running controller/load computations.
CREATE FUNCTION ref.site_map_power_details() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=pg_catalog,ref AS $snapshot$
 SELECT jsonb_build_object(
 'breakers',coalesce((SELECT jsonb_agg(jsonb_build_object(
  'site_power_breaker_id',b.site_power_breaker_id,'site_panel_id',b.site_panel_id,
  'breaker_name',b.breaker_name,'panel_outlets',b.panel_outlets,
  'source_evidence',b.source_evidence,'rated_amps',b.rated_amps) ORDER BY b.site_power_breaker_id)
  FROM ref.site_power_breaker b JOIN ref.site_panel p USING(site_panel_id) WHERE b.active AND p.active),'[]'::jsonb),
 'flw_tests',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY t.test_uuid) FROM ref.site_flw_cable_test t),'[]'::jsonb))
$snapshot$;
REVOKE ALL ON FUNCTION ref.site_map_power_details() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.site_map_power_details() TO fieldwiring_app;
COMMIT;
