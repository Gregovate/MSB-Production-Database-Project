#!/usr/bin/env python3
"""
Add the missing Procedures and Photos folder structures to existing MSB
Stage, Substage, and Scene folders.

Safety rules
------------
- Dry-run is the default.
- Existing folders and files are never renamed, moved, overwritten, or deleted.
- Scene folders are never invented. A Scene is changed only when an existing
  folder can be matched to a Scene recorded in the LOR SQLite database.
- Unmatched database Scenes are reported for review.
- Existing Wiring folders are not inspected or modified.
- Child display folders are not modified.

Standard structure
------------------
Procedures/
    Setup/
    Takedown/
    Maintenance/
    Operations/
    SourceDocs/
Photos/
    Current/
    Setup/
    Takedown/
    Reference/
    Historical/
"""

from __future__ import annotations

import argparse
import csv
import re
import sqlite3
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable


DEFAULT_ROOT = Path(r"G:\Shared drives\Display Folders")
DEFAULT_DB = Path(r"G:\Shared drives\MSB Database\database\lor_output_v7_scene.db")

STANDARD_RELATIVE_PATHS = (
    Path("Procedures/Setup"),
    Path("Procedures/Takedown"),
    Path("Procedures/Maintenance"),
    Path("Procedures/Operations"),
    Path("Procedures/SourceDocs"),
    Path("Photos/Current"),
    Path("Photos/Setup"),
    Path("Photos/Takedown"),
    Path("Photos/Reference"),
    Path("Photos/Historical"),
)

# Examples:
#   05-Festive Trees-FT
#   07a-Who Forest-WF
STAGE_FOLDER_RE = re.compile(
    r"^(?P<stage_id>\d{2}[A-Za-z]?)-.+-(?P<prefix>[A-Za-z0-9]+)$"
)


@dataclass(frozen=True)
class Target:
    kind: str
    stage_id: str
    scene_name: str | None
    path: Path


def normalized_name(value: str) -> str:
    """Normalize only for matching; never rename folders."""
    return re.sub(r"[^a-z0-9]+", "", value.casefold())


