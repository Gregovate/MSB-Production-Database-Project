"""PR470: exact release pins, failure containment and preserved operational rows."""
import hashlib
import json
import os
from pathlib import Path
import sys
import pytest
sys.path.insert(0, str(Path(__file__).parent))
import setup_470_release as site
from setup_maintenance_deploy import Stop
from test_setup_171_correction_release import Fake as ExistingFake

ROOT = Path(__file__).parent
MANIFEST = json.loads((ROOT/'setup_470_release.json').read_text())

class Fake(ExistingFake, site.MapDeploy):
    def __init__(self, root, fail=None):
        site.MapDeploy.__init__(self, dict(MANIFEST), root)
        self.events = []; self.fail = fail
    def after_reopen(self):
        self.event('receipt')


def test_sequence():
    assert site.MapDeploy.deploy is site.Deploy.deploy


def test_release_sequence(tmp_path):
    d = Fake(tmp_path/'report'); d.deploy()
    expected = ['on','snapshot','migrations','validate','promote','before_reopen','off','live_validation','receipt']
    assert [e for e in d.events if e in expected] == expected


@pytest.mark.parametrize('failure', ['on','snapshot','migrations','validate','promote','before_reopen'])
def test_failure_never_reopens(tmp_path, failure):
    d = Fake(tmp_path/'report', failure)
    with pytest.raises(Stop): d.deploy()
    assert 'off' not in d.events
    assert d.events.count('migrations') <= 1


def test_manifest_pins_and_no_scan():
    assert MANIFEST['candidate'] == MANIFEST['target'] == site.APP
    assert list(MANIFEST['blobs']) == list(site.MIGRATIONS + site.VALIDATIONS)
    assert site.MIGRATIONS == ('Database/EngineeringTools/sql/171_panel_receptacles.sql',)
    for name, digest in MANIFEST['helpers'].items():
        assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest() == digest
    source=(ROOT/'setup_470_release.py').read_text()
    assert 'scan_isolated' not in source and 'deploy_scan' not in source


def test_unreviewed_manifest_stops(tmp_path):
    d=site.MapDeploy({**MANIFEST,'target':'wrong'},tmp_path/'report')
    with pytest.raises(Stop,match='manifest'): d.preflight()
    assert not d.maintenance_started


def test_migration_requires_freeze(tmp_path):
    d=site.MapDeploy(MANIFEST,tmp_path/'report'); calls=[]
    d.baseline=lambda:None; d.database_preflight=lambda:None
    d.controller=lambda action:{}; d.sql=lambda q:calls.append(q)
    with pytest.raises(Stop): d.apply_migrations()
    assert not calls


def test_live_source_drift_stops(tmp_path):
    d=site.MapDeploy(MANIFEST,tmp_path/'report')
    d.git=lambda *a,**kw:'unexpected' if a[0]=='rev-parse' else ''
    with pytest.raises(Stop,match='drift'): d.baseline()


def test_preservation_and_replay_on_postgres(tmp_path):
    dsn=os.environ.get('MSB_205_TEST_DSN')
    if not dsn: pytest.skip('isolated PostgreSQL CI service required')
    import psycopg2
    d=site.MapDeploy(MANIFEST,tmp_path/'report'); d.sql=lambda q:q
    generated=d.capture().split('READ ONLY;',1)[1].split('\\gexec',1)[0]
    with psycopg2.connect(dsn) as db:
        try:
            with db.cursor() as cur:
                cur.execute('CREATE SCHEMA IF NOT EXISTS ref; CREATE SCHEMA IF NOT EXISTS ops;')
                cur.execute("CREATE TABLE ref.site_power_breaker(id int, note text); INSERT INTO ref.site_power_breaker VALUES(1,'Keep');")
                cur.execute("CREATE TABLE ops.site_equipment_event(id int, note text); INSERT INTO ops.site_equipment_event VALUES(7,'Keep equipment');")
                def capture():
                    cur.execute(generated); queries=[r[0] for r in cur.fetchall()]; rows=[]
                    for q in queries: cur.execute(q); rows.append(cur.fetchone()[0])
                    return rows
                before=capture()
                cur.execute('ALTER TABLE ref.site_power_breaker ADD COLUMN panel_outlets boolean NOT NULL DEFAULT false')
                assert capture()==before
                cur.execute("UPDATE ops.site_equipment_event SET note='changed'")
                assert capture()!=before
                def sql(q):
                    cur.execute(q.replace('BEGIN READ ONLY;','').replace('ROLLBACK;',''))
                d.sql=sql
                with pytest.raises(psycopg2.Error,match='no replay'): d.database_preflight()
        finally:
            db.rollback()
