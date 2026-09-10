from __future__ import annotations

import ast
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "Application"
DB = ROOT / "Database"
if str(APP) not in sys.path:
    sys.path.insert(0, str(APP))


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


def test_material_api_is_syntax_valid_and_partition_is_database_owned() -> None:
    path = APP / "setup_material_api.py"
    text = path.read_text(encoding="utf-8")
    ast.parse(text)

    start = text.index("def _stage_remainder_scene_ids")
    end = text.index("def _scope_relationships")
    stage_resolver = text[start:end]

    assert "FROM ref.lor_scene AS ls" in stage_resolver
    assert "FROM ref.setup_task AS t" in stage_resolver
    assert "t.active_flag" in stage_resolver
    assert "t.lor_scene_id IS NOT NULL" in stage_resolver
    assert "ls.stage_id = t.stage_id" in stage_resolver
    assert "drive_root" not in text
    assert "resolve_structured_scope" not in text
    assert "BackgroundFile" in text
    assert "ref.lor_scene_display" in text
    assert "child.lor_scene_id = ANY(%s)" in text
    assert "ref.setup_task_display" in text
    assert "is_display_setup_step" in text
    assert "ref.set_setup_task_display_setup_step" in text
    assert "ref.set_setup_task_display_material_requirement" in text


def test_stage01_remainder_uses_setup_scene_scope_not_google_drive_folder() -> None:
    import setup_material_api as material_api

    # These are the current Stage 01 LOR groups. Front Gate is deliberately
    # included even though its documentation does not live in a matching
    # Google Drive Scene folder. Setup scope is expressed by reusable tasks
    # carrying lor_scene_id, not by filesystem layout.
    all_lor_rows = [
        {"lor_scene_id": 253},  # Open-Close Sign
        {"lor_scene_id": 254},  # Making Spirits Bright
        {"lor_scene_id": 263},  # 01-Front Gate
        {"lor_scene_id": 264},  # 01-Entrance Arch
        {"lor_scene_id": 293},  # Goal Sign
        {"lor_scene_id": 467},  # TuneRadio
        {"lor_scene_id": 468},  # RotaryGear
    ]
    scene_scoped_setup_rows = [
        {"lor_scene_id": 263},
        {"lor_scene_id": 264},
    ]

    class FakeCursor:
        def __init__(self):
            self.call = 0

        def execute(self, _sql, _params):
            self.call += 1

        def fetchall(self):
            if self.call == 1:
                return all_lor_rows
            if self.call == 2:
                return scene_scoped_setup_rows
            raise AssertionError(f"Unexpected fetchall call {self.call}")

    remainder, specific, warnings = material_api._stage_remainder_scene_ids(
        FakeCursor(),
        {
            "setup_task_id": 999,
            "stage_id": 1,
            "stage_key": "01",
            "stage_name": "01-Front Entrance-FE",
            "folder_path": r"G:\Shared drives\Display Folders\01-Front Entrance-FE",
        },
    )

    assert remainder == [253, 254, 293, 467, 468]
    assert specific == [263, 264]
    assert warnings == []


def test_stage_remainder_excludes_distinct_active_scene_scopes_only() -> None:
    text = (APP / "setup_material_api.py").read_text(encoding="utf-8")
    assert "excluding LOR Scenes that are represented by active scene-scoped reusable" in text
    assert "Google Drive folders and Procedure paths" in text
    assert "specific_set = set(specific_ids)" in text
    assert "remainder_ids = [scene_id for scene_id in all_scene_ids if scene_id not in specific_set]" in text


def test_display_setup_color_is_separate_from_whole_scope_material_switch() -> None:
    js = (APP / "setup_material.js").read_text(encoding="utf-8")
    css = (APP / "setup_material.css").read_text(encoding="utf-8")
    api = (APP / "setup_material_api.py").read_text(encoding="utf-8")
    migration = (DB / "025_add_setup_display_material_requirement.sql").read_text(encoding="utf-8")

    assert "is_display_setup_step" in js
    assert "requires_display_material" in js
    assert "edit-is-display-setup-step" in js
    assert "edit-requires-display-material" in js
    assert "DISPLAY SETUP" in js
    assert "SCOPE MATERIAL" in js
    assert "Use whole Stage/Scene Display material" in js
    assert "material-context" in js
    assert "Issue #141" in api or "Issue #141" in migration
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
