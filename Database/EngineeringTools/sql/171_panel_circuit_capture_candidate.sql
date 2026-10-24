-- #171/#230 under #122. Candidate only; NOT a Production execution instruction.
-- Requires the #319 waypoint foundation. Replaces the UNINSTALLED draft power
-- portion of the old draft. Combined order: foundation, this file, GIS operations.
BEGIN;
DO $gate$ BEGIN
 IF to_regclass('ref.site_waypoint') IS NULL OR to_regclass('ref.site_waypoint_alias') IS NULL
 OR to_regclass('ref.controller') IS NULL OR to_regclass('ref.controller_model') IS NULL
 OR to_regprocedure('ref.setup_inventory_actor(text,boolean)') IS NULL THEN
  RAISE EXCEPTION 'Accepted GIS waypoint/alias foundation and existing Directus actor resolver required';
 END IF;
 IF to_regclass('ref.site_panel') IS NOT NULL THEN
  RAISE EXCEPTION 'Power schema already exists; reconcile installed migration, do not replay';
 END IF;
END $gate$;
-- Existing controller inventory owns assets; this table owns only placement history.
CREATE TABLE ref.site_controller_installation (
 site_controller_installation_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 controller_id bigint NOT NULL REFERENCES ref.controller(controller_id),
 site_waypoint_id bigint NOT NULL REFERENCES ref.site_waypoint(site_waypoint_id),
 -- Origin remains stable; order and ending are explicit observations, never inferred.
 upstream_kind text NOT NULL DEFAULT 'UNKNOWN' CHECK (upstream_kind IN ('UNKNOWN','WAYPOINT','CONTROLLER')),
 upstream_controller_id bigint REFERENCES ref.controller(controller_id),
 chain_end text NOT NULL DEFAULT 'UNKNOWN' CHECK (chain_end IN ('UNKNOWN','TERMINATOR','RETURN_TO_ORIGIN')),
 CHECK ((upstream_kind='CONTROLLER')=(upstream_controller_id IS NOT NULL)),
 CHECK (upstream_controller_id IS DISTINCT FROM controller_id),
 CHECK (upstream_kind<>'UNKNOWN' OR chain_end='UNKNOWN'),
 active boolean NOT NULL DEFAULT true,
 source_evidence text,
 verification_status text NOT NULL DEFAULT 'UNVERIFIED' CHECK (verification_status IN ('UNKNOWN','UNVERIFIED','VERIFIED','CONFLICTING')),
 verified_by_person_id integer REFERENCES ref.person(person_id), verified_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK ((verification_status='VERIFIED')=(verified_by_person_id IS NOT NULL AND verified_at IS NOT NULL))
);
CREATE UNIQUE INDEX site_controller_one_installation ON ref.site_controller_installation(controller_id) WHERE active;
CREATE TABLE ref.site_power_revision (
 singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton), revision bigint NOT NULL DEFAULT 0);
