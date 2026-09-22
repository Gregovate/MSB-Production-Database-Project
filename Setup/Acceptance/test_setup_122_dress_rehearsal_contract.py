from __future__ import annotations

from pathlib import Path


ACCEPTANCE_DIR = Path(__file__).resolve().parent
SETUP_DIR = ACCEPTANCE_DIR.parent


def read_acceptance(name: str) -> str:
    return (ACCEPTANCE_DIR / name).read_text(encoding="utf-8")


def read_app(name: str) -> str:
    return (SETUP_DIR / "Application" / name).read_text(encoding="utf-8")


def test_122_rehearsal_seed_starts_without_prebuilt_schedule_or_execution() -> None:
    seed = read_acceptance("setup_122_2026_dress_rehearsal_seed.sql")

    assert "ops.create_setup_session" in seed
    assert "must begin with no prebuilt schedule or progress" in seed
    assert "v_work_day_count <> 0" in seed
    assert "v_assignment_count <> 0" in seed
    assert "v_progress_count <> 0" in seed

    for forbidden in (
        "ops.upsert_setup_work_day(",
        "ops.add_setup_work_day_crew(",
        "ops.create_setup_work_day_assignment(",
        "ops.record_setup_task_progress(",
        "INSERT INTO stage.work_order_intake",
        "INSERT INTO ops.setup_movement_event",
    ):
        assert forbidden not in seed


def test_122_rehearsal_supports_shared_clone_manager_and_crew_personas() -> None:
    runner = read_acceptance("run_setup_disposable_browser_preview.ps1")
    server = read_acceptance("setup_disposable_browser_preview_server.sh")

    assert "CrewPreviewPort" in runner
    assert "CrewPreviewEmail" in runner
    assert "crew_preview_port" in runner
    assert "crew_preview_email" in runner
    assert "CREW_PREVIEW_PORT" in server
    assert "CREW_PREVIEW_EMAIL" in server
    assert "Auto-selected Production Crew preview identity" in server
    assert "role_name = 'Production Crew'" in server
    assert "same disposable clone" in server
    assert "Production Crew scheduling negative path: PASS (403)" in server
    for protected_port in ("8055", "8790", "8792", "8794", "8796"):
        assert protected_port in runner
        assert protected_port in server


def test_122_rehearsal_composes_launch_spine_surfaces() -> None:
    backend = read_app("production_backend.py")
    production = read_app("production.html")
    captain = read_app("setup_captain_work_list.js")
    pick = read_app("setup_pick_list.js")
    report = read_app("setup_next_pass.js")

    assert '@app.get("/captain-work-list")' in backend
    assert '@app.get("/pick-list")' in backend
    assert "setup_material_readiness_api" in backend
    assert "setup_work_order_intake_api" in backend
    assert 'id="captain-work-list-link"' in production
    assert 'id="pick-list-link"' in production
    assert "setup_work_day_task_id=" in captain
    assert "Report Problem / Suggest Change" in captain
    assert "api/setup/material-readiness?season_year=" in pick
    assert "next-duration-hours" in report
    assert "next-duration-minutes" in report
    assert "Work Order Intake for Manager triage" in report


def test_122_rehearsal_never_turns_pick_list_into_movement_write() -> None:
    pick = read_app("setup_pick_list.js")

    for forbidden in (
        "commandOptions(",
        "ops.setup_movement_event",
        "method: 'POST'",
        "method: 'PATCH'",
        "method: 'DELETE'",
    ):
        assert forbidden not in pick
