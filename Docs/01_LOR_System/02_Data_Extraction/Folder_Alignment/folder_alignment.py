#!/usr/bin/env python3
"""MSB Folder Alignment - current read-only operator worklist.

This is the single active Folder Alignment report script. Git history provides
version control; do not create numbered copies of this file for future changes.

The script:
- reads the current V7 parser SQLite snapshot;
- inventories Google Drive once;
- resolves Stage / Sub-stage / Scene documentation folders;
- scans the central 000-Instructions folder once;
- writes a concise operator HTML worklist plus a technical CSV;
- never creates, moves, renames, or deletes Drive content.
"""
from __future__ import annotations

import argparse
import csv
import html
import os
import re
import sqlite3
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path, PureWindowsPath

VERSION = "1.0.0"
DEFAULT_DB = Path(r"G:\Shared drives\MSB Database\database\lor_output_v7_scene.db")
DEFAULT_ROOT = Path(r"G:\Shared drives\Display Folders")
DEFAULT_OUTPUT = Path(r"G:\Shared drives\MSB Database\Database Previews V6.6.4\reports\google-drive-alignment")
MASTER_MUSICAL_RE = re.compile(r"^\s*\d{4}\s+Master\s+Musical\s+Preview\b", re.IGNORECASE)
STAGE_FOLDER_RE = re.compile(r"^(?P<stage>\d{2})-")
SCENE_PREFIX_RE = re.compile(r"^\s*(?P<num>\d{2})(?P<letter>[A-Za-z]?)-(?P<body>.+?)\s*$")
TWO_LETTER_SUFFIX_RE = re.compile(r"-[A-Za-z]{2}$")
PRUNE_NAMES = {
    "previewbackground", "photos", "procedures", "wiring", "000instructions",
    "archive", "archives", "historical", "sourcedocs", "images",
}
STRUCTURED_REQUIRED = (
    "PreviewBackground",
    "Photos/Current",
    "Photos/Historical",
    "Procedures/Inspection",
    "Procedures/Setup/Archive",
    "Procedures/Setup/images",
    "Procedures/Setup/SourceDocs",
    "Procedures/Takedown/Archive",
    "Procedures/Takedown/images",
    "Procedures/Takedown/SourceDocs",
    "Wiring/BackgroundStage/SourceDocs",
    "Wiring/MusicalStage/SourceDocs",
)
GENERIC_WORDS = {
    "setup", "set", "up", "instructions", "instruction", "procedure", "procedures",
    "take", "down", "takedown", "google", "docs", "pdf", "gdoc", "gslides",
    "work", "progress", "2024", "2025", "2026",
}


@dataclass(frozen=True)
class SceneInfo:
    preview_name: str
    preview_stage_id: str
    scene_stage_id: str
    scene_name: str
    background_file: str
    is_master_musical: bool


@dataclass(frozen=True)
class Scope:
    stage_id: str
    scope_type: str
    scope_name: str
    path: Path
    status: str
    note: str = ""


@dataclass(frozen=True)
class LegacyFile:
    path: Path
    category: str


def norm(value: str | None) -> str:
    return re.sub(r"[^a-z0-9]+", "", (value or "").casefold())


def stage_key(value: str | None) -> str:
    value = (value or "").strip().casefold()
    m = re.fullmatch(r"(\d{1,2})([a-z]?)", value)
    return f"{int(m.group(1)):02d}{m.group(2)}" if m else value


def qi(name: str) -> str:
    return '"' + name.replace('"', '""') + '"'


def cols(conn: sqlite3.Connection, obj: str) -> list[str]:
    return [str(r[1]) for r in conn.execute(f"PRAGMA table_info({qi(obj)})")]


def pick(columns: list[str], *names: str) -> str | None:
    lookup = {c.casefold(): c for c in columns}
    for name in names:
        if name.casefold() in lookup:
            return lookup[name.casefold()]
    return None


