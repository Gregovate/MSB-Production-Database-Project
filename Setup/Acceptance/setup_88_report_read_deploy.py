#!/usr/bin/env python3
"""#88 approved read prerequisite and report in one controller maintenance window.

Reuse the installed maintenance-controller orchestration and disposable clone
pattern. Failure never retries a grant, opens the fence, or restores a database.
"""
import argparse
import ast
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import sys
import tempfile
from datetime import datetime, timezone

from setup_maintenance_deploy import Deploy, Stop, require, fcntl, REPO, SETUP

GRANT_TARGET = '6b04d1afff67e2b79a068316198ee7ad95a635f7'  # Exact accepted migration/clone-artifact commit.
# Pin corrected infrastructure independently of frozen application/migration
# sources. The old candidate shell omitted Docker stdin forwarding for ACL SQL.
CLONE_RUNNER_BLOB = '2025db912621f8258356cdb3e7f474ea0ca763f1'
MIGRATION = 'Setup/Database/071_grant_setup_container_type_report_read.sql'
MIGRATION_BLOB = '1fd5de8f3de7665336e0eabead498e94ed915883'
REPORT_TARGET = '6c44a082dd520b75881c50ad2ce78feb029ff87d'
OLD_SETUP = 'cb0538022ed066ff90675e832daa1cd95488114a'
SHARED = '6dd05c4aa5ef8f50fe172145c3ae281cc245a101'
OLD_VERSION = 'V0.3.42-current-location'
REPORT_VERSION = 'V0.3.50-container-movement-report'
VALIDATION = 'Setup/Acceptance/setup_88_report_read_validation.sql'
HELPERS = {'setup_maintenance_deploy.py': '9bf50a37b44d142f253b927b06bf4dc1960eb92b',
           'setup_88_report_source_only_deploy.py': '0fe7e1115579f3d4dbdb56fbdcd61bde599612fa'}
# The established wrapper normalizes Windows line endings. The old maintenance
# helper contains one CRLF footer; verify both repository and LF transport pins.
TRANSPORT_BLOBS = {'setup_maintenance_deploy.py': '5070d20513aabb8ddd2e31b8995dc908ea9aaa96',
                   'setup_88_report_source_only_deploy.py': '0fe7e1115579f3d4dbdb56fbdcd61bde599612fa'}


def git_blob(data):
    return hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()


def report_queries(source):
    function = next(n for n in ast.parse(source).body
                    if isinstance(n, ast.FunctionDef) and n.name == 'movement_picture')
    queries = [n.args[0].value for n in ast.walk(function)
               if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute)
               and n.func.attr == 'execute' and isinstance(n.args[0], ast.Constant)]
    require(len(queries) == 6, 'Exact report statement contract changed')
    return queries


