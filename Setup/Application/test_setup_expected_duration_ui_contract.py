from pathlib import Path


ROOT = Path(__file__).resolve().parent


def read(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")


def test_reusable_expected_duration_editor_uses_hours_and_minute_remainder() -> None:
    html = read("production.html")

    assert 'id="edit-duration-hours" type="number" min="0" step="1"' in html
    assert 'id="edit-duration-minute-remainder" type="number" min="0" max="59" step="1"' in html
    assert 'class="compact-grid four"' in html
    assert "Crew min" in html
    assert "Crew max" in html
    assert "Expected hrs" in html
    assert "Expected mins (0–59)" in html
    assert "edit-duration-minutes" not in html


def test_reusable_expected_duration_loads_and_saves_as_total_minutes() -> None:
    js = read("setup_production.js")

    assert "function setExpectedDurationInputs(value)" in js
    assert "hoursInput.value = Math.floor(totalMinutes / 60);" in js
    assert "minutesInput.value = totalMinutes % 60;" in js
    assert "const totalMinutes = validParts ? (hours * 60) + minutes : 0;" in js
    assert "expected_duration_minutes: readExpectedDurationMinutes({ strict: true })" in js
    assert "if (!hoursText && !minutesText) return null;" in js
    assert "minutes <= 59" in js
    assert "totalMinutes < 1" in js


def test_dirty_guard_compares_combined_expected_duration_to_server_minutes() -> None:
    js = read("setup_catalog_dirty_guard.js")

    assert "'edit-duration-hours'" in js
    assert "'edit-duration-minute-remainder'" in js
    assert "expected_duration_minutes: readExpectedDurationMinutes({ strict: strictDuration })" in js
    assert "reusableFormState({ strictDuration: true })" in js
    assert "edit-duration-minutes" not in js


def test_planning_summary_keeps_missing_null_and_formats_saved_duration_readably() -> None:
    js = read("setup_planning_summary.js")

    assert "if (task.expected_duration_minutes == null) return null;" in js
    assert "const hours = Math.floor(totalMinutes / 60);" in js
    assert "const minutes = totalMinutes % 60;" in js
    assert "return minutes ? `${hours} hr ${minutes} min` : `${hours} hr`;" in js
    assert "duration || 'MISSING'" in js
