-- #88 owns movement evidence; #171 consumes location, not controller topology.
BEGIN;
ALTER TABLE ops.setup_movement_event
 ADD COLUMN controller_id integer REFERENCES ref.controller(controller_id),
 ADD COLUMN controller_request jsonb;
ALTER TABLE ops.setup_movement_event DROP CONSTRAINT ck_setup_movement_event_type;
ALTER TABLE ops.setup_movement_event ADD CONSTRAINT ck_setup_movement_event_type CHECK(event_type IN
 ('CONTAINER_MOVE','TASK_UNLOAD','DISPLAY_MOVE','DISPLAY_REATTACH','TASK_COMPLETION_RECONCILE',
 'PICKED','LOADED','IN_TRANSIT','DELIVERED','UNLOADED','STAGED','PLACED','RELOCATED','RETURNED','CONTROLLER_MOVE'));
ALTER TABLE ops.setup_movement_event ADD CONSTRAINT ck_setup_movement_controller CHECK
 ((controller_id IS NOT NULL) = (event_type='CONTROLLER_MOVE') AND
 (controller_id IS NULL OR (container_id IS NULL AND controller_request IS NOT NULL)));
CREATE INDEX ix_setup_movement_controller_time ON ops.setup_movement_event
 (setup_session_id,controller_id,occurred_at DESC,setup_movement_event_id DESC) WHERE controller_id IS NOT NULL;
