#!/usr/bin/env python3
"""V1.3.2 test patch for MSB Folder Alignment.

Adds explicit report visibility for the legacy 000-Instructions scan while
preserving the V1.3.1 Stage/sub-stage/documentation-root behavior.
"""
from __future__ import annotations

import html
from pathlib import Path

import generate_folder_alignment_report_v1_3_1 as patch

base = patch.base
base.VERSION = "V1.3.2"
_original_write_reports = base.write_reports


def write_reports(output: Path, root: Path, db: Path, previews, findings, helpers, provenance):
    html_path, csv_path, counts = _original_write_reports(
        output, root, db, previews, findings, helpers, provenance
    )

    legacy_dirs = []
    for contexts in helpers.values():
        for ctx in contexts:
            legacy_dirs.extend(ctx.legacy_instruction_dirs)

    unique_legacy = sorted(
        {str(p) for p in legacy_dirs},
        key=str.casefold,
    )

    if unique_legacy:
        items = "".join(
            f"<li><code>{html.escape(path)}</code></li>" for path in unique_legacy
        )
        legacy_html = (
            "<div class='roadmap'><h3>Legacy 000-Instructions Scan</h3>"
            f"<p>Searched recursively for legacy folders named <code>000-Instructions</code>. "
            f"Found <strong>{len(unique_legacy)}</strong> folder(s).</p><ul>{items}</ul></div>"
        )
    else:
        legacy_html = (
            "<div class='roadmap'><h3>Legacy 000-Instructions Scan</h3>"
            "<p>Searched recursively for legacy folders named <code>000-Instructions</code>. "
            "<strong>None were found in the documentation scopes included in this report.</strong> "
            "This does not search for generic folders named <code>Instructions</code>.</p></div>"
        )

    text = html_path.read_text(encoding="utf-8")
    marker = "<h2>Summary</h2>"
    if marker in text:
        text = text.replace(marker, legacy_html + marker, 1)
    else:
        text = text.replace("<body>", "<body>" + legacy_html, 1)
    html_path.write_text(text, encoding="utf-8")

    return html_path, csv_path, counts


base.write_reports = write_reports

if __name__ == "__main__":
    raise SystemExit(base.main())
