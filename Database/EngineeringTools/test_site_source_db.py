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


def test_bootstrap_archives_complete_document_without_claiming_field_verification(sample_gpx, tmp_path):
    import json
    from site_source_db import restore_gpx_source
    conn = RecordingConnection([(0, 0, 0, 0), (51,), (61,)])
    bootstrap_expertgps(conn, sample_gpx, 'source-reviewer', sha256(sample_gpx))
    archived = [p for sql, p in conn.statements if "'DOCUMENT'" in sql]
    assert len(archived) == 1
    output = tmp_path / 'restored.gpx'
    restore_gpx_source(RecordingConnection([(json.loads(archived[0][1]),)]), sha256(sample_gpx), output)
    assert output.read_bytes() == sample_gpx.read_bytes()
    sql = next(sql for sql, p in conn.statements if 'INSERT INTO ref.site_waypoint\n' in sql)
    assert 'verified_by' not in sql and 'verified_at' not in sql


def test_corrupt_archived_document_cannot_be_exported(tmp_path):
    from site_source_db import restore_gpx_source
    conn = RecordingConnection([({'encoding': 'base64', 'bytes': 'YmFk'},)])
    with pytest.raises(ValueError, match='SHA256'):
        restore_gpx_source(conn, '0' * 64, tmp_path / 'bad.gpx')
    assert not (tmp_path / 'bad.gpx').exists()


