from __future__ import annotations

from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
SETUP_DIR = APP_DIR.parent
REPO_ROOT = APP_DIR.parents[1]
DB_DIR = SETUP_DIR / "Database"
SITE_SOP = (
    REPO_ROOT
    / "Docs"
    / "00_Project_Overview"
    / "Google_Drive"
    / "operatorSOP"
    / "Create_Site_Infrastructure_Procedure_Folder.md"
)


def test_final_migrations_separate_reusable_baseline_from_annual_order() -> None:
    migration = (DB_DIR / "011_create_setup_planning_order_and_crew_lanes.sql").read_text(encoding="utf-8")
    assert "baseline_plan_order" in migration
    assert "planned_order" in migration
    assert "set_setup_session_task_planned_order" in migration
    assert "promote_setup_session_order_to_baseline" in migration
    assert "one-off year" in migration
    assert "absence from a work day is a normal UNSCHEDULED state" in migration


def test_final_schedule_has_parallel_crew_lanes_without_person_roster() -> None:
    migration = (DB_DIR / "011_create_setup_planning_order_and_crew_lanes.sql").read_text(encoding="utf-8")
    client = (APP_DIR / "setup_next_pass.js").read_text(encoding="utf-8")
    assert "crew_lane" in migration
    assert "Crew A" in client
    assert "Crew B" in client
    assert "Crew C" in client
    assert "MORNING" in client
    assert "AFTERNOON" in client
    assert "ALL_DAY" in client
    assert "individual volunteer" not in client.lower()


def test_planning_screen_is_ordered_backlog_with_visibility_filters() -> None:
    client = (APP_DIR / "setup_next_pass.js").read_text(encoding="utf-8")
    for phrase in (
        "Setup Planning Queue",
        "Unscheduled",
        "Scheduled",
        "In Progress",
        "Completed",
        "ordered backlog",
        "only schedule the next practical few days",
        "Use Current Order as Future Baseline",
        "road construction",
    ):
        assert phrase in client
    assert "persistAnnualPlanningOrder" in client
    assert "planned-order" in client
    assert "promote-baseline" in client


def test_sitewide_scope_is_first_class_and_not_lor_derived() -> None:
    client = (APP_DIR / "setup_next_pass.js").read_text(encoding="utf-8")
    api = (APP_DIR / "setup_next_api.py").read_text(encoding="utf-8")
    seed = (DB_DIR / "012_seed_site_infrastructure_review_tasks.sql").read_text(encoding="utf-8")
    assert "Site-wide / Infrastructure" in client
    assert "no LOR Stage/Scene" in client
    assert 'SITE_INFRASTRUCTURE_FOLDER = "Site Infrastructure"' in api
    assert "stage_id IS NULL" in seed
    for task in (
        "Deliver and Set Up Command Center Trailer",
        "Install WiFi Antenna",
        "Install Gateway and Test Internet Connection",
        "Deploy Hotspots",
        "Remove Street Lights",
        "Convert Street Lights to Show Power",
        "Turn On Site Breakers",
    ):
        assert task in seed
    assert "Larry''s house chimney approximately 800 feet away" in seed
    assert "Boom Lift" in seed


def test_task_procedure_route_resolves_sitewide_stage_or_exact_scene_server_side() -> None:
    api = (APP_DIR / "setup_next_api.py").read_text(encoding="utf-8")
    repo = (APP_DIR / "setup_next_repository.py").read_text(encoding="utf-8")
    assert "/api/setup/tasks/<int:setup_task_id>/procedure" in api
    assert "/api/setup/tasks/<int:setup_task_id>/procedure/current" in api
    assert "resolve_stage_procedure" in api
    assert "scene_uuid" in api
    assert "whole_stage=not scene_scoped" in api
    assert "Site Infrastructure" in api
    assert "MARKER_NAME" in api
    assert "Path(name or \"\").name" in api
    assert "scene_uuid" in repo
    assert "preview_uuid" in repo


def test_site_infrastructure_folder_sop_is_buildable_and_uses_existing_marker_contract() -> None:
    text = SITE_SOP.read_text(encoding="utf-8")
    assert r"G:\Shared drives\Display Folders\Site Infrastructure" in text
    assert "_MSB-DB-Source-Folder_READ-ME-FIRST-AND-DO-NOT-DELETE.txt" in text
    for folder in (
        "Procedures/",
        "Inspection/",
        "Setup/",
        "Archive/",
        "images/",
        "SourceDocs/",
        "Takedown/",
    ):
        assert folder in text
    assert "Do not create an LOR Preview" in text
    assert "Current published field PDFs" in text
    assert "Editable source documents" in text


def test_final_browser_does_not_enable_movement_writes() -> None:
    html = (APP_DIR / "production.html").read_text(encoding="utf-8")
    client = (APP_DIR / "setup_next_pass.js").read_text(encoding="utf-8")
    assert "movement write commands are not installed yet" in html
    assert "Movement/scanning writes remain a separate guarded implementation step" in client
    assert "Simulate Container Scan" not in html
