#!/usr/bin/env python3
"""Generate a read-only LOR vs Google Drive folder alignment report.

Version 1 targets Windows workstations where Google Drive for Desktop is mounted
as G:. It reads the current V7 SQLite parser output and the Display Folders
shared drive. It never creates, moves, renames, or deletes Stage/Scene/Display
folders.
"""
from __future__ import annotations

import argparse
import csv
import html
import re
import sqlite3
import sys
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable

VERSION = "V1.0.0"
DEFAULT_DB = Path(r"G:\Shared drives\MSB Database\database\lor_output_v7_scene.db")
DEFAULT_DRIVE_ROOT = Path(r"G:\Shared drives\Display Folders")
DEFAULT_OUTPUT = Path(
    r"G:\Shared drives\MSB Database\Database Previews V6.6.4\reports\google-drive-alignment"
)

RESERVED_STAGE_FOLDERS = {
    "photos",
    "procedures",
    "wiring",
    "sourcedocs",
    "historical",
    "archive",
    "archives",
}
STAGE_FOLDER_RE = re.compile(r"^(?P<stage_id>\d{2}[A-Za-z]?)-.+")


@dataclass(frozen=True)
class ExpectedDisplay:
    stage_id: str
    display_name: str
    scene_names: tuple[str, ...]


@dataclass(frozen=True)
class Finding:
    stage_id: str
    entity_type: str
    expected_name: str
    expected_parent: str
    status: str
    found_path: str
    note: str


def norm(value: str | None) -> str:
    """Normalize names only for matching. Never rename folders."""
    return re.sub(r"[^a-z0-9]+", "", (value or "").casefold())


def stage_key(value: str | None) -> str:
    """Normalize StageID for comparison: 4 -> 04, 7a -> 07a."""
    value = (value or "").strip().casefold()
    match = re.fullmatch(r"(\d{1,2})([a-z]?)", value)
    if not match:
        return value
    return f"{int(match.group(1)):02d}{match.group(2)}"


