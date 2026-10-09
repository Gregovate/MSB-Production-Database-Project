"""#205 scheduling workload candidate: source-level browser regression contracts.

These checks run under the existing Python-only Setup test workflow.
They do not replace disposable browser acceptance.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def _read(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")


def test_changed_scheduling_scripts_have_fresh_browser_asset_pins():
    html = _read("production.html")
    assert "setup_next_pass.js?v=2026-10-09.320.2" in html
    assert "setup_scheduling_board.js?v=2026-10-09.320.2" in html


def test_board_workload_banner_stays_inside_shift_cell():
    js = _read("setup_scheduling_board.js")
    start = js.index("function board205Cell(")
    end = js.index("function board205CanRemoveWorkDay(", start)
    cell = js[start:end]
    assert "${board205WorkloadBanner(crew.setup_work_day_crew_id, shift)}" in cell
    start = js.index("function board205Day(")
    end = js.index("function board205RenderBoard(", start)
    day = js[start:end]
    assert "${board205Cell(day, 'MORNING', crew)}" in day
    assert "${board205Cell(day, 'AFTERNOON', crew)}" in day
    assert "${board205WorkloadBanner(crew.setup_work_day_crew_id, 'MORNING')}" not in day


def test_multi_selection_and_drag_drop_handlers_are_preserved():
    js = _read("setup_scheduling_board.js")
    for expected in (
        "event.ctrlKey || event.metaKey",
        "event.shiftKey",
        "selectedAssignmentIds",
        "card.addEventListener('dragstart'",
        "cell.addEventListener('drop'",
        "board205DropToCell(",
        "board205DraggedAssignmentItems(",
    ):
        assert expected in js
    assert "pointer-events:none;position:relative" in js


def test_perform_work_navigation_uses_existing_router_and_day_focus():
    perform = _read("setup_next_pass.js")
    board = _read("setup_scheduling_board.js")
    assert "navigateSetupView('schedule')" in perform
    assert "board205FocusWorkDate(date)" in perform
    assert "function board205FocusWorkDate(" in board
    assert "window.location.assign(url.toString())" not in perform
