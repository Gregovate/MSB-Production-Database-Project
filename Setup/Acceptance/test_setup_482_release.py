"""#482 release-profile guards; no host or database access."""
import json
from pathlib import Path
import sys
import pytest

HERE = Path(__file__).parent
sys.path.insert(0,str(HERE))
import setup_482_release as release


def test_catalog_validation_matches_exact_accepted_function_without_test_writes():
    commands = []
    runner = object.__new__(release.SchedulingRelease)
    runner.git = lambda *args: (HERE.parent/'Database/080_prevent_unreported_setup_assignment_duplicates.sql').read_text()
    runner.sql = commands.append
    runner.database_gate(installed=True)
    assert len(commands) == 1
    assert 'BEGIN READ ONLY' in commands[0]
    assert 't.tgtype=7' in commands[0]
    assert 'p.prosecdef' in commands[0]
    assert 'md5(p.prosrc)' in commands[0]
    assert 'INSERT INTO' not in commands[0]


def test_preflight_rejects_unknown_database_delta_before_any_migration(tmp_path):
    runner = object.__new__(release.SchedulingRelease)
    runner.m = json.loads((HERE/'setup_482_release.json').read_text())
    runner.root = tmp_path
    runner.mark = lambda stage: None
    runner.online = lambda: None
    runner.journal = lambda: None
    runner.source_baseline = lambda: None
    runner.health = lambda version: None
    runner.source_version = lambda sha: release.VERSION
    runner.run = lambda *args: ''
    calls = []
    def git(*args,**kwargs):
        calls.append(args)
        if args[:2] == ('rev-parse','HEAD'): return 'a'*40
        if args[0] == 'diff': return 'Setup/Database/unapproved.sql'
        return ''
    runner.git = git
    runner.sql = lambda query: pytest.fail('Preflight must stop before any SQL')
    with pytest.raises(release.orchestrator.Stop,match='Unexpected database delta'):
        runner.preflight()
    assert not any(args[:2] == ('worktree','add') for args in calls)


def test_profile_reuses_single_existing_maintenance_transaction():
    assert release.SchedulingRelease.deploy is release.Deploy.deploy
    assert release.SchedulingRelease.capture is release.CalendarRelease.capture
    assert release.SchedulingRelease.cleanup is release.Deploy.cleanup
