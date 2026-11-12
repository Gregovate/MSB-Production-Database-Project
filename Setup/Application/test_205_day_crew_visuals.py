"""#205 visual acceptance contracts: Perform Work day groups and colored scheduling crews."""
from pathlib import Path

APP = Path(__file__).parent


def test_perform_day_is_calendar_group_without_changing_assignment_structure():
    js = (APP / "setup_next_pass.js").read_text(encoding="utf-8")
    css = (APP / "setup_next_pass.css").read_text(encoding="utf-8")
    assert '<section class="next-perform-day">' in js
    assert '<div class="next-perform-day-content"' in js
    assert ".next-perform-day:nth-of-type(odd)" in css
    assert ".next-perform-day:nth-of-type(even)" in css
    assert "border: 3px solid" in css
    assert ".next-perform-day-content { min-width: 0; }" in css


def test_crew_color_extends_across_both_shift_cells():
    js = (APP / "setup_scheduling_board.js").read_text(encoding="utf-8")
    css = (APP / "setup_scheduling_board.css").read_text(encoding="utf-8")
    assert 'class="setup-board205-crew-row' in js
    assert 'data-crew-letter="${board205Esc(crew.crew_code)}"' in js
    for letter in ("A", "B", "C", "D", "E", "F"):
        assert f'.setup-board205-crew-label[data-crew-letter="{letter}"]' in css
        assert f'.setup-board205-crew-row:has(.setup-board205-crew-label[data-crew-letter="{letter}"])' in css
    assert "var(--crew-tint" in css
    assert ".setup-board205-crew-row .setup-board205-cell" in css

def test_crew_letter_is_explicit_on_visible_am_pm_cells():
    js = (APP / "setup_scheduling_board.js").read_text(encoding="utf-8")
    css = (APP / "setup_scheduling_board.css").read_text(encoding="utf-8")
    assert 'data-crew-id="${crew.setup_work_day_crew_id}" data-crew-letter="${board205Esc(crew.crew_code)}"' in js
    for letter in ("A", "B", "C", "D", "E", "F"):
        selector = f'.setup-board205-cell[data-crew-letter="{letter}"]'
        assert selector in css
    assert "background-color:#deebfd" in css
    assert "background-color:#dcf3e8" in css
