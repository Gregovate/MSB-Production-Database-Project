"""PR495 pins accepted source and changes only the readiness function."""
import json
import os
import sys
from pathlib import Path
import pytest
HERE=Path(__file__).parent
sys.path.insert(0,str(HERE))
import setup_495_release as release


def runner():
    obj=object.__new__(release.QcRelease)
    obj.git=lambda *args:(HERE.parents[1]/args[-1].split(':',1)[1]).read_text()
    return obj


def test_exact_manifest_gate_and_preservation():
    obj=runner();statements=[];obj.sql=statements.append
    obj.database_gate(False);obj.database_gate(True);obj.capture()
    assert statements[0]!=statements[1]
    assert all(s.count('md5(p.prosrc)')==2 for s in statements[:2])
    assert "IS DISTINCT FROM true" in statements[1]
    assert "IS DISTINCT FROM false" in statements[1]
    assert 'to_jsonb(t)::text' in statements[2]
    assert "to_jsonb(t)-" not in statements[2]
    manifest=json.loads((HERE/'setup_495_release.json').read_text())
    assert manifest['candidate']==manifest['target']==release.CANDIDATE
    assert manifest['migration']==release.MIGRATION
    assert release.QcRelease.deploy is release.Deploy.deploy
    assert release.QcRelease.promote_source is release.Deploy.promote_source
    source=(HERE/'setup_495_release.py').read_text()
    assert "require(self.m['old_setup']==OLD" in source
    assert "self.mail_hashes()==self.m['mail_before']" in source
    assert "'install'" not in source


def test_real_function_security_and_rows():
    if not os.environ.get('MSB_QC_TEST_ADMIN_DSN'):
        pytest.skip('isolated PostgreSQL fixture only')
    import importlib.util
    spec=importlib.util.spec_from_file_location('qc495_fixture',HERE.parent/'Application/test_122_qc_postgres.py')
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
            for file in ['084_classify_unscheduled_qc_checks.sql','067_fix_setup_annual_hold_command.sql']:
                cur.execute((HERE.parent/'Database'/file).read_text())
            for sig in ['ops.setup_qc_is_final_task(bigint)','ops.set_setup_annual_hold(text,bigint,boolean,text)']:
                cur.execute('ALTER FUNCTION '+sig+' OWNER TO msbadmin')
        obj=runner()
        def execute(query):
            with db.cursor() as cur:
                cur.execute(query)
        obj.sql=execute
        obj.database_gate(False)
        with db.cursor() as cur:
            cur.execute('SELECT json_agg(t) FROM ops.setup_session_task t');before=cur.fetchone()[0]
            cur.execute((HERE.parent/'Database/085_allow_qc_readiness_confirmation.sql').read_text())
        obj.database_gate(True)
        with db.cursor() as cur:
            cur.execute('SELECT json_agg(t) FROM ops.setup_session_task t');assert cur.fetchone()[0]==before
        with pytest.raises(Exception):obj.database_gate(False)
    finally:
        try:next(fixture)
        except StopIteration:pass
