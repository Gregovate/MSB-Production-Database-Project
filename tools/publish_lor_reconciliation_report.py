"""Generate, publish, and register one immutable LOR reconciliation report.

The workflow supplies the reconciliation run ID returned by Start. This tool
never selects a latest run and contains no environment-specific run IDs.
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


REPORT_VERSION = "V0.2.0"
DEFAULT_OUTPUT_DIR = r"\\192.168.5.4\web\my\lortodb\reports"


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


def humanize_changes(data: dict[str, Any]) -> list[dict[str, Any]]:
    """Replace internal reconciliation keys with operator-readable identities."""
    displays = data.get("display_names", {})
    scenes = data.get("scene_names", {})
    previews = data.get("preview_names", {})
    stages = data.get("stage_names", {})
    readable = []

    for source in data["changes"]:
        row = dict(source)
        key = str(row.get("entity_key") or "")
        entity_type = row.get("entity_type")
        parts = key.split(":")

        if entity_type == "DISPLAY" and key.isdigit():
            row["entity_key"] = f"{key}-{displays.get(key, 'Unknown display')}"

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

        readable.append(row)
    return readable


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
            ORDER BY source_filename, preview_name
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
        stage_rows = rows(cur, "SELECT stage_id, stage_name FROM ref.stage", ())
        scene_rows = rows(cur, """
            SELECT s.preview_id, s.scene_id, s.scene_name, p.preview_name,
                   st.stage_name
            FROM ops.lor_reconciliation_source_scene AS s
            LEFT JOIN ops.lor_reconciliation_source_preview AS p
              ON p.lor_reconciliation_run_id = s.lor_reconciliation_run_id
             AND p.preview_id = s.preview_id
            LEFT JOIN ref.stage AS st
              ON st.stage_key = s.stage_id
            WHERE s.lor_reconciliation_run_id = %s
        """, (run_id,))
    return {"run": run[0], "previews": previews, "changes": changes,
            "names": names, "problems": problems, "decisions": decisions,
            "validations": validations,
            "display_names": {str(x["display_id"]): x["display_name"] for x in display_rows},
            "stage_names": {str(x["stage_id"]): x["stage_name"] for x in stage_rows},
            "preview_names": {str(x["preview_id"]): x["preview_name"] for x in previews},
            "scene_names": {(str(x["preview_id"]), str(x["scene_id"])): x for x in scene_rows}}


def render_report(data: dict[str, Any], generated_at: datetime) -> str:
    r = data["run"]
    previews = [dict(x) for x in data["previews"]]
    for preview in previews:
        preview["preview_revision"] = integer_display(preview.get("preview_revision"))
        preview["brightness"] = integer_display(preview.get("brightness"))
    if r.get("cancelled_at") is not None:
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
    manifest = f'<p><strong>Source folder:</strong> {html.escape(display(r["source_preview_folder"]))}</p>' + table([
        ("source_filename", "Preview filename"), ("preview_revision", "Revision"),
        ("preview_name", "Preview name"), ("stage_id", "Stage"),
        ("brightness", "Brightness"),
        ("background_file", "Background file"),
    ], previews, "No frozen preview manifest rows were recorded.")
    name_table = table([
        ("display_id", "Display_id"), ("before_name", "Before"),
        ("after_name", "After"), ("action_required", "Action Required"),
    ], data["names"], "No display-name changes were committed.")
    changed_name_ids = {str(n["display_id"]) for n in data["names"]}
    other_change_data = dict(data)
    other_change_data["changes"] = [x for x in data["changes"] if not (
        x["entity_type"] == "DISPLAY" and x["entity_key"] in changed_name_ids
    )]
    readable_changes = humanize_changes(other_change_data)
    other_changes = table([
        ("entity_type", "Object"), ("entity_key", "Permanent key"),
        ("result_class", "Change"), ("reason_code", "Reason"),
        ("operator_message", "Detail"),
    ], readable_changes, "No other production changes were committed.")
    changes_body = '<h3>Display Name Changes</h3>' + name_table + '<h3>Other Changes</h3>' + other_changes
    issues = table([
        ("entity_type", "Object"), ("entity_key", "Key"),
        ("result_class", "State"), ("reason_code", "Reason"),
        ("operator_message", "Required response"),
    ], data["problems"], "No blocked, deferred, unresolved, or failed items.")
    decisions = table([
        ("logical_group_key", "Logical group"), ("action_type", "Decision"),
        ("reason", "Reason"), ("acted_by", "Operator"),
        ("acted_at", "Date/time"),
    ], data["decisions"], "No operator decisions were required.")
    validation = table([
        ("validation_check", "Validation check"), ("result", "Result"),
        ("detail", "Detail"), ("recorded_at", "Date/time"),
    ], data["validations"], "No validation result was recorded.")
    change_action = "Print replacement labels" if data["names"] else "NONE"
    problem_action = "Review listed items" if data["problems"] else "NONE"
    validation_action = "Investigate failed validation" if any(v["result"] != "PASS" for v in data["validations"]) else "NONE"
    body = "".join([
        section(1, "Parser Run", parser, "NONE"),
        section(2, "PostgreSQL Ingest", ingest, "NONE"),
        section(3, "Source Preview Files", manifest, "NONE"),
        section(4, "Changes Made and Required Actions", changes_body, change_action),
        section(5, "Problems and Operator Decisions", '<h3>Problems</h3>' + issues + '<h3>Operator Decisions</h3>' + decisions, problem_action),
        section(6, "Final Validation", validation, validation_action),
    ])
    title = f'LOR Production Reconciliation Report — Run {r["lor_reconciliation_run_id"]}'
    return f"""<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>{html.escape(title)}</title>
<style>body{{font:14px/1.4 Arial,sans-serif;color:#1f2937;max-width:1400px;margin:24px auto;padding:0 18px}}h1{{margin-bottom:4px}}h2{{border-bottom:2px solid #334155;padding-bottom:5px;margin-top:30px}}h3{{margin-top:20px}}.meta{{color:#475569}}.action{{display:inline-block;padding:6px 10px;border-radius:4px}}.none{{background:#dcfce7}}.required{{background:#fef3c7}}table{{width:100%;border-collapse:collapse;margin:10px 0 18px}}th,td{{border:1px solid #cbd5e1;padding:6px 8px;text-align:left;vertical-align:top}}th{{background:#e2e8f0}}tr:nth-child(even) td{{background:#f8fafc}}.empty td{{font-style:italic;color:#475569}}@media print{{body{{margin:0;max-width:none}}section{{break-inside:avoid}}}}</style></head><body>
<h1>{html.escape(title)}</h1><p class="meta">Generated {html.escape(display(generated_at))} · Report framework {REPORT_VERSION} · Captured ingest {r["import_run_id"]}</p>{body}</body></html>"""


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
    return destination


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-id", type=int, required=True, help="Run ID retained by Start Reconciliation")
    parser.add_argument("--output-dir", default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--base-url")
    parser.add_argument("--pg-host", required=True)
    parser.add_argument("--pg-db", default="msb")
    parser.add_argument("--pg-user", default="msbadmin")
    args = parser.parse_args()
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
        path = publish(conn, args.run_id, args.output_dir, args.base_url)
        print(f"REPORT_PATH={path}")
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
