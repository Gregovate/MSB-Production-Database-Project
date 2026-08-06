"""
MSB Database - LOR reconciliation preflight API
backend.py

Initial Release : 2026-08-05  V0.1.0
Current Version : 2026-08-06  V0.3.2
Author          : GAL / OpenAI

Purpose:
    Provide the authenticated, same-origin API used by the reusable LOR
    preflight browser. PostgreSQL remains authoritative for frozen candidates,
    append-only decisions, Finish, Cancel, and report completion.

Revision History:
    2026-08-06  GAL / OpenAI  V0.3.2
        Made snapshot ownership authoritative on the landing page and Start
        endpoint. Any unfinished run is resumed first; otherwise the row whose
        import_run_id matches the current snapshot controls eligibility. A
        snapshot can never create a second reconciliation attempt.
    2026-08-06  GAL / OpenAI  V0.3.1
        Removed the repository-layout assumption from report publication.
        Production now supplies the deployed publisher's absolute path through
        LOR_REPORT_PUBLISHER_PATH, and the backend rejects a missing file
        before attempting to run it.
    2026-08-06  GAL / OpenAI  V0.3.0
        Added the lor2db landing-page status contract and guarded Start
        endpoint. The operator never supplies an import_run_id; Start captures
        the current committed snapshot through the installed database function.
    2026-08-05  GAL / OpenAI  V0.2.1
        Removed direct reconciliation-table row locks that incorrectly
        required the least-privilege application role to have UPDATE rights.
        Installed SECURITY DEFINER functions and procedures remain the only
        database writers and record the Cloudflare-authenticated operator.
    2026-08-05  GAL / OpenAI  V0.2.0
        Made per-decision comments optional and return PostgreSQL's primary
        rejection message instead of an unhelpful generic HTTP 500.
    2026-08-05  GAL / OpenAI  V0.1.0
        Initial secured read, decision, bulk-decision, Cancel, Finish, and
        report-publication implementation.
"""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
from collections import defaultdict
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator
from urllib.parse import unquote, urlparse

import psycopg2
from flask import Flask, Response, jsonify, request
from psycopg2.extras import RealDictCursor


APP_VERSION = "V0.3.2"
FALLBACK_ACTIONS = {"DEFER", "CORRECT_SOURCE_REQUIRED", "RESTORE_TO_LOR_REQUIRED"}
ACCEPTED_RUN_STATES = {"AWAITING_DECISIONS", "READY_TO_FINISH"}
ENTITY_VIEWS = {
    "DISPLAY": "ops.v_lor_reconciliation_operator_display_review",
    "STAGE": "ops.v_lor_reconciliation_operator_stage_review",
    "SCENE": "ops.v_lor_reconciliation_operator_scene_review",
    "SCENE_DISPLAY": "ops.v_lor_reconciliation_operator_scene_display_review",
}

app = Flask(__name__)

OPEN_RUN_STATES = {
    "STARTING", "PREFLIGHT", "AWAITING_DECISIONS", "READY_TO_FINISH",
    "PROMOTING", "VALIDATING", "REPORTING",
}
class ApiError(RuntimeError):
    """Expected request failure with a safe HTTP status and message."""

    def __init__(self, message: str, status: int = 400) -> None:
        super().__init__(message)
        self.status = status


