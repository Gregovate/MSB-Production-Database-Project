from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MIGRATION = (
    ROOT
    / "02_Reconciliation"
    / "reconciliation"
    / "migrations"
    / "0042_decouple_snapshot_provenance_and_add_retention.sql"
)
VALIDATION = (
    ROOT
    / "02_Reconciliation"
    / "reconciliation"
    / "validation"
    / "37_lor_snapshot_retention_validation.sql"
)
REPORT_PUBLISHER = ROOT / "03_Reporting" / "publish_lor_reconciliation_report.py"


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_installation_decouples_only_known_provenance_foreign_keys():
    sql = text(MIGRATION)
    assert "ALTER TABLE ref.lor_scene\n    DROP CONSTRAINT fk_lor_scene_import_run" in sql
    assert "ALTER TABLE ref.lor_scene_display\n    DROP CONSTRAINT fk_lor_scene_display_import_run" in sql
    assert "ops.lor_reconciliation_action_legacy" in sql
    assert "DROP CONSTRAINT fk_lor_reconciliation_action_run" in sql
    assert "lor_snap.dmx_channels" in sql
    assert "lor_snap.previews" in sql
    assert "lor_snap.props" in sql
    assert "lor_snap.sub_props" in sql
    assert "lor_snap.scene_lor_props" in sql
    assert "lor_snap.scenes" in sql


def test_installation_never_runs_the_prune_procedure():
    sql = text(MIGRATION).upper()
    assert "CALL OPS.P_PRUNE_LOR_SNAPSHOTS" not in sql


def test_retention_plan_keeps_recent_and_nonterminal_snapshots():
    sql = text(MIGRATION)
    assert "p_keep_completed integer DEFAULT 5" in sql
    assert "NEWEST_COMPLETED_WORKING_SET" in sql
    assert "NON_TERMINAL_RECONCILIATION" in sql
    assert "INCOMPLETE_INGEST_REQUIRES_REVIEW" in sql
    for status in (
        "STARTING",
        "PREFLIGHT",
        "AWAITING_DECISIONS",
        "READY_TO_FINISH",
        "PROMOTING",
        "VALIDATING",
        "REPORTING",
    ):
        assert status in sql


def test_prune_requires_exact_reviewed_candidate_set_and_rechecks_dependencies():
    sql = text(MIGRATION)
    assert "Retention plan changed since dry run" in sql
    assert "pg_advisory_xact_lock" in sql
    assert "Unexpected foreign key(s) still reference lor_snap.import_run" in sql
    assert "DELETE FROM lor_snap.scene_lor_props" in sql
    assert "DELETE FROM lor_snap.scenes" in sql
    assert "DELETE FROM lor_snap.import_run" in sql
    assert "Latest completed import changed" in sql


def test_retention_admin_objects_are_not_public():
    sql = text(MIGRATION)
    assert "REVOKE ALL ON FUNCTION ops.f_lor_snapshot_retention_plan(integer) FROM PUBLIC" in sql
    assert "REVOKE ALL ON PROCEDURE ops.p_prune_lor_snapshots(bigint[], integer) FROM PUBLIC" in sql


def test_production_validation_is_read_only_and_never_prunes():
    sql = text(VALIDATION).upper()
    assert "CALL OPS.P_PRUNE_LOR_SNAPSHOTS" not in sql
    assert "DELETE FROM LOR_SNAP" not in sql
    assert "UPDATE LOR_SNAP" not in sql
    assert "INSERT INTO LOR_SNAP" not in sql
    assert "LOR_SNAPSHOT_RETENTION_VALIDATION_PASS" in sql


def test_report_publisher_uses_frozen_reconciliation_evidence_not_raw_snapshot():
    source = text(REPORT_PUBLISHER)
    assert "ops.lor_reconciliation_source_run" in source
    assert "ops.lor_reconciliation_source_preview" in source
    assert "ops.lor_reconciliation_source_scene" in source
    assert "FROM lor_snap." not in source
    assert "JOIN lor_snap." not in source
