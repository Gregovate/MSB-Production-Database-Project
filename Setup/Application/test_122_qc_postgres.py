"""Actual migration081 PostgreSQL tests on an isolated localhost CI database.

No Production connection or Node. Auth fixtures stand in for existing identity
functions; all QC gates, locking, persistence and permissions are real SQL.
"""
import os
from pathlib import Path
from uuid import uuid4

import psycopg2
from psycopg2 import sql
from psycopg2.extensions import parse_dsn, make_dsn
import pytest

DSN = os.environ.get('MSB_QC_TEST_ADMIN_DSN')
pytestmark = pytest.mark.skipif(not DSN, reason='isolated PostgreSQL CI fixture only')

FIXTURE = """
CREATE SCHEMA ops; CREATE SCHEMA ref; CREATE SCHEMA stage;
DO $$ BEGIN IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='fieldwiring_app')
THEN CREATE ROLE fieldwiring_app; END IF; END $$;
-- Match the established application schema boundary; table access stays denied.
GRANT USAGE ON SCHEMA ops,ref TO fieldwiring_app;
CREATE TABLE public.directus_users(id uuid PRIMARY KEY,email text,status text);
CREATE TABLE ref.person(person_id integer PRIMARY KEY,first_name text,last_name text,email text,directus_user_id uuid);
INSERT INTO public.directus_users VALUES('00000000-0000-0000-0000-000000000001','crew@test','active');
INSERT INTO ref.person VALUES(1,'Crew','Auditor','crew@test','00000000-0000-0000-0000-000000000001');
CREATE FUNCTION ref.setup_execution_actor(text,bigint) RETURNS TABLE(person_id integer,can_manage_setup boolean)
LANGUAGE plpgsql AS $$ BEGIN IF $1<>'crew@test' THEN RAISE EXCEPTION USING ERRCODE='42501'; END IF;
RETURN QUERY SELECT 1,false; END $$;
CREATE FUNCTION ref.setup_browser_capabilities(text) RETURNS TABLE(can_read_setup boolean,can_manage_setup boolean)
LANGUAGE sql AS $$ SELECT $1='crew@test',false $$;
CREATE TABLE ref.stage(stage_id integer PRIMARY KEY,stage_key text,stage_name text);
CREATE TABLE ref.lor_scene(lor_scene_id integer PRIMARY KEY,scene_name text);
CREATE TABLE ops.setup_session(setup_session_id integer PRIMARY KEY,season_year integer);
INSERT INTO ops.setup_session VALUES(1,2026);
CREATE TABLE ops.setup_session_task(setup_session_task_id bigint PRIMARY KEY,setup_session_id integer,
 setup_task_id bigint,annual_task_name text,included_flag boolean DEFAULT true,annual_stage_id integer,
 annual_lor_scene_id integer,task_origin text DEFAULT 'REUSABLE',execution_status text DEFAULT 'NOT_READY',
 annual_readiness_state text DEFAULT 'READY',linked_work_order_gate boolean DEFAULT false,
 linked_work_order_id integer,actual_completed_at timestamptz,completed_by_person_id integer,completion_note text);
CREATE TABLE ref.setup_task_dependency(setup_task_id bigint,prerequisite_setup_task_id bigint);
CREATE TABLE ops.setup_session_task_dependency(setup_session_task_id bigint,prerequisite_setup_session_task_id bigint,dependency_origin text);
CREATE TABLE ops.work_order(work_order_id integer PRIMARY KEY,source_intake_id integer,date_completed date);
CREATE VIEW ops.setup_scheduling_work_order_gate AS SELECT * FROM ops.work_order;
CREATE TABLE stage.work_order_intake(intake_id integer PRIMARY KEY,stage_id integer,target_year integer,
 updated_at timestamptz,submitter_name_raw text,problem_raw text,notes_raw text,source_form_name text);
INSERT INTO ops.setup_session_task(setup_session_task_id,setup_session_id,setup_task_id,annual_task_name,annual_stage_id,annual_lor_scene_id)
VALUES(10,1,110,'Install wiring',5,7),(11,1,111,'Shared Stage work',5,NULL),
(20,1,120,'Plug in Network to controller and watch display against 2 minute Test show',5,7),
(30,1,130,'Other area work',6,8),(40,1,140,'External prerequisite',6,8);
INSERT INTO ref.setup_task_dependency VALUES(120,140);
"""

