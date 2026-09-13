from pathlib import Path
import re


APP_DIR = Path(__file__).resolve().parent
DB_DIR = APP_DIR.parent / "Database"


def test_task_resource_upsert_uses_named_primary_key_constraint() -> None:
    sql = (DB_DIR / "031_fix_setup_task_resource_upsert.sql").read_text(
        encoding="utf-8"
    )

    match = re.search(
        r"CREATE OR REPLACE FUNCTION ref\.set_setup_task_resource"
        r".*?AS \$function\$(.*?)\$function\$;",
        sql,
        flags=re.S,
    )
    assert match is not None

    function_body = match.group(1)

    assert "ON CONFLICT ON CONSTRAINT pk_setup_task_resource" in function_body
    assert "ON CONFLICT (setup_task_id, setup_resource_id)" not in function_body

    # Preserve the current migration-027 behavior.
    assert "Inactive Setup resource cannot be assigned to a task" in function_body
    assert "Setup task resource relationship was not found" in function_body
    assert "quantity_required = EXCLUDED.quantity_required" in function_body
    assert "requirement_type = EXCLUDED.requirement_type" in function_body
    assert "active_flag = EXCLUDED.active_flag" in function_body

    # Preserve the governed function boundary.
    assert "SECURITY DEFINER" in sql
    assert "GRANT EXECUTE ON FUNCTION ref.set_setup_task_resource" in sql
    assert "GRANT INSERT ON ref.setup_task_resource" not in sql
    assert "GRANT UPDATE ON ref.setup_task_resource" not in sql
    assert "GRANT DELETE ON ref.setup_task_resource" not in sql