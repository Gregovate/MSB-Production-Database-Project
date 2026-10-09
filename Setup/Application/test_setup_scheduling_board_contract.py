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


def test_122_launch_preserves_catalog_review_state_by_session_type() -> None:
    sql = read_db("058_preserve_catalog_review_on_annual_launch.sql")
    validation = read_acceptance("setup_122_2026_launch_unblock_disposable_validation.sql")

    assert "WHEN v_status = 'HISTORICAL_VERIFICATION' THEN 'UNVERIFIED'" in sql
    assert "WHEN s.session_status = 'HISTORICAL_VERIFICATION' THEN 'UNVERIFIED'" in sql
    assert "ELSE 'VERIFIED'" in sql
    assert "this does not rewrite existing annual history" in sql
    assert "reset accepted reusable Catalog work to UNVERIFIED" in validation
    assert "Historical verification Session did not preserve UNVERIFIED semantics" in validation


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


def test_205_season_only_tasks_never_seed_future_sessions_or_write_back_to_catalog() -> None:
    migration_050 = read_db("050_add_setup_scheduling_board_foundation.sql")
    migration_058 = read_db("058_preserve_catalog_review_on_annual_launch.sql")

    season_create = migration_050.split(
        "CREATE OR REPLACE FUNCTION ops.create_setup_season_task", 1
    )[1].split("CREATE OR REPLACE FUNCTION ops.update_setup_annual_task_definition", 1)[0]
    assert "INSERT INTO ref.setup_task" not in season_create
    assert "task_origin" in season_create
    assert "'SEASON_ONLY'" in season_create

    session_create = migration_058.split(
        "CREATE OR REPLACE FUNCTION ops.create_setup_session", 1
    )[1].split("CREATE OR REPLACE FUNCTION ref.create_setup_task", 1)[0]
    assert "FROM ref.setup_task t" in session_create
    assert "WHERE t.active_flag" in session_create
    assert "FROM ops.setup_session_task" not in session_create


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
    assert "AM Crew w/Captain" in ui
    assert "PM Crew w/Captain" in ui
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


def test_122_plan_schedule_preserves_catalog_material_visual_cue() -> None:
    ui = read_app("setup_scheduling_board.js")
    repo = read_app("setup_scheduling_board_repository.py")
    catalog = read_app("setup_catalog_effort.js")

    assert "coalesce(rt.requires_display_material, false) AS requires_display_material" in repo
    assert "task.requires_display_material ? 'setup-material-task'" in ui
    assert ".setup-material-task {" in catalog
    assert "border-left: 5px solid #7657c7 !important;" in catalog


def test_122_reusable_rename_syncs_current_annual_name_until_next_session() -> None:
    sql = read_db("059_sync_reusable_task_name_to_open_annual.sql")
    validation = read_acceptance("setup_122_reusable_name_authority_disposable_validation.sql")

    assert "AFTER UPDATE OF task_name ON ref.setup_task" in sql
    assert "OLD.task_name IS DISTINCT FROM NEW.task_name" in sql
    assert "SET annual_task_name = NEW.task_name" in sql
    assert "ss.session_status <> 'HISTORICAL_VERIFICATION'" in sql
    assert "newer.season_year > ss.season_year" in sql
    assert "st.task_origin = 'REUSABLE'" in sql
    assert "Current annual Setup Session still contains reusable task-name drift" in sql

    assert "ref.update_setup_task(" in validation
    assert "ss.session_status <> 'HISTORICAL_VERIFICATION'" in validation
    assert "newer.season_year > ss.season_year" in validation
    assert "ss.session_status = 'HISTORICAL_VERIFICATION'" in validation
    assert "Historical Verification annual name was rewritten" in validation
    assert "ROLLBACK;" in validation
    assert "SETUP_122_REUSABLE_NAME_AUTHORITY_DISPOSABLE_VALIDATION_PASS" in validation


