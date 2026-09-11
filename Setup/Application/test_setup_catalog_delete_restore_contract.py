from pathlib import Path


ROOT = Path(__file__).resolve().parent


def test_catalog_delete_is_manager_visible_without_annual_reconstruction_row():
    js = (ROOT / "setup_training_review_refinement.js").read_text(encoding="utf-8")
    assert "button.textContent !== 'Delete Task'" in js
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


def test_catalog_delete_sync_is_idempotent_under_mutation_observers():
    js = (ROOT / "setup_training_review_refinement.js").read_text(encoding="utf-8")
    assert "if (button.textContent !== 'Delete Task') button.textContent = 'Delete Task';" in js
    assert "if (button.title !== deleteTitle) button.title = deleteTitle;" in js
    assert "if (button.hidden !== shouldHide) button.hidden = shouldHide;" in js
    assert "attributeFilter: ['hidden']" in js


def test_catalog_delete_returns_through_existing_catalog_origin_control():
    js = (ROOT / "setup_training_review_refinement.js").read_text(encoding="utf-8")
    assert "const returnButton = document.getElementById('setup-return-library');" in js
    assert "const returnWrap = document.getElementById('setup-return-library-wrap');" in js
    assert "returnThroughCatalogOrigin" in js
    assert "returnButton.click();" in js


def test_cleanup_assets_are_cache_busted_together():
    html = (ROOT / "production.html").read_text(encoding="utf-8")
    assert 'setup_training_review_refinement.css?v=2026-09-09.3' in html
    assert 'setup_training_review_refinement.js?v=2026-09-09.3' in html
    assert 'setup_catalog_effort.js?v=2026-09-09.3' in html
