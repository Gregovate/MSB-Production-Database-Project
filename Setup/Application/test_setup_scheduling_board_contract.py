from __future__ import annotations

from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
SETUP_DIR = APP_DIR.parent
DB_DIR = SETUP_DIR / "Database"
ACCEPTANCE_DIR = SETUP_DIR / "Acceptance"


def read_app(name: str) -> str:
    return (APP_DIR / name).read_text(encoding="utf-8")


def read_db(name: str) -> str:
    return (DB_DIR / name).read_text(encoding="utf-8")


def read_acceptance(name: str) -> str:
    return (ACCEPTANCE_DIR / name).read_text(encoding="utf-8")


def test_205_migration_separates_reusable_and_season_only_annual_work() -> None:
    sql = read_db("050_add_setup_scheduling_board_foundation.sql")
    for token in (
        "setup_day_number",
        "task_origin",
        "'REUSABLE','SEASON_ONLY'",
        "annual_task_name",
        "annual_stage_id",
        "annual_lor_scene_id",
        "annual_expected_duration_minutes",
        "annual_effort_level",
        "annual_readiness_state",
        "create_setup_season_task",
        "update_setup_annual_task_definition",
    ):
        assert token in sql

    assert "ALTER COLUMN setup_task_id DROP NOT NULL" in sql
    assert "task_origin = 'SEASON_ONLY'" in sql
    assert "INSERT INTO ref.setup_task" not in sql.split(
        "CREATE OR REPLACE FUNCTION ops.create_setup_season_task", 1
    )[1].split("CREATE OR REPLACE FUNCTION ops.update_setup_annual_task_definition", 1)[0]


def test_205_annual_dependencies_can_include_season_only_tasks() -> None:
    sql = read_db("050_add_setup_scheduling_board_foundation.sql")
    assert "CREATE TABLE IF NOT EXISTS ops.setup_session_task_dependency" in sql
    assert "prerequisite_setup_session_task_id" in sql
    assert "REUSABLE_BASELINE" in sql
    assert "ops.set_setup_session_task_dependency" in sql
    assert "Annual prerequisite would create a circular Setup dependency" in sql
    assert "FROM chain c" in sql
    assert "WHERE c.setup_session_task_id = p_setup_session_task_id" in sql


def test_205_work_order_gate_is_a_real_relationship() -> None:
    sql = read_db("050_add_setup_scheduling_board_foundation.sql")
    repo = read_app("setup_scheduling_board_repository.py")
    assert "linked_work_order_id" in sql
    assert "REFERENCES ops.work_order(work_order_id)" in sql
    assert "linked_work_order_gate" in sql
    assert "CREATE OR REPLACE VIEW ops.setup_scheduling_work_order_gate" in sql
    assert "GRANT SELECT ON ops.setup_scheduling_work_order_gate TO fieldwiring_app" in sql
    assert "LEFT JOIN ops.setup_scheduling_work_order_gate wo" in repo
    assert "LEFT JOIN ops.work_order wo" not in repo
    assert "wo.date_completed" in repo
    assert "WAITING_ON_WORK_ORDER" in repo


def test_205_assignment_identity_and_stickiness_are_database_authoritative() -> None:
    sql = read_db("050_add_setup_scheduling_board_foundation.sql")
    for token in (
        "setup_work_day_task_id bigint GENERATED ALWAYS AS IDENTITY",
        "UNIQUE (setup_work_day_id, setup_session_task_id, shift_code)",
        "setup_work_day_crew_id bigint",
        "create_setup_work_day_assignment",
        "update_setup_work_day_assignment",
        "remove_setup_work_day_assignment",
        "Actual work exists for this assignment",
        "historical work cannot be removed",
        "ADD COLUMN IF NOT EXISTS setup_work_day_task_id bigint",
        "FOREIGN KEY (setup_work_day_task_id)",
    ):
        assert token in sql

    assert "crew_lane ~ '^[A-Z]+$'" in sql
    assert "setup_work_day_task_id" in sql.split(
        "CREATE OR REPLACE FUNCTION ops.record_setup_task_progress", 1
    )[1]


def test_205_work_day_crews_are_dynamic_and_shift_specific() -> None:
    sql = read_db("050_add_setup_scheduling_board_foundation.sql")
    api = read_app("setup_scheduling_board_api.py")
    repo = read_app("setup_scheduling_board_repository.py")
    ui = read_app("setup_scheduling_board.js")

    for token in (
        "CREATE TABLE IF NOT EXISTS ops.setup_work_day_crew",
        "crew_number integer NOT NULL",
        "crew_code text NOT NULL",
        "am_planned_crew_count integer",
        "pm_planned_crew_count integer",
        "captain_person_id integer",
        "ops.add_setup_work_day_crew",
        "ops.update_setup_work_day_crew",
        "ops.remove_setup_work_day_crew",
        "ops.setup_crew_code",
    ):
        assert token in sql

    assert "VALUES (v_day_id, 1, 'A')" in sql
    assert "ON CONFLICT ON CONSTRAINT uq_setup_work_day_crew_number DO NOTHING" in sql
    assert "ON CONFLICT (setup_work_day_id, crew_number) DO NOTHING" not in sql
    assert "crew_lane IN ('A','B','C','D')" not in sql
    assert "/api/setup/scheduling-board/work-days/<int:setup_work_day_id>/crews" in api
    assert "/api/setup/scheduling-board/crews/<int:setup_work_day_crew_id>" in api
    assert '"crews": crews' in repo
    assert "+ Add Crew" in ui
    assert "am_planned_crew_count" in ui
    assert "pm_planned_crew_count" in ui
    assert "setup-board205-crew-captain-select" in ui
    assert "preserve the Crew Captain as history" in sql
    assert "preserve the planned AM crew count as history" in sql
    assert "preserve the planned PM crew count as history" in sql


