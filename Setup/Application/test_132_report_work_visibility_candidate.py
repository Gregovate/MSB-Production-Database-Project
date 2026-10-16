"""#132 / #205: Report Work input clarity regression for the bounded launch fix.

This is a source contract, not substitute for interactive browser acceptance.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def test_report_work_explicit_inputs_and_minutes():
    js = (ROOT / "setup_next_pass.js").read_text(encoding="utf-8")
    start = js.index('<form class="next-completion-form next-report-work-form"')
    end = js.index("${nextCorrectionIntakeMarkup", start)
    form = js[start:end]
    for label in (
        "Date work actually happened",
        "Actual crew size",
        "Hours worked",
        "Minutes worked",
        "Whole task % complete",
        "Save Work Report",
    ):
        assert label in form
    assert 'class="next-duration-minutes"' in form
    assert 'min="0" max="59" step="1"' in form
    assert 'placeholder="0–59" required' in form
    assert 'next-duration-minutes" type="number" min="0" max="59" step="1" value="0"' not in form
    assert "form?.addEventListener('submit', submitNextProgress)" in js


def test_minutes_field_visibly_distinct_and_mobile_usable():
    css = (ROOT / "setup_next_pass.css").read_text(encoding="utf-8")
    assert ".next-report-work-form .next-report-work-grid .next-work-key-field" in css
    assert ".next-report-work-form .next-report-work-grid .next-work-minutes-field" in css
    assert "min-height: 44px" in css
    assert "@media (max-width: 650px)" in css


def test_actual_work_date_is_prominent_and_confirmed_before_submission():
    js = (ROOT / "setup_next_pass.js").read_text(encoding="utf-8")
    css = (ROOT / "setup_next_pass.css").read_text(encoding="utf-8")
    start = js.index('<form class="next-completion-form next-report-work-form"')
    end = js.index("${nextCorrectionIntakeMarkup", start)
    form = js[start:end]
    assert "Date work actually happened" in form
    assert "next-work-date-field" in form
    assert 'data-scheduled-date=' in form
    assert "Scheduled:" in form
    assert "Scheduled assignment date:" in js
    assert ".next-work-date-field" in css
    begin = js.index("async function submitNextProgress(event)")
    finish = js.index("const priorNextPopulateStageSelects", begin)
    handler = js[begin:finish]
    assert "Date work ACTUALLY happened:" in handler
    assert handler.index("if (!performedOn)") < handler.index("window.confirm(")
    assert handler.index("if (percent < 100 && !note)") < handler.index("window.confirm(")
    assert handler.index("window.confirm(") < handler.index("await api(")
    assert "if (!window.confirm(" in handler
    assert "performed_on: performedOn" in handler


def test_manager_existing_report_correction_preserves_original_identity():
    js = (ROOT / "setup_next_pass.js").read_text(encoding="utf-8")
    start = js.index("async function submitNextProgressCorrection(event)")
    end = js.index("async function loadNextTaskExecution", start)
    correct = js[start:end]
    assert "data-progress-id" in js
    assert "const progressId = Number(form.dataset.progressId)" in correct
    assert "performed_on: performedOn" in correct
    assert "commandOptions('PATCH'" in correct
    assert "Save Correction" in js
