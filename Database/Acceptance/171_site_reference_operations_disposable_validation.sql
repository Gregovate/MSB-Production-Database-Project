-- #171/#230 under #122: disposable-only site operations/authorization audit tests.
-- Apply 171_site_infrastructure_schema_candidate.sql FIRST, then
-- 171_site_reference_operations_candidate.sql. No Production writes.
\set ON_ERROR_STOP on
BEGIN;
DO $accept$
DECLARE
    v_uuid text := gen_random_uuid()::text;
    v_panel bigint; v_outlet_a bigint; v_outlet_b bigint;
    v_network bigint; v_circuit bigint; v_cable bigint; v_second_cable bigint;
    v_test uuid := gen_random_uuid();
    v_sha text := md5(gen_random_uuid()::text) || md5(gen_random_uuid()::text);
    v_rev bigint; v_out jsonb; v_snapshot jsonb;
    v_denied boolean := false;
BEGIN
    SELECT revision INTO v_rev FROM ref.site_reference_revision WHERE singleton;
    IF v_rev IS NULL THEN RAISE EXCEPTION 'Reference revision singleton missing'; END IF;
    -- App role receives only named EXECUTE; no generic ref.* DML.
    IF to_regrole('fieldwiring_app') IS NOT NULL THEN
        IF has_table_privilege('fieldwiring_app','ref.site_waypoint','UPDATE')
           OR has_table_privilege('fieldwiring_app','ref.site_power_circuit','INSERT')
           OR has_table_privilege('fieldwiring_app','ref.site_circuit_destination','DELETE')
           OR has_table_privilege('fieldwiring_app','ops.site_reference_edit_log','DELETE')
           OR NOT has_function_privilege('fieldwiring_app',
                'ref.site_reference_snapshot()','EXECUTE')
           OR NOT has_function_privilege('fieldwiring_app',
                'ref.site_reference_command(text,text,bigint,jsonb)','EXECUTE') THEN
            RAISE EXCEPTION 'App role has incorrect site-reference privileges';
        END IF;
    END IF;
    IF (ref.site_reference_permissions('crew@example.test')->>'operations')::boolean
        OR (ref.site_reference_permissions('manager@example.test')->>'identity')::boolean THEN
        RAISE EXCEPTION 'GIS reference editor must default deny';
    END IF;
    INSERT INTO ref.site_waypoint(canonical_label,waypoint_type,current_point)
    VALUES('DISPOSABLE-PANEL-'||v_uuid,'Panel',
        ST_SetSRID(ST_MakePoint(100000,100000),8158))
    RETURNING site_waypoint_id INTO v_panel;
    INSERT INTO ref.site_waypoint(canonical_label,waypoint_type,current_point)
    VALUES('DISPOSABLE-OUT-A-'||v_uuid,'OUT-Combo',
        ST_SetSRID(ST_MakePoint(100020,100030),8158))
    RETURNING site_waypoint_id INTO v_outlet_a;
    INSERT INTO ref.site_waypoint(canonical_label,waypoint_type,current_point)
    VALUES('DISPOSABLE-OUT-B-'||v_uuid,'OUT-Combo',
        ST_SetSRID(ST_MakePoint(100035,100040),8158))
    RETURNING site_waypoint_id INTO v_outlet_b;

    -- Direct crew edit before positive grant must FAIL under SQL backstop.
    BEGIN
        PERFORM ref.site_reference_command('crew@example.test','crew_set_meter',v_rev,
            jsonb_build_object('waypoint_id',v_panel,'meter_identifier','TEST',
                               'evidence_notes','Fixture only'));
        RAISE EXCEPTION 'Unprivileged crew was granted an editor command';
    EXCEPTION WHEN SQLSTATE '42501' THEN v_denied:=true;
    END;
    IF NOT v_denied THEN RAISE EXCEPTION 'Missing default-deny assertion'; END IF;

    INSERT INTO ref.site_editor_grant(
        operator_email,can_manage_identity,can_maintain_operations,
        active,granted_by,evidence_notes)
    VALUES('manager@example.test',true,false,true,'319-disposable','Fixture only'),
          ('crew@example.test',false,true,true,'319-disposable','Fixture only');

    -- Operations-only cannot change waypoint names or surveyed coordinates.
    BEGIN
        PERFORM ref.site_reference_command('crew@example.test','manager_update_waypoint',
            v_rev,jsonb_build_object('waypoint_id',v_panel,'label','BAD',
                         'evidence_notes','Fixture only'));
        RAISE EXCEPTION 'Crew was allowed to modify waypoint identity';
    EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
    END;

    -- Manager explicitly reviews ownership (UNKNOWN must be initial default).
    v_out := ref.site_reference_command('manager@example.test','manager_set_panel_owner',
        v_rev,jsonb_build_object('waypoint_id',v_panel,'owner_code','CITY',
                    'evidence_notes','Disposable documented ownership'));
    v_rev := (v_out->>'revision')::bigint;
    v_out := ref.site_reference_command('crew@example.test','crew_set_meter',v_rev,
        jsonb_build_object('waypoint_id',v_panel,'meter_identifier','M-TEST-319',
                    'evidence_notes','Disposable meter check'));
    v_rev := (v_out->>'revision')::bigint;
    v_out := ref.site_reference_command('crew@example.test','crew_upsert_circuit',v_rev,
        jsonb_build_object('panel_waypoint_id',v_panel,'circuit_code','12 A',
             'circuit_label','Test outputs','breaker_rating_amps',20,
             'evidence_notes','Disposable breaker check'));
    v_rev := (v_out->>'revision')::bigint;
    v_circuit := (v_out->>'target_id')::bigint;
    IF v_circuit IS NULL THEN RAISE EXCEPTION 'Circuit ID not returned'; END IF;
    -- Two distinct OUT waypoints on ONE circuit; geographic closeness not used.
    v_out := ref.site_reference_command('crew@example.test','crew_link_destination',v_rev,
        jsonb_build_object('circuit_id',v_circuit,'waypoint_id',v_outlet_a,
             'evidence_notes','Field verified test link A'));
    v_rev := (v_out->>'revision')::bigint;
    v_out := ref.site_reference_command('crew@example.test','crew_link_destination',v_rev,
        jsonb_build_object('circuit_id',v_circuit,'waypoint_id',v_outlet_b,
             'evidence_notes','Field verified test link B'));
    v_rev := (v_out->>'revision')::bigint;
    IF (SELECT count(*) FROM ref.site_circuit_destination
        WHERE site_power_circuit_id=v_circuit)<>2 THEN
        RAISE EXCEPTION 'Multi-outlet circuit links not conserved';
    END IF;
    v_out := ref.site_reference_command('manager@example.test','manager_set_circuit_owner',
        v_rev,jsonb_build_object('circuit_id',v_circuit,'owner_code','MSB',
             'evidence_notes','Fixture split panel/circuit ownership'));
    v_rev := (v_out->>'revision')::bigint;

    -- Explicit maintained network membership is independent of power circuit.
    v_out := ref.site_reference_command('manager@example.test','manager_add_network',v_rev,
        jsonb_build_object('network_code','DISPOSABLE-NET-'||v_uuid,
            'network_kind','LOR','evidence_notes','Fixture network designation'));
    v_rev := (v_out->>'revision')::bigint;
    v_network := (v_out->>'target_id')::bigint;
    v_out := ref.site_reference_command('crew@example.test','crew_assign_network',v_rev,
        jsonb_build_object('waypoint_id',v_outlet_a,'network_id',v_network,
                           'evidence_notes','Fixture reviewed port connection'));
    v_rev := (v_out->>'revision')::bigint;
    v_out := ref.site_reference_command('crew@example.test','crew_set_switching',v_rev,
        jsonb_build_object('circuit_id',v_circuit,'season_year',2026,
            'turn_on_instruction','MSB tech confirms before energizing',
            'turn_off_instruction','MSB tech signs off before shutdown',
            'evidence_notes','Fixture operational plan, not observed state'));
    v_rev := (v_out->>'revision')::bigint;

    -- Stale editor tabs cannot overwrite an updated revision.
    BEGIN
        PERFORM ref.site_reference_command('crew@example.test','crew_set_meter',v_rev-1,
            jsonb_build_object('waypoint_id',v_panel,'meter_identifier','BAD',
                                'evidence_notes','Stale fixture'));
        RAISE EXCEPTION 'Stale revision silently applied';
    EXCEPTION WHEN SQLSTATE '40001' THEN NULL;
    END;

    -- The same endpoints may support a distinct reviewed physical cable.
    -- LinkIQ UUID/result and test standard are evidence, not guessed speed.
    INSERT INTO ops.site_source_batch(source_sha256,source_kind,original_filename,actor)
    VALUES(v_sha,'LINKIQ_FLW','disposable-only.flw','319-disposable');
    INSERT INTO ref.site_cable(endpoint_a_waypoint_id,endpoint_b_waypoint_id,
                               site_network_id,lifecycle_status,reviewed_by,reviewed_at)
    VALUES(v_panel,v_outlet_a,v_network,'CURRENT','319-disposable',clock_timestamp())
    RETURNING site_cable_id INTO v_cable;
    INSERT INTO ops.linkiq_test(test_uuid,first_seen_source_sha256,tester_original_name,
           test_time_local,test_status_code,test_standard,length_ft,evidence_sha256,
           original_result,identity_review_status)
    VALUES(v_test,v_sha,'DISPOSABLE-Raw Tester Name','2026-10-11T17:00:00',
           1,'1000BASE-T',132.4,v_sha,'{"test":"fixture"}'::jsonb,'UNMATCHED');
    INSERT INTO ops.linkiq_test_appearance(source_sha256,source_row,test_uuid,
        linkware_project,display_cable_name,original_test_name,record_payload_sha256)
    VALUES(v_sha,1,v_test,'MSB-Park-Network','DISPOSABLE corrected name',
           'DISPOSABLE-Raw Tester Name',v_sha);
    INSERT INTO ops.linkiq_intake_review(source_sha256,test_uuid,proposal,actor)
    VALUES(v_sha,v_test,'{"status":"REVIEW_REQUIRED"}'::jsonb,'319-disposable');

    -- Reviewed identity is created by a separately attributed manager decision.
    -- Multiple cables between the SAME endpoints/network are not collapsed.
    v_out:=ref.site_reference_command('manager@example.test','manager_create_cable',v_rev,
       jsonb_build_object('endpoint_a_waypoint_id',v_panel,
          'endpoint_b_waypoint_id',v_outlet_a,'network_id',v_network,
          'lifecycle_status','CURRENT',
          'evidence_notes','Independent fixture cable physically verified'));
    v_rev:=(v_out->>'revision')::bigint;
    v_second_cable:=(v_out->>'target_id')::bigint;
    IF v_second_cable=v_cable THEN
       RAISE EXCEPTION 'Distinct reviewed parallel cables were collapsed';
    END IF;
    v_out:=ref.site_reference_command('manager@example.test','manager_link_test',v_rev,
       jsonb_build_object('source_sha256',v_sha,'test_uuid',v_test,
          'site_cable_id',v_cable,'expected_cable_id',NULL,
          'evidence_notes','Test UUID reviewed by source identity, not label'));
    v_rev:=(v_out->>'revision')::bigint;
    IF (SELECT physical_site_cable_id FROM ops.linkiq_test WHERE test_uuid=v_test)
        IS DISTINCT FROM v_cable THEN
        RAISE EXCEPTION 'Reviewed physical cable binding failed';
    END IF;
    BEGIN
       PERFORM ref.site_reference_command('manager@example.test','manager_link_test',v_rev,
          jsonb_build_object('source_sha256',v_sha,'test_uuid',v_test,
            'site_cable_id',v_second_cable,'expected_cable_id',NULL,
            'evidence_notes','Expected binding is intentionally stale'));
       RAISE EXCEPTION 'Expected prior binding was ignored';
    EXCEPTION WHEN SQLSTATE '40001' THEN NULL;
    END;
    -- A later explicit correction preserves the SAME UUID and an additional
    -- append-only decision; it never creates a new test or edits raw payload.
    v_out:=ref.site_reference_command('manager@example.test','manager_link_test',v_rev,
       jsonb_build_object('source_sha256',v_sha,'test_uuid',v_test,
          'site_cable_id',v_second_cable,'expected_cable_id',v_cable,
          'evidence_notes','Reviewed corrected cable after independent observation'));
    v_rev:=(v_out->>'revision')::bigint;
    IF (SELECT count(*) FROM ops.linkiq_test WHERE test_uuid=v_test)<>1 OR
       (SELECT count(*) FROM ops.linkiq_identity_decision WHERE test_uuid=v_test)<>2 OR
       (SELECT physical_site_cable_id FROM ops.linkiq_test WHERE test_uuid=v_test)
           IS DISTINCT FROM v_second_cable OR
       (SELECT tester_original_name FROM ops.linkiq_test WHERE test_uuid=v_test)
           <>'DISPOSABLE-Raw Tester Name' THEN
       RAISE EXCEPTION 'Reviewed correction destroyed source/test history';
    END IF;

    v_snapshot := ref.site_reference_snapshot();
    IF (v_snapshot->>'revision')::bigint <> v_rev
       OR v_snapshot->>'data_mode'<>'postgres' THEN
       RAISE EXCEPTION 'Map projection missed latest maintained revision';
    END IF;
    IF (SELECT count(*) FROM jsonb_array_elements(v_snapshot->'destinations') AS d
        WHERE (d->>'site_power_circuit_id')::bigint=v_circuit)<>2 THEN
        RAISE EXCEPTION 'Map projection lost reviewed destinations';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v_snapshot->'memberships') m
         WHERE (m->>'site_waypoint_id')::bigint=v_outlet_a
           AND (m->>'site_network_id')::bigint=v_network) THEN
        RAISE EXCEPTION 'Map projection lost explicit network membership';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v_snapshot->'panels') p
         WHERE (p->>'site_waypoint_id')::bigint=v_panel
           AND p->>'owner_code'='CITY'
           AND p->>'meter_identifier'='M-TEST-319') THEN
        RAISE EXCEPTION 'Map projection missing owner or crew-maintained meter';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v_snapshot->'circuits') c
         WHERE (c->>'site_power_circuit_id')::bigint=v_circuit
           AND c->>'owner_code'='MSB') THEN
        RAISE EXCEPTION 'Circuit owner incorrectly inherited panel owner';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v_snapshot->'instructions') i
         WHERE (i->>'site_power_circuit_id')::bigint=v_circuit
           AND i->>'turn_on_instruction' LIKE '%confirms%') THEN
        RAISE EXCEPTION 'Planned switching instructions missing';
    END IF;
    IF (SELECT count(*) FROM ops.site_reference_edit_log
         WHERE operator_email IN ('manager@example.test','crew@example.test')
           AND revision<=v_rev)<9 THEN
        RAISE EXCEPTION 'Missing attributed revisioned reference audit';
    END IF;

    -- A LinkIQ test standard is never an achieved speed measurement.
    IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v_snapshot->'cables') c,
                 LATERAL jsonb_array_elements(c->'tests') t
                 WHERE (c->>'id')::bigint=v_second_cable
                   AND t->>'uuid'=v_test::text
                   AND t->>'test_standard'='1000BASE-T'
                   AND (t->>'length_ft')::numeric=132.4
                   AND t->>'measured_link_speed_mbps' IS NULL) THEN
        RAISE EXCEPTION 'LinkIQ test evidence/speed-unknown contract violated';
    END IF;
END;
$accept$;
ROLLBACK;
\echo 'PASS: #171/#230 reference default-deny, audited commands, live map, m:n circuits, network, switching, meter and speed-unknown'
