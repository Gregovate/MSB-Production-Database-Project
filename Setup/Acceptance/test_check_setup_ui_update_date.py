import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from check_setup_ui_update_date import check

class DateGateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(self.tmp.name)
        self.git('init', '-q')
        self.git('config', 'user.name', 'Test')
        self.git('config', 'user.email', 'test@example.invalid')
        self.ui = self.repo / 'Setup/Application'
        self.ui.mkdir(parents=True)
        (self.ui / 'production.html').write_text('Updated 2026-10-04')
        self.commit('2026-10-04', 'first UI')
    def git(self, *args, env=None):
        subprocess.run(['git', '-C', str(self.repo), *args], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, env=env)
    def commit(self, day, message):
        env = os.environ.copy()
        env.update(GIT_AUTHOR_DATE=day+'T12:00:00Z', GIT_COMMITTER_DATE=day+'T12:00:00Z')
        self.git('add', '.')
        self.git('commit', '-qm', message, env=env)
    def test_current_date_passes(self):
        self.assertEqual(check(self.repo), '2026-10-04')
    def test_new_ui_rejects_stale_footer(self):
        (self.ui/'setup.css').write_text('body {color:blue}')
        self.commit('2026-10-05', 'new UI')
        with self.assertRaises(RuntimeError): check(self.repo)
    def test_later_documentation_does_not_change_ui_date(self):
        (self.repo/'README.md').write_text('documentation')
        self.commit('2026-10-05', 'docs only')
        self.assertEqual(check(self.repo), '2026-10-04')
    def test_updated_footer_passes_after_ui_change(self):
        (self.ui/'setup.css').write_text('body {color:blue}')
        (self.ui/'production.html').write_text('Updated 2026-10-05')
        self.commit('2026-10-05', 'new UI with current date')
        self.assertEqual(check(self.repo), '2026-10-05')

if __name__ == '__main__': unittest.main()

