"""PR490 release boundaries using the existing isolated PostgreSQL fixture."""
import sys
from pathlib import Path
import pytest
HERE=Path(__file__).parent
sys.path.insert(0,str(HERE))
import setup_490_release as release


def test_all_function_bodies_are_pinned_in_read_only_gate():
    runner=object.__new__(release.QcRelease)
    runner.git=lambda *args: (HERE.parents[1]/args[-1].split(':',1)[1]).read_text()
    commands=[]
    runner.sql=commands.append
    runner.database_gate(False)
    runner.database_gate(True)
    assert '083 already present' in commands[0]
    assert commands[0].count('md5(p.prosrc)')==5
    assert commands[1].count('md5(p.prosrc)')==9
    assert 'BEGIN READ ONLY' in commands[1]
    assert 'IS DISTINCT FROM false' in commands[1]
    assert release.QcRelease.deploy is release.Deploy.deploy


def test_490_reopen_release_preserves_existing_business_rows():
    """Real correction082 gates and normalized fingerprints, not fixture writes on Production."""
    import importlib.util, os, json
    if not os.environ.get('MSB_QC_TEST_ADMIN_DSN'):
        pytest.skip('isolated PostgreSQL CI fixture only')
    import setup_490_release as followup
    spec = importlib.util.spec_from_file_location('qc490_fixture', HERE.parent/'Application/test_122_qc_postgres.py')
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
        with db.cursor() as cur:
            cur.execute((HERE.parent/'Database/082_correct_qc_wording_and_shared_repairs.sql').read_text())
        runner.database_gate(installed=False)
        before=runner.capture()
        with db.cursor() as cur:
            cur.execute((HERE.parent/'Database/083_repeatable_preshow_qc.sql').read_text())
            for sig in followup.NEW_SIGNATURES:
                cur.execute('ALTER FUNCTION '+sig+' OWNER TO msbadmin')
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
