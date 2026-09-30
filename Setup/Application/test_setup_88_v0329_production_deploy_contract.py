from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
ACCEPTANCE_DIR = APP_DIR.parent / "Acceptance"
WRAPPER = ACCEPTANCE_DIR / "run_setup_88_v0329_production_deploy.ps1"
SERVER = ACCEPTANCE_DIR / "setup_88_v0329_production_deploy_server.sh"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_v0329_wrapper_requires_merged_main_and_pins_accepted_application() -> None:
    text = read(WRAPPER)
    assert "$ExpectedBranch = 'main'" in text
    assert "$AcceptedApplicationSha = '7da6828d7b884ee5bb12123dab647bd6fadfba50'" in text
    assert "$AcceptedMigrationBlob = '2738065a6fc3cb84858e401de5fae9bd6ae35dcc'" in text
    assert "$AcceptedValidationBlob = 'fc152c305dc0bf7a056aeff60aae3615b06b96d4'" in text
    assert "$AcceptedScanBlob = '4c2810bf33087d33803456d4b73a4ff1dc86760b'" in text
    assert "$AcceptedServerRunnerBlob = 'bd90c85d923f3b8bee0ceb6b8617632c74039819'" in text
    assert "& git -C $RepoRoot fetch origin main" in text
    assert "$localHead -ne $originMain" in text
    assert "merge-base --is-ancestor $AcceptedApplicationSha HEAD" in text
    assert 'PRODUCTION_VERSION = "V0\\.3\\.29-pick-clarity"' in text
    assert "CLIENT_BUILD = 'V0\\.3\\.29-pick-clarity'" in text


def test_v0329_wrapper_uses_one_bundle_and_one_foreground_ssh() -> None:
    text = read(WRAPPER)
    assert text.count("& scp -r") == 1
    assert text.count("& ssh -tt") == 1
    assert "Start-Process ssh" not in text
    assert "ssh -N" not in text
    assert "ssh -f" not in text
    assert "Tee-Object" not in text
    assert "timeout --foreground --signal=TERM 3600s" in text
    assert "bash -n" in text


def test_v0329_server_targets_merged_main_but_deploys_exact_accepted_app_sha() -> None:
    text = read(SERVER)
    assert 'TARGET_REF="main"' in text
    assert 'TARGET_SHA="7da6828d7b884ee5bb12123dab647bd6fadfba50"' in text
    assert 'EXPECTED_PRE_VERSION="V0.3.22-pick-list-delay"' in text
    assert 'EXPECTED_POST_VERSION="V0.3.29-pick-clarity"' in text
    assert 'MIGRATION_REL="Setup/Database/065_add_setup_movement_capture.sql"' in text
    assert 'MIGRATION_BLOB="2738065a6fc3cb84858e401de5fae9bd6ae35dcc"' in text
    assert 'VALIDATION_BLOB="fc152c305dc0bf7a056aeff60aae3615b06b96d4"' in text
    assert 'SCAN_BLOB="4c2810bf33087d33803456d4b73a4ff1dc86760b"' in text
    assert 'EXPECTED_LIVE_SCAN_SHA256="3457efa15f461b774ef20462f57807d36cb848cac67bdcffcc2a8284c2dc2f96"' in text


def test_v0329_server_follows_runbook_order() -> None:
    text = read(SERVER)
    regression = text.index("--- Detached exact-target regression and Scan staging ---")
    freeze = text.index("--- Freeze Setup writes for bounded Production mutation window ---")
    backup = text.index("--- Create and validate rollback PostgreSQL archive ---")
    scan_rollback = text.index("--- Capture immediately preceding Scan rollback artifact ---")
    preflight = text.index("--- Production database preflight for migration 065 ---")
    migrate = text.index("--- Apply reviewed migration 065 ---")
    validate = text.index("--- Transactional production validation of movement contract ---")
    setup_advance = text.index("--- Advance dedicated Setup Production checkout to exact accepted target ---")
    scan_install = text.index("--- Install exact approved Scan artifact ---")
    directus_restart = text.index("--- Restart Directus and verify Scan extension ---")
    setup_restart = text.index("--- Restart and verify Setup V0.3.29 runtime ---")
    live_regression = text.index("--- Live Setup regression ---")
    final = text.index("--- Final Production invariants ---")

    assert (
        regression
        < freeze
        < backup
        < scan_rollback
        < preflight
        < migrate
        < validate
        < setup_advance
        < scan_install
        < directus_restart
        < setup_restart
        < live_regression
        < final
    )


def test_v0329_server_uses_only_reviewed_database_change_and_transactional_validation() -> None:
    text = read(SERVER)
    assert 'psql_prod < "$M065"' in text
    assert 'psql_prod < "$V065"' in text
    assert "Repair-SetActorOnUpdate-Attribution.sql" not in text
    assert "ref.set_actor_on_update()" in text
    assert "new_movement_evidence_count" in text
    assert 'if [[ "$NEW_EVIDENCE" != "0" ]]' in text
    assert "Migration 065 reached committed state and is intentionally not auto-restored." in text
    assert "Use the retained validated PostgreSQL archive only through a separately governed recovery decision." in text
    assert 'pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$BACKUP_FILE"' in text
    assert 'pg_restore --list < "$BACKUP_FILE"' in text
    assert 'cat "$BACKUP_FILE" |' not in text
    assert 'cat "$M065" |' not in text


def test_v0329_server_scan_deployment_is_hash_gated_and_rollback_bounded() -> None:
    text = read(SERVER)
    assert 'LIVE SCAN HASH BASELINE: PASS' in text
    assert 'sudo cp -p "$SCAN_LIVE_PATH" "$SCAN_ROLLBACK"' in text
    assert 'sudo docker exec "$DIRECTUS_CONTAINER" node --check "$SCAN_CONTAINER_TMP"' in text
    assert 'sudo cp "$STAGED_SCAN" "$SCAN_LIVE_PATH"' in text
    assert "LIVE SCAN ARTIFACT HASH/SYNTAX: PASS" in text
    assert 'sudo docker exec "$DIRECTUS_CONTAINER" node --check /directus/extensions/directus-extension-scan/dist/index.js' in text
    assert "Restoring immediately preceding Scan artifact" in text
    assert 'sudo cp -p "$SCAN_ROLLBACK" "$SCAN_LIVE_PATH"' in text
    assert "SCAN ROUTE/HANDOFF REGRESSION: PASS" in text
    assert "focusScanInput" in text
    assert "Record Location" in text
    assert "fieldwiring/controllers?controller_id=1014" in text


def test_v0329_server_preserves_setup_security_and_final_identity() -> None:
    text = read(SERVER)
    assert "fieldwiring_app unexpectedly has broad movement DML before deployment" in text
    assert "PROTECTED MOVEMENT API NEGATIVE PATH: PASS" in text
    assert "LIVE SETUP REGRESSION: PASS" in text
    assert '[[ "$FINAL_SETUP_HEAD" == "$TARGET_SHA" ]]' in text
    assert '[[ "$FINAL_SHARED_HEAD" == "$SHARED_HEAD_BEFORE" ]]' in text
    assert '[[ "$FINAL_FINGERPRINT" == "$FROZEN_FINGERPRINT" ]]' in text
    assert '[[ "$FINAL_NEW_EVIDENCE" == "0" ]]' in text
    assert "SETUP_88_V0329_PRODUCTION_DEPLOYMENT_PASS" in text
