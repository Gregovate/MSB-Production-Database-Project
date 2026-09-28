from __future__ import annotations

from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent


def text(name: str) -> str:
    return (BASE_DIR / name).read_text(encoding="utf-8")


def test_reusable_task_extra_materials_are_visible_in_task_detail() -> None:
    ui = text("setup_task_extra_materials.js")
    bridge = text("setup_extra_materials.js")
    host = text("production_backend.py")

    assert "Extra Materials Required by This Task" in ui
    assert "api/setup/tasks/${taskId}/extra-materials" in ui
    assert "maintain its Expected Source Container from the same requirement row" in ui
    assert "selectTaskWithExtraMaterials" in ui
    assert "task-extra-material-source-inline" in ui
    assert "Review Sources" in ui
    assert "Add Source" in ui
    assert "window.openTaskExtraMaterialSource" in ui

    assert "setup_task_extra_materials.js?v=2026-09-28.1" in bridge
    assert '"setup_task_extra_materials.js"' in host


def test_manager_requirement_editor_is_explicit_and_collapsed_by_default() -> None:
    ui = text("setup_task_extra_materials.js")
    refinement = text("setup_extra_material_source_usability.js")

    assert 'id="task-extra-material-add"' in ui
    assert 'id="task-extra-material-form" class="extra-material-editor manager-only" hidden' in ui
    assert "el('task-extra-material-form').hidden = false" in ui
    assert "Edit Requirement" in ui
    assert "Manager — Edit Task Requirement" in ui
    assert "New requirements require a physical source Container." in ui
    assert 'id="task-extra-material-create-source-container" required' in ui
    assert "commandOptions(method, payload(true))" in ui
    assert "Delete Mistake" in ui
    assert "window.editTaskExtraMaterialRequirement = editRequirement" in ui
    assert "['task-extra-material-form', 'task-extra-material-source-form']" in refinement
    assert "form.classList.remove('manager-only')" in refinement


def test_existing_task_extra_material_requirement_keeps_stable_material_identity() -> None:
    ui = text("setup_task_extra_materials.js")

    assert "el('task-extra-material-item').disabled = true" in ui
    assert "el('task-extra-material-item').disabled = false" in ui
    assert "if (option?.dataset.uom && !state.editingRowId)" in ui


def test_operator_quantity_formatting_strips_database_scale_zeroes() -> None:
    ui = text("setup_task_extra_materials.js")

    assert "function displayNumber(value)" in ui
    assert "Number.isFinite(parsed) ? String(parsed)" in ui
    assert "displayNumber(row.quantity_required)" in ui
    assert "displayNumber(row.length_value)" in ui


def test_kit_row_actions_move_operator_to_the_selected_editor() -> None:
    review = text("setup_kit_inventory_review.js")

    assert "openExpectedPanel('expected-qty')" in review
    assert "openInventoryPanel()" in review
    assert "focusEditor('inventory-editor', 'inventory-delta')" in review
    assert "scrollIntoView({ behavior: 'smooth', block: 'start' })" in review
    assert "focus({ preventScroll: true })" in review



def test_task_requirement_rows_keep_source_maintenance_adjacent() -> None:
    ui = text("setup_task_extra_materials.js")
    css = text("setup_extra_materials.css")

    assert "Expected Source Container from the same requirement row" in ui
    assert "function sourceAction(row)" in ui
    assert "task-extra-material-source-inline" in ui
    assert "Review Sources" in ui
    assert "Add Source" in ui
    assert "window.openTaskExtraMaterialSource(Number(rowId))" in ui
    assert ".task-extra-material-source-summary" in css
    assert ".task-extra-material-source-inline" in css



def test_new_requirement_requires_source_and_creates_container_authority_atomically() -> None:
    ui = text("setup_task_extra_materials.js")
    api = text("setup_extra_material_api.py")
    repo = text("setup_extra_material_repository.py")

    assert "New Extra Material requirements cannot be created without physical source authority." in ui
    assert "task-extra-material-create-source-container" in ui
    assert "setup_task_extra_material_source=result[\"source\"]" in api
    assert "container_content_created=result[\"container_content_created\"]" in api
    assert 'payload.get("source")' in repo
    assert "create_task_material_with_source" in repo
    assert "ref.set_setup_task_extra_material(" in repo
    assert "ref.set_setup_task_extra_material_source(" in repo
    assert "ref.set_setup_container_extra_material(" in repo
    assert "conn.commit()" in repo
    assert "A source Container is required when adding an Extra Material requirement." in api


def test_mistaken_requirement_uses_governed_hard_delete_not_inactive_tombstone() -> None:
    ui = text("setup_task_extra_materials.js")
    api = text("setup_extra_material_api.py")
    repo = text("setup_extra_material_repository.py")

    assert "Delete Mistake" in ui
    assert "commandOptions('DELETE', {})" in ui
    assert "permanently remove" in ui
    assert "@setup_extra_material_api.delete(" in api
    assert "delete_task_material" in repo
    assert "ref.delete_setup_task_extra_material" in repo
    assert "Do not carry mistaken Extra Material requirements forward as inactive rows." in api
