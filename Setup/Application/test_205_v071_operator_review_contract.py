"""#205 V0.3.71 browser-rejection safeguards. Source checks do not replace live browser review."""
from pathlib import Path

APP = Path(__file__).parent


def source(name):
    return (APP / name).read_text(encoding="utf-8")


def test_same_captain_move_is_suggestion_not_unconfirmed_write():
    js = source("setup_next_pass.js")
    assert "const nextSameCaptain = originalCaptain" in js
    assert "Number(crew.captain_person_id) === originalCaptain" in js
    assert "nextSameCaptain.crew.setup_work_day_crew_id" in js
    assert "NO WORK WAS PERFORMED" in js
    assert "!assignment.historical_locked" in js
    assert "nextCanRescheduleNoWork(row)" in js


def test_capacity_distinguishes_am_pressure_from_true_overload():
    js = source("setup_scheduling_board.js")
    assert "board205PlacementCrewCount(crewId, 'AFTERNOON')" in js
    assert "AM PRESSURE — REVIEW PM CONTINUATION" in js
    assert "const shiftPressure = shift === 'MORNING' && w.overload > 0" in js
    assert "AM PRESSURE — PM CREW UNCONFIRMED" in js
    assert "PM staffing needs a Manager decision" in js
    assert "PM may absorb" in js
    assert "const dayDemand = am.known + pm.known;" in js


def test_day_and_crew_identity_and_visible_actions():
    css = source("setup_scheduling_board.css")
    js = source("setup_scheduling_board.js")
    perform_css = source("setup_next_pass.css")
    assert 'data-crew-letter="${board205Esc(crew.crew_code)}"' in js
    for crew in ("A", "B", "C", "D"):
        assert f'data-crew-letter="{crew}"' in css
    assert ".setup-board205-day-header { position: sticky;" in css
    assert ".setup-board205-filters { position: static; }" in css
    assert ".setup205-action-center .setup205-action" in perform_css
    assert 'placeholder="Number of volunteers"' in source("setup_next_pass.js")


def test_version_and_asset_pins_change_together():
    html = source("production.html")
    assert "2026-10-16.72" in html
    assert "V0.3.72-planned-crew-corrections" in source("production_backend.py")
    assert "V0.3.72-planned-crew-corrections" in source("setup_catalog_dirty_guard.js")


def test_new_crew_move_preserves_captain_inside_one_guarded_transaction():
    ui = source("setup_next_pass.js")
    api = source("setup_scheduling_board_api.py")
    repo = source("setup_scheduling_board_repository.py")
    assert "captain_person_id: dialog.dataset.preferredCaptain" in ui
    assert 'captain_person_id=nullable_int(payload.get("captain_person_id"), "captain_person_id")' in api
    start = repo.index("def add_crew_with_tasks(")
    end = repo.index("def update_crew(", start)
    atomic = repo[start:end]
    assert "ops.add_setup_work_day_crew" in atomic
    assert "ops.update_setup_work_day_crew" in atomic
    assert "ops.update_setup_work_day_assignment" in atomic
    assert "conn.commit()" in atomic


def test_second_review_never_defaults_to_wrong_captain_and_shows_save_failure():
    perform = source("setup_next_pass.js")
    board = source("setup_scheduling_board.js")
    css = source("setup_next_pass.css")
    assert "if (captainId && !captainCrew)" in perform
    assert "crewSelect.value = 'NEW_CREW';" in perform
    assert "The new-crew route records the original Captain atomically." in perform
    assert "Not saved — " in board
    assert "const reason = String(error?.message" in board
    assert "input?.addEventListener('blur'" in board
    assert ".setup205-kpi-glance .setup205-open-action-center" in css
    assert ".setup205-action-center .setup205-action-group li" in css
