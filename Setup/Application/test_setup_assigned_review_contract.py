from pathlib import Path


ROOT = Path(__file__).resolve().parent
DB_ROOT = ROOT.parent / "Database"


def read(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")


def read_db(name: str) -> str:
    return (DB_ROOT / name).read_text(encoding="utf-8")


def test_assigned_browser_asset_is_loaded_after_training_ux():
    html = read("production.html")
    training_index = html.index("setup_training_ux.js?v=2026-09-08.1")
    assigned_index = html.index("setup_assigned_review.js?v=2026-09-08.2")
    assert assigned_index > training_index
    host = read("production_backend.py")
    assert '"setup_assigned_review.js"' in host


def test_assigned_items_leave_default_active_queue_but_remain_filterable():
    js = read("setup_assigned_review.js")
    assert "option.value = 'ASSIGNED'" in js
    assert "option.textContent = 'Matched to Reusable Task'" in js
    assert "if (filter !== '') return" in js
    assert "task?.verification_state === 'ASSIGNED'" in js
    assert "Confirmed matches are available from the Matched to Reusable Task filter" in js


def test_manager_confirms_current_annual_item_matches_current_reusable_task():
    js = read("setup_assigned_review.js")
    assert "Confirm Reusable Task Match" in js
    assert "Current reusable scope:" in js
    assert "does NOT move the task or change its Stage / Scene scope" in js
    assert "setup-reusable-match-target" in js
    assert "2025 item → reusable task match" in js
    assert "verification_state: 'ASSIGNED'" in js
    assert "setup_session_task_id" in js
    assert "commandOptions('PATCH', payload)" in js
    assert "Its Stage / Scene scope was not changed" in js


def test_assigned_database_state_is_terminal_reconciliation_not_execution():
    sql = read_db("021_add_setup_assigned_reconciliation_state.sql")
    assert "ASSIGNED" in sql
    assert "reconciliation state, not an execution/completion state" in sql
    assert "UNVERIFIED', 'VERIFIED', 'NEEDS_CORRECTION', 'ASSIGNED" in sql
    assert "ops.update_setup_session_task_review" in sql
    assert "execution_status" not in sql
