-- #171/#230 under #122: DISPOSABLE candidate following 171_site_infrastructure_schema_candidate.sql.
-- No Production migration/grant is authorized by this source file.
-- One maintained store: reviewed infrastructure in ref, source tests/audit in ops.
BEGIN;
SELECT pg_advisory_xact_lock(hashtext('MSB:#171:site-reference-operations'));

CREATE TABLE IF NOT EXISTS ref.site_reference_revision (
    singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
    revision bigint NOT NULL DEFAULT 0 CHECK (revision >= 0),
    changed_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
INSERT INTO ref.site_reference_revision(singleton) VALUES (true)
ON CONFLICT (singleton) DO NOTHING;

-- Separate positive grants. Setup movement access and generic ref membership grant NOTHING.
-- Provision only by reviewed database administration. Never populate from role-name guesses.
CREATE TABLE IF NOT EXISTS ref.site_editor_grant (
    operator_email text PRIMARY KEY CHECK (operator_email = lower(btrim(operator_email))
                              AND operator_email LIKE '%@%'),
    can_manage_identity boolean NOT NULL DEFAULT false,
    can_maintain_operations boolean NOT NULL DEFAULT false,
    active boolean NOT NULL DEFAULT false,
    granted_by text NOT NULL CHECK (length(btrim(granted_by)) > 0),
    evidence_notes text NOT NULL CHECK (length(btrim(evidence_notes)) > 0),
    granted_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

-- UNKNOWN is not MSB or City. A panel meter ID is separate from its identity.
CREATE TABLE IF NOT EXISTS ref.site_panel (
    site_waypoint_id bigint PRIMARY KEY REFERENCES ref.site_waypoint(site_waypoint_id),
    owner_code text NOT NULL DEFAULT 'UNKNOWN'
        CHECK (owner_code IN ('UNKNOWN', 'MSB', 'CITY')),
    meter_identifier text,
    owner_evidence text,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE IF NOT EXISTS ref.site_power_circuit (
    site_power_circuit_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    panel_waypoint_id bigint NOT NULL REFERENCES ref.site_panel(site_waypoint_id),
    circuit_code text NOT NULL CHECK (length(btrim(circuit_code)) > 0),
    circuit_label text,
    breaker_rating_amps numeric CHECK (breaker_rating_amps > 0 AND breaker_rating_amps <= 1000),
    owner_code text NOT NULL DEFAULT 'UNKNOWN'
        CHECK (owner_code IN ('UNKNOWN', 'MSB', 'CITY')),
    evidence_notes text NOT NULL CHECK (length(btrim(evidence_notes)) > 0),
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE UNIQUE INDEX IF NOT EXISTS site_power_circuit_panel_code_uq
    ON ref.site_power_circuit(panel_waypoint_id, lower(btrim(circuit_code)));

-- One circuit may supply multiple existing waypoints; one outlet may have multiple verified feeds.
CREATE TABLE IF NOT EXISTS ref.site_circuit_destination (
    site_power_circuit_id bigint NOT NULL REFERENCES ref.site_power_circuit(site_power_circuit_id),
    site_waypoint_id bigint NOT NULL REFERENCES ref.site_waypoint(site_waypoint_id),
    evidence_notes text NOT NULL CHECK (length(btrim(evidence_notes)) > 0),
    reviewed_by text NOT NULL CHECK (length(btrim(reviewed_by)) > 0),
    reviewed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY(site_power_circuit_id, site_waypoint_id)
);
CREATE TABLE IF NOT EXISTS ref.site_waypoint_network (
    site_waypoint_id bigint NOT NULL REFERENCES ref.site_waypoint(site_waypoint_id),
    site_network_id bigint NOT NULL REFERENCES ref.site_network(site_network_id),
    evidence_notes text NOT NULL CHECK (length(btrim(evidence_notes)) > 0),
    reviewed_by text NOT NULL CHECK (length(btrim(reviewed_by)) > 0),
    reviewed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY(site_waypoint_id, site_network_id)
);
-- Planned actions are NOT observed energized/de-energized evidence.
CREATE TABLE IF NOT EXISTS ref.site_seasonal_switch_instruction (
    site_power_circuit_id bigint NOT NULL REFERENCES ref.site_power_circuit(site_power_circuit_id),
    season_year integer NOT NULL CHECK (season_year BETWEEN 2020 AND 2100),
    turn_on_instruction text,
    turn_off_instruction text,
    evidence_notes text NOT NULL CHECK (length(btrim(evidence_notes)) > 0),
    reviewed_by text NOT NULL CHECK (length(btrim(reviewed_by)) > 0),
    reviewed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY(site_power_circuit_id, season_year),
    CHECK (nullif(btrim(coalesce(turn_on_instruction,'')), '') IS NOT NULL
        OR nullif(btrim(coalesce(turn_off_instruction,'')), '') IS NOT NULL)
);
CREATE TABLE IF NOT EXISTS ops.site_reference_edit_log (
    event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    revision bigint NOT NULL UNIQUE,
    operator_email text NOT NULL,
    named_command text NOT NULL,
    target_id bigint,
    evidence_notes text NOT NULL CHECK (length(btrim(evidence_notes)) > 0),
    before_data jsonb,
    after_data jsonb,
    changed_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

-- Return curated reference facts, NEVER arbitrary LinkWare payloads or guessed speed.
-- This function's output replaces the old baked map and dated network JSON.
CREATE OR REPLACE FUNCTION ref.site_reference_snapshot() RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, ref, ops
AS $snapshot$
 SELECT jsonb_build_object(
   'format_version', 1, 'data_mode', 'postgres', 'revision', rv.revision,
   'generated_at', clock_timestamp(),
   'sources', jsonb_build_object(
      'gpx', (SELECT jsonb_build_object('sha256',source_sha256,'received_at',received_at)
                FROM ops.site_source_batch WHERE source_kind='EXPERTGPS_GPX'
                ORDER BY received_at DESC,source_sha256 DESC LIMIT 1),
      'flw', (SELECT jsonb_build_object('sha256',source_sha256,'received_at',received_at)
                FROM ops.site_source_batch WHERE source_kind='LINKIQ_FLW'
                ORDER BY received_at DESC,source_sha256 DESC LIMIT 1)),
   'waypoints', coalesce((SELECT jsonb_agg(jsonb_build_object(
       'id',w.site_waypoint_id,'label',w.canonical_label,'type',w.waypoint_type,
       'geometry',ST_AsGeoJSON(ST_Transform(w.current_point,4326))::jsonb,
       'source_label',b.baseline_map_label,'source_description',w.source_description,
       'source_comment',w.source_comment,'source_time',w.source_time,
       'verified_at',w.verified_at,'updated_at',w.updated_at
       ) ORDER BY w.site_waypoint_id)
       FROM ref.site_waypoint w
       LEFT JOIN LATERAL (
          SELECT baseline_map_label FROM ref.site_waypoint_source_binding sb
          WHERE sb.site_waypoint_id=w.site_waypoint_id
          ORDER BY accepted_at DESC NULLS LAST,source_sha256 DESC LIMIT 1
       ) b ON true), '[]'::jsonb),
   'tracks', coalesce((SELECT jsonb_agg(jsonb_build_object(
       'id',t.site_track_id,'label',t.track_label,'type',t.source_type,
       'description',t.description,'lifecycle',t.lifecycle_status,
       'geometry',CASE WHEN ST_IsEmpty(t.reference_line) THEN NULL
                ELSE ST_AsGeoJSON(COALESCE(t.source_wgs84,ST_Transform(t.reference_line,4326)))::jsonb END,
       'source_ordinal',sb.source_ordinal)
       ORDER BY t.site_track_id)
       FROM ref.site_track t LEFT JOIN LATERAL (
         SELECT source_ordinal FROM ref.site_track_source_binding st
         WHERE st.site_track_id=t.site_track_id
         ORDER BY accepted_at DESC LIMIT 1
       ) sb ON true), '[]'::jsonb),
   'routes', coalesce((SELECT jsonb_agg(jsonb_build_object(
       'id',r.site_route_segment_id,'label',r.route_label,
       'endpoint_a',r.endpoint_a_waypoint_id,'endpoint_b',r.endpoint_b_waypoint_id,
       'geometry',ST_AsGeoJSON(ST_Transform(r.reference_line,4326))::jsonb,
       'cable_ids',coalesce((SELECT jsonb_agg(x.site_cable_id ORDER BY x.site_cable_id)
          FROM (SELECT DISTINCT c.site_cable_id FROM ref.site_cable_route_segment c
                WHERE c.site_route_segment_id=r.site_route_segment_id) x),'[]'::jsonb)
       ) ORDER BY r.site_route_segment_id)
       FROM ref.site_route_segment r WHERE r.review_status='REVIEWED'),'[]'::jsonb),
   'panels', coalesce((SELECT jsonb_agg(to_jsonb(p) ORDER BY p.site_waypoint_id)
       FROM ref.site_panel p),'[]'::jsonb),
   'circuits', coalesce((SELECT jsonb_agg(to_jsonb(c) ORDER BY c.site_power_circuit_id)
       FROM ref.site_power_circuit c),'[]'::jsonb),
   'destinations', coalesce((SELECT jsonb_agg(to_jsonb(d) ORDER BY d.site_power_circuit_id,d.site_waypoint_id)
       FROM ref.site_circuit_destination d),'[]'::jsonb),
   'networks', coalesce((SELECT jsonb_agg(to_jsonb(n) ORDER BY n.site_network_id)
       FROM ref.site_network n),'[]'::jsonb),
   'memberships', coalesce((SELECT jsonb_agg(to_jsonb(m) ORDER BY m.site_waypoint_id,m.site_network_id)
       FROM ref.site_waypoint_network m),'[]'::jsonb),
   'instructions', coalesce((SELECT jsonb_agg(to_jsonb(i) ORDER BY i.season_year,i.site_power_circuit_id)
       FROM ref.site_seasonal_switch_instruction i),'[]'::jsonb),
   'cables', coalesce((SELECT jsonb_agg(jsonb_build_object(
       'id',c.site_cable_id,'endpoint_a',c.endpoint_a_waypoint_id,
       'endpoint_b',c.endpoint_b_waypoint_id,'network_id',c.site_network_id,
       'spare',c.spare_designation,'lifecycle',c.lifecycle_status,
       'reviewed_at',c.reviewed_at,'reviewed_by',c.reviewed_by,
       'tests',coalesce((SELECT jsonb_agg(jsonb_build_object(
         'uuid',t.test_uuid,'tested_at_local',t.test_time_local,
         'length_ft',t.length_ft,'test_status_code',t.test_status_code,
         'test_standard',t.test_standard,
         'measured_link_speed_mbps',NULL,'speed_interpretation','NOT_ESTABLISHED',
         'original_name',t.tester_original_name)
         ORDER BY t.test_time_local DESC NULLS LAST,t.test_uuid)
         FROM ops.linkiq_test t WHERE t.physical_site_cable_id=c.site_cable_id
             AND t.identity_review_status='REVIEWED'),'[]'::jsonb))
       ORDER BY c.site_cable_id) FROM ref.site_cable c
       WHERE c.reviewed_by IS NOT NULL AND c.reviewed_at IS NOT NULL),'[]'::jsonb),
   'unresolved_linkiq_tests', (SELECT count(*) FROM ops.linkiq_test
       WHERE identity_review_status<>'REVIEWED')
 ) FROM ref.site_reference_revision rv WHERE rv.singleton=true
$snapshot$;

CREATE OR REPLACE FUNCTION ref.site_reference_permissions(p_email text) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $permissions$
 SELECT jsonb_build_object(
   'identity',coalesce(bool_or(can_manage_identity),false),
   'operations',coalesce(bool_or(can_maintain_operations),false))
 FROM ref.site_editor_grant
 WHERE operator_email=lower(btrim(p_email)) AND active
$permissions$;

-- Exactly named commands with audited before/after, positive grant, and a
-- global optimistic revision. This is NOT generic ref.* CRUD. All actions
-- require evidence and always preserve earlier source observations.
CREATE OR REPLACE FUNCTION ref.site_reference_command(
    p_email text, p_command text, p_expected_revision bigint, p_data jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, ref, ops
AS $command$
DECLARE
    v_permissions jsonb;
    v_current bigint;
    v_target bigint;
    v_waypoint bigint;
    v_panel bigint;
    v_circuit bigint;
    v_network bigint;
    v_before jsonb;
    v_after jsonb;
    v_evidence text := nullif(btrim(p_data->>'evidence_notes'),'');
    v_code text;
    v_lat numeric;
    v_lon numeric;
    v_result jsonb;
BEGIN
    IF p_email IS NULL OR p_email<>lower(btrim(p_email)) OR position('@' IN p_email)=0 THEN
        RAISE EXCEPTION 'Authenticated operator identity required' USING ERRCODE='42501';
    END IF;
    IF p_data IS NULL OR jsonb_typeof(p_data)<>'object' OR v_evidence IS NULL THEN
        RAISE EXCEPTION 'Structured command and nonblank evidence required' USING ERRCODE='22023';
    END IF;
    v_permissions := ref.site_reference_permissions(p_email);
    IF p_command IN ('manager_update_waypoint','manager_set_panel_owner',
                     'manager_set_circuit_owner','manager_add_network') THEN
        IF NOT (v_permissions->>'identity')::boolean THEN
            RAISE EXCEPTION 'Manager GIS identity grant required' USING ERRCODE='42501';
        END IF;
    ELSIF p_command IN ('crew_set_meter','crew_upsert_circuit','crew_link_destination',
                        'crew_assign_network','crew_set_switching') THEN
        IF NOT (v_permissions->>'operations')::boolean THEN
            RAISE EXCEPTION 'Production crew infrastructure grant required' USING ERRCODE='42501';
        END IF;
    ELSE
        RAISE EXCEPTION 'Unrecognized reference command' USING ERRCODE='22023';
    END IF;
    SELECT revision INTO v_current FROM ref.site_reference_revision
       WHERE singleton=true FOR UPDATE;
    IF p_expected_revision IS NULL OR p_expected_revision<>v_current THEN
        RAISE EXCEPTION 'Reference revision changed; refresh before editing' USING ERRCODE='40001';
    END IF;

    IF p_command='manager_update_waypoint' THEN
        v_target := (p_data->>'waypoint_id')::bigint;
        SELECT to_jsonb(w) INTO v_before FROM ref.site_waypoint w
           WHERE w.site_waypoint_id=v_target FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'Waypoint not found' USING ERRCODE='P0002'; END IF;
        IF (p_data ? 'latitude') <> (p_data ? 'longitude') THEN
            RAISE EXCEPTION 'Both WGS84 coordinates must be supplied' USING ERRCODE='22023';
        END IF;
        IF p_data ? 'latitude' THEN
            v_lat:=(p_data->>'latitude')::numeric; v_lon:=(p_data->>'longitude')::numeric;
            IF v_lat NOT BETWEEN -90 AND 90 OR v_lon NOT BETWEEN -180 AND 180 THEN
                RAISE EXCEPTION 'WGS84 coordinates invalid' USING ERRCODE='22023';
            END IF;
        END IF;
        UPDATE ref.site_waypoint AS w SET
           canonical_label=coalesce(nullif(btrim(p_data->>'label'),''),w.canonical_label),
           waypoint_type=coalesce(p_data->>'type',w.waypoint_type),
           current_point=CASE WHEN v_lat IS NOT NULL THEN
                  ST_Transform(ST_SetSRID(ST_MakePoint(v_lon,v_lat),4326),8158)
                  ELSE w.current_point END,
           source_wgs84=CASE WHEN v_lat IS NOT NULL THEN
                  ST_SetSRID(ST_MakePoint(v_lon,v_lat),4326) ELSE w.source_wgs84 END,
           updated_at=clock_timestamp(),verified_by=p_email,verified_at=clock_timestamp()
         WHERE w.site_waypoint_id=v_target RETURNING to_jsonb(w) INTO v_after;

    ELSIF p_command='manager_set_panel_owner' THEN
        v_target := (p_data->>'waypoint_id')::bigint;
        v_code:=upper(btrim(p_data->>'owner_code'));
        IF v_code NOT IN ('UNKNOWN','MSB','CITY') THEN
            RAISE EXCEPTION 'Ownership must be UNKNOWN, MSB or CITY' USING ERRCODE='22023';
        END IF;
        PERFORM 1 FROM ref.site_waypoint w WHERE site_waypoint_id=v_target
          AND lower(w.waypoint_type) LIKE '%panel%';
        IF NOT FOUND THEN RAISE EXCEPTION 'Existing panel waypoint required' USING ERRCODE='22023'; END IF;
        SELECT to_jsonb(p) INTO v_before FROM ref.site_panel p WHERE site_waypoint_id=v_target;
        INSERT INTO ref.site_panel(site_waypoint_id,owner_code,owner_evidence)
         VALUES(v_target,v_code,v_evidence)
         ON CONFLICT(site_waypoint_id) DO UPDATE
           SET owner_code=EXCLUDED.owner_code,owner_evidence=EXCLUDED.owner_evidence,
               updated_at=clock_timestamp();
        SELECT to_jsonb(p) INTO v_after FROM ref.site_panel p WHERE site_waypoint_id=v_target;

    ELSIF p_command='crew_set_meter' THEN
        v_target := (p_data->>'waypoint_id')::bigint;
        PERFORM 1 FROM ref.site_waypoint w WHERE site_waypoint_id=v_target
          AND lower(w.waypoint_type) LIKE '%panel%';
        IF NOT FOUND THEN RAISE EXCEPTION 'Existing panel waypoint required' USING ERRCODE='22023'; END IF;
        SELECT to_jsonb(p) INTO v_before FROM ref.site_panel p WHERE site_waypoint_id=v_target;
        INSERT INTO ref.site_panel(site_waypoint_id,meter_identifier)
          VALUES(v_target,nullif(btrim(p_data->>'meter_identifier'),''))
          ON CONFLICT(site_waypoint_id) DO UPDATE
            SET meter_identifier=EXCLUDED.meter_identifier,updated_at=clock_timestamp();
        SELECT to_jsonb(p) INTO v_after FROM ref.site_panel p WHERE site_waypoint_id=v_target;

    ELSIF p_command='crew_upsert_circuit' THEN
        v_panel := (p_data->>'panel_waypoint_id')::bigint;
        v_code := nullif(btrim(p_data->>'circuit_code'),'');
        IF v_code IS NULL THEN
            RAISE EXCEPTION 'Circuit number required' USING ERRCODE='22023';
        END IF;
        PERFORM 1 FROM ref.site_waypoint w WHERE site_waypoint_id=v_panel
          AND lower(w.waypoint_type) LIKE '%panel%';
        IF NOT FOUND THEN RAISE EXCEPTION 'Existing panel waypoint required' USING ERRCODE='22023'; END IF;
        INSERT INTO ref.site_panel(site_waypoint_id) VALUES(v_panel)
          ON CONFLICT(site_waypoint_id) DO NOTHING;
        SELECT site_power_circuit_id,to_jsonb(c) INTO v_target,v_before
           FROM ref.site_power_circuit c
          WHERE c.panel_waypoint_id=v_panel AND lower(btrim(c.circuit_code))=lower(v_code);
        IF v_target IS NULL THEN
            INSERT INTO ref.site_power_circuit(
                panel_waypoint_id,circuit_code,circuit_label,breaker_rating_amps,evidence_notes)
            VALUES(v_panel,v_code,nullif(btrim(p_data->>'circuit_label'),''),
                   nullif(p_data->>'breaker_rating_amps','')::numeric,v_evidence)
            RETURNING site_power_circuit_id INTO v_target;
        ELSE
            UPDATE ref.site_power_circuit c SET
                circuit_label=coalesce(p_data->>'circuit_label',c.circuit_label),
                breaker_rating_amps=CASE WHEN p_data ? 'breaker_rating_amps'
                    THEN nullif(p_data->>'breaker_rating_amps','')::numeric
                    ELSE c.breaker_rating_amps END,
                evidence_notes=v_evidence,updated_at=clock_timestamp()
            WHERE c.site_power_circuit_id=v_target;
        END IF;
        SELECT to_jsonb(c) INTO v_after FROM ref.site_power_circuit c
          WHERE c.site_power_circuit_id=v_target;

    ELSIF p_command='manager_set_circuit_owner' THEN
        v_target := (p_data->>'circuit_id')::bigint;
        v_code := upper(btrim(p_data->>'owner_code'));
        IF v_code NOT IN ('UNKNOWN','MSB','CITY') THEN
            RAISE EXCEPTION 'Explicit circuit ownership required' USING ERRCODE='22023';
        END IF;
        SELECT to_jsonb(c) INTO v_before FROM ref.site_power_circuit c
          WHERE c.site_power_circuit_id=v_target FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'Circuit not found' USING ERRCODE='P0002'; END IF;
        UPDATE ref.site_power_circuit c SET owner_code=v_code,updated_at=clock_timestamp(),
            evidence_notes=v_evidence WHERE site_power_circuit_id=v_target
          RETURNING to_jsonb(c) INTO v_after;

    ELSIF p_command='crew_link_destination' THEN
        v_circuit := (p_data->>'circuit_id')::bigint;
        v_waypoint := (p_data->>'waypoint_id')::bigint;
        SELECT panel_waypoint_id INTO v_panel FROM ref.site_power_circuit
          WHERE site_power_circuit_id=v_circuit;
        IF v_panel IS NULL OR v_waypoint=v_panel
           OR NOT EXISTS(SELECT 1 FROM ref.site_waypoint WHERE site_waypoint_id=v_waypoint) THEN
            RAISE EXCEPTION 'Existing circuit and distinct destination waypoint required'
                USING ERRCODE='22023';
        END IF;
        v_target:=v_circuit;
        SELECT to_jsonb(d) INTO v_before FROM ref.site_circuit_destination d
          WHERE d.site_power_circuit_id=v_circuit AND d.site_waypoint_id=v_waypoint;
        INSERT INTO ref.site_circuit_destination
          (site_power_circuit_id,site_waypoint_id,evidence_notes,reviewed_by)
        VALUES(v_circuit,v_waypoint,v_evidence,p_email)
        ON CONFLICT(site_power_circuit_id,site_waypoint_id) DO UPDATE
          SET evidence_notes=EXCLUDED.evidence_notes,reviewed_by=EXCLUDED.reviewed_by,
              reviewed_at=clock_timestamp();
        SELECT to_jsonb(d) INTO v_after FROM ref.site_circuit_destination d
          WHERE d.site_power_circuit_id=v_circuit AND d.site_waypoint_id=v_waypoint;

    ELSIF p_command='manager_add_network' THEN
        v_code:=nullif(btrim(p_data->>'network_code'),'');
        IF v_code IS NULL OR p_data->>'network_kind' NOT IN ('LOR','IP','OTHER') THEN
            RAISE EXCEPTION 'Named network and explicit kind required' USING ERRCODE='22023';
        END IF;
        INSERT INTO ref.site_network(network_code,network_kind,notes)
          VALUES(v_code,p_data->>'network_kind',v_evidence)
          RETURNING site_network_id INTO v_target;
        SELECT to_jsonb(n) INTO v_after FROM ref.site_network n WHERE site_network_id=v_target;

    ELSIF p_command='crew_assign_network' THEN
        v_waypoint := (p_data->>'waypoint_id')::bigint;
        v_network := (p_data->>'network_id')::bigint;
        IF NOT EXISTS(SELECT 1 FROM ref.site_waypoint WHERE site_waypoint_id=v_waypoint)
           OR NOT EXISTS(SELECT 1 FROM ref.site_network WHERE site_network_id=v_network) THEN
           RAISE EXCEPTION 'Known waypoint and maintained network required'
               USING ERRCODE='22023';
        END IF;
        v_target:=v_waypoint;
        SELECT to_jsonb(m) INTO v_before FROM ref.site_waypoint_network m
          WHERE m.site_waypoint_id=v_waypoint AND m.site_network_id=v_network;
        INSERT INTO ref.site_waypoint_network
          (site_waypoint_id,site_network_id,evidence_notes,reviewed_by)
        VALUES(v_waypoint,v_network,v_evidence,p_email)
        ON CONFLICT(site_waypoint_id,site_network_id) DO UPDATE
          SET evidence_notes=EXCLUDED.evidence_notes,reviewed_by=EXCLUDED.reviewed_by,
              reviewed_at=clock_timestamp();
        SELECT to_jsonb(m) INTO v_after FROM ref.site_waypoint_network m
          WHERE m.site_waypoint_id=v_waypoint AND m.site_network_id=v_network;

    ELSIF p_command='crew_set_switching' THEN
        v_target:=(p_data->>'circuit_id')::bigint;
        IF NOT EXISTS(SELECT 1 FROM ref.site_power_circuit WHERE site_power_circuit_id=v_target)
           OR (p_data->>'season_year')::int NOT BETWEEN 2020 AND 2100 THEN
           RAISE EXCEPTION 'Existing circuit and valid season required' USING ERRCODE='22023';
        END IF;
        SELECT to_jsonb(i) INTO v_before FROM ref.site_seasonal_switch_instruction i
          WHERE i.site_power_circuit_id=v_target AND i.season_year=(p_data->>'season_year')::int;
        INSERT INTO ref.site_seasonal_switch_instruction
          (site_power_circuit_id,season_year,turn_on_instruction,turn_off_instruction,
           evidence_notes,reviewed_by)
        VALUES(v_target,(p_data->>'season_year')::int,
               nullif(btrim(p_data->>'turn_on_instruction'),''),
               nullif(btrim(p_data->>'turn_off_instruction'),''),v_evidence,p_email)
        ON CONFLICT(site_power_circuit_id,season_year) DO UPDATE
          SET turn_on_instruction=EXCLUDED.turn_on_instruction,
              turn_off_instruction=EXCLUDED.turn_off_instruction,
              evidence_notes=EXCLUDED.evidence_notes,reviewed_by=EXCLUDED.reviewed_by,
              reviewed_at=clock_timestamp();
        SELECT to_jsonb(i) INTO v_after FROM ref.site_seasonal_switch_instruction i
          WHERE i.site_power_circuit_id=v_target AND i.season_year=(p_data->>'season_year')::int;
    END IF;

    UPDATE ref.site_reference_revision SET revision=revision+1,
       changed_at=clock_timestamp() WHERE singleton=true RETURNING revision INTO v_current;
    INSERT INTO ops.site_reference_edit_log(
      revision,operator_email,named_command,target_id,evidence_notes,before_data,after_data)
    VALUES(v_current,p_email,p_command,v_target,v_evidence,v_before,v_after);
    v_result := jsonb_build_object('revision',v_current,'target_id',v_target,
                                  'command',p_command,'changed',true);
    RETURN v_result;
END
$command$;

-- PostgreSQL grants follow the existing FieldWiring application account, if present
-- on the clone. No generic DML or unreviewed editor grants.
REVOKE ALL ON FUNCTION ref.site_reference_snapshot() FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.site_reference_permissions(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION ref.site_reference_command(text,text,bigint,jsonb) FROM PUBLIC;
DO $grant$
BEGIN
 IF to_regrole('fieldwiring_app') IS NOT NULL THEN
   GRANT USAGE ON SCHEMA ref TO fieldwiring_app;
   GRANT EXECUTE ON FUNCTION ref.site_reference_snapshot() TO fieldwiring_app;
   GRANT EXECUTE ON FUNCTION ref.site_reference_permissions(text) TO fieldwiring_app;
   GRANT EXECUTE ON FUNCTION ref.site_reference_command(text,text,bigint,jsonb)
     TO fieldwiring_app;
 END IF;
END $grant$;
COMMIT;
