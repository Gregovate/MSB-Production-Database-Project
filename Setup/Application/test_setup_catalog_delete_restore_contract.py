from pathlib import Path


ROOT = Path(__file__).resolve().parent


def test_catalog_delete_is_manager_visible_without_annual_reconstruction_row():
    js = (ROOT / "setup_training_review_refinement.js").read_text(encoding="utf-8")
    assert "button.textContent = 'Delete Task'" in js
    assert "appState.access?.can_manage_setup" in js
    assert "task?.setup_task_id != null" in js
    assert "setup_session_task_id" not in js
    assert "season?.session_status" not in js
    assert "reconstruction mistakes, duplicates, and bad task definitions" in js


def test_catalog_delete_uses_existing_governed_fail_closed_command():
    js = (ROOT / "setup_training_review_refinement.js").read_text(encoding="utf-8")
    assert "deleteSelectedCatalogTask" in js
    assert "reconstruction-delete" in js
    assert "commandOptions('DELETE', {})" in js
    assert "protected planning or execution history" in js
    assert "event.stopImmediatePropagation()" in js
    assert "showView('library')" in js
