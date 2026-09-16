from __future__ import annotations

import ast
from pathlib import Path


APP_DIR = Path(__file__).resolve().parent


def text(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def test_source_container_catalog_is_read_only_and_not_kit_restricted() -> None:
    api = text("setup_extra_material_api.py")

    assert '@setup_extra_material_api.get("/api/setup/containers/source-options")' in api
    section = api.split('def api_setup_extra_material_source_containers', 1)[1].split('@setup_extra_material_api.get("/api/setup/uoms")', 1)[0]
    assert "require_reader()" in section
    assert "FROM ref.container AS c" in section
    assert "LEFT JOIN ref.container_type AS ct" in section
    assert "container_type_name" in section
    assert "home_location_code" in section
    assert "container_type_id = 2" not in section


def test_task_source_editor_preserves_requirement_and_uses_governed_source_commands() -> None:
    ui = text("setup_task_extra_material_sources.js")
    bridge = text("setup_extra_materials.js")
    host = text("production_backend.py")

    assert "Expected Source Containers" in ui
    assert "Task-resolved Display Containers are shown first" in ui
    assert "expected_quantity: numberOrNull" in ui
    assert "active_flag: false" in ui
    assert "api/setup/task-extra-materials/${state.selectedRequirementId}/sources" in ui
    assert "api/setup/task-extra-materials/${requirementId}/sources/${sourceId}" in ui
    assert "material_resolution?.container_ids" in ui
    assert "already an active source" in ui
    assert "TASK CONTAINER" in ui

    assert "setup_task_extra_material_sources.js?v=2026-09-15.1" in bridge
    assert "script.addEventListener('load', loadTaskExtraMaterialSourceUi" in bridge
    assert '"setup_task_extra_material_sources.js"' in host


def test_tpost_inventory_can_bootstrap_an_existing_non_kit_container() -> None:
    page = text("t_post_inventory.html")
    ui = text("setup_tpost_inventory_bootstrap.js")
    host = text("production_backend.py")

    assert 'id="tpost-bootstrap-panel"' in page
    assert "Add another T-Post stock Container" in page
    assert "setup_tpost_inventory_bootstrap.js?v=2026-09-15.1" in page

    assert "api/setup/containers/source-options" in ui
    assert "api/setup/t-post-inventory/containers" in ui
    assert "api/setup/containers/${containerId}/extra-materials" in ui
    assert "setup_extra_material_id: Number(state.tpostMaterialId)" in ui
    assert "quantity_uom: 'EA'" in ui
    assert "expected_quantity: null" in ui
    assert "container_type_id === 2" not in ui
    assert "container_type_id == 2" not in ui
    assert '"setup_tpost_inventory_bootstrap.js"' in host


def test_changed_python_modules_parse() -> None:
    for name in ("setup_extra_material_api.py", "production_backend.py"):
        ast.parse(text(name), filename=name)
