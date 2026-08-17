"""
MSB Database - LOR Reconciliation Report Publisher
publish_lor_reconciliation_report.py

Initial Release : 2026-08-03  V0.1.0
Current Version : 2026-08-17  V0.6.0
Author          : GAL / OpenAI

Purpose:
    Generate, publish, index, and register an immutable HTML report for one
    completed LOR reconciliation run.

Operation:
    - Uses the reconciliation run ID supplied by the workflow.
    - Never selects the latest reconciliation run internally.
    - Contains no environment-specific reconciliation run IDs.
    - Publishes finalized reports to the protected lor2db reports folder.
    - Rebuilds the browsable report index.
    - Registers finalized reports in the production audit record.
    - Supports unregistered evaluation copies so report presentation can be
      revised without changing the production audit row.

Revision History:
    2026-08-17  GAL / OpenAI  V0.6.0
        Show every captured Scene background path, sort production changes in
        natural Stage order, and expose the exact frozen fields changed by P2.

    2026-08-17  GAL / OpenAI  V0.5.2
        Added explicit navigation from published reports and the report archive
        back to the LOR2DB dashboard.

    2026-08-17  GAL / OpenAI  V0.5.1
        Sorted the source Preview manifest by Stage and replaced the misleading
        Preview-level BackgroundFile column with Scene background coverage.

    2026-08-14  GAL / OpenAI  V0.5.0
        Made cancelled runs unmistakable, marked validation not applicable,
        removed misleading follow-up actions, and added Outcome to the archive.
    2026-08-04  GAL / OpenAI  V0.4.1
        Changed the default NAS publication folder from lortodb to lor2db.

    2026-08-04  GAL / OpenAI  V0.4.0
        Added evaluation-copy rendering and report presentation revisions.

    2026-08-03  GAL / OpenAI  V0.1.0
        Initial immutable reconciliation report generation, publication,
        indexing, and registration workflow.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import os
import re
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any, Iterable, Sequence


REPORT_VERSION = "V0.6.0"
DEFAULT_OUTPUT_DIR = r"\\192.168.5.4\web\my\lor2db\reports"
REPORT_FILENAME = re.compile(
    r"^lor-reconciliation-(?P<stamp>\d{8}-\d{6})-run-(?P<run>\d+)"
    r"(?P<evaluation>-evaluation)?\.html$"
)


def rows(cursor, query: str, params: Sequence[Any]) -> list[dict[str, Any]]:
    cursor.execute(query, params)
    return [dict(row) for row in cursor.fetchall()]


def display(value: Any) -> str:
    if value is None:
        return "—"
    if isinstance(value, datetime):
        return value.astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")
    if isinstance(value, (list, tuple)):
        return ", ".join(display(item) for item in value)
    return str(value)


def integer_display(value: Any) -> Any:
    """Render numeric LOR metadata as an integer when it is whole-valued."""
    if value is None or value == "":
        return value
    try:
        number = float(value)
    except (TypeError, ValueError):
        return value
    return int(number) if number.is_integer() else value


def stage_sort_key(row: dict[str, Any]) -> tuple[int, str, str, str]:
    """Sort Stage identifiers naturally while leaving unassigned rows last."""
    stage_id = str(row.get("report_stage_id") or row.get("stage_id") or "").strip()
    match = re.match(r"^(\d+)(.*)$", stage_id)
    if match:
        return (
            int(match.group(1)),
            match.group(2).casefold(),
            str(row.get("preview_name") or "").casefold(),
            str(row.get("scene_name") or row.get("source_filename") or "").casefold(),
        )
    return (
        2_147_483_647,
        stage_id.casefold(),
        str(row.get("preview_name") or "").casefold(),
        str(row.get("scene_name") or row.get("source_filename") or "").casefold(),
    )


def humanize_changes(data: dict[str, Any]) -> list[dict[str, Any]]:
    """Replace internal reconciliation keys with operator-readable identities."""
    displays = data.get("display_names", {})
    scenes = data.get("scene_names", {})
    previews = data.get("preview_names", {})
    stages = data.get("stage_names", {})
    stage_keys = data.get("stage_keys", {})
    display_evidence = data.get("display_change_evidence", {})
    readable = []

    for source in data["changes"]:
        row = dict(source)
        key = str(row.get("entity_key") or "")
        entity_type = row.get("entity_type")
        parts = key.split(":")

        if entity_type == "DISPLAY" and key.isdigit():
            row["entity_key"] = f"{key}-{displays.get(key, 'Unknown display')}"
            evidence = display_evidence.get(key, {})
            row["report_stage_id"] = (
                evidence.get("proposed_stage_key")
                or stage_keys.get(str(evidence.get("current_stage_id") or ""))
            )
            row["changed_fields_display"] = display(
                evidence.get("changed_fields") or []
            )
            if "stage_id" in (evidence.get("changed_fields") or []):
                before_key = stage_keys.get(
                    str(evidence.get("current_stage_id") or ""), "Unassigned"
                )
                after_key = evidence.get("proposed_stage_key") or "Unassigned"
                row["before_after"] = f"Stage {before_key} -> Stage {after_key}"
            elif "display_name" in (evidence.get("changed_fields") or []):
                row["before_after"] = (
                    f'{evidence.get("current_display_name") or "—"} -> '
                    f'{evidence.get("proposed_display_name") or "—"}'
                )
            else:
                row["before_after"] = "—"

        elif entity_type == "SCENE" and len(parts) >= 3:
            scene = scenes.get((parts[1], parts[2]), {})
            scene_name = scene.get("scene_name") or "Unnamed scene"
            preview_name = scene.get("preview_name") or previews.get(parts[1], "Unknown preview")
            stage_name = scene.get("stage_name")
            target = f'preview "{preview_name}"'
            if stage_name:
                target += f' / stage "{stage_name}"'
            row["entity_key"] = f"SCENE: {scene_name}"
            row["operator_message"] = f'Synchronized scene "{scene_name}" to {target}.'
            row["report_stage_id"] = scene.get("report_stage_id")

        elif entity_type == "SCENE_DISPLAY":
            match = re.search(r"display_id\s+(\d+)", str(row.get("operator_message") or ""))
            display_id = match.group(1) if match else (parts[-1] if parts[-1].isdigit() else None)
            scene = scenes.get((parts[1], parts[2]), {}) if len(parts) >= 3 else {}
            scene_name = scene.get("scene_name") or "Unnamed scene"
            display_key = (
                f"{display_id}-{displays.get(display_id, 'Unknown display')}"
                if display_id else "Unknown display"
            )
            row["entity_key"] = f"{display_key} -> SCENE: {scene_name}"
            row["operator_message"] = f'Synchronized display {display_key} to scene "{scene_name}".'
            row["report_stage_id"] = scene.get("report_stage_id")

        elif entity_type == "STAGE" and key.isdigit():
            row["report_stage_id"] = stage_keys.get(key)
            row["entity_key"] = f"{key}-{stages.get(key, 'Unknown stage')}"

        elif entity_type == "STAGE" and len(parts) >= 2:
            source_name = previews.get(parts[1]) if parts[0] == "PREVIEW" else None
            if parts[0] == "SCENE" and len(parts) >= 3:
                source_name = scenes.get((parts[1], parts[2]), {}).get("scene_name")
            stage_match = re.search(r"stage_id\s+(\d+)", str(row.get("operator_message") or ""))
            stage_id = stage_match.group(1) if stage_match else None
            stage_name = stages.get(stage_id, "Unknown stage") if stage_id else "Unknown stage"
            row["entity_key"] = f'{parts[0]}: {source_name or "Unnamed source"}'
            row["operator_message"] = (
                f'Synchronized {parts[0].lower()} "{source_name or "Unnamed source"}" '
                f'to stage "{stage_name}".'
            )
            row["report_stage_id"] = scene.get("report_stage_id") if parts[0] == "SCENE" else None

        readable.append(row)
    return sorted(
        readable,
        key=lambda item: stage_sort_key(item) + (
            str(item.get("entity_type") or ""),
            str(item.get("entity_key") or ""),
        ),
    )


def table(columns: Sequence[tuple[str, str]], data: Iterable[dict[str, Any]], empty: str) -> str:
    materialized = list(data)
    head = "".join(f"<th>{html.escape(label)}</th>" for _, label in columns)
    if materialized:
        body = "".join(
            "<tr>" + "".join(
                f"<td>{html.escape(display(row.get(key)))}</td>" for key, _ in columns
            ) + "</tr>"
            for row in materialized
        )
    else:
        body = (
            f'<tr class="empty"><td colspan="{len(columns)}">'
            f"{html.escape(empty)}</td></tr>"
        )
    return f"<table><thead><tr>{head}</tr></thead><tbody>{body}</tbody></table>"


def section(number: int, title: str, body: str, action: str) -> str:
    action_class = "none" if action == "NONE" else "required"
    return (
        f'<section><h2>{number}. {html.escape(title)}</h2>'
        f'<p class="action {action_class}"><strong>Action Required:</strong> '
        f"{html.escape(action)}</p>{body}</section>"
    )


def report_index_entry(path: Path) -> dict[str, str] | None:
    """Read operator-facing metadata from one generated report filename/body."""
    match = REPORT_FILENAME.match(path.name)
    if not match:
        return None
    generated = datetime.strptime(match.group("stamp"), "%Y%m%d-%H%M%S")
    content = path.read_text(encoding="utf-8", errors="replace")
    meta_match = re.search(
        r"Generated\s+(.+?)\s+·\s+Report framework\s+([^·<]+)"
        r"\s+·\s+Captured ingest\s+([^<]+)",
        content,
    )
    outcome_match = re.search(r'data-report-outcome="([A-Z_]+)"', content)
    if outcome_match is None:
        # Reports published before V0.5.0 already contain the durable final
        # status in their ingest table. Recover it without rewriting the
        # immutable report so the refreshed archive labels historical runs.
        outcome_match = re.search(
            r">(COMPLETED_WITH_EXCEPTIONS|CANCELLED|COMPLETED)<", content
        )
    return {
        "filename": path.name,
        "run_id": match.group("run"),
        "report_type": "Evaluation copy" if match.group("evaluation") else "Published report",
        "generated": meta_match.group(1).strip() if meta_match else generated.strftime("%Y-%m-%d %H:%M:%S"),
        "framework": meta_match.group(2).strip() if meta_match else "—",
        "captured_ingest": meta_match.group(3).strip() if meta_match else "—",
        "outcome": outcome_match.group(1).replace("_", " ") if outcome_match else "UNKNOWN",
        "sort_key": match.group("stamp"),
    }


def refresh_report_index(output_dir: str) -> Path:
    """Atomically rebuild the browsable index from every report in the folder."""
    directory = Path(output_dir)
    directory.mkdir(parents=True, exist_ok=True)
    entries = [
        entry for path in directory.glob("lor-reconciliation-*.html")
        if (entry := report_index_entry(path)) is not None
    ]
    entries.sort(key=lambda entry: entry["sort_key"], reverse=True)
    rows_html = "".join(
        "<tr>"
        f'<td><a href="{html.escape(entry["filename"], quote=True)}">'
        f'{html.escape(entry["filename"])}</a></td>'
        f'<td>{html.escape(entry["report_type"])}</td>'
        f'<td>{html.escape(entry["outcome"])}</td>'
        f'<td>{html.escape(entry["run_id"])}</td>'
        f'<td>{html.escape(entry["captured_ingest"])}</td>'
        f'<td>{html.escape(entry["generated"])}</td>'
        f'<td>{html.escape(entry["framework"])}</td>'
        "</tr>"
        for entry in entries
    )
    if not rows_html:
        rows_html = '<tr><td colspan="7" class="empty">No reconciliation reports are available.</td></tr>'
    generated = datetime.now().astimezone()
    document = f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>LOR Reconciliation Reports</title>
<style>body{{font:14px/1.4 Arial,sans-serif;color:#1f2937;max-width:1400px;margin:24px auto;padding:0 18px}}h1{{margin-bottom:4px}}.report-nav{{float:right;padding:9px 13px;border:1px solid #94a3b8;border-radius:4px;text-decoration:none}}.meta{{color:#475569}}table{{width:100%;border-collapse:collapse;margin-top:18px}}th,td{{border:1px solid #cbd5e1;padding:8px;text-align:left;vertical-align:top}}th{{background:#e2e8f0}}tr:nth-child(even) td{{background:#f8fafc}}a{{color:#075985}}.empty{{font-style:italic;color:#475569}}@media print{{.report-nav{{display:none}}}}</style></head><body>
<a class="report-nav" href="../">Return to LOR2DB dashboard</a><h1>LOR Reconciliation Reports</h1><p class="meta">Index refreshed {html.escape(display(generated))} · {len(entries)} report(s)</p>
<table><thead><tr><th>Report</th><th>Type</th><th>Outcome</th><th>Reconciliation run</th><th>Captured ingest</th><th>Generated</th><th>Framework</th></tr></thead><tbody>{rows_html}</tbody></table>
</body></html>"""
    destination = directory / "index.html"
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=directory, delete=False) as tmp:
        tmp.write(document)
        temporary = Path(tmp.name)
    os.replace(temporary, destination)
    return destination