class ReadDeploy(Deploy):
    def __init__(self, root):
        self.report = None
        super().__init__(dict(issue=88, grant_target=GRANT_TARGET,
                             clone_runner_blob=CLONE_RUNNER_BLOB,
                             report_target=REPORT_TARGET, migration=MIGRATION,
                             migration_blob=MIGRATION_BLOB, old_setup=OLD_SETUP,
                             shared=SHARED), root)

    def journal(self, **extra):
        # Retain source-promotion evidence across subsequent stage updates.
        if self.report is not None:
            extra.update(report_directory=str(self.report.root),
                         application_promotion_started=self.report.advanced)
        super().journal(**extra)

    def git(self, *args, root=REPO):
        return self.run(['sudo', 'env', 'GIT_TERMINAL_PROMPT=0', 'git', '-C', root, *args])

    def mark(self, stage):
        self.stage = stage
        print('Setup #88: '+stage, flush=True)
        self.log.write('STAGE ' + stage + '\n')
        self.journal()
        if self.maintenance_started:
            self.controller('stage', '#88 report read ' + stage)

    def online(self):
        state = self.controller('status')
        live = state.get('live', {})
        require(state.get('state') == 'ONLINE' and not state.get('last_error')
                and live.get('database_fenced') is False and live.get('mode') == 'real',
                'Production is not healthy real ONLINE')
        services = ['msb-setup.service','fieldwiring.service','msb-procedures.service',
                    'msb-people.service','lor-preflight-api.service']
        require(all(live.get('services', {}).get(s) == 'active' for s in services)
                and live.get('services', {}).get('container:msb-directus') == 'running',
                'Governed services unhealthy')
        require(live.get('backups', {}).get('nas_mounted') is True
                and live.get('backups', {}).get('replication', {}).get('current_run_ok') is True,
                'Backup chain not current')

    def baseline(self):
        require(self.git('rev-parse','HEAD',root=SETUP) == OLD_SETUP
                and not self.git('status','--porcelain',root=SETUP)
                and not self.git('branch','--show-current',root=SETUP), 'Live Setup drift')
        require(self.git('rev-parse','HEAD') == SHARED
                and not self.git('status','--porcelain'), 'Shared checkout drift')
        health = json.loads(self.run(['curl','-fsS','--max-time','10',
                                      'http://192.168.5.9:8794/api/health']))
        require(health.get('status') == 'ok' and health.get('data_mode') == 'postgres'
                and health.get('version') == OLD_VERSION, 'Setup baseline health differs')

    def missing_read(self):
        # Refuse previously applied/partially applied or broad privileges instead
        # of treating a repeated run as permission to redo a deployment.
        self.sql("""BEGIN READ ONLY; DO $$ BEGIN
          IF has_column_privilege('fieldwiring_app','ref.container_type','container_type_id','SELECT')
             OR has_column_privilege('fieldwiring_app','ref.container_type','container_type_name','SELECT')
             OR has_table_privilege('fieldwiring_app','ref.container_type','INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
             OR EXISTS (SELECT 1 FROM pg_attribute WHERE attrelid='ref.container_type'::regclass
                 AND attnum>0 AND NOT attisdropped
                 AND has_column_privilege('fieldwiring_app','ref.container_type',attname,'SELECT,INSERT,UPDATE,REFERENCES'))
          THEN RAISE EXCEPTION 'Type permission baseline changed; inspect, do not retry'; END IF;
        END $$; ROLLBACK;""")

    def capture(self):
        # Unlike migration 069, this grant permits no business-row difference.
        return self.sql(r"""BEGIN READ ONLY;
          SELECT format('SELECT json_build_object(''table'',%L,''digest'',md5(coalesce(string_agg(to_jsonb(t)::text,'''' ORDER BY to_jsonb(t)::text),''''))) FROM %I.%I t;',
            n.nspname||'.'||c.relname,n.nspname,c.relname)
          FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE n.nspname IN ('ref','ops') AND c.relkind IN ('r','p')
          ORDER BY n.nspname,c.relname
          \gexec
          ROLLBACK;
        """)

    def acl_preservation(self):
        # Ignore only the two newly approved SELECT entries. Every other
        # Container-type table/column ACL must remain byte-for-byte equivalent.
        return self.sql("""BEGIN READ ONLY;
          SELECT jsonb_build_object('table_acl',c.relacl,'columns',(
            SELECT jsonb_agg(jsonb_build_object('name',a.attname,'acl',(
              SELECT jsonb_agg(to_jsonb(x) ORDER BY x.grantor,x.grantee,x.privilege_type)
              FROM aclexplode(a.attacl) x
              WHERE NOT (a.attname IN ('container_type_id','container_type_name')
                AND x.grantee='fieldwiring_app'::regrole AND x.privilege_type='SELECT')))
              ORDER BY a.attnum)
            FROM pg_attribute a WHERE a.attrelid=c.oid AND a.attnum>0 AND NOT a.attisdropped))
          FROM pg_class c WHERE c.oid='ref.container_type'::regclass;
          ROLLBACK;""")

    def validate(self):
        source = self.git('show',REPORT_TARGET+':Setup/Application/setup_production_report.py')
        validation = self.git('show',GRANT_TARGET+':'+VALIDATION)
        # Keep the committed SQL validation tied to the unchanged exact report.
        for query in report_queries(source):
            require(query.replace('%s', ':report_session_id') in validation,
                    'Validation SQL differs from exact approved report')
        self.sql(validation)

    def clone_acceptance(self):
        # Reuse the existing clone runner in its new actual-SELECT mode. Its
        # cleanup owns this dedicated transport directory, not our report.
        bundle = Path(tempfile.mkdtemp(prefix='setup-88-read-clone-',dir='/tmp'))
        try:
            runner = bundle / 'setup_disposable_acceptance_server.sh'
            # Fetch has made the merged, content-addressed runner available.
            # Deploy.run strips output; restore its single final LF and prove
            # exact bytes before execution. Candidate SQL still comes from 6b04.
            source = (self.git('cat-file','blob',CLONE_RUNNER_BLOB)+'\n').encode()
            require(git_blob(source) == CLONE_RUNNER_BLOB,
                    'Disposable clone runner differs from accepted blob')
            runner.write_bytes(source)
            manifest = bundle / 'manifest.tsv'
            manifest.write_text('candidate_sha\t'+GRANT_TARGET+'\ntarget_ref\tmain\n'
                'allow_concurrent_production_writes\ttrue\nproduction_read_boundary\ttrue\n'
                'migration\t'+MIGRATION+'\nvalidation\t'+VALIDATION+'\n')
            self.run(['bash',str(runner),str(manifest)],timeout=1200)
        finally:
            if bundle.exists():
                shutil.rmtree(bundle)

    def preflight(self):
        self.mark('ONLINE preflight')
        self.online(); self.baseline()
        require(not self.run(['ss','-ltnH','sport = :8898']), 'Browser preview still active')
        self.missing_read()
        self.git('fetch','origin','+refs/heads/main:refs/remotes/origin/main')
        for target in (GRANT_TARGET,REPORT_TARGET):
            self.git('merge-base','--is-ancestor',target,'origin/main')
            self.git('merge-base','--is-ancestor',OLD_SETUP,target)
        require(self.git('rev-parse',GRANT_TARGET+':'+MIGRATION) == MIGRATION_BLOB,
                'Migration blob differs')
        require(self.git('diff','--name-only',REPORT_TARGET,GRANT_TARGET,'--','Setup/Database') == MIGRATION,
                'Unexpected Database source in read prerequisite')
        changed = self.git('diff','--name-only',REPORT_TARGET,GRANT_TARGET,'--','Setup/Application').splitlines()
        require(set(changed) <= {'Setup/Application/README.md',
                                'Setup/Application/test_setup_reusable_acceptance_tooling_contract.py'},
                'Reviewed report runtime Application bytes changed')
        for name, blob in HELPERS.items():
            require(self.git('rev-parse',GRANT_TARGET+':Setup/Acceptance/'+name) == blob
                    and git_blob(Path(__file__).with_name(name).read_bytes()) == TRANSPORT_BLOBS[name],
                    'Transported helper differs: '+name)
        self.worktree = tempfile.mkdtemp(prefix='setup-88-read-candidate-',dir='/tmp')
        os.chmod(self.worktree,0o755)
        self.git('worktree','add','--detach',self.worktree,GRANT_TARGET)
        self.clone_acceptance()
        self.prepare_report()
        self.baseline(); self.online(); self.missing_read()
        self.mark('current-Production clone acceptance PASS')

    def prepare_report(self):
        """Reuse pinned source checks/tests while operators can keep working."""
        from setup_88_report_source_only_deploy import Installer
        self.report = Installer()
        report = self.report
        (self.root/'report-directory.txt').write_text(str(report.root)+'\n')
        self.journal()
        require(not report.git('diff','--name-only',OLD_SETUP,REPORT_TARGET,
                               '--','Setup/Database'), 'Report Database source changed')
        require(report.git('show',REPORT_TARGET+':Setup/Application/production_backend.py')
                .count('PRODUCTION_VERSION = "'+REPORT_VERSION+'"') == 1,
                'Report server identity differs')
        require("CLIENT_BUILD = '"+REPORT_VERSION+"'" in report.git('show',
                REPORT_TARGET+':Setup/Application/setup_catalog_dirty_guard.js'),
                'Report client identity differs')
        # Mark ownership before creation so a partial Git failure is cleaned up.
        report.worktree_created = True
        report.git('worktree','add','--detach',report.candidate,REPORT_TARGET)
        report.run(['sudo','python3',report.candidate+'/Setup/Acceptance/check_setup_ui_update_date.py',
                    '--repository',REPO,'--target',REPORT_TARGET])
        report.regression(report.candidate,['Setup/Application'])
        report.focused_regression(report.candidate)
        self.mark('exact report source regression PASS')

    def deploy(self):
        self.baseline(); self.online(); self.missing_read()
        require(self.report is not None, 'Exact report regression not prepared')
        self.log.write('Authority: Server Management — Production_Database_Change_Deployment_Runbook.md\n'
                       'Procedure: controlled database-changing deployment\n'
                       'This step: controller ON; snapshot; only migration 071; report promotion; frozen validation; OFF\n')
        self.mark('entering maintenance')
        self.maintenance_started = True; self.journal()
        self.frozen(self.controller('on'))
        self.mark('freeze PASS')
        before = self.capture(); acl_before = self.acl_preservation()
        (self.root/'frozen-invariants.jsonl').write_text(before+'\n')
        (self.root/'before-type-acl.json').write_text(acl_before+'\n')
        archive = '/home/msbadmin/backups/setup-88/msb-pre-071-'+self.root.name+'.dump'
        snap = self.controller('snapshot',archive).get('snapshot',{})
        require(snap.get('validated') is True and snap.get('ok') is True
                and snap.get('bytes',0)>0 and snap.get('path')==archive
                and len(snap.get('sha256',''))==64, 'Snapshot not validated')
        require(self.run(['sudo','sha256sum',archive]).split()[0]==snap['sha256'],
                'Snapshot hash differs')
        (self.root/'snapshot.json').write_text(json.dumps(snap,indent=2)+'\n')
        self.mark('snapshot PASS')
        self.frozen(self.controller('status')); self.missing_read()
        require(self.capture()==before and self.acl_preservation()==acl_before,
                'Frozen baseline changed')
        migration = self.git('show',GRANT_TARGET+':'+MIGRATION)
        require(git_blob((migration+'\n').encode())==MIGRATION_BLOB, 'Migration bytes differ')
        self.mark('permission migration starting'); self.migration_started=True; self.journal()
        self.sql(migration)
        self.committed=True; self.mark('permission migration committed')
        self.validate()
        after=self.capture(); acl_after=self.acl_preservation()
        (self.root/'after-invariants.jsonl').write_text(after+'\n')
        (self.root/'after-type-acl.json').write_text(acl_after+'\n')
        require(after==before and acl_after==acl_before, 'Data or unapproved ACL changed')
        self.frozen(self.controller('status'))
        require(self.git('rev-parse','HEAD',root=SETUP)==OLD_SETUP
                and self.git('rev-parse','HEAD')==SHARED, 'Checkout changed during grant')
        self.mark('permission validation PASS; installing report while frozen')
        self.promote_report()
        # Compare business data before OFF. Normal work after OFF is legitimate
        # and must never trigger a stale-fingerprint rollback.
        self.validate()
        after=self.capture(); acl_after=self.acl_preservation()
        (self.root/'after-report-invariants.jsonl').write_text(after+'\n')
        (self.root/'after-report-type-acl.json').write_text(acl_after+'\n')
        require(after==before and acl_after==acl_before,
                'Data or unapproved ACL changed during report promotion')
        self.frozen(self.controller('status'))
        self.mark('grant and report frozen validation PASS; returning to service')
        state=self.controller('off')
        require(state.get('state')=='ONLINE' and not state.get('last_error')
                and state.get('live',{}).get('database_fenced') is False
                and state.get('gates',{}).get('online_proof',{}).get('ok') is True,
                'Return to service not proven')
        self.maintenance_started=False; self.journal()
        self.finish_report()
        self.mark('grant and report server PASS; protected browser check pending')

    def promote_report(self):
        """Advance only Setup; the controller still owns all stopped writers."""
        require(self.report is not None, 'Exact report regression not prepared')
        self.frozen(self.controller('status'))
        report=self.report
        report.advanced=True; self.journal()
        report.git('checkout','--detach',REPORT_TARGET,root=SETUP)
        require(report.git('rev-parse','HEAD',root=SETUP)==REPORT_TARGET
                and not report.git('status','--porcelain',root=SETUP),
                'Promoted report identity differs')
        require(report.git('rev-parse','HEAD')==SHARED
                and not report.git('status','--porcelain'), 'Shared checkout changed')
        report.focused_regression(SETUP)
        report.report_read_probe()

    def finish_report(self):
        """Validate after controller OFF without comparing reopened business rows."""
        report=self.report
        self.online()
        try:
            report.health(REPORT_VERSION)
            report.focused_regression(SETUP)
            report.report_read_probe()
            require(report.git('rev-parse','HEAD',root=SETUP)==REPORT_TARGET
                    and not report.git('status','--porcelain',root=SETUP),
                    'Final report source differs')
            require(report.git('rev-parse','HEAD')==SHARED
                    and not report.git('status','--porcelain'), 'Shared checkout changed')
        except BaseException as exc:
            report.log.write('STOP '+repr(exc)+'\n')
            # OFF was proven. Restore only source/service on a failed live
            # application check; keep the validated grant and legitimate work.
            try:
                state=self.controller('status')
                require(state.get('state')=='ONLINE' and not state.get('last_error')
                        and state.get('live',{}).get('database_fenced') is False,
                        'Source rollback requires current healthy ONLINE controller')
                require(report.git('rev-parse','HEAD',root=SETUP)==REPORT_TARGET,
                        'Source changed outside this run; do not overwrite')
                report.rollback()
            except Exception as recovery:
                report.log.write('ROLLBACK FAILED '+repr(recovery)+'\n')
                raise RuntimeError('Report failed and source rollback failed; inspect both reports') from recovery
            raise
        (self.root/'result.json').write_text(json.dumps(dict(result='PASS',
            migration=MIGRATION,migration_blob=MIGRATION_BLOB,grant_target=GRANT_TARGET,
            report_directory=str(report.root),app_target=REPORT_TARGET,
            version=REPORT_VERSION,preservation='ref/ops rows and unapproved ACL unchanged while frozen',
            operator_check='PENDING'),indent=2)+'\n')

    def cleanup(self):
        # Cleanup never opens maintenance or restarts a writer on a failed gate.
        errors=[]
        if self.report is not None:
            try:
                self.report.cleanup()
            except Exception as exc:
                errors.append(exc)
            finally:
                self.report.log.close()
        if self.worktree:
            try:
                super().cleanup()
                self.worktree=None
            except Exception as exc:
                errors.append(exc)
        require(not errors, 'Owned worktree cleanup failed: '+repr(errors))


