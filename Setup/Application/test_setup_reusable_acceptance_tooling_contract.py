from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
SETUP_DIR = APP_DIR.parent
ACCEPTANCE_DIR = SETUP_DIR / "Acceptance"


def read_acceptance(name: str) -> str:
    return (ACCEPTANCE_DIR / name).read_text(encoding="utf-8")


def test_reusable_disposable_acceptance_is_parameterized_not_feature_pinned() -> None:
    launcher = read_acceptance("run_setup_disposable_acceptance.ps1")
    server = read_acceptance("setup_disposable_acceptance_server.sh")

    assert "[string]$CandidateSha" in launcher
    assert "[string]$TargetRef" in launcher
    assert "[string[]]$MigrationPaths" in launcher
    assert "[string[]]$ValidationPaths" in launcher
    assert "candidate_sha`t$CandidateSha" in launcher
    assert "migration`t$path" in launcher
    assert "validation`t$path" in launcher
    assert "MIGRATIONS=()" in server
    assert "VALIDATIONS=()" in server
    assert 'case "$kind" in' in server
    assert 'migration) MIGRATIONS+=' in server
    assert 'validation) VALIDATIONS+=' in server


def test_reusable_browser_preview_is_parameterized_and_version_pinnable() -> None:
    launcher = read_acceptance("run_setup_disposable_browser_preview.ps1")
    server = read_acceptance("setup_disposable_browser_preview_server.sh")

    for token in (
        "[string]$CandidateSha",
        "[string]$TargetRef",
        "[int]$PreviewPort",
        "[string]$ExpectedVersion",
        "[string[]]$MigrationPaths",
        "[string[]]$ValidationPaths",
        "[switch]$AllowConcurrentProductionWrites",
    ):
        assert token in launcher

    assert "expected_version`t$ExpectedVersion" in launcher
    assert "allow_concurrent_production_writes`t$($AllowConcurrentProductionWrites.IsPresent.ToString().ToLowerInvariant())" in launcher
    assert 'EXPECTED_VERSION=""' in server
    assert 'ALLOW_CONCURRENT_PRODUCTION_WRITES="false"' in server
    assert 'allow_concurrent_production_writes) ALLOW_CONCURRENT_PRODUCTION_WRITES="$value" ;;' in server
    assert "PASS WITH CONCURRENT ACTIVITY" in server
    assert "Preview version pin: PASS" in server
    assert "SETUP REUSABLE DISPOSABLE BROWSER REVIEW READY" in server


def test_reusable_acceptance_uses_exact_candidate_and_full_application_regression() -> None:
    disposable = read_acceptance("setup_disposable_acceptance_server.sh")
    browser = read_acceptance("setup_disposable_browser_preview_server.sh")

    for server in (disposable, browser):
        assert 'merge-base --is-ancestor "$SETUP_HEAD_BEFORE" "$TARGET_SHA"' in server
        assert 'worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"' in server
        assert "-m pytest -q -p no:cacheprovider Setup/Application" in server
        assert 'pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc' in server
        assert 'pg_restore --list < "$DUMP_FILE"' in server


def test_reusable_acceptance_preserves_final_postgis_readiness_contract() -> None:
    for name in (
        "setup_disposable_acceptance_server.sh",
        "setup_disposable_browser_preview_server.sh",
    ):
        server = read_acceptance(name)
        assert "cat /proc/1/comm" in server
        assert '[[ "$pid1" == "postgres" ]]' in server
        assert "pg_isready" in server
        assert "final post-init ready state" in server


def test_reusable_acceptance_mirrors_current_setup_application_privileges_safely() -> None:
    for name in (
        "setup_disposable_acceptance_server.sh",
        "setup_disposable_browser_preview_server.sh",
    ):
        server = read_acceptance(name)
        assert "has_schema_privilege('fieldwiring_app'" in server
        assert "has_table_privilege('fieldwiring_app'" in server
        assert "has_function_privilege('fieldwiring_app', p.oid, 'EXECUTE')" in server
        assert "p.prokind IN ('f','w')" in server
        assert "ALTER ROLE fieldwiring_app SET default_transaction_read_only = on" in server


