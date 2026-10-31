BEGIN READ ONLY;
DO $$ BEGIN
 IF to_regclass('ops.setup_container_pickup_list') IS NULL THEN RAISE EXCEPTION 'Missing pickup report'; END IF;
 IF NOT has_function_privilege('fieldwiring_app','ops.record_setup_container_pickup(text,integer,uuid,integer,text,integer,text,boolean)','EXECUTE') THEN RAISE EXCEPTION 'Missing pickup command permission'; END IF;
 IF has_table_privilege('fieldwiring_app','ops.setup_container_pickup_event','INSERT') THEN RAISE EXCEPTION 'Unexpected direct write permission'; END IF;
 RAISE NOTICE 'PASS: container pickup command/report installed; direct table writes denied';
END $$;
SELECT season_year,count(*) AS awaiting_pickup FROM ops.setup_container_pickup_list GROUP BY season_year;
ROLLBACK;
