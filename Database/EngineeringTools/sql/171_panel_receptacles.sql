-- Incremental after PR463. Explicit panel ownership, never synthetic waypoints.
BEGIN;
ALTER TABLE ref.site_power_device ADD COLUMN site_panel_id bigint REFERENCES ref.site_panel;
ALTER TABLE ref.site_power_device ADD CONSTRAINT site_panel_outlet_location_ck
 CHECK(site_panel_id IS NULL OR (device_kind='OUTLET' AND site_waypoint_id IS NULL));
CREATE UNIQUE INDEX site_panel_outlet_name_uq ON ref.site_power_device(site_panel_id,lower(btrim(device_name)))
 WHERE active AND site_panel_id IS NOT NULL;

-- All mutation paths (including generic device/feed edits) retain local identity.
CREATE FUNCTION ref.site_panel_outlet_guard() RETURNS trigger LANGUAGE plpgsql
SET search_path=pg_catalog,ref AS $guard$
BEGIN
 IF EXISTS(SELECT 1 FROM ref.site_power_device d JOIN ref.site_panel p USING(site_panel_id)
   WHERE d.active AND NOT p.active)
 OR EXISTS(SELECT 1 FROM ref.site_power_feed f JOIN ref.site_power_device d
   ON d.site_power_device_id=f.destination_device_id LEFT JOIN ref.site_power_circuit c
   ON c.site_power_circuit_id=f.source_circuit_id
   WHERE f.active AND d.site_panel_id IS NOT NULL AND
     (NOT d.active OR c.site_power_circuit_id IS NULL OR NOT c.active OR c.site_panel_id<>d.site_panel_id))
 OR EXISTS(SELECT 1 FROM ref.site_power_feed f JOIN ref.site_power_device d
   ON d.site_power_device_id=f.source_device_id WHERE f.active AND d.site_panel_id IS NOT NULL)
 OR EXISTS(SELECT 1 FROM ref.site_power_feed f JOIN ref.site_power_device d
   ON d.site_power_device_id=f.destination_device_id WHERE f.active AND d.site_panel_id IS NOT NULL
   GROUP BY d.site_power_device_id HAVING count(*)>1) THEN
  RAISE EXCEPTION 'Panel receptacle requires one circuit from its active parent panel; competing or onward feeds are not supported' USING ERRCODE='23514';
 END IF;
 RETURN NULL;
END $guard$;
REVOKE ALL ON FUNCTION ref.site_panel_outlet_guard() FROM PUBLIC;
CREATE TRIGGER site_panel_outlet_guard AFTER INSERT OR UPDATE ON ref.site_power_device FOR EACH STATEMENT EXECUTE FUNCTION ref.site_panel_outlet_guard();
CREATE TRIGGER site_panel_outlet_guard AFTER INSERT OR UPDATE ON ref.site_power_feed FOR EACH STATEMENT EXECUTE FUNCTION ref.site_panel_outlet_guard();
CREATE TRIGGER site_panel_outlet_guard AFTER UPDATE ON ref.site_power_circuit FOR EACH STATEMENT EXECUTE FUNCTION ref.site_panel_outlet_guard();
CREATE TRIGGER site_panel_outlet_guard AFTER UPDATE ON ref.site_panel FOR EACH STATEMENT EXECUTE FUNCTION ref.site_panel_outlet_guard();

CREATE FUNCTION ref.site_panel_outlet_snapshot() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=pg_catalog,ref AS $snapshot$
 SELECT coalesce(jsonb_agg(jsonb_build_object('site_power_device_id',d.site_power_device_id,
  'site_panel_id',d.site_panel_id,'device_name',d.device_name,'site_power_circuit_id',c.site_power_circuit_id,
  'circuit_code',c.circuit_code) ORDER BY d.site_panel_id,d.device_name,d.site_power_device_id),'[]'::jsonb)
 FROM ref.site_power_device d JOIN ref.site_panel p USING(site_panel_id)
 LEFT JOIN ref.site_power_feed f ON f.destination_device_id=d.site_power_device_id AND f.active
 LEFT JOIN ref.site_power_circuit c ON c.site_power_circuit_id=f.source_circuit_id AND c.active
 WHERE d.active AND p.active
