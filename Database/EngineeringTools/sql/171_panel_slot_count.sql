-- #171 incremental correction to deployed PR319. No source reimport.
-- Existing rows remain unknown; no installed breaker/circuit data is rewritten.
BEGIN;
ALTER TABLE ref.site_panel ADD COLUMN branch_position_count integer
 CONSTRAINT site_panel_slot_count_range CHECK (branch_position_count BETWEEN 1 AND 200);
COMMENT ON COLUMN ref.site_panel.branch_position_count IS
 'Number of numbered branch slots excluding the main; NULL means not recorded.';
-- Extend only the reviewed allowlist; preserve command body and privileges.
DO $migration$
DECLARE definition text; original text; replacement text;
BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid=
  'ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure) <> '49ed9c2fda6accb89dd9c72966aa4b78' THEN
  RAISE EXCEPTION 'Unexpected site_power_command baseline; reconcile before migration';
 END IF;
 original := 'WHEN ''panel'' THEN table_name:=''site_panel''; key_name:=''site_panel_id''; allowed:=ARRAY[';
 replacement := original || '''branch_position_count'',';
 SELECT pg_get_functiondef('ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure) INTO definition;
 IF length(definition)-length(replace(definition,original,'')) <> length(original) THEN
  RAISE EXCEPTION 'Panel command allowlist not unique';
 END IF;
 EXECUTE replace(definition,original,replacement);
END $migration$;
-- Share the model's revision lock, including for administrative writes.
CREATE FUNCTION ref.site_panel_slot_guard() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog,ref AS $guard$
DECLARE panel_id bigint; slot_count integer; occupied integer;
BEGIN
 PERFORM 1 FROM ref.site_power_revision WHERE singleton FOR UPDATE;
 panel_id := NEW.site_panel_id;
 SELECT branch_position_count INTO slot_count FROM ref.site_panel WHERE site_panel_id=panel_id;
 IF slot_count IS NOT NULL THEN
  SELECT max(pos) INTO occupied FROM ref.site_power_breaker b,unnest(b.panel_positions) pos
   WHERE b.site_panel_id=panel_id AND b.active AND b.breaker_role<>'MAIN';
  IF occupied>slot_count THEN
   RAISE EXCEPTION 'Number of slots (%) cannot exclude occupied position %',slot_count,occupied USING ERRCODE='23514';
  END IF;
 END IF;
 RETURN NEW;
END $guard$;
REVOKE ALL ON FUNCTION ref.site_panel_slot_guard() FROM PUBLIC;
CREATE TRIGGER site_panel_slot_count_guard AFTER INSERT OR UPDATE ON ref.site_panel
 FOR EACH ROW EXECUTE FUNCTION ref.site_panel_slot_guard();
CREATE TRIGGER site_breaker_slot_count_guard AFTER INSERT OR UPDATE ON ref.site_power_breaker
 FOR EACH ROW EXECUTE FUNCTION ref.site_panel_slot_guard();
COMMIT;
