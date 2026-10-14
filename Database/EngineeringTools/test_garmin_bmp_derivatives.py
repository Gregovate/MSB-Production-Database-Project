"""#171 Garmin named-BMP creation: fail-closed regression tests."""
import io
import json
import tempfile
from pathlib import Path
import unittest

from PIL import Image
from garmin_bmp_derivatives import GarminSyncError, bmp_from_png, load_registry, prepare


def make_png(mode="RGBA", size=(32, 32), color=(12, 34, 56, 255)):
    image = Image.new(mode, size, color)
    b = io.BytesIO()
    image.save(b, "PNG")
    return b.getvalue()


class GarminBMPTests(unittest.TestCase):
    def test_24bit_named_bmp_and_native_dimensions(self):
        payload, dimensions = bmp_from_png(make_png(size=(28, 13)), "switch.png")
        with Image.open(io.BytesIO(payload)) as image:
            self.assertEqual(image.format, "BMP")
            self.assertEqual(image.mode, "RGB")
            self.assertEqual(image.size, (28, 13))
            self.assertEqual(image.getpixel((0, 0)), (12, 34, 56))
        self.assertEqual(int.from_bytes(payload[28:30], "little"), 24)
        self.assertEqual(dimensions, (28, 13))

    def test_magenta_transparency_key(self):
        png = make_png(color=(12, 34, 56, 0))
        payload, _ = bmp_from_png(png, "transparent.png")
        with Image.open(io.BytesIO(payload)) as bmp:
            self.assertEqual(bmp.getpixel((0, 0)), (255, 0, 255))

    def test_semitransparent_artwork_rejected(self):
        with self.assertRaises(GarminSyncError):
            bmp_from_png(make_png(color=(12, 34, 56, 128)), "alpha.png")

    def test_oversize_rejected(self):
        with self.assertRaises(GarminSyncError):
            bmp_from_png(make_png(size=(33, 32)), "large.png")

    def test_unreviewed_symbol_and_type_duplicates_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "registry.json"
            path.write_text(json.dumps({"symbols": [
                {"type": "Panel", "source": "panel.png", "symbol": "PANEL"},
                {"type": "Panel", "source": "stage.png", "symbol": "Stage"}]}))
            with self.assertRaises(GarminSyncError):
                load_registry(path)

    def test_preview_no_writes_and_additions_only(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)
            source, dest = p / "png", p / "bmp"
            source.mkdir()
            (source / "panel.png").write_bytes(make_png())
            registry = p / "registry.json"
            registry.write_text(json.dumps({"symbols": [
                {"type": "Panel", "source": "panel.png", "symbol": "PANEL"}]}))
            preview = prepare(registry, source, dest)
            self.assertEqual(preview["icons"][0]["action"], "create")
            self.assertFalse(dest.exists())
            self.assertTrue(prepare(registry, source, dest, apply=True)["applied"])
            self.assertTrue((dest / "PANEL.bmp").is_file())
            self.assertEqual(prepare(registry, source, dest)["icons"][0]["action"], "identical")
            (source / "panel.png").write_bytes(make_png(color=(30, 40, 50, 255)))
            with self.assertRaisesRegex(GarminSyncError, "Replacement requires"):
                prepare(registry, source, dest, apply=True)
            self.assertEqual(prepare(registry, source, dest)["icons"][0]["action"], "replace")


if __name__ == "__main__":
    unittest.main()
