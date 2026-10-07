"""Exercise installer boundaries without contacting Production."""
import io
import importlib.util
from pathlib import Path
import pytest

spec = importlib.util.spec_from_file_location('deploy305', Path(__file__).with_name('setup_305_source_only_deploy.py'))
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
    assert not any(c[0] == 'git' and c[2][0] == 'checkout' for c in obj.calls)
    assert not any(c[0] == 'run' and 'restart' in c[1] for c in obj.calls)


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


def test_unmerged_target_stops_before_live_checkout(tmp_path):
    obj = installer(tmp_path)
    original = obj.git

    def git(*args, **kwargs):
        if args == ('merge-base', '--is-ancestor', m.TARGET, 'origin/main'):
            raise RuntimeError('target not merged')
        return original(*args, **kwargs)

    obj.git = git
    with pytest.raises(RuntimeError, match='target not merged'):
        obj.deploy()
    assert not obj.advanced


def test_active_preview_stops_before_live_checkout(tmp_path):
    obj = installer(tmp_path)
    obj.run = lambda *args, **kwargs: 'LISTEN 127.0.0.1:8898'
    with pytest.raises(RuntimeError, match='CLEAN EXIT'):
        obj.deploy()
    assert not obj.advanced


def test_cleanup_failure_propagates(tmp_path):
    obj = installer(tmp_path)
    obj.worktree_created = True
    obj.git = lambda *args, **kwargs: (_ for _ in ()).throw(RuntimeError('remove failed'))
    with pytest.raises(RuntimeError, match='remove failed'):
        obj.cleanup()
    assert obj.worktree_created


def test_main_reports_stop_when_cleanup_fails(tmp_path, monkeypatch, capsys):
    # A healthy installation cannot hide failure to remove its candidate worktree.
    import builtins
    real_open = builtins.open
    monkeypatch.setattr(m, 'open', lambda *args, **kwargs: real_open(tmp_path / 'deploy.lock', 'a'), raising=False)
    monkeypatch.setattr(m.signal, 'signal', lambda *args: None)

    class FailedCleanup:
        root = tmp_path
        log = io.StringIO()

        def deploy(self):
            pass

        def cleanup(self):
            raise RuntimeError('cleanup failed')

    monkeypatch.setattr(m, 'Installer', FailedCleanup)
    assert m.main() == 1
    output = capsys.readouterr().out
    assert 'STOP' in output and 'PASS:' not in output


def test_movement_fingerprint_is_read_only_and_covers_display_inheritance(tmp_path):
    obj = installer(tmp_path)
    captured = {}

    def run(argv, input=None, **kwargs):
        captured['sql'] = input
        return 'a' * 32

    obj.run = run
    assert m.Installer.fingerprint(obj) == 'a' * 32
    sql = captured['sql']
    assert sql.startswith('BEGIN READ ONLY; SELECT')
    assert 'ops.setup_display_state' in sql and 'ops.setup_container_state' in sql
    assert 'ops.setup_movement_event_display' in sql and 'ops.setup_movement_event' in sql
    assert not any(word in sql.upper() for word in ('INSERT', 'UPDATE', 'DELETE', 'CREATE'))
