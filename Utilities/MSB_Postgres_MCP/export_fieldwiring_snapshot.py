from __future__ import annotations

import argparse
import datetime as dt
import decimal
import json
import os
import sqlite3
import sys
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import psycopg
from psycopg import IsolationLevel, sql
from psycopg.rows import dict_row


SNAPSHOT_FORMAT_VERSION = 1
DEFAULT_STATEMENT_TIMEOUT_MS = 30000


@dataclass(frozen=True)
class RelationSpec:
    schema: str
    relation: str
    current_run_filter: bool = False

    @property
    def sqlite_table(self) -> str:
        return f"{self.schema}__{self.relation}"


RELATIONS: tuple[RelationSpec, ...] = (
    RelationSpec("lor_snap", "v_current_run"),
    RelationSpec("lor_snap", "v_current_previews"),
    RelationSpec("lor_snap", "v_current_scenes"),
    RelationSpec("lor_snap", "v_current_props"),
    RelationSpec("lor_snap", "v_current_sub_props"),
    RelationSpec("lor_snap", "v_current_dmx_channels"),
    RelationSpec("lor_snap", "v_current_scene_lor_props"),
    RelationSpec("lor_snap", "v_display_lor_occurrence", current_run_filter=True),
    RelationSpec("lor_snap", "preview_wiring_fieldlead_v6"),
    RelationSpec("ops", "v_lor_display_reconciliation", current_run_filter=True),
    RelationSpec("ref", "display"),
    RelationSpec("ref", "display_status"),
    RelationSpec("ref", "stage"),
)


def _dsn() -> str:
    value = os.environ.get("MSB_PG_DSN", "").strip()
    if not value:
        raise RuntimeError(
            "MSB_PG_DSN is not configured. Load the protected MCP config before running the exporter."
        )
    return value


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Export the current MSB PostgreSQL FieldWiring engineering read model "
            "to one SQLite snapshot."
        )
    )
    parser.add_argument(
        "--output",
        type=Path,
        help=(
            "Destination .db path. If omitted, create a timestamped "
            "fieldwiring_snapshot_run_<id>_<UTC>.db file in the current directory."
        ),
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Replace an existing output file.",
    )
    return parser.parse_args()


def _sqlite_type(data_type: str, udt_name: str) -> str:
    data_type = (data_type or "").lower()
    udt_name = (udt_name or "").lower()

    if data_type in {"smallint", "integer", "bigint", "boolean"}:
        return "INTEGER"
    if data_type in {"real", "double precision", "numeric", "decimal"}:
        return "REAL"
    if data_type == "bytea" or udt_name == "bytea":
        return "BLOB"
    return "TEXT"


def _sqlite_value(value: Any) -> Any:
    if value is None:
        return None
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, (int, float, str, bytes)):
        return value
    if isinstance(value, memoryview):
        return bytes(value)
    if isinstance(value, decimal.Decimal):
        return float(value)
    if isinstance(value, (dt.datetime, dt.date, dt.time)):
        return value.isoformat()
    if isinstance(value, uuid.UUID):
        return str(value)
    if isinstance(value, (dict, list, tuple)):
        return json.dumps(value, default=str, sort_keys=True)
    return str(value)


def _q(value: str) -> str:
    return '"' + value.replace('"', '""') + '"'


def _get_relation_columns(cur: Any, spec: RelationSpec) -> list[dict[str, Any]]:
    cur.execute(
        """
        SELECT
            ordinal_position,
            column_name,
            data_type,
            udt_name,
            is_nullable
        FROM information_schema.columns
        WHERE table_schema = %s
          AND table_name = %s
        ORDER BY ordinal_position
        """,
        (spec.schema, spec.relation),
    )
    columns = [dict(row) for row in cur.fetchall()]
    if not columns:
        raise RuntimeError(
            f"Relation not found or not visible: {spec.schema}.{spec.relation}"
        )
    return columns


def _get_relation_definition(
    cur: Any, spec: RelationSpec
) -> tuple[str | None, str | None]:
    cur.execute(
        """
        SELECT
            c.relkind,
            CASE
                WHEN c.relkind IN ('v', 'm') THEN pg_get_viewdef(c.oid, true)
            END AS view_definition
        FROM pg_class AS c
        JOIN pg_namespace AS n ON n.oid = c.relnamespace
        WHERE n.nspname = %s
          AND c.relname = %s
        """,
        (spec.schema, spec.relation),
    )
    row = cur.fetchone()
    if row is None:
        return None, None
    return row["relkind"], row["view_definition"]


