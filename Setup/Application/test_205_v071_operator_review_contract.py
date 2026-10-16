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
    assert "const shiftPressure = w.overload > 0 && mayUsePm && !dayOver;" in js
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
    assert "2026-10-16.71" in html
    assert "V0.3.71-operator-review-corrections" in source("production_backend.py")
    assert "V0.3.71-operator-review-corrections" in source("setup_catalog_dirty_guard.js")
