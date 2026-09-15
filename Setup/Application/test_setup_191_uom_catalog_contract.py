from __future__ import annotations

import ast
from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
SETUP_DIR = APP_DIR.parent
DB_DIR = SETUP_DIR / "Database"
ACCEPTANCE_DIR = SETUP_DIR / "Acceptance"


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_uom_migration_harvests_current_values_before_enforcing_fks() -> None:
    sql = text(DB_DIR / "049_add_setup_uom_catalog.sql")

    assert "CREATE TABLE IF NOT EXISTS ref.setup_uom" in sql
    assert "SELECT upper(btrim(default_uom)) AS uom_code FROM ref.setup_extra_material" in sql
    assert "SELECT upper(btrim(quantity_uom)) FROM ref.setup_task_extra_material" in sql
    assert "SELECT upper(btrim(quantity_uom)) FROM ref.setup_container_extra_material" in sql
    assert "ON CONFLICT (uom_code) DO NOTHING" in sql

    harvest_at = sql.index("WITH current_uom AS")
    material_fk_at = sql.index("fk_setup_extra_material_default_uom")
    task_fk_at = sql.index("fk_setup_task_extra_material_quantity_uom")
    container_fk_at = sql.index("fk_setup_container_extra_material_quantity_uom")
    assert harvest_at < material_fk_at
    assert harvest_at < task_fk_at
    assert harvest_at < container_fk_at

    assert "('EA', 'Each'" in sql
    assert "('FT', 'Foot / feet'" in sql
    assert "('IN', 'Inch / inches'" in sql
    assert "('SHEET', 'Sheet'" in sql


def test_uom_migration_enforces_active_stable_codes_and_narrow_writes() -> None:
    sql = text(DB_DIR / "049_add_setup_uom_catalog.sql")

    assert "CREATE OR REPLACE FUNCTION ref.enforce_active_setup_uom()" in sql
    assert "Unknown or inactive Setup UOM" in sql
    assert "CREATE OR REPLACE FUNCTION ref.guard_setup_uom_identity_and_deactivation()" in sql
    assert "Setup UOM code is a stable identity and cannot be renamed" in sql
    assert "Setup UOM cannot be deactivated while active Extra Material rows still reference it" in sql
    assert "CREATE OR REPLACE FUNCTION ref.create_setup_uom" in sql
    assert "CREATE OR REPLACE FUNCTION ref.update_setup_uom" in sql
    assert "GRANT SELECT ON ref.setup_uom TO fieldwiring_app" in sql
    assert "REVOKE INSERT, UPDATE, DELETE ON ref.setup_uom FROM fieldwiring_app" in sql
    assert "GRANT EXECUTE ON FUNCTION ref.create_setup_uom" in sql
    assert "GRANT EXECUTE ON FUNCTION ref.update_setup_uom" in sql


def test_uom_api_and_repository_use_governed_commands() -> None:
    api = text(APP_DIR / "setup_extra_material_api.py")
    repo = text(APP_DIR / "setup_uom_repository.py")

    assert '@setup_extra_material_api.get("/api/setup/uoms")' in api
    assert '@setup_extra_material_api.get("/api/setup/uom-catalog")' in api
    assert '@setup_extra_material_api.post("/api/setup/uoms")' in api
    assert '@setup_extra_material_api.patch("/api/setup/uoms/<path:uom_code>")' in api
    assert "require_reader()" in api
    assert "require_manager()" in api
    assert "require_setup_command()" in api
    assert "SetupUomRepositoryError" in api

    assert "FROM ref.setup_uom" in repo
    assert "ref.create_setup_uom" in repo
    assert "ref.update_setup_uom" in repo
    assert "conn.set_session(readonly=False, autocommit=False)" in repo
    assert "INSERT INTO ref.setup_uom" not in repo
    assert "UPDATE ref.setup_uom" not in repo

    ast.parse(api)
    ast.parse(repo)


def test_kit_uom_fields_are_governed_selectors_not_free_text() -> None:
    html = text(APP_DIR / "kit_inventory.html")
    js = text(APP_DIR / "setup_uom_catalog.js")
    backend = text(APP_DIR / "production_backend.py")

    assert '<label>UOM<select id="expected-uom" required></select></label>' in html
    assert '<label>Default UOM<select id="extra-material-catalog-uom" required></select></label>' in html
    assert '<label>Default UOM<select id="extra-material-new-uom" required></select></label>' in html
    assert 'id="expected-uom" type="text"' not in html
    assert 'id="extra-material-catalog-uom" type="text"' not in html
    assert 'id="extra-material-new-uom" type="text"' not in html
    assert "setup_uom_catalog.js?v=2026-09-15.1" in html

    assert "'expected-uom'" in js
    assert "'extra-material-new-uom'" in js
    assert "'task-extra-material-uom'" in js
    assert "'extra-material-catalog-uom'" in js
    assert "api/setup/uoms" in js
    assert "api/setup/uom-catalog" in js
    assert "setup-uom-manager" in js
    assert "Manage UOMs…" in js
    assert "Save UOM" in js
    assert "Save New UOM" in js
    assert "choose it explicitly where needed" in js

    assert '"setup_uom_catalog.js"' in backend
    assert "setup_uom_catalog.js" in text(APP_DIR / "setup_extra_materials.js")


def test_uom_save_actions_follow_primary_blue_button_convention() -> None:
    html = text(APP_DIR / "kit_inventory.html")
    js = text(APP_DIR / "setup_uom_catalog.js")

    assert '<button type="submit">Save New Catalog Material</button>' in html
    assert '<button type="submit" class="secondary">Save New Catalog Material</button>' not in html
    assert '<button id="setup-uom-save" type="button">Save UOM</button>' in js
    assert '<button id="setup-uom-new-save" type="submit">Save New UOM</button>' in js
    assert 'id="setup-uom-save" type="button" class="secondary"' not in js
    assert 'id="setup-uom-new-save" type="submit" class="secondary"' not in js


def test_quantity_can_remain_unknown_but_supplied_values_are_positive() -> None:
    schema = text(DB_DIR / "032_add_setup_extra_material_schema.sql")
    commands = text(DB_DIR / "033_add_setup_extra_material_manager_commands.sql")
    html = text(APP_DIR / "kit_inventory.html")

    assert "quantity_required IS NULL OR quantity_required > 0" in schema
    assert "expected_quantity IS NULL OR expected_quantity > 0" in schema
    assert "p_quantity_required IS NOT NULL AND p_quantity_required <= 0" in commands
    assert 'id="expected-qty" type="number" min="0.001" step="0.001"' in html
    assert 'id="expected-qty" type="number" min="0.001" step="0.001" required' not in html


def test_disposable_validation_covers_fk_privilege_and_behavioral_guards() -> None:
    validation = text(ACCEPTANCE_DIR / "setup_191_uom_catalog_disposable_validation.sql")

    assert "SETUP_191_UOM_CATALOG_DISPOSABLE_PASS" in validation
    assert "fk_setup_extra_material_default_uom" in validation
    assert "fk_setup_task_extra_material_quantity_uom" in validation
    assert "fk_setup_container_extra_material_quantity_uom" in validation
    assert "ZZNOTREAL" in validation
    assert "unknown UOM was accepted" in validation
    assert "allowed deactivation of UOM still referenced" in validation
    assert "ROLLBACK;" in validation
    assert "season_year=2026" in validation
