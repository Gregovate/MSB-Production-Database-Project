from pathlib import Path


ROOT = Path(__file__).resolve().parent


def read(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")


def test_training_ux_assets_are_loaded_after_live_review_fixes():
    html = read("production.html")
    live_index = html.index("setup_live_review_fixes.js?v=2026-09-08.3")
    training_index = html.index("setup_training_ux.js?v=2026-09-08.1")
    assert "setup_training_ux.css?v=2026-09-08.1" in html
    assert training_index > live_index


def test_catalog_open_gets_contextual_return_navigation():
    js = read("setup_training_ux.js")
    assert "#library-view .open-task" in js
    assert "← Back to Reusable Task Catalog" in js
    assert "rememberLibraryOrigin" in js
    assert "showView('library')" in js
    assert "scrollIntoView({ block: 'center', behavior: 'auto' })" in js
    assert "setup-return-highlight" in js


def test_verification_queue_open_clears_catalog_return_context():
    js = read("setup_training_ux.js")
    assert "#review-list .task-row" in js
    assert "clearLibraryOrigin" in js


def test_return_control_is_sticky_and_hidden_when_not_in_catalog_flow():
    css = read("setup_training_ux.css")
    assert ".setup-return-library-wrap" in css
    assert "position: sticky" in css
    assert ".setup-return-library-wrap[hidden]" in css
