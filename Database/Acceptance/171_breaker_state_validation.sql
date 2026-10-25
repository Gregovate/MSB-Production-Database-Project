-- Read-only acceptance, safe on a disposable clone or the governed deployed target.
BEGIN READ ONLY;
DO $validation$
BEGIN
 IF position('IF p_kind=''breaker_state'' THEN' IN pg_get_functiondef(
   'ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure))=0 THEN
  RAISE EXCEPTION 'Breaker state command missing';
 END IF;
 IF has_table_privilege('fieldwiring_app','ops.setup_power_activity_event','INSERT')
 OR has_table_privilege('fieldwiring_app','ops.setup_power_activity_event','UPDATE')
 OR has_table_privilege('fieldwiring_app','ops.setup_power_activity_event','DELETE') THEN
  RAISE EXCEPTION 'Activity history must remain command-only and append-only';
 END IF;
 IF NOT has_function_privilege('fieldwiring_app',
  'ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)','EXECUTE') THEN
  RAISE EXCEPTION 'Existing application command grant missing';
 END IF;
END $validation$;
ROLLBACK;
