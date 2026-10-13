"""Disposable #171 Office EvergreenParkCropped native calibration capture tests.

No real HKCU, G:, device images, GPX or Production assets are accessed.
"""
from datetime import datetime, timezone
import json
from pathlib import Path
import tempfile
import unittest

from gis_workstation_map_source import inspect_office_map, save_office_map_source
from gis_workstation_profile import ProfileError, MAPS_KEY, sha256_file
from test_gis_workstation_profile import FakeRegistry


class OfficeMapSourceTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.image_root = self.root / "Park Drawings"
        self.image_root.mkdir()
        self.image = self.image_root / "EvergreenParkCropped.tif"
        self.image.write_bytes(b"Office raster test bytes; different from laptop crop")
        self.world = self.image.with_suffix(".tfw")
        self.world.write_text("0.25\n0\n0\n-0.25\n209220.125\n187904.625\n")
        self.shared = self.root / "MSB GIS" / "Workstation-Configuration"
        self.shared.parent.mkdir()
        self.reg = FakeRegistry()
        self.reg.keys[MAPS_KEY + r"\EvergreenParkCropped"] = {
            "Map Path": (str(self.image), self.reg.REG_SZ),
            "Width": (36000, self.reg.REG_DWORD),
            "Height": (19000, self.reg.REG_DWORD),
            "Projection": ("NAD83 HARN WISCRS Sheboygan County Feet", self.reg.REG_SZ),
            "Use Worldfile Data": (1, self.reg.REG_DWORD),
        }
        self.reg.keys[MAPS_KEY + r"\EvergreenParkCropped\Point01"] = {
            "X": ("100", self.reg.REG_SZ),
            "Y": ("200", self.reg.REG_SZ),
            "Worldfile X": ("321231.125", self.reg.REG_SZ),
            "Worldfile Y": ("982343.125", self.reg.REG_SZ),
        }
        self.reg.keys[MAPS_KEY + r"\EvergreenParkCropped\Point02"] = {
            "X": ("36000", self.reg.REG_SZ),
            "Y": ("19000", self.reg.REG_SZ),
            "Latitude": ("43.776", self.reg.REG_SZ),
            "Longitude": ("-87.771", self.reg.REG_SZ),
        }
        # Deliberate mismatched test registration; don't read it.
        self.reg.keys[MAPS_KEY + r"\2019 Ortho Cropped for GPS Export"] = {
            "Map Path": (r"C:\Different\bad.tif", self.reg.REG_SZ)}
        self.host = "MSB-OFFICE-PC"
        self.when = datetime(2026, 10, 13, 17, tzinfo=timezone.utc)

    def capture(self, hostname=None):
        return inspect_office_map(
            reg=self.reg, hostname=self.host if hostname is None else hostname,
            shared_image_root=self.image_root)

    def save(self, review):
        return save_office_map_source(
            review, reg=self.reg, hostname=self.host,
            shared_root=self.shared, shared_image_root=self.image_root,
            now=self.when, token="aabbccddeeff")

    def test_three_map_capture_keeps_calibration_separate(self):
        slash = chr(92)
        base = MAPS_KEY + slash + "EvergreenParkCropped"
        for idx, name in enumerate(("2019 Ortho Cropped for GPS Export",
                                    "2019OrthoEvergreenParktoWorkshop")):
            img = self.image_root / (name + ".tif")
            img.write_bytes(name.encode("utf-8"))
            key = MAPS_KEY + slash + name
            self.reg.keys[key] = dict(self.reg.keys[base])
            self.reg.keys[key]["Map Path"] = (str(img), self.reg.REG_SZ)
            for point in ("Point01", "Point02"):
                self.reg.keys[key + slash + point] = dict(
                    self.reg.keys[base + slash + point])
            self.reg.keys[key + slash + "Point01"]["X"] = (
                "999", self.reg.REG_SZ)
            review = inspect_office_map(
                map_name=name, reg=self.reg, hostname=self.host,
                shared_image_root=self.image_root)
            self.assertEqual(review["points"]["Point01"]["X"]["value"], "999")
            receipt = save_office_map_source(
                review, reg=self.reg, hostname=self.host,
                shared_root=self.shared, shared_image_root=self.image_root,
                now=self.when, token=("111111111111" if idx == 0
                                      else "222222222222"))
            saved = json.loads(Path(receipt["destination"]).read_text())
            self.assertEqual(saved["map_name"], name)
            self.assertEqual(saved["target_roles"], [])
        self.assertEqual(self.reg.writes, [])
        self.assertEqual(len(list((self.shared / "Map-Sources" /
                                   self.host).glob("*.json"))), 2)

    def test_unknown_map_name_refused(self):
        for name in ("not-registered", "", "../bad"):
            with self.assertRaises(ProfileError):
                inspect_office_map(
                    map_name=name, reg=self.reg, hostname=self.host,
                    shared_image_root=self.image_root)

    def test_source_read_only_exact_values_and_g_file_hash(self):
        reviewed = self.capture()
        self.assertEqual(reviewed["map_name"], "EvergreenParkCropped")
        self.assertEqual(reviewed["point_count"], 2)
        self.assertEqual(reviewed["width"], 36000)
        self.assertEqual(reviewed["source"]["native_header"]["Width"]["kind"],
                         self.reg.REG_DWORD)
        self.assertEqual(reviewed["source"]["native_control_points"]
                         ["Point01"]["Worldfile X"]["value"], "321231.125")
        self.assertEqual(reviewed["image_sha256"], sha256_file(self.image))
        self.assertEqual(reviewed["sidecars_count"], 1)
        self.assertFalse(self.shared.exists())
        self.assertEqual(self.reg.writes, [])
        self.assertFalse(any("2019 Ortho Cropped for GPS Export" in p
                             for p in self.reg.opened))

    def test_explicit_save_is_hostname_scoped_and_hash_verified(self):
        receipt = self.save(self.capture())
        path = Path(receipt["destination"])
        self.assertTrue(path.is_file())
        self.assertEqual(path.parent.name, "MSB-OFFICE-PC")
        self.assertEqual(path.parent.parent.name, "Map-Sources")
        body = json.loads(path.read_text())
        self.assertEqual(body["approval_status"],
                         "UNAPPROVED MAP SOURCE - NOT INSTALLABLE")
        self.assertEqual(body["native_header"]["Width"]["kind"], self.reg.REG_DWORD)
        self.assertEqual(body["native_control_points"]["Point02"]["Latitude"]["value"],
                         "43.776")
        self.assertEqual(sha256_file(path), receipt["sha256"])
        self.assertFalse((self.shared / "Releases").exists())
        self.assertEqual(self.reg.writes, [])

    def test_changed_control_point_blocks_shared_save(self):
        viewed = self.capture()
        self.reg.keys[MAPS_KEY + r"\EvergreenParkCropped\Point02"]["Latitude"] = (
            "42.001", self.reg.REG_SZ)
        with self.assertRaisesRegex(ProfileError, "changed since preview"):
            self.save(viewed)
        self.assertFalse(self.shared.exists())

    def test_missing_raster_and_nonshared_raster_block_capture(self):
        self.image.unlink()
        with self.assertRaises(ProfileError):
            self.capture()
        self.image.write_bytes(b"back")
        with self.assertRaises(ProfileError):
            inspect_office_map(reg=self.reg, hostname=self.host,
                               shared_image_root=self.root / "Other Folder")

    def test_wrong_host_refused(self):
        with self.assertRaisesRegex(ProfileError, "MSB-OFFICE-PC"):
            self.capture(hostname="YOGA-GREG")
        self.assertFalse(self.shared.exists())

    def test_existing_record_not_overwritten(self):
        first = self.save(self.capture())
        with self.assertRaisesRegex(ProfileError, "never be overwritten"):
            self.save(self.capture())
        self.assertEqual(first["sha256"], sha256_file(first["destination"]))


if __name__ == "__main__":
    unittest.main()
