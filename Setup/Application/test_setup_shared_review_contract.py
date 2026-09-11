from __future__ import annotations

from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
REPO_ROOT = APP_DIR.parents[1]


def test_shared_2025_review_is_explicitly_permanent_and_year_bounded() -> None:
    guide = (
        REPO_ROOT
        / "Docs"
        / "02_Production_Database"
        / "02_Operational_SOPs"
        / "Setup"
        / "Setup_Session_Manager_Review_Guide.md"
    ).read_text(encoding="utf-8")
    assert "not disposable test data" in guide.lower()
    assert "2025 Historical Verification" in guide
    assert "accepts 2025 operational dates only" in guide
    assert "Administrator" in guide
    assert "41 Park Infrastructure-PI" in guide
    assert "40-CommandCenter" in guide


def test_production_preflight_blocks_cross_year_existing_data_and_2026_session() -> None:
    sql = (
        REPO_ROOT / "Setup" / "Acceptance" / "setup_v03_production_preflight.sql"
    ).read_text(encoding="utf-8")
    assert "READY_FOR_CONTROLLED_V034_PROMOTION" in sql
    assert "America/Chicago" in sql
    assert "Existing Setup data violates session-year guard" in sql
    assert "WHERE season_year = 2026" in sql
    assert "creates_2026_session" in sql
    assert "false AS creates_2026_session" in sql


def test_production_install_plan_excludes_disposable_seed_012() -> None:
    plan = (
        REPO_ROOT / "Setup" / "Acceptance" / "setup_v034_production_install_plan.md"
    ).read_text(encoding="utf-8")
    assert "skip `012_seed_site_infrastructure_review_tasks.sql`" in plan
    assert "016_seed_command_center_park_infrastructure_production.sql" in plan
    assert "017_enforce_setup_session_year_and_admin_promotion.sql" in plan
    assert "must not" in plan
    assert "create a 2026 Setup Session" in plan
