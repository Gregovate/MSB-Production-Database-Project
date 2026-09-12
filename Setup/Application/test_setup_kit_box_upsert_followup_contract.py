from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
DB_DIR = APP_DIR.parent / "Database"


def test_kit_box_upsert_uses_named_primary_key_constraint() -> None:
    sql = (DB_DIR / "030_fix_setup_kit_box_assignment_upsert.sql").read_text(encoding="utf-8")
    assert "CREATE OR REPLACE FUNCTION ref.set_setup_task_kit_box_assignment" in sql
    assert "ON CONFLICT ON CONSTRAINT pk_setup_task_container_support" in sql
    assert "ON CONFLICT (setup_task_id, container_id)" not in sql
    assert "container_type_id=2 (Kit Box)" in sql
    assert "relationship_type = 'KIT'" in sql
    assert "GRANT EXECUTE ON FUNCTION ref.set_setup_task_kit_box_assignment" in sql
