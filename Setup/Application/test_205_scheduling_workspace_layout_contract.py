"""#205 UI regression: scheduling workspace remains primary over KPI analysis.

Source contract + existing executable Node classifier cover layout and logical
disclosure. The protected 8898 browser review remains necessary for acceptance.
"""
from pathlib import Path

APP = Path(__file__).resolve().parent


def read(name):
    return (APP / name).read_text(encoding="utf-8")


def test_board_is_not_pushed_behind_kpis_in_flex_toolbar():
    js = read("setup_scheduling_board.js")
    root = js.split('view.innerHTML = `',1)[1].split('\n    <dialog',1)[0]
    toolbar = root.split('<div class="setup-board205-toolbar">',1)[1].split('</div>\n            <div id="setup-board205-kpis"',1)[0]
    assert 'id="setup-board205-kpis"' not in toolbar, (
        "Full KPI block must not share narrow toolbar row with title and Add Task"
    )
    assert 'id="setup-board205-kpis"' in root
    assert root.index('id="setup-board205-kpis"') < root.index(
        'id="setup-board205-dispatch-controls"') if 'id="setup-board205-dispatch-controls"' in root else (
        root.index('id="setup-board205-kpis"') < root.index(
            'class="setup-board205-dispatch-controls"')
    )
    assert root.index('id="setup-board205-kpis"') < root.index('id="setup-board205-board-pane"')
    assert root.index('id="setup-board205-board-pane"') < root.index('id="setup-board205-days"')
    assert 'id="setup-board205-queue"' in root
    assert 'id="setup-board205-schedule-dialog"' in js


def test_kpi_glance_precedes_closed_disclosure_and_all_manager_actions_survive():
    js = read("setup_next_pass.js")
    fn = js.split("function setup205DeadlineKpiHtml(",1)[1].split(
        "\nfunction setup205ActionCenterHtml(",1
    )[0]
    assert 'class="setup205-kpi-glance"' in fn
    assert 'class="setup205-kpi-expand"' not in fn
    assert "setup205ActionCenterHtml(board, k)" not in fn
    assert "setup205-open-action-center" in fn
    assert "function setup205ManagementReportHtml(board, year)" in js
    assert "setup205ActionCenterHtml(board) +" in js
    assert "setup205WireActionCenter(target)" in js
    assert "loadSetup205ActionCenter()" in js
    for key in ("k.tasks.length", "k.complete.length", "k.incomplete.length",
                "k.blocked.length", "k.required", "k.projectedFinish", "k.deadline"):
        assert key in fn


def test_css_keeps_grid_board_visible_and_action_details_bounded():
    css = read("setup_scheduling_board.css")
    assert ".setup205-kpi-expanded" in css
    assert "max-height: 34dvh;" in css
    assert "overflow-y: auto;" in css
    assert ".setup-board205-kpis" in css
    assert "display: block;" in css
    assert "grid-template-columns: minmax(17rem, 0.72fr) minmax(0, 2.28fr)" in css
    assert "height: max(28rem, calc(100dvh - 12rem));" in css
    assert ".setup-board205-main:not(.finder-only)[data-tablet-pane=" in css


def test_secondary_labor_does_not_duplicate_primary_complete_remaining():
    ui = read("setup_scheduling_board.js").split(
        "function board205RenderKpis()",1
    )[1].split("\nfunction board205Render()",1)[0]
    assert "setup205DeadlineKpiHtml(board, appState.seasonYear)" in ui
    assert "setup205-scheduling-secondary" in ui
    assert "Planned person-hours TBD" in ui
    assert "known task-hours" in ui
    assert "tasks scheduled" in ui
    assert "setup205WireManagementNavigation(target)" in ui
    assert "<span><strong>" not in ui, "Avoid repeated primary task badges below KPI"
