from __future__ import annotations

from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
REPO_ROOT = APP_DIR.parents[1]
MIGRATION = REPO_ROOT / "Setup" / "Database" / "008_create_setup_resource_management_commands.sql"


def test_resource_migration_preserves_narrow_write_boundary() -> None:
    text = MIGRATION.read_text(encoding="utf-8")
    assert "ADD COLUMN IF NOT EXISTS active_flag" in text
    assert "CREATE OR REPLACE FUNCTION ref.create_setup_resource" in text
    assert "CREATE OR REPLACE FUNCTION ref.set_setup_task_resource" in text
    assert "FROM ref.setup_management_actor(p_email, false)" in text
    assert "GRANT EXECUTE ON FUNCTION ref.create_setup_resource" in text
    assert "GRANT EXECUTE ON FUNCTION ref.set_setup_task_resource" in text
    assert "GRANT UPDATE ON ref.setup_task_resource" not in text
    assert "DELETE FROM ref.setup_task_resource" not in text


def test_resource_ui_uses_structured_api_not_free_text_equipment_field() -> None:
    js = (APP_DIR / "setup_resource_review.js").read_text(encoding="utf-8")
    css = (APP_DIR / "setup_resource_review.css").read_text(encoding="utf-8")
    assert "Equipment / Resources Needed" in js
    assert "api/setup/resources" in js
    assert "quantity_required" in js
    assert "requirement_type" in js
    assert "active_flag" in js
    assert "resource-edit-grid" in css
    assert "grid-template-columns: minmax(290px, 340px) minmax(0, 1fr)" in css


def test_resource_api_is_role_governed() -> None:
    text = (APP_DIR / "setup_resource_api.py").read_text(encoding="utf-8")
    assert "require_reader()" in text
    assert "require_manager()" in text
    assert "require_setup_command()" in text
    assert "setup_resource_api.post(\"/api/setup/resources\")" in text
    assert "setup_resource_api.patch(" in text