def collect_report_data(conn: Any, run_id: int) -> dict[str, Any]:
    try:
        from psycopg2.extras import RealDictCursor
    except ImportError as exc:
        raise RuntimeError(
            "psycopg2-binary is required for PostgreSQL report publication"
        ) from exc

    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        run = rows(cur, """
            SELECT r.*, sr.run_ts, sr.notes, sr.parser_version,
                   sr.parser_started_at, sr.parser_completed_at,
                   sr.parser_actor, sr.parser_host, sr.source_preview_folder,
                   sr.source_sqlite_path, sr.preview_count, sr.scene_count,
                   sr.prop_count, sr.sub_prop_count, sr.dmx_channel_count,
                   sr.scene_lor_prop_count, sr.ingest_script_version,
                   sr.ingest_actor, sr.ingest_host, sr.ingest_started_at,
                   sr.ingest_completed_at
            FROM ops.lor_reconciliation_run r
            JOIN ops.lor_reconciliation_source_run sr
              ON sr.lor_reconciliation_run_id = r.lor_reconciliation_run_id
            WHERE r.lor_reconciliation_run_id = %s
        """, (run_id,))
        if len(run) != 1:
            raise RuntimeError(f"Reconciliation run {run_id} was not found or lacks frozen source evidence")

        previews = rows(cur, """
            SELECT source_filename, preview_revision, preview_name, stage_id,
                   preview_id, brightness, background_file
            FROM ops.lor_reconciliation_source_preview
            WHERE lor_reconciliation_run_id = %s
            ORDER BY stage_id NULLS LAST, preview_name, source_filename
        """, (run_id,))
        changes = rows(cur, """
            SELECT entity_type, entity_key, result_class, reason_code,
                   operator_message, recorded_at
            FROM ops.lor_reconciliation_result
            WHERE lor_reconciliation_run_id = %s
              AND committed
              AND result_class IN ('ADDED','UPDATED','REASSOCIATED','STATUS_CHANGED')
            ORDER BY entity_type, entity_key, recorded_at
        """, (run_id,))
        names = rows(cur, """
            SELECT "Display_id" AS display_id, "Before" AS before_name,
                   "After" AS after_name, "Follow-up" AS action_required
            FROM ops.f_lor_reconciliation_display_name_changes_report(%s)
        """, (run_id,))
        display_evidence_rows = rows(cur, """
            SELECT DISTINCT ON (c.display_id)
                   c.display_id, c.changed_fields,
                   c.current_display_name, c.proposed_display_name,
                   c.current_stage_id, c.proposed_stage_id,
                   c.proposed_stage_key
            FROM ops.lor_reconciliation_display_candidate AS c
            WHERE c.lor_reconciliation_run_id = %s
              AND c.display_id IS NOT NULL
            ORDER BY c.display_id,
                     c.lor_reconciliation_display_candidate_id DESC
        """, (run_id,))
        problems = rows(cur, """
            /* Current problems come from effective state, not historical flags. */
            SELECT gr.entity_type, gr.logical_group_key AS entity_key,
                   gr.effective_resolution_state AS result_class,
                   gr.effective_action_type AS reason_code,
                   coalesce(gr.effective_reason, gr.operator_message)
                       AS operator_message,
                   gr.acted_at AS recorded_at
            FROM ops.v_lor_reconciliation_group_review AS gr
            WHERE gr.lor_reconciliation_run_id = %s
              AND gr.effective_resolution_state IN (
                  'BLOCKED', 'DEFERRED', 'UNRESOLVED'
              )
            UNION ALL
            SELECT rr.entity_type, rr.entity_key, rr.result_class,
                   rr.reason_code, rr.operator_message, rr.recorded_at
            FROM ops.lor_reconciliation_result AS rr
            WHERE rr.lor_reconciliation_run_id = %s
              AND rr.result_class = 'FAILED'
            ORDER BY result_class, entity_type, entity_key, recorded_at
        """, (run_id, run_id))
        decisions = rows(cur, """
            SELECT g.logical_group_key, a.action_type, a.reason,
                   a.acted_by, a.acted_by_application, a.acted_at
            FROM ops.lor_reconciliation_action a
            LEFT JOIN ops.lor_reconciliation_group g
              ON g.lor_reconciliation_group_id = a.lor_reconciliation_group_id
            WHERE a.lor_reconciliation_run_id = %s
            ORDER BY a.acted_at, a.lor_reconciliation_action_id
        """, (run_id,))
        validations = rows(cur, """
            SELECT reason_code AS validation_check,
                   CASE WHEN committed THEN 'PASS' ELSE 'FAIL' END AS result,
                   operator_message AS detail, recorded_at
            FROM ops.lor_reconciliation_result
            WHERE lor_reconciliation_run_id = %s
              AND result_class IN ('VALIDATION','FAILED')
            ORDER BY recorded_at, lor_reconciliation_result_id
        """, (run_id,))
        display_rows = rows(cur, "SELECT display_id, display_name FROM ref.display", ())
        stage_rows = rows(cur, "SELECT stage_id, stage_key, stage_name FROM ref.stage", ())
        scene_rows = rows(cur, """
            SELECT s.preview_id, s.scene_id, s.scene_name, p.preview_name,
                   p.stage_id AS preview_stage_id,
                   s.stage_id AS scene_stage_id,
                   coalesce(
                       nullif(btrim(s.stage_id), ''),
                       nullif(btrim(p.stage_id), '')
                   ) AS report_stage_id,
                   s.background_file,
                   st.stage_name
            FROM ops.lor_reconciliation_source_scene AS s
            LEFT JOIN ops.lor_reconciliation_source_preview AS p
              ON p.lor_reconciliation_run_id = s.lor_reconciliation_run_id
             AND p.preview_id = s.preview_id
            LEFT JOIN ref.stage AS st
              ON st.stage_key = coalesce(
                  nullif(btrim(s.stage_id), ''),
                  nullif(btrim(p.stage_id), '')
              )
            WHERE s.lor_reconciliation_run_id = %s
        """, (run_id,))
    return {"run": run[0], "previews": previews, "scene_backgrounds": scene_rows,
            "changes": changes,
            "names": names, "problems": problems, "decisions": decisions,
            "validations": validations,
            "display_names": {str(x["display_id"]): x["display_name"] for x in display_rows},
            "stage_names": {str(x["stage_id"]): x["stage_name"] for x in stage_rows},
            "stage_keys": {str(x["stage_id"]): x["stage_key"] for x in stage_rows},
            "display_change_evidence": {
                str(x["display_id"]): x for x in display_evidence_rows
            },
            "preview_names": {str(x["preview_id"]): x["preview_name"] for x in previews},
            "scene_names": {(str(x["preview_id"]), str(x["scene_id"])): x for x in scene_rows}}


