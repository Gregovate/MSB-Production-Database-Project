"""#171/#230 preflight: prove browser editor provision is clone-only.

These are engineering/static checks; live server and role grants still need
the governed one-clone acceptance. Never create a Production grant in tests.
"""
from pathlib import Path

RUNNER = Path(__file__).with_name("setup_disposable_browser_preview_server.sh")


def test_manager_editor_grant_is_disposable_and_guarded_by_real_source_intake():
    text = RUNNER.read_text(encoding="utf-8")
    start = text.index('# Combined GIS/power review uses existing Directus roles;')
    end = text.index('TEST_IP=', start)
    block = text[start:end]
    assert 'if [[ "$GIS_EDITOR_PREVIEW" == "1" ]]' in block
    assert '[[ -n "$GIS_GPX_SHA" ]]' in block
    assert '171_site_reference_operations_candidate.sql' in block
    assert 'MANAGE_OK=' in text[:start]
    assert 'INSERT INTO ref.site_editor_grant' not in text
    assert 'ref.site_power_access' in block
    assert 'psql_test -qAt -F \'|\' -v preview_email=' in block
    assert 'if [[ "$GIS_GRANT_VERIFIED" != \'t|t\' ]]' in block
    # No Production SQL commands in the grant block; not a grant on live login.
    assert 'sudo docker exec "$PROD_CONTAINER"' not in block
    assert 'psql -U "$DB_ACTOR" -d "$PROD_DB"' not in block
    assert text.index('--- Apply candidate migrations to disposable clone only ---') < start
    assert start < text.index('accept_site_sources.py')
    assert text.count('pg_dump -U "$DB_ACTOR"') == 1


def test_reference_preflight_verifies_actual_authenticated_http_snapshot():
    text = RUNNER.read_text(encoding="utf-8")
    section = text[text.index('--- Verify real-source PostGIS reference map'): ]
    assert 'http://127.0.0.1:$PREVIEW_PORT/api/setup/locate/references' in section
    assert 'snapshot.get("data_mode") == "postgres"' in section
    assert 'snapshot.get("sources", {}).get("gpx", {}).get("sha256")' in section
    assert 'snapshot.get("permissions", {}).get("identity") is True' in section
    assert 'snapshot.get("power_editor_url") == "/fieldwiring/circuits"' in section
    assert 'len(snapshot.get("waypoints") or []) > 0' in section
    assert 'len(snapshot.get("tracks") or []) > 0' in section
    assert text.index('--- Verify real-source PostGIS reference map') < text.index(
        'SETUP REUSABLE DISPOSABLE BROWSER REVIEW READY'
    )
    assert 'SETUP_REUSABLE_DISPOSABLE_BROWSER_PREVIEW_CLEAN_EXIT' in text
