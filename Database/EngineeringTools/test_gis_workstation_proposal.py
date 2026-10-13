"""#171 disposable shared GIS proposal acceptance, no real G:/HKCU/GPX/Production."""
from datetime import datetime, timezone
import json
import tempfile
import unittest
from pathlib import Path

from gis_workstation_profile import ProfileError, load_release, sha256
from gis_workstation_proposal import (PROPOSAL_SCHEMA, proposal_destination,
    prepare_laptop_proposal, workstation_hostname)
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
        self.shared_parent = self.root / "MSB GIS"
        self.shared_parent.mkdir()
        self.shared = self.shared_parent / "Workstation-Configuration"
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
        self.host = "LAPTOP-TEST"
        self.now = datetime(2026, 10, 13, 7, 0, tzinfo=timezone.utc)
        self.token = "123456abcdef"
        self.out = proposal_destination(self.shared, self.host, self.now, self.token)

    def build(self, save=False, hostname=None):
        return prepare_laptop_proposal(
            self.plain, self.canonical, self.shared, "Ortho 2019",
            hostname=self.host if hostname is None else hostname, reg=self.reg,
            local_symbols=self.local, save=save,
            now=self.now, token=self.token)

    def test_check_only_is_readonly_including_shared_drive(self):
        result = self.build()
        self.assertEqual(result["status"], "Read-only preflight")
        self.assertEqual(result["type_count"], 1)
        self.assertEqual(result["png_count"], 1)
        self.assertEqual(result["map_count"], 1)
        self.assertEqual(result["hostname"], self.host)
        self.assertEqual(result["review_items"], [])
        self.assertFalse(self.shared.exists(), "Preflight must not create shared folders")
        self.assertFalse(self.out.exists())
        self.assertEqual(self.reg.writes, [])

    def test_shared_host_specific_unapproved_proposal(self):
        result = self.build(save=True)
        self.assertEqual(result["status"], "UNAPPROVED proposal saved")
        self.assertEqual(Path(result["destination"]), self.out)
        self.assertEqual(self.out.parent.name, self.host)
        self.assertEqual(self.out.parent.parent.name, "Proposals")
        data = json.loads(self.out.read_text("utf-8"))
        self.assertEqual(data["schema"], PROPOSAL_SCHEMA)
        self.assertEqual(data["approval_status"], "UNAPPROVED")
        self.assertEqual(data["source_pc_hostname"], self.host)
        self.assertEqual(data["native_registry_kinds"]["types"]
                         ["Display Anchor"]["Symbol Type"], self.reg.REG_SZ)
        self.assertEqual(data["native_registry_kinds"]["symbol_to_type"]
                         ["Flag, Blue"], self.reg.REG_SZ)
        self.assertEqual(data["symbol_to_type"]["Flag, Blue"], "Display Anchor")
        self.assertEqual(data["types"]["Display Anchor"]["GPS Symbol"], "Flag, Blue")
        self.assertEqual(data["files"]["msb/pole-yellow.png"], sha256(png(24, 32)))
        self.assertEqual(data["approved_plain_source_sha256"]["pole-yellow.svg"],
                         sha256(svg(24, 32)))
        self.assertNotIn("Private Vendor Setting", self.out.read_text())
        self.assertNotIn(str(self.root), self.out.read_text())
        self.assertNotIn("Map Path", self.out.read_text())
        self.assertEqual(self.reg.writes, [])
        self.assertTrue(all(str(x).startswith(r"Software\TopoGrafix\Common")
                            for x in self.reg.opened))
        # No proposal file may be fed to the approved-release Step 6 loader.
        with self.assertRaisesRegex(ProfileError, "Unsupported"):
            load_release(self.out, sha256(self.out.read_bytes()))

    def test_source_captures_real_dword_kind_without_reg_write(self):
        self.reg.keys[TYPES_KEY + r"\\Display Anchor"]["Symbol Type"] = (
            2, self.reg.REG_DWORD)
        result = self.build(save=True)
        evidence = json.loads(Path(result["destination"]).read_text("utf-8"))
        self.assertEqual(evidence["types"]["Display Anchor"]["Symbol Type"], "2")
        self.assertEqual(evidence["native_registry_kinds"]["types"]
                         ["Display Anchor"]["Symbol Type"], self.reg.REG_DWORD)
        self.assertEqual(self.reg.writes, [])

    def test_bad_png_does_not_create_shared_folders(self):
        (self.local / "pole-yellow.png").write_bytes(b"changed")
        with self.assertRaisesRegex(ProfileError, "installed PNG differs"):
            self.build(save=True)
        self.assertFalse(self.shared.exists())

    def test_missing_calibration_does_not_create_shared_folders(self):
        self.reg.keys.pop(MAPS_KEY + r"\Ortho 2019\Point02")
        with self.assertRaisesRegex(ProfileError, "Point01/Point02"):
            self.build(save=True)
        self.assertFalse(self.shared.exists())

    def test_historical_case_url_preserved_as_explicit_review_item(self):
        self.reg.keys[TYPES_KEY + r"\Display Anchor"]["Bitmap Symbol URL"] = (
            "https://webassets.sheboyganlights.org/images/symbols/msb/Pole-Yellow.png",
            self.reg.REG_SZ)
        preflight = self.build()
        self.assertEqual(len(preflight["review_items"]), 1)
        self.assertEqual(preflight["review_items"][0]["type"], "Display Anchor")
        self.assertFalse(self.shared.exists(), "Review-only mode must not write")
        self.build(save=True)
        report = json.loads(self.out.read_text("utf-8"))
        self.assertEqual(len(report["review_items"]), 1)
        self.assertEqual(report["review_items"][0]["type"], "Display Anchor")

    def test_gui_review_fingerprint_blocks_stale_configuration(self):
        before = self.build(save=False)
        self.assertEqual(len(before["review_source_sha256"]), 64)
        # Operator reviewed one Type, but changed the association afterward.
        self.reg.keys[TYPES_KEY + r"\\Display Anchor"]["GPS Symbol"] = (
            "Tall Tower", self.reg.REG_SZ)
        with self.assertRaisesRegex(ProfileError, "changed since review"):
            prepare_laptop_proposal(
                self.plain, self.canonical, self.shared, "Ortho 2019",
                hostname=self.host, reg=self.reg, local_symbols=self.local,
                save=True, now=self.now, token=self.token,
                expected_source_sha256=before["review_source_sha256"])
        self.assertFalse(self.shared.exists(), "Stale review must never write")

    def test_gui_review_fingerprint_allows_explicit_fresh_save(self):
        before = self.build(save=False)
        result = prepare_laptop_proposal(
            self.plain, self.canonical, self.shared, "Ortho 2019",
            hostname=self.host, reg=self.reg, local_symbols=self.local,
            save=True, now=self.now, token=self.token,
            expected_source_sha256=before["review_source_sha256"])
        self.assertTrue(Path(result["destination"]).is_file())

    def test_no_overwrite_even_for_same_host_timestamp(self):
        self.build(save=True)
        original = self.out.read_bytes()
        with self.assertRaises(FileExistsError):
            self.build(save=True)
        self.assertEqual(original, self.out.read_bytes())

    def test_invalid_hostname_refused_before_all_writes(self):
        for name in ("../../other", r"PC\OTHER", "", ".hidden", "PC WITH SPACE"):
            with self.subTest(hostname=name):
                with self.assertRaises(ProfileError):
                    self.build(save=True, hostname=name)
        self.assertFalse(self.shared.exists())

    def test_two_hostnames_are_separate_without_shared_release_overwrite(self):
        one = self.build(save=True)
        two = self.build(save=True, hostname="SHOW-PC")
        self.assertNotEqual(one["destination"], two["destination"])
        self.assertTrue(Path(one["destination"]).exists())
        self.assertTrue(Path(two["destination"]).exists())
        self.assertFalse((self.shared / "Releases").exists())
        self.assertFalse((self.shared / "Receipts").exists())

    def test_symlinked_shared_parent_refused(self):
        self.shared.mkdir()
        try:
            (self.shared / "Proposals").symlink_to(
                self.local, target_is_directory=True)
        except (OSError, NotImplementedError):
            # Windows without Developer Mode may prohibit symlink creation.
            # The same denial case still runs on the Linux CI host.
            self.skipTest("Windows policy disallows disposable directory symlink")
        with self.assertRaisesRegex(ProfileError, "Linked Shared Drive"):
            self.build(save=True)
        self.assertFalse((self.local / self.host).exists())


if __name__ == "__main__":
    unittest.main()
