"""#171 disposable PNG distribution tests. No real G: / Synology / TopoGrafix writes."""
import csv
import os
from pathlib import Path
import struct
import tempfile
import unittest
import zlib
from unittest.mock import patch

from distribute_gis_pngs import (checked_canonical_pngs, distribute_pngs,
                                 local_expertgps_folder, png_distribution_preflight)
from sync_gis_icons import IconError, canonical_sources, sha_file


def svg(w=32, h=32):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
            f'viewBox="0 0 {w} {h}"><rect width="{w}" height="{h}"/></svg>').encode()


def png(w, h):
    def chunk(t, data):
        return (struct.pack(">I", len(data)) + t + data +
                struct.pack(">I", zlib.crc32(t + data) & 0xffffffff))
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    raw = b"".join(b"\x00" + b"\x10\x20\x30\xff" * w for _ in range(h))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) +
            chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


class DistributionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.plain = self.root / "Plain"
        self.plain.mkdir()
        self.canonical = self.root / "png"
        self.canonical.mkdir()
        self.web = self.root / "public-msb"
        self.web.mkdir()
        self.local = self.root / "user-local-msb"
        self.local.mkdir()
        self.stage = self.root / "release"
        self.stage.mkdir()
        self.readme_bytes = (
            b"https://webassets.sheboyganlights.org/images/symbols/\n"
            b"ExpertGPS uses the first line as the parent custom-symbol URL.\n"
        )
        self.readme = self.local / "readme.txt"
        self.readme.write_bytes(self.readme_bytes)
        (self.plain / "car-r.svg").write_bytes(svg(32, 18))
        (self.plain / "antenna-l.svg").write_bytes(svg(32, 32))
        self.sources = canonical_sources(self.plain)
        self.records = []
        for name, (file, source_hash, w, h) in self.sources.items():
            target = self.canonical / (file.stem + ".png")
            target.write_bytes(png(w, h))
            self.records.append(dict(SVG=name, SVG_SHA256=source_hash,
                                     PNG=target.name, Width_PX=w, Height_PX=h,
                                     PNG_SHA256=sha_file(target)))
        self.local_patch = patch("distribute_gis_pngs.local_expertgps_folder",
                                 return_value=self.local)
        self.local_patch.start()

    def tearDown(self):
        self.local_patch.stop()
        self.temp.cleanup()

    def preflight(self, kind="web"):
        dest = self.web if kind == "web" else self.local
        return png_distribution_preflight(kind, dest, self.plain, self.canonical,
                                          self.sources, self.records,
                                          local_readme=self.readme)

    def publish(self, kind="web", progress=None):
        dest = self.web if kind == "web" else self.local
        return distribute_pngs(kind, dest, self.plain, self.canonical,
                               self.sources, self.records, self.stage,
                               local_readme=self.readme, progress=progress)

    def test_public_web_additive_uses_current_pngs_and_preserves_legacy(self):
        (self.web / "Legacy_BMP.bmp").write_bytes(b"untouched")
        preflight = self.preflight()
        self.assertEqual(len(preflight["add"]), 2)
        events = []
        receipt = self.publish(progress=lambda *data: events.append(data))
        self.assertEqual(len(receipt), 2)
        self.assertTrue((self.web / "Legacy_BMP.bmp").is_file())
        self.assertEqual(sha_file(self.web / "car-r.png"),
                         next(r["PNG_SHA256"] for r in self.records if r["PNG"] == "car-r.png"))
        self.assertIn("/msb/car-r.png", receipt[1]["Public_URL"])
        self.assertEqual([e[1] for e in events if e[0] == "distribute" and
                          e[3].endswith("hash verified")], [1, 2])
        self.assertTrue((self.stage / "MSB_GIS_web_PNG_Distribution_Receipt.csv").exists())

    def test_current_user_expertgps_install_preserves_readme(self):
        earlier = self.readme.read_bytes()
        (self.local / "Panel.png").write_bytes(b"legacy old-case name preserved")
        receipt = self.publish("expertgps")
        self.assertEqual(len(receipt), 2)
        self.assertEqual(self.readme.read_bytes(), earlier)
        self.assertEqual((self.local / "Panel.png").read_bytes(), b"legacy old-case name preserved")
        self.assertTrue((self.local / "car-r.png").exists())
        self.assertTrue((self.stage / "MSB_GIS_expertgps_PNG_Distribution_Receipt.csv").is_file())

    def test_replace_backs_up_original_and_hash_verifies(self):
        previous = png(2, 2)
        (self.web / "car-r.png").write_bytes(previous)
        (self.web / "antenna-l.png").write_bytes((self.canonical / "antenna-l.png").read_bytes())
        plan = self.preflight()
        self.assertEqual(len(plan["replace"]), 1)
        self.assertEqual(len(plan["identical"]), 1)
        receipt = self.publish()
        self.assertEqual({r["PNG"]: r["Action"] for r in receipt},
                         {"antenna-l.png": "identical", "car-r.png": "replaced-with-backup"})
        self.assertEqual((self.stage / "web-png-backups-before-replacement" /
                          "car-r.png").read_bytes(), previous)
        self.assertEqual(sha_file(self.web / "car-r.png"), sha_file(self.canonical / "car-r.png"))

    def test_case_collision_rejects_before_write(self):
        (self.web / "Car-R.png").write_bytes(b"legacy")
        with self.assertRaises(IconError):
            self.publish()
        self.assertEqual([p.name for p in self.web.iterdir()], ["Car-R.png"])

    def test_readme_missing_or_wrong_blocks_local(self):
        self.readme.unlink()
        with self.assertRaises(IconError):
            self.publish("expertgps")
        self.assertFalse((self.local / "car-r.png").exists())
        self.readme.write_bytes(b"https://wrong.example/icons/\n")
        with self.assertRaises(IconError):
            self.publish("expertgps")
        self.assertFalse((self.local / "car-r.png").exists())

    def test_canonical_folder_must_be_saved_and_match_manifest(self):
        (self.canonical / "car-r.png").unlink()
        with self.assertRaisesRegex(IconError, "Save approved PNG changes"):
            self.publish()
        self.assertFalse(list(self.web.iterdir()))

    def test_source_changed_after_scan_aborts(self):
        (self.plain / "car-r.svg").write_bytes(svg(16, 16))
        with self.assertRaises(IconError):
            self.publish()
        self.assertFalse(list(self.web.iterdir()))

    def test_new_plain_icon_added_after_scan_aborts(self):
        (self.plain / "antenna-r.svg").write_bytes(svg(32, 32))
        with self.assertRaises(IconError):
            self.publish()
        self.assertFalse(list(self.web.iterdir()))

    def test_wrong_source_canvas_or_hash_rejected(self):
        (self.canonical / "car-r.png").write_bytes(png(121, 121))
        self.records[1]["PNG_SHA256"] = sha_file(self.canonical / "car-r.png")
        with self.assertRaises(IconError):
            self.publish()

    def test_missing_destination_not_created(self):
        self.web.rmdir()
        with self.assertRaises(IconError):
            self.publish()
        self.assertFalse(self.web.exists())

    def test_distribution_destinations_are_independent(self):
        self.publish("expertgps")
        self.assertFalse(list(self.web.iterdir()))
        self.assertEqual(len(self.preflight("expertgps")["identical"]), 2)
        self.publish("web")
        self.assertTrue((self.web / "car-r.png").exists())

    def test_local_user_folder_is_enforced(self):
        with patch("distribute_gis_pngs.local_expertgps_folder",
                   return_value=self.root / "other-account"):
            with self.assertRaisesRegex(IconError, "current Windows user"):
                self.publish("expertgps")
        self.assertFalse((self.local / "car-r.png").exists())


if __name__ == "__main__":
    unittest.main()
