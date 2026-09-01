from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = BASE_DIR.parent.parent
ACCEPTANCE = REPO_ROOT / "Controllers" / "Acceptance"


def test_windows_wrapper_keeps_ssh_foreground_bounded_and_two_session() -> None:
    source = (ACCEPTANCE / "run_controller_label_disposable_acceptance.ps1").read_text(
        encoding="utf-8"
    )

    assert "Start-Process" not in source
    assert "ssh -f" not in source
    assert "ssh -N" not in source
    assert "-L " not in source
    assert "Tee-Object" not in source
    assert "timeout --signal=TERM 1200s" in source
    assert source.count("& ssh") == 1
    assert source.count("& scp") == 1
    assert "& ssh -tt $Server" in source
    assert "& scp -r $localBundle" in source


def test_windows_wrapper_normalizes_shell_script_to_lf_before_upload() -> None:
    source = (ACCEPTANCE / "run_controller_label_disposable_acceptance.ps1").read_text(
        encoding="utf-8"
    )

    assert 'Replace("`r`n", "`n")' in source
    assert '.Replace("`r", "`n")' in source
    assert "UTF8Encoding($false)" in source
    assert "controller_label_disposable_server.sh" in source


def test_server_runner_uses_isolated_production_equivalent_postgres() -> None:
    source = (ACCEPTANCE / "controller_label_disposable_server.sh").read_text(
        encoding="utf-8"
    )

    assert 'PROD_CONTAINER="msb-postgres"' in source
    assert 'DB_ACTOR="msbadmin"' in source
    assert 'IMAGE="postgis/postgis:16-3.5"' in source
    assert 'NETWORK="msb-stack_default"' in source
    assert "pg_dump" in source
    assert "docker run -d" in source
    assert "--network \"$NETWORK\"" in source
    assert "--publish" not in source
    assert " -p " not in source
    assert "PostgreSQL init process complete; ready for start up" in source


def test_server_runner_guards_production_and_cleanup() -> None:
    source = (ACCEPTANCE / "controller_label_disposable_server.sh").read_text(
        encoding="utf-8"
    )

    assert "prod_fingerprint()" in source
    assert 'PROD_BEFORE="$(prod_fingerprint)"' in source
    assert 'PROD_AFTER="$(prod_fingerprint)"' in source
    assert "production Controller fingerprint unchanged" in source
    assert "trap cleanup EXIT INT TERM" in source
    assert 'docker rm -f "$TEST_CONTAINER"' in source
    assert "CONTROLLER LABEL DISPOSABLE ACCEPTANCE: PASS" in source


def test_server_runner_tests_narrow_write_and_real_actor() -> None:
    source = (ACCEPTANCE / "controller_label_disposable_server.sh").read_text(
        encoding="utf-8"
    )

    assert "has_table_privilege('fieldwiring_app', 'ref.controller', 'UPDATE')" in source
    assert "direct fieldwiring_app Controller UPDATE denied" in source
    assert "unauthorized Controller label request denied" in source
    assert "updated_by_person_id" in source
    assert "ref.controller_browser_capabilities" in source
    assert "ref.request_controller_label" in source
    assert "repeated pending request is idempotent" in source
