from pathlib import Path

ROOT = Path(__file__).resolve().parent
ACCEPT = ROOT.parent / "Acceptance"


def read_accept(name: str) -> str:
    return (ACCEPT / name).read_text(encoding="utf-8")


def test_setup_145_production_wrapper_is_repo_governed_and_pinned() -> None:
    wrapper = read_accept("run_setup_145_display_ownership_production_deploy.ps1")
    assert "$ExpectedBranch = 'main'" in wrapper
    assert "1b08bdd26156b67ba89ea484fdc035b0b09ffc28" in wrapper
    assert "80f6ebbcbf2946eddb1b3fe04383a2d43f61b845" in wrapper
    assert "5fbe22f7af8218a0d9ca29ca25d7d53e389e7042" in wrapper
    assert "2fbdcaef96891192f2c2fb71f59de9c4602010e8" in wrapper
    assert "git status --porcelain" in wrapper
    assert "merge-base --is-ancestor" in wrapper
    assert "hash-object $ServerScript" in wrapper
    assert "scp -r $localBundle" in wrapper
    assert "ssh -tt -o ServerAliveInterval=15" in wrapper
    assert "timeout --foreground --signal=TERM 3600s" in wrapper
    assert "Start-Process ssh" not in wrapper
    assert "ssh -f" not in wrapper


def test_setup_145_server_runner_obeys_production_runbook_order_and_scope() -> None:
    server = read_accept("setup_145_display_ownership_production_deploy_server.sh")

    assert 'TARGET_SHA="1b08bdd26156b67ba89ea484fdc035b0b09ffc28"' in server
    assert 'MERGE_SHA="80f6ebbcbf2946eddb1b3fe04383a2d43f61b845"' in server
    assert 'EXPECTED_SETUP_VERSION="V0.3.16-stale-ownership-cleanup"' in server
    assert 'MIGRATION_REL="Setup/Database/052_add_stale_display_ownership_cleanup.sql"' in server
    assert 'MIGRATION_BLOB="5fbe22f7af8218a0d9ca29ca25d7d53e389e7042"' in server
    assert 'fetch origin "$TARGET_REF:refs/remotes/origin/$TARGET_REF"' in server

    detached = server.index("--- Detached exact-candidate regression in Production runtime ---")
    freeze = server.index("--- Freeze Setup writes for bounded Production mutation window ---")
    backup = server.index("--- Create and validate rollback PostgreSQL archive ---")
    preflight = server.index("--- Production database preflight for migration 052 ---")
    migrate = server.index("--- Apply reviewed migration 052 ---")
    validate = server.index("--- Validate migration 052 least-privilege contract ---")
    advance = server.index("--- Fast-forward dedicated Setup checkout to exact accepted SHA ---")
    live_regression = server.index("--- Live regression while Setup service remains stopped ---")
    restart = server.index("--- Restart and verify Setup Production runtime ---")
    assert detached < freeze < backup < preflight < migrate < validate < advance < live_regression < restart

    assert 'sudo systemctl stop "$SETUP_SERVICE"' in server
    assert 'pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$BACKUP_FILE"' in server
    assert 'pg_restore --list < "$BACKUP_FILE"' in server
    assert 'cat "$BACKUP_FILE" |' not in server
    assert 'psql_prod < "$M052"' in server
    assert 'cat "$M052" |' not in server

    assert "ref.clear_setup_task_display_owner(text,bigint,bigint)" in server
    assert "GRANT" not in server
    assert "has_function_privilege" in server
    assert "has_table_privilege('fieldwiring_app','ref.setup_task_display','DELETE')" in server
    assert "DROP FUNCTION IF EXISTS ref.clear_setup_task_display_owner(text,bigint,bigint)" in server

    assert "SELECT count(*) FROM ops.setup_session WHERE season_year=2026" in server
    assert "INSERT INTO ops.setup_session" not in server
    assert "create_setup_session(" not in server

    assert 'sudo git -C "$SETUP_ROOT" merge --ff-only "$TARGET_SHA"' in server
    assert '[[ "$FINAL_HEAD" == "$TARGET_SHA" ]]' in server
    assert "contextmenu" in server
    assert "Remove stale ownership" in server
    assert "shown as Missing owner until you assign it again" in server
    assert "Unauthenticated ownership DELETE status" in server


def test_setup_145_server_runner_fail_closed_recovery_is_narrow() -> None:
    server = read_accept("setup_145_display_ownership_production_deploy_server.sh")
    assert "--- FAIL-CLOSED RECOVERY ---" in server
    assert 'reset --hard "$OLD_HEAD"' in server
    assert "rollback_migration_052" in server
    assert "DROP FUNCTION IF EXISTS ref.clear_setup_task_display_owner(text,bigint,bigint)" in server
    assert "pg_restore" in server
    assert "pg_restore -d" not in server
    assert "DROP TABLE" not in server
