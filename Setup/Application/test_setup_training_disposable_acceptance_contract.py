from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
SETUP_DIR = APP_DIR.parent
ACCEPT = SETUP_DIR / "Acceptance"


def read_acceptance(name: str) -> str:
    return (ACCEPT / name).read_text(encoding="utf-8")


def test_disposable_wrapper_uses_one_bundle_transfer_and_foreground_ssh() -> None:
    wrapper = read_acceptance("run_setup_training_disposable_acceptance.ps1")
    assert "scp -r" in wrapper
    assert "ssh -tt" in wrapper
    assert "Tee-Object" not in wrapper
    assert "Start-Process" not in wrapper
    assert "ssh -f" not in wrapper
    assert "ssh -N" not in wrapper
    assert ".Replace(\"`r`n\", \"`n\")" in wrapper
    assert "UTF8Encoding" in wrapper
    assert "git -C $repo rev-parse HEAD" in wrapper
    assert "$head -ne $CandidateSha" in wrapper


def test_disposable_runner_reads_production_only_by_dump_and_select() -> None:
    runner = read_acceptance("setup_training_disposable_acceptance_server.sh")
    assert 'PROD_CONTAINER="msb-postgres"' in runner
    assert 'IMAGE="postgis/postgis:16-3.5"' in runner
    assert 'NETWORK="msb-stack_default"' in runner
    assert 'pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc' in runner
    assert 'prod_fingerprint()' in runner
    assert "Production DB: pg_dump + SELECT only" in runner
    assert "Test writes:   disposable PostgreSQL clone only" in runner
    assert "docker exec -i \"$PROD_CONTAINER\" pg_restore --list < \"$DUMP_FILE\"" in runner
    assert 'cat "$DUMP_FILE" |' not in runner
    assert '--network "$NETWORK"' in runner
    # Reject Docker host-port publication specifically. Do not use a blanket
    # '-p ' search because normal shell commands such as `mkdir -p` are valid.
    assert "docker run -d -p " not in runner
    assert "docker run -d \\\n    -p " not in runner
    assert "--publish" not in runner


def test_disposable_runner_applies_only_training_migrations_to_clone() -> None:
    runner = read_acceptance("setup_training_disposable_acceptance_server.sh")
    for migration in (
        "019_add_reconstruction_safe_task_delete.sql",
        "020_add_setup_captain_management_commands.sql",
        "021_add_setup_assigned_reconciliation_state.sql",
    ):
        assert migration in runner
    assert 'psql_test < "$M019"' in runner
    assert 'psql_test < "$M020"' in runner
    assert 'psql_test < "$M021"' in runner
    assert 'psql_test < "$VALIDATION"' in runner
    assert "DISPOSABLE_SETUP_TRAINING_ACCEPTANCE_PASS" in runner
    assert "sudo docker rm -f \"$TEST_CONTAINER\"" in runner
    assert "Production Setup fingerprint unchanged" in runner


def test_disposable_runner_replays_migrations_and_proves_idempotence() -> None:
    runner = read_acceptance("setup_training_disposable_acceptance_server.sh")
    assert runner.count('psql_test < "$M019"') == 2
    assert runner.count('psql_test < "$M020"') == 2
    assert runner.count('psql_test < "$M021"') == 2
    assert "--- Reapply candidate migrations to prove idempotence ---" in runner
    assert "IDEMPOTENCE_BEFORE" in runner
    assert "IDEMPOTENCE_AFTER" in runner
    assert "FAIL: candidate migration replay changed governed Setup data" in runner
    assert "PASS: migrations 019-021 replay cleanly with governed Setup data unchanged" in runner


def test_disposable_validation_proves_delete_captain_assigned_and_least_privilege() -> None:
    validation = read_acceptance("setup_training_disposable_validation.sql")
    assert "ref.delete_setup_reconstruction_task" in validation
    assert "ref.set_setup_task_captain" in validation
    assert "ref.setup_task_captain_list" in validation
    assert "ref.setup_captain_person_list" in validation
    assert "'ASSIGNED'" in validation
    assert "planned_date = DATE '2025-10-01'" in validation
    assert "foreign_key_violation" in validation
    assert "Invalid Captain role was unexpectedly accepted" in validation
    assert "has_table_privilege('fieldwiring_app', 'ref.setup_task', 'DELETE')" in validation
    assert "has_table_privilege('fieldwiring_app', 'ref.setup_task_captain', 'INSERT')" in validation
    assert "has_table_privilege('fieldwiring_app', 'ops.setup_session_task', 'UPDATE')" in validation
    assert "DISPOSABLE_SETUP_TRAINING_VALIDATION_PASS" in validation
