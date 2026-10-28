"""Source/runtime checks for the isolated review entry; never connects to DB."""
import os
from pathlib import Path
import subprocess
import sys
import unittest


class PreviewEntryTests(unittest.TestCase):
    def test_isolated_get_only_routes_and_static_assets(self):
        code = '''
import importlib.util
from pathlib import Path
from werkzeug.test import Client
from werkzeug.wrappers import Response
path=Path('LOR/preview_sync/production/preview_entry.py')
spec=importlib.util.spec_from_file_location('lor2pc_test_preview',path)
module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
c=Client(module.application,Response)
for path in ['/lor2db/','/lor2db/pc/','/lor2db/pc/handoff.js','/lor2db/pc/downloads/MSB-PC-Preview-Updater-1.0.9-pilot.zip','/lor2db/lor2db.js','/lor2db/preflight/api/health']:
    result=c.get(path,environ_overrides={'REMOTE_ADDR':'127.0.0.1'})
    assert result.status_code==200,(path,result.status_code)
    assert result.headers['X-MSB-Review']=='DISPOSABLE-NO-WRITES'
assert c.get('/lor2db/pc/downloads/unknown.zip',environ_overrides={'REMOTE_ADDR':'127.0.0.1'}).status_code==404
assert c.post('/lor2db/preflight/api/parser/run',environ_overrides={'REMOTE_ADDR':'127.0.0.1'}).status_code==403
assert c.get('/lor2db/',environ_overrides={'REMOTE_ADDR':'192.168.5.4'}).status_code==403
assert c.get('/lor2db/../../backend.py',environ_overrides={'REMOTE_ADDR':'127.0.0.1'}).status_code==404
'''
        env = dict(os.environ, LOR2PC_PREVIEW_MODE='disposable',LOR2PC_PREVIEW_PORT='8898',
                   LOR2PC_PREVIEW_EMAIL='fixture@example.org',
                   LOR2PC_PREVIEW_DSN='host=127.0.0.1 port=15433 dbname=lor2pc_disposable user=lor_preflight_app password=fixture')
        result=subprocess.run([sys.executable,'-c',code],env=env,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        env['LOR2PC_PREVIEW_DSN']='host=127.0.0.1 port=5432 dbname=msb user=lor_preflight_app'
        result=subprocess.run([sys.executable,'-c',code],env=env,capture_output=True,text=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('Explicit isolated',result.stderr)


if __name__=='__main__':unittest.main()
