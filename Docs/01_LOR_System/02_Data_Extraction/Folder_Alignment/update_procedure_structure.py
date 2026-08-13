#!/usr/bin/env python3
"""Align Procedures helper folders at existing Stage/Sub-stage/Scene scopes.

Authorized behavior only:
- create Procedures/Inspection when missing;
- create Procedures/Setup/images and Procedures/Setup/SourceDocs when missing;
- create Procedures/Takedown/images and Procedures/Takedown/SourceDocs when missing;
- delete Procedures/Maintenance only when empty;
- delete Procedures/Operations only when empty.

Explicitly NOT authorized:
- touching any Archive folder or its contents;
- creating Procedures, Setup, or Takedown parent folders;
- moving, renaming, or deleting non-empty folders/files;
- operating on Display folders.

Default mode is dry-run. Pass --apply only after reviewing the proposed changes.
"""
from __future__ import annotations

import argparse
import csv
import sqlite3
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

import update_previewbackground_folders as scope_source

base = scope_source.base
VERSION = "V1.0.0"


@dataclass(frozen=True)
class Result:
    scope_type: str
    stage_id: str
    scope_name: str
    scope_path: str
    target_path: str
    action: str
    status: str
    message: str


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Dry-run or align Procedures structure at existing Stage/Sub-stage/Scene roots.")
    p.add_argument("--db", type=Path, default=base.DEFAULT_DB)
    p.add_argument("--drive-root", type=Path, default=base.DEFAULT_ROOT)
    p.add_argument("--output-dir", type=Path, default=base.DEFAULT_OUTPUT)
    p.add_argument("--apply", action="store_true")
    return p.parse_args()


def result(target, path: Path, action: str, status: str, message: str) -> Result:
    return Result(target.scope_type, target.stage_id, target.scope_name,
                  str(target.scope_path), str(path), action, status, message)


def ensure_child(target, parent: Path, name: str, do_apply: bool) -> Result:
    path = parent / name
    if not parent.is_dir():
        return result(target, path, "CREATE", "SKIPPED_PARENT_MISSING",
                      f"Required existing parent is missing: {parent}")
    if path.exists():
        if path.is_dir():
            return result(target, path, "CREATE", "ALREADY_EXISTS", f"{name} already exists.")
        return result(target, path, "CREATE", "ERROR_NAME_CONFLICT",
                      f"A non-folder item named {name} already exists; no write attempted.")
    if not do_apply:
        return result(target, path, "CREATE", "WOULD_CREATE", "Dry-run only; folder was not created.")
    try:
        path.mkdir(parents=False, exist_ok=False)
        return result(target, path, "CREATE", "CREATED", f"Created {name}.")
    except FileExistsError:
        return result(target, path, "CREATE", "ALREADY_EXISTS", f"{name} appeared during execution.")
    except OSError as exc:
        return result(target, path, "CREATE", "ERROR", f"Could not create folder: {exc}")


def remove_if_empty(target, path: Path, do_apply: bool) -> Result:
    if not path.exists():
        return result(target, path, "DELETE_EMPTY", "NOT_PRESENT", "Legacy folder is not present.")
    if not path.is_dir():
        return result(target, path, "DELETE_EMPTY", "ERROR_NAME_CONFLICT",
                      "Legacy name exists but is not a folder; no write attempted.")
    try:
        if any(path.iterdir()):
            return result(target, path, "DELETE_EMPTY", "KEPT_NONEMPTY",
                          "Legacy folder contains one or more items and was left untouched.")
    except OSError as exc:
        return result(target, path, "DELETE_EMPTY", "ERROR", f"Could not inspect folder: {exc}")
    if not do_apply:
        return result(target, path, "DELETE_EMPTY", "WOULD_DELETE_EMPTY",
                      "Dry-run only; empty legacy folder was not deleted.")
    try:
        path.rmdir()
        return result(target, path, "DELETE_EMPTY", "DELETED_EMPTY", "Deleted empty legacy folder.")
    except OSError as exc:
        return result(target, path, "DELETE_EMPTY", "ERROR", f"Could not delete empty folder: {exc}")


