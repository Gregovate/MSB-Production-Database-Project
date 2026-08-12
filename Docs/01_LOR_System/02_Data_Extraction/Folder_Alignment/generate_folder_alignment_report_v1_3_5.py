#!/usr/bin/env python3
"""V1.3.5 test patch for MSB Folder Alignment.

Setup-document alignment is Stage / Scene / Sub-stage focused. Display-folder
reconciliation remains available as an engineering diagnostic, but is suppressed
from the normal report by default.

Use --include-displays to include Display findings in the HTML/CSV report.
No filesystem changes are made.
"""
from __future__ import annotations

import sys

import generate_folder_alignment_report_v1_3_4 as patch

base = patch.base
base.VERSION = "V1.3.5"

_original_write_reports = base.write_reports

INCLUDE_DISPLAYS = False


def write_reports(output, root, db, previews, findings, helpers, provenance):
    report_findings = findings
    if not INCLUDE_DISPLAYS:
        report_findings = [f for f in findings if f.kind not in {"DISPLAY", "BACKGROUND_GROUP"}]

    html_path, csv_path, counts = _original_write_reports(
        output, root, db, previews, report_findings, helpers, provenance
    )

    text = html_path.read_text(encoding="utf-8")
    if INCLUDE_DISPLAYS:
        note = (
            "<div class='roadmap'><h3>Display Reconciliation Enabled</h3>"
            "<p>Display-folder reconciliation is included because <code>--include-displays</code> "
            "was requested. Display findings are engineering diagnostics and do not imply "
            "Display-level Setup Instructions.</p></div>"
        )
    else:
        note = (
            "<div class='roadmap'><h3>Setup Alignment Scope</h3>"
            "<p>This worklist is focused on Stage, Scene, and Sub-stage Setup documentation. "
            "Display-folder reconciliation is suppressed by default because current Setup "
            "Instructions are not being assigned at Display scope. Run with "
            "<code>--include-displays</code> only when Display-folder engineering diagnostics "
            "are needed.</p></div>"
        )

    marker = "<h2>Summary</h2>"
    if marker in text:
        text = text.replace(marker, note + marker, 1)
    html_path.write_text(text, encoding="utf-8")
    return html_path, csv_path, counts


base.write_reports = write_reports


def main() -> int:
    global INCLUDE_DISPLAYS

    cleaned = [sys.argv[0]]
    for arg in sys.argv[1:]:
        if arg == "--include-displays":
            INCLUDE_DISPLAYS = True
        else:
            cleaned.append(arg)
    sys.argv = cleaned

    return base.main()


if __name__ == "__main__":
    raise SystemExit(main())
