"""Exercise grant/deployment ordering and failures without contacting Production."""
import json
from pathlib import Path
import pytest
import setup_88_report_read_deploy as mod
from test_setup_maintenance_deploy import frozen


class FakeDeploy(mod.ReadDeploy):
    def __init__(self, root, failure=None):
        super().__init__(root)
        self.calls=[]; self.failure=failure; self.captures=0; self.acls=0
    def controller(self, action, *args):
        self.calls.append(action)
        if self.failure==action: raise mod.Stop('injected '+action)
        state=frozen()
        if action=='snapshot':
            state['snapshot']=dict(validated=True,ok=True,bytes=1,path=args[0],sha256='a'*64)
        if action=='off':
            state=dict(state='ONLINE',last_error=None,live={'database_fenced':False},
                       gates={'online_proof':{'ok':True}})
        return state
    def baseline(self): self.calls.append('baseline')
    def online(self): self.calls.append('online')
    def missing_read(self): self.calls.append('missing_read')
    def capture(self):
        self.captures+=1
        return 'drift' if self.failure=='data' and self.captures==3 else 'same'
    def acl_preservation(self):
        self.acls+=1
        return 'drift' if self.failure=='acl' and self.acls==3 else 'same'
    def validate(self):
        self.calls.append('validate')
        if self.failure=='validate': raise mod.Stop('injected validate')
    def git(self,*args,root=mod.REPO):
        self.calls.append('git:'+args[0])
        if args[0]=='show':
            return Path(__file__).parents[1].joinpath('Database/071_grant_setup_container_type_report_read.sql').read_text().rstrip()
        if args[0]=='rev-parse': return mod.OLD_SETUP if root==mod.SETUP else mod.SHARED
        return ''
    def run(self,args,**kwargs):
        if 'sha256sum' in args: return 'a'*64+' archive'
        return ''
    def sql(self,query):
        self.calls.append('migration')
        if self.failure=='migration': raise mod.Stop('injected migration interruption')
    def install_report(self):
        self.calls.append('report')
        if self.failure=='report': raise mod.Stop('injected report')


@pytest.fixture
def deploy(tmp_path):
    made=[]
    def make(failure=None):
        d=FakeDeploy(tmp_path/('report-'+str(len(made))),failure); made.append(d); return d
    yield make
    for d in made: d.log.close()


def test_complete_order_uses_snapshot_before_grant_and_online_before_report(deploy):
    d=deploy(); d.deploy()
    for first,second in [('on','snapshot'),('snapshot','migration'),('migration','validate'),
                         ('validate','off'),('off','report')]:
        assert d.calls.index(first)<d.calls.index(second)
    assert d.committed and not d.maintenance_started
    assert not any(c=='git:checkout' for c in d.calls)


@pytest.mark.parametrize('failure,forbidden',[
 ('on',['snapshot','migration','off','report']),
 ('snapshot',['migration','off','report']),
 ('migration',['validate','off','report']),
 ('validate',['off','report']),('data',['off','report']),('acl',['off','report']),
 ('off',['report'])])
def test_failure_does_not_reopen_or_continue(deploy,failure,forbidden):
    d=deploy(failure)
    with pytest.raises(mod.Stop): d.deploy()
    assert all(c not in d.calls for c in forbidden)
    if failure=='migration': assert d.migration_started and not d.committed
    if failure in ['validate','data','acl','off']: assert d.committed


def test_report_failure_leaves_proven_grant_and_no_database_recovery(deploy):
    d=deploy('report')
    with pytest.raises(mod.Stop): d.deploy()
    assert d.committed and not d.maintenance_started
    assert d.calls.count('migration')==1 and d.calls.count('off')==1


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


def test_windows_transport_normalization_matches_exact_helper_pins():
    for name,blob in mod.HELPERS.items():
        source=Path(__file__).with_name(name).read_bytes()
        assert mod.git_blob(source)==blob
        assert mod.git_blob(source.replace(b'\r',b''))==mod.TRANSPORT_BLOBS[name]
