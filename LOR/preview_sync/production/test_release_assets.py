"""Check critical deployable entry assets and comparison-only release gates."""
from pathlib import Path
import subprocess
import hashlib
import json
import zipfile
import re
import base64
import io
import unittest

ROOT = Path(__file__).resolve().parents[3]
PRODUCTION = Path(__file__).parent


class ReleaseAssetsTests(unittest.TestCase):
    def test_browser_entry_and_assets_are_tracked_and_exist(self):
        for name in ['LOR2DB/Application/landing/pc/index.html',
                     'LOR2DB/Application/landing/pc/handoff.js',
                     'LOR2DB/Application/landing/lor2db.css']:
            with self.subTest(name=name):
                self.assertTrue((ROOT / name).is_file())
                self.assertEqual(subprocess.run(['git', 'ls-files', '--error-unmatch', name], cwd=ROOT, capture_output=True).returncode, 0)

    def test_release_modes_keep_explicit_audit_override_and_opt_in_apply(self):
        self.assertIn('-AuditOnly', (PRODUCTION / 'Install-LOR2PC-Launcher.ps1').read_text())
        self.assertIn("action='store_true'", (PRODUCTION / 'Prepare-LOR2PC-Candidate.py').read_text())
        self.assertIn('$AuditOnly -or -not $prepared.Deployment.apply_enabled',
                      (PRODUCTION / 'Update_MSB_Previews.ps1').read_text())

    def test_download_matches_committed_runtime_and_comparison_guards(self):
        page = (ROOT/'LOR2DB/Application/landing/pc/index.html').read_text()
        path = re.search(r'id="install-updater"[^>]*href="([^"]+)"', page).group(1)
        self.assertEqual(path, 'downloads/MSB-PC-Preview-Updater-1.1.1-pilot.zip')
        with zipfile.ZipFile(ROOT/'LOR2DB/Application/landing/pc'/path) as archive:
            self.assertIsNone(archive.testzip())
            self.assertEqual(set(archive.namelist()), {'Setup MSB PC Preview Updater.vbs','READ ME Instructions.txt'})
            self.assertEqual(len(archive.namelist()), 2)
            setup = archive.read('Setup MSB PC Preview Updater.vbs').decode('ascii')
            encoded = ''.join(re.findall(r'payload = payload & "([A-Za-z0-9+/=]+)"', setup))
            payload = base64.b64decode(encoded, validate=True)
            expected = re.search(r"-ine '([a-f0-9]{64})'", setup).group(1)
            self.assertEqual(hashlib.sha256(payload).hexdigest(), expected)
            self.assertLess(setup.index('Get-FileHash'), setup.index('Expand-Archive'))
            self.assertLess(setup.index('Expand-Archive'), setup.index("& (Join-Path"))
            archive = zipfile.ZipFile(io.BytesIO(payload))
            self.assertIsNone(archive.testzip())
            names = archive.namelist()
            self.assertEqual(len(names), len(set(names)))
            self.assertTrue(all('/' not in n and '\\' not in n for n in names))
            metadata = json.loads(archive.read('DEPLOYMENT.json'))
            self.assertIs(metadata['apply_enabled'], True)
            self.assertEqual(metadata['acceptance'], 'CONTROLLED_APPLY_PILOT')
            self.assertEqual(metadata['version'], '1.1.1')
            for name, expected in metadata['files'].items():
                actual = archive.read(name)
                self.assertEqual(hashlib.sha256(actual).hexdigest(), expected)
                committed = subprocess.check_output(['git','show',metadata['source_commit']+':LOR/preview_sync/production/'+name], cwd=ROOT)
                self.assertEqual(actual, committed)
            self.assertIn(b'-AuditOnly', archive.read('Install-LOR2PC-Launcher.ps1'))
            self.assertIn(b'Assert-MSBLocalLibrary', archive.read('Install-LOR2PC-Launcher.ps1'))
            self.assertIn('READ ME - Programmer PC Setup.txt', names)

    def test_preflight_uses_read_only_transaction_and_no_service_restart(self):
        source = (PRODUCTION / 'deployment/Inspect-LOR2PC-Production.sh').read_text()
        self.assertIn('BEGIN READ ONLY;', source)
        self.assertNotIn('systemctl restart', source)
        self.assertNotIn('GRANT EXECUTE', source)


if __name__ == '__main__':
    unittest.main()
