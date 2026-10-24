-- Combined #319/#454 assertions, current-clone compatible and rollback-only.
-- Order: infrastructure foundation, power capture, GIS operations.
\set ON_ERROR_STOP on
BEGIN;
DO $accept$
DECLARE
 tag text := gen_random_uuid()::text;
 a bigint; b bigint; p bigint; c bigint; d bigint; f bigint;
 snapshot jsonb; result jsonb; net bigint; cable bigint; segment bigint; track bigint; breaker bigint;
BEGIN
 IF to_regclass('ref.site_editor_grant') IS NOT NULL
 OR to_regclass('ref.site_circuit_destination') IS NOT NULL
 OR to_regclass('ref.site_seasonal_switch_instruction') IS NOT NULL THEN
  RAISE EXCEPTION 'Competing legacy GIS power/grant tables exist';
 END IF;
 IF has_table_privilege('fieldwiring_app','ref.site_waypoint','UPDATE')
 OR has_table_privilege('fieldwiring_app','ref.site_power_circuit','INSERT')
 OR has_table_privilege('fieldwiring_app','ops.site_power_edit_log','DELETE') THEN
  RAISE EXCEPTION 'Runtime has direct reference write privilege';
 END IF;
 IF (ref.site_reference_permissions('nonexistent-'||tag||'@example.invalid')->>'identity')::boolean THEN
  RAISE EXCEPTION 'Unknown identity was granted GIS maintenance';
 END IF;
 BEGIN
  PERFORM ref.site_reference_command('nonexistent-'||tag||'@example.invalid',
   'manager_update_waypoint',0,'{"evidence_notes":"disposable denial"}');
  RAISE EXCEPTION 'Unknown actor accepted';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
 END;
 BEGIN
  PERFORM ref.site_reference_command('nonexistent-'||tag||'@example.invalid',
   'crew_upsert_circuit',0,'{"evidence_notes":"obsolete command"}');
  RAISE EXCEPTION 'Legacy power write accepted';
 EXCEPTION WHEN SQLSTATE '22023' THEN NULL;
 END;
 INSERT INTO ref.site_waypoint(canonical_label,current_point)
 VALUES('DISPOSABLE panel '||tag,ST_SetSRID(ST_MakePoint(100000,100000),8158)) RETURNING site_waypoint_id INTO a;
 INSERT INTO ref.site_waypoint(canonical_label,current_point)
 VALUES('DISPOSABLE outlet '||tag,ST_SetSRID(ST_MakePoint(100010,100010),8158)) RETURNING site_waypoint_id INTO b;
 INSERT INTO ref.site_panel(panel_name,site_waypoint_id,source_evidence)
 VALUES('DISPOSABLE '||tag,a,'Rollback fixture only') RETURNING site_panel_id INTO p;
 INSERT INTO ref.site_power_circuit(site_panel_id,circuit_code,source_evidence)
 VALUES(p,'1','Rollback fixture only') RETURNING site_power_circuit_id INTO c;
 INSERT INTO ref.site_power_device(device_name,device_kind,source_evidence)
 VALUES('DISPOSABLE disconnect '||tag,'DISCONNECT','Rollback fixture only') RETURNING site_power_device_id INTO d;
 INSERT INTO ref.site_power_feed(source_circuit_id,destination_device_id,source_evidence)
 VALUES(c,d,'Rollback fixture only');
 INSERT INTO ref.site_power_feed(source_device_id,destination_waypoint_id,source_evidence)
 VALUES(d,b,'Rollback fixture only') RETURNING site_power_feed_id INTO f;
 snapshot := ref.site_reference_snapshot();
 IF NOT EXISTS(SELECT FROM jsonb_array_elements(snapshot->'circuits') x
    WHERE (x->>'site_power_circuit_id')::bigint=c AND (x->>'site_panel_id')::bigint=p
      AND (x->>'panel_waypoint_id')::bigint=a) THEN
  RAISE EXCEPTION 'Map lost permanent panel/circuit identity';
 END IF;
 IF NOT EXISTS(SELECT FROM jsonb_array_elements(snapshot->'destinations') x
    WHERE (x->>'site_power_circuit_id')::bigint=c AND (x->>'site_waypoint_id')::bigint=b) THEN
  RAISE EXCEPTION 'Map lost recorded indirect equipment feed';
 END IF;
 UPDATE ref.site_power_feed SET active=false WHERE site_power_feed_id=f;
 snapshot := ref.site_reference_snapshot();
 IF EXISTS(SELECT FROM jsonb_array_elements(snapshot->'destinations') x
    WHERE (x->>'site_power_circuit_id')::bigint=c AND (x->>'site_waypoint_id')::bigint=b) THEN
  RAISE EXCEPTION 'Retired feed remains active on map';
 END IF;
 UPDATE ref.site_waypoint SET canonical_label='DISPOSABLE corrected '||tag WHERE site_waypoint_id=b;
 snapshot := ref.site_reference_snapshot();
 IF NOT EXISTS(SELECT FROM jsonb_array_elements(snapshot->'waypoints') x
    WHERE (x->>'id')::bigint=b AND x->>'label'='DISPOSABLE corrected '||tag) THEN
  RAISE EXCEPTION 'Map lost corrected current waypoint name';
 END IF;
 IF snapshot->>'power_editor_url'<>'/fieldwiring/circuits' THEN
  RAISE EXCEPTION 'Power editor handoff missing';
 END IF;
 -- Final integrated projections execute against the actual PG16/PostGIS catalog.
 IF NOT EXISTS(SELECT FROM ref.site_circuit_load WHERE site_power_circuit_id=c
   AND completeness='INCOMPLETE' AND recorded_display_amps IS NULL) THEN
  RAISE EXCEPTION 'Missing loads were treated as zero or complete';
 END IF;
 INSERT INTO ref.site_power_breaker(site_panel_id,breaker_name,breaker_role,rated_amps,pole_count)
 VALUES(p,'Disposable two-pole','BRANCH',20,2) RETURNING site_power_breaker_id INTO breaker;
 UPDATE ref.site_power_circuit SET site_power_breaker_id=breaker,breaker_pole=1 WHERE site_power_circuit_id=c;
 UPDATE ref.site_panel SET show_desired_state='ON',restoration_desired_state='OFF' WHERE site_panel_id=p;
 IF (SELECT rated_amps FROM ref.site_circuit_load WHERE site_power_circuit_id=c)<>20
 OR (SELECT restoration_desired_state FROM ref.site_power_breaker WHERE site_power_breaker_id=breaker)<>'UNKNOWN' THEN
  RAISE EXCEPTION 'Pole rating or independent panel plan failed';
 END IF;
 INSERT INTO ref.site_network(network_code,network_kind) VALUES('DISPOSABLE-'||tag,'LOR') RETURNING site_network_id INTO net;
 INSERT INTO ref.site_cable(endpoint_a_waypoint_id,endpoint_b_waypoint_id,site_network_id,lifecycle_status,reviewed_by,reviewed_at)
 VALUES(a,b,net,'CURRENT','Disposable',now()) RETURNING site_cable_id INTO cable;
 INSERT INTO ref.site_track(track_label,reference_line,lifecycle_status,changed_at)
 VALUES('Disposable',ST_GeomFromText('MULTILINESTRING((100000 100000,100010 100010))',8158),'CURRENT',now()) RETURNING site_track_id INTO track;
 INSERT INTO ref.site_route_segment(endpoint_a_waypoint_id,endpoint_b_waypoint_id,route_label,reference_line,review_status,reviewed_by,reviewed_at)
 VALUES(a,b,'Disposable',ST_GeomFromText('LINESTRING(100000 100000,100010 100010)',8158),'REVIEWED','Disposable',now()) RETURNING site_route_segment_id INTO segment;
 INSERT INTO ref.site_route_source_track VALUES(segment,track,'NET','Disposable review','Disposable',now());
 INSERT INTO ref.site_cable_route_segment VALUES(cable,1,segment,1,'Disposable',now());
 IF (SELECT count(*) FROM ref.site_network_availability WHERE site_cable_id=cable)<>2 THEN
  RAISE EXCEPTION 'Reviewed network route endpoints not available';
 END IF;
 UPDATE ref.site_track SET changed_at=now()+interval '1 second' WHERE site_track_id=track;
 IF EXISTS(SELECT FROM ref.site_network_availability WHERE site_cable_id=cable) THEN
  RAISE EXCEPTION 'Changed track incorrectly retains network availability';
 END IF;
 BEGIN
  PERFORM ref.site_power_command('nonexistent-'||tag||'@example.invalid',gen_random_uuid(),0,'network',NULL,'{}');
  RAISE EXCEPTION 'Retired network write accepted';
 EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
 END;
 IF has_table_privilege('fieldwiring_app','ref.site_network_availability','INSERT,UPDATE,DELETE')
 OR has_table_privilege('fieldwiring_app','ref.site_circuit_load','INSERT,UPDATE,DELETE') THEN
  RAISE EXCEPTION 'Projection write privilege leaked';
 END IF;
 PERFORM count(*) FROM ref.site_controller_network_requirement;
 PERFORM count(*) FROM ref.site_controller_placement_eligibility;
 PERFORM count(*) FROM ref.site_circuit_load_lineage;
 RAISE NOTICE 'PASS: integrated network source freshness, per-pole load, panel plan and network denial';
 RAISE NOTICE 'PASS: combined GIS/circuit identity, indirect feeds, retirement, current names, denied legacy writes';
END $accept$;
ROLLBACK;
