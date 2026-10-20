"""#428 source-only safeguards. Run: python -m unittest test_gis_track_intake.py"""
import tempfile
import unittest
from pathlib import Path
from gis_track_intake import parse, nearest, type_hint, propose, save, source_digest

GPX = '<gpx xmlns="http://www.topografix.com/GPX/1/1"><wpt lat="43.1" lon="-87.1"><name>FE-00</name></wpt><wpt lat="43.101" lon="-87.102"><name>FE-07</name></wpt><trk><name>2026-10-20 NET</name><trkseg><trkpt lat="43.1" lon="-87.1"/><trkpt lat="43.101" lon="-87.102"/></trkseg></trk></gpx>'

class IntakeTests(unittest.TestCase):
    def test_waypoint_suggestion_and_type(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/"raw.gpx";p.write_text(GPX)
            tracks,waypoints=parse(p)
            self.assertEqual(len(tracks),1)
            self.assertEqual(nearest(tracks[0][2][0],waypoints)[0][0],"FE-00")
            self.assertEqual(nearest(tracks[0][2][-1],waypoints)[0][0],"FE-07")
            self.assertEqual(type_hint(tracks[0][1]),"NET")
            self.assertEqual(propose("NET","FE-00","FE-07"),"NET FE-00 to FE-07")
    def test_save_archives_original_and_preserves_bytes(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d);source=root/"raw.gpx";source.write_text(GPX)
            before=source.read_bytes();digest=source_digest(source)
            reviewed=save(root/"Field-Recordings",source,1,"NET FE-00 to FE-07","NET","FE-00","FE-07")
            self.assertTrue(reviewed.is_file())
            self.assertEqual(source.read_bytes(),before)
            self.assertEqual(len(list((root/"Field-Recordings").glob("*/Originals/*.gpx"))),1)
            self.assertEqual(source_digest(source),digest)
            save(root/"Field-Recordings",source,1,"NET FE-00 to FE-07","NET","FE-00","FE-07")
            self.assertEqual(len(list((root/"Field-Recordings").glob("*/Originals/*.gpx"))),1)
    def test_unknown_type_not_forced(self):
        self.assertEqual(type_hint("2026-10-20 08:00"),"Unknown")

if __name__=="__main__":unittest.main()
