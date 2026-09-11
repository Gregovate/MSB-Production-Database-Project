from __future__ import annotations

import sys
from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
REPO_ROOT = APP_DIR.parents[1]
if str(APP_DIR) not in sys.path:
    sys.path.insert(0, str(APP_DIR))
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))


def test_review_usability_assets_are_loaded_and_served() -> None:
    html = (APP_DIR / "production.html").read_text(encoding="utf-8")
    assert "setup_review_usability.css" in html
    assert "setup_review_usability.js" in html

    from production_backend import app

    app.testing = True
    client = app.test_client()
    assert client.get("/setup_review_usability.css").status_code == 200
    assert client.get("/setup_review_usability.js").status_code == 200


def test_plain_english_manager_help_covers_current_and_next_workflows() -> None:
    text = (APP_DIR / "setup_review_usability.js").read_text(encoding="utf-8")
    for phrase in (
        "How Setup Session Works",
        "Verify 2025",
        "Reusable tasks and Stage sequence",
        "Prerequisites and readiness",
        "Scheduling model coming next",
        "Pick Lists",
        "Movement and scanning",
        "Morning",
        "Afternoon",
        "All Day",
        "parallel crews",
        "multi-day work",
    ):
        assert phrase in text


def test_reusable_catalog_supports_stage_reordering_and_copy() -> None:
    text = (APP_DIR / "setup_review_usability.js").read_text(encoding="utf-8")
    assert "persistSetupStageOrder" in text
    assert "moveSetupLibraryTask" in text
    assert "dragstart" in text
    assert "drop-target" in text
    assert "stage-move-up" in text
    assert "stage-move-down" in text
    assert "copySetupReusableTask" in text
    assert "Prerequisites and annual history will NOT be copied" in text
    assert "api/setup/tasks/${source.setup_task_id}/resources" in text
    assert "api/setup/tasks/${newId}/resources/${resource.setup_resource_id}" in text


def test_reordering_uses_existing_narrow_task_update_boundary() -> None:
    text = (APP_DIR / "setup_review_usability.js").read_text(encoding="utf-8")
    assert "setupTaskUpdatePayload" in text
    assert "commandOptions('PATCH'" in text
    assert "api/setup/tasks/${task.setup_task_id}" in text
    assert "(index + 1) * 10" in text
    assert "localStorage." not in text


def test_preview_copy_never_claims_disposable_writes_are_production() -> None:
    text = (APP_DIR / "setup_review_usability.js").read_text(encoding="utf-8")
    assert "Browser Review — disposable clone." in text
    assert "Production is not being edited." in text
    assert "saved to the disposable review clone" in text
    assert "created in the disposable review clone" in text
