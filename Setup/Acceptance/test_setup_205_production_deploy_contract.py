from pathlib import Path


ROOT = Path(__file__).resolve().parent
PS1 = (ROOT / "run_setup_205_production_deploy.ps1").read_text(encoding="utf-8")
SH = (ROOT / "setup_205_production_deploy_server.sh").read_text(encoding="utf-8")


def test_205_production_wrapper_pins_exact_accepted_candidate_and_migration() -> None:
    assert "8161e91384cb13587fa0c92da2f80f6cf770592d" in PS1
    assert "8161e91384cb13587fa0c92da2f80f6cf770592d" in SH
    assert "V0.3.14-scheduling-board" in SH
    assert "050_add_setup_scheduling_board_foundation.sql" in PS1
    assert "050_add_setup_scheduling_board_foundation.sql" in SH
    assert "cdce6a62bb42cb7df9c32acb1dc1a5f6b6af2bb5" in PS1
    assert "cdce6a62bb42cb7df9c32acb1dc1a5f6b6af2bb5" in SH


def test_205_production_wrapper_follows_foreground_runbook_contract() -> None:
    assert "timeout --foreground --signal=TERM 3600s" in PS1
    assert "ssh -tt" in PS1
    assert "Tee-Object" not in PS1
    assert "ssh -f" not in PS1
    assert "Start-Process" not in PS1
    assert "pg_restore --list < \"$BACKUP_FILE\"" in SH
    assert "cat \"$BACKUP_FILE\" |" not in SH


def test_205_production_runner_has_fail_closed_source_rollback_boundary() -> None:
    assert "reset --hard \"$OLD_HEAD\"" in SH
    assert "Migration 050 remains installed." in SH
    assert "Do NOT auto-restore the full PostgreSQL archive" in SH
    assert "legacy command compatibility" in SH
    assert "pre-050 business data" in SH


def test_205_production_runner_preserves_no_real_2026_session_gate() -> None:
    assert "Real 2026 Setup Session exists before #205 deployment" in SH
    assert "#205 deployment created a 2026 Setup Session" in SH
    assert "SELECT count(*) FROM ops.setup_session WHERE season_year=2026" in SH
    assert '\"session\\":null' in SH


def test_205_production_runner_checks_legacy_and_new_command_compatibility() -> None:
    assert "ops.upsert_setup_work_day(text,integer,date,text,text)" in SH
    assert "ops.upsert_setup_work_day(text,integer,date,integer,text,text,text,text)" in SH
    assert "ops.set_setup_work_day_task(text,bigint,bigint,text,text,integer,integer,boolean)" in SH
    assert "ops.record_setup_task_progress(text,bigint,bigint,text,integer,integer,text,text,boolean)" in SH


def test_205_production_runner_preserves_least_privilege() -> None:
    assert "has_table_privilege('fieldwiring_app','ops.work_order','SELECT')" in SH
    assert "Forbidden broad Scheduling Board table privilege detected" in SH
    assert "PROTECTED SCHEDULING BOARD NEGATIVE PATH: PASS" in SH
