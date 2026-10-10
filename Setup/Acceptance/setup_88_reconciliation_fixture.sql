-- Local synthetic PostgreSQL fixture only. Never run against MSB or a Production
-- clone: current-clone validation uses the real actor, constraints and triggers.
CREATE SCHEMA ref;
CREATE SCHEMA ops;
CREATE ROLE fieldwiring_app;
CREATE TABLE ref.container_type(container_type_id integer PRIMARY KEY,container_type_name text);
CREATE TABLE ref.container(container_id integer PRIMARY KEY,container_type_id integer,location_code text,description text);
CREATE TABLE ref.display_status(display_status_id integer PRIMARY KEY,display_status_name text);
CREATE TABLE ref.display(display_id bigint PRIMARY KEY,container_id integer,display_status_id integer,display_name text);
CREATE TABLE ref.stage(stage_id integer PRIMARY KEY,stage_key text,stage_name text);
CREATE TABLE ref.lor_scene(lor_scene_id bigint PRIMARY KEY,stage_id integer REFERENCES ref.stage);
CREATE TABLE ref.lor_scene_display(lor_scene_id bigint REFERENCES ref.lor_scene,display_id bigint REFERENCES ref.display);
INSERT INTO ref.stage VALUES(15,'15','Church-ParkingLot'),(16,'16','Actual placement elsewhere');
CREATE TABLE ops.setup_session(setup_session_id bigint PRIMARY KEY,season_year integer,session_status text);
CREATE TABLE ops.setup_movement_event(
 setup_movement_event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 setup_session_id bigint,event_type text,container_id integer,destination_stage_id integer,
 destination_location_note text,occurred_at timestamptz,notes text,client_event_id uuid UNIQUE,
 received_at timestamptz,device_id text,captured_operator_email text,captured_operator_person_id integer,
 capture_method text,offline_captured boolean,gps_latitude numeric,gps_longitude numeric,gps_accuracy_m numeric,
 gps_fix_at timestamptz,gps_fix_age_ms integer,gps_quality text,gps_quality_note text,source_location_code text);
CREATE TABLE ops.setup_movement_event_display(setup_movement_event_id bigint,display_id bigint,movement_effect text);
CREATE TABLE ops.setup_container_state(
 setup_session_id bigint,container_id integer,current_stage_id integer,current_location_note text,
 last_movement_event_id bigint,movement_status text,last_movement_at timestamptz,
 CONSTRAINT pk_setup_container_state PRIMARY KEY(setup_session_id,container_id));
CREATE TABLE ops.setup_display_state(
 setup_session_id bigint,display_id bigint,position_mode text,current_stage_id integer,current_location_note text,
 last_movement_event_id bigint,movement_status text,last_movement_at timestamptz,
 CONSTRAINT pk_setup_display_state PRIMARY KEY(setup_session_id,display_id));
CREATE FUNCTION ref.setup_movement_actor(text) RETURNS TABLE(directus_user_id uuid,person_id integer,display_name text)
 LANGUAGE sql AS $$ SELECT '88000000-0000-4000-8000-000000000001'::uuid,1,'Local fixture operator'::text $$;
INSERT INTO ref.container_type VALUES(1,'Pallet'),(2,'Kit Box'),(3,'Display Pallet'),(4,'Standalone Display');
INSERT INTO ref.display_status VALUES(1,'ACTIVE'),(2,'RECYCLED');
INSERT INTO ref.container VALUES(95,1,'RC01-A-01','Angel3D'),(216,1,'RC02-A-01','Panels'),(30,1,'RC03-A-01','Bells'),
 (199,4,'RC04-A-01','Bruce'),(177,3,'RC05-A-01','Singular'),(149,3,'RC06-A-01','Multi Display Pallet'),(222,1,'RC07-A-01','No prior observation');
INSERT INTO ref.display VALUES(1,95,1,'Angel3D-02'),(2,216,1,'WV-MtCrumpitPanel-01'),(3,216,1,'CH-PeaceOnEarth'),
 (4,30,1,'CH-Bell-01'),(5,199,1,'Bruce the Spruce'),(6,177,1,'CH-Steeple'),
 (7,149,1,'Santa'),(8,149,1,'Sleigh'),(9,222,1,'Unobserved'),(10,216,2,'Inactive');
INSERT INTO ops.setup_session VALUES(2,2026,'ACTIVE');

-- Mirror the movement/state CHECK contracts actually retained from migration 065.
ALTER TABLE ops.setup_movement_event ADD CONSTRAINT fixture_event_type CHECK(event_type IN
 ('CONTAINER_MOVE','TASK_UNLOAD','DISPLAY_MOVE','DISPLAY_REATTACH','TASK_COMPLETION_RECONCILE',
  'PICKED','LOADED','IN_TRANSIT','DELIVERED','UNLOADED','STAGED','PLACED','RELOCATED','RETURNED'));
ALTER TABLE ops.setup_movement_event ADD CONSTRAINT fixture_destination CHECK(event_type IN ('PICKED','LOADED','IN_TRANSIT','RETURNED')
 OR destination_stage_id IS NOT NULL OR nullif(btrim(destination_location_note),'') IS NOT NULL
 OR (gps_latitude IS NOT NULL AND gps_longitude IS NOT NULL));
ALTER TABLE ops.setup_movement_event ADD CONSTRAINT fixture_gps_pair CHECK((gps_latitude IS NULL)=(gps_longitude IS NULL));
ALTER TABLE ops.setup_movement_event ADD FOREIGN KEY(destination_stage_id) REFERENCES ref.stage;
ALTER TABLE ops.setup_movement_event_display ADD PRIMARY KEY(setup_movement_event_id,display_id);
ALTER TABLE ops.setup_movement_event_display ADD FOREIGN KEY(setup_movement_event_id) REFERENCES ops.setup_movement_event;
ALTER TABLE ops.setup_movement_event_display ADD FOREIGN KEY(display_id) REFERENCES ref.display;
ALTER TABLE ops.setup_movement_event_display ADD CONSTRAINT fixture_effect CHECK(movement_effect IN ('UNLOADED','MOVED','REATTACHED','VERIFIED_PRESENT'));
ALTER TABLE ops.setup_display_state ADD FOREIGN KEY(last_movement_event_id) REFERENCES ops.setup_movement_event;
ALTER TABLE ops.setup_display_state ADD CONSTRAINT fixture_mode CHECK(position_mode IN ('WITH_CONTAINER','DETACHED'));
ALTER TABLE ops.setup_display_state ADD CONSTRAINT fixture_detached_location CHECK(position_mode<>'DETACHED'
 OR current_stage_id IS NOT NULL OR nullif(btrim(current_location_note),'') IS NOT NULL
 OR movement_status IN ('PICKED','LOADED','IN_TRANSIT','DELIVERED','UNLOADED','STAGED','PLACED','RELOCATED','RETURNED','DISPLAY_MOVE','TASK_UNLOAD'));
