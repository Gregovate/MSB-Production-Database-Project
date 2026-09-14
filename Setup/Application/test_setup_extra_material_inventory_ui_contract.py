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


def test_kit_inventory_is_standalone_route_not_annual_session_workspace() -> None:
    html = text(BASE_DIR / "production.html")
    host = text(BASE_DIR / "production_backend.py")
    bridge = text(BASE_DIR / "setup_extra_materials.js")
    page = text(BASE_DIR / "kit_inventory.html")
    js = text(BASE_DIR / "setup_kit_inventory.js")
    css = text(BASE_DIR / "setup_kit_inventory.css")

    # Setup retains an entry point, but the first embedded #167 workspace is
    # removed at runtime and the tab routes to durable Kit Inventory instead.
    assert 'data-view="extra-materials"' in html
    assert "tab.textContent = 'Kit Inventory'" in bridge
    assert "document.getElementById('extra-materials-view')?.remove()" in bridge
    assert "window.location.assign(inventoryUrl(containerId))" in bridge

    assert '@app.get("/kit-inventory")' in host
    assert '@app.get("/kit-inventory/")' in host
    assert '@app.get("/kit-inventory/<int:container_id>")' in host
    assert 'send_from_directory(BASE_DIR, "kit_inventory.html")' in host
    assert 'app.register_blueprint(setup_kit_inventory_api)' in host

    assert '<h1>Kit Inventory</h1>' in page
    assert 'id="kit-list"' in page
    assert 'id="kit-content-body"' in page
    assert 'id="unverified-items"' in page
    assert 'id="inventory-form"' in page
    assert 'Back to Setup Session' in page

    assert "api/setup/kit-inventory/kit-boxes" in js
    assert "api/setup/containers/${state.selectedContainerId}/extra-materials" in js
    assert "api/setup/container-extra-materials/${state.inventoryContentId}/inventory-events" in js
    assert "Production Crew" in js
    assert ".inventory-layout" in css


def test_setup_assignments_link_directly_to_kit_inventory() -> None:
    bridge = text(BASE_DIR / "setup_extra_materials.js")
    assert "setup-kit-box-chip[data-container-id]" in bridge
    assert "setup-kit-box-row[data-container-id]" in bridge
    assert "View Inventory" in bridge
    assert "openInventory(containerId)" in bridge


def test_manager_and_production_crew_split_is_preserved() -> None:
    js = text(BASE_DIR / "setup_kit_inventory.js")
    api = text(BASE_DIR / "setup_extra_material_api.py")

    assert "state.access?.can_manage_setup" in js
    assert "canAdjustInventory()" in js
    assert "role === 'Production Crew'" in js
    assert "policies.has('Production Crew')" in js
    assert "Volunteer" not in js

    assert "require_manager()" in api
    assert "require_inventory_operator()" in api
    assert "role_name == \"Production Crew\"" in api
    assert "role_name == \"Volunteer\"" not in api


def test_kit_inventory_list_reads_existing_141_assignments() -> None:
    api = text(BASE_DIR / "setup_kit_inventory_api.py")
    assert "ref.setup_task_container_support" in api
    assert "tc.relationship_type = 'KIT'" in api
    assert "WHERE c.container_type_id = 2" in api
    assert "INSERT INTO ref.setup_task_container_support" not in api


def test_new_python_modules_parse() -> None:
    for name in (
        "setup_extra_material_repository.py",
        "setup_extra_material_api.py",
        "setup_kit_inventory_api.py",
        "production_backend.py",
    ):
        ast.parse(text(BASE_DIR / name), filename=name)
