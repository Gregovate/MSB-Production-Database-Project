from pathlib import Path


ROOT = Path(__file__).resolve().parent
PARSER_DIR = ROOT / "landing" / "parser"
INDEX = PARSER_DIR / "index.html"
RESUME = PARSER_DIR / "parser-reconciliation-resume.js"


def test_parser_page_loads_resume_bridge_after_main_parser_script():
    html = INDEX.read_text(encoding="utf-8")

    main_script = 'parser.js?v=0.6.2.1'
    resume_script = 'parser-reconciliation-resume.js?v=0.6.2.2'

    assert main_script in html
    assert resume_script in html
    assert html.index(main_script) < html.index(resume_script)


def test_resume_bridge_consumes_backend_review_action_and_persisted_run_url():
    source = RESUME.read_text(encoding="utf-8")

    assert '../preflight/api/dashboard' in source
    assert 'action?.kind !== "review"' in source
    assert 'REVIEW_URL.test(reviewUrl)' in source
    assert 'link.href = `../${reviewUrl}`' in source
    assert 'action.label || "Continue reconciliation"' in source
    assert 'refreshButton.replaceWith(link)' in source


def test_resume_bridge_does_not_start_or_mutate_reconciliation():
    source = RESUME.read_text(encoding="utf-8")

    assert 'runs/start' not in source
    assert 'method: "POST"' not in source
    assert 'method: "PUT"' not in source
    assert 'method: "DELETE"' not in source


def test_resume_bridge_rejects_arbitrary_review_urls():
    source = RESUME.read_text(encoding="utf-8")

    assert 'const REVIEW_URL = /^preflight\\/\\?run=\\d+$/' in source


def test_non_review_or_no_action_state_leaves_existing_control_unchanged():
    source = RESUME.read_text(encoding="utf-8")

    assert 'return false;' in source
    assert 'Leave the existing refresh control intact' in source
