"""#483 source-only theme release using the existing #305 deployment engine."""
from datetime import datetime, timezone
from pathlib import Path
import signal
import setup_305_source_only_deploy as engine

TARGET = 'fdf1549e4215c305cb82b3e6e70e327ade574dd2'
OLD = '37a02e2d9460d115e1d7255833b264a6bb5d8d80'
VERSION = 'V0.3.111-explicit-no-work'


class ThemeInstaller(engine.Installer):
    def __init__(self):
        stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
        self.root = Path('/home/msbadmin/setup-deployment-reports') / ('PR483-Source-' + stamp)
        self.root.mkdir(parents=True,exist_ok=False)
        self.log = (self.root/'report.txt').open('w',buffering=1)
        self.candidate = '/tmp/'+self.root.name
        self.advanced = self.worktree_created = False
        self.before = None


def configure():
    engine.TARGET, engine.EXPECTED_OLD = TARGET, OLD
    engine.VERSION = engine.OLD_VERSION = VERSION
    # Shared checkout stays unchanged; pin current evidence for drift checks.
    engine.SHARED = engine.subprocess.check_output([
        'sudo','env','GIT_TERMINAL_PROMPT=0','git','-C',engine.REPO,'rev-parse','HEAD'
    ],text=True).strip()
    engine.FOCUSED = list(engine.FOCUSED) + ['Setup/Application/test_205_perform_theme.py']


def main():
    configure()
    signal.signal(signal.SIGTERM,engine.interrupted)
    signal.signal(signal.SIGINT,engine.interrupted)
    with open('/home/msbadmin/.msb-production-deploy.lock','a') as lock:
        engine.fcntl.flock(lock,engine.fcntl.LOCK_EX | engine.fcntl.LOCK_NB)
        installer = ThemeInstaller()
        status = 0
        try:
            installer.deploy()
        except Exception as exc:
            installer.log.write('STOP '+repr(exc)+'\n')
            try:
                installer.rollback()
            except Exception as recovery:
                installer.log.write('ROLLBACK FAILED '+repr(recovery)+'\n')
            status = 1
        finally:
            try:
                installer.cleanup()
            except Exception as cleanup:
                installer.log.write('CLEANUP FAILED '+repr(cleanup)+'\n')
                status = 1
            installer.log.close()
        if status:
            print('STOP: deployment or cleanup failed; do not rerun; report: '+str(installer.root))
        else:
            print('PASS: PR483 theme source installed; protected light/dark check pending; report: '+str(installer.root))
        return status


if __name__ == '__main__':
    raise SystemExit(main())
