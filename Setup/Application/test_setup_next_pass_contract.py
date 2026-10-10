from __future__ import annotations

from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
DB_DIR = APP_DIR.parent / "Database"


def test_scope_schedule_execution_migration_has_governed_boundaries() -> None:
    sql = (DB_DIR / "009_create_setup_scope_schedule_execution_commands.sql").read_text(encoding="utf-8")
    assert "ADD COLUMN IF NOT EXISTS lor_scene_id bigint" in sql
    assert "fk_setup_task_scene_stage" in sql
    assert "ref.set_setup_task_scope" in sql
    assert "ref.set_setup_task_dependency" in sql
    assert "circular Setup dependency" in sql
    assert "shift_code IN ('MORNING','AFTERNOON','ALL_DAY')" in sql
    assert "ops.upsert_setup_work_day" in sql
    assert "ops.set_setup_work_day_task" in sql
    assert "CREATE TABLE IF NOT EXISTS ops.setup_task_progress" in sql
    assert "ref.setup_execution_actor" in sql
    assert "CAPTAIN','ALTERNATE" in sql
    assert "ops.record_setup_task_progress" in sql
    assert "completion_note" in sql
    assert "completed_by_person_id" in sql
    assert "GRANT EXECUTE ON FUNCTION ops.record_setup_task_progress" in sql
    assert "GRANT UPDATE ON ref.setup_task" not in sql
    assert "GRANT INSERT ON ops.setup_task_progress" not in sql
    assert "TASK_UNLOAD" not in sql  # this migration does not add movement write behavior


def test_review_correction_seed_preserves_confirmed_stage02_and_elf_facts() -> None:
    sql = (DB_DIR / "010_seed_2025_stage02_elf_scope_corrections.sql").read_text(encoding="utf-8")
    assert "02-Mega Tree" in sql
    assert "02-Fred''s Stars" in sql
    assert "Install Fred''s Stars" in sql
    assert "2, 3, NULL" in sql
    assert "No locates required." in sql
    assert "one Boom Lift" in sql
    assert "Install Stage 02 Panels" in sql
    assert "Locates required before panel installation. No lift required." in sql
    assert "one powered stake pounder" in sql
    assert "Short Stake Pounder" in sql
    assert "Tall Stake Pounder" in sql
    assert "Elf Choir scaffold work requires locates first." in sql
    assert "'UNVERIFIED'" in sql


def test_next_pass_browser_has_stage_scene_drag_copy_and_collapsible_groups() -> None:
    text = (APP_DIR / "setup_next_pass.js").read_text(encoding="utf-8")
    assert "api/setup/organization" in text
    assert "next-scope-dropzone" in text
    assert "draggable=" in text
    assert "api/setup/tasks/${taskId}/scope" in text
    assert "Copy Reusable Task" in text
    assert "<label>Destination<select" in text
    assert "<label>Stage area<select" in text
    assert "scrollIntoView" in text
    assert "Stage-level / General" in text
    assert "Scene —" in text
    assert "Expand All" in text
    assert "Collapse All" in text
    assert "stage-gap-list').innerHTML = ''" in text


def test_next_pass_browser_exposes_prerequisite_schedule_and_captain_execution() -> None:
    text = (APP_DIR / "setup_next_pass.js").read_text(encoding="utf-8")
    assert "Add prerequisite" in text
    assert "dependencies/${prereq}" in text
    assert "Schedule" in text
    assert "MORNING" in text
    assert "AFTERNOON" in text
    assert "ALL_DAY" in text
    assert "Perform Work" in text
    assert "api/setup/execution" in text
    assert "api/setup/tasks/${taskId}/field-context" in text
    assert "Published Setup Procedure" in text
    assert "api/setup/tasks/${taskId}/procedure/current" in text
    assert "Crew size" in text
    assert "Completed quantity" in text
    assert "Which units" in text
    assert "What was done / what remains" in text
    assert "next-duration-hours" in text
    assert "next-duration-minutes" in text
    assert "next-percent-complete" in text
    assert "100% completes the annual task" in text
    assert "next-mark-complete" not in text
    assert "api/setup/session-tasks/${sessionTaskId}/progress" in text


def test_next_pass_api_stays_protected() -> None:
    text = (APP_DIR / "setup_next_api.py").read_text(encoding="utf-8")
    assert "require_reader()" in text
    assert "require_manager()" in text
    assert "require_setup_command()" in text
    assert "@setup_next_api.errorhandler(SetupAuthenticationError)" in text
    assert "@setup_next_api.errorhandler(SetupCommandError)" in text
    assert "record_progress" in text
    assert "require_reader()" in text.split("def api_setup_record_progress", 1)[1]


