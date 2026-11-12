#!/usr/bin/env python3
"""Create missing PreviewBackground folders at existing MSB Drive scopes.

This utility is intentionally narrow and additive-only.

It may create:
    <existing Stage>/PreviewBackground
    <existing Sub-stage>/PreviewBackground
    <existing Scene>/PreviewBackground
    <existing Display>/PreviewBackground

It will NOT create Stage, Sub-stage, Scene, or Display folders and will never
move, rename, delete, or overwrite files/folders.

Default mode is dry-run. Pass --apply to create missing PreviewBackground
folders after reviewing the proposed changes.
"""
from __future__ import annotations

import argparse
import csv
import os
import sqlite3
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

import generate_folder_alignment_report_v1_3_6 as alignment

base = alignment.base
VERSION = "V1.0.0"
PREVIEW_BACKGROUND = "PreviewBackground"

# Never descend into application/helper trees when looking for existing Display
# folders. The updater is locating scope folders, not documentation folders.
PRUNE_SCOPE_SEARCH = {
    "previewbackground",
    "photos",
    "procedures",
    "wiring",
    "000instructions",
    "archive",
    "archives",
    "historical",
    "sourcedocs",
}


@dataclass(frozen=True)
class ScopeTarget:
    scope_type: str
    stage_id: str
    scope_name: str
    scope_path: Path
    evidence: str


@dataclass(frozen=True)
class Result:
    scope_type: str
    stage_id: str
    scope_name: str
    scope_path: str
    previewbackground_path: str
    evidence: str
    status: str
    message: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Dry-run or add missing PreviewBackground folders to existing "
            "Stage, Sub-stage, Scene, and Display folders."
        )
    )
    parser.add_argument("--db", type=Path, default=base.DEFAULT_DB,
                        help=f"V7 parser SQLite snapshot (default: {base.DEFAULT_DB})")
    parser.add_argument("--drive-root", type=Path, default=base.DEFAULT_ROOT,
                        help=f"Display Folders root (default: {base.DEFAULT_ROOT})")
    parser.add_argument("--output-dir", type=Path, default=base.DEFAULT_OUTPUT,
                        help="Folder for the updater CSV audit log")
    parser.add_argument("--apply", action="store_true",
                        help="Create missing PreviewBackground folders. Without this flag, dry-run only.")
    return parser.parse_args()


def canonical(path: Path) -> str:
    try:
        return str(path.resolve()).casefold()
    except OSError:
        return str(path).casefold()


def unique_top_stage(stage_folders: dict[str, list[Path]], stage_id: str) -> Path | None:
    sid = alignment._numeric_stage(stage_id)
    matches = stage_folders.get(sid, [])
    return matches[0] if len(matches) == 1 else None


def collect_structured_scope_targets(root: Path, scene_infos) -> tuple[list[ScopeTarget], list[Result]]:
    """Collect existing Stage/Sub-stage/Scene roots from deterministic V1.3.6 logic."""
    stage_folders, _by_name, _candidates, _direct = base.inventory_drive(root)
    targets: dict[str, ScopeTarget] = {}
    results: list[Result] = []

    # Every unique existing top-level Stage is always a target.
    for sid, matches in sorted(stage_folders.items()):
        if len(matches) != 1:
            results.append(Result(
                "STAGE", sid, "", "", "", "Drive top-level Stage scan",
                "SKIPPED_AMBIGUOUS",
                f"Expected one Stage folder for {sid}; found {len(matches)}. No write attempted.",
            ))
            continue
        stage = matches[0]
        targets[canonical(stage)] = ScopeTarget(
            "STAGE", sid, stage.name, stage, "Existing top-level Stage folder"
        )

    # Use the current deterministic Scene contract in
    # Folder Alignment. Only existing resolved folders are eligible for writes.
    for info in scene_infos:
        row = alignment._make_scope_row(info, stage_folders)
        if row.classification == "DISPLAY_OR_GROUP":
            continue
        if row.resolved_path is None or not row.resolved_path.is_dir():
            continue

        if row.classification in {"STAGE_ROOT", "STAGE_ROOT_MARKER"}:
            scope_type = "STAGE"
        elif row.classification == "SUB_STAGE_ROOT":
            scope_type = "SUB_STAGE"
        else:
            scope_type = "SCENE"

        key = canonical(row.resolved_path)
        targets[key] = ScopeTarget(
            scope_type,
            row.stage_id,
            row.resolved_path.name,
            row.resolved_path,
            f"{row.classification}; {row.resolution}",
        )

    return sorted(targets.values(), key=lambda x: canonical(x.scope_path)), results


