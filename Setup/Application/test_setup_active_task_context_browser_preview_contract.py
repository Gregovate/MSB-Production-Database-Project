from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
REPO_ROOT = APP_DIR.parents[1]
LAUNCHER = REPO_ROOT / "Setup" / "Acceptance" / "run_setup_active_task_context_browser_preview.ps1"


def launcher_text() -> str:
    return LAUNCHER.read_text(encoding="utf-8")


def test_active_task_preview_pins_exact_candidate_and_branch() -> None:
    text = launcher_text()
    assert "28ad2d28addd47f8f086ed3b2e53468b453dbe13" in text
    assert "agent/setup-active-task-context-169" in text
    assert "run_setup_source_only_browser_preview.ps1" in text


def test_active_task_preview_uses_hardened_browser_review_lifecycle() -> None:
    text = launcher_text()
    assert "setup_session_browser_preview_cleanup_server.sh" in text
    assert "timeout --foreground --signal=TERM 28800s" in text
    assert "ServerAliveInterval=15" in text
    assert "ServerAliveCountMax=3" in text
    assert "trap - EXIT HUP INT TERM" in text
    assert "trap cleanup EXIT HUP INT TERM" in text


def test_active_task_preview_runs_focused_regression_present_in_candidate() -> None:
    text = launcher_text()
    for test_name in (
        "test_setup_production_contract.py",
        "test_setup_dirty_edit_guard_contract.py",
        "test_setup_task_detail_compact_contract.py",
        "test_setup_predecessor_drag_contract.py",
        "test_setup_prerequisite_editor_contract.py",
        "test_setup_resource_management_contract.py",
        "test_setup_active_task_context_contract.py",
    ):
        assert test_name in text


def test_active_task_preview_is_source_only() -> None:
    text = launcher_text()
    assert "No migration is applied" in text
    assert "027_add_setup_resource_catalog_management.sql" not in text
    assert "026_add_setup_dependency_order.sql" not in text


def test_active_task_preview_checklist_covers_issue_169_acceptance() -> None:
    text = launcher_text()
    for marker in (
        "Client V0.3.11",
        "Active task",
        "entire scroll",
        "Save and continue",
        "Discard and continue",
        "Stay on this task",
        "light mode",
        "dark mode",
        "Resource Catalog/Equipment controls",
        "do not show a stale Active task identity",
        "Production remains unchanged",
    ):
        assert marker in text
