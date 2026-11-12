"""Exercise actual orchestrator sequencing and fail-closed #205 profile hooks."""
import hashlib
import json
from pathlib import Path
import subprocess

import pytest
import setup_205_estimates_deploy as profile
from setup_maintenance_deploy import Stop, SETUP
from test_setup_maintenance_deploy import frozen

ROOT = Path(__file__).parent
REPO = ROOT.parents[1]
MANIFEST = json.loads((ROOT / 'setup_205_estimates_release.json').read_text())


class Fake(profile.EstimatesDeploy):
    def __init__(self, root, fail=None):
        super().__init__({**MANIFEST, 'shared': 'preserved-shared'}, root)
        self.calls = []
        self.fail = fail
        self.head = profile.OLD
        self.count = 0

    def gate(self, name):
        self.calls.append(name)
        if name == self.fail:
            raise Stop('injected ' + name)

    def baseline(self): self.gate('baseline')
    def online(self): self.gate('online')
    def regression(self, root): self.gate('frozen-regression')
    def database_check(self, installed): self.gate('validate' if installed else 'db-preflight')

    def controller(self, action, *args):
        self.gate(action)
        state = frozen()
        if action == 'snapshot':
            state['snapshot'] = dict(ok=True, validated=True, bytes=1, path=args[0], sha256='hash')
        if action == 'off':
            state = dict(state='ONLINE', last_error=None, live={'database_fenced': False},
                         gates={'online_proof': {'ok': True}})
        return state

    def capture(self):
        self.count += 1
        self.gate('capture-' + str(self.count))
        return 'changed' if self.fail == 'drift-' + str(self.count) else 'stable'

    def sql(self, query):
        self.gate('075' if 'Correct daily planned' in query else '076')
        return ''

    def git(self, *args, root=None):
        if args[0] == 'checkout':
            self.gate('promote'); self.head = profile.TARGET; return ''
        if args[0] == 'rev-parse': return self.head if root == SETUP else self.m['shared']
        if args[0] == 'show':
            return subprocess.check_output(['git', '-C', str(REPO), *args], text=True).strip()
        if args[0] == 'status': return ''
        raise AssertionError(args)

    def run(self, args, **kw):
        if 'sha256sum' in args: return 'hash archive'
        if '%{http_code}' in args: self.gate('negative-route'); return '401'
        if 'curl' in args:
            self.gate('health')
            return json.dumps(dict(status='ok', data_mode='postgres', version=profile.VERSION))
        self.gate('live-regression')
        return ''


@pytest.fixture
def factory(tmp_path):
    opened = []
    def make(fail=None):
        d = Fake(tmp_path / str(len(opened)), fail); opened.append(d); return d
    yield make
    for d in opened: d.log.close()


def test_success_orders_all_gates_and_preserves_shared(factory):
    d = factory(); d.deploy()
    sequence = ['on', 'snapshot', '075', '076', 'validate', 'promote',
                'frozen-regression', 'capture-4', 'off', 'health', 'negative-route']
    assert [d.calls.index(x) for x in sequence] == sorted(d.calls.index(x) for x in sequence)
    assert d.m['applied_migrations'] == list(profile.MIGRATIONS)
    assert d.committed and d.m['shared'] == 'preserved-shared'
    assert (d.root / 'snapshot.json').exists()
    assert (d.root / 'before-online-invariants.jsonl').read_text() == 'stable\n'


@pytest.mark.parametrize('failure', ['baseline', 'online', 'db-preflight', 'on', 'snapshot',
    'capture-2', '075', '076', 'validate', 'drift-3', 'promote', 'frozen-regression', 'drift-4'])
def test_every_failed_pre_online_gate_keeps_writers_closed(factory, failure):
    d = factory(failure)
    with pytest.raises(Stop): d.deploy()
    assert 'off' not in d.calls
    if failure in ('baseline', 'online', 'db-preflight', 'on', 'snapshot', 'capture-2'):
        assert '075' not in d.calls and not d.migration_started
    if failure == '076':
        assert d.m['applied_migrations'] == [profile.MIGRATIONS[0]]
        assert d.migration_started and not d.committed
        assert 'promote' not in d.calls


@pytest.mark.parametrize('failure', ['off', 'health', 'negative-route'])
def test_failure_after_promotion_never_retries_or_restores(factory, failure):
    d = factory(failure)
    with pytest.raises(Stop): d.deploy()
    assert d.calls.count('on') == 1 and d.calls.count('off') == 1
    assert d.head == profile.TARGET
    assert 'server deployment PASS' not in d.stage


def test_manifest_and_helpers_are_exact():
    for name, digest in MANIFEST['helpers'].items():
        assert hashlib.sha256((ROOT / name).read_bytes().replace(b'\r', b'')).hexdigest() == digest
    for path, blob in MANIFEST['migration_blobs'].items():
        assert subprocess.check_output(['git', '-C', str(REPO), 'rev-parse', profile.TARGET + ':' + path], text=True).strip() == blob
    assert MANIFEST['migrations'] == list(profile.MIGRATIONS)
    assert MANIFEST['target'] == profile.TARGET
    assert MANIFEST['candidate'] == profile.CANDIDATE


def test_exact_security_queries_and_old_definitions(factory):
    d = factory(); queries = []; d.sql = queries.append
    for installed in (False, True):
        profile.EstimatesDeploy.database_check(d, installed)
        query = queries[-1]
        assert query.startswith('BEGIN READ ONLY;') and query.endswith('ROLLBACK;')
        assert 'md5(p.prosrc)' in query and 'prosecdef' in query and 'a.grantee=0' in query
        assert 'INSERT,UPDATE,DELETE,TRUNCATE' in query
        if installed:
            assert 'tgtype=17' in query and 'pg_get_triggerdef' in query
            assert "tgenabled='O'" in query
        else:
            assert 'already installed; do not replay' in query
    assert len(queries) == 2


def test_wrapper_uses_one_foreground_session_and_committed_transport():
    s = (ROOT / 'run_setup_205_estimates_deploy.ps1').read_text()
    assert s.count('& scp ') == 1 and s.count('& ssh ') == 1
    assert 'timeout --foreground' in s and 'ssh -tt' in s
    assert 'setup_205_estimates_transport.py' in s
    for bad in ('Start-Process', 'Tee-Object', 'ssh -f', 'ssh -N'):
        assert bad not in s


def test_wrong_manifest_stops_before_server_calls(factory):
    d = factory(); d.m['target'] = 'bad'
    with pytest.raises(Stop, match='Unreviewed manifest'): d.preflight()
    assert not d.calls