def test_reusable_acceptance_cleanup_and_production_after_check_are_mandatory() -> None:
    disposable = read_acceptance("setup_disposable_acceptance_server.sh")
    browser = read_acceptance("setup_disposable_browser_preview_server.sh")

    for server in (disposable, browser):
        assert "trap cleanup EXIT HUP INT TERM" in server
        assert 'docker rm -f "$TEST_CONTAINER"' in server
        assert 'worktree remove --force "$CANDIDATE_WORKTREE"' in server
        assert 'sudo rm -rf "$PYCACHE"' in server
        assert "PASS: Production Setup fingerprint unchanged" in server
        assert "PASS: live Setup checkout unchanged" in server

    assert 'sudo -u fieldwiring -H kill -- -"$PREVIEW_PGID"' in browser
    assert "preview-owned TCP port" in browser


def test_windows_launchers_keep_interactive_ssh_in_foreground() -> None:
    for name in (
        "run_setup_disposable_acceptance.ps1",
        "run_setup_disposable_browser_preview.ps1",
    ):
        launcher = read_acceptance(name)
        assert "ssh -tt" in launcher
        assert "ServerAliveInterval=15" in launcher
        assert "Start-Process" not in launcher
        assert "Tee-Object" not in launcher
        assert "ssh -f" not in launcher


def test_candidate_paths_are_restricted_to_feature_owned_directories() -> None:
    for name in (
        "run_setup_disposable_acceptance.ps1",
        "run_setup_disposable_browser_preview.ps1",
    ):
        launcher = read_acceptance(name)
        assert "Setup/Database/" in launcher
        assert "Setup/Acceptance/" in launcher
        assert "Unsafe $Kind candidate-relative path" in launcher


def test_reusable_browser_preview_concurrent_production_mode_is_explicit_and_default_strict() -> None:
    launcher = read_acceptance("run_setup_disposable_browser_preview.ps1")
    server = read_acceptance("setup_disposable_browser_preview_server.sh")

    assert "[switch]$AllowConcurrentProductionWrites" in launcher
    assert 'ALLOW_CONCURRENT_PRODUCTION_WRITES="false"' in server
    assert 'if [[ "$ALLOW_CONCURRENT_PRODUCTION_WRITES" == "true" ]]' in server
    assert "PASS WITH CONCURRENT ACTIVITY" in server
    assert "FAIL: Production Setup fingerprint changed during browser preview" in server
    assert "The preview clone is a point-in-time snapshot" in server


def test_browser_preview_allows_only_the_approved_shared_audit_repair() -> None:
    launcher = read_acceptance("run_setup_disposable_browser_preview.ps1")

    assert "$isSetupMigration = $Path.StartsWith('Setup/Database/')" in launcher
    assert "$isApprovedSharedMigration = $Path -eq 'Database/Basic_Query_Tools_Dev/Repair-SetActorOnUpdate-Attribution.sql'" in launcher
    assert "explicitly approved shared database repair" in launcher
    assert "$isSetupValidation = $Path.StartsWith('Setup/Acceptance/')" in launcher
    assert "$isApprovedSharedValidation = $Path -eq 'Database/Acceptance/database_shared_audit_actor_disposable_validation.sql'" in launcher
    assert "explicitly approved shared database validation" in launcher
    assert "Database/Basic_Query_Tools_Dev/" not in launcher.replace(
        "Database/Basic_Query_Tools_Dev/Repair-SetActorOnUpdate-Attribution.sql",
        "",
    )
    assert "Database/Acceptance/" not in launcher.replace(
        "Database/Acceptance/database_shared_audit_actor_disposable_validation.sql",
        "",
    )


def test_reusable_disposable_grant_replay_identifies_the_exact_failing_statement() -> None:
    for name in (
        "setup_disposable_acceptance_server.sh",
        "setup_disposable_browser_preview_server.sh",
    ):
        server = read_acceptance(name)
        assert 'echo "Grant replay [$grant_index]: $grant_stmt"' in server
        assert 'psql_test -c "$grant_stmt"' in server
        assert "application-role grant replay failed at statement" in server
        assert 'psql_test < "$GRANTS_FILE"' not in server
