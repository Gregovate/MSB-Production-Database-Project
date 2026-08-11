#!/usr/bin/env python3
"""Read-only LOR vs Google Shared Drive documentation alignment report.

Windows V1.2.0. Uses the current parser SQLite output as the LOR source of truth.
Google Drive is inventoried read-only; no folder or document is created, moved,
renamed, or deleted.
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
from difflib import SequenceMatcher
from pathlib import Path

VERSION = "V1.2.0"
DEFAULT_DB = Path(r"G:\Shared drives\MSB Database\database\lor_output_v7_scene.db")
DEFAULT_ROOT = Path(r"G:\Shared drives\Display Folders")
DEFAULT_OUTPUT = Path(r"G:\Shared drives\MSB Database\Database Previews V6.6.4\reports\google-drive-alignment")
STAGE_RE = re.compile(r"^(?P<stage>\d{2}[A-Za-z]?)-")

INFRA_ROOTS = {"photos", "procedures", "wiring"}
PRUNE_EXACT = {
    "sourcedocs", "corelautopreserve", "obsolete", "archive", "archives",
    "historical", "debug", "templates", "libraries", "workspaces",
}
LEGACY_INSTRUCTION_NAMES = {"000instructions", "000instruction"}


@dataclass(frozen=True)
class ExpectedDisplay:
    stage_id: str
    name: str
    scenes: tuple[str, ...]


@dataclass(frozen=True)
class Candidate:
    path: Path
    score: float
    reason: str


@dataclass(frozen=True)
class Finding:
    stage_id: str
    kind: str
    lor_name: str
    current_path: str
    recommended_name: str
    recommended_parent: str
    recommended_path: str
    status: str
    confidence: str
    action: str
    note: str


@dataclass
class HelperContext:
    stage_id: str
    scope_type: str
    scope_name: str
    base_path: Path
    setup_path: Path
    setup_exists: bool
    published_files: list[Path]
    legacy_instruction_dirs: list[Path]
    legacy_files: list[Path]


def norm(value: str | None) -> str:
    return re.sub(r"[^a-z0-9]+", "", (value or "").casefold())


def words(value: str | None) -> list[str]:
    s = (value or "").strip()
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", s)
    s = re.sub(r"[^A-Za-z0-9]+", " ", s)
    return [x.casefold() for x in s.split() if x]


def stage_key(value: str | None) -> str:
    value = (value or "").strip().casefold()
    m = re.fullmatch(r"(\d{1,2})([a-z]?)", value)
    return f"{int(m.group(1)):02d}{m.group(2)}" if m else value


def strip_display_stage_code(value: str) -> str:
    return re.sub(r"^[A-Za-z]{2}-", "", value.strip(), count=1)


def strip_scene_stage_id(value: str) -> str:
    return re.sub(r"^\d{2}[A-Za-z]?-", "", value.strip(), count=1)


def compare_form(value: str, kind: str) -> str:
    if kind == "DISPLAY":
        value = strip_display_stage_code(value)
    elif kind == "SCENE":
        value = strip_scene_stage_id(value)
    return norm(value)


def token_set(value: str, kind: str) -> set[str]:
    if kind == "DISPLAY":
        value = strip_display_stage_code(value)
    elif kind == "SCENE":
        value = strip_scene_stage_id(value)
    return set(words(value))


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
    pr_type = pick(prc, "DeviceType", "Device_Type")
    if not all((p_id, p_stage, p_name, pr_prev, pr_disp, pr_type)):
        raise RuntimeError("Could not resolve current previews/props columns including DeviceType.")

    previews: dict[str, list[str]] = defaultdict(list)
    for sid, name in conn.execute(
        f"SELECT DISTINCT {qi(p_stage)}, {qi(p_name)} FROM previews "
        f"WHERE NULLIF(TRIM({qi(p_stage)}),'') IS NOT NULL ORDER BY 1,2"
    ):
        key = stage_key(str(sid))
        if name and str(name) not in previews[key]:
            previews[key].append(str(name))

    lor_names: set[str] = set()
    for (display,) in conn.execute(
        f"SELECT DISTINCT {qi(pr_disp)} FROM props "
        f"WHERE UPPER(TRIM(COALESCE({qi(pr_type)},'')))='LOR' "
        f"AND NULLIF(TRIM({qi(pr_disp)}),'') IS NOT NULL"
    ):
        lor_names.add(str(display).strip())
    lor_norm = {norm(x) for x in lor_names}

    if not exists(conn, "scene_displays_vw"):
        raise RuntimeError("Current snapshot does not contain scene_displays_vw; run the current V7 parser first.")

    sc = cols(conn, "scene_displays_vw")
    s_stage = pick(sc, "SceneStageID", "StageID", "StageId")
    s_name = pick(sc, "SceneName", "Name")
    s_disp = pick(sc, "DisplayName", "Display_Name", "LORComment")
    if not all((s_stage, s_name, s_disp)):
        raise RuntimeError("Could not resolve columns in scene_displays_vw.")

    scenes: dict[str, dict[str, set[str]]] = defaultdict(lambda: defaultdict(set))
    display_scenes: dict[tuple[str, str], set[str]] = defaultdict(set)
    scene_assigned_norms: set[str] = set()
    scene_sql = (
        f"SELECT DISTINCT {qi(s_stage)}, {qi(s_name)}, {qi(s_disp)} FROM scene_displays_vw "
        f"WHERE NULLIF(TRIM({qi(s_stage)}),'') IS NOT NULL "
        f"AND NULLIF(TRIM({qi(s_name)}),'') IS NOT NULL "
        f"AND NULLIF(TRIM({qi(s_disp)}),'') IS NOT NULL ORDER BY 1,2,3"
    )
    for sid, scene, display in conn.execute(scene_sql):
        display_name = str(display).strip()
        if norm(display_name) not in lor_norm:
            continue
        key = stage_key(str(sid))
        scene_name = str(scene).strip()
        scenes[key][scene_name].add(display_name)
        display_scenes[(key, display_name)].add(scene_name)
        scene_assigned_norms.add(norm(display_name))

    stage_displays: dict[str, set[str]] = defaultdict(set)
    sql = (
        f"SELECT DISTINCT v.{qi(p_stage)}, p.{qi(pr_disp)} FROM props p "
        f"JOIN previews v ON v.{qi(p_id)}=p.{qi(pr_prev)} "
        f"WHERE UPPER(TRIM(COALESCE(p.{qi(pr_type)},'')))='LOR' "
        f"AND NULLIF(TRIM(v.{qi(p_stage)}),'') IS NOT NULL "
        f"AND NULLIF(TRIM(p.{qi(pr_disp)}),'') IS NOT NULL"
    )
    for sid, display in conn.execute(sql):
        display_name = str(display).strip()
        if norm(display_name) in scene_assigned_norms:
            continue
        stage_displays[stage_key(str(sid))].add(display_name)

    all_stages = set(previews) | set(stage_displays) | set(scenes)
    displays: list[ExpectedDisplay] = []
    for sid in sorted(all_stages):
        names = set(stage_displays.get(sid, set()))
        for values in scenes.get(sid, {}).values():
            names.update(values)
        for name in sorted(names, key=str.casefold):
            displays.append(ExpectedDisplay(
                sid,
                name,
                tuple(sorted(display_scenes.get((sid, name), set()), key=str.casefold)),
            ))

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


def prune_branch(name: str) -> bool:
    n = norm(name)
    if n in PRUNE_EXACT:
        return True
    return n.startswith("archive") or n.startswith("archived")


def inventory_drive(root: Path, expected_stage_ids: set[str]):
    print("[INFO] Reading Stage folders from Google Drive...", flush=True)
    stages: dict[str, list[Path]] = defaultdict(list)
    for child in root.iterdir():
        if child.is_dir():
            m = STAGE_RE.match(child.name)
            if m:
                stages[stage_key(m.group("stage"))].append(child)

    candidates: dict[str, list[Path]] = defaultdict(list)
    direct: dict[str, list[Path]] = defaultdict(list)

    for n, sid in enumerate(sorted(expected_stage_ids), 1):
        matches = stages.get(sid, [])
        if len(matches) != 1:
            continue
        stage = matches[0]
        print(f"[INFO] Scanning Stage {sid} ({n}/{len(expected_stage_ids)}): {stage.name}", flush=True)

        try:
            for child in stage.iterdir():
                if child.is_dir() and norm(child.name) not in INFRA_ROOTS:
                    direct[sid].append(child)
        except OSError:
            pass

        try:
            for current, dirs, _files in os.walk(stage):
                current_path = Path(current)
                if current_path == stage:
                    dirs[:] = [d for d in dirs if norm(d) not in INFRA_ROOTS and not prune_branch(d)]
                    continue
                dirs[:] = [d for d in dirs if not prune_branch(d)]
                candidates[sid].append(current_path)
        except OSError:
            pass

    print("[INFO] Google Drive inventory complete.", flush=True)
    return dict(stages), dict(candidates), dict(direct)


def score_name(lor_name: str, folder_name: str, kind: str) -> tuple[float, str]:
    a = compare_form(lor_name, kind)
    b = compare_form(folder_name, kind)
    if not a or not b:
        return 0.0, ""
    if a == b:
        return 1.0, "normalized name match"

    seq = SequenceMatcher(None, a, b).ratio()
    ta = token_set(lor_name, kind)
    tb = token_set(folder_name, kind)
    jaccard = (len(ta & tb) / len(ta | tb)) if (ta or tb) else 0.0

    containment = 0.0
    shorter, longer = sorted((a, b), key=len)
    if len(shorter) >= 5 and shorter in longer:
        containment = min(0.92, 0.72 + 0.20 * (len(shorter) / len(longer)))

    score = max(seq, 0.55 * seq + 0.45 * jaccard, containment)
    return score, f"name similarity {score:.2f}"


def best_candidates(lor_name: str, paths: list[Path], kind: str, limit: int = 3) -> list[Candidate]:
    scored: list[Candidate] = []
    for p in paths:
        score, reason = score_name(lor_name, p.name, kind)
        if score >= 0.58:
            scored.append(Candidate(p, score, reason))
    scored.sort(key=lambda x: (-x.score, len(x.path.parts), str(x.path).casefold()))
    return scored[:limit]


def confidence(score: float) -> str:
    if score >= 0.93:
        return "HIGH"
    if score >= 0.78:
        return "MEDIUM"
    if score >= 0.65:
        return "LOW"
    return ""


def find_scene_folder(scene: str, direct_paths: list[Path]) -> Path | None:
    matches = best_candidates(scene, direct_paths, "SCENE")
    if matches and matches[0].score >= 0.93:
        return matches[0].path
    return None


def list_direct_files(folder: Path) -> list[Path]:
    if not folder.is_dir():
        return []
    try:
        return sorted([p for p in folder.iterdir() if p.is_file()], key=lambda p: p.name.casefold())
    except OSError:
        return []


def find_legacy_instruction_dirs(base: Path) -> list[Path]:
    found: list[Path] = []
    if not base.is_dir():
        return found
    try:
        for current, dirs, _files in os.walk(base):
            current_path = Path(current)
            for d in dirs:
                if norm(d) in LEGACY_INSTRUCTION_NAMES:
                    found.append(current_path / d)
    except OSError:
        pass
    return sorted(set(found), key=lambda p: str(p).casefold())


def list_recursive_files(folder: Path) -> list[Path]:
    files: list[Path] = []
    if not folder.is_dir():
        return files
    try:
        for current, _dirs, names in os.walk(folder):
            current_path = Path(current)
            for name in names:
                files.append(current_path / name)
    except OSError:
        pass
    return sorted(files, key=lambda p: str(p).casefold())


def build_helper_contexts(root: Path, scenes, stage_folders, direct) -> dict[str, list[HelperContext]]:
    result: dict[str, list[HelperContext]] = defaultdict(list)
    for sid in sorted(set(stage_folders) | set(scenes)):
        sm = stage_folders.get(sid, [])
        if len(sm) != 1:
            continue
        stage = sm[0]

        stage_setup = stage / "Procedures" / "Setup"
        stage_legacy = find_legacy_instruction_dirs(stage)
        result[sid].append(HelperContext(
            stage_id=sid,
            scope_type="STAGE",
            scope_name=stage.name,
            base_path=stage,
            setup_path=stage_setup,
            setup_exists=stage_setup.is_dir(),
            published_files=list_direct_files(stage_setup),
            legacy_instruction_dirs=stage_legacy,
            legacy_files=[f for d in stage_legacy for f in list_recursive_files(d)],
        ))

        for scene in sorted(scenes.get(sid, {}), key=str.casefold):
            scene_path = find_scene_folder(scene, direct.get(sid, []))
            if scene_path is None:
                scene_path = stage / scene
            scene_setup = scene_path / "Procedures" / "Setup"
            scene_legacy = find_legacy_instruction_dirs(scene_path) if scene_path.is_dir() else []
            result[sid].append(HelperContext(
                stage_id=sid,
                scope_type="SCENE",
                scope_name=scene,
                base_path=scene_path,
                setup_path=scene_setup,
                setup_exists=scene_setup.is_dir(),
                published_files=list_direct_files(scene_setup),
                legacy_instruction_dirs=scene_legacy,
                legacy_files=[f for d in scene_legacy for f in list_recursive_files(d)],
            ))
    return dict(result)


def audit(root: Path, previews, scenes, displays):
    expected_stage_ids = set(previews) | set(scenes) | {d.stage_id for d in displays}
    stage_folders, candidates, direct = inventory_drive(root, expected_stage_ids)
    findings: list[Finding] = []

    for sid in sorted(expected_stage_ids):
        sm = stage_folders.get(sid, [])
        if len(sm) == 0:
            findings.append(Finding(sid, "STAGE", sid, "", sid, str(root), str(root / sid), "MISSING", "", "CREATE_STAGE_REVIEW", "No Stage folder with this StageID was found."))
            continue
        if len(sm) > 1:
            findings.append(Finding(sid, "STAGE", sid, "; ".join(rel(p, root) for p in sm), sid, str(root), "", "AMBIGUOUS", "", "REVIEW_MULTIPLE", "More than one Stage folder has this StageID."))
            continue
        stage = sm[0]
        findings.append(Finding(sid, "STAGE", sid, rel(stage, root), stage.name, str(root), rel(stage, root), "MATCH", "HIGH", "NONE", "Stage matched by two-digit StageID."))

        for scene in sorted(scenes.get(sid, {}), key=str.casefold):
            rec_name = scene
            rec_parent = rel(stage, root)
            rec_path = f"{rec_parent}\\{rec_name}"
            matches = best_candidates(scene, direct.get(sid, []), "SCENE")
            if matches and matches[0].score >= 0.93:
                p = matches[0].path
                exact_name = p.name == rec_name
                status = "MATCH" if exact_name else "LIKELY_MATCH"
                action = "NONE" if exact_name else "RENAME"
                findings.append(Finding(sid, "SCENE", scene, rel(p, root), rec_name, rec_parent, rec_path, status, confidence(matches[0].score), action, matches[0].reason))
            elif matches and matches[0].score >= 0.78:
                p = matches[0].path
                findings.append(Finding(sid, "SCENE", scene, rel(p, root), rec_name, rec_parent, rec_path, "POSSIBLE_MATCH", confidence(matches[0].score), "REVIEW", matches[0].reason))
            else:
                findings.append(Finding(sid, "SCENE", scene, "", rec_name, rec_parent, rec_path, "MISSING", "", "CREATE_SCENE_FOLDER", "LOR Scene has no likely direct folder match under the Stage."))

    display_findings: list[Finding] = []
    candidate_usage: dict[str, list[int]] = defaultdict(list)

    for d in displays:
        sm = stage_folders.get(d.stage_id, [])
        rec_name = d.name
        if len(sm) != 1:
            display_findings.append(Finding(d.stage_id, "DISPLAY", d.name, "", rec_name, "", "", "BLOCKED", "", "REVIEW_STAGE", "Stage folder is missing or ambiguous."))
            continue
        stage = sm[0]

        if len(d.scenes) == 1:
            scene = d.scenes[0]
            rec_parent = f"{rel(stage, root)}\\{scene}"
            rec_path = f"{rec_parent}\\{rec_name}"
        elif len(d.scenes) > 1:
            rec_parent = "Multiple LOR Scenes"
            rec_path = ""
        else:
            rec_parent = rel(stage, root)
            rec_path = f"{rec_parent}\\{rec_name}"

        matches = best_candidates(d.name, candidates.get(d.stage_id, []), "DISPLAY")

        if len(d.scenes) > 1:
            current = rel(matches[0].path, root) if matches else ""
            display_findings.append(Finding(d.stage_id, "DISPLAY", d.name, current, rec_name, rec_parent, rec_path, "REVIEW_MULTIPLE_SCENES", confidence(matches[0].score) if matches else "", "REVIEW", "Display appears in more than one LOR Scene: " + ", ".join(d.scenes)))
            continue

        if not matches:
            display_findings.append(Finding(d.stage_id, "DISPLAY", d.name, "", rec_name, rec_parent, rec_path, "NO_FOLDER_MATCH", "", "REVIEW_FOLDER_NEED", "No likely existing documentation folder was found. This does not mean a folder must be created."))
            continue

        top = matches[0]
        current = rel(top.path, root)
        c = confidence(top.score)
        if top.score >= 0.93:
            status = "LIKELY_MATCH"
            action = "REVIEW_RENAME_OR_MOVE"
        elif top.score >= 0.78:
            status = "POSSIBLE_MATCH"
            action = "REVIEW"
        else:
            status = "WEAK_MATCH"
            action = "REVIEW"

        note = top.reason
        if len(matches) > 1 and matches[1].score >= top.score - 0.04:
            status = "REVIEW_MULTIPLE"
            action = "REVIEW"
            note += "; competing candidates: " + "; ".join(f"{rel(x.path, root)} ({x.score:.2f})" for x in matches[1:])

        idx = len(display_findings)
        display_findings.append(Finding(d.stage_id, "DISPLAY", d.name, current, rec_name, rec_parent, rec_path, status, c, action, note))
        if top.score >= 0.65:
            candidate_usage[current.casefold()].append(idx)

    for indexes in candidate_usage.values():
        if len(indexes) < 2:
            continue
        for idx in indexes:
            f = display_findings[idx]
            display_findings[idx] = Finding(
                f.stage_id, f.kind, f.lor_name, f.current_path, f.recommended_name,
                f.recommended_parent, f.recommended_path, "LIKELY_SHARED_GROUP",
                f.confidence, "REVIEW_SHARED_GROUP",
                (f.note + f"; {len(indexes)} LOR Displays point to this same historical folder").strip("; "),
            )

    findings.extend(display_findings)
    helpers = build_helper_contexts(root, scenes, stage_folders, direct)
    return findings, helpers


def file_href(path: Path) -> str:
    try:
        return path.resolve().as_uri()
    except (OSError, ValueError):
        return ""


def folder_link(path: Path, label: str = "Open Folder") -> str:
    href = file_href(path)
    if not href:
        return html.escape(label)
    return f"<a href='{html.escape(href, quote=True)}'>{html.escape(label)}</a>"


def render_file_list(paths: list[Path], root: Path) -> str:
    if not paths:
        return "<em>None found</em>"
    items = []
    for p in paths:
        href = file_href(p)
        label = html.escape(rel(p, root))
        if href:
            items.append(f"<li><a href='{html.escape(href, quote=True)}'>{label}</a></li>")
        else:
            items.append(f"<li>{label}</li>")
    return "<ul>" + "".join(items) + "</ul>"


def write_reports(output: Path, root: Path, db: Path, previews, scenes, findings, helpers, provenance):
    output.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    csv_path = output / f"lor-google-drive-alignment-{stamp}.csv"
    html_path = output / f"lor-google-drive-alignment-{stamp}.html"

    headers = [
        "stage_id", "entity_type", "lor_name", "current_path", "recommended_name",
        "recommended_parent", "recommended_path", "status", "confidence", "action", "note",
    ]
    with csv_path.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f)
        w.writerow(headers)
        for x in findings:
            w.writerow([
                x.stage_id, x.kind, x.lor_name, x.current_path, x.recommended_name,
                x.recommended_parent, x.recommended_path, x.status, x.confidence, x.action, x.note,
            ])

    by_stage: dict[str, list[Finding]] = defaultdict(list)
    counts: dict[str, int] = defaultdict(int)
    for x in findings:
        by_stage[x.stage_id].append(x)
        counts[x.status] += 1

    esc = lambda v: html.escape(str(v or ""))
    parts = ["<!doctype html><html><head><meta charset='utf-8'><title>MSB Documentation Alignment Worklist</title>"]
    parts.append("<style>body{font-family:Segoe UI,Arial;margin:24px;color:#222}table{border-collapse:collapse;width:100%;margin:10px 0 28px;font-size:13px}th,td{border:1px solid #ccc;padding:6px;text-align:left;vertical-align:top}th{background:#eee}.MATCH{background:#edf8ed}.MISSING,.NO_FOLDER_MATCH{background:#fff0f0}.LIKELY_MATCH,.LIKELY_SHARED_GROUP{background:#eef7ff}.POSSIBLE_MATCH,.WEAK_MATCH,.REVIEW_MULTIPLE,.REVIEW_MULTIPLE_SCENES,.BLOCKED{background:#fff7e6}code{font-family:Consolas,monospace}.warn{padding:10px;background:#fff8d6;border:1px solid #d5a400}.roadmap{padding:12px;border:2px solid #6a8fb3;background:#f7fbff;margin:14px 0}.ok{color:#176b22;font-weight:700}.missing{color:#a40000;font-weight:700}.legacy{background:#fff4e5;padding:8px;border-left:4px solid #d98a00}ul{margin-top:5px}</style></head><body>")
    parts.append("<h1>MSB Documentation Alignment Worklist</h1>")
    parts.append("<p class='warn'><strong>READ-ONLY.</strong> This is a roadmap generated from the current LOR parser snapshot and the current Google Shared Drive. It does not change any folders or documents. Regenerate it after LOR or folder changes.</p>")
    parts.append(f"<p><strong>Version:</strong> {VERSION}<br><strong>Generated:</strong> {esc(datetime.now().astimezone())}<br><strong>SQLite snapshot:</strong> <code>{esc(db)}</code><br><strong>Drive:</strong> <code>{esc(root)}</code></p>")
    if provenance:
        parts.append("<p><strong>Parser snapshot details:</strong> " + "; ".join(f"{esc(k)}={esc(v)}" for k, v in provenance.items() if v) + "</p>")
    parts.append("<h2>Summary</h2><p>" + " &nbsp; ".join(f"<strong>{esc(k)}:</strong> {v}" for k, v in sorted(counts.items())) + "</p>")

    for sid in sorted(by_stage):
        parts.append(f"<h2>Stage {esc(sid)}</h2>")
        if previews.get(sid):
            parts.append("<p><strong>LOR Preview(s):</strong> " + "; ".join(esc(v) for v in previews[sid]) + "</p>")
        if scenes.get(sid):
            parts.append("<p><strong>LOR Scenes:</strong> " + "; ".join(esc(v) for v in sorted(scenes[sid], key=str.casefold)) + "</p>")

        parts.append("<div class='roadmap'><h3>Documentation Roadmap</h3>")
        contexts = helpers.get(sid, [])
        if not contexts:
            parts.append("<p>No single Stage folder is available for helper-folder inventory.</p>")
        for ctx in contexts:
            parts.append(f"<h4>{esc(ctx.scope_type.title())}: {esc(ctx.scope_name)}</h4>")
            base_link_target = ctx.base_path if ctx.base_path.is_dir() else ctx.base_path.parent
            parts.append(f"<p><strong>Location:</strong> <code>{esc(rel(ctx.base_path, root))}</code> &nbsp; {folder_link(base_link_target)}</p>")
            if ctx.setup_exists:
                parts.append(f"<p><span class='ok'>Setup folder exists</span>: <code>{esc(rel(ctx.setup_path, root))}</code> &nbsp; {folder_link(ctx.setup_path, 'Open Setup Folder')}</p>")
            else:
                parts.append(f"<p><span class='missing'>Setup folder missing</span>: expected <code>{esc(rel(ctx.setup_path, root))}</code>. Open the nearest existing location: {folder_link(base_link_target)}</p>")
            parts.append(f"<p><strong>Published Setup Documents ({len(ctx.published_files)}):</strong></p>{render_file_list(ctx.published_files, root)}")
            if ctx.legacy_instruction_dirs:
                parts.append("<div class='legacy'><strong>Legacy Instructions Found</strong><br>")
                for d in ctx.legacy_instruction_dirs:
                    parts.append(f"<p><code>{esc(rel(d, root))}</code> &nbsp; {folder_link(d, 'Open Legacy Instructions')}</p>")
                parts.append(f"<p><strong>Legacy files ({len(ctx.legacy_files)}):</strong></p>{render_file_list(ctx.legacy_files, root)}</div>")
        parts.append("</div>")

        parts.append("<details><summary><strong>Stage / Scene / Display Alignment Detail</strong></summary>")
        parts.append("<table><tr><th>Type</th><th>LOR Name</th><th>Current Drive Path</th><th>Recommended Name</th><th>Recommended Location</th><th>Status</th><th>Confidence</th><th>Action</th><th>Notes</th></tr>")
        order = {"STAGE": 0, "SCENE": 1, "DISPLAY": 2}
        for x in sorted(by_stage[sid], key=lambda z: (order.get(z.kind, 9), z.lor_name.casefold())):
            current_html = f"<code>{esc(x.current_path)}</code>"
            if x.current_path:
                p = root / x.current_path
                if p.exists():
                    current_html += " &nbsp; " + folder_link(p)
            parts.append(
                f"<tr class='{esc(x.status)}'><td>{esc(x.kind)}</td><td>{esc(x.lor_name)}</td>"
                f"<td>{current_html}</td><td>{esc(x.recommended_name)}</td>"
                f"<td><code>{esc(x.recommended_path)}</code></td><td><strong>{esc(x.status)}</strong></td>"
                f"<td>{esc(x.confidence)}</td><td>{esc(x.action)}</td><td>{esc(x.note)}</td></tr>"
            )
        parts.append("</table></details>")
    parts.append("</body></html>")
    html_path.write_text("".join(parts), encoding="utf-8")
    return html_path, csv_path, counts


def main() -> int:
    ap = argparse.ArgumentParser(description="Read-only LOR vs Google Shared Drive documentation alignment audit")
    ap.add_argument("--db", type=Path, default=DEFAULT_DB)
    ap.add_argument("--drive-root", type=Path, default=DEFAULT_ROOT)
    ap.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    args = ap.parse_args()

    print(f"[INFO] MSB Documentation Alignment {VERSION}", flush=True)
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
            previews, scenes, displays, provenance = load_expected(conn)
        print(f"[INFO] LOR snapshot loaded: {len(previews)} Stage IDs, {sum(len(v) for v in scenes.values())} Scenes, {len(displays)} LOR Displays", flush=True)
        findings, helpers = audit(args.drive_root, previews, scenes, displays)
        print("[INFO] Writing reports...", flush=True)
        hp, cp, counts = write_reports(args.output_dir, args.drive_root, args.db, previews, scenes, findings, helpers, provenance)
    except KeyboardInterrupt:
        print("\n[STOPPED] Audit cancelled by user. No folders were changed.", file=sys.stderr)
        return 130
    except (sqlite3.Error, RuntimeError, OSError) as exc:
        print(f"[ERROR] {exc}", file=sys.stderr)
        return 4

    print("[INFO] " + " | ".join(f"{s}={n}" for s, n in sorted(counts.items())), flush=True)
    print(f"[INFO] HTML worklist: {hp}", flush=True)
    print(f"[INFO] CSV detail:    {cp}", flush=True)
    print("[INFO] Read-only audit complete. No Google Drive folders or documents were changed.", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
