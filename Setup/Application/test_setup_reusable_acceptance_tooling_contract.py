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


def test_reusable_launchers_fail_before_server_contact_on_setup_build_identity_drift() -> None:
    disposable = read_acceptance("run_setup_disposable_acceptance.ps1")
    browser = read_acceptance("run_setup_disposable_browser_preview.ps1")

    for launcher in (disposable, browser):
        assert "function Get-CandidateSetupBuildIdentity" in launcher
        assert "Setup/Application/production_backend.py" in launcher
        assert "Setup/Application/setup_catalog_dirty_guard.js" in launcher
        assert "PRODUCTION_VERSION" in launcher
        assert "CLIENT_BUILD" in launcher
        assert "$buildIdentity.Server -ne $buildIdentity.Client" in launcher
        assert "STOP before server contact: Setup client/server version mismatch" in launcher

    assert "[Parameter(Mandatory=$true)]\n    [string]$ExpectedVersion" in browser
    assert "$ExpectedVersion -ne $buildIdentity.Server" in browser
    assert "ExpectedVersion" in browser
    assert "does not match exact candidate Setup build" in browser


def test_reusable_browser_preview_recovers_transport_loss_without_rebuilding_clone() -> None:
    launcher = read_acceptance("run_setup_disposable_browser_preview.ps1")
    server = read_acceptance("setup_disposable_browser_preview_server.sh")

    # Application candidate may stay pinned while later commits harden only the
    # reusable acceptance tooling, matching the accepted #151 pattern.
    assert "$toolingHead = (git -C $repo rev-parse HEAD).Trim()" in launcher
    assert "merge-base --is-ancestor $CandidateSha $toolingHead" in launcher
    assert "does not equal requested candidate" not in launcher

    # The remote preview writes resumable state before the operator-review wait.
    for token in (
        'MODE="${2:-start}"',
        'STATE_FILE="/tmp/msb-setup-browser-preview-state-${PREVIEW_PORT}.env"',
        "write_resume_state",
        "resume_existing_preview",
        "PRESERVE_FOR_RECONNECT=1",
        "SETUP_BROWSER_PREVIEW_TRANSPORT_LOST",
        "preserving preview for reconnect",
    ):
        assert token in server

    # A lost PTY must not trigger destructive cleanup of the healthy clone.
    assert 'trap cleanup EXIT INT TERM' in server
    assert 'trap preserve_transport_loss HUP' in server
    assert 'if ! read -r _done; then' in server

    # The workstation launcher re-establishes the foreground SSH tunnel to the
    # same remote preview instead of re-running clone preparation.
    assert "$resumeCommand" in launcher
    assert "$mode = 'resume'" in launcher
    assert "$maxReconnectAttempts = 12" in launcher
    assert "Reconnecting to preserved Setup browser preview" in launcher
    assert "Start-Process" not in launcher
    assert "ssh -N" not in launcher

def test_reusable_browser_preview_preserves_setup_procedure_runtime_mounts() -> None:
    server = read_acceptance("setup_disposable_browser_preview_server.sh")

    assert "msb-display-folders.service" in server
    assert "msb-setup-google-links.service" in server
    assert "/mnt/msb-display-folders" in server
    assert "/mnt/msb-setup-google-links" in server
    assert 'SETUP_DRIVE_ROOT="/mnt/msb-display-folders"' in server
    assert 'SETUP_GOOGLE_DOC_LINK_ROOT="/mnt/msb-setup-google-links"' in server
    assert '"8796"' in server


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


def test_reusable_acceptance_uses_established_setup_read_boundary_and_production_command_acls() -> None:
    for name in (
        "setup_disposable_acceptance_server.sh",
        "setup_disposable_browser_preview_server.sh",
    ):
        server = read_acceptance(name)

        # Accepted Setup disposable previews use a broad read-only application
        # surface across the business schemas while preserving narrow command
        # writes. Do not infer schema/table grants from a --no-acl clone.
        assert "GRANT USAGE ON SCHEMA ref, ops, lor_snap TO fieldwiring_app;" in server
        assert "GRANT SELECT ON ALL TABLES IN SCHEMA ref, ops, lor_snap TO fieldwiring_app;" in server

        # Command EXECUTE and PUBLIC revokes still come from current Production
        # catalog ACLs so new governed commands remain synchronized.
        assert "aclexplode(p.proacl)" in server
        assert "grantee.rolname = 'fieldwiring_app'" in server
        assert "acl.privilege_type = 'EXECUTE'" in server
        assert "public_acl.grantee = 0" in server
        assert "REVOKE ALL ON FUNCTION %I.%I(%s) FROM PUBLIC;" in server
        assert "ALTER ROLE fieldwiring_app SET default_transaction_read_only = on" in server
        assert "Production role/ACL diagnostic (read-only)" in server
        assert "pg_auth_members" in server

        # The reconstructed clone must prove both required access and forbidden
        # broad/internal write access before any candidate migration/browser.
        assert "Preview fieldwiring_app lacks required schema USAGE" in server
        assert "Preview fieldwiring_app lacks required Setup SELECT boundary" in server
        assert "Preview fieldwiring_app cannot execute Setup capability function" in server
        if name == "setup_disposable_browser_preview_server.sh":
            assert "Production Setup function authorization boundary: PASS" in server
        else:
            assert "Preview fieldwiring_app can execute internal Setup actor helper" in server
        assert "Preview fieldwiring_app unexpectedly has broad Setup DML" in server
        assert "Established Setup disposable read boundary + Production command ACL replay: PASS" in server


