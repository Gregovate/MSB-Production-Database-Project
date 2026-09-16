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
    assert "ref.container_type" not in section
    assert "c.container_type_id" in section
    assert "c.display_pallet" in section
    assert "home_location_code" in section
    assert "container_type_id = 2" not in section


def test_task_source_editor_is_compact_and_uses_governed_source_commands() -> None:
    ui = text("setup_task_extra_material_sources.js")
    bridge = text("setup_extra_materials.js")
    host = text("production_backend.py")

    assert "Expected Source Containers" in ui
    assert 'id="task-extra-material-source-form" class="extra-material-editor manager-only" hidden' in ui
    assert "Assign and reconcile where this requirement comes from." in ui
    assert "expected_quantity: numberOrNull" in ui
    assert "active_flag: false" in ui
    assert "api/setup/task-extra-materials/${requirementId}/sources/${existingSourceId}" in ui
    assert "api/setup/task-extra-materials/${requirementId}/sources" in ui
    assert "material_resolution?.container_ids" in ui
    assert "already an active source" in ui
    assert "if (row.display_pallet) return 'Display Pallet'" in ui
    assert "if (Number(row.container_type_id) === 2) return 'Kit Box'" in ui
    assert "setup-extra-material-source-row" in ui
    assert "Change</button>" in ui
    assert "Remove</button>" in ui

    assert "setup_task_extra_material_sources.js?v=2026-09-16.3" in bridge
    assert "script.addEventListener('load', loadTaskExtraMaterialSourceUi" in bridge
    assert '"setup_task_extra_material_sources.js"' in host


def test_replacement_source_does_not_inherit_old_container_facts() -> None:
    ui = text("setup_task_extra_material_sources.js")

    assert "originalSourceContainerId" in ui
    assert "handleSourceContainerChange" in ui
    assert "Replacement selected. Enter the quantity and verification known for the new Container." in ui
    assert "el('task-extra-material-source-qty').value = ''" in ui
    assert "el('task-extra-material-source-verification').value = 'UNVERIFIED'" in ui
    assert "el('task-extra-material-source-notes').value = ''" in ui


def test_source_quantity_is_verified_after_save_and_rendered_without_scale_zeroes() -> None:
    ui = text("setup_task_extra_material_sources.js")

    assert "function displayNumber(value)" in ui
    assert "Number.isFinite(parsed) ? String(parsed)" in ui
    assert "async function verifySourceRoundTrip" in ui
    assert "Saved source quantity mismatch" in ui
    assert "sameQuantity(source.expected_quantity, requested.expected_quantity)" in ui
    assert "Qty ${displayNumber(source.expected_quantity)}" in ui
    assert "await window.refreshTaskExtraMaterials(taskId)" in ui


def test_verified_source_requires_quantity_and_allocation_is_audited() -> None:
    ui = text("setup_task_extra_material_sources.js")
    css = text("setup_extra_materials.css")

    assert "Qty from this Container" in ui
    assert "A VERIFIED source requires Qty from this Container." in ui
    assert "function allocationAudit(requirement)" in ui
    assert "Allocated ${displayNumber(knownTotal)} of ${displayNumber(required)}" in ui
    assert "Verified sources total ${displayNumber(knownTotal)}; task requires ${displayNumber(required)}" in ui
    assert "REVIEW TASK REQUIREMENT" in ui
    assert "BALANCED" in ui
    assert "source ${missingCount === 1 ? 'quantity' : 'quantities'} missing" in ui
    assert "setup-extra-material-source-audit" in ui
    assert ".setup-extra-material-source-audit.ok" in css
    assert ".setup-extra-material-source-audit.mismatch" in css


def test_verified_mismatch_can_open_the_requirement_editor() -> None:
    ui = text("setup_task_extra_material_sources.js")
    requirement_ui = text("setup_task_extra_materials.js")

    assert "task-extra-material-requirement-review" in ui
    assert "Review Requirement" in ui
    assert "window.editTaskExtraMaterialRequirement(requirementId)" in ui
    assert "window.editTaskExtraMaterialRequirement = editRequirement" in requirement_ui


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
    assert "if (row.display_pallet) return 'Display Pallet'" in ui
    assert "if (Number(row.container_type_id) === 2) return 'Kit Box'" in ui
    assert "container_type_id === 2" not in ui
    assert "container_type_id == 2" not in ui
    assert '"setup_tpost_inventory_bootstrap.js"' in host


def test_changed_python_modules_parse() -> None:
    for name in ("setup_extra_material_api.py", "production_backend.py"):
        ast.parse(text(name), filename=name)