def test_205_work_day_number_is_persisted_and_dow_is_derived() -> None:
    sql = read_db("050_add_setup_scheduling_board_foundation.sql")
    repo = read_app("setup_scheduling_board_repository.py")
    ui = read_app("setup_scheduling_board.js")
    assert "ADD COLUMN IF NOT EXISTS setup_day_number integer" in sql
    assert "UNIQUE (setup_session_id, setup_day_number)" in sql
    assert "upper(to_char(wd.work_date, 'Dy')) AS day_of_week" in repo
    assert "extract(isodow FROM wd.work_date)" in repo
    assert "Day " in ui and "setup_day_number" in ui
    assert "Saturday · typically stronger volunteer turnout" in ui
    assert "Sunday · avoid scheduling unless deliberately needed" in ui
    assert "Setup Day %s is already assigned to %s" in sql
    assert "CREATE OR REPLACE FUNCTION ops.resequence_setup_future_work_days" in sql
    assert "ORDER BY wd.work_date, wd.setup_day_number" in repo
    assert "setup-board205-day-number" not in ui
    assert "Setup Day # is assigned automatically in chronological order." in ui


def test_205_board_uses_dynamic_crews_am_pm_and_accessible_move_controls() -> None:
    ui = read_app("setup_scheduling_board.js")
    css = read_app("setup_scheduling_board.css")

    for phrase in (
        "Crew A",
        "+ Add Crew",
        "MORNING",
        "AFTERNOON",
        "Schedule…",
        "Move…",
        "Remove",
        "Historical actual — locked",
        "Drop work here",
        "Legacy All Day",
    ):
        assert phrase in ui

    assert '<option value="ALL_DAY">All Day</option>' not in ui
    assert "dragstart" in ui
    assert "dragover" in ui
    assert "setup-board205-up" in ui
    assert "setup-board205-down" in ui
    assert "repeat(2, minmax(14rem, 1fr))" in css


def test_205_finder_uses_task_time_minimum_crew_and_effort() -> None:
    sql = read_db("050_add_setup_scheduling_board_foundation.sql")
    repo = read_app("setup_scheduling_board_repository.py")
    ui = read_app("setup_scheduling_board.js")

    assert "annual_effort_level" in sql
    assert "st.annual_effort_level AS effort_level" in repo
    assert "setup-board205-task-search" in ui
    assert "setup-board205-time-filter" in ui
    assert "setup-board205-crew-filter" in ui
    assert "setup-board205-effort-filter" in ui
    assert "setup-board205-time-op" in ui
    assert "setup-board205-crew-op" in ui
    assert 'option value="LTE"' in ui
    assert 'option value="GTE"' in ui
    css = read_app("setup_scheduling_board.css")
    assert "grid-template-columns: 4.5rem minmax(5.5rem, 1fr)" in css
    assert "padding-left: 0.5rem" in css
    assert "padding-right: 1.5rem" in css
    assert "text-align: center" in css
    assert "task.normal_crew_min" in ui
    assert "task.expected_duration_minutes" in ui
    assert "task.effort_level" in ui
    assert "setup-board205-stage-filter" in ui
    assert "setup-board205-scene-filter" in ui
    assert "setup-board205-sort" in ui
    assert "setup-board205-status-ready" in ui
    assert "setup-board205-status-blocked" not in ui
    assert "setup-board205-status-waiting" not in ui
    assert 'placeholder="e.g. locate"' in ui
    assert "task-name search checks all statuses" in ui
    assert "task.stage_name" in ui


def test_205_heavy_work_is_captain_aware_warning_not_prohibition() -> None:
    ui = read_app("setup_scheduling_board.js")
    assert "HEAVY work follows HEAVY work for Captain" in ui
    assert "HEAVY work follows HEAVY work for this crew" in ui
    assert "board205HeavyWarning" in ui
    assert "captain_person_id" in ui
    assert "window.confirm('HEAVY" not in ui


