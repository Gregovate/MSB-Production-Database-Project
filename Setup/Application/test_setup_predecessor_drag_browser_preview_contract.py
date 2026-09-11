from __future__ import annotations

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ACCEPTANCE_DIR = REPO_ROOT / "Setup" / "Acceptance"


def test_predecessor_drag_preview_pins_exact_candidate_and_branch() -> None:
    launcher = (ACCEPTANCE_DIR / "run_setup_predecessor_drag_browser_preview.ps1").read_text(encoding="utf-8")

    assert "4cada529a0cd714f5da2cb43f5dffb016e40b7ac" in launcher
    assert "agent/setup-shift-drag-predecessor-151" in launcher
    assert "run_setup_source_only_browser_preview.ps1" in launcher
    assert "test_setup_predecessor_drag_contract.py" in launcher
    assert "test_setup_dirty_edit_guard_contract.py" in launcher


def test_predecessor_drag_preview_checklist_covers_direction_cycle_and_normal_drag() -> None:
    launcher = (ACCEPTANCE_DIR / "run_setup_predecessor_drag_browser_preview.ps1").read_text(encoding="utf-8")

    for required in (
        "Hold Shift BEFORE starting the drag",
        "Dependent",
        "Prerequisite target",
        "A depends on B",
        "not a duplicate",
        "circular-dependency error",
        "ordinary drag WITHOUT Shift",
        "manual prerequisite editor",
        "empty Stage/Scene space",
    ):
        assert required in launcher
