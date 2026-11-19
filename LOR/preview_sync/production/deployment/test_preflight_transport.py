"""Reproduce native-argument quote loss using harmless local shell fixtures."""
import base64
from pathlib import Path
import subprocess
import unittest


class PreflightTransportTests(unittest.TestCase):
    def test_lost_bash_c_quotes_can_silently_return_success(self):
        script = b'#!/usr/bin/env bash\nprintf "PREFLIGHT_EXECUTED\\n"\n'
        encoded = base64.b64encode(script).decode()
        result = subprocess.run('bash -c $(printf %s ' + encoded + ' | base64 -d)', shell=True, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, '')

    def test_quote_free_transport_executes_entire_script(self):
        encoded = base64.b64encode(b'#!/usr/bin/env bash\nprintf "PREFLIGHT_EXECUTED\\n"\n').decode()
        result = subprocess.run('printf %s ' + encoded + ' | base64 -d | bash', shell=True, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, 'PREFLIGHT_EXECUTED\n')

    def test_script_failure_propagates(self):
        encoded = base64.b64encode(b'#!/usr/bin/env bash\nexit 37\n').decode()
        result = subprocess.run('printf %s ' + encoded + ' | base64 -d | bash', shell=True, capture_output=True, text=True)
        self.assertEqual(result.returncode, 37)
        source = Path(__file__).with_name('Run-LOR2PC-ReadOnly-Preflight.ps1').read_text()
        self.assertIn("' | base64 -d | bash'", source)


if __name__ == '__main__':
    unittest.main()