def test_205_am_to_pm_spillover_is_advisory_not_a_third_shift() -> None:
    ui = read_app("setup_scheduling_board.js")
    assert "SETUP_BOARD205_TYPICAL_AM_MINUTES = 180" in ui
    assert "of AM work carries past lunch into PM" in ui
    assert "≈ 9–12" in ui
    assert "after lunch ≈ 1 PM" in ui
    assert '<option value="ALL_DAY">All Day</option>' not in ui


def test_205_readiness_is_annual_state_separate_from_hard_predecessors() -> None:
    sql = read_db("050_add_setup_scheduling_board_foundation.sql")
    repo = read_app("setup_scheduling_board_repository.py")
    api = read_app("setup_scheduling_board_api.py")
    ui = read_app("setup_scheduling_board.js")

    assert "annual_readiness_state" in sql
    assert "annual_readiness_state IN ('READY','NOT_READY')" in sql
    assert "ops.set_setup_annual_task_readiness" in sql
    assert "st.annual_readiness_state = 'NOT_READY'" in repo
    assert "/readiness" in api
    assert "Mark Ready" in ui
    assert "Mark Not Ready" in ui
    assert "Hard predecessor(s)" in ui
    assert "Readiness not met" in ui


def test_205_crew_captain_is_optional_and_can_build_reusable_knowledge() -> None:
    sql = read_db("050_add_setup_scheduling_board_foundation.sql")
    repo = read_app("setup_scheduling_board_repository.py")
    api = read_app("setup_scheduling_board_api.py")
    ui = read_app("setup_scheduling_board.js")

    assert "captain_person_id integer" in sql
    assert "ops.add_setup_crew_captain_to_reusable_task" in sql
    assert "ref.set_setup_task_captain" in sql
    assert "ref.setup_captain_person_list()" in repo
    assert '"captain_candidates": captain_candidates' in repo
    assert "/crew-captain/" in api and "/promote" in api
    assert "setup-board205-crew-captain-select" in ui
    assert "Existing Captains will remain" in ui
    assert "Crew Captain:" in ui


def test_205_scheduler_can_correct_planning_info_before_execution() -> None:
    sql = read_db("050_add_setup_scheduling_board_foundation.sql")
    api = read_app("setup_scheduling_board_api.py")
    ui = read_app("setup_scheduling_board.js")

    assert "ops.update_setup_scheduling_task_planning_info" in sql
    assert "Actual work exists for this annual task; planning information is historical" in sql
    assert "/planning-info" in api
    assert "Edit Planning Info" in ui
    assert "Updates current reusable planning knowledge. Historical 2025 facts are not changed." in ui
    assert "Readiness condition" in ui


def test_122_b1a_pre2026_compact_editor_writes_reusable_catalog_only() -> None:
    ui = read_app("setup_scheduling_board.js")

    assert "board205OpenPlanningInfoDialog(taskId || null, reusableTaskId || null)" in ui
    assert "const reusablePlanning = board205HistoricalReviewMode() && reusableTaskId;" in ui
    assert "api/setup/tasks/${reusableTaskId}" in ui
    assert "api/setup/tasks/${reusableTaskId}/effort" in ui
    assert "Reusable planning information updated." in ui
    assert "setup-board205-open-full-reusable" in ui
    assert "Open Full Reusable Task" in ui

    block = ui.split("const reusablePlanning = board205HistoricalReviewMode() && reusableTaskId;", 1)[1].split(
        "} else {", 1
    )[0]
    assert "season-tasks/" not in block
    assert "annual_" not in block


def test_122_b1a_pre2026_finder_hides_deferred_and_filters_soft_readiness() -> None:
    ui = read_app("setup_scheduling_board.js")

    assert "setup-board205-ready-only" in ui
    assert 'id="setup-board205-ready-only" type="checkbox" checked' in ui
    assert "if (readyOnly && task.readiness_state === 'NOT_READY') return false;" in ui
    assert "setup-board205-status-deferred" not in ui
    assert "DEFERRED: 'setup-board205-status-deferred'" not in ui


def test_205_short_crew_requires_deliberate_confirmation_but_is_not_prohibited() -> None:
    ui = read_app("setup_scheduling_board.js")
    css = read_app("setup_scheduling_board.css")
    assert "SHORT CREW" in ui
    assert "short by" in ui
    assert "setup-board205-short-crew-warning" in ui
    assert ".setup-board205-short-crew-warning" in css
    assert "board205ConfirmPlacement" in ui
    assert "Schedule this task anyway?" in ui


def test_205_browser_fixture_preserves_real_readiness_state() -> None:
    fixture = read_acceptance("setup_205_scheduling_board_browser_fixture.sql")
    assert "SET annual_readiness_state = 'READY'" not in fixture
    assert "Preserve annual readiness exactly as seeded" in fixture


def test_205_scheduled_work_uses_scheduled_bucket_even_when_readiness_is_blocked() -> None:
    repo = read_app("setup_scheduling_board_repository.py")
    scheduled = repo.index("coalesce(sched.unworked_assignment_count, 0) > 0")
    blocked_readiness = repo.index("st.annual_readiness_state = 'NOT_READY'")
    blocked_prereq = repo.index("coalesce(dep.prerequisites_complete, true) IS NOT TRUE")
    assert scheduled < blocked_readiness
    assert scheduled < blocked_prereq
    assert "unworked_assignment_count" in repo


