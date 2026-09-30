from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
ACCEPTANCE_DIR = APP_DIR.parent / "Acceptance"
WRAPPER = ACCEPTANCE_DIR / "run_setup_88_v0329_audit_recovery.ps1"
SERVER = ACCEPTANCE_DIR / "setup_88_v0329_audit_recovery_server.sh"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_audit_recovery_wrapper_requires_merged_main_and_exact_artifacts() -> None:
    text = read(WRAPPER)
    assert "$ExpectedBranch = 'main'" in text
    assert "$AcceptedApplicationSha = '7da6828d7b884ee5bb12123dab647bd6fadfba50'" in text
    assert "$AuditBlob = '2b848e91f0cc4b926e33156641cf2ceed8e6ccee'" in text
    assert "$AuditValidationBlob = '1e09846734deb02f49a8b94d7614758958c2cc3e'" in text
    assert "$MovementValidationBlob = 'fc152c305dc0bf7a056aeff60aae3615b06b96d4'" in text
    assert "$MigrationBlob = '2738065a6fc3cb84858e401de5fae9bd6ae35dcc'" in text
    assert "$ServerRunnerBlob = '73e6f83ff7339f6cb4108f7779c54ad39298499e'" in text
    assert "& git -C $RepoRoot fetch origin main" in text
    assert "$localHead -ne $originMain" in text
    assert "merge-base --is-ancestor $AcceptedApplicationSha HEAD" in text
    assert "Migration 065 must already be installed and will NOT be reapplied." in text
    assert 'fetch origin "main:refs/remotes/origin/main"' in read(SERVER)


def test_audit_recovery_wrapper_uses_one_bundle_and_one_foreground_ssh() -> None:
    text = read(WRAPPER)
    assert text.count("& scp -r") == 1
    assert text.count("& ssh -tt") == 1
    assert "Start-Process ssh" not in text
    assert "ssh -N" not in text
    assert "ssh -f" not in text
    assert "timeout --foreground --signal=TERM 3600s" in text
    assert "bash -n" in text
    assert "'$localHead'" in text


def test_audit_recovery_server_requires_065_but_never_reapplies_it() -> None:
    text = read(SERVER)
    assert 'M065_REL="Setup/Database/065_add_setup_movement_capture.sql"' in text
    assert 'M065_BLOB="2738065a6fc3cb84858e401de5fae9bd6ae35dcc"' in text
    assert "--- Prove migration 065 is already installed; do not rerun it ---" in text
    assert "Migration 065 command surface is not installed" in text
    assert "Migration 065 schema is incomplete" in text
    assert 'psql_prod < "$CANDIDATE_WORKTREE/$M065_REL"' not in text
    assert 'psql_prod < "$M065"' not in text
    assert "--- Apply reviewed migration 065 ---" not in text
    assert "Migration 065:             PRE-EXISTING / NOT REAPPLIED" in text


def test_audit_recovery_order_is_forward_only() -> None:
    text = read(SERVER)
    prove_065 = text.index("--- Prove migration 065 is already installed; do not rerun it ---")
    regression = text.index("--- Create detached reviewed-main worktree and run regression ---")
    freeze = text.index("--- Freeze Setup writes for bounded forward recovery ---")
    backup = text.index("--- Create and validate post-065 / pre-audit rollback PostgreSQL archive ---")
    repair = text.index("--- Apply yesterday's accepted database-wide audit repair ---")
    audit_validate = text.index("--- Validate shared audit actor contract in rollback transaction ---")
    movement_validate = text.index("--- Re-run #88 movement contract validation only; migration 065 is NOT reapplied ---")
    promote = text.index("--- Advance dedicated Setup Production checkout to exact accepted V0.3.29 application ---")
    restart = text.index("--- Restart and verify Setup V0.3.29 runtime ---")
    live_regression = text.index("--- Live Setup regression ---")
    final = text.index("--- Final Production invariants ---")

    assert (
        prove_065
        < regression
        < freeze
        < backup
        < repair
        < audit_validate
        < movement_validate
        < promote
        < restart
        < live_regression
        < final
    )


