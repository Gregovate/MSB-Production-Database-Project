# MSB Database — Postgres Snapshot Ingest (from LOR SQLite)
# postgres_ingest_from_lor_sqlite_v7.py
# Initial Release : 2026-02-21  V0.1.0
# Version         : 2026-02-21  V0.1.0
# Current Version : 2026-08-21  V0.4.2
#
# Changes:
# - Initial append-only ingestion layer (SQLite → Postgres)
# - Creates new lor_snap.import_run row per execution
# - Loads previews, scenes, props, sub_props, dmx_channels, scene_lor_props
# - All-or-nothing transaction (rollback on failure)
# - Removed unassigned display count from summary (no longer relevant)
# - Added scene_lor_props ingestion for LOR 6.6.4 Software Update (2026-07-31)
# - V0.2.0 requires props.RawPropID and subProps.RawPropID in SQLite and
#   lor_snap.props.raw_prop_id and lor_snap.sub_props.raw_prop_id in Postgres.
# - V0.2.0 fails before creating an import_run when the raw UUID schema contract
#   is missing, rather than silently inserting NULL into an unmapped column.
# - V0.3.0 reads the disposable SQLite parser_run row and writes parser provenance,
#   source paths, ingest provenance, and source row counts to lor_snap.import_run.
# - V0.3.1 preserves the exact source .lorprev filename in
#   lor_snap.previews.source_filename.
# - V0.3.2 refuses to ingest unless parser_run.Status is COMPLETE.
# - V0.4.0 requires the exact operator-reviewed SQLite SHA-256 and a current V7
#   production/validation provenance before any PostgreSQL write.
# - V0.4.1 makes console diagnostics safe on legacy Windows code pages, reports
#   post-commit failures truthfully, and treats an already-completed matching
#   SQLite digest as a successful idempotent recovery instead of duplicating it.
# - V0.4.2 requires V7.0.11+ DMX source-detail schema/value preservation on both
#   SQLite and PostgreSQL sides before a new import run can commit.
# (GAL)
#
# Author          : Greg Liebig, Engineering Innovations, LLC.
#
# Purpose
# -------
# Promote the rebuilt SQLite snapshot (lor_output_v7_scene.db), produced by
# parse_props_v7_scene_parser.py, into the production Postgres database (msb-prod-db).
#
# This script:
#   • Creates a new import_run record in lor_snap.import_run
#   • Inserts all snapshot tables with import_run_id
#   • Does NOT modify historical runs (append-only model)
#   • Does NOT transform or reinterpret wiring data
#
# Architectural Rules
# --------------------
# • LOR is the authoritative source of wiring.
# • Postgres never accepts manually entered wiring.
# • SQLite is rebuilt each run and serves as the validation gate.
# • Current Postgres state = latest import_run_id (Option A).
#
# Safety Model
# ------------
# • Single transaction.
# • On any failure, Postgres is rolled back.
# • No partial snapshots are committed.
#
# Dependencies
# ------------
# pip install psycopg2-binary
#
# Environment
# -----------
# • Postgres host : msb-prod-db (db.sheboyganlights.org)
# • Database      : msb
# • Schema        : lor_snap
#
# Execution
# ---------
# Intended to be launched via PowerShell wrapper (no password stored in script).
#
# Source of Truth
#   - Wiring/channel data is authoritative in LOR and is imported only.
#   - No manual wiring entry in Postgres.
#   - SQLite is a disposable build artifact and is rebuilt every run by design.
#
# Safety / Guarantees
#   - All-or-nothing transaction:
#       If anything fails, the Postgres transaction is rolled back and NO
#       partial snapshot is committed.
#   - No deletes of historical runs (append-only).
#   - No transformations beyond column-name matching:
#       Postgres tables mirror SQLite tables + import_run_id.
#
# Inputs
#   - SQLite file: G:\Shared drives\MSB Database\database\lor_output_v7_scene.db
#   - Postgres host: db.sheboyganlights.org (msb-prod-db)
#   - Database: msb
#   - Schema: lor_snap
#
# How to Run (PowerShell)
#   $env:PGPASSWORD="your_password"
#   python postgres_ingest_from_lor_sqlite_v7.py `
#     --sqlite "G:\Shared drives\MSB Database\database\lor_output_v7_scene.db" `
#     --pg-host "db.sheboyganlights.org" `
#     --pg-db "msb" `
#     --pg-user "msbadmin" `
#     --notes "LOR snapshot ingest"
#
# Verification (pgAdmin)
#   SELECT * FROM lor_snap.v_current_run;
#   SELECT COUNT(*) FROM lor_snap.v_current_previews;
#   SELECT COUNT(*) FROM lor_snap.v_current_props;
#   SELECT COUNT(*) FROM lor_snap.v_current_sub_props;
#   SELECT COUNT(*) FROM lor_snap.v_current_dmx_channels;
#
# Dependencies
#   pip install psycopg2-binary
#
# -----------------------------------------------------------------------------
# Change Log
# 2026-08-21  GAL / OpenAI  V0.4.2
#   - For parser V7.0.11 and later, requires dmxChannels.RawPropID,
#     ChannelName, and ChannelGridRowNumber in SQLite and matching additive
#     columns in lor_snap.dmx_channels before creating a new import_run.
#   - Validates all V7.0.11+ DMX source-detail values before import and again in
#     PostgreSQL before commit; source row-number gaps remain valid.
#   - Keeps older V7 snapshots eligible under their historical schema contract.
# 2026-08-16  GAL / OpenAI  V0.4.1
#   - Prevented Unicode diagnostics from aborting a committed Windows ingest.
#   - Detects an already-completed exact SQLite digest and returns its existing
#     import_run_id without creating a duplicate snapshot.
#   - Never claims that a committed transaction was rolled back.
# 2026-08-13  GAL / OpenAI  V0.4.0
#   - Requires --expected-sqlite-sha256 and rejects any byte-level change.
#   - Requires parser_run RunMode=PRODUCTION, ValidationStatus=PASSED,
#     SourceLORVersion, ParserSHA256, and SourceManifestSHA256.
#   - Carries the complete authority chain into lor_snap.import_run.
# 2026-08-03  GAL  V0.3.2
#   - Added a pre-ingest parser lifecycle guard.
#   - Requires parser_run.Status = COMPLETE before creating import_run.
#   - RUNNING, FAILED, blank, or missing status aborts without PostgreSQL writes.
# 2026-08-03  GAL  V0.3.1
#   - Added source preview filename handoff from
#     SQLite previews.SourceFilename to
#     lor_snap.previews.source_filename.
#   - The exact .lorprev filename is now preserved with each
#     append-only PostgreSQL preview snapshot row.
# 2026-08-03  GAL  V0.3.0
#   - Added INGEST_SCRIPT_VERSION as the authoritative ingest version constant.
#   - Reads parser_run metadata from the rebuilt SQLite snapshot.
#   - Writes parser and ingest provenance directly to lor_snap.import_run.
#   - Records source row counts for previews, scenes, props, sub_props,
#     dmx_channels, and scene_lor_props.
#   - Updates ingest_completed_at within the same atomic transaction.
#
# 2026-08-02  GAL  V0.2.0
#   - Added required raw PropClass UUID ingestion for props and sub_props.
#   - Added source/target schema-contract validation before import_run creation.
#   - Added post-ingest raw UUID completeness checks for both snapshot tables.
#
# 2026-02-21  GAL
#   - Initial version: append-only snapshot ingestion from SQLite to Postgres.
# =============================================================================

