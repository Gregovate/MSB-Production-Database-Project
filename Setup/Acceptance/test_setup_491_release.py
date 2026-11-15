"""PR491 release validates the actual084 delta and preserves all business rows."""
import sys
import os
import json
from pathlib import Path
import pytest
HERE=Path(__file__).parent
sys.path.insert(0,str(HERE))
import setup_491_release as release


def test_exact_profile_and_mail_update_are_bounded():
    runner=object.__new__(release.QcRelease)
    runner.git=lambda *args: (HERE.parents[1]/args[-1].split(':',1)[1]).read_text()
    commands=[]
    runner.sql=commands.append
    runner.database_gate(False)
    runner.database_gate(True)
    assert '084 column baseline differs' in commands[0]
    assert commands[0].count('md5(p.prosrc)')==1
    assert commands[1].count('md5(p.prosrc)')==3
    assert 'tgtype=23' in commands[1]
    assert release.QcRelease.deploy is release.Deploy.deploy
    assert json.loads((HERE/'setup_491_release.json').read_text())['target']==release.CANDIDATE
    source=(HERE/'setup_491_release.py').read_text()
    assert "'start',MAIL_SERVICE" not in source
    assert "'restart',MAIL_SERVICE" not in source
    assert 'manager-mail-before' in source
    assert 'epoch-time.time()>3600' in source


def test_real_084_gate_fingerprint_and_classification():
    if not os.environ.get('MSB_QC_TEST_ADMIN_DSN'):
        pytest.skip('isolated PostgreSQL CI fixture only')
    import importlib.util
    spec=importlib.util.spec_from_file_location('qc491_fixture',HERE.parent/'Application/test_122_qc_postgres.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    fixture=module.db.__wrapped__();db=next(fixture)
    try:
        with db.cursor() as cur:
            for name in ('082_correct_qc_wording_and_shared_repairs.sql','083_repeatable_preshow_qc.sql'):
                cur.execute((HERE.parent/'Database'/name).read_text())
            cur.execute('''CREATE TABLE ops.setup_work_day_task(setup_work_day_task_id bigint,
              setup_session_task_id bigint,setup_work_day_id bigint,setup_work_day_crew_id bigint,shift_code text);
              INSERT INTO ops.setup_work_day_task VALUES(1,20,1,1,'AM');
              DO $$ BEGIN IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='msbadmin') THEN CREATE ROLE msbadmin; END IF; END $$;
              GRANT USAGE ON SCHEMA ops,ref TO msbadmin;
              GRANT SELECT ON ALL TABLES IN SCHEMA ops,ref TO msbadmin;
              ALTER FUNCTION ops.setup_qc_is_final_task(bigint) OWNER TO msbadmin;
              CREATE FUNCTION ref.fixture_stamp() RETURNS trigger LANGUAGE plpgsql AS $$
              BEGIN NEW.updated_at=clock_timestamp(); RETURN NEW; END $$;
              CREATE TRIGGER fixture_stamp BEFORE UPDATE ON ref.setup_task FOR EACH ROW EXECUTE FUNCTION ref.fixture_stamp();
              CREATE TRIGGER fixture_stamp BEFORE UPDATE ON ops.setup_session_task FOR EACH ROW EXECUTE FUNCTION ref.fixture_stamp();''')
        runner=object.__new__(release.QcRelease)
        runner.git=lambda *args:(HERE.parents[1]/args[-1].split(':',1)[1]).read_text()
        def execute(query):
            with db.cursor() as cur:
                if '\\gexec' in query:
                    first,last=query.split('\\gexec');cur.execute(first)
                    statements=[r[0] for r in cur.fetchall()];rows=[]
                    for statement in statements:
                        cur.execute(statement);rows.append(json.dumps(cur.fetchone()[0],sort_keys=True))
                    cur.execute(last);return '\n'.join(rows)
                cur.execute(query)
                # psql returns the intermediate SELECT from qc_ids before ROLLBACK.
                if 'json_agg(setup_session_task_id' in query:
                    cur.execute(query.split('ROLLBACK')[0]);value=json.dumps(cur.fetchone()[0]);cur.execute('ROLLBACK');return value
        runner.sql=execute
        runner.database_gate(False)
        baseline=runner.capture();runner.m={'frozen_qc_ids':runner.qc_ids()}
        with db.cursor() as cur:
            cur.execute((HERE.parent/'Database/084_classify_unscheduled_qc_checks.sql').read_text())
            for signature in ('ops.setup_qc_is_final_task(bigint)','ops.setup_inherit_qc_classification()','ops.setup_reject_qc_scheduling()'):
                cur.execute('ALTER FUNCTION '+signature+' OWNER TO msbadmin')
        runner.validate()
        assert runner.capture()==baseline
        with db.cursor() as cur:
            cur.execute("UPDATE ops.setup_work_day_task SET shift_code='PM' WHERE setup_session_task_id=10")
            cur.execute("UPDATE ref.setup_task SET task_name='Unexpected change'")
        assert runner.capture()!=baseline
    finally:
        try:next(fixture)
        except StopIteration:pass
