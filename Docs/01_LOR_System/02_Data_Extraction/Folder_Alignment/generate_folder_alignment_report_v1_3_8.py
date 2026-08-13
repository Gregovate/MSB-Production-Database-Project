#!/usr/bin/env python3
"""Folder Alignment V1.3.8 - simplified operator worklist.

This keeps the existing read-only Folder Alignment checks but replaces the
operator-facing HTML with a short Stage / Sub-stage / Scene worklist.
Engineering detail remains available in the CSV output.
"""
from __future__ import annotations

import html
import re
from pathlib import Path

import generate_folder_alignment_report_v1_3_7 as previous
import generate_folder_alignment_report_v1_3_3 as legacy_source

base = previous.base
base.VERSION = "V1.3.8"
_original_write_reports = base.write_reports

GENERIC_WORDS = {
    "setup", "set", "up", "instructions", "instruction", "procedure", "procedures",
    "take", "down", "takedown", "take-down", "google", "docs", "pdf", "gdoc", "gslides",
    "work", "progress", "2024", "2025", "2026",
}


def clean_words(value: str) -> list[str]:
    value = Path(value).stem
    value = re.sub(r"^\s*\d{2}[A-Za-z]?\s*[-_. ]*", "", value)
    words = re.findall(r"[A-Za-z0-9]+", value.casefold())
    return [w for w in words if w not in GENERIC_WORDS]


def scope_words(name: str) -> list[str]:
    name = re.sub(r"^\s*\d{2}[A-Za-z]?\s*[-_. ]*", "", name)
    # Drop the normal two-letter Stage/Scene suffix when present.
    name = re.sub(r"[-_ ]+[A-Za-z]{2}\s*$", "", name)
    return re.findall(r"[A-Za-z0-9]+", name.casefold())


def legacy_branch(category: str, filename: str) -> str | None:
    text = f"{category} {filename}".casefold()
    if "takedown" in text or "take-down" in text or "take down" in text or category.startswith("1 -"):
        return "Takedown"
    if "setup" in text or "set-up" in text or category.startswith("0 -"):
        return "Setup"
    return None


def match_legacy_scope(filename: str, stage_targets: list) -> object | None:
    fwords = clean_words(filename)
    if not fwords:
        return None

    candidates = []
    for target in stage_targets:
        if target.scope_type == "STAGE":
            continue
        swords = scope_words(target.scope_name)
        if not swords:
            continue
        overlap = len(set(fwords) & set(swords))
        coverage = overlap / max(1, len(set(swords)))
        if coverage >= 0.70:
            candidates.append((coverage, overlap, len(swords), target))

    if not candidates:
        return None
    candidates.sort(key=lambda item: (item[0], item[1], item[2]), reverse=True)
    best = candidates[0]
    if len(candidates) > 1 and candidates[1][:3] == best[:3]:
        return None
    return best[3]


def file_link(path: Path, label: str = "Open") -> str:
    href = base.file_href(path)
    if not href:
        return html.escape(label)
    return f"<a href='{html.escape(href, quote=True)}'>{html.escape(label)}</a>"


def rel(path: Path, root: Path) -> str:
    try:
        return str(path.relative_to(root))
    except ValueError:
        return str(path)


def status_text(status: str) -> str:
    return {
        "MATCH": "OK",
        "MISSING": "Missing",
        "PATH_NAME_CONFLICT": "Review",
    }.get(status, status.replace("_", " ").title())


def operator_issue(finding, root: Path) -> str | None:
    if finding.status == "MISSING" and finding.finding_type == "DOCUMENTATION_SCOPE":
        return f"<strong>Missing:</strong> expected folder <code>{html.escape(finding.recommended_location)}</code>"
    if finding.status == "PATH_NAME_CONFLICT" and finding.finding_type == "DOCUMENTATION_SCOPE":
        current = html.escape(finding.current_drive_path or "")
        wanted = html.escape(finding.recommended_location or "")
        return f"<strong>Review:</strong> LOR name and current folder path do not agree. Current: <code>{current}</code>; expected from name: <code>{wanted}</code>"
    return None