def test_ephemeral_postgis_document_restore_and_replay(sample_gpx, tmp_path):
    """Opt-in existing CI PostGIS service; never a Production/current-clone test."""
    import os
    from site_db_connection import connect
    from site_source_db import restore_gpx_source, export_waypoint_projection
    from site_source_sync import gpx_roundtrip
    dsn = os.environ.get('MSB_GIS_EPHEMERAL_TEST_DSN')
    if not dsn:
        pytest.skip('existing ephemeral PostGIS service not selected')
    # Real import/projection must retain independent GPS and map names/styles.
    sample_gpx.write_text(sample_gpx.read_text().replace('<trkseg>', '''<extensions>
      <o:label><o:label_text>HV display label</o:label_text></o:label>
      <line xmlns="http://www.topografix.com/GPX/gpx_style/0/2"><color>fc180d</color>
        <width>1.0417</width><opacity>1</opacity><pattern>Solid</pattern></line>
      </extensions><trkseg>'''))
    with connect(dsn) as conn:
        assert conn.info.dbname == 'site_acceptance', 'Only isolated CI database permitted'
        digest = sha256(sample_gpx)
        assert bootstrap_expertgps(conn, sample_gpx, 'ci-source-reviewer', digest)['status'] == 'ACCEPTED'
        assert bootstrap_expertgps(conn, sample_gpx, 'ci-source-reviewer', digest)['status'] == 'ALREADY_ACCEPTED'
        original = tmp_path / 'archived.gpx'
        restore_gpx_source(conn, digest, original)
        assert original.read_bytes() == sample_gpx.read_bytes()
        with conn.cursor() as cur:
            cur.execute('SELECT verified_by,verified_at FROM ref.site_waypoint')
            assert all(row == (None, None) for row in cur.fetchall())
            # Disposable correction proves identity-bound export, not just no-op.
            cur.execute("UPDATE ref.site_waypoint SET canonical_label='CI corrected map label'")
        with conn.cursor() as cur:
            cur.execute('SELECT ref.site_reference_snapshot()')
            track=cur.fetchone()[0]['tracks'][0]
            assert track['label']=='HV display label'
            assert track['source_label']=='NET Example'
            assert track['style']['color']=='fc180d'
            cur.execute("UPDATE ref.site_track SET track_label='HV reviewed display label'")
        projection = export_waypoint_projection(conn, digest)
        output = tmp_path / 'corrected.gpx'
        assert gpx_roundtrip(original, projection, output)['updated'] == 1
        from site_source_sync import extract_gpx
        exported_track=extract_gpx(output)['tracks'][0]
        assert exported_track['name']=='NET Example'
        assert exported_track['map_label']=='HV reviewed display label'
        assert exported_track['style']['color']=='fc180d'
        assert bootstrap_expertgps(conn, sample_gpx, 'ci-source-reviewer', digest)['status'] == 'ALREADY_ACCEPTED'
        assert export_waypoint_projection(conn, digest) == projection

        # Exercise the actual autocommit adapter and combined consumer gate,
        # not a fake connection that might hide transaction-boundary failures.
        from accept_site_sources import validate_shared_consumers
        assert validate_shared_consumers(conn, 'gis-ci@example.invalid')['status'] == 'PASS'
        with conn.cursor() as cur:
            cur.execute('SELECT count(*) FROM ref.site_power_breaker')
            assert cur.fetchone()[0] == 0, 'Acceptance fixtures leaked'

        from site_source_db import seed_gpx_panels
        with conn.cursor() as cur:
            cur.execute("UPDATE ref.site_waypoint SET waypoint_type='Panel'")
        assert seed_gpx_panels(conn,digest,'gis-ci@example.invalid')['created']==1
        assert seed_gpx_panels(conn,digest,'gis-ci@example.invalid')['created']==0
        with conn.cursor() as cur:
            cur.execute("SELECT p.panel_name,p.verification_status,w.canonical_label FROM ref.site_panel p JOIN ref.site_waypoint w USING(site_waypoint_id)")
            name,status,current=cur.fetchone()
            assert name==current and status=='UNVERIFIED'
        # The real catalog/data query runs against the same disposable PostGIS
        # schema. Failure must not be hidden by synthetic connection fixtures.
        from site_source_db import capture_gpx_dependencies, require_gpx_dependency_freshness
        with conn.cursor() as cur:
            cur.execute('SELECT site_waypoint_id FROM ref.site_waypoint ORDER BY site_waypoint_id')
            waypoint_id = cur.fetchone()[0]
        report = capture_gpx_dependencies(conn, [waypoint_id])
        assert report['status'] == 'RECORDED_DEPENDENCIES_CAPTURED', report['holds']
        assert report['counts']['ref.site_panel'] == 1
        assert capture_gpx_dependencies(conn, [waypoint_id]) == report
        with conn.cursor() as cur:
            cur.execute('BEGIN')
            try:
                cur.execute("UPDATE ref.site_waypoint SET canonical_label='changed after review' WHERE site_waypoint_id=%s", (waypoint_id,))
                changed = capture_gpx_dependencies(conn, [waypoint_id])
                with pytest.raises(ValueError, match='Dependency state changed'):
                    require_gpx_dependency_freshness(changed, report['dependency_sha256'])
                cur.execute('CREATE TABLE ops.ci_unknown_gis_consumer(point_id bigint REFERENCES ref.site_waypoint(site_waypoint_id))')
                unknown = capture_gpx_dependencies(conn, [waypoint_id])
                assert unknown['status'] == 'HOLD'
                assert any(h['reason'] == 'UNINVENTORIED_FK_CONSUMER' for h in unknown['holds'])
            finally:
                cur.execute('ROLLBACK')
        assert capture_gpx_dependencies(conn, [waypoint_id]) == report



