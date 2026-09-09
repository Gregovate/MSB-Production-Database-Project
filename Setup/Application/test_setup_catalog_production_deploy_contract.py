from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LAUNCHER = ROOT / "Setup" / "Acceptance" / "run_setup_catalog_reconstruction_production_deploy.ps1"
SERVER = ROOT / "Setup" / "Acceptance" / "setup_catalog_reconstruction_production_deploy_server.sh"
ACCEPTED = "5a8a317357ffa5d77c38bc4df63fe6c7b451dbaf"
ACCEPTED_REF = "agent/setup-catalog-reconstruction-production-accepted-20260909"


def test_catalog_production_deploy_pins_exact_accepted_target():
    launcher = LAUNCHER.read_text(encoding="utf-8")
    server = SERVER.read_text(encoding="utf-8")
    assert ACCEPTED in launcher
    assert ACCEPTED_REF in launcher
    assert 'TARGET_SHA="19239e3584a66913ecaa5f0406434be54618c303"' in server
    assert 'TARGET_REF="agent/setup-catalog-reconstruction-20260909"' in server
    assert "$serverText.Replace($oldRef, $newRef).Replace($oldSha, $newSha)" in launcher


def test_catalog_production_deploy_uses_runbook_runtime_and_only_023_024():
    launcher = LAUNCHER.read_text(encoding="utf-8")
    server = SERVER.read_text(encoding="utf-8")
    assert "Production_Database_Change_Deployment_Runbook.md" in launcher
    assert 'SETUP_ROOT="/opt/msb-setup"' in server
    assert 'SETUP_SERVICE="msb-setup.service"' in server
    assert "023_add_setup_task_effort.sql" in server
    assert "024_reconstruct_setup_catalog_from_reviewed_one_list.sql" in server
    for old in range(8, 23):
        assert f"/{old:03d}_" not in server


def test_catalog_production_deploy_has_required_gates():
    server = SERVER.read_text(encoding="utf-8")
    assert "merge-base --is-ancestor" in server
    assert "DETACHED SETUP CATALOG CANDIDATE REGRESSION: PASS" in server
    assert "ROLLBACK ARCHIVE VALIDATION: PASS" in server
    assert "DATABASE PREFLIGHT: PASS" in server
    assert "PRODUCTION SETUP CATALOG VALIDATION: PASS" in server
    assert "merge --ff-only" in server
    assert "LIVE SETUP APPLICATION REGRESSION: PASS" in server
    assert "Protected Setup negative-path HTTP 401: PASS" in server
    assert "SETUP_CATALOG_RECONSTRUCTION_PRODUCTION_DEPLOYMENT_PASS" in server


def test_catalog_production_deploy_uses_safe_archive_and_migration_io():
    server = SERVER.read_text(encoding="utf-8")
    assert 'pg_restore --list < "$BACKUP_FILE"' in server
    assert "cat \"$BACKUP_FILE\" |" not in server
    assert 'psql_prod < "$M023"' in server
    assert '< "$M024"' in server
    assert "cat \"$M023\" |" not in server
    assert "cat \"$M024\" |" not in server


def test_catalog_production_deploy_knows_catalog_is_expected_data_change():
    server = SERVER.read_text(encoding="utf-8")
    assert '[[ -z "$POST_CATALOG_FP" || "$POST_CATALOG_FP" == "$PROD_BEFORE" ]]' in server
    assert '[[ "$FINAL_FP" != "$POST_CATALOG_FP" ]]' in server
    assert "active_reusable_tasks=" in server
    assert "2026_sessions=" in server
