/* ==========================================================================
Object group: LOR parser-to-ingest authority chain
Revision:     2026-08-13-lor-authority-chain-v1

Purpose:
  Preserve the declared LOR version, validated parser/source identities, and
  exact operator-reviewed SQLite digest through ingest and reconciliation.

Safety:
  Adds nullable provenance for historical compatibility. The V0.4.0 ingest
  requires every field for new runs before it creates an import_run row.
========================================================================== */

BEGIN;

ALTER TABLE lor_snap.import_run
    ADD COLUMN IF NOT EXISTS parser_run_mode text,
    ADD COLUMN IF NOT EXISTS source_lor_version text,
    ADD COLUMN IF NOT EXISTS parser_sha256 text,
    ADD COLUMN IF NOT EXISTS source_manifest_sha256 text,
    ADD COLUMN IF NOT EXISTS compatibility_manifest_sha256 text,
    ADD COLUMN IF NOT EXISTS parser_validation_status text,
    ADD COLUMN IF NOT EXISTS parser_validation_detail text,
    ADD COLUMN IF NOT EXISTS source_sqlite_sha256 text;

ALTER TABLE lor_snap.import_run
    DROP CONSTRAINT IF EXISTS ck_import_run_parser_run_mode,
    ADD CONSTRAINT ck_import_run_parser_run_mode
        CHECK (parser_run_mode IS NULL OR parser_run_mode IN ('PRODUCTION', 'VERSION_CHECK', 'TEST')),
    DROP CONSTRAINT IF EXISTS ck_import_run_parser_validation_status,
    ADD CONSTRAINT ck_import_run_parser_validation_status
        CHECK (parser_validation_status IS NULL OR parser_validation_status IN ('PASSED', 'FAILED', 'PENDING')),
    DROP CONSTRAINT IF EXISTS ck_import_run_parser_sha256,
    ADD CONSTRAINT ck_import_run_parser_sha256
        CHECK (parser_sha256 IS NULL OR parser_sha256 ~ '^[0-9a-f]{64}$'),
    DROP CONSTRAINT IF EXISTS ck_import_run_source_manifest_sha256,
    ADD CONSTRAINT ck_import_run_source_manifest_sha256
        CHECK (source_manifest_sha256 IS NULL OR source_manifest_sha256 ~ '^[0-9a-f]{64}$'),
    DROP CONSTRAINT IF EXISTS ck_import_run_compatibility_manifest_sha256,
    ADD CONSTRAINT ck_import_run_compatibility_manifest_sha256
        CHECK (compatibility_manifest_sha256 IS NULL OR compatibility_manifest_sha256 ~ '^[0-9a-f]{64}$'),
    DROP CONSTRAINT IF EXISTS ck_import_run_source_sqlite_sha256,
    ADD CONSTRAINT ck_import_run_source_sqlite_sha256
        CHECK (source_sqlite_sha256 IS NULL OR source_sqlite_sha256 ~ '^[0-9a-f]{64}$');

ALTER TABLE ops.lor_reconciliation_source_run
    ADD COLUMN IF NOT EXISTS parser_run_mode text,
    ADD COLUMN IF NOT EXISTS source_lor_version text,
    ADD COLUMN IF NOT EXISTS parser_sha256 text,
    ADD COLUMN IF NOT EXISTS source_manifest_sha256 text,
    ADD COLUMN IF NOT EXISTS compatibility_manifest_sha256 text,
    ADD COLUMN IF NOT EXISTS parser_validation_status text,
    ADD COLUMN IF NOT EXISTS parser_validation_detail text,
    ADD COLUMN IF NOT EXISTS source_sqlite_sha256 text;

CREATE OR REPLACE FUNCTION ops.trg_copy_lor_authority_chain()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops, lor_snap
AS $function$
BEGIN
    SELECT
        ir.parser_run_mode,
        ir.source_lor_version,
        ir.parser_sha256,
        ir.source_manifest_sha256,
        ir.compatibility_manifest_sha256,
        ir.parser_validation_status,
        ir.parser_validation_detail,
        ir.source_sqlite_sha256
    INTO
        NEW.parser_run_mode,
        NEW.source_lor_version,
        NEW.parser_sha256,
        NEW.source_manifest_sha256,
        NEW.compatibility_manifest_sha256,
        NEW.parser_validation_status,
        NEW.parser_validation_detail,
        NEW.source_sqlite_sha256
    FROM lor_snap.import_run AS ir
    WHERE ir.import_run_id = NEW.import_run_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cannot freeze missing import_run_id %', NEW.import_run_id;
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_copy_lor_authority_chain
    ON ops.lor_reconciliation_source_run;
