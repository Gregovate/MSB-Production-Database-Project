from pathlib import Path
import re


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
    assert "setup-task-editor-left" in js
    assert "setup-task-editor-right" in js
    assert "setup-captain-rail" in js
    assert "setup-material-context-compact-section" in js


def test_editor_uses_independent_left_and_right_rails() -> None:
    js = read("setup_task_detail_compact.js")
    assert "leftRail.appendChild(reusable)" in js
    assert "rightRail.appendChild(annual)" in js
    assert "rightRail.appendChild(captain)" in js
    assert "leftRail.appendChild(material)" in js


def test_captain_controls_and_governed_write_path_are_unchanged() -> None:
    training = read("setup_training_ux.js")
    assert "setup-captain-save" in training
    assert "setup-captain-clear" in training
    assert "api/setup/tasks/${task.setup_task_id}/captains/${personId}" in training


def test_reusable_editor_compacts_on_desktop_and_stacks_responsively() -> None:
    css = read("setup_task_detail_compact.css")
    assert "@media (min-width: 1051px)" in css
    assert "#reusable-fieldset" in css
    assert "grid-template-columns: repeat(2, minmax(0, 1fr))" in css
    assert "#review-detail .setup-task-editor-left" in css
    assert "#review-detail .setup-task-editor-right" in css
    assert "@media (max-width: 1050px)" in css
    assert "grid-template-columns: 1fr" in css


def test_material_context_uses_left_rail_and_consolidated_wording() -> None:
    js = read("setup_task_detail_compact.js")
    assert "leftRail.appendChild(material)" in js
    assert "4. Material / Logistics" in js
    assert "Current Displays and Containers resolved automatically" in js
    assert "Full Display / Container list and inclusion reasons." in js
    assert "Controllers:</strong> not included in this resolver yet." in js


def test_material_summary_is_compact_but_existing_detail_dialog_remains() -> None:
    css = read("setup_task_detail_compact.css")
    refinement = read("setup_training_review_refinement.js")
    assert "#setup-material-context-section .setup-material-summary" in css
    assert "display: flex" in css
    assert "border-radius: 999px" in css
    assert "View Material Details" in refinement
    assert "setup-material-details-dialog" in refinement
    assert "dialog.showModal()" in refinement


def test_compact_layout_does_not_introduce_a_new_base_palette() -> None:
    css = read("setup_task_detail_compact.css")

    # Issue #153 is layout-only. Ignore comments (including issue references such
    # as #153) and inspect only actual CSS syntax for palette declarations.
    css_without_comments = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    assert re.search(r"#[0-9a-fA-F]{3,8}\b", css_without_comments) is None

    for forbidden_property in (
        "background:",
        "background-color:",
        "color:",
        "border-color:",
        "box-shadow:",
    ):
        assert forbidden_property not in css_without_comments
