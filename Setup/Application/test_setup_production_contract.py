from __future__ import annotations

import sys
from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
REPO_ROOT = APP_DIR.parents[1]
if str(APP_DIR) not in sys.path:
    sys.path.insert(0, str(APP_DIR))
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


def test_production_html_uses_database_client_only() -> None:
    text = (APP_DIR / "production.html").read_text(encoding="utf-8")
    assert "setup_production.js" in text
    assert "setup_resource_review.js" in text
    assert "setup_resource_review.css" in text
    assert "setup_review_usability.js" in text
    assert "setup_next_pass.js" in text
    assert "setup_next_pass.css" in text
    assert "setup_stage_order.js" in text
    assert "setup_stage_order.css" in text
    assert "setup_acceptance_fixes.js" in text
    assert "setup_acceptance_fixes.css" in text
    assert "setup_session_year_guard.js" in text
    assert "setup_session_year_guard.css" in text
    assert "setup_catalog_dirty_guard.js" in text
    assert "setup.js" not in text
    assert "setup_review_extensions.js" not in text
    assert "setup_instruction_live.js" not in text
    assert "Reset Prototype" not in text
    assert "Simulate Container Scan" not in text


def test_production_client_has_no_browser_local_prototype_state() -> None:
    text = (APP_DIR / "setup_production.js").read_text(encoding="utf-8")
    resource_text = (APP_DIR / "setup_resource_review.js").read_text(encoding="utf-8")
    next_text = (APP_DIR / "setup_next_pass.js").read_text(encoding="utf-8")
    stage_order_text = (APP_DIR / "setup_stage_order.js").read_text(encoding="utf-8")
    acceptance_text = (APP_DIR / "setup_acceptance_fixes.js").read_text(encoding="utf-8")
    guard_text = (APP_DIR / "setup_session_year_guard.js").read_text(encoding="utf-8")
    dirty_guard_text = (APP_DIR / "setup_catalog_dirty_guard.js").read_text(encoding="utf-8")
    assert "localStorage." not in text
    assert "localStorage." not in resource_text
    assert "localStorage." not in next_text
    assert "localStorage." not in stage_order_text
    assert "localStorage." not in acceptance_text
    assert "localStorage." not in guard_text
    assert "localStorage." not in dirty_guard_text
    assert "initialTasks" not in text
    assert "msb.setup.prototype" not in text
    assert "X-MSB-Setup-Command" in text
    assert "api/setup/tasks" in text
    assert "api/setup/procedure" in text
    assert "api/setup/resources" in resource_text
    assert "api/setup/organization" in next_text
    assert "api/setup/schedule" in next_text
    assert "api/setup/execution" in next_text
    assert "planned-order" in next_text
    assert "promote-baseline" in next_text


def test_production_runtime_declares_gunicorn() -> None:
    requirements = (APP_DIR / "requirements.txt").read_text(encoding="utf-8")
    assert "gunicorn>=26,<27" in requirements


def test_production_entry_point_serves_shared_ui_and_blocks_prototype_routes() -> None:
    from production_backend import app

    app.testing = True
    client = app.test_client()

    root = client.get("/")
    assert root.status_code == 200
    assert b"Shared Setup planning and verification" in root.data
    assert root.headers["Cache-Control"] == "no-store, max-age=0"
    assert root.headers["Pragma"] == "no-cache"

    health = client.get("/api/health")
    assert health.status_code == 200
    payload = health.get_json()
    assert payload["status"] == "ok"
    assert payload["version"] == "V0.3.7-catalog-dirty-edit-followup"
    assert health.headers["Cache-Control"] == "no-store, max-age=0"

    for asset in (
        "/setup.css",
        "/setup_review_clarity.css",
        "/setup_theme.css",
        "/setup_theme.js",
        "/setup_production.css",
        "/setup_production.js",
        "/setup_resource_review.css",
        "/setup_resource_review.js",
        "/setup_review_usability.css",
        "/setup_review_usability.js",
        "/setup_next_pass.css",
        "/setup_next_pass.js",
        "/setup_stage_order.css",
        "/setup_stage_order.js",
        "/setup_acceptance_fixes.css",
        "/setup_acceptance_fixes.js",
        "/setup_session_year_guard.css",
        "/setup_session_year_guard.js",
        "/setup_catalog_dirty_guard.js",
    ):
        response = client.get(asset)
        assert response.status_code == 200
        assert response.headers["Cache-Control"] == "no-store, max-age=0"

    for forbidden in (
        "/production.html",
        "/index.html",
        "/setup.js",
        "/setup_review_extensions.js",
        "/setup_instruction_live.js",
        "/backend.py",
        "/setup_api.py",
        "/setup_repository.py",
        "/setup_resource_api.py",
        "/setup_resource_repository.py",
        "/setup_next_api.py",
        "/setup_next_repository.py",
        "/setup_operations_repository.py",
        "/requirements.txt",
    ):
        assert client.get(forbidden).status_code == 404

    assert client.get("/api/setup-instructions?stage_key=04").status_code == 404

    assert client.get("/api/setup/access").status_code == 401
    assert client.get("/api/setup/resources").status_code == 401
    assert client.get("/api/setup/organization").status_code == 401


def test_production_entry_point_uses_distinct_flask_app() -> None:
    import backend
    import production_backend

    assert production_backend.app is not backend.app


def test_production_api_contains_protected_read_and_command_surfaces() -> None:
    from production_backend import app

    rules = {rule.rule for rule in app.url_map.iter_rules()}
    for expected in (
        "/api/setup/tasks",
        "/api/setup/movement-summary",
        "/api/setup/procedure",
        "/api/setup/procedure/current",
        "/api/setup/resources",
        "/api/setup/tasks/<int:setup_task_id>/resources",
        "/api/setup/tasks/<int:setup_task_id>/resources/<int:setup_resource_id>",
        "/api/setup/organization",
        "/api/setup/tasks/<int:setup_task_id>/scope",
        "/api/setup/tasks/<int:setup_task_id>/dependencies/<int:prerequisite_setup_task_id>",
        "/api/setup/session-tasks/<int:setup_session_task_id>/planned-order",
        "/api/setup/planning/promote-baseline",
        "/api/setup/schedule",
        "/api/setup/work-days",
        "/api/setup/work-days/<int:setup_work_day_id>/tasks/<int:setup_session_task_id>",
        "/api/setup/execution",
        "/api/setup/session-tasks/<int:setup_session_task_id>/progress",
        "/api/setup/tasks/<int:setup_task_id>/field-context",
        "/api/setup/tasks/<int:setup_task_id>/procedure",
        "/api/setup/tasks/<int:setup_task_id>/procedure/current",
    ):
        assert expected in rules
