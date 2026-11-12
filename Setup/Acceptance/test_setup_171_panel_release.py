"""Failure containment tests for the #171 profile of the established runner."""
import hashlib
import json
from pathlib import Path
import sys
import pytest
sys.path.insert(0,str(Path(__file__).parent))
import setup_171_panel_release as site
from setup_maintenance_deploy import Stop

ROOT=Path(__file__).parent
MANIFEST=json.loads((ROOT/'setup_171_panel_release.json').read_text())


class Fake(site.PanelDeploy):
    def __init__(self,root,fail=None):
        super().__init__(dict(MANIFEST),root)
        self.events=[];self.fail=fail
    def event(self,name):
        self.events.append(name)
        if self.fail==name:raise Stop(name)
    def mark(self,name):
        self.stage=name; self.journal()
    def controller(self,action,*args):
        self.event(action)
        if action=='snapshot':
            return {'snapshot':dict(validated=True,ok=True,bytes=42,path=args[0],sha256='digest')}
        if action=='off':
            return dict(state='ONLINE',last_error=None,live={'database_fenced':False},gates={'online_proof':{'ok':True}})
        return dict(state='MAINTENANCE',last_error=None,maintenance_started_at='now',
                    gates={'freeze_proof':{'ok':True}},
                    live={'database_fenced':True,'sessions':[]})
    def run(self,argv,**kw):
        assert argv[:2]==['sudo','sha256sum']
        return 'digest archive'
    def capture(self):
        self.event('capture')
        return 'unchanged existing business rows'
    def apply_migrations(self):
        self.event('migrations')
    def validate(self):
        self.event('validate')
    def promote_source(self,baseline):
        self.event('promote')
    def before_reopen(self,baseline):
        self.event('before_reopen')
    def live_validation(self):
        self.event('live_validation')


def test_full_sequence_uses_existing_orchestrator(tmp_path):
    d=Fake(tmp_path/'report')
    d.deploy()
    assert d.events.index('on') < d.events.index('snapshot') < d.events.index('migrations')
    assert d.events.index('migrations') < d.events.index('validate') < d.events.index('promote')
    assert d.events.index('promote') < d.events.index('before_reopen') < d.events.index('off')
    assert d.events.index('off') < d.events.index('live_validation')
    assert d.committed


@pytest.mark.parametrize('failure',['on','snapshot','migrations','validate','promote','before_reopen'])
def test_failure_never_reopens_or_restores(tmp_path,failure):
    d=Fake(tmp_path/'report',failure)
    with pytest.raises(Stop): d.deploy()
    assert 'off' not in d.events
    assert d.maintenance_started
    assert d.events.count('migrations')<=1


def test_manifest_and_transport_pins():
    assert MANIFEST['candidate'] == MANIFEST['target'] == site.APP
    assert list(MANIFEST['blobs']) == [site.MIGRATION, site.VALIDATION]
    for name, digest in MANIFEST['helpers'].items():
        assert hashlib.sha256((ROOT/name).read_bytes()).hexdigest() == digest


def test_unreviewed_manifest_cannot_enter_maintenance(tmp_path):
    d = site.PanelDeploy({**MANIFEST, 'target':'wrong'}, tmp_path/'report')
    with pytest.raises(Stop, match='manifest'): d.preflight()
    assert not d.maintenance_started


@pytest.mark.parametrize('key,value', [('slot',True), ('command','changed'), ('execute',False), ('direct_write',True)])
def test_changed_or_replayed_baseline_rejected(tmp_path,key,value):
    d=site.PanelDeploy(MANIFEST,tmp_path/'report')
    baseline=dict(slot=False,command='49ed9c2fda6accb89dd9c72966aa4b78',execute=True,direct_write=False)
    d.sql=lambda query:json.dumps({**baseline,key:value})
    with pytest.raises(Stop,match='baseline'):d.database_preflight()
    assert not d.maintenance_started
    d.sql=lambda query:json.dumps(baseline)
    d.database_preflight()


