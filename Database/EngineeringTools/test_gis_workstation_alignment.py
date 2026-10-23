"""#171 disposable dry-run Office-to-laptop GPX config plan safety tests."""
from datetime import datetime, timezone
from pathlib import Path
import tempfile
import unittest

from gis_workstation_alignment import make_office_repair_plan, load_pinned_laptop_source, make_target_alignment_plan
from gis_workstation_profile import ProfileError, sha256_file, MAPS_KEY, TYPES_KEY, REVERSE_KEY
from gis_workstation_proposal import prepare_laptop_proposal
from test_gis_workstation_profile import FakeRegistry
from test_sync_gis_icons import png, svg


class GUIProposalPinRegressionTests(unittest.TestCase):
    def test_office_review_uses_matching_typed_source_filename(self):
        # The read-only GUI must not silently select an older proposal
        # after the exact laptop-source SHA pin has advanced.
        from gis_workstation_alignment import PINNED_YOGA_PROPOSAL_SHA256
        from pathlib import Path
        gui = (Path(__file__).resolve().parent / "icon_library_manager.pyw").read_text(
            encoding="utf-8")
        self.assertIn(
            "20261014T063601Z-a2f49947d090.json", gui)
        self.assertNotIn(
            "20261013T132823Z-6191db1f5562.json", gui)
        self.assertEqual(
            PINNED_YOGA_PROPOSAL_SHA256,
            "bf09186a9913973c85aecd64f5290e3dd0efdb93459395557013af376e30cfc1")