INSERT INTO ref.site_power_revision DEFAULT VALUES;
CREATE TABLE ref.site_panel (
 site_panel_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 show_desired_state text NOT NULL DEFAULT 'UNKNOWN' CHECK(show_desired_state IN ('UNKNOWN','ON','OFF')),
 restoration_desired_state text NOT NULL DEFAULT 'UNKNOWN' CHECK(restoration_desired_state IN ('UNKNOWN','ON','OFF')),
 panel_name text NOT NULL CHECK (btrim(panel_name)<>''),
 site_waypoint_id bigint REFERENCES ref.site_waypoint(site_waypoint_id),
 owner_name text, year_installed integer CHECK (year_installed BETWEEN 1900 AND 2100), panel_identification text, meter_information text, supply_breaker_id bigint,
 supply_panel_id bigint REFERENCES ref.site_panel(site_panel_id),
 active boolean NOT NULL DEFAULT true,
 source_evidence text,
 verification_status text NOT NULL DEFAULT 'UNVERIFIED' CHECK (verification_status IN ('UNKNOWN','UNVERIFIED','VERIFIED','CONFLICTING')),
 verified_by_person_id integer REFERENCES ref.person(person_id), verified_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK ((verification_status='VERIFIED')=(verified_by_person_id IS NOT NULL AND verified_at IS NOT NULL))
);
-- Breaker identity groups poles; circuit labels never establish grouping.
CREATE TABLE ref.site_power_breaker (
 site_power_breaker_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 site_panel_id bigint NOT NULL REFERENCES ref.site_panel(site_panel_id),
 breaker_name text NOT NULL CHECK (btrim(breaker_name)<>''),
 -- Physical positions are explicit observations, never parsed from circuit IDs.
 breaker_role text NOT NULL DEFAULT 'UNKNOWN' CHECK (breaker_role IN ('UNKNOWN','MAIN','BRANCH')),
 panel_positions integer[],
 CHECK (panel_positions IS NULL OR (breaker_role='BRANCH' AND pole_count IS NOT NULL
   AND cardinality(panel_positions)=pole_count AND array_ndims(panel_positions)=1
   AND array_position(panel_positions,NULL) IS NULL AND 0<ALL(panel_positions) AND 200>=ALL(panel_positions))),
 rated_amps numeric CHECK (rated_amps>0 AND rated_amps<'Infinity'::numeric AND rated_amps=trunc(rated_amps)),
 pole_count integer CHECK (pole_count>0),
 show_desired_state text NOT NULL DEFAULT 'UNKNOWN' CHECK(show_desired_state IN ('UNKNOWN','ON','OFF')),
 restoration_desired_state text NOT NULL DEFAULT 'UNKNOWN' CHECK(restoration_desired_state IN ('UNKNOWN','ON','OFF')),
 active boolean NOT NULL DEFAULT true,
 source_evidence text,
 verification_status text NOT NULL DEFAULT 'UNVERIFIED' CHECK (verification_status IN ('UNKNOWN','UNVERIFIED','VERIFIED','CONFLICTING')),
 verified_by_person_id integer REFERENCES ref.person(person_id), verified_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK ((verification_status='VERIFIED')=(verified_by_person_id IS NOT NULL AND verified_at IS NOT NULL))
);
ALTER TABLE ref.site_panel ADD CONSTRAINT site_panel_supply_breaker_fk FOREIGN KEY(supply_breaker_id) REFERENCES ref.site_power_breaker(site_power_breaker_id);
CREATE UNIQUE INDEX site_power_one_main_uq ON ref.site_power_breaker(site_panel_id) WHERE active AND breaker_role='MAIN';
CREATE TABLE ref.site_power_circuit (
 site_power_circuit_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 site_panel_id bigint NOT NULL REFERENCES ref.site_panel(site_panel_id),
 circuit_code text NOT NULL CHECK (btrim(circuit_code)<>''),
 description text, voltage numeric CHECK (voltage>0),
 site_power_breaker_id bigint REFERENCES ref.site_power_breaker(site_power_breaker_id),
 breaker_pole integer CHECK (breaker_pole>0),
 CHECK ((site_power_breaker_id IS NULL)=(breaker_pole IS NULL)),
 show_desired_state text NOT NULL DEFAULT 'UNKNOWN' CHECK (show_desired_state IN ('UNKNOWN','ON','OFF')),
 restoration_desired_state text NOT NULL DEFAULT 'UNKNOWN' CHECK (restoration_desired_state IN ('UNKNOWN','ON','OFF')),
 active boolean NOT NULL DEFAULT true,
 source_evidence text,
 verification_status text NOT NULL DEFAULT 'UNVERIFIED' CHECK (verification_status IN ('UNKNOWN','UNVERIFIED','VERIFIED','CONFLICTING')),
 verified_by_person_id integer REFERENCES ref.person(person_id), verified_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK ((verification_status='VERIFIED')=(verified_by_person_id IS NOT NULL AND verified_at IS NOT NULL))
);
CREATE UNIQUE INDEX site_power_circuit_active_pole_uq ON ref.site_power_circuit(site_power_breaker_id,breaker_pole) WHERE active;
-- Physical cable IDs are owned by GIS; electrical facts add no second cable store.
CREATE TABLE ref.site_power_cable_spec (
 site_power_cable_spec_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 site_cable_id bigint NOT NULL UNIQUE REFERENCES ref.site_cable(site_cable_id),
 cable_specification text NOT NULL CHECK(btrim(cable_specification)<>''),
 active boolean NOT NULL DEFAULT true,
 source_evidence text,
 verification_status text NOT NULL DEFAULT 'UNVERIFIED' CHECK (verification_status IN ('UNKNOWN','UNVERIFIED','VERIFIED','CONFLICTING')),
 verified_by_person_id integer REFERENCES ref.person(person_id), verified_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK ((verification_status='VERIFIED')=(verified_by_person_id IS NOT NULL AND verified_at IS NOT NULL))
);
CREATE TABLE ref.site_power_conductor (
 site_power_conductor_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 site_cable_id bigint NOT NULL REFERENCES ref.site_cable(site_cable_id),
 conductor_label text NOT NULL CHECK(btrim(conductor_label)<>''),
 conductor_role text NOT NULL CHECK(conductor_role IN ('HOT','NEUTRAL','GROUND','UNKNOWN')),
 active boolean NOT NULL DEFAULT true,
 source_evidence text,
 verification_status text NOT NULL DEFAULT 'UNVERIFIED' CHECK (verification_status IN ('UNKNOWN','UNVERIFIED','VERIFIED','CONFLICTING')),
 verified_by_person_id integer REFERENCES ref.person(person_id), verified_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK ((verification_status='VERIFIED')=(verified_by_person_id IS NOT NULL AND verified_at IS NOT NULL))
);
CREATE TABLE ref.site_power_conductor_circuit (
 site_power_conductor_circuit_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 site_power_conductor_id bigint NOT NULL REFERENCES ref.site_power_conductor(site_power_conductor_id),
 site_power_circuit_id bigint NOT NULL REFERENCES ref.site_power_circuit(site_power_circuit_id),
 active boolean NOT NULL DEFAULT true,
 source_evidence text,
 verification_status text NOT NULL DEFAULT 'UNVERIFIED' CHECK (verification_status IN ('UNKNOWN','UNVERIFIED','VERIFIED','CONFLICTING')),
 verified_by_person_id integer REFERENCES ref.person(person_id), verified_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK ((verification_status='VERIFIED')=(verified_by_person_id IS NOT NULL AND verified_at IS NOT NULL))
);
CREATE UNIQUE INDEX site_power_conductor_label_uq ON ref.site_power_conductor(site_cable_id,lower(btrim(conductor_label))) WHERE active;
CREATE UNIQUE INDEX site_power_conductor_membership_uq ON ref.site_power_conductor_circuit(site_power_conductor_id,site_power_circuit_id) WHERE active;
CREATE TABLE ref.site_controller_power_connection (
 site_controller_power_connection_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 controller_id bigint NOT NULL REFERENCES ref.controller(controller_id),
 site_waypoint_id bigint NOT NULL REFERENCES ref.site_waypoint(site_waypoint_id),
 site_power_circuit_id bigint NOT NULL REFERENCES ref.site_power_circuit(site_power_circuit_id),
 active boolean NOT NULL DEFAULT true,
 source_evidence text,
 verification_status text NOT NULL DEFAULT 'UNVERIFIED' CHECK (verification_status IN ('UNKNOWN','UNVERIFIED','VERIFIED','CONFLICTING')),
 verified_by_person_id integer REFERENCES ref.person(person_id), verified_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK ((verification_status='VERIFIED')=(verified_by_person_id IS NOT NULL AND verified_at IS NOT NULL))
);
CREATE UNIQUE INDEX site_controller_one_power_connection ON ref.site_controller_power_connection(controller_id) WHERE active;
CREATE TABLE ref.site_power_device (
 site_power_device_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 device_name text NOT NULL CHECK (btrim(device_name)<>''),
 device_kind text NOT NULL CHECK (device_kind IN ('FUSE','DISCONNECT','OUTLET','LIGHT_POLE','POWER_SUPPLY','ETHERNET_SWITCH','POE_SWITCH','ETHERNET_EXTENDER','ETHERNET_SPLITTER','RS485_REPEATER','OTHER')),
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
 site_panel_id bigint REFERENCES ref.site_panel(site_panel_id),
 action_name text NOT NULL CHECK (btrim(action_name)<>''),
 site_power_breaker_id bigint REFERENCES ref.site_power_breaker(site_power_breaker_id),
 site_power_circuit_id bigint REFERENCES ref.site_power_circuit(site_power_circuit_id),
 site_power_device_id bigint REFERENCES ref.site_power_device(site_power_device_id),
 phase text NOT NULL CHECK (phase IN ('SETUP','OPERATION','RESTORATION')),
 action_kind text NOT NULL CHECK (action_kind IN ('TURN_OFF_LIGHT','REMOVE_FUSE','REQUEST_UTILITY','ENERGIZE','RESTORE','OTHER')),
 desired_state text NOT NULL DEFAULT 'UNKNOWN' CHECK (desired_state IN ('UNKNOWN','ON','OFF','REMOVED','INSTALLED')),
 responsible_party text, instructions text,
 prerequisite_action_ids bigint[] NOT NULL DEFAULT '{}',
 CHECK (num_nonnulls(site_panel_id,site_power_breaker_id,site_power_circuit_id,site_power_device_id)=1),
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
-- Derived availability requires a complete, directed, reviewed physical route.
-- Geometry evidence is separate from FLW physical endpoint/network membership.
CREATE VIEW ref.site_route_network_evidence AS
WITH RECURSIVE edges AS (
 SELECT cr.site_cable_id,cr.segment_order,rs.site_route_segment_id,
 CASE cr.traversal_direction WHEN 1 THEN rs.endpoint_a_waypoint_id ELSE rs.endpoint_b_waypoint_id END a,
 CASE cr.traversal_direction WHEN 1 THEN rs.endpoint_b_waypoint_id ELSE rs.endpoint_a_waypoint_id END b
 FROM ref.site_cable_route_segment cr JOIN ref.site_route_segment rs USING(site_route_segment_id)
 WHERE rs.review_status='REVIEWED' AND cr.reviewed_at>=rs.reviewed_at
 AND EXISTS(SELECT 1 FROM ref.site_route_source_track st JOIN ref.site_track t USING(site_track_id)
   WHERE st.site_route_segment_id=rs.site_route_segment_id AND st.source_class IN ('NET','PRI','HV')
   AND t.lifecycle_status='CURRENT' AND st.reviewed_at>=t.changed_at
   AND cr.reviewed_at>=st.reviewed_at)
), walk AS (
 SELECT c.site_cable_id,c.site_network_id,c.endpoint_a_waypoint_id,c.endpoint_b_waypoint_id,
 e.segment_order,e.b,ARRAY[e.a,e.b] visited
 FROM ref.site_cable c JOIN edges e USING(site_cable_id)
 WHERE e.segment_order=1 AND e.a=c.endpoint_a_waypoint_id
 AND c.lifecycle_status IN ('CURRENT','REPAIRED') AND c.reviewed_by IS NOT NULL AND c.reviewed_at IS NOT NULL
 UNION ALL
 SELECT w.site_cable_id,w.site_network_id,w.endpoint_a_waypoint_id,w.endpoint_b_waypoint_id,
 e.segment_order,e.b,w.visited||e.b FROM walk w JOIN edges e
 ON e.site_cable_id=w.site_cable_id AND e.segment_order=w.segment_order+1 AND e.a=w.b
 WHERE NOT e.b=ANY(w.visited)
)
SELECT DISTINCT v.site_waypoint_id,w.site_network_id,n.network_code,w.site_cable_id
FROM walk w JOIN ref.site_network n USING(site_network_id)
CROSS JOIN LATERAL (VALUES(w.endpoint_a_waypoint_id),(w.endpoint_b_waypoint_id)) v(site_waypoint_id)
WHERE w.b=w.endpoint_b_waypoint_id AND w.segment_order=(SELECT max(segment_order) FROM ref.site_cable_route_segment WHERE site_cable_id=w.site_cable_id);

-- LinkWare owns physical endpoint/network evidence. These read-only projections
-- never rewrite imported tests or approve GPX geometry / physical cable identity.
CREATE FUNCTION ref.site_network_key(value text) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
 SELECT CASE WHEN upper(btrim(value)) ~ '^AUX[ -]+[A-Z]$'
 THEN regexp_replace(upper(btrim(value)), '[ -]+', '-', 'g')
 ELSE upper(btrim(value)) END
$$;
CREATE FUNCTION ref.site_flw_test_time(value text) RETURNS timestamp
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE result timestamp;
BEGIN
 -- Tester clock defaults are evidence, not usable chronology. Never substitute
 -- the import timestamp or source row number for a physical test timestamp.
 IF value IS NULL OR value !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}([T ][0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?)?$' THEN RETURN NULL; END IF;
 result:=value::timestamp;
 IF extract(year FROM result)<=1970 THEN RETURN NULL; END IF;
 RETURN result;
EXCEPTION WHEN datetime_field_overflow OR invalid_datetime_format THEN RETURN NULL;
END $$;
CREATE VIEW ref.site_flw_cable_test AS
WITH proposals AS (
 SELECT r.test_uuid,r.proposal,
 CASE WHEN jsonb_array_length(r.proposal->'endpoint_candidates')=2
 AND jsonb_array_length(r.proposal->'endpoint_candidates'->0)=1
 AND jsonb_array_length(r.proposal->'endpoint_candidates'->1)=1
 THEN r.proposal->'endpoint_candidates'->0->>0 END a,
 CASE WHEN jsonb_array_length(r.proposal->'endpoint_candidates')=2
 AND jsonb_array_length(r.proposal->'endpoint_candidates'->0)=1
 AND jsonb_array_length(r.proposal->'endpoint_candidates'->1)=1
 THEN r.proposal->'endpoint_candidates'->1->>0 END b,
 ref.site_network_key(r.proposal->>'designation') network_key
 FROM ops.linkiq_intake_review r
), resolved AS (
 SELECT p.test_uuid,least(a.site_waypoint_id,b.site_waypoint_id) endpoint_a,
 greatest(a.site_waypoint_id,b.site_waypoint_id) endpoint_b,p.network_key
 FROM proposals p JOIN ref.site_waypoint a ON a.site_waypoint_id::text=p.a
 JOIN ref.site_waypoint b ON b.site_waypoint_id::text=p.b
 WHERE a.site_waypoint_id<>b.site_waypoint_id AND p.network_key IS NOT NULL
 AND NOT (coalesce(p.proposal->'reasons','[]'::jsonb) ?| ARRAY['SOURCE_DELETED','REVIEWED_BINDING_SOURCE_DISAGREEMENT','NAME_REQUIRES_REVIEW'])
), identities AS (
 -- Conflicting source appearances do not silently reassign a test's endpoints.
 SELECT test_uuid,min(endpoint_a) endpoint_a,min(endpoint_b) endpoint_b,min(network_key) network_key
 FROM resolved GROUP BY test_uuid
 HAVING count(DISTINCT (endpoint_a,endpoint_b,network_key))=1
 AND count(*)=(SELECT count(*) FROM proposals p WHERE p.test_uuid=resolved.test_uuid)
), evidence AS (
 SELECT t.test_uuid,t.test_time_local,t.test_status_code,t.test_standard,t.length_ft,t.physical_site_cable_id,i.endpoint_a,i.endpoint_b,i.network_key,
 ref.site_flw_test_time(t.test_time_local) reliable_test_time,
 coalesce('cable:'||t.physical_site_cable_id::text,
 'pair:'||i.endpoint_a||':'||i.endpoint_b||':'||i.network_key) cable_key
 FROM identities i JOIN ops.linkiq_test t USING(test_uuid)
 LEFT JOIN ref.site_cable c ON c.site_cable_id=t.physical_site_cable_id
 WHERE t.physical_site_cable_id IS NULL OR c.lifecycle_status NOT IN ('REPLACED','DESTROYED','ABANDONED','RETIRED')
), ranked AS (
 SELECT e.*,max(reliable_test_time) OVER(PARTITION BY cable_key) newest_dated_test,
 bool_or(reliable_test_time IS NULL) OVER(PARTITION BY cable_key) has_unknown_test_order
 FROM evidence e
)
SELECT r.*,reliable_test_time=newest_dated_test AS latest_reliably_dated,
 count(*) FILTER(WHERE reliable_test_time=newest_dated_test) OVER(PARTITION BY cable_key)>1 AS latest_time_tied
FROM ranked r;
CREATE VIEW ref.site_network_availability AS
SELECT DISTINCT v.site_waypoint_id,n.site_network_id,n.network_code,t.physical_site_cable_id AS site_cable_id
FROM ref.site_flw_cable_test t
JOIN ref.site_network n ON ref.site_network_key(n.network_code)=t.network_key
CROSS JOIN LATERAL (VALUES(t.endpoint_a),(t.endpoint_b)) v(site_waypoint_id)
WHERE (SELECT count(*) FROM ref.site_network x WHERE ref.site_network_key(x.network_code)=t.network_key)=1;

-- Use stable LOR prop lineage, never Display names as keys or UID as asset ID.
CREATE VIEW ref.site_controller_network_requirement AS
WITH addresses AS (
 SELECT cd.controller_id,p.network,p.uid FROM ref.controller_display cd
 JOIN ref.display d ON d.display_id=coalesce(cd.wiring_source_display_id,cd.display_id)
 JOIN lor_snap.v_current_props p ON p.raw_prop_id=d.lor_prop_id
 WHERE upper(coalesce(p.device_type,'')) NOT IN ('NONE','DMX')
 UNION
 SELECT cd.controller_id,sp.network,sp.uid FROM ref.controller_display cd
 JOIN ref.display d ON d.display_id=coalesce(cd.wiring_source_display_id,cd.display_id)
 JOIN lor_snap.v_current_props p ON p.raw_prop_id=d.lor_prop_id
 JOIN lor_snap.v_current_sub_props sp ON sp.master_prop_id=p.prop_id AND sp.import_run_id=p.import_run_id
 WHERE upper(coalesce(sp.device_type,'')) NOT IN ('NONE','DMX')
), matching AS (
 SELECT c.controller_id,ref.site_network_key(a.network) network FROM ref.controller c JOIN addresses a USING(controller_id)
 WHERE CASE WHEN btrim(a.uid) ~* '^[0-9a-f]{1,2}$'
 THEN ('x'||lpad(btrim(a.uid),2,'0'))::bit(8)::integer BETWEEN c.lor_uid_start AND c.lor_uid_end ELSE false END
)
SELECT c.controller_id,c.lor_network,
 CASE WHEN count(DISTINCT m.network)=1 AND min(m.network)=ref.site_network_key(c.lor_network)
 THEN min(m.network) END required_network,
 CASE WHEN count(DISTINCT m.network)=1 AND min(m.network)=ref.site_network_key(c.lor_network)
 THEN 'CONFIRMED' ELSE 'LOR_NETWORK_UNRESOLVED' END requirement_status
FROM ref.controller c LEFT JOIN matching m USING(controller_id) GROUP BY c.controller_id,c.lor_network;

CREATE VIEW ref.site_controller_placement_eligibility AS
SELECT DISTINCT r.controller_id,a.site_waypoint_id,r.required_network,a.site_network_id
FROM ref.site_controller_network_requirement r JOIN ref.site_network_availability a
 ON ref.site_network_key(a.network_code)=r.required_network
JOIN ref.site_network n USING(site_network_id)
WHERE r.requirement_status='CONFIRMED' AND n.network_kind='LOR'
AND (SELECT count(*) FROM ref.site_network x WHERE ref.site_network_key(x.network_code)=r.required_network)=1;

-- Recorded amps are not verified branch-input amps. Keep physical-copy loads
-- distinct, and exclude ambiguous many-controller allocation from the subtotal.
CREATE VIEW ref.site_circuit_load_lineage AS
SELECT d.display_id,d.display_name,d.amps_measured,cd.controller_id,cd.wiring_source_display_id,
 cp.site_power_circuit_id,cp.site_waypoint_id,
 (SELECT count(DISTINCT x.controller_id) FROM ref.controller_display x WHERE x.display_id=d.display_id) controller_count,
 CASE WHEN d.display_status_id<>1 THEN 'INACTIVE_DISPLAY'
 WHEN (SELECT count(DISTINCT x.controller_id) FROM ref.controller_display x WHERE x.display_id=d.display_id)<>1 THEN 'AMBIGUOUS_CONTROLLER'
 WHEN cp.site_power_circuit_id IS NULL THEN 'NO_POWER_CONNECTION'
 WHEN d.amps_measured IS NULL THEN 'MISSING_AMPS'
 WHEN d.amps_measured=0 THEN 'ZERO_UNVERIFIED'
 WHEN d.amps_measured<0 OR d.amps_measured>='Infinity'::numeric THEN 'INVALID_AMPS'
 ELSE 'RECORDED_BASIS_UNVERIFIED' END load_status
FROM ref.display d LEFT JOIN ref.controller_display cd USING(display_id)
LEFT JOIN ref.site_controller_power_connection cp ON cp.controller_id=cd.controller_id AND cp.active;
CREATE VIEW ref.site_circuit_load AS
WITH physical AS (
 SELECT DISTINCT site_power_circuit_id,display_id,amps_measured,load_status FROM ref.site_circuit_load_lineage
), sums AS (
 SELECT site_power_circuit_id,
 sum(amps_measured) FILTER(WHERE load_status='RECORDED_BASIS_UNVERIFIED') recorded_display_amps,
 count(*) FILTER(WHERE load_status<>'RECORDED_BASIS_UNVERIFIED') unresolved_displays
 FROM physical GROUP BY site_power_circuit_id
)
SELECT c.site_power_circuit_id,c.site_power_breaker_id,c.breaker_pole,c.voltage,b.rated_amps,
 s.recorded_display_amps,s.unresolved_displays,
 b.rated_amps-s.recorded_display_amps nominal_headroom_amps,
 100*s.recorded_display_amps/nullif(b.rated_amps,0) nominal_utilization_percent,
 'INCOMPLETE'::text completeness,
 ARRAY['AMP_BASIS_AND_VOLTAGE_UNVERIFIED','SELF_AND_AUXILIARY_LOAD_UNKNOWN','FIELD_LOAD_UNCONFIRMED','CONDUCTOR_RECEPTACLE_AND_CONTINUOUS_LOAD_LIMITS_UNVERIFIED']::text[] warnings
FROM ref.site_power_circuit c LEFT JOIN ref.site_power_breaker b USING(site_power_breaker_id)
LEFT JOIN sums s USING(site_power_circuit_id) WHERE c.active;

-- Recorded feed topology remains separate from plans and observed voltage.
CREATE VIEW ref.site_waypoint_power_sources AS
WITH RECURSIVE paths AS (
 SELECT f.source_circuit_id site_power_circuit_id,f.destination_waypoint_id,
 f.destination_device_id,ARRAY[f.site_power_feed_id] feed_ids,ARRAY[f.verification_status] verification_states
 FROM ref.site_power_feed f WHERE f.active AND f.source_circuit_id IS NOT NULL
 UNION ALL
 SELECT p.site_power_circuit_id,f.destination_waypoint_id,f.destination_device_id,
 p.feed_ids||f.site_power_feed_id,p.verification_states||f.verification_status
 FROM paths p JOIN ref.site_power_feed f ON f.source_device_id=p.destination_device_id
 WHERE f.active AND NOT f.site_power_feed_id=ANY(p.feed_ids)
)
SELECT p.*,coalesce(p.destination_waypoint_id,d.site_waypoint_id) site_waypoint_id,
 c.site_panel_id,c.site_power_breaker_id,c.breaker_pole
FROM paths p LEFT JOIN ref.site_power_device d ON d.site_power_device_id=p.destination_device_id
JOIN ref.site_power_circuit c USING(site_power_circuit_id);

CREATE FUNCTION ref.site_power_access(p_email text) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=pg_catalog,ref AS $f$
 SELECT coalesce((SELECT jsonb_build_object('can_read',can_read_setup,
 'can_edit',coalesce(can_manage_setup,false) OR role_name='Production Crew' OR 'Production Crew'=ANY(policy_names),
 'display_name',display_name)
 FROM ref.setup_browser_capabilities(p_email)), '{"can_read":false,"can_edit":false}'::jsonb)
$f$;
-- Recorded reachability is not proof of de-energization or complete topology.
CREATE FUNCTION ref.site_power_breaker_impact(p_email text,p_breaker bigint) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=pg_catalog,ref AS $f$
DECLARE result jsonb; b ref.site_power_breaker%ROWTYPE; affected_panels bigint[];
BEGIN
 IF NOT coalesce((ref.site_power_access(p_email)->>'can_read')::boolean,false) THEN
  RAISE EXCEPTION 'FieldWiring circuit access denied' USING ERRCODE='42501'; END IF;
 SELECT * INTO b FROM ref.site_power_breaker WHERE site_power_breaker_id=p_breaker;
 IF NOT FOUND THEN RAISE EXCEPTION 'Breaker not found' USING ERRCODE='P0002'; END IF;
 WITH RECURSIVE supplied_panels(id) AS (
  SELECT site_panel_id FROM ref.site_panel WHERE active AND
   (supply_breaker_id=p_breaker OR (b.breaker_role='MAIN' AND (site_panel_id=b.site_panel_id OR supply_panel_id=b.site_panel_id)))
  UNION SELECT p.site_panel_id FROM supplied_panels s JOIN ref.site_panel p ON p.active AND
    (p.supply_panel_id=s.id OR EXISTS(SELECT 1 FROM ref.site_power_breaker upstream WHERE upstream.site_panel_id=s.id AND upstream.active AND p.supply_breaker_id=upstream.site_power_breaker_id))
 ) SELECT coalesce(array_agg(id),ARRAY[]::bigint[]) INTO affected_panels FROM supplied_panels;
 WITH RECURSIVE walk AS (
  SELECT c.site_power_circuit_id,c.breaker_pole,f.destination_waypoint_id,f.destination_device_id,
   ARRAY[f.site_power_feed_id] edge_ids,ARRAY[coalesce(f.destination_device_id,0)] device_ids,
   ARRAY[b.verification_status,c.verification_status,f.verification_status] verification_states
  FROM ref.site_power_circuit c JOIN ref.site_power_feed f ON f.source_circuit_id=c.site_power_circuit_id AND f.active
  WHERE (c.site_power_breaker_id=p_breaker OR c.site_panel_id=ANY(affected_panels)) AND c.active
  UNION ALL
  SELECT w.site_power_circuit_id,w.breaker_pole,f.destination_waypoint_id,f.destination_device_id,
   w.edge_ids||f.site_power_feed_id,w.device_ids||coalesce(f.destination_device_id,0),w.verification_states||f.verification_status
  FROM walk w JOIN ref.site_power_feed f ON f.source_device_id=w.destination_device_id AND f.active
  WHERE NOT coalesce(f.destination_device_id=ANY(w.device_ids),false)
 ), endpoints AS (
  SELECT w.*,coalesce(w.destination_waypoint_id,d.site_waypoint_id) waypoint_id,
   d.verification_status device_verification FROM walk w LEFT JOIN ref.site_power_device d ON d.site_power_device_id=w.destination_device_id
 ) SELECT coalesce(jsonb_agg(to_jsonb(e)||jsonb_build_object('waypoint_name',w.canonical_label)),'[]'::jsonb)
 INTO result FROM endpoints e LEFT JOIN ref.site_waypoint w ON w.site_waypoint_id=e.waypoint_id;
 RETURN jsonb_build_object('breaker',to_jsonb(b),'revision',(SELECT revision FROM ref.site_power_revision),
  'affected_panel_ids',to_jsonb(affected_panels),'paths',result,'coverage','RECORDED_ONLY_NOT_PROOF_OF_ISOLATION',
  'missing_pole_membership',EXISTS(SELECT 1 FROM ref.site_power_circuit WHERE site_panel_id=ANY(affected_panels) AND active AND site_power_breaker_id IS NULL) OR CASE WHEN b.breaker_role='MAIN' THEN false ELSE b.pole_count IS NULL OR b.pole_count<>(SELECT count(*) FROM ref.site_power_circuit WHERE site_power_breaker_id=p_breaker AND active) END,
  'controller_connections',coalesce((SELECT jsonb_agg(to_jsonb(cp)) FROM ref.site_controller_power_connection cp JOIN ref.site_power_circuit c USING(site_power_circuit_id) WHERE cp.active AND c.active AND (c.site_power_breaker_id=p_breaker OR c.site_panel_id=ANY(affected_panels))),'[]'::jsonb),
  'circuits',coalesce((SELECT jsonb_agg(site_power_circuit_id) FROM ref.site_power_circuit WHERE (site_power_breaker_id=p_breaker OR site_panel_id=ANY(affected_panels)) AND active),'[]'::jsonb));
END $f$;
REVOKE ALL ON FUNCTION ref.site_power_breaker_impact(text,bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.site_power_breaker_impact(text,bigint) TO fieldwiring_app;
CREATE FUNCTION ref.site_power_snapshot(p_email text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path=pg_catalog,ref,ops AS $f$
DECLARE access jsonb:=ref.site_power_access(p_email); result jsonb;
BEGIN
 IF NOT coalesce((access->>'can_read')::boolean,false) THEN
 RAISE EXCEPTION 'FieldWiring circuit access denied' USING ERRCODE='42501'; END IF;
 SELECT jsonb_build_object('revision',revision,'access',access) INTO result FROM ref.site_power_revision;
 result:=result||jsonb_build_object('network_requirements',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM ref.site_controller_network_requirement t),'[]'::jsonb));
 result:=result||jsonb_build_object('placement_eligibility',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM ref.site_controller_placement_eligibility t),'[]'::jsonb));
 result:=result||jsonb_build_object('flw_cable_tests',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM ref.site_flw_cable_test t),'[]'::jsonb));
 result:=result||jsonb_build_object('circuit_loads',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM ref.site_circuit_load t),'[]'::jsonb));
 result:=result||jsonb_build_object('load_lineage',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM ref.site_circuit_load_lineage t),'[]'::jsonb));
 result:=result||jsonb_build_object('waypoint_power_sources',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM ref.site_waypoint_power_sources t),'[]'::jsonb));
 result:=result||jsonb_build_object('route_evidence',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM ref.site_route_source_track t),'[]'::jsonb),'linkiq_evidence',coalesce((SELECT jsonb_agg(jsonb_build_object('test_uuid',t.test_uuid,'cable_id',t.physical_site_cable_id,'endpoint_a',c.endpoint_a_waypoint_id,'endpoint_b',c.endpoint_b_waypoint_id,'test_time',t.test_time_local,'status_code',t.test_status_code,'review_status',t.identity_review_status,'source_sha256',t.first_seen_source_sha256,'test_standard',t.test_standard,'length_ft',t.length_ft,'original_name',t.tester_original_name,'source_pair',(SELECT r.proposal || jsonb_build_object('source_sha256',r.source_sha256) FROM ops.linkiq_intake_review r WHERE r.test_uuid=t.test_uuid ORDER BY r.recorded_at DESC,r.source_sha256 LIMIT 1))) FROM ops.linkiq_test t LEFT JOIN ref.site_cable c ON c.site_cable_id=t.physical_site_cable_id),'[]'::jsonb));
 result:=result||jsonb_build_object('panels',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY 1) FROM ref.site_panel t),'[]'::jsonb));
 result:=result||jsonb_build_object('cable_specs',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM ref.site_power_cable_spec t),'[]'::jsonb));
 result:=result||jsonb_build_object('conductors',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM ref.site_power_conductor t),'[]'::jsonb));
 result:=result||jsonb_build_object('conductor_circuits',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM ref.site_power_conductor_circuit t),'[]'::jsonb));
 result:=result||jsonb_build_object('breakers',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM ref.site_power_breaker t),'[]'::jsonb));
 result:=result||jsonb_build_object('breaker_impacts',coalesce((SELECT jsonb_agg(ref.site_power_breaker_impact(p_email,t.site_power_breaker_id)) FROM ref.site_power_breaker t WHERE active),'[]'::jsonb));
 result:=result||jsonb_build_object('circuits',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY 1) FROM ref.site_power_circuit t),'[]'::jsonb));
 result:=result||jsonb_build_object('controller_power_connections',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM ref.site_controller_power_connection t),'[]'::jsonb));
 result:=result||jsonb_build_object('controller_installations',coalesce((SELECT jsonb_agg(to_jsonb(t)) FROM ref.site_controller_installation t),'[]'::jsonb));
 result:=result||jsonb_build_object('controller_options',coalesce((SELECT jsonb_agg(jsonb_build_object('id',c.controller_id,'model',m.model_code,'serial',c.serial_number,'lor_network',c.lor_network) ORDER BY c.controller_id) FROM ref.controller c JOIN ref.controller_model m USING(controller_model_id)),'[]'::jsonb));
 result:=result||jsonb_build_object('devices',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY 1) FROM ref.site_power_device t),'[]'::jsonb));
 result:=result||jsonb_build_object('feeds',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY 1) FROM ref.site_power_feed t),'[]'::jsonb));
 result:=result||jsonb_build_object('networks',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY 1) FROM ref.site_network_availability t),'[]'::jsonb));
 result:=result||jsonb_build_object('actions',coalesce((SELECT jsonb_agg(to_jsonb(t) ORDER BY 1) FROM ref.site_power_action t),'[]'::jsonb));
 RETURN result||jsonb_build_object(
 'waypoints',coalesce((SELECT jsonb_agg(jsonb_build_object('id',w.site_waypoint_id,'name',w.canonical_label,'type',w.waypoint_type,'network_capable',EXISTS(SELECT 1 FROM ref.site_network_availability n WHERE n.site_waypoint_id=w.site_waypoint_id),
 'aliases',coalesce((SELECT jsonb_agg(a.alias_text) FROM ref.site_waypoint_alias a WHERE a.site_waypoint_id=w.site_waypoint_id AND a.accepted_at IS NOT NULL AND a.accepted_by IS NOT NULL),'[]'::jsonb)) ORDER BY w.canonical_label) FROM ref.site_waypoint w),'[]'::jsonb),
 'network_options',coalesce((SELECT jsonb_agg(to_jsonb(n) ORDER BY n.network_code) FROM ref.site_network n),'[]'::jsonb),
 'cable_options',coalesce((SELECT jsonb_agg(jsonb_build_object('id',site_cable_id,'name',coalesce(notes,'Cable '||site_cable_id::text))) FROM ref.site_cable),'[]'::jsonb),
 'seasons',coalesce((SELECT jsonb_agg(season_year ORDER BY season_year DESC) FROM ref.season),'[]'::jsonb),
 'events',coalesce((SELECT jsonb_agg(to_jsonb(e) ORDER BY event_id DESC) FROM ops.setup_power_activity_event e),'[]'::jsonb),
 'history',coalesce((SELECT jsonb_agg(to_jsonb(h) ORDER BY event_id DESC) FROM ops.site_power_edit_log h),'[]'::jsonb));
