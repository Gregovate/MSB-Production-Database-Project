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

-- One power model: PR #454 installs panel/circuit/feed/network/action tables
-- before this reader. No legacy power tables or independent editor-role store.
DO $dependency$ BEGIN
 IF to_regprocedure('ref.site_power_snapshot(text)') IS NULL THEN
  RAISE EXCEPTION 'Install the combined circuit candidate before GIS operations';
 END IF;
END $dependency$;

CREATE TABLE IF NOT EXISTS ops.site_reference_edit_log (
    event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    revision bigint NOT NULL UNIQUE,
    operator_email text NOT NULL,
    directus_user_id uuid NOT NULL,
    person_id integer NOT NULL REFERENCES ref.person(person_id),
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
      'gpx', (SELECT jsonb_build_object('sha256',b.source_sha256,'received_at',b.received_at)
                FROM (SELECT source_sha256,count(*) AS bound_waypoints
                      FROM ref.site_waypoint_source_binding WHERE accepted_at IS NOT NULL
                      GROUP BY source_sha256) sb
                JOIN ops.site_source_batch b USING(source_sha256)
                ORDER BY sb.bound_waypoints DESC,b.received_at DESC LIMIT 1),
      'gpx_latest_staged', (SELECT jsonb_build_object('sha256',source_sha256,'received_at',received_at)
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
   'aliases', coalesce((SELECT jsonb_agg(jsonb_build_object(
       'id',a.alias_id,'waypoint_id',a.site_waypoint_id,'label',a.alias_text,
       'source',a.alias_source,'accepted_at',a.accepted_at,'accepted_by',a.accepted_by)
       ORDER BY a.site_waypoint_id,a.alias_id)
       FROM ref.site_waypoint_alias a
       WHERE a.accepted_by IS NOT NULL AND a.accepted_at IS NOT NULL),'[]'::jsonb),
   'tracks', coalesce((SELECT jsonb_agg(jsonb_build_object(
       'id',t.site_track_id,'label',t.track_label,'type',t.source_type,
       'description',t.description,'lifecycle',t.lifecycle_status,
       'geometry',CASE WHEN ST_IsEmpty(t.reference_line) THEN NULL
                ELSE ST_AsGeoJSON(COALESCE(t.source_wgs84,ST_Transform(t.reference_line,4326)))::jsonb END,
       'source_ordinal',sb.source_ordinal,
       'source_sha256',sb.source_sha256,
       'source_label',obs.source_document->>'name',
       'source_map_label',obs.source_document->>'map_label',
       'style',obs.source_document->'style',
       'verified_by',t.verified_by,'verified_at',t.verified_at)
       ORDER BY t.site_track_id)
       FROM ref.site_track t LEFT JOIN LATERAL (
         SELECT source_ordinal,source_sha256
         FROM ref.site_track_source_binding st
         WHERE st.site_track_id=t.site_track_id
         ORDER BY accepted_at DESC,source_sha256 DESC LIMIT 1
       ) sb ON true
       LEFT JOIN ops.site_source_observation obs
          ON obs.source_sha256=sb.source_sha256
         AND obs.source_row=sb.source_ordinal::text
         AND obs.item_kind='TRACK'), '[]'::jsonb),
   'routes', coalesce((SELECT jsonb_agg(jsonb_build_object(
       'id',r.site_route_segment_id,'label',r.route_label,
       'endpoint_a',r.endpoint_a_waypoint_id,'endpoint_b',r.endpoint_b_waypoint_id,
       'geometry',ST_AsGeoJSON(ST_Transform(r.reference_line,4326))::jsonb,
       'cable_ids',coalesce((SELECT jsonb_agg(x.site_cable_id ORDER BY x.site_cable_id)
          FROM (SELECT DISTINCT c.site_cable_id FROM ref.site_cable_route_segment c
                WHERE c.site_route_segment_id=r.site_route_segment_id) x),'[]'::jsonb)
       ) ORDER BY r.site_route_segment_id)
       FROM ref.site_route_segment r WHERE r.review_status='REVIEWED'),'[]'::jsonb),
   'power_revision', (SELECT revision FROM ref.site_power_revision WHERE singleton),
   'power_editor_url', '/fieldwiring/circuits',
   'panels', coalesce((SELECT jsonb_agg(to_jsonb(p) || jsonb_build_object(
       'owner_code',coalesce(p.owner_name,'UNKNOWN'),'meter_identifier',p.meter_information)
       ORDER BY p.site_panel_id) FROM ref.site_panel p WHERE p.active),'[]'::jsonb),
   'circuits', coalesce((SELECT jsonb_agg(to_jsonb(c) || jsonb_build_object(
       'panel_waypoint_id',p.site_waypoint_id,'panel_name',p.panel_name,
       'circuit_label',c.description,'owner_code',coalesce(p.owner_name,'UNKNOWN'))
       ORDER BY c.site_power_circuit_id)
       FROM ref.site_power_circuit c JOIN ref.site_panel p USING(site_panel_id)
       WHERE c.active AND p.active),'[]'::jsonb),
   -- Traverse only recorded active feed edges, never infer from GPX geometry.
   'destinations', coalesce((WITH RECURSIVE feeds AS (
       SELECT f.source_circuit_id AS site_power_circuit_id,
              f.destination_waypoint_id AS site_waypoint_id,
              f.destination_device_id AS device_id, ARRAY[f.site_power_feed_id] AS path
       FROM ref.site_power_feed f JOIN ref.site_power_circuit c
         ON c.site_power_circuit_id=f.source_circuit_id
       WHERE f.active AND c.active
       UNION ALL
       SELECT p.site_power_circuit_id,f.destination_waypoint_id,f.destination_device_id,
              p.path||f.site_power_feed_id
       FROM feeds p JOIN ref.site_power_device d ON d.site_power_device_id=p.device_id AND d.active
       JOIN ref.site_power_feed f ON f.source_device_id=d.site_power_device_id
       WHERE f.active AND NOT f.site_power_feed_id=ANY(p.path)
     ) SELECT jsonb_agg(to_jsonb(x)) FROM (
       SELECT DISTINCT f.site_power_circuit_id,coalesce(f.site_waypoint_id,d.site_waypoint_id) AS site_waypoint_id FROM feeds f
       LEFT JOIN ref.site_power_device d ON d.site_power_device_id=f.device_id AND d.active
       WHERE coalesce(f.site_waypoint_id,d.site_waypoint_id) IS NOT NULL) x),'[]'::jsonb),
   'networks', coalesce((SELECT jsonb_agg(to_jsonb(n) ORDER BY n.site_network_id)
       FROM ref.site_network n),'[]'::jsonb),
   'memberships', coalesce((SELECT jsonb_agg(to_jsonb(m) ORDER BY m.site_waypoint_id,m.site_network_id)
       FROM ref.site_network_availability m),'[]'::jsonb),
   -- Annual observations and desired states are distinct; render via power editor.
   'instructions', '[]'::jsonb,
   'power_actions', coalesce((SELECT jsonb_agg(to_jsonb(a) ORDER BY a.site_power_action_id)
       FROM ref.site_power_action a WHERE a.active),'[]'::jsonb),
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
       WHERE identity_review_status<>'REVIEWED'),
   -- The review queue contains durable UUID/source evidence, not inferred cable
   -- identities. Never expose the opaque BinRec payload to the operator map.
   'linkiq_review', coalesce((
       SELECT jsonb_agg(jsonb_build_object(
           'test_uuid',t.test_uuid,'tester_original_name',t.tester_original_name,
           'preferred_display_name',latest.display_cable_name,
           'source_sha256',latest.source_sha256,
           'intake_status',latest.intake_status,
           'identity_review_status',t.identity_review_status,
           'physical_site_cable_id',t.physical_site_cable_id,
           'tested_at_local',t.test_time_local,'test_status_code',t.test_status_code,
           'test_standard',t.test_standard,'length_ft',t.length_ft,
           'measured_link_speed_mbps',NULL
       ) ORDER BY t.test_time_local DESC NULLS LAST,t.test_uuid)
       FROM ops.linkiq_test t
       LEFT JOIN LATERAL (
           SELECT r.source_sha256,r.proposal->>'status' AS intake_status,
                  a.display_cable_name
           FROM ops.linkiq_intake_review r
           JOIN ops.site_source_batch b ON b.source_sha256=r.source_sha256
           LEFT JOIN LATERAL (
               SELECT x.display_cable_name FROM ops.linkiq_test_appearance x
               WHERE x.test_uuid=t.test_uuid AND x.source_sha256=r.source_sha256
               ORDER BY CASE x.linkware_project
                  WHEN 'MSB-Park-Network' THEN 0
                  WHEN 'Command Trailer' THEN 1
                  WHEN 'Park Network' THEN 2 ELSE 10 END,
                  x.source_row ASC LIMIT 1
           ) a ON true
           WHERE r.test_uuid=t.test_uuid
           ORDER BY b.received_at DESC,r.recorded_at DESC,r.source_sha256 DESC LIMIT 1
       ) latest ON true
       -- Reviewed entries remain visible for an explicitly evidenced CORRECTION.
       -- Every correction uses expected prior cable ID and appends a decision.
   ),'[]'::jsonb)
 ) FROM ref.site_reference_revision rv WHERE rv.singleton=true
