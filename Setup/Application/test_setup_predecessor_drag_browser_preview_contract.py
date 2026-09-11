from __future__ import annotations

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ACCEPTANCE_DIR = REPO_ROOT / "Setup" / "Acceptance"


def test_predecessor_drag_preview_pins_exact_candidate_branch_and_migration() -> None:
    launcher = (ACCEPTANCE_DIR / "run_setup_predecessor_drag_browser_preview.ps1").read_text(encoding="utf-8")

    assert "55478f98f760473b65b5d700a84c868285022ab7" in launcher
    assert "agent/setup-shift-drag-predecessor-151" in launcher
    assert "run_setup_source_only_browser_preview.ps1" in launcher
    assert "test_setup_predecessor_drag_contract.py" in launcher
    assert "test_setup_prerequisite_editor_contract.py" in launcher
    assert "test_setup_dirty_edit_guard_contract.py" in launcher
    assert "026_add_setup_dependency_order.sql" in launcher
    assert "prerequisite-order migration on disposable clone: PASS" in launcher
    assert "ref.reorder_setup_task_dependencies(text,bigint,bigint[])" in launcher
    assert "broad prerequisite table DML" in launcher
    assert "Client V0.3.9" in launcher


def test_predecessor_drag_preview_checklist_covers_full_prerequisite_workflow() -> None:
    launcher = (ACCEPTANCE_DIR / "run_setup_predecessor_drag_browser_preview.ps1").read_text(encoding="utf-8")

    for required in (
        "hold Shift BEFORE pressing the left mouse button",
        "neither task moves",
        "no duplicate relationship",
        "circular-dependency error",
        "ONE prerequisite list only",
        "Up, Down, and Remove",
        "same new order",
        "order persists",
        "stays removed",
        "manual Add form",
        "ordinary drag WITHOUT Shift",
        "empty Stage/Scene space",
        "review/display order only",
    ):
        assert required in launcher


def test_predecessor_drag_preview_recovers_stale_source_preview_safely() -> None:
    launcher = (ACCEPTANCE_DIR / "run_setup_predecessor_drag_browser_preview.ps1").read_text(encoding="utf-8")
    cleanup = (ACCEPTANCE_DIR / "setup_session_browser_preview_cleanup_server.sh").read_text(encoding="utf-8")

    for required in (
        "setup_session_browser_preview_cleanup_server.sh",
        "source-only stale-cleanup injection point",
        "ServerAliveInterval=15",
        "ServerAliveCountMax=3",
        "timeout --signal=TERM 28800s",
        "trap cleanup EXIT HUP INT TERM",
    ):
        assert required in launcher

    for required in (
        "governed Production listener and must never be cleaned as preview state",
        "/tmp/setup_session_browser_preview_entry.py",
        "fieldwiring",
        "msb-setup-source-preview-candidate-",
        "msb-setup-source-preview-",
        "unexpected process; refusing to kill it",
        "Reports and Flask logs are retained as acceptance evidence",
        "PASS: preview port $PREVIEW_PORT is free",
    ):
        assert required in cleanup