def test_205_rolling_board_hides_resolved_prior_days_by_default() -> None:
    ui = read_app("setup_scheduling_board.js")
    assert "setup-board205-show-history" in ui
    assert "Show prior / completed work days" in ui
    assert "board205PastDayNeedsAttention" in ui
    assert "board205VisibleDays" in ui
    assert "item.historical_locked" in ui
    assert "task.future_assignment_count" in ui


def test_205_scheduler_panes_scroll_independently_with_drag_edge_autoscroll() -> None:
    ui = read_app("setup_scheduling_board.js")
    css = read_app("setup_scheduling_board.css")
    assert "board205AutoScrollPane" in ui
    assert "pane.scrollTop" in ui
    assert ".setup-board205-backlog," in css
    assert ".setup-board205-board {" in css
    assert "overflow-y: auto" in css
    assert "max-height: calc(100vh - 10.5rem)" in css
    assert "overflow-y: visible" in css


def test_205_captain_learning_cancel_wording_preserves_schedule_only() -> None:
    ui = read_app("setup_scheduling_board.js")
    assert "Cancel = Keep the schedule only." in ui
    assert "Cancel = Keep the Crew Captain assignment only." in ui
    assert "Existing Captains will remain." in ui


def test_205_board_exposes_required_candidate_states() -> None:
    repo = read_app("setup_scheduling_board_repository.py")
    ui = read_app("setup_scheduling_board.js")
    for state in (
        "READY_TO_SCHEDULE",
        "BLOCKED",
        "NEEDS_SCHEDULING_AGAIN",
        "SCHEDULED",
        "COMPLETE",
        "WAITING_ON_WORK_ORDER",
    ):
        assert state in repo or state in ui


def test_205_season_task_editor_is_in_annual_plan_not_reusable_catalog() -> None:
    ui = read_app("setup_scheduling_board.js")
    assert "Add Season Task" in ui
    assert "THIS SEASON ONLY" in ui
    assert "It does not enter the Reusable Task Catalog" in ui
    assert "Existing Work Order<select" in ui
    assert "No Work Order" in ui
    assert "Work Order completion satisfies this gate" in ui
    assert "Insert after / prerequisite" in ui
    assert "Block downstream task" in ui
    assert "setup-board205-season-effort" in ui


def test_205_api_uses_governed_manager_commands_for_plan_mutations() -> None:
    api = read_app("setup_scheduling_board_api.py")
    repository = read_app("setup_scheduling_board_repository.py")
    for route in (
        "/api/setup/scheduling-board",
        "/api/setup/scheduling-board/work-days",
        "/api/setup/scheduling-board/assignments",
        "/api/setup/scheduling-board/work-days/<int:setup_work_day_id>/crews",
        "/api/setup/scheduling-board/crews/<int:setup_work_day_crew_id>",
        "/api/setup/scheduling-board/season-tasks",
        "/api/setup/scheduling-board/season-tasks/<int:setup_session_task_id>/readiness",
        "/api/setup/scheduling-board/season-tasks/<int:setup_session_task_id>/planning-info",
        "/api/setup/scheduling-board/season-tasks/<int:setup_session_task_id>/crew-captain/",
    ):
        assert route in api
    assert "require_reader()" in api
    assert "require_manager()" in api
    assert "require_setup_command()" in api
    assert "INSERT INTO ops.setup_work_day" not in repository
    assert "UPDATE ops.setup_work_day_task" not in repository
    assert "DELETE FROM ops.setup_work_day_task" not in repository


def test_205_work_day_form_survives_async_submit() -> None:
    ui = read_app("setup_scheduling_board.js")
    block = ui.split("async function board205AddWorkDay(event)", 1)[1].split(
        "function board205OpenSeasonTaskDialog", 1
    )[0]
    assert "const form = event.currentTarget;" in block
    assert "form.reset();" in block
    assert "event.currentTarget.reset();" not in block


def test_205_scheduling_board_javascript_has_no_stray_async_prefixes() -> None:
    ui = read_app("setup_scheduling_board.js")
    assert "\nasync \nasync function " not in ui
    assert "board205InstallView();" in ui
    assert "Setup Scheduling Board" in ui


def test_205_production_host_registers_board_without_replacing_report_work() -> None:
    host = read_app("production_backend.py")
    html = read_app("production.html")
    assert "setup_scheduling_board_api" in host
    assert "app.register_blueprint(setup_scheduling_board_api)" in host
    assert '"setup_scheduling_board.css"' in host
    assert '"setup_scheduling_board.js"' in host
    assert "setup_scheduling_board.css?v=2026-09-23.4" in html
    assert "setup_scheduling_board.js?v=2026-09-24.1" in html
    assert "\\n<script src=\"setup_scheduling_board.js" not in html
    assert "\\n  <link rel=\"stylesheet\" href=\"setup_scheduling_board.css" not in html
    assert "setup_next_pass.js" in html


