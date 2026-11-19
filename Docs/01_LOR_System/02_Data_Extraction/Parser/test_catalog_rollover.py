"""Reconciled-run rollover never requires overwritten originals or trusts current XML alone."""
import hashlib
import json
import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from unittest.mock import patch
from preview_catalog import Catalog, capture, source_digest, prove_database_rows, RECOVERY_TABLES

RAW='<PreviewClass id="p" Name="Stage" Revision="1"><Scene id="s" Name="Scene"/><PropClass id="a" Name="Channel" Comment="Display" DeviceType="LOR" ChannelGrid="Regular,10,1,16"/></PreviewClass>'

class RolloverTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.folder=self.root/'Database Previews V6.6.12';self.folder.mkdir()
        self.file=self.folder/'Stage.lorprev';self.file.write_text(RAW)
        self.files=capture(self.folder);self.store=self.root/'evidence'
        self.accepted=dict(schema_version=1,status='COMPLETED',validation='PASSED',lor_version='6.6.12',source_folder=str(self.folder),evidence_id='a'*64,source_manifest_sha256=source_digest(self.files),source_sqlite_sha256='b'*64,run_id=34,previews=[{k:self.files[0][k] for k in ('filename','preview_id','name','revision')}])
    def db(self,path,value='protected',background='old',parser_hash='c'*64):
        with closing(sqlite3.connect(path)) as db, db:
            for t in RECOVERY_TABLES:
                db.execute('CREATE TABLE "'+t+'" (id TEXT, Value TEXT'+(', BackgroundFile TEXT' if t=='scenes' else '')+')')
                if t=='scenes':db.execute('INSERT INTO scenes VALUES (?,?,?)',('id',value,background))
                else:db.execute('INSERT INTO "'+t+'" VALUES (?,?)',('id',value))
            db.execute('CREATE TABLE parser_run (ParserSHA256 TEXT,SourceManifestSHA256 TEXT,SourceLORVersion TEXT,ValidationStatus TEXT,Status TEXT)')
            db.execute('INSERT INTO parser_run VALUES (?,?,?,?,?)',(parser_hash,self.accepted['source_manifest_sha256'],'6.6.12','PASSED','COMPLETE'))
    def test_snapshot_rolls_over_after_original_export_overwritten(self):
        original=self.root/'accepted.db';self.db(original);h=hashlib.sha256(original.read_bytes()).hexdigest();self.accepted['source_sqlite_sha256']=h
        c=Catalog(self.store,self.folder,'6.6.12');c.retain_database_snapshot(original,h,self.accepted['source_manifest_sha256'])
        self.file.write_text(RAW.replace('Revision="1"','Revision="2"').replace('Name="Stage"','Name="Stage New"'))
        review=c.review(self.accepted,'publisher');self.assertTrue(review['can_publish']);self.assertFalse(review['database_contract_review_required'])
        self.assertEqual(c.read(c.context(self.accepted)/'baseline.json')['files'][0]['sha256'],self.files[0]['sha256'])
    def test_snapshot_rejects_unparsed_export(self):
        original=self.root/'accepted.db';self.db(original);h=hashlib.sha256(original.read_bytes()).hexdigest()
        self.file.write_text(RAW.replace('Regular,10','Regular,11'))
        with self.assertRaisesRegex(ValueError,'Master changed after parsing'):Catalog(self.store,self.folder,'6.6.12').retain_database_snapshot(original,h,self.accepted['source_manifest_sha256'])
        self.assertFalse((self.store/'database-snapshots').exists())
    def test_proof_allows_only_declared_presentation_fields(self):
        a=self.root/'a.db';b=self.root/'b.db';self.db(a);self.db(b,background='new')
        self.assertEqual(prove_database_rows(a,b),sorted(RECOVERY_TABLES))
    def test_proof_rejects_changed_protected_rows(self):
        a=self.root/'a.db';b=self.root/'b.db';self.db(a);self.db(b,value='different controller')
        with self.assertRaisesRegex(ValueError,'database differences'):prove_database_rows(a,b)
    def test_proof_closes_connections_on_success_and_difference(self):
        a=self.root/'a.db';b=self.root/'b.db';self.db(a);self.db(b)
        original=sqlite3.connect
        opened=[]
        def tracked(*args,**kwargs):
            db=original(*args,**kwargs);opened.append(db);return db
        with patch('preview_catalog.sqlite3.connect',side_effect=tracked):
            prove_database_rows(a,b)
            with closing(original(b)) as db, db:db.execute("UPDATE props SET Value='changed'")
            with self.assertRaisesRegex(ValueError,'database differences'):prove_database_rows(a,b)
        self.assertEqual(len(opened),4)
        for db in opened:
            with self.assertRaises(sqlite3.ProgrammingError):db.execute('SELECT 1')
    def test_channel_name_exception_requires_display_comment(self):
        a=self.root/'a.db';b=self.root/'b.db';self.db(a);self.db(b)
        for path,name in ((a,'Old Channel'),(b,'New Channel')):
            with closing(sqlite3.connect(path)) as db, db:
                db.execute('ALTER TABLE props ADD COLUMN Name TEXT')
                db.execute('ALTER TABLE props ADD COLUMN LORComment TEXT')
                db.execute('UPDATE props SET Name=?,LORComment=?',(name,'Display-01'))
        prove_database_rows(a,b)
        for path in (a,b):
            with closing(sqlite3.connect(path)) as db, db:db.execute("UPDATE props SET LORComment='' ")
        with self.assertRaisesRegex(ValueError,'database differences'):prove_database_rows(a,b)
    def test_recovery_rejects_wrong_sqlite_before_parse(self):
        a=self.root/'a.db';self.db(a);parser=self.root/'parser.py';parser.write_text('raise Exception("must not run")')
        self.file.write_text(RAW.replace('Revision="1"','Revision="2"'))
        c=Catalog(self.store,self.folder,'6.6.12',recovery_db=a,parser_path=parser)
        with self.assertRaisesRegex(ValueError,'exact reconciled'):c.review(self.accepted,'publisher')
        self.assertFalse(c.context(self.accepted).exists())
    def test_recovery_proves_rows_preserves_source_and_registers_provenance(self):
        # Execute a disposable parser process using only temporary fixtures.
        parser=self.root/'parser.py'
        parser.write_text('import sys,shutil\nfrom pathlib import Path\nargs=sys.argv\nshutil.copyfile(Path(__file__).with_name("accepted.db"),args[args.index("--db-file")+1])\n')
        a=self.root/'accepted.db';self.db(a,parser_hash=hashlib.sha256(parser.read_bytes()).hexdigest())
        self.accepted['source_sqlite_sha256']=hashlib.sha256(a.read_bytes()).hexdigest()
        self.file.write_text(RAW.replace('Revision="1"','Revision="2"'));before=self.file.read_bytes();db_before=a.read_bytes()
        c=Catalog(self.store,self.folder,'6.6.12',recovery_db=a,parser_path=parser)
        review=c.review(self.accepted,'publisher');self.assertTrue(review['can_publish'])
        baseline=c.read(c.context(self.accepted)/'baseline.json');self.assertEqual(baseline['recovery_proof']['sqlite_sha256'],self.accepted['source_sqlite_sha256'])
        self.assertEqual(self.file.read_bytes(),before);self.assertEqual(a.read_bytes(),db_before)
    def test_older_baseline_and_publication_are_not_rewritten(self):
        c=Catalog(self.store,self.folder,'6.6.12');old=dict(self.accepted,evidence_id='d'*64,run_id=32)
        r=c.review(old,'publisher');c.publish(old,'publisher',r['review_id'])
        saved={p:p.read_bytes() for p in c.context(old).rglob('*.json')}
        c.review(self.accepted,'publisher')
        self.assertTrue(all(p.read_bytes()==raw for p,raw in saved.items()))
if __name__=='__main__':unittest.main()
