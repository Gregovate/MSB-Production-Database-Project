from __future__ import annotations

from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
DB_DIR = APP_DIR.parent / "Database"


def test_database_enforces_active_session_year_for_operational_dates() -> None:
    sql = (DB_DIR / "017_enforce_setup_session_year_and_admin_promotion.sql").read_text(encoding="utf-8")
    for token in (
        "trg_setup_work_day_session_year",
        "trg_setup_session_task_operational_year",
        "trg_setup_movement_event_session_year",
        "America/Chicago",
        "work_date",
        "planned_date",
        "actual_started_at",
        "actual_completed_at",
        "occurred_at",
        "must be in active Setup Session year",
    ):
        assert token in sql

    # Recording/audit timestamps deliberately remain real current timestamps.
    assert "recorded_at AT TIME ZONE" not in sql
    assert "created_at AT TIME ZONE" not in sql
    assert "updated_at AT TIME ZONE" not in sql


def test_future_baseline_promotion_is_administrator_only() -> None:
    sql = (DB_DIR / "017_enforce_setup_session_year_and_admin_promotion.sql").read_text(encoding="utf-8")
    api = (APP_DIR / "setup_next_api.py").read_text(encoding="utf-8")
    js = (APP_DIR / "setup_session_year_guard.js").read_text(encoding="utf-8")

    assert "setup_management_actor(p_email, true)" in sql
    promote_block = api.split("def api_setup_promote_baseline", 1)[1].split("@setup_next_api", 1)[0]
    assert "require_admin()" in promote_block
    assert "can_admin_setup" in js
    assert "promote.hidden = !canAdmin" in js


def test_browser_date_inputs_follow_selected_setup_session_year() -> None:
    js = (APP_DIR / "setup_session_year_guard.js").read_text(encoding="utf-8")
    for token in (
        "appState?.seasonYear",
        "input[type=\"date\"]",
        "input[type=\"datetime-local\"]",
        "dateMin",
        "dateMax",
        "This Setup Session only accepts operational dates in",
        "Historical Review / Training",
        "Saved changes are permanent",
        "does not create or schedule a future season",
    ):
        assert token in js


def test_shared_production_entry_loads_year_guard_assets() -> None:
    html = (APP_DIR / "production.html").read_text(encoding="utf-8")
    backend = (APP_DIR / "production_backend.py").read_text(encoding="utf-8")
    assert "setup_session_year_guard.js" in html
    assert "setup_session_year_guard.css" in html
    assert '"setup_session_year_guard.js"' in backend
    assert '"setup_session_year_guard.css"' in backend
