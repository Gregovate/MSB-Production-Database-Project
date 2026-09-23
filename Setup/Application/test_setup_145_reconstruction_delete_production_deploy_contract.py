from pathlib import Path

ROOT = Path(__file__).resolve().parent
ACCEPT = ROOT.parent / "Acceptance"


def read_accept(name: str) -> str:
    return (ACCEPT / name).read_text(encoding="utf-8")


def test_reconstruction_delete_production_wrapper_is_pinned_and_foreground() -> None:
    wrapper = read_accept("run_setup_145_reconstruction_delete_production_deploy.ps1")

    assert "$ExpectedBranch = 'main'" in wrapper
    assert "4ff33a16a4a22e77972ac832edb678ed467df2a0" in wrapper
    assert "9126d5e9e9732fa0d3941e505d9bf7176119b3df" in wrapper
    assert "322428bef9b0aad2dcdbbea954385a5b377b1ba8" in wrapper
    assert "merge-base --is-ancestor" in wrapper
    assert "hash-object $ServerScript" in wrapper
    assert "scp -r $localBundle" in wrapper
    assert "ssh -tt -o ServerAliveInterval=15" in wrapper
    assert "timeout --foreground --signal=TERM 3600s" in wrapper
    assert "Start-Process ssh" not in wrapper
    assert "ssh -f" not in wrapper


def test_reconstruction_delete_server_runner_is_db_only_and_runbook_ordered() -> None:
    server = read_accept("setup_145_reconstruction_delete_production_deploy_server.sh")

    assert 'ACCEPTED_CANDIDATE_SHA="4ff33a16a4a22e77972ac832edb678ed467df2a0"' in server
    assert 'MIGRATION_BLOB="9126d5e9e9732fa0d3941e505d9bf7176119b3df"' in server
    assert 'EXPECTED_SETUP_VERSION="V0.3.16-stale-ownership-cleanup"' in server

    detached = server.index("--- Detached exact-candidate regression in Production runtime ---")
    freeze = server.index("--- Freeze Setup writes for bounded DB-only mutation window ---")
    backup = server.index("--- Create and validate rollback PostgreSQL archive ---")
    preflight = server.index("--- Production database preflight for migration 055 ---")
    migrate = server.index("--- Apply exact accepted migration 055 ---")
    validate = server.index("--- Validate migration 055 least-privilege contract ---")
    restart = server.index("--- Restart and verify unchanged Setup Production runtime ---")
    live = server.index("--- Live Setup regression after DB-only migration ---")

    assert detached < freeze < backup < preflight < migrate < validate < restart < live

    assert 'sudo systemctl stop "$SETUP_SERVICE"' in server
    assert 'pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$BACKUP_FILE"' in server
    assert 'pg_restore --list < "$BACKUP_FILE"' in server
    assert 'psql_prod < "$M055"' in server
    assert 'SELECT pg_get_functiondef(' in server
    assert 'restore_prior_delete_function' in server
    assert 'psql_prod < "$FUNCTION_ROLLBACK_SQL"' in server

    assert 'merge --ff-only "$ACCEPTED_CANDIDATE_SHA"' not in server
    assert 'reset --hard "$OLD_SETUP_HEAD"' not in server
    assert '[[ "$FINAL_SETUP_HEAD" == "$OLD_SETUP_HEAD" ]]' in server

    assert "SELECT count(*) FROM ops.setup_session WHERE season_year=2026" in server
    assert "INSERT INTO ops.setup_session" not in server
    assert "create_setup_session(" not in server

    assert "cat \"$BACKUP_FILE\" |" not in server
    assert "cat \"$M055\" |" not in server


def test_reconstruction_delete_server_runner_preserves_narrow_authority() -> None:
    server = read_accept("setup_145_reconstruction_delete_production_deploy_server.sh")

    for relation in (
        "ops.setup_session_task_dependency",
        "ops.setup_session_task",
        "ref.setup_task",
        "ref.setup_task_extra_material",
        "ref.setup_task_extra_material_source",
    ):
        assert f"has_table_privilege('fieldwiring_app','{relation}','DELETE')" in server

    assert "has_function_privilege" in server
    assert "GRANT DELETE" not in server
