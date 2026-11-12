#!/usr/bin/env python3
"""Read-only LOR vs Google Drive Stage/Scene/Display alignment report.

Windows V1.0.1. Designed for Google Drive for Desktop mounted as G:.
The Drive is inventoried once; no folder is created, moved, renamed, or deleted.
"""
from __future__ import annotations

import argparse
import csv
import html
import os
import re
import sqlite3
import sys
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

VERSION = "V1.0.1"
DEFAULT_DB = Path(r"G:\Shared drives\MSB Database\database\lor_output_v7_scene.db")
DEFAULT_ROOT = Path(r"G:\Shared drives\Display Folders")
DEFAULT_OUTPUT = Path(r"G:\Shared drives\MSB Database\Database Previews V6.6.4\reports\google-drive-alignment")
STAGE_RE = re.compile(r"^(?P<stage>\d{2}[A-Za-z]?)-")
RESERVED = {"photos", "procedures", "wiring", "sourcedocs", "historical", "archive", "archives"}


@dataclass(frozen=True)
class ExpectedDisplay:
    stage_id: str
    name: str
    scenes: tuple[str, ...]


@dataclass(frozen=True)
class Finding:
    stage_id: str
    kind: str
    name: str
    expected_parent: str
    status: str
    found_path: str
    note: str


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
    return conn.execute("SELECT 1 FROM sqlite_master WHERE lower(name)=lower(?)", (obj,)).fetchone() is not None


def load_expected(conn: sqlite3.Connection):
    if not exists(conn, "previews") or not exists(conn, "props"):
        raise RuntimeError("This is not a current V7 LOR SQLite snapshot (previews/props missing).")

    pc = cols(conn, "previews")
    prc = cols(conn, "props")
    p_id = pick(pc, "id", "PreviewID", "PreviewId")
    p_stage = pick(pc, "StageID", "StageId")
    p_name = pick(pc, "Name", "PreviewName")
    pr_prev = pick(prc, "PreviewId", "PreviewID")
    pr_disp = pick(prc, "LORComment", "DisplayName", "Display_Name")
    if not all((p_id, p_stage, p_name, pr_prev, pr_disp)):
        raise RuntimeError("Could not resolve current previews/props columns.")

    previews: dict[str, list[str]] = defaultdict(list)
    for sid, name in conn.execute(
        f"SELECT DISTINCT {qi(p_stage)}, {qi(p_name)} FROM previews "
        f"WHERE NULLIF(TRIM({qi(p_stage)}),'') IS NOT NULL ORDER BY 1,2"
    ):
        key = stage_key(str(sid))
        if name and str(name) not in previews[key]:
            previews[key].append(str(name))

    stage_displays: dict[str, set[str]] = defaultdict(set)
    sql = f"SELECT DISTINCT v.{qi(p_stage)}, p.{qi(pr_disp)} FROM props p JOIN previews v ON v.{qi(p_id)}=p.{qi(pr_prev)} WHERE NULLIF(TRIM(v.{qi(p_stage)}),'') IS NOT NULL AND NULLIF(TRIM(p.{qi(pr_disp)}),'') IS NOT NULL"
    for sid, display in conn.execute(sql):
        stage_displays[stage_key(str(sid))].add(str(display).strip())

    scenes: dict[str, dict[str, set[str]]] = defaultdict(lambda: defaultdict(set))
    if not exists(conn, "scene_displays_vw"):
        raise RuntimeError("Current snapshot does not contain scene_displays_vw; run the current V7 parser first.")

    sc = cols(conn, "scene_displays_vw")
    s_stage = pick(sc, "SceneStageID", "StageID", "StageId")
    s_name = pick(sc, "SceneName", "Name")
    s_disp = pick(sc, "DisplayName", "Display_Name", "LORComment")
    if not all((s_stage, s_name, s_disp)):
        raise RuntimeError("Could not resolve columns in scene_displays_vw.")

    scene_sql = f"SELECT DISTINCT {qi(s_stage)}, {qi(s_name)}, {qi(s_disp)} FROM scene_displays_vw WHERE NULLIF(TRIM({qi(s_stage)}),'') IS NOT NULL AND NULLIF(TRIM({qi(s_name)}),'') IS NOT NULL AND NULLIF(TRIM({qi(s_disp)}),'') IS NOT NULL ORDER BY 1,2,3"
    display_scenes: dict[tuple[str, str], set[str]] = defaultdict(set)
    for sid, scene, display in conn.execute(scene_sql):
        key = stage_key(str(sid))
        scene_name = str(scene).strip()
        display_name = str(display).strip()
        scenes[key][scene_name].add(display_name)
        display_scenes[(key, display_name)].add(scene_name)

    all_stages = set(previews) | set(stage_displays) | set(scenes)
    displays: list[ExpectedDisplay] = []
    for sid in sorted(all_stages):
        names = set(stage_displays.get(sid, set()))
        for values in scenes.get(sid, {}).values():
            names.update(values)
        for name in sorted(names, key=str.casefold):
            displays.append(ExpectedDisplay(sid, name, tuple(sorted(display_scenes.get((sid, name), set()), key=str.casefold))))

    provenance = {}
    if exists(conn, "parser_run"):
        c = cols(conn, "parser_run")
        row = conn.execute("SELECT * FROM parser_run ORDER BY rowid DESC LIMIT 1").fetchone()
        if row:
            provenance = {c[i]: "" if row[i] is None else str(row[i]) for i in range(len(c))}

    return dict(previews), {k: dict(v) for k, v in scenes.items()}, displays, provenance


