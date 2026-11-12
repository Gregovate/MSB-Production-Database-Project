from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
SETUP_DIR = APP_DIR.parent
ACCEPT = SETUP_DIR / "Acceptance"
TARGET_SHA = "aaf7de1c1d457b3dfaafe061f084a044cdf2abb7"


def read_acceptance(name: str) -> str:
    return (ACCEPT / name).read_text(encoding="utf-8")


def test_production_wrapper_uses_one_bundle_transfer_and_foreground_ssh() -> None:
    wrapper = read_acceptance("run_setup_training_production_deploy.ps1")
    assert wrapper.count("scp -r") == 1
    assert wrapper.count("ssh -tt") == 1
    assert "Tee-Object" not in wrapper
    assert "Start-Process" not in wrapper
    assert "ssh -f" not in wrapper
    assert "ssh -N" not in wrapper
    assert '.Replace("`r`n", "`n")' in wrapper
    assert "UTF8Encoding" in wrapper
    assert TARGET_SHA in wrapper
    assert "Production_Database_Change_Deployment_Runbook.md" in wrapper


def test_production_runner_pins_exact_target_and_live_setup_worktree() -> None:
    runner = read_acceptance("setup_training_production_deploy_server.sh")
    assert f'TARGET_SHA="{TARGET_SHA}"' in runner
    assert 'TARGET_REF="agent/setup-session-production-foundation"' in runner
    assert 'SETUP_ROOT="/opt/msb-setup"' in runner
    assert 'REPO_ROOT="/opt/fieldwiring"' in runner
    assert 'OLD_HEAD="$(sudo git -C "$SETUP_ROOT" rev-parse HEAD)"' in runner
    assert 'merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"' in runner
    assert 'sudo git -C "$SETUP_ROOT" merge --ff-only "$TARGET_SHA"' in runner
    assert 'sudo git -C "$SETUP_ROOT" reset --hard "$OLD_HEAD"' in runner


def test_production_runner_regresses_before_backup_and_backup_before_mutation() -> None:
    runner = read_acceptance("setup_training_production_deploy_server.sh")
    regression = runner.index("--- Detached Production-runtime candidate regression ---")
    backup = runner.index("--- Create and verify rollback PostgreSQL archive ---")
    preflight = runner.index("--- Production database preflight ---")
    mutation = runner.index("--- Apply accepted Setup migrations 019 / 020 / 021 / 022 ---")
    checkout = runner.index("--- Fast-forward dedicated Setup Production checkout ---")
    assert regression < backup < preflight < mutation < checkout
    assert "/opt/fieldwiring/.venv/bin/python -m pytest -q -p no:cacheprovider Setup/Application" in runner
    assert 'pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$BACKUP_FILE"' in runner
    assert 'pg_restore --list < "$BACKUP_FILE"' in runner
    assert 'cat "$BACKUP_FILE" |' not in runner


def test_production_runner_applies_only_019_through_022_by_stdin() -> None:
    runner = read_acceptance("setup_training_production_deploy_server.sh")
    for migration in (
        "019_add_reconstruction_safe_task_delete.sql",
        "020_add_setup_captain_management_commands.sql",
        "021_add_setup_assigned_reconciliation_state.sql",
        "022_require_active_setup_captain_people.sql",
    ):
        assert migration in runner
    for variable in ("M019", "M020", "M021", "M022"):
        assert f'< "${variable}"' in runner
        assert f'cat "${variable}" |' not in runner
    assert "886b910833f895179ad218c0cd1ba217de0f7bf9" in runner
    assert "deb83713295d23bb9b153cf905c9f9b16f1f48bd" in runner
    assert "44680394f71074446918cae4aa7ee1aeddd1599b" in runner
    assert "130fc1ebc289e7e26a152c88bbfb24e47e80eebc" in runner


def test_production_runner_enforces_setup_security_and_final_invariants() -> None:
    runner = read_acceptance("setup_training_production_deploy_server.sh")
    assert "default_transaction_read_only=on" in runner
    assert "has_function_privilege('fieldwiring_app', 'ref.delete_setup_reconstruction_task" in runner
    assert "has_function_privilege('fieldwiring_app', 'ref.set_setup_task_captain" in runner
    assert "has_table_privilege('fieldwiring_app', 'ref.setup_task', 'DELETE')" in runner
    assert "has_table_privilege('fieldwiring_app', 'ref.setup_task_captain', 'INSERT')" in runner
    assert "has_table_privilege('fieldwiring_app', 'ops.setup_session_task', 'UPDATE')" in runner
    assert "Inactive people are exposed by the Production Captain candidate projection" in runner
    assert "PASS: migrations 019-022 installed without changing governed Setup data" in runner
    assert "Protected Setup negative-path HTTP 401: PASS" in runner
    assert "SETUP_TRAINING_PRODUCTION_DEPLOYMENT_PASS" in runner
    assert 'sudo systemctl restart "$SETUP_SERVICE"' in runner
    assert 'sudo systemctl restart "$FIELDWIRING_SERVICE"' not in runner
    assert 'sudo systemctl restart "$PROCEDURES_SERVICE"' not in runner
