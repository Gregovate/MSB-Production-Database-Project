-- Read-only structure/privilege validation on the disposable current-Production clone.
BEGIN READ ONLY;
DO $$
DECLARE fn regprocedure := to_regprocedure('ops.record_setup_controller_location(text,integer,uuid,text,bigint,text,timestamptz,text,text,text,boolean,numeric,numeric,numeric,integer,text,text,bigint[],timestamptz,integer,text,text)');
BEGIN
 IF fn IS NULL THEN RAISE EXCEPTION 'Controller location command missing'; END IF;
 IF NOT (SELECT prosecdef FROM pg_proc WHERE oid=fn) THEN RAISE EXCEPTION 'Protected controller location command required'; END IF;
 IF NOT has_function_privilege('fieldwiring_app',fn,'EXECUTE') THEN RAISE EXCEPTION 'Application command grant missing'; END IF;
 IF has_table_privilege('fieldwiring_app','ops.setup_movement_event','INSERT') THEN RAISE EXCEPTION 'Direct movement writes must remain denied'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conrelid='ops.setup_movement_event'::regclass AND conname='ck_setup_movement_controller') THEN RAISE EXCEPTION 'Controller identity guard missing'; END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_indexes WHERE schemaname='ops' AND indexname='ix_setup_movement_controller_time') THEN RAISE EXCEPTION 'Latest controller observation index missing'; END IF;
 RAISE NOTICE 'PASS: controller location command, identity guard, index and write boundary; no data written';
END $$;
ROLLBACK;
