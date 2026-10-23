"""Disposable #171 comparison Copy/Export helper tests. No real HKCU, G: or GPX."""
from datetime import datetime, timezone
import json
from pathlib import Path
import tempfile
import unittest

from gis_workstation_profile import ProfileError, sha256_file
from gis_workstation_comparison_report import (
    SCHEMA, format_comparison_report, save_comparison_report)


class ExportComparisonTests(unittest.TestCase):
    def setUp(self):
        t = tempfile.TemporaryDirectory()
        self.addCleanup(t.cleanup)
        self.root = Path(t.name)
        self.shared = self.root / "MSB GIS" / "Workstation-Configuration"
        self.shared.parent.mkdir()
        self.now = datetime(2026, 10, 13, 16, tzinfo=timezone.utc)
        self.token = "a1b2c3d4e5f6"
        self.office = {
            "hostname": "MSB-OFFICE-PC",
            "fingerprint": "a" * 64,
            "selected_map": "EvergreenParkCropped",
            "png_matched": 0,
            "png_missing": 32,
            "png_different": 5,
        }
        self.comparison = {
            "rows": [
                ("GPS Symbol reverse differs", "Flag, Blue", "",
                 "Office: Outlet Power | Laptop: Display Anchor"),
                ("Type field differs", "T-Post", "GPS Symbol",
                 "Office: City (Small) | Laptop: Circle with X"),
                ("Different map registrations (review separately)",
                 "Office: EvergreenParkCropped",
                 "Laptop: 2019 Ortho Cropped for GPS Export",
                 "Do not assume identical or interchangeable calibration"),
            ],
            "office_type_count": 28,
            "laptop_type_count": 59,
            "laptop_maps": ["2019 Ortho Cropped for GPS Export"],
            "laptop_proposal_sha256": "b" * 64,
        }

    def run_save(self):
        return save_comparison_report(
            self.comparison, self.office, shared_root=self.shared,
            now=self.now, token=self.token)

    def test_copyable_report_contains_all_evidence_and_no_writes(self):
        report = format_comparison_report(self.comparison, self.office)
        self.assertIn("MSB-OFFICE-PC", report)
        self.assertIn("Flag, Blue", report)
        self.assertIn("T-Post", report)
        self.assertIn("EvergreenParkCropped", report)
        self.assertIn("NOT AN APPROVED GIS RELEASE", report)
        self.assertEqual(report.count("Office:"), 3)
        self.assertFalse(self.shared.exists())

    def test_explicit_save_has_exact_txt_json_and_sha_receipts(self):
        receipt = self.run_save()
        self.assertEqual(receipt["differences"], 3)
        txt = Path(receipt["text_file"])
        j = Path(receipt["json_file"])
        self.assertEqual(txt.read_text("utf-8"),
                         format_comparison_report(self.comparison, self.office))
        self.assertEqual(sha256_file(txt), receipt["text_sha256"])
        self.assertEqual(sha256_file(j), receipt["json_sha256"])
        self.assertEqual(txt.parent.parent.name, "MSB-OFFICE-PC")
        body = json.loads(j.read_text("utf-8"))
        self.assertEqual(body["schema"], SCHEMA)
        self.assertEqual(len(body["differences"]), 3)
        self.assertEqual(body["office_png_summary"]["missing"], 32)
        self.assertEqual(body["office_pc_hostname"], "MSB-OFFICE-PC")
        self.assertNotIn("approved_by", body)
        self.assertFalse((self.shared / "Releases").exists())

    def test_save_cannot_overwrite_existing_directory(self):
        original = self.run_save()
        with self.assertRaisesRegex(ProfileError, "already exists"):
            self.run_save()
        self.assertEqual(sha256_file(original["text_file"]),
                         original["text_sha256"])

    def test_bad_hostname_rejected_before_writing(self):
        self.office["hostname"] = "../../danger"
        with self.assertRaises(ProfileError):
            self.run_save()
        self.assertFalse(self.shared.exists())

    def test_symlink_parent_refused(self):
        self.shared.mkdir()
        try:
            (self.shared / "Comparisons").symlink_to(
                self.root, target_is_directory=True)
        except (OSError, NotImplementedError):
            self.skipTest("Windows policy denies test symlink creation")
        with self.assertRaisesRegex(ProfileError, "Linked"):
            self.run_save()
        self.assertFalse((self.root / "MSB-OFFICE-PC").exists())


if __name__ == "__main__":
    unittest.main()
