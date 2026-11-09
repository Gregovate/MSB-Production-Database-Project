import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
import xml.etree.ElementTree as ET
from garmin_field_handoff_gpx import run,NS,EXPECTED


class FieldHandoffGPX(unittest.TestCase):
    def test_tracks_geometry_and_extensions_preserved(self):
        with TemporaryDirectory() as d:
            root=Path(d)
            p=root/EXPECTED
            original=('<?xml version="1.0"?><gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1">'
                      '<wpt lat="43.78" lon="-87.74"><name>PANEL 12</name><sym>Block, Red</sym><type>Panel</type>'
                      '<extensions><detail xmlns="urn:msb">keep</detail></extensions></wpt>'
                      '<trk><name>NET A to B</name><trkseg><trkpt lat="43.7" lon="-87.7"/></trkseg></trk>'
                      '</gpx>').encode()
            p.write_bytes(original)
            reg=root/"map.json"
            reg.write_text(json.dumps({"symbols":[{"type":"Panel","source":"panel.png","symbol":"PANEL"}]}))
            preview=run(p,reg)
            self.assertEqual(preview["symbol_corrections"],1)
            self.assertEqual(preview["tracks"],1)
            self.assertEqual(p.read_bytes(),original)
            result=run(p,reg,apply=True)
            self.assertEqual((root/(EXPECTED+".BEFORE-GARMIN-SYM.bak")).read_bytes(),original)
            data=ET.parse(p).getroot()
            self.assertEqual(data.find(NS+"trk").find(NS+"trkseg").find(NS+"trkpt").attrib["lat"],"43.7")
            self.assertEqual(data.find(NS+"wpt").find(NS+"sym").text,"PANEL")
            self.assertIsNotNone(data.find(NS+"wpt").find(NS+"extensions"))
            self.assertTrue(Path(result["receipt"]).exists())
            with self.assertRaisesRegex(ValueError,"Existing backup"):
                run(p,reg,apply=True)

    def test_master_filename_refused(self):
        with TemporaryDirectory() as d:
            root=Path(d)
            p=root/"MSB-Park-Infrastructure.gpx";p.write_text("<gpx/>")
            mapping=root/"map.json";mapping.write_text("{}")
            with self.assertRaisesRegex(ValueError,"Refusing anything"):
                run(p,mapping,apply=True)


if __name__=="__main__":
    unittest.main()