def process_scope(target, do_apply: bool) -> list[Result]:
    scope = target.scope_path
    procedures = scope / "Procedures"
    if not procedures.is_dir():
        return [result(target, procedures, "VALIDATE", "SKIPPED_PROCEDURES_MISSING",
                       "Procedures folder is missing; parent creation was not authorized.")]

    rows: list[Result] = []
    rows.append(ensure_child(target, procedures, "Inspection", do_apply))

    setup = procedures / "Setup"
    rows.append(ensure_child(target, setup, "images", do_apply))
    rows.append(ensure_child(target, setup, "SourceDocs", do_apply))

    takedown = procedures / "Takedown"
    rows.append(ensure_child(target, takedown, "images", do_apply))
    rows.append(ensure_child(target, takedown, "SourceDocs", do_apply))

    # Archive is deliberately never inspected, created, moved, renamed, or deleted.
    rows.append(remove_if_empty(target, procedures / "Maintenance", do_apply))
    rows.append(remove_if_empty(target, procedures / "Operations", do_apply))
    return rows


def write_csv(output_dir: Path, rows: list[Result], mode: str) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    path = output_dir / f"procedure-structure-update-{mode}-{stamp}.csv"
    fields = ["scope_type", "stage_id", "scope_name", "scope_path", "target_path", "action", "status", "message"]
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for row in rows:
            w.writerow({name: getattr(row, name) for name in fields})
    return path


def main() -> int:
    args = parse_args()
    print(f"[INFO] Procedures structure updater {VERSION}")
    print(f"[INFO] Mode: {'APPLY' if args.apply else 'DRY-RUN'}")
    print(f"[INFO] SQLite: {args.db}")
    print(f"[INFO] Drive root: {args.drive_root}")

    if not args.db.is_file():
        print(f"[ERROR] SQLite database not found: {args.db}")
        return 2
    if not args.drive_root.is_dir():
        print(f"[ERROR] Display Folders root not found: {args.drive_root}")
        return 3

    try:
        with sqlite3.connect(args.db) as conn:
            _previews, _scenes, _displays, scene_infos, _provenance = base.load_expected(conn)
    except Exception as exc:
        print(f"[ERROR] Could not load current V7 parser snapshot: {exc}")
        return 4

    structured, preliminary = scope_source.collect_structured_scope_targets(args.drive_root, scene_infos)
    # Procedure migration is only for structured scopes. No Display folders.
    targets = sorted(structured, key=lambda x: (x.stage_id, x.scope_type, scope_source.canonical(x.scope_path)))
    rows: list[Result] = []

    for note in preliminary:
        rows.append(Result(note.scope_type, note.stage_id, note.scope_name, note.scope_path,
                           note.previewbackground_path, "VALIDATE", note.status, note.message))

    print(f"[INFO] Existing eligible Stage/Sub-stage/Scene scopes: {len(targets)}")
    for target in targets:
        for row in process_scope(target, args.apply):
            rows.append(row)
            print(f"[{row.status}] {row.scope_type} Stage={row.stage_id or '--'} {row.target_path}")

    mode = "apply" if args.apply else "dry-run"
    try:
        csv_path = write_csv(args.output_dir, rows, mode)
        print(f"[INFO] Audit log: {csv_path}")
    except OSError as exc:
        print(f"[WARN] Could not write CSV audit log: {exc}")

    counts: dict[str, int] = {}
    for row in rows:
        counts[row.status] = counts.get(row.status, 0) + 1
    print("[INFO] Summary:")
    for status in sorted(counts):
        print(f"[INFO]   {status}: {counts[status]}")

    if args.apply:
        print("[INFO] Apply completed. Archive folders were not touched. Non-empty Maintenance/Operations folders were preserved.")
    else:
        print("[INFO] Dry-run completed. Review WOULD_CREATE and WOULD_DELETE_EMPTY before using --apply.")

    return 1 if any(r.status in {"ERROR", "ERROR_NAME_CONFLICT"} for r in rows) else 0


if __name__ == "__main__":
    raise SystemExit(main())
