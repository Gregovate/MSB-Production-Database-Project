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
    assert "Reusable requirement only. Source Containers are maintained separately below." in ui
    assert "selectTaskWithExtraMaterials" in ui
    assert "source${sources.length === 1 ? '' : 's'}" in ui

    assert "setup_task_extra_materials.js?v=2026-09-16.2" in bridge
    assert '"setup_task_extra_materials.js"' in host


def test_manager_requirement_editor_is_explicit_and_collapsed_by_default() -> None:
    ui = text("setup_task_extra_materials.js")
    refinement = text("setup_extra_material_source_usability.js")

    assert 'id="task-extra-material-add"' in ui
    assert 'id="task-extra-material-form" class="extra-material-editor manager-only" hidden' in ui
    assert "el('task-extra-material-form').hidden = false" in ui
    assert "Edit Requirement" in ui
    assert "Manager — Edit Task Requirement" in ui
    assert "This changes the reusable requirement itself, not its source Containers." in ui
    assert "commandOptions(method, payload(true))" in ui
    assert "Remove Requirement" in ui
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
