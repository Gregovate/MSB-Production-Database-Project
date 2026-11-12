#!/usr/bin/env python3
"""V1.3.4 test patch for MSB Folder Alignment.

Corrects a report-classification problem where a Background Preview Scene name
that also matches a current Display could be promoted into a Scene documentation
scope. That promotion could incorrectly imply a Display-specific Procedures\Setup
folder.

Also adds review-only legacy-name hints for central 000-Instructions files using
loose name similarity within the already-resolved Stage. These hints are not
identity assertions and never move or rename anything.
"""
from __future__ import annotations

import html
import re
from collections import defaultdict
from pathlib import Path

import generate_folder_alignment_report_v1_3_3 as patch

base = patch.base
base.VERSION = "V1.3.4"

_original_audit = base.audit
_original_write_reports = base.write_reports


def _display_form(name: str) -> str:
    return base.compare_form(name, "DISPLAY")


def _scene_form(name: str) -> str:
    return base.compare_form(name, "SCENE")


def _display_like_scene_names(displays) -> dict[str, set[str]]:
    """Return normalized Background Scene names that also match a current Display."""
    by_stage: dict[str, set[str]] = defaultdict(set)
    for d in displays:
        by_stage[d.stage_id].add(_display_form(d.name))
    return by_stage


def audit(root: Path, previews, scenes, displays, scene_infos):
    findings, helpers = _original_audit(root, previews, scenes, displays, scene_infos)
    display_forms = _display_like_scene_names(displays)

    false_scene_keys: set[tuple[str, str]] = set()
    for info in scene_infos:
        if info.is_master_musical:
            continue
        sid = info.preview_stage_id or info.scene_stage_id
        if not sid:
            continue
        if _scene_form(info.scene_name) in display_forms.get(sid, set()):
            false_scene_keys.add((sid, info.scene_name.casefold()))

    if false_scene_keys:
        filtered_helpers = {}
        for sid, contexts in helpers.items():
            kept = []
            for ctx in contexts:
                if (
                    ctx.scope_type == "SCENE"
                    and (sid, ctx.scope_name.casefold()) in false_scene_keys
                ):
                    continue
                kept.append(ctx)
            filtered_helpers[sid] = kept
        helpers = filtered_helpers

        revised = []
        for f in findings:
            key = (f.stage_id, f.lor_name.casefold())
            if f.kind == "SCENE" and key in false_scene_keys:
                # Keep the LOR grouping visible in engineering detail, but do not
                # call it a documentation Scene or imply helper-folder creation.
                revised.append(base.Finding(
                    f.stage_id,
                    "BACKGROUND_GROUP",
                    f.lor_name,
                    f.current_path,
                    f.recommended_name,
                    f.recommended_parent,
                    f.current_path or f.recommended_path,
                    "DISPLAY_SCOPE",
                    "HIGH",
                    "NONE",
                    "Background Preview grouping name also matches a current LOR Display. "
                    "Treat the existing folder as Display scope; do not infer a Scene "
                    "documentation root or Display-specific Procedures\\Setup folder."
                ))
            else:
                revised.append(f)
        findings = revised

    return findings, helpers


def _legacy_subject(path: Path) -> str:
    """Remove two-digit Stage prefix and common Google shortcut extension."""
    name = path.name
    if name.casefold().endswith(".gdoc"):
        name = name[:-5]
    name = re.sub(r"^\s*\d{2}[A-Za-z]?\s*[-_.]*\s*", "", name)
    return name.strip()


