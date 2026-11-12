#!/usr/bin/env python3
"""V1.3.3 test patch for MSB Folder Alignment.

Adds a second, independent legacy source scan for a central 000-Instructions
repository directly beneath the Display Folders root.  Files are inventoried
recursively and associated to a Stage when the filename begins with a two-digit
Stage number.  No files or folders are changed.
"""
from __future__ import annotations

import html
import os
import re
from collections import defaultdict
from pathlib import Path

import generate_folder_alignment_report_v1_3_2 as patch

base = patch.base
base.VERSION = "V1.3.3"

_original_audit = base.audit
_original_write_reports = base.write_reports

CENTRAL_LEGACY_NAME = "000instructions"
STAGE_FILE_RE = re.compile(r"^\s*(?P<stage>\d{2})(?:[A-Za-z])?(?=[\s._-]|$)")


def find_central_legacy_root(root: Path) -> Path | None:
    """Find a top-level Display Folders child named 000-Instructions."""
    try:
        matches = [
            p for p in root.iterdir()
            if p.is_dir() and base.norm(p.name) == CENTRAL_LEGACY_NAME
        ]
    except OSError:
        return None
    return matches[0] if len(matches) == 1 else None


def central_legacy_inventory(root: Path):
    """Return (legacy_root, files_by_stage, unassigned_files)."""
    legacy_root = find_central_legacy_root(root)
    by_stage: dict[str, list[tuple[Path, str]]] = defaultdict(list)
    unassigned: list[tuple[Path, str]] = []

    if legacy_root is None:
        return None, dict(by_stage), unassigned

    try:
        for current, _dirs, files in os.walk(legacy_root):
            current_path = Path(current)
            for filename in files:
                path = current_path / filename
                try:
                    relative = path.relative_to(legacy_root)
                    category = relative.parts[0] if len(relative.parts) > 1 else "Central root"
                except ValueError:
                    category = "Central root"

                match = STAGE_FILE_RE.match(filename)
                if match:
                    sid = match.group("stage")
                    by_stage[sid].append((path, category))
                else:
                    unassigned.append((path, category))
    except OSError:
        pass

    for sid in by_stage:
        by_stage[sid].sort(key=lambda item: str(item[0]).casefold())
    unassigned.sort(key=lambda item: str(item[0]).casefold())
    return legacy_root, dict(by_stage), unassigned


def audit(root: Path, previews, scenes, displays, scene_infos):
    findings, helpers = _original_audit(root, previews, scenes, displays, scene_infos)
    legacy_root, by_stage, _unassigned = central_legacy_inventory(root)

    if legacy_root is None:
        return findings, helpers

    for sid, items in sorted(by_stage.items()):
        for path, category in items:
            findings.append(base.Finding(
                sid,
                "LEGACY_INSTRUCTION",
                path.name,
                base.rel(path, root),
                "",
                "",
                "",
                "LEGACY_SOURCE",
                "HIGH",
                "REVIEW_MIGRATION",
                f"Central 000-Instructions source; category: {category}; "
                "associated to Stage by leading two-digit filename prefix. "
                "Preserve original path until reviewed."
            ))

    return findings, helpers


def _file_link(path: Path, label: str) -> str:
    href = base.file_href(path)
    if not href:
        return html.escape(label)
    return f"<a href='{html.escape(href, quote=True)}'>{html.escape(label)}</a>"


def write_reports(output: Path, root: Path, db: Path, previews, findings, helpers, provenance):
    html_path, csv_path, counts = _original_write_reports(
        output, root, db, previews, findings, helpers, provenance
    )

    legacy_root, by_stage, unassigned = central_legacy_inventory(root)
    text = html_path.read_text(encoding="utf-8")

    # Clarify that the V1.3.2 block is the local-scope search.
    text = text.replace(
        "<h3>Legacy 000-Instructions Scan</h3>",
        "<h3>Local Legacy 000-Instructions Scan</h3>",
        1,
    )

    if legacy_root is None:
        central_html = (
            "<div class='roadmap'><h3>Central Legacy 000-Instructions Repository</h3>"
            "<p><strong>No single top-level <code>000-Instructions</code> folder was found "
            "directly beneath the Display Folders root.</strong></p></div>"
        )
    else:
        assigned_count = sum(len(v) for v in by_stage.values())
        central_html = (
            "<div class='roadmap'><h3>Central Legacy 000-Instructions Repository</h3>"
            f"<p><strong>Source:</strong> <code>{html.escape(str(legacy_root))}</code> &nbsp; "
            f"{_file_link(legacy_root, 'Open Central Legacy Folder')}</p>"
            "<p>The repository was scanned recursively. A file is associated to a Stage only "
            "when its filename begins with that two-digit Stage number. Association is discovery "
            "evidence only; this report does not move or rename anything.</p>"
            f"<p><strong>{assigned_count}</strong> file(s) were associated to Stages; "
            f"<strong>{len(unassigned)}</strong> file(s) did not have a recognized leading Stage number.</p>"
            "</div>"
        )

    marker = "<h2>Summary</h2>"
    if marker in text:
        text = text.replace(marker, central_html + marker, 1)

    for sid, items in sorted(by_stage.items()):
        stage_marker = f"<h2>Stage {html.escape(sid)}</h2>"
        if stage_marker not in text:
            continue
        rows = []
        for path, category in items:
            rows.append(
                "<tr>"
                f"<td>{html.escape(category)}</td>"
                f"<td><code>{html.escape(path.name)}</code></td>"
                f"<td><code>{html.escape(base.rel(path, root))}</code></td>"
                f"<td>{_file_link(path, 'Open File')}</td>"
                "</tr>"
            )
        stage_html = (
            "<div class='legacy'><h3>Central Legacy Instructions for this Stage</h3>"
            "<p>These files were found recursively under the central <code>000-Instructions</code> "
            "repository and matched to this Stage by the leading two-digit filename prefix.</p>"
            "<table><tr><th>Legacy Category</th><th>File</th><th>Original Path</th><th>Open</th></tr>"
            + "".join(rows) + "</table></div>"
        )
        text = text.replace(stage_marker, stage_marker + stage_html, 1)

    if legacy_root is not None and unassigned:
        rows = "".join(
            "<tr>"
            f"<td>{html.escape(category)}</td>"
            f"<td><code>{html.escape(path.name)}</code></td>"
            f"<td><code>{html.escape(base.rel(path, root))}</code></td>"
            "</tr>"
            for path, category in unassigned
        )
        unassigned_html = (
            "<details><summary><strong>Central Legacy Files Without a Stage Prefix "
            f"({len(unassigned)})</strong></summary>"
            "<table><tr><th>Legacy Category</th><th>File</th><th>Original Path</th></tr>"
            + rows + "</table></details>"
        )
        text = text.replace("</body>", unassigned_html + "</body>", 1)

    html_path.write_text(text, encoding="utf-8")
    return html_path, csv_path, counts


base.audit = audit
base.write_reports = write_reports

if __name__ == "__main__":
    raise SystemExit(base.main())
