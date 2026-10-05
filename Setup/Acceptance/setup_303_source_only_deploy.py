"""Pinned #303 source-only installer; follows Server Management's Setup runbook.

No SQL mutations, environment changes, maintenance entry, or shared promotion.
The previous application SHA is the rollback unit. Reports stay on the server.
"""
from datetime import datetime, timezone
import fcntl
import json
from pathlib import Path
import subprocess
import signal
import sys
import time

TARGET = '00de4635b0ee49658f2e6b5782d758e91054ca02'
EXPECTED_OLD = '0783b76bfdaa5c794a3922dd5e1e0d37b788a2c9'
OLD_VERSION = 'V0.3.39-tablet-launch-debug'
VERSION = 'V0.3.39-tablet-launch-debug'
SHARED = '6dd05c4aa5ef8f50fe172145c3ae281cc245a101'
REPO = '/opt/fieldwiring'
LIVE = '/opt/msb-setup'
PYTHON = '/opt/fieldwiring/.venv/bin/python'
HEALTH = 'http://192.168.5.9:8794/api/health'
FOCUSED = [
    'Setup/Application/test_setup_production_contract.py',
    'Setup/Application/test_setup_scheduling_board_contract.py',
    'Setup/Application/test_setup_material_readiness_contract.py',
    'Setup/Application/test_setup_88_pick_mode_contract.py',
    'Setup/Application/test_setup_next_pass_contract.py',
]


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


