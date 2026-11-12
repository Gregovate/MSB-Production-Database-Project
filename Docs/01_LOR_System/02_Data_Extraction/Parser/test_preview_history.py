"""Exact parser-validated XML history survives normal master overwrites."""
import hashlib
import tempfile
import unittest
import zipfile
from pathlib import Path
from preview_catalog import Catalog,capture,source_digest
RAW='<PreviewClass id="same-uuid" Name="Stage" Revision="1"/>'
class HistoryTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.folder=self.root/'Database Previews V6.6.12';self.folder.mkdir()
        self.file=self.folder/'Original Name.lorprev';self.file.write_text(RAW)
        self.c=Catalog(self.root/'history',self.folder,'6.6.12')
    def save(self,sqlhash='a'*64):
        files=capture(self.folder,include_backgrounds=False);h=source_digest(files)
        return self.c.retain_preview_archive(files,h,sqlhash),self.c.root/'preview-history/archives'/ (h+'.zip')
    def test_original_bytes_and_uuid_survive_overwrite(self):
        before=self.file.read_bytes();record,archive=self.save()
        self.file.write_text(RAW.replace('Revision="1"','Revision="2"'))
        with zipfile.ZipFile(archive) as z:self.assertEqual(z.read(self.file.name),before)
        self.assertEqual(record['files'][0]['preview_id'],'same-uuid')
    def test_repeat_is_idempotent_and_new_version_is_separate(self):
        r,a=self.save();self.assertEqual(self.save()[0],r)
        self.file.write_text(RAW.replace('Revision="1"','Revision="2"'));r2,a2=self.save('b'*64)
        self.assertNotEqual(a,a2);self.assertTrue(a.exists());self.assertTrue(a2.exists())
    def test_changed_source_is_rejected_before_archive_commit(self):
        files=capture(self.folder,include_backgrounds=False);h=source_digest(files)
        self.file.write_text(RAW.replace('Revision="1"','Revision="2"'))
        with self.assertRaisesRegex(ValueError,'Master changed'):self.c.retain_preview_archive(files,h,'a'*64)
        self.assertFalse(list(self.c.root.rglob('*.zip')))
    def test_corrupt_existing_archive_cannot_be_overwritten(self):
        _,a=self.save();a.write_bytes(b'bad')
        with self.assertRaises(zipfile.BadZipFile):self.save()
        self.assertEqual(a.read_bytes(),b'bad')
if __name__=='__main__':unittest.main()
