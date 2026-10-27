-- Read-only acceptance of the revised, breaker-owned designation.
BEGIN READ ONLY;
DO $validation$
DECLARE definition text;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='ref.site_power_breaker'::regclass AND conname='site_breaker_panel_outlets_ck') THEN
  RAISE EXCEPTION 'Breaker panel-outlet designation is missing';
 END IF;
 SELECT pg_get_functiondef('ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure) INTO definition;
 IF position('''breaker_name'',''panel_outlets'',''breaker_role''' IN definition)=0
 OR position('IF p_kind=''equipment_event'' AND' IN definition)=0 THEN
  RAISE EXCEPTION 'Breaker allowlist or retained equipment command missing';
 END IF;
 IF has_table_privilege('fieldwiring_app','ref.site_power_breaker','INSERT,UPDATE,DELETE')
 OR NOT has_function_privilege('fieldwiring_app','ref.site_map_power_details()','EXECUTE') THEN
  RAISE EXCEPTION 'Runtime privilege boundary differs';
 END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p, LATERAL aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
  WHERE p.oid='ref.site_map_power_details()'::regprocedure AND a.grantee=0 AND a.privilege_type='EXECUTE') THEN
  RAISE EXCEPTION 'PUBLIC snapshot execution granted';
 END IF;
 IF EXISTS(SELECT 1 FROM ref.site_power_breaker WHERE panel_outlets AND breaker_role<>'BRANCH') THEN
  RAISE EXCEPTION 'Non-branch breaker designated as panel outlets';
 END IF;
 PERFORM ref.site_map_power_details();
END $validation$;
COMMIT;
