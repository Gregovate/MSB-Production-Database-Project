"""Regression tests for the parser-independent LOR XML compatibility gate."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("lor_version_checker.py")
SPEC = importlib.util.spec_from_file_location("lor_version_checker", MODULE_PATH)
checker = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def write_preview(folder: Path, name: str, body: str) -> None:
    (folder / name).write_text(body, encoding="utf-8")


BASELINE_XML = """<?xml version="1.0"?>
<PreviewClass id="11111111-1111-4111-8111-111111111111" Name="Stage 01" Revision="1">
  <PropClass id="22222222-2222-4222-8222-222222222222" Name="A" Comment="Display A"
    DeviceType="LOR" ChannelGrid="Regular,01,1,16,0,FFFFFF" />
</PreviewClass>
"""


class CompatibilityCheckerTests(unittest.TestCase):
    def manifest(self, xml: str, version: str = "6.6.3"):
        temporary = tempfile.TemporaryDirectory()
        folder = Path(temporary.name)
        write_preview(folder, "test.lorprev", xml)
        manifest = checker.build_manifest(folder, version, "test.lorprev")
        return temporary, manifest

    def test_identical_xml_contract_passes(self) -> None:
        old_temp, baseline = self.manifest(BASELINE_XML)
        new_temp, candidate = self.manifest(BASELINE_XML, "6.6.4")
        self.addCleanup(old_temp.cleanup)
        self.addCleanup(new_temp.cleanup)
        report = checker.report_document(
            baseline, candidate, checker.compare_manifests(baseline, candidate)
        )
        self.assertEqual(report["status"], "PASSED")
        self.assertFalse(report["approval_blocked"])

    def test_new_scene_structure_is_blocking(self) -> None:
        candidate_xml = BASELINE_XML.replace(
            '<PropClass id=',
            '<Scene id="33333333-3333-4333-8333-333333333333" Name="01-Main" />\n  <PropClass id=',
        )
        old_temp, baseline = self.manifest(BASELINE_XML)
        new_temp, candidate = self.manifest(candidate_xml, "6.6.4")
        self.addCleanup(old_temp.cleanup)
        self.addCleanup(new_temp.cleanup)
        findings = checker.compare_manifests(baseline, candidate)
        self.assertTrue(any(item.severity == "BLOCKING" and "Scene" in item.message for item in findings))
        report = checker.report_document(baseline, candidate, findings)
        self.assertEqual(report["status"], "FAILED")
        self.assertTrue(report["parser_modifications_required"])

    def test_new_unused_propclass_attribute_is_blocking(self) -> None:
        candidate_xml = BASELINE_XML.replace(
            'DeviceType="LOR"', 'DeviceType="LOR" FutureField="new-format"'
        )
        old_temp, baseline = self.manifest(BASELINE_XML)
        new_temp, candidate = self.manifest(candidate_xml, "6.6.4")
        self.addCleanup(old_temp.cleanup)
        self.addCleanup(new_temp.cleanup)
        findings = checker.compare_manifests(baseline, candidate)
        self.assertTrue(any(
            item.severity == "BLOCKING" and item.area == "PropClass"
            and "FutureField" in item.message for item in findings
        ))

    def test_same_shape_scene_addition_still_requires_review(self) -> None:
        two_scenes = BASELINE_XML.replace(
            '<PropClass id=',
            '<Scene id="33333333-3333-4333-8333-333333333333" Name="01-First" />\n'
            '  <Scene id="44444444-4444-4444-8444-444444444444" Name="01-Second" />\n'
            '  <PropClass id=',
        )
        three_scenes = two_scenes.replace(
            '  <PropClass id=',
            '<Scene id="55555555-5555-4555-8555-555555555555" Name="01-Third" />\n'
            '  <PropClass id=',
        )
        old_temp, baseline = self.manifest(two_scenes)
        new_temp, candidate = self.manifest(three_scenes, "6.6.4")
        self.addCleanup(old_temp.cleanup)
        self.addCleanup(new_temp.cleanup)
        findings = checker.compare_manifests(baseline, candidate)
        self.assertTrue(any(
            item.severity == "REVIEW" and "Scene count changed" in item.message
            for item in findings
        ))
        report = checker.report_document(baseline, candidate, findings)
        self.assertEqual(report["status"], "REVIEW_REQUIRED")
        self.assertTrue(report["approval_blocked"])

    def test_non_channelgrid_delimited_position_change_is_blocking(self) -> None:
        baseline_xml = BASELINE_XML.replace(
            'DeviceType="LOR"', 'DeviceType="LOR" TraditionalColors="White,Blue"'
        )
        candidate_xml = baseline_xml.replace("White,Blue", "White,Blue,Red")
        old_temp, baseline = self.manifest(baseline_xml)
        new_temp, candidate = self.manifest(candidate_xml, "6.6.4")
        self.addCleanup(old_temp.cleanup)
        self.addCleanup(new_temp.cleanup)
        findings = checker.compare_manifests(baseline, candidate)
        self.assertTrue(any(
            item.severity == "BLOCKING"
            and item.area == "PropClass.TraditionalColors"
            for item in findings
        ))

    def test_channel_grid_position_change_is_blocking(self) -> None:
        candidate_xml = BASELINE_XML.replace(
            "Regular,01,1,16,0,FFFFFF", "Regular,01,1,16,0,FFFFFF,NEW"
        )
        old_temp, baseline = self.manifest(BASELINE_XML)
        new_temp, candidate = self.manifest(candidate_xml, "6.6.4")
        self.addCleanup(old_temp.cleanup)
        self.addCleanup(new_temp.cleanup)
        findings = checker.compare_manifests(baseline, candidate)
        self.assertTrue(any(
            item.severity == "BLOCKING" and item.area == "PropClass.ChannelGrid"
            for item in findings
        ))


if __name__ == "__main__":
    unittest.main()
