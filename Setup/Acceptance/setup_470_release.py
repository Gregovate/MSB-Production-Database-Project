"""Accepted PR470 profile of the existing maintenance controller/orchestrator.

Apply only the accepted breaker-outlet migration and both application sources.
Use the existing fence; preserve all existing operational records.
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

APP = 'b463f10d852d30b24aacf8e9657622ef93ed08de'
OLD = '820b154cd664f0cac0d1d8dfd38e47b4fe19df9c'
OLD_SETUP = OLD
MIGRATIONS = ('Database/EngineeringTools/sql/171_panel_receptacles.sql',)
VALIDATIONS = ('Database/Acceptance/171_panel_receptacles_validation.sql',)
MANIFEST = Path(__file__).with_name('setup_470_release.json')
class MapDeploy(Deploy):
    def baseline(self, promoted=False):
        for root, expected in ((REPO, APP if promoted else OLD), (SETUP, APP if promoted else OLD_SETUP)):
            require(self.git('rev-parse', 'HEAD', root=root) == expected and
                    not self.git('status', '--porcelain', root=root), 'Live source drift: '+root)

    def health(self, new=False):
        for port, version in ((8790, 'V0.4.35-power-panel-link' if new else 'V0.4.31-field-review'),
                              (8794, 'V0.3.95-map-return' if new else 'V0.3.91-integrated-power'), (8792, 'V0.1.0')):
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

    def database_preflight(self):
        # Reject replay/partial installation, and prove new actor reads beforehand.
        self.sql("""BEGIN READ ONLY; DO $$ BEGIN
          IF EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid='ref.site_power_breaker'::regclass
                    AND attname='panel_outlets' AND NOT attisdropped)
          OR to_regprocedure('ref.site_map_power_details()') IS NOT NULL
          OR to_regclass('ops.site_equipment_event') IS NULL
          OR to_regclass('ops.setup_container_pickup_event') IS NULL
          THEN RAISE EXCEPTION 'Unexpected PR470 baseline; no replay'; END IF;
          END $$;
          SET LOCAL ROLE fieldwiring_app;
          SELECT person_id,first_name,last_name FROM ref.person LIMIT 0;
          ROLLBACK;""")

    def preflight(self):
        require(self.m == json.loads(MANIFEST.read_text()), 'Unreviewed manifest')
        require(self.m['candidate'] == self.m['target'] == APP and self.m['shared'] == OLD
                and self.m['old_setup'] == OLD_SETUP and list(self.m['blobs']) == list(MIGRATIONS + VALIDATIONS),
                'Unreviewed release identities')
        for name, digest in self.m['helpers'].items():
            require(hashlib.sha256(Path(__file__).with_name(name).read_bytes()).hexdigest() == digest,
                    'Transport helper differs: '+name)
        self.mark('ONLINE PR470 release preflight')
        self.online(); self.baseline(); self.health(); self.database_preflight()
        require(not self.run(['ss', '-ltnH', 'sport = :8898']), 'Preview port occupied')
        self.source_lock = open('/home/msbadmin/setup-source-cache/.preview-source.lock', 'r')
        fcntl.flock(self.source_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        self.git('fetch', 'origin', '+refs/heads/main:refs/remotes/origin/main')
        self.git('merge-base', '--is-ancestor', APP, 'origin/main')
        self.git('merge-base', '--is-ancestor', OLD, APP)
        self.git('fetch', 'origin', '+refs/heads/main:refs/remotes/origin/main', root=SETUP)
        self.git('merge-base', '--is-ancestor', OLD_SETUP, APP, root=SETUP)
        require(self.git('rev-parse', APP+'^{tree}') == self.m['tree'], 'Accepted tree differs')
        for path, blob in self.m['blobs'].items():
            require(self.git('rev-parse', APP+':'+path) == blob, 'Reviewed SQL differs: '+path)
        self.worktree = tempfile.mkdtemp(prefix='msb-470-map-', dir='/tmp')
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
            CASE WHEN n.nspname='ref' AND c.relname='site_power_breaker' THEN 'to_jsonb(t)-''panel_outlets'''
                 ELSE 'to_jsonb(t)' END,
            n.nspname,c.relname)
          FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE c.relkind IN ('r','p')
          AND (n.nspname IN ('ref','ops','lor_snap')
            OR (n.nspname='public' AND c.relname IN
              ('directus_users','directus_roles','directus_policies','directus_permissions','directus_access')))
          ORDER BY n.nspname,c.relname
          \gexec
          ROLLBACK;""")

    def apply_migrations(self):
        self.baseline(); self.database_preflight(); self.frozen(self.controller('status'))
        for path in MIGRATIONS:
            self.mark('applying '+path)
            self.sql(self.git('show', APP+':'+path))

    def validate(self):
        for path in VALIDATIONS:
            self.sql(self.git('show', APP+':'+path))

    def new_rows_empty(self):
        # Existing breaker designations are an operator action, not migration data.
        self.sql("""BEGIN READ ONLY; DO $$ BEGIN
          IF EXISTS(SELECT 1 FROM ref.site_power_breaker WHERE panel_outlets)
          THEN RAISE EXCEPTION 'Unexpected migration-created panel designation'; END IF;
          END $$; ROLLBACK;""")

    def promote_source(self, baseline):
        self.baseline()
        self.mark('promoting accepted FieldWiring and Setup source while fenced')
        self.frozen(self.controller('status'))
        self.git('checkout', '--detach', APP, root=SETUP)
        self.git('merge', '--ff-only', APP)
        self.baseline(promoted=True)
        self.regression(REPO)

    def before_reopen(self, baseline):
        self.baseline(promoted=True); self.validate(); self.new_rows_empty(); self.frozen(self.controller('status'))
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
        self.online()
        snapshot = json.loads((self.root / 'snapshot.json').read_text())
        print('Rollback snapshot: '+snapshot['path'], flush=True)
        print('Snapshot SHA256: '+snapshot['sha256'], flush=True)
        print('Verified FieldWiring and Setup source: '+APP, flush=True)

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
    orchestrator.Deploy = MapDeploy
    raise SystemExit(orchestrator.main())
