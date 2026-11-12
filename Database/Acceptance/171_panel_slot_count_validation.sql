-- Read-only proof for the incremental #171 slot-count migration.
BEGIN READ ONLY;
DO $check$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid='ref.site_panel'::regclass
  AND attname='branch_position_count' AND atttypid='integer'::regtype AND NOT attnotnull) THEN
  RAISE EXCEPTION 'Nullable panel slot count missing'; END IF;
 IF (SELECT count(*) FROM pg_trigger WHERE tgname IN ('site_panel_slot_count_guard','site_breaker_slot_count_guard')
   AND NOT tgisinternal AND tgenabled='O')<>2 THEN RAISE EXCEPTION 'Slot guards missing'; END IF;
 IF EXISTS(SELECT 1 FROM ref.site_panel p JOIN ref.site_power_breaker b USING(site_panel_id),unnest(b.panel_positions) pos
  WHERE b.active AND b.breaker_role<>'MAIN' AND pos>p.branch_position_count) THEN
  RAISE EXCEPTION 'Occupied slot exceeds panel count'; END IF;
 IF NOT has_function_privilege('fieldwiring_app','ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)','EXECUTE')
  OR has_table_privilege('fieldwiring_app','ref.site_panel','INSERT,UPDATE,DELETE') THEN
  RAISE EXCEPTION 'Panel command permission boundary differs'; END IF;
END $check$;
ROLLBACK;
