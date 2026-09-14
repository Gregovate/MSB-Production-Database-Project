from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
ACCEPTANCE_DIR = APP_DIR.parent / "Acceptance"


def text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_workbench_is_preview_only_not_production_route() -> None:
    preview = text(ACCEPTANCE_DIR / "setup_session_browser_preview_entry.py")
    production = text(APP_DIR / "production_backend.py")

    assert '/kit-assignment-workbench' in preview
    assert 'setup_disposable_kit_assignment_workbench.html' in preview
    assert 'setup_disposable_kit_assignment_workbench.html' not in production
    assert 'setup_disposable_kit_assignment_workbench.js' not in production


def test_workbench_uses_existing_governed_kit_assignment_api() -> None:
    js = text(ACCEPTANCE_DIR / "setup_disposable_kit_assignment_workbench.js")

    assert 'X-MSB-Setup-Command' in js
    assert 'api/setup/tasks/${taskId}/kit-boxes/${containerId}' in js
    assert 'assigned: true' in js
    assert '[DISPOSABLE_KIT_RECON_V1]' in js
    assert 'ref.setup_task_container_support' in js  # capture artifact only
    assert 'INSERT INTO ref.setup_task_container_support' in js  # generated capture, never executed by browser


def test_existing_assignments_are_not_removed_by_bulk_workbench() -> None:
    js = text(ACCEPTANCE_DIR / "setup_disposable_kit_assignment_workbench.js")

    assert 'Existing/baseline Kit assignments cannot be removed' in js
    assert 'isWorkbenchAssignment(assignment)' in js
    assert 'assigned: false' in js
    assert 'undoAssignment' in js


def test_workbench_supports_drag_drop_and_capture() -> None:
    html = text(ACCEPTANCE_DIR / "setup_disposable_kit_assignment_workbench.html")
    js = text(ACCEPTANCE_DIR / "setup_disposable_kit_assignment_workbench.js")

    assert 'Drop a Kit on a Task' in html
    assert 'capture-copy' in html
    assert 'capture-download' in html
    assert "addEventListener('dragstart'" in js
    assert "addEventListener('drop'" in js
    assert 'Download capture SQL' in html
    assert 'DISPOSABLE CAPTURE ARTIFACT ONLY' in js