def test_only_incremental_migration_runs_after_fence(tmp_path):
    d=site.PanelDeploy(MANIFEST,tmp_path/'report')
    calls=[]
    d.baseline=lambda:calls.append('baseline')
    d.database_preflight=lambda:calls.append('database')
    d.controller=lambda action:dict(state='MAINTENANCE',maintenance_started_at='now',
        gates={'freeze_proof':{'ok':True}},live={'database_fenced':True,'sessions':[]})
    d.git=lambda *args:calls.append(args) or 'reviewed migration'
    d.sql=lambda sql:calls.append(sql)
    d.apply_migrations()
    assert calls==['baseline','database',('show',site.APP+':'+site.MIGRATION),'reviewed migration']


def test_setup_source_is_never_promoted(tmp_path):
    d=site.PanelDeploy(MANIFEST,tmp_path/'report'); calls=[]
    d.baseline=lambda **kw:None
    d.mark=lambda text:None
    d.git=lambda *args,**kw:calls.append((args,kw))
    d.regression=lambda root:None
    d.promote_source('baseline')
    assert calls==[(('merge','--ff-only',site.APP),{})]


def test_preservation_includes_source_evidence_and_all_existing_panel_fields(tmp_path):
    d=site.PanelDeploy(MANIFEST,tmp_path/'report')
    d.sql=lambda query:query
    query=d.capture()
    assert "to_jsonb(t)-''branch_position_count''" in query
    assert "('ref','ops','lor_snap')" in query
    assert 'NOT IN' not in query
    assert 'SELECT md5((%s)::text)' in query
    assert 'count(*)' in query


def test_wrapper_defaults_to_preflight_and_uses_foreground_transport():
    wrapper=(ROOT/'run_setup_171_panel_release.ps1').read_text()
    assert "if ($Deploy) { $mode = '--deploy' }" in wrapper
    assert '& ssh -tt ' in wrapper and '& scp -r ' in wrapper
    assert 'site_171_source_install' not in wrapper
    assert 'Tee-Object' not in wrapper and 'Start-Process' not in wrapper


def test_real_postgres_preservation_projection(tmp_path):
    # The existing release-tooling CI service owns this disposable-only DSN.
    import os
    dsn=os.environ.get('MSB_205_TEST_DSN')
    if not dsn: pytest.skip('isolated PostgreSQL CI fixture only')
    import psycopg2
    d=site.PanelDeploy(MANIFEST,tmp_path/'report'); d.sql=lambda q:q
    generated=d.capture().split('READ ONLY;',1)[1].split('\\gexec',1)[0]
    with psycopg2.connect(dsn) as db:
        try:
            with db.cursor() as cur:
                cur.execute('CREATE SCHEMA IF NOT EXISTS ref; CREATE SCHEMA IF NOT EXISTS ops;')
                cur.execute("CREATE TABLE ref.site_panel(id integer, name text); INSERT INTO ref.site_panel VALUES(1,'Keep panel');")
                cur.execute("CREATE TABLE ops.panel_release_source_fixture(payload jsonb); INSERT INTO ops.panel_release_source_fixture VALUES(jsonb_build_object('raw',repeat('evidence',250000)));")
                def capture():
                    cur.execute(generated); queries=[r[0] for r in cur.fetchall()]
                    results=[]
                    for q in queries:
                        cur.execute(q); results.append(cur.fetchone()[0])
                    return results
                before=capture()
                cur.execute('ALTER TABLE ref.site_panel ADD COLUMN branch_position_count integer')
                assert capture()==before
                cur.execute("UPDATE ref.site_panel SET name='Changed'")
                assert capture()!=before
                cur.execute("UPDATE ref.site_panel SET name='Keep panel'")
                assert capture()==before
                cur.execute("DELETE FROM ops.panel_release_source_fixture")
                assert capture()!=before
        finally:
            db.rollback()
