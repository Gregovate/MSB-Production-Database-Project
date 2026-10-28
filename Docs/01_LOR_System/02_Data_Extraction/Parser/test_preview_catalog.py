"""Disposable catalog checks. Never use G:, PostgreSQL or production runner."""
import ast
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from preview_catalog import Catalog, capture, source_digest
# Load the actual parser functions via AST without running parser top-level I/O.
parser_source=Path(__file__).with_name('parse_props_v7_scene_parser.py').read_text(encoding='utf-8-sig')
parser_tree=ast.parse(parser_source)
parser_functions=[node for node in parser_tree.body if isinstance(node,ast.FunctionDef) and node.name in {'sha256_file','source_manifest_sha256'}]
parser_scope={'Path':Path,'json':json,'hashlib':hashlib}
exec(compile(ast.Module(body=parser_functions,type_ignores=[]),'<actual-parser-source-digest>','exec'),parser_scope)
actual_parser_digest=parser_scope['source_manifest_sha256']

RAW='<PreviewClass id="preview" Name="Show Background Stage 00 Test" Revision="57" Brightness="20"><Scene id="scene" Name="Stage"/><PropClass id="prop" Name="Channel" Comment="HW-Flood-01" MasterDimmable="True" ChannelGrid="Regular,1C,1,3" DeviceType="LOR"/></PreviewClass>'

