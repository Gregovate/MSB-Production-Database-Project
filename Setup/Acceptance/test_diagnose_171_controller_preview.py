"""Clone boundary and exact-query capture tests; never contact a server."""
import importlib.util
from pathlib import Path
import sys
import pytest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('controller_probe', Path(__file__).with_name('diagnose_171_controller_preview.py'))
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
SHA = '0e53d5c6947cd93a4647928736b5cd91d481bc9b'


def state():
    root = '/tmp/msb-setup-browser-preview-candidate-20261025T190000'
    return dict(TARGET_SHA=SHA, PREVIEW_PORT='8898', TEST_CONTAINER='msb-setup-browser-preview-123',
                TEST_DB='msb_setup_browser_preview', CANDIDATE_WORKTREE=root,
                PREVIEW_ENTRY=root + '/Setup/Acceptance/setup_session_browser_preview_entry.py', PREVIEW_PGID='456')


def test_preview_boundary():
    assert probe.guard(state(), 8898, SHA)
    for key, bad in [('TEST_CONTAINER','msb-postgres'),('TEST_DB','msb'),
                     ('CANDIDATE_WORKTREE','/opt/fieldwiring'),('PREVIEW_PGID','x'),
                     ('TARGET_SHA','0'*40),('PREVIEW_PORT','8799')]:
        with pytest.raises(ValueError):
            probe.guard({**state(),key:bad},8898,SHA)


def test_state_is_data_not_executable(tmp_path):
    p = tmp_path/'state'
    p.write_text('PREVIEW_PORT=8898\nREPORT=/tmp/a\\ b.txt\nPROD_BEFORE=$\'ignored\\nvalue\'\n')
    assert probe.read_state(p) == {'PREVIEW_PORT':'8898','REPORT':'/tmp/a b.txt'}
    p.write_text('REPORT=$(touch /tmp/unsafe)\n')
    with pytest.raises(ValueError): probe.read_state(p)


def test_capture_actual_candidate_selects_without_connecting(monkeypatch):
    import psycopg2
    monkeypatch.setattr(psycopg2, 'connect', lambda *a,**k: pytest.fail('No connection during query capture'))
    queries = probe.capture_queries(ROOT, 101)
    assert len(queries) == 8
    assert sum(kind=='detail' for kind,_,_ in queries) == 3
    assert any('has_current_wiring' in sql for _,sql,_ in queries)
    for _,sql,params in queries:
        assert '%s' not in probe.literal_sql(sql,params)
    assert "'O''Brien'" in probe.literal_sql('SELECT %s',("O'Brien",))
    with pytest.raises(ValueError): probe.literal_sql('DELETE FROM ref.controller',())


def test_explain_is_clone_only_readonly_and_no_params_in_report(monkeypatch):
    calls=[]
    monkeypatch.setattr(probe,'command',lambda args,**kw: calls.append((args,kw)) or '[{"Execution Time":12,"Plan":{}}]')
    report={'sql':[]}
    probe.explain(state(),'SELECT %s',('private-email',),'unit',report)
    args,kw=calls[0]
    assert 'msb_setup_browser_preview' in args and 'msb-postgres' not in args
    assert kw['input'].startswith('BEGIN READ ONLY; SET LOCAL ROLE fieldwiring_app;')
    assert "statement_timeout='60s'" in kw['input']
    assert 'private-email' not in str(report)
