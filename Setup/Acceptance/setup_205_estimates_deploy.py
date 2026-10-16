#!/usr/bin/env python3
"""#205 075/076 release profile; the existing orchestrator owns the window."""
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import tempfile

import setup_maintenance_deploy as orchestrator
from setup_maintenance_deploy import Deploy, require, SETUP, PYTHON
from setup_required_container_deploy import RequiredContainerDeploy

TARGET = '7740498e6602f36c8cdfd384791bbafaab71ee9e'
CANDIDATE = '723a733ffbea516519c6dd7a20ec75faca10a9c4'
OLD = '86341d49dc8ccf290575f9d2b418c235094a1377'
VERSION = 'V0.3.84-direct-crew-cells'
MIGRATIONS = ('Setup/Database/075_allow_setup_planned_crew_count_corrections.sql',
              'Setup/Database/076_capture_2026_reusable_task_estimates.sql')
FOUNDATION = 'Setup/Database/050_add_setup_scheduling_board_foundation.sql'
CREW = 'ops.update_setup_work_day_crew(text,bigint,integer,integer,integer)'
PLANNING = 'ops.update_setup_scheduling_task_planning_info(text,bigint,integer,integer,integer,text,text,text,text)'
SYNC = 'ref.sync_setup_task_estimates_to_2026()'
TRIGGER = 'trg_setup_task_sync_2026_planning'


def function_body(source, signature):
    """Extract only the named reviewed SQL function body, preserving its bytes."""
    name = signature.split('(')[0]
    match = re.search(r'CREATE OR REPLACE FUNCTION\s+' + re.escape(name) +
                      r'\s*\(.*?\bAS\s+(\$\w+\$)(.*?)\1;', source, re.S)
    require(match is not None, 'Reviewed function not found: ' + signature)
    return match.group(2)


