-- Read-only deployed/disposable validation; no inferred state or repair writes.
BEGIN READ ONLY;
DO $validation$
BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure)<>'906289a801cae2e2d85957898984f031' THEN
  RAISE EXCEPTION 'Unexpected corrected breaker command'; END IF;
 IF (SELECT pg_get_expr(indpred,indrelid) FROM pg_index WHERE indexrelid='ref.site_power_circuit_panel_code_uq'::regclass) IS DISTINCT FROM 'active' THEN
  RAISE EXCEPTION 'Active circuit designation index missing'; END IF;
 IF NOT has_function_privilege('fieldwiring_app','ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)','EXECUTE')
 OR has_table_privilege('fieldwiring_app','ref.site_power_breaker','UPDATE')
 OR has_table_privilege('fieldwiring_app','ref.site_power_circuit','DELETE')
 OR has_table_privilege('fieldwiring_app','ops.setup_power_activity_event','DELETE') THEN
  RAISE EXCEPTION 'Command-only privilege boundary differs'; END IF;
END $validation$;
ROLLBACK;
