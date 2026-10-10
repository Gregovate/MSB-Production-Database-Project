#!/usr/bin/env python3
"""Bounded Setup deployment using the installed Server Management controller."""
import argparse
try:
    import fcntl
except ImportError:  # Allows non-Linux engineering tests; execution is Linux-only.
    fcntl = None
import json
import os
import re
from pathlib import Path
import subprocess
import sys
import tempfile
from datetime import datetime, timezone

REPO = '/opt/fieldwiring'
SETUP = '/opt/msb-setup'
PYTHON = '/opt/fieldwiring/.venv/bin/python'
CONTROL = ['sudo', 'python3', '/opt/msb-maintenance/msb_maintenance_controller.py',
           '--config', '/etc/msb-maintenance/config.json']
PSQL = ['sudo', 'docker', 'exec', '-i', 'msb-postgres', 'psql', '-X', '-qAt',
        '-v', 'ON_ERROR_STOP=1', '-U', 'msbadmin', '-d', 'msb']

class Stop(RuntimeError):
    pass

def require(condition, message):
    if not condition:
        raise Stop(message)

class Deploy:
    def __init__(self, manifest, report_dir):
        self.m = manifest
        self.root = Path(report_dir)
        self.root.mkdir(parents=True, exist_ok=False)
        self.stage = 'created'
        self.worktree = None
        self.maintenance_started = False
        self.migration_started = False
        self.committed = False
        self.log = (self.root / 'report.txt').open('a', buffering=1)
        self.journal()

    def journal(self, **extra):
        data = dict(manifest=self.m, stage=self.stage,
                    maintenance_started=self.maintenance_started,
                    migration_started=self.migration_started,
                    migration_confirmed=self.committed, **extra)
        temporary = self.root / 'state.tmp'
        temporary.write_text(json.dumps(data, indent=2) + '\n')
        os.replace(temporary, self.root / 'state.json')

    def run(self, argv, input=None, timeout=120):
        self.log.write('COMMAND ' + repr(argv) + '\n')
        result = subprocess.run(argv, input=input, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout)
        self.log.write(result.stdout + '\n')
        require(result.returncode == 0, 'Command failed; inspect retained report')
        return result.stdout.strip()

    def git(self, *args, root=REPO):
        return self.run(['sudo', 'git', '-C', root, *args])

    def sql(self, query):
        return self.run(PSQL, input=query, timeout=180)

    def controller(self, action, *args):
        return json.loads(self.run(CONTROL + [action, *args], timeout=300))

    def mark(self, stage):
        self.stage = stage
        self.log.write('STAGE ' + stage + '\n')
        self.journal()
        if self.maintenance_started:
            self.controller('stage', ('PR318/070 ' if self.m.get('profile') == 'field-070' else 'PR293 ') + stage)

    @staticmethod
    def frozen(state):
        require(state.get('state') == 'MAINTENANCE', 'Maintenance not proven')
        require(state.get('gates', {}).get('freeze_proof', {}).get('ok') is True,
                'Freeze proof not PASS')
        require(state.get('maintenance_started_at'), 'Missing current maintenance entry')
        require(state.get('live', {}).get('database_fenced') is True, 'Live fence absent')
        require(not state.get('last_error'), 'Controller reports error')
        sessions = state.get('live', {}).get('sessions')
        require(isinstance(sessions, list), 'Live sessions not available')
        require(all(s.get('usename') == 'msbadmin' and s.get('client_addr') == 'local'
                    for s in sessions), 'Normal writer sessions still present')

    def preflight(self):
        if self.m.get('profile') == 'field-070':
            return self.field_preflight()
        self.mark('ONLINE preflight')
        m = self.m
        require(self.git('rev-parse', 'HEAD', root=SETUP) == m['old_setup'], 'Setup SHA changed')
        require(self.git('rev-parse', 'HEAD') == m['shared'], 'Shared SHA changed')
        require(not self.git('status', '--porcelain', root=SETUP), 'Setup checkout dirty')
        require(not self.git('status', '--porcelain'), 'Shared checkout dirty')
        health = json.loads(self.run(['curl', '-fsS', '--max-time', '10',
                                     'http://192.168.5.9:8794/api/health']))
        require(health.get('status') == 'ok' and health.get('data_mode') == 'postgres'
                and health.get('version') == m['old_version'], 'Unexpected current Setup health')
        state = self.controller('status')
        require(state.get('state') == 'ONLINE' and not state.get('last_error')
                and state.get('live', {}).get('database_fenced') is False,
                'Production is not healthy ONLINE')
        live = state.get('live', {})
        require(live.get('mode') == 'real', 'Controller is not real Production')
        expected_services = ['msb-setup.service', 'fieldwiring.service', 'msb-procedures.service',
                             'msb-people.service', 'lor-preflight-api.service']
        require(all(live.get('services', {}).get(s) == 'active' for s in expected_services)
                and live.get('services', {}).get('container:msb-directus') == 'running',
                'Governed services unhealthy')
        require(live.get('backups', {}).get('nas_mounted') is True and
                live.get('backups', {}).get('replication', {}).get('current_run_ok') is True,
                'Backup chain not current')
        self.git('fetch', 'origin', '+refs/heads/main:refs/remotes/origin/main')
        self.git('merge-base', '--is-ancestor', m['target'], 'origin/main')
        self.git('merge-base', '--is-ancestor', m['old_setup'], m['target'])
        require(self.git('rev-parse', m['target'] + '^{tree}') == m['tree'], 'Merged target tree changed')
        require(self.git('rev-parse', m['candidate'] + '^{tree}') == m['tree'], 'Candidate tree changed')
        require(self.git('rev-parse', m['target'] + ':' + m['migration']) == m['migration_blob'],
                'Migration blob changed')
        ui_date = self.git('log', '-1', '--format=%cs', m['target'], '--',
                           ':(glob)Setup/Application/**/*.html',
                           ':(glob)Setup/Application/**/*.css',
                           ':(glob)Setup/Application/**/*.js')
        footer = self.git('show', m['target'] + ':Setup/Application/production.html')
        require(bool(ui_date) and re.findall(r'Updated\s+(\d{4}-\d{2}-\d{2})', footer) == [ui_date],
                'Stale visible UI date: update footer before deployment')
        self.sql("""DO $$ BEGIN
          IF to_regprocedure('ops.remove_empty_setup_work_day(text,bigint)') IS NULL
             OR to_regprocedure('ops.reject_past_setup_work_day_insert()') IS NULL
             OR NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='ops.setup_work_day'::regclass
                            AND tgname='trg_setup_work_day_reject_past_insert' AND tgenabled <> 'D')
             OR position('NEW.work_date < current_date' in pg_get_functiondef(
                  'ops.reject_past_setup_work_day_insert()'::regprocedure)) = 0
          THEN RAISE EXCEPTION 'Migration 068 baseline incomplete'; END IF;
          IF to_regclass('ops.setup_schedule_event') IS NOT NULL THEN
             RAISE EXCEPTION '069 objects already present: inspect, do not retry'; END IF;
        END $$;""")
        inventory = self.sql("""SELECT row_to_json(q) FROM (
          SELECT wd.setup_session_id, ss.season_year, ss.session_status,
            wd.setup_work_day_id, wd.work_date, wd.setup_day_number,
            row_number() OVER (PARTITION BY wd.setup_session_id ORDER BY wd.work_date,wd.setup_work_day_id)
              AS proposed_day_number
          FROM ops.setup_work_day wd JOIN ops.setup_session ss USING(setup_session_id)
          WHERE ss.session_status IN ('PLANNING','ACTIVE') ORDER BY wd.setup_session_id,wd.work_date
        ) q;""")
        (self.root / 'proposed-days.jsonl').write_text(inventory + '\n')
        audit = self.sql("SELECT pg_get_functiondef('ref.set_actor_on_update()'::regprocedure);")
        (self.root / 'audit-function.txt').write_text(audit + '\n')
        (self.root / 'online-invariants.jsonl').write_text(self.capture() + '\n')
        self.worktree = tempfile.mkdtemp(prefix='msb-setup-reviewed-', dir='/tmp')
        os.chmod(self.worktree, 0o755)
        self.git('worktree', 'add', '--detach', self.worktree, m['target'])
        self.run(['sudo', '-u', 'fieldwiring', '-H', 'env', 'PYTHONDONTWRITEBYTECODE=1',
                  'bash', '-c', 'cd ' + self.worktree + ' && ' + PYTHON +
                  ' -m pytest -q -p no:cacheprovider Setup/Application'], timeout=300)
        self.mark('preflight PASS')

    def capture(self):
        if self.m.get('profile') == 'field-070':
            # Function-only release preserves every business row, including audit fields.
            return self.sql(r"""BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
              SELECT format('SELECT json_build_object(''table'',%L,''digest'',md5(coalesce(string_agg(to_jsonb(t)::text, ORDER BY to_jsonb(t)::text),))) FROM %I.%I t;',
                n.nspname||'.'||c.relname,n.nspname,c.relname)
              FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
              WHERE n.nspname IN ('ref','ops') AND c.relkind IN ('r','p')
              ORDER BY n.nspname,c.relname
              \gexec
              ROLLBACK;""")
        # Hash all ref/ops business tables in one read-only transaction.
        # Only open Work Day sequence and three update audit columns may differ.
        return self.sql(r"""BEGIN READ ONLY;
          SELECT format(
            'SELECT json_build_object(''table'',%L,''digest'',md5(coalesce(string_agg(j::text,'''' ORDER BY j::text),''''))) FROM (SELECT %s AS j FROM %I.%I t) rows;',
            n.nspname||'.'||c.relname,
            CASE WHEN n.nspname='ops' AND c.relname='setup_work_day' THEN
              'CASE WHEN EXISTS (SELECT 1 FROM ops.setup_session s WHERE s.setup_session_id=t.setup_session_id AND s.session_status IN (''PLANNING'',''ACTIVE'')) THEN to_jsonb(t)-ARRAY[''setup_day_number'',''updated_at'',''updated_by'',''updated_by_person_id''] ELSE to_jsonb(t) END'
            ELSE 'to_jsonb(t)' END, n.nspname,c.relname)
          FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE n.nspname IN ('ref','ops') AND c.relkind IN ('r','p')
            AND NOT (n.nspname='ops' AND c.relname='setup_schedule_event')
          ORDER BY n.nspname,c.relname
          \gexec
          ROLLBACK;
        """)

    def validate(self):
        if self.m.get('profile') == 'field-070':
            return self.field_database_check(installed=True)
        self.sql("""DO $$ BEGIN
          IF EXISTS (SELECT 1 FROM (
             SELECT w.setup_day_number, row_number() OVER
               (PARTITION BY w.setup_session_id ORDER BY w.work_date,w.setup_work_day_id) rn
             FROM ops.setup_work_day w JOIN ops.setup_session s USING(setup_session_id)
             WHERE s.session_status IN ('PLANNING','ACTIVE')) q WHERE setup_day_number <> rn)
          THEN RAISE EXCEPTION 'Chronological numbering failed'; END IF;
          IF to_regprocedure('ops.add_historical_setup_work_day(text,integer,date,text)') IS NULL
             OR to_regprocedure('ops.remove_empty_setup_work_day(text,bigint,text)') IS NULL
          THEN RAISE EXCEPTION '069 commands missing'; END IF;
          IF NOT has_function_privilege('fieldwiring_app',
              'ops.add_historical_setup_work_day(text,integer,date,text)','EXECUTE')
             OR NOT has_function_privilege('fieldwiring_app',
              'ops.remove_empty_setup_work_day(text,bigint,text)','EXECUTE')
             OR has_function_privilege('fieldwiring_app',
              'ops.resequence_setup_future_work_days(bigint)','EXECUTE')
             OR has_table_privilege('fieldwiring_app','ops.setup_schedule_event','INSERT,UPDATE,DELETE')
          THEN RAISE EXCEPTION '069 least privilege failed'; END IF;
          IF EXISTS (SELECT 1 FROM ops.setup_schedule_event) THEN
             RAISE EXCEPTION 'Unexpected deployment schedule events'; END IF;
          IF (SELECT count(*) FROM pg_trigger WHERE tgrelid='ops.setup_schedule_event'::regclass
              AND tgname IN ('trg_setup_schedule_event_actor_insert','trg_setup_schedule_event_actor_update')
              AND tgenabled <> 'D') <> 2 THEN RAISE EXCEPTION 'Event triggers missing'; END IF;
        END $$;""")

    def deploy(self):
        self.mark('entering maintenance')
        self.maintenance_started = True
        self.journal()
        self.frozen(self.controller('on'))
        self.mark('freeze PASS')
        baseline = self.capture()
        (self.root / 'frozen-invariants.jsonl').write_text(baseline + '\n')
        archive = '/home/msbadmin/backups/setup-205/msb-pre-' + ('pr318-070-' if self.m.get('profile') == 'field-070' else 'pr293-069-') + self.root.name + '.dump'
        snap = self.controller('snapshot', archive).get('snapshot', {})
        require(snap.get('validated') is True and snap.get('ok') is True and snap.get('bytes', 0) > 0
                and snap.get('path') == archive and snap.get('sha256'), 'Snapshot not validated')
        require(self.run(['sudo', 'sha256sum', archive]).split()[0] == snap['sha256'], 'Snapshot hash differs')
        (self.root / 'snapshot.json').write_text(json.dumps(snap, indent=2) + '\n')
        self.mark('snapshot PASS')
        self.frozen(self.controller('status'))
        require(self.capture() == baseline, 'Frozen baseline changed')
        if self.m.get('profile') == 'field-070':
            self.field_database_check(installed=False)
        self.mark('migration starting')
        self.migration_started = True
        self.journal()
        migration = self.git('show', self.m['target'] + ':' + self.m['migration'])
        self.sql(migration)
        self.committed = True
        self.mark('migration committed')
        self.validate()
        after = self.capture()
        (self.root / 'after-invariants.jsonl').write_text(after + '\n')
        require(after == baseline, 'Preserved business data changed')
        self.mark('database validation PASS')
        self.frozen(self.controller('status'))
        self.git('checkout', '--detach', self.m['target'], root=SETUP)
        require(self.git('rev-parse', 'HEAD', root=SETUP) == self.m['target'], 'Setup promotion differs')
        require(not self.git('status', '--porcelain', root=SETUP), 'Promoted worktree dirty')
        require(self.git('rev-parse', 'HEAD') == self.m['shared'], 'Shared checkout changed')
        backend = self.git('show', self.m['target'] + ':Setup/Application/production_backend.py')
        client = self.git('show', self.m['target'] + ':Setup/Application/setup_catalog_dirty_guard.js')
        require('PRODUCTION_VERSION = "' + self.m['version'] + '"' in backend and
                "CLIENT_BUILD = '" + self.m['version'] + "'" in client, 'Version declarations differ')
        if self.m.get('profile') == 'field-070':
            self.mark('promoting shared Field Wiring source while fenced')
            self.git('merge', '--ff-only', self.m['target'])
            require(self.git('rev-parse', 'HEAD') == self.m['target'], 'Shared promotion differs')
            require(not self.git('status', '--porcelain'), 'Shared checkout dirty after promotion')
            self.frozen(self.controller('status'))
            require(self.capture() == baseline, 'Business data changed before reopening')
        self.mark('returning to service')
        state = self.controller('off')
        require(state.get('state') == 'ONLINE' and not state.get('last_error') and
                state.get('live', {}).get('database_fenced') is False and
                state.get('gates', {}).get('online_proof', {}).get('ok') is True,
                'Return to service not proven')
        health = json.loads(self.run(['curl', '-fsS', '--max-time', '10',
                                     'http://192.168.5.9:8794/api/health']))
        require(health.get('status') == 'ok' and health.get('data_mode') == 'postgres'
                and health.get('version') == self.m['version'], 'Live version differs')
        self.run(['sudo', '-u', 'fieldwiring', '-H', 'env', 'PYTHONDONTWRITEBYTECODE=1',
                  'bash', '-c', 'cd ' + SETUP + ' && ' + PYTHON +
                  ' -m pytest -q -p no:cacheprovider Setup/Application'], timeout=300)
        if self.m.get('profile') == 'field-070':
            self.field_health(new=True)
            self.validate()
        self.mark('server deployment PASS; protected browser and documentation closeout pending')

    def field_database_check(self, installed=False):
        # Match exact reviewed bodies, security settings and command-only privileges.
        expected = 'd17d4163a5516de6fe08c8dcd40ce6a9' if installed else '2771409ad019ea5121290b235ce37db1'
        reconciliation = """IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
          WHERE n.nspname='ops' AND p.proname='record_setup_container_reconciliation'
            AND p.pronargs=23 AND md5(p.prosrc)='7ccf1b101ba307543333fd9ccc969218'
            AND p.prosecdef AND p.proconfig=ARRAY['search_path=pg_catalog, ops, ref']
            AND pg_get_userbyid(p.proowner)='msbadmin'
            AND has_function_privilege('fieldwiring_app',p.oid,'EXECUTE')
            AND NOT EXISTS(SELECT 1 FROM aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
              WHERE a.grantee=0 AND a.privilege_type='EXECUTE'))<>1
          THEN RAISE EXCEPTION '070 reconciliation definition/privilege mismatch'; END IF;""" if installed else """
          IF EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
            WHERE n.nspname='ops' AND p.proname='record_setup_container_reconciliation')
          THEN RAISE EXCEPTION 'Reconciliation function already present; inspect, do not retry'; END IF;"""
        self.sql("""DO $gate$ BEGIN
          IF (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
            WHERE n.nspname='ops' AND p.proname='record_setup_movement_event' AND p.pronargs=22
              AND md5(p.prosrc)='""" + expected + """' AND p.prosecdef
              AND p.proconfig=ARRAY['search_path=pg_catalog, ops, ref']
              AND pg_get_userbyid(p.proowner)='msbadmin'
              AND has_function_privilege('fieldwiring_app',p.oid,'EXECUTE')
              AND NOT EXISTS(SELECT 1 FROM aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
                WHERE a.grantee=0 AND a.privilege_type='EXECUTE'))<>1
          THEN RAISE EXCEPTION 'Movement function differs from approved baseline'; END IF;
          """ + reconciliation + """
          IF has_table_privilege('fieldwiring_app','ops.setup_display_state','INSERT,UPDATE,DELETE')
             OR has_table_privilege('fieldwiring_app','ops.setup_movement_event','INSERT,UPDATE,DELETE')
          THEN RAISE EXCEPTION 'Unexpected direct movement write permission'; END IF;
          END $gate$;""")

    def field_health(self, new=False):
        for port, version in [(8794,self.m['version'] if new else self.m['old_version']),
                              (8790,'V0.4.1-gis-entry' if new else 'V0.4.0'),(8792,'V0.1.0')]:
            health=json.loads(self.run(['curl','-fsS','--max-time','10',f'http://192.168.5.9:{port}/api/health']))
            require(health.get('status')=='ok' and health.get('data_mode')=='postgres'
                    and health.get('version')==version, f'Unexpected health on {port}')

    def field_preflight(self):
        self.mark('ONLINE field release preflight')
        m=self.m
        for root,sha in [(SETUP,m['old_setup']),(REPO,m['shared'])]:
            require(self.git('rev-parse','HEAD',root=root)==sha,'Live source changed')
            require(not self.git('status','--porcelain',root=root),'Live checkout dirty')
        self.field_health()
        state=self.controller('status'); live=state.get('live',{})
        require(state.get('state')=='ONLINE' and not state.get('last_error')
                and live.get('database_fenced') is False and live.get('mode')=='real','Healthy ONLINE required')
        require(all(live.get('services',{}).get(s)=='active' for s in
                ['msb-setup.service','fieldwiring.service','msb-procedures.service','msb-people.service','lor-preflight-api.service'])
                and live.get('services',{}).get('container:msb-directus')=='running','Services unhealthy')
        backups=live.get('backups',{})
        require(backups.get('nas_mounted') is True and backups.get('replication',{}).get('current_run_ok') is True,'Backup chain unhealthy')
        self.git('fetch','origin','+refs/heads/main:refs/remotes/origin/main')
        self.git('merge-base','--is-ancestor',m['target'],'origin/main')
        for old in (m['old_setup'],m['shared']):
            self.git('merge-base','--is-ancestor',old,m['target'])
        for revision in (m['target'],m['candidate']):
            require(self.git('rev-parse',revision+'^{tree}')==m['tree'],'Accepted tree differs')
        require(self.git('rev-parse',m['target']+':'+m['migration'])==m['migration_blob'],'Migration differs')
        self.field_database_check()
        self.worktree=tempfile.mkdtemp(prefix='msb-setup-reviewed-',dir='/tmp'); os.chmod(self.worktree,0o755)
        self.git('worktree','add','--detach',self.worktree,m['target'])
        ui_date=self.git('log','-1','--format=%cs',m['target'],'--',
                         ':(glob)Setup/Application/**/*.html',':(glob)Setup/Application/**/*.css',':(glob)Setup/Application/**/*.js')
        require(re.findall(r'Updated\s+(\d{4}-\d{2}-\d{2})',self.git('show',m['target']+':Setup/Application/production.html'))==[ui_date],'UI date differs')
        # Separate interpreters avoid cross-application imports named backend/conftest.
        for suite in ['Setup/Application','FieldWiring/Application','Procedures/Application']:
            self.run(['sudo','-u','fieldwiring','-H','env','PYTHONDONTWRITEBYTECODE=1','bash','-c',
                      'cd '+self.worktree+' && '+PYTHON+' -m pytest -q -p no:cacheprovider '+suite],timeout=300)
        self.mark('field preflight PASS')

    def cleanup(self):
        if self.worktree:
            self.git('worktree', 'remove', self.worktree)