@pytest.fixture
def dependency_snapshot():
    from site_source_db import _GPX_DEPENDENCY_TABLES
    data = {'tables': {t: [] for t in _GPX_DEPENDENCY_TABLES},
            'foreign_keys': [], 'rls_tables': [], 'reference_revision': 4, 'power_revision': 9}
    tables = data['tables']
    tables['ref.site_waypoint'] = [dict(site_waypoint_id=1, canonical_label='A5-18/20')]
    tables['ref.site_track'] = [dict(site_track_id=5, track_label='A5-18/20')]
    tables['ref.site_cable'] = [dict(site_cable_id=10, endpoint_a_waypoint_id=1)]
    tables['ref.site_panel'] = [dict(site_panel_id=20, panel_name='PANEL A5')]
    tables['ref.site_power_breaker'] = [dict(site_power_breaker_id=21, site_panel_id=20,
                                           rated_amps=20, pole_count=2)]
    tables['ref.site_power_circuit'] = [dict(site_power_circuit_id=i, site_power_breaker_id=21,
                                           circuit_code=code) for i, code in [(22, '18'), (23, '20')]]
    tables['ref.site_power_feed'] = [dict(site_power_feed_id=i, source_circuit_id=c,
                                        destination_waypoint_id=1) for i, c in [(24, 22), (25, 23)]]
    tables['ops.linkiq_test'] = [dict(test_uuid=uuid, physical_site_cable_id=10,
                                     tester_original_name='A5-18/20', test_time_local=date)
                                for uuid, date in [('uuid-first', '2026-10-20'), ('uuid-retest', '2026-10-23')]]
    def fk(child, column, parent, key):
        data['foreign_keys'].append(dict(name=child+'_'+column+'_fk', child=child,
            child_columns=[column], parent=parent, parent_columns=[key], validated=True))
    fk('ref.site_cable', 'endpoint_a_waypoint_id', 'ref.site_waypoint', 'site_waypoint_id')
    fk('ops.linkiq_test', 'physical_site_cable_id', 'ref.site_cable', 'site_cable_id')
    fk('ref.site_power_feed', 'destination_waypoint_id', 'ref.site_waypoint', 'site_waypoint_id')
    fk('ref.site_power_feed', 'source_circuit_id', 'ref.site_power_circuit', 'site_power_circuit_id')
    fk('ref.site_power_circuit', 'site_power_breaker_id', 'ref.site_power_breaker', 'site_power_breaker_id')
    fk('ref.site_power_breaker', 'site_panel_id', 'ref.site_panel', 'site_panel_id')
    return data


def test_dependency_rename_preserves_bindings_and_both_dated_retests(dependency_snapshot):
    from site_source_db import _gpx_dependency_report, require_gpx_dependency_freshness
    before = deepcopy(dependency_snapshot)
    report = _gpx_dependency_report(before, [1], [])
    assert report['counts']['ref.site_power_circuit'] == 2
    assert report['counts']['ref.site_power_breaker'] == 1
    assert report['counts']['ops.linkiq_test'] == 2
    assert report['counts']['ref.site_track'] == 0  # Same label does not imply topology.
    dependency_snapshot['tables']['ref.site_waypoint'][0]['canonical_label'] = 'A5 corrected'
    after = _gpx_dependency_report(dependency_snapshot, [1], [])
    tests = lambda r: [x for x in r['related_records'] if x['table'] == 'ops.linkiq_test']
    assert tests(after) == tests(report)
    assert not after['promotion_ready'] and not after['writes_performed']
    with pytest.raises(ValueError, match='Dependency state changed'):
        require_gpx_dependency_freshness(after, report['dependency_sha256'])
    assert before['tables']['ref.site_waypoint'][0]['canonical_label'] == 'A5-18/20'


def test_unbound_track_cannot_acquire_cable_or_test_relationship(dependency_snapshot):
    from site_source_db import _gpx_dependency_report
    report = _gpx_dependency_report(dependency_snapshot, [], [5])
    assert len(report['related_records']) == 1
    assert report['counts']['ops.linkiq_test'] == 0
    assert report['coverage_gaps'] and not report['promotion_ready']


