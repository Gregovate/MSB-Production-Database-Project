"""Engineering checks; PostgreSQL/PostGIS execution remains a disposable gate."""
from contextlib import nullcontext
from copy import deepcopy
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from site_source_db import _track_geometry, bootstrap_expertgps, export_map_projection
from test_site_source_sync import sample_gpx
from site_source_sync import sha256


class RecordingConnection:
    def __init__(self, responses):
        self.responses = iter(responses)
        self.statements = []

    def transaction(self):
        return nullcontext()

    def cursor(self):
        return nullcontext(self)

    def execute(self, statement, params=None):
        self.statements.append((statement, params))

    def fetchone(self):
        return next(self.responses)

    def fetchall(self):
        return next(self.responses)


def test_bootstrap_replay_preserves_maintained_data(sample_gpx):
    conn = RecordingConnection([(1, 1, 1, 1)])
    result = bootstrap_expertgps(conn, sample_gpx, 'manager', sha256(sample_gpx))
    assert result['status'] == 'ALREADY_ACCEPTED'
    assert not any('INSERT' in sql or 'UPDATE' in sql for sql, _ in conn.statements)


def test_changed_baseline_stops_before_database_access(sample_gpx):
    conn = RecordingConnection([])
    with pytest.raises(ValueError, match='reviewed SHA256'):
        bootstrap_expertgps(conn, sample_gpx, 'manager', '0' * 64)
    assert not conn.statements


def test_other_source_cannot_replace_existing_identities(sample_gpx):
    conn = RecordingConnection([(1, 1, 0, 0)])
    with pytest.raises(ValueError, match='reconciliation required'):
        bootstrap_expertgps(conn, sample_gpx, 'manager', sha256(sample_gpx))
    assert not any('INSERT' in sql or 'UPDATE' in sql for sql, _ in conn.statements)


def test_bootstrap_keeps_garmin_alias_and_corrected_map_identity(sample_gpx):
    conn = RecordingConnection([(0, 0, 0, 0), (51,), (61,)])
    result = bootstrap_expertgps(conn, sample_gpx, 'manager', sha256(sample_gpx))
    assert result['status'] == 'ACCEPTED'
    inserts = [(sql, p) for sql, p in conn.statements if 'INSERT INTO ref.site_waypoint\n' in sql]
    assert inserts[0][1][:2] == ('A5-07/09', 'A5-Church')
    bindings = [p for sql, p in conn.statements if 'INSERT INTO ref.site_track_source_binding' in sql]
    assert bindings == [(61, sha256(sample_gpx), 1, 'manager')]


def test_incomplete_trace_never_becomes_fabricated_line():
    track = {'ordinal': 6, 'segments': [[{'lon': '-87', 'lat': '43', 'ele': '1'}]]}
    before = deepcopy(track)
    assert _track_geometry(track)['coordinates'] == []
    assert track == before


@pytest.mark.parametrize('lon,lat', [('nan', '43'), ('-87', 'inf'), ('181', '43'), ('0', '-91')])
def test_invalid_geography_rejected(lon, lat):
    with pytest.raises(ValueError, match='WGS84'):
        _track_geometry({'segments': [[{'lon': lon, 'lat': lat}]]})


def test_map_shared_route_single_feature_and_other_gpx_tracks_preserved():
    line = {'type': 'LineString', 'coordinates': [[-87, 43], [-87.1, 43.1]]}
    def export(label='A'):
        return export_map_projection(RecordingConnection([
            [(1, label, 'OUT-Combo', {'type': 'Point', 'coordinates': [-87, 43]})],
            [(9, 'Shared corridor', 1, 2, line, [11, 12], [21])],
            [(21, 'HV historical', '', line, True),
             (22, 'Footpath', '', line, True),
             (23, 'PRI one point', '', None, False)]]))
    data = export()
    routes = [f for f in data['features'] if f['properties']['kind'] == 'shared_route']
    assert len(routes) == 1
    assert routes[0]['properties']['cable_ids'] == [11, 12]
    traces = {f['id']: f for f in data['features'] if f['properties']['kind'] == 'source_track'}
    assert not traces['track:21']['properties']['visible_by_default']
    assert traces['track:22']['properties']['visible_by_default']
    assert traces['track:22']['geometry'] == line
    assert traces['track:23']['properties']['geometry_status'] == 'INCOMPLETE'
    assert export()['revision'] == data['revision']
    assert export('Corrected A')['revision'] != data['revision']
