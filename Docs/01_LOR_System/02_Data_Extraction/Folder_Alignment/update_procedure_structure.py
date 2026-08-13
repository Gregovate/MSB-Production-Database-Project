#!/usr/bin/env python3
"""Align Procedures helper folders at existing Stage/Sub-stage/Scene scopes.

Authorized behavior only:
- create the complete current Procedures structure when missing;
- create Procedures/Inspection when missing;
- create Procedures/Setup/{Archive,images,SourceDocs} when missing;
- create Procedures/Takedown/{Archive,images,SourceDocs} when missing;
- delete Procedures/Maintenance only when empty;
- delete Procedures/Operations only when empty.

Safety rules:
- existing Archive folders and their contents are never modified;
- no files are moved, renamed, deleted, or overwritten;
- non-empty Maintenance/Operations folders are preserved;
- only already-resolved Stage/Sub-stage/Scene scope folders are eligible;
- Display folders are never touched.

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
VERSION = "V1.1.0"


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


def ensure_dir(target, path: Path, do_apply: bool) -> Result:
    """Ensure one authorized directory exists without replacing anything."""
    if path.exists():
        if path.is_dir():
            return result(target, path, "CREATE", "ALREADY_EXISTS", "Folder already exists; contents left untouched.")
        return result(target, path, "CREATE", "ERROR_NAME_CONFLICT",
                      "A non-folder item exists at this path; no write attempted.")

    parent = path.parent
    if not parent.is_dir():
        return result(target, path, "CREATE", "SKIPPED_PARENT_MISSING",
                      f"Parent does not yet exist: {parent}")

    if not do_apply:
        return result(target, path, "CREATE", "WOULD_CREATE", "Dry-run only; folder was not created.")

    try:
        path.mkdir(parents=False, exist_ok=False)
        return result(target, path, "CREATE", "CREATED", "Folder created.")
    except FileExistsError:
        return result(target, path, "CREATE", "ALREADY_EXISTS", "Folder appeared during execution; contents left untouched.")
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
    if not scope.is_dir():
        return [result(target, scope, "VALIDATE", "SKIPPED_SCOPE_MISSING",
                       "Resolved scope no longer exists; no write attempted.")]

    rows: list[Result] = []
    procedures = scope / "Procedures"

    # Build the complete current procedure contract in dependency order.
    required = [
        procedures,
        procedures / "Inspection",
        procedures / "Setup",
        procedures / "Setup" / "Archive",
        procedures / "Setup" / "images",
        procedures / "Setup" / "SourceDocs",
        procedures / "Takedown",
        procedures / "Takedown" / "Archive",
        procedures / "Takedown" / "images",
        procedures / "Takedown" / "SourceDocs",
    ]

    # In dry-run mode a missing parent is still reported as WOULD_CREATE in the
    # planned hierarchy, even though it is not physically present yet.
    if not do_apply:
        planned = {scope}
        for path in required:
            if path.exists():
                if path.is_dir():
                    rows.append(result(target, path, "CREATE", "ALREADY_EXISTS",
                                       "Folder already exists; contents left untouched."))
                    planned.add(path)
                else:
                    rows.append(result(target, path, "CREATE", "ERROR_NAME_CONFLICT",
                                       "A non-folder item exists at this path; no write attempted."))
            elif path.parent in planned or path.parent.is_dir():
                rows.append(result(target, path, "CREATE", "WOULD_CREATE",
                                   "Dry-run only; folder was not created."))
                planned.add(path)
            else:
                rows.append(result(target, path, "CREATE", "SKIPPED_PARENT_MISSING",
                                   f"Parent cannot be resolved in planned hierarchy: {path.parent}"))
    else:
        for path in required:
            rows.append(ensure_dir(target, path, True))

    # Only inspect/delete legacy folders if Procedures exists now (apply) or
    # already existed before the dry-run. A newly planned Procedures tree cannot
    # contain legacy folders.
    if procedures.is_dir():
        rows.append(remove_if_empty(target, procedures / "Maintenance", do_apply))
        rows.append(remove_if_empty(target, procedures / "Operations", do_apply))
    else:
        rows.append(result(target, procedures / "Maintenance", "DELETE_EMPTY", "NOT_PRESENT",
                           "Procedures did not exist; legacy Maintenance cannot be present."))
        rows.append(result(target, procedures / "Operations", "DELETE_EMPTY", "NOT_PRESENT",
                           "Procedures did not exist; legacy Operations cannot be present."))

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
        print("[INFO] Apply completed. Existing Archive contents were untouched. Non-empty Maintenance/Operations folders were preserved.")
    else:
        print("[INFO] Dry-run completed. Review WOULD_CREATE and WOULD_DELETE_EMPTY before using --apply.")

    return 1 if any(r.status in {"ERROR", "ERROR_NAME_CONFLICT"} for r in rows) else 0


if __name__ == "__main__":
    raise SystemExit(main())
