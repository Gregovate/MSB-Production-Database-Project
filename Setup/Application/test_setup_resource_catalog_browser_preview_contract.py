from __future__ import annotations

from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
REPO_ROOT = APP_DIR.parents[1]
LAUNCHER = REPO_ROOT / "Setup" / "Acceptance" / "run_setup_resource_catalog_browser_preview.ps1"


def test_resource_catalog_preview_pins_exact_candidate_and_branch() -> None:
    text = LAUNCHER.read_text(encoding="utf-8")
    assert "d74202002e6845b291dc937697f4589d3f4be6c3" in text
    assert "agent/setup-152-resource-catalog" in text
    assert "run_setup_source_only_browser_preview.ps1" in text
    assert "setup_session_browser_preview_cleanup_server.sh" in text


def test_resource_catalog_preview_applies_only_issue_152_migration_to_clone() -> None:
    text = LAUNCHER.read_text(encoding="utf-8")
    assert "027_add_setup_resource_catalog_management.sql" in text
    assert "Issue #152 resource-catalog migration on disposable clone: PASS" in text
    assert "ref.update_setup_resource(text,integer,text,text,text,boolean,integer)" in text
    assert "broad resource-table DML" in text
    assert "Existing resource display_order values were unexpectedly rewritten" in text
    assert "026_add_setup_dependency_order.sql" not in text


def test_resource_catalog_preview_keeps_hardened_interactive_cleanup() -> None:
    text = LAUNCHER.read_text(encoding="utf-8")
    assert "timeout --foreground --signal=TERM 28800s" in text
    assert "ServerAliveInterval=15" in text
    assert "ServerAliveCountMax=3" in text
    assert "EXIT HUP INT TERM" in text


def test_resource_catalog_preview_checklist_covers_compact_picker_acceptance() -> None:
    text = LAUNCHER.read_text(encoding="utf-8")
    for marker in (
        "Client V0.3.10",
        "compact Resource picker",
        "does NOT show the full catalog editor/create forms by default",
        "name-oriented",
        "Manage Resource Catalog",
        "top Manage button is hidden while open",
        "colored Close Resource Catalog button sits directly beside Save Catalog Resource",
        "Name is the practical default browse sort",
        "setup_resource_id stays the same",
        "Optional display order",
        "different case or repeated/outer spaces",
        "possible existing catalog matches",
        "disposable unique resource",
        "Production remains unchanged",
    ):
        assert marker in text


def test_resource_catalog_preview_detached_regression_uses_candidate_contained_tests_only() -> None:
    text = LAUNCHER.read_text(encoding="utf-8")
    assert "test_setup_resource_management_contract.py" in text
    assert "test_setup_dirty_edit_guard_contract.py" in text
    assert "test_setup_resource_picker_compact_contract.py" not in text
    assert "do not exist at the pinned" in text
