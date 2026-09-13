from pathlib import Path


APP_DIR = Path(__file__).resolve().parent


def test_kit_box_assignment_dialog_has_client_side_search() -> None:
    js = (APP_DIR / "setup_kit_box_assignment.js").read_text(encoding="utf-8")
    css = (APP_DIR / "setup_kit_box_assignment.css").read_text(encoding="utf-8")

    assert 'id="setup-kit-box-search"' in js
    assert 'type="search"' in js
    assert "Search name, Container ID, home location, or other task" in js
    assert "function kitBoxMatchesSearch" in js
    assert "row.container_description" in js
    assert "row.container_id" in js
    assert "row.home_location_code" in js
    assert "row.other_task_assignments" in js
    assert "visibleKitBoxes" in js
    assert "No Kit Boxes match" in js
    assert "requestAnimationFrame(() => dialog.querySelector('#setup-kit-box-search')?.focus())" in js
    assert ".setup-kit-box-toolbar" in css
    assert ".setup-kit-box-search-label" in css