CREATE TRIGGER trg_copy_lor_authority_chain
BEFORE INSERT ON ops.lor_reconciliation_source_run
FOR EACH ROW EXECUTE FUNCTION ops.trg_copy_lor_authority_chain();

/* Preserve the existing view column order and append the new authority chain.
   SELECT sr.* would not automatically expand an already-created PostgreSQL
   view after ALTER TABLE. */
CREATE OR REPLACE VIEW ops.v_lor_reconciliation_source_run AS
SELECT
    sr.lor_reconciliation_run_id,
    sr.import_run_id,
    sr.run_ts,
    sr.notes,
    sr.parser_version,
    sr.parser_started_at,
    sr.parser_completed_at,
    sr.parser_actor,
    sr.parser_host,
    sr.source_preview_folder,
    sr.source_sqlite_path,
    sr.preview_count,
    sr.scene_count,
    sr.prop_count,
    sr.sub_prop_count,
    sr.dmx_channel_count,
    sr.scene_lor_prop_count,
    sr.ingest_script_version,
    sr.ingest_actor,
    sr.ingest_host,
    sr.ingest_started_at,
    sr.ingest_completed_at,
    sr.frozen_at,
    (SELECT count(*) FROM ops.lor_reconciliation_source_preview AS p
     WHERE p.lor_reconciliation_run_id = sr.lor_reconciliation_run_id)
        AS frozen_preview_count,
    (SELECT count(*) FROM ops.lor_reconciliation_source_scene AS s
     WHERE s.lor_reconciliation_run_id = sr.lor_reconciliation_run_id)
        AS frozen_scene_count,
    sr.parser_run_mode,
    sr.source_lor_version,
    sr.parser_sha256,
    sr.source_manifest_sha256,
    sr.compatibility_manifest_sha256,
    sr.parser_validation_status,
    sr.parser_validation_detail,
    sr.source_sqlite_sha256
FROM ops.lor_reconciliation_source_run AS sr;

ALTER VIEW ops.v_lor_reconciliation_source_run OWNER TO msbadmin;
GRANT SELECT ON ops.v_lor_reconciliation_source_run TO directus_app;

CREATE OR REPLACE VIEW lor_snap.v_current_run AS
SELECT
    ir.import_run_id,
    ir.run_ts,
    ir.notes,
    ir.parser_version,
    ir.parser_started_at,
    ir.parser_completed_at,
    ir.parser_actor,
    ir.parser_host,
    ir.source_preview_folder,
    ir.source_sqlite_path,
    ir.preview_count,
    ir.scene_count,
    ir.prop_count,
    ir.sub_prop_count,
    ir.dmx_channel_count,
    ir.scene_lor_prop_count,
    ir.ingest_script_version,
    ir.ingest_actor,
    ir.ingest_host,
    ir.ingest_started_at,
    ir.ingest_completed_at,
    ir.parser_run_mode,
    ir.source_lor_version,
    ir.parser_sha256,
    ir.source_manifest_sha256,
    ir.compatibility_manifest_sha256,
    ir.parser_validation_status,
    ir.parser_validation_detail,
    ir.source_sqlite_sha256
FROM lor_snap.import_run AS ir
ORDER BY ir.import_run_id DESC
LIMIT 1;

ALTER VIEW lor_snap.v_current_run OWNER TO msbadmin;
GRANT SELECT ON lor_snap.v_current_run TO directus_app;

COMMENT ON COLUMN lor_snap.import_run.source_sqlite_sha256 IS
'SHA-256 of the exact operator-reviewed SQLite artifact accepted by ingest.';
COMMENT ON COLUMN lor_snap.import_run.source_manifest_sha256 IS
'SHA-256 of the ordered .lorprev filename/file-hash manifest recorded by the parser.';
COMMENT ON COLUMN lor_snap.import_run.compatibility_manifest_sha256 IS
'SHA-256 of the approved complete XML compatibility manifest used for the parser run.';
COMMENT ON COLUMN lor_snap.import_run.source_lor_version IS
'Operator-declared Light-O-Rama version that exported the approved preview folder.';
COMMENT ON TABLE ops.lor_reconciliation_source_run IS
'Immutable typed copy of complete ingest provenance, including the LOR parser-to-SQLite authority chain.';

COMMIT;

SELECT
    import_run_id,
    parser_version,
    parser_run_mode,
    source_lor_version,
    parser_validation_status,
    source_manifest_sha256,
    compatibility_manifest_sha256,
    source_sqlite_sha256
FROM lor_snap.v_current_run;
