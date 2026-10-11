-- #171/#319/#230 disposable-only PostgreSQL acceptance.
-- Must run AFTER candidate schema on an isolated current-Production clone.
-- All test fixture data is rolled back; schema migration remains in disposable only.
\set ON_ERROR_STOP on
BEGIN;

DO $acceptance$
DECLARE
    v_missing text;
    v_source_sha text := md5('msb-171-disposable:' || gen_random_uuid()::text)
                      || md5(clock_timestamp()::text || gen_random_uuid()::text);
    v_evidence_sha text := md5('linkiq-test-uuid:' || gen_random_uuid()::text)
                        || md5(gen_random_uuid()::text);
    v_test uuid := gen_random_uuid();
    v_a bigint;
    v_b bigint;
    v_net bigint;
    v_cable bigint;
    v_parallel bigint;
    v_spare bigint;
    v_count integer;
    v_inserted integer;
    v_link bigint;
BEGIN
    -- Confirm schema types are real PostGIS rather than a text-only copy.
    SELECT string_agg(v.name, ', ') INTO v_missing
      FROM (VALUES
          ('ref.site_waypoint'), ('ref.site_waypoint_source_binding'),
          ('ref.site_waypoint_alias'), ('ref.site_track'),
          ('ref.site_network'), ('ref.site_cable'),
          ('ref.site_schematic_binding'),
          ('ops.site_source_batch'), ('ops.site_source_observation'),
          ('ops.linkiq_test'), ('ops.linkiq_test_appearance')
      ) AS v(name)
     WHERE to_regclass(v.name) IS NULL;
    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION 'Missing proposed site tables: %', v_missing;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM geometry_columns
         WHERE f_table_schema='ref' AND f_table_name='site_waypoint'
           AND f_geometry_column='current_point' AND srid=8158
           AND type='POINT'
    ) THEN
        RAISE EXCEPTION 'ref.site_waypoint current_point SRID/type contract differs from EPSG:8158 Point';
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM geometry_columns
         WHERE f_table_schema='ref' AND f_table_name='site_track'
           AND f_geometry_column='reference_line' AND srid=8158
           AND type='MULTILINESTRING'
    ) THEN
        RAISE EXCEPTION 'ref.site_track reference_line SRID/type contract differs from EPSG:8158 MultiLineString';
    END IF;

    INSERT INTO ref.site_waypoint (canonical_label, waypoint_type, current_point)
    VALUES (
       '319-DISPOSABLE-' || v_test::text || '-A', 'OUT-Combo',
       ST_SetSRID(ST_MakePoint(100000, 100000), 8158)
    ) RETURNING site_waypoint_id INTO v_a;

    INSERT INTO ref.site_waypoint (canonical_label, waypoint_type, current_point)
    VALUES (
       '319-DISPOSABLE-' || v_test::text || '-B', 'OUT-Combo',
       ST_SetSRID(ST_MakePoint(100100, 100100), 8158)
    ) RETURNING site_waypoint_id INTO v_b;

    INSERT INTO ref.site_network (network_code, network_kind)
    VALUES ('319-DISPOSABLE-' || v_test::text, 'LOR')
    RETURNING site_network_id INTO v_net;

    INSERT INTO ref.site_cable (endpoint_a_waypoint_id, endpoint_b_waypoint_id,
                                site_network_id, lifecycle_status)
    VALUES (v_a, v_b, v_net, 'CURRENT')
    RETURNING site_cable_id INTO v_cable;

    -- Distinct physical cables may share endpoints and a network; never dedupe these.
    INSERT INTO ref.site_cable (endpoint_a_waypoint_id, endpoint_b_waypoint_id,
                                site_network_id, lifecycle_status)
    VALUES (v_a, v_b, v_net, 'CURRENT')
    RETURNING site_cable_id INTO v_parallel;
    IF v_cable = v_parallel THEN
        RAISE EXCEPTION 'Parallel cables were incorrectly collapsed';
    END IF;

    -- Spare designation represents valid installed physical cable with NO LOR assignment.
    INSERT INTO ref.site_cable (endpoint_a_waypoint_id, endpoint_b_waypoint_id,
                                spare_designation, lifecycle_status)
    VALUES (v_a, v_b, 'SPARE-1', 'CURRENT')
    RETURNING site_cable_id INTO v_spare;

    INSERT INTO ops.site_source_batch
      (source_sha256, source_kind, original_filename, actor)
    VALUES (v_source_sha,'LINKIQ_FLW','DISPOSABLE-TEST.flw','319-disposable');

    INSERT INTO ops.linkiq_test
      (test_uuid, first_seen_source_sha256, tester_original_name,
       test_status_code, test_standard, length_ft, nvp,
       evidence_sha256, original_result, physical_site_cable_id,
       identity_review_status, reviewed_by, reviewed_at)
    VALUES (v_test, v_source_sha, 'IT-00 TO A5-01 REG',
            1, '1000BASE-T', 64.0, 0.68,
            v_evidence_sha, '{"source":"test-fixture"}'::jsonb,
            v_cable, 'REVIEWED', '319-disposable', clock_timestamp());

    -- Replay the same test UUID. It must not duplicate or overwrite reviewed links.
    INSERT INTO ops.linkiq_test
      (test_uuid, first_seen_source_sha256, tester_original_name,
       evidence_sha256, original_result)
    VALUES (v_test, v_source_sha, 'INCORRECT NAME',
            v_evidence_sha, '{"source":"bad-updated-label"}'::jsonb)
    ON CONFLICT (test_uuid) DO NOTHING;
    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    IF v_inserted <> 0 THEN
        RAISE EXCEPTION 'Re-import created duplicate test UUID';
    END IF;
    SELECT count(*), max(physical_site_cable_id)
      INTO v_count, v_link FROM ops.linkiq_test WHERE test_uuid=v_test;
    IF v_count <> 1 OR v_link <> v_cable THEN
        RAISE EXCEPTION 'Re-import displaced reviewed physical cable identity';
    END IF;

    -- Two project copies of the same UUID remain distinct provenance, not tests.
    INSERT INTO ops.linkiq_test_appearance
      (source_sha256, source_row, test_uuid, linkware_project,
       display_cable_name, original_test_name, record_payload_sha256)
    VALUES
      (v_source_sha,1,v_test,'MSB-Park-Network','A5-02A TO A5-01 REG',
       'IT-00 TO A5-01 REG', v_evidence_sha),
      (v_source_sha,2,v_test,'Park Network','IT-00 TO A5-01 REG',
       'IT-00 TO A5-01 REG', v_evidence_sha);
    INSERT INTO ops.linkiq_test_appearance
      (source_sha256, source_row, test_uuid, linkware_project,
       display_cable_name, original_test_name, record_payload_sha256)
    VALUES (v_source_sha,1,v_test,'Park Network','INCORRECT NAME',
            'IT-00 TO A5-01 REG', v_evidence_sha)
    ON CONFLICT (source_sha256, source_row) DO NOTHING;
    GET DIAGNOSTICS v_inserted = ROW_COUNT;
    IF v_inserted <> 0 THEN
        RAISE EXCEPTION 'Repeat source appearance inserted a duplicate';
    END IF;
    SELECT count(*) INTO v_count
      FROM ops.linkiq_test_appearance WHERE test_uuid=v_test;
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'Cross-project source appearance count was not preserved';
    END IF;
    IF (SELECT display_cable_name
          FROM ops.linkiq_test_appearance
         WHERE source_sha256=v_source_sha AND source_row=1)
       <> 'A5-02A TO A5-01 REG' THEN
        RAISE EXCEPTION 'Repeat source import overwritten corrected LinkWare name';
    END IF;

    -- New reference tables should not permit direct broad FieldWiring DML.
    IF to_regrole('fieldwiring_app') IS NOT NULL AND
       (has_table_privilege('fieldwiring_app','ref.site_waypoint','INSERT')
        OR has_table_privilege('fieldwiring_app','ref.site_cable','UPDATE')
        OR has_table_privilege('fieldwiring_app','ops.linkiq_test','DELETE')) THEN
        RAISE EXCEPTION 'Field Wiring application principal has unintended site-reference write privileges';
    END IF;
END
$acceptance$;

ROLLBACK;
\echo 'PASS: #171/#319 disposable schema, identity, parallel cable, spare and UUID-replay assertions'
