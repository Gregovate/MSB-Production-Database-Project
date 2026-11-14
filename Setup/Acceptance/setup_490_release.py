#!/usr/bin/env python3
"""#490 release profile; the existing #37 orchestrator owns all maintenance gates."""
import hashlib
import json
import os
import re
import signal
import tempfile

import setup_maintenance_deploy as orchestrator
from setup_maintenance_deploy import Deploy, require, SETUP, PYTHON
from setup_478_local_calendar_release import CalendarRelease

CANDIDATE = '9c86ff45b2efb2b1f5f65f3272c1b43d730dd7ef'
VERSION = 'V0.3.123-qc-recheck'
MIGRATION = 'Setup/Database/083_repeatable_preshow_qc.sql'
SIGNATURES = (
    'ops.setup_qc_command(text,text,bigint,bigint,text,text,text,text,integer)',
    'ops.setup_qc_final_gate(bigint)',
    'ops.setup_qc_ready_for_production(text,bigint,text,integer,text)',
    'ops.setup_qc_snapshot(text,integer)',
    'ops.setup_qc_intake_candidates(text,integer)',
)
TABLES = ('setup_qc_signoff','setup_qc_auditor','setup_qc_finding',
          'setup_qc_event','setup_qc_intake_link')

NEW_TABLES = ('setup_qc_signoff_history','setup_qc_correction','setup_qc_season_exception')
NEW_SIGNATURES = (
    'ops.setup_qc_invalidate_signoff(bigint,integer,text)',
    'ops.setup_qc_is_final_task(bigint)',
    'ops.setup_qc_edit_finding(text,bigint,bigint,bigint,text,timestamptz)',
    'ops.setup_qc_accept_for_season(text,bigint,bigint,text,date,integer,timestamptz)',
)



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
        # Preserve every existing row. Only the new nullable description column
        # and three new empty audit/exception tables differ structurally in083.
        return self.sql(r"""BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
          SELECT format($q$SELECT json_build_object('table',%L,'digest',
            md5(coalesce(string_agg(h,'' ORDER BY h),''))) FROM
            (SELECT md5((%s)::text) h FROM %I.%I t) rows;$q$,
            n.nspname||'.'||c.relname,
            CASE WHEN n.nspname='ops' AND c.relname='setup_qc_finding'
                 THEN $expr$to_jsonb(t)-'current_description'$expr$ ELSE 'to_jsonb(t)' END,
            n.nspname,c.relname)
          FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE n.nspname IN ('ref','ops','stage') AND c.relkind IN ('r','p')
            AND NOT (n.nspname='ops' AND c.relname IN
              ('setup_qc_signoff_history','setup_qc_correction','setup_qc_season_exception'))
          ORDER BY n.nspname,c.relname
          \gexec
          ROLLBACK;""")

    def database_gate(self, installed):
        # Production validation is catalog/SELECT only, never clone test writes.
        checks = []
        # Baseline is082 with real findings; installed state is083, not empty QC.
        original = self.git('show', CANDIDATE + ':Setup/Database/081_add_unscheduled_setup_qc_findings.sql')
        source = self.git('show', CANDIDATE + ':' + (MIGRATION if installed else 'Setup/Database/082_correct_qc_wording_and_shared_repairs.sql'))
        for sig in SIGNATURES + (NEW_SIGNATURES if installed else ()):
            name=sig.split('(')[0]
            match=re.search(r'CREATE (?:OR REPLACE )?FUNCTION '+re.escape(name)+r'\(.*?AS (\$[a-z_]+\$)(.*?)\1;', source if name!='ops.setup_qc_intake_candidates' else original,re.S)
            require(match is not None, 'Accepted function body missing: '+name)
            digest=hashlib.md5(match.group(2).encode()).hexdigest()
            exposed = 'false' if name in ('ops.setup_qc_final_gate','ops.setup_qc_invalidate_signoff','ops.setup_qc_is_final_task') else 'true'
            checks.append("""IF NOT EXISTS (SELECT 1 FROM pg_proc p
              WHERE p.oid=to_regprocedure('"""+sig+"""') AND md5(p.prosrc)='"""+digest+"""'
              AND p.prosecdef AND pg_get_userbyid(p.proowner)='msbadmin'
              AND EXISTS (SELECT 1 FROM unnest(p.proconfig) setting WHERE setting LIKE 'search_path=pg_catalog,%')
              AND NOT EXISTS (SELECT 1 FROM aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
                WHERE a.grantee=0 AND a.privilege_type='EXECUTE'))
              OR has_function_privilege('fieldwiring_app','"""+sig+"""','EXECUTE') IS DISTINCT FROM """+exposed+"""
              THEN RAISE EXCEPTION 'QC function definition/privilege differs: """+name+"""'; END IF;""")
        for name in TABLES + (NEW_TABLES if installed else ()):
            checks.append("IF has_table_privilege('fieldwiring_app','ops."+name+"','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') THEN RAISE EXCEPTION 'QC direct table access'; END IF;")
        for name in ('setup_qc_finding_qc_finding_id_seq','setup_qc_event_qc_event_id_seq'):
            checks.append("IF has_sequence_privilege('fieldwiring_app','ops."+name+"','USAGE,SELECT,UPDATE') THEN RAISE EXCEPTION 'QC direct sequence access'; END IF;")
        if not installed:
            checks.append("IF to_regclass('ops.setup_qc_season_exception') IS NOT NULL OR to_regclass('ops.setup_qc_signoff_history') IS NOT NULL OR to_regclass('ops.setup_qc_correction') IS NOT NULL OR EXISTS(SELECT 1 FROM information_schema.columns WHERE table_schema='ops' AND table_name='setup_qc_finding' AND column_name='current_description') THEN RAISE EXCEPTION '083 already present; do not replay'; END IF;")
        self.sql('BEGIN READ ONLY; DO $gate$ BEGIN '+ '\n'.join(checks)+' END $gate$; ROLLBACK;')

    def validate(self):
        self.database_gate(installed=True)
        # Migration083 must not silently import preview edits or create tickets.
        self.sql("""BEGIN READ ONLY; DO $check$ BEGIN
          IF EXISTS(SELECT 1 FROM ops.setup_qc_signoff_history)
            OR EXISTS(SELECT 1 FROM ops.setup_qc_correction)
            OR EXISTS(SELECT 1 FROM ops.setup_qc_season_exception)
            OR EXISTS(SELECT 1 FROM ops.setup_qc_finding WHERE current_description IS NOT NULL)
          THEN RAISE EXCEPTION 'Unexpected083 business writes'; END IF;
        END $check$; ROLLBACK;""")

    def preflight(self):
        require(self.m == {'profile':'490-qc', 'release_tag':'PR490-083',
                'candidate':CANDIDATE, 'target':CANDIDATE, 'version':VERSION,
                'migration':MIGRATION}, 'Unreviewed release manifest')
        self.mark('ONLINE PR490 preflight')
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
        require(re.findall(r'Updated\s+(\d{4}-\d{2}-\d{2})',footer) == ['2026-11-12'], 'Accepted UI date differs')
        self.m['tree'] = self.git('rev-parse',CANDIDATE+'^{tree}')
        self.m['migration_blob'] = self.git('rev-parse',CANDIDATE+':'+MIGRATION)
        self.journal()
        self.database_gate(installed=False)
        self.worktree = tempfile.mkdtemp(prefix='msb-490-release-',dir='/tmp')
        os.chmod(self.worktree,0o755)
        self.git('worktree','add','--detach',self.worktree,CANDIDATE)
        self.regression(self.worktree)
        self.source_baseline()
        self.online()
        self.database_gate(installed=False)
        (self.root/'online-fingerprint-probe.jsonl').write_text(self.capture()+'\n')
        self.mark('PR490 preflight PASS; Production unchanged')

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
        print('PR490 rollback snapshot: '+snapshot['path'],flush=True)
        print('PR490 snapshot SHA256: '+snapshot['sha256'],flush=True)
        print('PR490 live Setup: '+CANDIDATE+' / '+VERSION,flush=True)


if __name__ == '__main__':
    def interrupted(sig, frame):
        raise KeyboardInterrupt('PR490 deployment interrupted '+str(sig))
    signal.signal(signal.SIGTERM,interrupted)
    signal.signal(signal.SIGHUP,interrupted)
    orchestrator.Deploy = QcRelease
    raise SystemExit(orchestrator.main())
