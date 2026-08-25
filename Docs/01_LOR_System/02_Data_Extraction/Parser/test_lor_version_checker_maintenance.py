"""Regression tests for approved-version preview maintenance."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("lor_version_checker.py")
SPEC = importlib.util.spec_from_file_location(
    "lor_version_checker_maintenance", MODULE_PATH
)
checker = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


BLANK_DISPLAY = '''
  <PropClass id="22222222-2222-4222-8222-222222222222" Name="A"
    Comment="Display A" DeviceType="LOR"
    ChannelGrid="Regular,01,1,16,0," Tag="" TraditionalColors="">
    <shape BackgroundImage="" CustomGrid="" OffsetX="0" OffsetY="0"
      ScaleX="1" ScaleY="1" />
  </PropClass>
'''

AUTHORED_DISPLAY = '''
  <PropClass id="33333333-3333-4333-8333-333333333333" Name="B"
    Comment="Display B" DeviceType="LOR"
    ChannelGrid="Regular,02,17,32,0,FFFFFF" Tag="station"
    TraditionalColors="Red,Green,White">
    <shape BackgroundImage="G:\\Displays\\station.png"
      CustomGrid="0,0;1,1;2,2" OffsetX="0.5" OffsetY="1.5"
      ScaleX="1.25" ScaleY="0.75" />
  </PropClass>
'''


def preview(*displays: str, extra: str = "") -> str:
    return (
        '<?xml version="1.0"?>\n'
        '<PreviewClass id="11111111-1111-4111-8111-111111111111" '
        'Name="Stage 30" Revision="1">\n'
        + "".join(displays)
        + extra
        + "</PreviewClass>\n"
    )


class ApprovedVersionMaintenanceTests(unittest.TestCase):
    def manifest(self, xml: str, version: str = "6.6.10"):
        temporary = tempfile.TemporaryDirectory()
        folder = Path(temporary.name)
        filename = "Show Background Stage 30-Santa's Station-QV.lorprev"
        (folder / filename).write_text(xml, encoding="utf-8")
        manifest = checker.build_manifest(folder, version, filename)
        return temporary, manifest

    def compare(self, old_xml: str, new_xml: str, new_version: str = "6.6.10"):
        old_temp, baseline = self.manifest(old_xml)
        new_temp, candidate = self.manifest(new_xml, new_version)
        self.addCleanup(old_temp.cleanup)
        self.addCleanup(new_temp.cleanup)
        findings = checker.compare_manifests(baseline, candidate)
        return findings, checker.report_document(baseline, candidate, findings)

    def test_same_version_display_addition_and_authored_values_are_informational(self) -> None:
        findings, report = self.compare(
            preview(BLANK_DISPLAY),
            preview(BLANK_DISPLAY, AUTHORED_DISPLAY),
        )

        evidence = "\n".join(
            f"{finding.area}: {finding.message}" for finding in findings
        )
        for expected in (
            "PropClass.Tag",
            "PropClass.TraditionalColors",
            "shape.BackgroundImage",
            "shape.CustomGrid",
            "shape.OffsetX",
            "shape.OffsetY",
            "shape.ScaleX",
            "shape.ScaleY",
            "PropClass.ChannelGrid.6",
            "New delimiter-encoded field layout: shape.CustomGrid",
        ):
            self.assertIn(expected, evidence)
        self.assertTrue(findings)
        self.assertTrue(all(finding.severity == "INFO" for finding in findings))
        self.assertEqual(report["status"], "PASSED")
        self.assertFalse(report["approval_blocked"])

    def test_same_version_custom_grid_record_and_token_counts_are_informational(self) -> None:
        old_display = BLANK_DISPLAY.replace('CustomGrid=""', 'CustomGrid="0;1"')
        new_display = BLANK_DISPLAY.replace(
            'CustomGrid=""', 'CustomGrid="0,0;1,1;2,2"'
        )
        findings, report = self.compare(
            preview(old_display),
            preview(new_display),
        )

        evidence = "\n".join(finding.message for finding in findings)
        self.assertIn("semicolon record count", evidence)
        self.assertIn("comma token count", evidence)
        self.assertTrue(all(finding.severity == "INFO" for finding in findings))
        self.assertEqual(report["status"], "PASSED")
        self.assertFalse(report["approval_blocked"])

    def test_same_version_display_removal_is_informational(self) -> None:
        findings, report = self.compare(
            preview(BLANK_DISPLAY, AUTHORED_DISPLAY),
            preview(BLANK_DISPLAY),
        )

        self.assertTrue(findings)
        self.assertTrue(all(finding.severity == "INFO" for finding in findings))
        self.assertEqual(report["status"], "PASSED")
        self.assertFalse(report["approval_blocked"])

    def test_different_version_keeps_the_same_content_differences_strict(self) -> None:
        findings, report = self.compare(
            preview(BLANK_DISPLAY),
            preview(BLANK_DISPLAY, AUTHORED_DISPLAY),
            new_version="6.6.11",
        )

        self.assertTrue(any(finding.severity == "BLOCKING" for finding in findings))
        self.assertEqual(report["status"], "FAILED")
        self.assertTrue(report["approval_blocked"])

    def test_same_version_new_xml_vocabulary_remains_blocking(self) -> None:
        findings, report = self.compare(
            preview(BLANK_DISPLAY),
            preview(BLANK_DISPLAY, extra='  <UnknownField value="1" />\n'),
        )

        self.assertTrue(any(
            finding.severity == "BLOCKING"
            and "UnknownField" in f"{finding.area} {finding.message}"
            for finding in findings
        ))
        self.assertEqual(report["status"], "FAILED")
        self.assertTrue(report["approval_blocked"])


if __name__ == "__main__":
    unittest.main()
