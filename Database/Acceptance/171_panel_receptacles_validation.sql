-- Current-clone compatible; no business writes or synthetic inventory.
BEGIN READ ONLY;
DO $validation$
DECLARE definition text;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='ref.site_power_device'::regclass AND conname='site_panel_outlet_location_ck')
 OR to_regclass('ref.site_panel_outlet_name_uq') IS NULL
 OR (SELECT count(*) FROM pg_trigger WHERE tgname='site_panel_outlet_guard' AND NOT tgisinternal AND tgenabled='O')<>4 THEN
  RAISE EXCEPTION 'Panel receptacle schema/guards incomplete';
 END IF;
 SELECT pg_get_functiondef('ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure) INTO definition;
 IF position('IF p_kind=''panel_outlet'' THEN' IN definition)=0
 OR position('IF p_kind=''equipment_event'' AND' IN definition)=0 THEN
  RAISE EXCEPTION 'Panel command or retained equipment command missing';
 END IF;
 IF has_table_privilege('fieldwiring_app','ref.site_power_device','INSERT,UPDATE,DELETE')
 OR has_table_privilege('fieldwiring_app','ref.site_power_feed','INSERT,UPDATE,DELETE')
 OR NOT has_function_privilege('fieldwiring_app','ref.site_panel_outlet_snapshot()','EXECUTE') THEN
  RAISE EXCEPTION 'Runtime privilege boundary differs';
 END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p, LATERAL aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
   WHERE p.oid='ref.site_panel_outlet_snapshot()'::regprocedure AND a.grantee=0 AND a.privilege_type='EXECUTE') THEN
  RAISE EXCEPTION 'PUBLIC snapshot execution granted';
 END IF;
 IF EXISTS(SELECT 1 FROM ref.site_power_device d LEFT JOIN ref.site_panel p USING(site_panel_id)
  WHERE d.site_panel_id IS NOT NULL AND (d.device_kind<>'OUTLET' OR d.site_waypoint_id IS NOT NULL OR (d.active AND NOT p.active)))
 OR EXISTS(SELECT 1 FROM ref.site_power_feed f JOIN ref.site_power_device d ON d.site_power_device_id=f.destination_device_id
  LEFT JOIN ref.site_power_circuit c ON c.site_power_circuit_id=f.source_circuit_id
  WHERE f.active AND d.site_panel_id IS NOT NULL AND (NOT d.active OR c.site_power_circuit_id IS NULL OR NOT c.active OR c.site_panel_id<>d.site_panel_id))
 OR EXISTS(SELECT 1 FROM ref.site_power_feed f JOIN ref.site_power_device d ON d.site_power_device_id=f.source_device_id WHERE f.active AND d.site_panel_id IS NOT NULL)
 OR EXISTS(SELECT 1 FROM ref.site_power_feed f JOIN ref.site_power_device d ON d.site_power_device_id=f.destination_device_id
  WHERE f.active AND d.site_panel_id IS NOT NULL GROUP BY d.site_power_device_id HAVING count(*)>1) THEN
  RAISE EXCEPTION 'Panel receptacle location/supply invalid';
 END IF;
 PERFORM ref.site_panel_outlet_snapshot();
END $validation$;
COMMIT;