def quote_identifier(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def get_table_columns(conn: sqlite3.Connection, table: str) -> set[str]:
    rows = conn.execute(f"PRAGMA table_info({quote_identifier(table)})").fetchall()
    return {str(row[1]) for row in rows}


def read_scene_records(db_path: Path) -> list[tuple[str, str]]:
    """
    Return unique (StageID, SceneName) records.

    The V7 database has used Name for the Scene name. This function checks the
    schema and fails clearly rather than guessing if required fields are absent.
    """
    if not db_path.is_file():
        raise FileNotFoundError(f"LOR database not found: {db_path}")

    with sqlite3.connect(db_path) as conn:
        columns = get_table_columns(conn, "scenes")
        required = {"StageID", "Name"}
        missing = required - columns
        if missing:
            raise RuntimeError(
                "The scenes table does not contain the expected columns: "
                + ", ".join(sorted(missing))
            )

        rows = conn.execute(
            """
            SELECT DISTINCT TRIM(StageID), TRIM(Name)
            FROM scenes
            WHERE NULLIF(TRIM(StageID), '') IS NOT NULL
              AND NULLIF(TRIM(Name), '') IS NOT NULL
            ORDER BY TRIM(StageID), TRIM(Name)
            """
        ).fetchall()

    return [(str(stage_id), str(name)) for stage_id, name in rows]


def discover_stage_targets(root: Path) -> tuple[list[Target], dict[str, Path]]:
    targets: list[Target] = []
    by_stage_id: dict[str, Path] = {}

    for child in sorted(root.iterdir(), key=lambda p: p.name.casefold()):
        if not child.is_dir():
            continue

        match = STAGE_FOLDER_RE.match(child.name)
        if not match:
            continue

        stage_id = match.group("stage_id").casefold()
        targets.append(
            Target(
                kind="SUBSTAGE" if stage_id[-1:].isalpha() else "STAGE",
                stage_id=stage_id,
                scene_name=None,
                path=child,
            )
        )
        by_stage_id[stage_id] = child

    return targets, by_stage_id


def find_existing_scene_folder(stage_path: Path, scene_name: str) -> Path | None:
    """
    Find an existing Scene folder below its Stage.

    Reserved documentation folders are excluded. Matching is case-insensitive
    and punctuation-insensitive. Exactly one match is required.
    """
    reserved = {"wiring", "procedures", "photos"}
    wanted = normalized_name(scene_name)
    matches: list[Path] = []

    for candidate in stage_path.rglob("*"):
        if not candidate.is_dir():
            continue

        relative_parts = {
            part.casefold() for part in candidate.relative_to(stage_path).parts
        }
        if relative_parts & reserved:
            continue

        if normalized_name(candidate.name) == wanted:
            matches.append(candidate)

    if len(matches) == 1:
        return matches[0]

    return None


def discover_scene_targets(
    scene_records: Iterable[tuple[str, str]],
    stage_paths: dict[str, Path],
) -> tuple[list[Target], list[tuple[str, str, str]]]:
    targets: list[Target] = []
    review: list[tuple[str, str, str]] = []
    seen_paths: set[Path] = set()

    for raw_stage_id, scene_name in scene_records:
        stage_id = raw_stage_id.casefold()
        stage_path = stage_paths.get(stage_id)

        if stage_path is None:
            review.append((raw_stage_id, scene_name, "No matching Stage folder"))
            continue

        # A Stage-identifying Scene may have the same name as the Stage itself.
        # The Stage target already receives the standard structure.
        if normalized_name(scene_name) == normalized_name(stage_path.name):
            continue

        scene_path = find_existing_scene_folder(stage_path, scene_name)
        if scene_path is None:
            review.append(
                (
                    raw_stage_id,
                    scene_name,
                    "No unique existing Scene folder match; nothing created",
                )
            )
            continue

        resolved = scene_path.resolve()
        if resolved in seen_paths:
            continue

        seen_paths.add(resolved)
        targets.append(
            Target(
                kind="SCENE",
                stage_id=stage_id,
                scene_name=scene_name,
                path=scene_path,
            )
        )

    return targets, review


def apply_structure(
    targets: Iterable[Target],
    apply_changes: bool,
) -> list[dict[str, str]]:
    actions: list[dict[str, str]] = []

    for target in sorted(targets, key=lambda t: str(t.path).casefold()):
        for relative in STANDARD_RELATIVE_PATHS:
            destination = target.path / relative
            exists = destination.is_dir()

            if not exists and apply_changes:
                destination.mkdir(parents=True, exist_ok=True)

            actions.append(
                {
                    "target_type": target.kind,
                    "stage_id": target.stage_id,
                    "scene_name": target.scene_name or "",
                    "target_folder": str(target.path),
                    "relative_folder": str(relative),
                    "action": "EXISTS" if exists else ("CREATED" if apply_changes else "WOULD_CREATE"),
                }
            )

    return actions


def write_csv(path: Path, rows: list[dict[str, str]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Add missing Procedures and Photos structures to existing "
            "MSB Stage, Substage, and Scene folders."
        )
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=DEFAULT_ROOT,
        help=f"Display Folders root. Default: {DEFAULT_ROOT}",
    )
    parser.add_argument(
        "--db",
        type=Path,
        default=DEFAULT_DB,
        help=f"V7 LOR SQLite database. Default: {DEFAULT_DB}",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Create missing folders. Without this switch, the script is dry-run only.",
    )
    parser.add_argument(
        "--log-dir",
        type=Path,
        default=None,
        help="Directory for CSV logs. Default: <root>/_Folder_Structure_Logs",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root: Path = args.root
    db_path: Path = args.db
    apply_changes: bool = args.apply
    log_dir: Path = args.log_dir or (root / "_Folder_Structure_Logs")

    if not root.is_dir():
        print(f"[ERROR] Display Folders root not found: {root}", file=sys.stderr)
        return 2

    try:
        scene_records = read_scene_records(db_path)
    except (FileNotFoundError, RuntimeError, sqlite3.Error) as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 3

    stage_targets, stage_paths = discover_stage_targets(root)
    scene_targets, review = discover_scene_targets(scene_records, stage_paths)
    all_targets = stage_targets + scene_targets

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    actions = apply_structure(all_targets, apply_changes)

    action_log = log_dir / f"folder-structure-actions-{timestamp}.csv"
    review_log = log_dir / f"folder-structure-review-{timestamp}.csv"

    write_csv(
        action_log,
        actions,
        [
            "target_type",
            "stage_id",
            "scene_name",
            "target_folder",
            "relative_folder",
            "action",
        ],
    )

    write_csv(
        review_log,
        [
            {"stage_id": stage_id, "scene_name": scene, "reason": reason}
            for stage_id, scene, reason in review
        ],
        ["stage_id", "scene_name", "reason"],
    )

    created_or_planned = sum(
        row["action"] in {"CREATED", "WOULD_CREATE"} for row in actions
    )
    existing = sum(row["action"] == "EXISTS" for row in actions)

    mode = "APPLY" if apply_changes else "DRY RUN"
    print(f"[{mode}] Root: {root}")
    print(f"[{mode}] Scope: Procedures and Photos only; Wiring is untouched")
    print(f"[{mode}] Database: {db_path}")
    print(f"[{mode}] Stage/Substage targets: {len(stage_targets)}")
    print(f"[{mode}] Existing Scene targets matched: {len(scene_targets)}")
    print(f"[{mode}] Existing standard folders: {existing}")
    print(f"[{mode}] Missing folders {'created' if apply_changes else 'that would be created'}: {created_or_planned}")
    print(f"[{mode}] Scene records requiring review: {len(review)}")
    print(f"[INFO] Action log: {action_log}")
    print(f"[INFO] Review log: {review_log}")

    if not apply_changes:
        print("[INFO] No folders were changed. Re-run with --apply after reviewing the CSV logs.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
