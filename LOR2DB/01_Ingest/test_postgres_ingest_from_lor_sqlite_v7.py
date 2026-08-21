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


class ColumnsCursor:
    def __init__(self, columns: list[str]):
        self.columns = columns

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def execute(self, statement, parameters):
        self.statement = statement
        self.parameters = parameters

    def fetchall(self):
        return [(column,) for column in self.columns]


class ColumnsConnection:
    def __init__(self, columns: list[str]):
        self.columns = columns

    def cursor(self):
        return ColumnsCursor(self.columns)


class TargetCursor:
    def __init__(self, counts: list[int]):
        self.counts = counts

    def __enter__(self):
        return self

    def __exit__(self, *args):
        return False

    def execute(self, statement, parameters):
        self.statement = statement
        self.parameters = parameters

    def fetchone(self):
        return (self.counts.pop(0),)


class TargetConnection:
    def __init__(self, counts: list[int]):
        self.counts = counts

    def cursor(self):
        return TargetCursor(self.counts)


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

    def dmx_connection(self, *, with_columns: bool = True) -> sqlite3.Connection:
        connection = sqlite3.connect(":memory:")
        if with_columns:
            connection.execute("""
                CREATE TABLE dmxChannels (
                    RawPropID TEXT,
                    ChannelName TEXT,
                    ChannelGridRowNumber INTEGER
                )
            """)
        else:
            connection.execute("CREATE TABLE dmxChannels (PropId TEXT)")
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

    def test_dmx_source_detail_gate_starts_at_v7011(self) -> None:
        self.assertFalse(ingest.parser_requires_dmx_source_detail("V7.0.10"))
        self.assertTrue(ingest.parser_requires_dmx_source_detail("V7.0.11"))
        self.assertTrue(ingest.parser_requires_dmx_source_detail("V7.1.0"))

    def test_dmx_source_detail_names_map_without_transform(self) -> None:
        mapping = ingest.build_column_map(
            ["RawPropID", "ChannelName", "ChannelGridRowNumber"],
            ["raw_prop_id", "channel_name", "channel_grid_row_number"],
        )
        self.assertEqual(
            mapping,
            {
                "raw_prop_id": "RawPropID",
                "channel_name": "ChannelName",
                "channel_grid_row_number": "ChannelGridRowNumber",
            },
        )

    def test_v7010_does_not_require_new_dmx_columns(self) -> None:
        connection = sqlite3.connect(":memory:")
        self.addCleanup(connection.close)
        ingest.validate_dmx_source_detail_schema_contract(
            connection,
            object(),
            "V7.0.10",
        )
        ingest.validate_dmx_source_detail_source_values(connection, "V7.0.10")

    def test_v7011_rejects_missing_sqlite_dmx_source_columns(self) -> None:
        connection = self.dmx_connection(with_columns=False)
        self.addCleanup(connection.close)
        pg_columns = [
            "import_run_id",
            "int_dmx_channel_id",
            "prop_id",
            "network",
            "start_universe",
            "start_channel",
            "end_channel",
            "unknown",
            "preview_id",
            "raw_prop_id",
            "channel_name",
            "channel_grid_row_number",
        ]
        with self.assertRaisesRegex(RuntimeError, "RawPropID"):
            ingest.validate_dmx_source_detail_schema_contract(
                connection,
                ColumnsConnection(pg_columns),
                "V7.0.11",
            )

    def test_v7011_rejects_missing_postgres_dmx_source_columns(self) -> None:
        connection = self.dmx_connection()
        self.addCleanup(connection.close)
        pg_columns = [
            "import_run_id",
            "int_dmx_channel_id",
            "prop_id",
            "network",
            "start_universe",
            "start_channel",
            "end_channel",
            "unknown",
            "preview_id",
            "raw_prop_id",
            "channel_grid_row_number",
        ]
        with self.assertRaisesRegex(RuntimeError, "channel_name"):
            ingest.validate_dmx_source_detail_schema_contract(
                connection,
                ColumnsConnection(pg_columns),
                "V7.0.11",
            )

    def test_v7011_rejects_blank_or_invalid_dmx_source_values(self) -> None:
        connection = self.dmx_connection()
        self.addCleanup(connection.close)
        connection.execute(
            "INSERT INTO dmxChannels VALUES ('', 'Channel A', 0)"
        )
        with self.assertRaisesRegex(RuntimeError, "source-value validation failed"):
            ingest.validate_dmx_source_detail_source_values(connection, "V7.0.11")

    def test_v7011_allows_noncontiguous_positive_grid_row_numbers(self) -> None:
        connection = self.dmx_connection()
        self.addCleanup(connection.close)
        connection.executemany(
            "INSERT INTO dmxChannels VALUES (?, ?, ?)",
            [
                ("raw-a", "Channel A", 1),
                ("raw-a", "Channel A", 3),
                ("raw-b", "Channel B", 1),
            ],
        )
        ingest.validate_dmx_source_detail_source_values(connection, "V7.0.11")

    def test_v7011_target_validation_rejects_missing_values(self) -> None:
        connection = TargetConnection([1, 0, 0])
        with self.assertRaisesRegex(RuntimeError, "target-value validation failed"):
            ingest.validate_dmx_source_detail_target_values(
                connection,
                51,
                "V7.0.11",
            )

    def test_v7011_target_validation_accepts_complete_values(self) -> None:
        connection = TargetConnection([0, 0, 0])
        ingest.validate_dmx_source_detail_target_values(
            connection,
            51,
            "V7.0.11",
        )

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
