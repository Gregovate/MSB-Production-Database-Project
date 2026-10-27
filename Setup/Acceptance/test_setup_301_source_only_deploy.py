"""Exercise installer boundaries without contacting Production."""
import io
import importlib.util
from pathlib import Path
import pytest

spec = importlib.util.spec_from_file_location('deploy301', Path(__file__).with_name('setup_301_source_only_deploy.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


def installer(tmp_path, drift=False, failed_health=False):
    obj = m.Installer.__new__(m.Installer)
    obj.root = tmp_path
    obj.log = io.StringIO()
    obj.candidate = '/tmp/test-candidate'
    obj.advanced = obj.worktree_created = False
    obj.before = None
    obj.calls = []
    obj.head = 'unexpected' if drift else m.EXPECTED_OLD

    def git(*args, root=m.REPO):
        obj.calls.append(('git', root, args))
        if args == ('rev-parse', 'HEAD'):
            return obj.head if root == m.LIVE else m.SHARED
        if args[:2] == ('checkout', '--detach'):
            obj.head = args[2]
        if args[0] == 'show':
            return ('PRODUCTION_VERSION = "' + m.VERSION + '"' if 'backend' in args[1]
                    else "CLIENT_BUILD = '" + m.VERSION + "'")
        return ''

    def health(version):
        obj.calls.append(('health', version))
        if failed_health and version == m.VERSION:
            raise RuntimeError('simulated failed deployment')

    obj.git = git
    obj.health = health
    obj.fingerprint = lambda: 'a' * 32
    obj.regression = lambda root, tests: obj.calls.append(('regression', root, tests))
    obj.run = lambda argv, **kw: obj.calls.append(('run', argv))
    return obj


def test_success_pins_only_setup_and_retains_evidence(tmp_path):
    obj = installer(tmp_path)
    obj.deploy()
    checkouts = [c for c in obj.calls if c[0] == 'git' and c[2][0] == 'checkout']
    assert checkouts == [('git', m.LIVE, ('checkout', '--detach', m.TARGET))]
    restarts = [c for c in obj.calls if c[0] == 'run' and 'restart' in c[1]]
    assert restarts == [('run', ['sudo', 'systemctl', 'restart', 'msb-setup.service'])]
    assert '"operator_production_check": "PENDING"' in (tmp_path / 'result.json').read_text()


def test_live_drift_stops_without_checkout_or_restart(tmp_path):
    obj = installer(tmp_path, drift=True)
    with pytest.raises(RuntimeError, match='Live Setup changed'):
        obj.deploy()
    obj.rollback()
    assert not obj.advanced
    assert all(c[0] == 'git' and c[2] == ('rev-parse', 'HEAD') for c in obj.calls)


def test_failed_health_restores_old_source_and_setup_service(tmp_path):
    obj = installer(tmp_path, failed_health=True)
    with pytest.raises(RuntimeError, match='simulated'):
        obj.deploy()
    obj.rollback()
    assert obj.head == m.EXPECTED_OLD
    assert ('health', m.OLD_VERSION) in obj.calls
    assert 'SOURCE ROLLBACK PASS' in obj.log.getvalue()


def test_preflight_data_drift_stops_before_mutation(tmp_path):
    obj = installer(tmp_path)
    values = iter(['a' * 32, 'b' * 32])
    obj.fingerprint = lambda: next(values)
    with pytest.raises(RuntimeError, match='data changed during preflight'):
        obj.deploy()
    assert not obj.advanced


def test_interrupt_enters_exception_recovery_path():
    with pytest.raises(RuntimeError, match='interrupted'):
        m.interrupted(15, None)
