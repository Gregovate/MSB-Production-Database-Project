#!/usr/bin/env python3
"""V1.3.1 test patch for MSB Folder Alignment.

This patch layers the corrected Master Musical Preview documentation-root
resolution over V1.3.0 without changing the read-only behavior.

The top-level Stage remains the Stage identity.  For Master Musical Preview
Scenes, BackgroundFile may identify a more specific documentation root under
that Stage.  Example:

    G:\Shared drives\Display Folders\07-Whoville-WV\
      07a-Who Forest-WF\Wiring\MusicalStage\WhoForest-Tagged.jpg

resolves as:
    Stage = 07-Whoville-WV
    Documentation root = 07-Whoville-WV\07a-Who Forest-WF
"""
from __future__ import annotations

import importlib.util
from collections import defaultdict
from pathlib import Path, PureWindowsPath

HERE = Path(__file__).resolve().parent
BASE_PATH = HERE / "generate_folder_alignment_report.py"

spec = importlib.util.spec_from_file_location("folder_alignment_v130", BASE_PATH)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Could not load base Folder Alignment script: {BASE_PATH}")
base = importlib.util.module_from_spec(spec)
spec.loader.exec_module(base)

base.VERSION = "V1.3.1"


def documentation_root_from_background(background_file: str, stage: Path) -> Path | None:
    """Return the existing path immediately above \Wiring\ within the resolved Stage.

    BackgroundFile is a Windows path stored by LOR.  The path may point directly
    under the Stage Wiring folder or under a nested sub-stage/Scene Wiring folder.
    The returned documentation root must remain inside the already-resolved
    top-level Stage and must exist on disk.
    """
    if not background_file:
        return None
    try:
        bg = PureWindowsPath(background_file)
    except (TypeError, ValueError):
        return None

    parts = list(bg.parts)
    wiring_indexes = [i for i, part in enumerate(parts) if base.norm(part) == "wiring"]
    if not wiring_indexes:
        return None

    wiring_index = wiring_indexes[-1]
    if wiring_index <= 0:
        return None

    candidate_win = PureWindowsPath(*parts[:wiring_index])
    candidate = Path(str(candidate_win))

    # On Windows the stored G: path and Path string compare naturally.  Resolve
    # only when possible; mapped-drive paths may not always support resolve().
    try:
        stage_norm = str(stage.resolve()).casefold()
        candidate_norm = str(candidate.resolve()).casefold()
    except OSError:
        stage_norm = str(stage).casefold()
        candidate_norm = str(candidate).casefold()

    if candidate_norm == stage_norm:
        return stage
    prefix = stage_norm.rstrip("\\/") + "\\"
    if not candidate_norm.startswith(prefix):
        return None
    if candidate.is_dir():
        return candidate
    return None


def resolve_scene_context(info, stage_folders):
    """Resolve (top-level Stage, documentation root, resolution note)."""
    stage, method = base.resolve_scene_stage(info, stage_folders)
    if stage is None:
        return None, None, method

    if info.is_master_musical:
        doc_root = documentation_root_from_background(info.background_file, stage)
        if doc_root is not None:
            if doc_root == stage:
                return stage, stage, f"{method}; BackgroundFile documentation root is Stage"
            return stage, doc_root, f"{method}; BackgroundFile documentation root is nested under Stage"
        return stage, stage, f"{method}; no more-specific BackgroundFile documentation root"

    return stage, stage, method


