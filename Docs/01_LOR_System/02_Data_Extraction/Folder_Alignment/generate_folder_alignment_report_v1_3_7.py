#!/usr/bin/env python3
"""Folder Alignment V1.3.7 - validate the current Google Drive folder contract."""
from __future__ import annotations

import html
import sqlite3
from dataclasses import dataclass
from pathlib import Path

import generate_folder_alignment_report_v1_3_6 as previous
import update_previewbackground_folders as scope_source

base = previous.base
base.VERSION = "V1.3.7"
_original_write_reports = base.write_reports

STRUCTURED_REQUIRED = (
    "PreviewBackground", "Photos/Current", "Photos/Historical",
    "Procedures/Inspection", "Procedures/Setup/Archive",
    "Procedures/Setup/images", "Procedures/Setup/SourceDocs",
    "Procedures/Takedown/Archive", "Procedures/Takedown/images",
    "Procedures/Takedown/SourceDocs", "Wiring/BackgroundStage/SourceDocs",
    "Wiring/MusicalStage/SourceDocs",
)
DISPLAY_REQUIRED = ("PreviewBackground", "Photos/Current", "Photos/Historical")
LEGACY_PATHS = (
    "Procedures/Maintenance", "Procedures/Operations", "Procedures/SourceDocs",
    "Photos/Setup", "Photos/Takedown", "Photos/Reference",
)

@dataclass(frozen=True)
class ContractRow:
    scope_type: str
    stage_id: str
    scope_name: str
    scope_path: Path
    required_total: int
    present_total: int
    missing: tuple[str, ...]
    legacy_present: tuple[str, ...]
    status: str


def _exists(root: Path, rel: str) -> bool:
    return (root / Path(rel)).is_dir()


def _row(target, required: tuple[str, ...], check_legacy: bool) -> ContractRow:
    missing = tuple(rel for rel in required if not _exists(target.scope_path, rel))
    legacy = tuple(rel for rel in LEGACY_PATHS if check_legacy and _exists(target.scope_path, rel))
    status = "MISSING_REQUIRED" if missing else ("CURRENT_WITH_LEGACY" if legacy else "CURRENT")
    return ContractRow(target.scope_type, target.stage_id, target.scope_name, target.scope_path,
                       len(required), len(required) - len(missing), missing, legacy, status)


def collect_contract_rows(root: Path, db: Path) -> list[ContractRow]:
    with sqlite3.connect(db) as conn:
        _previews, _scenes, displays, scene_infos, _provenance = base.load_expected(conn)
    structured, _notes = scope_source.collect_structured_scope_targets(root, scene_infos)
    display_targets, _display_notes = scope_source.collect_display_targets(root, displays, structured)
    rows = [_row(t, STRUCTURED_REQUIRED, True) for t in structured]
    rows += [_row(t, DISPLAY_REQUIRED, False) for t in display_targets]
    return sorted(rows, key=lambda r: (r.stage_id, r.scope_type, str(r.scope_path).casefold()))


def _rel(path: Path, root: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def contract_html(rows: list[ContractRow], root: Path) -> str:
    current = sum(r.status == "CURRENT" for r in rows)
    legacy = sum(r.status == "CURRENT_WITH_LEGACY" for r in rows)
    missing = sum(r.status == "MISSING_REQUIRED" for r in rows)
    trs = []
    for r in rows:
        miss = "<br>".join(html.escape(x) for x in r.missing)
        old = "<br>".join(html.escape(x) for x in r.legacy_present)
        trs.append("<tr>"
                   f"<td>{html.escape(r.stage_id)}</td><td>{html.escape(r.scope_type)}</td>"
                   f"<td>{html.escape(r.scope_name)}</td><td><code>{html.escape(_rel(r.scope_path, root))}</code></td>"
                   f"<td>{r.present_total}/{r.required_total}</td><td><strong>{r.status}</strong></td>"
                   f"<td>{miss}</td><td>{old}</td></tr>")
    return ("<div class='roadmap'><h3>Current Google Drive Folder Contract Validation</h3>"
            "<p>Read-only validation of the current Stage/Sub-stage/Scene and Display folder contracts. Legacy folders are reported but never changed.</p>"
            f"<p><strong>Scopes:</strong> {len(rows)} &nbsp; <strong>CURRENT:</strong> {current} &nbsp; "
            f"<strong>CURRENT_WITH_LEGACY:</strong> {legacy} &nbsp; <strong>MISSING_REQUIRED:</strong> {missing}</p>"
            "<table><tr><th>Stage</th><th>Scope</th><th>Name</th><th>Path</th><th>Required Present</th>"
            "<th>Status</th><th>Missing Required</th><th>Legacy Present</th></tr>" + "".join(trs) + "</table></div>")


def write_reports(output: Path, root: Path, db: Path, previews, findings, helpers, provenance):
    html_path, csv_path, counts = _original_write_reports(output, root, db, previews, findings, helpers, provenance)
    rows = collect_contract_rows(root, db)
    text = html_path.read_text(encoding="utf-8")
    section = contract_html(rows, root)
    marker = "<h2>Summary</h2>"
    text = text.replace(marker, section + marker, 1) if marker in text else text + section
    text = text.replace("V1.3.6 Provisional Contract Test", "V1.3.7 Current Contract Validation")
    html_path.write_text(text, encoding="utf-8")
    return html_path, csv_path, counts

base.write_reports = write_reports

def main() -> int:
    return previous.main()

if __name__ == "__main__":
    raise SystemExit(main())