def test_audit_recovery_uses_known_shared_fix_and_both_rollback_validations() -> None:
    text = read(SERVER)
    assert 'AUDIT_REL="Database/Basic_Query_Tools_Dev/Repair-SetActorOnUpdate-Attribution.sql"' in text
    assert 'AUDIT_BLOB="2b848e91f0cc4b926e33156641cf2ceed8e6ccee"' in text
    assert 'AUDIT_VALIDATION_REL="Database/Acceptance/database_shared_audit_actor_disposable_validation.sql"' in text
    assert 'AUDIT_VALIDATION_BLOB="1e09846734deb02f49a8b94d7614758958c2cc3e"' in text
    assert 'MOVEMENT_VALIDATION_REL="Setup/Acceptance/setup_88_movement_capture_disposable_validation.sql"' in text
    assert 'MOVEMENT_VALIDATION_BLOB="fc152c305dc0bf7a056aeff60aae3615b06b96d4"' in text
    assert 'psql_prod < "$CANDIDATE_WORKTREE/$AUDIT_REL"' in text
    assert 'psql_prod < "$CANDIDATE_WORKTREE/$AUDIT_VALIDATION_REL"' in text
    assert 'psql_prod < "$CANDIDATE_WORKTREE/$MOVEMENT_VALIDATION_REL"' in text
    assert "DATABASE-WIDE AUDIT VALIDATION: PASS" in text
    assert "MOVEMENT CONTRACT VALIDATION: PASS" in text


def test_audit_recovery_creates_new_post_065_backup_before_repair() -> None:
    text = read(SERVER)
    assert 'BACKUP_FILE="$BACKUP_DIR/msb-post-065-pre-audit-recovery-$STAMP.dump"' in text
    assert 'pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$BACKUP_FILE"' in text
    assert 'pg_restore --list < "$BACKUP_FILE"' in text
    assert "Post-065 / pre-audit rollback archive retained at:" in text
    assert "Shared audit repair reached committed state and is intentionally not auto-restored." in text


def test_audit_recovery_leaves_no_validation_movement_evidence() -> None:
    text = read(SERVER)
    assert "new_movement_evidence_count()" in text
    assert 'if [[ "$INITIAL_NEW_EVIDENCE" != "0" ]]' in text
    assert 'if [[ "$POST_VALIDATION_EVIDENCE" != "0" ]]' in text
    assert '[[ "$FINAL_NEW_EVIDENCE" == "0" ]]' in text
    assert '[[ "$FINAL_MOVEMENT_EVENTS" == "$INITIAL_MOVEMENT_EVENTS" ]]' in text
    assert '[[ "$FINAL_CONTAINER_STATE" == "$INITIAL_CONTAINER_STATE" ]]' in text
    assert '[[ "$FINAL_DISPLAY_STATE" == "$INITIAL_DISPLAY_STATE" ]]' in text


def test_audit_recovery_does_not_touch_scan_directus() -> None:
    text = read(SERVER)
    for forbidden in (
        "DIRECTUS_CONTAINER",
        "SCAN_LIVE_PATH",
        "restart_directus",
        "docker restart msb-directus",
        "Install exact approved Scan artifact",
        "/scan/field-test",
    ):
        assert forbidden not in text
    assert "Scan/Directus: NOT MUTATED" in text


def test_audit_recovery_promotes_exact_accepted_app_only_after_validation() -> None:
    text = read(SERVER)
    assert 'APP_TARGET_SHA="7da6828d7b884ee5bb12123dab647bd6fadfba50"' in text
    assert 'EXPECTED_POST_VERSION="V0.3.29-pick-clarity"' in text
    assert 'sudo git -C "$SETUP_ROOT" checkout --detach "$APP_TARGET_SHA"' in text
    assert "PROTECTED MOVEMENT API NEGATIVE PATH: PASS" in text
    assert "LIVE SETUP REGRESSION: PASS" in text
    assert "SETUP_88_V0329_AUDIT_RECOVERY_PASS" in text
