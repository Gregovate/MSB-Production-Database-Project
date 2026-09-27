from pathlib import Path

ROOT = Path(__file__).resolve().parent
ACCEPT = ROOT.parent / "Acceptance"


def read_accept(name: str) -> str:
    return (ACCEPT / name).read_text(encoding="utf-8")


def test_122_launch_wrapper_is_merged_main_only_and_pinned() -> None:
    wrapper = read_accept("run_setup_122_2026_launch_unblock_production_deploy.ps1")

    assert "$ExpectedBranch = 'main'" in wrapper
    assert "06a6536d92db5c7352beeed496563ed9bfdb7146" in wrapper
    assert "144528c0d0df195ad2dd43cd352078926c055456" in wrapper
    assert "053570d192345caa5708ccc61f69674c17c25989" in wrapper
    assert "221498abaea8ab923c06d287ba2d94d80007d5e7" in wrapper
    assert "merge-base --is-ancestor" in wrapper
    assert "hash-object $ServerScript" in wrapper
    assert "scp -r $localBundle" in wrapper
    assert "ssh -tt -o ServerAliveInterval=15" in wrapper
    assert "timeout --foreground --signal=TERM 3600s" in wrapper
    assert "Start-Process" not in wrapper
    assert "ssh -f" not in wrapper


def test_122_launch_runner_is_exact_candidate_and_exact_migration_set() -> None:
    server = read_accept("setup_122_2026_launch_unblock_production_deploy_server.sh")

    assert 'TARGET_REF="main"' in server
    assert 'TARGET_SHA="06a6536d92db5c7352beeed496563ed9bfdb7146"' in server
    assert 'EXPECTED_SETUP_VERSION="V0.3.17-performance-trace"' in server
    assert 'M057_REL="Setup/Database/057_enable_2026_unworked_task_deletion.sql"' in server
    assert 'M057_BLOB="053570d192345caa5708ccc61f69674c17c25989"' in server
    assert 'M058_REL="Setup/Database/058_preserve_catalog_review_on_annual_launch.sql"' in server
    assert 'M058_BLOB="221498abaea8ab923c06d287ba2d94d80007d5e7"' in server
    assert 'fetch origin "$TARGET_REF:refs/remotes/origin/$TARGET_REF"' in server
    assert 'merge-base --is-ancestor "$TARGET_SHA" "origin/$TARGET_REF"' in server
    assert 'merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"' in server


def test_122_launch_runner_obeys_production_runbook_order() -> None:
    server = read_accept("setup_122_2026_launch_unblock_production_deploy_server.sh")

    detached = server.index("--- Detached exact-candidate regression in Production runtime ---")
    freeze = server.index("--- Freeze Setup writes for bounded Production mutation window ---")
    backup = server.index("--- Create and validate rollback PostgreSQL archive ---")
    preflight = server.index("--- Production database preflight for migrations 057 / 058 ---")
    rollback_capture = server.index("NARROW FUNCTION ROLLBACK CAPTURE: PASS")
    m057 = server.index("--- Apply reviewed migration 057 ---")
    m058 = server.index("--- Apply reviewed migration 058 ---")
    validate = server.index("--- Validate #122 launch least-privilege / no-session contract ---")
    advance = server.index("--- Fast-forward dedicated Setup checkout to exact accepted SHA ---")
    live = server.index("--- Live regression while Setup service remains stopped ---")
    restart = server.index("--- Restart and verify Setup Production runtime ---")

    assert detached < freeze < backup < preflight < rollback_capture < m057 < m058 < validate < advance < live < restart

    assert 'pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$BACKUP_FILE"' in server
    assert 'pg_restore --list < "$BACKUP_FILE"' in server
    assert 'cat "$BACKUP_FILE" |' not in server
    assert 'psql_prod < "$M057"' in server
    assert 'psql_prod < "$M058"' in server
    assert 'cat "$M057" |' not in server
    assert 'cat "$M058" |' not in server


def test_122_launch_runner_keeps_session_creation_out_of_deployment() -> None:
    server = read_accept("setup_122_2026_launch_unblock_production_deploy_server.sh")

    assert "2026 Setup Session creation:          FORBIDDEN DURING DEPLOYMENT" in server
    assert 'SELECT count(*) FROM ops.setup_session WHERE season_year=2026' in server
    assert "INSERT INTO ops.setup_session" not in server
    assert "PERFORM ops.create_setup_session" not in server
    assert "SELECT * FROM ops.create_setup_session" not in server
    assert '[[ "$FINAL_2026" == "0" ]]' in server


def test_122_launch_runner_preserves_least_privilege() -> None:
    server = read_accept("setup_122_2026_launch_unblock_production_deploy_server.sh")

    assert "ops.delete_unworked_setup_season_task(text,bigint)" in server
    assert "ref.delete_setup_reconstruction_task(text,bigint)" in server
    assert "has_function_privilege" in server
    assert "has_table_privilege('fieldwiring_app','ops.setup_session_task','DELETE')" in server
    assert "has_table_privilege('fieldwiring_app','ops.setup_work_day_task','DELETE')" in server
    assert "has_table_privilege('fieldwiring_app','ref.setup_task','DELETE')" in server
    assert "has_table_privilege('fieldwiring_app','ref.setup_task_display','DELETE')" in server
    assert "has_table_privilege('fieldwiring_app','ref.setup_task_container_support','DELETE')" in server


def test_122_launch_runner_has_narrow_function_and_source_rollback() -> None:
    server = read_accept("setup_122_2026_launch_unblock_production_deploy_server.sh")

    assert "capture_function_rollback" in server
    assert "pg_get_functiondef('ref.delete_setup_reconstruction_task(text,bigint)'::regprocedure)" in server
    assert "pg_get_functiondef('ops.create_setup_session(text,integer,text)'::regprocedure)" in server
    assert "pg_get_functiondef('ref.create_setup_task(text,text,integer,text,integer,integer,integer,integer,text,text,text,text)'::regprocedure)" in server
    assert "DROP FUNCTION IF EXISTS ops.delete_unworked_setup_season_task(text,bigint);" in server
    assert 'psql_prod < "$ROLLBACK_SQL"' in server
    assert 'reset --hard "$OLD_HEAD"' in server
    assert "pg_restore -d" not in server


def test_122_launch_runner_regresses_exact_candidate_before_and_after_promotion() -> None:
    server = read_accept("setup_122_2026_launch_unblock_production_deploy_server.sh")

    assert "worktree add --detach" in server
    assert "'$PYTHON' -m pytest -q -p no:cacheprovider Setup/Application" in server
    assert "DETACHED EXACT-TARGET SETUP REGRESSION: PASS" in server
    assert "LIVE SETUP REGRESSION: PASS" in server
    assert 'sudo git -C "$SETUP_ROOT" merge --ff-only "$TARGET_SHA"' in server
    assert '[[ "$FINAL_HEAD" == "$TARGET_SHA" ]]' in server


def test_122_launch_runner_keeps_protected_api_negative_path() -> None:
    server = read_accept("setup_122_2026_launch_unblock_production_deploy_server.sh")

    assert "Unauthenticated create-session status" in server
    assert "X-MSB-Setup-Command: 1" in server
    assert 'if [[ "$UNAUTH_CODE" != "401" && "$UNAUTH_CODE" != "404" ]]' in server
    assert "PROTECTED API NEGATIVE PATH: PASS" in server