def legacy_table(items: list[tuple[Path, str]], target, root: Path, stage_targets: list) -> str:
    rows = []
    for path, category in items:
        branch = legacy_branch(category, path.name)
        matched = match_legacy_scope(path.name, stage_targets)
        destination_target = matched if matched is not None else target

        if branch is None:
            action = "Review"
            destination = "Destination unclear"
        else:
            action = "Review → Move"
            destination = rel(destination_target.scope_path / "Procedures" / branch / "Archive", root)

        rows.append(
            "<tr>"
            f"<td class='file'><code>{html.escape(path.name)}</code></td>"
            f"<td class='action'>{html.escape(action)}</td>"
            f"<td><code>{html.escape(destination)}</code></td>"
            f"<td>{file_link(path)}</td>"
            "</tr>"
        )

    if not rows:
        return ""
    return (
        "<table class='work'><tr><th>Legacy file</th><th>What to do</th><th>Suggested destination</th><th></th></tr>"
        + "".join(rows) + "</table>"
    )


def write_operator_report(html_path: Path, csv_path: Path, root: Path, db: Path,
                          findings, helpers, provenance) -> None:
    legacy_root, legacy_by_stage, unassigned = legacy_source.central_legacy_inventory(root)
    contract_rows = [r for r in previous.collect_contract_rows(root, db) if r.scope_type != "DISPLAY"]

    targets_by_stage = {}
    for row in contract_rows:
        targets_by_stage.setdefault(row.stage_id, []).append(row)

    findings_by_stage = {}
    for finding in findings:
        findings_by_stage.setdefault(finding.stage_id, []).append(finding)

    stage_ids = sorted(set(targets_by_stage) | set(legacy_by_stage) | set(findings_by_stage))

    css = """
body{font-family:Segoe UI,Arial,sans-serif;margin:24px;color:#222;max-width:1500px}
h1{margin-bottom:4px}h2{margin-top:34px;border-bottom:2px solid #777;padding-bottom:5px}
h3{margin:22px 0 6px}h4{margin:16px 0 5px}.note{background:#fff8d6;border:1px solid #d5a400;padding:10px}
.stage-summary{background:#f5f7f9;border:1px solid #cbd2d8;padding:10px;margin:10px 0 16px}.scope{margin-left:18px}
table{border-collapse:collapse;width:100%;margin:7px 0 18px;font-size:14px;table-layout:fixed}th,td{border:1px solid #ccc;padding:7px;vertical-align:top;text-align:left}th{background:#eee}.work th:nth-child(1){width:38%}.work th:nth-child(2){width:14%}.work th:nth-child(3){width:38%}.work th:nth-child(4){width:10%}.file code{white-space:normal;overflow-wrap:anywhere}.action{font-weight:700}.ok{color:#176b22;font-weight:700}.review{color:#8a4b00}.missing{color:#a40000;font-weight:700}.attention{background:#fff4e5;border-left:4px solid #d98a00;padding:8px 12px;margin:8px 0 16px}.attention ul{margin:5px 0}.quiet{color:#666}details{margin:18px 0}code{font-family:Consolas,monospace;overflow-wrap:anywhere}
"""

    body = []
    body.append("<!doctype html><html><head><meta charset='utf-8'><title>MSB Folder Alignment Worklist</title>")
    body.append(f"<style>{css}</style></head><body>")
    body.append("<h1>MSB Folder Alignment Worklist</h1>")
    body.append("<p class='note'><strong>READ-ONLY.</strong> Use this report to review legacy Setup and Takedown files and check Stage/Scene folders. It does not move or rename anything.</p>")
    body.append(f"<p><strong>Version:</strong> V1.3.8 &nbsp; <strong>Drive:</strong> <code>{html.escape(str(root))}</code></p>")
    body.append("<p><strong>How to use:</strong> Work one Stage at a time. Review each legacy file, then move it to the suggested Archive only when the destination is correct.</p>")

    for sid in stage_ids:
        stage_targets = targets_by_stage.get(sid, [])
        stage_target = next((r for r in stage_targets if r.scope_type == "STAGE"), None)
        if stage_target is None:
            # Some older classification output labels a top-level Stage as SCENE.
            stage_target = next((r for r in stage_targets if len(r.scope_path.relative_to(root).parts) == 1), None)

        stage_name = stage_target.scope_name if stage_target is not None else f"Stage {sid}"
        body.append(f"<h2>Stage {html.escape(sid)} — {html.escape(stage_name)}</h2>")

        stage_legacy = legacy_by_stage.get(sid, [])
        assigned = {id(item): None for item in stage_legacy}

        # Assign legacy files to a specific Scene/Sub-stage only when the name is a strong match.
        scope_legacy = {}
        stage_level = []
        for item in stage_legacy:
            path, category = item
            match = match_legacy_scope(path.name, stage_targets)
            if match is None:
                stage_level.append(item)
            else:
                scope_legacy.setdefault(str(match.scope_path), []).append(item)

        if stage_target is not None:
            body.append("<h3>Stage-level files</h3>")
            if stage_level:
                body.append(legacy_table(stage_level, stage_target, root, stage_targets))
            else:
                body.append("<p class='quiet'>No Stage-level legacy files found.</p>")

        ordered_scopes = sorted(
            [r for r in stage_targets if r is not stage_target],
            key=lambda r: (0 if r.scope_type == "SUB_STAGE" else 1, str(r.scope_path).casefold())
        )
        for scope in ordered_scopes:
            label = "Sub-stage" if scope.scope_type == "SUB_STAGE" else "Scene"
            body.append(f"<div class='scope'><h3>{label} — {html.escape(scope.scope_name)}</h3>")
            items = scope_legacy.get(str(scope.scope_path), [])
            if items:
                body.append(legacy_table(items, scope, root, stage_targets))
            else:
                body.append("<p class='quiet'>No legacy files matched directly to this folder.</p>")
            body.append("</div>")

        issues = []
        for row in stage_targets:
            if row.missing:
                label = "Stage" if row is stage_target else ("Sub-stage" if row.scope_type == "SUB_STAGE" else "Scene")
                missing = ", ".join(row.missing)
                issues.append(f"<strong>{html.escape(label)} {html.escape(row.scope_name)}:</strong> missing <code>{html.escape(missing)}</code>")
            if row.legacy_present:
                label = "Stage" if row is stage_target else ("Sub-stage" if row.scope_type == "SUB_STAGE" else "Scene")
                old = ", ".join(row.legacy_present)
                issues.append(f"<strong>{html.escape(label)} {html.escape(row.scope_name)}:</strong> old folder(s) still present — <code>{html.escape(old)}</code>. Review contents before cleanup.")

        for finding in findings_by_stage.get(sid, []):
            issue = operator_issue(finding, root)
            if issue and issue not in issues:
                issues.append(issue)

        if issues:
            body.append("<div class='attention'><h3>Needs attention</h3><ul>")
            body.extend(f"<li>{issue}</li>" for issue in issues)
            body.append("</ul></div>")
        else:
            body.append("<p class='ok'>Folder check: OK</p>")

    if unassigned:
        body.append(f"<details><summary><strong>Legacy files not assigned to a Stage ({len(unassigned)})</strong></summary>")
        body.append("<p>These files do not begin with a recognized Stage number. Review them separately; no destination is suggested.</p>")
        body.append("<table class='work'><tr><th>Legacy file</th><th>What to do</th><th>Current location</th><th></th></tr>")
        for path, _category in unassigned:
            body.append("<tr>" +
                        f"<td class='file'><code>{html.escape(path.name)}</code></td>" +
                        "<td class='action'>Review</td>" +
                        f"<td><code>{html.escape(rel(path, root))}</code></td>" +
                        f"<td>{file_link(path)}</td></tr>")
        body.append("</table></details>")

    body.append("<details><summary><strong>Technical information</strong></summary>")
    body.append(f"<p>SQLite: <code>{html.escape(str(db))}</code><br>CSV detail: <code>{html.escape(str(csv_path))}</code></p>")
    if provenance:
        body.append(f"<p>{html.escape(str(provenance))}</p>")
    body.append("</details></body></html>")

    html_path.write_text("".join(body), encoding="utf-8")


def write_reports(output: Path, root: Path, db: Path, previews, findings, helpers, provenance):
    html_path, csv_path, counts = _original_write_reports(
        output, root, db, previews, findings, helpers, provenance
    )
    write_operator_report(html_path, csv_path, root, db, findings, helpers, provenance)
    return html_path, csv_path, counts


base.write_reports = write_reports


def main() -> int:
    return previous.main()


if __name__ == "__main__":
    raise SystemExit(main())
