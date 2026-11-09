"""Read-only GPX change detection regression coverage."""
import tempfile
import unittest
from pathlib import Path
from gis_source_review_dialog import compare_sources


def gpx(lat="43.1", *, sym="PANEL", new=False):
    additional = '<wpt lat="43.3" lon="-87.3"><name>NEW</name></wpt>' if new else ""
    return (f'<gpx xmlns="http://www.topografix.com/GPX/1/1"><wpt lat="{lat}" lon="-87.1">'
            f'<name>PANEL 09</name><sym>{sym}</sym></wpt>{additional}'
            f'<trk><name>NET route</name><trkseg><trkpt lat="43.1" lon="-87.2"/>'
            f'</trkseg></trk></gpx>')


class ReviewTests(unittest.TestCase):
    def test_added_and_recalibrated_waypoint(self):
        with tempfile.TemporaryDirectory() as d:
            a, b = Path(d)/"a.gpx", Path(d)/"b.gpx"
            a.write_text(gpx())
            b.write_text(gpx("43.2", new=True))
            rows = compare_sources(a,b)
            self.assertEqual(len(rows),2)
            self.assertEqual({x[2] for x in rows},{"Added","Changed"})
            self.assertTrue(any("recalibration" in x[3] for x in rows))
            self.assertEqual(a.read_text(),gpx())

    def test_symbol_only_change(self):
        with tempfile.TemporaryDirectory() as d:
            a, b = Path(d)/"a.gpx", Path(d)/"b.gpx"
            a.write_text(gpx())
            b.write_text(gpx(sym="Block, Red"))
            rows=compare_sources(a,b)
            self.assertEqual(len(rows),1)
            self.assertIn("symbol",rows[0][3])


if __name__=="__main__":
    unittest.main()
