from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "02_Reconciliation" / "reconciliation" / "migrations" / "0040_sync_existing_stage_folder_path.sql"
CURRENT_P1 = ROOT / "02_Reconciliation" / "reconciliation" / "current_procedures" / "P1_stage_promotion.sql"
VALIDATION = ROOT / "02_Reconciliation" / "reconciliation" / "validation" / "35_stage_folder_path_sync_validation.sql"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_migration_uses_existing_governed_root_resolver_without_drive_scan():
    sql = _read(MIGRATION)
    assert "ops.f_lor_governed_stage_roots" in sql
    assert "HAVING count(*) = 1" in sql
    assert "No Google Drive filesystem access or enumeration." in sql
    assert "os.walk" not in sql
    assert "rglob(" not in sql


def test_p1_preserves_0039_behavior_before_syncing_existing_paths():
    sql = _read(CURRENT_P1)
    assert "p1_promote_stage_from_reconciliation_before_0040" in sql
    assert "CALL ref.p1_promote_stage_from_reconciliation_before_0040" in sql
    assert "P1_STAGE_FOLDER_PATH" in sql


def test_p1_requires_permanent_identity_to_match_unique_governed_root():
    sql = _read(CURRENT_P1)
    assert "HAVING count(*) = 1" in sql
    assert "s.stage_name IS NOT DISTINCT FROM root.stage_name" in sql
    assert "s.folder_name IS NOT DISTINCT FROM root.folder_name" in sql
    assert "s.folder_path IS DISTINCT FROM root.folder_path" in sql


def test_p1_excludes_held_special_stage_keys():
    sql = _read(CURRENT_P1)
    for key in ("12", "39", "40", "90", "91", "92", "93", "94"):
        assert f"'{key}'" in sql


def test_install_repair_is_based_on_latest_frozen_import_not_names():
    sql = _read(MIGRATION)
    assert "FROM lor_snap.v_current_run" in sql
    assert "cr.import_run_id" in sql
    assert "SET folder_path = t.folder_path" in sql
    assert "stage_key ||" not in sql


def test_validation_covers_current_three_path_differences():
    sql = _read(VALIDATION)
    assert "('05a','07a','17')" in sql
    assert r"05-Festive Trees-FT\\05a-Mega Star-MS" in sql
    assert r"07-Whoville-WV\\07a-Who Forest-WF" in sql
    assert r"17-Candyland-CL" in sql


def test_validation_requires_zero_remaining_normal_path_mismatches():
    sql = _read(VALIDATION)
    assert "mismatch_count" in sql
    assert "stored_folder_path IS DISTINCT FROM governed_folder_path" in sql
