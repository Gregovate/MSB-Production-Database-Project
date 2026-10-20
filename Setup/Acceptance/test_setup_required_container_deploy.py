"""Verify PR389 consumes the established maintenance/snapshot/failure containment."""
import hashlib
import json
from pathlib import Path
import tempfile
import pytest
from setup_required_container_deploy import RequiredContainerDeploy, TARGET, VERSION, MIGRATION
from setup_maintenance_deploy import Stop, SETUP
from test_setup_maintenance_deploy import FakeDeploy

ROOT = Path(__file__).parent
MANIFEST = json.loads((ROOT/'setup_required_container_release.json').read_text())


class FakeRequired(RequiredContainerDeploy):
    controller = FakeDeploy.controller
    capture = FakeDeploy.capture
    sql = FakeDeploy.sql
    def __init__(self, root, fail=None):
        super().__init__({**MANIFEST, 'shared':'unchanged-shared'}, root)
        self.calls=[]; self.fail=fail; self.captures=0
    def git(self, *args, root=None):
        self.calls.append('git:'+args[0])
        if args[0]=='rev-parse': return TARGET if root==SETUP else self.m['shared']
        if args[0]=='show':
            if args[1].endswith('production_backend.py'): return 'PRODUCTION_VERSION = "'+VERSION+'"'
            if args[1].endswith('setup_catalog_dirty_guard.js'): return "CLIENT_BUILD = '"+VERSION+"'"
            return (ROOT.parents[1]/MIGRATION).read_text()
        return ''
    def run(self, args, **kwargs):
        self.calls.append(args[1] if len(args)>1 else args[0])
        if 'sha256sum' in args: return 'hash archive'
        if '%{http_code}' in args: return '401'
        if 'curl' in args: return json.dumps(dict(status='ok',data_mode='postgres',version=VERSION))
        return ''
    def validate(self):
        self.calls.append('validate')
        if self.fail=='validate': raise Stop('validation failure')
        self.database_check(True)


@pytest.fixture
def deployment(tmp_path):
    d=FakeRequired(tmp_path/'report')
    yield d
    d.log.close()


def test_new_profile_uses_existing_freeze_snapshot_and_off_order(deployment):
    d=deployment; d.deploy()
    assert d.calls.index('on') < d.calls.index('snapshot') < d.calls.index('sql')
    assert d.calls.index('validate') < d.calls.index('git:checkout') < d.calls.index('off')
    assert 'git:merge' not in d.calls  # Shared People/FieldWiring checkout preserved.
    assert d.committed
    assert json.loads((d.root/'state.json').read_text())['manifest']['shared']=='unchanged-shared'


@pytest.mark.parametrize('failure', ['on','snapshot','migration','validate','invariants'])
def test_failed_gate_never_reopens_writers(tmp_path, failure):
    d=FakeRequired(tmp_path/'report',failure)
    try:
        with pytest.raises(Stop): d.deploy()
        assert 'off' not in d.calls
        if failure in ('on','snapshot'): assert not d.migration_started
    finally: d.log.close()


def test_packaged_helper_hash_and_exact_release_pins():
    helper=(ROOT/'setup_maintenance_deploy.py').read_bytes().replace(b'\r',b'')
    assert hashlib.sha256(helper).hexdigest()==MANIFEST['helper_sha256']
    assert MANIFEST['target']==TARGET
    assert MANIFEST['migration']==MIGRATION
    assert MANIFEST['release_tag']=='PR389-073'
    wrapper=(ROOT/'run_setup_required_container_deploy.ps1').read_text()
    assert 'timeout --foreground' in wrapper and 'ssh -tt' in wrapper
    assert 'setup_required_container_transport.py' in wrapper
    assert 'Run from merged main.' in wrapper


def test_installed_check_verifies_definition_and_command_only_privileges(deployment):
    captured=[]
    deployment.sql=lambda query:captured.append(query)
    deployment.database_check(True)
    assert 'md5(p.prosrc)' in captured[0]
    assert 'prosecdef' in captured[0]
    assert "a.grantee=0" in captured[0]
    assert "'INSERT,UPDATE,DELETE'" in captured[0]
    captured.clear(); deployment.database_check(False)
    assert 'already exists' in captured[0]