def qident(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def object_exists(conn: sqlite3.Connection, name: str) -> bool:
    row = conn.execute(
        "SELECT 1 FROM sqlite_master WHERE lower(name)=lower(?) LIMIT 1", (name,)
    ).fetchone()
    return row is not None


def columns(conn: sqlite3.Connection, obj: str) -> list[str]:
    return [str(row[1]) for row in conn.execute(f"PRAGMA table_info({qident(obj)})")]


def choose_column(cols: Iterable[str], candidates: Iterable[str]) -> str | None:
    lookup = {column.casefold(): column for column in cols}
    for candidate in candidates:
        if candidate.casefold() in lookup:
            return lookup[candidate.casefold()]
    return None


def load_parser_provenance(conn: sqlite3.Connection) -> dict[str, str]:
    if not object_exists(conn, "parser_run"):
        return {}
    cols = columns(conn, "parser_run")
    if not cols:
        return {}
    row = conn.execute("SELECT * FROM parser_run ORDER BY rowid DESC LIMIT 1").fetchone()
    if row is None:
        return {}
    return {
        cols[index]: "" if row[index] is None else str(row[index])
        for index in range(len(cols))
    }


def load_stage_previews(conn: sqlite3.Connection) -> dict[str, list[str]]:
    if not object_exists(conn, "previews"):
        raise RuntimeError("Current V7 SQLite snapshot does not contain previews")

    cols = columns(conn, "previews")
    stage_col = choose_column(cols, ["StageID", "StageId"])
    name_col = choose_column(cols, ["Name", "PreviewName"])
    if not stage_col or not name_col:
        raise RuntimeError("previews must contain StageID and Name")

    rows = conn.execute(
        f"SELECT DISTINCT {qident(stage_col)}, {qident(name_col)} FROM previews "
        f"WHERE NULLIF(TRIM({qident(stage_col)}),'') IS NOT NULL "
        f"ORDER BY {qident(stage_col)}, {qident(name_col)}"
    ).fetchall()

    result: dict[str, list[str]] = defaultdict(list)
    for raw_stage_id, name in rows:
        sid = stage_key(str(raw_stage_id))
        if name and str(name) not in result[sid]:
            result[sid].append(str(name))
    return dict(result)


def load_stage_displays(conn: sqlite3.Connection) -> dict[str, set[str]]:
    if not object_exists(conn, "props"):
        raise RuntimeError("Current V7 SQLite snapshot does not contain props")

    pcols = columns(conn, "props")
    vcols = columns(conn, "previews")
    preview_fk = choose_column(pcols, ["PreviewId", "PreviewID"])
    display_col = choose_column(pcols, ["LORComment", "DisplayName", "Display_Name"])
    preview_id = choose_column(vcols, ["id", "PreviewID", "PreviewId"])
    stage_col = choose_column(vcols, ["StageID", "StageId"])
    if not all([preview_fk, display_col, preview_id, stage_col]):
        raise RuntimeError(
            "Could not resolve previews/props StageID and Display Name columns"
        )

    sql = f"""
        SELECT DISTINCT p.{qident(display_col)}, v.{qident(stage_col)}
        FROM props p
        JOIN previews v ON v.{qident(preview_id)} = p.{qident(preview_fk)}
        WHERE NULLIF(TRIM(p.{qident(display_col)}),'') IS NOT NULL
          AND NULLIF(TRIM(v.{qident(stage_col)}),'') IS NOT NULL
        ORDER BY v.{qident(stage_col)}, p.{qident(display_col)}
    """

    result: dict[str, set[str]] = defaultdict(set)
    for display_name, raw_stage_id in conn.execute(sql):
        result[stage_key(str(raw_stage_id))].add(str(display_name).strip())
    return dict(result)


def load_scene_membership_from_view(
    conn: sqlite3.Connection,
) -> list[tuple[str, str, str]] | None:
    """Prefer the V7 display-level scene reporting view when available."""
    if not object_exists(conn, "scene_displays_vw"):
        return None

    cols = columns(conn, "scene_displays_vw")
    stage_col = choose_column(cols, ["SceneStageID", "StageID", "StageId"])
    scene_col = choose_column(cols, ["SceneName", "Name"])
    display_col = choose_column(cols, ["DisplayName", "Display_Name", "LORComment"])
    if not all([stage_col, scene_col, display_col]):
        return None

    sql = f"""
        SELECT DISTINCT {qident(stage_col)}, {qident(scene_col)}, {qident(display_col)}
        FROM scene_displays_vw
        WHERE NULLIF(TRIM({qident(stage_col)}),'') IS NOT NULL
          AND NULLIF(TRIM({qident(scene_col)}),'') IS NOT NULL
          AND NULLIF(TRIM({qident(display_col)}),'') IS NOT NULL
        ORDER BY {qident(stage_col)}, {qident(scene_col)}, {qident(display_col)}
    """
    return [
        (stage_key(str(stage_id)), str(scene).strip(), str(display).strip())
        for stage_id, scene, display in conn.execute(sql)
    ]


def load_scene_membership_fallback(
    conn: sqlite3.Connection,
) -> list[tuple[str, str, str]]:
    """Strict fallback if scene_displays_vw is unavailable.

    The report never guesses positional XML membership. It only uses recognized V7
    scene tables and columns. If they cannot be resolved, the report stops.
    """
    for obj in ("scenes", "scene_lor_props"):
        if not object_exists(conn, obj):
            raise RuntimeError(
                "scene_displays_vw is unavailable and required V7 scene tables are missing"
            )

    scols = columns(conn, "scenes")
    lcols = columns(conn, "scene_lor_props")
    pcols = columns(conn, "props")
    spcols = columns(conn, "subProps") if object_exists(conn, "subProps") else []

    scene_id_s = choose_column(scols, ["SceneID", "SceneId", "id"])
    scene_stage = choose_column(scols, ["SceneStageID", "StageID", "StageId"])
    scene_name = choose_column(scols, ["Name", "SceneName"])
    scene_id_l = choose_column(lcols, ["SceneID", "SceneId"])
    raw_prop_l = choose_column(lcols, ["RawPropID", "PropID", "PropId"])
    raw_prop_p = choose_column(pcols, ["RawPropID", "PropID", "PropId"])
    display_p = choose_column(pcols, ["LORComment", "DisplayName", "Display_Name"])
    raw_prop_sp = choose_column(spcols, ["RawPropID", "SubPropID", "SubPropId"])
    display_sp = choose_column(spcols, ["LORComment", "DisplayName", "Display_Name"])

    if not all(
        [
            scene_id_s,
            scene_stage,
            scene_name,
            scene_id_l,
            raw_prop_l,
            raw_prop_p,
            display_p,
        ]
    ):
        raise RuntimeError(
            "Could not resolve the V7 scene membership schema; use a current parser snapshot"
        )

    result: set[tuple[str, str, str]] = set()

    sql_props = f"""
        SELECT DISTINCT s.{qident(scene_stage)}, s.{qident(scene_name)}, p.{qident(display_p)}
        FROM scene_lor_props slp
        JOIN scenes s ON s.{qident(scene_id_s)} = slp.{qident(scene_id_l)}
        JOIN props p ON p.{qident(raw_prop_p)} = slp.{qident(raw_prop_l)}
        WHERE NULLIF(TRIM(s.{qident(scene_stage)}),'') IS NOT NULL
          AND NULLIF(TRIM(s.{qident(scene_name)}),'') IS NOT NULL
          AND NULLIF(TRIM(p.{qident(display_p)}),'') IS NOT NULL
    """
    for stage_id, scene, display in conn.execute(sql_props):
        result.add((stage_key(str(stage_id)), str(scene).strip(), str(display).strip()))

    if raw_prop_sp and display_sp:
        sql_sub = f"""
            SELECT DISTINCT s.{qident(scene_stage)}, s.{qident(scene_name)}, sp.{qident(display_sp)}
            FROM scene_lor_props slp
            JOIN scenes s ON s.{qident(scene_id_s)} = slp.{qident(scene_id_l)}
            JOIN subProps sp ON sp.{qident(raw_prop_sp)} = slp.{qident(raw_prop_l)}
            WHERE NULLIF(TRIM(s.{qident(scene_stage)}),'') IS NOT NULL
              AND NULLIF(TRIM(s.{qident(scene_name)}),'') IS NOT NULL
              AND NULLIF(TRIM(sp.{qident(display_sp)}),'') IS NOT NULL
        """
        for stage_id, scene, display in conn.execute(sql_sub):
            result.add(
                (stage_key(str(stage_id)), str(scene).strip(), str(display).strip())
            )

    return sorted(result)


def load_expected(
    conn: sqlite3.Connection,
) -> tuple[
    dict[str, list[str]],
    dict[str, set[str]],
    dict[str, dict[str, set[str]]],
    list[ExpectedDisplay],
]:
    stage_previews = load_stage_previews(conn)
    stage_displays = load_stage_displays(conn)
    scene_rows = load_scene_membership_from_view(conn)
    if scene_rows is None:
        scene_rows = load_scene_membership_fallback(conn)

    scenes: dict[str, dict[str, set[str]]] = defaultdict(lambda: defaultdict(set))
    display_scenes: dict[tuple[str, str], set[str]] = defaultdict(set)

    for stage_id, scene_name, display_name in scene_rows:
        scenes[stage_id][scene_name].add(display_name)
        display_scenes[(stage_id, display_name)].add(scene_name)

    all_stage_ids = set(stage_previews) | set(stage_displays) | set(scenes)
    displays: list[ExpectedDisplay] = []

    for sid in sorted(all_stage_ids):
        names = set(stage_displays.get(sid, set()))
        for scene_displays in scenes.get(sid, {}).values():
            names.update(scene_displays)
        for name in sorted(names, key=str.casefold):
            displays.append(
                ExpectedDisplay(
                    sid,
                    name,
                    tuple(
                        sorted(
                            display_scenes.get((sid, name), set()), key=str.casefold
                        )
                    ),
                )
            )

    return (
        stage_previews,
        stage_displays,
        {stage: dict(scene_map) for stage, scene_map in scenes.items()},
        displays,
    )


def discover_stage_folders(root: Path) -> tuple[dict[str, list[Path]], list[Path]]:
    stages: dict[str, list[Path]] = defaultdict(list)
    other: list[Path] = []

    for child in sorted(root.iterdir(), key=lambda path: path.name.casefold()):
        if not child.is_dir():
            continue
        match = STAGE_FOLDER_RE.match(child.name)
        if match:
            stages[stage_key(match.group("stage_id"))].append(child)
        else:
            other.append(child)

    return dict(stages), other


def direct_dirs(path: Path) -> list[Path]:
    try:
        return sorted(
            [child for child in path.iterdir() if child.is_dir()],
            key=lambda child: child.name.casefold(),
        )
    except OSError:
        return []


def match_direct(
    parent: Path, expected_name: str, reserved: set[str] | None = None
) -> list[Path]:
    wanted = norm(expected_name)
    matches: list[Path] = []
    for child in direct_dirs(parent):
        if reserved and child.name.casefold() in reserved:
            continue
        if norm(child.name) == wanted:
            matches.append(child)
    return matches


def find_named_dirs_under(stage_path: Path, expected_name: str) -> list[Path]:
    """Find a possible Scene/Display folder anywhere below one Stage.

    Standard Photos, Procedures, Wiring, SourceDocs, and archive paths are excluded
    so a drawing/source subfolder does not get mistaken for a Display folder.
    """
    wanted = norm(expected_name)
    matches: list[Path] = []

    try:
        for candidate in stage_path.rglob("*"):
            if not candidate.is_dir():
                continue
            relative_parts = [
                part.casefold() for part in candidate.relative_to(stage_path).parts
            ]
            if any(part in RESERVED_STAGE_FOLDERS for part in relative_parts):
                continue
            if norm(candidate.name) == wanted:
                matches.append(candidate)
    except OSError:
        return matches

    return sorted(set(matches), key=lambda path: str(path).casefold())


def relative_display(path: Path, root: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def audit_drive(
    root: Path,
    stage_previews: dict[str, list[str]],
    scenes: dict[str, dict[str, set[str]]],
    displays: list[ExpectedDisplay],
) -> list[Finding]:
    stage_folders, _ = discover_stage_folders(root)
    findings: list[Finding] = []
    stage_ids = sorted(
        set(stage_previews) | set(scenes) | {display.stage_id for display in displays}
    )

    scene_paths: dict[tuple[str, str], Path | None] = {}

    for sid in stage_ids:
        matches = stage_folders.get(sid, [])
        if not matches:
            findings.append(
                Finding(
                    sid,
                    "STAGE",
                    sid,
                    str(root),
                    "MISSING",
                    "",
                    "No Stage folder with this StageID was found.",
                )
            )
            continue

        if len(matches) > 1:
            findings.append(
                Finding(
                    sid,
                    "STAGE",
                    sid,
                    str(root),
                    "AMBIGUOUS",
                    "; ".join(relative_display(path, root) for path in matches),
                    "More than one Stage folder has this StageID.",
                )
            )
            continue

        stage_path = matches[0]
        findings.append(
            Finding(
                sid,
                "STAGE",
                sid,
                str(root),
                "MATCH",
                relative_display(stage_path, root),
                "",
            )
        )

        for scene_name in sorted(scenes.get(sid, {}), key=str.casefold):
            direct = match_direct(stage_path, scene_name, RESERVED_STAGE_FOLDERS)

            if len(direct) == 1:
                scene_paths[(sid, scene_name)] = direct[0]
                findings.append(
                    Finding(
                        sid,
                        "SCENE",
                        scene_name,
                        relative_display(stage_path, root),
                        "MATCH",
                        relative_display(direct[0], root),
                        "",
                    )
                )
                continue

            if len(direct) > 1:
                scene_paths[(sid, scene_name)] = None
                findings.append(
                    Finding(
                        sid,
                        "SCENE",
                        scene_name,
                        relative_display(stage_path, root),
                        "AMBIGUOUS",
                        "; ".join(relative_display(path, root) for path in direct),
                        "Duplicate direct Scene folder matches.",
                    )
                )
                continue

            elsewhere = find_named_dirs_under(stage_path, scene_name)
            if len(elsewhere) == 1:
                scene_paths[(sid, scene_name)] = elsewhere[0]
                findings.append(
                    Finding(
                        sid,
                        "SCENE",
                        scene_name,
                        relative_display(stage_path, root),
                        "WRONG_LOCATION",
                        relative_display(elsewhere[0], root),
                        "Scene folder exists below the Stage but is not directly under the Stage.",
                    )
                )
            elif len(elsewhere) > 1:
                scene_paths[(sid, scene_name)] = None
                findings.append(
                    Finding(
                        sid,
                        "SCENE",
                        scene_name,
                        relative_display(stage_path, root),
                        "AMBIGUOUS",
                        "; ".join(relative_display(path, root) for path in elsewhere),
                        "More than one possible Scene folder match.",
                    )
                )
            else:
                scene_paths[(sid, scene_name)] = None
                findings.append(
                    Finding(
                        sid,
                        "SCENE",
                        scene_name,
                        relative_display(stage_path, root),
                        "MISSING",
                        "",
                        "LOR Scene has no matching folder under the Stage.",
                    )
                )

    for display in displays:
        stage_matches = stage_folders.get(display.stage_id, [])
        if len(stage_matches) != 1:
            findings.append(
                Finding(
                    display.stage_id,
                    "DISPLAY",
                    display.display_name,
                    "",
                    "BLOCKED",
                    "",
                    "Display could not be checked because the Stage folder is missing or ambiguous.",
                )
            )
            continue

        stage_path = stage_matches[0]

        if len(display.scene_names) > 1:
            all_found = find_named_dirs_under(stage_path, display.display_name)
            findings.append(
                Finding(
                    display.stage_id,
                    "DISPLAY",
                    display.display_name,
                    "Multiple LOR Scenes",
                    "AMBIGUOUS",
                    "; ".join(relative_display(path, root) for path in all_found),
                    "Display appears in more than one LOR Scene: "
                    + ", ".join(display.scene_names),
                )
            )
            continue

        if len(display.scene_names) == 1:
            scene_name = display.scene_names[0]
            expected_scene_path = scene_paths.get((display.stage_id, scene_name))
            expected_parent = (
                f"{relative_display(stage_path, root)}\\{scene_name}"
            )

            if expected_scene_path is not None:
                direct = match_direct(expected_scene_path, display.display_name)
                if len(direct) == 1:
                    findings.append(
                        Finding(
                            display.stage_id,
                            "DISPLAY",
                            display.display_name,
                            relative_display(expected_scene_path, root),
                            "MATCH",
                            relative_display(direct[0], root),
                            "",
                        )
                    )
                    continue

                if len(direct) > 1:
                    findings.append(
                        Finding(
                            display.stage_id,
                            "DISPLAY",
                            display.display_name,
                            relative_display(expected_scene_path, root),
                            "AMBIGUOUS",
                            "; ".join(
                                relative_display(path, root) for path in direct
                            ),
                            "Duplicate Display folder matches in the expected Scene.",
                        )
                    )
                    continue

            all_found = find_named_dirs_under(stage_path, display.display_name)
            if len(all_found) == 1:
                findings.append(
                    Finding(
                        display.stage_id,
                        "DISPLAY",
                        display.display_name,
                        expected_parent,
                        "WRONG_LOCATION",
                        relative_display(all_found[0], root),
                        f"LOR places this Display in Scene '{scene_name}'.",
                    )
                )
            elif len(all_found) > 1:
                findings.append(
                    Finding(
                        display.stage_id,
                        "DISPLAY",
                        display.display_name,
                        expected_parent,
                        "AMBIGUOUS",
                        "; ".join(
                            relative_display(path, root) for path in all_found
                        ),
                        "More than one possible Display folder match.",
                    )
                )
            else:
                findings.append(
                    Finding(
                        display.stage_id,
                        "DISPLAY",
                        display.display_name,
                        expected_parent,
                        "MISSING",
                        "",
                        f"LOR places this Display in Scene '{scene_name}'.",
                    )
                )
            continue

        direct = match_direct(stage_path, display.display_name, RESERVED_STAGE_FOLDERS)
        if len(direct) == 1:
            findings.append(
                Finding(
                    display.stage_id,
                    "DISPLAY",
                    display.display_name,
                    relative_display(stage_path, root),
                    "MATCH",
                    relative_display(direct[0], root),
                    "",
                )
            )
            continue

        if len(direct) > 1:
            findings.append(
                Finding(
                    display.stage_id,
                    "DISPLAY",
                    display.display_name,
                    relative_display(stage_path, root),
                    "AMBIGUOUS",
                    "; ".join(relative_display(path, root) for path in direct),
                    "Duplicate Display folder matches directly under Stage.",
                )
            )
            continue

        all_found = find_named_dirs_under(stage_path, display.display_name)
        if len(all_found) == 1:
            findings.append(
                Finding(
                    display.stage_id,
                    "DISPLAY",
                    display.display_name,
                    relative_display(stage_path, root),
                    "WRONG_LOCATION",
                    relative_display(all_found[0], root),
                    "LOR does not assign this Display to a Scene, so its folder should be directly under the Stage.",
                )
            )
        elif len(all_found) > 1:
            findings.append(
                Finding(
                    display.stage_id,
                    "DISPLAY",
                    display.display_name,
                    relative_display(stage_path, root),
                    "AMBIGUOUS",
                    "; ".join(relative_display(path, root) for path in all_found),
                    "More than one possible Display folder match.",
                )
            )
        else:
            findings.append(
                Finding(
                    display.stage_id,
                    "DISPLAY",
                    display.display_name,
                    relative_display(stage_path, root),
                    "MISSING",
                    "",
                    "LOR does not assign this Display to a Scene.",
                )
            )

    return findings


def write_csv_report(path: Path, findings: list[Finding]) -> None:
    with path.open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.writer(handle)
        writer.writerow(
            [
                "stage_id",
                "entity_type",
                "expected_name",
                "expected_parent",
                "status",
                "found_path",
                "note",
            ]
        )
        for finding in findings:
            writer.writerow(
                [
                    finding.stage_id,
                    finding.entity_type,
                    finding.expected_name,
                    finding.expected_parent,
                    finding.status,
                    finding.found_path,
                    finding.note,
                ]
            )


def esc(value: object) -> str:
    return html.escape("" if value is None else str(value))


def write_html_report(
    path: Path,
    db_path: Path,
    drive_root: Path,
    provenance: dict[str, str],
    stage_previews: dict[str, list[str]],
    scenes: dict[str, dict[str, set[str]]],
    displays: list[ExpectedDisplay],
    findings: list[Finding],
) -> None:
    by_stage: dict[str, list[Finding]] = defaultdict(list)
    for finding in findings:
        by_stage[finding.stage_id].append(finding)

    counts: dict[str, int] = defaultdict(int)
    for finding in findings:
        counts[finding.status] += 1

    status_order = ["MATCH", "MISSING", "WRONG_LOCATION", "AMBIGUOUS", "BLOCKED"]
    generated = datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")

    parts = [
        f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>LOR / Google Drive Folder Alignment</title>
<style>
body {{ font-family: Segoe UI, Arial, sans-serif; margin: 24px; color: #222; }}
h1, h2 {{ margin-bottom: .35em; }}
.meta {{ color: #555; }}
table {{ border-collapse: collapse; width: 100%; margin: 12px 0 28px; }}
th, td {{ border: 1px solid #ccc; padding: 7px; vertical-align: top; text-align: left; }}
th {{ background: #f1f1f1; }}
.MATCH {{ background: #edf8ed; }}
.MISSING {{ background: #fff0f0; }}
.WRONG_LOCATION {{ background: #fff7e6; }}
.AMBIGUOUS, .BLOCKED {{ background: #f3efff; }}
code {{ font-family: Consolas, monospace; }}
.summary span {{ display: inline-block; margin-right: 18px; }}
.warning {{ padding: 10px; border: 1px solid #d5a400; background: #fff8d6; }}
</style>
</head>
<body>
<h1>LOR Stage / Scene / Display — Google Drive Alignment Report</h1>
<p class="warning"><strong>READ-ONLY AUDIT.</strong> This report does not create, move, rename, or delete any Google Drive folders.</p>
<p class="meta">
<strong>Report version:</strong> {VERSION}<br>
<strong>Generated:</strong> {esc(generated)}<br>
<strong>SQLite snapshot:</strong> <code>{esc(db_path)}</code><br>
<strong>Google Drive root:</strong> <code>{esc(drive_root)}</code>
</p>
"""
    ]

    if provenance:
        parts.append("<h2>Parser Snapshot</h2><table><tbody>")
        preferred = [
            "parser_version",
            "started_at",
            "completed_at",
            "parser_actor",
            "actor",
            "host",
            "source_preview_folder",
            "sqlite_database_path",
            "status",
        ]
        shown: set[str] = set()

        for key in preferred:
            actual = next(
                (candidate for candidate in provenance if candidate.casefold() == key.casefold()),
                None,
            )
            if actual and provenance[actual]:
                parts.append(
                    f"<tr><th>{esc(actual)}</th><td>{esc(provenance[actual])}</td></tr>"
                )
                shown.add(actual)

        for key, value in provenance.items():
            if key not in shown and value:
                parts.append(
                    f"<tr><th>{esc(key)}</th><td>{esc(value)}</td></tr>"
                )

        parts.append("</tbody></table>")

    parts.append("<h2>Summary</h2><p class='summary'>")
    for status in status_order:
        parts.append(
            f"<span><strong>{esc(status)}:</strong> {counts.get(status, 0)}</span>"
        )
    parts.append("</p>")

    for sid in sorted(by_stage):
        parts.append(f"<h2>Stage {esc(sid)}</h2>")

        previews = stage_previews.get(sid, [])
        if previews:
            parts.append(
                "<p><strong>LOR Preview(s):</strong> "
                + "; ".join(esc(name) for name in previews)
                + "</p>"
            )

        if scenes.get(sid):
            parts.append(
                "<p><strong>LOR Scenes:</strong> "
                + "; ".join(
                    esc(name) for name in sorted(scenes[sid], key=str.casefold)
                )
                + "</p>"
            )

        parts.append(
            "<table><thead><tr>"
            "<th>Type</th><th>LOR Name</th><th>Expected Parent</th>"
            "<th>Status</th><th>Found</th><th>Notes</th>"
            "</tr></thead><tbody>"
        )

        type_order = {"STAGE": 0, "SCENE": 1, "DISPLAY": 2}
        for finding in sorted(
            by_stage[sid],
            key=lambda item: (
                type_order.get(item.entity_type, 9),
                item.expected_parent.casefold(),
                item.expected_name.casefold(),
            ),
        ):
            parts.append(
                f"<tr class='{esc(finding.status)}'>"
                f"<td>{esc(finding.entity_type)}</td>"
                f"<td>{esc(finding.expected_name)}</td>"
                f"<td><code>{esc(finding.expected_parent)}</code></td>"
                f"<td><strong>{esc(finding.status)}</strong></td>"
                f"<td><code>{esc(finding.found_path)}</code></td>"
                f"<td>{esc(finding.note)}</td>"
                "</tr>"
            )

        parts.append("</tbody></table>")

    parts.append(
        "<h2>Status Meanings</h2><table><tbody>"
        "<tr><th>MATCH</th><td>The expected folder exists in the expected location.</td></tr>"
        "<tr><th>MISSING</th><td>LOR expects the Stage, Scene, or Display but no matching folder was found.</td></tr>"
        "<tr><th>WRONG_LOCATION</th><td>A matching folder was found, but not where the current LOR Stage/Scene structure places it.</td></tr>"
        "<tr><th>AMBIGUOUS</th><td>More than one possible match exists, or LOR places one Display in more than one Scene. Review manually.</td></tr>"
        "<tr><th>BLOCKED</th><td>The parent Stage could not be resolved, so the child location could not be checked.</td></tr>"
        "</tbody></table>"
    )
    parts.append("</body></html>")
    path.write_text("".join(parts), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Read-only LOR vs Google Drive Stage/Scene/Display folder audit"
    )
    parser.add_argument(
        "--db",
        type=Path,
        default=DEFAULT_DB,
        help=f"V7 SQLite snapshot (default: {DEFAULT_DB})",
    )
    parser.add_argument(
        "--drive-root",
        type=Path,
        default=DEFAULT_DRIVE_ROOT,
        help=f"Display Folders root (default: {DEFAULT_DRIVE_ROOT})",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Report output directory (default: {DEFAULT_OUTPUT})",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if not args.db.is_file():
        print(f"[ERROR] SQLite snapshot not found: {args.db}", file=sys.stderr)
        return 2

    if not args.drive_root.is_dir():
        print(
            f"[ERROR] Google Drive Display Folders root not found: {args.drive_root}",
            file=sys.stderr,
        )
        return 3

    try:
        uri = args.db.resolve().as_uri() + "?mode=ro"
        with sqlite3.connect(uri, uri=True) as conn:
            provenance = load_parser_provenance(conn)
            stage_previews, _stage_displays, scenes, displays = load_expected(conn)
    except (sqlite3.Error, RuntimeError) as exc:
        print(
            f"[ERROR] Could not read current V7 SQLite structure: {exc}",
            file=sys.stderr,
        )
        return 4

    findings = audit_drive(args.drive_root, stage_previews, scenes, displays)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    html_path = args.output_dir / f"lor-google-drive-alignment-{stamp}.html"
    csv_path = args.output_dir / f"lor-google-drive-alignment-{stamp}.csv"

    write_html_report(
        html_path,
        args.db,
        args.drive_root,
        provenance,
        stage_previews,
        scenes,
        displays,
        findings,
    )
    write_csv_report(csv_path, findings)

    counts: dict[str, int] = defaultdict(int)
    for finding in findings:
        counts[finding.status] += 1

    print(f"[INFO] LOR / Google Drive Alignment {VERSION}")
    print(f"[INFO] SQLite: {args.db}")
    print(f"[INFO] Drive:  {args.drive_root}")
    print(f"[INFO] Stages in report: {len({finding.stage_id for finding in findings})}")
    print(f"[INFO] Displays from LOR: {len(displays)}")
    print(
        "[INFO] "
        + " | ".join(
            f"{status}={counts.get(status, 0)}"
            for status in [
                "MATCH",
                "MISSING",
                "WRONG_LOCATION",
                "AMBIGUOUS",
                "BLOCKED",
            ]
        )
    )
    print(f"[INFO] HTML: {html_path}")
    print(f"[INFO] CSV:  {csv_path}")
    print("[INFO] Read-only audit complete. No Google Drive folders were changed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
