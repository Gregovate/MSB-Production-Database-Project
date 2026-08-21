"""Regression tests for normal Motion FX authoring in the LOR XML gate."""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("lor_version_checker.py")
SPEC = importlib.util.spec_from_file_location("lor_version_checker_motion_fx", MODULE_PATH)
checker = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
sys.modules[SPEC.name] = checker
SPEC.loader.exec_module(checker)


def motion_preview(record_count: int) -> str:
    subc = ";".join(f"{index},0,1,2" for index in range(record_count))
    return f'''<?xml version="1.0"?>
<PreviewClass id="11111111-1111-4111-8111-111111111111" Name="2026 Master Musical Preview" Revision="1">
  <PropClass id="22222222-2222-4222-8222-222222222222" Name="Mt Crumpit" Comment="Mt Crumpit"
    DeviceType="None">
    <MotionRowDefaults>
      <MotionRowDefault Name="Motion FX" subc="{subc}" />
    </MotionRowDefaults>
  </PropClass>
</PreviewClass>
'''


class MotionFxCompatibilityTests(unittest.TestCase):
    def manifest(self, xml: str, version: str):
        temporary = tempfile.TemporaryDirectory()
        folder = Path(temporary.name)
        filename = "2026 Master Musical Preview.lorprev"
        (folder / filename).write_text(xml, encoding="utf-8")
        manifest = checker.build_manifest(folder, version, filename)
        return temporary, manifest

    def test_same_version_motion_row_subc_growth_is_informational(self) -> None:
        baseline_temp, baseline = self.manifest(motion_preview(2), "6.6.10")
        current_temp, current = self.manifest(motion_preview(275), "6.6.10")
        self.addCleanup(baseline_temp.cleanup)
        self.addCleanup(current_temp.cleanup)

        findings = checker.compare_manifests(baseline, current)
        motion_findings = [
            finding
            for finding in findings
            if "MotionRowDefault" in f"{finding.area} {finding.message}"
        ]

        self.assertTrue(motion_findings)
        self.assertTrue(all(finding.severity == "INFO" for finding in motion_findings))
        self.assertFalse(any(finding.severity == "BLOCKING" for finding in findings))
        report = checker.report_document(baseline, current, findings)
        self.assertEqual(report["status"], "PASSED")
        self.assertFalse(report["approval_blocked"])

    def test_new_lor_version_motion_row_change_remains_strict(self) -> None:
        baseline_temp, baseline = self.manifest(motion_preview(2), "6.6.10")
        candidate_temp, candidate = self.manifest(motion_preview(275), "6.6.11")
        self.addCleanup(baseline_temp.cleanup)
        self.addCleanup(candidate_temp.cleanup)

        findings = checker.compare_manifests(baseline, candidate)
        self.assertTrue(any(
            finding.severity == "BLOCKING"
            and "MotionRowDefault" in f"{finding.area} {finding.message}"
            for finding in findings
        ))
        report = checker.report_document(baseline, candidate, findings)
        self.assertEqual(report["status"], "FAILED")
        self.assertTrue(report["approval_blocked"])


if __name__ == "__main__":
    unittest.main()