def walk_scope_candidates(stage: Path):
    """Yield existing folders under a Stage while pruning helper/documentation trees."""
    for current, dirs, _files in os.walk(stage):
        current_path = Path(current)

        kept = []
        for d in dirs:
            if base.norm(d) in PRUNE_SCOPE_SEARCH:
                continue
            kept.append(d)
        dirs[:] = kept

        if current_path != stage:
            yield current_path


def display_compare_form(value: str) -> str:
    return base.compare_form(value, "DISPLAY")


def collect_display_targets(root: Path, displays, structured_targets: list[ScopeTarget]) -> tuple[list[ScopeTarget], list[Result]]:
    """Resolve only existing Display folders by unique exact normalized name match.

    No Display folder is ever created. If zero or multiple candidate folders match,
    the Display is skipped and recorded for review.
    """
    structured_paths = {canonical(t.scope_path) for t in structured_targets}
    stage_folders, _by_name, _candidates, _direct = base.inventory_drive(root)
    targets: dict[str, ScopeTarget] = {}
    results: list[Result] = []

    # Cache scope candidates per numeric Stage to avoid repeated Drive walks.
    candidate_cache: dict[str, list[Path]] = {}

    for display in displays:
        sid = alignment._numeric_stage(display.stage_id)
        if not sid:
            continue
        stage = unique_top_stage(stage_folders, sid)
        if stage is None:
            continue

        if sid not in candidate_cache:
            candidate_cache[sid] = list(walk_scope_candidates(stage))

        wanted_raw = base.norm(display.name)
        wanted_display = display_compare_form(display.name)
        matches: list[tuple[Path, str]] = []

        for candidate in candidate_cache[sid]:
            ckey = canonical(candidate)
            if ckey in structured_paths:
                continue

            # First preference: literal normalized folder/display name equality.
            if base.norm(candidate.name) == wanted_raw:
                matches.append((candidate, "Exact normalized Display/folder name"))
                continue

            # Compatibility with existing Display names that carry a two-letter
            # LOR prefix while the Drive folder omits it. Still requires exact
            # normalized equality after the established DISPLAY transform.
            if display_compare_form(candidate.name) == wanted_display:
                matches.append((candidate, "Exact normalized Display form"))

        # Deduplicate in case both comparison forms matched the same folder.
        unique_matches: dict[str, tuple[Path, str]] = {}
        for path, reason in matches:
            unique_matches[canonical(path)] = (path, reason)
        matches = list(unique_matches.values())

        if len(matches) == 1:
            path, reason = matches[0]
            targets[canonical(path)] = ScopeTarget(
                "DISPLAY", sid, display.name, path, reason
            )
        elif len(matches) > 1:
            results.append(Result(
                "DISPLAY", sid, display.name, "", "",
                "Current parser Display identity",
                "SKIPPED_AMBIGUOUS",
                "Multiple existing folders matched this Display: "
                + "; ".join(str(p) for p, _r in matches),
            ))
        # Zero matches are intentionally silent. A missing Display folder is not
        # an error and this utility must never create one.

    return sorted(targets.values(), key=lambda x: canonical(x.scope_path)), results


