from __future__ import annotations

from pathlib import Path


APP_DIR = Path(__file__).resolve().parent


def read_app(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def test_175_captain_work_list_is_served_as_read_only_standalone_surface() -> None:
    backend = read_app("production_backend.py")
    html = read_app("captain_work_list.html")
    ui = read_app("setup_captain_work_list.js")
    css = read_app("setup_captain_work_list.css")

    assert '@app.get("/captain-work-list")' in backend
    assert "captain_work_list.html" in backend
    assert "setup_captain_work_list.css" in backend
    assert "setup_captain_work_list.js" in backend

    for label in (
        "Captain Work List",
        "Season",
        "Work day",
        "Crew / Captain",
        "Email Captain",
    ):
        assert label in html

    for token in (
        "api/setup/scheduling-board?season_year=",
        "api/setup/tasks?season_year=",
        "api/setup/tasks/' + task.setup_task_id + '/procedure",
        "api/setup/tasks/' + task.setup_task_id + '/field-context?season_year=",
        "Can start when",
        "Weather limits",
        "Done when",
        "Expected / planned crew",
        "Expected duration",
        "Hard prerequisites",
        "Equipment / Resources",
        "Important setup notes",
        "Material summary",
        "Procedure",
        "Report Work",
        "Report Problem / Suggest Change",
        "report_problem=1",
        "mailto:",
    ):
        assert token in ui

    assert "commandOptions(" not in ui
    assert "method: 'POST'" not in ui
    assert "method: 'PATCH'" not in ui
    assert "method: 'DELETE'" not in ui
    assert "@media print" in css


def test_175_report_work_deep_link_preserves_season_and_annual_task_identity() -> None:
    captain_ui = read_app("setup_captain_work_list.js")
    production_ui = read_app("setup_production.js")
    perform_ui = read_app("setup_next_pass.js")

    assert "season_year=" in captain_ui
    assert "view=perform&setup_session_task_id=" in captain_ui
    for token in (
        "setup_work_day_id=",
        "setup_work_day_task_id=",
        "shift_code=",
        "crew_id=",
        "crew_code=",
        "work_date=",
    ):
        assert token in captain_ui
    assert "requestedYear" in production_ui
    assert "applyRequestedRouteCaptainDeepLink" in perform_ui
    assert "setup_session_task_id" in perform_ui
    assert "loadNextExecution()" in perform_ui


def test_175_email_link_only_appears_for_assigned_captain_with_email() -> None:
    ui = read_app("setup_captain_work_list.js")

    assert "captain_person_id" in ui
    assert "captain_candidates" in ui
    assert "captain?.email" in ui
    assert "link.hidden = true" in ui
    assert "mailto:" in ui
    assert "crew_id" in ui
    assert "work_date" in ui


def test_175_important_notes_cleanup_is_conservative() -> None:
    ui = read_app("setup_captain_work_list.js")

    assert "cleanImportantNotes" in ui
    assert "Copied from reusable task" in ui
    assert "reusable_notes" in ui
    # The sample removes only known copy boilerplate; it must not broadly erase
    # historical/provenance-looking text that could still contain field knowledge.
    assert "Historical" not in ui.split("function cleanImportantNotes", 1)[1].split("function catalogTask", 1)[0]


def test_175_main_setup_exposes_captain_work_list_entry_point() -> None:
    html = read_app("production.html")
    ui = read_app("setup_production.js")

    assert 'id="captain-work-list-link"' in html
    assert "Captain Work List" in html
    assert "captain-work-list/" in ui
