from __future__ import annotations

from pathlib import Path


APP_DIR = Path(__file__).resolve().parent
SETUP_DIR = APP_DIR.parent
ACCEPT = SETUP_DIR / "Acceptance"
CANDIDATE_SHA = "874a1f7d090676b97de1881df973fab08985085a"


def test_preview_harness_files_exist() -> None:
    for name in (
        "run_setup_session_browser_preview.ps1",
        "setup_session_browser_preview_server.sh",
        "setup_session_browser_preview_entry.py",
        "setup_session_browser_preview_cleanup_server.sh",
    ):
        assert (ACCEPT / name).is_file(), name


def test_preview_pins_exact_candidate_and_disposable_database() -> None:
    server = (ACCEPT / "setup_session_browser_preview_server.sh").read_text(encoding="utf-8")
    wrapper = (ACCEPT / "run_setup_session_browser_preview.ps1").read_text(encoding="utf-8")

    assert f'TARGET_SHA="{CANDIDATE_SHA}"' in server
    assert f"$CandidateSha = '{CANDIDATE_SHA}'" in wrapper
    assert 'TEST_CONTAINER="msb-setup-browser-preview-' in server
    assert 'pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc' in server
    assert 'pg_restore -U "$DB_ACTOR" -d "$TEST_DB" --no-owner --no-acl --exit-on-error' in server
    assert 'SETUP_DATABASE_DSN="$DSN"' in server
    assert 'Production DB:  pg_dump + SELECT only' in server
    assert 'Preview writes: disposable PostgreSQL clone only' in server


def test_preview_applies_resource_migration_only_to_disposable_clone() -> None:
    server = (ACCEPT / "setup_session_browser_preview_server.sh").read_text(encoding="utf-8")
    assert '008_create_setup_resource_management_commands.sql' in server
    assert 'psql_test < "$RESOURCE_MIGRATION"' in server
    assert 'Disposable Setup resource migration 008: PASS' in server
    assert 'ref.create_setup_resource(text,text,text,text)' in server
    assert 'ref.set_setup_task_resource(text,bigint,integer,integer,text,text,boolean)' in server


def test_preview_preserves_setup_authorization_and_no_broad_dml() -> None:
    server = (ACCEPT / "setup_session_browser_preview_server.sh").read_text(encoding="utf-8")

    assert "ref.setup_browser_capabilities(text)" in server
    assert "ref.setup_management_actor(text,boolean)" in server
    assert "ops.create_setup_session(text,integer,text)" in server
    assert "ref.create_setup_task(" in server
    assert "ref.update_setup_task(" in server
    assert "ops.update_setup_session_task_review(" in server
    assert "has_table_privilege('fieldwiring_app', 'ref.setup_task', 'UPDATE')" in server
    assert "has_table_privilege('fieldwiring_app', 'ref.setup_task_resource', 'UPDATE')" in server
    assert "has_table_privilege('fieldwiring_app', 'ops.setup_session_task', 'UPDATE')" in server
    assert "has_table_privilege('fieldwiring_app', 'ops.setup_movement_event', 'INSERT')" in server
    assert "has_table_privilege('fieldwiring_app', 'directus_users', 'SELECT')" in server


def test_preview_uses_separate_local_port_and_foreground_ssh() -> None:
    server = (ACCEPT / "setup_session_browser_preview_server.sh").read_text(encoding="utf-8")
    wrapper = (ACCEPT / "run_setup_session_browser_preview.ps1").read_text(encoding="utf-8")

    assert 'PREVIEW_PORT="${1:-8794}"' in server
    assert "[int]$PreviewPort = 8794" in wrapper
    assert 'MSB_SETUP_PREVIEW_HOST="127.0.0.1"' in server
    assert 'http://127.0.0.1:$PREVIEW_PORT/' in server
    assert '& ssh -tt -L "${PreviewPort}:127.0.0.1:${PreviewPort}"' in wrapper
    assert 'Start-Process $browserUrl' in wrapper
    assert 'setsid /opt/fieldwiring/.venv/bin/python "$MSB_SETUP_PREVIEW_ENTRY"' in server
    assert "setsid sudo" not in server


def test_preview_uses_production_setup_app_and_read_only_display_folders() -> None:
    entry = (ACCEPT / "setup_session_browser_preview_entry.py").read_text(encoding="utf-8")
    server = (ACCEPT / "setup_session_browser_preview_server.sh").read_text(encoding="utf-8")

    assert "from production_backend import app" in entry
    assert 'HTTP_CF_ACCESS_AUTHENTICATED_USER_EMAIL' in entry
    assert 'SETUP_DRIVE_ROOT="/mnt/msb-display-folders"' in server
    assert 'systemctl is-active --quiet msb-display-folders.service' in server
    assert "test -r /mnt/msb-display-folders" in server
    assert "test -x /mnt/msb-display-folders" in server


def test_preview_bridges_google_doc_identity_without_exposing_rclone_credentials() -> None:
    server = (ACCEPT / "setup_session_browser_preview_server.sh").read_text(encoding="utf-8")

    assert 'sudo -u msb-docs-fs -H /usr/bin/rclone lsjson' in server
    assert '--original' in server
    assert 'SETUP_GOOGLE_DOC_INDEX="$GOOGLE_DOC_INDEX"' in server
    assert 'sudo chown msb-docs-fs:msb-docs-read "$GOOGLE_DOC_INDEX"' in server
    assert 'sudo chmod 0640 "$GOOGLE_DOC_INDEX"' in server
    assert 'Mega Cube Google Doc/native Word discrimination: PASS' in server
    assert '03-Mega Cube-MC Setup Procedure.gdoc' in server
    assert 'Randy' in server


def test_preview_checks_resource_api_and_review_target() -> None:
    server = (ACCEPT / "setup_session_browser_preview_server.sh").read_text(encoding="utf-8")
    assert '/api/setup/resources' in server
    assert 'Front Entrance should show SkyTrak + Boom Lift' in server
    assert 'Equipment / Resources Needed' in server


def test_preview_cleanup_guards_live_checkout_and_setup_fingerprint() -> None:
    server = (ACCEPT / "setup_session_browser_preview_server.sh").read_text(encoding="utf-8")
    cleanup = (ACCEPT / "setup_session_browser_preview_cleanup_server.sh").read_text(encoding="utf-8")

    assert "prod_fingerprint()" in server
    assert "FROM ref.setup_resource r" in server
    assert "FROM ref.setup_task_resource tr" in server
    assert "Production Setup fingerprint unchanged" in server
    assert "live shared checkout unchanged" in server
    assert "worktree remove --force" in server
    assert "docker rm -f" in server
    assert 'rm -f "$DUMP_FILE" "$GOOGLE_DOC_INDEX"' in server
    assert "msb-setup-browser-preview-candidate-" in cleanup
    assert "msb-setup-browser-preview-" in cleanup
