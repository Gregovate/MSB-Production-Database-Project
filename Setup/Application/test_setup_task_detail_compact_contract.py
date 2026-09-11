from pathlib import Path


APP_DIR = Path(__file__).resolve().parent


def read(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def test_compact_task_detail_assets_are_loaded_and_protected() -> None:
    html = read("production.html")
    backend = read("production_backend.py")
    assert "setup_task_detail_compact.css?v=2026-09-11.1" in html
    assert "setup_task_detail_compact.js?v=2026-09-11.1" in html
    assert '"setup_task_detail_compact.css"' in backend
    assert '"setup_task_detail_compact.js"' in backend


def test_compact_layout_is_presentation_only() -> None:
    js = read("setup_task_detail_compact.js")
    assert "api(" not in js
    assert "commandOptions" not in js
    assert "fetch(" not in js
    assert "localStorage" not in js
    assert "setup-task-editor-grid" in js
    assert "setup-captain-rail" in js
    assert "setup-material-context-compact-section" in js


def test_captains_use_right_rail_without_changing_captain_controls() -> None:
    js = read("setup_task_detail_compact.js")
    training = read("setup_training_ux.js")
    assert "annual.insertAdjacentElement('afterend', captain)" in js
    assert "setup-captain-section" in js
    assert "setup-captain-save" in training
    assert "setup-captain-clear" in training
    assert "api/setup/tasks/${task.setup_task_id}/captains/${personId}" in training


def test_reusable_editor_compacts_on_desktop_and_stacks_responsively() -> None:
    css = read("setup_task_detail_compact.css")
    assert "@media (min-width: 1051px)" in css
    assert "#reusable-fieldset" in css
    assert "grid-template-columns: repeat(2, minmax(0, 1fr))" in css
    assert "#annual-fieldset" in css
    assert "#setup-captain-section.setup-captain-rail" in css
    assert "@media (max-width: 1050px)" in css


def test_material_summary_is_compact_but_existing_detail_dialog_remains() -> None:
    css = read("setup_task_detail_compact.css")
    refinement = read("setup_training_review_refinement.js")
    assert "#setup-material-context-section .setup-material-summary" in css
    assert "display: flex" in css
    assert "border-radius: 999px" in css
    assert "View Material Details" in refinement
    assert "setup-material-details-dialog" in refinement
    assert "dialog.showModal()" in refinement


def test_compact_layout_uses_existing_theme_tokens_not_a_new_base_palette() -> None:
    css = read("setup_task_detail_compact.css")
    for token in ("var(--border)", "var(--muted)"):
        assert token in css
    for forbidden in (
        "#f4f6f8",
        "#ffffff",
        "#1f2937",
        "#c8cdd4",
        "#1f6feb",
        "#0b1220",
        "#111a2b",
        "#2f81f7",
    ):
        assert forbidden not in css