def _create_snapshot_metadata(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        PRAGMA foreign_keys = OFF;

        CREATE TABLE _snapshot_manifest (
            snapshot_format_version INTEGER NOT NULL,
            exported_at_utc TEXT NOT NULL,
            source_database TEXT NOT NULL,
            source_database_user TEXT NOT NULL,
            transaction_read_only TEXT NOT NULL,
            import_run_id INTEGER NOT NULL,
            ingest_timestamp TEXT
        );

        CREATE TABLE _snapshot_relations (
            source_schema TEXT NOT NULL,
            source_relation TEXT NOT NULL,
            sqlite_table TEXT NOT NULL,
            current_run_filter INTEGER NOT NULL,
            row_count INTEGER NOT NULL,
            PRIMARY KEY (source_schema, source_relation)
        );

        CREATE TABLE _snapshot_columns (
            source_schema TEXT NOT NULL,
            source_relation TEXT NOT NULL,
            ordinal_position INTEGER NOT NULL,
            column_name TEXT NOT NULL,
            postgres_data_type TEXT,
            postgres_udt_name TEXT,
            is_nullable TEXT,
            sqlite_declared_type TEXT NOT NULL,
            PRIMARY KEY (source_schema, source_relation, ordinal_position)
        );

        CREATE TABLE _snapshot_view_definitions (
            source_schema TEXT NOT NULL,
            source_relation TEXT NOT NULL,
            relkind TEXT,
            view_definition TEXT,
            PRIMARY KEY (source_schema, source_relation)
        );

        CREATE INDEX _snapshot_relations_sqlite_table_idx
            ON _snapshot_relations (sqlite_table);
        """
    )
    conn.execute(f"PRAGMA user_version = {SNAPSHOT_FORMAT_VERSION}")


def _create_data_table(
    conn: sqlite3.Connection,
    spec: RelationSpec,
    columns: list[dict[str, Any]],
) -> None:
    definitions = [
        f"{_q(column['column_name'])} "
        f"{_sqlite_type(column['data_type'], column['udt_name'])}"
        for column in columns
    ]
    conn.execute(
        f"CREATE TABLE {_q(spec.sqlite_table)} ({', '.join(definitions)})"
    )


def _export_relation(
    pg_cur: Any,
    sqlite_conn: sqlite3.Connection,
    spec: RelationSpec,
    import_run_id: int,
    columns: list[dict[str, Any]],
) -> int:
    relation_sql = sql.SQL("{}.{}").format(
        sql.Identifier(spec.schema),
        sql.Identifier(spec.relation),
    )
    query = sql.SQL("SELECT * FROM {}").format(relation_sql)
    params: tuple[Any, ...] = ()

    if spec.current_run_filter:
        query += sql.SQL(" WHERE import_run_id = %s")
        params = (import_run_id,)

    pg_cur.execute(query, params)

    column_names = [column["column_name"] for column in columns]
    placeholders = ", ".join("?" for _ in column_names)
    insert_sql = (
        f"INSERT INTO {_q(spec.sqlite_table)} "
        f"({', '.join(_q(name) for name in column_names)}) "
        f"VALUES ({placeholders})"
    )

    row_count = 0
    batch: list[tuple[Any, ...]] = []
    for row in pg_cur:
        batch.append(tuple(_sqlite_value(row[name]) for name in column_names))
        if len(batch) >= 1000:
            sqlite_conn.executemany(insert_sql, batch)
            row_count += len(batch)
            batch.clear()

    if batch:
        sqlite_conn.executemany(insert_sql, batch)
        row_count += len(batch)

    return row_count


def _default_output(import_run_id: int) -> Path:
    timestamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return Path.cwd() / f"fieldwiring_snapshot_run_{import_run_id}_{timestamp}.db"


def _resolve_output(
    requested: Path | None,
    import_run_id: int,
    force: bool,
) -> Path:
    output = (requested or _default_output(import_run_id)).expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists() and not force:
        raise FileExistsError(
            f"Output already exists: {output}. Use --force to replace it."
        )
    return output


def _write_snapshot(
    pg_conn: Any,
    output: Path,
    current: dict[str, Any],
) -> list[tuple[str, int]]:
    temp_output = output.with_name(output.name + ".partial")
    if temp_output.exists():
        temp_output.unlink()

    sqlite_conn = sqlite3.connect(temp_output)
    relation_counts: list[tuple[str, int]] = []

    try:
        _create_snapshot_metadata(sqlite_conn)

        with pg_conn.cursor() as pg_cur:
            for spec in RELATIONS:
                columns = _get_relation_columns(pg_cur, spec)
                relkind, view_definition = _get_relation_definition(pg_cur, spec)
                _create_data_table(sqlite_conn, spec, columns)

                for column in columns:
                    sqlite_conn.execute(
                        """
                        INSERT INTO _snapshot_columns (
                            source_schema,
                            source_relation,
                            ordinal_position,
                            column_name,
                            postgres_data_type,
                            postgres_udt_name,
                            is_nullable,
                            sqlite_declared_type
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        (
                            spec.schema,
                            spec.relation,
                            column["ordinal_position"],
                            column["column_name"],
                            column["data_type"],
                            column["udt_name"],
                            column["is_nullable"],
                            _sqlite_type(column["data_type"], column["udt_name"]),
                        ),
                    )

                sqlite_conn.execute(
                    """
                    INSERT INTO _snapshot_view_definitions (
                        source_schema,
                        source_relation,
                        relkind,
                        view_definition
                    ) VALUES (?, ?, ?, ?)
                    """,
                    (
                        spec.schema,
                        spec.relation,
                        relkind,
                        view_definition,
                    ),
                )

                row_count = _export_relation(
                    pg_cur,
                    sqlite_conn,
                    spec,
                    int(current["import_run_id"]),
                    columns,
                )
                relation_counts.append(
                    (f"{spec.schema}.{spec.relation}", row_count)
                )

                sqlite_conn.execute(
                    """
                    INSERT INTO _snapshot_relations (
                        source_schema,
                        source_relation,
                        sqlite_table,
                        current_run_filter,
                        row_count
                    ) VALUES (?, ?, ?, ?, ?)
                    """,
                    (
                        spec.schema,
                        spec.relation,
                        spec.sqlite_table,
                        int(spec.current_run_filter),
                        row_count,
                    ),
                )

        sqlite_conn.execute(
            """
            INSERT INTO _snapshot_manifest (
                snapshot_format_version,
                exported_at_utc,
                source_database,
                source_database_user,
                transaction_read_only,
                import_run_id,
                ingest_timestamp
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                SNAPSHOT_FORMAT_VERSION,
                dt.datetime.now(dt.timezone.utc).isoformat(),
                current["database_name"],
                current["database_user"],
                current["transaction_read_only"],
                int(current["import_run_id"]),
                _sqlite_value(current["ingest_timestamp"]),
            ),
        )
        sqlite_conn.commit()

        integrity = sqlite_conn.execute("PRAGMA integrity_check").fetchone()
        if not integrity or integrity[0] != "ok":
            raise RuntimeError(f"SQLite integrity_check failed: {integrity}")
    except Exception:
        sqlite_conn.rollback()
        sqlite_conn.close()
        temp_output.unlink(missing_ok=True)
        raise
    else:
        sqlite_conn.close()

    os.chmod(temp_output, 0o600)
    os.replace(temp_output, output)
    return relation_counts


def main() -> int:
    args = _parse_args()

    pg_conn = psycopg.connect(
        _dsn(),
        row_factory=dict_row,
        autocommit=False,
        connect_timeout=5,
        application_name="msb-fieldwiring-snapshot-export",
    )
    try:
        # Use one repeatable-read, read-only PostgreSQL transaction so every
        # exported relation represents one consistent source snapshot.
        pg_conn.read_only = True
        pg_conn.isolation_level = IsolationLevel.REPEATABLE_READ

        with pg_conn.cursor() as cur:
            cur.execute(
                f"SET LOCAL statement_timeout = '{DEFAULT_STATEMENT_TIMEOUT_MS}ms'"
            )
            cur.execute("SET LOCAL lock_timeout = '2s'")
            cur.execute(
                """
                SELECT
                    current_database() AS database_name,
                    current_user AS database_user,
                    current_setting('transaction_read_only') AS transaction_read_only,
                    cr.import_run_id,
                    cr.run_ts AS ingest_timestamp
                FROM lor_snap.v_current_run AS cr
                """
            )
            current = cur.fetchone()

        if current is None:
            raise RuntimeError(
                "lor_snap.v_current_run returned no current import run"
            )
        if current["transaction_read_only"] != "on":
            raise RuntimeError("PostgreSQL export transaction is not read-only")

        output = _resolve_output(
            args.output,
            int(current["import_run_id"]),
            args.force,
        )
        relation_counts = _write_snapshot(
            pg_conn,
            output,
            dict(current),
        )

        # Never commit the PostgreSQL transaction.
        pg_conn.rollback()

        print(f"FieldWiring snapshot created: {output}")
        print(f"PostgreSQL import_run_id: {current['import_run_id']}")
        print("Exported relations:")
        for relation_name, row_count in relation_counts:
            print(f"  {relation_name}: {row_count} rows")
        print("SQLite integrity_check: ok")
        return 0
    finally:
        pg_conn.close()


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
