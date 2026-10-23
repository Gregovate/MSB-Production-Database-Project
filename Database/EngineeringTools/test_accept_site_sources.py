"""Exercise GPX-only acceptance without requiring unrelated tester evidence."""
from contextlib import nullcontext
import json
from types import SimpleNamespace
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import accept_site_sources as gate
import site_db_connection
from test_site_source_sync import sample_gpx


def setup_gate(monkeypatch, sample_gpx, tmp_path, dbname='msb_setup_browser_preview'):
    output = tmp_path / 'receipt'
    digest = gate.sha256(sample_gpx)
    monkeypatch.setattr(sys, 'argv', ['accept_site_sources', '--gpx', str(sample_gpx),
        '--gpx-sha', digest, '--operator-email', 'fixture@example.invalid', '--actor', 'fixture-reviewer', '--output', str(output)])
    conn = SimpleNamespace(info=SimpleNamespace(dbname=dbname))
    monkeypatch.setattr(site_db_connection, 'connect', lambda dsn: nullcontext(conn))
    monkeypatch.setattr(gate, 'validate_shared_consumers', lambda c, e: {'status': 'PASS'})
    calls = []
    def bootstrap(*args):
        calls.append(args)
        return {'status': 'ACCEPTED' if len(calls) == 1 else 'ALREADY_ACCEPTED'}
    monkeypatch.setattr(gate, 'bootstrap_expertgps', bootstrap)
    def forbidden(*args):
        pytest.fail('GPX-only review must not open or import FLW')
    monkeypatch.setattr(gate, 'ingest_linkiq', forbidden)
    monkeypatch.setattr(gate, 'export_map_projection', lambda c: {
        'revision': 'fixture', 'features': [
            {'properties': {'kind': k}} for k in ('waypoint', 'source_track')]})
    monkeypatch.setattr(gate, 'export_waypoint_projection', lambda c, sha: {
        'base_source_sha256': sha, 'approved_edits': []})
    def restore(conn, sha, path):
        path.write_bytes(sample_gpx.read_bytes())
        return {'source_sha256': sha, 'bytes': path.stat().st_size}
    monkeypatch.setattr(gate, 'restore_gpx_source', restore)
    return output, calls


def test_gpx_only_runs_replay_export_and_reports_flw_not_requested(monkeypatch, sample_gpx, tmp_path):
    output, calls = setup_gate(monkeypatch, sample_gpx, tmp_path)
    before = sample_gpx.read_bytes()
    gate.main()
    report = json.loads((output / 'acceptance.json').read_text())
    assert len(calls) == 2
    assert report['first_import']['status'] == 'NOT_REQUESTED'
    assert report['replay_import']['status'] == 'NOT_REQUESTED'
    assert report['gpx_replay']['status'] == 'ALREADY_ACCEPTED'
    assert sample_gpx.read_bytes() == before
    assert gate.extract_gpx(output / 'database-export.gpx')['waypoints'] == gate.extract_gpx(sample_gpx)['waypoints']


def test_gpx_only_rejects_production_before_bootstrap(monkeypatch, sample_gpx, tmp_path):
    _, calls = setup_gate(monkeypatch, sample_gpx, tmp_path, dbname='msb')
    with pytest.raises(RuntimeError, match='governed disposable'):
        gate.main()
    assert not calls


@pytest.mark.parametrize('extra', [['--flw', 'missing.flw'], ['--flw-sha', 'a' * 64]])
def test_partial_flw_input_fails_before_database(monkeypatch, sample_gpx, tmp_path, extra):
    _, calls = setup_gate(monkeypatch, sample_gpx, tmp_path)
    monkeypatch.setattr(sys, 'argv', sys.argv + extra)
    with pytest.raises(RuntimeError, match='supplied together'):
        gate.main()
    assert not calls
