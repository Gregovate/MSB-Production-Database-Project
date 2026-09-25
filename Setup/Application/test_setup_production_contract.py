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
    for asset in (
        "setup_production.js",
        "setup_resource_review.js",
        "setup_resource_review.css",
        "setup_review_usability.js",
        "setup_next_pass.js",
        "setup_next_pass.css",
        "setup_predecessor_drag.js",
        "setup_predecessor_drag.css",
        "setup_prerequisite_editor.js",
        "setup_prerequisite_editor.css",
        "setup_stage_order.js",
        "setup_stage_order.css",
        "setup_acceptance_fixes.js",
        "setup_acceptance_fixes.css",
        "setup_session_year_guard.js",
        "setup_session_year_guard.css",
        "setup_catalog_dirty_guard.js",
        "setup_task_detail_compact.css",
        "setup_task_detail_compact.js",
        "setup_active_task_context.css",
        "setup_active_task_context.js",
        "setup_display_ownership.css",
        "setup_display_ownership.js",
        "setup_kit_box_assignment.css",
        "setup_kit_box_assignment.js",
    ):
        assert asset in text
    assert "setup.js" not in text
    assert "setup_review_extensions.js" not in text
    assert "setup_instruction_live.js" not in text
    assert "Reset Prototype" not in text
    assert "Simulate Container Scan" not in text


def test_production_client_has_no_browser_local_prototype_state() -> None:
    texts = [
        (APP_DIR / name).read_text(encoding="utf-8")
        for name in (
            "setup_production.js",
            "setup_resource_review.js",
            "setup_next_pass.js",
            "setup_predecessor_drag.js",
            "setup_prerequisite_editor.js",
            "setup_stage_order.js",
            "setup_acceptance_fixes.js",
            "setup_session_year_guard.js",
            "setup_catalog_dirty_guard.js",
            "setup_task_detail_compact.js",
            "setup_active_task_context.js",
            "setup_display_ownership.js",
            "setup_kit_box_assignment.js",
        )
    ]
    for text in texts:
        assert "msb.setup.prototype" not in text
    assert "localStorage." not in texts[0]
    assert "localStorage." not in texts[-1]
    assert "X-MSB-Setup-Command" in texts[0]
    assert "api/setup/tasks" in texts[0]
    assert "api/setup/resources" in texts[1]
    assert "api/setup/organization" in texts[2]
    assert "api/setup/schedule" in texts[2]
    assert "api/setup/execution" in texts[2]
    assert "dependencies/${prerequisiteTaskId}" in texts[3]
    assert "api/setup/dependencies/ordered" in texts[4]
    assert "dependencies/order" in texts[4]
    assert "display-ownership" in texts[-2]
    assert "kit-boxes" in texts[-1]


def test_122_real_planning_season_hides_historical_verification_surface() -> None:
    production = (APP_DIR / "setup_production.js").read_text(encoding="utf-8")

    assert "function applySeasonReviewSurface()" in production
    assert "reviewTab.hidden = !historical" in production
    assert "summary.hidden = !historical" in production
    assert "season.session_status !== 'HISTORICAL_VERIFICATION'" in production
    assert "name = el('schedule-view') ? 'schedule' : 'library';" in production

    chooser = production.split("function chooseInitialSeason()", 1)[1].split(
        "function consumePendingCorrection", 1
    )[0]
    assert "const activeSeason = appState.seasons.find((season) => season.active_flag);" in chooser
    assert chooser.index("activeSeason") < chooser.index("historical")
    assert "activeWithSession" not in chooser


def test_large_setup_json_can_be_gzip_compressed() -> None:
    import gzip
    import json

    import production_backend

    payload = json.dumps({"tasks": [{"task_name": "Locate Power and Network", "notes": "x" * 200}] * 200})
    with production_backend.app.test_request_context(
        "/api/setup/scheduling-board",
        headers={"Accept-Encoding": "gzip"},
    ):
        response = production_backend.app.response_class(payload, mimetype="application/json")
        compressed = production_backend._setup_maybe_gzip_json(response)

    assert compressed.headers["Content-Encoding"] == "gzip"
    assert "Accept-Encoding" in compressed.headers["Vary"]
    assert len(compressed.get_data()) < len(payload.encode("utf-8"))
    assert gzip.decompress(compressed.get_data()).decode("utf-8") == payload


def test_small_or_unadvertised_setup_json_is_not_forced_to_gzip() -> None:
    import production_backend

    with production_backend.app.test_request_context("/api/setup/access"):
        response = production_backend.app.response_class('{"ok":true}', mimetype="application/json")
        unchanged = production_backend._setup_maybe_gzip_json(response)

    assert "Content-Encoding" not in unchanged.headers


