#!/usr/bin/env python3
"""#495 release profile; the existing #37 orchestrator owns all maintenance gates."""
import hashlib
import json
import os
import re
import signal
import tempfile
import time

import setup_maintenance_deploy as orchestrator
from setup_maintenance_deploy import Deploy, require, SETUP, PYTHON
from setup_478_local_calendar_release import CalendarRelease

CANDIDATE = '0e44e580ff73d13712e4c698e2faa0422187fe83'
VERSION = 'V0.3.128-qc-blocker-links'
MIGRATION = 'Setup/Database/085_allow_qc_readiness_confirmation.sql'
OLD = '8164cae8ecb71311abaa8d41d4e6d4be3e223231'
MAIL_ROOT = '/opt/msb-setup-manager-pilot'
MAIL_FILES = ('manager_mail_pilot.py','manager_digest_template.txt','manager_digest_html.html')
MAIL_SERVICE = 'msb-setup-manager-season-2026.service'


class QcRelease(Deploy):
    # Reuse accepted ONLINE, frozen row fingerprint and isolated regression gates.
    online = CalendarRelease.online
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

    def capture(self):
        # Function-only migration: every business row, including audit stamps,
        # work history, findings and existing sign-offs must remain byte-equivalent.
        return self.sql(r"""BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
          SELECT format($q$SELECT json_build_object('table',%L,'digest',
            md5(coalesce(string_agg(h,'' ORDER BY h),''))) FROM
            (SELECT md5(to_jsonb(t)::text) h FROM %I.%I t) rows;$q$,
            n.nspname||'.'||c.relname,n.nspname,c.relname)
          FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE n.nspname IN ('ref','ops','stage') AND c.relkind IN ('r','p')
          ORDER BY n.nspname,c.relname
          \gexec
          ROLLBACK;""")

    def database_gate(self, installed):
        # Match the actual function body and security before and after085.
        checks=[]
        for path,sig,app_execute in [
            (MIGRATION if installed else 'Setup/Database/067_fix_setup_annual_hold_command.sql',
             'ops.set_setup_annual_hold(text,bigint,boolean,text)',True),
            ('Setup/Database/084_classify_unscheduled_qc_checks.sql',
             'ops.setup_qc_is_final_task(bigint)',False)]:
            source=self.git('show',CANDIDATE+':'+path)
            name=sig.split('(')[0]
            match=re.search(r'CREATE (?:OR REPLACE )?FUNCTION '+re.escape(name)+r'\(.*?AS (\$[a-z_]+\$)(.*?)\1;',source,re.S)
            require(match is not None,'Accepted function missing: '+name)
            digest=hashlib.md5(match.group(2).encode()).hexdigest()
            checks.append("""IF NOT EXISTS(SELECT 1 FROM pg_proc p
              WHERE p.oid=to_regprocedure('"""+sig+"""') AND md5(p.prosrc)='"""+digest+"""'
              AND p.prosecdef AND pg_get_userbyid(p.proowner)='msbadmin'
              AND EXISTS(SELECT 1 FROM unnest(p.proconfig) s WHERE s LIKE 'search_path=pg_catalog,%')
              AND NOT EXISTS(SELECT 1 FROM aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
                WHERE a.grantee=0 AND a.privilege_type='EXECUTE'))
              OR has_function_privilege('fieldwiring_app','"""+sig+"""','EXECUTE') IS DISTINCT FROM """+str(app_execute).lower()+"""
              THEN RAISE EXCEPTION 'QC function/security differs: """+name+"""'; END IF;""")
        self.sql('BEGIN READ ONLY; DO $gate$ BEGIN '+'\n'.join(checks)+' END $gate$; ROLLBACK;')

    def qc_ids(self):
        return self.sql("""BEGIN READ ONLY; SELECT coalesce(json_agg(setup_session_task_id
          ORDER BY setup_session_task_id),'[]'::json) FROM ops.setup_session_task
          WHERE ops.setup_qc_is_final_task(setup_session_task_id); ROLLBACK;""")

    def validate(self):
        self.database_gate(True)
        require(self.qc_ids()==self.m['frozen_qc_ids'],'QC coverage changed')

    def mail_hashes(self):
        return {name:self.run(['sudo','sha256sum',MAIL_ROOT+'/'+name]).split()[0] for name in MAIL_FILES}

    def mail_idle(self):
        # The controller fences database writers. Also refuse to replace files
        # while the bounded daily sender process is running.
        state=self.run(['systemctl','show',MAIL_SERVICE,'--property=ActiveState','--value'])
        require(state=='inactive','Manager sender is running or failed; inspect before deployment')
        timer=MAIL_SERVICE.replace('.service','.timer')
        active=self.run(['systemctl','show',timer,'--property=ActiveState','--value'])
        if active=='active':
            due=self.run(['systemctl','show',timer,'--property=NextElapseUSecRealtime','--value'])
            require(bool(due),'Manager timer next execution is unknown')
            epoch=int(self.run(['date','--date='+due,'+%s']))
            require(epoch-time.time()>3600,'Manager digest due within one hour; use another release window')

    def mail_preflight(self):
        # Preserve the installed PR492 report files; this release never installs
        # mail sources or starts a sender, and does not change timers/recipients.
        self.mail_idle()
        self.m['mail_before']=self.mail_hashes()
        self.journal()

    def mail_validate(self):
        require(self.mail_hashes()==self.m['mail_before'],'Installed manager report changed')

    def preflight(self):
        require(self.m == {'profile':'495-qc', 'release_tag':'PR495-085',
                'candidate':CANDIDATE, 'target':CANDIDATE, 'version':VERSION,
                'migration':MIGRATION}, 'Unreviewed release manifest')
        self.mark('ONLINE PR495 preflight')
        self.online()
        # Capture current source evidence, then pin it for this one execution.
        # Ancestry and the exact database delta below reject an unknown baseline.
        self.m['old_setup'] = self.git('rev-parse', 'HEAD', root=SETUP)
        require(self.m['old_setup']==OLD,'Unexpected live Setup baseline; do not deploy')
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
        require(re.findall(r'Updated\s+(\d{4}-\d{2}-\d{2})',footer) == ['2026-11-15'], 'Accepted UI date differs')
        self.m['tree'] = self.git('rev-parse',CANDIDATE+'^{tree}')
        self.m['migration_blob'] = self.git('rev-parse',CANDIDATE+':'+MIGRATION)
        self.journal()
        self.database_gate(installed=False)
        self.mail_preflight()
        self.worktree = tempfile.mkdtemp(prefix='msb-495-release-',dir='/tmp')
        os.chmod(self.worktree,0o755)
        self.git('worktree','add','--detach',self.worktree,CANDIDATE)
        self.regression(self.worktree)
        self.source_baseline()
        self.online()
        self.database_gate(installed=False)
        (self.root/'online-fingerprint-probe.jsonl').write_text(self.capture()+'\n')
        self.mark('PR495 preflight PASS; Production unchanged')

    def apply_migrations(self):
        self.source_baseline()
        self.database_gate(installed=False)
        self.m['frozen_qc_ids']=self.qc_ids()
        self.journal()
        self.sql(self.git('show',CANDIDATE+':'+MIGRATION))

    def before_reopen(self, baseline):
        self.frozen(self.controller('status'))
        self.source_baseline(promoted=True)
        self.database_gate(installed=True)
        self.mail_validate()
        require(self.capture() == baseline, 'Business rows changed before ONLINE')

    def live_validation(self):
        self.source_baseline(promoted=True)
        self.health(VERSION)
        self.database_gate(installed=True)
        self.regression(SETUP)
        self.mail_validate()

    def after_reopen(self):
        snapshot = json.loads((self.root/'snapshot.json').read_text())
        print('PR495 rollback snapshot: '+snapshot['path'],flush=True)
        print('PR495 snapshot SHA256: '+snapshot['sha256'],flush=True)
        print('PR495 live Setup: '+CANDIDATE+' / '+VERSION,flush=True)


if __name__ == '__main__':
    def interrupted(sig, frame):
        raise KeyboardInterrupt('PR495 deployment interrupted '+str(sig))
    signal.signal(signal.SIGTERM,interrupted)
    signal.signal(signal.SIGHUP,interrupted)
    orchestrator.Deploy = QcRelease
    raise SystemExit(orchestrator.main())
