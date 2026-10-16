"""Real PostgreSQL catalog proof on an isolated CI database, never Production.

MSB_205_TEST_DSN must name the disposable CI fixture. No test is run by the
Production wrapper. The fixture is deliberately minimal: operator semantics
already passed current-Production disposable/browser acceptance.
"""
import os
from pathlib import Path
import re
import subprocess
import pytest
import setup_205_estimates_deploy as profile

ROOT = Path(__file__).resolve().parents[2]


def git_source(revision, path):
    return subprocess.check_output(['git', '-C', str(ROOT), 'show', revision + ':' + path], text=True).strip()


def fixture_sql():
    old = git_source(profile.OLD, profile.FOUNDATION)
    definitions = []
    for signature in (profile.CREW, profile.PLANNING):
        name = re.escape(signature.split('(')[0])
        definitions.append(re.search(r'CREATE OR REPLACE FUNCTION\s+' + name + r'\s*\(.*?\$function\$;', old, re.S).group())
    return '''CREATE ROLE msbadmin SUPERUSER; CREATE ROLE fieldwiring_app;
SET ROLE msbadmin;
CREATE SCHEMA ref AUTHORIZATION msbadmin; CREATE SCHEMA ops AUTHORIZATION msbadmin;
CREATE TABLE ref.setup_task (setup_task_id bigint,normal_crew_min integer,normal_crew_max integer,expected_duration_minutes integer,effort_level text);
CREATE TABLE ops.setup_session (id bigint); CREATE TABLE ops.setup_session_task (id bigint);
CREATE TABLE ops.setup_work_day_crew (id bigint); CREATE TABLE ops.setup_work_day_task (id bigint);
''' + '\n'.join(definitions) + '\n' + '\n'.join(
        f'REVOKE ALL ON FUNCTION {sig} FROM PUBLIC; GRANT EXECUTE ON FUNCTION {sig} TO fieldwiring_app;'
        for sig in (profile.CREW, profile.PLANNING))


def validation_sql(installed):
    # Generate the real runner's exact gate, with Git reads but no server access.
    d = object.__new__(profile.EstimatesDeploy)
    d.git = lambda *args: git_source(*args[1].split(':', 1))
    queries = []; d.sql = queries.append
    d.database_check(installed)
    return queries[0]


@pytest.mark.skipif(not os.getenv('MSB_205_TEST_DSN'), reason='isolated PostgreSQL CI fixture only')
def test_real_catalog_gates():
    import psycopg2
    with psycopg2.connect(os.environ['MSB_205_TEST_DSN']) as db:
        db.autocommit = True
        with db.cursor() as cur:
            cur.execute(fixture_sql())
            cur.execute(validation_sql(False))
            for path in profile.MIGRATIONS: cur.execute(git_source(profile.TARGET, path))
            cur.execute(validation_sql(True))
            with pytest.raises(psycopg2.Error): cur.execute(validation_sql(False))
            cur.execute('ROLLBACK')
            cur.execute('ALTER TABLE ref.setup_task DISABLE TRIGGER ' + profile.TRIGGER)
            with pytest.raises(psycopg2.Error): cur.execute(validation_sql(True))
            cur.execute('ROLLBACK')
            cur.execute('ALTER TABLE ref.setup_task ENABLE TRIGGER ' + profile.TRIGGER)
            cur.execute('GRANT UPDATE ON ref.setup_task TO fieldwiring_app')
            with pytest.raises(psycopg2.Error): cur.execute(validation_sql(True))
            cur.execute('ROLLBACK')