def required_setting(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise RuntimeError(f"Required setting {name} is missing")
    return value


def operator_email() -> str:
    """Trust the Access identity only behind the required loopback proxy."""
    email = request.headers.get("Cf-Access-Authenticated-User-Email", "").strip().lower()
    if not email:
        raise ApiError("Cloudflare Access operator identity is missing", 401)
    allowed = {
        item.strip().lower()
        for item in required_setting("LOR_PREFLIGHT_OPERATORS").split(",")
        if item.strip()
    }
    if email not in allowed:
        raise ApiError("This account is not authorized for LOR reconciliation", 403)
    return email


@contextmanager
def database() -> Iterator[Any]:
    conn = psycopg2.connect(required_setting("LOR_PREFLIGHT_DATABASE_URL"))
    try:
        yield conn
    finally:
        conn.close()


def fetch_one(cur: Any, query: str, parameters: tuple[Any, ...]) -> dict[str, Any]:
    cur.execute(query, parameters)
    row = cur.fetchone()
    if row is None:
        raise ApiError("Reconciliation run was not found", 404)
    return dict(row)


def human_label(value: str | None) -> str:
    return (value or "Unknown check").replace("_", " ").title()


def proposed_action(actions: list[str]) -> str | None:
    proposed = [action for action in actions if action not in FALLBACK_ACTIONS]
    return proposed[0] if len(proposed) == 1 else None


def decision_version(groups: list[dict[str, Any]]) -> str:
    """Stable token binding final review to the exact persisted decisions."""
    state = [
        [group["lor_reconciliation_group_id"], group.get("effective_action_id")]
        for group in sorted(groups, key=lambda item: item["lor_reconciliation_group_id"])
    ]
    return hashlib.sha256(json.dumps(state, separators=(",", ":")).encode()).hexdigest()


def facts_for(entity_type: str, members: list[dict[str, Any]]) -> list[dict[str, str]]:
    facts: list[dict[str, str]] = []
    row = members[0] if members else {}
    candidates = {
        "Stage": row.get("proposed_stage_key") or row.get("current_stage_key") or row.get("resolved_stage_key"),
        "Preview": row.get("preview_name") or row.get("source_name") or row.get("preview_id"),
        "Scene": row.get("scene_name") or row.get("scene_id"),
        "Location": row.get("location_summary"),
        "Members": len(members) if len(members) > 1 else None,
    }
    for label, value in candidates.items():
        if value not in (None, ""):
            facts.append({"label": label, "value": str(value)})
    return facts


def load_run(conn: Any, run_id: int) -> dict[str, Any]:
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        run = fetch_one(cur, """
            SELECT lor_reconciliation_run_id, import_run_id, status,
                   validation_state, unresolved_count, deferred_count,
                   blocked_count
            FROM ops.lor_reconciliation_run
            WHERE lor_reconciliation_run_id = %s
        """, (run_id,))
        cur.execute("""
            SELECT *
            FROM ops.v_lor_reconciliation_group_review
            WHERE lor_reconciliation_run_id = %s
              AND (decision_required OR effective_action_id IS NOT NULL)
            ORDER BY logical_group_key, lor_reconciliation_group_id
        """, (run_id,))
        groups = [dict(row) for row in cur.fetchall()]

        members: dict[int, list[dict[str, Any]]] = defaultdict(list)
        for entity_type, view in ENTITY_VIEWS.items():
            cur.execute(
                f"SELECT * FROM {view} WHERE lor_reconciliation_run_id = %s",
                (run_id,),
            )
            for row in cur.fetchall():
                item = dict(row)
                item["entity_type"] = entity_type
                if item.get("lor_reconciliation_group_id") is not None:
                    members[item["lor_reconciliation_group_id"]].append(item)

    candidates = []
    for group in groups:
        group_id = group["lor_reconciliation_group_id"]
        rows = members[group_id]
        first = rows[0] if rows else {}
        actions = list(group.get("allowed_action_types") or [])
        candidate = {
            "group_id": group_id,
            "entity_type": group["entity_type"],
            "entity_key": group["logical_group_key"],
            "classification_label": human_label(first.get("classification_code") or group.get("group_kind")),
            "operator_message": first.get("operator_message") or group.get("operator_message") or "Operator decision required.",
            "allowed_actions": actions,
            "proposed_action": proposed_action(actions),
            "effective_action_id": group.get("effective_action_id"),
            "effective_action_type": group.get("effective_action_type"),
            "effective_reason": group.get("effective_reason"),
            "current_display_name": first.get("current_display_name"),
            "proposed_display_name": first.get("proposed_display_name"),
            "facts": facts_for(group["entity_type"], rows),
            "members": rows,
        }
        candidates.append(candidate)

    document = {
        "run_id": run["lor_reconciliation_run_id"],
        "import_run_id": run["import_run_id"],
        "status": run["status"],
        "validation_state": run["validation_state"],
        "unresolved_count": run["unresolved_count"],
        "deferred_count": run["deferred_count"],
        "blocked_count": run["blocked_count"],
        "candidates": candidates,
        "operator": operator_email(),
    }
    document["decision_version"] = decision_version(groups)
    return document


def dashboard_state(snapshot: dict[str, Any] | None,
                    snapshot_run: dict[str, Any] | None) -> dict[str, Any]:
    """Derive the only valid next operator action from persisted state."""
    if snapshot_run and snapshot_run["status"] in OPEN_RUN_STATES:
        return {
            "state": "IN_PROGRESS",
            "message": (
                f"Reconciliation run {snapshot_run['lor_reconciliation_run_id']} "
                f"for snapshot {snapshot_run['import_run_id']} is unfinished "
                f"({snapshot_run['status'].replace('_', ' ').lower()})."
            ),
            "can_start": False,
            "action": {
                "kind": "review",
                "label": "Continue previous reconciliation",
                "url": (
                    "preflight/?run="
                    f"{snapshot_run['lor_reconciliation_run_id']}"
                ),
            },
        }

    if snapshot is None:
        return {
            "state": "NO_SNAPSHOT",
            "message": "No committed LOR snapshot is available.",
            "can_start": False,
            "action": None,
        }

    snapshot_id = snapshot["import_run_id"]
    if snapshot_run:
        return {
            "state": "SNAPSHOT_CONSUMED",
            "message": (
                f"Snapshot {snapshot_id} belongs to reconciliation run "
                f"{snapshot_run['lor_reconciliation_run_id']} "
                f"({snapshot_run['status'].replace('_', ' ').lower()})."
            ),
            "can_start": False,
            "action": None,
        }

    return {
        "state": "READY_TO_START",
        "message": f"Snapshot {snapshot_id} is ready for reconciliation.",
        "can_start": True,
        "action": {
            "kind": "start",
            "label": "Start reconciliation",
            "url": None,
        },
    }


def load_dashboard(conn: Any) -> dict[str, Any]:
    """Load the current snapshot and its authoritative reconciliation owner."""
    with conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute("""
            SELECT import_run_id, run_ts, notes, parser_version,
                   parser_started_at, parser_completed_at, parser_actor,
                   parser_host, source_preview_folder, preview_count,
                   scene_count, prop_count, sub_prop_count,
                   dmx_channel_count, scene_lor_prop_count,
                   ingest_script_version, ingest_actor, ingest_host,
                   ingest_started_at, ingest_completed_at
            FROM lor_snap.v_current_run
        """)
        row = cur.fetchone()
        snapshot = dict(row) if row else None

        # An unfinished run always takes precedence, even if a newer snapshot
        # was ingested after that run captured its immutable source snapshot.
        # Otherwise, only the run linked to the current snapshot determines
        # whether Start is legal. Numeric recency is not snapshot ownership.
        cur.execute("""
            SELECT lor_reconciliation_run_id, import_run_id, status,
                   started_at, completed_at, cancelled_at, failed_at,
                   validation_state, structural_failure_count,
                   blocked_count, deferred_count, unresolved_count,
                   report_url, report_published_at, cancellation_reason,
                   failure_message
            FROM ops.lor_reconciliation_run
            WHERE status = ANY(%s)
               OR import_run_id = %s
            ORDER BY
                CASE WHEN status = ANY(%s) THEN 0 ELSE 1 END,
                lor_reconciliation_run_id DESC
            LIMIT 1
        """, (
            list(OPEN_RUN_STATES),
            snapshot["import_run_id"] if snapshot else None,
            list(OPEN_RUN_STATES),
        ))
        row = cur.fetchone()
        snapshot_run = dict(row) if row else None

    state = dashboard_state(snapshot, snapshot_run)
    return {
        "snapshot": snapshot,
        # Retain the response key for the deployed browser contract. Its value
        # is now the run that owns/blocks the snapshot, not merely the last ID.
        "latest_run": snapshot_run,
        "workflow": state,
        "reports_url": "reports/",
        "operator": operator_email(),
        "parser_ingest_mode": "MANUAL",
    }


def json_body() -> dict[str, Any]:
    payload = request.get_json(silent=True)
    if not isinstance(payload, dict):
        raise ApiError("A JSON request body is required")
    return payload


def optional_decision_reason(payload: dict[str, Any], action: str) -> str:
    """Keep a nonblank audit reason without requiring an operator comment."""
    reason = str(payload.get("reason") or "").strip()
    return reason or f"Operator selected {action}; no additional comment provided."


def require_reason(payload: dict[str, Any]) -> str:
    """Require an explanation only for run-level cancellation."""
    reason = str(payload.get("reason") or "").strip()
    if not reason:
        raise ApiError("A specific cancellation reason is required")
    return reason


def publish_report(run_id: int) -> None:
    # GAL 2026-08-06: Production deploys a flattened /opt/lor-preflight
    # application, not the repository's LOR2DB directory tree. An explicit
    # absolute path prevents repository reorganizations from silently changing
    # the executable selected by the production service.
    script = Path(required_setting("LOR_REPORT_PUBLISHER_PATH"))
    if not script.is_absolute():
        raise RuntimeError("LOR_REPORT_PUBLISHER_PATH must be an absolute path")
    if not script.is_file():
        raise ApiError(f"Report publisher is not installed: {script}", 500)
    parsed = urlparse(required_setting("LOR_PREFLIGHT_DATABASE_URL"))
    if not parsed.hostname or not parsed.username or not parsed.password:
        raise RuntimeError("LOR_PREFLIGHT_DATABASE_URL must include host, user, and password")
    database_name = parsed.path.lstrip("/") or "msb"
    command = [
        sys.executable, str(script), "--run-id", str(run_id),
        "--output-dir", required_setting("LOR_REPORT_OUTPUT_DIR"),
        "--base-url", required_setting("LOR_REPORT_BASE_URL"),
        "--pg-host", parsed.hostname,
        "--pg-db", unquote(database_name),
        "--pg-user", unquote(parsed.username),
    ]
    child_environment = os.environ.copy()
    child_environment["PGPASSWORD"] = unquote(parsed.password)
    completed = subprocess.run(
        command, capture_output=True, text=True, timeout=180, check=False,
        env=child_environment,
    )
    if completed.returncode:
        detail = (completed.stderr or completed.stdout).strip()
        raise ApiError(f"Production update committed, but report publication failed: {detail}", 500)


@app.errorhandler(ApiError)
def api_error(error: ApiError) -> tuple[Response, int]:
    return jsonify(error=str(error)), error.status


@app.errorhandler(psycopg2.Error)
def database_error(error: psycopg2.Error) -> tuple[Response, int]:
    """Return the safe primary database rejection and retain the full log."""
    app.logger.exception("PostgreSQL rejected a preflight API request")
    primary = getattr(error.diag, "message_primary", None)
    return jsonify(error=f"Database rejected the decision: {primary or 'unknown database error'}"), 409


@app.errorhandler(Exception)
def unexpected_error(error: Exception) -> tuple[Response, int]:
    app.logger.exception("Unhandled preflight API error")
    return jsonify(error="The preflight service encountered an internal error"), 500


@app.get("/health")
def health() -> Response:
    return jsonify(status="ok", version=APP_VERSION)


@app.get("/runs/<int:run_id>")
def get_run(run_id: int) -> Response:
    operator_email()
    with database() as conn:
        return jsonify(load_run(conn, run_id))


@app.get("/dashboard")
def get_dashboard() -> Response:
    operator_email()
    with database() as conn:
        return jsonify(load_dashboard(conn))


@app.post("/runs/start")
def start_run() -> Response:
    """Start only when the current snapshot has no open/completed attempt."""
    operator = operator_email()
    with database() as conn:
        with conn.cursor() as cur:
            # Use the same transaction-scoped lock as the installed Start
            # function so two browser requests cannot pass the eligibility
            # check and create competing attempts.
            cur.execute(
                "SELECT pg_advisory_xact_lock(hashtext(%s))",
                ("ops.lor_reconciliation.start",),
            )
            current = load_dashboard(conn)
            if not current["workflow"]["can_start"]:
                raise ApiError(current["workflow"]["message"], 409)
            cur.execute(
                "SELECT ops.f_start_lor_reconciliation(%s)",
                (f"lor-preflight-api:{operator}",),
            )
            run_id = cur.fetchone()[0]
        conn.commit()
        run = load_run(conn, run_id)
    return jsonify(
        run_id=run_id,
        import_run_id=run["import_run_id"],
        status=run["status"],
        review_url=f"preflight/?run={run_id}",
    ), 201


@app.post("/runs/<int:run_id>/groups/<int:group_id>/decisions")
def record_decision(run_id: int, group_id: int) -> Response:
    operator = operator_email()
    payload = json_body()
    action = str(payload.get("action_type") or "").strip().upper()
    reason = optional_decision_reason(payload, action)
    expected = payload.get("expected_action_id")
    if action == "REASSOCIATE_DISPLAY":
        raise ApiError("Reassociation requires the dedicated complete-mapping interface")
    with database() as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                SELECT g.allowed_action_types,
                       (SELECT a.lor_reconciliation_action_id
                        FROM ops.lor_reconciliation_action AS a
                        WHERE a.lor_reconciliation_group_id = g.lor_reconciliation_group_id
                        ORDER BY a.acted_at DESC, a.lor_reconciliation_action_id DESC
                        LIMIT 1) AS effective_action_id
                FROM ops.lor_reconciliation_group AS g
                WHERE g.lor_reconciliation_run_id = %s
                  AND g.lor_reconciliation_group_id = %s
            """, (run_id, group_id))
            group = cur.fetchone()
            if group is None:
                raise ApiError("The selected group does not belong to this run", 404)
            if group["effective_action_id"] != expected:
                raise ApiError("This decision changed after the page loaded; the run has been refreshed", 409)
            if action not in group["allowed_action_types"]:
                raise ApiError("The selected action is not allowed for this group")
            cur.execute(
                "SELECT ops.f_record_lor_reconciliation_action(%s,%s,%s,%s,NULL,%s)",
                (run_id, group_id, action, reason, f"lor-preflight-api:{operator}"),
            )
        conn.commit()
        return jsonify(run=load_run(conn, run_id))


@app.post("/runs/<int:run_id>/decisions/bulk")
def record_bulk_decision(run_id: int) -> Response:
    operator = operator_email()
    payload = json_body()
    raw_ids = payload.get("group_ids")
    if not isinstance(raw_ids, list) or not raw_ids:
        raise ApiError("Select at least one reconciliation group")
    try:
        group_ids = [int(value) for value in raw_ids]
    except (TypeError, ValueError) as exc:
        raise ApiError("Every selected group ID must be numeric") from exc
    action = str(payload.get("action_type") or "").strip().upper()
    reason = optional_decision_reason(payload, action)
    if action == "REASSOCIATE_DISPLAY":
        raise ApiError("Reassociation cannot be recorded as a bulk action")
    with database() as conn:
        with conn.cursor() as cur:
            # Membership is checked read-only here. The SECURITY DEFINER bulk
            # function repeats the authoritative validation and owns locking.
            cur.execute("""
                SELECT lor_reconciliation_group_id
                FROM ops.lor_reconciliation_group
                WHERE lor_reconciliation_run_id = %s
                  AND lor_reconciliation_group_id = ANY(%s)
                ORDER BY lor_reconciliation_group_id
            """, (run_id, group_ids))
            locked = [row[0] for row in cur.fetchall()]
            if sorted(locked) != sorted(group_ids):
                raise ApiError("At least one selected group does not belong to this run", 404)
            cur.execute(
                "SELECT * FROM ops.f_record_lor_reconciliation_bulk_action(%s,%s,%s,%s,%s)",
                (run_id, group_ids, action, reason, f"lor-preflight-api:{operator}"),
            )
            cur.fetchall()
        conn.commit()
        return jsonify(run=load_run(conn, run_id))


@app.post("/runs/<int:run_id>/cancel")
def cancel_run(run_id: int) -> Response:
    operator = operator_email()
    reason = require_reason(json_body())
    with database() as conn:
        with conn.cursor() as cur:
            cur.execute("CALL ops.p_cancel_lor_reconciliation(%s,%s,%s)",
                        (run_id, reason, f"lor-preflight-api:{operator}"))
        conn.commit()
    publish_report(run_id)
    return jsonify(run_id=run_id, status="CANCELLED")


@app.post("/runs/<int:run_id>/finish")
def finish_run(run_id: int) -> Response:
    operator = operator_email()
    expected_version = str(json_body().get("expected_decision_version") or "")
    with database() as conn:
        # The decision version prevents proceeding from a stale final-review
        # page. The SECURITY DEFINER Finish procedure owns authoritative locks.
        document = load_run(conn, run_id)
        if document["status"] == "REPORTING":
            conn.rollback()
        else:
            if document["status"] != "READY_TO_FINISH" or document["unresolved_count"] != 0:
                raise ApiError("The run is not ready to finish", 409)
            if not expected_version or expected_version != document["decision_version"]:
                raise ApiError("Decisions changed after final review; review the refreshed run", 409)
            with conn.cursor() as cur:
                cur.execute("CALL ops.p_finish_lor_reconciliation(%s,%s)",
                            (run_id, f"lor-preflight-api:{operator}"))
            conn.commit()
    publish_report(run_id)
    return jsonify(run_id=run_id, status="COMPLETED")


if __name__ == "__main__":
    # Development only. Production uses gunicorn bound to 127.0.0.1.
    app.run(host="127.0.0.1", port=int(os.environ.get("PORT", "8784")), debug=False)