def rel(path: Path, root: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def inventory_drive(root: Path, expected_stage_ids: set[str]):
    print("[INFO] Reading Stage folders from Google Drive...", flush=True)
    stages: dict[str, list[Path]] = defaultdict(list)
    for child in root.iterdir():
        if child.is_dir():
            m = STAGE_RE.match(child.name)
            if m:
                stages[stage_key(m.group("stage"))].append(child)

    index: dict[str, dict[str, list[Path]]] = {}
    direct: dict[str, dict[str, list[Path]]] = {}
    for n, sid in enumerate(sorted(expected_stage_ids), 1):
        matches = stages.get(sid, [])
        if len(matches) != 1:
            continue
        stage = matches[0]
        print(f"[INFO] Scanning Stage {sid} ({n}/{len(expected_stage_ids)}): {stage.name}", flush=True)
        name_index: dict[str, list[Path]] = defaultdict(list)
        direct_index: dict[str, list[Path]] = defaultdict(list)

        try:
            for child in stage.iterdir():
                if child.is_dir() and child.name.casefold() not in RESERVED:
                    direct_index[norm(child.name)].append(child)
        except OSError:
            pass

        try:
            for current, dirs, _files in os.walk(stage):
                current_path = Path(current)
                dirs[:] = [d for d in dirs if d.casefold() not in RESERVED]
                if current_path == stage:
                    continue
                name_index[norm(current_path.name)].append(current_path)
        except OSError:
            pass

        index[sid] = dict(name_index)
        direct[sid] = dict(direct_index)

    print("[INFO] Google Drive inventory complete.", flush=True)
    return dict(stages), index, direct


def audit(root: Path, previews, scenes, displays):
    expected_stage_ids = set(previews) | set(scenes) | {d.stage_id for d in displays}
    stage_folders, index, direct = inventory_drive(root, expected_stage_ids)
    findings: list[Finding] = []
    scene_paths: dict[tuple[str, str], Path | None] = {}

    for sid in sorted(expected_stage_ids):
        sm = stage_folders.get(sid, [])
        if len(sm) == 0:
            findings.append(Finding(sid, "STAGE", sid, str(root), "MISSING", "", "No Stage folder with this StageID was found."))
            continue
        if len(sm) > 1:
            findings.append(Finding(sid, "STAGE", sid, str(root), "AMBIGUOUS", "; ".join(rel(p, root) for p in sm), "More than one Stage folder has this StageID."))
            continue
        stage = sm[0]
        findings.append(Finding(sid, "STAGE", sid, str(root), "MATCH", rel(stage, root), ""))

        for scene in sorted(scenes.get(sid, {}), key=str.casefold):
            dm = direct.get(sid, {}).get(norm(scene), [])
            if len(dm) == 1:
                scene_paths[(sid, scene)] = dm[0]
                findings.append(Finding(sid, "SCENE", scene, rel(stage, root), "MATCH", rel(dm[0], root), ""))
            elif len(dm) > 1:
                scene_paths[(sid, scene)] = None
                findings.append(Finding(sid, "SCENE", scene, rel(stage, root), "AMBIGUOUS", "; ".join(rel(p, root) for p in dm), "Duplicate direct Scene folder matches."))
            else:
                allm = index.get(sid, {}).get(norm(scene), [])
                if len(allm) == 1:
                    scene_paths[(sid, scene)] = allm[0]
                    findings.append(Finding(sid, "SCENE", scene, rel(stage, root), "WRONG_LOCATION", rel(allm[0], root), "Scene exists below the Stage but is not directly under it."))
                elif len(allm) > 1:
                    scene_paths[(sid, scene)] = None
                    findings.append(Finding(sid, "SCENE", scene, rel(stage, root), "AMBIGUOUS", "; ".join(rel(p, root) for p in allm), "More than one possible Scene folder match."))
                else:
                    scene_paths[(sid, scene)] = None
                    findings.append(Finding(sid, "SCENE", scene, rel(stage, root), "MISSING", "", "LOR Scene has no matching folder under the Stage."))

    for d in displays:
        sm = stage_folders.get(d.stage_id, [])
        if len(sm) != 1:
            findings.append(Finding(d.stage_id, "DISPLAY", d.name, "", "BLOCKED", "", "Stage folder is missing or ambiguous."))
            continue
        stage = sm[0]
        allm = index.get(d.stage_id, {}).get(norm(d.name), [])

        if len(d.scenes) > 1:
            findings.append(Finding(d.stage_id, "DISPLAY", d.name, "Multiple LOR Scenes", "AMBIGUOUS", "; ".join(rel(p, root) for p in allm), "Display appears in more than one LOR Scene: " + ", ".join(d.scenes)))
            continue

        if len(d.scenes) == 1:
            scene = d.scenes[0]
            sp = scene_paths.get((d.stage_id, scene))
            expected_parent = f"{rel(stage, root)}\\{scene}"
            if sp is not None:
                try:
                    dm = [p for p in sp.iterdir() if p.is_dir() and norm(p.name) == norm(d.name)]
                except OSError:
                    dm = []
                if len(dm) == 1:
                    findings.append(Finding(d.stage_id, "DISPLAY", d.name, rel(sp, root), "MATCH", rel(dm[0], root), ""))
                    continue
            if len(allm) == 1:
                findings.append(Finding(d.stage_id, "DISPLAY", d.name, expected_parent, "WRONG_LOCATION", rel(allm[0], root), f"LOR places this Display in Scene '{scene}'."))
            elif len(allm) > 1:
                findings.append(Finding(d.stage_id, "DISPLAY", d.name, expected_parent, "AMBIGUOUS", "; ".join(rel(p, root) for p in allm), "More than one possible Display folder match."))
            else:
                findings.append(Finding(d.stage_id, "DISPLAY", d.name, expected_parent, "MISSING", "", f"LOR places this Display in Scene '{scene}'."))
            continue

        dm = direct.get(d.stage_id, {}).get(norm(d.name), [])
        if len(dm) == 1:
            findings.append(Finding(d.stage_id, "DISPLAY", d.name, rel(stage, root), "MATCH", rel(dm[0], root), ""))
        elif len(dm) > 1:
            findings.append(Finding(d.stage_id, "DISPLAY", d.name, rel(stage, root), "AMBIGUOUS", "; ".join(rel(p, root) for p in dm), "Duplicate direct Display folder matches."))
        elif len(allm) == 1:
            findings.append(Finding(d.stage_id, "DISPLAY", d.name, rel(stage, root), "WRONG_LOCATION", rel(allm[0], root), "LOR does not assign this Display to a Scene."))
        elif len(allm) > 1:
            findings.append(Finding(d.stage_id, "DISPLAY", d.name, rel(stage, root), "AMBIGUOUS", "; ".join(rel(p, root) for p in allm), "More than one possible Display folder match."))
        else:
            findings.append(Finding(d.stage_id, "DISPLAY", d.name, rel(stage, root), "MISSING", "", "LOR does not assign this Display to a Scene."))

    return findings


def write_reports(output: Path, root: Path, db: Path, previews, scenes, findings):
    output.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    csv_path = output / f"lor-google-drive-alignment-{stamp}.csv"
    html_path = output / f"lor-google-drive-alignment-{stamp}.html"

    with csv_path.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(["stage_id", "entity_type", "expected_name", "expected_parent", "status", "found_path", "note"])
        for x in findings:
            w.writerow([x.stage_id, x.kind, x.name, x.expected_parent, x.status, x.found_path, x.note])

    by_stage: dict[str, list[Finding]] = defaultdict(list)
    counts: dict[str, int] = defaultdict(int)
    for x in findings:
        by_stage[x.stage_id].append(x)
        counts[x.status] += 1

    esc = lambda v: html.escape(str(v or ""))
    parts = ["<!doctype html><html><head><meta charset='utf-8'><title>LOR / Google Drive Alignment</title><style>body{font-family:Segoe UI,Arial;margin:24px;color:#222}table{border-collapse:collapse;width:100%;margin:10px 0 28px}th,td{border:1px solid #ccc;padding:7px;text-align:left;vertical-align:top}th{background:#eee}.MATCH{background:#edf8ed}.MISSING{background:#fff0f0}.WRONG_LOCATION{background:#fff7e6}.AMBIGUOUS,.BLOCKED{background:#f3efff}code{font-family:Consolas,monospace}.warn{padding:10px;background:#fff8d6;border:1px solid #d5a400}</style></head><body>"]
    parts.append("<h1>LOR Stage / Scene / Display — Google Drive Alignment Report</h1><p class='warn'><strong>READ-ONLY AUDIT.</strong> No Google Drive folders were changed.</p>")
    parts.append(f"<p><strong>Version:</strong> {VERSION}<br><strong>Generated:</strong> {esc(datetime.now().astimezone())}<br><strong>SQLite:</strong> <code>{esc(db)}</code><br><strong>Drive:</strong> <code>{esc(root)}</code></p>")
    parts.append("<h2>Summary</h2><p>" + " &nbsp; ".join(f"<strong>{s}:</strong> {counts.get(s,0)}" for s in ["MATCH","MISSING","WRONG_LOCATION","AMBIGUOUS","BLOCKED"]) + "</p>")
    for sid in sorted(by_stage):
        parts.append(f"<h2>Stage {esc(sid)}</h2>")
        if previews.get(sid):
            parts.append("<p><strong>LOR Preview(s):</strong> " + "; ".join(esc(v) for v in previews[sid]) + "</p>")
        if scenes.get(sid):
            parts.append("<p><strong>LOR Scenes:</strong> " + "; ".join(esc(v) for v in sorted(scenes[sid], key=str.casefold)) + "</p>")
        parts.append("<table><tr><th>Type</th><th>LOR Name</th><th>Expected Parent</th><th>Status</th><th>Found</th><th>Notes</th></tr>")
        order={"STAGE":0,"SCENE":1,"DISPLAY":2}
        for x in sorted(by_stage[sid], key=lambda z:(order.get(z.kind,9),z.expected_parent.casefold(),z.name.casefold())):
            parts.append(f"<tr class='{esc(x.status)}'><td>{esc(x.kind)}</td><td>{esc(x.name)}</td><td><code>{esc(x.expected_parent)}</code></td><td><strong>{esc(x.status)}</strong></td><td><code>{esc(x.found_path)}</code></td><td>{esc(x.note)}</td></tr>")
        parts.append("</table>")
    parts.append("</body></html>")
    html_path.write_text("".join(parts), encoding="utf-8")
    return html_path, csv_path, counts


def main() -> int:
    ap = argparse.ArgumentParser(description="Read-only LOR vs Google Drive folder alignment audit")
    ap.add_argument("--db", type=Path, default=DEFAULT_DB)
    ap.add_argument("--drive-root", type=Path, default=DEFAULT_ROOT)
    ap.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    args = ap.parse_args()

    print(f"[INFO] LOR / Google Drive Alignment {VERSION}", flush=True)
    print(f"[INFO] SQLite: {args.db}", flush=True)
    print(f"[INFO] Drive:  {args.drive_root}", flush=True)
    if not args.db.is_file():
        print(f"[ERROR] SQLite snapshot not found: {args.db}", file=sys.stderr)
        return 2
    if not args.drive_root.is_dir():
        print(f"[ERROR] Google Drive root not found: {args.drive_root}", file=sys.stderr)
        return 3

    try:
        print("[INFO] Reading current LOR snapshot...", flush=True)
        uri = args.db.resolve().as_uri() + "?mode=ro"
        with sqlite3.connect(uri, uri=True) as conn:
            previews, scenes, displays, _provenance = load_expected(conn)
        print(f"[INFO] LOR snapshot loaded: {len(previews)} Stage IDs, {sum(len(v) for v in scenes.values())} Scenes, {len(displays)} Displays", flush=True)
        findings = audit(args.drive_root, previews, scenes, displays)
        print("[INFO] Writing reports...", flush=True)
        hp, cp, counts = write_reports(args.output_dir, args.drive_root, args.db, previews, scenes, findings)
    except KeyboardInterrupt:
        print("\n[STOPPED] Audit cancelled by user. No folders were changed.", file=sys.stderr)
        return 130
    except (sqlite3.Error, RuntimeError, OSError) as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 4

    print("[INFO] " + " | ".join(f"{s}={counts.get(s,0)}" for s in ["MATCH","MISSING","WRONG_LOCATION","AMBIGUOUS","BLOCKED"]), flush=True)
    print(f"[INFO] HTML: {hp}", flush=True)
    print(f"[INFO] CSV:  {cp}", flush=True)
    print("[INFO] Read-only audit complete. No Google Drive folders were changed.", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