def interrupted(signum, frame):
    raise RuntimeError('Interrupted by signal '+str(signum)+'; inspect retained journal')


def main():
    require(fcntl is not None,'Run only on the Linux Production host')
    parser=argparse.ArgumentParser()
    parser.add_argument('--deploy',action='store_true')
    args=parser.parse_args()
    signal.signal(signal.SIGTERM,interrupted); signal.signal(signal.SIGINT,interrupted)
    with (Path.home()/'.msb-production-deploy.lock').open('a+') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        stamp=datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        deploy=ReadDeploy(Path.home()/'setup-deployment-reports'/('Setup88Read-'+stamp))
        try:
            deploy.preflight()
            if args.deploy: deploy.deploy()
            deploy.cleanup()
            print('PASS: '+deploy.stage+'; report: '+str(deploy.root))
            return 0
        except BaseException as exc:
            deploy.journal(error=str(exc)); deploy.log.write('STOP '+repr(exc)+'\n')
            try: deploy.cleanup()
            except Exception as cleanup: deploy.log.write('CLEANUP FAILED '+repr(cleanup)+'\n')
            print('STOP: '+deploy.stage+'; error: '+str(exc)+'; report: '+str(deploy.root)+
                  '; do not rerun or change maintenance; inspect retained journal')
            return 1
        finally:
            deploy.log.close()


if __name__=='__main__':
    sys.exit(main())