def main():
    require(fcntl is not None, 'Run this deployment only on the Linux Production host')
    parser = argparse.ArgumentParser()
    parser.add_argument('manifest')
    parser.add_argument('--deploy', action='store_true')
    args = parser.parse_args()
    manifest = json.loads(Path(args.manifest).read_text())
    # Cooperative process lock: all governed deployment chats must use this runner.
    lock_path = Path.home() / '.msb-production-deploy.lock'
    with lock_path.open('a+') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print('STOP: another deployment owns the lock')
            return 1
        stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        deploy = Deploy(manifest, Path.home() / 'setup-deployment-reports' / (('PR318-070-' if manifest.get('profile') == 'field-070' else 'PR293-') + stamp))
        try:
            deploy.preflight()
            if args.deploy:
                deploy.deploy()
            deploy.cleanup()
            print('PASS: ' + deploy.stage + '; report: ' + str(deploy.root))
            return 0
        except BaseException as exc:
            deploy.journal(error=str(exc))
            deploy.log.write('STOP ' + repr(exc) + '\n')
            # Never retry, restore, or call controller OFF from error cleanup.
            try:
                deploy.cleanup()
            except Exception as cleanup_error:
                deploy.log.write('Cleanup issue: ' + repr(cleanup_error) + '\n')
            print('STOP: ' + deploy.stage + '; report: ' + str(deploy.root) +
                  '; do not rerun or change maintenance; inspect retained state')
            return 1

if __name__ == '__main__':
    sys.exit(main())

