#!/usr/bin/env python3
"""#485 release profile; the existing #37 orchestrator owns all maintenance gates."""
import hashlib
import json
import os
import re
import signal
import tempfile

import setup_maintenance_deploy as orchestrator
from setup_maintenance_deploy import Deploy, require, SETUP, PYTHON
from setup_478_local_calendar_release import CalendarRelease

CANDIDATE = '3f281e49bf44a5d64a3be5e43f71319f59c8c27f'
VERSION = 'V0.3.121-qc-compact'
MIGRATION = 'Setup/Database/081_add_unscheduled_setup_qc_findings.sql'
SIGNATURES = (
    'ops.setup_qc_command(text,text,bigint,bigint,text,text,text,text,integer)',
    'ops.setup_qc_final_gate(bigint)',
    'ops.setup_qc_ready_for_production(text,bigint,text,integer,text)',
    'ops.setup_qc_snapshot(text,integer)',
    'ops.setup_qc_intake_candidates(text,integer)',
)
TABLES = ('setup_qc_signoff','setup_qc_auditor','setup_qc_finding',
          'setup_qc_event','setup_qc_intake_link')



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
        # New QC tables start empty. Preserve ALL existing ref/ops/stage rows,
        # including original Intake, annual work, assignments and Work Orders.
        return self.sql(r"""BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
          SELECT format($q$SELECT json_build_object('table',%L,'digest',
            md5(coalesce(string_agg(h,'' ORDER BY h),''))) FROM
            (SELECT md5(to_jsonb(t)::text) h FROM %I.%I t) rows;$q$,
            n.nspname||'.'||c.relname,n.nspname,c.relname)
          FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE n.nspname IN ('ref','ops','stage') AND c.relkind IN ('r','p')
            AND NOT (n.nspname='ops' AND c.relname IN
              ('setup_qc_signoff','setup_qc_auditor','setup_qc_finding','setup_qc_event','setup_qc_intake_link'))
          ORDER BY n.nspname,c.relname
          \gexec
          ROLLBACK;""")

    def database_gate(self, installed):
        # Production validation is catalog/SELECT only, never clone test writes.
        checks = []
        if not installed:
            for name in TABLES:
                checks.append("IF to_regclass('ops."+name+"') IS NOT NULL THEN RAISE EXCEPTION '081 already present'; END IF;")
            for sig in SIGNATURES:
                checks.append("IF to_regprocedure('"+sig+"') IS NOT NULL THEN RAISE EXCEPTION '081 function already present'; END IF;")
        else:
            source = self.git('show', CANDIDATE + ':' + MIGRATION)
            for sig in SIGNATURES:
                name=sig.split('(')[0]
                match=re.search(r'CREATE FUNCTION '+re.escape(name)+r'\(.*?AS (\$[a-z_]+\$)(.*?)\1;',source,re.S)
                require(match is not None, 'Accepted function body missing: '+name)
                digest=hashlib.md5(match.group(2).encode()).hexdigest()
                exposed = 'false' if name.endswith('setup_qc_final_gate') else 'true'
                checks.append("""IF NOT EXISTS (SELECT 1 FROM pg_proc p
                  WHERE p.oid=to_regprocedure('"""+sig+"""') AND md5(p.prosrc)='"""+digest+"""'
                  AND p.prosecdef AND pg_get_userbyid(p.proowner)='msbadmin'
                  AND EXISTS (SELECT 1 FROM unnest(p.proconfig) setting WHERE setting LIKE 'search_path=pg_catalog,%')
                  AND NOT EXISTS (SELECT 1 FROM aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
                    WHERE a.grantee=0 AND a.privilege_type='EXECUTE'))
                  OR has_function_privilege('fieldwiring_app','"""+sig+"""','EXECUTE') IS DISTINCT FROM """+exposed+"""
                  THEN RAISE EXCEPTION '081 function definition/privilege differs: """+name+"""'; END IF;""")
            for name in TABLES:
                checks.append("IF has_table_privilege('fieldwiring_app','ops."+name+"','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') THEN RAISE EXCEPTION 'QC direct table access'; END IF;")
            for name in ('setup_qc_finding_qc_finding_id_seq','setup_qc_event_qc_event_id_seq'):
                checks.append("IF has_sequence_privilege('fieldwiring_app','ops."+name+"','USAGE,SELECT,UPDATE') THEN RAISE EXCEPTION 'QC direct sequence access'; END IF;")
        self.sql('BEGIN READ ONLY; DO $gate$ BEGIN '+ '\n'.join(checks)+' END $gate$; ROLLBACK;')

    def validate(self):
        self.database_gate(installed=True)
        # Only before reopening: production must not contain disposable QC records.
        checks=' '.join("IF EXISTS (SELECT 1 FROM ops."+name+") THEN RAISE EXCEPTION 'Unexpected initial QC records'; END IF;" for name in TABLES)
        self.sql('BEGIN READ ONLY; DO $gate$ BEGIN '+checks+' END $gate$; ROLLBACK;')

    def preflight(self):
        require(self.m == {'profile':'485-qc', 'release_tag':'PR485-081',
                'candidate':CANDIDATE, 'target':CANDIDATE, 'version':VERSION,
                'migration':MIGRATION}, 'Unreviewed release manifest')
        self.mark('ONLINE PR485 preflight')
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
        self.worktree = tempfile.mkdtemp(prefix='msb-485-release-',dir='/tmp')
        os.chmod(self.worktree,0o755)
        self.git('worktree','add','--detach',self.worktree,CANDIDATE)
        self.regression(self.worktree)
        self.source_baseline()
        self.online()
        self.database_gate(installed=False)
        (self.root/'online-fingerprint-probe.jsonl').write_text(self.capture()+'\n')
        self.mark('PR485 preflight PASS; Production unchanged')

    def apply_migrations(self):
        self.source_baseline()
        self.database_gate(installed=False)
        self.sql(self.git('show',CANDIDATE+':'+MIGRATION))

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
        print('PR485 rollback snapshot: '+snapshot['path'],flush=True)
        print('PR485 snapshot SHA256: '+snapshot['sha256'],flush=True)
        print('PR485 live Setup: '+CANDIDATE+' / '+VERSION,flush=True)


if __name__ == '__main__':
    def interrupted(sig, frame):
        raise KeyboardInterrupt('PR485 deployment interrupted '+str(sig))
    signal.signal(signal.SIGTERM,interrupted)
    signal.signal(signal.SIGHUP,interrupted)
    orchestrator.Deploy = QcRelease
    raise SystemExit(orchestrator.main())
