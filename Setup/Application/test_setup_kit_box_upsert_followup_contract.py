from pathlib import Path
import re


APP_DIR = Path(__file__).resolve().parent
DB_DIR = APP_DIR.parent / "Database"


def test_kit_box_upsert_uses_named_primary_key_constraint() -> None:
    sql = (DB_DIR / "030_fix_setup_kit_box_assignment_upsert.sql").read_text(encoding="utf-8")
    executable_sql = re.sub(r"/\*.*?\*/", "", sql, flags=re.S)
    assert "CREATE OR REPLACE FUNCTION ref.set_setup_task_kit_box_assignment" in executable_sql
    assert "ON CONFLICT ON CONSTRAINT pk_setup_task_container_support" in executable_sql
    assert "ON CONFLICT (setup_task_id, container_id)" not in executable_sql
    assert "container_type_id=2 (Kit Box)" in executable_sql
    assert "relationship_type = 'KIT'" in executable_sql
    assert "GRANT EXECUTE ON FUNCTION ref.set_setup_task_kit_box_assignment" in executable_sql
