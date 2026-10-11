-- #171/#319/#230: CANDIDATE ONLY. Not an authorized Production migration.
-- Validate current schema and controlled migration number before promotion.
-- PostgreSQL/PostGIS authority: stable waypoint/cable IDs, source evidence, retests.
-- Original GPX/FLW/draw.io files are NEVER mutated by this schema.
BEGIN;

-- Refusing concurrent installs protects the identity bootstrap.
SELECT pg_advisory_xact_lock(hashtext('MSB:#171:site-infrastructure-schema'));

CREATE TABLE IF NOT EXISTS ref.site_waypoint (
    site_waypoint_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    canonical_label text NOT NULL CHECK (length(btrim(canonical_label)) > 0),
    source_garmin_name text,
    waypoint_type text NOT NULL DEFAULT '',
    current_point geometry(Point, 8158) NOT NULL,
    source_wgs84 geometry(Point, 4326),
    source_comment text,
    source_description text,
    source_time text, -- Source timestamps are provenance, not install timestamps
    verified_by text,
    verified_at timestamptz,
    updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CHECK (ST_IsValid(current_point))
);
CREATE UNIQUE INDEX IF NOT EXISTS site_waypoint_canonical_label_unique
    ON ref.site_waypoint (lower(btrim(canonical_label)));

-- Approved source binding pins a specific GPX baseline to a permanent waypoint.
-- This is essential for deterministic two-way reconciliation and export.
CREATE TABLE IF NOT EXISTS ref.site_waypoint_source_binding (
    site_waypoint_id bigint NOT NULL REFERENCES ref.site_waypoint(site_waypoint_id),
    source_sha256 text NOT NULL CHECK (source_sha256 ~ '^[0-9a-f]{64}$'),
    baseline_map_label text NOT NULL,
    baseline_latitude text NOT NULL,
    baseline_longitude text NOT NULL,
    accepted_by text,
    accepted_at timestamptz,
    PRIMARY KEY (site_waypoint_id, source_sha256),
    UNIQUE (source_sha256, baseline_map_label, baseline_latitude, baseline_longitude)
);