class Installer:
    def __init__(self):
        stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        self.root = Path('/home/msbadmin/setup-deployment-reports') / ('PR303-' + stamp)
        self.root.mkdir(parents=True)
        self.log = (self.root / 'report.txt').open('w', buffering=1)
        self.candidate = '/tmp/' + self.root.name
        self.advanced = False
        self.worktree_created = False
        self.before = None

    def run(self, argv, input=None, timeout=300):
        self.log.write(repr(argv) + '\n')
        result = subprocess.run(argv, input=input, text=True, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout)
        self.log.write(result.stdout + '\n')
        require(result.returncode == 0, 'Command failed; inspect retained report')
        return result.stdout.strip()

    def git(self, *args, root=REPO):
        return self.run(['sudo', 'env', 'GIT_TERMINAL_PROMPT=0', 'git', '-C', root, *args])

    def health(self, version):
        for _ in range(30):
            try:
                self.run(['systemctl', 'is-active', 'msb-setup.service'])
                data = json.loads(self.run(['curl', '-fsS', '--max-time', '3', HEALTH]))
                require(data.get('status') == 'ok' and data.get('data_mode') == 'postgres'
                        and data.get('version') == version, 'Unexpected Setup health/version')
                return
            except Exception:
                time.sleep(1)
        raise RuntimeError('Setup health/version timed out')

    def fingerprint(self):
        # Read-only query matches the accepted source-only fingerprint boundary.
        tables = ['ref.setup_task', 'ref.setup_resource', 'ref.setup_task_resource',
                  'ops.setup_session', 'ops.setup_session_task', 'ops.setup_work_day']
        queries = [f"SELECT '{table}' name,jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text) v FROM {table} t"
                   for table in tables]
        sql = "BEGIN READ ONLY; SELECT md5(string_agg(v::text,'' ORDER BY name)) FROM (" + ' UNION ALL '.join(queries) + ") q; COMMIT;"
        value = self.run(['sudo', 'docker', 'exec', '-i', 'msb-postgres', 'psql',
                          '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-U', 'msbadmin', '-d', 'msb'], input=sql)
        require(len(value) == 32 and all(c in '0123456789abcdef' for c in value), 'Invalid fingerprint')
        return value

    def regression(self, root, tests):
        # Paths and test names are immutable release constants, never user input.
        command = 'cd ' + root + ' && ' + PYTHON + ' -m pytest -q -p no:cacheprovider ' + ' '.join(tests)
        return self.run(['sudo', '-u', 'fieldwiring', '-H', 'env',
                         'PYTHONDONTWRITEBYTECODE=1', 'bash', '-c', command], timeout=600)

    def rollback(self):
        if self.advanced:
            self.git('checkout', '--detach', EXPECTED_OLD, root=LIVE)
            self.run(['sudo', 'systemctl', 'restart', 'msb-setup.service'])
            self.health(OLD_VERSION)
            require(self.git('rev-parse', 'HEAD', root=LIVE) == EXPECTED_OLD, 'Rollback SHA differs')
            require(self.before is None or self.fingerprint() == self.before, 'Rollback data fingerprint differs; inspect report')
            self.log.write('SOURCE ROLLBACK PASS; database not mutated\n')

    def deploy(self):
        require(self.git('rev-parse', 'HEAD', root=LIVE) == EXPECTED_OLD, 'Live Setup changed: STOP before mutation')
        require(self.git('rev-parse', 'HEAD') == SHARED, 'Shared checkout changed: STOP')
        require(not self.git('status', '--porcelain', root=LIVE) and not self.git('status', '--porcelain'), 'Dirty checkout: STOP')
        require(not self.git('branch', '--show-current', root=LIVE), 'Live Setup is not detached: STOP')
        self.health(OLD_VERSION)
        self.before = self.fingerprint()
        self.git('fetch', 'origin', '+refs/heads/main:refs/remotes/origin/main')
        self.git('merge-base', '--is-ancestor', TARGET, 'origin/main')
        self.git('merge-base', '--is-ancestor', EXPECTED_OLD, TARGET)
        # The exact browser-approved candidate is pinned; no new migration can
        # enter through a newer branch head or deployment tooling descendant.
        require(not self.git('diff', '--name-only', EXPECTED_OLD, TARGET, '--', 'Setup/Database'), 'Database source changed: STOP')
        require(self.git('show', TARGET + ':Setup/Application/production_backend.py').count('PRODUCTION_VERSION = "' + VERSION + '"') == 1, 'Server identity differs')
        require("CLIENT_BUILD = '" + VERSION + "'" in self.git('show', TARGET + ':Setup/Application/setup_catalog_dirty_guard.js'), 'Client identity differs')
        self.git('worktree', 'add', '--detach', self.candidate, TARGET)
        self.worktree_created = True
        self.run(['sudo', 'python3', self.candidate + '/Setup/Acceptance/check_setup_ui_update_date.py', '--repository', REPO, '--target', TARGET])
        self.regression(self.candidate, ['Setup/Application'])
        require(self.fingerprint() == self.before, 'Setup data changed during preflight: STOP')
        require(self.git('rev-parse', 'HEAD', root=LIVE) == EXPECTED_OLD and not self.git('status', '--porcelain', root=LIVE), 'Live drift during preflight: STOP')
        self.log.write('Authority: Gregovate/MSB-Server-Management — docs/server/Setup_Source_Only_Application_Deployment_Runbook.md\nProcedure: Controlled Production Mutation\nThis step: advance only /opt/msb-setup to ' + TARGET + '\n')
        # Set the rollback flag before checkout: a partially failed command must
        # also return through the documented source-only rollback path.
        self.advanced = True
        self.git('checkout', '--detach', TARGET, root=LIVE)
        require(self.git('rev-parse', 'HEAD', root=LIVE) == TARGET and not self.git('status', '--porcelain', root=LIVE), 'Deployed identity differs')
        self.run(['sudo', 'systemctl', 'restart', 'msb-setup.service'])
        self.health(VERSION)
        self.regression(LIVE, FOCUSED)
        require(self.git('rev-parse', 'HEAD') == SHARED, 'Shared checkout moved')
        require(self.fingerprint() == self.before, 'Setup data changed during deployment: inspect report')
        (self.root / 'result.json').write_text(json.dumps({'result': 'PASS', 'old_setup': EXPECTED_OLD,
            'target': TARGET, 'version': VERSION, 'fingerprint': self.before,
            'migration': None, 'operator_production_check': 'PENDING'}, indent=2) + '\n')


def interrupted(signum, frame):
    raise RuntimeError('Deployment interrupted by signal ' + str(signum))


def main():
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGINT, interrupted)
    # One directing chat owns this window; the cooperative lock blocks duplicate
    # instances but does not replace that operational rule.
    with open('/home/msbadmin/.msb-production-deploy.lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        installer = Installer()
        try:
            installer.deploy()
        except Exception as exc:
            installer.log.write('STOP ' + repr(exc) + '\n')
            try:
                installer.rollback()
            except Exception as recovery:
                installer.log.write('ROLLBACK FAILED ' + repr(recovery) + '\n')
            print('STOP: do not rerun; report: ' + str(installer.root))
            return 1
        finally:
            if installer.worktree_created:
                try:
                    installer.git('worktree', 'remove', '--force', installer.candidate)
                except Exception as cleanup:
                    installer.log.write('CLEANUP FAILED ' + repr(cleanup) + '\n')
            installer.log.close()
        print('PASS: Setup V0.3.39 installed; protected browser check pending; report: ' + str(installer.root))
        return 0


if __name__ == '__main__':
    sys.exit(main())
