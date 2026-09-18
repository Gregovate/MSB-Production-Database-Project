from pathlib import Path


ROOT = Path(__file__).resolve().parent
PS1 = (ROOT / "run_setup_205_production_resume.ps1").read_text(encoding="utf-8")
SH = (ROOT / "setup_205_production_resume_server.sh").read_text(encoding="utf-8")


def test_resume_is_pinned_to_bounded_incident_state_and_accepted_target() -> None:
    assert "052d31dd4e68e13f2997f723778b88eddf9c53cf" in PS1
    assert "052d31dd4e68e13f2997f723778b88eddf9c53cf" in SH
    assert "8161e91384cb13587fa0c92da2f80f6cf770592d" in PS1
    assert "8161e91384cb13587fa0c92da2f80f6cf770592d" in SH
    assert "V0.3.13-assignment-layer" in SH
    assert "V0.3.14-scheduling-board" in SH


def test_resume_uses_source_only_runbook_and_mutates_no_database() -> None:
    assert "Setup_Source_Only_Application_Deployment_Runbook.md" in PS1
    assert "Setup_Source_Only_Application_Deployment_Runbook.md" in SH
    assert "Database mutation in this resume: NONE" in PS1
    assert "Database mutation in this resume: NONE" in SH
    assert "pg_dump" not in SH
    assert "pg_restore" not in SH
    assert "050_add_setup_scheduling_board_foundation.sql" not in SH
    assert "psql_prod <" not in SH
    assert "INSERT INTO " not in SH
    assert "UPDATE ops." not in SH
    assert "DELETE FROM " not in SH
    assert "ALTER TABLE " not in SH
    assert "CREATE TABLE " not in SH


def test_resume_uses_established_source_only_checkout_and_rollback() -> None:
    assert 'checkout --detach "$TARGET_SHA"' in SH
    assert 'checkout --detach "$OLD_HEAD"' in SH
    assert 'sudo systemctl restart "$SETUP_SERVICE"' in SH
    assert "fieldwiring.service" not in SH
    assert "msb-procedures.service" not in SH


def test_resume_runs_exact_target_and_live_regression() -> None:
    assert "worktree add --detach" in SH
    assert "'$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application" in SH
    assert "DETACHED EXACT-TARGET SETUP REGRESSION: PASS" in SH
    assert "LIVE SETUP REGRESSION: PASS" in SH


def test_resume_fingerprints_current_post_050_state_only_across_source_change() -> None:
    assert "Post-050 / pre-source Production fingerprint" in SH
    assert "Production Setup fingerprint unchanged by source-only recovery" in SH
    assert "legacy_setup_fingerprint" not in SH


def test_resume_wrapper_uses_one_foreground_ssh_session() -> None:
    assert "timeout --foreground --signal=TERM 3600s" in PS1
    assert "ssh -tt" in PS1
    assert "Start-Process" not in PS1
    assert "ssh -f" not in PS1
    assert "Tee-Object" not in PS1
