"""Catalog publication is authorized by exact passed parser evidence, without ingest."""
import hashlib
import sqlite3
import tempfile
import unittest
from contextlib import closing
from pathlib import Path
from preview_catalog import Catalog,capture,source_digest

RAW='<PreviewClass id="p" Name="Show Background Stage 19 Test" Revision="1"><Scene id="s" Name="Stage"/><PropClass id="a" Name="Channel" Comment="Display" DeviceType="LOR" ChannelGrid="Regular,10,1,16"/></PreviewClass>'
class ParserAuthorityTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.folder=self.root/'Database Previews V6.6.12';self.folder.mkdir()
        self.file=self.folder/'Stage.lorprev';self.file.write_text(RAW)
        old=capture(self.folder)
        self.accepted=dict(schema_version=1,status='COMPLETED',validation='PASSED',lor_version='6.6.12',source_folder=str(self.folder),evidence_id='a'*64,source_manifest_sha256=source_digest(old),source_sqlite_sha256='b'*64,run_id=34,previews=[{k:old[0][k] for k in ('filename','preview_id','name','revision')}])
        # New controller assignment remains un-ingested.
        self.file.write_text(RAW.replace('Regular,10','Regular,11').replace('Revision="1"','Revision="2"'))
        self.parser=self.root/'parser.py';self.parser.write_text('# trusted parser fixture')
        self.db=self.root/'production.db';source=source_digest(capture(self.folder))
        with closing(sqlite3.connect(self.db)) as db,db:
            db.execute('CREATE TABLE parser_run (ParserSHA256,SourceManifestSHA256,SourceLORVersion,ValidationStatus,Status,RunMode,SourcePreviewFolder)')
            db.execute('INSERT INTO parser_run VALUES (?,?,?,?,?,?,?)',(hashlib.sha256(self.parser.read_bytes()).hexdigest(),source,'6.6.12','PASSED','COMPLETE','PRODUCTION',str(self.folder)))
        self.run=dict(status='COMPLETE',validation_status='PASSED',parser_activity_id='current-proof',source_lor_version='6.6.12',source_manifest_sha256=source,sqlite_path=str(self.db),sqlite_sha256=hashlib.sha256(self.db.read_bytes()).hexdigest())
        self.activity=dict(activity_id='current-proof',status='PASSED',target='current',source_lor_version='6.6.12',source_preview_folder=str(self.folder),result=dict(sqlite_sha256=self.run['sqlite_sha256']))
        self.c=Catalog(self.root/'evidence',self.folder,'6.6.12',recovery_db=self.db,parser_path=self.parser,parser_run=self.run,parser_activity=self.activity)
    def test_controller_changes_publish_without_ingest_and_keep_database_baseline(self):
        before=self.db.read_bytes();r=self.c.review(self.accepted,'admin');self.assertTrue(r['can_publish']);self.assertEqual(r['parser_validation']['activity_id'],'current-proof')
        doc=self.c.publish(self.accepted,'admin',r['review_id'])
        self.assertEqual(doc['run_id'],34);self.assertEqual(doc['source_sqlite_sha256'],'b'*64)
        self.assertEqual(doc['distribution_authority'],'PASSED_PARSER_V1');self.assertEqual(doc['parser_validation']['sqlite_sha256'],self.run['sqlite_sha256'])
        self.assertEqual(self.db.read_bytes(),before)
    def test_export_after_parser_cannot_use_old_pass(self):
        self.file.write_text(self.file.read_text().replace('Regular,11','Regular,12'))
        with self.assertRaises(ValueError):self.c.review(self.accepted,'admin')
    def test_failed_activity_cannot_publish(self):
        self.activity['status']='FAILED'
        with self.assertRaises(ValueError):self.c.review(self.accepted,'admin')
    def test_other_activity_cannot_publish(self):
        self.activity['activity_id']='other'
        with self.assertRaises(ValueError):self.c.review(self.accepted,'admin')
    def test_candidate_version_parser_cannot_publish(self):
        self.activity['target']='candidate'
        with self.assertRaises(ValueError):self.c.review(self.accepted,'admin')
    def test_sqlite_changed_during_review_blocks_publish(self):
        r=self.c.review(self.accepted,'admin');self.db.write_bytes(self.db.read_bytes()+b'changed')
        with self.assertRaisesRegex(ValueError,'SQLite changed'):self.c.publish(self.accepted,'admin',r['review_id'])
    def test_parser_changed_blocks_authority(self):
        self.parser.write_text('# changed parser')
        with self.assertRaisesRegex(ValueError,'provenance'):self.c.review(self.accepted,'admin')
    def test_existing_old_baseline_allows_parser_validated_controller_update(self):
        # Simulate an existing baseline under this same DB run.
        self.file.write_text(RAW)
        old=Catalog(self.c.root,self.folder,'6.6.12');r=old.review(self.accepted,'admin');old.publish(self.accepted,'admin',r['review_id'])
        self.file.write_text(RAW.replace('Regular,10','Regular,11').replace('Revision="1"','Revision="2"'))
        r=self.c.review(self.accepted,'admin');self.assertTrue(r['can_publish']);self.assertTrue(r['changes'][0]['database_contract_changed']);self.assertFalse(r['database_contract_review_required'])
if __name__=='__main__':unittest.main()
