from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
SETUP_DIR = APP_DIR.parent
ACCEPTANCE = SETUP_DIR / "Acceptance"

LAUNCHER = (ACCEPTANCE / "run_setup_disposable_browser_preview.ps1").read_text(
    encoding="utf-8"
)
SERVER = (
    ACCEPTANCE / "people_identity_bootstrap_disposable_browser_preview_server.sh"
).read_text(encoding="utf-8")
ENTRY = (
    ACCEPTANCE / "people_identity_bootstrap_disposable_browser_preview_entry.py"
).read_text(encoding="utf-8")


def test_reusable_launcher_adds_people_profile_without_replacing_setup_default() -> None:
    assert "[ValidateSet('Setup','PeopleIdentityBootstrap')]" in LAUNCHER
    assert "[string]$PreviewProfile = 'Setup'" in LAUNCHER
    assert "Get-CandidateSetupBuildIdentity" in LAUNCHER
    assert "$PreviewProfile -eq 'Setup'" in LAUNCHER
    assert "$PreviewProfile -eq 'PeopleIdentityBootstrap'" in LAUNCHER
    assert "People/Application/backend.py" in LAUNCHER
    assert "APP_VERSION" in LAUNCHER


def test_people_profile_is_pinned_to_registered_8898_review_port() -> None:
    assert "$PreviewPort -ne 8898" in LAUNCHER
    assert "registered port 8898" in LAUNCHER
    assert '"$PREVIEW_PORT" != "8898"' in SERVER
    assert "registered stable port 8898" in SERVER
    assert "8795" not in SERVER


def test_people_profile_requires_exact_external_apps_identity() -> None:
    assert "[string]$ExternalAppsSha" in LAUNCHER
    assert "[string]$ExternalAppsBlob" in LAUNCHER
    assert "external_apps_sha" in LAUNCHER
    assert "$ExternalAppsSha" in LAUNCHER
    assert "external_apps_blob" in LAUNCHER
    assert "$ExternalAppsBlob" in LAUNCHER
    assert 'external_apps_sha) BACKBONE_APPS_SHA="$value"' in SERVER
    assert 'external_apps_blob) BACKBONE_APPS_BLOB="$value"' in SERVER
    assert "git hash-object" in SERVER
    assert "Apps candidate blob mismatch" in SERVER



def test_apps_source_is_authenticated_byte_exact_and_uploaded_before_server_contact() -> None:
    # The pinned draft Backbone Apps raw URL returned HTTP 404 during preflight.
    # Authenticate via workstation Git, pin commit/tree blob/checkout/bundle,
    # then independently hash the byte-identical SCP payload server-side.
    assert "git clone --quiet --no-checkout" in LAUNCHER
    assert "Gregovate/MSB-Internal-Web-Backbone.git" in LAUNCHER
    assert "core.autocrlf=false" in LAUNCHER
    assert 'rev-parse "${ExternalAppsSha}:my/apps/index.html"' in LAUNCHER
    assert "hash-object -- $appsSource" in LAUNCHER
    assert "[System.IO.File]::Copy($appsSource, $bundledApps)" in LAUNCHER
    assert "hash-object -- $bundledApps" in LAUNCHER
    assert "STOP before server contact: bundled Apps file" in LAUNCHER
    assert "scp -r $localBundle" in LAUNCHER
    assert "chmod 644 '$remoteEntry' '$remoteApps'" in LAUNCHER
    assert "Remove-Item -LiteralPath $backboneSourceDir" in LAUNCHER

    assert "raw.githubusercontent.com" not in SERVER
    assert '[[ -s "$APPS_HTML" ]]' in SERVER
    assert "bundled Backbone Apps candidate missing or empty" in SERVER
    assert 'git hash-object "$APPS_HTML"' in SERVER
    assert "Apps candidate blob mismatch" in SERVER
    assert SERVER.index('git hash-object "$APPS_HTML"') < SERVER.index("pg_dump")


def test_people_profile_uses_same_foreground_reconnect_transport() -> None:
    assert "$resumeCommand" in LAUNCHER
    assert "timeout --foreground --signal=TERM 28800s" in LAUNCHER
    assert "ServerAliveInterval=15" in LAUNCHER
    assert "Start-Process" not in LAUNCHER
    assert "ssh -N" not in LAUNCHER

    for token in (
        'MODE="${2:-start}"',
        "write_resume_state",
        "resume_existing_preview",
        "PRESERVE_FOR_RECONNECT=1",
        "trap preserve_transport_loss HUP",
        "TRANSPORT_LOST",
    ):
        assert token in SERVER


