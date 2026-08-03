/* ============================================================================
Object group: Frozen reconciliation source evidence
Repository:   Postgres_sql/Upsert Procedures/reconciliation/
Filename:     0021_freeze_reconciliation_source_evidence.sql
Revision:     2026-08-03-frozen-source-evidence-v1

Purpose:
  Preserve the complete captured ingest provenance plus every preview and scene
  row needed by the immutable Finish/Cancel report before lor_snap data can be
  deleted.

Safety boundary:
  - Adds reconciliation-owned audit tables and a source-freeze function.
  - Replaces only the unified Start Reconciliation wrapper.
  - Does not change P1, P2, scene promotion, or production ref data.
  - Does not delete or alter lor_snap data.

Revision history:
  2026-08-03  GAL / OpenAI  Initial typed source-run, preview, and scene freeze.
============================================================================ */

BEGIN;

CREATE TABLE IF NOT EXISTS ops.lor_reconciliation_source_run (
    lor_reconciliation_run_id bigint PRIMARY KEY
        REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id),
    import_run_id bigint NOT NULL,
    run_ts timestamptz NOT NULL,
    notes text,
    parser_version text,
    parser_started_at timestamptz,
    parser_completed_at timestamptz,
    parser_actor text,
    parser_host text,
    source_preview_folder text,
    source_sqlite_path text,
    preview_count integer,
    scene_count integer,
    prop_count integer,
    sub_prop_count integer,
    dmx_channel_count integer,
    scene_lor_prop_count integer,
    ingest_script_version text,
    ingest_actor text,
    ingest_host text,
    ingest_started_at timestamptz,
    ingest_completed_at timestamptz,
    frozen_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ux_lor_reconciliation_source_run_import
        UNIQUE (lor_reconciliation_run_id, import_run_id)
);

CREATE TABLE IF NOT EXISTS ops.lor_reconciliation_source_preview (
    lor_reconciliation_source_preview_id bigint
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lor_reconciliation_run_id bigint NOT NULL
        REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id),
    import_run_id bigint NOT NULL,
    int_preview_id bigint NOT NULL,
    preview_id text NOT NULL,
    stage_id text,
    preview_name text,
    preview_revision text,
    brightness double precision,
    background_file text,
    source_filename text,
    frozen_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT ux_lor_reconciliation_source_preview
        UNIQUE (lor_reconciliation_run_id, int_preview_id)
);