def render_report(data: dict[str, Any], generated_at: datetime) -> str:
    r = data["run"]
    previews = sorted((dict(x) for x in data["previews"]), key=stage_sort_key)
    for preview in previews:
        preview["preview_revision"] = integer_display(preview.get("preview_revision"))
        preview["brightness"] = integer_display(preview.get("brightness"))
    cancelled = r.get("cancelled_at") is not None
    if cancelled:
        final_status = "CANCELLED"
    elif any(int(r.get(key) or 0) != 0 for key in (
        "blocked_count", "deferred_count", "unresolved_count"
    )):
        final_status = "COMPLETED_WITH_EXCEPTIONS"
    else:
        final_status = "COMPLETED"
    report_run = dict(r, report_status=final_status)
    parser = table([
        ("parser_completed_at", "Date/time parsed"), ("parser_version", "Parser version"),
        ("parser_actor", "Run by"), ("parser_host", "Computer"),
        ("preview_count", "Previews"), ("scene_count", "Scenes"),
        ("prop_count", "Props"), ("sub_prop_count", "Subprops"),
        ("dmx_channel_count", "DMX"), ("scene_lor_prop_count", "Scene/prop rows"),
    ], [r], "Parser metadata unavailable.")
    ingest = table([
        ("import_run_id", "Ingest number"), ("ingest_completed_at", "Date/time ingested"),
        ("ingest_script_version", "Ingest version"), ("ingest_actor", "Ingested by"),
        ("ingest_host", "Computer"), ("lor_reconciliation_run_id", "Reconciliation run"),
        ("report_status", "Final status"), ("validation_state", "Validation"),
    ], [report_run], "Ingest metadata unavailable.")
    scene_backgrounds = sorted(
        (dict(x) for x in data.get("scene_backgrounds", [])),
        key=stage_sort_key,
    )
    assigned_backgrounds = [
        row for row in scene_backgrounds
        if str(row.get("background_file") or "").strip()
    ]
    coverage = (
        f'<h3>Scene background coverage</h3>'
        f'<p><strong>{len(assigned_backgrounds)} of {len(scene_backgrounds)} Scenes</strong> '
        'have an assigned background file. Folder alignment uses these Scene-level paths; '
        'Preview-level background metadata is not shown here.</p>'
        + table([
            ("report_stage_id", "Stage"),
            ("preview_name", "Preview name"),
            ("scene_name", "Scene"),
            ("background_file", "Background file"),
        ], scene_backgrounds, "No captured Scene rows were recorded.")
    )
    manifest = f'<p><strong>Source folder:</strong> {html.escape(display(r["source_preview_folder"]))}</p>' + table([
        ("source_filename", "Preview filename"), ("preview_revision", "Revision"),
        ("preview_name", "Preview name"), ("stage_id", "Stage"),
        ("brightness", "Brightness"),
    ], previews, "No frozen preview manifest rows were recorded.") + coverage
    name_rows = []
    for source in data["names"]:
        row = dict(source)
        evidence = data.get("display_change_evidence", {}).get(
            str(row.get("display_id")), {}
        )
        row["report_stage_id"] = (
            evidence.get("proposed_stage_key")
            or data.get("stage_keys", {}).get(
                str(evidence.get("current_stage_id") or "")
            )
        )
        name_rows.append(row)
    name_rows.sort(key=stage_sort_key)
    name_table = table([
        ("report_stage_id", "Stage"),
        ("display_id", "Display_id"), ("before_name", "Before"),
        ("after_name", "After"), ("action_required", "Action Required"),
    ], name_rows, "No display-name changes were committed.")
    changed_name_ids = {str(n["display_id"]) for n in data["names"]}
    other_change_data = dict(data)
    other_change_data["changes"] = [x for x in data["changes"] if not (
        x["entity_type"] == "DISPLAY" and x["entity_key"] in changed_name_ids
    )]
    readable_changes = humanize_changes(other_change_data)
    other_changes = table([
        ("report_stage_id", "Stage"),
        ("entity_type", "Object"), ("entity_key", "Permanent key"),
        ("result_class", "Change"), ("reason_code", "Reason"),
        ("changed_fields_display", "Fields changed"),
        ("before_after", "Before -> After"),
        ("operator_message", "Detail"),
    ], readable_changes, "No other production changes were committed.")
    changes_body = '<h3>Display Name Changes</h3>' + name_table + '<h3>Other Changes</h3>' + other_changes
    issues = table([
        ("entity_type", "Object"), ("entity_key", "Key"),
        ("result_class", "State"), ("reason_code", "Reason"),
        ("operator_message", "Required response"),
    ], data["problems"], "No blocked, deferred, unresolved, or failed items.")
    decision_rows = [dict(row) for row in data["decisions"]]
    for decision in decision_rows:
        application = str(decision.get("acted_by_application") or "")
        if application.startswith("lor-preflight-api:"):
            # Until the planned Directus person lookup exists, the authenticated
            # Cloudflare email embedded by the API is the human operator.
            decision["operator"] = application.split(":", 1)[1]
        else:
            decision["operator"] = decision.get("acted_by")
    decisions = table([
        ("logical_group_key", "Logical group"), ("action_type", "Decision"),
        ("reason", "Reason"), ("operator", "Operator"),
        ("acted_at", "Date/time"),
    ], decision_rows, "No operator decisions were required.")
    if cancelled:
        validation = '<p class="not-applicable"><strong>Not applicable — reconciliation cancelled before production validation.</strong></p>'
    else:
        validation = table([
            ("validation_check", "Validation check"), ("result", "Result"),
            ("detail", "Detail"), ("recorded_at", "Date/time"),
        ], data["validations"], "No validation result was recorded.")
    change_action = "NONE" if cancelled else ("Print replacement labels" if data["names"] else "NONE")
    problem_action = "NONE" if cancelled else ("Review listed items" if data["problems"] else "NONE")
    validation_action = "NONE" if cancelled else (
        "Investigate failed validation"
        if any(v["result"] != "PASS" for v in data["validations"])
        else "NONE"
    )
    body = "".join([
        section(1, "Parser Run", parser, "NONE"),
        section(2, "PostgreSQL Ingest", ingest, "NONE"),
        section(3, "Source Preview Files", manifest, "NONE"),
        section(4, "Changes Made and Required Actions", changes_body, change_action),
        section(5, "Problems and Operator Decisions", '<h3>Problems</h3>' + issues + '<h3>Operator Decisions</h3>' + decisions, problem_action),
        section(6, "Final Validation", validation, validation_action),
    ])
    title = (
        f'LOR Reconciliation Cancellation Record — Run {r["lor_reconciliation_run_id"]}'
        if cancelled else
        f'LOR Production Reconciliation Report — Run {r["lor_reconciliation_run_id"]}'
    )
    banner = ""
    if cancelled:
        banner = (
            '<div class="cancelled-banner"><strong>CANCELLED — NO PRODUCTION CHANGES COMMITTED</strong><br>'
            'The captured ingest snapshot was removed and this run is closed. '
            f'Cancellation reason: {html.escape(display(r.get("cancellation_reason")))}</div>'
        )
    return f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>{html.escape(title)}</title>
