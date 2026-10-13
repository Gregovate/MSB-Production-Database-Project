"""#171 Office PC reconstruction, map selection, laptop diff and safe G: observation."""
from datetime import datetime, timezone
import json
from pathlib import Path
import tempfile
import unittest

from gis_workstation_profile import MAPS_KEY, TYPES_KEY, REVERSE_KEY, ProfileError, sha256_file
from gis_workstation_proposal import prepare_laptop_proposal
from gis_workstation_observation import (
    list_scanned_map_names, read_observation, compare_with_laptop,
    save_observation)
from test_gis_workstation_profile import FakeRegistry
from test_sync_gis_icons import png, svg


class OfficeObservationTests(unittest.TestCase):
    def setUp(self):
        t = tempfile.TemporaryDirectory()
        self.addCleanup(t.cleanup)
        self.root = Path(t.name)
        self.plain = self.root / "Plain"
        self.canonical = self.root / "png"
        self.laptop_icons = self.root / "laptop-installed"
        self.office_icons = self.root / "office-installed"
        self.shared = self.root / "MSB GIS" / "Workstation-Configuration"
        for p in (self.plain, self.canonical, self.laptop_icons,
                  self.office_icons, self.shared.parent):
            p.mkdir(parents=True, exist_ok=True)
        (self.plain / "pole-yellow.svg").write_bytes(svg(24, 32))
        (self.canonical / "pole-yellow.png").write_bytes(png(24, 32))
        (self.laptop_icons / "pole-yellow.png").write_bytes(png(24, 32))
        self.crop = self.root / "crop.tif"
        self.crop.write_bytes(b"crop image, fixture only")
        laptop = FakeRegistry()
        laptop.keys[MAPS_KEY + r"\Ortho 2019"]["Map Path"] = (
            str(self.crop), laptop.REG_SZ)
        laptop.keys[MAPS_KEY + r"\Ortho 2019\Point02"] = {
            "X": ("2", laptop.REG_SZ),
            "Y": ("3", laptop.REG_SZ),
            "Latitude": ("43.7", laptop.REG_SZ),
            "Longitude": ("-87.7", laptop.REG_SZ),
        }
        self.laptop = prepare_laptop_proposal(
            self.plain, self.canonical, self.shared, "Ortho 2019",
            hostname="YOGA-GREG", reg=laptop, local_symbols=self.laptop_icons,
            save=True, now=datetime(2026, 10, 13, tzinfo=timezone.utc),
            token="abcdef123456")
        self.laptop_path = Path(self.laptop["destination"])
        self.office = FakeRegistry()
        self.full = self.root / "full.tif"
        self.full.write_bytes(b"full aerial, distinct map footprint")
        self.office.keys.pop(MAPS_KEY + r"\Ortho 2019")
        self.office.keys.pop(MAPS_KEY + r"\Ortho 2019\Point01")
        self.office.keys[MAPS_KEY + r"\Full Office Aerial"] = {
            "Map Path": (str(self.full), self.office.REG_SZ),
            "Width": (40000, self.office.REG_DWORD),
            "Height": (22000, self.office.REG_DWORD),
            "Projection": ("Office projection", self.office.REG_SZ),
        }
        self.office.keys[MAPS_KEY + r"\Full Office Aerial\Point01"] = {
            "X": ("0", self.office.REG_SZ),
            "Y": ("0", self.office.REG_SZ),
            "Latitude": ("43.776", self.office.REG_SZ)}
        self.office.keys[MAPS_KEY + r"\Full Office Aerial\Point02"] = {
            "X": ("40000", self.office.REG_SZ),
            "Y": ("22000", self.office.REG_SZ),
            "Longitude": ("-87.73", self.office.REG_SZ)}
        self.office.keys[TYPES_KEY + r"\Display Anchor"]["GPS Symbol"] = (
            "Tall Tower", self.office.REG_SZ)
        self.office.keys[REVERSE_KEY]["Flag, Blue"] = (
            "Office Anchor", self.office.REG_SZ)
        self.timestamp = datetime(2026, 10, 13, 15, tzinfo=timezone.utc)

    def observe(self):
        return read_observation(
            self.plain, self.canonical,
            map_name="Full Office Aerial", reg=self.office,
            local_symbols=self.office_icons, hostname="MSB-OFFICE")

    def test_enumerate_names_only_then_explicit_map(self):
        names = list_scanned_map_names(self.office)
        self.assertEqual(names, ["Full Office Aerial"])
        self.assertFalse(any("Full Office Aerial" in p for p in self.office.opened))
        with self.assertRaisesRegex(ProfileError, "not currently configured"):
            read_observation(self.plain, self.canonical,
                             map_name="Ortho 2019", reg=self.office,
                             local_symbols=self.office_icons,
                             hostname="MSB-OFFICE")
        data = self.observe()
        self.assertEqual(data["selected_map"], "Full Office Aerial")
        self.assertTrue(data["map_image_verified"])
        self.assertEqual(data["png_missing"], 1)
        self.assertEqual(data["png_different"], 0)
        self.assertEqual(data["type_count"], 1)
        self.assertEqual(self.office.writes, [])
        self.assertNotIn(str(self.full), json.dumps(data["profile"]))
        self.assertFalse((self.shared / "Observations").exists())

    def test_compare_to_laptop_keeps_full_map_distinct(self):
        result = compare_with_laptop(
            self.observe(), self.laptop_path, shared_root=self.shared)
        text = json.dumps(result)
        self.assertIn("Different map variants (expected)", text)
        self.assertIn("Full Office Aerial", text)
        self.assertIn("Ortho 2019", text)
        self.assertIn("Local PNG not verified", text)
        self.assertIn("Type field differs", text)
        self.assertIn("GPS Symbol reverse differs", text)
        self.assertFalse((self.shared / "Observations").exists())

    def test_same_map_image_but_deliberately_wrong_office_calibration_flagged(self):
        # A test-only Office registration may use the SAME aerial bytes as
        # laptop while intentionally storing a different CRS/control point.
        # Must never be classified solely as an expected separate variant.
        self.full.write_bytes(self.crop.read_bytes())
        observed = self.observe()
        result = compare_with_laptop(
            observed, self.laptop_path, shared_root=self.shared)
        evidence = json.dumps(result)
        self.assertIn("SAME IMAGE, DIFFERENT GEOREFERENCE", evidence)
        self.assertIn("Full Office Aerial", evidence)
        self.assertIn("Ortho 2019", evidence)
        self.assertFalse((self.shared / "Observations").exists())
        self.assertEqual(self.office.writes, [])

    def test_host_observation_can_be_saved_without_local_pngs(self):
        result = self.observe()
        saved = save_observation(
            result, plain=self.plain, canonical_png=self.canonical,
            shared_root=self.shared, reg=self.office,
            local_symbols=self.office_icons, now=self.timestamp,
            token="123456abcdef")
        path = Path(saved["destination"])
        self.assertTrue(path.is_file())
        self.assertEqual(path.parent.name, "MSB-OFFICE")
        self.assertEqual(path.parent.parent.name, "Observations")
        self.assertEqual(sha256_file(path), saved["sha256"])
        snapshot = json.loads(path.read_text())
        self.assertEqual(snapshot["source_pc_hostname"], "MSB-OFFICE")
        self.assertEqual(snapshot["approval_status"],
                         "UNAPPROVED OBSERVATION - NOT AN INSTALL SOURCE")
        self.assertEqual(snapshot["local_png_status"]["pole-yellow.png"]["status"],
                         "missing")
        self.assertNotIn(str(self.full), path.read_text())
        self.assertFalse((self.shared / "Releases").exists())
        self.assertEqual(self.office.writes, [])

    def test_stale_registry_prevents_shared_write(self):
        before = self.observe()
        self.office.keys[TYPES_KEY + r"\Display Anchor"]["GPS Symbol"] = (
            "Navaid, Red", self.office.REG_SZ)
        with self.assertRaisesRegex(ProfileError, "changed since review"):
            save_observation(before, plain=self.plain,
                             canonical_png=self.canonical,
                             shared_root=self.shared, reg=self.office,
                             local_symbols=self.office_icons, now=self.timestamp)
        self.assertFalse((self.shared / "Observations").exists())

    def test_no_existing_observation_overwrite(self):
        snapshot = self.observe()
        args = dict(plain=self.plain, canonical_png=self.canonical,
                    shared_root=self.shared, reg=self.office,
                    local_symbols=self.office_icons, now=self.timestamp,
                    token="123456abcdef")
        first = save_observation(snapshot, **args)
        with self.assertRaises(FileExistsError):
            save_observation(snapshot, **args)
        self.assertEqual(sha256_file(first["destination"]), first["sha256"])

    def test_different_local_png_does_not_block_recon(self):
        (self.office_icons / "pole-yellow.png").write_bytes(b"different")
        snapshot = self.observe()
        self.assertEqual(snapshot["png_different"], 1)
        self.assertEqual(snapshot["png_missing"], 0)
        self.assertFalse((self.shared / "Observations").exists())


if __name__ == "__main__":
    unittest.main()
