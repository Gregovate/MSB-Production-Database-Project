from __future__ import annotations

import ast
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "Application"
DB = ROOT / "Database"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_corrected_migration_separates_work_scope_from_material_sources() -> None:
    text = read(DB / "026_add_setup_explicit_lor_material_sources.sql")
    assert "is_display_setup_step boolean NOT NULL DEFAULT false" in text
    assert "CREATE TABLE IF NOT EXISTS ref.setup_task_material_source" in text
    assert "LOR_STAGE" in text and "LOR_PREVIEW" in text and "LOR_SCENE" in text
    assert "set_setup_task_material_source" in text
    assert "requires_display_material" not in text
    assert "STAGE_REMAINDER" not in text
    assert "ref.setup_task_display is not changed or repurposed" in text
    assert "No automatic material-source backfill" in text
    assert "Issue #141" in text


def test_rejected_migration_025_is_not_present() -> None:
    assert not (DB / "025_add_setup_display_material_requirement.sql").exists()


def test_material_api_has_no_filesystem_or_scope_inference() -> None:
    text = read(APP / "setup_material_api.py")
    ast.parse(text)
    assert "drive_root" not in text
    assert "resolve_structured_scope" not in text
    assert "STAGE_REMAINDER" not in text
    assert "requires_display_material" not in text
    assert "ref.setup_task_display" not in text
    assert "work_stage_id" in text
    assert "work_lor_scene_id" in text


def test_stage_and_preview_sources_use_current_raw_lor_membership() -> None:
    text = read(APP / "setup_material_api.py")
    assert "lor_snap.v_current_props AS p" in text
    assert "d.lor_prop_id = p.raw_prop_id" in text
    assert "d.stage_id = ANY(%s)" in text
    assert "p.preview_id = ANY(%s)" in text


def test_scene_source_uses_current_reconciled_scene_membership() -> None:
    text = read(APP / "setup_material_api.py")
    assert "FROM ref.lor_scene_display AS lsd" in text
    assert "lsd.lor_scene_id = ANY(%s)" in text


def test_multiple_sources_union_and_containers_derive_from_display() -> None:
    text = read(APP / "setup_material_api.py")
    assert "display_ids: set[int] = set()" in text
    assert text.count("display_ids.update(") == 3
    assert "d.container_id" in text
    assert "container_ids = sorted(" in text
    assert "material_containers" in text


def test_zero_sources_means_none_even_when_work_scope_exists() -> None:
    text = read(APP / "setup_material_api.py")
    assert "if not sources:" in text
    assert "return []" in text
    assert '"mode": "EXPLICIT_LOR_SOURCES" if sources else "NONE"' in text


def test_ui_has_explicit_multi_source_editor_and_no_scope_material_switch() -> None:
    js = read(APP / "setup_material.js")
    css = read(APP / "setup_material.css")
    assert "Display material sources" in js
    assert "Add material source" in js
    assert "No Display material selected." in js
    assert "material-source" in js
    assert "LOR_STAGE" in js and "LOR_PREVIEW" in js and "LOR_SCENE" in js
    assert "Use whole Stage/Scene Display material" not in js
    assert "SCOPE MATERIAL" not in js
    assert "requires_display_material" not in js
    assert "DISPLAY SETUP" in js
    assert "--ui-material" in css


def test_new_catalog_task_hands_off_to_full_editor() -> None:
    js = read(APP / "setup_material.js")
    assert "setupAddTaskForm?.addEventListener('submit'" in js
    assert "requestedTaskId != null" in js
    assert "showView('review');" in js
    assert "selectTask(Number(requestedTaskId));" in js
    assert "edit-task-name" in js


def test_production_host_registers_material_api() -> None:
    backend = read(APP / "production_backend.py")
    html = read(APP / "production.html")
    assert "from setup_material_api import setup_material_api" in backend
    assert "app.register_blueprint(setup_material_api)" in backend
    assert '"setup_material.css"' in backend
    assert '"setup_material.js"' in backend
    assert "setup_material.css?v=2026-09-10.2" in html
    assert "setup_material.js?v=2026-09-10.2" in html