CREATE OR REPLACE FUNCTION ops.record_setup_controller_location(
    p_email text,
    p_season_year integer,
    p_client_event_id uuid,
    p_asset_type text,
    p_asset_id bigint,
    p_movement_action text,
    p_occurred_at timestamptz,
    p_device_id text DEFAULT NULL,
    p_captured_operator_email text DEFAULT NULL,
    p_capture_method text DEFAULT 'HID_SCAN',
    p_offline_captured boolean DEFAULT false,
    p_gps_latitude numeric DEFAULT NULL,
    p_gps_longitude numeric DEFAULT NULL,
    p_gps_accuracy_m numeric DEFAULT NULL,
    p_destination_stage_id integer DEFAULT NULL,
    p_destination_location_note text DEFAULT NULL,
    p_notes text DEFAULT NULL,
    p_unloaded_display_ids bigint[] DEFAULT NULL,
    p_gps_fix_at timestamptz DEFAULT NULL,
    p_gps_fix_age_ms integer DEFAULT NULL,
    p_gps_quality text DEFAULT 'UNASSESSED',
    p_gps_quality_note text DEFAULT NULL
)
RETURNS TABLE (
    setup_movement_event_id bigint,
    setup_session_id bigint,
    asset_type text,
    asset_id bigint,
    movement_action text,
    occurred_at timestamptz,
    movement_status text,
    home_location_code text,
    duplicate_event boolean,
    unloaded_display_count integer,
    operator_display_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, ref
AS $function$
DECLARE
 actor record; captured record; sid bigint; existing ops.setup_movement_event%ROWTYPE;
 eid bigint; request_data jsonb;
BEGIN
 SELECT * INTO STRICT actor FROM ref.setup_movement_actor(p_email);
 SELECT * INTO STRICT captured FROM ref.setup_movement_actor(coalesce(nullif(btrim(p_captured_operator_email),''),p_email));
 IF p_asset_type IS DISTINCT FROM 'CONTROLLER' OR p_movement_action IS DISTINCT FROM 'CONTROLLER_MOVE'
    OR cardinality(coalesce(p_unloaded_display_ids,ARRAY[]::bigint[]))<>0 THEN
   RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Controller location requires CONTROLLER / CONTROLLER_MOVE without Display unloads';
 END IF;
 IF p_client_event_id IS NULL OR p_asset_id IS NULL OR p_asset_id<=0 OR p_occurred_at IS NULL THEN
   RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Controller identity, client event and observation time are required';
 END IF;
 IF p_capture_method IS NULL OR p_capture_method NOT IN ('HID_SCAN','CAMERA_SCAN','MANUAL_ENTRY','TOUCH_SELECT','SYSTEM')
 OR p_gps_quality IS NULL OR p_gps_quality NOT IN ('UNASSESSED','QUESTIONABLE','BAD') THEN
   RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Invalid capture method or GPS quality';
 END IF;
 IF (p_gps_latitude IS NULL)<>(p_gps_longitude IS NULL)
 OR p_gps_latitude NOT BETWEEN -90 AND 90 OR p_gps_longitude NOT BETWEEN -180 AND 180
 OR p_gps_accuracy_m<0 OR p_gps_fix_age_ms<0 THEN
   RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='Invalid GPS evidence';
 END IF;
 IF p_gps_latitude IS NULL AND p_destination_stage_id IS NULL AND nullif(btrim(p_destination_location_note),'') IS NULL THEN
   RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='Location evidence is required';
 END IF;
 SELECT ss.setup_session_id INTO STRICT sid FROM ops.setup_session ss
 WHERE ss.season_year=p_season_year AND ss.session_status NOT IN ('COMPLETE','HISTORICAL_VERIFICATION');
 IF NOT EXISTS(SELECT 1 FROM ref.controller c WHERE c.controller_id=p_asset_id) THEN
   RAISE EXCEPTION USING ERRCODE='P0002',MESSAGE='Controller was not found';
 END IF;
 -- Serialize retries of this UUID. Existing cross-asset commands retain their
 -- unique index protection; a conflicting concurrent insert rolls back intact.
 PERFORM pg_advisory_xact_lock(hashtextextended(p_client_event_id::text,88));
 request_data=jsonb_build_array(p_season_year,p_asset_type,p_asset_id,p_movement_action,p_occurred_at,
 p_device_id,lower(btrim(coalesce(p_captured_operator_email,p_email))),p_capture_method,
 coalesce(p_offline_captured,false),p_gps_latitude,p_gps_longitude,p_gps_accuracy_m,
 p_destination_stage_id,p_destination_location_note,p_notes,p_gps_fix_at,p_gps_fix_age_ms,p_gps_quality,p_gps_quality_note);
 SELECT * INTO existing FROM ops.setup_movement_event e WHERE e.client_event_id=p_client_event_id;
 IF FOUND THEN
   IF existing.controller_request IS DISTINCT FROM request_data OR existing.controller_id IS DISTINCT FROM p_asset_id THEN
     RAISE EXCEPTION USING ERRCODE='23505',MESSAGE='Client event identity already belongs to different movement evidence';
   END IF;
   RETURN QUERY SELECT existing.setup_movement_event_id,sid,'CONTROLLER'::text,p_asset_id,
   'CONTROLLER_MOVE'::text,existing.occurred_at,'CONTROLLER_MOVE'::text,NULL::text,true,0,actor.display_name::text;
   RETURN;
 END IF;
 PERFORM set_config('app.directus_user_uuid',actor.directus_user_id::text,true);
 INSERT INTO ops.setup_movement_event(setup_session_id,event_type,controller_id,controller_request,
 destination_stage_id,destination_location_note,occurred_at,notes,client_event_id,received_at,device_id,
 captured_operator_email,captured_operator_person_id,capture_method,offline_captured,
 gps_latitude,gps_longitude,gps_accuracy_m,gps_fix_at,gps_fix_age_ms,gps_quality,gps_quality_note)
 VALUES(sid,'CONTROLLER_MOVE',p_asset_id,request_data,p_destination_stage_id,nullif(btrim(p_destination_location_note),''),
 p_occurred_at,p_notes,p_client_event_id,now(),p_device_id,lower(btrim(coalesce(p_captured_operator_email,p_email))),
 captured.person_id,p_capture_method,coalesce(p_offline_captured,false),p_gps_latitude,p_gps_longitude,
 p_gps_accuracy_m,p_gps_fix_at,p_gps_fix_age_ms,p_gps_quality,p_gps_quality_note)
 RETURNING ops.setup_movement_event.setup_movement_event_id INTO eid;
 RETURN QUERY SELECT eid,sid,'CONTROLLER'::text,p_asset_id,'CONTROLLER_MOVE'::text,p_occurred_at,
 'CONTROLLER_MOVE'::text,NULL::text,false,0,actor.display_name::text;
END;
$function$;
REVOKE ALL ON FUNCTION ops.record_setup_controller_location(text,integer,uuid,text,bigint,text,timestamptz,text,text,text,boolean,numeric,numeric,numeric,integer,text,text,bigint[],timestamptz,integer,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ops.record_setup_controller_location(text,integer,uuid,text,bigint,text,timestamptz,text,text,text,boolean,numeric,numeric,numeric,integer,text,text,bigint[],timestamptz,integer,text,text) TO fieldwiring_app;
COMMIT;
