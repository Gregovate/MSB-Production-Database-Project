"""Exercise actual metadata preparation in a tiny disposable committed repository."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

SOURCE=Path(__file__).with_name('Prepare-LOR2PC-Candidate.py')

class ReleaseModeTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(prefix='msb-release-mode-')
        self.addCleanup(self.temp.cleanup)
        self.base=Path(self.temp.name); self.repo=self.base/'repo'
        self.production=self.repo/'LOR/preview_sync/production'; self.production.mkdir(parents=True)
        self.script=self.production/SOURCE.name; shutil.copy2(SOURCE,self.script)
        for name in ['Update_MSB_Previews.ps1','Install-LOR2PC-Launcher.ps1','Install MSB PC Preview Updater.vbs','READ ME - Programmer PC Setup.txt']:
            (self.production/name).write_text('disposable fixture')
        artifacts=self.production.parent/'artifacts'; artifacts.mkdir()
        (artifacts/'MSB Preview Update Tree v2.ico').write_bytes(b'fixture')
        for command in [['git','init'],['git','add','.'],['git','-c','user.name=Fixture','-c','user.email=fixture@example.invalid','commit','-m','fixture']]:
            subprocess.run(command,cwd=self.repo,capture_output=True,check=True)

    def prepare(self,*args):
        target=self.base/'prepared'
        result=subprocess.run([sys.executable,str(self.script),str(target),*args],capture_output=True,text=True)
        return result,target

    def test_default_is_audit_only(self):
        result,target=self.prepare()
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIs(json.loads((target/'DEPLOYMENT.json').read_text())['apply_enabled'],False)

    def test_explicit_pilot_enables_apply(self):
        result,target=self.prepare('--enable-apply')
        self.assertEqual(result.returncode,0,result.stderr)
        metadata=json.loads((target/'DEPLOYMENT.json').read_text())
        self.assertIs(metadata['apply_enabled'],True)
        self.assertEqual(metadata['acceptance'],'CONTROLLED_APPLY_PILOT')

    def test_dirty_source_blocks_even_explicit_pilot(self):
        (self.production/'Update_MSB_Previews.ps1').write_text('uncommitted')
        result,target=self.prepare('--enable-apply')
        self.assertNotEqual(result.returncode,0)
        self.assertFalse(target.exists())

if __name__=='__main__':unittest.main()
