"""Disposable verification for controlled Garmin BMP backup/promotion."""
import json
from pathlib import Path
import tempfile
import unittest
import io

from PIL import Image

from garmin_bmp_derivatives import GarminSyncError
from garmin_bmp_promotion import review, promote


def png(color):
    im = Image.new("RGBA", (24, 16), (*color, 255))
    buf = io.BytesIO()
    im.save(buf, "PNG")
    return buf.getvalue()


class PromotionTests(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.TemporaryDirectory()
        root = Path(self.t.name)
        self.images, self.target, self.backups = [root / n for n in ("png", "bmp", "backups")]
        for folder in (self.images, self.target, self.backups):
            folder.mkdir()
        self.mapping = root / "registry.json"
        self.mapping.write_text(json.dumps({"symbols": [
            {"type": "Panel", "source": "panel.png", "symbol": "PANEL"}]}))
        (self.images / "panel.png").write_bytes(png((20, 30, 40)))

    def tearDown(self):
        self.t.cleanup()

    def test_add_then_verified_replace_with_backup(self):
        before = review(self.mapping, self.images, self.target)
        self.assertEqual(before["icons"][0]["action"], "create")
        receipt = promote(self.mapping, self.images, self.target, self.backups, before["review_digest"])
        self.assertEqual(json.loads((receipt / "receipt.json").read_text())["status"], "VERIFIED")
        original = (self.target / "panel.bmp").read_bytes()
        (self.images / "panel.png").write_bytes(png((40, 50, 60)))
        candidate = review(self.mapping, self.images, self.target)
        self.assertEqual(candidate["icons"][0]["action"], "replace")
        release = promote(self.mapping, self.images, self.target, self.backups, candidate["review_digest"])
        self.assertEqual((release / "before" / "panel.bmp").read_bytes(), original)
        self.assertNotEqual((self.target / "panel.bmp").read_bytes(), original)
        self.assertEqual(json.loads((release / "receipt.json").read_text())["status"], "VERIFIED")

    def test_first_release_creates_missing_bmp_directory(self):
        self.target.rmdir()
        before = review(self.mapping, self.images, self.target)
        self.assertFalse(self.target.exists())
        receipt = promote(self.mapping, self.images, self.target,
                          self.backups, before["review_digest"])
        self.assertTrue((self.target / "panel.bmp").is_file())
        self.assertEqual(json.loads((receipt / "receipt.json").read_text())["status"], "VERIFIED")

    def test_missing_destination_not_created_on_stale_approval(self):
        self.target.rmdir()
        plan = review(self.mapping, self.images, self.target)
        (self.images / "panel.png").write_bytes(png((1, 2, 3)))
        with self.assertRaisesRegex(GarminSyncError, "Plan changed"):
            promote(self.mapping, self.images, self.target,
                    self.backups, plan["review_digest"])
        self.assertFalse(self.target.exists())

    def test_changed_source_after_preview_stops(self):
        plan = review(self.mapping, self.images, self.target)
        (self.images / "panel.png").write_bytes(png((77, 88, 99)))
        with self.assertRaisesRegex(GarminSyncError, "Plan changed"):
            promote(self.mapping, self.images, self.target, self.backups, plan["review_digest"])
        self.assertEqual(list(self.target.iterdir()), [])

    def test_case_collision_stops(self):
        (self.target / "PANEL.bmp").write_bytes(b"old")
        with self.assertRaisesRegex(GarminSyncError, "case collision"):
            review(self.mapping, self.images, self.target)


if __name__ == "__main__":
    unittest.main()
