"""Disposable targeted Office registry/native-backup/icon repair tests for #171."""
import copy
import json
from pathlib import Path
import unittest
from unittest.mock import patch

from gis_workstation_alignment import make_office_repair_plan
from gis_workstation_install import (
    apply_office_repair, restore_office_private_backup,
    snapshot_managed_registry, assert_expertgps_closed)
from gis_workstation_profile import ProfileError, TYPES_KEY, REVERSE_KEY, MAPS_KEY, sha256
from test_gis_workstation_alignment import OfficeAlignmentPlanTests, FakeRegistry, png


class WritableRegistry(FakeRegistry):
    KEY_WRITE = 0x20006

    def __init__(self, values):
        super().__init__()
        self.keys = copy.deepcopy(values)
        self.writes = []

    def OpenKey(self, hive, path, options, access):
        assert hive == self.HKEY_CURRENT_USER
        assert access in (self.KEY_READ, self.KEY_READ | self.KEY_WRITE)
        self.opened.append(path)
        if path not in self.keys:
            raise FileNotFoundError(path)
        from test_gis_workstation_profile import FakeKey
        return FakeKey(path)

    def CreateKeyEx(self, hive, path, reserved, access):
        assert hive == self.HKEY_CURRENT_USER and access == self.KEY_WRITE
        self.keys.setdefault(path, {})
        self.writes.append(("create", path))
        from test_gis_workstation_profile import FakeKey
        return FakeKey(path)

    def DeleteKey(self, hive, path):
        assert hive == self.HKEY_CURRENT_USER
        if path not in self.keys:
            raise FileNotFoundError(path)
        if any(k.startswith(path + "\\") for k in self.keys):
            raise OSError("Registry key has subkeys")
        del self.keys[path]
        self.writes.append(("delete", path))

    def SetValueEx(self, key, name, reserved, kind, value):
        self.keys[key.path][name] = (value, kind)
        self.writes.append(("set", key.path, name))

    def DeleteValue(self, key, name):
        del self.keys[key.path][name]
        self.writes.append(("delete-value", key.path, name))