def test_122_setup_startup_waits_for_full_script_graph_and_uses_real_theme_logo() -> None:
    html = (APP_DIR / "production.html").read_text(encoding="utf-8")
    production = (APP_DIR / "setup_production.js").read_text(encoding="utf-8")
    theme = (APP_DIR / "setup_theme.js").read_text(encoding="utf-8")
    theme_css = (APP_DIR / "setup_theme.css").read_text(encoding="utf-8")
    base_css = (APP_DIR / "setup.css").read_text(encoding="utf-8")

    assert '<body class="setup-booting" aria-busy="true">' in html
    assert 'id="screen-logo"' in html
    assert "window.addEventListener('DOMContentLoaded'" in production
    assert "void initialize();" in production
    assert "document.body.classList.remove('setup-booting')" in production
    assert "document.body.setAttribute('aria-busy', 'false')" in production
    assert "initialize();\n" not in production.split("window.addEventListener('DOMContentLoaded'", 1)[0][-50:]
    assert "msb-white-logo-600-plain.svg" in theme
    assert "msb-blue-logo-600-plain.svg" in theme
    assert "setupSyncThemeLogo()" in theme
    assert "filter: brightness" not in theme_css
    assert "body.setup-booting main" in base_css


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
    assert payload["version"] == "V0.3.17-performance-trace"
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
        "/setup_predecessor_drag.css",
        "/setup_predecessor_drag.js",
        "/setup_prerequisite_editor.css",
        "/setup_prerequisite_editor.js",
        "/setup_stage_order.css",
        "/setup_stage_order.js",
        "/setup_acceptance_fixes.css",
        "/setup_acceptance_fixes.js",
        "/setup_session_year_guard.css",
        "/setup_session_year_guard.js",
        "/setup_catalog_dirty_guard.js",
        "/setup_task_detail_compact.css",
        "/setup_task_detail_compact.js",
        "/setup_active_task_context.css",
        "/setup_active_task_context.js",
        "/setup_display_ownership.css",
        "/setup_display_ownership.js",
        "/setup_kit_box_assignment.css",
        "/setup_kit_box_assignment.js",
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
        "/setup_display_ownership.py",
        "/setup_display_ownership_api.py",
        "/setup_assignment_layer.py",
        "/setup_assignment_api.py",
        "/setup_material_audit_api.py",
        "/setup_material_audit_repository.py",
        "/setup_prerequisite_order_api.py",
        "/setup_prerequisite_order_repository.py",
        "/setup_operations_repository.py",
        "/requirements.txt",
    ):
        assert client.get(forbidden).status_code == 404

    assert client.get("/api/setup-instructions?stage_key=04").status_code == 404
    assert client.get("/api/setup/access").status_code == 401
    assert client.get("/api/setup/resources").status_code == 401
    assert client.get("/api/setup/resource-catalog").status_code == 401
    assert client.get("/api/setup/organization").status_code == 401
    assert client.get("/api/setup/dependencies/ordered").status_code == 401

    audit_page = client.get("/material-audit/")
    assert audit_page.status_code == 200
    assert b"Material Completeness Audit" in audit_page.data
    assert audit_page.headers["Cache-Control"] == "no-store, max-age=0"
    assert client.get("/material-audit/assets/setup_material_audit.css").status_code == 200
    assert client.get("/material-audit/assets/setup_material_audit.js").status_code == 200
    assert client.get("/api/setup/material-audit").status_code == 401


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
        "/api/setup/resource-catalog",
        "/api/setup/resources/<int:setup_resource_id>",
        "/api/setup/tasks/<int:setup_task_id>/resources",
        "/api/setup/tasks/<int:setup_task_id>/resources/<int:setup_resource_id>",
        "/api/setup/organization",
        "/api/setup/tasks/<int:setup_task_id>/scope",
        "/api/setup/tasks/<int:setup_task_id>/dependencies/<int:prerequisite_setup_task_id>",
        "/api/setup/dependencies/ordered",
        "/api/setup/tasks/<int:setup_task_id>/dependencies/order",
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
        "/api/setup/tasks/<int:setup_task_id>/display-ownership/initialize",
        "/api/setup/tasks/<int:context_setup_task_id>/display-ownership/<int:display_id>",
        "/api/setup/tasks/<int:setup_task_id>/kit-boxes",
        "/api/setup/tasks/<int:setup_task_id>/kit-boxes/<int:container_id>",
        "/api/setup/material-audit",
        "/api/setup/material-audit/kits/<int:container_id>/shared-non-task",
    ):
        assert expected in rules


def test_setup_navigation_uses_browser_history_inside_shared_app() -> None:
    production = (APP_DIR / "setup_production.js").read_text(encoding="utf-8")
    next_pass = (APP_DIR / "setup_next_pass.js").read_text(encoding="utf-8")
    html = (APP_DIR / "production.html").read_text(encoding="utf-8")

    assert "function setupCommitCurrentRouteState()" in production
    assert "window.history.replaceState" in production
    assert "window.history.pushState" in production
    assert "window.addEventListener('popstate'" in production
    assert "setupMayLeaveCurrentView" in production
    assert "typeof board205Load === 'function'" in production
    assert "await board205Load();" in production
    schedule_route = production.split("if (view === 'schedule') {", 1)[1].split(
        "} else if (view === 'perform'", 1
    )[0]
    assert "else if (typeof loadNextSchedule === 'function')" not in schedule_route
    assert "await loadNextSchedule();" not in schedule_route
    assert "if (!appState.access?.can_read_setup)" in production
    assert "msbSetupHasDirtyEdits" in production
    assert "setupPopstateUndo" in production
    assert "setupPopstateReplay" in production
    assert "window.history.go(-delta)" in production
    assert "window.history.go(pending.delta)" in production
    assert "['review', 'library', 'extra-materials', 'movement', 'schedule', 'perform']" in production
    assert "navigateSetupView(button.dataset.view)" in production
    assert "navigateSetupView('schedule')" in next_pass
    assert "navigateSetupView('perform')" in next_pass
    assert "setup_production.js?v=2026-09-24.8" in html
    assert "setup_next_pass.js?v=2026-09-24.1" in html
    assert "setup_scheduling_board.js?v=2026-09-25.4" in html

