"""State and path safety tests for the Windows-side LOR operator runner."""

from __future__ import annotations

import argparse
from contextlib import closing, redirect_stderr, redirect_stdout
import io
import json
import os
import sqlite3
import tempfile
import unittest
from http import HTTPStatus
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

    def test_credential_fingerprint_is_stable_and_does_not_reveal_token(self) -> None:
        token = "a" * 64
        first = runner_module.credential_fingerprint(f"Bearer {token}")
        second = runner_module.credential_fingerprint(f"Bearer {token}")
        self.assertEqual(first, second)
        self.assertEqual(len(first), 16)
        self.assertNotIn(token, first)
        self.assertEqual(runner_module.credential_fingerprint(""), "missing")

    def test_windows_launcher_is_ascii_for_powershell_51(self) -> None:
        """Windows PowerShell 5.1 misreads BOM-less UTF-8 punctuation."""
        launcher = Path(__file__).resolve().parents[4] / "run_lor_runner.ps1"
        source = launcher.read_bytes().decode("ascii")
        self.assertIn("PYTHONUNBUFFERED", source)
        self.assertIn("START FAILED", source)
        self.assertIn("AllowStartIfOnBatteries", source)
        self.assertIn("DontStopIfGoingOnBatteries", source)
        self.assertIn("savedErrorActionPreference", source)
        self.assertIn("native process exit code remains authoritative", source)
        self.assertIn("WindowStyle Hidden", source)
        self.assertIn("function Stop-InstalledRunner", source)
        self.assertIn("not the managed LOR runner", source)
        self.assertIn("parser_activity.status -eq 'RUNNING'", source)

    def test_http_access_log_uses_stdout_not_stderr(self) -> None:
        """A successful request must not become a PowerShell native error."""
        handler = object.__new__(runner_module.RequestHandler)
        handler.address_string = lambda: "192.168.5.9"
        handler.log_date_time_string = lambda: "15/Aug/2026 09:08:51"
        stdout = io.StringIO()
        stderr = io.StringIO()

        with redirect_stdout(stdout), redirect_stderr(stderr):
            handler.log_message('"GET /health HTTP/1.1" %d -', 200)

        self.assertIn('"GET /health HTTP/1.1" 200 -', stdout.getvalue())
        self.assertEqual(stderr.getvalue(), "")

    def test_second_runner_operation_is_rejected_instead_of_queued(self) -> None:
        """Two browser tabs cannot schedule sequential parser executions."""
        handler = object.__new__(runner_module.RequestHandler)
        handler.command = "POST"
        handler.path = "/parser/run"
        handler.headers = {
            "Authorization": "Bearer " + ("a" * 64),
            "Content-Length": "0",
        }
        handler.rfile = io.BytesIO()
        handler.server = argparse.Namespace(runner=self.runner)

        with patch.dict(os.environ, {"LOR_RUNNER_TOKEN": "a" * 64}):
            self.runner.operation_lock.acquire()
            try:
                status, payload = handler.dispatch()
            finally:
                self.runner.operation_lock.release()

        self.assertEqual(status, HTTPStatus.CONFLICT)
        self.assertIn("already running", payload["error"])

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
                "parser_version": "V7.0.10",
                "source_lor_version": "6.6.10",
                "sqlite_sha256": "a" * 64,
            }
            state["baseline_parser_run"] = {
                "status": "COMPLETE",
                "validation_status": "PASSED",
                "source_lor_version": "6.6.4",
                "sqlite_sha256": "b" * 64,
            }
            state["candidate_output_comparison"] = {
                "status": "PASSED",
                "report_json": str(self.root / "reports" / "output-comparison.json"),
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
        self.assertEqual(state["last_approval"]["parser_version"], "V7.0.10")
        self.assertEqual(state["last_approval"]["baseline_sqlite_sha256"], "b" * 64)
        self.assertEqual(state["baseline_parser_run"]["source_lor_version"], "6.6.10")

    def test_approval_requires_output_comparison(self) -> None:
        self.runner.select_candidate("6.6.10", "operator@example.com")

        def prepare(state):
            state["candidate_check"] = {"status": "PASSED"}
            state["baseline_parser_run"] = {
                "status": "COMPLETE",
                "validation_status": "PASSED",
            }
            state["candidate_parser_run"] = {
                "status": "COMPLETE",
                "validation_status": "PASSED",
            }

        self.store.update(prepare)
        with self.assertRaisesRegex(ValueError, "output differences"):
            self.runner.approve_candidate("6.6.10", "operator@example.com")

    def test_changed_candidate_folder_invalidates_checked_manifest(self) -> None:
        self.runner.select_candidate("6.6.10", "operator@example.com")
        manifest = build_manifest(self.candidate, "6.6.10", "test.lorprev")
        manifest_path = self.root / "reports" / "candidate-manifest.json"
        write_json(manifest_path, manifest)

        def prepare(state):
            state["candidate_check"] = {
                "status": "PASSED",
                "candidate_manifest_path": str(manifest_path),
            }

        self.store.update(prepare)
        (self.candidate / "test.lorprev").write_text(
            PREVIEW_XML.replace('Name="Stage 01"', 'Name="Stage 01 changed"'),
            encoding="utf-8",
        )
        with self.assertRaisesRegex(ValueError, "changed after its XML check"):
            self.runner.run_parser("candidate", "operator@example.com")

    @patch("lor_operator_runner.subprocess.run")
    def test_current_parser_allows_compatible_preview_edits(self, run) -> None:
        """Approved-version authoring changes must not make Run Parser stale."""
        (self.current / "test.lorprev").write_text(
            PREVIEW_XML.replace('Name="Stage 01"', 'Name="Stage 01 revised"'),
            encoding="utf-8",
        )

        def complete(command, **_kwargs):
            result_path = Path(command[command.index("--result-json") + 1])
            result_path.parent.mkdir(parents=True, exist_ok=True)
            result_path.write_text(json.dumps({
                "status": "COMPLETE",
                "validation_status": "PASSED",
                "source_lor_version": "6.6.4",
                "sqlite_sha256": "a" * 64,
            }), encoding="utf-8")
            return argparse.Namespace(
                returncode=0,
                stdout="[OK] parser complete\n",
                stderr="",
            )

        run.side_effect = complete
        result = self.runner.run_parser("current", "operator@example.com")
        self.assertEqual(result["status"], "COMPLETE")
        activity = self.runner.public_parser_activity()
        self.assertEqual(activity["status"], "PASSED")
        self.assertEqual(activity["target"], "current")
        self.assertIn("[OK] parser complete", activity["console_output"])
        self.assertNotIn("console_log_path", self.runner.public_state()["parser_activity"])

    @patch("lor_operator_runner.subprocess.run")
    def test_failed_parser_records_console_and_preserves_terminal_status(self, run) -> None:
        """Browser diagnostics must survive a failed parser request."""
        run.return_value = argparse.Namespace(
            returncode=2,
            stdout="[INFO] parser started\n",
            stderr="[FATAL] invalid preview\n",
        )

        with self.assertRaisesRegex(RuntimeError, "invalid preview"):
            self.runner.run_parser("current", "operator@example.com")

        activity = self.runner.public_parser_activity()
        self.assertEqual(activity["status"], "FAILED")
        self.assertIn("[INFO] parser started", activity["console_output"])
        self.assertIn("[FATAL] invalid preview", activity["console_output"])
        self.assertIn("invalid preview", activity["error"])

    def test_runner_restart_marks_incomplete_parser_activity_interrupted(self) -> None:
        """A process restart cannot leave the browser claiming RUNNING forever."""
        def prepare(state):
            state["parser_activity"] = {
                "activity_id": "current-stale",
                "status": "RUNNING",
                "console_log_path": str(self.root / "missing.log"),
            }

        self.store.update(prepare)
        runner_module.Runner(self.store)
        activity = self.runner.public_parser_activity()
        self.assertEqual(activity["status"], "INTERRUPTED")
        self.assertIn("restarted", activity["error"])

    def test_current_parser_blocks_new_xml_contract(self) -> None:
        (self.current / "test.lorprev").write_text(
            PREVIEW_XML.replace("</PreviewClass>", '<UnknownField value="1" /></PreviewClass>'),
            encoding="utf-8",
        )
        with self.assertRaisesRegex(ValueError, "parser-breaking XML changes"):
            self.runner.run_parser("current", "operator@example.com")


class ParserOutputComparisonTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.baseline = self.root / "baseline.db"
        self.candidate = self.root / "candidate.db"
        self._create_database(self.baseline, revision="1", name="Master 6.6.4", source="old.lorprev")
        self._create_database(self.candidate, revision="2", name="Master 6.6.10", source="new.lorprev")

    def _create_database(self, path: Path, revision: str, name: str, source: str) -> None:
        # sqlite3.Connection.__exit__ commits/rolls back but does not close.
        # Explicit closure is required before TemporaryDirectory cleanup on Windows.
        with closing(sqlite3.connect(path)) as connection:
            connection.execute(
                "CREATE TABLE previews (IntPreviewID INTEGER PRIMARY KEY, id TEXT UNIQUE, "
                "StageID TEXT, Name TEXT, Revision TEXT, Brightness REAL, "
                "BackgroundFile TEXT, SourceFilename TEXT)"
            )
            connection.execute(
                "INSERT INTO previews VALUES (1, 'preview-id', '01', ?, ?, 100.0, 'background.jpg', ?)",
                (name, revision, source),
            )
            connection.execute(
                "CREATE TABLE parser_run (ParserVersion TEXT, RunMode TEXT, ValidationStatus TEXT)"
            )
            connection.execute(
                "INSERT INTO parser_run VALUES ('V7.0.10', 'VERSION_CHECK', 'PASSED')"
            )
            for table in runner_module.AUTHORITATIVE_OUTPUT_TABLES:
                if table == "props":
                    connection.execute(
                        'CREATE TABLE props (IntPropID INTEGER PRIMARY KEY, '
                        'Value TEXT, IndividualChannels TEXT)'
                    )
                    connection.execute('INSERT INTO props VALUES (1, "same", "True")')
                else:
                    connection.execute(
                        f'CREATE TABLE "{table}" (IntRowID INTEGER PRIMARY KEY, Value TEXT)'
                    )
                    connection.execute(f'INSERT INTO "{table}" VALUES (1, "same")')
            connection.execute("CREATE VIEW props_review_vw AS SELECT Value FROM props")
            connection.commit()

    def compare(self) -> dict:
        return runner_module.compare_parser_outputs(
            self.baseline,
            self.candidate,
            "6.6.4",
            "6.6.10",
            self.root / "comparison.json",
            self.root / "comparison.md",
        )

    def test_revision_is_informational_and_name_file_changes_require_review(self) -> None:
        report = self.compare()
        self.assertEqual(report["status"], "REVIEW_REQUIRED")
        self.assertEqual(report["blocking_count"], 0)
        self.assertEqual(report["review_count"], 2)
        self.assertEqual(report["information_count"], 1)
        self.assertEqual(report["preview_metadata_change_counts"]["Revision"], 1)
        for table in runner_module.AUTHORITATIVE_OUTPUT_TABLES:
            self.assertEqual(report["tables"][table]["baseline_only"], 0)
            self.assertEqual(report["tables"][table]["candidate_only"], 0)

    def test_authoritative_content_difference_is_blocking(self) -> None:
        with closing(sqlite3.connect(self.candidate)) as connection:
            connection.execute('UPDATE props SET Value = "changed"')
            connection.commit()
        report = self.compare()
        self.assertEqual(report["status"], "BLOCKED")
        self.assertEqual(report["blocking_count"], 1)
        self.assertEqual(report["tables"]["props"]["baseline_only"], 1)
        self.assertEqual(report["tables"]["props"]["candidate_only"], 1)

    def test_individual_channels_is_not_mistaken_for_surrogate_integer_key(self) -> None:
        with closing(sqlite3.connect(self.candidate)) as connection:
            connection.execute('UPDATE props SET IndividualChannels = "False"')
            connection.commit()
        report = self.compare()
        self.assertEqual(report["status"], "BLOCKED")
        self.assertEqual(report["tables"]["props"]["baseline_only"], 1)
        self.assertEqual(report["tables"]["props"]["candidate_only"], 1)


if __name__ == "__main__":
    unittest.main()
