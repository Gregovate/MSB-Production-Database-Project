from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent


def test_controller_search_exposes_stage_match_context_without_changing_filter():
    html = (BASE_DIR / "controllers.html").read_text(encoding="utf-8")
    script = (BASE_DIR / "controllers_search_context.js").read_text(encoding="utf-8")

    assert 'id="search-context"' in html
    assert 'controllers_search_context.js' in html
    assert 'controllers_search_context.css' in html
    assert 'Stage search match:' in script
    assert 'Stage search matches:' in script
    assert 'stageFilter.options' in script
    assert 'option.value' in script

    # Free-text Stage confirmation is informational only. It must not silently
    # change the explicit Stage/Sub-stage dropdown selected by the operator.
    assert 'stageFilter.value =' not in script