@pytest.mark.parametrize('mutation', ['binding', 'test_content', 'new_test', 'power_revision', 'reference_revision'])
def test_dependency_digest_detects_changes_even_without_revision_increment(dependency_snapshot, mutation):
    from site_source_db import _gpx_dependency_report, require_gpx_dependency_freshness
    prior = _gpx_dependency_report(dependency_snapshot, [1], [])
    if mutation == 'binding':
        dependency_snapshot['tables']['ops.linkiq_test'][0]['physical_site_cable_id'] = None
    elif mutation == 'test_content':
        dependency_snapshot['tables']['ops.linkiq_test'][0]['tester_original_name'] = 'corrected in LinkWare'
    elif mutation == 'new_test':
        dependency_snapshot['tables']['ops.linkiq_test'].append(dict(test_uuid='third', physical_site_cable_id=10))
    else:
        dependency_snapshot[mutation] += 1
    current = _gpx_dependency_report(dependency_snapshot, [1], [])
    with pytest.raises(ValueError, match='refresh comparison'):
        require_gpx_dependency_freshness(current, prior['dependency_sha256'])


def test_dependency_order_independent_and_capture_is_one_data_snapshot(dependency_snapshot):
    from site_source_db import capture_gpx_dependencies
    before = deepcopy(dependency_snapshot)
    conn = RecordingConnection([(False,), (dependency_snapshot,)])
    first = capture_gpx_dependencies(conn, [1, 1], [])
    assert len(conn.statements) == 2 and all(q[0].startswith('SELECT ') for q in conn.statements)
    assert 'to_regclass' in conn.statements[0][0]
    for rows in dependency_snapshot['tables'].values():
        rows.reverse()
    dependency_snapshot['foreign_keys'].reverse()
    second = capture_gpx_dependencies(RecordingConnection([(False,), (dependency_snapshot,)]), [1], [])
    assert first == second
    assert before['tables']['ops.linkiq_test'][0]['test_uuid'] == 'uuid-first'


@pytest.mark.parametrize('problem', ['unknown_consumer', 'missing_root', 'rls', 'unvalidated_fk', 'broken_fk'])
def test_dependency_incomplete_coverage_holds(dependency_snapshot, problem):
    from site_source_db import _gpx_dependency_report, require_gpx_dependency_freshness
    ids = [1]
    if problem == 'unknown_consumer':
        dependency_snapshot['foreign_keys'].append(dict(name='future_fk', child='ops.future_consumer',
            child_columns=['point_id'], parent='ref.site_waypoint', parent_columns=['site_waypoint_id'], validated=True))
    elif problem == 'missing_root':
        ids = [999]
    elif problem == 'rls':
        dependency_snapshot['rls_tables'] = ['ops.linkiq_test']
    elif problem == 'unvalidated_fk':
        dependency_snapshot['foreign_keys'][0]['validated'] = False
    else:
        dependency_snapshot['tables']['ref.site_cable'][0]['endpoint_a_waypoint_id'] = 999
    result = _gpx_dependency_report(dependency_snapshot, ids, [])
    assert result['status'] == 'HOLD' and result['holds']
    with pytest.raises(ValueError, match='capture HOLD'):
        require_gpx_dependency_freshness(result, result['dependency_sha256'])


@pytest.mark.parametrize('ids', [[], [True], ['1'], [0], [-1]])
def test_dependency_invalid_targets_never_query_database(ids):
    from site_source_db import capture_gpx_dependencies
    conn = RecordingConnection([])
    with pytest.raises(ValueError):
        capture_gpx_dependencies(conn, ids, [])
    assert conn.statements == []


def test_equipment_history_is_a_captured_dependency(dependency_snapshot):
    from site_source_db import capture_gpx_dependencies
    dependency_snapshot['tables']['ops.site_equipment_event'] = [{'event_id': 1, 'from_waypoint_id': 1, 'notes': 'Failed supply'}]
    dependency_snapshot['foreign_keys'].append(dict(name='equipment_from', child='ops.site_equipment_event', child_columns=['from_waypoint_id'], parent='ref.site_waypoint', parent_columns=['site_waypoint_id'], validated=True))
    conn = RecordingConnection([(True,), (dependency_snapshot,)])
    report = capture_gpx_dependencies(conn, [1])
    assert report['status'] == 'RECORDED_DEPENDENCIES_CAPTURED'
    assert report['counts']['ops.site_equipment_event'] == 1
    assert 'ops.site_equipment_event' in conn.statements[1][0]