$snapshot$;

CREATE OR REPLACE FUNCTION ref.site_reference_permissions(p_email text) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, ref
AS $permissions$
 SELECT jsonb_build_object('identity',coalesce((
   SELECT can_manage_setup FROM ref.setup_browser_capabilities(p_email)),false),
   'operations',false)
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
    v_actor record;
    v_current bigint;
    v_target bigint;
    v_waypoint bigint;
    v_panel bigint;
    v_circuit bigint;
    v_network bigint;
    v_cable bigint;
    v_expected_cable bigint;
    v_test_uuid uuid;
    v_source_sha text;
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
    IF p_command NOT IN ('manager_update_waypoint','manager_add_network',
        'manager_create_cable','manager_link_test','manager_add_alias',
        'manager_retire_cable','manager_update_track_label') OR p_command IS NULL THEN
        RAISE EXCEPTION 'Unrecognized GIS command; power capture belongs in FieldWiring' USING ERRCODE='22023';
    END IF;
    IF NOT coalesce((v_permissions->>'identity')::boolean,false) THEN
        RAISE EXCEPTION 'Directus Manager GIS identity access required' USING ERRCODE='42501';
    END IF;
    SELECT * INTO STRICT v_actor FROM ref.setup_inventory_actor(p_email,true);
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

    ELSIF p_command='manager_update_track_label' THEN
        -- Stable site_track_id and caller-supplied expected name prevent a
        -- guessed source-name match or stale-tab overwrite. NO geometry change.
        v_target := (p_data->>'track_id')::bigint;
        v_code := nullif(btrim(p_data->>'track_label'),'');
        IF v_target IS NULL OR v_code IS NULL
           OR NOT (p_data ? 'expected_track_label')
           OR jsonb_typeof(p_data->'expected_track_label') <> 'string' THEN
            RAISE EXCEPTION 'Track ID, expected prior name and reviewed new name required'
                USING ERRCODE='22023';
        END IF;
        SELECT jsonb_build_object('track_id',t.site_track_id,
                   'track_label',t.track_label,
                   'verified_by',t.verified_by,'verified_at',t.verified_at,
                   'changed_at',t.changed_at)
          INTO v_before
          FROM ref.site_track t WHERE t.site_track_id=v_target FOR UPDATE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Existing GPX track identity not found' USING ERRCODE='P0002';
        END IF;
        IF NOT EXISTS (
            SELECT 1 FROM ref.site_track_source_binding b
            WHERE b.site_track_id=v_target AND b.accepted_at IS NOT NULL
        ) THEN
            RAISE EXCEPTION 'Track must have an accepted GPX source binding'
                USING ERRCODE='22023';
        END IF;
        IF v_before->>'track_label' IS DISTINCT FROM p_data->>'expected_track_label' THEN
            RAISE EXCEPTION 'Track name changed; refresh and re-review before saving'
                USING ERRCODE='40001';
        END IF;
        IF v_before->>'track_label' = v_code THEN
            RAISE EXCEPTION 'Track label already current; no new review recorded'
                USING ERRCODE='22023';
        END IF;
        UPDATE ref.site_track t SET track_label=v_code,verified_by=p_email,
            verified_at=clock_timestamp(),changed_at=clock_timestamp()
        WHERE t.site_track_id=v_target;
        SELECT jsonb_build_object('track_id',t.site_track_id,
                   'track_label',t.track_label,
                   'verified_by',t.verified_by,'verified_at',t.verified_at,
                   'changed_at',t.changed_at)
          INTO v_after
          FROM ref.site_track t WHERE t.site_track_id=v_target;

    ELSIF p_command='manager_add_alias' THEN
        v_target := (p_data->>'waypoint_id')::bigint;
        v_code := nullif(btrim(p_data->>'alias_text'),'');
        IF v_target IS NULL OR v_code IS NULL OR
           NOT EXISTS(SELECT 1 FROM ref.site_waypoint w WHERE w.site_waypoint_id=v_target) THEN
            RAISE EXCEPTION 'Existing waypoint and explicit alias required'
                USING ERRCODE='22023';
        END IF;
        IF EXISTS(SELECT 1 FROM ref.site_waypoint w
                  WHERE lower(btrim(w.canonical_label))=lower(v_code))
           OR EXISTS(SELECT 1 FROM ref.site_waypoint_alias a
                  WHERE lower(btrim(a.alias_text))=lower(v_code)) THEN
            RAISE EXCEPTION 'Alias already names a waypoint; review identity conflict'
                USING ERRCODE='23505';
        END IF;
        INSERT INTO ref.site_waypoint_alias(site_waypoint_id,alias_text,alias_source,
              alias_notes,accepted_by,accepted_at)
        VALUES(v_target,v_code,coalesce(nullif(btrim(p_data->>'alias_source'),''),
               'FIELD_REVIEW'),v_evidence,p_email,clock_timestamp())
        RETURNING alias_id INTO v_waypoint;
        SELECT to_jsonb(a) INTO v_after FROM ref.site_waypoint_alias a
        WHERE a.alias_id=v_waypoint;

    ELSIF p_command='manager_add_network' THEN
        v_code:=nullif(btrim(p_data->>'network_code'),'');
        IF v_code IS NULL OR p_data->>'network_kind' NOT IN ('LOR','IP','OTHER') THEN
            RAISE EXCEPTION 'Named network and explicit kind required' USING ERRCODE='22023';
        END IF;
        INSERT INTO ref.site_network(network_code,network_kind,notes)
          VALUES(v_code,p_data->>'network_kind',v_evidence)
          RETURNING site_network_id INTO v_target;
        SELECT to_jsonb(n) INTO v_after FROM ref.site_network n WHERE site_network_id=v_target;

    ELSIF p_command='manager_create_cable' THEN
        -- Create one physical cable only after operator selects two EXISTING
        -- waypoint identities and a reviewed network or explicit SPARE label.
        -- Parallel cables with identical endpoints remain distinct identities.
        v_waypoint := (p_data->>'endpoint_a_waypoint_id')::bigint;
        v_panel := (p_data->>'endpoint_b_waypoint_id')::bigint;
        v_network := nullif(p_data->>'network_id','')::bigint;
        v_code := nullif(btrim(p_data->>'spare_designation'),'');
        IF v_waypoint IS NULL OR v_panel IS NULL OR v_waypoint=v_panel OR
           NOT EXISTS(SELECT 1 FROM ref.site_waypoint WHERE site_waypoint_id=v_waypoint) OR
           NOT EXISTS(SELECT 1 FROM ref.site_waypoint WHERE site_waypoint_id=v_panel) THEN
           RAISE EXCEPTION 'Two distinct, existing physical endpoint waypoints are required'
               USING ERRCODE='22023';
        END IF;
        IF (v_network IS NULL) = (v_code IS NULL) THEN
            RAISE EXCEPTION 'Choose exactly one reviewed network or explicit SPARE designation'
                USING ERRCODE='22023';
        END IF;
        IF v_network IS NOT NULL AND NOT EXISTS(
               SELECT 1 FROM ref.site_network WHERE site_network_id=v_network) THEN
            RAISE EXCEPTION 'Selected network does not exist' USING ERRCODE='22023';
        END IF;
        IF coalesce(p_data->>'lifecycle_status','CURRENT')
           NOT IN ('CURRENT','FAILED','REPAIRED') THEN
            RAISE EXCEPTION 'Cable review needs explicit current/failed/repaired lifecycle'
                USING ERRCODE='22023';
        END IF;
        INSERT INTO ref.site_cable(
            endpoint_a_waypoint_id,endpoint_b_waypoint_id,site_network_id,
            spare_designation,lifecycle_status,reviewed_by,reviewed_at,notes)
        VALUES(v_waypoint,v_panel,v_network,v_code,
               coalesce(p_data->>'lifecycle_status','CURRENT'),p_email,
               clock_timestamp(),v_evidence)
        RETURNING site_cable_id INTO v_target;
        SELECT to_jsonb(c) INTO v_after FROM ref.site_cable c
        WHERE c.site_cable_id=v_target;

    ELSIF p_command='manager_retire_cable' THEN
        v_target := (p_data->>'site_cable_id')::bigint;
        v_code := nullif(btrim(p_data->>'lifecycle_status'),'');
        IF v_code NOT IN ('REPLACED','DESTROYED','ABANDONED','RETIRED') THEN
            RAISE EXCEPTION 'Retirement needs explicit reviewed lifecycle'
                USING ERRCODE='22023';
        END IF;
        SELECT to_jsonb(c) INTO v_before FROM ref.site_cable c
          WHERE c.site_cable_id=v_target AND c.reviewed_at IS NOT NULL FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'Reviewed physical cable not found'
              USING ERRCODE='P0002'; END IF;
        IF v_before->>'lifecycle_status'=v_code THEN
            RAISE EXCEPTION 'Cable is already in that lifecycle; no change to record'
                USING ERRCODE='22023';
        END IF;
        UPDATE ref.site_cable c SET lifecycle_status=v_code,
            retired_at=coalesce(nullif(p_data->>'retired_at','')::date, current_date),
            notes=concat_ws(E'
',nullif(c.notes,''),v_evidence)
        WHERE c.site_cable_id=v_target RETURNING to_jsonb(c) INTO v_after;

    ELSIF p_command='manager_link_test' THEN
        -- Stable UUID identity is never equated to a physical cable ID.
        -- A later correction retains the source and all previous decisions.
        IF NOT (p_data ? 'expected_cable_id') THEN
            RAISE EXCEPTION 'Explicit previous cable binding required (null permitted)'
                USING ERRCODE='22023';
        END IF;
        v_source_sha:=lower(btrim(p_data->>'source_sha256'));
        IF v_source_sha IS NULL OR v_source_sha !~ '^[0-9a-f]{64}$' THEN
            RAISE EXCEPTION 'Source SHA256 required for identity decision'
                USING ERRCODE='22023';
        END IF;
        v_test_uuid:=(p_data->>'test_uuid')::uuid;
        v_cable:=(p_data->>'site_cable_id')::bigint;
        IF v_cable IS NULL THEN
            RAISE EXCEPTION 'An existing reviewed physical cable ID is required'
                USING ERRCODE='22023';
        END IF;
        PERFORM 1 FROM ref.site_cable c WHERE c.site_cable_id=v_cable
          AND c.reviewed_by IS NOT NULL AND c.reviewed_at IS NOT NULL
          AND c.endpoint_a_waypoint_id IS NOT NULL AND c.endpoint_b_waypoint_id IS NOT NULL
          AND c.lifecycle_status NOT IN ('DESTROYED','RETIRED','REPLACED','ABANDONED')
          FOR SHARE;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'Selected physical cable is not reviewed/active'
                USING ERRCODE='22023';
        END IF;
        -- Do not clone immutable BinRec original_result into each audit event.
        SELECT jsonb_build_object('test_uuid',t.test_uuid,
                    'physical_site_cable_id',t.physical_site_cable_id,
                    'identity_review_status',t.identity_review_status,
                    'reviewed_by',t.reviewed_by,'reviewed_at',t.reviewed_at),
               t.physical_site_cable_id
          INTO v_before,v_expected_cable
          FROM ops.linkiq_test t WHERE t.test_uuid=v_test_uuid FOR UPDATE;
        IF NOT FOUND THEN RAISE EXCEPTION 'LinkIQ UUID not found' USING ERRCODE='P0002'; END IF;
        IF v_expected_cable IS DISTINCT FROM (p_data->>'expected_cable_id')::bigint THEN
            RAISE EXCEPTION 'Reviewed test binding changed; refresh before deciding'
                USING ERRCODE='40001';
        END IF;
        IF v_expected_cable IS NOT DISTINCT FROM v_cable AND
           v_before->>'identity_review_status'='REVIEWED' THEN
            RAISE EXCEPTION 'Test already reviewed to this cable; no new decision needed'
                USING ERRCODE='22023';
        END IF;
        IF NOT EXISTS(SELECT 1 FROM ops.linkiq_intake_review r
           WHERE r.source_sha256=v_source_sha AND r.test_uuid=v_test_uuid) THEN
            RAISE EXCEPTION 'No retained source proposal for this test UUID/SHA'
                USING ERRCODE='22023';
        END IF;
        INSERT INTO ops.linkiq_identity_decision(
            source_sha256,test_uuid,previous_cable_id,site_cable_id,actor,evidence_notes)
        VALUES(v_source_sha,v_test_uuid,v_expected_cable,v_cable,p_email,v_evidence);
        UPDATE ops.linkiq_test t SET physical_site_cable_id=v_cable,
            identity_review_status='REVIEWED',reviewed_by=p_email,
            reviewed_at=clock_timestamp()
        WHERE t.test_uuid=v_test_uuid;
        v_target:=v_cable;
        SELECT jsonb_build_object('test_uuid',t.test_uuid,
                    'physical_site_cable_id',t.physical_site_cable_id,
                    'identity_review_status',t.identity_review_status,
                    'reviewed_by',t.reviewed_by,'reviewed_at',t.reviewed_at)
          INTO v_after FROM ops.linkiq_test t WHERE t.test_uuid=v_test_uuid;

    END IF;

    UPDATE ref.site_reference_revision SET revision=revision+1,
       changed_at=clock_timestamp() WHERE singleton=true RETURNING revision INTO v_current;
    INSERT INTO ops.site_reference_edit_log(
      revision,operator_email,directus_user_id,person_id,named_command,target_id,evidence_notes,before_data,after_data)
    VALUES(v_current,p_email,v_actor.directus_user_id,v_actor.person_id,p_command,v_target,v_evidence,v_before,v_after);
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
