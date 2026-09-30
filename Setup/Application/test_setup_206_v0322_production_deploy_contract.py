from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
ACCEPTANCE_DIR = APP_DIR.parent / "Acceptance"
WRAPPER = ACCEPTANCE_DIR / "run_setup_206_v0322_production_deploy.ps1"
SERVER = ACCEPTANCE_DIR / "setup_206_v0322_production_deploy_server.sh"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_v0322_wrapper_pins_exact_accepted_release() -> None:
    text = read(WRAPPER)
    assert "$ExpectedBranch = 'main'" in text
    assert "$AcceptedTargetSha = '6f53d7f0c4b15f7175e773a2069595eef3f0e698'" in text
    assert "$MigrationPath = 'Setup/Database/063_add_setup_pick_list_delay.sql'" in text
    assert "$AcceptedMigrationBlob = '45d1f71e226ab9e358e40f331945135cbe19cfb8'" in text
    assert "$AcceptedServerRunnerBlob = 'c104f9b51ea258720bd13ae0f2d125167f30be6e'" in text
    assert 'PRODUCTION_VERSION = "V0\\.3\\.22-pick-list-delay"' in text
    assert "CLIENT_BUILD = 'V0\\.3\\.22-pick-list-delay'" in text
    assert "setup_catalog_dirty_guard.js?v=2026-09-30.1" in text


def test_v0322_wrapper_is_one_bundle_one_foreground_ssh() -> None:
    text = read(WRAPPER)
    assert text.count("& scp -r") == 1
    assert text.count("& ssh -tt") == 1
    assert "Start-Process ssh" not in text
    assert "ssh -N" not in text
    assert "ssh -f" not in text
    assert "timeout --foreground --signal=TERM 3600s" in text
    assert "bash -n" in text


def test_v0322_server_uses_only_approved_pick_delay_migration() -> None:
    text = read(SERVER)
    assert 'MIGRATION_REL="Setup/Database/063_add_setup_pick_list_delay.sql"' in text
    assert 'MIGRATION_BLOB="45d1f71e226ab9e358e40f331945135cbe19cfb8"' in text
    assert "063_harden_setup_extra_material_requirement_lifecycle.sql" not in text
    assert "064_add_setup_extra_material_requirement_restore.sql" not in text
    assert "060_add_setup_pick_list_manager_override.sql" not in text
    assert 'psql_prod < "$M063"' in text


def test_v0322_server_follows_runbook_order_and_backup_contract() -> None:
    text = read(SERVER)
    regression = text.index("--- Detached exact-target regression in Production runtime ---")
    freeze = text.index("--- Freeze Setup writes for bounded Production mutation window ---")
    backup = text.index("--- Create and validate rollback PostgreSQL archive ---")
    preflight = text.index("--- Production database preflight for exact Pick Delay migration ---")
    migrate = text.index("--- Apply reviewed Pick Delay migration ---")
    advance = text.index("--- Advance dedicated Setup Production checkout to exact target ---")
    restart = text.index("--- Restart and verify Setup V0.3.22 runtime ---")
    assert regression < freeze < backup < preflight < migrate < advance < restart
    assert 'pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$BACKUP_FILE"' in text
    assert 'pg_restore --list < "$BACKUP_FILE"' in text
    assert 'cat "$BACKUP_FILE" |' not in text
    assert 'cat "$M063" |' not in text


def test_v0322_server_fails_closed_and_rolls_back_only_its_own_objects() -> None:
    text = read(SERVER)
    assert "rollback_migration_063_pick_delay()" in text
    assert 'rows="$(delay_count 2>/dev/null || true)"' in text
    assert 'if [[ "$rows" != "0" ]]' in text
    assert "DROP TRIGGER IF EXISTS trg_setup_pick_list_delay_schedule_release" in text
    assert "DROP FUNCTION IF EXISTS ops.clear_setup_pick_list_delay_on_schedule();" in text
    assert "DROP FUNCTION IF EXISTS ops.set_setup_pick_list_delay(" in text
    assert "DROP TABLE IF EXISTS ops.setup_pick_list_delay;" in text
    assert "Restoring Setup checkout to verified prior SHA" in text
    assert "pg_restore" not in text[text.index("rollback_migration_063_pick_delay()"):text.index("cleanup()")]


def test_v0322_server_validates_least_privilege_and_release_identity() -> None:
    text = read(SERVER)
    assert 'EXPECTED_PRE_VERSION="V0.3.21-scheduling-gates"' in text
    assert 'EXPECTED_POST_VERSION="V0.3.22-pick-list-delay"' in text
    assert "Forbidden broad Pick Delay DML privilege detected" in text
    assert "fieldwiring_app" in text
    assert "ops.set_setup_pick_list_delay(text,integer,integer,bigint[],text,boolean)" in text
    assert "ops.clear_setup_pick_list_delay_on_schedule()" in text
    assert "V0.3.22 CLIENT/PICK DELAY SOURCE CONTRACT: PASS" in text
    assert "AUTHENTICATED 2026 PICK LIST/PICK DELAY READ: PASS" in text
    assert "LIVE SETUP REGRESSION: PASS" in text


def test_v0322_server_has_no_stale_release_tokens_or_broken_duplicate_blocks() -> None:
    text = read(SERVER)
    for forbidden in (
        "V0.3.18-scheduling-board",
        "V0.3.19-pick-list",
        "wait_setup_ready() {wait_setup_ready() {",
        "cleanup() {cleanup() {",
        'DATABASE PREFLIGHT: PASS"echo',
        'preserved existing governed Setup data"echo',
    ):
        assert forbidden not in text