def apply_target(target: ScopeTarget, do_apply: bool) -> Result:
    scope = target.scope_path
    pb = scope / PREVIEW_BACKGROUND

    if not scope.is_dir():
        return Result(
            target.scope_type, target.stage_id, target.scope_name,
            str(scope), str(pb), target.evidence,
            "SKIPPED_SCOPE_MISSING", "Scope folder no longer exists; no write attempted.",
        )

    if pb.exists():
        if pb.is_dir():
            status = "ALREADY_EXISTS"
            message = "PreviewBackground already exists."
        else:
            status = "ERROR_NAME_CONFLICT"
            message = "A non-folder item named PreviewBackground already exists; no write attempted."
        return Result(
            target.scope_type, target.stage_id, target.scope_name,
            str(scope), str(pb), target.evidence, status, message,
        )

    if not do_apply:
        return Result(
            target.scope_type, target.stage_id, target.scope_name,
            str(scope), str(pb), target.evidence,
            "WOULD_CREATE", "Dry-run only; folder was not created.",
        )

    try:
        # Parent scope must already exist. parents=False is deliberate.
        pb.mkdir(parents=False, exist_ok=False)
        return Result(
            target.scope_type, target.stage_id, target.scope_name,
            str(scope), str(pb), target.evidence,
            "CREATED", "PreviewBackground created.",
        )
    except FileExistsError:
        return Result(
            target.scope_type, target.stage_id, target.scope_name,
            str(scope), str(pb), target.evidence,
            "ALREADY_EXISTS", "PreviewBackground appeared during execution; treated as existing.",
        )
    except OSError as exc:
        return Result(
            target.scope_type, target.stage_id, target.scope_name,
            str(scope), str(pb), target.evidence,
            "ERROR", f"Could not create PreviewBackground: {exc}",
        )


def write_csv(output_dir: Path, results: list[Result], mode: str) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    path = output_dir / f"previewbackground-update-{mode}-{stamp}.csv"
    fields = [
        "scope_type", "stage_id", "scope_name", "scope_path",
        "previewbackground_path", "evidence", "status", "message",
    ]
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        for row in results:
            writer.writerow({name: getattr(row, name) for name in fields})
    return path


def main() -> int:
    args = parse_args()
    db = args.db
    root = args.drive_root
    output = args.output_dir

    print(f"[INFO] PreviewBackground updater {VERSION}")
    print(f"[INFO] Mode: {'APPLY' if args.apply else 'DRY-RUN'}")
    print(f"[INFO] SQLite: {db}")
    print(f"[INFO] Drive root: {root}")

    if not db.is_file():
        print(f"[ERROR] SQLite database not found: {db}")
        return 2
    if not root.is_dir():
        print(f"[ERROR] Display Folders root not found: {root}")
        return 3

    try:
        with sqlite3.connect(db) as conn:
            _previews, _scenes, displays, scene_infos, _provenance = base.load_expected(conn)
    except Exception as exc:
        print(f"[ERROR] Could not load current V7 parser snapshot: {exc}")
        return 4

    structured, preliminary = collect_structured_scope_targets(root, scene_infos)
    display_targets, display_notes = collect_display_targets(root, displays, structured)

    targets_by_path: dict[str, ScopeTarget] = {}
    for target in structured + display_targets:
        targets_by_path[canonical(target.scope_path)] = target

    targets = sorted(targets_by_path.values(), key=lambda x: (x.stage_id, x.scope_type, canonical(x.scope_path)))
    results = preliminary + display_notes

    print(f"[INFO] Existing eligible scopes resolved: {len(targets)}")
    print(f"[INFO]   Structured Stage/Sub-stage/Scene scopes: {len(structured)}")
    print(f"[INFO]   Existing Display folders resolved: {len(display_targets)}")

    for target in targets:
        result = apply_target(target, args.apply)
        results.append(result)
        print(
            f"[{result.status}] {result.scope_type} "
            f"Stage={result.stage_id or '--'} {result.previewbackground_path}"
        )

    mode = "apply" if args.apply else "dry-run"
    try:
        csv_path = write_csv(output, results, mode)
        print(f"[INFO] Audit log: {csv_path}")
    except OSError as exc:
        print(f"[WARN] Could not write CSV audit log: {exc}")

    counts: dict[str, int] = {}
    for result in results:
        counts[result.status] = counts.get(result.status, 0) + 1

    print("[INFO] Summary:")
    for status in sorted(counts):
        print(f"[INFO]   {status}: {counts[status]}")

    if args.apply:
        print("[INFO] Apply mode completed. No files/folders were moved, renamed, deleted, or overwritten.")
    else:
        print("[INFO] Dry-run completed. Re-run with --apply only after reviewing WOULD_CREATE rows.")

    return 1 if any(r.status in {"ERROR", "ERROR_NAME_CONFLICT"} for r in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
