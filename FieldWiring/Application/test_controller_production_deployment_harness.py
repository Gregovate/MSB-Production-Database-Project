from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = BASE_DIR.parent.parent
ACCEPTANCE = REPO_ROOT / "Controllers" / "Acceptance"


def _powershell_executable_lines(source: str) -> str:
    return "\n".join(
        line for line in source.splitlines() if not line.lstrip().startswith("#")
    )


def test_production_wrapper_is_two_session_foreground_and_lf_safe() -> None:
    source = (ACCEPTANCE / "run_controller_label_production_deploy.ps1").read_text(
        encoding="utf-8"
    )
    executable = _powershell_executable_lines(source)

    assert "Start-Process" not in executable
    assert "ssh -f" not in executable
    assert "ssh -N" not in executable
    assert "-L " not in executable
    assert "Tee-Object" not in executable
    assert executable.count("& scp") == 1
    assert executable.count("& ssh") == 1
    assert "timeout --signal=TERM 1200s" in executable
    assert 'Replace("`r`n", "`n")' in source
    assert '.Replace("`r", "`n")' in source
    assert "UTF8Encoding($false)" in source


def test_production_server_gate_pins_exact_live_and_target_commits() -> None:
    source = (ACCEPTANCE / "controller_label_production_deploy_server.sh").read_text(
        encoding="utf-8"
    )

    assert 'EXPECTED_CURRENT_SHA="84d6f06e16c43ebb0f6aa21273b999af7f6d455b"' in source
    assert 'TARGET_SHA="e9ab029a17067b38b34f9306069f54899925f73f"' in source
    assert 'TARGET_REF="agent/controller-inventory-ref-sandbox"' in source
    assert 'merge-base --is-ancestor "$OLD_HEAD" "$TARGET_SHA"' in source
    assert 'merge --ff-only "$TARGET_SHA"' in source
    assert 'status --porcelain' in source


def test_production_server_gate_requires_rollback_backup_before_mutation() -> None:
    source = (ACCEPTANCE / "controller_label_production_deploy_server.sh").read_text(
        encoding="utf-8"
    )

    backup = source.index("--- Create and verify rollback database backup ---")
    migration = source.index("--- Apply migrations 021 / 022 to production ---")
    deploy = source.index("--- Fast-forward shared production checkout ---")

    assert backup < migration < deploy
    assert "pg_dump" in source
    assert "pg_restore --list" in source
    assert "sha256sum" in source
    assert "msb-pre-controller-browser-" in source


def test_production_server_gate_preserves_narrow_database_boundary() -> None:
    source = (ACCEPTANCE / "controller_label_production_deploy_server.sh").read_text(
        encoding="utf-8"
    )

    assert "021_create_controller_browser_authorization_contract.sql" in source
    assert "022_create_controller_label_request_command.sql" in source
    assert "has_table_privilege('fieldwiring_app', 'ref.controller', 'UPDATE')" in source
    assert "ref.controller_browser_capabilities" in source
    assert "ref.request_controller_label" in source
    assert "UPDATE ref.controller SET print_label" not in source
    assert "INSERT INTO ref.controller" not in source
    assert "DELETE FROM ref.controller" not in source


def test_production_server_gate_has_fail_closed_rollback() -> None:
    source = (ACCEPTANCE / "controller_label_production_deploy_server.sh").read_text(
        encoding="utf-8"
    )

    assert "FAIL-CLOSED ROLLBACK" in source
    assert 'reset --hard "$OLD_HEAD"' in source
    assert "rollback_database_functions" in source
    assert "DROP FUNCTION IF EXISTS ref.request_controller_label" in source
    assert "DROP FUNCTION IF EXISTS ref.controller_browser_capabilities" in source
    assert "trap cleanup EXIT INT TERM" in source


def test_production_server_gate_runs_detached_and_live_regression_and_health() -> None:
    source = (ACCEPTANCE / "controller_label_production_deploy_server.sh").read_text(
        encoding="utf-8"
    )

    assert "DETACHED CANDIDATE REGRESSION: PASS" in source
    assert "LIVE SHARED REGRESSION: PASS" in source
    assert "FieldWiring/Application Procedures/Application" in source
    assert 'EXPECTED_FIELDWIRING_VERSION="V0.3.3"' in source
    assert 'EXPECTED_PROCEDURES_VERSION="V0.1.0"' in source
    assert "192.168.5.9:8790/api/health" in source
    assert "192.168.5.9:8792/api/health" in source
    assert "Controller access endpoint rejects missing Cloudflare identity" in source


def test_production_server_gate_fingerprints_controller_tables_before_after() -> None:
    source = (ACCEPTANCE / "controller_label_production_deploy_server.sh").read_text(
        encoding="utf-8"
    )

    assert "prod_fingerprint()" in source
    assert 'PROD_BEFORE="$(prod_fingerprint)"' in source
    assert 'FINAL_FP="$(prod_fingerprint)"' in source
    assert "production Controller table fingerprint unchanged" in source
    assert "CONTROLLER LABEL PRODUCTION DEPLOYMENT: PASS" in source
