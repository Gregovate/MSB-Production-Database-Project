#!/usr/bin/env python3
"""#482 release profile; the existing #37 orchestrator owns all maintenance gates."""
import hashlib
import json
import os
import re
import signal
import tempfile

import setup_maintenance_deploy as orchestrator
from setup_maintenance_deploy import Deploy, require, SETUP, PYTHON
from setup_478_local_calendar_release import CalendarRelease

CANDIDATE = '37a02e2d9460d115e1d7255833b264a6bb5d8d80'
VERSION = 'V0.3.111-explicit-no-work'
MIGRATION = 'Setup/Database/080_prevent_unreported_setup_assignment_duplicates.sql'
SIGNATURE = 'ops.reject_unresolved_setup_assignment_insert()'


class SchedulingRelease(Deploy):
    # Reuse accepted ONLINE, frozen row fingerprint and isolated regression gates.
    online = CalendarRelease.online
    capture = CalendarRelease.capture
    regression = CalendarRelease.regression
    health = CalendarRelease.health
    source_version = CalendarRelease.source_version

    def source_baseline(self, promoted=False):
        expected = CANDIDATE if promoted else self.m['old_setup']
        require(self.git('rev-parse', 'HEAD', root=SETUP) == expected,
                'Setup baseline drift; inspect retained journal')
        require(not self.git('status', '--porcelain', root=SETUP), 'Setup checkout dirty')
        require(self.git('rev-parse', 'HEAD') == self.m['shared']
                and not self.git('status', '--porcelain'), 'Shared checkout drift')

    def database_gate(self, installed):
        if not installed:
            self.sql("DO $$ BEGIN IF to_regprocedure('" + SIGNATURE + "') IS NOT NULL "
                     "OR EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid='ops.setup_work_day_task'::regclass "
                     "AND tgname='reject_unresolved_setup_assignment_insert') THEN "
                     "RAISE EXCEPTION '080 already present; inspect, do not replay'; END IF; END $$;")
            return
        source = self.git('show', CANDIDATE + ':' + MIGRATION)
        body = re.search(r'AS \$function\$(.*?)\$function\$;', source, re.S).group(1)
        digest = hashlib.md5(body.encode()).hexdigest()
        self.sql("""BEGIN READ ONLY; DO $gate$ BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.oid=to_regprocedure('""" + SIGNATURE + """')
            AND md5(p.prosrc)='""" + digest + """' AND p.prosecdef
            AND p.proconfig=ARRAY['search_path=pg_catalog, ops, ref']
            AND pg_get_userbyid(p.proowner)='msbadmin'
            AND NOT EXISTS (SELECT 1 FROM aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
              WHERE a.grantee=0 AND a.privilege_type='EXECUTE'))
          THEN RAISE EXCEPTION '080 function body/security differs'; END IF;
          IF NOT EXISTS (SELECT 1 FROM pg_trigger t
            WHERE t.tgrelid='ops.setup_work_day_task'::regclass
              AND t.tgname='reject_unresolved_setup_assignment_insert'
              AND t.tgfoid=to_regprocedure('""" + SIGNATURE + """')
              AND t.tgenabled='O' AND t.tgtype=7)
          THEN RAISE EXCEPTION '080 BEFORE INSERT row trigger differs'; END IF;
          END $gate$; ROLLBACK;""")

    def preflight(self):
        require(self.m == {'profile':'482-unreported-guard', 'release_tag':'PR482-080',
                'candidate':CANDIDATE, 'target':CANDIDATE, 'version':VERSION,
                'migration':MIGRATION}, 'Unreviewed release manifest')
        self.mark('ONLINE PR482 preflight')
        self.online()
        # Capture current source evidence, then pin it for this one execution.
        # Ancestry and the exact database delta below reject an unknown baseline.
        self.m['old_setup'] = self.git('rev-parse', 'HEAD', root=SETUP)
        self.m['shared'] = self.git('rev-parse', 'HEAD')
        self.m['old_version'] = self.source_version(self.m['old_setup'])
        self.journal()
        self.source_baseline()
        self.health(self.m['old_version'])
        require(not self.run(['ss','-ltnH','sport = :8898']), 'Preview still active; finish CLEAN EXIT')
        self.git('fetch','origin','+refs/heads/main:refs/remotes/origin/main')
        self.git('merge-base','--is-ancestor',CANDIDATE,'origin/main')
        self.git('merge-base','--is-ancestor',self.m['old_setup'],CANDIDATE)
        require(self.git('diff','--name-only',self.m['old_setup'],CANDIDATE,'--','Setup/Database') == MIGRATION,
                'Unexpected database delta; inspect baseline, do not deploy')
        require(self.source_version(CANDIDATE) == VERSION, 'Accepted server version differs')
        require("CLIENT_BUILD = '" + VERSION + "'" in self.git('show',CANDIDATE+':Setup/Application/setup_catalog_dirty_guard.js'),
                'Accepted client version differs')
        footer = self.git('show',CANDIDATE+':Setup/Application/production.html')
        require(re.findall(r'Updated\s+(\d{4}-\d{2}-\d{2})',footer) == ['2026-11-11'], 'Accepted UI date differs')
        self.m['tree'] = self.git('rev-parse',CANDIDATE+'^{tree}')
        self.m['migration_blob'] = self.git('rev-parse',CANDIDATE+':'+MIGRATION)
        self.journal()
        self.database_gate(installed=False)
        self.worktree = tempfile.mkdtemp(prefix='msb-482-release-',dir='/tmp')
        os.chmod(self.worktree,0o755)
        self.git('worktree','add','--detach',self.worktree,CANDIDATE)
        self.regression(self.worktree)
        self.source_baseline()
        self.online()
        self.database_gate(installed=False)
        (self.root/'online-fingerprint-probe.jsonl').write_text(self.capture()+'\n')
        self.mark('PR482 preflight PASS; Production unchanged')

    def apply_migrations(self):
        self.source_baseline()
        self.database_gate(installed=False)
        self.sql(self.git('show',CANDIDATE+':'+MIGRATION))

    def validate(self):
        # No Production test assignments or rollback-only operational writes.
        self.database_gate(installed=True)

    def before_reopen(self, baseline):
        self.frozen(self.controller('status'))
        self.source_baseline(promoted=True)
        self.database_gate(installed=True)
        require(self.capture() == baseline, 'Business rows changed before ONLINE')

    def live_validation(self):
        self.source_baseline(promoted=True)
        self.health(VERSION)
        self.database_gate(installed=True)
        self.regression(SETUP)

    def after_reopen(self):
        snapshot = json.loads((self.root/'snapshot.json').read_text())
        print('PR482 rollback snapshot: '+snapshot['path'],flush=True)
        print('PR482 snapshot SHA256: '+snapshot['sha256'],flush=True)
        print('PR482 live Setup: '+CANDIDATE+' / '+VERSION,flush=True)


if __name__ == '__main__':
    def interrupted(sig, frame):
        raise KeyboardInterrupt('PR482 deployment interrupted '+str(sig))
    signal.signal(signal.SIGTERM,interrupted)
    signal.signal(signal.SIGHUP,interrupted)
    orchestrator.Deploy = SchedulingRelease
    raise SystemExit(orchestrator.main())
