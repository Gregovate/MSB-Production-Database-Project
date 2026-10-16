"""#205: planned crew sizes stay editable; actual assignments and Captain history stay protected.

Source contracts run in normal Setup regression. Disposable SQL separately exercises
the real PostgreSQL function and performs rollback on the current-Production clone.
"""
from pathlib import Path

APP = Path(__file__).parent
ROOT = APP.parent


def read(path):
    return path.read_text(encoding="utf-8")


def test_migration_is_bounded_function_replacement():
    sql = read(ROOT / "Database/075_allow_setup_planned_crew_count_corrections.sql")
    assert "BEGIN;" in sql and "COMMIT;" in sql
    assert "CREATE OR REPLACE FUNCTION ops.update_setup_work_day_crew(" in sql
    assert "SECURITY DEFINER" in sql
    assert "ref.setup_management_actor(p_email, false)" in sql
    assert "Planned shift crew count cannot be negative" in sql
    assert "Selected Crew Captain must be an active person" in sql
    assert "p_am_planned_crew_count IS DISTINCT FROM v_current_am" not in sql
    assert "p_pm_planned_crew_count IS DISTINCT FROM v_current_pm" not in sql
    assert "IF p_captain_person_id IS DISTINCT FROM v_current_captain" in sql
    assert "Actual work exists for this crew; preserve the Crew Captain as history" in sql
    assert "GRANT EXECUTE ON FUNCTION ops.update_setup_work_day_crew" in sql
    assert "REVOKE ALL ON FUNCTION ops.update_setup_work_day_crew" in sql
    assert "UPDATE ops.setup_work_day_crew c" in sql
    assert "UPDATE ops.setup_work_day_task" not in sql
    assert "UPDATE ops.setup_task_progress" not in sql
    assert "DELETE FROM ops.setup_task_progress" not in sql


def test_disposable_crew22_reproduction_has_explicit_rollback():
    validation = read(ROOT / "Acceptance/setup_205_planned_crew_count_disposable_validation.sql")
    assert "Crew 22" in validation
    assert "WHERE setup_work_day_crew_id = 22" in validation
    assert "actual_crew_count" in validation and "progress_count" in validation
    assert "ops.update_setup_work_day_crew(" in validation
    assert "Historical Captain changed without required lock" in validation
    assert "PASS: Crew 22 AM and PM planning counts updated" in validation
    assert "ROLLBACK;" in validation
    assert "PASS: simulated planning writes fully rolled back" in validation


def test_existing_api_and_frontend_keep_authority_and_failed_save_feedback():
    api = read(APP / "setup_scheduling_board_api.py")
    js = read(APP / "setup_scheduling_board.js")
    repo = read(APP / "setup_scheduling_board_repository.py")
    assert "def api_setup_scheduling_board_crew_update(" in api
    crew_api = api.split("def api_setup_scheduling_board_crew_update(",1)[1].split(
        "@setup_scheduling_board_api.delete",1
    )[0]
    assert "require_setup_command()" in crew_api
    assert "require_manager()" in crew_api
    assert "repo().update_crew(" in crew_api
    assert "ops.update_setup_work_day_crew" in repo
    assert "async function board205SaveCrew(" in js
    assert "commandOptions('PATCH', draft)" in js
    assert "board205CrewSaveMessage(crewNode, 'Not saved — ' + reason, true)" in js
    assert "setup-board205-retry-crew" in js


def test_release_version_and_assets_are_exact():
    backend = read(APP / "production_backend.py")
    client = read(APP / "setup_catalog_dirty_guard.js")
    html = read(APP / "production.html")
    assert 'PRODUCTION_VERSION = "V0.3.84-direct-crew-cells"' in backend
    assert "CLIENT_BUILD = 'V0.3.84-direct-crew-cells'" in client
    for filename in ("setup_scheduling_board.js","setup_scheduling_board.css",
                     "setup_next_pass.js","setup_next_pass.css"):
        assert filename + "?v=2026-10-16.84" in html
    assert "Updated 2026-10-16" in html
