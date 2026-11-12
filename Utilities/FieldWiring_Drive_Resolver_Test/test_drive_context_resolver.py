#!/usr/bin/env python3
"""
Read-only V7+ FieldWiring Drive-context resolver test harness.

This tool does not modify SQLite, PostgreSQL, LOR, or Google Drive.
It validates current Scene/Preview path evidence against the mapped
Google Shared Drive hierarchy before browser implementation.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
from dataclasses import asdict, dataclass
from datetime import datetime
from pathlib import Path, PureWindowsPath

DRIVE_ROOT_DEFAULT = r"G:\Shared drives\Display Folders"
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png"}
SKIP_SEARCH_FOLDERS = {
    "wiring", "procedures", "photos", "previewbackground", "sourcedocs",
    "archive", "archived", "archived photos", "current photos",
}
DEFAULT_CASES = [
    ("MASTER", "15-Church-CH"),
    ("MASTER", "05a-Mega Star-MS"),
    ("MASTER", "03-Mega Cube-MC"),
    ("MASTER", "07-Who Characters"),
    ("MASTER", "02-Fred's Stars"),
    ("BACKGROUND15", "Root"),
]


@dataclass
class Candidate:
    label: str
    path: str
    exists: bool
    image_count: int
    images: list[str]


@dataclass
class Result:
    preview: str
    scene: str
    stage_key: str | None
    scene_background_file: str | None
    pointer_under_drive_root: bool
    exact_pointer_resolves: bool
    stage_root: str | None
    stage_root_exists: bool
    resolved_scope_type: str
    resolved_scope_root: str | None
    resolution_basis: str
    wiring_branch: str | None
    candidates: list[Candidate]
    selected_candidate: str | None
    selected_path: str | None
    warnings: list[str]
    status: str


def open_snapshot_ro(path: Path) -> sqlite3.Connection:
    uri = path.resolve().as_uri() + "?mode=ro"
    conn = sqlite3.connect(uri, uri=True)
    conn.row_factory = sqlite3.Row
    return conn


def required_tables(conn: sqlite3.Connection) -> None:
    required = {
        "lor_snap__v_current_scenes",
        "lor_snap__v_current_previews",
        "ref__stage",
    }
    actual = {
        row[0]
        for row in conn.execute(
            "SELECT name FROM sqlite_master WHERE type IN ('table','view')"
        )
    }
    missing = sorted(required - actual)
    if missing:
        raise RuntimeError(
            "Snapshot is missing required exported relations: " + ", ".join(missing)
        )


def discover_snapshot(repo_root: Path, explicit: str | None) -> Path:
    candidates: list[Path] = []
    if explicit:
        candidates.append(Path(explicit))
    env = os.environ.get("FIELDWIRING_SNAPSHOT")
    if env:
        candidates.append(Path(env))
    candidates.extend(
        [
            repo_root / "fieldwiring_snapshot.db",
            repo_root / "Utilities" / "fieldwiring_snapshot.db",
            Path(r"G:\Shared drives\MSB Database\database\fieldwiring_snapshot.db"),
        ]
    )
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    checked = "\n  - ".join(str(p) for p in candidates)
    raise FileNotFoundError(
        "fieldwiring_snapshot.db was not found. Supply -SnapshotPath or set "
        "FIELDWIRING_SNAPSHOT.\nChecked:\n  - " + checked
    )


def windows_is_under(path_text: str, root_text: str) -> bool:
    try:
        path_parts = [p.casefold() for p in PureWindowsPath(path_text).parts]
        root_parts = [p.casefold() for p in PureWindowsPath(root_text).parts]
    except Exception:
        return False
    return path_parts[: len(root_parts)] == root_parts


def canonical_scene_names(scene_name: str) -> set[str]:
    names = {scene_name.strip()}
    # Current Scene names sometimes retain a trailing two/three-letter
    # short-code suffix while the Drive folder omits it (e.g. 03-Mega Cube-MC).
    stripped = re.sub(r"-[A-Z]{2,3}$", "", scene_name.strip())
    if stripped:
        names.add(stripped)
    return {name.casefold() for name in names if name}


def bounded_matching_dirs(stage_root: Path, scene_name: str, max_depth: int = 2) -> list[Path]:
    targets = canonical_scene_names(scene_name)
    matches: list[Path] = []

    def walk(path: Path, depth: int) -> None:
        if depth > max_depth:
            return
        try:
            children = [p for p in path.iterdir() if p.is_dir()]
        except OSError:
            return
        for child in children:
            if child.name.casefold() in targets:
                matches.append(child)
            if depth < max_depth and child.name.casefold() not in SKIP_SEARCH_FOLDERS:
                walk(child, depth + 1)

    walk(stage_root, 1)
    unique: dict[str, Path] = {}
    for item in matches:
        unique[str(item).casefold()] = item
    return sorted(unique.values(), key=lambda p: str(p).casefold())


def stage_record(conn: sqlite3.Connection, stage_key: str | None) -> sqlite3.Row | None:
    if not stage_key:
        return None
    row = conn.execute(
        """
        SELECT stage_id, stage_key, stage_name, folder_name, folder_path, parent_stage_key
        FROM ref__stage
        WHERE lower(stage_key) = lower(?)
        LIMIT 1
        """,
        (stage_key,),
    ).fetchone()
    if row is not None and row["folder_path"]:
        return row

    # A formal Substage may not yet have its own persisted folder_path. The
    # physical Stage path is still a valid root anchor for deterministic
    # hierarchy walking.
    base = re.match(r"^(\d{2})", stage_key)
    if base:
        parent = conn.execute(
            """
            SELECT stage_id, stage_key, stage_name, folder_name, folder_path, parent_stage_key
            FROM ref__stage
            WHERE stage_key = ?
            LIMIT 1
            """,
            (base.group(1),),
        ).fetchone()
        if parent is not None and parent["folder_path"]:
            return parent
    return row


def derive_wiring_branch(preview_name: str, pointer: str | None) -> str | None:
    pointer_fold = (pointer or "").casefold()
    preview_fold = preview_name.casefold()
    if "musicalstage" in pointer_fold or "master musical preview" in preview_fold:
        return "MusicalStage"
    if "backgroundstage" in pointer_fold or preview_fold.startswith("show background stage"):
        return "BackgroundStage"
    return None


def direct_images(path: Path) -> list[str]:
    if not path.is_dir():
        return []
    try:
        images = [
            p.name
            for p in path.iterdir()
            if p.is_file() and p.suffix.casefold() in IMAGE_EXTENSIONS
        ]
    except OSError:
        return []
    return sorted(images, key=str.casefold)


def make_candidate(label: str, path: Path) -> Candidate:
    images = direct_images(path)
    return Candidate(
        label=label,
        path=str(path),
        exists=path.is_dir(),
        image_count=len(images),
        images=images,
    )


def select_candidate(candidates: list[Candidate]) -> Candidate | None:
    # Current operator hypothesis under test: a folder must contain at least one
    # directly published image to be considered usable.
    for candidate in candidates:
        if candidate.exists and candidate.image_count > 0:
            return candidate
    return None


def query_default_cases(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    rows: list[sqlite3.Row] = []
    for kind, scene_name in DEFAULT_CASES:
        if kind == "MASTER":
            found = conn.execute(
                """
                SELECT
                    s.scene_id,
                    s.name AS scene_name,
                    s.stage_id AS scene_stage_id,
                    s.background_file AS scene_background_file,
                    p.id AS preview_id,
                    p.name AS preview_name,
                    p.stage_id AS preview_stage_id,
                    p.background_file AS preview_background_file
                FROM lor_snap__v_current_scenes s
                JOIN lor_snap__v_current_previews p ON p.id = s.preview_id
                WHERE s.name = ?
                  AND lower(p.name) LIKE '%master musical preview%'
                ORDER BY p.name
                """,
                (scene_name,),
            ).fetchall()
        else:
            found = conn.execute(
                """
                SELECT
                    s.scene_id,
                    s.name AS scene_name,
                    s.stage_id AS scene_stage_id,
                    s.background_file AS scene_background_file,
                    p.id AS preview_id,
                    p.name AS preview_name,
                    p.stage_id AS preview_stage_id,
                    p.background_file AS preview_background_file
                FROM lor_snap__v_current_scenes s
                JOIN lor_snap__v_current_previews p ON p.id = s.preview_id
                WHERE s.name = ?
                  AND lower(p.name) LIKE 'show background stage 15 church%'
                ORDER BY p.name
                """,
                (scene_name,),
            ).fetchall()
        if len(found) != 1:
            raise RuntimeError(
                f"Acceptance case {scene_name!r} ({kind}) resolved to "
                f"{len(found)} current rows; expected exactly 1."
            )
        rows.append(found[0])
    return rows


def query_named_scenes(conn: sqlite3.Connection, names: list[str]) -> list[sqlite3.Row]:
    rows: list[sqlite3.Row] = []
    for name in names:
        found = conn.execute(
            """
            SELECT
                s.scene_id,
                s.name AS scene_name,
                s.stage_id AS scene_stage_id,
                s.background_file AS scene_background_file,
                p.id AS preview_id,
                p.name AS preview_name,
                p.stage_id AS preview_stage_id,
                p.background_file AS preview_background_file
            FROM lor_snap__v_current_scenes s
            JOIN lor_snap__v_current_previews p ON p.id = s.preview_id
            WHERE s.name = ?
            ORDER BY p.name
            """,
            (name,),
        ).fetchall()
        if not found:
            raise RuntimeError(f"Scene {name!r} was not found in the current snapshot.")
        if len(found) > 1:
            previews = ", ".join(row["preview_name"] for row in found)
            raise RuntimeError(
                f"Scene {name!r} is not unique across current previews: {previews}. "
                "Use the default acceptance set or refine the harness before accepting it."
            )
        rows.append(found[0])
    return rows


def query_all_master_scenes(conn: sqlite3.Connection) -> list[sqlite3.Row]:
    return conn.execute(
        """
        SELECT
            s.scene_id,
            s.name AS scene_name,
            s.stage_id AS scene_stage_id,
            s.background_file AS scene_background_file,
            p.id AS preview_id,
            p.name AS preview_name,
            p.stage_id AS preview_stage_id,
            p.background_file AS preview_background_file
        FROM lor_snap__v_current_scenes s
        JOIN lor_snap__v_current_previews p ON p.id = s.preview_id
        WHERE lower(p.name) LIKE '%master musical preview%'
        ORDER BY lower(s.name), s.scene_id
        """
    ).fetchall()


def resolve_one(
    conn: sqlite3.Connection,
    row: sqlite3.Row,
    drive_root: Path,
    drive_root_text: str,
) -> Result:
    preview = row["preview_name"]
    scene = row["scene_name"]
    pointer = row["scene_background_file"] or row["preview_background_file"]
    stage_key = row["scene_stage_id"] or row["preview_stage_id"]
    warnings: list[str] = []

    record = stage_record(conn, stage_key)
    stage_root = Path(record["folder_path"]) if record is not None and record["folder_path"] else None
    stage_root_exists = bool(stage_root and stage_root.is_dir())

    if stage_root is None:
        return Result(
            preview=preview, scene=scene, stage_key=stage_key,
            scene_background_file=pointer, pointer_under_drive_root=False,
            exact_pointer_resolves=False, stage_root=None, stage_root_exists=False,
            resolved_scope_type="UNRESOLVED", resolved_scope_root=None,
            resolution_basis="No current Stage folder_path anchor could be resolved.",
            wiring_branch=derive_wiring_branch(preview, pointer),
            candidates=[], selected_candidate=None, selected_path=None,
            warnings=["No current Stage folder_path anchor."], status="UNRESOLVED",
        )

    if not stage_root_exists:
        warnings.append(f"Stage root does not resolve on the mapped Drive: {stage_root}")

    pointer_under_root = bool(pointer and windows_is_under(pointer, drive_root_text))
    if pointer and not pointer_under_root:
        warnings.append("BackgroundFile pointer is not beneath the configured Display Folders root.")

    pointer_path = Path(pointer) if pointer else None
    exact_resolves = bool(pointer_path and pointer_under_root and pointer_path.is_file())

    scope_root: Path = stage_root
    scope_type = "STAGE"
    basis = "Current Production Database Stage folder_path."

    if scene.casefold() == "root":
        basis = "Scene is Root; governing rule resolves to owning Preview Stage root."
    else:
        targets = canonical_scene_names(scene)
        if exact_resolves and pointer_path is not None:
            # Search only ancestors between the pointed file and known Stage root.
            current = pointer_path.parent
            found_scope: Path | None = None
            stage_fold = str(stage_root).casefold()
            while str(current).casefold().startswith(stage_fold):
                if current.name.casefold() in targets:
                    found_scope = current
                    break
                if str(current).casefold() == stage_fold:
                    break
                current = current.parent
            if found_scope is not None:
                scope_root = found_scope
                basis = "Exact BackgroundFile resolved; matching structured Scene/Substage ancestor found."
            else:
                basis = (
                    "Exact BackgroundFile resolved within the known Stage, but no distinct "
                    "Scene/Substage folder matched current Scene identity; Stage scope retained."
                )
        else:
            if pointer:
                warnings.append("Exact BackgroundFile pointer does not currently resolve.")
            if stage_root_exists:
                matches = bounded_matching_dirs(stage_root, scene)
                if len(matches) == 1:
                    scope_root = matches[0]
                    basis = (
                        "Stored pointer did not resolve exactly; one deterministic current "
                        "Scene/Substage folder matched current Scene identity."
                    )
                elif len(matches) > 1:
                    return Result(
                        preview=preview, scene=scene, stage_key=stage_key,
                        scene_background_file=pointer, pointer_under_drive_root=pointer_under_root,
                        exact_pointer_resolves=exact_resolves, stage_root=str(stage_root),
                        stage_root_exists=stage_root_exists, resolved_scope_type="UNRESOLVED",
                        resolved_scope_root=None,
                        resolution_basis="Multiple deterministic current Scene/Substage folder matches.",
                        wiring_branch=derive_wiring_branch(preview, pointer), candidates=[],
                        selected_candidate=None, selected_path=None,
                        warnings=warnings + [f"Matches: {', '.join(str(m) for m in matches)}"],
                        status="UNRESOLVED",
                    )
                else:
                    basis = (
                        "No distinct current Scene/Substage folder matched current Scene identity; "
                        "known current Stage root retained for task fallback."
                    )

    if str(scope_root).casefold() != str(stage_root).casefold():
        if stage_key and re.match(r"^\d{2}[A-Za-z]$", stage_key) and \
                scope_root.name.casefold().startswith(stage_key.casefold() + "-"):
            scope_type = "SUBSTAGE"
        else:
            scope_type = "SCENE"

    branch = derive_wiring_branch(preview, pointer)
    if branch is None:
        warnings.append("Wiring context could not be derived from current Preview/path evidence.")
        return Result(
            preview=preview, scene=scene, stage_key=stage_key,
            scene_background_file=pointer, pointer_under_drive_root=pointer_under_root,
            exact_pointer_resolves=exact_resolves, stage_root=str(stage_root),
            stage_root_exists=stage_root_exists, resolved_scope_type=scope_type,
            resolved_scope_root=str(scope_root), resolution_basis=basis,
            wiring_branch=None, candidates=[], selected_candidate=None,
            selected_path=None, warnings=warnings, status="UNRESOLVED",
        )

    candidates: list[Candidate] = []
    if str(scope_root).casefold() != str(stage_root).casefold():
        candidates.extend(
            [
                make_candidate(f"{scope_type.title()} Wiring {branch}", scope_root / "Wiring" / branch),
                make_candidate(f"{scope_type.title()} PreviewBackground", scope_root / "PreviewBackground"),
            ]
        )
    candidates.extend(
        [
            make_candidate(f"Stage Wiring {branch}", stage_root / "Wiring" / branch),
            make_candidate("Stage PreviewBackground", stage_root / "PreviewBackground"),
        ]
    )

    selected = select_candidate(candidates)
    status = "RESOLVED" if selected else "UNRESOLVED"
    if selected is None:
        warnings.append("No candidate folder contained a directly published .jpg/.jpeg/.png image.")

    return Result(
        preview=preview,
        scene=scene,
        stage_key=stage_key,
        scene_background_file=pointer,
        pointer_under_drive_root=pointer_under_root,
        exact_pointer_resolves=exact_resolves,
        stage_root=str(stage_root),
        stage_root_exists=stage_root_exists,
        resolved_scope_type=scope_type,
        resolved_scope_root=str(scope_root),
        resolution_basis=basis,
        wiring_branch=branch,
        candidates=candidates,
        selected_candidate=selected.label if selected else None,
        selected_path=selected.path if selected else None,
        warnings=warnings,
        status=status,
    )


def render_text(results: list[Result], snapshot: Path, drive_root: str) -> str:
    now = datetime.now().astimezone()
    lines = [
        "FieldWiring Drive Context Resolver Test",
        f"Generated: {now.isoformat(timespec='seconds')}",
        f"Snapshot: {snapshot}",
        f"Drive root: {drive_root}",
        "",
    ]
    for index, result in enumerate(results, 1):
        lines.extend(
            [
                f"[{index}] {result.scene}",
                f"  Status: {result.status}",
                f"  Preview: {result.preview}",
                f"  Stage key: {result.stage_key}",
                f"  BackgroundFile pointer: {result.scene_background_file}",
                f"  Pointer beneath Display Folders: {result.pointer_under_drive_root}",
                f"  Exact pointer resolves: {result.exact_pointer_resolves}",
                f"  Stage root: {result.stage_root}",
                f"  Stage root resolves: {result.stage_root_exists}",
                f"  Resolved scope type: {result.resolved_scope_type}",
                f"  Resolved scope root: {result.resolved_scope_root}",
                f"  Resolution basis: {result.resolution_basis}",
                f"  Wiring branch: {result.wiring_branch}",
                "  Candidates:",
            ]
        )
        if result.candidates:
            for candidate in result.candidates:
                lines.append(
                    f"    - {candidate.label}: exists={candidate.exists}, "
                    f"images={candidate.image_count}, path={candidate.path}"
                )
                for image in candidate.images:
                    lines.append(f"        * {image}")
        else:
            lines.append("    - none")
        lines.append(f"  Selected: {result.selected_candidate or 'NONE'}")
        lines.append(f"  Selected path: {result.selected_path or 'NONE'}")
        if result.warnings:
            lines.append("  Warnings:")
            for warning in result.warnings:
                lines.append(f"    - {warning}")
        lines.append("")
    resolved = sum(r.status == "RESOLVED" for r in results)
    lines.extend(
        [
            f"Summary: {resolved}/{len(results)} resolved under current test rule.",
            "NOTE: This is a read-only engineering test. The fallback order remains under test.",
        ]
    )
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--snapshot", dest="snapshot")
    parser.add_argument("--drive-root", default=DRIVE_ROOT_DEFAULT)
    parser.add_argument("--scene", action="append", default=[])
    parser.add_argument("--all-master-scenes", action="store_true")
    parser.add_argument("--output-dir")
    args = parser.parse_args()

    script_path = Path(__file__).resolve()
    repo_root = script_path.parent.parent.parent
    snapshot = discover_snapshot(repo_root, args.snapshot)
    drive_root_text = args.drive_root
    drive_root = Path(drive_root_text)
    if not drive_root.is_dir():
        raise FileNotFoundError(f"Mapped Display Folders root was not found: {drive_root}")

    conn = open_snapshot_ro(snapshot)
    try:
        required_tables(conn)
        if args.all_master_scenes:
            rows = query_all_master_scenes(conn)
        elif args.scene:
            rows = query_named_scenes(conn, args.scene)
        else:
            rows = query_default_cases(conn)
        results = [resolve_one(conn, row, drive_root, drive_root_text) for row in rows]
    finally:
        conn.close()

    output_dir = Path(args.output_dir) if args.output_dir else Path.home() / "Desktop"
    output_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    text_path = output_dir / f"FieldWiring_Drive_Resolver_Test_{stamp}.txt"
    json_path = output_dir / f"FieldWiring_Drive_Resolver_Test_{stamp}.json"

    text = render_text(results, snapshot, drive_root_text)
    text_path.write_text(text, encoding="utf-8")
    json_path.write_text(
        json.dumps([asdict(result) for result in results], indent=2),
        encoding="utf-8",
    )

    print(text)
    print(f"Text report: {text_path}")
    print(f"JSON report: {json_path}")
    return 0 if all(result.status == "RESOLVED" for result in results) else 2


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        raise SystemExit(1)
