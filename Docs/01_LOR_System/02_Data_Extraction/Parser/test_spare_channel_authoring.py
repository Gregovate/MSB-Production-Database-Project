"""Execute the real parser against disposable renamed-channel fixtures."""
import subprocess
import sys
import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
PARSER=Path(__file__).with_name('parse_props_v7_scene_parser.py')
PREVIEW='a4066ac0-67bf-453f-b2f1-6c245024d65d'
def prop(id,name,comment,channel,master=''):
    return f'<PropClass id="{id}" Name="{name}" Comment="{comment}" DeviceType="LOR" ChannelGrid="Regular,22,{channel},{channel},0,White" MasterPropId="{master}"/>'
class SpareAuthoringTests(unittest.TestCase):
    def parse(self,props,success=True):
        tmp=tempfile.TemporaryDirectory();self.addCleanup(tmp.cleanup);root=Path(tmp.name)
        folder=root/'previews';folder.mkdir()
        (folder/'Food.lorprev').write_text(f'<PreviewClass id="{PREVIEW}" Name="Show Background Stage 04 Food Collection" Revision="97"><Scene id="scene" Name="Food"/>'+props+'</PreviewClass>')
        result=subprocess.run([sys.executable,str(PARSER),'--run-mode','TEST','--db-file',str(root/'output.db'),'--preview-folder',str(folder),'--reports-folder',str(root/'reports'),'--source-lor-version','6.6.12','--non-interactive'],capture_output=True)
        if not success:
            self.assertNotEqual(result.returncode,0);return
        self.assertEqual(result.returncode,0,(result.stdout+result.stderr).decode(errors='replace')[-3000:])
        with closing(sqlite3.connect(root/'output.db')) as db:
            self.assertEqual(db.execute('PRAGMA foreign_key_check').fetchall(),[])
            return db.execute('SELECT RawPropID,StartChannel FROM props ORDER BY RawPropID').fetchall(),db.execute('SELECT RawPropID,MasterPropId FROM subProps ORDER BY RawPropID').fetchall()
    def fixture(self,comment='SPARE'):
        return prop('base','FC 22-01 SPARE',comment,1)+prop('a','FC 22-15 Sponsor Signs',comment,15)+prop('b','FC 22-16 Sponsor Signs',comment,16)+prop('c','FC 22-Dup15 SPARE',comment,15,'a')+prop('d','FC 22-Dup16 SPARE',comment,16,'b')
    def test_two_renamed_spare_channels_keep_independent_masters_and_children(self):
        masters,children=self.parse(self.fixture())
        self.assertEqual(masters,[('a',15),('b',16),('base',1)])
        self.assertEqual(children,[('c',PREVIEW+':a'),('d',PREVIEW+':b')])
    def test_spare_comment_case_and_whitespace(self):
        masters,children=self.parse(self.fixture(' spare '));self.assertEqual(len(masters),3);self.assertEqual(len(children),2)
    def test_assigned_display_comment_overrides_old_spare_channel_name(self):
        masters,children=self.parse(prop('a','Old SPARE 15','FC-Sponsor',15)+prop('b','Old SPARE 16','FC-Sponsor',16))
        self.assertEqual(masters,[('a',15)]);self.assertEqual(children,[('b',PREVIEW+':a')])
    def test_distinct_display_comments_stay_distinct(self):
        masters,children=self.parse(prop('a','Sponsor channel 15','FC-Sponsor-A',15)+prop('b','Sponsor channel 16','FC-Sponsor-B',16))
        self.assertEqual(masters,[('a',15),('b',16)]);self.assertEqual(children,[])
    def test_missing_explicit_master_is_not_silently_repaired(self):
        self.parse(prop('a','Duplicate SPARE','SPARE',15,'missing'),success=False)
if __name__=='__main__':unittest.main()
