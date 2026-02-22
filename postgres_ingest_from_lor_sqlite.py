# MSB Database — Postgres Snapshot Ingest (from LOR SQLite)
# postgres_ingest_from_lor_sqlite.py
# Initial Release : 2026-02-21  V0.1.0
# Version         : 2026-02-21  V0.1.0
# Current Version : 2026-02-21  V0.1.0
#
# Changes:
# - Initial append-only ingestion layer (SQLite → Postgres)
# - Creates new lor_snap.import_run row per execution
# - Loads previews, props, sub_props, dmx_channels
# - All-or-nothing transaction (rollback on failure)
# (GAL)
#
# Author          : Greg Liebig, Engineering Innovations, LLC.
#
# Purpose
# -------
# Promote the rebuilt SQLite snapshot (lor_output_v6.db), produced by
# parse_props_v6.py, into the production Postgres database (msb-prod-db).
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
#   - SQLite file: G:\Shared drives\MSB Database\database\lor_output_v6.db
#   - Postgres host: db.sheboyganlights.org (msb-prod-db)
#   - Database: msb
#   - Schema: lor_snap
#
# How to Run (PowerShell)
#   $env:PGPASSWORD="your_password"
#   python ingest_lor_sqlite_to_postgres.py `
#     --sqlite "G:\Shared drives\MSB Database\database\lor_output_v6.db" `
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
  python ingest_lor_sqlite_to_postgres.py ^
    --sqlite "G:\\Shared drives\\MSB Database\\database\\lor_output_v6.db" ^
    --pg-host "db.sheboyganlights.org" ^
    --pg-db "msb" ^
    --pg-user "msbadmin" ^
    --pg-password "YOUR_PASSWORD" ^
    --notes "Initial Postgres snapshot ingest"
"""

from __future__ import annotations

import argparse
import os
import sqlite3
import sys
from typing import Dict, List, Tuple, Any

import psycopg2
import psycopg2.extras


# ---------------------------
# Helpers
# ---------------------------

def norm_name(s: str) -> str:
    """Normalize a column name for matching: lowercase and remove underscores/spaces."""
    return "".join(ch for ch in s.lower() if ch.isalnum())


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


def insert_import_run(pg_conn, notes: str | None) -> int:
    with pg_conn.cursor() as cur:
        cur.execute(
            "INSERT INTO lor_snap.import_run (notes) VALUES (%s) RETURNING import_run_id",
            (notes,),
        )
        return int(cur.fetchone()[0])


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
    ap.add_argument("--sqlite", required=True, help="Path to lor_output_v6.db (SQLite).")
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

    pg_password = args.pg_password or os.environ.get("PGPASSWORD")
    if not pg_password:
        print("[FATAL] Missing Postgres password. Use --pg-password or set PGPASSWORD env var.", file=sys.stderr)
        return 2

    # Connect SQLite
    sqlite_conn = sqlite3.connect(sqlite_path)
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
        import_run_id = insert_import_run(pg_conn, args.notes)
        print(f"[INFO] Created import_run_id={import_run_id}")

        # Ingest tables (order matters because of FKs)
        ingest_table(sqlite_conn, pg_conn, sqlite_table="previews",    pg_table="previews",     import_run_id=import_run_id)
        ingest_table(sqlite_conn, pg_conn, sqlite_table="props",       pg_table="props",        import_run_id=import_run_id)
        ingest_table(sqlite_conn, pg_conn, sqlite_table="subProps",    pg_table="sub_props",    import_run_id=import_run_id)
        ingest_table(sqlite_conn, pg_conn, sqlite_table="dmxChannels", pg_table="dmx_channels", import_run_id=import_run_id)

        # ---------------------------------------------------------------------
        # Rebuild Postgres views after ingest (no psql required)
        # NOTE: keep this in the same transaction so ingest+views are atomic.
        # ---------------------------------------------------------------------
        from pathlib import Path

        views_sql_path = Path(__file__).parent / "Postgres_sql" / "postgres_create_views_lor_snap.sql"
        if not views_sql_path.exists():
            raise FileNotFoundError("View SQL file not found: Postgres_sql/postgres_create_views_lor_snap.sql")

        print("[INFO] Rebuilding lor_snap views...")

        view_sql = views_sql_path.read_text(encoding="utf-8")

        with pg_conn.cursor() as cur:
            cur.execute(view_sql)

        # One commit at the end = atomic run
        pg_conn.commit()
        print(f"[DONE] Ingest + views complete. import_run_id={import_run_id}")

        # -----------------------------------------------------------------
        # Post-run sanity summary (quick health check)
        # -----------------------------------------------------------------
        with pg_conn.cursor() as cur:
            cur.execute("""
                SELECT
                  (SELECT import_run_id FROM lor_snap.v_current_run)               AS current_run,
                  (SELECT COUNT(*) FROM lor_snap.v_current_previews)               AS previews,
                  (SELECT COUNT(*) FROM lor_snap.v_current_props)                  AS props,
                  (SELECT COUNT(*) FROM lor_snap.v_current_sub_props)              AS sub_props,
                  (SELECT COUNT(*) FROM lor_snap.v_current_dmx_channels)           AS dmx_channels,
                  (SELECT COUNT(*) FROM lor_snap.preview_wiring_fieldonly_v6)      AS wiring_field_rows,
                  (SELECT COUNT(*) FROM lor_snap.stage_display_unassigned_v1)      AS unassigned_displays
            """)
            row = cur.fetchone()

        print(
            "[INFO] Run summary → "
            f"run={row[0]} | "
            f"previews={row[1]} | "
            f"props={row[2]} | "
            f"sub_props={row[3]} | "
            f"dmx={row[4]} | "
            f"field_wiring={row[5]} | "
            f"unassigned={row[6]}"
        )
        if row[5] == 0:
            print("[WARN] wiring_field_rows is 0 — views likely failed or current_run is empty.", file=sys.stderr)

        if row[6] > 0:
            print(f"[WARN] Unassigned displays detected: {row[6]}", file=sys.stderr)
            
        return 0

    except Exception as e:
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