def test_reusable_acceptance_cleanup_and_production_after_check_are_mandatory() -> None:
    disposable = read_acceptance("setup_disposable_acceptance_server.sh")
    browser = read_acceptance("setup_disposable_browser_preview_server.sh")

    assert "trap cleanup EXIT HUP INT TERM" in disposable
    assert "trap cleanup EXIT INT TERM" in browser
    assert "trap preserve_transport_loss HUP" in browser

    for server in (disposable, browser):
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


def test_reusable_disposable_grant_replay_is_batched_and_fail_fast() -> None:
    for name in (
        "setup_disposable_acceptance_server.sh",
        "setup_disposable_browser_preview_server.sh",
    ):
        server = read_acceptance(name)
        assert "Production function ACL statements extracted:" in server
        assert 'psql_test -q < "$GRANTS_FILE"' in server
        assert "Production function ACL batch replay: PASS" in server
        assert "application-role function ACL batch replay failed" in server
        assert 'echo "Grant replay [$grant_index]: $grant_stmt"' not in server
        assert 'psql_test -c "$grant_stmt" </dev/null' not in server


def test_reusable_acl_batch_block_is_complete_before_role_lockdown() -> None:
    for name in (
        "setup_disposable_acceptance_server.sh",
        "setup_disposable_browser_preview_server.sh",
    ):
        server = read_acceptance(name)
        assert 'grant_count="$(wc -l < "$GRANTS_FILE" | tr -d \'[:space:]\')"' in server
        count_at = server.index("Production function ACL statements extracted:")
        replay_at = server.index('psql_test -q < "$GRANTS_FILE"')
        pass_at = server.index("Production function ACL batch replay: PASS")
        readonly_at = server.index(
            'psql_test -c "ALTER ROLE fieldwiring_app SET default_transaction_read_only = on;"'
        )
        assert count_at < replay_at < pass_at < readonly_at


def test_reusable_disposable_acceptance_allows_tooling_descendant_of_exact_candidate() -> None:
    launcher = read_acceptance("run_setup_disposable_acceptance.ps1")

    assert "$toolingHead = (git -C $repo rev-parse HEAD).Trim()" in launcher
    assert "merge-base --is-ancestor $CandidateSha $toolingHead" in launcher
    assert "requested candidate $CandidateSha is not an ancestor of current acceptance-tooling HEAD $toolingHead" in launcher
    assert "does not equal requested candidate" not in launcher


def test_reusable_acceptance_runners_have_single_main_flow_tail() -> None:
    disposable = read_acceptance("setup_disposable_acceptance_server.sh")
    browser = read_acceptance("setup_disposable_browser_preview_server.sh")

    assert disposable.count("SETUP_REUSABLE_DISPOSABLE_ACCEPTANCE_PASS") == 1
    assert disposable.count("Production function ACL statements extracted:") == 1
    assert disposable.count("Production function ACL batch replay: PASS") == 1

    # Browser has one resume completion marker and one normal main-flow marker.
    assert browser.count("SETUP_REUSABLE_DISPOSABLE_BROWSER_PREVIEW_CLEAN_EXIT") == 2
    assert browser.count("Production function ACL statements extracted:") == 1
    assert browser.count("Production function ACL batch replay: PASS") == 1

    assert disposable.rstrip().endswith(
        'echo "SETUP_REUSABLE_DISPOSABLE_ACCEPTANCE_PASS"'
    )
    assert browser.rstrip().endswith(
        'echo "SETUP_REUSABLE_DISPOSABLE_BROWSER_PREVIEW_CLEAN_EXIT"'
    )


def test_reusable_disposable_allows_only_the_approved_shared_audit_repair() -> None:
    launcher = read_acceptance("run_setup_disposable_acceptance.ps1")

    assert "$isSetupMigration = $Path.StartsWith('Setup/Database/')" in launcher
    assert "$isApprovedSharedMigration = $Path -eq 'Database/Basic_Query_Tools_Dev/Repair-SetActorOnUpdate-Attribution.sql'" in launcher
    assert "explicitly approved shared database repair" in launcher
    assert "$isSetupValidation = $Path.StartsWith('Setup/Acceptance/')" in launcher
    assert "$isApprovedSharedValidation = $Path -eq 'Database/Acceptance/database_shared_audit_actor_disposable_validation.sql'" in launcher
    assert "explicitly approved shared database validation" in launcher
