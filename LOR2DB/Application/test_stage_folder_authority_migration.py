from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
MIGRATION = (
    ROOT
    / "02_Reconciliation"
    / "reconciliation"
    / "migrations"
    / "0039_repair_stage_folder_authority.sql"
)
P1_MIRROR = (
    ROOT
    / "02_Reconciliation"
    / "reconciliation"
    / "current_procedures"
    / "P1_stage_promotion.sql"
)
VALIDATION = (
    ROOT
    / "02_Reconciliation"
    / "reconciliation"
    / "validation"
    / "34_stage_folder_authority_validation.sql"
)


def test_migration_uses_frozen_governed_drive_evidence():
    sql = MIGRATION.read_text(encoding="utf-8")

    assert "ops.f_lor_governed_stage_roots" in sql
    assert "lor_snap.previews AS p" in sql
    assert "lor_snap.scenes AS s" in sql
    assert "lor_snap.scene_lor_props AS slp" in sql
    assert "p.id = s.preview_id" in sql
    assert "shared drives" in sql.lower()
    assert "display folders" in sql.lower()
    assert "v_current_previews" not in sql
    assert "v_current_scenes" not in sql


def test_governed_root_preserves_exact_stage_root_name():
    sql = MIGRATION.read_text(encoding="utf-8")

    assert "c.folder_name AS stage_name" in sql
    assert "descriptive middle component only" not in sql
    assert "substr(c.folder_name" not in sql
    assert "regexp_replace(\n                substr(c.folder_name" not in sql


def test_governed_root_uses_first_matching_path_segment():
    sql = MIGRATION.read_text(encoding="utf-8")

    root_selector = sql.split("CROSS JOIN LATERAL (", 1)[1].split(
        ") AS root", 1
    )[0]
    assert "ORDER BY u.ordinality" in root_selector
    assert "LIMIT 1" in root_selector


def test_add_new_stage_has_no_preview_name_fallback():
    sql = MIGRATION.read_text(encoding="utf-8")
    p1 = P1_MIRROR.read_text(encoding="utf-8")

    assert "governed_stage_name" in sql
    assert "governed_folder_name" in sql
    assert "governed_folder_path" in sql
    assert "SELECT r.* INTO STRICT v_root" in sql

    assert "f_lor_governed_stage_roots" in p1
    assert "governed_folder_path" in p1
    assert "f_normalize_lor_stage_name" not in p1
    assert "RGB Plus Stage" not in p1
    assert "v_group.stage_name IS DISTINCT FROM v_group.folder_name" in p1


def test_existing_repair_is_exact_29_key_name_only_allowlist():
    sql = MIGRATION.read_text(encoding="utf-8")
    repair = sql.split(
        "INSERT INTO pg_temp._stage_folder_authority_repair",
        1,
    )[1].split("COMMIT;", 1)[0]

    keys = re.findall(r"\('([0-9]{2}[a-z]?)',\s*'[^']*(?:''[^']*)*'\)", repair)
    assert len(keys) == 29
    assert len(set(keys)) == 29
    assert "12" not in keys
    assert "39" not in keys
    assert "40" not in keys
    assert not {"90", "91", "92", "93", "94"}.intersection(keys)

    assert "stage_name = t.governed_root_name" in repair
    assert "folder_name = t.governed_root_name" in repair
    assert "folder_path = t." not in repair


def test_repair_values_are_exact_governed_root_names():
    sql = MIGRATION.read_text(encoding="utf-8")

    for value in (
        "00-HWY 42-HW",
        "01-Front Entrance-FE",
        "04-Food Collection-FC",
        "07a-Who Forest-WF",
        "15-Church-Bells-CH",
        "21-Polar Bear Playground-PB",
        "30-Santa''s Station-QV",
    ):
        assert value in sql


def test_validation_covers_exact_03a_and_excluded_rows():
    sql = VALIDATION.read_text(encoding="utf-8")

    assert "mismatch_count" in sql
    assert "bad_preview_derived_name_count" in sql
    assert "('03a'),('05a'),('07a'),('17'),('39'),('40')" in sql
    assert "stage_name = '03a-Mega Cube-MC'" in sql
    assert "folder_name = '03a-Mega Cube-MC'" in sql
    assert "exact_03a_authority" in sql
