from __future__ import annotations

from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
ACCEPT_DIR = APP_DIR.parent / "Acceptance"


def read_accept(name: str) -> str:
    return (ACCEPT_DIR / name).read_text(encoding="utf-8")


def test_material_authority_wrapper_pins_exact_accepted_release() -> None:
    wrapper = read_accept("run_setup_206_material_authority_production_deploy.ps1")

    assert "$ExpectedBranch = 'deploy/setup-206-material-authority-production'" in wrapper
    assert "$AcceptedTargetSha = '947b86a9598584717167cce094cd78d99e9a71e7'" in wrapper
    assert "$Migration063Path = 'Setup/Database/063_harden_setup_extra_material_requirement_lifecycle.sql'" in wrapper
    assert "$Migration063Blob = '2c686ad3ae55b09a9cf3629b9ef01bb0b83dd447'" in wrapper
    assert "$Migration064Path = 'Setup/Database/064_add_setup_extra_material_requirement_restore.sql'" in wrapper
    assert "$Migration064Blob = '50de44a51b44eb008e826a7ef76b2023fafa29f7'" in wrapper
    assert "$AcceptedServerRunnerBlob = '2aef8ae83f92f4ff92f9641568bf7e09549db932'" in wrapper
    assert "V0.3.20-material-authority" in wrapper
    assert "Production_Database_Change_Deployment_Runbook.md" in wrapper
    assert "scp -r $localBundle" in wrapper
    assert "ssh -tt -o ServerAliveInterval=15 -o ServerAliveCountMax=3" in wrapper
    assert "Start-Process ssh" not in wrapper
    assert "ssh -f" not in wrapper
    assert "ssh -N" not in wrapper


def test_material_authority_server_runner_follows_bounded_release_order() -> None:
    server = read_accept("setup_206_material_authority_production_deploy_server.sh")

    assert 'TARGET_SHA="947b86a9598584717167cce094cd78d99e9a71e7"' in server
    assert 'EXPECTED_LIVE_SHA="fc0b76d57826eebf04b81c99cbb904109162cd87"' in server
    assert 'EXPECTED_PRE_VERSION="V0.3.19-pick-list"' in server
    assert 'EXPECTED_POST_VERSION="V0.3.20-material-authority"' in server
    assert 'M063_BLOB="2c686ad3ae55b09a9cf3629b9ef01bb0b83dd447"' in server
    assert 'M064_BLOB="50de44a51b44eb008e826a7ef76b2023fafa29f7"' in server

    detached = server.index("--- Detached exact-target Production-runtime regression ---")
    freeze = server.index("--- Freeze Setup writes for bounded Production mutation window ---")
    backup = server.index("--- Create and validate rollback PostgreSQL archive ---")
    preflight = server.index("--- Production database preflight for migrations 063 + 064 ---")
    migration_063 = server.index("--- Apply migration 063 only ---")
    migration_064 = server.index("--- Apply migration 064 only ---")
    validate = server.index("--- Validate 063/064 least privilege and data preservation ---")
    advance = server.index("--- Advance /opt/msb-setup to frozen V0.3.20 target ---")
    restart = server.index("--- Restart and verify Setup V0.3.20 runtime ---")
    live = server.index("--- Full live Setup regression ---")
    final = server.index("--- Final Production invariants ---")

    assert detached < freeze < backup < preflight < migration_063 < migration_064 < validate < advance < restart < live < final
    assert 'pg_restore --list < "$BACKUP_FILE"' in server
    assert 'psql_prod < "$M063"' in server
    assert 'psql_prod < "$M064"' in server
    assert 'cat "$BACKUP_FILE" |' not in server
    assert 'cat "$M063" |' not in server
    assert 'cat "$M064" |' not in server


def test_material_authority_deployment_preserves_data_and_least_privilege() -> None:
    server = read_accept("setup_206_material_authority_production_deploy_server.sh")

    assert "core_fingerprint()" in server
    assert "material_fingerprint()" in server
    assert "ref.setup_task_extra_material tm" in server
    assert "ref.setup_task_extra_material_source src" in server
    assert "ref.setup_container_extra_material cem" in server
    assert "ops.setup_extra_material_inventory_event ev" in server
    assert "ref.setup_container_extra_material_review rem" in server
    assert "ORDER BY rem.container_id" in server
    assert "setup_container_extra_material_review_id" not in server

    assert "has_function_privilege(" in server
    assert "ref.delete_setup_task_extra_material(text,bigint,bigint)" in server
    assert "ref.restore_setup_task_extra_material(text,bigint,bigint)" in server
    assert "Forbidden broad Extra Material DML privilege detected" in server
    assert "has_table_privilege('fieldwiring_app','ref.setup_task_extra_material','UPDATE')" in server
    assert "has_table_privilege('fieldwiring_app','ref.setup_task_extra_material','DELETE')" in server
    assert "has_table_privilege('fieldwiring_app','ref.setup_task_extra_material_source','DELETE')" in server


def test_material_authority_rollback_only_removes_new_functions_and_restores_source() -> None:
    server = read_accept("setup_206_material_authority_production_deploy_server.sh")

    assert "rollback_new_functions()" in server
    assert "DROP FUNCTION IF EXISTS ref.restore_setup_task_extra_material(text,bigint,bigint)" in server
    assert "DROP FUNCTION IF EXISTS ref.delete_setup_task_extra_material(text,bigint,bigint)" in server
    assert 'sudo git -C "$SETUP_ROOT" checkout --detach "$OLD_HEAD"' in server
    assert 'sudo systemctl restart "$SETUP_SERVICE"' in server
    assert "pg_restore -d" not in server


def test_material_authority_release_identity_and_live_assets_are_verified() -> None:
    server = read_accept("setup_206_material_authority_production_deploy_server.sh")

    assert 'PRODUCTION_VERSION = "V0.3.20-material-authority"' in server
    assert "CLIENT_BUILD = 'V0.3.20-material-authority'" in server
    assert "setup_catalog_dirty_guard.js?v=2026-09-28.1" in server
    assert "setup_extra_materials.js?v=2026-09-28.3" in server
    assert "setup_kit_inventory.css?v=2026-09-28.2" in server
    assert "setup_kit_inventory.js?v=2026-09-28.3" in server
    assert "Client V0.3.20" in server
    assert "Edit / Remove" in server
    assert "Count / Adjust" in server
    assert "ID or C###" in server
    assert "PROTECTED NEGATIVE PATH: PASS" in server
    assert "AUTHENTICATED MANAGER ACCESS: PASS" in server
    assert "SETUP_206_MATERIAL_AUTHORITY_PRODUCTION_DEPLOYMENT_PASS" in server
