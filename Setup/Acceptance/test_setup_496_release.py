"""Real release guards: accepted source, atomic migration and bounded row change."""
import importlib.util
import json
import os
import sys
from pathlib import Path
import pytest
HERE=Path(__file__).parent
sys.path.insert(0,str(HERE))
import setup_496_release as release


def runner():
    obj=object.__new__(release.QcRelease)
    obj.git=lambda *args:(HERE.parents[1]/args[-1].split(':',1)[1]).read_text()
    obj.source_baseline=lambda:None
    obj.journal=lambda:None
    obj.m={}
    return obj


def test_manifest_atomicity_and_preservation_contract():
    obj=runner();statements=[];obj.sql=statements.append
    obj.database_gate(False);obj.database_gate(True);obj.capture()
    assert all(s.count('md5(p.prosrc)')==3 for s in statements[:2])
    assert "setup_session_task_id'='590'" in statements[2]
    obj.database_gate=lambda installed:None
    obj.qc_ids=lambda:[588,590]
    obj.duplicate=lambda:{'included_flag':True}
    obj.apply_migrations()
    assert statements[-1].count('\nCOMMIT;')==1
    assert statements[-1].count('BEGIN;')==1
    manifest=json.loads((HERE/'setup_496_release.json').read_text())
    assert manifest['candidate']==manifest['target']==release.CANDIDATE
    assert manifest['migrations']==list(release.MIGRATIONS)
    assert release.QcRelease.deploy is release.Deploy.deploy


def test_real_release_security_preservation_and_cleanup():
    if not os.environ.get('MSB_QC_TEST_ADMIN_DSN'):
        pytest.skip('isolated PostgreSQL fixture only')
    spec=importlib.util.spec_from_file_location('qc496_fixture',HERE.parent/'Application/test_122_qc_postgres.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    fixture=module.db.__wrapped__();db=next(fixture)
    try:
        with db.cursor() as cur:
            for file in ['082_correct_qc_wording_and_shared_repairs.sql','083_repeatable_preshow_qc.sql']:
                cur.execute((HERE.parent/'Database'/file).read_text())
            cur.execute('''CREATE TABLE ops.setup_work_day_task(setup_session_task_id bigint);
              DO $$ BEGIN IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='msbadmin') THEN CREATE ROLE msbadmin; END IF; END $$;
              GRANT USAGE ON SCHEMA ops,ref TO msbadmin;
              GRANT SELECT ON ALL TABLES IN SCHEMA ops,ref TO msbadmin;''')
            for file in ['084_classify_unscheduled_qc_checks.sql','085_allow_qc_readiness_confirmation.sql']:
                cur.execute((HERE.parent/'Database'/file).read_text())
            for sig in ['ops.setup_qc_final_gate(bigint)','ops.setup_qc_is_final_task(bigint)','ops.set_setup_annual_hold(text,bigint,boolean,text)']:
                cur.execute('ALTER FUNCTION '+sig+' OWNER TO msbadmin')
            cur.execute("INSERT INTO ref.stage VALUES(19,'19','19-Santa''s Workshop-SW')")
            cur.execute('''INSERT INTO ops.setup_session_task
              (setup_session_task_id,setup_session_id,setup_task_id,annual_task_name,annual_stage_id)
              VALUES(588,1,120,'Santa QC',19),(590,1,120,'Duplicate',19)''')
        obj=runner()
        def execute(query):
            with db.cursor() as cur:
                if '\\gexec' in query:
                    # Execute the same dynamic fingerprint SQL used by psql.
                    cur.execute(query.split('\\gexec')[0]);generated=cur.fetchall()
                    rows=[]
                    for (statement,) in generated:
                        cur.execute(statement);rows.append(cur.fetchone()[0])
                    cur.execute('ROLLBACK')
                    return json.dumps(rows,sort_keys=True)
                cur.execute(query)
                return json.dumps(cur.fetchone()[0]) if cur.description else ''
        obj.sql=execute
        obj.database_gate(False)
        before=obj.capture()
        obj.apply_migrations();obj.validate()
        assert obj.capture()==before
        with db.cursor() as cur:
            cur.execute("UPDATE ops.setup_session_task SET annual_task_name='Unexpected edit' WHERE setup_session_task_id=590")
        assert obj.capture()!=before
        with pytest.raises(RuntimeError):obj.validate()
    finally:
        try:next(fixture)
        except StopIteration:pass
