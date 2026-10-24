-- #171/#230 under #122. Candidate only; NOT a Production execution instruction.
-- Requires the #319 waypoint foundation. Replaces the UNINSTALLED draft power
-- portion of 171_site_reference_operations_candidate.sql; do not apply both.
BEGIN;
DO $gate$ BEGIN
 IF to_regclass('ref.site_waypoint') IS NULL OR to_regclass('ref.site_waypoint_alias') IS NULL
 OR to_regprocedure('ref.setup_inventory_actor(text,boolean)') IS NULL THEN
  RAISE EXCEPTION 'Accepted GIS waypoint/alias foundation and existing Directus actor resolver required';
 END IF;
 IF to_regclass('ref.site_panel') IS NOT NULL THEN
  RAISE EXCEPTION 'Power schema already exists; reconcile installed migration, do not replay';
 END IF;
END $gate$;
CREATE TABLE ref.site_power_revision (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton), revision bigint NOT NULL DEFAULT 0);
INSERT INTO ref.site_power_revision DEFAULT VALUES;
CREATE TABLE ref.site_panel (
 site_panel_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 panel_name text NOT NULL CHECK (btrim(panel_name)<>''),
 site_waypoint_id bigint REFERENCES ref.site_waypoint(site_waypoint_id),
 owner_name text, panel_identification text, meter_information text,
 active boolean NOT NULL DEFAULT true,
 source_evidence text,
 verification_status text NOT NULL DEFAULT 'UNVERIFIED' CHECK (verification_status IN ('UNKNOWN','UNVERIFIED','VERIFIED','CONFLICTING')),
 verified_by_person_id integer REFERENCES ref.person(person_id), verified_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK ((verification_status='VERIFIED')=(verified_by_person_id IS NOT NULL AND verified_at IS NOT NULL))
);
CREATE TABLE ref.site_power_circuit (
 site_power_circuit_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 site_panel_id bigint NOT NULL REFERENCES ref.site_panel(site_panel_id),
 circuit_code text NOT NULL CHECK (btrim(circuit_code)<>''),
 description text, breaker_rating_amps numeric CHECK (breaker_rating_amps>0),
 voltage numeric CHECK (voltage>0), poles integer CHECK (poles>0), ganged_device text,
 show_desired_state text NOT NULL DEFAULT 'UNKNOWN' CHECK (show_desired_state IN ('UNKNOWN','ON','OFF')),
 restoration_desired_state text NOT NULL DEFAULT 'UNKNOWN' CHECK (restoration_desired_state IN ('UNKNOWN','ON','OFF')),
 active boolean NOT NULL DEFAULT true,
 source_evidence text,
 verification_status text NOT NULL DEFAULT 'UNVERIFIED' CHECK (verification_status IN ('UNKNOWN','UNVERIFIED','VERIFIED','CONFLICTING')),
 verified_by_person_id integer REFERENCES ref.person(person_id), verified_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK ((verification_status='VERIFIED')=(verified_by_person_id IS NOT NULL AND verified_at IS NOT NULL))
);
CREATE TABLE ref.site_power_device (
 site_power_device_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 device_name text NOT NULL CHECK (btrim(device_name)<>''),
 device_kind text NOT NULL CHECK (device_kind IN ('FUSE','DISCONNECT','OUTLET','LIGHT_POLE','OTHER')),
 site_waypoint_id bigint REFERENCES ref.site_waypoint(site_waypoint_id),
 owner_name text, utility_asset_id text, rating text, description text,
 active boolean NOT NULL DEFAULT true,
 source_evidence text,
 verification_status text NOT NULL DEFAULT 'UNVERIFIED' CHECK (verification_status IN ('UNKNOWN','UNVERIFIED','VERIFIED','CONFLICTING')),
 verified_by_person_id integer REFERENCES ref.person(person_id), verified_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK ((verification_status='VERIFIED')=(verified_by_person_id IS NOT NULL AND verified_at IS NOT NULL))
);
CREATE TABLE ref.site_power_feed (
 site_power_feed_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 source_circuit_id bigint REFERENCES ref.site_power_circuit(site_power_circuit_id),
 source_device_id bigint REFERENCES ref.site_power_device(site_power_device_id),
 destination_waypoint_id bigint REFERENCES ref.site_waypoint(site_waypoint_id),
 destination_device_id bigint REFERENCES ref.site_power_device(site_power_device_id),
 CHECK (num_nonnulls(source_circuit_id,source_device_id)=1),
 CHECK (num_nonnulls(destination_waypoint_id,destination_device_id)=1),
 CHECK (source_device_id IS DISTINCT FROM destination_device_id OR source_device_id IS NULL),
 active boolean NOT NULL DEFAULT true,
 source_evidence text,
 verification_status text NOT NULL DEFAULT 'UNVERIFIED' CHECK (verification_status IN ('UNKNOWN','UNVERIFIED','VERIFIED','CONFLICTING')),
 verified_by_person_id integer REFERENCES ref.person(person_id), verified_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK ((verification_status='VERIFIED')=(verified_by_person_id IS NOT NULL AND verified_at IS NOT NULL))
);
CREATE TABLE ref.site_waypoint_network (
 site_waypoint_network_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 site_waypoint_id bigint NOT NULL REFERENCES ref.site_waypoint(site_waypoint_id),
 site_network_id bigint NOT NULL REFERENCES ref.site_network(site_network_id),
 active boolean NOT NULL DEFAULT true,
 source_evidence text,
 verification_status text NOT NULL DEFAULT 'UNVERIFIED' CHECK (verification_status IN ('UNKNOWN','UNVERIFIED','VERIFIED','CONFLICTING')),
 verified_by_person_id integer REFERENCES ref.person(person_id), verified_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK ((verification_status='VERIFIED')=(verified_by_person_id IS NOT NULL AND verified_at IS NOT NULL))
);
CREATE TABLE ref.site_power_action (
 site_power_action_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 action_name text NOT NULL CHECK (btrim(action_name)<>''),
 site_power_circuit_id bigint REFERENCES ref.site_power_circuit(site_power_circuit_id),
 site_power_device_id bigint REFERENCES ref.site_power_device(site_power_device_id),
 phase text NOT NULL CHECK (phase IN ('SETUP','OPERATION','RESTORATION')),
 action_kind text NOT NULL CHECK (action_kind IN ('TURN_OFF_LIGHT','REMOVE_FUSE','REQUEST_UTILITY','ENERGIZE','RESTORE','OTHER')),
 desired_state text NOT NULL DEFAULT 'UNKNOWN' CHECK (desired_state IN ('UNKNOWN','ON','OFF','REMOVED','INSTALLED')),
 responsible_party text, instructions text,
 prerequisite_action_ids bigint[] NOT NULL DEFAULT '{}',
 CHECK (num_nonnulls(site_power_circuit_id,site_power_device_id)=1),
 active boolean NOT NULL DEFAULT true,
 source_evidence text,
 verification_status text NOT NULL DEFAULT 'UNVERIFIED' CHECK (verification_status IN ('UNKNOWN','UNVERIFIED','VERIFIED','CONFLICTING')),
 verified_by_person_id integer REFERENCES ref.person(person_id), verified_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK ((verification_status='VERIFIED')=(verified_by_person_id IS NOT NULL AND verified_at IS NOT NULL))
);
CREATE UNIQUE INDEX site_power_circuit_panel_code_uq ON ref.site_power_circuit(site_panel_id,lower(btrim(circuit_code)));
CREATE UNIQUE INDEX site_power_feed_active_uq ON ref.site_power_feed(
 coalesce(source_circuit_id,0),coalesce(source_device_id,0),
 coalesce(destination_waypoint_id,0),coalesce(destination_device_id,0)) WHERE active;