def test_122_b1a_pre2026_current_catalog_allows_planning_edits_but_blocks_actual_scheduling() -> None:
    ui = read_app("setup_scheduling_board.js")

    assert "function board205HistoricalReviewMode()" in ui
    assert "HISTORICAL_VERIFICATION" in ui
    assert "const canScheduleDays = Boolean(session) && canManage && !historicalReview;" in ui
    assert "dayForm.hidden = !canScheduleDays" in ui
    assert "boardPane.hidden = historicalReview" in ui
    assert "Current Reusable Task Finder — Pre-2026 Planning" in ui
    assert "Pre-2026 planning — current reusable Catalog." in ui

    # Pre-2026 planning edits durable reusable knowledge. Annual readiness and
    # season-task actions remain suppressed until a real annual Session exists.
    assert "setup-board205-edit-planning-info" in ui
    assert "canManage && !historicalReview && !task.catalog_only && task.readiness_note" in ui
    assert "canManage && !historicalReview && seasonOnly" in ui
    assert "setup-board205-plan-up" not in ui
    assert "setup-board205-plan-down" not in ui


def test_122_b1a_finder_has_stage_scene_sort_and_search_across_statuses() -> None:
    ui = read_app("setup_scheduling_board.js")

    for token in (
        "setup-board205-stage-filter",
        "setup-board205-scene-filter",
        "setup-board205-sort",
        "setup-board205-status-ready",
        "setup-board205-status-scheduled",
        "setup-board205-status-complete",
        "setup-board205-ready-only",
        "setup-board205-finder-summary",
        "board205SyncFinderSceneOptions",
        "board205FinderCompare",
    ):
        assert token in ui

    # A nonblank Task-name search bypasses ordinary status checkboxes. Blocking
    # ON hides only hard blockers; readiness remains visible for judgement.
    assert "if (board205BlockingEnabled() && hardBlocked) return false;" in ui
    assert "if (!search && !hardBlocked && !statuses.has(family)) return false;" in ui
    assert "task-name search checks all statuses" in ui
    assert "const taskName = String(task.task_name || '').toLowerCase();" in ui
    assert "if (!taskName.includes(search)) return false;" in ui
    assert 'placeholder="e.g. locate"' in ui


def test_122_b1a_finder_explains_blocker_classes() -> None:
    ui = read_app("setup_scheduling_board.js")

    assert "function board205BlockerDetails(task, deps)" in ui
    assert "Hard predecessor" in ui
    assert "Readiness condition · soft" in ui
    assert "Work Order gate" in ui
    assert "Complete first:" in ui
    assert "keep visible for operator judgement; mark Ready when the condition is actually met." in ui
    assert "clear when that Work Order is completed." in ui


def test_122_b1a_blocking_toggle_hides_only_hard_blockers() -> None:
    ui = read_app("setup_scheduling_board.js")

    assert "setup-board205-blocking-toggle" in ui
    assert "Blocking ON" in ui
    assert "Blocking OFF" in ui
    assert "function board205HasHardBlock(task)" in ui
    assert "task.prerequisites_complete === false" in ui
    assert "return task.prerequisites_complete === false;" in ui
    assert "WAITING_ON_WORK_ORDER' && task?.linked_work_order_gate" in ui
    assert "function board205ReadinessOnly(task)" in ui
    assert "if (board205BlockingEnabled() && hardBlocked) return false;" in ui
    assert "hard blockers hidden" in ui
    assert "hard-blocked work included" in ui
    assert "Readiness stays a soft blocker" in ui
    assert "Ready only" in ui
    assert "BLOCKING IGNORED FOR PLANNING" not in ui

    # Finder toggle remains non-mutating.
    toggle_section = ui.split("function board205BlockingEnabled()", 1)[1].split(
        "function board205FinderStageRows()", 1
    )[0]
    assert "api(" not in toggle_section
    assert "commandOptions(" not in toggle_section

def test_122_b1a_stage_sort_puts_numbered_stages_before_site_wide() -> None:
    ui = read_app("setup_scheduling_board.js")

    assert "const aSiteWide = a.stage_id == null ? 1 : 0;" in ui
    assert "const bSiteWide = b.stage_id == null ? 1 : 0;" in ui
    assert "if (aSiteWide !== bSiteWide) return aSiteWide - bSiteWide;" in ui
    assert "const aSceneLevel = a.lor_scene_id == null ? 0 : 1;" in ui
    assert "const bSceneLevel = b.lor_scene_id == null ? 0 : 1;" in ui


def test_122_b1a_task_search_is_name_only_not_resource_or_blocker_text() -> None:
    ui = read_app("setup_scheduling_board.js")

    queue = ui.split("function board205QueueTasks()", 1)[1].split(
        "function board205RenderQueue()", 1
    )[0]

    assert "task.task_name" in queue
    assert "task.resource_summary" not in queue
    assert "task.readiness_note" not in queue
    assert "prerequisite_task_name" not in queue
    assert "linked_work_order_id" not in queue


