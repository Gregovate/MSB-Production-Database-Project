"""#171 disposable checks for exact laptop-vs-Office calibration repair guard.

No actual Windows registry, shared drive, GPX, or map files are changed.
"""
import unittest
from gis_workstation_map_repair import MAP, RASTER, TARGET, EXPECTED_OLD, _check_baseline
from gis_workstation_profile import ProfileError


class OfficeMapRepairTests(unittest.TestCase):
    def sample(self):
        header = {"Projection": {"kind": 1, "value": "Mercator"},
                  "Datum": {"kind": 1, "value": "North American 1983 (United States)"}}
        points = {"Point01": {"Latitude": {"kind": 1, "value": "1.69910207"},
                              "Longitude": {"kind": 1, "value": "1.87947681"}},
                  "Point02": {"Latitude": {"kind": 1, "value": "1.67765309"},
                              "Longitude": {"kind": 1, "value": "1.92052983"}}}
        return {MAP: {"image_sha256": RASTER,
                      "source": {"native_header": header,
                                 "native_control_points": points}}}

    def test_known_negative_office_calibration_is_guarded(self):
        _check_baseline(self.sample())
        self.assertEqual(TARGET["Projection\\EPSG"], "103458")
        self.assertEqual(TARGET["Point01.Latitude"], "43.78198693")
        self.assertEqual(TARGET["Point02.Longitude"], "-87.73252256")

    def test_wrong_raster_refused(self):
        item = self.sample()
        item[MAP]["image_sha256"] = "0" * 64
        with self.assertRaises(ProfileError):
            _check_baseline(item)

    def test_changed_latitude_refused(self):
        item = self.sample()
        item[MAP]["source"]["native_control_points"]["Point01"]["Latitude"]["value"] = "43"
        with self.assertRaises(ProfileError):
            _check_baseline(item)

    def test_preexisting_projection_epsg_refused(self):
        item = self.sample()
        item[MAP]["source"]["native_header"]["Projection\\EPSG"] = {"kind": 1, "value": "103458"}
        with self.assertRaises(ProfileError):
            _check_baseline(item)


if __name__ == "__main__":
    unittest.main()
