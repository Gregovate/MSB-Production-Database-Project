"""#485 release-profile guards; no host or database access."""
import json
from pathlib import Path
import sys
import pytest

HERE = Path(__file__).parent
sys.path.insert(0,str(HERE))
import setup_485_release as release


def test_catalog_validation_matches_exact_accepted_function_without_test_writes():
    commands = []
    runner = object.__new__(release.QcRelease)
    runner.git = lambda *args: (HERE.parent/'Database/081_add_unscheduled_setup_qc_findings.sql').read_text()
    runner.sql = commands.append
    runner.database_gate(installed=True)
    assert len(commands) == 1
    assert 'BEGIN READ ONLY' in commands[0]
    assert 'QC direct sequence access' in commands[0]
    assert 'p.prosecdef' in commands[0]
    assert 'md5(p.prosrc)' in commands[0]
    assert 'INSERT INTO' not in commands[0]
    assert commands[0].count('md5(p.prosrc)') == 5
    assert 'setup_qc_final_gate(bigint)' in commands[0]
    assert 'IS DISTINCT FROM false' in commands[0]


def test_preflight_rejects_unknown_database_delta_before_any_migration(tmp_path):
    runner = object.__new__(release.QcRelease)
    runner.m = json.loads((HERE/'setup_485_release.json').read_text())
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
    assert release.QcRelease.deploy is release.Deploy.deploy
    assert 'stage' in release.QcRelease.capture.__code__.co_consts[1]
    assert release.QcRelease.cleanup is release.Deploy.cleanup


def test_release_sql_on_ephemeral_postgres():
    """Execute the read-only release gate against real accepted migration SQL."""
    import importlib.util
    import os
    if not os.environ.get('MSB_QC_TEST_ADMIN_DSN'):
        pytest.skip('isolated PostgreSQL CI fixture only')
    spec = importlib.util.spec_from_file_location('qc_release_fixture', HERE.parent/'Application/test_122_qc_postgres.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    # Reuse the existing unique local-only fixture; its finally drops the database.
    fixture = module.db.__wrapped__()
    db = next(fixture)
    try:
        with db.cursor() as cur:
            cur.execute("DO $$ BEGIN IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='msbadmin') THEN CREATE ROLE msbadmin; END IF; END $$;")
            for sig in release.SIGNATURES:
                cur.execute('ALTER FUNCTION '+sig+' OWNER TO msbadmin')
        runner = object.__new__(release.QcRelease)
        runner.git = lambda *args: (HERE.parent/'Database/081_add_unscheduled_setup_qc_findings.sql').read_text()
        def execute(query):
            with db.cursor() as cur:
                cur.execute(query)
        runner.sql = execute
        runner.validate()
        # Existing QC objects must reject replay before the migration begins.
        with pytest.raises(module.psycopg2.errors.RaiseException):
            runner.database_gate(installed=False)
        db.rollback()
    finally:
        try:
            next(fixture)
        except StopIteration:
            pass


def test_489_correction_release_preserves_existing_business_rows():
    """Real correction082 gates and normalized fingerprints, not fixture writes on Production."""
    import importlib.util, os, json
    if not os.environ.get('MSB_QC_TEST_ADMIN_DSN'):
        pytest.skip('isolated PostgreSQL CI fixture only')
    import setup_489_release as followup
    spec = importlib.util.spec_from_file_location('qc489_fixture', HERE.parent/'Application/test_122_qc_postgres.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    fixture = module.db.__wrapped__()
    db = next(fixture)
    try:
        with db.cursor() as cur:
            cur.execute("DO $$ BEGIN IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='msbadmin') THEN CREATE ROLE msbadmin; END IF; END $$;")
            for sig in followup.SIGNATURES:
                cur.execute('ALTER FUNCTION '+sig+' OWNER TO msbadmin')
            cur.execute("INSERT INTO ops.setup_qc_finding(setup_session_task_id,title,status,created_by_person_id) VALUES(20,'Existing repair','OPEN',1)")
        runner = object.__new__(followup.QcRelease)
        runner.git = lambda *args: (HERE.parents[1]/args[-1].split(':',1)[1]).read_text()
        def execute(query):
            with db.cursor() as cur:
                if '\\gexec' in query:
                    first, last = query.split('\\gexec')
                    cur.execute(first)
                    statements = [row[0] for row in cur.fetchall()]
                    rows=[]
                    for statement in statements:
                        cur.execute(statement)
                        rows.append(json.dumps(cur.fetchone()[0],sort_keys=True))
                    cur.execute(last)
                    return '\n'.join(rows)
                cur.execute(query)
        runner.sql = execute
        runner.database_gate(installed=False)
        before=runner.capture()
        with db.cursor() as cur:
            cur.execute((HERE.parent/'Database/082_correct_qc_wording_and_shared_repairs.sql').read_text())
        runner.validate()
        assert runner.capture()==before
        with db.cursor() as cur:
            cur.execute("UPDATE ops.setup_qc_finding SET title='Unexpected mutation'")
        assert runner.capture()!=before
    finally:
        try:
            next(fixture)
        except StopIteration:
            pass
