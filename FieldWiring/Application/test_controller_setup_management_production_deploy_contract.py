from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = BASE_DIR.parent.parent
ACCEPT = REPO_ROOT / "Controllers" / "Acceptance"
TARGET_SHA = "2fd2067958cc0a903260fe6f089f88ae63a857f1"


def test_production_runner_pins_accepted_target_and_migrations_from_target_worktree() -> None:
    source = (
        ACCEPT / "controller_setup_management_production_deploy_server.sh"
    ).read_text(encoding="utf-8")

    assert f'TARGET_SHA="{TARGET_SHA}"' in source
    assert 'TARGET_REF="agent/controller-inventory-ref-sandbox"' in source
    assert 'worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"' in source
    assert 'MIGRATION_023="$CANDIDATE_WORKTREE/Controllers/Database/023_create_controller_management_commands.sql"' in source
    assert 'MIGRATION_024="$CANDIDATE_WORKTREE/Controllers/Database/024_harden_controller_assignment_capability.sql"' in source
    assert "EXPECTED_FIELDWIRING_VERSION=\"V0.4.0\"" in source


def test_production_runner_obeys_backup_before_mutation_and_direct_stdin_rules() -> None:
    source = (
        ACCEPT / "controller_setup_management_production_deploy_server.sh"
    ).read_text(encoding="utf-8")

    backup_pos = source.index('echo "--- Create and verify rollback PostgreSQL archive ---"')
    preflight_pos = source.index('echo "--- Production database preflight ---"')
    migration_pos = source.index('echo "--- Apply accepted migrations 023 / 024 ---"')
    checkout_pos = source.index('echo "--- Fast-forward shared production checkout ---"')
    assert backup_pos < preflight_pos < migration_pos < checkout_pos

    assert 'pg_restore --list < "$BACKUP_FILE"' in source
    assert '< "$MIGRATION_023"' in source
    assert '< "$MIGRATION_024"' in source
    assert 'cat "$BACKUP_FILE" |' not in source
    assert 'cat "$MIGRATION_023" |' not in source
    assert 'cat "$MIGRATION_024" |' not in source


def test_production_runner_preserves_least_privilege_and_fail_closed_rollback() -> None:
    source = (
        ACCEPT / "controller_setup_management_production_deploy_server.sh"
    ).read_text(encoding="utf-8")

    assert "has_table_privilege('fieldwiring_app', 'ref.controller', 'INSERT')" in source
    assert "has_table_privilege('fieldwiring_app', 'ref.controller', 'UPDATE')" in source
    assert "has_table_privilege('fieldwiring_app', 'ref.controller_display', 'INSERT')" in source
    assert "fieldwiring_app must not execute internal controller_management_actor" in source
    assert "rollback_management_functions" in source
    assert "DROP FUNCTION IF EXISTS ref.controller_management_options(text);" in source
    assert "DROP FUNCTION IF EXISTS ref.controller_management_actor(text);" in source
    assert 'sudo git -C "$FIELDWIRING_ROOT" reset --hard "$OLD_HEAD"' in source
    assert "APP_ADVANCED=0" in source
    assert "DB_CHANGE_STARTED=0" in source


def test_production_runner_requires_live_regression_security_and_invariant_checks() -> None:
    source = (
        ACCEPT / "controller_setup_management_production_deploy_server.sh"
    ).read_text(encoding="utf-8")

    assert "python -m pytest" in source
    assert "/api/controller-access" in source
    assert "/api/controller-management/options" in source
    assert 'if [[ "$ACCESS_CODE" != "401" ]]' in source
    assert 'if [[ "$MANAGE_CODE" != "401" ]]' in source
    assert 'FINAL_FP="$(prod_fingerprint)"' in source
    assert 'FINAL_FP" != "$PROD_BEFORE' in source


def test_windows_wrapper_uses_one_scp_and_one_foreground_ssh_and_clean_worktree() -> None:
    source = (
        ACCEPT / "run_controller_setup_management_production_deploy.ps1"
    ).read_text(encoding="utf-8")

    assert TARGET_SHA in source
    assert "$ExpectedBranch = 'agent/controller-inventory-ref-sandbox'" in source
    assert "status --porcelain" in source
    assert source.count("& scp -r") == 1
    assert source.count("& ssh -tt") == 1
    assert "bash -n" in source
    assert "timeout --signal=TERM 1800s" in source
    assert "Start-Process" not in source
    assert "Tee-Object" not in source
    assert "ssh -f" not in source
    assert "ssh -N" not in source
