"""Exercise grant/deployment ordering and failures without contacting Production."""
import json
from pathlib import Path
import pytest
import setup_88_report_read_deploy as mod
from test_setup_maintenance_deploy import frozen


class FakeReport:
    """Observe real orchestration phases without touching services or data."""
    def __init__(self, owner):
        self.owner=owner; self.root=owner.root/'source-report'; self.advanced=False
        self.before=None; self.log=owner.log
    def git(self,*args,**kwargs): return self.owner.git(*args,**kwargs)
    def focused_regression(self,root):
        phase='frozen' if self.owner.maintenance_started else 'online'
        self.owner.calls.append('tests:'+phase)
        if self.owner.failure=='tests:'+phase: raise mod.Stop('injected tests '+phase)
    def report_read_probe(self):
        phase='frozen' if self.owner.maintenance_started else 'online'
        self.owner.calls.append('probe:'+phase)
        if self.owner.failure=='probe:'+phase: raise mod.Stop('injected probe '+phase)
    def health(self,version):
        self.owner.calls.append('health:'+version)
        if self.owner.failure=='health': raise mod.Stop('injected health')
    def rollback(self):
        assert self.before is None  # No equality gate across legitimate ONLINE work.
        self.owner.calls.append('source-rollback'); self.owner.head=mod.OLD_SETUP


class FakeDeploy(mod.ReadDeploy):
    def __init__(self, root, failure=None):
        super().__init__(root)
        self.calls=[]; self.failure=failure; self.captures=0; self.acls=0
        self.head=mod.OLD_SETUP; self.report=FakeReport(self)
    def controller(self, action, *args):
        self.calls.append(action)
        if self.failure==action: raise mod.Stop('injected '+action)
        state=frozen()
        if action=='snapshot':
            state['snapshot']=dict(validated=True,ok=True,bytes=1,path=args[0],sha256='a'*64)
        if action=='off':
            state=dict(state='ONLINE',last_error=None,live={'database_fenced':False},
                       gates={'online_proof':{'ok':True}})
        elif action=='status' and not self.maintenance_started:
            state=dict(state='ONLINE',last_error=None,live={'database_fenced':False})
        return state
    def baseline(self): self.calls.append('baseline')
    def online(self): self.calls.append('online')
    def missing_read(self): self.calls.append('missing_read')
    def capture(self):
        self.captures+=1
        assert self.maintenance_started, 'Fingerprint comparison must stay frozen'
        return 'drift' if ((self.failure=='data' and self.captures==3)
                         or (self.failure=='report-data' and self.captures==4)) else 'same'
    def acl_preservation(self):
        self.acls+=1
        assert self.maintenance_started
        return 'drift' if ((self.failure=='acl' and self.acls==3)
                         or (self.failure=='report-acl' and self.acls==4)) else 'same'
    def validate(self):
        self.calls.append('validate')
        if self.failure=='validate': raise mod.Stop('injected validate')
    def git(self,*args,root=mod.REPO):
        self.calls.append('git:'+args[0])
        if args[0]=='checkout':
            assert self.maintenance_started
            self.head=args[2]
            if self.failure=='checkout': raise mod.Stop('injected partial checkout')
        if args[0]=='show':
            return Path(__file__).parents[1].joinpath('Database/071_grant_setup_container_type_report_read.sql').read_text().rstrip()
        if args[0]=='rev-parse': return self.head if root==mod.SETUP else mod.SHARED
        return ''
    def run(self,args,**kwargs):
        if 'sha256sum' in args: return 'a'*64+' archive'
        return ''
    def sql(self,query):
        self.calls.append('migration')
        if self.failure=='migration': raise mod.Stop('injected migration interruption')
@pytest.fixture
def deploy(tmp_path):
    made=[]
    def make(failure=None):
        d=FakeDeploy(tmp_path/('report-'+str(len(made))),failure); made.append(d); return d
    yield make
    for d in made: d.log.close()


