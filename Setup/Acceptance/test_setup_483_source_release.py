"""#483 profile checks; existing engine tests own promotion/rollback coverage."""
from pathlib import Path
import sys
import pytest
sys.path.insert(0,str(Path(__file__).parent))
pytest.importorskip('fcntl')
import setup_483_source_release as profile


def test_reuses_established_source_promotion_rollback_and_fingerprint():
    for method in ('deploy','rollback','fingerprint','regression','focused_regression','cleanup'):
        assert getattr(profile.ThemeInstaller,method) is getattr(profile.engine.Installer,method)


def test_pins_accepted_source_and_current_rollback_without_node(monkeypatch):
    engine = profile.engine
    for name in ('TARGET','EXPECTED_OLD','VERSION','OLD_VERSION','SHARED','FOCUSED'):
        monkeypatch.setattr(engine,name,getattr(engine,name))
    monkeypatch.setattr(engine.subprocess,'check_output',lambda *a,**k:'verified-shared\n')
    profile.configure()
    assert engine.TARGET == 'fdf1549e4215c305cb82b3e6e70e327ade574dd2'
    assert engine.EXPECTED_OLD == '37a02e2d9460d115e1d7255833b264a6bb5d8d80'
    assert engine.SHARED == 'verified-shared'
    assert engine.VERSION == engine.OLD_VERSION == 'V0.3.111-explicit-no-work'
    assert 'Setup/Application/test_205_perform_theme.py' in engine.FOCUSED
