"""Disposable #171 live-web SVG synchronization tests; all paths are temp dirs.

Never reaches the real G: Drive or private Synology share.
"""
from pathlib import Path
import tempfile
import unittest

from publish_gis_svgs import publish_web_svgs, web_svg_preflight
from sync_gis_icons import IconError, canonical_sources, sha_file


def svg(w=32, h=32, fill="red"):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}px" height="{h}px" '
            f'viewBox="0 0 {w} {h}"><rect width="{w}" height="{h}" fill="{fill}"/></svg>').encode()


class WebSVGTests(unittest.TestCase):
    def setUp(self):
        self.t = tempfile.TemporaryDirectory()
        self.root = Path(self.t.name)
        self.plain = self.root / "Plain"
        self.plain.mkdir()
        self.public = self.root / "msb-svg"
        self.public.mkdir()
        self.stage = self.root / "run"
        self.stage.mkdir()
        (self.plain / "car-r.svg").write_bytes(svg(32, 18))
        (self.plain / "antenna-l.svg").write_bytes(svg(32, 32))
        self.sources = canonical_sources(self.plain)

    def tearDown(self):
        self.t.cleanup()

    def test_additive_publish_preserves_existing_unrelated_file(self):
        (self.public / "legacy.svg").write_bytes(b"legacy marker")
        plan = web_svg_preflight(self.public, self.sources)
        self.assertEqual(len(plan["add"]), 2)
        self.assertEqual(len(plan["identical"]), 0)
        events = []
        receipt = publish_web_svgs(self.plain, self.public, self.stage, self.sources,
                                   progress=lambda *parts: events.append(parts))
        self.assertEqual(len(receipt), 2)
        self.assertTrue((self.public / "legacy.svg").is_file())
        self.assertEqual(sha_file(self.public / "car-r.svg"), self.sources["car-r.svg"][1])
        self.assertEqual([x[1] for x in events if x[0] == "publish" and
                          x[3].endswith("remote hash verified")], [1, 2])
        self.assertTrue((self.stage / "MSB_GIS_Web_SVG_Publication_Receipt.csv").exists())

    def test_replace_with_backup_and_unchanged_other_icon(self):
        old_bytes = svg(32, 18, "yellow")
        (self.public / "car-r.svg").write_bytes(old_bytes)
        (self.public / "antenna-l.svg").write_bytes((self.plain / "antenna-l.svg").read_bytes())
        plan = web_svg_preflight(self.public, self.sources)
        self.assertEqual(plan["replace"], ["car-r.svg"])
        self.assertEqual(plan["identical"], ["antenna-l.svg"])
        receipt = publish_web_svgs(self.plain, self.public, self.stage, self.sources)
        self.assertEqual({r["SVG"]: r["Action"] for r in receipt},
                         {"car-r.svg": "replaced-with-backup", "antenna-l.svg": "identical"})
        self.assertEqual((self.stage / "web-svg-backups-before-replacement" / "car-r.svg").read_bytes(),
                         old_bytes)
        self.assertEqual((self.public / "car-r.svg").read_bytes(), (self.plain / "car-r.svg").read_bytes())

    def test_case_collision_fails_before_server_mutation(self):
        (self.public / "CAR-R.svg").write_bytes(b"historic")
        with self.assertRaises(IconError):
            publish_web_svgs(self.plain, self.public, self.stage, self.sources)
        self.assertEqual([p.name for p in self.public.iterdir()], ["CAR-R.svg"])

    def test_verified_historical_case_alias_allows_other_icons_without_renaming(self):
        # October 11 real web issue: msb-splitter-Combiner.svg is exactly the
        # current approved lowercase source by SHA, but its lowercase HTTPS URL
        # does NOT resolve. Keep the historical name, never attempt a case rename.
        (self.plain / "msb-splitter-combiner.svg").write_bytes(svg(24, 16))
        self.sources = canonical_sources(self.plain)
        old_name = "msb-splitter-Combiner.svg"
        (self.public / old_name).write_bytes(
            (self.plain / "msb-splitter-combiner.svg").read_bytes())
        plan = web_svg_preflight(self.public, self.sources)
        self.assertEqual(plan["legacy_case_identical"],
                         {"msb-splitter-combiner.svg": old_name})
        self.assertEqual(len(plan["add"]), 2)
        receipt = publish_web_svgs(self.plain, self.public, self.stage, self.sources)
        alias = next(row for row in receipt
                     if row["SVG"] == "msb-splitter-combiner.svg")
        self.assertEqual(alias["Action"], "legacy-case-identical")
        self.assertTrue(alias["Public_URL"].endswith("/" + old_name))
        self.assertTrue((self.public / old_name).exists())
        self.assertFalse((self.public / "msb-splitter-combiner.svg").exists())
        self.assertTrue((self.public / "car-r.svg").exists())
        self.assertTrue((self.public / "antenna-l.svg").exists())

    def test_historical_case_alias_different_bytes_still_blocks_every_write(self):
        (self.plain / "msb-splitter-combiner.svg").write_bytes(svg(24, 16))
        self.sources = canonical_sources(self.plain)
        existing = self.public / "msb-splitter-Combiner.svg"
        existing.write_bytes(svg(24, 16, "blue"))
        with self.assertRaisesRegex(IconError, "contains different bytes"):
            publish_web_svgs(self.plain, self.public, self.stage, self.sources)
        self.assertEqual([p.name for p in self.public.iterdir()],
                         ["msb-splitter-Combiner.svg"])

    def test_historical_case_alias_modified_after_preview_stops_before_writing(self):
        (self.plain / "msb-splitter-combiner.svg").write_bytes(svg(24, 16))
        self.sources = canonical_sources(self.plain)
        existing = self.public / "msb-splitter-Combiner.svg"
        existing.write_bytes((self.plain / "msb-splitter-combiner.svg").read_bytes())
        plan = web_svg_preflight(self.public, self.sources)
        self.assertEqual(len(plan["legacy_case_identical"]), 1)
        existing.write_bytes(svg(24, 16, "yellow"))
        with self.assertRaises(IconError):
            publish_web_svgs(self.plain, self.public, self.stage, self.sources)
        self.assertFalse((self.public / "car-r.svg").exists())
        self.assertFalse((self.public / "antenna-l.svg").exists())

    def test_added_or_mutated_source_refused(self):
        (self.plain / "new-icon.svg").write_bytes(svg(24, 30))
        with self.assertRaises(IconError):
            publish_web_svgs(self.plain, self.public, self.stage, self.sources)
        self.assertFalse(list(self.public.iterdir()))
        (self.plain / "new-icon.svg").unlink()
        (self.plain / "car-r.svg").write_bytes(svg(32, 18, "blue"))
        with self.assertRaises(IconError):
            publish_web_svgs(self.plain, self.public, self.stage, self.sources)
        self.assertFalse(list(self.public.iterdir()))

    def test_missing_server_share_never_created(self):
        missing = self.root / "unavailable-msb-svg"
        with self.assertRaises(IconError):
            web_svg_preflight(missing, self.sources)
        self.assertFalse(missing.exists())

    def test_reject_scripted_svg_without_publishing(self):
        self.assertFalse(list(self.public.iterdir()))
        scripted = (b'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32">'
                    b'<script>alert(1)</script></svg>')
        (self.plain / "antenna-l.svg").write_bytes(scripted)
        sources = canonical_sources(self.plain)
        with self.assertRaises(IconError):
            publish_web_svgs(self.plain, self.public, self.stage, sources)
        self.assertFalse(list(self.public.iterdir()))

    def test_allow_embedded_gradient_reference_in_svg_css(self):
        gradient = (b'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32">'
                    b'<defs><linearGradient id="shine"><stop offset="0"/></linearGradient></defs>'
                    b'<style>.shape { fill:url(#shine) }</style>'
                    b'<rect class="shape" width="32" height="32"/></svg>')
        (self.plain / "antenna-l.svg").write_bytes(gradient)
        sources = canonical_sources(self.plain)
        plan = web_svg_preflight(self.public, sources)
        self.assertEqual(len(plan["add"]), 2)

    def test_reject_mm_source_before_web_copy(self):
        (self.plain / "antenna-l.svg").write_bytes(
            b'<svg xmlns="http://www.w3.org/2000/svg" width="32mm" height="32mm"/>')
        with self.assertRaises(IconError):
            canonical_sources(self.plain)
        self.assertFalse(list(self.public.iterdir()))


if __name__ == "__main__":
    unittest.main()
