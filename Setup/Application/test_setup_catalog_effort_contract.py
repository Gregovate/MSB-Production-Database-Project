from pathlib import Path

BASE = Path(__file__).resolve().parent
DB = BASE.parent / "Database"


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_effort_migration_is_narrow_and_governed():
    migration = text(DB / "023_add_setup_task_effort.sql")
    assert "ADD COLUMN IF NOT EXISTS effort_level text" in migration
    assert "LIGHT', 'MODERATE', 'HEAVY" in migration
    assert "ref.set_setup_task_effort" in migration
    assert "GRANT EXECUTE ON FUNCTION ref.set_setup_task_effort" in migration
    assert "planning_role" not in migration


def test_production_host_registers_effort_surface():
    host = text(BASE / "production_backend.py")
    assert "from setup_effort_api import setup_effort_api" in host
    assert "app.register_blueprint(setup_effort_api)" in host
    assert '"setup_catalog_effort.js"' in host


def test_effort_api_uses_governed_command_not_table_dml():
    api = text(BASE / "setup_effort_api.py")
    assert '/api/setup/task-efforts' in api
    assert '/api/setup/tasks/<int:setup_task_id>/effort' in api
    assert "ref.set_setup_task_effort" in api
    assert "WHERE active_flag" in api
    assert "UPDATE ref.setup_task" not in api
    assert "INSERT INTO ref.setup_task" not in api
    assert "DELETE FROM ref.setup_task" not in api


def test_effort_editor_is_part_of_reusable_task_save():
    html = text(BASE / "production.html")
    js = text(BASE / "setup_catalog_effort.js")
    production = text(BASE / "setup_production.js")

    assert 'id="edit-effort-level"' in html
    assert 'id="save-task-effort"' not in html
    assert "LIGHT" in html and "MODERATE" in html and "HEAVY" in html
    assert "Effort:" in js
    assert "can_manage_setup" in js
    assert "setup-effort-badge" in js
    assert "async function saveSelectedSetupEffort()" not in js
    assert "placeSetupEffortSaveControl" not in js
    assert "api/setup/tasks/${task.setup_task_id}/effort" in production
    assert "const effort = el('edit-effort-level')?.value || null;" in production