$snapshot$;
REVOKE ALL ON FUNCTION ref.site_panel_outlet_snapshot() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.site_panel_outlet_snapshot() TO fieldwiring_app;

DO $migration$
DECLARE definition text; anchor text:=' IF p_kind=''equipment_event'' AND'; addition text;
BEGIN
addition:=$branch$
 IF p_kind='panel_outlet' THEN
  DECLARE parent_id bigint:=(p_data->>'site_panel_id')::bigint;
   supply_id bigint:=(p_data->>'site_power_circuit_id')::bigint;
   label text:=btrim(p_data->>'device_name'); enabled boolean:=(p_data->>'active')::boolean;
  BEGIN
   IF NOT p_data ?& ARRAY['site_panel_id','site_power_circuit_id','device_name','active']
    OR (SELECT count(*) FROM jsonb_object_keys(p_data))<>4 OR enabled IS NULL
    OR label IS NULL OR length(label) NOT BETWEEN 1 AND 100
    OR NOT EXISTS(SELECT 1 FROM ref.site_panel WHERE site_panel_id=parent_id AND active)
    OR (enabled AND NOT EXISTS(SELECT 1 FROM ref.site_power_circuit WHERE site_power_circuit_id=supply_id AND site_panel_id=parent_id AND active)) THEN
    RAISE EXCEPTION 'Select active panel, supplying circuit and receptacle name' USING ERRCODE='22023';
   END IF;
   IF p_id IS NOT NULL THEN
    SELECT to_jsonb(d) INTO before_row FROM ref.site_power_device d
     WHERE site_power_device_id=p_id AND site_panel_id=parent_id AND device_kind='OUTLET' AND active;
    IF NOT FOUND THEN RAISE EXCEPTION 'Active panel receptacle not found; reload' USING ERRCODE='P0002'; END IF;
    SELECT before_row || jsonb_build_object('site_power_circuit_id',(SELECT source_circuit_id FROM ref.site_power_feed WHERE destination_device_id=p_id AND active)) INTO before_row;
    -- Retire old relationships first. Names/history remain attached to stable ID.
    UPDATE ref.site_power_feed SET active=false,updated_at=clock_timestamp()
     WHERE destination_device_id=p_id AND active AND (NOT enabled OR source_circuit_id IS DISTINCT FROM supply_id);
    UPDATE ref.site_power_device SET device_name=label,active=enabled,updated_at=clock_timestamp()
     WHERE site_power_device_id=p_id RETURNING site_power_device_id INTO target;
   ELSE
    IF NOT enabled THEN RAISE EXCEPTION 'Cannot create a retired receptacle' USING ERRCODE='22023'; END IF;
    INSERT INTO ref.site_power_device(device_name,device_kind,site_panel_id)
     VALUES(label,'OUTLET',parent_id) RETURNING site_power_device_id INTO target;
   END IF;
   IF enabled AND NOT EXISTS(SELECT 1 FROM ref.site_power_feed WHERE destination_device_id=target AND active) THEN
    INSERT INTO ref.site_power_feed(source_circuit_id,destination_device_id) VALUES(supply_id,target);
   END IF;
   SELECT to_jsonb(d)||jsonb_build_object('site_power_circuit_id',supply_id) INTO after_row FROM ref.site_power_device d WHERE site_power_device_id=target;
   UPDATE ref.site_power_revision SET revision=revision+1 WHERE singleton RETURNING revision INTO rev;
   INSERT INTO ops.site_power_edit_log(revision,request_id,command,target_id,payload,before_data,after_data,directus_user_id,person_id,operator_email)
    VALUES(rev,p_request,p_kind,target,jsonb_build_object('id',p_id,'fields',request_fields),before_row,after_row,actor.directus_user_id,actor.person_id,lower(btrim(p_email)));
   RETURN jsonb_build_object('revision',rev,'target_id',target,'replayed',false);
  END;
 END IF;
$branch$;
SELECT pg_get_functiondef('ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure) INTO definition;
IF length(definition)-length(replace(definition,anchor,''))<>length(anchor) THEN RAISE EXCEPTION 'PR463 command baseline differs'; END IF;
EXECUTE replace(definition,anchor,addition||anchor);
END $migration$;
COMMIT;
