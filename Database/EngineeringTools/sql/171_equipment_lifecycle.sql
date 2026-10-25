-- Part 2 incremental history; existing device inventory and power command retained.
BEGIN;
DO $$ BEGIN
 IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure)<>'7c1ff2630aefda0a7e46c0ef4672714e'
 OR (SELECT md5(prosrc) FROM pg_proc WHERE oid='ref.site_power_snapshot(text)'::regprocedure)<>'1409b5a8bada107ecfd5954c8f49a18d' THEN
 RAISE EXCEPTION 'Unexpected equipment baseline or replay; reconcile before applying'; END IF;
END $$;
CREATE TABLE ops.site_equipment_event (
 event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 site_power_device_id bigint NOT NULL REFERENCES ref.site_power_device,
 event_kind text NOT NULL CHECK(event_kind IN ('TEST','MOVE','REPLACE')),
 condition text CHECK(condition IN ('UNTESTED','WORKING','FAILED')),
 observed_at timestamptz CHECK(observed_at IS NULL OR isfinite(observed_at)),
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 from_waypoint_id bigint REFERENCES ref.site_waypoint,
 to_waypoint_id bigint REFERENCES ref.site_waypoint,
 replacement_device_id bigint REFERENCES ref.site_power_device,
 corrects_event_id bigint UNIQUE REFERENCES ops.site_equipment_event,
 notes text NOT NULL DEFAULT '',
 directus_user_id uuid NOT NULL, person_id integer NOT NULL REFERENCES ref.person,
 operator_email text NOT NULL,
 CHECK((event_kind='TEST')=(condition IS NOT NULL)),
 CHECK((event_kind='REPLACE')=(replacement_device_id IS NOT NULL)),
 CHECK(replacement_device_id IS DISTINCT FROM site_power_device_id),
 CHECK(corrects_event_id IS NULL OR event_kind='TEST')
);
CREATE FUNCTION ops.site_equipment_event_immutable() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN RAISE EXCEPTION 'Equipment history is append-only' USING ERRCODE='23514'; END $$;
CREATE TRIGGER site_equipment_event_immutable BEFORE UPDATE OR DELETE ON ops.site_equipment_event
 FOR EACH ROW EXECUTE FUNCTION ops.site_equipment_event_immutable();
