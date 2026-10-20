"""#428 source-only safeguards. Run: python -m unittest test_gis_track_intake.py"""
import tempfile
import unittest
from pathlib import Path
from gis_track_intake import parse, nearest, type_hint, propose, save, source_digest, mercator, aerial_image, AERIAL_URL, fit_zoom

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
    def test_existing_aerial_xyz_calibration(self):
        import io
        from PIL import Image
        self.assertIn("evergreen-2019-v1/{z}/{x}/{y}.jpg", AERIAL_URL)
        origin=mercator(0,0,1)
        self.assertAlmostEqual(origin[0],256)
        self.assertAlmostEqual(origin[1],256)
        tile=io.BytesIO()
        Image.new("RGB",(256,256),(110,120,130)).save(tile,format="JPEG")
        called=[]
        def fetch(url):
            called.append(url)
            return tile.getvalue()
        rendered,offset=aerial_image([(43.778,-87.742),(43.77801,-87.74201)],256,256,zoom=19,fetch=fetch)
        self.assertEqual(rendered.size,(256,256))
        self.assertTrue(called)
        self.assertTrue(all("/maps/evergreen-2019-v1/19/" in u for u in called))
    def test_fit_zoom_keeps_full_track_visible(self):
        pts=[(43.778,-87.742),(43.779,-87.743)]
        z=fit_zoom(pts,550,290)
        self.assertGreaterEqual(z,14)
        self.assertLessEqual(z,20)
        xy=[mercator(*p,z) for p in pts]
        self.assertLessEqual(abs(xy[0][0]-xy[1][0]),550*0.82)
        self.assertLessEqual(abs(xy[0][1]-xy[1][1]),290*0.82)

    def test_unknown_type_not_forced(self):
        self.assertEqual(type_hint("2026-10-20 08:00"),"Unknown")

if __name__=="__main__":unittest.main()
