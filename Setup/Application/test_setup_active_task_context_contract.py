from pathlib import Path
import re


APP_DIR = Path(__file__).resolve().parent


def read(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def test_active_task_context_assets_are_loaded_and_protected() -> None:
    html = read("production.html")
    backend = read("production_backend.py")
    assert "setup_active_task_context.css?v=2026-09-12.1" in html
    assert "setup_active_task_context.js?v=2026-09-12.1" in html
    assert '"setup_active_task_context.css"' in backend
    assert '"setup_active_task_context.js"' in backend


def test_active_task_context_is_presentation_only() -> None:
    js = read("setup_active_task_context.js")
    for forbidden in ("api(", "fetch(", "commandOptions", "localStorage", "sessionStorage"):
        assert forbidden not in js
    assert "document.querySelector('.site-header .brand-copy')" in js
    assert "setup-active-task-context" in js
    assert "Active task" in js


def test_active_task_context_mirrors_existing_selected_task_identity() -> None:
    js = read("setup_active_task_context.js")
    assert "document.getElementById('detail-stage')" in js
    assert "document.getElementById('detail-task-name')" in js
    assert "reviewView?.classList.contains('active-view')" in js
    assert "!reviewDetail.hidden" in js
    assert "`${stage}${stage ? ' · ' : ''}${taskName}`" in js


def test_active_task_context_updates_on_task_switch_and_view_changes() -> None:
    js = read("setup_active_task_context.js")
    assert "MutationObserver" in js
    assert "watchText(document.getElementById('detail-stage'))" in js
    assert "watchText(document.getElementById('detail-task-name'))" in js
    assert "attributeFilter: ['hidden']" in js
    assert "attributeFilter: ['class']" in js
    assert "requestAnimationFrame(syncContext)" in js


def test_active_task_context_uses_existing_theme_tokens_and_mobile_wrap() -> None:
    css = read("setup_active_task_context.css")
    css_without_comments = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    assert "var(--accent)" in css
    assert "var(--text)" in css
    assert ".active-task-context[hidden]" in css
    assert "@media (max-width: 650px)" in css
    assert "overflow-wrap: anywhere" in css
    assert re.search(r"#[0-9a-fA-F]{3,8}\b", css_without_comments) is None


def test_issue_169_does_not_replace_dirty_edit_protection() -> None:
    guard = read("setup_catalog_dirty_guard.js")
    assert "Save and continue" in guard
    assert "Discard and continue" in guard
    assert "Stay on this task" in guard
    assert "resolveDirtyBeforeNavigation('opening another task')" in guard
    assert "beforeunload" in guard
