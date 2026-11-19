"""Exercise the real PowerShell TCP handoff, without a browser or production.

Runs only the transport function extracted through the PowerShell AST. The
browser launch and UI event pump are replaced; no updater startup/apply executes.
"""
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import tempfile
import time
import unittest
from urllib.parse import urlparse, parse_qs

PWSH = os.environ.get('MSB_TEST_PWSH') or shutil.which('pwsh')


@unittest.skipUnless(PWSH, 'Set MSB_TEST_PWSH to a PowerShell executable')
class BrowserTransportTests(unittest.TestCase):
    def test_no_connection_timeout_is_logged_without_signin_assumption(self):
        with tempfile.TemporaryDirectory(prefix='msb299-no-connect-') as directory:
            root=Path(directory)
            source=Path(__file__).with_name('Update_MSB_Previews.ps1').resolve()
            def quote(path): return str(path).replace("'", "''")
            runner=root/'timeout.ps1'
            runner.write_text(f"""
$ErrorActionPreference='Stop'
$LogFolder='{quote(root / 'logs')}'
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile('{quote(source)}',[ref]$tokens,[ref]$errors)
foreach ($name in @('Write-HandoffTrace','Receive-BrowserSource')) {{
  $fn=$ast.FindAll({{param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name}}, $true)[0]
  . ([scriptblock]::Create($fn.Extent.Text.Replace('AddSeconds(120)', 'AddSeconds(1)')))
}}
function Invoke-SyncEvents {{}}
function Start-Process {{param($FilePath)}}
try {{ Receive-BrowserSource; throw 'Unexpected receipt' }} catch {{
  if ($_.Exception.Message -notlike 'Browser handoff timed out.*') {{ throw }}
}}
""")
            result=subprocess.run([PWSH,'-NoProfile','-File',str(runner)],capture_output=True,text=True,timeout=10)
            self.assertEqual(result.returncode,0,result.stderr)
            events=[json.loads(line) for line in (root/'logs/browser-handoff.log').read_text().splitlines()]
            self.assertEqual([e['event'] for e in events], ['LISTENING','TIMEOUT','STOPPED'])
            self.assertEqual(events[1]['reason'], 'connections=0;preflights=0;rejections=0')

    def test_real_loopback_rejects_bad_requests_then_accepts_exact_nonce_origin(self):
        with tempfile.TemporaryDirectory(prefix='msb299-transport-') as root:
            root = Path(root)
            source = Path(__file__).with_name('Update_MSB_Previews.ps1').resolve()
            launch, result = root / 'launch.txt', root / 'result.json'
            def quote(path): return str(path).replace("'", "''")
            runner = root / 'test.ps1'
            runner.write_text(f"""
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile('{quote(source)}',[ref]$tokens,[ref]$errors)
if ($errors.Count) {{ throw 'Updater syntax error' }}
$LogFolder='{quote(root / 'logs')}'
$trace=$ast.FindAll({{param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Write-HandoffTrace'}}, $true)[0]
. ([scriptblock]::Create($trace.Extent.Text))
$fn=$ast.FindAll({{param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Receive-BrowserSource'}}, $true)[0]
. ([scriptblock]::Create($fn.Extent.Text))
function Invoke-SyncEvents {{}}
function Start-Process {{param($FilePath) [IO.File]::WriteAllText('{quote(launch)}', $FilePath)}}
$body=Receive-BrowserSource
[IO.File]::WriteAllText('{quote(result)}', $body)
""", encoding='utf-8')
            process = subprocess.Popen([PWSH, '-NoProfile', '-File', str(runner)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                end = time.monotonic() + 15
                while not launch.exists() and process.poll() is None and time.monotonic() < end:
                    time.sleep(.05)
                self.assertTrue(launch.exists(), 'Transport failed to open listener')
                url = urlparse(launch.read_text(encoding='utf-8-sig'))
                self.assertEqual(url.scheme, 'https')
                self.assertEqual(url.netloc, 'my.sheboyganlights.org')
                args = parse_qs(url.fragment); port = int(args['port'][0]); nonce = args['nonce'][0]
                self.assertRegex(nonce, '^[a-f0-9]{64}$')
                def send(method='POST', path=None, origin='https://my.sheboyganlights.org', body='{}', extra=''):
                    request = (f'{method} /{nonce if path is None else path} HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nOrigin: {origin}\r\nContent-Type: text/plain\r\nContent-Length: {len(body)}\r\n{extra}\r\n{body}')
                    with socket.create_connection(('127.0.0.1', port), timeout=3) as client:
                        client.settimeout(3); client.sendall(request.encode('ascii'))
                        try: return client.recv(8192)
                        except ConnectionResetError: return b''
                for bad in [dict(origin='https://evil.example'), dict(path='wrong'), dict(method='GET'), dict(extra='Transfer-Encoding: chunked\r\n'), dict(extra='Origin: https://my.sheboyganlights.org\r\n'), dict(extra='NoSeparator\r\n')]:
                    self.assertNotIn(b'200 OK', send(**bad))
                    self.assertFalse(result.exists(), 'Rejected request leaked into accepted result')
                reply = send(method='OPTIONS', body='')
                self.assertIn(b'200 OK', reply)
                self.assertIn(b'Access-Control-Allow-Private-Network: true', reply)
                self.assertNotIn(b'Access-Control-Allow-Origin: *', reply)
                payload = json.dumps({'run_id': 32, 'name': 'MSB 🎄'}, ensure_ascii=True)
                self.assertIn(b'200 OK', send(body=payload))
                stdout, stderr = process.communicate(timeout=10)
                self.assertEqual(process.returncode, 0, stdout + stderr)
                self.assertEqual(json.loads(result.read_text(encoding='utf-8-sig')), json.loads(payload))
                trace=(root/'logs/browser-handoff.log').read_text()
                events=[json.loads(line) for line in trace.splitlines()]
                self.assertEqual(events[0]['event'], 'LISTENING')
                self.assertEqual(sum(x['event']=='REQUEST_REJECTED' for x in events), 6)
                rejected=[x for x in events if x['event']=='REQUEST_REJECTED']
                self.assertTrue(all(x['exception_type'] and x['line'] > 0 for x in rejected))
                self.assertIn('header-separator', [x['reason'] for x in rejected])
                self.assertIn('PREFLIGHT_REPLIED', [x['event'] for x in events])
                self.assertIn('DOCUMENT_RECEIVED', [x['event'] for x in events])
                self.assertEqual(events[-1]['event'], 'STOPPED')
                for sensitive in [nonce, payload, 'https://evil.example', 'MSB']:
                    self.assertNotIn(sensitive, trace)
                with self.assertRaises(OSError):
                    socket.create_connection(('127.0.0.1', port), timeout=1)
            finally:
                if process.poll() is None:
                    process.kill(); process.communicate()


if __name__ == '__main__':
    unittest.main()
