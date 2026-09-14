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
    assert "Expected Source" in ui
    assert "row.sources" in ui
    assert "Task requirements are separate from Kit contents and physical stock" in ui
    assert "selectTaskWithExtraMaterials" in ui

    assert "setup_task_extra_materials.js" in bridge
    assert '"setup_task_extra_materials.js"' in host


def test_manager_can_maintain_task_extra_material_requirements() -> None:
    ui = text("setup_task_extra_materials.js")

    assert "Manager — Task Extra Material Requirement" in ui
    assert "commandOptions(method, payload(true))" in ui
    assert "Add Requirement" in ui
    assert "Save Requirement" in ui
    assert "Remove Requirement" in ui
    assert "quantity_qualifier" in ui
    assert "verification_state" in ui


def test_kit_row_actions_move_operator_to_the_selected_editor() -> None:
    review = text("setup_kit_inventory_review.js")

    assert "focusEditor('expected-editor', 'expected-qty')" in review
    assert "focusEditor('inventory-editor', 'inventory-delta')" in review
    assert "scrollIntoView({ behavior: 'smooth', block: 'start' })" in review
    assert "focus({ preventScroll: true })" in review
