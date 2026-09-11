from __future__ import annotations

import re
from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
DB_DIR = APP_DIR.parent / "Database"


def read(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def test_predecessor_drag_assets_are_production_loaded_after_normal_drag_engine() -> None:
    html = read("production.html")
    backend = read("production_backend.py")

    for asset in ("setup_predecessor_drag.css", "setup_predecessor_drag.js"):
        assert asset in html
        assert asset in backend

    assert html.index("setup_next_pass.js") < html.index("setup_predecessor_drag.js")


def test_shift_drag_uses_existing_dependency_command_only() -> None:
    js = read("setup_predecessor_drag.js")

    assert "event.shiftKey" in js
    assert "event.stopImmediatePropagation()" in js
    assert "effectAllowed = 'link'" in js
    assert "dropEffect = 'link'" in js
    assert "api/setup/tasks/${dependentTaskId}/dependencies/${prerequisiteTaskId}" in js
    assert "active: true" in js
    assert "dependency_note: null" in js

    # The modifier interaction has exactly one governed API write: dependency upsert.
    # Test executable call names instead of prose substrings so comments such as
    # "row/scope" cannot produce false positives.
    assert js.count("await api(") == 1
    assert "api/setup/tasks/${dependentTaskId}/scope" not in js
    assert "api/setup/tasks/${prerequisiteTaskId}/scope" not in js
    assert "nextMoveTask(" not in js
    assert "nextPersistOrder(" not in js


def test_normal_drag_and_manual_prerequisite_editor_remain_available() -> None:
    normal = read("setup_next_pass.js")
    shift = read("setup_predecessor_drag.js")

    assert "api/setup/tasks/${taskId}/scope" in normal
    assert "event.dataTransfer.dropEffect = 'move'" in normal
    assert "nextMoveTask(sourceId, stageId, sceneId, taskId)" in normal
    assert "Add prerequisite" in normal
    assert "dependencies/${prereq}" in normal

    # Capture listeners only take ownership when dependencyMode is active.
    assert "if (!state.dependencyMode) return;" in shift
    assert "if (!row || !event.shiftKey" in shift


def test_dependency_direction_and_failure_feedback_are_explicit() -> None:
    js = read("setup_predecessor_drag.js")

    assert "is the dependent task" in js
    assert "Prerequisite target" in js
    assert "depends on" in js
    assert "Neither task moved" in js
    assert "setAlert(message, 'error')" in js
    assert "window.alert(message)" in js


def test_dependency_mode_has_distinct_visual_cues_without_new_palette() -> None:
    css = read("setup_predecessor_drag.css")

    for selector in ("dependency-dragging", "dependency-drop-target", "data-dependency-role"):
        assert selector in css
    for token in ("var(--accent)", "var(--accent-soft)", "var(--panel)", "var(--text)", "var(--border)"):
        assert token in css

    assert re.search(r"#[0-9a-fA-F]{3,8}\b", css) is None


def test_database_dependency_command_remains_idempotent_and_cycle_protected() -> None:
    sql = (DB_DIR / "018_fix_setup_dependency_cycle_reference.sql").read_text(encoding="utf-8")

    assert "ref.set_setup_task_dependency" in sql
    assert "A Setup task cannot depend on itself" in sql
    assert "Prerequisite would create a circular Setup dependency" in sql
    assert "ON CONFLICT ON CONSTRAINT pk_setup_task_dependency" in sql
    assert "DO UPDATE SET dependency_note = EXCLUDED.dependency_note" in sql