def test_122_b1a_finder_shows_and_edits_reusable_notes() -> None:
    repo = read_app("setup_scheduling_board_repository.py")
    api = read_app("setup_scheduling_board_api.py")
    ui = read_app("setup_scheduling_board.js")

    assert "rt.reusable_notes" in repo
    assert "task.reusable_notes" in ui
    assert "Reusable notes:" in ui
    assert "setup-board205-planning-reusable-notes" in ui
    assert "reusable_notes: document.getElementById('setup-board205-planning-reusable-notes')" in ui
    assert 'reusable_notes=optional_text(payload.get("reusable_notes"))' in api
    assert "reusable_notes: str | None" in repo
    assert "SELECT * FROM ref.update_setup_task(" in repo
    assert "Reusable Notes update returned no result" in repo


def test_122_b1a_finder_does_not_duplicate_annual_order_controls() -> None:
    ui = read_app("setup_scheduling_board.js")
    next_pass = read_app("setup_next_pass.js")

    assert "setup-board205-plan-up" not in ui
    assert "setup-board205-plan-down" not in ui
    assert "board205MoveAnnualOrder" not in ui
    assert "Setup Planning Queue" in next_pass
    assert "persistAnnualPlanningOrder" in next_pass


def test_122_b1a_finder_uses_current_reusable_prerequisites() -> None:
    repo = read_app("setup_scheduling_board_repository.py")

    # Reusable tasks must follow the current Catalog prerequisite graph, not a
    # stale REUSABLE_BASELINE copy captured in the 2025 annual snapshot.
    assert "FROM ref.setup_task_dependency rd" in repo
    assert "st.task_origin = 'REUSABLE'" in repo
    assert "'REUSABLE_CURRENT'::text AS dependency_origin" in repo
    assert "Ignore stale REUSABLE_BASELINE copies for reusable tasks." in repo

    # Season-only / explicit annual edges remain supported separately.
    assert "st.task_origin = 'SEASON_ONLY'" in repo
    assert "ad.dependency_origin = 'ANNUAL'" in repo


def test_122_b1a_finder_filters_stay_visible_while_results_scroll() -> None:
    css = read_app("setup_scheduling_board.css")

    block = css.split(".setup-board205-filters {", 1)[1].split("}", 1)[0]
    assert "position: sticky" in block
    assert "top: 0" in block
    assert "z-index: 4" in block


def test_122_b1a_reusable_task_audit_is_visible() -> None:
    scheduling_repo = read_app("setup_scheduling_board_repository.py")
    base_repo = read_app("setup_repository.py")
    ui = read_app("setup_scheduling_board.js")
    production = read_app("setup_production.js")
    html = read_app("production.html")

    for source in (scheduling_repo, base_repo):
        assert "created_by_person_id" in source
        assert "updated_by_person_id" in source
        assert "reusable_created_at" in source
        assert "reusable_created_by_display" in source
        assert "reusable_updated_at" in source
        assert "reusable_updated_by_display" in source
        assert "LEFT JOIN ref.person created_actor" in source
        assert "LEFT JOIN ref.person updated_actor" in source

    assert "function board205AuditLine(task)" in ui
    assert "<strong>Audit:</strong>" in ui
    assert "reusable-task-audit" in html
    assert "Created ${createdAt} by ${createdBy} · Last updated ${updatedAt} by ${updatedBy}" in production
    assert "setup_production.js?v=2026-09-24.1" in html


def test_122_b1a_historical_overlay_preserves_fresh_board_audit_after_write() -> None:
    ui = read_app("setup_scheduling_board.js")

    overlay = ui.split("function board205ApplyHistoricalCatalogOverlay()", 1)[1].split(
        "function board205TaskCard(task)", 1
    )[0]

    # board205Load() fetches a fresh Scheduling Board row after governed writes.
    # Historical Verification then overlays current Catalog planning fields from
    # appState.tasks. Audit fields must prefer the fresh board row or the older
    # page-level task cache will visually restore the prior actor/timestamp until
    # a full browser reload.
    assert "annual?.reusable_created_at ?? current.reusable_created_at" in overlay
    assert "annual?.reusable_created_by_display ?? current.reusable_created_by_display" in overlay
    assert "annual?.reusable_updated_at ?? current.reusable_updated_at" in overlay
    assert "annual?.reusable_updated_by ?? current.reusable_updated_by" in overlay
    assert "annual?.reusable_updated_by_person_id ?? current.reusable_updated_by_person_id" in overlay
    assert "annual?.reusable_updated_by_display ?? current.reusable_updated_by_display" in overlay

    assert "reusable_updated_at: current.reusable_updated_at," not in overlay
    assert "reusable_updated_by_display: current.reusable_updated_by_display," not in overlay


