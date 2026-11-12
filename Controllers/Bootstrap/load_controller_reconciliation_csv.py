"""Load Controller Inventory bootstrap evidence into stage.controller_bootstrap.

Default behavior is read-only validation. Pass --apply to write staging rows.
No permanent controller_id is allocated by this tool.
"""

from __future__ import annotations

import argparse
import csv
import os
from pathlib import Path

import psycopg2

EXPECTED_COLUMNS = {
    "source_row",
    "display_name",
    "network_evidence",
    "model",
    "firmware_source_raw",
    "firmware_state",
    "lor_uid_or_address_evidence",
    "controller_type",
    "stage_scene_evidence",
    "park_location",
    "grouping_note",
    "v7_match_state",
    "v7_match_type",
    "v7_match_count",
}

DEFAULT_SOURCE_NAME = "Controller Inventory & Testing 2026(7).xlsx"
DEFAULT_EXPECTED_ROWS = 177


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("csv_path", type=Path)
    parser.add_argument(
        "--source-name",
        default=DEFAULT_SOURCE_NAME,
        help="Original workbook/source name recorded in stage evidence",
    )
    parser.add_argument(
        "--expected-rows",
        type=int,
        default=DEFAULT_EXPECTED_ROWS,
        help="Safety count for the initial deployed-controller bootstrap",
    )
    parser.add_argument(
        "--dsn",
        default=os.environ.get("CONTROLLER_DATABASE_DSN", ""),
        help="PostgreSQL DSN; defaults to CONTROLLER_DATABASE_DSN",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Write stage.controller_bootstrap; without this flag validation only",
    )
    return parser.parse_args()


def read_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        fields = set(reader.fieldnames or [])
        missing = sorted(EXPECTED_COLUMNS - fields)
        if missing:
            raise SystemExit(f"CSV is missing required columns: {', '.join(missing)}")
        rows = list(reader)
    return rows


def validate_rows(rows: list[dict[str, str]], expected_rows: int) -> None:
    if len(rows) != expected_rows:
        raise SystemExit(
            f"Expected {expected_rows} deployed-controller rows; found {len(rows)}"
        )

    source_rows: set[int] = set()
    recorded = 0
    verify = 0
    matched = 0
    review = 0

    for row in rows:
        try:
            source_row = int(row["source_row"])
        except (TypeError, ValueError) as exc:
            raise SystemExit(f"Invalid source_row: {row.get('source_row')!r}") from exc

        if source_row in source_rows:
            raise SystemExit(f"Duplicate source_row {source_row}")
        source_rows.add(source_row)

        if not row["display_name"].strip():
            raise SystemExit(f"Row {source_row} has blank display_name")
        if not row["model"].strip():
            raise SystemExit(f"Row {source_row} has blank model")

        firmware_state = row["firmware_state"].strip()
        if firmware_state == "RECORDED":
            recorded += 1
        elif firmware_state == "UNKNOWN_OR_VERIFY":
            verify += 1
        else:
            raise SystemExit(
                f"Row {source_row} has unsupported firmware_state {firmware_state!r}"
            )

        if row["v7_match_state"].strip() == "MATCHED":
            matched += 1
        else:
            review += 1

    print(f"rows={len(rows)}")
    print(f"firmware_recorded={recorded}")
    print(f"firmware_unknown_or_verify={verify}")
    print(f"v7_matched={matched}")
    print(f"v7_review_required={review}")


def apply_rows(
    rows: list[dict[str, str]], *, dsn: str, source_name: str
) -> None:
    if not dsn.strip():
        raise SystemExit("A PostgreSQL DSN is required for --apply")

    sql = """
        INSERT INTO stage.controller_bootstrap (
            source_file,
            source_row_num,
            display_name_evidence,
            network_evidence,
            uid_evidence,
            model_evidence,
            firmware_evidence,
            firmware_state_evidence,
            controller_type_evidence,
            stage_scene_evidence,
            park_location_evidence,
            for_what_evidence,
            v7_match_state,
            v7_match_type,
            v7_match_count
        ) VALUES (
            %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
        )
        ON CONFLICT (source_file, source_row_num)
        DO UPDATE SET
            display_name_evidence = EXCLUDED.display_name_evidence,
            network_evidence = EXCLUDED.network_evidence,
            uid_evidence = EXCLUDED.uid_evidence,
            model_evidence = EXCLUDED.model_evidence,
            firmware_evidence = EXCLUDED.firmware_evidence,
            firmware_state_evidence = EXCLUDED.firmware_state_evidence,
            controller_type_evidence = EXCLUDED.controller_type_evidence,
            stage_scene_evidence = EXCLUDED.stage_scene_evidence,
            park_location_evidence = EXCLUDED.park_location_evidence,
            for_what_evidence = EXCLUDED.for_what_evidence,
            v7_match_state = EXCLUDED.v7_match_state,
            v7_match_type = EXCLUDED.v7_match_type,
            v7_match_count = EXCLUDED.v7_match_count
    """

    with psycopg2.connect(dsn) as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT to_regclass('stage.controller_bootstrap')")
            if cur.fetchone()[0] is None:
                raise SystemExit(
                    "stage.controller_bootstrap does not exist; run database script 001 first"
                )

            for row in rows:
                match_count = row["v7_match_count"].strip()
                cur.execute(
                    sql,
                    (
                        source_name,
                        int(row["source_row"]),
                        row["display_name"].strip(),
                        row["network_evidence"].strip() or None,
                        row["lor_uid_or_address_evidence"].strip() or None,
                        row["model"].strip(),
                        row["firmware_source_raw"].strip() or None,
                        row["firmware_state"].strip(),
                        row["controller_type"].strip() or None,
                        row["stage_scene_evidence"].strip() or None,
                        row["park_location"].strip() or None,
                        row["grouping_note"].strip() or None,
                        row["v7_match_state"].strip() or None,
                        row["v7_match_type"].strip() or None,
                        int(match_count) if match_count else None,
                    ),
                )

        conn.commit()

    print(f"applied={len(rows)} staging rows")
    print("permanent_controller_ids_allocated=0")


def main() -> None:
    args = parse_args()
    rows = read_rows(args.csv_path)
    validate_rows(rows, args.expected_rows)

    if not args.apply:
        print("mode=VALIDATE_ONLY")
        print("database_writes=0")
        return

    print("mode=APPLY_STAGE_ONLY")
    apply_rows(rows, dsn=args.dsn, source_name=args.source_name)


if __name__ == "__main__":
    main()
