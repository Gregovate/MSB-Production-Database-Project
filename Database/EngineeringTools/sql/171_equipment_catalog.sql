-- Pending after 171_equipment_lifecycle only; never apply to original Production.
BEGIN;
DO $$ BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure)<>'7c6df16cea62a5635db1579d8dfeacb8'
 OR (SELECT md5(prosrc) FROM pg_proc WHERE oid='ref.site_power_snapshot(text)'::regprocedure)<>'7458c9499a05bf53ad6dc585b369c1f9' THEN
 RAISE EXCEPTION 'Unexpected catalog baseline or replay'; END IF;
END $$;
CREATE TABLE ref.site_equipment_type (
 equipment_type_id bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
 device_kind text PRIMARY KEY CHECK(device_kind ~ '^[A-Z][A-Z0-9_]{0,63}$' AND device_kind NOT IN ('CTRL','CONTROLLER','CONTROLLERS')),
 type_name text NOT NULL CHECK(length(btrim(type_name)) BETWEEN 1 AND 100),
 additional_equipment boolean NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX site_equipment_type_name_uq ON ref.site_equipment_type(lower(btrim(type_name)));
INSERT INTO ref.site_equipment_type(device_kind,type_name,additional_equipment) SELECT kind,initcap(replace(kind,'_',' ')),kind NOT IN ('FUSE','DISCONNECT','OUTLET','LIGHT_POLE')
 FROM unnest(ARRAY['FUSE','DISCONNECT','OUTLET','LIGHT_POLE','POWER_SUPPLY','ETHERNET_SWITCH','POE_SWITCH','ETHERNET_EXTENDER','ETHERNET_SPLITTER','RS485_REPEATER','OTHER','CAMERA']) kind;
CREATE TABLE ref.site_equipment_model (
 equipment_model_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 device_kind text NOT NULL REFERENCES ref.site_equipment_type,
 model_name text NOT NULL CHECK(length(btrim(model_name)) BETWEEN 1 AND 200),
 UNIQUE(equipment_model_id,device_kind)
);
CREATE UNIQUE INDEX site_equipment_model_name_uq ON ref.site_equipment_model(device_kind,lower(btrim(model_name)));
-- Carry forward the supplied field-picker vocabulary as references only.
-- No owned units, quantities, model assignments or placements are inferred.
INSERT INTO ref.site_equipment_model(device_kind,model_name) VALUES
 ('POWER_SUPPLY','Mean Well MDR-60-24 · 24 V 2.5 A'),
 ('POWER_SUPPLY','NDR 120 W · 48 V 2.5 A DIN supply'),
 ('POE_SWITCH','TRENDnet TI-PGLC50 · 5-port PoE+'),
 ('ETHERNET_SWITCH','10/100 Ethernet switch'),
 ('ETHERNET_SWITCH','Industrial 5-port Gigabit switch · model unknown, seller Zhipu China'),
 ('ETHERNET_EXTENDER','Tupavco TEX-200 · VDSL Ethernet extender'),
 ('ETHERNET_SPLITTER','RJ45 1-to-2 splitter · model unknown, seller Mhinese'),
 ('RS485_REPEATER','LOR RS485 Repeater · RS485REP / LOR-REP'),
 ('OTHER','MSB Blue Splitter'),
 ('OTHER','MSB Green Splitter'),
 ('OTHER','Ubiquiti LiteBeam LBE-5AC-GEN2 · wireless bridge'),
 ('CAMERA','REOLINK RLC-810A · PoE security camera'),
 ('OTHER','PixieLink');
ALTER TABLE ref.site_power_device DROP CONSTRAINT site_power_device_device_kind_check;
ALTER TABLE ref.site_power_device ADD CONSTRAINT site_power_device_kind_fk FOREIGN KEY(device_kind) REFERENCES ref.site_equipment_type;
ALTER TABLE ref.site_power_device ADD COLUMN equipment_model_id bigint;
ALTER TABLE ref.site_power_device ADD CONSTRAINT site_power_device_model_fk FOREIGN KEY(equipment_model_id,device_kind) REFERENCES ref.site_equipment_model(equipment_model_id,device_kind);
-- Existing device names are asset descriptions, not authoritative model identities.
-- Do not infer model assignments or rewrite existing inventory during migration.
REVOKE ALL ON ref.site_equipment_type,ref.site_equipment_model FROM PUBLIC,fieldwiring_app;
REVOKE ALL ON SEQUENCE ref.site_equipment_type_equipment_type_id_seq,ref.site_equipment_model_equipment_model_id_seq FROM PUBLIC,fieldwiring_app;
DO $migration$
DECLARE definition text; anchor text:=' IF p_kind=''equipment_event'' THEN'; addition text;
BEGIN
addition:=$branch$
 IF p_kind='equipment_event' AND p_data->>'event_kind'='MOVE' AND p_data->>'to_waypoint_id' IS NOT NULL
 AND NOT EXISTS(SELECT 1 FROM ref.site_waypoint WHERE site_waypoint_id=(p_data->>'to_waypoint_id')::bigint
  AND regexp_split_to_array(lower(btrim(waypoint_type)), '[-_[:space:]]+') && ARRAY['power','network','combo']) THEN
  RAISE EXCEPTION 'Install equipment at a Power, Network or Combo waypoint' USING ERRCODE='23514';
 END IF;
 -- Model cleanup never deletes physical equipment or lifecycle evidence.
 IF p_kind IN ('equipment_model_rename','equipment_model_delete') THEN
  IF p_id IS NULL OR (p_kind='equipment_model_delete' AND p_data<>'{}'::jsonb)
   OR (p_kind='equipment_model_rename' AND (NOT p_data ? 'model_name' OR EXISTS(SELECT 1 FROM jsonb_object_keys(p_data) k WHERE k<>'model_name'))) THEN
   RAISE EXCEPTION 'Select a model and valid cleanup fields' USING ERRCODE='22023'; END IF;
  SELECT to_jsonb(m) INTO before_row FROM ref.site_equipment_model m WHERE equipment_model_id=p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Equipment model not found' USING ERRCODE='P0002'; END IF;
  IF p_kind='equipment_model_delete' THEN
   IF EXISTS(SELECT 1 FROM ref.site_power_device WHERE equipment_model_id=p_id) THEN
    RAISE EXCEPTION 'Model is used by recorded equipment; its identity and history must be retained' USING ERRCODE='23514'; END IF;
   DELETE FROM ref.site_equipment_model WHERE equipment_model_id=p_id;
   after_row:=jsonb_build_object('deleted',true,'equipment_model_id',p_id);
  ELSE
   UPDATE ref.site_equipment_model SET model_name=btrim(p_data->>'model_name') WHERE equipment_model_id=p_id RETURNING to_jsonb(site_equipment_model) INTO after_row;
  END IF;
  target:=p_id;
  UPDATE ref.site_power_revision SET revision=revision+1 WHERE singleton RETURNING revision INTO rev;
  INSERT INTO ops.site_power_edit_log(revision,request_id,command,target_id,payload,before_data,after_data,directus_user_id,person_id,operator_email)
  VALUES(rev,p_request,p_kind,target,jsonb_build_object('id',p_id,'fields',request_fields),before_row,after_row,actor.directus_user_id,actor.person_id,lower(btrim(p_email)));
  RETURN jsonb_build_object('revision',rev,'target_id',target,'replayed',false);
 END IF;
 IF p_kind IN ('equipment_type','equipment_model','equipment_inventory','equipment_install') THEN
  DECLARE model ref.site_equipment_model%ROWTYPE; kind text; name text; qty integer; destination bigint:=(p_data->>'site_waypoint_id')::bigint; unit_id bigint; unit_ids jsonb:='[]';
  BEGIN
   IF p_id IS NOT NULL THEN RAISE EXCEPTION 'Catalog identities are immutable; create a new record' USING ERRCODE='22023'; END IF;
   IF p_kind='equipment_type' THEN
    IF EXISTS(SELECT 1 FROM jsonb_object_keys(p_data) k WHERE k NOT IN ('type_name')) THEN RAISE EXCEPTION 'Invalid type fields' USING ERRCODE='22023'; END IF;
    name:=btrim(p_data->>'type_name');kind:=regexp_replace(upper(name),'[^A-Z0-9]+','_','g');
    INSERT INTO ref.site_equipment_type(device_kind,type_name) VALUES(kind,name) RETURNING equipment_type_id,to_jsonb(site_equipment_type) INTO target,after_row;
   ELSIF p_kind='equipment_model' THEN
    IF EXISTS(SELECT 1 FROM jsonb_object_keys(p_data) k WHERE k NOT IN ('device_kind','model_name')) THEN RAISE EXCEPTION 'Invalid model fields' USING ERRCODE='22023'; END IF;
    IF NOT EXISTS(SELECT 1 FROM ref.site_equipment_type WHERE device_kind=p_data->>'device_kind' AND additional_equipment) THEN RAISE EXCEPTION 'Additional equipment type required' USING ERRCODE='22023'; END IF;
    INSERT INTO ref.site_equipment_model(device_kind,model_name) VALUES(p_data->>'device_kind',btrim(p_data->>'model_name')) RETURNING equipment_model_id,to_jsonb(site_equipment_model) INTO target,after_row;
   ELSE
    IF EXISTS(SELECT 1 FROM jsonb_object_keys(p_data) k WHERE k NOT IN ('equipment_model_id','quantity','notes','site_waypoint_id')) OR coalesce(p_data->>'quantity','') !~ '^[1-9][0-9]*$' OR length(coalesce(p_data->>'notes',''))>4000 THEN RAISE EXCEPTION 'Invalid inventory fields or quantity' USING ERRCODE='22023'; END IF;
    IF p_kind='equipment_install' THEN
     IF destination IS NULL OR NOT EXISTS(SELECT 1 FROM ref.site_waypoint WHERE site_waypoint_id=destination AND regexp_split_to_array(lower(btrim(waypoint_type)), '[-_[:space:]]+') && ARRAY['power','network','combo']) THEN
      RAISE EXCEPTION 'Select a Power, Network or Combo waypoint' USING ERRCODE='23514'; END IF;
    ELSIF p_data ? 'site_waypoint_id' THEN RAISE EXCEPTION 'Use Install Equipment to record a placement' USING ERRCODE='22023'; END IF;
    qty:=(p_data->>'quantity')::integer;
    IF qty>100 THEN RAISE EXCEPTION 'Quantity must be 1 to 100' USING ERRCODE='22023'; END IF;
    SELECT m.* INTO model FROM ref.site_equipment_model m JOIN ref.site_equipment_type t USING(device_kind) WHERE equipment_model_id=(p_data->>'equipment_model_id')::bigint AND t.additional_equipment;
    IF NOT FOUND THEN RAISE EXCEPTION 'Select an equipment model' USING ERRCODE='22023'; END IF;
    FOR i IN 1..qty LOOP
     INSERT INTO ref.site_power_device(device_name,device_kind,equipment_model_id,site_waypoint_id,owner_name,description,source_evidence,verification_status)
     VALUES(model.model_name,model.device_kind,model.equipment_model_id,destination,'MSB',coalesce(p_data->>'notes',''),'Inventory recorded through FieldWiring','UNVERIFIED') RETURNING site_power_device_id INTO unit_id;
     IF destination IS NOT NULL THEN
      INSERT INTO ops.site_equipment_event(site_power_device_id,event_kind,observed_at,from_waypoint_id,to_waypoint_id,notes,directus_user_id,person_id,operator_email)
      VALUES(unit_id,'MOVE',clock_timestamp(),NULL,destination,coalesce(p_data->>'notes',''),actor.directus_user_id,actor.person_id,lower(btrim(p_email)));
     END IF;
     unit_ids:=unit_ids||to_jsonb(unit_id);
    END LOOP;
    target:=unit_id;after_row:=jsonb_build_object('device_ids',unit_ids,'equipment_model_id',model.equipment_model_id,'quantity',qty,'site_waypoint_id',destination,'notes',coalesce(p_data->>'notes',''));
   END IF;
   UPDATE ref.site_power_revision SET revision=revision+1 WHERE singleton RETURNING revision INTO rev;
   INSERT INTO ops.site_power_edit_log(revision,request_id,command,target_id,payload,before_data,after_data,directus_user_id,person_id,operator_email)
   VALUES(rev,p_request,p_kind,target,jsonb_build_object('id',p_id,'fields',request_fields),NULL,after_row,actor.directus_user_id,actor.person_id,lower(btrim(p_email)));
   RETURN jsonb_build_object('revision',rev,'target_id',target,'replayed',false);
  END;
 END IF;
$branch$;
SELECT pg_get_functiondef('ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure) INTO definition;
IF length(definition)-length(replace(definition,anchor,''))<>length(anchor) THEN RAISE EXCEPTION 'Catalog command anchor mismatch'; END IF;
EXECUTE replace(definition,anchor,addition||anchor);
SELECT pg_get_functiondef('ref.site_power_snapshot(text)'::regprocedure) INTO definition;
anchor:=' RETURN result||jsonb_build_object(';
IF length(definition)-length(replace(definition,anchor,''))<>length(anchor) THEN RAISE EXCEPTION 'Catalog snapshot anchor mismatch'; END IF;
EXECUTE replace(definition,anchor,$addition$
 result:=result||jsonb_build_object('equipment_types',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY type_name) FROM ref.site_equipment_type t WHERE additional_equipment),'[]'::jsonb),'equipment_models',coalesce((SELECT jsonb_agg(to_jsonb(m) ORDER BY model_name,equipment_model_id) FROM ref.site_equipment_model m),'[]'::jsonb));
 RETURN result||jsonb_build_object($addition$);
END $migration$;
COMMIT;
