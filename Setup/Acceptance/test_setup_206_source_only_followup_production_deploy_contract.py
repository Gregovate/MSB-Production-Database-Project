from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent
PS1 = (ROOT / "run_setup_206_source_only_followup_production_deploy.ps1").read_text(encoding="utf-8")
SH = (ROOT / "setup_206_source_only_followup_production_deploy_server.sh").read_text(encoding="utf-8")


def test_206_source_only_followup_is_pinned_to_browser_accepted_target() -> None:
    target = "3cedba88283e4766932ae7905034856a2b9baa00"
    live = "947b86a9598584717167cce094cd78d99e9a71e7"
    assert target in PS1 and target in SH
    assert live in PS1 and live in SH
    assert "agent/setup-206-tablet-material-audit" in PS1 and "agent/setup-206-tablet-material-audit" in SH
    assert "V0.3.20-material-authority" in PS1 and "V0.3.20-material-authority" in SH


def test_206_source_only_followup_uses_source_only_runbook_and_no_migrations() -> None:
    for text in (PS1, SH):
        assert "Setup_Source_Only_Application_Deployment_Runbook.md" in text
        assert "Database migration: NONE" in text
    assert "pg_dump" not in SH
    assert "pg_restore" not in SH
    assert "Setup/Database/063_" not in SH
    assert "Setup/Database/064_" not in SH
    assert "psql_prod <" not in SH
    assert "PostgreSQL rollback archive: NOT REQUIRED / NOT CREATED" in SH


def test_206_source_only_followup_proves_forward_ancestry_and_diff_boundary() -> None:
    assert 'merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"' in SH
    assert 'merge-base --is-ancestor "$TARGET_SHA" "origin/$TARGET_REF"' in SH
    assert 'diff --name-only "$OLD_HEAD..$TARGET_SHA"' in SH
    assert "^Setup/Database/" in SH
    assert "SOURCE-ONLY DIFF BOUNDARY: PASS" in SH


def test_206_source_only_followup_runs_exact_target_and_live_regressions() -> None:
    assert 'worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"' in SH
    assert "'$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application" in SH
    assert "DETACHED EXACT-TARGET SETUP REGRESSION: PASS" in SH
    assert "LIVE SETUP REGRESSION: PASS" in SH


def test_206_source_only_followup_checks_accepted_ui_repairs() -> None:
    for marker in (
        "setup_catalog_dirty_guard.js?v=2026-09-29.1",
        "setup_extra_materials.js?v=2026-09-29.1",
        "setup_next_pass.js?v=2026-09-29.1",
        "setup_kit_inventory.css?v=2026-09-29.1",
        "setup_kit_inventory.js?v=2026-09-29.1",
        "Client V0.3.20",
        "Already linked — use Change",
        "Task / Kit spec differs. Material identity and source relationship are already linked.",
        "Loading reusable Catalog organization…",
    ):
        assert marker in SH or marker in PS1

    assert '! grep -Fq "priorNextRenderLibrary"' in SH


def test_206_source_only_followup_restarts_only_setup_and_rolls_back_source_only() -> None:
    assert 'sudo systemctl restart "$SETUP_SERVICE"' in SH
    assert "systemctl stop" not in SH
    for forbidden in (
        "fieldwiring.service",
        "directus.service",
        "postgresql.service",
        "nginx.service",
        "reboot",
    ):
        assert forbidden not in SH

    assert 'checkout --detach "$OLD_HEAD"' in SH
    assert "PostgreSQL was not mutated." in SH


def test_206_source_only_followup_fingerprints_core_and_material_data() -> None:
    assert "core_fingerprint()" in SH
    assert "material_fingerprint()" in SH
    assert "PRE-MUTATION DATA STABILITY: PASS" in SH
    assert "source-only deployment changed core Setup data" in SH
    assert "source-only deployment changed material authority data" in SH
    assert "setup_2026_count()" in SH


def test_206_source_only_followup_requires_real_protected_route_after_wrapper() -> None:
    assert "Protected /setup/ operator validation: REQUIRED NEXT" in SH


def test_206_windows_wrapper_uses_ascii_structural_catalog_markers() -> None:
    assert "function renderNextLibraryReadiness()" in PS1
    assert "Retry Catalog Organization" in PS1
    assert "Loading reusable Catalog organization…" not in PS1
    assert "priorNextRenderLibrary" in PS1


def test_206_windows_wrapper_updates_remote_tracking_target_ref() -> None:
    assert "refs/remotes/origin/" in PS1
    assert "$AcceptedTargetRef + ':refs/remotes/origin/' + $AcceptedTargetRef" in PS1
