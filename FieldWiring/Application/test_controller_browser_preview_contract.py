from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent
REPO_ROOT = BASE_DIR.parent.parent
ACCEPT = REPO_ROOT / "Controllers" / "Acceptance"
CANDIDATE_SHA = "2fd2067958cc0a903260fe6f089f88ae63a857f1"


def test_browser_preview_pins_exact_candidate_and_disposable_database() -> None:
    server = (ACCEPT / "controller_setup_management_browser_preview_server.sh").read_text(
        encoding="utf-8"
    )

    assert f'TARGET_SHA="{CANDIDATE_SHA}"' in server
    assert 'TEST_CONTAINER="msb-controller-browser-preview-' in server
    assert 'TEST_DB="msb_controller_browser_preview"' in server
    assert 'pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc' in server
    assert 'pg_restore -U "$DB_ACTOR" -d "$TEST_DB" --no-owner --no-acl' in server
    assert '< "$MIGRATION_023"' in server
    assert '< "$MIGRATION_024"' in server
    assert 'FIELDWIRING_DATABASE_DSN="$DSN"' in server


def test_browser_preview_preserves_controller_write_boundary() -> None:
    server = (ACCEPT / "controller_setup_management_browser_preview_server.sh").read_text(
        encoding="utf-8"
    )
    entry = (ACCEPT / "controller_setup_management_browser_preview_entry.py").read_text(
        encoding="utf-8"
    )

    assert "GRANT SELECT ON ALL TABLES IN SCHEMA ref, lor_snap, ops" in server
    assert "GRANT INSERT ON" not in server
    assert "GRANT UPDATE ON" not in server
    assert "GRANT DELETE ON" not in server
    assert "REVOKE ALL ON FUNCTION ref.controller_browser_capabilities(text) FROM PUBLIC" in server
    assert "REVOKE ALL ON FUNCTION ref.request_controller_label(text,bigint) FROM PUBLIC" in server
    assert "has_table_privilege('fieldwiring_app', 'ref.controller', 'INSERT')" in server
    assert "has_table_privilege('fieldwiring_app', 'ref.controller', 'UPDATE')" in server
    assert "has_table_privilege('fieldwiring_app', 'ref.controller_display', 'INSERT')" in server
    assert ":'preview_email'" not in server
    assert "ref.controller_browser_capabilities('$PREVIEW_EMAIL')" in server
    assert 'HTTP_CF_ACCESS_AUTHENTICATED_USER_EMAIL' in entry
    assert "backend import app" in entry
    assert "api/controller-management/options" in server


def test_browser_preview_uses_separate_local_flask_port_and_foreground_ssh() -> None:
    wrapper = (ACCEPT / "run_controller_setup_management_browser_preview.ps1").read_text(
        encoding="utf-8"
    )
    server = (ACCEPT / "controller_setup_management_browser_preview_server.sh").read_text(
        encoding="utf-8"
    )

    assert "$PreviewPort = 8793" in wrapper
    assert '-L "${PreviewPort}:127.0.0.1:${PreviewPort}"' in wrapper
    assert "& ssh -tt -L" in wrapper
    assert "Start-Process" not in wrapper
    assert "Tee-Object" not in wrapper
    assert 'MSB_PREVIEW_HOST="127.0.0.1"' in server
    assert 'http://127.0.0.1:$PREVIEW_PORT/controllers' in server
    assert 'read -r -p "Press ENTER to stop and clean up the browser preview' in server


def test_browser_preview_switches_runtime_user_before_backgrounding_flask() -> None:
    server = (ACCEPT / "controller_setup_management_browser_preview_server.sh").read_text(
        encoding="utf-8"
    )

    assert "sudo -u fieldwiring -H env" in server
    assert "bash -c '" in server
    assert 'setsid /opt/fieldwiring/.venv/bin/python "$MSB_PREVIEW_ENTRY"' in server
    assert 'echo $!' in server
    assert "setsid sudo" not in server


def test_browser_preview_cleanup_proves_production_unchanged() -> None:
    server = (ACCEPT / "controller_setup_management_browser_preview_server.sh").read_text(
        encoding="utf-8"
    )

    assert 'PROD_BEFORE="$(prod_fingerprint)"' in server
    assert 'PROD_AFTER="$(prod_fingerprint 2>/dev/null)"' in server
    assert "production Controller fingerprint changed during browser preview" in server
    assert 'sudo docker rm -f "$TEST_CONTAINER"' in server
    assert 'worktree remove --force "$CANDIDATE_WORKTREE"' in server
    assert 'rm -f "$DUMP_FILE"' in server
    assert 'kill -- -"$PREVIEW_PGID"' in server
    assert "sudo git -C \"$FIELDWIRING_ROOT\" merge" not in server
    assert "systemctl restart" not in server
