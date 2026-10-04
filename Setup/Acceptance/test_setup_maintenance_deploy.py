import json
from pathlib import Path
import tempfile
import unittest
import setup_maintenance_deploy as mod

MANIFEST = json.loads(Path(__file__).with_name('setup_205_069_release.json').read_text())

def frozen():
    return dict(state='MAINTENANCE', maintenance_started_at='current', last_error=None,
                gates={'freeze_proof': {'ok': True}},
                live={'database_fenced': True, 'sessions': [dict(usename='msbadmin', client_addr='local')]})

class FakeDeploy(mod.Deploy):
    def __init__(self, root, fail=None):
        super().__init__(MANIFEST, root)
        self.calls = []
        self.fail = fail
        self.captures = 0
    def controller(self, action, *args):
        self.calls.append(action)
        if self.fail == action:
            raise mod.Stop('injected ' + action)
        state = frozen()
        if action == 'snapshot':
            state['snapshot'] = dict(validated=True, ok=True, bytes=1, path=args[0], sha256='hash')
        if action == 'off':
            state = dict(state='ONLINE', last_error=None, gates={'online_proof': {'ok': True}},
                         live={'database_fenced': False})
        return state
    def capture(self):
        self.captures += 1
        if self.fail == 'invariants' and self.captures == 3:
            return 'changed'
        return 'stable'
    def sql(self, text):
        self.calls.append('sql')
        if self.fail == 'migration':
            raise mod.Stop('injected migration interruption')
        return ''
    def validate(self):
        self.calls.append('validate')
        if self.fail == 'validate':
            raise mod.Stop('injected validation')
    def git(self, *args, root=mod.REPO):
        self.calls.append('git:' + args[0])
        if args[0] == 'show':
            if args[1].endswith('production_backend.py'):
                return 'PRODUCTION_VERSION = "' + MANIFEST['version'] + '"'
            if args[1].endswith('setup_catalog_dirty_guard.js'):
                return "CLIENT_BUILD = '" + MANIFEST['version'] + "'"
            return 'BEGIN; approved migration; COMMIT;'
        if args[0] == 'rev-parse':
            return MANIFEST['target'] if root == mod.SETUP else MANIFEST['shared']
        return ''
    def run(self, args, **kwargs):
        self.calls.append(args[1] if len(args)>1 else args[0])
        if 'sha256sum' in args:
            return 'hash archive'
        if 'curl' in args:
            return json.dumps(dict(status='ok', data_mode='postgres', version=MANIFEST['version']))
        return ''

class SafetyTests(unittest.TestCase):
    def make(self, fail=None):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        deploy = FakeDeploy(Path(temporary.name)/'report', fail)
        self.addCleanup(deploy.log.close)
        return deploy
    def test_complete_order(self):
        d = self.make(); d.deploy()
        self.assertLess(d.calls.index('on'), d.calls.index('snapshot'))
        self.assertLess(d.calls.index('snapshot'), d.calls.index('sql'))
        self.assertLess(d.calls.index('validate'), d.calls.index('git:checkout'))
        self.assertLess(d.calls.index('git:checkout'), d.calls.index('off'))
        self.assertTrue(d.committed)
    def test_snapshot_failure_cannot_migrate_or_reopen(self):
        d = self.make('snapshot')
        with self.assertRaises(mod.Stop): d.deploy()
        self.assertNotIn('sql', d.calls); self.assertNotIn('off', d.calls)
        self.assertFalse(d.migration_started)
    def test_entry_failure_cannot_snapshot(self):
        d = self.make('on')
        with self.assertRaises(mod.Stop): d.deploy()
        self.assertNotIn('snapshot', d.calls); self.assertNotIn('off', d.calls)
    def test_interrupted_migration_not_assumed_rolled_back(self):
        d = self.make('migration')
        with self.assertRaises(mod.Stop): d.deploy()
        self.assertTrue(d.migration_started); self.assertFalse(d.committed)
        self.assertNotIn('off', d.calls)
    def test_committed_validation_failure_keeps_fence(self):
        d = self.make('validate')
        with self.assertRaises(mod.Stop): d.deploy()
        self.assertTrue(d.committed)
        self.assertNotIn('git:checkout', d.calls); self.assertNotIn('off', d.calls)
    def test_business_drift_cannot_promote_or_reopen(self):
        d = self.make('invariants')
        with self.assertRaises(mod.Stop): d.deploy()
        self.assertNotIn('git:checkout', d.calls); self.assertNotIn('off', d.calls)
    def test_exit_failure_not_success(self):
        d = self.make('off')
        with self.assertRaises(mod.Stop): d.deploy()
        self.assertEqual(d.stage, 'returning to service')
    def test_stale_proof_and_live_writer_are_rejected(self):
        for change in ({'state':'ONLINE'}, {'maintenance_started_at':None},
                       {'live': {'database_fenced':False, 'sessions':[]}},
                       {'live': {'database_fenced':True, 'sessions':[{'usename':'directus_app','client_addr':'remote'}]}}):
            state=frozen(); state.update(change)
            with self.assertRaises(mod.Stop): mod.Deploy.frozen(state)
    def test_current_deployment_stage_reaches_dashboard(self):
        d = self.make()
        d.mark('preflight PASS')
        self.assertNotIn('stage', d.calls)
        d.maintenance_started = True
        d.mark('migration committed')
        self.assertIn('stage', d.calls)

if __name__ == '__main__': unittest.main()
