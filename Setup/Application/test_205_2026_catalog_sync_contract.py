"""#205: two-way 2026 Catalog ↔ annual planning estimate source contract.

The executable PostgreSQL mirror is verified in the governed disposable clone,
not by a fake Python mock. These contracts catch missing direction and lost
history/season boundaries before that browser gate.
"""
from pathlib import Path

APP = Path(__file__).parent
ROOT = APP.parent


def text(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_existing_annual_save_remains_atomic_with_2026_catalog():
    migration = text("Database/076_capture_2026_reusable_task_estimates.sql")
    repo = text("Application/setup_scheduling_board_repository.py")
    for fragment in (
        "CREATE OR REPLACE FUNCTION ops.update_setup_scheduling_task_planning_info(",
        "v_season_year = 2026",
        "UPDATE ref.setup_task t",
        "UPDATE ops.setup_session_task st",
        "v_has_actual",
        "only 2026 reusable task estimates may be revised",
        "SECURITY DEFINER",
        "ref.setup_management_actor(p_email, false)",
    ):
        assert fragment in migration
    assert "def update_planning_info(" in repo
    assert "ops.update_setup_scheduling_task_planning_info" in repo
    assert "conn.commit()" in repo


def test_catalog_to_2026_annual_is_same_transaction_and_history_safe():
    migration = text("Database/076_capture_2026_reusable_task_estimates.sql")
    assert "CREATE OR REPLACE FUNCTION ref.sync_setup_task_estimates_to_2026()" in migration
    assert "CREATE TRIGGER trg_setup_task_sync_2026_planning" in migration
    assert "AFTER UPDATE OF normal_crew_min, normal_crew_max," in migration
    assert "EXECUTE FUNCTION ref.sync_setup_task_estimates_to_2026()" in migration
    assert "UPDATE ops.setup_session_task st" in migration
    assert "ss.season_year = 2026" in migration
    assert "newer.season_year > ss.season_year" in migration
    assert "st.task_origin = 'REUSABLE'" in migration
    assert "Only task estimate columns are mirrored." in migration
    assert "2026 annual task has reported work" not in migration
    assert "newer.season_year > ss.season_year" in migration
    assert "SECURITY DEFINER" in migration
    assert "REVOKE ALL ON FUNCTION ref.sync_setup_task_estimates_to_2026()" in migration
    assert "UPDATE ops.setup_task_progress" not in migration
    assert "UPDATE ops.setup_work_day_task" not in migration


def test_disposable_probes_both_directions_and_rolls_back():
    validation = text("Acceptance/setup_205_2026_catalog_estimate_disposable_validation.sql")
    assert "ops.update_setup_scheduling_task_planning_info(" in validation
    assert "ref.update_setup_task(" in validation
    assert "ref.set_setup_task_effort(" in validation
    assert "Catalog edit did not synchronize ALL four 2026 annual estimate fields" in validation
    assert "reported 2026 annual/Catalog estimate changes synchronized both directions with actual unchanged" in validation
    assert "2026 estimate sync modified reported assignment or progress history" in validation
    assert "reported task readiness remains locked" in validation
    assert "ROLLBACK;" in validation
    assert "annual and Catalog values unchanged after disposable rollback" in validation


def test_two_way_decision_is_documented_in_its_owner():
    model = (ROOT.parent / "Docs/02_Production_Database/01_System_Architecture/"
             "12_Setup_and_Deployment/engineering/Setup_Planning_Operating_Model_2026-09-08.md").read_text(encoding="utf-8")
    assert "TWO-WAY Catalog / annual planning synchronization" in model
    assert "Edit through the reusable Catalog editor" in model
    assert "2027 decision gate" in model


def test_catalog_editor_uses_one_transaction_for_estimates_and_effort():
    repo = text("Application/setup_repository.py")
    ui = text("Application/setup_production.js")
    board = text("Application/setup_scheduling_board.js")
    update = repo.split("def update_task(", 1)[1].split("\n    def update_session_task_review(", 1)[0]
    assert '"effort_level" in payload' in update
    assert "SELECT * FROM ref.update_setup_task(" in update
    assert "SELECT * FROM ref.set_setup_task_effort(%s,%s,%s)" in update
    assert update.index("SELECT * FROM ref.update_setup_task(") < update.index(
        "SELECT * FROM ref.set_setup_task_effort(%s,%s,%s)"
    ) < update.index("conn.commit()")
    save = ui.split("async function saveReusableTask()", 1)[1].split(
        "\nasync function saveAnnualReview(", 1
    )[0]
    assert "effort_level: el('edit-effort-level')" in save
    assert "/effort" not in save
    planning = board.split("async function board205PersistPlanningInfo(",1)[1].split(
        "\nasync function board205SubmitPlanningInfo(",1
    )[0]
    assert "effort_level: draft.effort_level" in planning
    assert "/effort" not in planning
