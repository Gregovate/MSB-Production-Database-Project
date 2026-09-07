from __future__ import annotations

from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
DB_DIR = APP_DIR.parent / "Database"


def test_reusable_task_creation_ambiguity_is_corrected() -> None:
    sql = (DB_DIR / "013_fix_setup_task_creation_command.sql").read_text(encoding="utf-8")
    assert "ON CONFLICT ON CONSTRAINT uq_setup_session_task DO NOTHING" in sql
    assert "ON CONFLICT (setup_session_id, setup_task_id)" not in sql
    assert "GRANT EXECUTE ON FUNCTION ref.create_setup_task" in sql


def test_scene_field_context_derives_existing_scene_displays_without_manual_duplication() -> None:
    text = (APP_DIR / "setup_next_repository.py").read_text(encoding="utf-8")
    assert "FROM ref.setup_task_display" in text
    assert "JOIN ref.lor_scene_display" in text
    assert "lsd.lor_scene_id = tc.lor_scene_id" in text
    assert "'SCENE_SCOPE'::text" in text
    assert "relationship_source" in text
    assert "c.description AS container_description" in text
    assert "INSERT INTO ops.setup_movement_event" not in text


def test_setup_owns_narrow_scene_field_context_read_grants() -> None:
    sql = (DB_DIR / "014_grant_setup_scene_field_context_read.sql").read_text(encoding="utf-8")
    for table in ("ref.display", "ref.container", "ref.lor_scene", "ref.lor_scene_display"):
        assert table in sql
    assert "GRANT SELECT ON TABLE" in sql
    assert "GRANT UPDATE" not in sql
    assert "GRANT INSERT" not in sql
    assert "GRANT DELETE" not in sql


def test_reusable_catalog_has_contextual_add_task_workflow() -> None:
    text = (APP_DIR / "setup_acceptance_fixes.js").read_text(encoding="utf-8")
    assert "Add Task Here" in text
    assert "add-scene-id" in text
    assert "acceptanceOpenAddTask" in text
    assert "acceptanceNextSequence" in text
    assert "removeEventListener('submit', createReusableTask)" in text
    assert "api/setup/tasks/${newId}/scope" in text
    assert "lor_scene_id: sceneId" in text


def test_captain_completion_is_compact_and_multi_unit_detail_is_optional() -> None:
    js = (APP_DIR / "setup_acceptance_fixes.js").read_text(encoding="utf-8")
    css = (APP_DIR / "setup_acceptance_fixes.css").read_text(encoding="utf-8")
    assert "Partial / multi-unit progress (optional)" in js
    assert "Entire task complete" in js
    assert "acceptance-complete-check" in js
    assert 'width: 1.55rem' in css
    assert 'height: 1.55rem' in css
    assert "acceptance-completion-actions" in css


def test_scene_material_is_presented_by_container_and_uses_governed_park_root_name() -> None:
    text = (APP_DIR / "setup_acceptance_fixes.js").read_text(encoding="utf-8")
    assert "Container ${escapeHtml(containerId)}" in text
    assert "Display${sceneCount === 1 ? '' : 's'} from current Scene membership" in text
    assert "41 Park Infrastructure-PI" in text
    assert "Display Folders\\\\Site Infrastructure" not in text
