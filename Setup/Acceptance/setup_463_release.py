"""Accepted PR463 profile of the existing maintenance controller/orchestrator.

Apply the four accepted incremental migrations and application promotions inside
the existing fence. Reference catalog seeds do not create installed equipment.
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

APP = '820b154cd664f0cac0d1d8dfd38e47b4fe19df9c'
OLD = '2548edd130b5cebad33a44786bc1811c2b089bf8'
OLD_SETUP = '72a94be772f2e4ae8bfaed74051f667fc87201a6'
MIGRATIONS = ('Database/EngineeringTools/sql/171_equipment_lifecycle.sql',
              'Database/EngineeringTools/sql/171_equipment_catalog.sql',
              'Setup/Database/077_add_setup_controller_location.sql',
              'Setup/Database/078_add_setup_container_pickup.sql')
VALIDATIONS = ('Database/Acceptance/171_equipment_catalog_validation.sql',
               'Setup/Acceptance/setup_88_controller_location_validation.sql',
               'Setup/Acceptance/setup_88_container_pickup_validation.sql')
MANIFEST = Path(__file__).with_name('setup_463_release.json')
LIVE_SCAN = '/opt/directus/extensions/directus-extension-scan/dist/index.js'
OLD_SCAN = 'c2bc2d4e7d9d7ff86c57a7d30a52d427f9897f538aa2ce68c5ffc4f0a305bfea'



class EquipmentDeploy(Deploy):
    def baseline(self, promoted=False):
        for root, expected in ((REPO, APP if promoted else OLD), (SETUP, APP if promoted else OLD_SETUP)):
            require(self.git('rev-parse', 'HEAD', root=root) == expected and
                    not self.git('status', '--porcelain', root=root), 'Live source drift: '+root)

    def health(self, new=False):
        for port, version in ((8790, 'V0.4.31-field-review' if new else 'V0.4.29-breaker-correction'),
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

    def database_preflight(self):
        # Reject replay/partial install before entering maintenance.
        self.sql("""BEGIN READ ONLY; DO $$ BEGIN
          IF (SELECT md5(prosrc) FROM pg_proc WHERE oid='ref.site_power_command(text,uuid,bigint,text,bigint,jsonb)'::regprocedure)
              IS DISTINCT FROM '906289a801cae2e2d85957898984f031'
          OR (SELECT md5(prosrc) FROM pg_proc WHERE oid='ref.site_power_snapshot(text)'::regprocedure)
              IS DISTINCT FROM '1409b5a8bada107ecfd5954c8f49a18d'
          OR to_regclass('ops.site_equipment_event') IS NOT NULL
          OR to_regclass('ref.site_equipment_model') IS NOT NULL
          OR to_regclass('ref.site_equipment_type') IS NOT NULL
          OR to_regclass('ops.setup_container_pickup_event') IS NOT NULL
          OR EXISTS(SELECT 1 FROM pg_attribute WHERE attrelid='ops.setup_movement_event'::regclass
                    AND attname IN ('controller_id','controller_request') AND NOT attisdropped)
          THEN RAISE EXCEPTION 'Unexpected PR463 baseline; no replay'; END IF;
          END $$; ROLLBACK;""")

    def preflight(self):
        require(self.m == json.loads(MANIFEST.read_text()), 'Unreviewed manifest')
        require(self.m['candidate'] == self.m['target'] == APP and self.m['shared'] == OLD
                and self.m['old_setup'] == OLD_SETUP and list(self.m['blobs']) == list(MIGRATIONS + VALIDATIONS),
                'Unreviewed release identities')
        for name, digest in self.m['helpers'].items():
            require(hashlib.sha256(Path(__file__).with_name(name).read_bytes()).hexdigest() == digest,
                    'Transport helper differs: '+name)
        self.mark('ONLINE PR463 release preflight')
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
        self.worktree = tempfile.mkdtemp(prefix='msb-463-equipment-', dir='/tmp')
        os.chmod(self.worktree, 0o755)
        self.git('worktree', 'add', '--detach', self.worktree, APP)
        self.regression(self.worktree)
        # ONLINE syntax/read proof only. The stable baseline starts after fencing.
        self.capture()
        self.scan_isolated()
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
            CASE WHEN n.nspname='ref' AND c.relname='site_power_device' THEN 'to_jsonb(t)-''equipment_model_id'''
                 WHEN n.nspname='ops' AND c.relname='setup_movement_event' THEN 'to_jsonb(t)-''controller_id''-''controller_request'''
                 ELSE 'to_jsonb(t)' END,
            n.nspname,c.relname)
          FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE c.relkind IN ('r','p')
          AND n.nspname||'.'||c.relname NOT IN ('ref.site_equipment_type','ref.site_equipment_model',
            'ops.site_equipment_event','ops.setup_container_pickup_event') AND (n.nspname IN ('ref','ops','lor_snap')
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
        self.sql("""BEGIN READ ONLY; DO $$ BEGIN
          IF EXISTS(SELECT 1 FROM ops.site_equipment_event)
          OR EXISTS(SELECT 1 FROM ops.setup_container_pickup_event)
          OR EXISTS(SELECT 1 FROM ref.site_power_device WHERE equipment_model_id IS NOT NULL)
          OR EXISTS(SELECT 1 FROM ops.setup_movement_event WHERE controller_id IS NOT NULL OR controller_request IS NOT NULL)
          THEN RAISE EXCEPTION 'Unexpected migration-created operational data'; END IF;
          END $$; ROLLBACK;""")

    def scan_arguments(self):
        return ['--candidate-sha', APP, '--candidate-artifact-sha', self.m['scan_sha256'],
                '--expected-live-scan-sha', OLD_SCAN]

    def scan_isolated(self):
        require(self.run(['sudo','sha256sum',LIVE_SCAN]).split()[0] == OLD_SCAN, 'Scan baseline changed')
        root = Path(__file__).parent
        self.mark('isolated Scan validation before maintenance')
        self.run(['sudo','bash',str(root/'validate_scan_extension_isolated.sh'),
                  '--bundle',str(root/'scan-candidate.tar'), *self.scan_arguments()], timeout=300)

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
        # Surface the already validated receipt so operator closeout needs no
        # separate forensic command to find the rollback archive and hash.
        # Database/apps are proven ONLINE before the existing Scan source-only gate.
        self.online()
        self.mark('database/apps ONLINE; installing accepted Scan via existing runner')
        root = Path(__file__).parent
        self.run(['sudo','bash',str(root/'deploy_scan_extension_issue219.sh'),
                  '--candidate-file',str(root/'scan-index.js'), *self.scan_arguments()], timeout=300)
        page = self.run(['curl','-fsS','--max-time','15','-H','Host: my.sheboyganlights.org',
                         'http://127.0.0.1:8055/scan/CONT/216'])
        require('https://my.sheboyganlights.org/setup/container-pickups/?asset=CONT:216' in page,
                'Live container pickup handoff missing')
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
    orchestrator.Deploy = EquipmentDeploy
    raise SystemExit(orchestrator.main())
