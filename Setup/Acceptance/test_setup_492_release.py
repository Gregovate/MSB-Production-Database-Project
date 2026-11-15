"""Exercise partial mail installation rollback without a server or SMTP."""
import io
from pathlib import Path
import shutil
import sys
import pytest
sys.path.insert(0, str(Path(__file__).parent))
import setup_492_release as release


def test_partial_mail_install_restores_every_file_before_source_rollback(tmp_path, monkeypatch):
    installed = tmp_path / 'mail'
    installed.mkdir()
    live = tmp_path / 'live'
    incoming = live / 'Setup/Acceptance/manager_mail_pilot'
    incoming.mkdir(parents=True)
    for name in release.MAIL_FILES:
        (installed / name).write_text('old ' + name)
        (incoming / name).write_text('new ' + name)
    monkeypatch.setattr(release, 'MAIL_ROOT', str(installed))
    monkeypatch.setattr(release.source, 'LIVE', str(live))
    runner = object.__new__(release.Release)
    runner.root = tmp_path / 'report'
    runner.root.mkdir()
    runner.mail_advanced = False
    runner.mail_idle = lambda *args: None
    runner.mail_hashes = lambda: {p.name:p.read_text() for p in installed.iterdir() if not p.name.endswith('.pr492-new')}
    runner.mail_before = runner.mail_hashes()
    runner.mail_validate = lambda: None
    calls=[]
    def run(args, **kwargs):
        calls.append(args)
        if args[1] == 'test':
            assert not Path(args[-1]).exists()
        elif args[1] == 'cp':
            shutil.copy2(args[-2],args[-1])
        elif args[1] == 'install':
            if args[-1].endswith('manager_digest_template.txt.pr492-new'):
                raise RuntimeError('simulated partial install')
            shutil.copy2(args[-2],args[-1])
        elif args[1] == 'mv':
            Path(args[-2]).replace(args[-1])
        elif args[1] == 'rm':
            Path(args[-1]).unlink(missing_ok=True)
        else:
            raise AssertionError(args)
    runner.run=run
    with pytest.raises(RuntimeError, match='partial install'):
        runner.install_mail()
    assert runner.mail_advanced
    assert (installed / release.MAIL_FILES[0]).read_text().startswith('new')
    def source_rollback(self):
        assert self.mail_hashes() == self.mail_before
        calls.append(['source rollback'])
    monkeypatch.setattr(release.source.Installer,'rollback',source_rollback)
    runner.rollback()
    assert calls[-1] == ['source rollback']
    assert runner.mail_hashes() == runner.mail_before
    assert not runner.mail_advanced


def test_busy_sender_stops_before_file_mutation():
    runner=object.__new__(release.Release)
    calls=[]
    runner.run=lambda args, **kwargs: calls.append(args) or 'active'
    with pytest.raises(RuntimeError,match='running or failed'):
        runner.mail_preflight()
    assert len(calls)==1 and calls[0][0]=='systemctl'


def test_accepted_source_stays_pinned_and_no_database_or_sender_command():
    assert release.source.TARGET == '6a8cee60b96e28c62776c9668e9ca569c8ade81a'
    assert release.source.EXPECTED_OLD == 'aba4a5a4aacd54a648d8d2770743b757d28d4d86'
    text=Path(release.__file__).read_text()
    assert 'BEGIN READ ONLY' in text
    assert 'setup_task_progress' in text and 'setup_qc_signoff_history' in text
    assert "'restart', MAIL_SERVICE" not in text
    assert ' --daily' not in text and ' --send' not in text


def test_read_probe_uses_current_management_contract_not_legacy_movement_shape(monkeypatch):
    runner = object.__new__(release.Release)
    queries = []
    runner.run = lambda args, **kwargs: queries.append(kwargs.get('input'))
    monkeypatch.setattr(release.source.Installer, 'report_read_probe',
                        lambda self: pytest.fail('obsolete movement probe invoked'))
    runner.report_read_probe()
    assert len(queries) == 1
    assert 'SET LOCAL ROLE fieldwiring_app' in queries[0]
    assert 'ops.setup_qc_snapshot' in queries[0]
    assert 'sum(crew_count*duration_minutes)' in queries[0]
    assert queries[0].strip().endswith('ROLLBACK;')