def test_122_b1a_current_catalog_is_single_pre2026_task_finder_authority() -> None:
    ui = read_app("setup_scheduling_board.js")

    assert "function board205ApplyHistoricalCatalogOverlay()" in ui
    assert "currentTasks = (appState.tasks || []).filter((task) => Boolean(task.active_flag))" in ui
    assert "baseline_plan_order: current.baseline_plan_order" in ui
    assert "Current Reusable Task Finder — Pre-2026 Planning" in ui
    assert "Pre-2026 planning — current reusable Catalog." in ui
    assert "Historical 2025 facts remain in Verification" in ui

    # The current planning finder must not make 2025 membership/order part of
    # the operator-facing task identity.
    assert "CATALOG ONLY · NOT IN 2025" not in ui
    assert "Current reusable Catalog task · no 2025 annual occurrence was created." not in ui
    assert "2025 order ${board205Esc(task.planned_order)}" not in ui
    assert "2025 annual name:" not in ui

    # Compact planning edit is primary; full Catalog detail is secondary.
    assert "setup-board205-edit-planning-info" in ui
    assert "setup-board205-open-reusable-task" not in ui
    assert "setup-board205-open-full-reusable" in ui

    # Overlay is still a read projection and must not fabricate annual rows.
    overlay = ui.split("function board205ApplyHistoricalCatalogOverlay()", 1)[1].split(
        "function board205TaskCard(task)", 1
    )[0]
    assert "api(" not in overlay
    assert "commandOptions(" not in overlay
    assert "season-tasks" not in overlay


def test_122_b1a_finder_uses_reusable_task_id_and_reusable_plan_order() -> None:
    ui = read_app("setup_scheduling_board.js")

    assert "Task ${board205Esc(task.setup_task_id ?? 'annual-only')}" in ui
    assert "const reusablePlanning = board205HistoricalReviewMode()" in ui
    assert "task.baseline_plan_order" in ui
    assert "task.planned_order ?? task.baseline_plan_order" in ui
    assert "<span>${board205Esc(task.planned_order ?? '—')} · ${board205Esc(task.task_name)}</span>" not in ui


def test_122_b1a_historical_catalog_overlay_excludes_inactive_reusable_tasks() -> None:
    ui = read_app("setup_scheduling_board.js")

    assert "filter((task) => Boolean(task.active_flag))" in ui


def test_122_b1a_readiness_note_defaults_to_not_ready() -> None:
    ui = read_app("setup_scheduling_board.js")
    sql = read_db("050_add_setup_scheduling_board_foundation.sql")

    assert "function board205DefaultReadinessState(readinessNote)" in ui
    assert "String(readinessNote || '').trim() ? 'NOT_READY' : 'READY'" in ui
    assert "readiness_state: board205DefaultReadinessState(current.readiness_note)" in ui
    assert "function board205ReadinessOnly(task)" in ui
    assert "canManage && !historicalReview && !task.catalog_only && task.readiness_note" in ui
    assert "if (!task || !task.setup_session_task_id || !appState.access?.can_manage_setup) return;" in ui

    # Real annual seeding already follows the same rule: a reusable readiness
    # condition starts NOT_READY until explicitly cleared for that season.
    assert "WHEN nullif(btrim(coalesce(NEW.annual_readiness_note, v_task.readiness_note)), '') IS NULL" in sql
    assert "ELSE 'NOT_READY'" in sql


def test_122_readiness_note_invariant_is_enforced_in_database() -> None:
    sql = read_db("056_enforce_setup_readiness_note_not_ready.sql")

    assert "CREATE OR REPLACE FUNCTION ops.enforce_setup_readiness_note_state()" in sql
    assert "NEW.annual_readiness_state := CASE" in sql
    assert "WHEN v_note IS NULL THEN 'READY'" in sql
    assert "ELSE 'NOT_READY'" in sql
    assert "BEFORE INSERT OR UPDATE ON ops.setup_session_task" in sql

    assert "CREATE OR REPLACE FUNCTION ops.sync_reusable_readiness_to_current_sessions()" in sql
    assert "ss.session_status IN ('PLANNING','ACTIVE')" in sql
    assert "st.task_origin = 'REUSABLE'" in sql
    assert "st.actual_started_at IS NULL" in sql
    assert "st.actual_completed_at IS NULL" in sql
    assert "FROM ops.setup_task_progress p" in sql
    assert "AFTER UPDATE OF readiness_note ON ref.setup_task" in sql

    # Historical Verification is intentionally excluded because only
    # PLANNING / ACTIVE sessions are synchronized.
    assert "ss.session_status IN ('PLANNING','ACTIVE')" in sql


def test_122_b1a_catalog_prerequisites_begin_hard_blocked() -> None:
    ui = read_app("setup_scheduling_board.js")

    assert "prerequisite_complete: false" in ui
    assert "Reusable prerequisites therefore begin as hard blockers." in ui
    assert "catalog_dependencies: currentDependencies" in ui
    assert "prerequisites_complete: !hasHardPrerequisite" in ui
    assert "board_status: hasHardPrerequisite ? 'BLOCKED' : 'CATALOG_ONLY'" in ui
    assert "2025 completion does not satisfy future prerequisites." in ui
    assert "const blockerDetails = board205BlockerDetails(task, deps);" in ui


