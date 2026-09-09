from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
LAUNCHER = ROOT / "Setup" / "Acceptance" / "run_setup_catalog_reconstruction_browser_preview.ps1"
SERVER = ROOT / "Setup" / "Acceptance" / "setup_catalog_reconstruction_browser_preview_server.sh"
ACCEPTED = "dd1cbeafe6243089b4ee3b04ea3f67359654381f"


def test_catalog_preview_pins_exact_accepted_candidate():
    launcher = LAUNCHER.read_text(encoding="utf-8")
    server = SERVER.read_text(encoding="utf-8")
    assert ACCEPTED in launcher
    assert f'TARGET_SHA="{ACCEPTED}"' in server
    assert "agent/setup-catalog-reconstruction-20260909" in server


def test_catalog_preview_uses_only_new_reconstruction_migrations():
    server = SERVER.read_text(encoding="utf-8")
    assert "023_add_setup_task_effort.sql" in server
    assert "024_reconstruct_setup_catalog_from_reviewed_one_list.sql" in server
    assert "024_catalog_batch_01.sql" in server
    assert "024_catalog_batch_05.sql" in server
    for old in range(8, 23):
        assert f"/{old:03d}_" not in server


def test_catalog_preview_preserves_production_boundary():
    launcher = LAUNCHER.read_text(encoding="utf-8")
    server = SERVER.read_text(encoding="utf-8")
    assert "Production database contract: pg_dump + SELECT only" in launcher
    assert "pg_dump -U \"$DB_ACTOR\" -d \"$PROD_DB\" -Fc" in server
    assert "PASS: Production Setup fingerprint unchanged" in server
    assert "shared live checkout unchanged" in server
    assert "merge --ff-only" not in server
    assert "psql -f" not in server.split("prod_fingerprint()", 1)[0]


def test_catalog_preview_uses_final_postgis_readiness_gate():
    server = SERVER.read_text(encoding="utf-8")
    assert "cat /proc/1/comm" in server
    assert '[[ "$pid1" == "postgres" ]]' in server
    assert "pg_isready" in server


def test_catalog_preview_rejects_production_ports_and_backgrounded_sudo():
    launcher = LAUNCHER.read_text(encoding="utf-8")
    server = SERVER.read_text(encoding="utf-8")
    for port in (8055, 8790, 8792, 8794):
        assert str(port) in launcher
        assert str(port) in server
    assert "setsid sudo" not in server
    assert "sudo -u fieldwiring -H env" in server


def test_catalog_preview_validates_effort_and_waits_for_operator_cleanup():
    server = SERVER.read_text(encoding="utf-8")
    assert "/api/setup/task-efforts" in server
    assert "185 reusable tasks" in server
    assert "LIGHT" in server and "MODERATE" in server and "HEAVY" in server
    assert "read -r -p" in server
    assert "SETUP CATALOG BROWSER REVIEW READY" in server