class OfficeAlignmentPlanTests(unittest.TestCase):
    def setUp(self):
        t = tempfile.TemporaryDirectory()
        self.addCleanup(t.cleanup)
        self.root = Path(t.name)
        self.shared = self.root / "MSB GIS" / "Workstation-Configuration"
        self.shared.parent.mkdir()
        self.plain = self.root / "Plain"
        self.canonical = self.root / "png"
        self.laptop_local = self.root / "laptop-symbols"
        self.office_local = self.root / "office-symbols"
        for p in (self.plain, self.canonical, self.laptop_local,
                  self.office_local):
            p.mkdir()
        (self.plain / "pole-yellow.svg").write_bytes(svg(24, 32))
        (self.canonical / "pole-yellow.png").write_bytes(png(24, 32))
        (self.laptop_local / "pole-yellow.png").write_bytes(png(24, 32))
        for i in range(1, 37):
            icon = f"symbol-{i:02d}"
            (self.plain / f"{icon}.svg").write_bytes(svg(24, 32))
            (self.canonical / f"{icon}.png").write_bytes(png(24, 32))
            (self.laptop_local / f"{icon}.png").write_bytes(png(24, 32))
        laptop = FakeRegistry()
        for i in range(1, 59):
            laptop.keys[TYPES_KEY + f"\\Test Type {i:02d}"] = {
                "Symbol Type": ("1", laptop.REG_SZ),
                "GPS Symbol": (f"Test Symbol {i:02d}", laptop.REG_SZ)}
        aerial = self.root / "laptop-crop.tif"
        aerial.write_bytes(b"disposable only")
        laptop.keys[MAPS_KEY + r"\Ortho 2019"]["Map Path"] = (
            str(aerial), laptop.REG_SZ)
        laptop.keys[MAPS_KEY + r"\Ortho 2019\Point02"] = {
            "Latitude": ("43.7", laptop.REG_SZ),
            "Longitude": ("-87.7", laptop.REG_SZ)}
        self.proposed = prepare_laptop_proposal(
            self.plain, self.canonical, self.shared, "Ortho 2019",
            hostname="YOGA-GREG", reg=laptop,
            local_symbols=self.laptop_local, save=True,
            now=datetime(2026, 10, 13, tzinfo=timezone.utc),
            token="123456abcdef")
        self.path = Path(self.proposed["destination"])
        self.pin = sha256_file(self.path)
        self.office = FakeRegistry()
        self.office.keys[TYPES_KEY + r"\Display Anchor"]["Symbol Type"] = (
            "1", self.office.REG_SZ)
        self.office.keys[TYPES_KEY + r"\Office Only Type"] = {
            "Symbol Type": ("1", self.office.REG_SZ)}
        self.office.keys[REVERSE_KEY]["Flag, Blue"] = (
            "Outlet Power", self.office.REG_SZ)
        self.office.keys[REVERSE_KEY]["Navaid, Green"] = (
            "Display", self.office.REG_SZ)
        self.office_maps_before = dict(self.office.keys[MAPS_KEY + r"\Ortho 2019"])
        (self.office_local / "pole-yellow.png").write_bytes(b"old office")

    def plan(self, host="MSB-OFFICE-PC"):
        return make_office_repair_plan(
            self.path, self.canonical, local_symbols=self.office_local,
            reg=self.office, shared_root=self.shared,
            hostname=host, approved_pin=self.pin)

    def test_pinned_laptop_state_and_explicit_changes(self):
        plan = self.plan()
        self.assertEqual(plan["status"],
                         "READ-ONLY PLAN — OFFICE NOT YET REPAIRED")
        names = {row["type"]: row["action"] for row in plan["type_actions"]}
        self.assertEqual(names["Display Anchor"], "update_Type_fields")
        self.assertEqual(names["Office Only Type"], "remove_obsolete_Office_Type")
        reverses = {row["gps_symbol"]: row for row in plan["reverse_actions"]}
        self.assertEqual(reverses["Flag, Blue"]["laptop"], "Display Anchor")
        self.assertEqual(reverses["Navaid, Green"]["action"], "remove")
        self.assertEqual(len(plan["png_actions"]), 37)
        self.assertTrue(any(row["action"] == "replace_with_backup"
                            for row in plan["png_actions"]))
        self.assertEqual(plan["office_existing_maps"],
                         "NOT TOUCHED OR EVEN READ")
        self.assertFalse(any(k.startswith(MAPS_KEY + "\\")
                             for k in self.office.opened))
        self.assertEqual(self.office.writes, [])
        self.assertEqual(self.office.keys[MAPS_KEY + r"\Ortho 2019"],
                         self.office_maps_before)

    def test_wrong_source_pin_blocked(self):
        with self.assertRaisesRegex(ProfileError, "SHA"):
            make_office_repair_plan(
                self.path, self.canonical, reg=self.office,
                local_symbols=self.office_local, shared_root=self.shared,
                hostname="MSB-OFFICE-PC", approved_pin="0" * 64)
        self.assertEqual(self.office.writes, [])

    def test_cannot_target_laptop_show_or_unrelated_pc(self):
        for hostname in ("YOGA-GREG", "SHOW-PC", "RICH-DESKTOP"):
            with self.subTest(hostname=hostname):
                with self.assertRaisesRegex(ProfileError, "restricted"):
                    self.plan(hostname)
        self.assertEqual(self.office.writes, [])

    def test_other_workstation_comparison_is_readonly(self):
        report = make_target_alignment_plan(
            self.path, self.canonical, local_symbols=self.office_local,
            reg=self.office, shared_root=self.shared,
            hostname="SHOW-TEST", approved_pin=self.pin)
        self.assertEqual(report["target_pc_hostname"], "SHOW-TEST")
        self.assertIn("INSTALLATION NOT AUTHORIZED", report["status"])
        self.assertEqual(report["laptop_type_count"], 59)
        self.assertEqual(self.office.writes, [])

    def test_canonical_png_has_changed_blocks_office_plan(self):
        (self.canonical / "pole-yellow.png").write_bytes(b"not approved")
        with self.assertRaisesRegex(ProfileError, "Canonical PNG no longer matches"):
            self.plan()
        self.assertEqual(self.office.writes, [])

    def test_no_approval_implied_by_reading_submitted_file(self):
        with self.assertRaises(ProfileError):
            load_pinned_laptop_source(self.path, self.shared,
                                      approved_pin="f" * 64)


if __name__ == "__main__":
    unittest.main()
