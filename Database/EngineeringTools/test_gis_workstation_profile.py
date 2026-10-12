"""Disposable #171 workstation release comparison tests; no HKCU/G:/Production access."""
import copy
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from gis_workstation_profile import (SCHEMA, MAPS_KEY, REVERSE_KEY, TYPES_KEY,
    ProfileError, read_current_user, load_release, compare_release, sha256)


class FakeKey:
    def __init__(self, path):
        self.path = path

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False


class FakeRegistry:
    HKEY_CURRENT_USER = "HKCU"
    KEY_READ = 0x20019
    REG_SZ = 1
    REG_DWORD = 4

    def __init__(self):
        self.keys = {
            TYPES_KEY: {},
            TYPES_KEY + r"\Display Anchor": {
                "Symbol Type": ("2", self.REG_SZ),
                "GPS Symbol": ("Flag, Blue", self.REG_SZ),
                "Bitmap Symbol URL":
                    ("https://webassets.sheboyganlights.org/images/symbols/msb/pole-yellow.png",
                     self.REG_SZ),
                "Private Vendor Setting": ("do-not-surface", self.REG_SZ),
            },
            REVERSE_KEY: {"Flag, Blue": ("Display Anchor", self.REG_SZ)},
            MAPS_KEY: {},
            MAPS_KEY + r"\Ortho 2019": {
                "Map Path": ("Z:\\Different PCs\\map.tif", self.REG_SZ),
                "Width": (18281, self.REG_DWORD),
                "Height": (9492, self.REG_DWORD),
                "Projection": ("UTM", self.REG_SZ),
                "Use Worldfile Data": (1, self.REG_DWORD),
            },
            MAPS_KEY + r"\Ortho 2019\Point01": {
                "X": ("7", self.REG_SZ), "Y": ("8", self.REG_SZ),
                "Latitude": ("43.7", self.REG_SZ),
                "Longitude": ("-87.7", self.REG_SZ),
                "Worldfile X": ("1", self.REG_SZ),
            },
        }
        self.opened = []
        self.writes = []

    def OpenKey(self, hive, path, options, access):
        assert hive == self.HKEY_CURRENT_USER and access == self.KEY_READ
        self.opened.append(path)
        if path not in self.keys:
            raise FileNotFoundError(path)
        return FakeKey(path)

    def EnumKey(self, key, index):
        children = sorted({name[len(key.path) + 1:].split("\\")[0]
                           for name in self.keys if name.startswith(key.path + "\\")})
        if index >= len(children):
            raise OSError("No more data")
        return children[index]

    def QueryValueEx(self, key, name):
        if name not in self.keys[key.path]:
            raise FileNotFoundError(name)
        return self.keys[key.path][name]

    def EnumValue(self, key, index):
        rows = list(self.keys[key.path].items())
        if index >= len(rows):
            raise OSError("No more data")
        name, (val, kind) = rows[index]
        return name, val, kind


def release_fixture(root):
    icon = b"\x89PNG\r\n\x1a\n---only-test-fixture---"
    bundle = root / "approved"
    (bundle / "msb").mkdir(parents=True)
    (bundle / "msb" / "pole-yellow.png").write_bytes(icon)
    source = FakeRegistry()
    map_image = root / "ortho-test.tif"
    map_image.write_bytes(b"disposable 2019 orthophoto identity test")
    source.keys[MAPS_KEY + r"\Ortho 2019"]["Map Path"] = (str(map_image), source.REG_SZ)
    profile = read_current_user(source, root / "local")
    (root / "local").mkdir()
    (root / "local" / "pole-yellow.png").write_bytes(icon)
    manifest = {
        "schema": SCHEMA, "release_id": "MSB-GIS-2026.10.12-test",
        "approved_by": "Fixture administrator", "approved_utc": "2026-10-12T00:00:00Z",
        "types": profile["types"], "symbol_to_type": profile["symbol_to_type"],
        "maps": {name: {"calibration": entry["calibration"],
                         "points": entry["points"],
                         "image_sha256": entry["image_sha256"]}
                 for name, entry in profile["maps"].items()},
        "files": {"msb/pole-yellow.png": sha256(icon)},
    }
    path = bundle / "manifest.json"
    raw = (json.dumps(manifest, sort_keys=True, separators=(",", ":")) + "\n").encode()
    path.write_bytes(raw)
    return path, sha256(raw), profile, manifest


class WorkstationReadOnlyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.path, self.pin, self.profile, self.manifest = release_fixture(self.root)

    def test_precise_hkcu_projection_excludes_personal_settings(self):
        reg = FakeRegistry()
        profile = read_current_user(reg, self.root / "local")
        self.assertIn("Display Anchor", profile["types"])
        self.assertEqual(profile["symbol_to_type"]["Flag, Blue"], "Display Anchor")
        self.assertNotIn("Private Vendor Setting", str(profile))
        self.assertNotIn("Z:\\Different PCs", str(profile))
        self.assertTrue(all(name.startswith(r"Software\TopoGrafix\Common")
                            for name in reg.opened))
        self.assertEqual(reg.writes, [])

    def test_unrelated_personal_maps_are_not_opened(self):
        reg = FakeRegistry()
        reg.keys[MAPS_KEY + r"\Unrelated private map"] = {
            "Map Path": (r"C:\Personal\Private.png", reg.REG_SZ),
            "Latitude": ("unrelated", reg.REG_SZ),
        }
        profile = read_current_user(reg, self.root / "local",
                                    map_names={"Ortho 2019"})
        self.assertEqual(set(profile["maps"]), {"Ortho 2019"})
        self.assertFalse(any("Unrelated private map" in name for name in reg.opened))
        self.assertNotIn("Private.png", str(profile))

    def test_pinned_release_hash_and_unchanged_current_profile(self):
        release = load_release(self.path, self.pin)
        r = compare_release(release, self.profile)
        self.assertEqual(r["status"], "Current")
        self.assertEqual(r["differences"], [])
        self.assertFalse(r["workstation_accepted_for_two_way"])

    def test_mismatched_type_and_reverse_are_not_conflated_with_gps_sym(self):
        changed = copy.deepcopy(self.profile)
        changed["types"].pop("Display Anchor")
        changed["types"]["Flag"] = {
            "Symbol Type": "2", "GPS Symbol": "Flag, Blue",
            "Bitmap Symbol URL": self.manifest["types"]["Display Anchor"]["Bitmap Symbol URL"]}
        changed["symbol_to_type"]["Flag, Blue"] = "Flag"
        diff = compare_release(load_release(self.path, self.pin), changed)
        self.assertEqual(diff["status"], "Not verified")
        text = json.dumps(diff)
        self.assertIn("Display Anchor", text)
        self.assertIn("Flag, Blue", text)
        self.assertIn("symbol_to_type", text)
        self.assertIn("pole-yellow.png", text)

    def test_missing_local_icon_fails_comparison_without_writing(self):
        (self.root / "local" / "pole-yellow.png").unlink()
        r = compare_release(load_release(self.path, self.pin), self.profile)
        self.assertEqual(r["status"], "Not verified")
        self.assertTrue(any(x["field"].startswith("/files/msb") for x in r["differences"]))

    def test_calibration_mismatch_without_machine_path_sync(self):
        changed = copy.deepcopy(self.profile)
        changed["maps"]["Ortho 2019"]["points"]["Point01"]["Latitude"] = "44.1"
        r = compare_release(load_release(self.path, self.pin), changed)
        self.assertEqual(r["status"], "Not verified")
        self.assertTrue(any("Latitude" in x["field"] for x in r["differences"]))
        self.assertNotIn("Z:\\", json.dumps(r))

    def test_missing_map_image_prevents_current_status(self):
        changed = copy.deepcopy(self.profile)
        changed["maps"]["Ortho 2019"]["image_sha256"] = None
        changed["maps"]["Ortho 2019"]["image_file_verified"] = False
        r = compare_release(load_release(self.path, self.pin), changed)
        self.assertEqual(r["status"], "Not verified")
        self.assertEqual(r["unverifiable_maps"], ["Ortho 2019"])

    def test_digest_tampering_and_unsupported_schema_refused(self):
        with self.assertRaisesRegex(ProfileError, "SHA-256 disagrees"):
            load_release(self.path, "0" * 64)
        self.path.write_text(self.path.read_text() + "\n")
        with self.assertRaisesRegex(ProfileError, "SHA-256 disagrees"):
            load_release(self.path, self.pin)

    def test_package_asset_tamper_refused_even_with_valid_manifest(self):
        (self.path.parent / "msb" / "pole-yellow.png").write_bytes(b"tampered")
        with self.assertRaisesRegex(ProfileError, "artifact hash mismatch"):
            load_release(self.path, self.pin)

    def test_traversal_refused_even_if_manifest_is_reapproved(self):
        manifest = dict(self.manifest)
        manifest["files"] = {"../outside": "a" * 64}
        raw = json.dumps(manifest).encode()
        self.path.write_bytes(raw)
        with self.assertRaisesRegex(ProfileError, "Unsafe relative release path"):
            load_release(self.path, sha256(raw))

    def test_missing_or_untrusted_release_not_verified(self):
        with self.assertRaises(ProfileError):
            load_release(self.root / "missing.json", "f" * 64)
        with self.assertRaises(ProfileError):
            load_release(self.path, "")

    def test_differences_without_verified_base_must_not_guess_update_vs_local(self):
        new_profile = copy.deepcopy(self.profile)
        new_profile["symbol_to_type"]["Flag, Blue"] = "Outlet Power"
        r = compare_release(load_release(self.path, self.pin), new_profile)
        self.assertEqual(r["status"], "Not verified")
        self.assertNotIn(r["status"], ["Update available", "Local unpublished changes", "Conflict"])

    def test_verified_base_three_way_classification(self):
        release = load_release(self.path, self.pin)
        new_profile = copy.deepcopy(self.profile)
        # Both local and approved changed the same value since verified base.
        old_base = {
            "types": self.profile["types"],
            "symbol_to_type": {"Flag, Blue": "Old"},
            "maps": {name: {"calibration": r["calibration"], "points": r["points"],
                            "image_sha256": r["image_sha256"]}
                     for name, r in self.profile["maps"].items()},
            "files": {"msb/pole-yellow.png": self.manifest["files"]["msb/pole-yellow.png"]},
        }
        new_profile["symbol_to_type"]["Flag, Blue"] = "Flag"
        r = compare_release(release, new_profile, verified_base=old_base)
        self.assertEqual(r["status"], "Conflict")
        # A release-only update is distinguishable with trusted prior base.
        new_profile["symbol_to_type"]["Flag, Blue"] = "Old"
        r = compare_release(release, new_profile, verified_base=old_base)
        self.assertEqual(r["status"], "Update available")


if __name__ == "__main__":
    unittest.main()