def test_122_b1a_work_order_gate_is_visible_and_blocks_downstream() -> None:
    ui = read_app("setup_scheduling_board.js")

    # Gate task itself remains visible while its Work Order is open.
    assert "WAITING_ON_WORK_ORDER' && task?.linked_work_order_gate) return 'READY';" in ui

    # Blocking ON hides the subsequent task only when its prerequisite edge
    # remains incomplete.
    assert "return task.prerequisites_complete === false;" in ui
    assert "if (board205BlockingEnabled() && hardBlocked) return false;" in ui

    # Work Order completion still participates in prerequisite completion through
    # the repository's dependency calculation, not finder-local mutation.
    repo = read_app("setup_scheduling_board_repository.py")
    assert "pst.linked_work_order_gate" in repo
    assert "pwo.date_completed IS NOT NULL" in repo


def test_122_b1a_work_order_selector_uses_live_lookup() -> None:
    repo = read_app("setup_scheduling_board_repository.py")
    ui = read_app("setup_scheduling_board.js")

    assert "FROM ops.setup_scheduling_work_order_gate wo" in repo
    assert "wo.work_order_id" in repo
    assert "wo.problem" in repo
    assert "wo.date_completed" in repo
    assert '"work_orders": work_orders' in repo

    assert "setupBoard205State.board.work_orders" in ui
    assert "WO ${wo.work_order_id} · ${status}" in ui
    assert "setup-board205-season-work-order" in ui
    assert "type=\"number\"" not in ui.split(
        'id="setup-board205-season-work-order"', 1
    )[1].split("</label>", 1)[0]

    # Completion remains live database state, not a manual Setup checkbox.
    assert "pwo.date_completed IS NOT NULL" in repo


def test_122_b1a_historical_catalog_uses_fresh_season_dependency_baseline() -> None:
    ui = read_app("setup_scheduling_board.js")

    overlay = ui.split("function board205ApplyHistoricalCatalogOverlay()", 1)[1].split(
        "function board205TaskCard(task)", 1
    )[0]

    assert "const currentDependencies = board205CatalogDependencyRows(current);" in overlay
    assert "const hasHardPrerequisite = currentDependencies.length > 0;" in overlay
    assert "catalog_dependencies: currentDependencies" in overlay
    assert "prerequisites_complete: !hasHardPrerequisite" in overlay
    assert "board.dependencies = [];" in overlay
    assert "2025 completion does not satisfy future prerequisites." in overlay

    card = ui.split("function board205TaskCard(task)", 1)[1].split(
        "function board205QueueTasks()", 1
    )[0]
    assert "const catalogReview = historicalReview" in card
    assert "task.catalog_dependencies || []" in card
    assert "HARD BLOCKED" in card
    assert "CURRENT CATALOG" in card


def test_122_b1a_finder_can_collapse_secondary_filters() -> None:
    ui = read_app("setup_scheduling_board.js")
    css = read_app("setup_scheduling_board.css")

    assert "finderCompact: null" in ui
    assert "function board205ApplyFinderCompact()" in ui
    assert "setup-board205-filter-density" in ui
    assert "More filters" in ui
    assert "Compact filters" in ui
    assert "setup-board205-secondary-filters" in ui
    assert "setupBoard205State.finderCompact = historicalReview" in ui
    assert ".setup-board205-filters.compact .setup-board205-secondary-filters" in css
    assert ".setup-board205-filters.compact .setup-board205-blocking-help" in css


def test_122_b1a_finder_ready_only_is_visibility_not_hard_blocking() -> None:
    ui = read_app("setup_scheduling_board.js")

    assert 'id="setup-board205-ready-only"' in ui
    assert "function board205ReadyOnlyEnabled()" in ui
    assert "readyOnly && task.readiness_state === 'NOT_READY'" in ui
    assert "Readiness stays a soft blocker" in ui
    assert "board205FinderStatusFamily(task)" in ui
    assert "return 'READY';" in ui


def test_122_b1a_finder_drilldown_preserves_and_restores_operator_context() -> None:
    ui = read_app("setup_scheduling_board.js")
    production = read_app("setup_production.js")
    html = read_app("production.html")

    assert "function board205CaptureFinderState()" in ui
    assert "function board205RestoreFinderState(state)" in ui
    for token in (
        "stage:",
        "scene:",
        "sort:",
        "search:",
        "blocking:",
        "readyOnly:",
        "statusReady:",
        "timeOp:",
        "crewOp:",
        "effort:",
        "scrollY:",
    ):
        assert token in ui

    assert "setupNavigateToReusableTaskFromFinder(reusableTaskId)" in ui
    assert 'id="setup-return-to-finder"' in html
    assert "setupCommitCurrentRouteState()" in production
    assert "returnToFinder: true" in production
    assert "window.history.back()" in production
    assert "board205RestoreFinderState(requested.finder)" in production

