"""Accepted PR460 profile of the existing maintenance controller/orchestrator.

No source intake or initial-state seeding. Only the accepted snapshot
migration and FieldWiring source promotion run inside the existing fence.
"""
import fcntl
import hashlib
import json
import os
from pathlib import Path
import signal
import tempfile
import setup_maintenance_deploy as orchestrator
from setup_maintenance_deploy import Deploy, require, REPO, SETUP, PYTHON

APP = '875003c504e8a60c5851c530ec6496e4430945d9'
OLD = '72a94be772f2e4ae8bfaed74051f667fc87201a6'
OLD_SETUP = OLD
MIGRATION = 'Database/EngineeringTools/sql/171_power_snapshot_performance.sql'
VALIDATION = 'Database/Acceptance/171_power_snapshot_performance_validation.sql'
MANIFEST = Path(__file__).with_name('setup_171_performance_release.json')


class PerformanceDeploy(Deploy):
    def baseline(self, promoted=False):
        for root, expected in ((REPO, APP if promoted else OLD), (SETUP, OLD_SETUP)):
            require(self.git('rev-parse', 'HEAD', root=root) == expected and
                    not self.git('status', '--porcelain', root=root), 'Live source drift: '+root)

    def health(self, new=False):
        for port, version in ((8790, 'V0.4.27-panel-performance' if new else 'V0.4.26-breaker-reports'),
                              (8794, 'V0.3.91-integrated-power'), (8792, 'V0.1.0')):
            h = json.loads(self.run(['curl', '-fsS', '--retry', '5', '--retry-connrefused',
                                    '--retry-delay', '1', '--max-time', '15',
                                    f'http://192.168.5.9:{port}/api/health']))
            require(h.get('status') == 'ok' and h.get('data_mode') == 'postgres'
                    and h.get('version') == version, 'Unexpected health: '+str(port))

    def online(self):
        state = self.controller('status'); live = state.get('live', {})
        require(state.get('state') == 'ONLINE' and not state.get('last_error')
                and live.get('mode') == 'real' and live.get('database_fenced') is False,
                'Healthy real ONLINE required')
        require(all(live.get('services', {}).get(s) == 'active' for s in (
            'fieldwiring.service', 'msb-setup.service', 'msb-procedures.service',
            'msb-people.service', 'lor-preflight-api.service', 'msb-work-management.service'))
            and live.get('services', {}).get('container:msb-directus') == 'running', 'Unhealthy services')
        backups = live.get('backups', {})
        require(backups.get('nas_mounted') is True
                and backups.get('replication', {}).get('current_run_ok') is True, 'Backup chain unhealthy')

    def snapshot_security(self):
        value = json.loads(self.sql("""BEGIN READ ONLY;
          SELECT json_build_object('command', (SELECT md5(prosrc) FROM pg_proc WHERE oid=
            'ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure),
            'definer', p.prosecdef, 'stability', p.provolatile,
            'path', p.proconfig, 'owner', pg_get_userbyid(p.proowner),
            'execute', has_function_privilege('fieldwiring_app',p.oid,'EXECUTE'),
            'public_execute', EXISTS(SELECT 1 FROM aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
              WHERE a.grantee=0 AND a.privilege_type='EXECUTE'))
          FROM pg_proc p WHERE p.oid='ref.site_power_snapshot(text)'::regprocedure;
          ROLLBACK;"""))
        require(value == dict(command='7c1ff2630aefda0a7e46c0ef4672714e', definer=True,
            stability='s', path=['search_path=pg_catalog, ref, ops'], owner='msbadmin',
            execute=True, public_execute=False), 'Snapshot security/command baseline differs')

    def database_preflight(self):
        self.snapshot_security()
        value = json.loads(self.sql("""BEGIN READ ONLY;
          SELECT json_build_object('slot', EXISTS(SELECT 1 FROM pg_attribute
            WHERE attrelid='ref.site_panel'::regclass AND attname='branch_position_count' AND NOT attisdropped),
            'snapshot', (SELECT md5(prosrc) FROM pg_proc WHERE oid=
              'ref.site_power_snapshot(text)'::regprocedure),
            'execute', has_function_privilege('fieldwiring_app',
              'ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)','EXECUTE'),
            'direct_write', has_table_privilege('fieldwiring_app','ref.site_panel','INSERT,UPDATE,DELETE'));
          ROLLBACK;"""))
        require(value == dict(slot=True, snapshot='90d9a9a08645e6611e1216f80bdc774c',
                              execute=True, direct_write=False), 'Migration baseline differs; do not replay')

    def preflight(self):
        require(self.m == json.loads(MANIFEST.read_text()), 'Unreviewed manifest')
        require(self.m['candidate'] == self.m['target'] == APP and self.m['shared'] == OLD
                and self.m['old_setup'] == OLD_SETUP and list(self.m['blobs']) == [MIGRATION, VALIDATION],
                'Unreviewed release identities')
        for name, digest in self.m['helpers'].items():
            require(hashlib.sha256(Path(__file__).with_name(name).read_bytes()).hexdigest() == digest,
                    'Transport helper differs: '+name)
        self.mark('ONLINE performance release preflight')
        self.online(); self.baseline(); self.health(); self.database_preflight()
        require(not self.run(['ss', '-ltnH', 'sport = :8898']), 'Preview port occupied')
        self.source_lock = open('/home/msbadmin/setup-source-cache/.preview-source.lock', 'r')
        fcntl.flock(self.source_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        self.git('fetch', 'origin', '+refs/heads/main:refs/remotes/origin/main')
        self.git('merge-base', '--is-ancestor', APP, 'origin/main')
        self.git('merge-base', '--is-ancestor', OLD, APP)
        require(not self.git('diff', '--name-only', OLD, APP, '--', 'Setup/Application', 'Procedures/Application'),
                'Unexpected Setup/Procedures application changes')
        require(self.git('rev-parse', APP+'^{tree}') == self.m['tree'], 'Accepted tree differs')
        for path, blob in self.m['blobs'].items():
            require(self.git('rev-parse', APP+':'+path) == blob, 'Reviewed SQL differs: '+path)
        self.worktree = tempfile.mkdtemp(prefix='msb-171-performance-', dir='/tmp')
        os.chmod(self.worktree, 0o755)
        self.git('worktree', 'add', '--detach', self.worktree, APP)
        self.regression(self.worktree)
        # ONLINE syntax/read proof only. The stable baseline starts after fencing.
        self.capture()
        self.baseline(); self.online(); self.database_preflight()
        self.mark('preflight PASS')

    def regression(self, root):
        for suite in ('FieldWiring/Application', 'Procedures/Application', 'Setup/Application'):
            self.run(['sudo', '-u', 'fieldwiring', '-H', 'env', 'PYTHONDONTWRITEBYTECODE=1',
                      'bash', '-c', 'cd '+root+' && '+PYTHON+
                      ' -m pytest -q -p no:cacheprovider '+suite], timeout=300)

    def capture(self):
        # Per-row hashes avoid aggregating hundreds of MB of immutable source JSON.
        # Every existing key is preserved, including the installed slot count.
        return self.sql(r"""BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
          SELECT format($q$SELECT json_build_object('table',%L,'rows',count(*),'digest',
            md5(coalesce(string_agg(h,'' ORDER BY h),''))) FROM
            (SELECT md5((%s)::text) AS h FROM %I.%I t) hashed;$q$,
            n.nspname||'.'||c.relname,
            'to_jsonb(t)',
            n.nspname,c.relname)
          FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE c.relkind IN ('r','p') AND (n.nspname IN ('ref','ops','lor_snap')
            OR (n.nspname='public' AND c.relname IN
              ('directus_users','directus_roles','directus_policies','directus_permissions','directus_access')))
          ORDER BY n.nspname,c.relname
          \gexec
          ROLLBACK;""")

    def apply_migrations(self):
        self.baseline(); self.database_preflight(); self.frozen(self.controller('status'))
        self.sql(self.git('show', APP+':'+MIGRATION))

    def validate(self):
        self.snapshot_security()
        self.sql(self.git('show', APP+':'+VALIDATION))
        bodies = json.loads(self.sql("""BEGIN READ ONLY;
          SELECT json_object_agg(proname,md5(prosrc)) FROM pg_proc WHERE oid IN
           ('ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure,
            'ref.site_power_snapshot(text)'::regprocedure);
          ROLLBACK;"""))
        require(bodies == {'site_power_command':'7c1ff2630aefda0a7e46c0ef4672714e',
                          'site_power_snapshot':'1409b5a8bada107ecfd5954c8f49a18d'},
                'Installed command/snapshot differs from accepted candidate')

    def promote_source(self, baseline):
        self.baseline()
        self.mark('promoting accepted FieldWiring source while fenced; Setup unchanged')
        self.frozen(self.controller('status'))
        self.git('merge', '--ff-only', APP)
        self.baseline(promoted=True)
        self.regression(REPO)

    def before_reopen(self, baseline):
        self.baseline(promoted=True); self.validate(); self.frozen(self.controller('status'))
        require(self.capture() == baseline, 'Preserved business rows changed')

    def live_validation(self):
        self.health(new=True); self.validate(); self.baseline(promoted=True)
        code = self.run(['curl', '-sS', '--max-time', '15', '-o', '/dev/null', '-w', '%{http_code}',
                         'http://192.168.5.9:8790/api/power'])
        require(code in ('401', '403'), 'Unidentified power request was not denied')
        code = self.run(['curl', '-sS', '--max-time', '15', '-o', '/dev/null', '-w', '%{http_code}',
                         'http://192.168.5.9:8790/api/power/report.pdf?season=2026'])
        require(code in ('401', '403'), 'Unidentified report request was not denied')
        self.regression(REPO)

    def after_reopen(self):
        # Surface the already validated receipt so operator closeout needs no
        # separate forensic command to find the rollback archive and hash.
        snapshot = json.loads((self.root / 'snapshot.json').read_text())
        print('Rollback snapshot: '+snapshot['path'], flush=True)
        print('Snapshot SHA256: '+snapshot['sha256'], flush=True)
        print('Verified FieldWiring source: '+APP, flush=True)
        print('Verified unchanged Setup source: '+OLD_SETUP, flush=True)

    def cleanup(self):
        try:
            super().cleanup()
        finally:
            if getattr(self, 'source_lock', None):
                self.source_lock.close()


if __name__ == '__main__':
    def interrupted(signum, frame):
        raise KeyboardInterrupt('Deployment signal '+str(signum))
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGHUP, interrupted)
    orchestrator.Deploy = PerformanceDeploy
    raise SystemExit(orchestrator.main())