"""
SQLite -> Postgres (lor_snap) ingestion
- Append-only by run: each ingestion inserts a new lor_snap.import_run row
- Snapshot tables are loaded with import_run_id
- No business logic, no transforms beyond column name matching

Requirements:
  pip install psycopg2-binary

Example:
  python postgres_ingest_from_lor_sqlite_v7.py ^
    --sqlite "G:\\Shared drives\\MSB Database\\database\\lor_output_v7_scene.db" ^
    --pg-host "db.sheboyganlights.org" ^
    --pg-db "msb" ^
    --pg-user "msbadmin" ^
    --pg-password "YOUR_PASSWORD" ^
    --notes "Initial Postgres snapshot ingest"
"""

from __future__ import annotations

import argparse
import getpass
import hashlib
import os
import platform
import re
import socket
import sqlite3
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Any

import psycopg2
import psycopg2.extras


INGEST_SCRIPT_VERSION = "V0.4.2"
DMX_SOURCE_DETAIL_MIN_PARSER_VERSION = (7, 0, 11)
DMX_SOURCE_DETAIL_SCHEMA_CONTRACT = (
    ("RawPropID", "raw_prop_id"),
    ("ChannelName", "channel_name"),
    ("ChannelGridRowNumber", "channel_grid_row_number"),
)


# ---------------------------
# Helpers
# ---------------------------

def configure_console_output() -> None:
    """Make diagnostics non-fatal on legacy Windows console code pages."""
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if callable(reconfigure):
            try:
                reconfigure(errors="backslashreplace")
            except (AttributeError, OSError, ValueError):
                # Embedded and test streams may not support reconfiguration.
                pass


configure_console_output()


def norm_name(s: str) -> str:
    """Normalize a column name for matching: lowercase and remove underscores/spaces."""
    return "".join(ch for ch in s.lower() if ch.isalnum())