def exists(conn: sqlite3.Connection, obj: str) -> bool:
    return conn.execute(
        "SELECT 1 FROM sqlite_master WHERE lower(name)=lower(?)", (obj,)
    ).fetchone() is not None


def rel(path: Path, root: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def file_href(path: Path) -> str:
    try:
        return path.resolve().as_uri()
    except (OSError, ValueError):
        return ""


def file_link(path: Path, label: str = "Open") -> str:
    href = file_href(path)
    if not href:
        return html.escape(label)
    return f"<a href='{html.escape(href, quote=True)}'>{html.escape(label)}</a>"


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Read-only MSB Stage/Scene documentation alignment worklist")
    p.add_argument("--db", type=Path, default=DEFAULT_DB)
    p.add_argument("--drive-root", type=Path, default=DEFAULT_ROOT)
    p.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    return p.parse_args()


def load_scene_info(conn: sqlite3.Connection):
    if not exists(conn, "previews") or not exists(conn, "scenes"):
        raise RuntimeError("Current V7 previews/scenes tables were not found. Run the current parser first.")

    pc = cols(conn, "previews")
    sc = cols(conn, "scenes")
    p_id = pick(pc, "id", "PreviewID", "PreviewId")
    p_stage = pick(pc, "StageID", "StageId")
    p_name = pick(pc, "Name", "PreviewName")
    s_prev = pick(sc, "PreviewId", "PreviewID")
    s_stage = pick(sc, "StageID", "StageId")
    s_name = pick(sc, "Name", "SceneName")
    s_bg = pick(sc, "BackgroundFile")
    if not all((p_id, p_stage, p_name, s_prev, s_name, s_bg)):
        raise RuntimeError("Could not resolve current previews/scenes columns.")

    previews: dict[str, list[str]] = defaultdict(list)
    for sid, name in conn.execute(
        f"SELECT DISTINCT {qi(p_stage)}, {qi(p_name)} FROM previews "
        f"WHERE NULLIF(TRIM({qi(p_stage)}),'') IS NOT NULL ORDER BY 1,2"
    ):
        key = stage_key(str(sid))
        if name and str(name) not in previews[key]:
            previews[key].append(str(name))

    rows: list[SceneInfo] = []
    stage_expr = f"s.{qi(s_stage)}" if s_stage else "''"
    sql = (
        f"SELECT p.{qi(p_name)}, p.{qi(p_stage)}, {stage_expr}, s.{qi(s_name)}, s.{qi(s_bg)} "
        f"FROM scenes s JOIN previews p ON p.{qi(p_id)}=s.{qi(s_prev)} "
        f"WHERE NULLIF(TRIM(s.{qi(s_name)}),'') IS NOT NULL "
        f"ORDER BY p.{qi(p_name)}, s.{qi(s_name)}"
    )
    for preview_name, preview_stage, scene_stage, scene_name, bg in conn.execute(sql):
        pn = "" if preview_name is None else str(preview_name).strip()
        rows.append(SceneInfo(
            preview_name=pn,
            preview_stage_id="" if preview_stage is None else stage_key(str(preview_stage)),
            scene_stage_id="" if scene_stage is None else stage_key(str(scene_stage)),
            scene_name=str(scene_name).strip(),
            background_file="" if bg is None else str(bg).strip(),
            is_master_musical=bool(MASTER_MUSICAL_RE.search(pn)),
        ))

    provenance = {}
    if exists(conn, "parser_run"):
        c = cols(conn, "parser_run")
        row = conn.execute("SELECT * FROM parser_run ORDER BY rowid DESC LIMIT 1").fetchone()
        if row:
            provenance = {c[i]: "" if row[i] is None else str(row[i]) for i in range(len(c))}
    return dict(previews), rows, provenance


def inventory_drive(root: Path):
    print("[INFO] Reading Stage folders from Google Drive...", flush=True)
    stages: dict[str, Path] = {}
    dirs_by_stage: dict[str, list[Path]] = defaultdict(list)
    direct_by_stage: dict[str, list[Path]] = defaultdict(list)

    for child in root.iterdir():
        if not child.is_dir():
            continue
        m = STAGE_FOLDER_RE.match(child.name)
        if not m:
            continue
        sid = m.group("stage")
        if sid in stages:
            raise RuntimeError(f"More than one top-level Stage folder was found for Stage {sid}.")
        stages[sid] = child

    for sid in sorted(stages):
        stage = stages[sid]
        print(f"[INFO] Scanning Stage {sid}: {stage.name}", flush=True)
        try:
            for child in stage.iterdir():
                if child.is_dir() and norm(child.name) not in PRUNE_NAMES:
                    direct_by_stage[sid].append(child)
        except OSError:
            pass

        try:
            for current, dirs, _files in os.walk(stage):
                current_path = Path(current)
                dirs[:] = [d for d in dirs if norm(d) not in PRUNE_NAMES]
                if current_path != stage:
                    dirs_by_stage[sid].append(current_path)
        except OSError:
            pass

    print("[INFO] Google Drive inventory complete.", flush=True)
    return stages, dict(dirs_by_stage), dict(direct_by_stage)


def background_scope(info: SceneInfo, root: Path, stages: dict[str, Path]) -> Path | None:
    """
    Resolve the Stage / Sub-stage / Scene that owns a BackgroundFile.

    Infrastructure folders are never documentation scopes.

    Examples:

        Stage\\PreviewBackground\\image
            -> Stage

        Stage\\Scene\\PreviewBackground\\image
            -> Scene

        Stage\\Wiring\\BackgroundStage\\image
            -> Stage

        Stage\\Scene\\Wiring\\BackgroundStage\\image
            -> Scene
    """
    if not info.background_file:
        return None

    try:
        parts = list(PureWindowsPath(info.background_file).parts)
    except (TypeError, ValueError):
        return None

    normalized = [norm(p) for p in parts]

    stage_index = None
    stage_path = None

    for _sid, stage in stages.items():
        try:
            idx = normalized.index(norm(stage.name))
        except ValueError:
            continue

        stage_index = idx
        stage_path = stage
        break

    if stage_index is None or stage_path is None:
        return None

    after = parts[stage_index + 1:]

    if not after:
        return stage_path

    normalized_after = [norm(p) for p in after]

    # These folders belong to an existing Stage / Sub-stage / Scene.
    # They can never become a documentation scope themselves.
    infrastructure = {
        "previewbackground",
        "photos",
        "procedures",
        "wiring",
    }

    boundary = next(
        (
            index
            for index, part in enumerate(normalized_after)
            if part in infrastructure
        ),
        None,
    )

    if boundary is not None:
        # Everything before the infrastructure folder identifies the
        # owning Stage / Sub-stage / Scene.
        scope_parts = after[:boundary]
    else:
        # No infrastructure folder is present. The final component is
        # assumed to be the background image/file itself.
        scope_parts = after[:-1]

    candidate = (
        stage_path.joinpath(*scope_parts)
        if scope_parts
        else stage_path
    )

    return candidate if candidate.is_dir() else None


def find_exact(paths: list[Path], name: str) -> Path | None:
    matches = [p for p in paths if norm(p.name) == norm(name)]
    return matches[0] if len(matches) == 1 else None


def classify_scene(name: str):
    if name.strip().casefold() == "root":
        return "ROOT", "", ""
    m = SCENE_PREFIX_RE.match(name)
    if not m:
        return "DISPLAY_GROUP", "", ""
    token = f"{m.group('num')}{m.group('letter').casefold()}"
    if TWO_LETTER_SUFFIX_RE.search(name):
        return ("SUB_STAGE" if m.group("letter") else "STAGE_ROOT"), token, name
    return "SCENE", token, name


def resolve_scopes(root: Path, stages: dict[str, Path], dirs_by_stage, direct_by_stage, scene_infos):
    scopes: dict[str, Scope] = {}
    issues: dict[str, list[str]] = defaultdict(list)

    for sid, stage in stages.items():
        scopes[str(stage).casefold()] = Scope(sid, "STAGE", stage.name, stage, "OK")

    for info in scene_infos:
        kind, token, expected_name = classify_scene(info.scene_name)
        if kind == "DISPLAY_GROUP":
            continue

        sid = (token[:2] if token else (info.preview_stage_id or info.scene_stage_id)[:2])
        stage = stages.get(sid)
        if stage is None:
            continue

        bg_scope = background_scope(info, root, stages)

        if kind in {"ROOT", "STAGE_ROOT"}:
            if kind == "STAGE_ROOT" and norm(info.scene_name) != norm(stage.name):
                issues[sid].append(
                    f"Review LOR Scene name <code>{html.escape(info.scene_name)}</code>; its background path points to Stage folder <code>{html.escape(rel(stage, root))}</code>."
                )
            continue

        if kind == "SUB_STAGE":
            target = find_exact(
                direct_by_stage.get(sid, []),
                expected_name,
            )

            if target is None and bg_scope is not None and bg_scope != stage:
                bg_kind, bg_token, _bg_name = classify_scene(bg_scope.name)

                # BackgroundFile may confirm a Sub-stage only when the
                # actual Drive folder is itself named as that Sub-stage.
                if bg_kind == "SUB_STAGE" and bg_token.casefold() == token.casefold():
                    target = bg_scope

            if target is None:
                issues[sid].append(
                    "Missing Sub-stage folder expected from LOR: "
                    f"<code>{html.escape(expected_name)}</code>."
                )
                continue

            scopes[str(target).casefold()] = Scope(
                sid,
                "SUB_STAGE",
                target.name,
                target,
                "OK",
            )
            continue

        # Scene.
        #
        # The LOR Scene name identifies a possible structured Scene, but the
        # actual Google Drive folder must also satisfy the Scene naming rule.
        #
        # A BackgroundFile path may locate a folder, but it must never promote
        # an unprefixed Display/group folder into a Scene documentation scope.
        target = None
        background_is_non_scene_scope = False

        if bg_scope is not None and bg_scope != stage:
            bg_kind, bg_token, _bg_name = classify_scene(bg_scope.name)

            if bg_kind == "SCENE" and bg_token.casefold() == token.casefold():
                target = bg_scope
            else:
                # Examples:
                #
                #   Making Spirits Bright
                #   Open-Close
                #
                # These may legitimately be Display/group folders even when an
                # LOR sequencing Scene passes through them.
                background_is_non_scene_scope = True

        if target is None:
            if len(token) == 3:
                # Example: 07a-Scene belongs beneath Sub-stage 07a.
                substage = next(
                    (
                        p
                        for p in direct_by_stage.get(sid, [])
                        if p.name.casefold().startswith(
                            token.casefold() + "-"
                        )
                        and classify_scene(p.name)[0] == "SUB_STAGE"
                    ),
                    None,
                )

                if substage is not None:
                    try:
                        target = find_exact(
                            [
                                p
                                for p in substage.iterdir()
                                if p.is_dir()
                            ],
                            expected_name,
                        )
                    except OSError:
                        target = None
            else:
                target = find_exact(
                    direct_by_stage.get(sid, []),
                    expected_name,
                )

        if target is None:
            # Background at the owning Stage means this LOR Scene uses
            # Stage-level documentation. No child Scene folder is required.
            if bg_scope == stage:
                continue

            # A BackgroundFile through an unprefixed Display/group does not
            # make that folder a Scene and does not require the full
            # Stage/Scene Procedures/Wiring structure.
            if background_is_non_scene_scope:
                continue

            issues[sid].append(
                "Missing Scene folder expected from LOR: "
                f"<code>{html.escape(expected_name)}</code>."
            )
            continue

        # Final safety gate: even an exact/path-resolved target must itself
        # satisfy the established Scene folder naming rule.
        target_kind, target_token, _target_name = classify_scene(target.name)

        if target_kind != "SCENE" or target_token.casefold() != token.casefold():
            continue

        scopes[str(target).casefold()] = Scope(
            sid,
            "SCENE",
            target.name,
            target,
            "OK",
        )

        if norm(target.name) != norm(expected_name):
            issues[sid].append(
                "Review Scene name "
                f"<code>{html.escape(info.scene_name)}</code>; "
                "current folder is "
                f"<code>{html.escape(rel(target, root))}</code>."
            )
    return list(scopes.values()), dict(issues)

def scan_legacy(root: Path):
    legacy_root = next((p for p in root.iterdir() if p.is_dir() and norm(p.name) == "000instructions"), None)
    by_stage: dict[str, list[LegacyFile]] = defaultdict(list)
    unassigned: list[LegacyFile] = []
    if legacy_root is None:
        return None, dict(by_stage), unassigned

    stage_file_re = re.compile(r"^\s*(?P<stage>\d{2})(?:[A-Za-z])?(?=[\s._-]|$)")
    for current, _dirs, files in os.walk(legacy_root):
        current_path = Path(current)
        for filename in files:
            path = current_path / filename
            try:
                relative = path.relative_to(legacy_root)
                category = relative.parts[0] if len(relative.parts) > 1 else "Central root"
            except ValueError:
                category = "Central root"
            item = LegacyFile(path, category)
            m = stage_file_re.match(filename)
            if m:
                by_stage[m.group("stage")].append(item)
            else:
                unassigned.append(item)

    for sid in by_stage:
        by_stage[sid].sort(key=lambda x: str(x.path).casefold())
    unassigned.sort(key=lambda x: str(x.path).casefold())
    return legacy_root, dict(by_stage), unassigned


def clean_words(value: str) -> list[str]:
    value = Path(value).stem
    value = re.sub(r"^\s*\d{2}[A-Za-z]?\s*[-_. ]*", "", value)
    return [w for w in re.findall(r"[A-Za-z0-9]+", value.casefold()) if w not in GENERIC_WORDS]


def scope_words(name: str) -> list[str]:
    name = re.sub(r"^\s*\d{2}[A-Za-z]?\s*[-_. ]*", "", name)
    name = re.sub(r"[-_ ]+[A-Za-z]{2}\s*$", "", name)
    return re.findall(r"[A-Za-z0-9]+", name.casefold())


def match_legacy_scope(filename: str, scopes: list[Scope]) -> Scope | None:
    f = set(clean_words(filename))
    if not f:
        return None
    candidates = []
    for scope in scopes:
        if scope.scope_type == "STAGE":
            continue
        s = set(scope_words(scope.scope_name))
        if not s:
            continue
        overlap = len(f & s)
        coverage = overlap / len(s)
        if coverage >= 0.70:
            candidates.append((coverage, overlap, len(s), scope))
    if not candidates:
        return None
    candidates.sort(key=lambda x: (x[0], x[1], x[2]), reverse=True)
    if len(candidates) > 1 and candidates[0][:3] == candidates[1][:3]:
        return None
    return candidates[0][3]


def legacy_branch(item: LegacyFile) -> str | None:
    text = f"{item.category} {item.path.name}".casefold()
    if "takedown" in text or "take-down" in text or "take down" in text or item.category.startswith("1 -"):
        return "Takedown"
    if "setup" in text or "set-up" in text or item.category.startswith("0 -"):
        return "Setup"
    return None


def missing_contract(scope: Scope) -> list[str]:
    return [p for p in STRUCTURED_REQUIRED if not (scope.path / Path(p)).is_dir()]


def write_reports(output: Path, root: Path, db: Path, previews, scopes, scope_issues, legacy_by_stage, unassigned, provenance):
    output.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    html_path = output / f"lor-google-drive-alignment-{stamp}.html"
    csv_path = output / f"lor-google-drive-alignment-{stamp}.csv"

    scopes_by_stage: dict[str, list[Scope]] = defaultdict(list)
    for scope in scopes:
        scopes_by_stage[scope.stage_id].append(scope)

    with csv_path.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(["stage_id", "scope_type", "scope_name", "scope_path", "missing_required"])
        for scope in sorted(scopes, key=lambda s: (s.stage_id, s.scope_type, str(s.path).casefold())):
            w.writerow([scope.stage_id, scope.scope_type, scope.scope_name, rel(scope.path, root), "; ".join(missing_contract(scope))])

    css = """
body{font-family:Segoe UI,Arial,sans-serif;margin:24px;color:#222;max-width:1450px}
h1{margin-bottom:5px}h2{margin-top:34px;border-bottom:2px solid #777;padding-bottom:5px}h3{margin:20px 0 6px}
table{border-collapse:collapse;width:100%;margin:7px 0 18px;font-size:14px;table-layout:fixed}
th,td{border:1px solid #ccc;padding:7px;vertical-align:top;text-align:left}th{background:#eee}
.work th:nth-child(1){width:38%}.work th:nth-child(2){width:14%}.work th:nth-child(3){width:38%}.work th:nth-child(4){width:10%}
.file code{white-space:normal;overflow-wrap:anywhere}.action{font-weight:700}.note{background:#fff8d6;border:1px solid #d5a400;padding:10px}
.attention{background:#fff4e5;border-left:4px solid #d98a00;padding:8px 12px;margin:8px 0 16px}.quiet{color:#666}.ok{color:#176b22;font-weight:700}
.scope{margin-left:20px}code{font-family:Consolas,monospace;overflow-wrap:anywhere}details{margin:18px 0}
"""
    out = ["<!doctype html><html><head><meta charset='utf-8'><title>MSB Folder Alignment Worklist</title>", f"<style>{css}</style></head><body>"]
    out.append("<h1>MSB Folder Alignment Worklist</h1>")
    out.append("<p class='note'><strong>READ-ONLY.</strong> Work one Stage at a time. Review each legacy file, then move it only when the suggested destination is correct.</p>")

    stage_ids = sorted(set(scopes_by_stage) | set(legacy_by_stage) | set(scope_issues))
    for sid in stage_ids:
        stage_scopes = scopes_by_stage.get(sid, [])
        stage_scope = next((s for s in stage_scopes if s.scope_type == "STAGE"), None)
        stage_name = stage_scope.scope_name if stage_scope else f"Stage {sid}"
        out.append(f"<h2>Stage {html.escape(sid)} — {html.escape(stage_name)}</h2>")

        stage_legacy = legacy_by_stage.get(sid, [])
        scope_items: dict[str, list[LegacyFile]] = defaultdict(list)
        stage_items: list[LegacyFile] = []
        for item in stage_legacy:
            matched = match_legacy_scope(item.path.name, stage_scopes)
            if matched:
                scope_items[str(matched.path).casefold()].append(item)
            else:
                stage_items.append(item)

        def render_table(items: list[LegacyFile], default_scope: Scope | None):
            if not items:
                out.append("<p class='quiet'>No legacy files found.</p>")
                return
            out.append("<table class='work'><tr><th>Legacy file</th><th>What to do</th><th>Suggested destination</th><th></th></tr>")
            for item in items:
                matched = match_legacy_scope(item.path.name, stage_scopes)
                target = matched or default_scope
                branch = legacy_branch(item)
                if branch and target:
                    action = "Review → Move"
                    destination = rel(target.path / "Procedures" / branch / "Archive", root)
                else:
                    action = "Review"
                    destination = "Destination unclear"
                out.append("<tr>" +
                           f"<td class='file'><code>{html.escape(item.path.name)}</code></td>" +
                           f"<td class='action'>{html.escape(action)}</td>" +
                           f"<td><code>{html.escape(destination)}</code></td>" +
                           f"<td>{file_link(item.path)}</td></tr>")
            out.append("</table>")

        out.append("<h3>Stage-level files</h3>")
        render_table(stage_items, stage_scope)

        ordered = sorted([s for s in stage_scopes if s.scope_type != "STAGE"], key=lambda s: (0 if s.scope_type == "SUB_STAGE" else 1, str(s.path).casefold()))
        for scope in ordered:
            label = "Sub-stage" if scope.scope_type == "SUB_STAGE" else "Scene"
            out.append(f"<div class='scope'><h3>{label} — {html.escape(scope.scope_name)}</h3>")
            render_table(scope_items.get(str(scope.path).casefold(), []), scope)
            out.append("</div>")

        issues = list(scope_issues.get(sid, []))
        for scope in stage_scopes:
            missing = missing_contract(scope)
            if missing:
                label = "Stage" if scope.scope_type == "STAGE" else ("Sub-stage" if scope.scope_type == "SUB_STAGE" else "Scene")
                issues.append(f"<strong>{html.escape(label)} {html.escape(scope.scope_name)}:</strong> missing <code>{html.escape(', '.join(missing))}</code>.")
        if issues:
            out.append("<div class='attention'><h3>Needs attention</h3><ul>")
            out.extend(f"<li>{x}</li>" for x in issues)
            out.append("</ul></div>")
        else:
            out.append("<p class='ok'>Folder check: OK</p>")

    if unassigned:
        out.append(f"<details><summary><strong>Legacy files not assigned to a Stage ({len(unassigned)})</strong></summary>")
        out.append("<table class='work'><tr><th>Legacy file</th><th>What to do</th><th>Current location</th><th></th></tr>")
        for item in unassigned:
            out.append("<tr>" + f"<td class='file'><code>{html.escape(item.path.name)}</code></td>" + "<td class='action'>Review</td>" + f"<td><code>{html.escape(rel(item.path, root))}</code></td>" + f"<td>{file_link(item.path)}</td></tr>")
        out.append("</table></details>")

    out.append("<details><summary><strong>Technical information</strong></summary>")
    out.append(f"<p>Script version: {VERSION}<br>SQLite: <code>{html.escape(str(db))}</code><br>CSV: <code>{html.escape(str(csv_path))}</code></p>")
    if provenance:
        out.append("<p>" + "; ".join(f"{html.escape(str(k))}={html.escape(str(v))}" for k, v in provenance.items() if v) + "</p>")
    out.append("</details></body></html>")
    html_path.write_text("".join(out), encoding="utf-8")
    return html_path, csv_path


def main() -> int:
    args = parse_args()
    if not args.db.is_file():
        raise SystemExit(f"[ERROR] SQLite file not found: {args.db}")
    if not args.drive_root.is_dir():
        raise SystemExit(f"[ERROR] Drive root not found: {args.drive_root}")

    print(f"[INFO] Folder Alignment {VERSION}", flush=True)
    print(f"[INFO] SQLite: {args.db}", flush=True)
    print(f"[INFO] Drive root: {args.drive_root}", flush=True)

    with sqlite3.connect(args.db) as conn:
        previews, scene_infos, provenance = load_scene_info(conn)

    stages, dirs_by_stage, direct_by_stage = inventory_drive(args.drive_root)
    scopes, scope_issues = resolve_scopes(args.drive_root, stages, dirs_by_stage, direct_by_stage, scene_infos)
    _legacy_root, legacy_by_stage, unassigned = scan_legacy(args.drive_root)

    html_path, csv_path = write_reports(
        args.output_dir, args.drive_root, args.db, previews, scopes, scope_issues,
        legacy_by_stage, unassigned, provenance,
    )
    print(f"[INFO] HTML: {html_path}", flush=True)
    print(f"[INFO] CSV: {csv_path}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
