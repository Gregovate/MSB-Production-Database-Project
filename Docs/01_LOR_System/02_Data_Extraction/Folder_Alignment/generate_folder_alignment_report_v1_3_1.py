#!/usr/bin/env python3
r"""V1.3.1 test patch for MSB Folder Alignment.

This patch preserves the top-level Stage identity while allowing a Master
Musical Preview BackgroundFile to identify a more specific documentation root
beneath that Stage.

Example:
    G:\Shared drives\Display Folders\07-Whoville-WV\
      07a-Who Forest-WF\Wiring\MusicalStage\WhoForest-Tagged.jpg

resolves as:
    Stage = 07-Whoville-WV
    Documentation root = 07-Whoville-WV\07a-Who Forest-WF
"""
from __future__ import annotations

from collections import defaultdict
from dataclasses import replace
from pathlib import Path, PureWindowsPath

import generate_folder_alignment_report as base

base.VERSION = "V1.3.1"


def documentation_root_from_background(background_file: str, stage: Path) -> Path | None:
    r"""Return the existing path immediately above \Wiring\ inside the Stage."""
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

    candidate = Path(str(PureWindowsPath(*parts[:wiring_index])))

    try:
        stage_text = str(stage.resolve()).casefold()
        candidate_text = str(candidate.resolve()).casefold()
    except OSError:
        stage_text = str(stage).casefold()
        candidate_text = str(candidate).casefold()

    if candidate_text == stage_text:
        return stage

    prefix = stage_text.rstrip("\\/") + "\\"
    if candidate_text.startswith(prefix) and candidate.is_dir():
        return candidate

    return None


def build_musical_contexts(scene_infos, stage_folders):
    """Map a parsed Master Musical Scene to Stage and documentation root."""
    result = {}
    for info in scene_infos:
        if not info.is_master_musical:
            continue

        stage, method = base.resolve_scene_stage(info, stage_folders)
        if stage is None:
            continue

        doc_root = documentation_root_from_background(info.background_file, stage) or stage
        result[(info.scene_stage_id, info.scene_name)] = (stage, doc_root, method)

    return result


def audit(root: Path, previews, scenes, displays, scene_infos):
    """Run V1.3.0, then apply the corrected nested musical documentation scope."""
    findings, helpers = base._audit_v130(root, previews, scenes, displays, scene_infos)

    stage_folders, _stage_by_name, candidates, _direct = base.inventory_drive(root)
    stage_path_to_id = {
        str(paths[0]).casefold(): sid
        for sid, paths in stage_folders.items()
        if len(paths) == 1
    }
    musical = build_musical_contexts(scene_infos, stage_folders)

    # Replace Master Musical group rows with the BackgroundFile-derived
    # documentation root while retaining the real top-level Stage identity.
    revised_findings = []
    for finding in findings:
        if finding.kind != "MUSICAL_GROUP":
            revised_findings.append(finding)
            continue

        matched = None
        for (scene_stage_id, scene_name), value in musical.items():
            if scene_name == finding.lor_name:
                stage, doc_root, method = value
                sid = stage_path_to_id.get(str(stage).casefold(), finding.stage_id)
                if sid == finding.stage_id:
                    matched = (stage, doc_root, method)
                    break

        if matched is None:
            revised_findings.append(finding)
            continue

        stage, doc_root, method = matched
        stage_rel = base.rel(stage, root)
        doc_rel = base.rel(doc_root, root)
        nested = doc_root != stage

        revised_findings.append(replace(
            finding,
            current_path=doc_rel,
            recommended_name=doc_root.name,
            recommended_parent=stage_rel,
            recommended_path=doc_rel,
            status="DOCUMENTATION_SCOPE" if nested else "STAGE_SCOPE",
            confidence="HIGH",
            action="NONE",
            note=(
                f"{method}. Top-level Stage remains {stage.name}; "
                + (
                    f"BackgroundFile resolves nested documentation root {doc_rel}."
                    if nested
                    else "BackgroundFile resolves to the Stage documentation root."
                )
            ),
        ))

    # Add one helper roadmap entry for each unique nested musical documentation
    # root so Setup is checked under the sub-stage rather than only Stage root.
    existing_helper_roots = {
        (sid, str(ctx.base_path).casefold())
        for sid, contexts in helpers.items()
        for ctx in contexts
    }
    for _key, (stage, doc_root, _method) in musical.items():
        if doc_root == stage:
            continue

        sid = stage_path_to_id.get(str(stage).casefold())
        if not sid:
            continue

        helper_key = (sid, str(doc_root).casefold())
        if helper_key in existing_helper_roots:
            continue

        helpers.setdefault(sid, []).append(base.helper_context(
            root,
            sid,
            "SUB-STAGE",
            doc_root.name,
            doc_root,
            "Master Musical BackgroundFile documentation root",
        ))
        existing_helper_roots.add(helper_key)

    # Correct Display recommendation parents for Displays that belong to one
    # Master Musical Scene whose BackgroundFile points at a nested documentation
    # root. Existing candidate matching remains the V1.3.0 logic.
    display_scope = {}
    for d in displays:
        if len(d.scenes) != 1:
            continue
        context = musical.get((d.stage_id, d.scenes[0]))
        if context is not None:
            display_scope[d.name] = context

    final_findings = []
    for finding in revised_findings:
        if finding.kind != "DISPLAY" or finding.lor_name not in display_scope:
            final_findings.append(finding)
            continue

        stage, doc_root, method = display_scope[finding.lor_name]
        sid = stage_path_to_id.get(str(stage).casefold(), finding.stage_id)
        rec_parent = base.rel(doc_root, root)
        rec_path = f"{rec_parent}\\{finding.lor_name}"

        current = finding.current_path
        status = finding.status
        action = finding.action
        note = finding.note

        if current:
            current_path = root / current
            target_path = root / rec_path
            if current_path == target_path:
                status = "MATCH"
                action = "NONE"

        note = f"{note}; documentation scope resolved from Master Musical BackgroundFile ({method})"

        final_findings.append(replace(
            finding,
            stage_id=sid,
            recommended_parent=rec_parent,
            recommended_path=rec_path,
            status=status,
            action=action,
            note=note,
        ))

    return final_findings, helpers


# Keep the original V1.3.0 implementation available, then replace only audit().
base._audit_v130 = base.audit
base.audit = audit

if __name__ == "__main__":
    raise SystemExit(base.main())
