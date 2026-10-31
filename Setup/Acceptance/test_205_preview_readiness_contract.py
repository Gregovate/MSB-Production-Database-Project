"""The existing runner must prove this report renders before Greg reviews it."""
from pathlib import Path


def test_manager_preview_gate_precedes_ready_and_is_scoped_to_205():
    source = Path(__file__).with_name('setup_disposable_browser_preview_server.sh').read_text()
    start = source.index('# #205 review must render')
    ready = source.index('SETUP REUSABLE DISPOSABLE BROWSER REVIEW READY')
    gate = source[start:ready]
    assert 'Setup/Acceptance/setup_205_manager_brief_readonly_validation.sql' in gate
    assert '/api/setup/notifications/manager-preview' in gate
    assert 'READ_ONLY_NO_SEND' in gate
    assert 'continuation_evidence' in gate and 'continuation_needed' in gate
    assert 'body_text' in gate and 'body_html' in gate
    assert 'exit 26' in gate
    assert '--request POST' not in gate and '/send' not in gate