def sha256_file(path: str) -> str:
    """Return a streaming digest for the exact reviewed SQLite artifact."""
    digest = hashlib.sha256()
    with open(path, "rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def verify_reviewed_sqlite(path: str, expected_sha256: str) -> str:
    expected = expected_sha256.strip().lower()
    if len(expected) != 64 or any(character not in "0123456789abcdef" for character in expected):
        raise RuntimeError("Expected SQLite SHA-256 must be exactly 64 hexadecimal characters")
    actual = sha256_file(path)
    if actual != expected:
        raise RuntimeError(
            "SQLite authority check failed: the selected file is not the exact "
            f"operator-reviewed artifact (expected {expected}, found {actual})"
        )
    return actual


def get_sqlite_columns(conn: sqlite3.Connection, table: str) -> List[str]:
    cur = conn.execute(f'PRAGMA table_info("{table}")')
    rows = cur.fetchall()
    # PRAGMA table_info: (cid, name, type, notnull, dflt_value, pk)
    return [r[1] for r in rows]


def get_pg_columns(pg_conn, schema: str, table: str) -> List[str]:
    with pg_conn.cursor() as cur:
        cur.execute(
            """
            SELECT column_name
            FROM information_schema.columns
            WHERE table_schema = %s AND table_name = %s
            ORDER BY ordinal_position
            """,
            (schema, table),
        )
        return [r[0] for r in cur.fetchall()]


RAW_ID_SCHEMA_CONTRACT = {
    "props": {
        "sqlite_table": "props",
        "sqlite_column": "RawPropID",
        "pg_table": "props",
        "pg_column": "raw_prop_id",
    },
    "sub_props": {
        "sqlite_table": "subProps",
        "sqlite_column": "RawPropID",
        "pg_table": "sub_props",
        "pg_column": "raw_prop_id",
    },
}


def validate_raw_id_schema_contract(
    sqlite_conn: sqlite3.Connection,
    pg_conn,
) -> None:
    """
    Require the raw LOR PropClass UUID columns on both sides before ingest.

    This prevents the generic column mapper from silently inserting NULL when
    either the rebuilt SQLite schema or the Postgres snapshot schema is stale.
    """
    failures: List[str] = []

    for label, contract in RAW_ID_SCHEMA_CONTRACT.items():
        sqlite_cols = get_sqlite_columns(sqlite_conn, contract["sqlite_table"])
        pg_cols = get_pg_columns(pg_conn, "lor_snap", contract["pg_table"])

        if contract["sqlite_column"] not in sqlite_cols:
            failures.append(
                f'SQLite table "{contract["sqlite_table"]}" is missing '
                f'"{contract["sqlite_column"]}"'
            )

        if contract["pg_column"] not in pg_cols:
            failures.append(
                f'Postgres table lor_snap.{contract["pg_table"]} is missing '
                f'"{contract["pg_column"]}"'
            )

    if failures:
        details = "\n".join(f"  - {item}" for item in failures)
        raise RuntimeError(
            "Raw PropClass UUID schema contract failed:\n"
            f"{details}\n"
            "The ingest was not started."
        )

    print("[OK] Raw PropClass UUID schema contract verified.")


def validate_raw_id_source_values(sqlite_conn: sqlite3.Connection) -> None:
    """Fail if any rebuilt SQLite prop/subprop row lacks RawPropID."""
    failures: List[str] = []

    for table in ("props", "subProps"):
        missing = int(
            sqlite_conn.execute(
                f"""
                SELECT COUNT(*)
                FROM "{table}"
                WHERE RawPropID IS NULL OR TRIM(RawPropID) = ''
                """
            ).fetchone()[0]
        )
        if missing:
            failures.append(f'SQLite "{table}" has {missing} blank RawPropID row(s)')

    if failures:
        details = "\n".join(f"  - {item}" for item in failures)
        raise RuntimeError(
            "Raw PropClass UUID source-value validation failed:\n"
            f"{details}"
        )

    print("[OK] SQLite raw PropClass UUID values are complete.")


def validate_raw_id_target_values(pg_conn, import_run_id: int) -> None:
    """Fail if the inserted Postgres snapshot contains blank raw_prop_id values."""
    failures: List[str] = []

    for table in ("props", "sub_props"):
        with pg_conn.cursor() as cur:
            cur.execute(
                f"""
                SELECT COUNT(*)
                FROM lor_snap.{table}
                WHERE import_run_id = %s
                  AND (raw_prop_id IS NULL OR BTRIM(raw_prop_id) = '')
                """,
                (import_run_id,),
            )
            missing = int(cur.fetchone()[0])

        if missing:
            failures.append(
                f"lor_snap.{table} has {missing} blank raw_prop_id row(s) "
                f"for import_run_id={import_run_id}"
            )

    if failures:
        details = "\n".join(f"  - {item}" for item in failures)
        raise RuntimeError(
            "Raw PropClass UUID target-value validation failed:\n"
            f"{details}"
        )

    print("[OK] Postgres raw PropClass UUID values are complete.")


def parser_version_tuple(parser_version: str) -> tuple[int, int, int]:
    """Parse the controlled V<major>.<minor>.<patch> parser version."""
    match = re.fullmatch(r"V(\d+)\.(\d+)\.(\d+)", str(parser_version or "").strip())
    if match is None:
        raise RuntimeError(
            "Parser snapshot is not eligible for ingest: parser_version must use "
            f"V<major>.<minor>.<patch>; found {parser_version!r}"
        )
    return tuple(int(part) for part in match.groups())


def parser_requires_dmx_source_detail(parser_version: str) -> bool:
    """Return whether this parser version owns the V7.0.11 DMX source contract."""
    return parser_version_tuple(parser_version) >= DMX_SOURCE_DETAIL_MIN_PARSER_VERSION


def validate_dmx_source_detail_schema_contract(
    sqlite_conn: sqlite3.Connection,
    pg_conn,
    parser_version: str,
) -> None:
    """Require V7.0.11+ DMX source-detail columns on both sides before ingest."""
    if not parser_requires_dmx_source_detail(parser_version):
        return

    sqlite_cols = get_sqlite_columns(sqlite_conn, "dmxChannels")
    pg_cols = get_pg_columns(pg_conn, "lor_snap", "dmx_channels")
    failures: List[str] = []

    for sqlite_column, pg_column in DMX_SOURCE_DETAIL_SCHEMA_CONTRACT:
        if sqlite_column not in sqlite_cols:
            failures.append(
                f'SQLite table "dmxChannels" is missing "{sqlite_column}"'
            )
        if pg_column not in pg_cols:
            failures.append(
                f'Postgres table lor_snap.dmx_channels is missing "{pg_column}"'
            )

    if failures:
        details = "\n".join(f"  - {item}" for item in failures)
        raise RuntimeError(
            "V7.0.11+ DMX source-detail schema contract failed:\n"
            f"{details}\n"
            "The ingest was not started."
        )

    print("[OK] V7.0.11+ DMX source-detail schema contract verified.")


def validate_dmx_source_detail_source_values(
    sqlite_conn: sqlite3.Connection,
    parser_version: str,
) -> None:
    """Require every V7.0.11+ DMX row to retain source identity/name/row number."""
    if not parser_requires_dmx_source_detail(parser_version):
        return

    failures: List[str] = []
    checks = (
        (
            "blank RawPropID",
            "RawPropID IS NULL OR TRIM(RawPropID) = ''",
        ),
        (
            "blank ChannelName",
            "ChannelName IS NULL OR TRIM(ChannelName) = ''",
        ),
        (
            "invalid ChannelGridRowNumber",
            "ChannelGridRowNumber IS NULL OR ChannelGridRowNumber <= 0",
        ),
    )
    for label, predicate in checks:
        count = int(
            sqlite_conn.execute(
                f'SELECT COUNT(*) FROM "dmxChannels" WHERE {predicate}'
            ).fetchone()[0]
        )
        if count:
            failures.append(f'SQLite "dmxChannels" has {count} row(s) with {label}')

    if failures:
        details = "\n".join(f"  - {item}" for item in failures)
        raise RuntimeError(
            "V7.0.11+ DMX source-detail source-value validation failed:\n"
            f"{details}"
        )

    print("[OK] SQLite V7.0.11+ DMX source-detail values are complete.")


def validate_dmx_source_detail_target_values(
    pg_conn,
    import_run_id: int,
    parser_version: str,
) -> None:
    """Require V7.0.11+ source detail to survive SQLite -> PostgreSQL."""
    if not parser_requires_dmx_source_detail(parser_version):
        return

    checks = (
        ("blank raw_prop_id", "raw_prop_id IS NULL OR BTRIM(raw_prop_id) = ''"),
        ("blank channel_name", "channel_name IS NULL OR BTRIM(channel_name) = ''"),
        (
            "invalid channel_grid_row_number",
            "channel_grid_row_number IS NULL OR channel_grid_row_number <= 0",
        ),
    )
    failures: List[str] = []
    for label, predicate in checks:
        with pg_conn.cursor() as cur:
            cur.execute(
                f"""
                SELECT COUNT(*)
                FROM lor_snap.dmx_channels
                WHERE import_run_id = %s
                  AND ({predicate})
                """,
                (import_run_id,),
            )
            count = int(cur.fetchone()[0])
        if count:
            failures.append(
                f"lor_snap.dmx_channels has {count} row(s) with {label} "
                f"for import_run_id={import_run_id}"
            )

    if failures:
        details = "\n".join(f"  - {item}" for item in failures)
        raise RuntimeError(
            "V7.0.11+ DMX source-detail target-value validation failed:\n"
            f"{details}"
        )

    print("[OK] Postgres V7.0.11+ DMX source-detail values are complete.")


def build_column_map(sqlite_cols: List[str], pg_cols: List[str]) -> Dict[str, str]:
    """
    Build mapping from PG col -> SQLite col by normalized-name matching.

    Example:
      PG: 'lor_comment'  -> SQLite: 'LORComment'
      PG: 'int_preview_id' -> SQLite: 'IntPreviewID'
    """
    sqlite_by_norm = {norm_name(c): c for c in sqlite_cols}
    mapping: Dict[str, str] = {}

    for pg_c in pg_cols:
        if pg_c == "import_run_id":
            continue
        n = norm_name(pg_c)
        if n in sqlite_by_norm:
            mapping[pg_c] = sqlite_by_norm[n]

    return mapping


def fetch_sqlite_rows(conn: sqlite3.Connection, table: str, cols: List[str]) -> List[Tuple[Any, ...]]:
    """
    Fetch rows from SQLite table selecting columns in 'cols' order.
    """
    if not cols:
        return []
    col_sql = ", ".join(f'"{c}"' for c in cols)
    sql = f'SELECT {col_sql} FROM "{table}"'
    cur = conn.execute(sql)
    return cur.fetchall()


def get_actor_host() -> tuple[str, str]:
    """Return the current operating-system user and host names."""
    actor = (
        os.environ.get("USERNAME")
        or os.environ.get("USER")
        or getpass.getuser()
        or "unknown"
    )
    host = (
        os.environ.get("COMPUTERNAME")
        or socket.gethostname()
        or platform.node()
        or "unknown-host"
    )
    return str(actor).strip(), str(host).strip()


def read_parser_run(sqlite_conn: sqlite3.Connection) -> Dict[str, Any]:
    """Read the current parser execution metadata from the rebuilt SQLite DB."""
    cols = get_sqlite_columns(sqlite_conn, "parser_run")
    if not cols:
        raise RuntimeError('SQLite table "parser_run" is missing')

    cur = sqlite_conn.execute(
        'SELECT ParserVersion, StartedAt, CompletedAt, Actor, HostName, '
        'SourcePreviewFolder, SQLiteDatabasePath, Status, RunMode, '
        'SourceLORVersion, ParserSHA256, SourceManifestSHA256, '
        'CompatibilityManifestSHA256, ValidationStatus, ValidationDetail '
        'FROM parser_run LIMIT 2'
    )
    rows = cur.fetchall()
    if len(rows) != 1:
        raise RuntimeError(
            f'Expected exactly one parser_run row in SQLite; found {len(rows)}'
        )

    keys = [
        "parser_version",
        "parser_started_at",
        "parser_completed_at",
        "parser_actor",
        "parser_host",
        "source_preview_folder",
        "source_sqlite_path",
        "parser_status",
        "parser_run_mode",
        "source_lor_version",
        "parser_sha256",
        "source_manifest_sha256",
        "compatibility_manifest_sha256",
        "parser_validation_status",
        "parser_validation_detail",
    ]
    parser_run = dict(zip(keys, rows[0]))
    parser_status = parser_run.get("parser_status")
    if parser_status != "COMPLETE":
        displayed_status = "<NULL>" if parser_status is None else repr(parser_status)
        raise RuntimeError(
            "Parser snapshot is not eligible for ingest: "
            f"parser_run.Status must be exactly COMPLETE; found {displayed_status}. "
            "Run the parser successfully before starting PostgreSQL ingest."
        )

    required = {
        "parser_run_mode": "PRODUCTION",
        "parser_validation_status": "PASSED",
    }
    for field, expected in required.items():
        if parser_run.get(field) != expected:
            raise RuntimeError(
                f"Parser snapshot is not eligible for ingest: {field} must be "
                f"{expected}; found {parser_run.get(field)!r}"
            )
    if not str(parser_run.get("parser_version") or "").startswith("V7."):
        raise RuntimeError("Parser snapshot is not eligible for ingest: a current V7 parser is required")
    for field in (
        "source_lor_version", "parser_sha256", "source_manifest_sha256",
        "compatibility_manifest_sha256",
        "parser_completed_at",
    ):
        if not str(parser_run.get(field) or "").strip():
            raise RuntimeError(f"Parser snapshot is not eligible for ingest: {field} is missing")

    return parser_run


def get_sqlite_snapshot_counts(sqlite_conn: sqlite3.Connection) -> Dict[str, int]:
    """Count the current disposable SQLite snapshot tables."""
    table_map = {
        "preview_count": "previews",
        "scene_count": "scenes",
        "prop_count": "props",
        "sub_prop_count": "subProps",
        "dmx_channel_count": "dmxChannels",
        "scene_lor_prop_count": "scene_lor_props",
    }
    return {
        key: int(sqlite_conn.execute(f'SELECT COUNT(*) FROM "{table}"').fetchone()[0])
        for key, table in table_map.items()
    }


def insert_import_run(
    pg_conn,
    notes: str | None,
    parser_run: Dict[str, Any],
    source_counts: Dict[str, int],
    ingest_actor: str,
    ingest_host: str,
    ingest_started_at: datetime,
    sqlite_sha256: str,
) -> int:
    """Create the append-only import_run row with parser and ingest provenance."""
    with pg_conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO lor_snap.import_run (
                notes,
                parser_version,
                parser_started_at,
                parser_completed_at,
                parser_actor,
                parser_host,
                source_preview_folder,
                source_sqlite_path,
                parser_run_mode,
                source_lor_version,
                parser_sha256,
                source_manifest_sha256,
                compatibility_manifest_sha256,
                parser_validation_status,
                parser_validation_detail,
                source_sqlite_sha256,
                preview_count,
                scene_count,
                prop_count,
                sub_prop_count,
                dmx_channel_count,
                scene_lor_prop_count,
                ingest_script_version,
                ingest_actor,
                ingest_host,
                ingest_started_at
            )
            VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            )
            RETURNING import_run_id
            """,
            (
                notes,
                parser_run.get("parser_version"),
                parser_run.get("parser_started_at"),
                parser_run.get("parser_completed_at"),
                parser_run.get("parser_actor"),
                parser_run.get("parser_host"),
                parser_run.get("source_preview_folder"),
                parser_run.get("source_sqlite_path"),
                parser_run.get("parser_run_mode"),
                parser_run.get("source_lor_version"),
                parser_run.get("parser_sha256"),
                parser_run.get("source_manifest_sha256"),
                parser_run.get("compatibility_manifest_sha256"),
                parser_run.get("parser_validation_status"),
                parser_run.get("parser_validation_detail"),
                sqlite_sha256,
                source_counts["preview_count"],
                source_counts["scene_count"],
                source_counts["prop_count"],
                source_counts["sub_prop_count"],
                source_counts["dmx_channel_count"],
                source_counts["scene_lor_prop_count"],
                INGEST_SCRIPT_VERSION,
                ingest_actor,
                ingest_host,
                ingest_started_at,
            ),
        )
        return int(cur.fetchone()[0])


def complete_import_run(pg_conn, import_run_id: int, completed_at: datetime) -> None:
    """Stamp ingest completion before the single transaction commit."""
    with pg_conn.cursor() as cur:
        cur.execute(
            """
            UPDATE lor_snap.import_run
            SET ingest_completed_at = %s
            WHERE import_run_id = %s
            """,
            (completed_at, import_run_id),
        )


def find_completed_import_run(pg_conn, sqlite_sha256: str) -> int | None:
    """Return the completed run for an exact SQLite digest, if it exists."""
    with pg_conn.cursor() as cur:
        cur.execute(
            """
            SELECT import_run_id
            FROM lor_snap.import_run
            WHERE lower(source_sqlite_sha256) = %s
              AND ingest_completed_at IS NOT NULL
            ORDER BY import_run_id DESC
            LIMIT 1
            """,
            (sqlite_sha256.lower(),),
        )
        row = cur.fetchone()
    return int(row[0]) if row else None


def bulk_insert(
    pg_conn,
    target_schema: str,
    target_table: str,
    pg_cols: List[str],
    rows: List[Tuple[Any, ...]],
    page_size: int = 5000,
) -> None:
    """
    Bulk insert into Postgres using execute_values.
    pg_cols must match tuple order in rows.
    """
    if not rows:
        return

    cols_sql = ", ".join(pg_cols)
    sql = f"INSERT INTO {target_schema}.{target_table} ({cols_sql}) VALUES %s"
    with pg_conn.cursor() as cur:
        psycopg2.extras.execute_values(cur, sql, rows, page_size=page_size)


def count_rows_pg(pg_conn, schema: str, table: str, import_run_id: int) -> int:
    with pg_conn.cursor() as cur:
        cur.execute(
            f"SELECT COUNT(*) FROM {schema}.{table} WHERE import_run_id = %s",
            (import_run_id,),
        )
        return int(cur.fetchone()[0])


# ---------------------------
# Main ingestion
# ---------------------------

def ingest_table(
    sqlite_conn: sqlite3.Connection,
    pg_conn,
    sqlite_table: str,
    pg_table: str,
    import_run_id: int,
) -> None:
    """
    Load one SQLite table into one Postgres table.
    Adds import_run_id to every row, and matches columns by normalized names.
    """
    sqlite_cols = get_sqlite_columns(sqlite_conn, sqlite_table)
    pg_cols_full = get_pg_columns(pg_conn, "lor_snap", pg_table)

    # Build mapping from PG col -> SQLite col where possible.
    pg_to_sqlite = build_column_map(sqlite_cols, pg_cols_full)

    # Build final column order for Postgres insert.
    # Always include import_run_id first for clarity.
    insert_pg_cols: List[str] = ["import_run_id"] + [c for c in pg_cols_full if c != "import_run_id"]

    # For SQLite select, only select columns that exist in SQLite (in the same order as insert columns),
    # and later fill missing columns with None.
    sqlite_select_cols: List[str] = []
    for pg_c in insert_pg_cols:
        if pg_c == "import_run_id":
            continue
        if pg_c in pg_to_sqlite:
            sqlite_select_cols.append(pg_to_sqlite[pg_c])

    sqlite_rows = fetch_sqlite_rows(sqlite_conn, sqlite_table, sqlite_select_cols)

    # Create Postgres rows in the correct tuple order (matching insert_pg_cols).
    # For any PG column not found in SQLite, insert None.
    # For columns found, take from SQLite row in the same position as sqlite_select_cols.
    # We'll build a lookup of SQLite col -> index in sqlite row.
    sqlite_idx = {c: i for i, c in enumerate(sqlite_select_cols)}

    out_rows: List[Tuple[Any, ...]] = []
    for r in sqlite_rows:
        row_out: List[Any] = [import_run_id]
        for pg_c in insert_pg_cols[1:]:
            s_c = pg_to_sqlite.get(pg_c)
            if s_c is None:
                row_out.append(None)
            else:
                row_out.append(r[sqlite_idx[s_c]])
        out_rows.append(tuple(row_out))

    bulk_insert(pg_conn, "lor_snap", pg_table, insert_pg_cols, out_rows)

    # Basic count check
    pg_count = count_rows_pg(pg_conn, "lor_snap", pg_table, import_run_id)
    if pg_count != len(out_rows):
        raise RuntimeError(
            f"[COUNT MISMATCH] {pg_table}: inserted={pg_count} expected={len(out_rows)}"
        )

    print(f"[OK] {pg_table}: inserted {pg_count} rows")


def main() -> int:
    ap = argparse.ArgumentParser(description="Ingest LOR SQLite snapshot into Postgres lor_snap (append-only by run).")
    ap.add_argument("--sqlite", required=True, help="Path to lor_output_v7_scene.db (SQLite).")
    ap.add_argument(
        "--expected-sqlite-sha256", required=True,
        help="SHA-256 recorded when the exact SQLite file was approved for ingest.",
    )
    ap.add_argument("--pg-host", required=True, help="Postgres host (e.g., db.sheboyganlights.org).")
    ap.add_argument("--pg-port", type=int, default=5432, help="Postgres port (default 5432).")
    ap.add_argument("--pg-db", required=True, help="Postgres database name (e.g., msb).")
    ap.add_argument("--pg-user", required=True, help="Postgres username (e.g., msbadmin).")
    ap.add_argument("--pg-password", default=None, help="Postgres password (or set PGPASSWORD env var).")
    ap.add_argument("--notes", default=None, help="Notes to store on lor_snap.import_run.")
    args = ap.parse_args()

    sqlite_path = args.sqlite
    if not os.path.exists(sqlite_path):
        print(f"[FATAL] SQLite file not found: {sqlite_path}", file=sys.stderr)
        return 2

    committed = False
    try:
        reviewed_sqlite_sha256 = verify_reviewed_sqlite(
            sqlite_path, args.expected_sqlite_sha256
        )
    except RuntimeError as error:
        print(f"[FATAL] {error}", file=sys.stderr)
        return 2

    pg_password = args.pg_password or os.environ.get("PGPASSWORD")
    if not pg_password:
        print("[FATAL] Missing Postgres password. Use --pg-password or set PGPASSWORD env var.", file=sys.stderr)
        return 2

    # Open the approved artifact read-only. Recheck its digest immediately
    # before the PostgreSQL commit to close the parser/review/ingest handoff.
    sqlite_uri = Path(sqlite_path).resolve().as_uri() + "?mode=ro&immutable=1"
    sqlite_conn = sqlite3.connect(sqlite_uri, uri=True)
    sqlite_conn.row_factory = None  # tuples

    # Connect Postgres
    pg_conn = psycopg2.connect(
        host=args.pg_host,
        port=args.pg_port,
        dbname=args.pg_db,
        user=args.pg_user,
        password=pg_password,
    )
    pg_conn.autocommit = False  # we want all-or-nothing

    try:
        # Read parser provenance first.  The V7.0.11+ DMX contract is versioned,
        # and every contract check below still runs before any import_run insert.
        parser_run = read_parser_run(sqlite_conn)
        parser_version = str(parser_run.get("parser_version") or "")

        validate_raw_id_schema_contract(sqlite_conn, pg_conn)
        validate_raw_id_source_values(sqlite_conn)
        validate_dmx_source_detail_schema_contract(
            sqlite_conn, pg_conn, parser_version
        )
        validate_dmx_source_detail_source_values(sqlite_conn, parser_version)

        source_counts = get_sqlite_snapshot_counts(sqlite_conn)
        ingest_actor, ingest_host = get_actor_host()
        ingest_started_at = datetime.now().astimezone()

        existing_import_run_id = find_completed_import_run(
            pg_conn, reviewed_sqlite_sha256
        )
        if existing_import_run_id is not None:
            pg_conn.rollback()
            print(
                "[DONE] Snapshot already ingested; using existing "
                f"import_run_id={existing_import_run_id}"
            )
            return 0

        import_run_id = insert_import_run(
            pg_conn,
            args.notes,
            parser_run,
            source_counts,
            ingest_actor,
            ingest_host,
            ingest_started_at,
            reviewed_sqlite_sha256,
        )
        print(
            f"[INFO] Created import_run_id={import_run_id} | "
            f"parser={parser_run.get('parser_version')} | "
            f"parser_completed={parser_run.get('parser_completed_at')} | "
            f"parser_actor={parser_run.get('parser_actor')}@{parser_run.get('parser_host')} | "
            f"lor={parser_run.get('source_lor_version')} | "
            f"sqlite_sha256={reviewed_sqlite_sha256} | "
            f"ingest_actor={ingest_actor}@{ingest_host}"
        )

        # ---------------------------------------------------------------------
        # Ingest snapshot tables
        #
        # Order:
        #   previews first
        #   scenes after previews
        #   props before scene_lor_props
        #   child/wiring tables after their parent snapshot data
        # ---------------------------------------------------------------------
        ingest_table(
            sqlite_conn,
            pg_conn,
            sqlite_table="previews",
            pg_table="previews",
            import_run_id=import_run_id,
        )

        ingest_table(
            sqlite_conn,
            pg_conn,
            sqlite_table="scenes",
            pg_table="scenes",
            import_run_id=import_run_id,
        )

        ingest_table(
            sqlite_conn,
            pg_conn,
            sqlite_table="props",
            pg_table="props",
            import_run_id=import_run_id,
        )

        ingest_table(
            sqlite_conn,
            pg_conn,
            sqlite_table="subProps",
            pg_table="sub_props",
            import_run_id=import_run_id,
        )

        ingest_table(
            sqlite_conn,
            pg_conn,
            sqlite_table="dmxChannels",
            pg_table="dmx_channels",
            import_run_id=import_run_id,
        )

        ingest_table(
            sqlite_conn,
            pg_conn,
            sqlite_table="scene_lor_props",
            pg_table="scene_lor_props",
            import_run_id=import_run_id,
        )

        # Views are managed separately in PostgreSQL and are not rebuilt here.
        # This ingest transaction only loads the append-only lor_snap snapshot.

        # Confirm required source identity/detail survived SQLite -> PostgreSQL
        # before committing the append-only snapshot.
        validate_raw_id_target_values(pg_conn, import_run_id)
        validate_dmx_source_detail_target_values(
            pg_conn, import_run_id, parser_version
        )

        # Complete the permanent handoff record inside the same transaction.
        complete_import_run(pg_conn, import_run_id, datetime.now().astimezone())

        final_sqlite_sha256 = verify_reviewed_sqlite(
            sqlite_path, reviewed_sqlite_sha256
        )
        if final_sqlite_sha256 != reviewed_sqlite_sha256:
            raise RuntimeError("SQLite changed while the ingest transaction was running")

        # One commit at the end = atomic run
        pg_conn.commit()
        committed = True
        print(f"[DONE] Snapshot ingest complete. import_run_id={import_run_id}")

        # -----------------------------------------------------------------
        # Post-run sanity summary (quick health check)
        # -----------------------------------------------------------------
        with pg_conn.cursor() as cur:
            cur.execute("""
                SELECT
                  (SELECT import_run_id FROM lor_snap.v_current_run)               AS current_run,
                  (SELECT COUNT(*) FROM lor_snap.v_current_previews)               AS previews,
                  (SELECT COUNT(*) FROM lor_snap.v_current_scenes)                 AS scenes,
                  (SELECT COUNT(*) FROM lor_snap.v_current_props)                  AS props,
                  (SELECT COUNT(*) FROM lor_snap.v_current_sub_props)              AS sub_props,
                  (SELECT COUNT(*) FROM lor_snap.v_current_dmx_channels)           AS dmx_channels,
                  (SELECT COUNT(*) FROM lor_snap.v_current_scene_lor_props)        AS scene_lor_props,
                  (SELECT COUNT(*) FROM lor_snap.preview_wiring_fieldonly_v6)      AS wiring_field_rows
            """)
            row = cur.fetchone()

            print(
                "[INFO] Run summary -> "
                f"run={row[0]} | "
                f"previews={row[1]} | "
                f"scenes={row[2]} | "
                f"props={row[3]} | "
                f"sub_props={row[4]} | "
                f"dmx={row[5]} | "
                f"scene_lor_props={row[6]} | "
                f"field_wiring={row[7]}"
            )
        if row[7] == 0:
            print("[WARN] wiring_field_rows is 0; views likely failed or current_run is empty.", file=sys.stderr)

        return 0

    except Exception as e:
        if committed:
            print(
                "[FATAL] Ingest committed, but post-commit reporting failed; "
                "do not retry without checking PostgreSQL.",
                file=sys.stderr,
            )
        else:
            pg_conn.rollback()
            print("[FATAL] Ingest failed; transaction rolled back.", file=sys.stderr)
        print(f"        {type(e).__name__}: {e}", file=sys.stderr)
        return 1

    finally:
        try:
            sqlite_conn.close()
        except Exception:
            pass
        try:
            pg_conn.close()
        except Exception:
            pass


if __name__ == "__main__":
    raise SystemExit(main())