def _legacy_display_hints(root: Path, findings):
    displays_by_stage: dict[str, list[str]] = defaultdict(list)
    legacy_by_stage: dict[str, list[Path]] = defaultdict(list)

    for f in findings:
        if f.kind == "DISPLAY":
            displays_by_stage[f.stage_id].append(f.lor_name)
        elif f.kind == "LEGACY_INSTRUCTION" and f.current_path:
            legacy_by_stage[f.stage_id].append(root / f.current_path)

    hints: dict[str, dict[str, tuple[str, float]]] = defaultdict(dict)
    for sid, files in legacy_by_stage.items():
        displays = displays_by_stage.get(sid, [])
        if not displays:
            continue
        for path in files:
            subject = _legacy_subject(path)
            scored = []
            for display in displays:
                score, _reason = base.score_name(display, subject, "DISPLAY")
                scored.append((score, display))
            scored.sort(reverse=True)
            if scored and scored[0][0] >= 0.55:
                score, display = scored[0]
                hints[sid][str(path).casefold()] = (display, score)
    return hints


def write_reports(output: Path, root: Path, db: Path, previews, findings, helpers, provenance):
    html_path, csv_path, counts = _original_write_reports(
        output, root, db, previews, findings, helpers, provenance
    )

    hints = _legacy_display_hints(root, findings)
    text = html_path.read_text(encoding="utf-8")

    # Neutralize any inherited wording that might imply all subordinate scopes
    # require a Setup folder. Stage-level facts remain untouched.
    text = text.replace(
        "<span class='missing'>Setup folder missing</span>: expected ",
        "<strong>No Procedures\\Setup folder at this documentation scope.</strong> Expected path if this scope is later approved for its own procedures: ",
    )

    # Add a review-only hint column to the central legacy tables. This is a
    # presentation enhancement only; no identity or migration decision is made.
    for sid, stage_hints in hints.items():
        stage_marker = f"<h2>Stage {html.escape(sid)}</h2>"
        if stage_marker not in text:
            continue

        # Locate this Stage's central legacy table and add one column header.
        start = text.find(stage_marker)
        next_stage = text.find("<h2>Stage ", start + len(stage_marker))
        end = next_stage if next_stage != -1 else len(text)
        segment = text[start:end]
        table_marker = "<table><tr><th>Legacy Category</th><th>File</th><th>Original Path</th><th>Open</th></tr>"
        if table_marker not in segment:
            continue

        segment = segment.replace(
            table_marker,
            "<table><tr><th>Legacy Category</th><th>File</th><th>Original Path</th>"
            "<th>Possible Current Display</th><th>Open</th></tr>",
            1,
        )

        # Rows are generated by V1.3.3. Insert a hint cell before the Open cell
        # by matching each legacy file's displayed relative path.
        for path_key, (display, score) in stage_hints.items():
            path = Path(path_key)
            # path_key is casefolded absolute text, so locate by filename instead.
            filename = path.name
            if not filename:
                continue
            row_file = f"<td><code>{html.escape(filename)}</code></td>"
            pos = segment.casefold().find(row_file.casefold())
            if pos == -1:
                continue
            row_end = segment.find("</tr>", pos)
            if row_end == -1:
                continue
            open_cell = segment.rfind("<td>", pos, row_end)
            if open_cell == -1:
                continue
            label = (
                f"<td>{html.escape(display)} "
                f"<small>(review-only similarity {score:.2f})</small></td>"
            )
            segment = segment[:open_cell] + label + segment[open_cell:]

        text = text[:start] + segment + text[end:]

    text = text.replace(
        "<h3>Central Legacy Instructions for this Stage</h3>",
        "<h3>Central Legacy Files Associated With This Stage</h3>",
    )
    text = text.replace(
        "These files were found recursively under the central <code>000-Instructions</code> repository and matched to this Stage by the leading two-digit filename prefix.",
        "These historical files were found recursively under the central <code>000-Instructions</code> repository and associated with this Stage by the leading two-digit filename prefix. The legacy category or filename does not prove the file is a current procedure or identify its final destination.",
    )

    html_path.write_text(text, encoding="utf-8")
    return html_path, csv_path, counts


base.audit = audit
base.write_reports = write_reports

if __name__ == "__main__":
    raise SystemExit(base.main())
