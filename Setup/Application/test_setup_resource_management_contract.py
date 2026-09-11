from __future__ import annotations

from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
REPO_ROOT = APP_DIR.parents[1]
BASE_MIGRATION = REPO_ROOT / "Setup" / "Database" / "008_create_setup_resource_management_commands.sql"
CATALOG_MIGRATION = REPO_ROOT / "Setup" / "Database" / "027_add_setup_resource_catalog_management.sql"


def test_resource_migration_preserves_narrow_write_boundary() -> None:
    base = BASE_MIGRATION.read_text(encoding="utf-8")
    catalog = CATALOG_MIGRATION.read_text(encoding="utf-8")
    assert "ADD COLUMN IF NOT EXISTS active_flag" in base
    assert "CREATE OR REPLACE FUNCTION ref.create_setup_resource" in base
    assert "CREATE OR REPLACE FUNCTION ref.set_setup_task_resource" in base
    assert "FROM ref.setup_management_actor(p_email, false)" in base
    assert "GRANT EXECUTE ON FUNCTION ref.create_setup_resource" in base
    assert "GRANT EXECUTE ON FUNCTION ref.set_setup_task_resource" in base
    assert "GRANT UPDATE ON ref.setup_task_resource" not in base
    assert "DELETE FROM ref.setup_task_resource" not in base

    assert "ADD COLUMN IF NOT EXISTS display_order integer NOT NULL DEFAULT 100" in catalog
    assert "CREATE OR REPLACE FUNCTION ref.update_setup_resource" in catalog
    assert "FROM ref.setup_management_actor(p_email, false)" in catalog
    assert "GRANT EXECUTE ON FUNCTION ref.update_setup_resource" in catalog
    assert "GRANT UPDATE ON ref.setup_resource" not in catalog
    assert "GRANT DELETE ON ref.setup_resource" not in catalog
    assert "DELETE FROM ref.setup_resource" not in catalog


def test_resource_repository_uses_catalog_order_and_stable_id_update() -> None:
    source = (APP_DIR / "setup_resource_repository.py").read_text(encoding="utf-8")
    assert "display_order" in source
    assert "ORDER BY display_order, resource_name, setup_resource_id" in source
    assert "r.display_order" in source
    assert "ref.update_setup_resource" in source
    assert "setup_resource_id" in source


def test_resource_ui_separates_catalog_editing_from_task_assignment() -> None:
    js = (APP_DIR / "setup_resource_review.js").read_text(encoding="utf-8")
    css = (APP_DIR / "setup_resource_review.css").read_text(encoding="utf-8")
    assert "Equipment / Resources Needed" in js
    assert "Add existing equipment/resource to this task" in js
    assert "Task-specific notes" in js
    assert "Manage reusable resource catalog" in js
    assert "Existing task assignments stay attached to the same resource ID after a rename" in js
    assert "setup-resource-catalog-name" in js
    assert "setup-resource-catalog-type" in js
    assert "setup-resource-catalog-order" in js
    assert "setup-resource-catalog-active" in js
    assert "setup-resource-catalog-notes" in js
    assert "api/setup/resource-catalog" in js
    assert "api/setup/resources/${resourceId}" in js
    assert "quantity_required" in js
    assert "requirement_type" in js
    assert "active_flag" in js
    assert "resource-edit-grid" in css
    assert "resource-catalog-grid" in css
    assert "grid-template-columns: minmax(290px, 340px) minmax(0, 1fr)" in css


def test_resource_api_is_role_governed() -> None:
    text = (APP_DIR / "setup_resource_api.py").read_text(encoding="utf-8")
    assert "require_reader()" in text
    assert "require_manager()" in text
    assert "require_setup_command()" in text
    assert "setup_resource_api.post(\"/api/setup/resources\")" in text
    assert "setup_resource_api.get(\"/api/setup/resource-catalog\")" in text
    assert "setup_resource_api.patch(\"/api/setup/resources/<int:setup_resource_id>\")" in text
    assert "catalog(include_inactive=True)" in text
