"""#171 Garmin GPX export must never silently change source master or other fields."""
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
import xml.etree.ElementTree as ET

from garmin_bmp_derivatives import GarminSyncError
from garmin_gpx_export import export_waypoints, GPX


class TestGarminExport(unittest.TestCase):
    def test_reconcile_symbol_only_and_keep_master_unchanged(self):
        with TemporaryDirectory() as temp:
            p = Path(temp)
            source, out, registry = p / "master.gpx", p / "device.gpx", p / "mapping.json"
            original = ('<?xml version="1.0" encoding="utf-8"?>'
                        '<gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="ExpertGPS">'
                        '<wpt lat="43.1" lon="-87.7"><name>PANEL 12</name><sym>Block, Red</sym>'
                        '<type>Panel</type><extensions><label xmlns="urn:msb"><marker url="keep"/></label>'
                        '</extensions></wpt><trk><name>NET example</name></trk></gpx>').encode()
            source.write_bytes(original)
            registry.write_text(json.dumps({"symbols": [
                {"type": "Panel", "source": "panel.png", "symbol": "PANEL"}]}))
            review = export_waypoints(source, out, registry)
            self.assertEqual(review["summary"]["modified"], 1)
            self.assertEqual(review["summary"]["tracks_removed_from_device_export"], 1)
            self.assertFalse(out.exists())
            result = export_waypoints(source, out, registry, approve=True)
            self.assertEqual(source.read_bytes(), original)
            self.assertIn("output_sha256", result)
            parsed = ET.parse(out).getroot()
            wp = parsed.find(GPX + "wpt")
            self.assertEqual(wp.find(GPX + "sym").text, "PANEL")
            self.assertEqual(wp.find(GPX + "type").text, "Panel")
            self.assertEqual(wp.attrib, {"lat": "43.1", "lon": "-87.7"})
            self.assertEqual(len(parsed.findall(GPX + "trk")), 0)
            self.assertIsNotNone(wp.find(GPX + "extensions"))
            with self.assertRaisesRegex(GarminSyncError, "Output exists"):
                export_waypoints(source, out, registry, approve=True)
            with self.assertRaisesRegex(GarminSyncError, "never overwrite"):
                export_waypoints(source, source, registry, approve=True)

    def test_unmapped_types_preserved(self):
        with TemporaryDirectory() as temp:
            p = Path(temp)
            source, output, reg = p / "m.gpx", p / "o.gpx", p / "r.json"
            source.write_text('<gpx xmlns="http://www.topografix.com/GPX/1/1">'
                              '<wpt lat="0" lon="0"><sym>Stadium</sym><type>Stage</type></wpt></gpx>')
            reg.write_text(json.dumps({"symbols": [
                {"type": "Panel", "source": "panel.png", "symbol": "PANEL"}]}))
            result = export_waypoints(source, output, reg, approve=True)
            self.assertEqual(result["summary"]["unmapped"], 1)
            self.assertEqual(ET.parse(output).getroot().find(GPX + "wpt").find(GPX + "sym").text, "Stadium")


if __name__ == "__main__":
    unittest.main()