def test_205_board_uses_dynamic_crews_am_pm_and_accessible_move_controls() -> None:
    ui = read_app("setup_scheduling_board.js")
    css = read_app("setup_scheduling_board.css")

    for phrase in (
        "Crew ${board205Esc(crew.crew_code)}",
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
    assert "task-name search keeps status filters" in ui
    assert "task.stage_name" in ui


def test_122_work_order_picker_is_searchable() -> None:
    ui = read_app("setup_scheduling_board.js")
    repo = read_app("setup_scheduling_board_repository.py")

    assert "Find open Work Order" in ui
    assert "setup-board205-season-work-order-search" in ui
    assert "WHERE wo.date_completed IS NULL" in repo
    assert 'placeholder="WO # or problem text"' in ui
    assert "function board205PopulateWorkOrderOptions(" in ui
    assert "function board205WorkOrderMatches(" in ui
    assert "terms.every((term) => haystack.includes(term))" in ui


def test_122_scheduled_task_drops_out_of_default_needs_scheduling_queue() -> None:
    ui = read_app("setup_scheduling_board.js")

    assert "if (!hardBlocked && !statuses.has(family)) return false;" in ui
    assert "task-name search keeps status filters" in ui
    assert 'id="setup-board205-status-scheduled" type="checkbox"' in ui
    assert 'id="setup-board205-status-scheduled" type="checkbox" checked' not in ui


def test_122_planning_screen_uses_compact_operational_kpis_and_stage_scoped_placement() -> None:
    ui = read_app("setup_scheduling_board.js")
    css = read_app("setup_scheduling_board.css")

    assert "function board205RenderKpis()" in ui
    assert "scheduled · " in ui
    assert "complete · " in ui
    assert "setup-board205-primary-filters" in ui
    assert "setup-board205-scene-label" in ui
    assert "function board205PopulateSeasonPlacementOptions(" in ui
    assert "Number(task.stage_id) === stageId" in ui
    assert "grid-template-columns: minmax(0, 1.55fr) minmax(6.5rem, 0.8fr)" in css


def test_122_season_task_type_labels_explain_operator_meaning() -> None:
    ui = read_app("setup_scheduling_board.js")

    assert ">Setup Work — schedulable<" in ui
    assert ">Wait / Gate — not schedulable<" in ui
    assert ">Support / Prep<" in ui
    assert ">Unload Container<" in ui

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
    assert "function board205AmCapacity(crewId)" in ui
    assert "remains in AM" in ui
    assert "over the typical AM window" in ui
    assert "of AM work carries past lunch into PM" in ui
    assert "AM work fills the typical ≈ 9–12 window." in ui
    assert "≈ 9–12" in ui
    assert "after lunch ≈ 1 PM" in ui
    assert '<option value="ALL_DAY">All Day</option>' not in ui


def test_205_scheduled_task_finder_locates_existing_schedule_assignments() -> None:
    ui = read_app("setup_scheduling_board.js")
    css = read_app("setup_scheduling_board.css")

    assert "Find scheduled task" in ui
    assert 'id="setup-board205-scheduled-search"' in ui
    assert 'id="setup-board205-scheduled-search-results"' in ui
    assert "function board205ScheduledSearchMatches" in ui
    assert "function board205RevealScheduledAssignment" in ui
    assert "function board205RenderScheduledSearch" in ui
    assert "board205CompareAssignmentOrder" in ui
    assert "Stage, task name, or Captain" in ui
    assert "captain_display_name" in ui
    assert "stage_name" in ui
    assert "function board205ScheduledStageLabel" in ui
    assert "function board205CompactDayContext" in ui
    assert "scrollIntoView({ behavior: 'smooth', block: 'center', inline: 'nearest' })" in ui
    assert "scheduled-search-hit" in ui
    assert ".setup-board205-scheduled-search" in css
    assert ".setup-board205-assignment.scheduled-search-hit" in css
    assert "setup-board205-dispatch-controls" in ui
    assert "setup-board205-scheduled-search-sticky" not in ui
    assert ".setup-board205-dispatch-controls .setup-board205-scheduled-search-results" in css
    assert "position: absolute;" in css
    assert "function board205CollapseScheduledSearchResults" in ui
    assert "scheduledSearchOpen: false" in ui
    assert "setupBoard205State.scheduledSearchOpen = false;" in ui
    assert "if (!search || !setupBoard205State.scheduledSearchOpen)" in ui
    assert "scheduledSearch?.addEventListener('input', openScheduledSearch)" in ui
    assert "scheduledSearch?.addEventListener('click', openScheduledSearch)" in ui
    assert "if (event.key === 'Escape')" in ui


def test_205_empty_work_day_removal_is_fail_closed_end_to_end() -> None:
    sql = read_db("068_add_setup_empty_work_day_removal.sql")
    api = read_app("setup_scheduling_board_api.py")
    repo = read_app("setup_scheduling_board_repository.py")
    ui = read_app("setup_scheduling_board.js")

    assert "ops.remove_empty_setup_work_day" in sql
    assert "v_day_status <> 'PLANNED'" in sql
    assert "v_crew_count <> 1" in sql
    assert "v_crew_number <> 1" in sql
    assert "v_crew_code <> 'A'" in sql
    assert "v_captain_person_id IS NOT NULL" in sql
    assert "FROM ops.setup_work_day_task wdt" in sql
    assert "FROM ops.setup_task_progress p" in sql
    assert "ops.resequence_setup_future_work_days(v_session_id)" in sql
    assert '@setup_scheduling_board_api.delete("/api/setup/scheduling-board/work-days/<int:setup_work_day_id>")' in api
    assert "def remove_work_day(" in repo
    assert "function board205CanRemoveWorkDay(day)" in ui
    assert "Remove Empty Day" in ui
    assert "one Crew A, Captain TBD, and no tasks assigned." in ui
    assert "function board205ExistingWorkDayDates()" in ui
    assert "const alreadyExists = existing.has(date);" in ui
    assert "if (existing.has(date) || date < todayKey) setupBoard205State.workDaySelection.delete(date);" in ui


def test_205_schedule_print_keeps_landscape_while_task_cover_sheet_is_portrait() -> None:
    css = read_app("setup_scheduling_board.css")

    assert "@page {" in css
    assert "size: landscape;" in css
    assert "@page setup-perform-task {" in css
    assert "size: portrait;" in css
    assert "page: setup-perform-task;" in css
    assert css.count("@page {") == 1
    assert "break-after: avoid;" in css


def test_205_work_day_calendar_and_database_reject_past_dates() -> None:
    ui = read_app("setup_scheduling_board.js")
    sql = read_db("068_add_setup_empty_work_day_removal.sql")
    validation = read_acceptance("setup_205_empty_work_day_removal_disposable_validation.sql")

    assert "function board205TodayDateKey()" in ui
    assert "const inPast = date < todayKey;" in ui
    assert "Past dates cannot be added as Setup Work Days" in ui
    assert "date < board205TodayDateKey()" in ui
    assert "ops.reject_past_setup_work_day_insert" in sql
    assert "NEW.work_date < current_date" in sql
    assert "Setup work days cannot be added in the past" in sql
    assert "Past Setup work day was unexpectedly addable" in validation


def test_205_schedulable_tasks_print_is_separate_blocking_on_report() -> None:
    ui = read_app("setup_scheduling_board.js")
    css = read_app("setup_scheduling_board.css")

    assert "Print Schedulable Tasks" in ui
    assert "function board205SchedulableTasksForReport()" in ui
    assert "!board205HasHardBlock(task)" in ui
    assert "board205FinderStatusFamily(task) === 'READY'" in ui
    assert "Number(task.unworked_assignment_count || 0) === 0" in ui
    assert "String(task.task_action_type || '').toUpperCase() !== 'GATE'" in ui
    assert "board205FinderCompare(a, b, 'STAGE')" in ui
    assert "Hard prerequisite blockers excluded" in ui
    assert "NOT READY conditions shown for Manager judgment" in ui
    assert "Stage / Scene order" in ui
    assert "setup-print-schedulable-tasks" in ui
    assert "@page setup-schedulable-tasks" in css
    assert "page: setup-schedulable-tasks;" in css


def test_205_light_mode_strengthens_schedule_structure_without_changing_dark_palette() -> None:
    css = read_app("setup_scheduling_board.css")

    assert 'html[data-theme="light"] .setup-board205-day' in css
    assert "border-color: #b8c4d0;" in css
    assert 'html[data-theme="light"] .setup-board205-assignment' in css
    assert "border-color: #bdc9d5;" in css
    assert "background: #eef3f7;" in css
    assert "background: #fbfcfe;" in css


def test_205_schedule_command_bar_preserves_board_height_and_controls() -> None:
    ui = read_app("setup_scheduling_board.js")
    css = read_app("setup_scheduling_board.css")

    assert "setup-board205-dispatch-controls" in ui
    assert "+ Add Work Days" in ui
    assert "Find scheduled task" in ui
    assert "> Unfinished</label>" in ui
    assert "> Completed</label>" in ui
    assert "> Empty</label>" in ui
    assert "setup-board205-selection-count" in ui
    assert "Print Schedule" in ui
    assert "Open only when you need to add dates." not in ui
    assert "Each work day starts with Crew A." not in ui
    assert "setup-board205-board-key" in ui
    assert "grid-template-columns: auto auto minmax(16rem, 1fr) auto auto auto;" in css
    assert "max-height: min(22rem, 55vh);" in css


def test_205_schedule_badges_use_consistent_semantic_colors() -> None:
    ui = read_app("setup_scheduling_board.js")
    css = read_app("setup_scheduling_board.css")

    assert "function board205StatusBadgeClass" in ui
    for token in (
        "status-ready",
        "status-reschedule",
        "status-scheduled",
        "status-complete",
        "status-blocked",
        "status-waiting",
        "status-deferred",
        "status-catalog",
        "wo-open",
        "wo-complete",
        "gate-badge",
        "effort-light",
        "effort-moderate",
        "effort-heavy",
        "effort-unknown",
    ):
        assert token in ui or token in css

    assert "--setup-board205-badge-info-bg: #dbeafe;" in css
    assert "--setup-board205-badge-warn-bg: #fff1c7;" in css
    assert "--setup-board205-badge-danger-bg: #fee2e2;" in css
    assert "--setup-board205-badge-success-bg: #dcfce7;" in css
    assert "--setup-board205-badge-neutral-bg: #eef2f7;" in css
    assert "--setup-board205-badge-info-bg: #17365d;" in css
    assert "background: var(--setup-board205-badge-effort-bg);" in css
    assert ".setup-board205-badge.short-crew-badge" in css
    assert ".setup-board205-badge.effort-heavy" in css


def test_205_schedule_board_shows_cumulative_progress_without_deriving_time() -> None:
    repo = read_app("setup_scheduling_board_repository.py")
    ui = read_app("setup_scheduling_board.js")
    css = read_app("setup_scheduling_board.css")

    assert "max(p.percent_complete) AS percent_complete" in repo
    assert "coalesce(progress.percent_complete, 0) AS percent_complete" in repo
    assert "function board205ProgressPercent(task)" in ui
    assert "function board205ProgressGauge(task)" in ui
    assert 'class="setup-board205-progress-gauge"' in ui
    assert 'role="progressbar"' in ui
    assert "aria-valuenow" in ui
    assert "!locked ? board205ProgressGauge(task) : ''" in ui
    assert ".setup-board205-progress-gauge" in css
    assert "width: var(--setup-board205-progress, 0%);" in css
    assert "background: var(--success, #277a43);" in css
    assert "remaining" not in ui.split("function board205ProgressGauge(task)", 1)[1].split(
        "function board205AuditWhen", 1
    )[0]


def test_205_schedule_board_multi_select_moves_only_unworked_assignments() -> None:
    ui = read_app("setup_scheduling_board.js")
    css = read_app("setup_scheduling_board.css")

    assert "selectedAssignmentIds: new Set()" in ui
    assert "lastSelectedAssignmentId: null" in ui
    assert "event.ctrlKey || event.metaKey" in ui
    assert "event.shiftKey" in ui
    assert "function board205SelectAssignmentCard" in ui
    assert "function board205SelectedAssignmentItems" in ui
    assert "kind: 'assignments'" in ui
    assert "drag any selected task to move the group" in ui
    assert "item && !item.historical_locked" in ui
    assert "moved before the operation stopped" in ui
    assert "board205MaybeLearnCaptainForTasks" in ui
    assert ".setup-board205-assignment.selected" in css
    assert "background: var(--setup-material-action-bg" in css
    assert "box-shadow: 0 0 0 2px var(--setup-material-action-focus" in css


def test_205_needs_scheduling_card_keeps_scheduler_context_compact() -> None:
    ui = read_app("setup_scheduling_board.js")

    task_card = ui.split("function board205TaskCard(task)", 1)[1].split(
        "function board205QueueTasks()", 1
    )[0]
    assert "<strong>Resources:</strong>" not in task_card
    assert "Reusable notes:" in task_card
    assert "Hard predecessor(s):" in task_card
    assert "Readiness:" in task_card
    assert "Min crew:" in task_card
    assert "Expected:" in task_card
    assert "return `Updated ${board205AuditWhen(task.reusable_updated_at)} by ${updatedBy}`;" in ui
    assert "Created ${board205AuditWhen(task.reusable_created_at)}" not in ui


def test_205_schedule_board_repeats_day_context_at_crew_and_compacts_print() -> None:
    ui = read_app("setup_scheduling_board.js")
    css = read_app("setup_scheduling_board.css")

    assert "setup-board205-crew-day-context" in ui
    assert "Crew ${board205Esc(crew.crew_code)} <span class=\"setup-board205-crew-day-context\">· ${board205Esc(compactDay)}</span>" in ui
    assert "board205CompactDayContext(day)" in ui
    assert "font-size: inherit;" in css
    assert "font-weight: inherit;" in css
    assert "setup-board205-crew-row" in ui
    assert "print-empty-day" in ui
    assert "print-empty-crew" in ui
    assert "setup-board205-assignment-captain" in ui
    assert ".setup-board205-crew-row" in css
    assert "break-inside: avoid;" in css
    assert "#schedule-view .print-empty-day" in css
    assert "#schedule-view .print-empty-crew" in css
    assert "#schedule-view .setup-board205-planning-header" in css
    assert "#schedule-view .setup-board205-assignment-captain" in css
    assert "min-height: 0 !important;" in css


def test_122_schedule_board_compacts_crew_controls_and_prints_operational_board() -> None:
    ui = read_app("setup_scheduling_board.js")
    css = read_app("setup_scheduling_board.css")

    assert "Crew / Captain / Volunteers" in ui
    assert ">AM Crew w/Captain <" in ui
    assert ">PM Crew w/Captain <" in ui
    assert "setup-board205-crew-title-row" in ui
    assert '<button type="button" class="small setup-board205-save-crew">Save</button>' in ui
    assert "secondary setup-board205-save-crew" not in ui
    assert "setup-board205-print" in ui
    assert "Print Schedule" in ui
    assert "setup-board205-board-title-row" in ui
    assert "window.print()" in ui
    assert ".setup-board205-board-title-row" in css
    assert "@media print" in css
    assert "#schedule-view .setup-board205-backlog" in css
    assert ".setup-board205-kpis" in css


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


def test_122_b1a_open_full_reusable_saves_compact_edits_first() -> None:
    ui = read_app("setup_scheduling_board.js")

    assert "function board205PlanningInfoDirty()" in ui
    assert "async function board205PersistPlanningInfo(" in ui
    assert "if (board205PlanningInfoDirty()) {" in ui
    assert "board205PersistPlanningInfo({ closeDialog: false, announce: false })" in ui
    assert "Planning edits saved before opening the full reusable task." in ui
    assert "await reloadTasks(reusableTaskId);" in ui
    assert "await setupNavigateToReusableTaskFromFinder(reusableTaskId);" in ui


def test_122_b1a_pre2026_finder_hides_deferred_and_filters_soft_readiness() -> None:
    ui = read_app("setup_scheduling_board.js")

    assert "setup-board205-ready-only" in ui
    assert 'id="setup-board205-ready-only" type="checkbox"> Ready only' in ui
    assert 'id="setup-board205-ready-only" type="checkbox" checked' not in ui
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
    assert "board205PlacementCrewCount" in ui
    assert ".setup-board205-crew-label[data-crew-id=" in ui
    assert "board205CrewCapacityWarnings" in ui
    assert "Save this crew size anyway?" in ui
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


def test_205_rolling_board_filters_days_by_operational_state() -> None:
    ui = read_app("setup_scheduling_board.js")
    css = read_app("setup_scheduling_board.css")

    assert "function board205DayViewState(day)" in ui
    assert "if (status === 'COMPLETE' || status === 'CANCELLED') return 'COMPLETED';" in ui
    assert "if (!assignments.length) return 'EMPTY';" in ui
    assert "return hasUnfinished ? 'UNFINISHED' : 'COMPLETED';" in ui
    assert "> Completed</label>" in ui
    assert "cancelled-day" in ui
    assert 'id="setup-board205-show-unfinished-days" type="checkbox" checked' in ui
    assert 'id="setup-board205-show-completed-days" type="checkbox" checked' in ui
    assert 'id="setup-board205-show-empty-days" type="checkbox"' in ui
    assert "> Unfinished</label>" in ui
    assert "if (showEmptyDays) showEmptyDays.checked = true;" in ui
    assert "setup-board205-show-history" not in ui
    assert "day-band-odd" in ui
    assert "day-band-even" in ui
    assert ".setup-board205-day.day-band-odd .setup-board205-day-header" in css
    assert ".setup-board205-day.day-band-even .setup-board205-day-header" in css

def test_205_scheduler_panes_scroll_independently_with_drag_edge_autoscroll() -> None:
    ui = read_app("setup_scheduling_board.js")
    css = read_app("setup_scheduling_board.css")
    assert "board205AutoScrollPane" in ui
    assert "board205AutoScrollTick" in ui
    assert "board205StopAutoScroll" in ui
    assert "requestAnimationFrame(board205AutoScrollTick)" in ui
    assert "visibleBottom = Math.min(rect.bottom, window.innerHeight)" in ui
    assert "pane.scrollTop" in ui
    assert ".setup-board205-backlog," in css
    assert ".setup-board205-board {" in css
    assert "overflow-y: auto" in css
    assert "height: calc(100vh - 6.25rem)" in css
    assert "grid-template-columns: minmax(22rem, 0.95fr) minmax(34rem, 1.55fr)" in css
    assert ".setup-board205-right {" in css
    assert "grid-template-rows: auto minmax(0, 1fr)" in css
    assert "setup-board205-planning-header" in ui
    assert "margin: 0.2rem 0 0.55rem" in css
    assert "max-height: none;" in css


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
    assert "Add Task" in ui
    assert "THIS SEASON ONLY" in ui
    assert "It does not enter the Reusable Task Catalog" in ui
    assert "Selected Work Order<select" in ui
    assert "setup-board205-season-work-order-results" in ui
    assert "The full open Work Order list is intentionally not shown." in ui
    assert "function board205WorkOrderMatches(" in ui
    assert "terms.every((term) => haystack.includes(term))" in ui
    assert "No Work Order" in ui
    assert "Linked Work Order completion completes/satisfies this Setup item" in ui
    assert "Wait / Gate is NOT scheduled to a crew or work day." in ui
    assert "Setup Work is real crew work" in ui
    assert "['WORK', 'GATE'].includes(actionType)" in ui
    assert "gate.disabled = !(isGate || isWork) || !workOrderSelected" in ui
    assert "finishing that Work Order also completes this Setup task and unblocks downstream work" in ui
    assert "Est. labor:" in ui
    assert "planned labor hr" in ui
    assert "board205LaborHours" in ui
    assert "board205AssignmentPlannedCrew" in ui
    assert "Locate Power & Network is Setup Work, not Support / Prep." in ui
    assert "This task happens after" in ui
    assert "This task must happen before" in ui
    assert "board205SeasonPlacementState" in ui
    assert "chain.hidden = true" not in ui
    assert "setup-board205-season-placement-note" in ui
    assert "setup-board205-season-effort" in ui


def test_205_existing_season_gate_can_reconcile_annual_placement_without_rewriting_other_edges() -> None:
    ui = read_app("setup_scheduling_board.js")
    api = read_app("setup_scheduling_board_api.py")
    repository = read_app("setup_scheduling_board_repository.py")

    assert "/placement" in api
    assert "reconcile_season_task_placement" in repository
    assert "ops.set_setup_session_task_dependency" in repository
    assert "ops.set_setup_session_task_planned_order" in repository
    reconcile = repository.split("def reconcile_season_task_placement(", 1)[1].split(
        "def set_readiness(", 1
    )[0]
    assert "FOR UPDATE" not in reconcile
    assert "previous_prerequisite_setup_session_task_id" in ui
    assert "previous_downstream_setup_session_task_id" in ui
    assert "Additional prerequisite(s) preserved" in ui
    assert "Additional downstream dependency/dependencies preserved" in ui
    assert "Use one side when that is enough." in ui
    assert "setup-board205-season-error" in ui
    assert "window.alert(error.message || error)" not in ui.split("async function board205SubmitSeasonTask", 1)[1].split("function board205InstallView", 1)[0]

    # Save the definition and requested placement as one browser command so a
    # dependency failure cannot leave a partially updated season-only task.
    season_submit = ui.split("async function board205SubmitSeasonTask", 1)[1].split(
        "function board205InstallView", 1
    )[0]
    assert "/placement" not in season_submit
    assert "previous_prerequisite_setup_session_task_id" in season_submit
    assert "downstream_setup_session_task_id" in season_submit

    update_method = repository.split("def update_annual_task(", 1)[1].split(
        "def update_planning_info(", 1
    )[0]
    assert "ops.update_setup_annual_task_definition" in update_method
    assert "ops.set_setup_session_task_dependency" in update_method
    assert "ops.set_setup_session_task_planned_order" in update_method
    assert "FOR UPDATE" not in update_method

    create_method = repository.split("def create_season_task(", 1)[1].split(
        "def delete_season_task(", 1
    )[0]
    assert "ops.create_setup_season_task" in create_method
    assert "ops.set_setup_session_task_dependency" in create_method
    assert "conn.commit()" in create_method

    assert "prerequisite_session_task_id=nullable_int(" in api
    assert "downstream_session_task_id=nullable_int(" in api
    assert "previous_prerequisite_session_task_id=nullable_int(" in api
    assert "previous_downstream_session_task_id=nullable_int(" in api



def test_205_quick_readiness_uses_existing_governed_readiness_command() -> None:
    ui = read_app("setup_scheduling_board.js")
    repository = read_app("setup_scheduling_board_repository.py")

    quick = ui.split("async function board205SetReadiness(task)", 1)[1].split(
        "async function board205AddCrew", 1
    )[0]
    assert "/readiness" in quick
    assert "/annual-hold" not in quick
    assert "readiness_note" not in quick

    set_readiness = repository.split("def set_readiness(", 1)[1].split(
        "def set_dependency(", 1
    )[0]
    assert "ops.set_setup_annual_task_readiness" in set_readiness
    assert "FOR UPDATE" not in set_readiness


def test_205_annual_hold_is_season_only_and_uses_one_governed_command() -> None:
    ui = read_app("setup_scheduling_board.js")
    api = read_app("setup_scheduling_board_api.py")
    repository = read_app("setup_scheduling_board_repository.py")
    sql = read_db("067_fix_setup_annual_hold_command.sql")
    validation = read_acceptance("setup_205_annual_hold_disposable_validation.sql")

    assert "Annual readiness…" in ui
    assert "THIS SEASON ONLY." in ui
    assert "does not change reusable Catalog readiness knowledge" in ui
    assert "/annual-hold" in api

    annual_hold = repository.split("def set_annual_hold(", 1)[1].split(
        "def reconcile_season_task_placement(", 1
    )[0]
    assert "ops.set_setup_annual_hold" in annual_hold
    assert "FOR UPDATE" not in annual_hold
    assert "ops.update_setup_annual_task_definition" not in annual_hold
    assert "ops.set_setup_annual_task_readiness" not in annual_hold
    assert "ref.update_setup_task" not in annual_hold

    assert "CREATE OR REPLACE FUNCTION ops.set_setup_annual_hold" in sql
    assert "SECURITY DEFINER" in sql
    assert "FOR UPDATE" in sql
    assert "Actual work exists for this annual task; annual readiness is historical." in sql
    assert "SET annual_readiness_note = v_note" in sql
    assert "SET annual_readiness_state = v_state" in sql
    assert "GRANT EXECUTE ON FUNCTION ops.set_setup_annual_hold" in sql
    assert "GRANT UPDATE ON ops.setup_session_task" not in sql

    assert "SETUP_205_ANNUAL_HOLD_DISPOSABLE_VALIDATION_PASS" in validation
    assert "fieldwiring_app unexpectedly has broad UPDATE" in validation
    assert "Annual hold READY-with-note mutation failed" in validation


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
        "/api/setup/scheduling-board/season-tasks/<int:setup_session_task_id>/annual-hold",
        "/api/setup/scheduling-board/season-tasks/<int:setup_session_task_id>/placement",
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


def test_122_work_day_calendar_supports_tablet_multiselect_without_overwriting_existing_days() -> None:
    ui = read_app("setup_scheduling_board.js")
    css = read_app("setup_scheduling_board.css")
    block = ui.split("async function board205AddWorkDay(event)", 1)[1].split(
        "function board205OpenPlanningInfoDialog", 1
    )[0]

    assert "workDaySelection: new Set()" in ui
    assert "function board205RenderWorkDayCalendar()" in ui
    assert "workDayPickerExpanded: false" in ui
    assert "function board205ApplyWorkDayPickerExpanded()" in ui
    assert 'id="setup-board205-toggle-work-days"' in ui
    assert 'id="setup-board205-toggle-work-days" type="button" class="small"' in ui
    assert 'id="setup-board205-toggle-work-days" type="button" class="small secondary"' not in ui
    assert 'aria-expanded="false">+ Add Work Days' in ui
    assert 'id="setup-board205-work-day-picker-body"' in ui
    assert "body.hidden = !expanded;" in ui
    assert "setupBoard205State.workDayPickerExpanded = false;" in ui
    assert 'id="setup-board205-cancel-work-days"' in ui
    assert ".setup-board205-day-form:not(.expanded)" in css
    assert "function board205ExistingWorkDayDates()" in ui
    assert "setup-board205-work-day-calendar" in ui
    assert "setup-board205-calendar-day:not(:disabled)" in ui
    assert "setupBoard205State.workDaySelection.delete(date)" in ui
    assert "setupBoard205State.workDaySelection.add(date)" in ui
    assert "alreadyExists || inPast ? 'disabled aria-disabled=\"true\"' : ''" in ui
    assert "Existing Work Days are disabled." in ui
    calendar_form = ui.split('<form id="setup-board205-day-form"', 1)[1].split("</form>", 1)[0]
    assert "Ctrl" not in calendar_form
    assert "Shift" not in calendar_form

    assert "const form = event.currentTarget;" in block
    assert "const dates = [...setupBoard205State.workDaySelection]" in block
    assert ".filter((date) => !existing.has(date))" in block
    assert "for (const date of dates)" in block
    assert "if (board205ExistingWorkDayDates().has(date)) continue;" in block
    assert "form.reset();" in block
    assert "event.currentTarget.reset();" not in block
    assert "setupBoard205State.workDaySelection.clear();" in block

    assert "touch-action: manipulation;" in css
    assert ".setup-board205-calendar-day.selected" in css
    assert ".setup-board205-calendar-day.existing:disabled" in css
    assert "@media (max-width: 720px)" in css


def test_205_scheduling_board_javascript_has_no_stray_async_prefixes() -> None:
    ui = read_app("setup_scheduling_board.js")
    assert "\nasync \nasync function " not in ui
    assert "board205InstallView();" in ui
    assert "document.getElementById('schedule-view')?.classList.contains('active-view')" in ui
    assert "void board205Load();" in ui
    assert "Setup Scheduling Board" in ui


def test_205_production_host_registers_board_without_replacing_report_work() -> None:
    host = read_app("production_backend.py")
    html = read_app("production.html")
    ui = read_app("setup_scheduling_board.js")
    assert "setup_scheduling_board_api" in host
    assert "app.register_blueprint(setup_scheduling_board_api)" in host
    assert '"setup_scheduling_board.css"' in host
    assert '"setup_scheduling_board.js"' in host
    assert "setup_scheduling_board.css?v=2026-10-05.1" in html
    assert "setup_scheduling_board.js?v=2026-10-09.320.5" in html
    assert 'id="setup-board205-show-empty-days" type="checkbox" checked' in ui
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
    assert "setup-board205-edit-annual-hold" in ui
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
    assert "if (!hardBlocked && !statuses.has(family)) return false;" in ui
    assert "task-name search keeps status filters" in ui
    assert "const taskName = String(task.task_name || '').toLowerCase();" in ui
    assert "if (!taskName.includes(search)) return false;" in ui
    assert 'placeholder="e.g. locate"' in ui


def test_122_b1a_finder_explains_blocker_classes() -> None:
    ui = read_app("setup_scheduling_board.js")

    assert "function board205BlockerDetails(task, deps)" in ui
    assert "Readiness condition · soft" not in ui
    assert "Hard predecessor" in ui
    assert "Work Order gate" in ui
    assert "Complete first:" in ui
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

def test_122_b1a_plan_sort_uses_visible_reusable_step_order_inside_scope() -> None:
    ui = read_app("setup_scheduling_board.js")
    repository = read_app("setup_scheduling_board_repository.py")

    assert "rt.display_order," in repository
    assert "display_order: current.display_order" in ui
    assert "const stageFilter = document.getElementById('setup-board205-stage-filter')?.value || '';" in ui
    assert "const useReusableStepOrder = Boolean(stageFilter) && task.task_origin === 'REUSABLE';" in ui
    assert "task.display_order ?? task.baseline_plan_order ?? task.planned_order" in ui
    assert "const scopeCompare = (left, right) => {" in ui
    assert "left.lor_scene_id == null ? 0 : 1" in ui
    assert "textCompare(left.scene_name, right.scene_name)" in ui
    assert "if (stageFilter) {" in ui
    assert "return scopeCompare(a, b)" in ui
    assert "|| stepOrder(a) - stepOrder(b)" in ui
    assert "reusablePlanning && stageFilter" not in ui


def test_122_b1a_finder_controls_rerender_through_delegated_events() -> None:
    ui = read_app("setup_scheduling_board.js")

    assert "const finderFilters = document.getElementById('setup-board205-filters');" in ui
    assert "finderFilters?.addEventListener('change'" in ui
    assert "finderFilters?.addEventListener('input'" in ui
    assert "board205RenderQueue();" in ui


def test_122_b1a_ready_only_is_expanded_and_soft_visible_by_default() -> None:
    ui = read_app("setup_scheduling_board.js")

    assert '<input id="setup-board205-ready-only" type="checkbox"> Ready only' in ui
    assert '<input id="setup-board205-ready-only" type="checkbox" checked>' not in ui
    status = ui.split('<fieldset class="setup-board205-status-filter">', 1)[1].split('</fieldset>', 1)[0]
    assert status.index("setup-board205-status-scheduled") < status.index("setup-board205-ready-only")
    assert status.index("setup-board205-ready-only") < status.index("setup-board205-status-complete")
    assert "soft readiness shown" in ui


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
        "function board205SchedulableTasksForReport()", 1
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
    assert "reusable_notes: draft.reusable_notes" in ui
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


def test_122_b1a_task_search_and_filter_panel_are_visually_distinct() -> None:
    css = read_app("setup_scheduling_board.css")

    assert ".setup-board205-filters {" in css
    assert "border: 2px solid color-mix(" in css
    assert "background: color-mix(" in css
    assert ".setup-board205-finder .setup-board205-search input {" in css
    assert "border-width: 2px;" in css
    assert ".setup-board205-finder .setup-board205-search input:focus {" in css


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
    assert "setup_production.js?v=2026-10-01.2" in html


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
    assert "The 2025 construction marker does not define this task list or current planning state." in ui

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
    assert "function board205WorkOrderLabel(wo)" in ui
    assert "problem ? ` · ${problem}` : ''" in ui
    assert "WHERE wo.date_completed IS NULL" in repo
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
    assert "setupBoard205State.finderCompact = true" in ui
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



def test_122_real_2026_session_creation_and_add_intent_are_explicit() -> None:
    ui = read_app("setup_scheduling_board.js")
    assert "setup-board205-create-session" in ui
    assert "Create the real" in ui
    assert "api/setup/sessions" in ui
    assert "session_status: 'PLANNING'" in ui
    assert "setup-board205-add-intent-dialog" in ui
    assert "Reusable Setup Task — every year" in ui
    assert "Season Task Only — this season" in ui
    assert "There is no default" in ui
    assert "board205ChooseReusableTask" in ui
    assert "board205ChooseSeasonOnlyTask" in ui

    # Scheduling can deliberately create either identity. Reusable creation
    # hands off to the normal Catalog editor; season-only stays annual-only.
    reusable_choice = ui.split("async function board205ChooseReusableTask()", 1)[1].split(
        "function board205ChooseSeasonOnlyTask()", 1
    )[0]
    season_choice = ui.split("function board205ChooseSeasonOnlyTask()", 1)[1].split(
        "async function board205DeleteSeasonTask()", 1
    )[0]
    assert "navigateSetupView('library')" in reusable_choice
    assert "acceptanceOpenAddTask" in reusable_choice
    assert "board205OpenSeasonTaskDialog()" in season_choice


def test_122_season_only_unworked_task_delete_is_governed() -> None:
    ui = read_app("setup_scheduling_board.js")
    api = read_app("setup_scheduling_board_api.py")
    repository = read_app("setup_scheduling_board_repository.py")
    migration = read_db("057_enable_2026_unworked_task_deletion.sql")
    assert "setup-board205-delete-season-task" in ui
    assert "commandOptions('DELETE')" in ui
    assert '@setup_scheduling_board_api.delete(' in api
    assert "delete_season_task" in api
    assert "ops.delete_unworked_setup_season_task" in repository
    assert "CREATE OR REPLACE FUNCTION ops.delete_unworked_setup_season_task" in migration
    assert "reported work/progress" in migration
    assert "DELETE FROM ops.setup_work_day_task" in migration


def test_205_schedule_view_expands_on_wide_displays_without_changing_mobile_stack() -> None:
    base_css = read_app("setup.css")
    board_css = read_app("setup_scheduling_board.css")
    production = read_app("setup_production.js")

    assert "document.body.classList.toggle('setup-schedule-view', name === 'schedule')" in production
    assert "body.setup-schedule-view main" in base_css
    assert "max-width: none" in base_css
    assert "@media (min-width: 1101px)" in base_css
    assert "@media (min-width: 1600px)" in board_css
    assert "minmax(20rem, 0.72fr) minmax(48rem, 2.28fr)" in board_css
    assert "minmax(10rem, 0.58fr) repeat(2, minmax(18rem, 1fr))" in board_css
    assert "@media (max-width: 1100px)" in board_css


def test_205_production_notice_is_not_persistent_after_successful_load() -> None:
    html = read_app("production.html")
    production = read_app("setup_production.js")

    assert 'id="app-alert" class="notice production-notice" aria-live="polite" hidden' in html
    set_alert = production.split("function setAlert(message, state = 'ok')", 1)[1].split(
        "function setBusy", 1
    )[0]
    assert "target.hidden = false" in set_alert

    load_season = production.split("async function loadSeason(", 1)[1].split(
        "function chooseInitialSeason", 1
    )[0]
    assert "alert.hidden = true" in load_season
    assert "Setup Session loaded from Production" not in load_season


def test_205_day_number_repair_historical_correction_and_passive_audit_are_governed() -> None:
    migration = read_db("069_fix_setup_day_sequence_and_audit.sql")
    validation = read_acceptance("setup_205_day_sequence_history_disposable_validation.sql")
    api = read_app("setup_scheduling_board_api.py")
    repository = read_app("setup_scheduling_board_repository.py")
    ui = read_app("setup_scheduling_board.js")

    assert "CREATE TABLE IF NOT EXISTS ops.setup_schedule_event" in migration
    assert "ASSIGNMENT_MOVED" in migration
    assert "WORK_DAY_DELETED" in migration
    assert "HISTORICAL_WORK_DAY_ADDED" in migration
    assert "REVOKE ALL ON ops.setup_schedule_event FROM fieldwiring_app" in migration

    resequence = migration.split(
        "CREATE OR REPLACE FUNCTION ops.resequence_setup_future_work_days", 1
    )[1].split("REVOKE ALL ON FUNCTION ops.resequence_setup_future_work_days", 1)[0]
    assert "row_number() OVER" in resequence
    assert "ORDER BY wd.work_date, wd.setup_work_day_id" in resequence
    assert "1000000 + ranked.rn" in resequence
    assert "SET setup_day_number = ranked.rn" in resequence
    assert "v_last_historical_date" not in resequence
    assert "max(wd.setup_day_number)" not in resequence

    assert "ss.session_status IN ('PLANNING','ACTIVE')" in migration
    assert "ops.add_historical_setup_work_day" in migration
    assert "app.setup_allow_past_work_day" in migration
    assert "ops.upsert_setup_work_day(" in migration
    assert "Historical correction is only for dates before today" in migration
    assert "A Setup work day already exists for this date" in migration
    assert "ops.remove_empty_setup_work_day(" in migration
    assert "p_note text" in migration
    assert "event_note" in migration
    assert "Required lift unavailable" in validation
    assert "SETUP_205_DAY_SEQUENCE_HISTORY_VALIDATION_PASS" in validation

    assert '@setup_scheduling_board_api.post("/api/setup/scheduling-board/work-days/historical")' in api
    assert "def add_historical_work_day(" in repository
    assert "ops.add_historical_setup_work_day" in repository
    assert "request.get_json(silent=True) or {}" in api
    assert "note=optional_text(payload.get(\"note\"))" in api
    assert "ops.remove_empty_setup_work_day(%s,%s,%s)" in repository

    assert "Historical Day…" in ui
    assert "setup-board205-historical-day-dialog" in ui
    assert "board205SubmitHistoricalDayCorrection" in ui
    assert "api/setup/scheduling-board/work-days/historical" in ui
    assert "Historical correction is only for dates before today" in ui
    assert "window.prompt(" in ui
    assert "Optional note (leave blank if this date was simply added by mistake)" in ui
    assert "commandOptions('DELETE', { note:" in ui


def test_205_normal_add_work_days_remains_future_only_after_historical_correction() -> None:
    ui = read_app("setup_scheduling_board.js")
    migration068 = read_db("068_add_setup_empty_work_day_removal.sql")
    migration069 = read_db("069_fix_setup_day_sequence_and_audit.sql")

    assert "const inPast = date < todayKey;" in ui
    assert "alreadyExists || inPast ? 'disabled aria-disabled=\"true\"' : ''" in ui
    assert "date < board205TodayDateKey()" in ui
    assert "NEW.work_date < current_date" in migration068
    assert "Setup work days cannot be added in the past" in migration068
    assert "app.setup_allow_past_work_day" in migration069
    assert "coalesce(" in migration069
    assert "<> '1'" in migration069


def test_205_assignment_move_history_is_passive_and_does_not_require_reason() -> None:
    migration = read_db("069_fix_setup_day_sequence_and_audit.sql")
    ui = read_app("setup_scheduling_board.js")

    move_fn = migration.split(
        "CREATE OR REPLACE FUNCTION ops.update_setup_work_day_assignment(", 1
    )[1].split(
        "REVOKE ALL ON FUNCTION ops.update_setup_work_day_assignment", 1
    )[0]

    assert "'ASSIGNMENT_MOVED'" in move_fn
    assert "v_from_work_day_id" in move_fn
    assert "v_from_work_date" in move_fn
    assert "v_from_shift" in move_fn
    assert "v_from_crew_code" in move_fn
    assert "v_to_work_date" in move_fn
    assert "v_to_day_number" in move_fn
    assert "event_note" not in move_fn
    move_ui = ui.split(
        "async function board205DropToCell", 1
    )[1].split(
        "async function board205NudgeAssignment", 1
    )[0].lower()
    assert "move reason" not in move_ui
    assert "reason:" not in move_ui


def test_historical_day_action_remains_visible_in_dark_mode() -> None:
    ui = read_app("setup_scheduling_board.js")
    css = read_app("setup_scheduling_board.css")

    assert 'id="setup-board205-historical-day"' in ui
    assert "#setup-board205-historical-day" in css
    assert 'html[data-theme="dark"] #setup-board205-historical-day' in css
    assert "background: #1c3148;" in css
    assert "border-color: #4f8fc3;" in css
    assert "color: #e8f2fb;" in css


def test_historical_button_rule_does_not_split_shared_scroll_container_selector() -> None:
    css = read_app("setup_scheduling_board.css")
    import re
    shared = re.search(r"\.setup-board205-backlog,\s*\.setup-board205-board\s*\{([^}]+)\}", css)
    assert shared is not None
    assert "overflow-y: auto;" in shared.group(1)
    assert "min-width: 0;" in shared.group(1)
    assert not re.search(r"\.setup-board205-backlog,\s*#setup-board205-historical-day", css)


def test_narrow_board_has_direct_panel_navigation_and_page_scroll():
    css = read_app("setup_scheduling_board.css")
    assert "overflow-y: visible;" in css
    assert 'data-tablet-pane="board"' in css
    assert 'data-tablet-pane="tasks"' in css
    assert '.setup-board205-main:not(.finder-only)' in css
    ui = read_app("setup_scheduling_board.js")
    assert 'aria-controls="setup-board205-right"' in ui
    assert 'aria-controls="setup-board205-backlog"' in ui
    assert "board205SetTabletPane(setupBoard205State.tabletPane);" in ui


def test_launch_quick_progress_filter_is_outside_collapsed_filters():
    ui = read_app("setup_scheduling_board.js")
    assert 'id="setup-board205-in-progress-only" type="checkbox"' not in ui
    assert "inProgressOnly: checked('setup-board205-in-progress-only')" in ui
    assert "setChecked('setup-board205-in-progress-only', state.inProgressOnly)" in ui
    assert "if (task.execution_status !== 'IN_PROGRESS') return false;" in ui
    assert "else if (!hardBlocked && !statuses.has(family)) return false;" in ui
    css = read_app("setup_scheduling_board.css")
    assert "body.setup-schedule-view .site-header { position: static; }" in css
