from __future__ import annotations

from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
REPO_ROOT = APP_DIR.parents[1]


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_park_infrastructure_uses_exact_governed_non_lor_folder() -> None:
    api = read(APP_DIR / "setup_next_api.py")
    assert 'PARK_INFRASTRUCTURE_FOLDER = "41 Park Infrastructure-PI"' in api
    assert 'SITE_INFRASTRUCTURE_FOLDER = "Site Infrastructure"' not in api
    assert 'Path(drive_root()) / PARK_INFRASTRUCTURE_FOLDER' in api
    assert 'scope_type": "SITE_WIDE"' in api


def test_command_center_and_park_infrastructure_scope_boundary_is_seeded_correctly() -> None:
    seed = read(REPO_ROOT / "Setup" / "Database" / "012_seed_site_infrastructure_review_tasks.sql")
    assert "'CC-10', '40'" in seed
    assert "'CC-20', '40'" in seed
    assert "'CC-30', '40'" in seed
    assert "'CC-40', '40'" in seed
    assert "'PI-10', NULL" in seed
    assert "'PI-20', NULL" in seed
    assert "'PI-30', NULL" in seed
    assert "Preview currently has no wired inventory items" in seed
    assert "Stage 40 Command Center" in seed


def test_park_infrastructure_folder_is_documented_as_non_lor_and_sortable() -> None:
    google_readme = read(
        REPO_ROOT / "Docs" / "00_Project_Overview" / "Google_Drive" / "README.md"
    )
    folder_alignment = read(
        REPO_ROOT
        / "Docs"
        / "01_LOR_System"
        / "02_Data_Extraction"
        / "Folder_Alignment"
        / "engineering"
        / "Park_Infrastructure_Non_LOR_Root_2026-09-07.md"
    )
    for text in (google_readme, folder_alignment):
        assert "41 Park Infrastructure-PI" in text
        assert "Stage 41" in text
    assert "40-CommandCenter" in google_readme


def test_final_planning_ui_has_backlog_filters_and_parallel_crew_lanes() -> None:
    js = read(APP_DIR / "setup_next_pass.js")
    for phrase in (
        "Unscheduled",
        "Scheduled",
        "In Progress",
        "Completed",
        "crew_lane",
        "Crew A",
        "Crew B",
        "Crew C",
        "planned_order",
    ):
        assert phrase in js


def test_task_specific_procedure_endpoint_serves_stage_scene_or_park_scope() -> None:
    api = read(APP_DIR / "setup_next_api.py")
    assert '@setup_next_api.get("/api/setup/tasks/<int:setup_task_id>/procedure")' in api
    assert '@setup_next_api.get("/api/setup/tasks/<int:setup_task_id>/procedure/current")' in api
    assert "_stage_scene_current_document(task, name)" in api
    assert "_park_current_document(name)" in api


def test_seed_verification_query_does_not_reference_dropped_temp_map_after_commit() -> None:
    seed = read(REPO_ROOT / "Setup" / "Database" / "012_seed_site_infrastructure_review_tasks.sql")
    after_commit = seed.split("COMMIT;", 1)[1]
    assert "_setup_review_map" not in after_commit
    assert "reusable_notes LIKE '[Setup review seed %'" in after_commit
