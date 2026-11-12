"""Standard-library regression checks for read-only #171 symbol inventory."""
import unittest

from inventory_gis_symbols import name_key, record, scope_for, svg_details


class InventoryGISIconsTests(unittest.TestCase):
    def test_plain_svg_without_editor_metadata_is_plain_like(self):
        data = b'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="16"/>'
        parsed = svg_details(data)
        self.assertEqual(parsed[0], "PLAIN_LIKE_NO_EDITOR_METADATA")
        self.assertEqual(parsed[2:4], ("32", "16"))

    def test_editor_metadata_is_recognized_even_with_plain_filename(self):
        data = (b'<svg xmlns="http://www.w3.org/2000/svg" '
                b'xmlns:inkscape="http://www.inkscape.org/namespaces/inkscape" '
                b'xmlns:sodipodi="http://sodipodi.sourceforge.net/DTD/sodipodi-0.dtd">'
                b'<sodipodi:namedview id="nv" inkscape:zoom="2"/></svg>')
        self.assertEqual(svg_details(data)[0], "INKSCAPE_METADATA_PRESENT")
        self.assertGreater(svg_details(data)[1], 0)

    def test_invalid_svg_cannot_be_classified_as_plain(self):
        self.assertEqual(svg_details(b'<svg><path></svg>')[0], "INVALID_SVG")

    def test_historical_misspelled_master_suffix_is_alias_hint_only(self):
        self.assertEqual(name_key("IP-camera-inskape.svg"), "ip-camera")
        self.assertEqual(name_key("Stage-inksccape.svg"), "stage")
        self.assertEqual(name_key("LP_Power-inscape.svg"), "lp-power")
        self.assertEqual(name_key("msb-splitter-Combiner.svg"), "msb-splitter-combiner")

    def test_noncanonical_plain_filename_is_reported_without_renaming(self):
        row = record("G:/Park/MSB GIS/Symbols/Plain/msb-splitter-Combiner.svg",
                     b'<svg xmlns="http://www.w3.org/2000/svg"/>', "PLAIN")
        self.assertEqual(row["NoncanonicalFilename"], "YES")
        self.assertEqual(row["Filename"], "msb-splitter-Combiner.svg")

    def test_role_uses_canonical_folder(self):
        park = r"G:\Shared drives\Display Folders\Park Drawings"
        local = r"C:\Users\example\AppData\Local\TopoGrafix\Symbols"
        self.assertEqual(scope_for(park + r"\MSB GIS\Symbols\Masters\lp.svg", park, local), "MASTERS")
        self.assertEqual(scope_for(park + r"\MSB GIS\Symbols\Plain\lp.svg", park, local), "PLAIN")
        self.assertEqual(scope_for(park + r"\MSB GIS\Symbols\png\lp.png", park, local), "CANONICAL_PNG")
        self.assertEqual(scope_for(local + r"\msb\LP.png", park, local), "EXPERTGPS_LOCAL")


if __name__ == "__main__":
    unittest.main()