def test_people_profile_stale_cleanup_is_profile_owned_and_fail_closed() -> None:
    assert "cleanup_stale_profile_preview" in SERVER
    assert "occupied without recognized People identity preview state" in SERVER
    assert "refusing to kill it" in SERVER
    assert "people_identity_bootstrap_disposable_browser_preview_entry.py" in SERVER
    assert 'sudo -u fieldwiring -H kill -- -"$pgid"' in SERVER
    assert "msb-395-browser-directus-" in SERVER
    assert "msb-395-browser-db-" in SERVER
    assert "PASS: stale People identity preview removed narrowly" in SERVER


def test_people_profile_preserves_production_and_uses_disposable_directus() -> None:
    assert 'PROD_DB_CONTAINER="msb-postgres"' in SERVER
    assert 'PROD_DIRECTUS_CONTAINER="msb-directus"' in SERVER
    assert 'DIRECTUS_IMAGE="directus/directus:11.17.1"' in SERVER
    assert "pg_dump" in SERVER
    assert "Production ref.person fingerprint unchanged" in SERVER
    assert "Production directus_users fingerprint unchanged" in SERVER
    assert 'docker rm -f "$TEST_DIRECTUS_CONTAINER"' in SERVER
    assert 'docker rm -f "$TEST_DB_CONTAINER"' in SERVER
    assert 'docker rm -f "$PROD_DIRECTUS_CONTAINER"' not in SERVER
    assert 'docker rm -f "$PROD_DB_CONTAINER"' not in SERVER
    assert "systemctl restart" not in SERVER
    assert "git checkout" not in SERVER


def test_people_profile_runs_exact_accepted_candidate_and_version() -> None:
    assert 'worktree add --detach "$WORKTREE" "$RUNTIME_SHA"' in SERVER
    assert "People/Application/backend.py" in SERVER
    assert "People/Database/006_create_silent_identity_bootstrap_contract.sql" in SERVER
    assert "CANDIDATE_VERSION" in SERVER
    assert "does not match expected" in SERVER
    assert "test_people_manager_contract.py" in SERVER
    assert "test_people_identity_bootstrap_runtime.py" in SERVER
    assert "test_people_shared_tablet_identity_contract.py" in SERVER


def test_people_profile_browser_path_exercises_real_bootstrap_and_idempotence() -> None:
    assert "READY_CREATE" in SERVER
    assert "MSB Browser" in SERVER
    assert "/people/api/identity/bootstrap" in SERVER
    assert "browser created exact Google Directus identity" in SERVER
    assert '"created":false' in SERVER
    assert "repeat bootstrap is idempotent" in SERVER


def test_preview_entry_mounts_exact_people_candidate_under_apps_without_analytics() -> None:
    assert 'DispatcherMiddleware(apps_app, {"/people": people_app})' in ENTRY
    assert 'HTTP_CF_ACCESS_AUTHENTICATED_USER_EMAIL' in ENTRY
    assert 'MSB_PREVIEW_APPS_HTML' in ENTRY
    assert "analytics intentionally disabled" in ENTRY
    assert 'run_simple(HOST, PORT, application, use_reloader=False)' in ENTRY



def test_preview_entry_syntax_gate_works_with_read_only_uploaded_bundle() -> None:
    # The SSH upload is owned by the operator; fieldwiring can read, not write.
    # Running py_compile would attempt to create __pycache__ and fail preflight.
    assert "chmod 755 '$remoteBundle'" in LAUNCHER
    assert "chmod 644 '$remoteEntry'" in LAUNCHER
    assert ' -m py_compile "$PREVIEW_ENTRY"' not in SERVER
    assert 'sudo -u fieldwiring -H "$PRODUCTION_PYTHON" -c' in SERVER
    assert 'compile(source.read_bytes(), str(source), "exec")' in SERVER


def test_people_profile_does_not_touch_don_fixture() -> None:
    combined = LAUNCHER + SERVER + ENTRY
    assert "dmartens@sheboyganlights.org" not in combined
    assert "Don Martens" not in combined
