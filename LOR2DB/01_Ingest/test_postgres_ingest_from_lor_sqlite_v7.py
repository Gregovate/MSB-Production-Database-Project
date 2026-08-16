"""Safety tests for the reviewed-SQLite ingest authority gate."""

from __future__ import annotations

import hashlib
import importlib.util
import os
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("postgres_ingest_from_lor_sqlite_v7.py")
SPEC = importlib.util.spec_from_file_location("lor_ingest", MODULE_PATH)
ingest = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
sys.modules[SPEC.name] = ingest
SPEC.loader.exec_module(ingest)


class IngestAuthorityTests(unittest.TestCase):
    def test_ascii_redirect_cannot_abort_unicode_diagnostic(self) -> None:
        script = (
            "import runpy, sys, types; "
            "pg=types.ModuleType('psycopg2'); "
            "extras=types.ModuleType('psycopg2.extras'); "
            "pg.extras=extras; "
            "sys.modules['psycopg2']=pg; "
            "sys.modules['psycopg2.extras']=extras; "
            f"runpy.run_path({str(MODULE_PATH)!r}, run_name='ingest_encoding_test'); "
            "print('ingest output \\u2192 browser log')"
        )
        environment = os.environ.copy()
        environment["PYTHONIOENCODING"] = "ascii:strict"
        completed = subprocess.run(
            [sys.executable, "-c", script],
            env=environment,
            capture_output=True,
            check=False,
        )
        self.assertEqual(
            completed.returncode,
            0,
            completed.stderr.decode(errors="replace"),
        )
        self.assertIn(b"ingest output \\u2192 browser log", completed.stdout)

    def test_reviewed_sqlite_hash_accepts_exact_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "lor_output_v7_scene.db"
            path.write_bytes(b"reviewed-sqlite")
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            self.assertEqual(ingest.verify_reviewed_sqlite(str(path), digest), digest)

    def test_reviewed_sqlite_hash_rejects_changed_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "lor_output_v7_scene.db"
            path.write_bytes(b"changed-sqlite")
            with self.assertRaisesRegex(RuntimeError, "not the exact operator-reviewed artifact"):
                ingest.verify_reviewed_sqlite(str(path), "0" * 64)

    def parser_connection(self, run_mode: str, validation: str) -> sqlite3.Connection:
        connection = sqlite3.connect(":memory:")
        connection.execute("""
            CREATE TABLE parser_run (
                ParserVersion, StartedAt, CompletedAt, Actor, HostName,
                SourcePreviewFolder, SQLiteDatabasePath, Status, RunMode,
                SourceLORVersion, ParserSHA256, SourceManifestSHA256,
                CompatibilityManifestSHA256, ValidationStatus, ValidationDetail
            )
        """)
        connection.execute("""
            INSERT INTO parser_run VALUES (
                'V7.0.8', 'start', 'complete', 'actor', 'host', 'folder', 'db',
                'COMPLETE', ?, '6.6.4', ?, ?, ?, ?, '{}'
            )
        """, (run_mode, "a" * 64, "b" * 64, "c" * 64, validation))
        return connection

    def test_ingest_requires_production_parser_run(self) -> None:
        connection = self.parser_connection("VERSION_CHECK", "PASSED")
        self.addCleanup(connection.close)
        with self.assertRaisesRegex(RuntimeError, "parser_run_mode must be PRODUCTION"):
            ingest.read_parser_run(connection)

    def test_ingest_requires_passed_parser_validation(self) -> None:
        connection = self.parser_connection("PRODUCTION", "FAILED")
        self.addCleanup(connection.close)
        with self.assertRaisesRegex(RuntimeError, "parser_validation_status must be PASSED"):
            ingest.read_parser_run(connection)

    def test_import_run_authority_chain_matches_sql_parameters(self) -> None:
        class Cursor:
            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

            def execute(self, statement, parameters):
                self.parameter_count = len(parameters)
                self.placeholder_count = statement.count("%s")
                if self.parameter_count != self.placeholder_count:
                    raise AssertionError(
                        f"{self.placeholder_count} placeholders for "
                        f"{self.parameter_count} parameters"
                    )

            def fetchone(self):
                return (41,)

        class Connection:
            def cursor(self):
                return Cursor()

        parser_run = {
            "parser_version": "V7.0.8",
            "parser_started_at": "start",
            "parser_completed_at": "complete",
            "parser_actor": "operator",
            "parser_host": "lor-workstation",
            "source_preview_folder": r"G:\\Shared drives\\MSB Database Previews V6.6.4",
            "source_sqlite_path": r"G:\\Shared drives\\lor_output_v7_scene.db",
            "parser_run_mode": "PRODUCTION",
            "source_lor_version": "6.6.4",
            "parser_sha256": "a" * 64,
            "source_manifest_sha256": "b" * 64,
            "compatibility_manifest_sha256": "c" * 64,
            "parser_validation_status": "PASSED",
            "parser_validation_detail": "{}",
        }
        counts = {
            "preview_count": 33,
            "scene_count": 92,
            "prop_count": 1157,
            "sub_prop_count": 1312,
            "dmx_channel_count": 508,
            "scene_lor_prop_count": 2260,
        }
        import_run_id = ingest.insert_import_run(
            Connection(),
            "reviewed",
            parser_run,
            counts,
            "operator",
            "database-host",
            datetime.now(timezone.utc),
            "d" * 64,
        )
        self.assertEqual(import_run_id, 41)

    def test_completed_exact_digest_is_reused(self) -> None:
        class Cursor:
            def __enter__(self):
                return self

            def __exit__(self, *args):
                return False

            def execute(self, statement, parameters):
                self.statement = statement
                self.parameters = parameters

            def fetchone(self):
                return (48,)

        class Connection:
            def cursor(self):
                return Cursor()

        digest = "d" * 64
        self.assertEqual(
            ingest.find_completed_import_run(Connection(), digest),
            48,
        )


if __name__ == "__main__":
    unittest.main()