class EstimatesDeploy(RequiredContainerDeploy):
    target = TARGET
    old_setup = OLD
    old_version = 'V0.3.65-scheduled-search-focus'
    version = VERSION

    def preflight(self):
        expected = json.loads(Path(__file__).with_name('setup_205_estimates_release.json').read_text())
        require(self.m == expected and self.m['target'] == TARGET
                and self.m['candidate'] == CANDIDATE and self.m['old_setup'] == OLD
                and self.m['version'] == VERSION and self.m['migrations'] == list(MIGRATIONS)
                and self.m['profile'] == '205-estimates-075-076', 'Unreviewed manifest')
        for name, digest in self.m['helpers'].items():
            require(hashlib.sha256(Path(__file__).with_name(name).read_bytes().replace(b'\r', b'')).hexdigest()
                    == digest, 'Transported helper differs: ' + name)
        self.mark('ONLINE #205 preflight')
        self.online()
        self.m['shared'] = self.git('rev-parse', 'HEAD')
        self.journal()
        self.baseline()
        require(self.run(['systemctl', 'is-active', 'msb-maintenance-admin.service']) == 'active',
                'Maintenance admin inactive')
        require(not self.run(['ss', '-ltnH', 'sport = :8898']), 'Preview not CLEAN EXIT')
        self.git('fetch', 'origin', '+refs/heads/main:refs/remotes/origin/main')
        self.git('merge-base', '--is-ancestor', TARGET, 'origin/main')
        self.git('merge-base', '--is-ancestor', CANDIDATE, TARGET)
        self.git('merge-base', '--is-ancestor', OLD, TARGET)
        # Shared may contain newer accepted Controller/People work. Never move it.
        self.git('merge-base', '--is-ancestor', self.m['shared'], 'origin/main')
        require(self.git('rev-parse', TARGET + '^{tree}') == self.m['tree'], 'Target tree differs')
        for path in ('Setup/Application', 'Setup/Database'):
            require(self.git('rev-parse', TARGET + ':' + path) ==
                    self.git('rev-parse', CANDIDATE + ':' + path), 'Accepted Setup source differs')
        for path, blob in self.m['migration_blobs'].items():
            require(self.git('rev-parse', TARGET + ':' + path) == blob, 'Migration differs')
        for path, marker in [('production_backend.py', 'PRODUCTION_VERSION = "' + VERSION + '"'),
                             ('setup_catalog_dirty_guard.js', "CLIENT_BUILD = '" + VERSION + "'")]:
            require(marker in self.git('show', TARGET + ':Setup/Application/' + path), 'Version differs')
        # Same local-time date rule, using required sudo Git administration.
        stamp = self.git('log', '-1', '--format=%cI', TARGET, '--',
                         ':(glob)Setup/Application/**/*.html',
                         ':(glob)Setup/Application/**/*.css', ':(glob)Setup/Application/**/*.js')
        date = datetime.fromisoformat(stamp).astimezone(ZoneInfo('America/Chicago')).date().isoformat()
        footer = self.git('show', TARGET + ':Setup/Application/production.html')
        require(re.findall(r'Updated\s+(\d{4}-\d{2}-\d{2})', footer) == [date], 'UI date differs')
        self.database_check(False)
        self.worktree = tempfile.mkdtemp(prefix='msb-205-estimates-', dir='/tmp')
        os.chmod(self.worktree, 0o755)
        self.git('worktree', 'add', '--detach', self.worktree, TARGET)
        self.regression(self.worktree)
        (self.root / 'online-probe.jsonl').write_text(self.capture() + '\n')
        self.baseline(); self.online(); self.database_check(False)
        self.mark('preflight PASS')

    def regression(self, root):
        self.run(['sudo', '-u', 'fieldwiring', '-H', 'env', 'PYTHONDONTWRITEBYTECODE=1',
                  'bash', '-c', 'cd ' + root + ' && ' + PYTHON +
                  ' -m pytest -q -p no:cacheprovider Setup/Application'], timeout=300)

    def database_check(self, installed):
        """Exact bodies and security, with no Production command invocation/test writes."""
        checks = []
        for sig, path, search, executable in [
            (CREW, MIGRATIONS[0], 'pg_catalog, ops, ref', True),
            (PLANNING, MIGRATIONS[1], 'pg_catalog, ops, ref', True),
            (SYNC, MIGRATIONS[1], 'pg_catalog, ref, ops', False)]:
            if not installed and sig == SYNC:
                checks.append("IF to_regprocedure('" + sig + "') IS NOT NULL THEN RAISE EXCEPTION '076 already installed; do not replay'; END IF;")
                continue
            source = self.git('show', (TARGET if installed else OLD) + ':' + (path if installed else FOUNDATION))
            digest = hashlib.md5(function_body(source, sig).encode()).hexdigest()
            checks.append("""IF NOT EXISTS (SELECT 1 FROM pg_proc p
                WHERE p.oid=to_regprocedure('%s') AND md5(p.prosrc)='%s'
                AND p.prosecdef AND p.proconfig=ARRAY['search_path=%s']
                AND pg_get_userbyid(p.proowner)='msbadmin'
                AND has_function_privilege('fieldwiring_app',p.oid,'EXECUTE')=%s
                AND NOT EXISTS (SELECT 1 FROM aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
                                WHERE a.grantee=0 AND a.privilege_type='EXECUTE'))
                THEN RAISE EXCEPTION 'Function body/security differs: %s'; END IF;""" %
                (sig, digest, search, 'true' if executable else 'false', sig))
        if installed:
            # PostgreSQL expands row IS DISTINCT FROM to per-column OR terms.
            # Compare all tokens except deparser grouping parentheses/whitespace.
            definition = ('CREATE TRIGGER ' + TRIGGER + ' AFTER UPDATE OF normal_crew_min, normal_crew_max, '
                          'expected_duration_minutes, effort_level ON ref.setup_task FOR EACH ROW WHEN '
                          'old.normal_crew_min IS DISTINCT FROM new.normal_crew_min OR '
                          'old.normal_crew_max IS DISTINCT FROM new.normal_crew_max OR '
                          'old.expected_duration_minutes IS DISTINCT FROM new.expected_duration_minutes OR '
                          'old.effort_level IS DISTINCT FROM new.effort_level '
                          'EXECUTE FUNCTION ref.sync_setup_task_estimates_to_2026()')
            normalized = re.sub(r'[\s()"]', '', definition)
            checks.append("""IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='ref.setup_task'::regclass
                AND tgname='%s' AND tgenabled='O' AND NOT tgisinternal AND tgtype=17
                AND tgfoid=to_regprocedure('%s')
                AND regexp_replace(pg_get_triggerdef(oid), '[[:space:]()"]', '', 'g')='%s')
                THEN RAISE EXCEPTION '076 trigger definition differs'; END IF;""" % (TRIGGER, SYNC, normalized))
        else:
            checks.append("IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='ref.setup_task'::regclass AND tgname='" + TRIGGER + "') THEN RAISE EXCEPTION '076 trigger already present'; END IF;")
        checks.append("""IF EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
            WHERE n.nspname IN ('ref','ops') AND c.relkind IN ('r','p')
              AND has_table_privilege('fieldwiring_app',c.oid,'INSERT,UPDATE,DELETE,TRUNCATE'))
            THEN RAISE EXCEPTION 'Unexpected direct application table writes'; END IF;""")
        self.sql('BEGIN READ ONLY; DO $gate$ BEGIN\n' + '\n'.join(checks) + '\nEND $gate$; ROLLBACK;')

    def capture(self):
        rows = super().capture()
        # Preserve all existing relation/column/function ACLs, including unrelated
        # ref/ops security. The new trigger function is separately checked above.
        acl = self.sql("""BEGIN READ ONLY;
          SELECT json_build_object('kind','relation','oid',c.oid,'acl',c.relacl)
          FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE n.nspname IN ('ref','ops') ORDER BY c.oid;
          SELECT json_build_object('kind','column','oid',a.attrelid,'att',a.attnum,'acl',a.attacl)
          FROM pg_attribute a JOIN pg_class c ON c.oid=a.attrelid
          JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE n.nspname IN ('ref','ops') AND a.attnum>0 ORDER BY a.attrelid,a.attnum;
          SELECT json_build_object('kind','function','oid',p.oid,'owner',p.proowner,'acl',p.proacl)
          FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
          WHERE n.nspname IN ('ref','ops') AND p.oid IS DISTINCT FROM to_regprocedure('ref.sync_setup_task_estimates_to_2026()')
          ORDER BY p.oid; ROLLBACK;""")
        return rows + '\n' + acl

    def apply_migrations(self):
        # Called only by the orchestrator after current freeze and validated dump.
        self.database_check(False)
        for path in MIGRATIONS:
            self.mark('applying ' + path)
            self.sql(self.git('show', TARGET + ':' + path))
            self.m.setdefault('applied_migrations', []).append(path)
            self.journal()

    def validate(self):
        self.database_check(True)
        expected = OLD if self.stage == 'migration committed' else TARGET
        require(self.git('rev-parse', 'HEAD', root=SETUP) == expected
                and not self.git('status', '--porcelain', root=SETUP), 'Setup source drift at validation')
        require(self.git('rev-parse', 'HEAD') == self.m['shared']
                and not self.git('status', '--porcelain'), 'Shared source drift at validation')

    def before_reopen(self, baseline):
        self.frozen(self.controller('status'))
        require(self.git('rev-parse', 'HEAD', root=SETUP) == TARGET
                and not self.git('status', '--porcelain', root=SETUP), 'Promoted Setup drift')
        require(self.git('rev-parse', 'HEAD') == self.m['shared']
                and not self.git('status', '--porcelain'), 'Shared source drift')
        self.regression(SETUP)
        self.validate()
        after = self.capture()
        (self.root / 'before-online-invariants.jsonl').write_text(after + '\n')
        require(after == baseline, 'Frozen rows or ACLs changed before ONLINE')
        self.frozen(self.controller('status'))

    def deploy(self):
        # Close the ONLINE preparation interval with fresh baseline/controller gates.
        self.baseline(); self.online(); self.database_check(False)
        Deploy.deploy(self)

    def after_reopen(self):
        self.online(); self.validate()
        require(self.git('rev-parse', 'HEAD', root=SETUP) == TARGET
                and not self.git('status', '--porcelain', root=SETUP), 'Final Setup drift')
        require(self.git('rev-parse', 'HEAD') == self.m['shared'], 'Final shared drift')
        for route in ('crews/1', 'season-tasks/1/planning-info'):
            status = self.run(['curl', '-sS', '--max-time', '10', '-o', '/dev/null',
                               '-w', '%{http_code}', '-X', 'PATCH',
                               '-H', 'X-MSB-Setup-Command: 1', '-H', 'Content-Type: application/json',
                               '-d', '{}', 'http://192.168.5.9:8794/api/setup/scheduling-board/' + route])
            require(status == '401', 'Unauthenticated command did not reject identity')
        self.mark('#205 V0.3.84 server deployment PASS; retain report and snapshot')


if __name__ == '__main__':
    def interrupted(signum, frame):
        raise KeyboardInterrupt('Deployment signal ' + str(signum))
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGHUP, interrupted)
    orchestrator.Deploy = EstimatesDeploy
    raise SystemExit(orchestrator.main())