REVOKE ALL ON ops.site_equipment_event FROM PUBLIC,fieldwiring_app;
REVOKE ALL ON FUNCTION ops.site_equipment_event_immutable() FROM PUBLIC;
DO $migration$
DECLARE definition text; anchor text:=' IF p_kind=''breaker_schedule'' THEN'; addition text;
BEGIN
addition:=$branch$
 IF p_kind='equipment_event' THEN
  DECLARE old_device ref.site_power_device%ROWTYPE; spare ref.site_power_device%ROWTYPE;
   event_type text:=p_data->>'event_kind'; destination bigint:=(p_data->>'to_waypoint_id')::bigint;
   replacement bigint:=(p_data->>'replacement_device_id')::bigint; corrected bigint:=(p_data->>'corrects_event_id')::bigint;
   observed timestamptz:=(p_data->>'observed_at')::timestamptz;
  BEGIN
   IF EXISTS(SELECT 1 FROM jsonb_object_keys(p_data) k WHERE k NOT IN ('event_kind','condition','observed_at','to_waypoint_id','replacement_device_id','corrects_event_id','notes'))
    OR event_type IS NULL OR event_type NOT IN ('TEST','MOVE','REPLACE') OR length(coalesce(p_data->>'notes',''))>4000 THEN
    RAISE EXCEPTION 'Invalid equipment event fields' USING ERRCODE='22023'; END IF;
   SELECT * INTO old_device FROM ref.site_power_device WHERE site_power_device_id=p_id AND active;
   IF NOT FOUND THEN RAISE EXCEPTION 'Active equipment required' USING ERRCODE='22023'; END IF;
   IF observed IS NOT NULL AND (NOT isfinite(observed) OR observed>clock_timestamp()+interval '5 minutes') THEN
    RAISE EXCEPTION 'Invalid or future observation time' USING ERRCODE='22023'; END IF;
   IF event_type='TEST' THEN
    IF coalesce(p_data->>'condition','') NOT IN ('UNTESTED','WORKING','FAILED') OR destination IS NOT NULL OR replacement IS NOT NULL THEN
     RAISE EXCEPTION 'Test requires a condition, without movement fields' USING ERRCODE='22023'; END IF;
    IF corrected IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ops.site_equipment_event e WHERE e.event_id=corrected AND e.site_power_device_id=p_id AND e.event_kind='TEST'
     AND NOT EXISTS(SELECT 1 FROM ops.site_equipment_event c WHERE c.corrects_event_id=e.event_id)) THEN
     RAISE EXCEPTION 'Correct an uncorrected test for this device' USING ERRCODE='22023'; END IF;
    destination:=old_device.site_waypoint_id;
   ELSE
    IF corrected IS NOT NULL OR p_data->>'condition' IS NOT NULL OR observed IS NOT NULL THEN
     RAISE EXCEPTION 'Movement records the current change, without test/correction fields' USING ERRCODE='22023'; END IF;
    observed:=clock_timestamp();
    IF EXISTS(SELECT 1 FROM ref.site_power_feed WHERE active AND (source_device_id=p_id OR destination_device_id=p_id OR source_device_id=replacement OR destination_device_id=replacement)) THEN
     RAISE EXCEPTION 'Reconcile active equipment feeds before moving or replacing' USING ERRCODE='23514'; END IF;
    IF event_type='REPLACE' THEN
     SELECT * INTO spare FROM ref.site_power_device WHERE site_power_device_id=replacement AND active AND site_waypoint_id IS NULL;
     IF NOT FOUND OR replacement=p_id OR old_device.site_waypoint_id IS NULL OR destination IS NOT NULL THEN
      RAISE EXCEPTION 'Replace installed equipment with a different active uninstalled spare' USING ERRCODE='23514'; END IF;
     UPDATE ref.site_power_device SET site_waypoint_id=old_device.site_waypoint_id,verification_status='UNVERIFIED',verified_at=NULL,verified_by_person_id=NULL,updated_at=clock_timestamp() WHERE site_power_device_id=replacement;
     destination:=NULL;
    ELSIF replacement IS NOT NULL OR destination IS NOT DISTINCT FROM old_device.site_waypoint_id THEN
     RAISE EXCEPTION 'Choose a changed waypoint or remove to spares' USING ERRCODE='22023';
    END IF;
    UPDATE ref.site_power_device SET site_waypoint_id=destination,verification_status='UNVERIFIED',verified_at=NULL,verified_by_person_id=NULL,updated_at=clock_timestamp() WHERE site_power_device_id=p_id;
   END IF;
   INSERT INTO ops.site_equipment_event(site_power_device_id,event_kind,condition,observed_at,from_waypoint_id,to_waypoint_id,replacement_device_id,corrects_event_id,notes,directus_user_id,person_id,operator_email)
   VALUES(p_id,event_type,p_data->>'condition',observed,old_device.site_waypoint_id,destination,replacement,corrected,coalesce(p_data->>'notes',''),actor.directus_user_id,actor.person_id,lower(btrim(p_email)))
   RETURNING event_id,to_jsonb(site_equipment_event) INTO target,after_row;
   UPDATE ref.site_power_revision SET revision=revision+1 WHERE singleton RETURNING revision INTO rev;
   INSERT INTO ops.site_power_edit_log(revision,request_id,command,target_id,payload,before_data,after_data,directus_user_id,person_id,operator_email)
   VALUES(rev,p_request,p_kind,target,jsonb_build_object('id',p_id,'fields',request_fields),to_jsonb(old_device)||jsonb_build_object('replacement_before',to_jsonb(spare)),after_row,actor.directus_user_id,actor.person_id,lower(btrim(p_email)));
   RETURN jsonb_build_object('revision',rev,'target_id',target,'replayed',false);
  END;
 END IF;
$branch$;
SELECT pg_get_functiondef('ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure) INTO definition;
IF length(definition)-length(replace(definition,anchor,''))<>length(anchor) THEN RAISE EXCEPTION 'Equipment command anchor mismatch'; END IF;
EXECUTE replace(definition,anchor,addition||anchor);
SELECT pg_get_functiondef('ref.site_power_snapshot(text)'::regprocedure) INTO definition;
anchor:=' RETURN result||jsonb_build_object(';
IF length(definition)-length(replace(definition,anchor,''))<>length(anchor) THEN RAISE EXCEPTION 'Equipment snapshot anchor mismatch'; END IF;
EXECUTE replace(definition,anchor,$addition$
 result:=result||jsonb_build_object('equipment_events',coalesce((SELECT jsonb_agg(to_jsonb(e)||jsonb_build_object('operator_name',coalesce(nullif(btrim(concat_ws(' ',u.first_name,u.last_name)),''),'Name unavailable')) ORDER BY e.event_id DESC) FROM ops.site_equipment_event e LEFT JOIN public.directus_users u ON u.id=e.directus_user_id),'[]'::jsonb));
 RETURN result||jsonb_build_object($addition$);
END $migration$;
COMMIT;