class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        root=Path(self.temp.name);self.folder=root/'Database Previews V6.6.12';self.folder.mkdir()
        self.file=self.folder/'Test.lorprev';self.file.write_text(RAW)
        files=capture(self.folder)
        self.accepted=dict(schema_version=1,status='COMPLETED',validation='PASSED',lor_version='6.6.12',
                           source_folder=str(self.folder),evidence_id='a'*64,source_manifest_sha256=source_digest(files),
                           previews=[{k:files[0][k] for k in ('filename','preview_id','name','revision')}],
                           run_id=32,import_run_id=74,preview_count=1,source_sqlite_sha256='b'*64,report_sha256='c'*64,report_url='report')
        self.catalog=Catalog(root/'evidence',self.folder,'6.6.12');self.actor='publisher@example.org'

    def register(self): return self.catalog.review(self.accepted,self.actor)

    def test_parser_digest_parity(self):
        self.assertEqual(source_digest(capture(self.folder)),actual_parser_digest(self.folder))

    def test_bootstrap_requires_accepted_bytes(self):
        self.file.write_text(RAW.replace('True','False'))
        with self.assertRaisesRegex(ValueError,'unchanged accepted'): self.register()
        self.assertFalse(self.catalog.root.exists())

    def test_register_export_review_publish_consume_without_ingest(self):
        self.register();self.file.write_text(RAW.replace('True','False').replace('Channel"','New Channel"').replace('57','58'))
        proposal=self.register();self.assertTrue(proposal['can_publish'])
        self.assertEqual(len(proposal['changes'][0]['metadata_changes']),2)
        before=self.file.read_bytes();doc=self.catalog.publish(self.accepted,self.actor,proposal['review_id'])
        self.assertEqual(doc['schema_version'],2);self.assertEqual(doc['status'],'ACCEPTED')
        self.assertEqual(doc['database_baseline_evidence_id'],self.accepted['evidence_id'])
        self.assertEqual(doc,self.catalog.current(self.accepted));self.assertEqual(before,self.file.read_bytes())
        self.assertEqual(doc['previews'][0]['revision'],'58')
        self.assertNotEqual(doc['source_manifest_sha256'],self.accepted['source_manifest_sha256'])

    def test_current_without_publication_is_completed_source(self):
        self.assertEqual(self.catalog.current(self.accepted),self.accepted)

    def test_protected_changes_cannot_publish(self):
        self.register()
        for old,new in [('HW-Flood-01','Other Display'),('Regular,1C,1,3','Aux A,1D,4,6'),('id="prop"','id="different"'),('Name="Stage"','Name="Other Scene"'),('DeviceType="LOR"','DeviceType="DMX"')]:
            with self.subTest(field=old):
                self.file.write_text(RAW.replace(old,new));review=self.register()
                self.assertFalse(review['can_publish'])
                with self.assertRaises(ValueError):self.catalog.publish(self.accepted,self.actor,review['review_id'])

    def test_edit_after_review_blocks_publication(self):
        review=self.register();self.file.write_text(RAW.replace('True','False'))
        with self.assertRaisesRegex(ValueError,'stale'):self.catalog.publish(self.accepted,self.actor,review['review_id'])

    def test_publisher_mismatch_blocks(self):
        review=self.register()
        with self.assertRaisesRegex(ValueError,'another publisher'):self.catalog.publish(self.accepted,'other@example.org',review['review_id'])

    def test_new_baseline_invalidates_review(self):
        review=self.register();accepted=dict(self.accepted,evidence_id='d'*64,run_id=33)
        with self.assertRaises(OSError):self.catalog.publish(accepted,self.actor,review['review_id'])

    def test_tampered_evidence_blocks(self):
        review=self.register();self.catalog.publish(self.accepted,self.actor,review['review_id'])
        directory=self.catalog.context(self.accepted);(directory/'current.json').write_text('{}')
        with self.assertRaisesRegex(ValueError,'integrity'):self.catalog.current(self.accepted)

    def test_second_publisher_review_is_stale_after_first_publication(self):
        review=self.register();self.catalog.publish(self.accepted,self.actor,review['review_id'])
        with self.assertRaisesRegex(ValueError,'stale'):self.catalog.publish(self.accepted,self.actor,review['review_id'])

    def test_source_capture_drift_blocks(self):
        first=capture(self.folder)
        with patch('preview_catalog.capture',side_effect=[first,[]]):
            with self.assertRaisesRegex(ValueError,'changed during'):self.catalog.scan()

    def test_missing_preview_blocks(self):
        self.register();self.file.unlink()
        with self.assertRaisesRegex(ValueError,'empty'):self.register()

    def test_unknown_setting_requires_review(self):
        self.register();self.file.write_text(RAW.replace('DeviceType="LOR"','DeviceType="LOR" NewField="unknown"'))
        self.assertFalse(self.register()['can_publish'])

    def test_name_without_display_comment_is_not_exempt(self):
        self.file.write_text(RAW.replace('Comment="HW-Flood-01"','Comment=""'))
        files=capture(self.folder)
        self.accepted['source_manifest_sha256']=source_digest(files)
        self.register();self.file.write_text(self.file.read_text().replace('Name="Channel"','Name="Different"'))
        self.assertFalse(self.register()['can_publish'])

    def test_review_diffs_against_last_publication(self):
        review=self.register();self.file.write_text(RAW.replace('True','False'))
        changed=self.register();self.catalog.publish(self.accepted,self.actor,changed['review_id'])
        self.assertEqual(self.register()['changes'],[])

    def test_missing_committed_pointer_never_falls_back(self):
        review=self.register();self.catalog.publish(self.accepted,self.actor,review['review_id'])
        (self.catalog.context(self.accepted)/'current.json').unlink()
        with self.assertRaisesRegex(ValueError,'pointer is missing'):self.catalog.current(self.accepted)
        with self.assertRaisesRegex(ValueError,'pointer is missing'):self.register()

    def test_parser_digest_multiple_files_nonascii_names_and_order(self):
        (self.folder/'à Extras.lorprev').write_text(RAW.replace('id="preview"','id="second-preview"'),encoding='utf-8')
        (self.folder/'A First.lorprev').write_bytes(RAW.replace('id="preview"','id="third-preview"').encode('utf-8-sig'))
        captured=capture(self.folder)
        self.assertEqual(source_digest(list(reversed(captured))),actual_parser_digest(self.folder))

    def test_known_previously_proven_pc_parser_digest(self):
        self.file.unlink()
        raw='<PreviewClass id="managed" Name="Rotary-Trees" Revision="57"><Scene Name="HW-Flood" /></PreviewClass>'
        (self.folder/'Rotary.lorprev').write_bytes(raw.encode('utf-8'))
        self.assertEqual(source_digest(capture(self.folder)),'f0b1d09d14ed4e5438f010e8fb69c096339dd97f4a44acbbee3cb6859d61fe18')

if __name__=='__main__':unittest.main()
