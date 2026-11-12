"""Failure containment tests for the #171 profile of the established runner."""
import hashlib
import json
from pathlib import Path
import sys
import pytest
sys.path.insert(0,str(Path(__file__).parent))
import setup_171_correction_release as site
from setup_maintenance_deploy import Stop

ROOT=Path(__file__).parent
MANIFEST=json.loads((ROOT/'setup_171_correction_release.json').read_text())


class Fake(site.CorrectionDeploy):
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
    d = site.CorrectionDeploy({**MANIFEST, 'target':'wrong'}, tmp_path/'report')
    with pytest.raises(Stop, match='manifest'): d.preflight()
    assert not d.maintenance_started


@pytest.mark.parametrize('key,value', [('slot',False), ('snapshot','changed'), ('execute',False), ('direct_write',True)])
def test_changed_or_replayed_baseline_rejected(tmp_path,key,value):
    d=site.CorrectionDeploy(MANIFEST,tmp_path/'report')
    d.snapshot_security=lambda:None
    baseline=dict(slot=True,snapshot='1409b5a8bada107ecfd5954c8f49a18d',execute=True,direct_write=False)
    d.sql=lambda query:json.dumps({**baseline,key:value})
    with pytest.raises(Stop,match='baseline'):d.database_preflight()
    assert not d.maintenance_started
    d.sql=lambda query:json.dumps(baseline)
    d.database_preflight()


def test_only_incremental_migration_runs_after_fence(tmp_path):
    d=site.CorrectionDeploy(MANIFEST,tmp_path/'report')
    calls=[]
    d.baseline=lambda:calls.append('baseline')
    d.database_preflight=lambda:calls.append('database')
    d.controller=lambda action:dict(state='MAINTENANCE',maintenance_started_at='now',
        gates={'freeze_proof':{'ok':True}},live={'database_fenced':True,'sessions':[]})
    d.git=lambda *args:calls.append(args) or 'reviewed migration'
    d.sql=lambda sql:calls.append(sql)
    d.apply_migrations()
    assert calls==['baseline','database',('show',site.APP+':'+site.MIGRATION),'reviewed migration']


def test_only_fieldwiring_source_promotes_under_fence(tmp_path):
    d=site.CorrectionDeploy(MANIFEST,tmp_path/'report'); calls=[]
    d.baseline=lambda **kw:None
    d.mark=lambda text:None
    d.git=lambda *args,**kw:calls.append((args,kw))
    d.regression=lambda root:None
    d.frozen=lambda state:None
    d.controller=lambda action:{}
    d.promote_source('baseline')
    assert calls==[(('merge','--ff-only',site.APP),{})]


def test_preservation_includes_source_evidence_and_all_existing_panel_fields(tmp_path):
    d=site.CorrectionDeploy(MANIFEST,tmp_path/'report')
    d.sql=lambda query:query
    query=d.capture()
    assert "to_jsonb(t)-" not in query
    assert "('ref','ops','lor_snap')" in query
    assert 'NOT IN' not in query
    assert 'SELECT md5((%s)::text)' in query
    assert 'count(*)' in query


def test_wrapper_defaults_to_preflight_and_uses_foreground_transport():
    wrapper=(ROOT/'run_setup_171_correction_release.ps1').read_text()
    assert "if ($Deploy) { $mode = '--deploy' }" in wrapper
    assert '& ssh -tt ' in wrapper and '& scp -r ' in wrapper
    assert 'site_171_source_install' not in wrapper
    assert 'Tee-Object' not in wrapper and 'Start-Process' not in wrapper


def test_slot_values_and_state_records_are_not_excluded(tmp_path):
    d=site.CorrectionDeploy(MANIFEST,tmp_path/'report');d.sql=lambda q:q
    query=d.capture()
    assert "'to_jsonb(t)'" in query
    assert 'EXCEPT' not in query and 'NOT IN' not in query


def test_drift_in_either_live_checkout_stops(tmp_path):
    d=site.CorrectionDeploy(MANIFEST,tmp_path/'report')
    d.git=lambda *args,**kw: 'wrong' if args[0]=='rev-parse' else ''
    with pytest.raises(Stop,match='drift'):d.baseline()
    assert not d.maintenance_started


