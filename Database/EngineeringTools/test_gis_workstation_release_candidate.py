"""#171 disposable shared-release candidate tests. No real G:, HKCU, GPX, Garmin."""
from datetime import datetime, timezone
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from gis_workstation_profile import ProfileError, sha256, sha256_file, load_release
from gis_workstation_proposal import prepare_laptop_proposal
from gis_workstation_release_candidate import (CANDIDATE_SCHEMA,
    inspect_saved_proposal, prepare_release_candidate)
from test_gis_workstation_profile import FakeRegistry, MAPS_KEY
from test_sync_gis_icons import svg, png


class CandidateSafetyTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        self.shared_parent = self.root / "MSB GIS"
        self.shared_parent.mkdir()
        self.shared = self.shared_parent / "Workstation-Configuration"
        self.plain = self.root / "Plain"
        self.canonical = self.root / "png"
        self.local = self.root / "installed"
        for p in (self.plain, self.canonical, self.local):
            p.mkdir()
        (self.plain / "pole-yellow.svg").write_bytes(svg(24, 32))
        (self.canonical / "pole-yellow.png").write_bytes(png(24, 32))
        (self.local / "pole-yellow.png").write_bytes(png(24, 32))
        self.reg = FakeRegistry()
        self.ortho = self.root / "laptop-crop-test.tif"
        self.ortho.write_bytes(b"disposable mapped orthophoto")
        self.reg.keys[MAPS_KEY + r"\Ortho 2019"]["Map Path"] = (
            str(self.ortho), self.reg.REG_SZ)
        self.reg.keys[MAPS_KEY + r"\Ortho 2019\Point02"] = {
            "X": ("200", self.reg.REG_SZ),
            "Y": ("300", self.reg.REG_SZ),
            "Latitude": ("43.71", self.reg.REG_SZ),
            "Longitude": ("-87.77", self.reg.REG_SZ),
        }
        self.now = datetime(2026, 10, 13, 14, tzinfo=timezone.utc)
        self.saved = prepare_laptop_proposal(
            self.plain, self.canonical, self.shared, "Ortho 2019",
            hostname="YOGA-GREG", reg=self.reg, local_symbols=self.local,
            save=True, now=self.now, token="abbccddeeff0")
        self.proposal = Path(self.saved["destination"])
        self.pin = sha256_file(self.proposal)

    def prepare(self, save=False):
        return prepare_release_candidate(
            self.proposal, self.canonical, shared_root=self.shared,
            reviewed_sha256=self.pin, save=save, now=self.now,
            token="123456abcdef")

    def test_review_is_readonly_and_has_exact_original_url(self):
        record = inspect_saved_proposal(self.proposal, self.shared)
        self.assertEqual(record["hostname"], "YOGA-GREG")
        self.assertEqual(record["types"], 1)
        self.assertEqual(record["pngs"], 1)
        self.assertEqual(record["maps"], 1)
        self.assertEqual(record["sha256"], self.pin)
        self.assertFalse((self.shared / "Candidates").exists())

    def test_preflight_does_not_create_candidate_or_approval(self):
        result = self.prepare()
        self.assertEqual(result["status"], "Candidate preflight only")
        self.assertFalse(Path(result["destination"]).exists())
        self.assertFalse((self.shared / "Releases").exists())
        self.assertFalse((self.shared / "Receipts").exists())

    def test_explicit_package_copies_hash_matched_icons_only(self):
        result = self.prepare(save=True)
        dest = Path(result["destination"])
        self.assertEqual(result["status"], "UNAPPROVED candidate staged")
        self.assertEqual(sha256_file(dest / "msb" / "pole-yellow.png"),
                         sha256(png(24, 32)))
        body = json.loads((dest / "candidate.json").read_text())
        self.assertEqual(body["schema"], CANDIDATE_SCHEMA)
        self.assertEqual(body["source_pc_hostname"], "YOGA-GREG")
        self.assertEqual(body["source_proposal_sha256"], self.pin)
        self.assertEqual(body["status"], "UNAPPROVED; NOT INSTALLABLE")
        self.assertFalse((dest / "2019 Ortho 2019.tif").exists())
        self.assertFalse((self.shared / "Releases").exists())
        with self.assertRaisesRegex(ProfileError, "Unsupported"):
            load_release(dest / "candidate.json", result["candidate_sha256_not_approval"])

    def test_no_overwrite_of_existing_candidate_directory(self):
        self.prepare(save=True)
        with self.assertRaisesRegex(ProfileError, "already exists"):
            self.prepare(save=True)

    def test_post_review_proposal_edit_refuses_package(self):
        self.proposal.write_text(self.proposal.read_text() + "\n")
        with self.assertRaisesRegex(ProfileError, "differ"):
            self.prepare(save=True)
        self.assertFalse((self.shared / "Candidates").exists())

    def test_post_review_icon_change_refuses_package(self):
        (self.canonical / "pole-yellow.png").write_bytes(b"unexpected")
        with self.assertRaisesRegex(ProfileError, "changed since"):
            self.prepare(save=True)
        self.assertFalse((self.shared / "Candidates").exists())

    def test_source_outside_host_proposal_directory_refused(self):
        with self.assertRaises(ProfileError):
            inspect_saved_proposal(self.proposal.parent.parent, self.shared)
        with self.assertRaises(ProfileError):
            inspect_saved_proposal(self.ortho, self.shared)

    def test_unapproved_candidate_cannot_be_a_step6_release(self):
        result = self.prepare(save=True)
        path = Path(result["destination"]) / "candidate.json"
        with self.assertRaisesRegex(ProfileError, "Unsupported"):
            load_release(path, sha256_file(path))


if __name__ == "__main__":
    unittest.main()
