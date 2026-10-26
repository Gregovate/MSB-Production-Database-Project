"""PR463 release safety: ordering, fail-closed gates and row preservation."""
import hashlib
import json
import os
from pathlib import Path
import sys
import pytest
sys.path.insert(0, str(Path(__file__).parent))
import setup_463_release as site
from setup_maintenance_deploy import Stop
from test_setup_171_correction_release import Fake as ExistingFake

ROOT = Path(__file__).parent
MANIFEST = json.loads((ROOT/'setup_463_release.json').read_text())


class Fake(ExistingFake, site.EquipmentDeploy):
    def __init__(self, root, fail=None):
        site.EquipmentDeploy.__init__(self, dict(MANIFEST), root)
        self.events = []; self.fail = fail

    def after_reopen(self):
        self.event('scan_deploy')


def test_sequence_and_scan_after_online(tmp_path):
    d = Fake(tmp_path/'report'); d.deploy()
    expected = ['on','snapshot','migrations','validate','promote','before_reopen','off','live_validation','scan_deploy']
    assert [e for e in d.events if e in expected] == expected


@pytest.mark.parametrize('failure', ['on','snapshot','migrations','validate','promote','before_reopen'])
def test_failure_before_online_never_reopens_or_installs_scan(tmp_path, failure):
    d = Fake(tmp_path/'report', failure)
    with pytest.raises(Stop): d.deploy()
    assert 'off' not in d.events and 'scan_deploy' not in d.events
    assert d.events.count('migrations') <= 1


def test_scan_failure_does_not_replay_database(tmp_path):
    d = Fake(tmp_path/'report', 'scan_deploy')
    with pytest.raises(Stop): d.deploy()
    assert d.events.count('migrations') == d.events.count('off') == 1
    assert d.committed


def test_manifest_pins_local_helpers_and_external_identities():
    assert MANIFEST['candidate'] == MANIFEST['target'] == site.APP
    assert list(MANIFEST['blobs']) == list(site.MIGRATIONS + site.VALIDATIONS)
    for name, digest in MANIFEST['helpers'].items():
        if name in MANIFEST['server_helpers']:
            assert digest == MANIFEST['server_helpers'][name]
        else:
            assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest() == digest


def test_unreviewed_manifest_stops_before_maintenance(tmp_path):
    d = site.EquipmentDeploy({**MANIFEST, 'target':'wrong'}, tmp_path/'report')
    with pytest.raises(Stop, match='manifest'): d.preflight()
    assert not d.maintenance_started


def test_ordered_migrations_require_frozen_state(tmp_path):
    d = site.EquipmentDeploy(MANIFEST, tmp_path/'report'); calls = []
    d.baseline = lambda: None; d.database_preflight = lambda: None
    d.controller = lambda action: {}
    d.sql = lambda query: calls.append(query)
    d.git = lambda *args: args[1]
    with pytest.raises(Stop): d.apply_migrations()
    assert not calls
    d.frozen = lambda state: None; d.mark = lambda stage: None
    d.apply_migrations()
    assert calls == [site.APP+':'+p for p in site.MIGRATIONS]


def test_isolated_scan_failure_stops_preflight_without_maintenance(tmp_path):
    d = site.EquipmentDeploy(MANIFEST, tmp_path/'report')
    d.mark = lambda stage: None
    def run(argv, **kw):
        if argv[:2] == ['sudo','sha256sum']: return site.OLD_SCAN+' artifact'
        raise Stop('isolated validation failed')
    d.run = run
    with pytest.raises(Stop): d.scan_isolated()
    assert not d.maintenance_started


def test_both_sources_pinned_after_promotion(tmp_path):
    d = site.EquipmentDeploy(MANIFEST, tmp_path/'report')
    d.git = lambda *args, **kw: site.APP if args[0] == 'rev-parse' else ''
    d.baseline(promoted=True)
    d.git = lambda *args, **kw: site.OLD if args[0] == 'rev-parse' else ''
    with pytest.raises(Stop): d.baseline(promoted=True)


def test_preservation_projection_on_real_postgres(tmp_path):
    dsn = os.environ.get('MSB_205_TEST_DSN')
    if not dsn: pytest.skip('isolated PostgreSQL CI service required')
    import psycopg2
    d = site.EquipmentDeploy(MANIFEST, tmp_path/'report'); d.sql = lambda q: q
    generated = d.capture().split('READ ONLY;',1)[1].split('\\gexec',1)[0]
    with psycopg2.connect(dsn) as db:
        try:
            with db.cursor() as cur:
                cur.execute('CREATE SCHEMA IF NOT EXISTS ref; CREATE SCHEMA IF NOT EXISTS ops;')
                cur.execute('CREATE TABLE ref.site_power_device(id int, name text); INSERT INTO ref.site_power_device VALUES(1,\'existing device\');')
                cur.execute('CREATE TABLE ops.setup_movement_event(id int, evidence jsonb); INSERT INTO ops.setup_movement_event VALUES(1,\'{"keep":true}\');')
                def capture():
                    cur.execute(generated); queries = [r[0] for r in cur.fetchall()]
                    result = []
                    for q in queries:
                        cur.execute(q); result.append(cur.fetchone()[0])
                    return result
                before = capture()
                cur.execute('ALTER TABLE ref.site_power_device ADD COLUMN equipment_model_id bigint; ALTER TABLE ops.setup_movement_event ADD COLUMN controller_id int, ADD COLUMN controller_request jsonb;')
                cur.execute('CREATE TABLE ops.site_equipment_event(id int); CREATE TABLE ops.setup_container_pickup_event(id int); CREATE TABLE ref.site_equipment_type(id int); CREATE TABLE ref.site_equipment_model(id int); INSERT INTO ref.site_equipment_model VALUES(1);')
                assert capture() == before
                d.sql = lambda q: cur.execute(q.replace('BEGIN READ ONLY;', '').replace('ROLLBACK;', ''))
                d.new_rows_empty()
                cur.execute("UPDATE ops.setup_movement_event SET evidence='{}'")
                assert capture() != before
                cur.execute('UPDATE ref.site_power_device SET equipment_model_id=1')
                with pytest.raises(psycopg2.Error, match='operational data'): d.new_rows_empty()
        finally:
            db.rollback()