@pytest.fixture
def db():
    opts = parse_dsn(DSN)
    assert opts.get('host') in ('127.0.0.1', 'localhost'), 'Only local ephemeral CI PostgreSQL is allowed'
    name = 'qc_test_' + uuid4().hex
    admin = psycopg2.connect(DSN)
    admin.autocommit = True
    with admin.cursor() as cur:
        cur.execute(sql.SQL('CREATE DATABASE {}').format(sql.Identifier(name)))
    conn = psycopg2.connect(make_dsn(DSN, dbname=name))
    conn.autocommit = True
    try:
        with conn.cursor() as cur:
            cur.execute(FIXTURE)
            cur.execute((Path(__file__).parents[1]/'Database/081_add_unscheduled_setup_qc_findings.sql').read_text())
        yield conn
    finally:
        conn.close()
        with admin.cursor() as cur:
            cur.execute(sql.SQL('DROP DATABASE {}').format(sql.Identifier(name)))
        admin.close()


def test_actual_final_gate_and_post_signoff_boundary(db):
    def query(statement, args=()):
        with db.cursor() as cur:
            cur.execute(statement, args)
            return cur.fetchone()[0] if cur.description else None

    def command(action, finding=None, note=None):
        return query('SELECT ops.setup_qc_command(%s,%s,20,%s,%s)', ('crew@test',action,finding,note))

    def final(seconds=120, evidence='Observed full test; all working', email='crew@test'):
        return query('SELECT ops.setup_qc_ready_for_production(%s,20,%s,%s,%s)',
                     (email,evidence,seconds,'Two minute test v1'))

    # Ordinary Crew may report before any claim, readiness, or work completion.
    ids = command('REPORT_LINES',note='Arch 3 red\nArch 4 blue')['finding_ids']
    assert len(ids) == 2
    with pytest.raises(psycopg2.errors.InsufficientPrivilege):
        final()
    command('CLAIM_AUDIT')
    for seconds, evidence in [(119,'Observed'),(120,None)]:
        with pytest.raises(psycopg2.errors.InvalidParameterValue):
            final(seconds,evidence)
    with pytest.raises(psycopg2.errors.InsufficientPrivilege):
        final(email='outsider@test')
    gate = query('SELECT ops.setup_qc_final_gate(20)')
    assert {x['id'] for x in gate['unfinished_work']} == {10,11,40}
    # Same scene, shared Stage work and external reusable prerequisite all block.
    with pytest.raises(psycopg2.errors.CheckViolation):
        final()
    query("UPDATE ops.setup_session_task SET execution_status='COMPLETE' WHERE setup_session_task_id IN (10,11,40)")
    query("UPDATE ops.setup_session_task SET annual_readiness_state='NOT_READY' WHERE setup_session_task_id=20")
    with pytest.raises(psycopg2.errors.CheckViolation):
        final()
    query("UPDATE ops.setup_session_task SET annual_readiness_state='READY' WHERE setup_session_task_id=20")
    for finding in ids:
        for action in [None, 'CLAIM_REPAIR', 'REPAIRED']:
            if action:
                command(action, finding, 'Actual fixture repair' if action=='REPAIRED' else None)
            with pytest.raises(psycopg2.errors.CheckViolation):
                final()
        command('RETEST_PASS', finding, 'Observed working in retest')
    # Actual application role executes the final gate without direct QC-table access.
    query('SET ROLE fieldwiring_app')
    with pytest.raises(psycopg2.errors.InsufficientPrivilege):
        query('SELECT * FROM ops.setup_qc_signoff')
    result=final()
    assert result['status']=='READY_FOR_PRODUCTION'
    snap=query("SELECT ops.setup_qc_snapshot('crew@test',2026)")
    assert snap['viewer_person_id']==1 and len(snap['signoffs'])==1
    for action in ['REPORT_LINES','REOPEN','CLAIM_AUDIT']:
        with pytest.raises(psycopg2.errors.CheckViolation):
            command(action, ids[0], 'New failure after signoff')
    with pytest.raises(psycopg2.errors.CheckViolation):
        final()
    query('RESET ROLE')
    assert query("SELECT execution_status FROM ops.setup_session_task WHERE setup_session_task_id=20")=='COMPLETE'
    assert query('SELECT completed_by_person_id FROM ops.setup_session_task WHERE setup_session_task_id=20')==1
    assert query("SELECT execution_status FROM ops.setup_session_task WHERE setup_session_task_id=30")=='NOT_READY'
    assert query('SELECT count(*) FROM ops.work_order')==0
    assert query('SELECT count(*) FROM stage.work_order_intake')==0
