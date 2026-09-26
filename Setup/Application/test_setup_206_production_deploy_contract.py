from __future__ import annotations

from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
ACCEPT_DIR = APP_DIR.parent / "Acceptance"


def read_accept(name: str) -> str:
    return (ACCEPT_DIR / name).read_text(encoding="utf-8")


def test_206_production_wrapper_pins_exact_accepted_release() -> None:
    wrapper = read_accept("run_setup_206_pick_list_production_deploy.ps1")

    assert "$ExpectedBranch = 'main'" in wrapper
    assert "$AcceptedBrowserSha = '59148515ab361a297cd7107184662648cd10a60d'" in wrapper
    assert "$AcceptedTargetSha = 'a084b0130eae4547f26f3aaddf181b644eccd0b9'" in wrapper
    assert "$MigrationPath = 'Setup/Database/060_add_setup_pick_list_manager_override.sql'" in wrapper
    assert "$AcceptedMigrationBlob = '72137b49d78da26647e539769973641b24ee1c57'" in wrapper
    assert "$AcceptedServerRunnerBlob = '4160c4f12d264d83e23f82bce6fa0b969f751ef9'" in wrapper
    assert "V0.3.18-scheduling-board" in wrapper
    assert "V0.3.19-pick-list" in wrapper
    assert "Production_Database_Change_Deployment_Runbook.md" in wrapper
    assert "scp -r $localBundle" in wrapper
    assert "ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3" in wrapper
    assert "Start-Process ssh" not in wrapper
    assert "ssh -f" not in wrapper
    assert "ssh -N" not in wrapper


def test_206_server_runner_follows_bounded_database_then_setup_release_order() -> None:
    server = read_accept("setup_206_pick_list_production_deploy_server.sh")

    assert 'ACCEPTED_BROWSER_SHA="59148515ab361a297cd7107184662648cd10a60d"' in server
    assert 'TARGET_SHA="a084b0130eae4547f26f3aaddf181b644eccd0b9"' in server
    assert 'EXPECTED_PRE_VERSION="V0.3.18-scheduling-board"' in server
    assert 'EXPECTED_POST_VERSION="V0.3.19-pick-list"' in server
    assert 'MIGRATION_REL="Setup/Database/060_add_setup_pick_list_manager_override.sql"' in server
    assert 'MIGRATION_BLOB="72137b49d78da26647e539769973641b24ee1c57"' in server

    detached = server.index("--- Detached exact-target regression in Production runtime ---")
    freeze = server.index("--- Freeze Setup writes for bounded Production mutation window ---")
    backup = server.index("--- Create and validate rollback PostgreSQL archive ---")
    preflight = server.index("--- Production database preflight for migration 060 ---")
    migration = server.index("--- Apply reviewed migration 060 ---")
    validate = server.index("--- Validate migration 060 authority and least privilege ---")
    advance = server.index("--- Advance dedicated Setup Production checkout to exact target ---")
    restart = server.index("--- Restart and verify Setup V0.3.19 runtime ---")
    live = server.index("--- Live Setup regression ---")
    final = server.index("--- Final Production invariants ---")

    assert detached < freeze < backup < preflight < migration < validate < advance < restart < live < final
    assert 'pg_restore --list < "$BACKUP_FILE"' in server
    assert 'psql_prod < "$M060"' in server
    assert 'cat "$BACKUP_FILE" |' not in server
    assert 'cat "$M060" |' not in server


def test_206_deployment_preserves_live_2026_and_least_privilege() -> None:
    server = read_accept("setup_206_pick_list_production_deploy_server.sh")

    assert 'if [[ "$INITIAL_2026_COUNT" != "1" ]]' in server
    assert 'FINAL_2026_COUNT="$(setup_2026_count)"' in server
    assert '[[ "$FINAL_2026_COUNT" == "$INITIAL_2026_COUNT" ]]' in server

    assert "GRANT INSERT" not in server
    assert "GRANT UPDATE" not in server
    assert "GRANT DELETE" not in server
    assert "Forbidden broad Pick List override DML privilege detected" in server
    assert "'ops.setup_pick_list_override','INSERT'" in server
    assert "'ops.setup_pick_list_override','UPDATE'" in server
    assert "'ops.setup_pick_list_override','DELETE'" in server
    assert "has_function_privilege(" in server
    assert "ops.set_setup_pick_list_override(text,integer,integer,date,date,integer,text,boolean)" in server

    assert "Migration 060 unexpectedly created Pick List override rows" in server
    assert 'FINAL_OVERRIDE_COUNT="$(override_count)"' in server
    assert '[[ "$FINAL_OVERRIDE_COUNT" == "0" ]]' in server


def test_206_deployment_rolls_back_only_new_060_objects_and_setup_source() -> None:
    server = read_accept("setup_206_pick_list_production_deploy_server.sh")

    assert "rollback_migration_060()" in server
    assert "DROP FUNCTION IF EXISTS ops.set_setup_pick_list_override" in server
    assert "DROP TABLE IF EXISTS ops.setup_pick_list_override" in server
    assert "REFUSE automatic migration 060 rollback" in server
    assert 'sudo git -C "$SETUP_ROOT" checkout --detach "$OLD_HEAD"' in server
    assert 'sudo systemctl restart "$SETUP_SERVICE"' in server
    assert "pg_restore -d" not in server


def test_206_deployment_validates_release_identity_and_pick_list_runtime() -> None:
    server = read_accept("setup_206_pick_list_production_deploy_server.sh")

    assert 'PRODUCTION_VERSION = "V0.3.19-pick-list"' in server
    assert "CLIENT_BUILD = 'V0.3.19-pick-list'" in server
    assert "setup_catalog_dirty_guard.js?v=2026-09-26.1" in server
    assert "setup_pick_list.js?v=2026-09-26.5" in server
    assert "Rolling Pick List" in server
    assert "/pick-list/assets/qrcode.min.js" in server
    assert "material-readiness?season_year=2026" in server
    assert "PROTECTED PICK LIST NEGATIVE PATH: PASS" in server
    assert "AUTHENTICATED 2026 PICK LIST READ: PASS" in server
    assert "SETUP_206_PICK_LIST_PRODUCTION_DEPLOYMENT_PASS" in server
