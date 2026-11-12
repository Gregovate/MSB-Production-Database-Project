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

CANDIDATE = '57a8c2049cbb1e78fba48beb2f66a359703d5e16'
VERSION = 'V0.3.122-qc-report'
MIGRATION = 'Setup/Database/082_correct_qc_wording_and_shared_repairs.sql'
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

    def wording(self):
        source = self.git('show', CANDIDATE + ':' + MIGRATION)
        match = re.search(r"SET task_name='([^']+)',completion_point='([^']+)'", source)
        require(match is not None, 'Accepted wording missing')
        return match.groups()

    def capture(self):
        # Exclude only authorized wording/audit columns on exact target rows.
        # Every QC event, claim, signoff and all unrelated business data is hashed.
        name, _ = self.wording()
        old = 'plug[[:space:]]+in[[:space:]]+network[[:space:]]+to[[:space:]]+controller.*2[[:space:]]+minute[[:space:]]+test[[:space:]]+show'
        catalog = "CASE WHEN t.task_name ~* '"+old+"' OR t.task_name='"+name+"' THEN to_jsonb(t)-ARRAY['task_name','completion_point','updated_at','updated_by','updated_by_person_id'] ELSE to_jsonb(t) END"
        annual = "CASE WHEN (t.annual_task_name ~* '"+old+"' OR t.annual_task_name='"+name+"') AND EXISTS(SELECT 1 FROM ops.setup_session ss WHERE ss.setup_session_id=t.setup_session_id AND ss.season_year=2026) THEN to_jsonb(t)-ARRAY['annual_task_name','annual_completion_point','updated_at','updated_by','updated_by_person_id'] ELSE to_jsonb(t) END"
        def literal(value):
            return "'"+value.replace("'","''")+"'"
        return self.sql("""BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
          SELECT format($q$SELECT json_build_object('table',%L,'digest',
            md5(coalesce(string_agg(h,'' ORDER BY h),''))) FROM
            (SELECT md5((%s)::text) h FROM %I.%I t) rows;$q$,
            n.nspname||'.'||c.relname,
            CASE WHEN n.nspname='ref' AND c.relname='setup_task' THEN """+literal(catalog)+"""
                 WHEN n.nspname='ops' AND c.relname='setup_session_task' THEN """+literal(annual)+"""
                 ELSE 'to_jsonb(t)' END,n.nspname,c.relname)
          FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE n.nspname IN ('ref','ops','stage') AND c.relkind IN ('r','p')
          ORDER BY n.nspname,c.relname
          \\gexec
          ROLLBACK;""")

    def database_gate(self, installed):
        # Production validation is catalog/SELECT only, never clone test writes.
        checks = []
        # Baseline is081 with real findings; installed state is082, not empty QC.
        original = self.git('show', CANDIDATE + ':Setup/Database/081_add_unscheduled_setup_qc_findings.sql')
        source = self.git('show', CANDIDATE + ':' + MIGRATION) if installed else original
        for sig in SIGNATURES:
            name=sig.split('(')[0]
            match=re.search(r'CREATE (?:OR REPLACE )?FUNCTION '+re.escape(name)+r'\(.*?AS (\$[a-z_]+\$)(.*?)\1;', source if name!='ops.setup_qc_intake_candidates' else original,re.S)
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
              THEN RAISE EXCEPTION 'QC function definition/privilege differs: """+name+"""'; END IF;""")
        for name in TABLES:
            checks.append("IF has_table_privilege('fieldwiring_app','ops."+name+"','SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') THEN RAISE EXCEPTION 'QC direct table access'; END IF;")
        for name in ('setup_qc_finding_qc_finding_id_seq','setup_qc_event_qc_event_id_seq'):
            checks.append("IF has_sequence_privilege('fieldwiring_app','ops."+name+"','USAGE,SELECT,UPDATE') THEN RAISE EXCEPTION 'QC direct sequence access'; END IF;")
        self.sql('BEGIN READ ONLY; DO $gate$ BEGIN '+ '\n'.join(checks)+' END $gate$; ROLLBACK;')

    def validate(self):
        self.database_gate(installed=True)
        name, completion = self.wording()
        old = 'plug[[:space:]]+in[[:space:]]+network[[:space:]]+to[[:space:]]+controller.*2[[:space:]]+minute[[:space:]]+test[[:space:]]+show'
        self.sql("BEGIN READ ONLY; DO $wording$ BEGIN "
          "IF EXISTS(SELECT 1 FROM ref.setup_task WHERE task_name ~* '"+old+"' OR (task_name='"+name+"' AND completion_point IS DISTINCT FROM '"+completion+"')) THEN RAISE EXCEPTION 'Catalog wording differs'; END IF; "
          "IF EXISTS(SELECT 1 FROM ops.setup_session_task t JOIN ops.setup_session ss USING(setup_session_id) WHERE ss.season_year=2026 AND (t.annual_task_name ~* '"+old+"' OR (t.annual_task_name='"+name+"' AND t.annual_completion_point IS DISTINCT FROM '"+completion+"'))) THEN RAISE EXCEPTION 'Annual wording differs'; END IF; "
          "END $wording$; ROLLBACK;")

    def preflight(self):
        require(self.m == {'profile':'489-qc', 'release_tag':'PR489-082',
                'candidate':CANDIDATE, 'target':CANDIDATE, 'version':VERSION,
                'migration':MIGRATION}, 'Unreviewed release manifest')
        self.mark('ONLINE PR489 preflight')
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
        self.worktree = tempfile.mkdtemp(prefix='msb-489-release-',dir='/tmp')
        os.chmod(self.worktree,0o755)
        self.git('worktree','add','--detach',self.worktree,CANDIDATE)
        self.regression(self.worktree)
        self.source_baseline()
        self.online()
        self.database_gate(installed=False)
        (self.root/'online-fingerprint-probe.jsonl').write_text(self.capture()+'\n')
        self.mark('PR489 preflight PASS; Production unchanged')

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
        print('PR489 rollback snapshot: '+snapshot['path'],flush=True)
        print('PR489 snapshot SHA256: '+snapshot['sha256'],flush=True)
        print('PR489 live Setup: '+CANDIDATE+' / '+VERSION,flush=True)


if __name__ == '__main__':
    def interrupted(sig, frame):
        raise KeyboardInterrupt('PR489 deployment interrupted '+str(sig))
    signal.signal(signal.SIGTERM,interrupted)
    signal.signal(signal.SIGHUP,interrupted)
    orchestrator.Deploy = QcRelease
    raise SystemExit(orchestrator.main())
