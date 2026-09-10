from __future__ import annotations

from pathlib import Path


APP_DIR = Path(__file__).resolve().parent


def test_operational_search_uses_existing_global_search_control() -> None:
    text = (APP_DIR / "setup_operational_search.js").read_text(encoding="utf-8")
    assert "setup-task-search" in text
    assert "setup-task-search-clear" in text
    assert "renderPlanningBacklogWithOperationalSearch" in text
    assert "renderNextExecutionWithOperationalSearch" in text
    assert "next-planning-backlog" in text
    assert "next-perform-list" in text
    assert "next-schedule-task" in text
    assert "setup-stage-order-heading" in text
    assert "setup-stage-scope-heading" in text
    assert "localStorage." not in text
    assert "/api/setup/" not in text
    assert "commandOptions" not in text


def test_operational_search_is_loaded_and_served_by_production_host() -> None:
    html = (APP_DIR / "production.html").read_text(encoding="utf-8")
    backend = (APP_DIR / "production_backend.py").read_text(encoding="utf-8")
    assert "setup_live_review_fixes.js" in html
    assert "setup_operational_search.js" in html
    assert html.index("setup_live_review_fixes.js") < html.index("setup_operational_search.js")
    assert "setup_operational_search.js" in backend

    from production_backend import app

    app.testing = True
    client = app.test_client()
    response = client.get("/setup_operational_search.js")
    assert response.status_code == 200
    assert response.mimetype == "application/javascript"
