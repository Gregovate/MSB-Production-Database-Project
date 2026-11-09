"""#171 disposable test of shared Symbol Library rename and inventory."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from gis_symbol_library_migration import MigrationError, inspect, migrate


def digest(files):
    return hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest()


class LibraryMigrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        old = self.root / "Symbols"
        for folder in ("Masters", "Plain", "png", "release-history"):
            (old / folder).mkdir(parents=True)
            (old / folder / "sample.txt").write_text(folder, encoding="utf-8")

    def tearDown(self):
        self.temp.cleanup()

    def test_review_only(self):
        previous = inspect(self.root)
        self.assertEqual(previous["state"], "NOT_MIGRATED")
        self.assertTrue((self.root / "Symbols").is_dir())
        self.assertFalse((self.root / "Symbol Library").exists())

    def test_rename_preserves_every_file(self):
        before = inspect(self.root)
        result = migrate(self.root, approved_digest=digest(before["files"]))
        self.assertEqual(result["status"], "VERIFIED")
        self.assertEqual(inspect(self.root)["files"], before["files"])
        self.assertFalse((self.root / "Symbols").exists())

    def test_changed_digest_stops_without_move(self):
        with self.assertRaisesRegex(MigrationError, "Inventory changed"):
            migrate(self.root, approved_digest="0" * 64)
        self.assertTrue((self.root / "Symbols").is_dir())

    def test_dual_roots_stop_without_merging(self):
        (self.root / "Symbol Library").mkdir()
        with self.assertRaisesRegex(MigrationError, "Both library roots"):
            inspect(self.root)


if __name__ == "__main__":
    unittest.main()
