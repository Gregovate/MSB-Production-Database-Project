from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
SETUP_DIR = APP_DIR.parent
ACCEPTANCE_DIR = SETUP_DIR / "Acceptance"


def read_acceptance(name: str) -> str:
    return (ACCEPTANCE_DIR / name).read_text(encoding="utf-8")


def test_175_132_production_wrapper_pins_exact_browser_accepted_target() -> None:
    wrapper = read_acceptance("run_setup_175_132_production_deploy.ps1")

    assert "$ExpectedBranch = 'issue-175-captain-work-list-v2'" in wrapper
    assert "$AcceptedTargetSha = '15864bcce17d0b59c8396e99178e7113fc368b2d'" in wrapper
    assert "$MigrationPath = 'Setup/Database/061_add_live_assignment_report_work.sql'" in wrapper
    assert "$AcceptedMigrationBlob = '75a5daace003a229d15be1092535f020ffb010d8'" in wrapper
    assert "$AcceptedServerRunnerBlob = 'b0fb78b63cfdded2bdf84fbffb36aab0fb42f03f'" in wrapper
    assert "merge-base --is-ancestor $AcceptedTargetSha HEAD" in wrapper
    assert "git -C $RepoRoot hash-object $ServerScript" in wrapper
    assert "setup_next_pass.js?v=2026-09-26.10" in wrapper
    assert "setup_next_pass.css?v=2026-09-26.10" in wrapper


def test_175_132_wrapper_uses_one_bundle_and_foreground_ssh() -> None:
    wrapper = read_acceptance("run_setup_175_132_production_deploy.ps1")

    assert "& scp -r $localBundle" in wrapper
    assert wrapper.count("& scp ") == 1
    assert wrapper.count("& ssh ") == 1
    assert "ssh -tt" in wrapper
    assert "ServerAliveInterval=15" in wrapper
    assert "timeout --foreground --signal=TERM 3600s" in wrapper
    assert "Start-Process" not in wrapper
    assert "Tee-Object" not in wrapper
    assert "ssh -f" not in wrapper
    assert ".Replace($cr + $lf, $lf).Replace($cr, $lf)" in wrapper


def test_175_132_server_runner_follows_production_database_change_runbook() -> None:
    server = read_acceptance("setup_175_132_production_deploy_server.sh")

    for token in (
        'TARGET_SHA="15864bcce17d0b59c8396e99178e7113fc368b2d"',
        'TARGET_REF="issue-175-captain-work-list-v2"',
        'MIGRATION_REL="Setup/Database/061_add_live_assignment_report_work.sql"',
        'MIGRATION_BLOB="75a5daace003a229d15be1092535f020ffb010d8"',
        "trap cleanup EXIT HUP INT TERM",
        "pg_dump -U",
        'pg_restore --list < "$BACKUP_FILE"',
        'merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"',
        'worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"',
        "-m pytest -q -p no:cacheprovider Setup/Application",
        'sudo systemctl stop "$SETUP_SERVICE"',
        'psql_prod < "$M061"',
        'sudo git -C "$SETUP_ROOT" checkout --detach "$TARGET_SHA"',
        "LIVE SETUP REGRESSION: PASS",
        "SETUP_175_132_REPORT_WORK_PRODUCTION_DEPLOYMENT_PASS",
    ):
        assert token in server

    assert "cat " + '"$BACKUP_FILE"' + " |" not in server
    assert "cat " + '"$M061"' + " |" not in server
    assert "reset --hard" not in server


def test_175_132_runner_has_bounded_pre061_rollback() -> None:
    server = read_acceptance("setup_175_132_production_deploy_server.sh")

    for token in (
        "rollback_migration_061()",
        "pg_get_functiondef('ref.setup_execution_actor(text,bigint)'::regprocedure)",
        "pg_get_functiondef('ops.record_setup_task_progress(text,bigint,bigint,text,integer,integer,text,text,boolean)'::regprocedure)",
        "DROP FUNCTION IF EXISTS ops.correct_setup_task_progress",
        "DROP FUNCTION IF EXISTS ops.record_setup_task_progress",
        "DROP COLUMN IF EXISTS performed_on",
        "DROP COLUMN IF EXISTS duration_minutes",
        "DROP COLUMN IF EXISTS percent_complete",
        'psql_prod < "$OLD_ACTOR_SQL"',
        'psql_prod < "$OLD_PROGRESS_SQL"',
        "REFUSE automatic migration 061 rollback",
        "Setup service will remain stopped",
    ):
        assert token in server


def test_175_132_runner_validates_least_privilege_and_no_data_rewrite() -> None:
    server = read_acceptance("setup_175_132_production_deploy_server.sh")

    for token in (
        "has_function_privilege(",
        "'ops.record_setup_task_progress(text,bigint,date,integer,integer,integer,integer,text,text,bigint,bigint,text)'",
        "'ops.correct_setup_task_progress(text,bigint,date,integer,integer,integer,integer,text,text)'",
        "Forbidden broad setup_task_progress DML privilege detected",
        "Migration 061 unexpectedly populated new progress fields on existing rows",
        "PASS: migration 061 preserved existing Setup business data/progress rows",
        "Final Setup business fingerprint:",
        "Final Setup progress row count:",
    ):
        assert token in server


def test_175_132_runner_checks_live_browser_contract_without_writing() -> None:
    server = read_acceptance("setup_175_132_production_deploy_server.sh")

    for token in (
        "setup_next_pass.js?v=2026-09-26.10",
        "setup_next_pass.css?v=2026-09-26.10",
        "Report Correction",
        "Correct report",
        "msb.setup.performCaptainFilter.v1.",
        "Work completed on",
        "Direct unauthenticated scheduling-board API status",
        "AUTHENTICATED 2026 SCHEDULING BOARD READ: PASS",
    ):
        assert token in server