CREATE TABLE IF NOT EXISTS ops.lor_reconciliation_source_scene (
    lor_reconciliation_source_scene_row_id bigint
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    lor_reconciliation_run_id bigint NOT NULL
        REFERENCES ops.lor_reconciliation_run(lor_reconciliation_run_id),
    import_run_id bigint NOT NULL,
    int_scene_id integer,
    scene_id text,
    preview_id text,
    stage_id text,
    scene_name text,
    scene_section text,
    background_file text,
    h_scroll integer,
    v_scroll integer,
    zoom integer,
    create_grid_view text,
    frozen_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_lor_reconciliation_source_scene_run
    ON ops.lor_reconciliation_source_scene (lor_reconciliation_run_id);

COMMENT ON TABLE ops.lor_reconciliation_source_run IS
'Immutable typed copy of the complete lor_snap.import_run row captured by Start Reconciliation.';
COMMENT ON TABLE ops.lor_reconciliation_source_preview IS
'Immutable copy of every preview row in the captured ingest, including filename, name, and revision.';
COMMENT ON TABLE ops.lor_reconciliation_source_scene IS
'Immutable copy of every scene row in the captured ingest for Finish/Cancel reporting.';

CREATE OR REPLACE FUNCTION ops.f_freeze_lor_reconciliation_source_evidence(
    p_lor_reconciliation_run_id bigint
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap
AS $function$
DECLARE
    v_import_run_id bigint;
    v_recorded_preview_count integer;
    v_recorded_scene_count integer;
    v_actual_preview_count integer;
    v_actual_scene_count integer;
    v_frozen_preview_count integer;
    v_frozen_scene_count integer;
BEGIN
    SELECT r.import_run_id
      INTO v_import_run_id
    FROM ops.lor_reconciliation_run AS r
    WHERE r.lor_reconciliation_run_id = p_lor_reconciliation_run_id
    FOR UPDATE;

    IF v_import_run_id IS NULL THEN
        RAISE EXCEPTION 'Reconciliation run % does not exist',
            p_lor_reconciliation_run_id;
    END IF;

    SELECT ir.preview_count, ir.scene_count
      INTO v_recorded_preview_count, v_recorded_scene_count
    FROM lor_snap.import_run AS ir
    WHERE ir.import_run_id = v_import_run_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Captured import_run_id % no longer exists',
            v_import_run_id;
    END IF;

    SELECT count(*)::integer INTO v_actual_preview_count
    FROM lor_snap.previews WHERE import_run_id = v_import_run_id;

    SELECT count(*)::integer INTO v_actual_scene_count
    FROM lor_snap.scenes WHERE import_run_id = v_import_run_id;

    IF v_recorded_preview_count IS DISTINCT FROM v_actual_preview_count THEN
        RAISE EXCEPTION
            'Captured import_run_id % preview count mismatch: recorded %, actual %',
            v_import_run_id, v_recorded_preview_count, v_actual_preview_count;
    END IF;

    IF v_recorded_scene_count IS DISTINCT FROM v_actual_scene_count THEN
        RAISE EXCEPTION
            'Captured import_run_id % scene count mismatch: recorded %, actual %',
            v_import_run_id, v_recorded_scene_count, v_actual_scene_count;
    END IF;

    INSERT INTO ops.lor_reconciliation_source_run (
        lor_reconciliation_run_id, import_run_id, run_ts, notes,
        parser_version, parser_started_at, parser_completed_at,
        parser_actor, parser_host, source_preview_folder, source_sqlite_path,
        preview_count, scene_count, prop_count, sub_prop_count,
        dmx_channel_count, scene_lor_prop_count, ingest_script_version,
        ingest_actor, ingest_host, ingest_started_at, ingest_completed_at
    )
    SELECT
        p_lor_reconciliation_run_id, ir.import_run_id, ir.run_ts, ir.notes,
        ir.parser_version, ir.parser_started_at, ir.parser_completed_at,
        ir.parser_actor, ir.parser_host, ir.source_preview_folder,
        ir.source_sqlite_path, ir.preview_count, ir.scene_count, ir.prop_count,
        ir.sub_prop_count, ir.dmx_channel_count, ir.scene_lor_prop_count,
        ir.ingest_script_version, ir.ingest_actor, ir.ingest_host,
        ir.ingest_started_at, ir.ingest_completed_at
    FROM lor_snap.import_run AS ir
    WHERE ir.import_run_id = v_import_run_id
    ON CONFLICT (lor_reconciliation_run_id) DO NOTHING;

    INSERT INTO ops.lor_reconciliation_source_preview (
        lor_reconciliation_run_id, import_run_id, int_preview_id,
        preview_id, stage_id, preview_name, preview_revision, brightness,
        background_file, source_filename
    )
    SELECT
        p_lor_reconciliation_run_id, p.import_run_id, p.int_preview_id,
        p.id, p.stage_id, p.name, p.revision, p.brightness,
        p.background_file, p.source_filename
    FROM lor_snap.previews AS p
    WHERE p.import_run_id = v_import_run_id
    ON CONFLICT (lor_reconciliation_run_id, int_preview_id) DO NOTHING;

    IF NOT EXISTS (
        SELECT 1 FROM ops.lor_reconciliation_source_scene
        WHERE lor_reconciliation_run_id = p_lor_reconciliation_run_id
    ) THEN
        INSERT INTO ops.lor_reconciliation_source_scene (
            lor_reconciliation_run_id, import_run_id, int_scene_id, scene_id,
            preview_id, stage_id, scene_name, scene_section, background_file,
            h_scroll, v_scroll, zoom, create_grid_view
        )
        SELECT
            p_lor_reconciliation_run_id, s.import_run_id, s.int_scene_id,
            s.scene_id, s.preview_id, s.stage_id, s.name, s.scene_section,
            s.background_file, s.h_scroll, s.v_scroll, s.zoom,
            s.create_grid_view
        FROM lor_snap.scenes AS s
        WHERE s.import_run_id = v_import_run_id;
    END IF;

    SELECT count(*)::integer INTO v_frozen_preview_count
    FROM ops.lor_reconciliation_source_preview
    WHERE lor_reconciliation_run_id = p_lor_reconciliation_run_id;

    SELECT count(*)::integer INTO v_frozen_scene_count
    FROM ops.lor_reconciliation_source_scene
    WHERE lor_reconciliation_run_id = p_lor_reconciliation_run_id;

    IF v_frozen_preview_count IS DISTINCT FROM v_actual_preview_count
       OR v_frozen_scene_count IS DISTINCT FROM v_actual_scene_count THEN
        RAISE EXCEPTION
            'Frozen evidence count mismatch for reconciliation run %: previews %/%, scenes %/%',
            p_lor_reconciliation_run_id,
            v_frozen_preview_count, v_actual_preview_count,
            v_frozen_scene_count, v_actual_scene_count;
    END IF;
END;
$function$;

COMMENT ON FUNCTION ops.f_freeze_lor_reconciliation_source_evidence(bigint) IS
'Atomically freezes complete ingest provenance and all preview/scene report evidence for one captured reconciliation run.';

/* Make all frozen source evidence append-only. */
DROP TRIGGER IF EXISTS trg_lor_reconciliation_source_run_immutable
    ON ops.lor_reconciliation_source_run;
CREATE TRIGGER trg_lor_reconciliation_source_run_immutable
BEFORE UPDATE OR DELETE ON ops.lor_reconciliation_source_run
FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();

DROP TRIGGER IF EXISTS trg_lor_reconciliation_source_preview_immutable
    ON ops.lor_reconciliation_source_preview;
CREATE TRIGGER trg_lor_reconciliation_source_preview_immutable
BEFORE UPDATE OR DELETE ON ops.lor_reconciliation_source_preview
FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();

DROP TRIGGER IF EXISTS trg_lor_reconciliation_source_scene_immutable
    ON ops.lor_reconciliation_source_scene;
CREATE TRIGGER trg_lor_reconciliation_source_scene_immutable
BEFORE UPDATE OR DELETE ON ops.lor_reconciliation_source_scene
FOR EACH ROW EXECUTE FUNCTION ops.trg_lor_reconciliation_detail_immutable();

CREATE OR REPLACE FUNCTION ops.f_start_lor_reconciliation(
    p_started_by_application text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap, ref
AS $function$
DECLARE
    v_run_id bigint;
BEGIN
    v_run_id := ops.f_start_lor_display_reconciliation(
        p_started_by_application
    );
    PERFORM ops.f_freeze_lor_reconciliation_source_evidence(v_run_id);
    PERFORM ops.f_build_lor_reconciliation_stage_candidates(v_run_id);
    PERFORM ops.f_build_lor_reconciliation_scene_candidates(v_run_id);
    PERFORM ops.f_build_lor_reconciliation_scene_display_candidates(v_run_id);
    RETURN v_run_id;
END;
$function$;

COMMENT ON FUNCTION ops.f_start_lor_reconciliation(text) IS
'Unified reconciliation start: captures one completed ingest; freezes complete run, preview, scene, display, stage, and scene-membership evidence for that same run.';

CREATE OR REPLACE VIEW ops.v_lor_reconciliation_source_run AS
SELECT sr.*,
       (SELECT count(*) FROM ops.lor_reconciliation_source_preview AS p
        WHERE p.lor_reconciliation_run_id = sr.lor_reconciliation_run_id)
           AS frozen_preview_count,
       (SELECT count(*) FROM ops.lor_reconciliation_source_scene AS s
        WHERE s.lor_reconciliation_run_id = sr.lor_reconciliation_run_id)
           AS frozen_scene_count
FROM ops.lor_reconciliation_source_run AS sr;

ALTER TABLE ops.lor_reconciliation_source_run OWNER TO msbadmin;
ALTER TABLE ops.lor_reconciliation_source_preview OWNER TO msbadmin;
ALTER TABLE ops.lor_reconciliation_source_scene OWNER TO msbadmin;
ALTER VIEW ops.v_lor_reconciliation_source_run OWNER TO msbadmin;

GRANT SELECT ON ops.lor_reconciliation_source_run TO directus_app;
GRANT SELECT ON ops.lor_reconciliation_source_preview TO directus_app;
GRANT SELECT ON ops.lor_reconciliation_source_scene TO directus_app;
GRANT SELECT ON ops.v_lor_reconciliation_source_run TO directus_app;

REVOKE EXECUTE ON FUNCTION
    ops.f_freeze_lor_reconciliation_source_evidence(bigint) FROM PUBLIC;

COMMIT;

SELECT
    to_regclass('ops.lor_reconciliation_source_run') IS NOT NULL
        AS has_source_run,
    to_regclass('ops.lor_reconciliation_source_preview') IS NOT NULL
        AS has_source_preview,
    to_regclass('ops.lor_reconciliation_source_scene') IS NOT NULL
        AS has_source_scene,
    to_regprocedure('ops.f_freeze_lor_reconciliation_source_evidence(bigint)')
        IS NOT NULL AS has_source_freeze;