def test_field_context_is_read_only_location_integration_not_movement_simulation() -> None:
    repo = (APP_DIR / "setup_next_repository.py").read_text(encoding="utf-8")
    assert "FROM ref.setup_task_display" in repo
    assert "ops.setup_display_state" in repo
    assert "ops.setup_container_state" in repo
    assert "home_location_code" in repo
    assert "FROM ref.setup_task_container_support" in repo
    assert "INSERT INTO ops.setup_movement_event" not in repo
    assert "UPDATE ops.setup_display_state" not in repo
    assert "UPDATE ops.setup_container_state" not in repo


def test_next_pass_catalog_waits_for_organization_readiness() -> None:
    text = (APP_DIR / "setup_next_pass.js").read_text(encoding="utf-8")
    html = (APP_DIR / "production.html").read_text(encoding="utf-8")

    assert "organizationStatus: 'idle'" in text
    assert "organizationPromise: null" in text
    assert "organizationError: null" in text
    assert "setupNextState.organizationStatus = 'loading';" in text
    assert "setupNextState.organizationStatus = 'ready';" in text
    assert "setupNextState.organizationStatus = 'failed';" in text
    assert "function renderNextLibraryReadiness()" in text
    assert "Loading reusable Catalog organization…" in text
    assert "Reusable Catalog organization could not be loaded." in text
    assert "Retry Catalog Organization" in text
    assert "if (renderNextLibraryReadiness()) return;" in text
    assert "priorNextRenderLibrary" not in text
    assert "if (!setupNextState.scenes.length)" not in text
    assert "if (setupNextState.scenes.length) renderLibrary();" not in text
    assert "setup_next_pass.js?v=2026-10-10.60" in html


def test_perform_work_shows_planned_and_actual_person_hours() -> None:
    text = (APP_DIR / "setup_next_pass.js").read_text(encoding="utf-8")
    assert "nextLaborHoursText" in text
    assert "nextPerformLaborKpis" in text
    assert 'id="next-perform-kpis"' in text
    assert "<span>Planned labor</span>" in text
    assert "<span>Actual labor</span>" in text
    assert "<span>Completed-work variance</span>" in text
    assert "Est. labor" in text
    assert "person-hour" in text
    assert "Labor " in text
    assert "nextPerformPlannedCrew" in text
    assert "nextPerformCaptainScopedAssignments" in text
    assert "completedPlannedHours" in text
    assert "completedActualHours" in text
    assert "completedPlannedUnknown" in text
    assert "Completed:" in text
    assert "const labor = nextPerformLaborKpis(scopedAssignments);" in text
    assert "completedCount += 1;" in text
    assert "reported work in Captain scope" in text
    assert "no completed assignments in Captain scope" in text


def test_205_annual_launch_milestones_are_derived_from_season_year_and_visible() -> None:
    next_pass = (APP_DIR / "setup_next_pass.js").read_text(encoding="utf-8")
    board = (APP_DIR / "setup_scheduling_board.js").read_text(encoding="utf-8")
    css = (APP_DIR / "setup_scheduling_board.css").read_text(encoding="utf-8")

    assert "function setupAnnualMilestoneDates(seasonYear)" in next_pass
    assert "firstThursday + 21" in next_pass
    assert "setupComplete.setUTCDate(setupComplete.getUTCDate() - 7)" in next_pass
    assert "foodBankRunWalk.setUTCDate(foodBankRunWalk.getUTCDate() - 5)" in next_pass
    assert "openingNight.setUTCDate(openingNight.getUTCDate() + 1)" in next_pass
    assert "COMPLETE SETUP · VIP SPONSOR NIGHT" in next_pass
    assert "FOOD BANK RUN/WALK" in next_pass
    assert "OPENING NIGHT · BLACK FRIDAY" in next_pass
    assert "window.renderSetupAnnualMilestones = renderSetupAnnualMilestones" in next_pass
    assert 'id="setup-perform-milestones"' in next_pass
    assert "renderSetupAnnualMilestones(document.getElementById('setup-perform-milestones')" in next_pass

    assert 'id="setup-board205-milestones"' in board
    assert "function board205RenderMilestones()" in board
    assert "window.renderSetupAnnualMilestones(target, Number(appState.seasonYear))" in board
    assert "board205RenderMilestones();" in board

    assert ".setup-annual-milestones" in css
    assert ".setup-annual-milestone.primary" in css
    milestones = css.split(".setup-annual-milestones {", 1)[1].split("/* Explicit panel selection", 1)[0]
    assert "display: flex;" in milestones
    assert "border:" not in milestones
    assert "background:" not in milestones