<style>body{{font:14px/1.4 Arial,sans-serif;color:#1f2937;max-width:1400px;margin:24px auto;padding:0 18px}}h1{{margin-bottom:4px}}h2{{border-bottom:2px solid #334155;padding-bottom:5px;margin-top:30px}}h3{{margin-top:20px}}.report-nav{{float:right;padding:9px 13px;border:1px solid #94a3b8;border-radius:4px;color:#075985;text-decoration:none}}.meta{{color:#475569}}.action{{display:inline-block;padding:6px 10px;border-radius:4px}}.none{{background:#dcfce7}}.required{{background:#fef3c7}}.cancelled-banner{{margin:18px 0;padding:14px;border:2px solid #991b1b;background:#fee2e2;color:#7f1d1d}}.not-applicable{{padding:10px;background:#e2e8f0}}table{{width:100%;border-collapse:collapse;margin:10px 0 18px}}th,td{{border:1px solid #cbd5e1;padding:6px 8px;text-align:left;vertical-align:top}}th{{background:#e2e8f0}}tr:nth-child(even) td{{background:#f8fafc}}.empty td{{font-style:italic;color:#475569}}@media print{{body{{margin:0;max-width:none}}section{{break-inside:avoid}}.report-nav{{display:none}}}}</style></head><body data-report-outcome="{html.escape(final_status, quote=True)}">
<a class="report-nav" href="../">Return to LOR2DB dashboard</a><h1>{html.escape(title)}</h1><p class="meta">Generated {html.escape(display(generated_at))} · Report framework {REPORT_VERSION} · Captured ingest {r["import_run_id"]}</p>{banner}{body}</body></html>"""


def publish(conn: Any, run_id: int, output_dir: str, base_url: str | None) -> Path:
    data = collect_report_data(conn, run_id)
    if data["run"]["status"] != "REPORTING":
        raise RuntimeError(f'Run {run_id} is {data["run"]["status"]}, not REPORTING')
    generated = datetime.now().astimezone()
    filename = f"lor-reconciliation-{generated:%Y%m%d-%H%M%S}-run-{run_id}.html"
    destination = Path(output_dir) / filename
    report_bytes = render_report(data, generated).encode("utf-8")
    digest = hashlib.sha256(report_bytes).hexdigest()
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("wb", dir=destination.parent, delete=False) as tmp:
        tmp.write(report_bytes)
        temporary = Path(tmp.name)
    os.replace(temporary, destination)
    report_url = f"{base_url.rstrip('/')}/{filename}" if base_url else destination.as_uri()
    with conn.cursor() as cur:
        cur.execute("CALL ops.p_publish_lor_reconciliation_report(%s,%s,%s,%s,%s)",
                    (run_id, str(destination), report_url, digest, "Python HTML report publisher"))
    conn.commit()
    refresh_report_index(output_dir)
    return destination


def render_evaluation_copy(conn: Any, run_id: int, output_dir: str) -> Path:
    """Render a completed run without registering or mutating it.

    Evaluation copies are deliberately separate from publication. They do not
    call ``ops.p_publish_lor_reconciliation_report``, commit a transaction, or
    replace the path, URL, timestamp, and hash registered for the original.
    """
    data = collect_report_data(conn, run_id)
    if data["run"]["status"] != "COMPLETED":
        raise RuntimeError(
            f'Run {run_id} is {data["run"]["status"]}, not COMPLETED; '
            "evaluation-copy mode is only for completed runs"
        )
    generated = datetime.now().astimezone()
    filename = (
        f"lor-reconciliation-{generated:%Y%m%d-%H%M%S}-run-{run_id}"
        "-evaluation.html"
    )
    destination = Path(output_dir) / filename
    report_bytes = render_report(data, generated).encode("utf-8")
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("wb", dir=destination.parent, delete=False) as tmp:
        tmp.write(report_bytes)
        temporary = Path(tmp.name)
    os.replace(temporary, destination)
    refresh_report_index(output_dir)
    return destination


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-id", type=int, help="Run ID retained by Start Reconciliation")
    parser.add_argument("--output-dir", default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--base-url")
    parser.add_argument("--pg-host")
    parser.add_argument("--pg-db", default="msb")
    parser.add_argument("--pg-user", default="msbadmin")
    parser.add_argument(
        "--evaluation-copy",
        action="store_true",
        help=(
            "Render an unregistered HTML copy of a COMPLETED run without "
            "changing its audit record"
        ),
    )
    parser.add_argument(
        "--refresh-index",
        action="store_true",
        help="Rebuild index.html from existing reports without connecting to PostgreSQL",
    )
    args = parser.parse_args()
    if args.refresh_index:
        path = refresh_report_index(args.output_dir)
        print(f"REPORT_INDEX_PATH={path}")
        return 0
    if args.run_id is None:
        parser.error("--run-id is required unless --refresh-index is used")
    if not args.pg_host:
        parser.error("--pg-host is required unless --refresh-index is used")
    password = os.environ.get("PGPASSWORD")
    if not password:
        raise RuntimeError("PGPASSWORD is required; use the secured PowerShell runner")
    try:
        import psycopg2
    except ImportError as exc:
        raise RuntimeError(
            "psycopg2-binary is required; install it before report publication"
        ) from exc
    conn = psycopg2.connect(host=args.pg_host, dbname=args.pg_db, user=args.pg_user, password=password)
    try:
        if args.evaluation_copy:
            path = render_evaluation_copy(conn, args.run_id, args.output_dir)
            print(f"EVALUATION_REPORT_PATH={path}")
        else:
            path = publish(conn, args.run_id, args.output_dir, args.base_url)
            print(f"REPORT_PATH={path}")
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