CREATE TABLE IF NOT EXISTS ref.site_waypoint_alias (
    alias_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    site_waypoint_id bigint NOT NULL REFERENCES ref.site_waypoint(site_waypoint_id),
    alias_text text NOT NULL CHECK (length(btrim(alias_text)) > 0),
    alias_source text NOT NULL,
    alias_notes text,
    accepted_by text,
    accepted_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX IF NOT EXISTS site_waypoint_alias_lookup
    ON ref.site_waypoint_alias (lower(btrim(alias_text)));
-- Alias may be ambiguous; resolution must not guess between two physical points.

CREATE TABLE IF NOT EXISTS ref.site_track (
    site_track_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    track_label text NOT NULL,
    source_type text NOT NULL DEFAULT '',
    reference_line geometry(MultiLineString, 8158) NOT NULL,
    source_wgs84 geometry(MultiLineString, 4326),
    description text,
    lifecycle_status text NOT NULL DEFAULT 'SOURCE_UNREVIEWED'
       CHECK (lifecycle_status IN ('SOURCE_UNREVIEWED', 'CURRENT', 'ABANDONED', 'DESTROYED', 'RETIRED')),
    verified_by text,
    verified_at timestamptz,
    changed_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE IF NOT EXISTS ref.site_network (
    site_network_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    network_code text NOT NULL UNIQUE,
    network_kind text NOT NULL CHECK (network_kind IN ('LOR', 'IP', 'OTHER')),
    notes text
);

CREATE TABLE IF NOT EXISTS ref.site_cable (
    site_cable_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    endpoint_a_waypoint_id bigint REFERENCES ref.site_waypoint(site_waypoint_id),
    endpoint_b_waypoint_id bigint REFERENCES ref.site_waypoint(site_waypoint_id),
    site_network_id bigint REFERENCES ref.site_network(site_network_id),
    spare_designation text,
    lifecycle_status text NOT NULL DEFAULT 'UNREVIEWED'
       CHECK (lifecycle_status IN ('UNREVIEWED', 'CURRENT', 'FAILED', 'REPAIRED', 'REPLACED', 'DESTROYED', 'ABANDONED', 'RETIRED')),
    installed_at date, -- NULL unless verified; never infer from test date
    retired_at date,
    reviewed_by text,
    reviewed_at timestamptz,
    notes text,
    CHECK (spare_designation IS NULL OR site_network_id IS NULL),
    CHECK (endpoint_a_waypoint_id IS NULL OR endpoint_b_waypoint_id IS NULL
           OR endpoint_a_waypoint_id <> endpoint_b_waypoint_id)
);
-- Several distinct physical cables may have identical endpoints and designation.
-- Never UNIQUE(endpoint_a, endpoint_b, network): parallel cables are real.

CREATE TABLE IF NOT EXISTS ops.site_source_batch (
    source_sha256 text PRIMARY KEY CHECK (source_sha256 ~ '^[0-9a-f]{64}$'),
    source_kind text NOT NULL CHECK (source_kind IN ('EXPERTGPS_GPX', 'LINKIQ_FLW', 'DRAWIO')),
    original_filename text NOT NULL,
    received_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    actor text NOT NULL,
    source_metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- Raw source snapshot rows are append-only. Stage before any curated promotion.
CREATE TABLE IF NOT EXISTS ops.site_source_observation (
    observation_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_sha256 text NOT NULL REFERENCES ops.site_source_batch(source_sha256),
    source_row text NOT NULL,
    item_kind text NOT NULL,
    source_document jsonb NOT NULL,
    recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    UNIQUE (source_sha256, source_row, item_kind)
);

CREATE TABLE IF NOT EXISTS ops.linkiq_test (
    test_uuid uuid PRIMARY KEY,
    first_seen_source_sha256 text NOT NULL REFERENCES ops.site_source_batch(source_sha256),
    tester_original_name text NOT NULL,
    test_time_local text,
    test_status_code integer,
    test_standard text,
    length_ft numeric,
    nvp numeric,
    tester_serial text,
    evidence_sha256 text NOT NULL CHECK (evidence_sha256 ~ '^[0-9a-f]{64}$'),
    original_result jsonb NOT NULL,
    physical_site_cable_id bigint REFERENCES ref.site_cable(site_cable_id),
    identity_review_status text NOT NULL DEFAULT 'UNMATCHED'
        CHECK (identity_review_status IN ('UNMATCHED','REVIEW_REQUIRED','REVIEWED')),
    reviewed_by text,
    reviewed_at timestamptz,
    first_seen_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    CHECK ((identity_review_status <> 'REVIEWED') OR (physical_site_cable_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS linkiq_test_physical_cable_idx ON ops.linkiq_test(physical_site_cable_id);

-- A LinkWare project copy is not another test. Preserve corrected display names
-- per source appearance, even when the same test UUID occurs multiple times.
CREATE TABLE IF NOT EXISTS ops.linkiq_test_appearance (
    source_sha256 text NOT NULL REFERENCES ops.site_source_batch(source_sha256),
    source_row integer NOT NULL,
    test_uuid uuid NOT NULL REFERENCES ops.linkiq_test(test_uuid),
    linkware_project text,
    display_cable_name text,
    deleted_in_project text,
    original_test_name text,
    measured_ft numeric,
    status_code integer,
    record_payload_sha256 text NOT NULL,
    observed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (source_sha256, source_row)
);
CREATE INDEX IF NOT EXISTS linkiq_appearance_test_idx ON ops.linkiq_test_appearance(test_uuid);

-- Schematic geometry remains independent from physical cable topology.
CREATE TABLE IF NOT EXISTS ref.site_schematic_binding (
    binding_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    site_cable_id bigint NOT NULL REFERENCES ref.site_cable(site_cable_id),
    drawing_name text NOT NULL,
    drawio_object_id text NOT NULL,
    UNIQUE(drawing_name, drawio_object_id),
    UNIQUE(drawing_name, site_cable_id, drawio_object_id)
);

-- A source trace is retained independently from the reviewed route it supports.
-- One displayed waypoint-to-waypoint segment can carry many physical cables.
-- No uniqueness by coordinates/endpoints: distinct parallel routes are real.
CREATE TABLE IF NOT EXISTS ref.site_route_segment (
    site_route_segment_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    endpoint_a_waypoint_id bigint NOT NULL REFERENCES ref.site_waypoint(site_waypoint_id),
    endpoint_b_waypoint_id bigint NOT NULL REFERENCES ref.site_waypoint(site_waypoint_id),
    route_label text NOT NULL CHECK (length(btrim(route_label)) > 0),
    reference_line geometry(LineString, 8158) NOT NULL,
    review_status text NOT NULL DEFAULT 'REVIEW_REQUIRED'
        CHECK (review_status IN ('REVIEW_REQUIRED', 'REVIEWED', 'RETIRED')),
    reviewed_by text,
    reviewed_at timestamptz,
    CHECK (endpoint_a_waypoint_id <> endpoint_b_waypoint_id),
    CHECK (ST_IsValid(reference_line) AND NOT ST_IsEmpty(reference_line)),
    CHECK (review_status <> 'REVIEWED' OR
           (nullif(btrim(reviewed_by), '') IS NOT NULL AND reviewed_at IS NOT NULL))
);

-- This is an explicit reviewed association, never inferred from overlap alone.
-- A long historical GPX track may support several segments and vice versa.
CREATE TABLE IF NOT EXISTS ref.site_route_source_track (
    site_route_segment_id bigint NOT NULL REFERENCES ref.site_route_segment(site_route_segment_id),
    site_track_id bigint NOT NULL REFERENCES ref.site_track(site_track_id),
    source_class text NOT NULL CHECK (source_class IN ('NET', 'PRI', 'HV')),
    evidence_notes text NOT NULL CHECK (length(btrim(evidence_notes)) > 0),
    reviewed_by text NOT NULL CHECK (length(btrim(reviewed_by)) > 0),
    reviewed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (site_route_segment_id, site_track_id)
);

-- Separate physical cables can traverse the same ordered route segments.
-- PRI/HV electrical circuit relationships must not be invented as LinkIQ tests.
CREATE TABLE IF NOT EXISTS ref.site_cable_route_segment (
    site_cable_id bigint NOT NULL REFERENCES ref.site_cable(site_cable_id),
    segment_order integer NOT NULL CHECK (segment_order > 0),
    site_route_segment_id bigint NOT NULL REFERENCES ref.site_route_segment(site_route_segment_id),
    traversal_direction smallint NOT NULL CHECK (traversal_direction IN (-1, 1)),
    reviewed_by text NOT NULL CHECK (length(btrim(reviewed_by)) > 0),
    reviewed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (site_cable_id, segment_order)
);

-- Bind imported trace identity to a source observation, not its mutable label.
CREATE TABLE IF NOT EXISTS ref.site_track_source_binding (
    site_track_id bigint NOT NULL REFERENCES ref.site_track(site_track_id),
    source_sha256 text NOT NULL REFERENCES ops.site_source_batch(source_sha256),
    source_ordinal integer NOT NULL CHECK (source_ordinal > 0),
    accepted_by text NOT NULL CHECK (length(btrim(accepted_by)) > 0),
    accepted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (source_sha256, source_ordinal),
    UNIQUE (site_track_id, source_sha256)
);

-- Future governed edit functions and permission grants belong to #230 and
-- MUST be accepted before exposing these tables to operators.
COMMIT;
