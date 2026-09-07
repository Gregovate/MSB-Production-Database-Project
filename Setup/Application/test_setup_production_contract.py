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
    assert "setup.js" not in text
    assert "setup_review_extensions.js" not in text
    assert "setup_instruction_live.js" not in text
    assert "Reset Prototype" not in text
    assert "Simulate Container Scan" not in text


def test_production_client_has_no_browser_local_prototype_state() -> None:
    text = (APP_DIR / "setup_production.js").read_text(encoding="utf-8")
    # Detect actual browser-storage API use without failing on an explanatory
    # comment that merely names localStorage.
    assert "localStorage." not in text
    assert "initialTasks" not in text
    assert "msb.setup.prototype" not in text
    assert "X-MSB-Setup-Command" in text
    assert "api/setup/tasks" in text
    assert "api/setup/procedure" in text


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

    health = client.get("/api/health")
    assert health.status_code == 200
    payload = health.get_json()
    assert payload["status"] == "ok"
    assert payload["version"] == "V0.1.0-production-foundation"

    for asset in (
        "/setup.css",
        "/setup_review_clarity.css",
        "/setup_theme.css",
        "/setup_theme.js",
        "/setup_production.css",
        "/setup_production.js",
    ):
        assert client.get(asset).status_code == 200

    for forbidden in (
        "/production.html",
        "/index.html",
        "/setup.js",
        "/setup_review_extensions.js",
        "/setup_instruction_live.js",
        "/backend.py",
        "/setup_api.py",
        "/setup_repository.py",
        "/requirements.txt",
    ):
        assert client.get(forbidden).status_code == 404

    assert client.get("/api/setup-instructions?stage_key=04").status_code == 404

    no_identity = client.get("/api/setup/access")
    assert no_identity.status_code == 401


def test_production_entry_point_uses_distinct_flask_app() -> None:
    import backend
    import production_backend

    assert production_backend.app is not backend.app


def test_production_api_contains_protected_read_surfaces() -> None:
    from production_backend import app

    rules = {rule.rule for rule in app.url_map.iter_rules()}
    assert "/api/setup/tasks" in rules
    assert "/api/setup/movement-summary" in rules
    assert "/api/setup/procedure" in rules
    assert "/api/setup/procedure/current" in rules
