"""Verify the accepted source and preservation-only manager mail checks."""
from pathlib import Path
import sys
import pytest
sys.path.insert(0, str(Path(__file__).parent))
import setup_493_release as release


def test_exact_candidate_and_source_only_rollback():
    assert release.source.TARGET == 'e9b6e227ecd547497ee364de244cbc194da09998'
    assert release.source.EXPECTED_OLD == '6a8cee60b96e28c62776c9668e9ca569c8ade81a'
    assert release.Release.rollback is release.source.Installer.rollback
    assert release.Release.health is release.source.Installer.health
    assert not hasattr(release.Release, 'install_mail')


def test_mail_drift_prevents_source_deploy(monkeypatch):
    runner = object.__new__(release.Release)
    runner.git = lambda *args: 'a' * 40
    def drift():
        raise RuntimeError('Installed manager source drift')
    runner.mail_preflight = drift
    monkeypatch.setattr(release.source.Installer, 'deploy', lambda self: pytest.fail('mutated source'))
    with pytest.raises(RuntimeError, match='source drift'):
        runner.deploy()


def test_success_validates_existing_mail_without_installing(monkeypatch):
    runner = object.__new__(release.Release)
    calls = []
    runner.git = lambda *args: 'a' * 40
    runner.mail_preflight = lambda: calls.append('preflight')
    runner.mail_validate = lambda: calls.append('unchanged mail')
    monkeypatch.setattr(release.source.Installer, 'deploy', lambda self: calls.append('source'))
    runner.deploy()
    assert calls == ['preflight', 'source', 'unchanged mail']
