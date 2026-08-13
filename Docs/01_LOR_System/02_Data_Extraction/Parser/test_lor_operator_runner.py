"""State and path safety tests for the Windows-side LOR operator runner."""

from __future__ import annotations

import argparse
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import lor_operator_runner as runner_module
from lor_version_checker import build_manifest, write_json


PREVIEW_XML = """<?xml version="1.0"?>
<PreviewClass id="11111111-1111-4111-8111-111111111111" Name="Stage 01">
  <Scene id="22222222-2222-4222-8222-222222222222" Name="01-Main" />
</PreviewClass>
"""


class OperatorRunnerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.previews = self.root / "previews"
        self.current = self.previews / "Database Previews V6.6.4"
        self.candidate = self.previews / "Database Previews V6.6.10"
        for folder in (self.current, self.candidate):
            folder.mkdir(parents=True)
            (folder / "test.lorprev").write_text(PREVIEW_XML, encoding="utf-8")
        self.state_file = self.root / "state" / "lor-runner-state.json"
        runner_module.initialize(argparse.Namespace(
            current_preview_folder=self.current,
            current_lor_version="6.6.4",
            deep_preview="test.lorprev",
            state_file=self.state_file,
        ))
        self.environment = patch.dict(os.environ, {
            "LOR_PREVIEW_PARENT": str(self.previews),
            "LOR_SQLITE_OUTPUT": str(self.root / "lor_output_v7_scene.db"),
            "LOR_RUNNER_REPORTS_ROOT": str(self.root / "reports"),
        })
        self.environment.start()
        self.addCleanup(self.environment.stop)
        self.store = runner_module.StateStore(self.state_file)
        self.runner = runner_module.Runner(self.store)

    def test_candidate_is_resolved_only_from_versioned_preview_root(self) -> None:
        state = self.runner.select_candidate("6.6.10", "operator@example.com")
        self.assertEqual(state["new_lor_version"], "6.6.10")
        self.assertEqual(Path(state["new_preview_folder"]), self.candidate.resolve())
        with self.assertRaisesRegex(ValueError, "numeric and dot-separated"):
            self.runner.select_candidate("..\\outside", "operator@example.com")

    def test_approval_preserves_manifest_and_appends_history(self) -> None:
        self.runner.select_candidate("6.6.10", "operator@example.com")
        candidate_manifest = build_manifest(self.candidate, "6.6.10", "test.lorprev")
        candidate_manifest_path = self.root / "reports" / "candidate-manifest.json"
        write_json(candidate_manifest_path, candidate_manifest)

        def prepare(state):
            state["candidate_check"] = {
                "status": "PASSED",
                "report_json": str(self.root / "reports" / "compatibility.json"),
                "candidate_manifest_path": str(candidate_manifest_path),
            }
            state["candidate_parser_run"] = {
                "status": "COMPLETE",
                "validation_status": "PASSED",
                "parser_version": "V7.0.8",
                "sqlite_sha256": "a" * 64,
            }

        self.store.update(prepare)
        state = self.runner.approve_candidate("6.6.10", "operator@example.com")
        approved_manifest = self.state_file.with_name("current-lor-manifest.json")
        self.assertEqual(state["current_lor_version"], "6.6.10")
        self.assertEqual(state["current_manifest_path"], str(approved_manifest))
        self.assertEqual(
            json.loads(approved_manifest.read_text(encoding="utf-8"))["manifest_sha256"],
            candidate_manifest["manifest_sha256"],
        )
        self.assertEqual(len(state["approval_history"]), 1)
        self.assertEqual(state["last_approval"]["parser_version"], "V7.0.8")


if __name__ == "__main__":
    unittest.main()
