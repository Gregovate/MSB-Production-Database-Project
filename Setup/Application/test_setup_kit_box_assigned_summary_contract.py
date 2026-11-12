from pathlib import Path


APP_DIR = Path(__file__).resolve().parent


def read(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def test_kit_assignment_round_trips_immediately_without_task_save() -> None:
    js = read("setup_kit_box_assignment.js")
    assert "Changes save immediately." in js
    assert "await loadKitBoxes(taskId, { render: true });" in js
    assert "instead of waiting" in js
    assert "Save Reusable Task" in js
    assert "assigned and saved immediately" in js


def test_material_panel_lists_assigned_kit_box_names() -> None:
    js = read("setup_kit_box_assignment.js")
    assert "setup-kit-box-assigned" in js
    assert "Assigned Kit Boxes:" in js
    assert "row.container_description" in js
    assert "setup-kit-box-chip-id" in js


def test_assigned_kit_box_can_be_removed_without_opening_full_picker() -> None:
    js = read("setup_kit_box_assignment.js")
    assert "setup-kit-box-chip-remove" in js
    assert "Remove this Kit Box assignment" in js
    assert "await setAssignment(containerId, false, null);" in js


def test_kit_box_action_uses_same_material_action_visual_language() -> None:
    css = read("setup_kit_box_assignment.css")
    assert "#setup-kit-box-open" in css
    assert "var(--setup-material-action-bg" in css
    assert "var(--setup-material-action-border" in css
    assert "var(--setup-material-action-hover" in css