def test_complete_order_keeps_grant_and_report_inside_one_maintenance_window(deploy):
    d=deploy(); d.deploy()
    for first,second in [('on','snapshot'),('snapshot','migration'),('migration','validate'),
                         ('validate','git:checkout'),('git:checkout','tests:frozen'),
                         ('probe:frozen','off'),('off','health:'+mod.REPORT_VERSION)]:
        assert d.calls.index(first)<d.calls.index(second)
    assert d.committed and not d.maintenance_started
    assert d.head==mod.REPORT_TARGET and d.captures==4 and d.acls==4
    assert d.calls.count('on')==1 and d.calls.count('off')==1
    assert d.calls.count('tests:online')==1 and d.calls.count('probe:online')==1
    assert 'source-rollback' not in d.calls


@pytest.mark.parametrize('failure,forbidden',[
 ('on',['snapshot','migration','off','git:checkout']),
 ('snapshot',['migration','off','git:checkout']),
 ('migration',['validate','off','git:checkout']),
 ('validate',['off','git:checkout']),('data',['off','git:checkout']),('acl',['off','git:checkout']),
 ('checkout',['off','tests:online']),('tests:frozen',['off','tests:online']),
 ('probe:frozen',['off','probe:online']),('report-data',['off']),('report-acl',['off']),
 ('off',['tests:online','probe:online'])])
def test_failure_does_not_reopen_or_continue(deploy,failure,forbidden):
    d=deploy(failure)
    with pytest.raises(mod.Stop): d.deploy()
    assert all(c not in d.calls for c in forbidden)
    if failure=='migration': assert d.migration_started and not d.committed
    if failure in ['validate','data','acl','off','checkout','tests:frozen','probe:frozen',
                    'report-data','report-acl']: assert d.committed
    assert 'source-rollback' not in d.calls
    assert d.maintenance_started


@pytest.mark.parametrize('failure',['health','tests:online','probe:online'])
def test_live_report_failure_rolls_back_only_source_after_proven_online(deploy,failure):
    d=deploy(failure)
    with pytest.raises(mod.Stop): d.deploy()
    assert d.committed and not d.maintenance_started
    assert d.calls.count('migration')==1 and d.calls.count('off')==1
    assert d.calls.count('source-rollback')==1 and d.head==mod.OLD_SETUP
    journal=json.loads((d.root/'state.json').read_text())
    assert journal['migration_confirmed'] and journal['application_promotion_started']


def test_unprepared_report_cannot_enter_maintenance(deploy):
    d=deploy(); d.report=None
    with pytest.raises(mod.Stop,match='not prepared'): d.deploy()
    assert 'on' not in d.calls


def test_controller_drift_prevents_online_source_rollback(deploy):
    d=deploy('health'); real=d.controller
    def changed(action,*args):
        if action=='status' and not d.maintenance_started:
            return frozen()
        return real(action,*args)
    d.controller=changed
    with pytest.raises(RuntimeError,match='rollback failed'): d.deploy()
    assert 'source-rollback' not in d.calls and d.head==mod.REPORT_TARGET


def test_exact_report_preparation_runs_before_any_production_mutation(tmp_path,monkeypatch):
    pytest.importorskip('fcntl',reason='Pinned preparation helper is Linux-only')
    import setup_88_report_source_only_deploy as pinned
    calls=[]
    class Prepared:
        def __init__(self):
            self.root=tmp_path/'report'; self.root.mkdir()
            self.candidate='/tmp/owned-exact-report'
            self.advanced=False; self.worktree_created=False
            self.log=(self.root/'report.txt').open('w')
        def git(self,*args):
            calls.append(args)
            if args[0]=='show':
                return ('PRODUCTION_VERSION = "'+mod.REPORT_VERSION+'"' if 'production_backend.py' in args[1]
                        else "CLIENT_BUILD = '"+mod.REPORT_VERSION+"'")
            return ''
        def run(self,args): calls.append(tuple(args))
        def regression(self,root,tests): calls.append(('full',root,tuple(tests)))
        def focused_regression(self,root): calls.append(('focused',root))
        def cleanup(self): calls.append(('cleanup',))
    monkeypatch.setattr(pinned,'Installer',Prepared)
    d=mod.ReadDeploy(tmp_path/'deployment')
    try:
        d.prepare_report()
        assert ('worktree','add','--detach','/tmp/owned-exact-report',mod.REPORT_TARGET) in calls
        assert ('full','/tmp/owned-exact-report',('Setup/Application',)) in calls
        assert ('focused','/tmp/owned-exact-report') in calls
        assert any('--target' in c and mod.REPORT_TARGET in c for c in calls)
        assert not d.maintenance_started and not d.migration_started and not d.report.advanced
        assert not any(c[0]=='checkout' for c in calls)
    finally:
        d.cleanup(); d.log.close()


