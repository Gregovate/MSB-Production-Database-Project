#!/usr/bin/env python3
"""Read-only LOR vs Google Shared Drive documentation alignment report.

Windows V1.3.0. Uses the current parser SQLite output as the LOR source of truth.
Google Drive is inventoried read-only; no folder or document is created, moved,
renamed, or deleted.

V1.3 adds Preview-aware Stage resolution:
- Background Previews continue to use their Stage and Scene organization.
- Master Musical Preview scenes resolve to the real top-level Stage first.
- A Master Musical Scene name may identify the Stage directly.
- Otherwise the Scene BackgroundFile path may identify the top-level Stage folder.
- Musical Scene names are not automatically treated as child Drive folders.
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
from pathlib import Path, PureWindowsPath

VERSION = "V1.3.0"
DEFAULT_DB = Path(r"G:\Shared drives\MSB Database\database\lor_output_v7_scene.db")
DEFAULT_ROOT = Path(r"G:\Shared drives\Display Folders")
DEFAULT_OUTPUT = Path(r"G:\Shared drives\MSB Database\Database Previews V6.6.4\reports\google-drive-alignment")
STAGE_RE = re.compile(r"^(?P<stage>\d{2}[A-Za-z]?)-")
MASTER_MUSICAL_RE = re.compile(r"^\s*\d{4}\s+Master\s+Musical\s+Preview\b", re.IGNORECASE)

INFRA_ROOTS = {"photos", "procedures", "wiring"}
PRUNE_EXACT = {
    "sourcedocs", "corelautopreserve", "obsolete", "archive", "archives",
    "historical", "debug", "templates", "libraries", "workspaces",
}
LEGACY_INSTRUCTION_NAMES = {"000instructions", "000instruction"}


@dataclass(frozen=True)
class SceneInfo:
    preview_name: str
    preview_stage_id: str
    scene_stage_id: str
    scene_name: str
    background_file: str
    is_master_musical: bool


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
    resolution_method: str = ""


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
    return conn.execute(
        "SELECT 1 FROM sqlite_master WHERE lower(name)=lower(?)", (obj,)
    ).fetchone() is not None


def load_expected(conn: sqlite3.Connection):
    if not exists(conn, "previews") or not exists(conn, "props"):
        raise RuntimeError("This is not a current V7 LOR SQLite snapshot (previews/props missing).")
    if not exists(conn, "scenes") or not exists(conn, "scene_displays_vw"):
        raise RuntimeError("Current snapshot does not contain V7 scene data; run the current V7 parser first.")

    pc = cols(conn, "previews")
    prc = cols(conn, "props")
    scn = cols(conn, "scenes")
    vw = cols(conn, "scene_displays_vw")

    p_id = pick(pc, "id", "PreviewID", "PreviewId")
    p_stage = pick(pc, "StageID", "StageId")
    p_name = pick(pc, "Name", "PreviewName")
    pr_prev = pick(prc, "PreviewId", "PreviewID")
    pr_disp = pick(prc, "LORComment", "DisplayName", "Display_Name")
    pr_type = pick(prc, "DeviceType", "Device_Type")

    s_prev = pick(scn, "PreviewId", "PreviewID")
    s_stage = pick(scn, "StageID", "StageId")
    s_name = pick(scn, "Name", "SceneName")
    s_bg = pick(scn, "BackgroundFile")

    v_stage = pick(vw, "SceneStageID", "StageID", "StageId")
    v_name = pick(vw, "SceneName", "Name")
    v_disp = pick(vw, "DisplayName", "Display_Name", "LORComment")
    v_preview = pick(vw, "PreviewName")

    if not all((p_id, p_stage, p_name, pr_prev, pr_disp, pr_type)):
        raise RuntimeError("Could not resolve current previews/props columns including DeviceType.")
    if not all((s_prev, s_name, s_bg, v_stage, v_name, v_disp)):
        raise RuntimeError("Could not resolve current scene columns.")

    previews: dict[str, list[str]] = defaultdict(list)
    for sid, name in conn.execute(
        f"SELECT DISTINCT {qi(p_stage)}, {qi(p_name)} FROM previews "
        f"WHERE NULLIF(TRIM({qi(p_stage)}),'') IS NOT NULL ORDER BY 1,2"
    ):
        key = stage_key(str(sid))
        if name and str(name) not in previews[key]:
            previews[key].append(str(name))

    scene_infos: list[SceneInfo] = []
    scene_sql = (
        f"SELECT p.{qi(p_name)}, p.{qi(p_stage)}, s.{qi(s_stage)}, "
        f"s.{qi(s_name)}, s.{qi(s_bg)} "
        f"FROM scenes s JOIN previews p ON p.{qi(p_id)}=s.{qi(s_prev)} "
        f"WHERE NULLIF(TRIM(s.{qi(s_name)}),'') IS NOT NULL "
        f"ORDER BY p.{qi(p_name)}, s.{qi(s_name)}"
    )
    for preview_name, preview_stage, scene_stage, scene_name, bg in conn.execute(scene_sql):
        info = SceneInfo(
            preview_name="" if preview_name is None else str(preview_name).strip(),
            preview_stage_id="" if preview_stage is None else stage_key(str(preview_stage)),
            scene_stage_id="" if scene_stage is None else stage_key(str(scene_stage)),
            scene_name=str(scene_name).strip(),
            background_file="" if bg is None else str(bg).strip(),
            is_master_musical=bool(MASTER_MUSICAL_RE.search("" if preview_name is None else str(preview_name))),
        )
        scene_infos.append(info)

    lor_names: set[str] = set()
    for (display,) in conn.execute(
        f"SELECT DISTINCT {qi(pr_disp)} FROM props "
        f"WHERE UPPER(TRIM(COALESCE({qi(pr_type)},'')))='LOR' "
        f"AND NULLIF(TRIM({qi(pr_disp)}),'') IS NOT NULL"
    ):
        lor_names.add(str(display).strip())
    lor_norm = {norm(x) for x in lor_names}

    scenes: dict[str, dict[str, set[str]]] = defaultdict(lambda: defaultdict(set))
    display_scenes: dict[tuple[str, str], set[str]] = defaultdict(set)
    scene_assigned_norms: set[str] = set()

    preview_expr = qi(v_preview) if v_preview else "''"
    vw_sql = (
        f"SELECT DISTINCT {qi(v_stage)}, {qi(v_name)}, {qi(v_disp)}, {preview_expr} "
        f"FROM scene_displays_vw "
        f"WHERE NULLIF(TRIM({qi(v_stage)}),'') IS NOT NULL "
        f"AND NULLIF(TRIM({qi(v_name)}),'') IS NOT NULL "
        f"AND NULLIF(TRIM({qi(v_disp)}),'') IS NOT NULL ORDER BY 1,2,3"
    )
    for sid, scene, display, _preview in conn.execute(vw_sql):
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

    return dict(previews), {k: dict(v) for k, v in scenes.items()}, displays, scene_infos, provenance


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


def inventory_drive(root: Path):
    print("[INFO] Reading Stage folders from Google Drive...", flush=True)
    stages: dict[str, list[Path]] = defaultdict(list)
    by_name: dict[str, Path] = {}

    for child in root.iterdir():
        if not child.is_dir():
            continue
        m = STAGE_RE.match(child.name)
        if not m:
            continue
        stages[stage_key(m.group("stage"))].append(child)
        by_name[norm(child.name)] = child

    candidates: dict[str, list[Path]] = defaultdict(list)
    direct: dict[str, list[Path]] = defaultdict(list)

    for sid in sorted(stages):
        matches = stages[sid]
        if len(matches) != 1:
            continue
        stage = matches[0]
        print(f"[INFO] Scanning Stage {sid}: {stage.name}", flush=True)

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
                    dirs[:] = [
                        d for d in dirs
                        if norm(d) not in INFRA_ROOTS and not prune_branch(d)
                    ]
                    continue
                dirs[:] = [d for d in dirs if not prune_branch(d)]
                candidates[sid].append(current_path)
        except OSError:
            pass

    print("[INFO] Google Drive inventory complete.", flush=True)
    return dict(stages), by_name, dict(candidates), dict(direct)


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


def top_stage_from_background(background_file: str, stage_folders: dict[str, list[Path]]) -> Path | None:
    """Resolve only the top-level Stage folder from a stored Windows BackgroundFile path."""
    if not background_file:
        return None
    try:
        bg = PureWindowsPath(background_file)
    except (TypeError, ValueError):
        return None

    bg_parts = [norm(p) for p in bg.parts]
    for matches in stage_folders.values():
        if len(matches) != 1:
            continue
        stage = matches[0]
        if norm(stage.name) in bg_parts:
            return stage
    return None


def direct_stage_from_scene_name(scene_name: str, stage_folders: dict[str, list[Path]]) -> Path | None:
    """Exact normalized Stage-folder identity only; no fuzzy Stage inference."""
    target = norm(scene_name)
    matches = [
        paths[0] for paths in stage_folders.values()
        if len(paths) == 1 and norm(paths[0].name) == target
    ]
    return matches[0] if len(matches) == 1 else None


def resolve_scene_stage(
    info: SceneInfo,
    stage_folders: dict[str, list[Path]],
) -> tuple[Path | None, str]:
    """Resolve the real top-level Stage for one parsed Scene."""
    if info.is_master_musical:
        by_name = direct_stage_from_scene_name(info.scene_name, stage_folders)
        if by_name is not None:
            return by_name, "Master Musical Scene matches Stage folder"

        by_path = top_stage_from_background(info.background_file, stage_folders)
        if by_path is not None:
            return by_path, "Master Musical BackgroundFile path"

        sm = stage_folders.get(info.scene_stage_id, [])
        if len(sm) == 1:
            return sm[0], "SceneStageID fallback"
        return None, "Master Musical Stage unresolved"

    sid = info.preview_stage_id or info.scene_stage_id
    sm = stage_folders.get(sid, [])
    if len(sm) == 1:
        return sm[0], "Background Preview StageID"

    by_path = top_stage_from_background(info.background_file, stage_folders)
    if by_path is not None:
        return by_path, "BackgroundFile Stage fallback"
    return None, "Stage unresolved"


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


def helper_context(
    root: Path,
    stage_id: str,
    scope_type: str,
    scope_name: str,
    base_path: Path,
    resolution_method: str,
) -> HelperContext:
    setup_path = base_path / "Procedures" / "Setup"
    legacy = find_legacy_instruction_dirs(base_path)
    return HelperContext(
        stage_id=stage_id,
        scope_type=scope_type,
        scope_name=scope_name,
        base_path=base_path,
        setup_path=setup_path,
        setup_exists=setup_path.is_dir(),
        published_files=list_direct_files(setup_path),
        legacy_instruction_dirs=legacy,
        legacy_files=[f for d in legacy for f in list_recursive_files(d)],
        resolution_method=resolution_method,
    )


def audit(root: Path, previews, scenes, displays, scene_infos):
    stage_folders, _stage_by_name, candidates, direct = inventory_drive(root)
    findings: list[Finding] = []
    helpers: dict[str, list[HelperContext]] = defaultdict(list)
    stage_path_to_id: dict[str, str] = {}
    for sid, paths in stage_folders.items():
        if len(paths) == 1:
            stage_path_to_id[str(paths[0]).casefold()] = sid

    scene_resolution: dict[tuple[str, str], tuple[Path | None, str, bool]] = {}
    for info in scene_infos:
        stage, method = resolve_scene_stage(info, stage_folders)
        scene_resolution[(info.scene_stage_id, info.scene_name)] = (stage, method, info.is_master_musical)

    used_stage_ids: set[str] = set(previews)
    for stage, _method, _musical in scene_resolution.values():
        if stage is not None:
            sid = stage_path_to_id.get(str(stage).casefold())
            if sid:
                used_stage_ids.add(sid)

    for sid in sorted(used_stage_ids):
        sm = stage_folders.get(sid, [])
        if len(sm) == 0:
            findings.append(Finding(
                sid, "STAGE", sid, "", sid, str(root), str(root / sid),
                "MISSING", "", "CREATE_STAGE_REVIEW",
                "No Stage folder with this StageID was found."
            ))
            continue
        if len(sm) > 1:
            findings.append(Finding(
                sid, "STAGE", sid, "; ".join(rel(p, root) for p in sm),
                sid, str(root), "", "AMBIGUOUS", "", "REVIEW_MULTIPLE",
                "More than one Stage folder has this StageID."
            ))
            continue

        stage = sm[0]
        findings.append(Finding(
            sid, "STAGE", sid, rel(stage, root), stage.name, str(root),
            rel(stage, root), "MATCH", "HIGH", "NONE",
            "Stage matched by top-level two-digit StageID."
        ))
        helpers[sid].append(helper_context(
            root, sid, "STAGE", stage.name, stage, "Top-level Stage folder"
        ))

    for info in scene_infos:
        stage, method, is_musical = scene_resolution[(info.scene_stage_id, info.scene_name)]
        if stage is None:
            findings.append(Finding(
                info.scene_stage_id or "?", "SCENE", info.scene_name, "",
                info.scene_name, "", "", "SCENE_STAGE_REVIEW", "",
                "REVIEW", f"{method}; no top-level Stage could be resolved."
            ))
            continue

        sid = stage_path_to_id.get(str(stage).casefold(), info.scene_stage_id)
        stage_rel = rel(stage, root)

        if is_musical:
            findings.append(Finding(
                sid, "MUSICAL_GROUP", info.scene_name, stage_rel,
                stage.name, stage_rel, stage_rel, "STAGE_SCOPE",
                "HIGH", "NONE",
                f"{method}. Master Musical Scene is used to resolve Stage membership; "
                "it is not automatically a child Google Drive folder."
            ))
            continue

        scene_path = find_scene_folder(info.scene_name, direct.get(sid, []))
        if scene_path is not None:
            findings.append(Finding(
                sid, "SCENE", info.scene_name, rel(scene_path, root),
                scene_path.name, stage_rel, rel(scene_path, root),
                "MATCH", "HIGH", "NONE",
                f"{method}; existing Scene folder matched."
            ))
            helpers[sid].append(helper_context(
                root, sid, "SCENE", info.scene_name, scene_path,
                "Existing Background Scene folder match"
            ))
        else:
            findings.append(Finding(
                sid, "SCENE", info.scene_name, "", info.scene_name,
                stage_rel, f"{stage_rel}\\{info.scene_name}",
                "SCENE_SCOPE_REVIEW", "", "REVIEW",
                f"{method}; no one-to-one existing Scene folder match. "
                "Review before creating or moving folders."
            ))

    display_findings: list[Finding] = []
    candidate_usage: dict[str, list[int]] = defaultdict(list)

    for d in displays:
        resolved_stage: Path | None = None
        musical_scope = False
        resolution_note = ""

        if len(d.scenes) == 1:
            key = (d.stage_id, d.scenes[0])
            resolved_stage, resolution_note, musical_scope = scene_resolution.get(
                key, (None, "Scene resolution not found", False)
            )

        if resolved_stage is None:
            sm = stage_folders.get(d.stage_id, [])
            if len(sm) == 1:
                resolved_stage = sm[0]
                resolution_note = "StageID"
            elif len(d.scenes) > 1:
                display_findings.append(Finding(
                    d.stage_id, "DISPLAY", d.name, "", d.name,
                    "Multiple LOR Scenes", "", "REVIEW_MULTIPLE_SCENES", "",
                    "REVIEW", "Display appears in more than one LOR Scene: " + ", ".join(d.scenes)
                ))
                continue
            else:
                display_findings.append(Finding(
                    d.stage_id, "DISPLAY", d.name, "", d.name, "", "",
                    "BLOCKED", "", "REVIEW_STAGE",
                    "Top-level Stage could not be resolved."
                ))
                continue

        sid = stage_path_to_id.get(str(resolved_stage).casefold(), d.stage_id)
        stage_rel = rel(resolved_stage, root)

        rec_parent = stage_rel
        if len(d.scenes) == 1 and not musical_scope:
            scene_path = find_scene_folder(d.scenes[0], direct.get(sid, []))
            if scene_path is not None:
                rec_parent = rel(scene_path, root)

        rec_path = f"{rec_parent}\\{d.name}"
        matches = best_candidates(d.name, candidates.get(sid, []), "DISPLAY")

        if not matches:
            display_findings.append(Finding(
                sid, "DISPLAY", d.name, "", d.name, rec_parent, rec_path,
                "NO_FOLDER_MATCH", "", "REVIEW_FOLDER_NEED",
                f"No likely existing documentation folder was found. "
                f"Resolved Stage by {resolution_note}. This does not mean a folder must be created."
            ))
            continue

        top = matches[0]
        current = rel(top.path, root)
        c = confidence(top.score)

        target_path = root / rec_path
        if top.path == target_path:
            status = "MATCH"
            action = "NONE"
        elif top.score >= 0.93:
            status = "LIKELY_MATCH"
            action = "REVIEW_RENAME_OR_MOVE"
        elif top.score >= 0.78:
            status = "POSSIBLE_MATCH"
            action = "REVIEW"
        else:
            status = "WEAK_MATCH"
            action = "REVIEW"

        note = f"{top.reason}; Stage resolved by {resolution_note}"
        if len(matches) > 1 and matches[1].score >= top.score - 0.04:
            status = "REVIEW_MULTIPLE"
            action = "REVIEW"
            note += "; competing candidates: " + "; ".join(
                f"{rel(x.path, root)} ({x.score:.2f})" for x in matches[1:]
            )

        idx = len(display_findings)
        display_findings.append(Finding(
            sid, "DISPLAY", d.name, current, d.name, rec_parent,
            rec_path, status, c, action, note
        ))
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
    return findings, dict(helpers)


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


def write_reports(output: Path, root: Path, db: Path, previews, findings, helpers, provenance):
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
    parts.append(
        "<style>"
        "body{font-family:Segoe UI,Arial;margin:24px;color:#222}"
        "table{border-collapse:collapse;width:100%;margin:10px 0 28px;font-size:13px}"
        "th,td{border:1px solid #ccc;padding:6px;text-align:left;vertical-align:top}"
        "th{background:#eee}"
        ".MATCH,.STAGE_SCOPE{background:#edf8ed}"
        ".MISSING,.NO_FOLDER_MATCH{background:#fff0f0}"
        ".LIKELY_MATCH,.LIKELY_SHARED_GROUP{background:#eef7ff}"
        ".POSSIBLE_MATCH,.WEAK_MATCH,.REVIEW_MULTIPLE,.REVIEW_MULTIPLE_SCENES,"
        ".BLOCKED,.SCENE_SCOPE_REVIEW,.SCENE_STAGE_REVIEW{background:#fff7e6}"
        "code{font-family:Consolas,monospace}"
        ".warn{padding:10px;background:#fff8d6;border:1px solid #d5a400}"
        ".roadmap{padding:12px;border:2px solid #6a8fb3;background:#f7fbff;margin:14px 0}"
        ".ok{color:#176b22;font-weight:700}.missing{color:#a40000;font-weight:700}"
        ".legacy{background:#fff4e5;padding:8px;border-left:4px solid #d98a00}"
        "ul{margin-top:5px}</style></head><body>"
    )
    parts.append("<h1>MSB Documentation Alignment Worklist</h1>")
    parts.append(
        "<p class='warn'><strong>READ-ONLY.</strong> This is a roadmap generated from the current "
        "LOR parser snapshot and the current Google Shared Drive. It does not change any folders or "
        "documents. Regenerate it after LOR or folder changes.</p>"
    )
    parts.append(
        "<p><strong>V1.3 Preview rule:</strong> The root is always the top-level Stage. "
        "Background Preview Scenes may use established Scene folders for grouping. "
        "Master Musical Preview scenes resolve Stage membership first and are not automatically "
        "treated as child folders.</p>"
    )
    parts.append(
        f"<p><strong>Version:</strong> {VERSION}<br>"
        f"<strong>Generated:</strong> {esc(datetime.now().astimezone())}<br>"
        f"<strong>SQLite snapshot:</strong> <code>{esc(db)}</code><br>"
        f"<strong>Drive:</strong> <code>{esc(root)}</code></p>"
    )
    if provenance:
        parts.append(
            "<p><strong>Parser snapshot details:</strong> " +
            "; ".join(f"{esc(k)}={esc(v)}" for k, v in provenance.items() if v) +
            "</p>"
        )
    parts.append(
        "<h2>Summary</h2><p>" +
        " &nbsp; ".join(f"<strong>{esc(k)}:</strong> {v}" for k, v in sorted(counts.items())) +
        "</p>"
    )

    for sid in sorted(by_stage):
        parts.append(f"<h2>Stage {esc(sid)}</h2>")
        if previews.get(sid):
            parts.append(
                "<p><strong>Background/Stage Preview(s):</strong> " +
                "; ".join(esc(v) for v in previews[sid]) + "</p>"
            )

        parts.append("<div class='roadmap'><h3>Documentation Roadmap</h3>")
        contexts = helpers.get(sid, [])
        if not contexts:
            parts.append("<p>No single Stage folder is available for helper-folder inventory.</p>")
        for ctx in contexts:
            parts.append(f"<h4>{esc(ctx.scope_type.title())}: {esc(ctx.scope_name)}</h4>")
            if ctx.resolution_method:
                parts.append(f"<p><strong>Why this location:</strong> {esc(ctx.resolution_method)}</p>")
            base_link_target = ctx.base_path if ctx.base_path.is_dir() else ctx.base_path.parent
            parts.append(
                f"<p><strong>Location:</strong> <code>{esc(rel(ctx.base_path, root))}</code> "
                f"&nbsp; {folder_link(base_link_target)}</p>"
            )
            if ctx.setup_exists:
                parts.append(
                    f"<p><span class='ok'>Setup folder exists</span>: "
                    f"<code>{esc(rel(ctx.setup_path, root))}</code> &nbsp; "
                    f"{folder_link(ctx.setup_path, 'Open Setup Folder')}</p>"
                )
            else:
                parts.append(
                    f"<p><span class='missing'>Setup folder missing</span>: expected "
                    f"<code>{esc(rel(ctx.setup_path, root))}</code>. "
                    f"Open the nearest existing location: {folder_link(base_link_target)}</p>"
                )
            parts.append(
                f"<p><strong>Published Setup Documents ({len(ctx.published_files)}):</strong></p>"
                f"{render_file_list(ctx.published_files, root)}"
            )
            if ctx.legacy_instruction_dirs:
                parts.append("<div class='legacy'><strong>Legacy Instructions Found</strong><br>")
                for d in ctx.legacy_instruction_dirs:
                    parts.append(
                        f"<p><code>{esc(rel(d, root))}</code> &nbsp; "
                        f"{folder_link(d, 'Open Legacy Instructions')}</p>"
                    )
                parts.append(
                    f"<p><strong>Legacy files ({len(ctx.legacy_files)}):</strong></p>"
                    f"{render_file_list(ctx.legacy_files, root)}</div>"
                )
        parts.append("</div>")

        parts.append("<details><summary><strong>Stage / Group / Scene / Display Alignment Detail</strong></summary>")
        parts.append(
            "<table><tr><th>Type</th><th>LOR Name</th><th>Current Drive Path</th>"
            "<th>Recommended Name</th><th>Recommended Location</th><th>Status</th>"
            "<th>Confidence</th><th>Action</th><th>Notes</th></tr>"
        )
        order = {"STAGE": 0, "MUSICAL_GROUP": 1, "SCENE": 2, "DISPLAY": 3}
        for x in sorted(by_stage[sid], key=lambda z: (order.get(z.kind, 9), z.lor_name.casefold())):
            current_html = f"<code>{esc(x.current_path)}</code>"
            if x.current_path:
                p = root / x.current_path
                if p.exists():
                    current_html += " &nbsp; " + folder_link(p)
            parts.append(
                f"<tr class='{esc(x.status)}'><td>{esc(x.kind)}</td><td>{esc(x.lor_name)}</td>"
                f"<td>{current_html}</td><td>{esc(x.recommended_name)}</td>"
                f"<td><code>{esc(x.recommended_path)}</code></td>"
                f"<td><strong>{esc(x.status)}</strong></td>"
                f"<td>{esc(x.confidence)}</td><td>{esc(x.action)}</td><td>{esc(x.note)}</td></tr>"
            )
        parts.append("</table></details>")

    parts.append("</body></html>")
    html_path.write_text("".join(parts), encoding="utf-8")
    return html_path, csv_path, counts


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Read-only LOR vs Google Shared Drive documentation alignment audit"
    )
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
            previews, scenes, displays, scene_infos, provenance = load_expected(conn)

        master_count = sum(1 for s in scene_infos if s.is_master_musical)
        print(
            f"[INFO] LOR snapshot loaded: {len(previews)} Stage IDs, "
            f"{len(scene_infos)} parsed Scenes ({master_count} Master Musical), "
            f"{len(displays)} LOR Displays",
            flush=True,
        )
        findings, helpers = audit(args.drive_root, previews, scenes, displays, scene_infos)
        print("[INFO] Writing reports...", flush=True)
        hp, cp, counts = write_reports(
            args.output_dir, args.drive_root, args.db,
            previews, findings, helpers, provenance
        )
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