CREATE UNIQUE INDEX site_waypoint_network_active_uq ON ref.site_waypoint_network(site_waypoint_id,site_network_id) WHERE active;
CREATE TABLE ops.setup_power_activity_event (
 event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 request_id uuid NOT NULL UNIQUE,
 site_power_action_id bigint NOT NULL REFERENCES ref.site_power_action(site_power_action_id),
 season_year integer NOT NULL REFERENCES ref.season(season_year),
 event_kind text NOT NULL CHECK (event_kind IN ('REPORTED','FIELD_VERIFIED','STARTED','COMPLETED','UTILITY_REQUESTED','UTILITY_CONFIRMED','EXCEPTION')),
 condition text NOT NULL CHECK (condition IN ('UNKNOWN','ON','OFF','REMOVED','INSTALLED','NOT_APPLICABLE')),
 observed_at timestamptz NOT NULL CHECK (isfinite(observed_at)),
 evidence text NOT NULL CHECK (btrim(evidence)<>''),
 corrects_event_id bigint REFERENCES ops.setup_power_activity_event(event_id),
 definition_snapshot jsonb NOT NULL,
 directus_user_id uuid NOT NULL, person_id integer NOT NULL REFERENCES ref.person(person_id),
 operator_email text NOT NULL, recorded_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE ops.site_power_edit_log (
 event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 revision bigint NOT NULL UNIQUE, request_id uuid NOT NULL UNIQUE,
 command text NOT NULL, target_id bigint NOT NULL,
 payload jsonb NOT NULL, before_data jsonb, after_data jsonb NOT NULL,
 directus_user_id uuid NOT NULL, person_id integer NOT NULL REFERENCES ref.person(person_id),
 operator_email text NOT NULL, recorded_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
-- Read capability does not invoke the identity reconciler (which can write).
CREATE FUNCTION ref.site_power_access(p_email text) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=pg_catalog,ref AS $f$
 SELECT coalesce((SELECT jsonb_build_object('can_read',can_read_setup,
 'can_edit',coalesce(can_manage_setup,false) OR role_name='Production Crew' OR 'Production Crew'=ANY(policy_names),
 'display_name',display_name)
 FROM ref.setup_browser_capabilities(p_email)), '{"can_read":false,"can_edit":false}'::jsonb)
$f$;
CREATE FUNCTION ref.site_power_snapshot(p_email text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,ref,ops AS $f$
DECLARE access jsonb:=ref.site_power_access(p_email); result jsonb;
BEGIN
 IF NOT coalesce((access->>'can_read')::boolean,false) THEN
 RAISE EXCEPTION 'FieldWiring circuit access denied' USING ERRCODE='42501'; END IF;
 SELECT jsonb_build_object('revision',revision,'access',access) INTO result FROM ref.site_power_revision;
 result:=result||jsonb_build_object('panels',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY 1) FROM ref.site_panel t),'[]'::jsonb));
 result:=result||jsonb_build_object('circuits',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY 1) FROM ref.site_power_circuit t),'[]'::jsonb));
 result:=result||jsonb_build_object('devices',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY 1) FROM ref.site_power_device t),'[]'::jsonb));
 result:=result||jsonb_build_object('feeds',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY 1) FROM ref.site_power_feed t),'[]'::jsonb));
 result:=result||jsonb_build_object('networks',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY 1) FROM ref.site_waypoint_network t),'[]'::jsonb));
 result:=result||jsonb_build_object('actions',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY 1) FROM ref.site_power_action t),'[]'::jsonb));
 RETURN result||jsonb_build_object(
 'waypoints',coalesce((SELECT jsonb_agg(jsonb_build_object('id',w.site_waypoint_id,'name',w.canonical_label,'type',w.waypoint_type,
 'aliases',coalesce((SELECT jsonb_agg(a.alias_text) FROM ref.site_waypoint_alias a WHERE a.site_waypoint_id=w.site_waypoint_id AND a.accepted_at IS NOT NULL AND a.accepted_by IS NOT NULL),'[]'::jsonb)) ORDER BY w.canonical_label) FROM ref.site_waypoint w),'[]'::jsonb),
 'network_options',coalesce((SELECT jsonb_agg(to_jsonb(n) ORDER BY n.network_code) FROM ref.site_network n),'[]'::jsonb),
 'seasons',coalesce((SELECT jsonb_agg(season_year ORDER BY season_year DESC) FROM ref.season),'[]'::jsonb),
 'events',coalesce((SELECT jsonb_agg(to_jsonb(e) ORDER BY event_id DESC) FROM ops.setup_power_activity_event e),'[]'::jsonb),
 'history',coalesce((SELECT jsonb_agg(to_jsonb(h) ORDER BY event_id DESC) FROM ops.site_power_edit_log h),'[]'::jsonb));
