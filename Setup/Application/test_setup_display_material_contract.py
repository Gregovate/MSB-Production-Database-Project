from __future__ import annotations

import ast
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "Application"
DB = ROOT / "Database"


def test_material_migration_separates_display_setup_from_scope_material() -> None:
    text = (DB / "025_add_setup_display_material_requirement.sql").read_text(encoding="utf-8")
    assert "is_display_setup_step boolean NOT NULL DEFAULT false" in text
    assert "requires_display_material boolean NOT NULL DEFAULT false" in text
    assert "set_setup_task_display_setup_step" in text
    assert "set_setup_task_display_material_requirement" in text
    assert text.count("GRANT EXECUTE ON FUNCTION") >= 2
    assert "TO fieldwiring_app" in text
    assert "Issue #141" in text
    assert "like '%setup%'" not in text.lower()


def test_material_api_is_syntax_valid_and_stage_resolution_is_not_preview_bounded() -> None:
    path = APP / "setup_material_api.py"
    text = path.read_text(encoding="utf-8")
    ast.parse(text)

    start = text.index("def _stage_remainder_scene_ids")
    end = text.index("def _scope_relationships")
    stage_resolver = text[start:end]
    assert "WHERE ls.stage_id = %s" in stage_resolver
    assert "resolve_structured_scope" in stage_resolver
    assert "preview_uuid = %s" not in stage_resolver
    assert "ref.lor_scene_display" in text
    assert "child.lor_scene_id = ANY(%s)" in text
    assert "ref.setup_task_display" in text
    assert "is_display_setup_step" in text
    assert "ref.set_setup_task_display_setup_step" in text
    assert "ref.set_setup_task_display_material_requirement" in text


def test_stage_remainder_fails_closed_instead_of_returning_partial_material() -> None:
    text = (APP / "setup_material_api.py").read_text(encoding="utf-8")
    assert "refused a partial Stage list" in text
    assert "if unresolved:" in text
    assert "more-specific current LOR scopes" in text


def test_display_setup_color_is_separate_from_whole_scope_material_switch() -> None:
    js = (APP / "setup_material.js").read_text(encoding="utf-8")
    css = (APP / "setup_material.css").read_text(encoding="utf-8")

    assert "is_display_setup_step" in js
    assert "requires_display_material" in js
    assert "edit-is-display-setup-step" in js
    assert "edit-requires-display-material" in js
    assert "DISPLAY SETUP" in js
    assert "SCOPE MATERIAL" in js
    assert "Use whole Stage/Scene Display material" in js
    assert "material-context" in js
    assert "Issue #141" in js
    assert "if (task.is_display_setup_step)" in js
    assert "if (task.requires_display_material)" in js
    assert "setup-material-task" in js
    assert "setup-scope-material-badge" in js
    assert "--ui-material" in css
    assert "--ui-material-soft" in css
    assert "--ui-material-border" in css
    assert "--ui-material-text" in css


def test_material_metadata_refresh_cannot_turn_successful_write_into_false_failure() -> None:
    js = (APP / "setup_material.js").read_text(encoding="utf-8")
    assert "const result = await setupMaterialBaseReloadTasks(...args);" in js
    assert "try {\n      await loadSetupMaterial({ rerender: false });" in js
    assert "Supplemental metadata failure must never make a successfully completed" in js
    assert "return result;" in js


def test_new_catalog_task_hands_off_to_full_review_editor_after_successful_create() -> None:
    js = (APP / "setup_material.js").read_text(encoding="utf-8")
    assert "setupAddTaskForm?.addEventListener('submit'" in js
    assert "requestedTaskId != null" in js
    assert "showView('review');" in js
    assert "selectTask(Number(requestedTaskId));" in js
    assert "edit-task-name" in js


def test_production_host_exposes_material_api_and_cache_busted_assets() -> None:
    backend = (APP / "production_backend.py").read_text(encoding="utf-8")
    html = (APP / "production.html").read_text(encoding="utf-8")
    assert "from setup_material_api import setup_material_api" in backend
    assert "app.register_blueprint(setup_material_api)" in backend
    assert '"setup_material.css"' in backend
    assert '"setup_material.js"' in backend
    assert "setup_material.css?v=2026-09-10.2" in html
    assert "setup_material.js?v=2026-09-10.2" in html