def test_real_postgres_preservation_projection(tmp_path):
    # The existing release-tooling CI service owns this disposable-only DSN.
    import os
    dsn=os.environ.get('MSB_205_TEST_DSN')
    if not dsn: pytest.skip('isolated PostgreSQL CI fixture only')
    import psycopg2
    d=site.CorrectionDeploy(MANIFEST,tmp_path/'report'); d.sql=lambda q:q
    generated=d.capture().split('READ ONLY;',1)[1].split('\\gexec',1)[0]
    with psycopg2.connect(dsn) as db:
        try:
            with db.cursor() as cur:
                cur.execute('CREATE SCHEMA IF NOT EXISTS ref; CREATE SCHEMA IF NOT EXISTS ops;')
                cur.execute("CREATE TABLE ref.site_panel(id integer, name text, branch_position_count integer); INSERT INTO ref.site_panel VALUES(1,'Keep panel',8);")
                cur.execute("CREATE TABLE ops.panel_release_source_fixture(payload jsonb); INSERT INTO ops.panel_release_source_fixture VALUES(jsonb_build_object('raw',repeat('evidence',250000)));")
                def capture():
                    cur.execute(generated); queries=[r[0] for r in cur.fetchall()]
                    results=[]
                    for q in queries:
                        cur.execute(q); results.append(cur.fetchone()[0])
                    return results
                before=capture()
                cur.execute('UPDATE ref.site_panel SET branch_position_count=10')
                assert capture()!=before
                cur.execute('UPDATE ref.site_panel SET branch_position_count=8')
                assert capture()==before
                cur.execute("UPDATE ref.site_panel SET name='Changed'")
                assert capture()!=before
                cur.execute("UPDATE ref.site_panel SET name='Keep panel'")
                assert capture()==before
                cur.execute("DELETE FROM ops.panel_release_source_fixture")
                assert capture()!=before
        finally:
            db.rollback()


def test_closeout_surfaces_validated_snapshot_receipt(tmp_path,capsys):
    d=site.CorrectionDeploy(MANIFEST,tmp_path/'report')
    (d.root/'snapshot.json').write_text(json.dumps(dict(path='/retained/snapshot.dump',sha256='verified-hash')))
    d.after_reopen()
    output=capsys.readouterr().out
    assert '/retained/snapshot.dump' in output and 'verified-hash' in output
    assert site.APP in output


def test_snapshot_security_drift_denied(tmp_path):
    d=site.CorrectionDeploy(MANIFEST,tmp_path/'report')
    baseline=dict(command='7c1ff2630aefda0a7e46c0ef4672714e',definer=True,stability='s',
        path=['search_path=pg_catalog, ref, ops'],owner='msbadmin',execute=True,public_execute=False)
    d.sql=lambda q:json.dumps(baseline)
    d.snapshot_security()
    for key,value in [('command','changed'),('definer',False),('stability','v'),
                      ('path',[]),('owner','other'),('execute',False),('public_execute',True)]:
        d.sql=lambda q:json.dumps({**baseline,key:value})
        with pytest.raises(Stop,match='security/command'):d.snapshot_security()


def test_setup_remains_at_prior_source_after_promotion(tmp_path):
    d=site.CorrectionDeploy(MANIFEST,tmp_path/'report')
    def git(*args,root=site.REPO):
        return (site.APP if root==site.REPO else site.OLD_SETUP) if args[0]=='rev-parse' else ''
    d.git=git
    d.baseline(promoted=True)


def test_new_command_and_unchanged_optimized_snapshot_required(tmp_path):
    d=site.CorrectionDeploy(MANIFEST,tmp_path/'report')
    d.git=lambda *args:'read-only validation'
    def sql(query):
        if query=='read-only validation':return ''
        if 'json_object_agg' in query:
            return json.dumps(dict(site_power_command='906289a801cae2e2d85957898984f031',site_power_snapshot='1409b5a8bada107ecfd5954c8f49a18d'))
        return json.dumps(dict(command='906289a801cae2e2d85957898984f031',definer=True,stability='s',path=['search_path=pg_catalog, ref, ops'],owner='msbadmin',execute=True,public_execute=False))
    d.sql=sql
    d.validate()
    with pytest.raises(Stop,match='security/command'):d.snapshot_security()


def test_release_targets_only_accepted_correction():
    assert site.APP=='2548edd130b5cebad33a44786bc1811c2b089bf8'
    assert site.OLD=='875003c504e8a60c5851c530ec6496e4430945d9'
    assert site.OLD_SETUP=='72a94be772f2e4ae8bfaed74051f667fc87201a6'
    assert site.MIGRATION.endswith('/171_unassigned_breaker_correction.sql')
    assert site.VALIDATION.endswith('/171_unassigned_breaker_correction_validation.sql')