END $f$;
CREATE FUNCTION ref.site_power_command(p_email text,p_request uuid,p_revision bigint,p_kind text,p_id bigint,p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ref,ops AS $f$
DECLARE actor record; rev bigint; before_row jsonb; after_row jsonb; prior ops.site_power_edit_log%ROWTYPE;
 allowed text[]; expected jsonb; verified integer; verified_time timestamptz; target bigint;
 table_name text; key_name text; columns_sql text; values_sql text; updates_sql text;
 action_row ref.site_power_action%ROWTYPE; event_target bigint;
BEGIN
 -- Fail closed even if a legacy actor resolver returns NULL for an unassigned role.
 IF NOT coalesce((ref.site_power_access(p_email)->>'can_edit')::boolean,false) THEN
  RAISE EXCEPTION 'Production Crew circuit access required' USING ERRCODE='42501'; END IF;
 -- Reuse Directus roles and existing human reconciliation; never accept a client actor.
 SELECT * INTO STRICT actor FROM ref.setup_inventory_actor(p_email,false);
 IF p_request IS NULL OR p_revision IS NULL OR p_revision<0 OR p_data IS NULL OR jsonb_typeof(p_data)<>'object' THEN
 RAISE EXCEPTION 'Request ID, revision and structured fields required' USING ERRCODE='22023'; END IF;
 SELECT revision INTO rev FROM ref.site_power_revision WHERE singleton FOR UPDATE;
 SELECT * INTO prior FROM ops.site_power_edit_log WHERE request_id=p_request;
 IF FOUND THEN
  IF prior.operator_email IS DISTINCT FROM lower(btrim(p_email)) OR prior.command IS DISTINCT FROM p_kind
     OR prior.payload IS DISTINCT FROM jsonb_build_object('id',p_id,'fields',p_data) THEN
   RAISE EXCEPTION 'Request ID reused with different content' USING ERRCODE='22023'; END IF;
  RETURN jsonb_build_object('revision',prior.revision,'target_id',prior.target_id,'replayed',true);
 END IF;
 IF rev<>p_revision THEN RAISE EXCEPTION 'Another edit was saved. Reload before saving your changes.' USING ERRCODE='40001'; END IF;
 IF p_kind='event' THEN
  allowed:=ARRAY['site_power_action_id','season_year','event_kind','condition','observed_at','evidence','corrects_event_id'];
 ELSE
  CASE p_kind
  WHEN 'panel' THEN table_name:='site_panel'; key_name:='site_panel_id'; allowed:=ARRAY['panel_name','site_waypoint_id','owner_name','panel_identification','meter_information','active','source_evidence','verification_status'];
  WHEN 'circuit' THEN table_name:='site_power_circuit'; key_name:='site_power_circuit_id'; allowed:=ARRAY['site_panel_id','circuit_code','description','breaker_rating_amps','voltage','poles','ganged_device','show_desired_state','restoration_desired_state','active','source_evidence','verification_status'];
  WHEN 'device' THEN table_name:='site_power_device'; key_name:='site_power_device_id'; allowed:=ARRAY['device_name','device_kind','site_waypoint_id','owner_name','utility_asset_id','rating','description','active','source_evidence','verification_status'];
  WHEN 'feed' THEN table_name:='site_power_feed'; key_name:='site_power_feed_id'; allowed:=ARRAY['source_circuit_id','source_device_id','destination_waypoint_id','destination_device_id','active','source_evidence','verification_status'];
  WHEN 'network' THEN table_name:='site_waypoint_network'; key_name:='site_waypoint_network_id'; allowed:=ARRAY['site_waypoint_id','site_network_id','active','source_evidence','verification_status'];
  WHEN 'action' THEN table_name:='site_power_action'; key_name:='site_power_action_id'; allowed:=ARRAY['action_name','site_power_circuit_id','site_power_device_id','phase','action_kind','desired_state','responsible_party','instructions','prerequisite_action_ids','active','source_evidence','verification_status'];
  ELSE RAISE EXCEPTION 'Unknown circuit command' USING ERRCODE='22023'; END CASE;
 END IF;
 IF EXISTS(SELECT 1 FROM jsonb_object_keys(p_data) k WHERE NOT k=ANY(allowed)) THEN
 RAISE EXCEPTION 'Unrecognized or protected field' USING ERRCODE='22023'; END IF;
 IF p_kind='event' THEN
  IF p_id IS NOT NULL THEN RAISE EXCEPTION 'Activity events are append-only' USING ERRCODE='22023'; END IF;
  SELECT * INTO action_row FROM ref.site_power_action WHERE site_power_action_id=(p_data->>'site_power_action_id')::bigint;
  IF NOT FOUND OR NOT action_row.active THEN RAISE EXCEPTION 'Active action required' USING ERRCODE='22023'; END IF;
  IF action_row.action_kind='REQUEST_UTILITY' AND p_data->>'event_kind'='COMPLETED' THEN
   RAISE EXCEPTION 'Record utility work as UTILITY_CONFIRMED, not generic completion' USING ERRCODE='22023'; END IF;
  IF p_data->>'event_kind' IN ('UTILITY_REQUESTED','UTILITY_CONFIRMED') AND action_row.action_kind<>'REQUEST_UTILITY' THEN
   RAISE EXCEPTION 'Utility events require a utility action' USING ERRCODE='22023'; END IF;
  IF (p_data->>'observed_at')::timestamptz>clock_timestamp()+interval '5 minutes' THEN
   RAISE EXCEPTION 'Observation time is in the future' USING ERRCODE='22023'; END IF;
  IF p_data->>'corrects_event_id' IS NOT NULL AND NOT EXISTS(SELECT 1 FROM ops.setup_power_activity_event
     WHERE event_id=(p_data->>'corrects_event_id')::bigint AND site_power_action_id=action_row.site_power_action_id
     AND season_year=(p_data->>'season_year')::integer) THEN
   RAISE EXCEPTION 'Correction must reference the same action and season' USING ERRCODE='22023'; END IF;
  -- A blocked prerequisite remains explicit; completion is rejected until an
  -- uncorrected completion/utility confirmation exists in the SAME season.
  IF p_data->>'event_kind' IN ('STARTED','COMPLETED','UTILITY_CONFIRMED') AND EXISTS (
    SELECT 1 FROM unnest(action_row.prerequisite_action_ids) needed WHERE NOT EXISTS (
     SELECT 1 FROM ops.setup_power_activity_event e WHERE e.site_power_action_id=needed
      AND e.season_year=(p_data->>'season_year')::integer AND e.event_kind IN ('COMPLETED','UTILITY_CONFIRMED')
      AND NOT EXISTS(SELECT 1 FROM ops.setup_power_activity_event c WHERE c.corrects_event_id=e.event_id))) THEN
    RAISE EXCEPTION 'Prerequisite activity is not complete for this season' USING ERRCODE='23514'; END IF;
  INSERT INTO ops.setup_power_activity_event(request_id,site_power_action_id,season_year,event_kind,condition,observed_at,evidence,corrects_event_id,
   definition_snapshot,directus_user_id,person_id,operator_email)
  VALUES(p_request,action_row.site_power_action_id,(p_data->>'season_year')::integer,p_data->>'event_kind',p_data->>'condition',
   (p_data->>'observed_at')::timestamptz,p_data->>'evidence',(p_data->>'corrects_event_id')::bigint,
   to_jsonb(action_row),actor.directus_user_id,actor.person_id,lower(btrim(p_email))) RETURNING event_id,to_jsonb(setup_power_activity_event) INTO target,after_row;
 ELSE
  -- Ordinary field records are attributable through the governed actor/audit;
  -- a note or explicit verification claim is not required to save.
  IF p_data ? 'verification_status' AND
     p_data->>'verification_status' NOT IN ('UNKNOWN','UNVERIFIED','VERIFIED','CONFLICTING') THEN
    RAISE EXCEPTION 'Invalid reference verification state' USING ERRCODE='22023';
  END IF;
  IF p_id IS NOT NULL THEN
   EXECUTE format('SELECT to_jsonb(t) FROM ref.%I t WHERE %I=$1 FOR UPDATE',table_name,key_name) INTO before_row USING p_id;
   IF before_row IS NULL THEN RAISE EXCEPTION 'Record not found' USING ERRCODE='P0002'; END IF;
  END IF;
  IF p_kind IN ('feed','network') AND EXISTS (
   SELECT 1 FROM ref.site_waypoint w WHERE w.site_waypoint_id=coalesce(
     (p_data->>'destination_waypoint_id')::bigint,(p_data->>'site_waypoint_id')::bigint,
     (before_row->>'destination_waypoint_id')::bigint,(before_row->>'site_waypoint_id')::bigint)
    AND lower(btrim(w.waypoint_type)) IN ('hydrant','fire hydrant','stage','manhole')) THEN
   RAISE EXCEPTION 'This waypoint type does not carry circuit or network assignments' USING ERRCODE='22023'; END IF;
  verified:=CASE WHEN p_data->>'verification_status'='VERIFIED' THEN actor.person_id ELSE NULL END;
  verified_time:=CASE WHEN verified IS NOT NULL THEN clock_timestamp() ELSE NULL END;
  expected:=coalesce(before_row,'{}'::jsonb)||p_data||jsonb_build_object('verified_by_person_id',verified,'verified_at',verified_time,'updated_at',clock_timestamp());
  -- jsonb_populate_record enforces native PostgreSQL field types. Omitted fields
  -- retain prior values on corrections; inserts receive explicit safe defaults.
  IF p_id IS NULL THEN expected:=jsonb_build_object('verification_status','UNVERIFIED','active',true,'show_desired_state','UNKNOWN',
   'restoration_desired_state','UNKNOWN','desired_state','UNKNOWN','prerequisite_action_ids','[]'::jsonb)||expected; END IF;
  allowed:=allowed||ARRAY['verified_by_person_id','verified_at','updated_at'];
  SELECT string_agg(format('%I',k),','),string_agg(format('r.%I',k),','),string_agg(format('%I=r.%I',k,k),',')
   INTO columns_sql,values_sql,updates_sql FROM unnest(allowed) k;
  IF p_id IS NULL THEN
   EXECUTE format('INSERT INTO ref.%I (%s) SELECT %s FROM jsonb_populate_record(NULL::ref.%I,$1) r RETURNING %I,to_jsonb(%I)',
    table_name,columns_sql,values_sql,table_name,key_name,table_name) INTO target,after_row USING expected;
  ELSE
   -- Foreign identity keys cannot silently move a circuit to another panel.
   IF p_kind='circuit' AND expected->'site_panel_id' IS DISTINCT FROM before_row->'site_panel_id' THEN
    RAISE EXCEPTION 'A circuit cannot change panel identity; retire and define the correct circuit' USING ERRCODE='22023'; END IF;
   EXECUTE format('UPDATE ref.%I t SET %s FROM jsonb_populate_record(NULL::ref.%I,$1) r WHERE t.%I=$2 RETURNING t.%I,to_jsonb(t)',
    table_name,updates_sql,table_name,key_name,key_name) INTO target,after_row USING expected,p_id;
  END IF;
  -- Retirement never silently leaves an active dependent electrical relationship.
  IF NOT (after_row->>'active')::boolean AND (
   (p_kind='panel' AND EXISTS(SELECT 1 FROM ref.site_power_circuit WHERE site_panel_id=target AND active)) OR
   (p_kind='circuit' AND (EXISTS(SELECT 1 FROM ref.site_power_feed WHERE source_circuit_id=target AND active)
     OR EXISTS(SELECT 1 FROM ref.site_power_action WHERE site_power_circuit_id=target AND active))) OR
   (p_kind='device' AND (EXISTS(SELECT 1 FROM ref.site_power_feed WHERE (source_device_id=target OR destination_device_id=target) AND active)
     OR EXISTS(SELECT 1 FROM ref.site_power_action WHERE site_power_device_id=target AND active))) OR
   (p_kind='action' AND EXISTS(SELECT 1 FROM ref.site_power_action WHERE target=ANY(prerequisite_action_ids) AND active))
  ) THEN RAISE EXCEPTION 'Retire or correct active dependent records first' USING ERRCODE='23514'; END IF;
  IF (after_row->>'active')::boolean AND p_kind IN ('feed','action') AND (
    EXISTS(SELECT 1 FROM ref.site_power_circuit WHERE site_power_circuit_id=coalesce((after_row->>'source_circuit_id')::bigint,(after_row->>'site_power_circuit_id')::bigint) AND NOT active)
    OR EXISTS(SELECT 1 FROM ref.site_power_device WHERE site_power_device_id IN
      ((after_row->>'source_device_id')::bigint,(after_row->>'destination_device_id')::bigint,(after_row->>'site_power_device_id')::bigint) AND NOT active)
  ) THEN RAISE EXCEPTION 'Active relationships require active circuit/equipment records' USING ERRCODE='23514'; END IF;
  IF (after_row->>'active')::boolean AND p_kind='circuit' AND EXISTS(
    SELECT 1 FROM ref.site_panel WHERE site_panel_id=(after_row->>'site_panel_id')::bigint AND NOT active
  ) THEN RAISE EXCEPTION 'An active circuit requires an active panel' USING ERRCODE='23514'; END IF;
  IF p_kind='feed' AND EXISTS (
   WITH RECURSIVE edges AS (SELECT source_device_id a,destination_device_id b FROM ref.site_power_feed WHERE active AND source_device_id IS NOT NULL AND destination_device_id IS NOT NULL),
   walk(a,b,path,cycle) AS (SELECT a,b,ARRAY[a,b],a=b FROM edges UNION ALL
    SELECT w.a,e.b,w.path||e.b,e.b=ANY(w.path) FROM walk w JOIN edges e ON e.a=w.b WHERE NOT w.cycle)
   SELECT 1 FROM walk WHERE cycle) THEN RAISE EXCEPTION 'Documented feed would form a cycle' USING ERRCODE='23514'; END IF;
  IF p_kind='action' THEN
   IF EXISTS(SELECT 1 FROM ref.site_power_action a,unnest(a.prerequisite_action_ids) x
      WHERE NOT EXISTS(SELECT 1 FROM ref.site_power_action b WHERE b.site_power_action_id=x)) THEN
    RAISE EXCEPTION 'Prerequisite action does not exist' USING ERRCODE='23503'; END IF;
   IF EXISTS(WITH RECURSIVE walk(id,path,cycle) AS (
     SELECT target,ARRAY[target],false UNION ALL
     SELECT x,w.path||x,x=ANY(w.path) FROM walk w JOIN ref.site_power_action a ON a.site_power_action_id=w.id,
      unnest(a.prerequisite_action_ids) x WHERE NOT cycle)
     SELECT 1 FROM walk WHERE cycle) THEN RAISE EXCEPTION 'Action prerequisites form a cycle' USING ERRCODE='23514'; END IF;
  END IF;
 END IF;
 UPDATE ref.site_power_revision SET revision=revision+1 WHERE singleton RETURNING revision INTO rev;
 INSERT INTO ops.site_power_edit_log(revision,request_id,command,target_id,payload,before_data,after_data,directus_user_id,person_id,operator_email)
 VALUES(rev,p_request,p_kind,target,jsonb_build_object('id',p_id,'fields',p_data),before_row,after_row,actor.directus_user_id,actor.person_id,lower(btrim(p_email)));
 RETURN jsonb_build_object('revision',rev,'target_id',target,'replayed',false);
END $f$;
REVOKE ALL ON FUNCTION ref.site_power_access(text),ref.site_power_snapshot(text),ref.site_power_command(text,uuid,bigint,text,bigint,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.site_power_access(text),ref.site_power_snapshot(text),ref.site_power_command(text,uuid,bigint,text,bigint,jsonb) TO fieldwiring_app;
-- Override any ambient default privileges; all runtime access uses functions.
REVOKE ALL ON ref.site_panel,ref.site_power_circuit,ref.site_power_device,
 ref.site_power_feed,ref.site_waypoint_network,ref.site_power_action,ref.site_power_revision,
 ops.site_power_edit_log,ops.setup_power_activity_event FROM PUBLIC,fieldwiring_app;
-- No table/sequence writes, direct actor-function access, or Directus grants.
COMMIT;