def test_frozen_failure_journal_retains_source_promotion_evidence(deploy):
    d=deploy('probe:frozen')
    with pytest.raises(mod.Stop): d.deploy()
    d.journal(error='retained failure')
    journal=json.loads((d.root/'state.json').read_text())
    assert journal['maintenance_started'] and journal['migration_confirmed']
    assert journal['application_promotion_started'] and journal['report_directory']==str(d.report.root)
    assert 'off' not in d.calls and 'source-rollback' not in d.calls


def test_legitimate_work_after_off_does_not_trigger_preservation_rollback(deploy):
    d=deploy(); controller=d.controller; capture=d.capture
    changed=False
    def with_operator_work(action,*args):
        nonlocal changed
        state=controller(action,*args)
        if action=='off': changed=True
        return state
    def business_rows():
        assert not changed, 'Do not compare reopened rows with the frozen baseline'
        return capture()
    d.controller=with_operator_work; d.capture=business_rows
    d.deploy()
    assert changed and d.head==mod.REPORT_TARGET and 'source-rollback' not in d.calls


def test_exact_validation_is_bound_to_report_statements():
    source=Path(__file__).parents[1].joinpath('Application/setup_production_report.py').read_text()
    validation=Path(__file__).with_name('setup_88_report_read_validation.sql').read_text()
    assert all(q.replace('%s',':report_session_id') in validation for q in mod.report_queries(source))
    assert mod.git_blob(Path(__file__).parents[1].joinpath('Database/071_grant_setup_container_type_report_read.sql').read_bytes())==mod.MIGRATION_BLOB


def test_permission_sensitive_clone_consumes_actual_read_exporter():
    shell=Path(__file__).with_name('setup_disposable_acceptance_server.sh').read_text()
    assert 'production_read_boundary)' in shell
    actual=shell.split('if [[ "$PRODUCTION_READ_BOUNDARY" == "true" ]]',1)[1].split('\nelse',1)[0]
    assert 'setup_production_read_boundary.sql' in actual
    assert 'SELECT ON ALL' not in actual
    source=Path(mod.__file__).read_text()
    assert 'production_read_boundary\\ttrue' in source
    assert source.index('self.clone_acceptance()')<source.index("self.mark('current-Production clone acceptance PASS')")
    assert not any(bad in source for bad in ['pg_restore -d msb','GRANT SELECT ON ALL','setup_205_069_release.json'])


@pytest.mark.parametrize('corrupt', [False, True])
def test_clone_launch_uses_pinned_corrected_tooling_not_old_candidate(tmp_path, corrupt):
    runner=Path(__file__).with_name('setup_disposable_acceptance_server.sh').read_bytes()
    assert mod.git_blob(runner)==mod.CLONE_RUNNER_BLOB
    d=mod.ReadDeploy.__new__(mod.ReadDeploy)
    requested=[]; bundles=[]
    def git(*args):
        requested.append(args)
        return (runner.decode()+'unexpected' if corrupt else runner.decode()).strip()
    def run(argv,timeout):
        bundle=Path(argv[1]).parent; bundles.append(bundle)
        assert Path(argv[1]).read_bytes()==runner
        assert 'candidate_sha\t'+mod.GRANT_TARGET+'\n' in (bundle/'manifest.tsv').read_text()
        assert 'production_read_boundary\ttrue\n' in (bundle/'manifest.tsv').read_text()
        assert timeout==1200
    d.git=git; d.run=run
    if corrupt:
        with pytest.raises(mod.Stop,match='runner differs'):
            d.clone_acceptance()
        assert not bundles
    else:
        d.clone_acceptance()
        assert bundles and not bundles[0].exists()
    assert requested==[('cat-file','blob',mod.CLONE_RUNNER_BLOB)]


def test_windows_transport_normalization_matches_exact_helper_pins():
    for name,blob in mod.HELPERS.items():
        source=Path(__file__).with_name(name).read_bytes()
        assert mod.git_blob(source)==blob
        assert mod.git_blob(source.replace(b'\r',b''))==mod.TRANSPORT_BLOBS[name]
