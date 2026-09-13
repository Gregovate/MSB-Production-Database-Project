from __future__ import annotations

import ast
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DB_DIR = BASE_DIR.parent / "Database"


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_inventory_requires_baseline_and_cannot_go_negative() -> None:
    sql = text(DB_DIR / "035_add_setup_extra_material_inventory_commands.sql")
    assert "Initial physical count must be recorded before inventory adjustments" in sql
    assert "Initial physical count already exists; use Count Correction for later recounts" in sql
    assert "Inventory adjustment would make physical on-hand quantity negative" in sql
    assert "v_event_count=0 AND v_event_type <> 'INITIAL_COUNT'" in sql
    assert "v_event_count>0 AND v_event_type='INITIAL_COUNT'" in sql


def test_inventoried_container_identity_is_immutable() -> None:
    sql = text(DB_DIR / "034_add_setup_extra_material_container_commands.sql")
    assert "Inventoried Container material identity cannot be changed" in sql
    assert "Container material cannot be removed while physical on-hand inventory is nonzero" in sql
    for field in (
        "cem.container_id IS DISTINCT FROM p_container_id",
        "cem.setup_extra_material_id IS DISTINCT FROM p_setup_extra_material_id",
        "cem.quantity_uom IS DISTINCT FROM v_uom",
        "cem.size_text IS DISTINCT FROM v_size",
        "cem.length_value IS DISTINCT FROM p_length_value",
        "cem.length_unit IS DISTINCT FROM v_length_unit",
        "cem.color IS DISTINCT FROM v_color",
    ):
        assert field in sql


def test_inventory_history_uses_real_person_columns() -> None:
    repo = text(BASE_DIR / "setup_extra_material_repository.py")
    assert "p.display_name" not in repo
    assert "p.first_name" in repo
    assert "p.last_name" in repo
    assert "p.email" in repo


def test_extra_material_ui_is_mounted_as_setup_tab() -> None:
    html = text(BASE_DIR / "production.html")
    host = text(BASE_DIR / "production_backend.py")
    js = text(BASE_DIR / "setup_extra_materials.js")
    css = text(BASE_DIR / "setup_extra_materials.css")

    assert 'data-view="extra-materials"' in html
    assert 'id="extra-materials-view"' in html
    assert 'id="extra-material-container-id"' in html
    assert 'id="extra-material-unverified-items"' in html
    assert 'id="extra-material-inventory-form"' in html
    assert 'id="extra-material-summary-body"' in html
    assert 'setup_extra_materials.js?v=' in html
    assert 'setup_extra_materials.css?v=' in html

    assert '"setup_extra_materials.js"' in host
    assert '"setup_extra_materials.css"' in host
    assert "app.register_blueprint(setup_extra_material_api)" in host

    assert "api/setup/containers/${state.containerId}/extra-materials" in js
    assert "api/setup/container-extra-materials/${state.selectedInventoryContentId}/inventory-events" in js
    assert "api/setup/extra-materials/balance-summary" in js
    assert "Production Crew" in js
    assert "extra-material-table" in css


def test_extra_material_js_has_expected_manager_and_crew_split() -> None:
    js = text(BASE_DIR / "setup_extra_materials.js")
    api = text(BASE_DIR / "setup_extra_material_api.py")

    assert "access.can_manage_setup" in js
    assert "canAdjustInventory()" in js
    assert "role === 'Production Crew'" in js
    assert "policies.has('Production Crew')" in js
    assert "Volunteer" not in js

    assert "require_manager()" in api
    assert "require_inventory_operator()" in api
    assert "role_name == \"Production Crew\"" in api
    assert "role_name == \"Volunteer\"" not in api


def test_new_python_modules_parse() -> None:
    for name in ("setup_extra_material_repository.py", "setup_extra_material_api.py", "production_backend.py"):
        ast.parse(text(BASE_DIR / name), filename=name)
