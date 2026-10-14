#!/usr/bin/env python3
"""PR389 migration073 profile of the existing controller deployment orchestrator."""
import hashlib
import json
import os
import re
import signal
import tempfile
from pathlib import Path
import setup_maintenance_deploy as orchestrator
from setup_maintenance_deploy import Deploy, require, REPO, SETUP, PYTHON

TARGET = 'efb7f26fd0d4e1275daa509e2ade62bc291b1d8f'
TREE = 'e0161b97296df534e7a009062ef5a9c85e5961a2'
OLD_SETUP = '2bc88ae627420c2138268e39a26b4942a3248580'
VERSION = 'V0.3.64-required-containers'
MIGRATION = 'Setup/Database/073_add_setup_required_container_command.sql'
SIGNATURE = 'ref.set_setup_task_required_container(text,bigint,integer,boolean,text)'


class RequiredContainerDeploy(Deploy):
    def database_check(self, installed):
        if not installed:
            self.sql("DO $$ BEGIN IF to_regprocedure('" + SIGNATURE + "') IS NOT NULL THEN "
                     "RAISE EXCEPTION '073 command already exists; inspect, do not replay'; END IF; END $$;")
            return
        source = self.git('show', TARGET + ':' + MIGRATION)
        body = re.search(r'AS \$function\$(.*?)\$function\$;', source, re.S).group(1)
        digest = hashlib.md5(body.encode()).hexdigest()
        self.sql("""BEGIN READ ONLY; DO $gate$ BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid=to_regprocedure('""" + SIGNATURE + """')
            AND md5(p.prosrc)='""" + digest + """' AND p.prosecdef
            AND p.proconfig=ARRAY['search_path=pg_catalog, ref']
            AND pg_get_userbyid(p.proowner)='msbadmin'
            AND has_function_privilege('fieldwiring_app',p.oid,'EXECUTE')
            AND NOT EXISTS (SELECT 1 FROM aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
                            WHERE a.grantee=0 AND a.privilege_type='EXECUTE'))
          THEN RAISE EXCEPTION '073 function body/security/EXECUTE mismatch'; END IF;
          IF has_table_privilege('fieldwiring_app','ref.setup_task_container_support','INSERT,UPDATE,DELETE')
          THEN RAISE EXCEPTION 'Unexpected direct task Container write permission'; END IF;
          END $gate$; ROLLBACK;""")

    def online(self):
        state = self.controller('status'); live = state.get('live', {})
        require(state.get('state') == 'ONLINE' and not state.get('last_error')
                and live.get('database_fenced') is False and live.get('mode') == 'real',
                'Healthy real ONLINE required')
        require(all(live.get('services', {}).get(s) == 'active' for s in
                    ['msb-setup.service', 'fieldwiring.service', 'msb-procedures.service',
                     'msb-people.service', 'lor-preflight-api.service'])
                and live.get('services', {}).get('container:msb-directus') == 'running',
                'Governed services unhealthy')
        require(live.get('backups', {}).get('nas_mounted') is True
                and live.get('backups', {}).get('replication', {}).get('current_run_ok') is True,
                'Backup chain not current')

    def baseline(self):
        require(self.git('rev-parse', 'HEAD', root=SETUP) == OLD_SETUP
                and not self.git('status', '--porcelain', root=SETUP)
                and not self.git('branch', '--show-current', root=SETUP), 'Setup baseline drift')
        require(self.git('rev-parse', 'HEAD') == self.m['shared']
                and not self.git('status', '--porcelain'), 'Shared source changed')
        health = json.loads(self.run(['curl', '-fsS', '--max-time', '10',
                                     'http://192.168.5.9:8794/api/health']))
        require(health.get('status') == 'ok' and health.get('data_mode') == 'postgres'
                and health.get('version') == 'V0.3.62-field-networks', 'Unexpected baseline health')

    def preflight(self):
        # Only this reviewed manifest/profile may use this extension.
        require(self.m.get('profile') == 'required-073' and self.m.get('release_tag') == 'PR389-073'
                and self.m.get('target') == TARGET and self.m.get('candidate') == TARGET
                and self.m.get('tree') == TREE and self.m.get('migration') == MIGRATION
                and self.m.get('old_setup') == OLD_SETUP and self.m.get('version') == VERSION,
                'Unreviewed deployment manifest')
        self.mark('ONLINE preflight')
        self.online()
        # Read current shared identity instead of assuming pre-People-release history.
        # It stays unchanged; ancestry below verifies it belongs to the accepted source.
        self.m['shared'] = self.git('rev-parse', 'HEAD')
        self.journal()
        self.baseline()
        require(not self.run(['ss', '-ltnH', 'sport = :8898']), 'Preview still active; finish CLEAN EXIT')
        self.git('fetch', 'origin', '+refs/heads/main:refs/remotes/origin/main')
        self.git('merge-base', '--is-ancestor', TARGET, 'origin/main')
        for old in (OLD_SETUP, self.m['shared']):
            self.git('merge-base', '--is-ancestor', old, TARGET)
        require(self.git('rev-parse', TARGET + '^{tree}') == TREE, 'Accepted tree differs')
        require(self.git('rev-parse', TARGET + ':' + MIGRATION) == self.m['migration_blob'], 'Migration blob differs')
        require(self.git('rev-parse', TARGET + ':Setup/Acceptance/setup_required_container_validation.sql')
                == self.m['validation_blob'], 'Accepted clone validation differs')
        helper = Path(__file__).with_name('setup_maintenance_deploy.py').read_bytes().replace(b'\r', b'')
        require(hashlib.sha256(helper).hexdigest() == self.m['helper_sha256'], 'Transported orchestrator differs')
        self.database_check(installed=False)
        ui_date = self.git('log', '-1', '--format=%cs', TARGET, '--',
                           ':(glob)Setup/Application/**/*.html', ':(glob)Setup/Application/**/*.css',
                           ':(glob)Setup/Application/**/*.js')
        footer = self.git('show', TARGET + ':Setup/Application/production.html')
        require(re.findall(r'Updated\s+(\d{4}-\d{2}-\d{2})', footer) == [ui_date], 'Stale UI date')
        self.worktree = tempfile.mkdtemp(prefix='msb-required-container-', dir='/tmp')
        os.chmod(self.worktree, 0o755)
        self.git('worktree', 'add', '--detach', self.worktree, TARGET)
        self.run(['sudo', '-u', 'fieldwiring', '-H', 'env', 'PYTHONDONTWRITEBYTECODE=1',
                  'bash', '-c', 'cd ' + self.worktree + ' && ' + PYTHON +
                  ' -m pytest -q -p no:cacheprovider Setup/Application'], timeout=300)
        # Prove fingerprint SQL while ONLINE; the frozen baseline is captured later.
        (self.root / 'online-probe.jsonl').write_text(self.capture() + '\n')
        self.baseline(); self.online(); self.database_check(installed=False)
        self.mark('preflight PASS')

    def capture(self):
        # Function-only migration: preserve every ref/ops business/audit row.
        return self.sql(r"""BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
          SELECT format('SELECT json_build_object(''table'',%L,''digest'',md5(coalesce(string_agg(to_jsonb(t)::text,'''' ORDER BY to_jsonb(t)::text),''''))) FROM %I.%I t;',
            n.nspname||'.'||c.relname,n.nspname,c.relname)
          FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE n.nspname IN ('ref','ops') AND c.relkind IN ('r','p')
          ORDER BY n.nspname,c.relname
          \gexec
          ROLLBACK;""")

    def deploy(self):
        super().deploy()
        # Real protected-route negative path, with command guard present but no
        # Cloudflare identity. Authorization must fail before any database write.
        status = self.run(['curl', '-sS', '--max-time', '10', '-o', '/dev/null',
                           '-w', '%{http_code}', '-X', 'PATCH',
                           '-H', 'X-MSB-Setup-Command: 1', '-H', 'Content-Type: application/json',
                           '-d', '{"assigned":false}',
                           'http://192.168.5.9:8794/api/setup/tasks/1/required-containers/106'])
        require(status == '401', 'Live unauthenticated assignment route did not reject identity')
        self.mark('server deployment PASS; protected C106 assignment and documentation closeout pending')

    def validate(self):
        self.database_check(installed=True)
        # Read-only contract validation only. Browser mutation tests already passed
        # in the same disposable preview; never create a Production test assignment.


if __name__ == '__main__':
    def interrupted(signum, frame):
        raise KeyboardInterrupt('Deployment signal ' + str(signum))
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGHUP, interrupted)
    orchestrator.Deploy = RequiredContainerDeploy
    raise SystemExit(orchestrator.main())