class OfficeInstallTests(OfficeAlignmentPlanTests):
    def setUp(self):
        super().setUp()
        self.office = WritableRegistry(self.office.keys)
        self.expected_maps = copy.deepcopy({
            key: value for key, value in self.office.keys.items()
            if key == MAPS_KEY or key.startswith(MAPS_KEY + "\\")
        })
        self.backups = self.root / "private-recovery"
        self.office_reg_original = copy.deepcopy(self.office.keys)

    def install(self, confirmed=True, expected_digest=None, checker=None):
        plan = self.plan()
        digest = sha256(json.dumps(
            plan, sort_keys=True, ensure_ascii=False).encode("utf-8"))
        return apply_office_repair(
            self.path, self.canonical, expected_plan_sha256=(
                expected_digest if expected_digest is not None else digest),
            local_symbols=self.office_local, reg=self.office,
            shared_root=self.shared, hostname="MSB-OFFICE-PC",
            private_backup_base=self.backups,
            closed_checker=checker if checker is not None else (lambda: True),
            approval_confirmed=confirmed)

    def test_success_targeted_parity_and_private_rollback_exists(self):
        receipt = self.install()
        self.assertIn("MATCHES PINNED LAPTOP", receipt["status"])
        self.assertEqual(receipt["type_count"], 59)
        self.assertEqual(receipt["canonical_png_count"], 37)
        self.assertEqual(len(self.office.keys[TYPES_KEY + r"\Display Anchor"]), 3)
        self.assertEqual(
            self.office.keys[REVERSE_KEY]["Flag, Blue"][0], "Display Anchor")
        self.assertNotIn(TYPES_KEY + r"\Office Only Type", self.office.keys)
        new = self.plan()
        self.assertEqual(new["type_actions"], [])
        self.assertEqual(new["reverse_actions"], [])
        self.assertEqual(new["png_actions"], [])
        private = Path(receipt["private_rollback_backup"])
        self.assertTrue((private / "backup.json").is_file())
        self.assertTrue((private / "original-msb" / "pole-yellow.png").is_file())
        self.assertEqual(
            (private / "original-msb" / "pole-yellow.png").read_bytes(),
            b"old office")
        self.assertTrue((private / "repair-receipt.json").is_file())
        self.assertTrue((self.office_local / "readme.txt").is_file())
        for key, value in self.expected_maps.items():
            self.assertEqual(self.office.keys[key], value)
        self.assertFalse((self.shared / "Releases").exists())

    def test_legacy_png_filename_case_is_reviewed_and_reversible(self):
        old = self.office_local / "pole-yellow.png"
        legacy = self.office_local / "Pole-Yellow.png"
        old.rename(legacy)
        plan = self.plan()
        self.assertTrue(any(row["file"] == "pole-yellow.png" and
                            row["case_alias"] and
                            row["existing_filename"] == "Pole-Yellow.png"
                            for row in plan["png_actions"]))
        receipt = self.install()
        self.assertTrue((self.office_local / "pole-yellow.png").is_file())
        self.assertFalse(legacy.exists())
        backup = Path(receipt["private_rollback_backup"])
        self.assertTrue((backup / "original-msb" / "Pole-Yellow.png").is_file())
        restore_office_private_backup(
            backup, reg=self.office, local_symbols=self.office_local,
            hostname="MSB-OFFICE-PC", private_backup_base=self.backups,
            closed_checker=lambda: True, approval_confirmed=True)
        self.assertTrue(legacy.is_file())
        self.assertEqual(legacy.read_bytes(), b"old office")

    def test_explicit_local_recovery_restores_original_office_fields(self):
        receipt = self.install()
        self.assertTrue(Path(receipt["shared_receipt"]).is_file())
        shared = json.loads(Path(receipt["shared_receipt"]).read_text())
        self.assertEqual(shared["gpxtest_status"], "NOT YET ACCEPTED")
        self.assertNotIn("private_rollback_backup", shared)
        self.assertEqual(shared["host"], "MSB-OFFICE-PC")
        result = restore_office_private_backup(
            receipt["private_rollback_backup"], reg=self.office,
            local_symbols=self.office_local, hostname="MSB-OFFICE-PC",
            private_backup_base=self.backups,
            closed_checker=lambda: True, approval_confirmed=True)
        self.assertIn("RESTORED", result["status"])
        self.assertEqual(self.office.keys, self.office_reg_original)
        self.assertEqual((self.office_local / "pole-yellow.png").read_bytes(),
                         b"old office")
        self.assertFalse((self.office_local / "readme.txt").exists())

    def test_recovery_rejects_wrong_backup_root_before_mutation(self):
        with self.assertRaisesRegex(ProfileError, "private recovery root"):
            restore_office_private_backup(
                self.root / "untrusted-network-path", reg=self.office,
                local_symbols=self.office_local, hostname="MSB-OFFICE-PC",
                private_backup_base=self.backups,
                closed_checker=lambda: True, approval_confirmed=True)
        self.assertEqual(self.office.writes, [])

    def test_declined_operator_confirmation_writes_nothing(self):
        with self.assertRaisesRegex(ProfileError, "confirmation"):
            self.install(confirmed=False)
        self.assertEqual(self.office.writes, [])
        self.assertFalse(self.backups.exists())

    def test_expertgps_still_running_blocks_before_backup(self):
        with self.assertRaisesRegex(ProfileError, "closed"):
            self.install(checker=lambda: False)
        self.assertEqual(self.office.writes, [])
        self.assertFalse(self.backups.exists())

    def test_changed_after_review_blocks_before_backup(self):
        with self.assertRaisesRegex(ProfileError, "changed since preview"):
            self.install(expected_digest="a" * 64)
        self.assertEqual(self.office.writes, [])
        self.assertFalse(self.backups.exists())

    def test_failure_after_registry_mutation_automatically_restores(self):
        import gis_workstation_install as install
        original_copy = install.shutil.copy2
        def fail_on_approved(source, dest, *args, **kwargs):
            if (str(dest).startswith(str(self.office_local)) and
                    str(dest).endswith(".png")):
                raise OSError("simulated write failure")
            return original_copy(source, dest, *args, **kwargs)
        with patch.object(install.shutil, "copy2", side_effect=fail_on_approved):
            with self.assertRaisesRegex(ProfileError, "restored"):
                self.install()
        for path, values in self.office_reg_original.items():
            self.assertEqual(self.office.keys.get(path), values, path)
        self.assertEqual(self.office.keys.keys(), self.office_reg_original.keys())
        self.assertEqual((self.office_local / "pole-yellow.png").read_bytes(),
                         b"old office")
        for key, value in self.expected_maps.items():
            self.assertEqual(self.office.keys[key], value)
        self.assertTrue(list(self.backups.rglob("backup.json")))

    def test_unrecognized_readme_stops_before_any_setting_changes(self):
        (self.office_local / "readme.txt").write_text("bad unapproved parent\n")
        with self.assertRaisesRegex(ProfileError, "readme URL parent"):
            self.install()
        self.assertEqual(self.office.writes, [])
        self.assertFalse(self.backups.exists())


if __name__ == "__main__":
    unittest.main()
