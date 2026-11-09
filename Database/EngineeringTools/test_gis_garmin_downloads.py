import tempfile
import unittest
from pathlib import Path
import gis_garmin_downloads as d

GPX='<gpx xmlns="http://www.topografix.com/GPX/1/1" creator="Garmin"><wpt lat="43" lon="-87"><name>Bollard</name></wpt></gpx>'


class DownloadsTest(unittest.TestCase):
    def test_download_skip_change_disconnect_and_selective_removal(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'device';source.mkdir()
            root=Path(tmp)/'intake';root.mkdir()
            a=source/'waypoints.gpx';a.write_text(GPX)
            b=source/'upload.gpx';b.write_text(GPX.replace('Garmin','ExpertGPS'))
            rows=d.inventory(source,root)
            selected=[r for r in rows if not r['uploaded']]
            self.assertEqual(len(selected),1)
            self.assertEqual(selected[0]['waypoints'],1)
            d.download(source,root,selected)
            retained=d.retained(root)[0];mtime=retained.stat().st_mtime_ns
            d.download(source,root,selected)
            self.assertEqual(retained.stat().st_mtime_ns,mtime)
            a.write_text(GPX.replace('Bollard','Bollard 2'))
            with self.assertRaises(ValueError):d.remove_verified(source,root,selected)
            changed=[r for r in d.inventory(source,root) if not r['uploaded']]
            self.assertFalse(changed[0]['downloaded'])
            d.download(source,root,changed)
            self.assertEqual(len(d.retained(root)),1)
            self.assertTrue(retained.exists()) # old versions are preserved
            d.remove_verified(source,root,changed)
            self.assertFalse(a.exists());self.assertTrue(b.exists())
            source.rename(Path(tmp)/'disconnected')
            self.assertIn('Bollard 2',d.retained(root)[0].read_text())

    def test_corrupt_archive_blocks_removal_and_queue(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp)/'device';source.mkdir()
            a=source/'a.gpx';a.write_text(GPX)
            root=Path(tmp)/'intake'
            rows=d.inventory(source,root);d.download(source,root,rows)
            d.retained(root)[0].write_text('corrupt')
            with self.assertRaises(ValueError):d.remove_verified(source,root,rows)
            with self.assertRaises(ValueError):d.retained(root)
            self.assertTrue(a.exists())


if __name__=='__main__':unittest.main()
