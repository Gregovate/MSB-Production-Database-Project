"""Disposable #171 laptop proposal tests: no live G:, HKCU, GPX or Production."""
import json
import tempfile
import unittest
from pathlib import Path

from gis_workstation_profile import ProfileError, load_release, sha256
from gis_workstation_proposal import prepare_laptop_proposal, PROPOSAL_SCHEMA
from test_gis_workstation_profile import FakeRegistry, MAPS_KEY, TYPES_KEY
from test_sync_gis_icons import png, svg


class LaptopProposalTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.plain = self.root / "Plain"
        self.canonical = self.root / "png"
        self.local = self.root / "local"
        for path in (self.plain, self.canonical, self.local):
            path.mkdir()
        (self.plain / "pole-yellow.svg").write_bytes(svg(24, 32))
        data = png(24, 32)
        (self.canonical / "pole-yellow.png").write_bytes(data)
        (self.local / "pole-yellow.png").write_bytes(data)
        self.reg = FakeRegistry()
        image = self.root / "orthophoto-disposable.tif"
        image.write_bytes(b"not a real aerial, fixture only")
        self.reg.keys[MAPS_KEY + r"\Ortho 2019"]["Map Path"] = (
            str(image), self.reg.REG_SZ)
        self.reg.keys[MAPS_KEY + r"\Ortho 2019\Point02"] = {
            "X": ("18280", self.reg.REG_SZ),
            "Y": ("9491", self.reg.REG_SZ),
            "Latitude": ("43.7", self.reg.REG_SZ),
            "Longitude": ("-87.7", self.reg.REG_SZ),
        }
        self.out = self.root / "candidate.json"

    def build(self):
        return prepare_laptop_proposal(
            self.plain, self.canonical, self.out, "Ortho 2019",
            reg=self.reg, local_symbols=self.local)

    def test_unapproved_sanitized_proposal_and_readonly_inputs(self):
        result = self.build()
        body = self.out.read_text("utf-8")
        data = json.loads(body)
        self.assertEqual(result["type_count"], 1)
        self.assertEqual(result["png_count"], 1)
        self.assertEqual(data["schema"], PROPOSAL_SCHEMA)
        self.assertEqual(data["approval_status"], "UNAPPROVED")
        self.assertEqual(data["symbol_to_type"]["Flag, Blue"], "Display Anchor")
        self.assertEqual(data["types"]["Display Anchor"]["GPS Symbol"], "Flag, Blue")
        self.assertEqual(data["files"]["msb/pole-yellow.png"], sha256(png(24, 32)))
        self.assertNotIn("Private Vendor Setting", body)
        self.assertNotIn(str(self.root), body)
        self.assertNotIn("Map Path", body)
        self.assertEqual(self.reg.writes, [])
        self.assertTrue(all(str(x).startswith("Software\\TopoGrafix\\Common")
                            for x in self.reg.opened))
        # A proposal cannot be trusted as an administrator-approved release.
        with self.assertRaisesRegex(ProfileError, "Unsupported"):
            load_release(self.out, sha256(self.out.read_bytes()))

    def test_bad_png_blocks_without_creating_proposal(self):
        (self.local / "pole-yellow.png").write_bytes(b"changed")
        with self.assertRaisesRegex(ProfileError, "installed PNG differs"):
            self.build()
        self.assertFalse(self.out.exists())

    def test_missing_calibration_blocks_without_writing(self):
        self.reg.keys.pop(MAPS_KEY + r"\Ortho 2019\Point02")
        with self.assertRaisesRegex(ProfileError, "Point01/Point02"):
            self.build()
        self.assertFalse(self.out.exists())

    def test_preserve_unrecognized_legacy_type_url_as_review_item(self):
        self.reg.keys[TYPES_KEY + r"\Display Anchor"]["Bitmap Symbol URL"] = (
            "https://webassets.sheboyganlights.org/images/symbols/msb/Pole-Yellow.png",
            self.reg.REG_SZ)
        self.build()
        report = json.loads(self.out.read_text("utf-8"))
        self.assertEqual(len(report["review_items"]), 1)
        self.assertEqual(report["review_items"][0]["type"], "Display Anchor")

    def test_no_overwriting_existing_proposals(self):
        self.out.write_text("existing local evidence")
        with self.assertRaisesRegex(ProfileError, "overwrite"):
            self.build()
        self.assertEqual(self.out.read_text(), "existing local evidence")


if __name__ == "__main__":
    unittest.main()