def audit(root: Path, previews, scenes, displays, scene_infos):
    stage_folders, _stage_by_name, candidates, direct = base.inventory_drive(root)
    findings = []
    helpers = defaultdict(list)
    stage_path_to_id = {}
    for sid, paths in stage_folders.items():
        if len(paths) == 1:
            stage_path_to_id[str(paths[0]).casefold()] = sid

    # (Stage, documentation root, resolution method, is musical)
    scene_resolution = {}
    for info in scene_infos:
        stage, doc_root, method = resolve_scene_context(info, stage_folders)
        scene_resolution[(info.scene_stage_id, info.scene_name)] = (
            stage, doc_root, method, info.is_master_musical
        )

    used_stage_ids = set(previews)
    for stage, _doc_root, _method, _musical in scene_resolution.values():
        if stage is not None:
            sid = stage_path_to_id.get(str(stage).casefold())
            if sid:
                used_stage_ids.add(sid)

    for sid in sorted(used_stage_ids):
        sm = stage_folders.get(sid, [])
        if len(sm) == 0:
            findings.append(base.Finding(
                sid, "STAGE", sid, "", sid, str(root), str(root / sid),
                "MISSING", "", "CREATE_STAGE_REVIEW",
                "No Stage folder with this StageID was found."
            ))
            continue
        if len(sm) > 1:
            findings.append(base.Finding(
                sid, "STAGE", sid, "; ".join(base.rel(p, root) for p in sm),
                sid, str(root), "", "AMBIGUOUS", "", "REVIEW_MULTIPLE",
                "More than one Stage folder has this StageID."
            ))
            continue

        stage = sm[0]
        findings.append(base.Finding(
            sid, "STAGE", sid, base.rel(stage, root), stage.name, str(root),
            base.rel(stage, root), "MATCH", "HIGH", "NONE",
            "Stage matched by top-level two-digit StageID."
        ))
        helpers[sid].append(base.helper_context(
            root, sid, "STAGE", stage.name, stage, "Top-level Stage folder"
        ))

    added_helper_roots = set()

    for info in scene_infos:
        stage, doc_root, method, is_musical = scene_resolution[
            (info.scene_stage_id, info.scene_name)
        ]
        if stage is None or doc_root is None:
            findings.append(base.Finding(
                info.scene_stage_id or "?", "SCENE", info.scene_name, "",
                info.scene_name, "", "", "SCENE_STAGE_REVIEW", "",
                "REVIEW", f"{method}; no top-level Stage could be resolved."
            ))
            continue

        sid = stage_path_to_id.get(str(stage).casefold(), info.scene_stage_id)
        stage_rel = base.rel(stage, root)
        doc_rel = base.rel(doc_root, root)

        if is_musical:
            nested = doc_root != stage
            status = "DOCUMENTATION_SCOPE" if nested else "STAGE_SCOPE"
            scope_label = "nested documentation root" if nested else "Stage root"
            findings.append(base.Finding(
                sid, "MUSICAL_GROUP", info.scene_name, doc_rel,
                doc_root.name, stage_rel, doc_rel, status,
                "HIGH", "NONE",
                f"{method}. Master Musical Scene resolves to the top-level Stage, "
                f"with {scope_label} from BackgroundFile when available."
            ))

            if nested:
                helper_key = (sid, str(doc_root).casefold())
                if helper_key not in added_helper_roots:
                    helpers[sid].append(base.helper_context(
                        root, sid, "SUB-STAGE", doc_root.name, doc_root,
                        "Master Musical BackgroundFile documentation root"
                    ))
                    added_helper_roots.add(helper_key)
            continue

        scene_path = base.find_scene_folder(info.scene_name, direct.get(sid, []))
        if scene_path is not None:
            findings.append(base.Finding(
                sid, "SCENE", info.scene_name, base.rel(scene_path, root),
                scene_path.name, stage_rel, base.rel(scene_path, root),
                "MATCH", "HIGH", "NONE",
                f"{method}; existing Scene folder matched."
            ))
            helpers[sid].append(base.helper_context(
                root, sid, "SCENE", info.scene_name, scene_path,
                "Existing Background Scene folder match"
            ))
        else:
            findings.append(base.Finding(
                sid, "SCENE", info.scene_name, "", info.scene_name,
                stage_rel, f"{stage_rel}\\{info.scene_name}",
                "SCENE_SCOPE_REVIEW", "", "REVIEW",
                f"{method}; no one-to-one existing Scene folder match. "
                "Review before creating or moving folders."
            ))

    display_findings = []
    candidate_usage = defaultdict(list)

    for d in displays:
        resolved_stage = None
        resolved_doc_root = None
        musical_scope = False
        resolution_note = ""

        if len(d.scenes) == 1:
            key = (d.stage_id, d.scenes[0])
            resolved_stage, resolved_doc_root, resolution_note, musical_scope = scene_resolution.get(
                key, (None, None, "Scene resolution not found", False)
            )

        if resolved_stage is None:
            sm = stage_folders.get(d.stage_id, [])
            if len(sm) == 1:
                resolved_stage = sm[0]
                resolved_doc_root = resolved_stage
                resolution_note = "StageID"
            elif len(d.scenes) > 1:
                display_findings.append(base.Finding(
                    d.stage_id, "DISPLAY", d.name, "", d.name,
                    "Multiple LOR Scenes", "", "REVIEW_MULTIPLE_SCENES", "",
                    "REVIEW", "Display appears in more than one LOR Scene: " + ", ".join(d.scenes)
                ))
                continue
            else:
                display_findings.append(base.Finding(
                    d.stage_id, "DISPLAY", d.name, "", d.name, "", "",
                    "BLOCKED", "", "REVIEW_STAGE",
                    "Top-level Stage could not be resolved."
                ))
                continue

        if resolved_doc_root is None:
            resolved_doc_root = resolved_stage

        sid = stage_path_to_id.get(str(resolved_stage).casefold(), d.stage_id)
        rec_parent = base.rel(resolved_doc_root, root)

        if len(d.scenes) == 1 and not musical_scope:
            scene_path = base.find_scene_folder(d.scenes[0], direct.get(sid, []))
            if scene_path is not None:
                rec_parent = base.rel(scene_path, root)

        rec_path = f"{rec_parent}\\{d.name}"
        matches = base.best_candidates(d.name, candidates.get(sid, []), "DISPLAY")

        if not matches:
            display_findings.append(base.Finding(
                sid, "DISPLAY", d.name, "", d.name, rec_parent, rec_path,
                "NO_FOLDER_MATCH", "", "REVIEW_FOLDER_NEED",
                f"No likely existing documentation folder was found. "
                f"Resolved by {resolution_note}. This does not mean a folder must be created."
            ))
            continue

        top = matches[0]
        current = base.rel(top.path, root)
        c = base.confidence(top.score)
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

        note = f"{top.reason}; resolved by {resolution_note}"
        if len(matches) > 1 and matches[1].score >= top.score - 0.04:
            status = "REVIEW_MULTIPLE"
            action = "REVIEW"
            note += "; competing candidates: " + "; ".join(
                f"{base.rel(x.path, root)} ({x.score:.2f})" for x in matches[1:]
            )

        idx = len(display_findings)
        display_findings.append(base.Finding(
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
            display_findings[idx] = base.Finding(
                f.stage_id, f.kind, f.lor_name, f.current_path, f.recommended_name,
                f.recommended_parent, f.recommended_path, "LIKELY_SHARED_GROUP",
                f.confidence, "REVIEW_SHARED_GROUP",
                (f.note + f"; {len(indexes)} LOR Displays point to this same historical folder").strip("; "),
            )

    findings.extend(display_findings)
    return findings, dict(helpers)


base.audit = audit

if __name__ == "__main__":
    raise SystemExit(base.main())
