from __future__ import annotations

from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
DB_DIR = APP_DIR.parent / "Database"


def test_scope_schedule_execution_migration_has_governed_boundaries() -> None:
    sql = (DB_DIR / "009_create_setup_scope_schedule_execution_commands.sql").read_text(encoding="utf-8")
    assert "ADD COLUMN IF NOT EXISTS lor_scene_id bigint" in sql
    assert "fk_setup_task_scene_stage" in sql
    assert "ref.set_setup_task_scope" in sql
    assert "ref.set_setup_task_dependency" in sql
    assert "circular Setup dependency" in sql
    assert "shift_code IN ('MORNING','AFTERNOON','ALL_DAY')" in sql
    assert "ops.upsert_setup_work_day" in sql
    assert "ops.set_setup_work_day_task" in sql
    assert "CREATE TABLE IF NOT EXISTS ops.setup_task_progress" in sql
    assert "ref.setup_execution_actor" in sql
    assert "CAPTAIN','ALTERNATE" in sql
    assert "ops.record_setup_task_progress" in sql
    assert "completion_note" in sql
    assert "completed_by_person_id" in sql
    assert "GRANT EXECUTE ON FUNCTION ops.record_setup_task_progress" in sql
    assert "GRANT UPDATE ON ref.setup_task" not in sql
    assert "GRANT INSERT ON ops.setup_task_progress" not in sql
    assert "TASK_UNLOAD" not in sql  # this migration does not add movement write behavior


def test_review_correction_seed_preserves_confirmed_stage02_and_elf_facts() -> None:
    sql = (DB_DIR / "010_seed_2025_stage02_elf_scope_corrections.sql").read_text(encoding="utf-8")
    assert "02-Mega Tree" in sql
    assert "02-Fred''s Stars" in sql
    assert "Install Fred''s Stars" in sql
    assert "2, 3, NULL" in sql
    assert "No locates required." in sql
    assert "one Boom Lift" in sql
    assert "Install Stage 02 Panels" in sql
    assert "Locates required before panel installation. No lift required." in sql
    assert "one powered stake pounder" in sql
    assert "Short Stake Pounder" in sql
    assert "Tall Stake Pounder" in sql
    assert "Elf Choir scaffold work requires locates first." in sql
    assert "'UNVERIFIED'" in sql


def test_next_pass_browser_has_stage_scene_drag_copy_and_collapsible_groups() -> None:
    text = (APP_DIR / "setup_next_pass.js").read_text(encoding="utf-8")
    assert "api/setup/organization" in text
    assert "next-scope-dropzone" in text
    assert "draggable=" in text
    assert "api/setup/tasks/${taskId}/scope" in text
    assert "Copy Reusable Task" in text
    assert "Destination Stage" in text
    assert "Destination area" in text
    assert "scrollIntoView" in text
    assert "Stage-level / General" in text
    assert "Scene —" in text
    assert "Expand All" in text
    assert "Collapse All" in text
    assert "stage-gap-list').innerHTML = ''" in text


def test_next_pass_browser_exposes_prerequisite_schedule_and_captain_execution() -> None:
    text = (APP_DIR / "setup_next_pass.js").read_text(encoding="utf-8")
    assert "Add prerequisite" in text
    assert "dependencies/${prereq}" in text
    assert "Schedule" in text
    assert "MORNING" in text
    assert "AFTERNOON" in text
    assert "ALL_DAY" in text
    assert "Perform Work" in text
    assert "api/setup/execution" in text
    assert "api/setup/tasks/${taskId}/field-context" in text
    assert "Published Setup Procedure" in text
    assert "api/setup/procedure/current" in text
    assert "Crew size" in text
    assert "Completed quantity" in text
    assert "Which units / what was completed" in text
    assert "Progress / completion note" in text
    assert "Entire task complete" in text
    assert "api/setup/session-tasks/${sessionTaskId}/progress" in text


def test_next_pass_api_stays_protected() -> None:
    text = (APP_DIR / "setup_next_api.py").read_text(encoding="utf-8")
    assert "require_reader()" in text
    assert "require_manager()" in text
    assert "require_setup_command()" in text
    assert "@setup_next_api.errorhandler(SetupAuthenticationError)" in text
    assert "@setup_next_api.errorhandler(SetupCommandError)" in text
    assert "record_progress" in text
    assert "require_reader()" in text.split("def api_setup_record_progress", 1)[1]


def test_field_context_is_read_only_location_integration_not_movement_simulation() -> None:
    repo = (APP_DIR / "setup_next_repository.py").read_text(encoding="utf-8")
    assert "FROM ref.setup_task_display" in repo
    assert "ops.setup_display_state" in repo
    assert "ops.setup_container_state" in repo
    assert "home_location_code" in repo
    assert "FROM ref.setup_task_container_support" in repo
    assert "INSERT INTO ops.setup_movement_event" not in repo
    assert "UPDATE ops.setup_display_state" not in repo
    assert "UPDATE ops.setup_container_state" not in repo
