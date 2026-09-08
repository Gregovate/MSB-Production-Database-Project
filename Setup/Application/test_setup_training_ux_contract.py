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


def test_catalog_detail_adds_database_resolved_material_logistics_section():
    js = read("setup_training_ux.js")
    assert "4. Material / Logistics Context" in js
    assert "5. Setup Procedures" in js
    assert "field-context?season_year=" in js
    assert "Displays resolved" in js
    assert "Containers resolved" in js
    assert "Support / KIT Containers" in js
    assert "Displays without Container" in js
    assert "Current LOR Scene membership" in js
    assert "Explicit reusable-task Display mapping" in js


def test_material_context_exposes_knowledge_gaps_instead_of_hard_coding_ids():
    js = read("setup_training_ux.js")
    assert "No Display or supplemental Container relationship is currently resolved" in js
    assert "Controllers:" in js
    assert "authoritative FieldWiring/controller relationships" in js
    assert "hard-coded Procedure text" in js


def test_material_context_has_theme_safe_responsive_styles():
    css = read("setup_training_ux.css")
    assert ".setup-material-summary" in css
    assert ".setup-material-container" in css
    assert ".setup-support-container-block" in css
    assert ".setup-controller-context-note" in css
    assert "var(--theme-subtle)" in css
    assert "var(--border)" in css