END $f$;
CREATE FUNCTION ref.site_power_command(p_email text,p_request uuid,p_revision bigint,p_kind text,p_id bigint,p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog,ref,ops AS $f$
DECLARE actor record; rev bigint; before_row jsonb; after_row jsonb; prior ops.site_power_edit_log%ROWTYPE;
 allowed text[]; expected jsonb; request_fields jsonb; verified integer; verified_time timestamptz; target bigint;
 table_name text; key_name text; columns_sql text; values_sql text; updates_sql text;
 action_row ref.site_power_action%ROWTYPE; event_target bigint;
 child jsonb; evidence jsonb; leg jsonb; old_leg ref.site_power_circuit%ROWTYPE;
 old_feed ref.site_power_feed%ROWTYPE; breaker_data jsonb; circuit_id bigint; waypoint_id bigint;
 child_no integer:=0;
BEGIN
 -- Deny retired network mutation even for replay IDs or privileged Crew.
 IF p_kind='network' THEN RAISE EXCEPTION 'Network membership is read-only; reconcile FLW endpoint evidence' USING ERRCODE='42501'; END IF;
 -- Fail closed even if a legacy actor resolver returns NULL for an unassigned role.
 IF NOT coalesce((ref.site_power_access(p_email)->>'can_edit')::boolean,false) THEN
  RAISE EXCEPTION 'Production Crew circuit access required' USING ERRCODE='42501'; END IF;
 -- Reuse Directus roles and existing human reconciliation; never accept a client actor.
 SELECT * INTO STRICT actor FROM ref.setup_inventory_actor(p_email,false);
 IF p_request IS NULL OR p_revision IS NULL OR p_revision<0 OR p_data IS NULL OR jsonb_typeof(p_data)<>'object' THEN
 RAISE EXCEPTION 'Request ID, revision and structured fields required' USING ERRCODE='22023'; END IF;
 -- Stable idempotency identity is the ORIGINAL request, not fields defaulted internally.
 request_fields:=p_data;
 SELECT revision INTO rev FROM ref.site_power_revision WHERE singleton FOR UPDATE;
 SELECT * INTO prior FROM ops.site_power_edit_log WHERE request_id=p_request;
 IF FOUND THEN
  IF prior.operator_email IS DISTINCT FROM lower(btrim(p_email)) OR prior.command IS DISTINCT FROM p_kind
     OR prior.payload IS DISTINCT FROM jsonb_build_object('id',p_id,'fields',p_data) THEN
   RAISE EXCEPTION 'Request ID reused with different content' USING ERRCODE='22023'; END IF;
  RETURN jsonb_build_object('revision',prior.revision,'target_id',prior.target_id,'replayed',true);
 END IF;
 IF rev<>p_revision THEN RAISE EXCEPTION 'Another edit was saved. Reload before saving your changes.' USING ERRCODE='40001'; END IF;
 IF p_kind='breaker_schedule' THEN
  IF (SELECT count(*) FROM jsonb_object_keys(p_data))<>4 OR NOT p_data ?& ARRAY['breaker','legs','show_desired_state','restoration_desired_state']
    OR jsonb_typeof(p_data->'breaker')<>'object' OR jsonb_typeof(p_data->'legs')<>'array'
    OR jsonb_array_length(p_data->'legs')>200
    OR coalesce(p_data->>'show_desired_state','') NOT IN ('UNKNOWN','ON','OFF')
    OR coalesce(p_data->>'restoration_desired_state','') NOT IN ('UNKNOWN','ON','OFF') THEN
   RAISE EXCEPTION 'Invalid breaker schedule fields' USING ERRCODE='22023'; END IF;
  breaker_data:=p_data->'breaker';
  evidence:=jsonb_build_object('source_evidence',breaker_data->>'source_evidence','verification_status',coalesce(breaker_data->>'verification_status','UNVERIFIED'));
  SELECT to_jsonb(b) INTO before_row FROM ref.site_power_breaker b WHERE site_power_breaker_id=p_id;
  IF p_id IS NOT NULL AND (before_row IS NULL OR NOT (before_row->>'active')::boolean) THEN
   RAISE EXCEPTION 'Active breaker not found' USING ERRCODE='P0002'; END IF;
  -- Reject omitted existing legs or malformed/duplicate explicit memberships.
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_data->'legs') l WHERE jsonb_typeof(l)<>'object'
     OR NOT l ?& ARRAY['pole','circuit_code','waypoint_ids'] OR (SELECT count(*) FROM jsonb_object_keys(l))<>3
     OR jsonb_typeof(l->'waypoint_ids')<>'array' OR jsonb_typeof(l->'pole')<>'number')
   OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_data->'legs') l GROUP BY l->>'pole' HAVING count(*)>1) THEN
   RAISE EXCEPTION 'Each circuit leg requires a unique pole, circuit designation and waypoint list' USING ERRCODE='22023'; END IF;
  IF EXISTS(SELECT 1 FROM ref.site_power_circuit c WHERE c.site_power_breaker_id=p_id AND c.active
     AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_data->'legs') l WHERE (l->>'pole')::integer=c.breaker_pole)) THEN
   RAISE EXCEPTION 'Existing circuit legs cannot be omitted; reconcile their relationships before changing pole count' USING ERRCODE='23514'; END IF;
  IF (breaker_data->>'breaker_role'='MAIN' AND jsonb_array_length(p_data->'legs')<>0)
   OR (breaker_data->>'breaker_role'<>'MAIN' AND
      (jsonb_array_length(p_data->'legs')<>coalesce((breaker_data->>'pole_count')::integer,0)
       OR jsonb_array_length(p_data->'legs')=0)) THEN
   RAISE EXCEPTION 'Record one circuit leg per branch pole; mains have no branch circuit legs' USING ERRCODE='23514'; END IF;
  child_no:=child_no+1;
  child:=ref.site_power_command(p_email,md5(p_request::text||':'||child_no)::uuid,rev,'breaker',p_id,
    breaker_data||jsonb_build_object('show_desired_state',p_data->>'show_desired_state','restoration_desired_state',p_data->>'restoration_desired_state'));
  target:=(child->>'target_id')::bigint; rev:=(child->>'revision')::bigint;
  -- All legacy desired-state transitions are audited within this transaction.
  FOR old_leg IN SELECT * FROM ref.site_power_circuit WHERE site_power_breaker_id=target AND active ORDER BY breaker_pole LOOP
   child_no:=child_no+1;
   child:=ref.site_power_command(p_email,md5(p_request::text||':'||child_no)::uuid,rev,'circuit',old_leg.site_power_circuit_id,
     evidence||jsonb_build_object('show_desired_state','UNKNOWN','restoration_desired_state','UNKNOWN'));
   rev:=(child->>'revision')::bigint;
  END LOOP;
  FOR leg IN SELECT value FROM jsonb_array_elements(p_data->'legs') ORDER BY (value->>'pole')::integer LOOP
   SELECT * INTO old_leg FROM ref.site_power_circuit WHERE site_power_breaker_id=target AND active AND breaker_pole=(leg->>'pole')::integer;
   child_no:=child_no+1;
   child:=ref.site_power_command(p_email,md5(p_request::text||':'||child_no)::uuid,rev,'circuit',old_leg.site_power_circuit_id,
    evidence||jsonb_build_object('site_panel_id',(breaker_data->>'site_panel_id')::bigint,'site_power_breaker_id',target,
     'breaker_pole',(leg->>'pole')::integer,'circuit_code',leg->>'circuit_code',
     'show_desired_state',p_data->>'show_desired_state','restoration_desired_state',p_data->>'restoration_desired_state'));
   circuit_id:=(child->>'target_id')::bigint; rev:=(child->>'revision')::bigint;
   FOR old_feed IN SELECT * FROM ref.site_power_feed WHERE active AND source_circuit_id=circuit_id AND destination_waypoint_id IS NOT NULL
     AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements_text(leg->'waypoint_ids') x WHERE x::bigint=destination_waypoint_id) LOOP
    child_no:=child_no+1;
    child:=ref.site_power_command(p_email,md5(p_request::text||':'||child_no)::uuid,rev,'feed',old_feed.site_power_feed_id,evidence||'{"active":false}'::jsonb);
    rev:=(child->>'revision')::bigint;
   END LOOP;
   FOR waypoint_id IN SELECT DISTINCT value::bigint FROM jsonb_array_elements_text(leg->'waypoint_ids') LOOP
    IF NOT EXISTS(SELECT 1 FROM ref.site_power_feed WHERE active AND source_circuit_id=circuit_id AND destination_waypoint_id=waypoint_id) THEN
     child_no:=child_no+1;
     child:=ref.site_power_command(p_email,md5(p_request::text||':'||child_no)::uuid,rev,'feed',NULL,
       evidence||jsonb_build_object('source_circuit_id',circuit_id,'destination_waypoint_id',waypoint_id));
     rev:=(child->>'revision')::bigint;
    END IF;
   END LOOP;
  END LOOP;
  SELECT to_jsonb(b) INTO after_row FROM ref.site_power_breaker b WHERE site_power_breaker_id=target;
  UPDATE ref.site_power_revision SET revision=revision+1 WHERE singleton RETURNING revision INTO rev;
  INSERT INTO ops.site_power_edit_log(revision,request_id,command,target_id,payload,before_data,after_data,directus_user_id,person_id,operator_email)
  VALUES(rev,p_request,p_kind,target,jsonb_build_object('id',p_id,'fields',request_fields),before_row,after_row,actor.directus_user_id,actor.person_id,lower(btrim(p_email)));
  RETURN jsonb_build_object('revision',rev,'target_id',target,'replayed',false);
 END IF;
 IF p_kind='event' THEN
  allowed:=ARRAY['impact_reviewed','site_power_action_id','season_year','event_kind','condition','observed_at','evidence','corrects_event_id'];
 ELSE
  CASE p_kind
  WHEN 'panel' THEN table_name:='site_panel'; key_name:='site_panel_id'; allowed:=ARRAY['show_desired_state','restoration_desired_state','panel_name','site_waypoint_id','owner_name','year_installed','panel_identification','meter_information','supply_panel_id','supply_breaker_id','active','source_evidence','verification_status'];
  WHEN 'cable_spec' THEN table_name:='site_power_cable_spec'; key_name:='site_power_cable_spec_id'; allowed:=ARRAY['site_cable_id','cable_specification','active','source_evidence','verification_status'];
  WHEN 'conductor' THEN table_name:='site_power_conductor'; key_name:='site_power_conductor_id'; allowed:=ARRAY['site_cable_id','conductor_label','conductor_role','active','source_evidence','verification_status'];
  WHEN 'conductor_circuit' THEN table_name:='site_power_conductor_circuit'; key_name:='site_power_conductor_circuit_id'; allowed:=ARRAY['site_power_conductor_id','site_power_circuit_id','active','source_evidence','verification_status'];
  WHEN 'breaker' THEN table_name:='site_power_breaker'; key_name:='site_power_breaker_id'; allowed:=ARRAY['site_panel_id','breaker_name','breaker_role','panel_positions','rated_amps','pole_count','show_desired_state','restoration_desired_state','active','source_evidence','verification_status'];
  WHEN 'circuit' THEN table_name:='site_power_circuit'; key_name:='site_power_circuit_id'; allowed:=ARRAY['site_panel_id','circuit_code','description','voltage','site_power_breaker_id','breaker_pole','show_desired_state','restoration_desired_state','active','source_evidence','verification_status'];
  WHEN 'device' THEN table_name:='site_power_device'; key_name:='site_power_device_id'; allowed:=ARRAY['device_name','device_kind','site_waypoint_id','owner_name','utility_asset_id','rating','description','active','source_evidence','verification_status'];
  WHEN 'feed' THEN table_name:='site_power_feed'; key_name:='site_power_feed_id'; allowed:=ARRAY['source_circuit_id','source_device_id','destination_waypoint_id','destination_device_id','active','source_evidence','verification_status'];
  WHEN 'controller_power_connection' THEN table_name:='site_controller_power_connection'; key_name:='site_controller_power_connection_id'; allowed:=ARRAY['controller_id','site_waypoint_id','site_power_circuit_id','active','source_evidence','verification_status'];
  WHEN 'controller_installation' THEN table_name:='site_controller_installation'; key_name:='site_controller_installation_id'; allowed:=ARRAY['controller_id','site_waypoint_id','upstream_kind','upstream_controller_id','chain_end','active','source_evidence','verification_status'];

  WHEN 'action' THEN table_name:='site_power_action'; key_name:='site_power_action_id'; allowed:=ARRAY['site_panel_id','action_name','site_power_breaker_id','site_power_circuit_id','site_power_device_id','phase','action_kind','desired_state','responsible_party','instructions','prerequisite_action_ids','active','source_evidence','verification_status'];
  ELSE RAISE EXCEPTION 'Unknown circuit command' USING ERRCODE='22023'; END CASE;
 END IF;
 IF EXISTS(SELECT 1 FROM jsonb_object_keys(p_data) k WHERE NOT k=ANY(allowed)) THEN
 RAISE EXCEPTION 'Unrecognized or protected field' USING ERRCODE='22023'; END IF;
 IF p_kind='event' THEN
  IF p_id IS NOT NULL THEN RAISE EXCEPTION 'Activity events are append-only' USING ERRCODE='22023'; END IF;
  SELECT * INTO action_row FROM ref.site_power_action WHERE site_power_action_id=(p_data->>'site_power_action_id')::bigint;
  IF NOT FOUND OR NOT action_row.active THEN RAISE EXCEPTION 'Active action required' USING ERRCODE='22023'; END IF;
  IF action_row.site_power_breaker_id IS NOT NULL AND p_data->'impact_reviewed' IS DISTINCT FROM 'true'::jsonb THEN
   RAISE EXCEPTION 'Review grouped breaker impact at the current revision before recording an event' USING ERRCODE='22023'; END IF;
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
   to_jsonb(action_row)||CASE WHEN action_row.site_power_breaker_id IS NOT NULL THEN jsonb_build_object('impact',ref.site_power_breaker_impact(p_email,action_row.site_power_breaker_id)) ELSE '{}'::jsonb END,actor.directus_user_id,actor.person_id,lower(btrim(p_email))) RETURNING event_id,to_jsonb(setup_power_activity_event) INTO target,after_row;
 ELSE
  -- Routine assignments require no operator-authored note or verification;
  -- the existing command audit still records actor and revision.
  IF p_data ? 'verification_status' AND
     p_data->>'verification_status' NOT IN ('UNKNOWN','UNVERIFIED','VERIFIED','CONFLICTING') THEN
    RAISE EXCEPTION 'Invalid reference verification status' USING ERRCODE='22023';
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
  -- Any routine correction without an explicit verification action demotes the
  -- current reference to UNVERIFIED. Never keep old verifier attribution on
  -- changed facts or falsely attribute verification to this Crew operator.
  IF NOT p_data ? 'verification_status' THEN
    p_data:=p_data||jsonb_build_object('verification_status','UNVERIFIED');
  END IF;
  verified:=CASE WHEN p_data->>'verification_status'='VERIFIED' THEN actor.person_id ELSE NULL END;
  verified_time:=CASE WHEN verified IS NOT NULL THEN clock_timestamp() ELSE NULL END;
  expected:=coalesce(before_row,'{}'::jsonb)||p_data||jsonb_build_object('verified_by_person_id',verified,'verified_at',verified_time,'updated_at',clock_timestamp());
  -- jsonb_populate_record enforces native PostgreSQL field types. Omitted fields
  -- retain prior values on corrections; inserts receive explicit safe defaults.
  IF p_id IS NULL THEN expected:=jsonb_build_object('verification_status','UNVERIFIED','active',true,'breaker_role','UNKNOWN','show_desired_state','UNKNOWN',
   'upstream_kind','UNKNOWN','chain_end','UNKNOWN','restoration_desired_state','UNKNOWN','desired_state','UNKNOWN','prerequisite_action_ids','[]'::jsonb)||expected; END IF;
  IF p_kind='controller_power_connection' AND p_id IS NOT NULL AND (
    expected->'controller_id' IS DISTINCT FROM before_row->'controller_id'
    OR expected->'site_waypoint_id' IS DISTINCT FROM before_row->'site_waypoint_id'
    OR expected->'site_power_circuit_id' IS DISTINCT FROM before_row->'site_power_circuit_id') THEN
   RAISE EXCEPTION 'Retire the previous outlet connection and create a new one to move a controller' USING ERRCODE='22023';
  END IF;
  IF p_kind='controller_installation' THEN
   IF p_id IS NOT NULL AND (expected->'controller_id' IS DISTINCT FROM before_row->'controller_id'
      OR expected->'site_waypoint_id' IS DISTINCT FROM before_row->'site_waypoint_id') THEN
    RAISE EXCEPTION 'Retire the previous installation and create a new one to move equipment' USING ERRCODE='22023';
   END IF;
   -- FLW membership, not a GPX type or special endpoint name, controls network
   -- placement. The independent power connection guard still requires an outlet.
   IF (expected->>'active')::boolean AND NOT EXISTS(SELECT 1 FROM ref.site_controller_placement_eligibility
    WHERE controller_id=(expected->>'controller_id')::bigint AND site_waypoint_id=(expected->>'site_waypoint_id')::bigint) THEN
    RAISE EXCEPTION 'Controller placement held: required LOR network lacks resolved FLW endpoint evidence at this waypoint' USING ERRCODE='23514';
   END IF;
  END IF;
  allowed:=allowed||ARRAY['verified_by_person_id','verified_at','updated_at'];
  SELECT string_agg(format('%I',k),','),string_agg(format('r.%I',k),','),string_agg(format('%I=r.%I',k,k),',')
   INTO columns_sql,values_sql,updates_sql FROM unnest(allowed) k;
  IF p_id IS NULL THEN
   EXECUTE format('INSERT INTO ref.%I (%s) SELECT %s FROM jsonb_populate_record(NULL::ref.%I,$1) r RETURNING %I,to_jsonb(%I)',
    table_name,columns_sql,values_sql,table_name,key_name,table_name) INTO target,after_row USING expected;
  ELSE
   -- Foreign identity keys cannot silently move a circuit to another panel.
   IF p_kind IN ('circuit','breaker') AND expected->'site_panel_id' IS DISTINCT FROM before_row->'site_panel_id' THEN
    RAISE EXCEPTION 'A circuit cannot change panel identity; retire and define the correct circuit' USING ERRCODE='22023'; END IF;
   EXECUTE format('UPDATE ref.%I t SET %s FROM jsonb_populate_record(NULL::ref.%I,$1) r WHERE t.%I=$2 RETURNING t.%I,to_jsonb(t)',
    table_name,updates_sql,table_name,key_name,key_name) INTO target,after_row USING expected,p_id;
  END IF;
  -- Commands hold the shared revision lock. Validate the resulting graph, so a
  -- parent cannot be retired, moved or terminated underneath a recorded child.
  IF p_kind='controller_installation' THEN
   IF EXISTS (
    SELECT 1 FROM ref.site_controller_installation child
    LEFT JOIN ref.site_controller_installation parent ON parent.controller_id=child.upstream_controller_id AND parent.active
    LEFT JOIN ref.site_controller_network_requirement cr ON cr.controller_id=child.controller_id
    LEFT JOIN ref.site_controller_network_requirement pr ON pr.controller_id=parent.controller_id
    WHERE child.active AND child.upstream_kind='CONTROLLER' AND
     (parent.controller_id IS NULL OR parent.upstream_kind='UNKNOWN' OR parent.chain_end<>'UNKNOWN'
      OR parent.site_waypoint_id<>child.site_waypoint_id
      OR cr.requirement_status IS DISTINCT FROM 'CONFIRMED' OR pr.requirement_status IS DISTINCT FROM 'CONFIRMED'
      OR cr.required_network IS DISTINCT FROM pr.required_network
      OR NOT EXISTS(SELECT 1 FROM ref.site_controller_placement_eligibility e
         WHERE e.controller_id=parent.controller_id AND e.site_waypoint_id=parent.site_waypoint_id))
   ) THEN RAISE EXCEPTION 'Chain requires an active upstream controller with recorded order, the same origin and LOR network, and no recorded ending; reconnect downstream controllers first' USING ERRCODE='23514'; END IF;
   IF EXISTS(SELECT 1 FROM ref.site_controller_installation WHERE active AND upstream_controller_id IS NOT NULL
       GROUP BY upstream_controller_id HAVING count(*)>1) THEN
    RAISE EXCEPTION 'A controller can feed only one next controller; branching belongs at a distribution waypoint' USING ERRCODE='23514'; END IF;
   IF EXISTS(WITH RECURSIVE chain(id,path,cycle) AS (
      SELECT controller_id,ARRAY[controller_id],false FROM ref.site_controller_installation WHERE active
      UNION ALL
      SELECT i.upstream_controller_id,c.path||i.upstream_controller_id,i.upstream_controller_id=ANY(c.path)
      FROM chain c JOIN ref.site_controller_installation i ON i.controller_id=c.id AND i.active
      WHERE NOT c.cycle AND i.upstream_controller_id IS NOT NULL)
      SELECT 1 FROM chain WHERE cycle) THEN
    RAISE EXCEPTION 'Controller chain cannot contain circular controller dependencies; use Return to origin for the final cable' USING ERRCODE='23514'; END IF;
  END IF;
  IF EXISTS (
   WITH RECURSIVE supplied(circuit_id,waypoint_id,device_id,visited) AS (
    SELECT f.source_circuit_id,f.destination_waypoint_id,f.destination_device_id,ARRAY[f.site_power_feed_id]
    FROM ref.site_power_feed f JOIN ref.site_power_circuit c ON c.site_power_circuit_id=f.source_circuit_id
    WHERE f.active AND c.active
    UNION ALL
    SELECT s.circuit_id,f.destination_waypoint_id,f.destination_device_id,s.visited||f.site_power_feed_id
    FROM supplied s JOIN ref.site_power_feed f ON f.source_device_id=s.device_id
    JOIN ref.site_power_device d ON d.site_power_device_id=s.device_id AND d.active
    WHERE f.active AND NOT f.site_power_feed_id=ANY(s.visited)
   )
   SELECT 1 FROM ref.site_controller_power_connection cp JOIN ref.site_waypoint w USING(site_waypoint_id)
   WHERE cp.active AND ((lower(btrim(w.waypoint_type)) NOT IN ('power','out-power') AND NOT (regexp_split_to_array(lower(btrim(w.waypoint_type)), '[-_[:space:]]+') @> ARRAY['combo']::text[])) OR NOT EXISTS(
    SELECT 1 FROM supplied s LEFT JOIN ref.site_power_device d ON d.site_power_device_id=s.device_id AND d.active
    WHERE s.circuit_id=cp.site_power_circuit_id AND (s.waypoint_id=cp.site_waypoint_id OR d.site_waypoint_id=cp.site_waypoint_id)))
  ) THEN RAISE EXCEPTION 'Controller outlet connection requires an active circuit feed to a Power or Combo waypoint; retire dependent connections before changing supply' USING ERRCODE='23514'; END IF;
  -- A known upstream panel may precede inventory of its feeder breaker.
  -- Never manufacture an isolation device or accept contradictory ancestry.
  IF EXISTS(SELECT 1 FROM ref.site_panel p
    LEFT JOIN ref.site_power_breaker b ON b.site_power_breaker_id=p.supply_breaker_id
    LEFT JOIN ref.site_panel upstream ON upstream.site_panel_id=coalesce(p.supply_panel_id,b.site_panel_id)
    WHERE p.active AND (p.supply_panel_id IS NOT NULL OR p.supply_breaker_id IS NOT NULL)
      AND (NOT upstream.active OR upstream.site_panel_id=p.site_panel_id
        OR (p.supply_breaker_id IS NOT NULL AND (NOT b.active OR
          (p.supply_panel_id IS NOT NULL AND p.supply_panel_id<>b.site_panel_id)))
        OR EXISTS(SELECT 1 FROM ref.site_power_breaker m WHERE m.site_panel_id=p.site_panel_id AND m.active AND m.breaker_role='MAIN'))) THEN
   RAISE EXCEPTION 'Remote supply requires a consistent active upstream panel/breaker and no conflicting local main' USING ERRCODE='23514'; END IF;
  IF EXISTS(WITH RECURSIVE supply(id,path,cycle) AS (
    SELECT site_panel_id,ARRAY[site_panel_id],false FROM ref.site_panel WHERE active
    UNION ALL SELECT coalesce(p.supply_panel_id,b.site_panel_id),s.path||coalesce(p.supply_panel_id,b.site_panel_id),coalesce(p.supply_panel_id,b.site_panel_id)=ANY(s.path)
    FROM supply s JOIN ref.site_panel p ON p.site_panel_id=s.id
    LEFT JOIN ref.site_power_breaker b ON b.site_power_breaker_id=p.supply_breaker_id
    WHERE NOT s.cycle AND p.active AND coalesce(p.supply_panel_id,b.site_panel_id) IS NOT NULL)
    SELECT 1 FROM supply WHERE cycle) THEN
   RAISE EXCEPTION 'Panel supply relationships form a cycle' USING ERRCODE='23514'; END IF;
  -- Revision locking serializes commands; reject overlapping occupied slots.
  IF EXISTS(SELECT 1 FROM ref.site_power_breaker b CROSS JOIN LATERAL unnest(b.panel_positions) pos
    WHERE b.active GROUP BY b.site_panel_id,pos HAVING count(*)>1) THEN
   RAISE EXCEPTION 'Panel position already occupied (including duplicate positions on one breaker)' USING ERRCODE='23514'; END IF;
  IF EXISTS(SELECT 1 FROM ref.site_power_circuit c JOIN ref.site_power_breaker b USING(site_power_breaker_id)
    WHERE c.active AND (NOT b.active OR b.breaker_role='MAIN' OR c.site_panel_id<>b.site_panel_id OR b.pole_count IS NULL OR c.breaker_pole>b.pole_count)) THEN
   RAISE EXCEPTION 'Circuit breaker membership requires an active same-panel breaker and a known in-range pole' USING ERRCODE='23514'; END IF;
  IF EXISTS(SELECT 1 FROM ref.site_power_breaker b JOIN ref.site_panel p USING(site_panel_id) WHERE b.active AND NOT p.active) THEN
   RAISE EXCEPTION 'Active breaker requires an active panel' USING ERRCODE='23514'; END IF;
  IF EXISTS(SELECT 1 FROM ref.site_power_circuit a JOIN ref.site_power_circuit b USING(site_power_breaker_id)
    WHERE a.active AND b.active AND ((a.show_desired_state<>'UNKNOWN' AND b.show_desired_state<>'UNKNOWN' AND a.show_desired_state<>b.show_desired_state)
    OR (a.restoration_desired_state<>'UNKNOWN' AND b.restoration_desired_state<>'UNKNOWN' AND a.restoration_desired_state<>b.restoration_desired_state))) THEN
   RAISE EXCEPTION 'Grouped breaker legs cannot have contradictory desired states' USING ERRCODE='23514'; END IF;
  IF EXISTS(SELECT 1 FROM ref.site_power_action a JOIN ref.site_power_circuit c USING(site_power_circuit_id)
    WHERE a.active AND c.active AND c.site_power_breaker_id IS NOT NULL AND a.desired_state IN ('ON','OFF')) THEN
   RAISE EXCEPTION 'Switching a grouped circuit must target its breaker or the actual downstream device' USING ERRCODE='23514'; END IF;
  IF EXISTS(SELECT 1 FROM ref.site_power_action a JOIN ref.site_panel p USING(site_panel_id) WHERE a.active AND NOT p.active) THEN
   RAISE EXCEPTION 'Retire panel activities before retiring panel' USING ERRCODE='23514'; END IF;
  IF EXISTS(SELECT 1 FROM ref.site_power_action a JOIN ref.site_power_breaker b USING(site_power_breaker_id) WHERE a.active AND NOT b.active) THEN
   RAISE EXCEPTION 'Retire breaker actions before retiring breaker' USING ERRCODE='23514'; END IF;
  IF EXISTS(SELECT 1 FROM ref.site_power_conductor_circuit m
    JOIN ref.site_power_conductor d USING(site_power_conductor_id)
    JOIN ref.site_power_circuit c USING(site_power_circuit_id) WHERE m.active AND (NOT d.active OR NOT c.active)) THEN
   RAISE EXCEPTION 'Active conductor membership requires active conductor and circuit; retire memberships first' USING ERRCODE='23514'; END IF;
  IF EXISTS(SELECT 1 FROM ref.site_power_conductor_circuit m JOIN ref.site_power_conductor d USING(site_power_conductor_id)
    WHERE m.active AND d.conductor_role='HOT' GROUP BY m.site_power_conductor_id HAVING count(*)>1) THEN
   RAISE EXCEPTION 'A hot conductor cannot be assigned to multiple circuits; reconcile conflicting evidence' USING ERRCODE='23514'; END IF;
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
  -- Every waypoint may receive multiple legs of ONE breaker, never competing
  -- breakers. Follow actual active device/feed edges; names prove nothing.
  IF EXISTS (
   WITH RECURSIVE supplied AS (
    SELECT c.site_power_circuit_id,c.site_power_breaker_id,
      f.destination_waypoint_id,f.destination_device_id,
      ARRAY[coalesce(f.destination_device_id,0)] visited
    FROM ref.site_power_circuit c JOIN ref.site_power_feed f
      ON f.source_circuit_id=c.site_power_circuit_id AND f.active
    WHERE c.active
    UNION ALL
    SELECT w.site_power_circuit_id,w.site_power_breaker_id,
      f.destination_waypoint_id,f.destination_device_id,
      w.visited||coalesce(f.destination_device_id,0)
    FROM supplied w JOIN ref.site_power_feed f
      ON f.source_device_id=w.destination_device_id AND f.active
    WHERE NOT coalesce(f.destination_device_id=ANY(w.visited),false)
   ), endpoints AS (
    SELECT s.site_power_circuit_id,s.site_power_breaker_id,
      coalesce(s.destination_waypoint_id,d.site_waypoint_id) waypoint_id
    FROM supplied s LEFT JOIN ref.site_power_device d
      ON d.site_power_device_id=s.destination_device_id
   ) SELECT 1 FROM endpoints e JOIN ref.site_waypoint w
     ON w.site_waypoint_id=e.waypoint_id
    GROUP BY e.waypoint_id HAVING count(DISTINCT
      CASE WHEN e.site_power_breaker_id IS NOT NULL THEN 'B:'||e.site_power_breaker_id
           ELSE 'UNKNOWN-C:'||e.site_power_circuit_id END)>1
  ) THEN RAISE EXCEPTION 'A waypoint cannot be supplied by different breakers or unresolved competing circuits; review its direct and equipment feeds' USING ERRCODE='23514'; END IF;
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
 VALUES(rev,p_request,p_kind,target,jsonb_build_object('id',p_id,'fields',request_fields),before_row,after_row,actor.directus_user_id,actor.person_id,lower(btrim(p_email)));
 RETURN jsonb_build_object('revision',rev,'target_id',target,'replayed',false);
END $f$;
REVOKE ALL ON FUNCTION ref.site_power_access(text),ref.site_power_snapshot(text),ref.site_power_command(text,uuid,bigint,text,bigint,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ref.site_power_access(text),ref.site_power_snapshot(text),ref.site_power_command(text,uuid,bigint,text,bigint,jsonb) TO fieldwiring_app;
-- Override any ambient default privileges; all runtime access uses functions.
REVOKE ALL ON ref.site_controller_power_connection,ref.site_controller_installation,ref.site_power_cable_spec,ref.site_power_breaker,ref.site_panel,ref.site_power_circuit,ref.site_power_device,
 ref.site_power_feed,ref.site_waypoint_network,ref.site_power_action,ref.site_power_revision,
 ops.site_power_edit_log,ops.setup_power_activity_event FROM PUBLIC,fieldwiring_app;
-- No table/sequence writes, direct actor-function access, or Directus grants.
COMMIT;
