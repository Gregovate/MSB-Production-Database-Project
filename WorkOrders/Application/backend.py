"""#419 Work Management: protected disposable-only save-capable browser candidate.

Run ONLY through the existing Server Management isolated-clone runner.
POST writes are clone-token/CSRF guarded. No email transport or Directus Flows.
"""
from __future__ import annotations

import logging
import os
import hmac
import hashlib
import re
from pathlib import Path

import psycopg2
from flask import Flask, Response, jsonify, request, send_from_directory

from repository import WorkManagementError, WorkManagementRepository
from commands import CloneCommands

APP_VERSION = "V1.0.0-work-orders-release-candidate"
BASE_DIR = Path(__file__).resolve().parent
CLOUDFLARE_HEADER = "Cf-Access-Authenticated-User-Email"
TICKET_KEY = re.compile(r"^(?:WO|INTAKE)-[1-9][0-9]{0,12}$")

app = Flask(__name__, static_folder=None)
app.logger.setLevel(logging.INFO)


def runtime_mode() -> str:
    """Never select Production merely because someone supplies a database DSN."""
    mode = os.environ.get("WORK_MGMT_RUNTIME_MODE", "disposable")
    if mode not in ("disposable", "production"):
        raise WorkManagementError("Unapproved Work Orders runtime mode.", 503)
    return mode


def store():
    if runtime_mode() == "production":
        from v1_runtime import V1Repository
        return V1Repository()
    return WorkManagementRepository()


def command_store():
    if runtime_mode() == "production":
        from v1_runtime import V1Commands
        return V1Commands()
    return CloneCommands()


def command_token(current: dict) -> str:
    if runtime_mode() == "disposable":
        return os.environ.get("WORK_MGMT_PREVIEW_CSRF_TOKEN", "")
    from v1_runtime import require_v1_production_configuration
    require_v1_production_configuration()
    key = os.environ.get("WORK_MGMT_PRODUCTION_COMMAND_SECRET", "")
    if len(key) < 48:
        raise WorkManagementError("Work Orders V1 CSRF secret unavailable.", 503)
    email = current.get("email", "")
    person = current.get("person_id", "")
    if not isinstance(email, str) or not str(person).isdigit():
        raise WorkManagementError("Verified V1 identity unavailable.", 403)
    return hmac.new(key.encode("utf-8"),
                    (email + ":" + str(person)).encode("utf-8"),
                    hashlib.sha256).hexdigest()


def runtime_response() -> dict:
    if runtime_mode() == "production":
        return {"runtime_mode": "production", "disposable_only": False,
                "notifications": "PENDING_CUTOVER"}
    return {"runtime_mode": "disposable", "disposable_only": True,
            "notifications": "NO_SEND"}


def actor() -> dict:
    """The trusted perimeter must remove client-supplied identity headers."""
    # BOTH preview and Production bind to loopback behind the existing trusted
    # server reverse proxy. An external request must never supply CF identity.
    if request.remote_addr not in ("127.0.0.1", "::1"):
        raise WorkManagementError("Work Orders is restricted to the approved local proxy.", 403)
    email = request.headers.get(CLOUDFLARE_HEADER, "").strip().lower()
    if not email or len(email) > 254 or "@" not in email:
        raise WorkManagementError("Cloudflare Access identity is required.", 401)
    return store().access(email)


def ticket_key(value: str) -> str:
    if not TICKET_KEY.fullmatch(value):
        raise WorkManagementError("Valid Work Order or Intake ID required.", 400)
    return value


@app.after_request
def no_cache(response: Response) -> Response:
    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "same-origin"
    return response


@app.get("/")
@app.get("/work-orders/")
def work_management() -> Response:
    actor()  # An unauthenticated user cannot receive the ticket application.
    return send_from_directory(BASE_DIR, "index.html")


@app.get("/work-orders/assets/<name>")
def work_management_asset(name: str) -> Response:
    if name not in {"app.js", "app.css", "review_actions.js"}:
        raise WorkManagementError("Asset not found.", 404)
    actor()
    return send_from_directory(BASE_DIR, name)


@app.get("/api/work-orders/health")
def work_management_health() -> Response:
    # Requires user identity and clone readiness. Not a public diagnostic.
    current = actor()
    return jsonify(
        status="ready" if runtime_mode() == "production" else "preview",
        version=APP_VERSION,
        read_only=False,
        person_id=current["person_id"],
        **runtime_response(),
    )


@app.get("/api/work-orders/access")
def access() -> Response:
    current = actor()
    return jsonify(access=current, version=APP_VERSION, read_only=False,
                   csrf_token=command_token(current), **runtime_response())


@app.get("/api/work-orders/assignees")
def assignees() -> Response:
    actor()
    return jsonify(assignees=store().assignees())


@app.get("/api/work-orders/reviewer-options")
def reviewer_options() -> Response:
    """Manager-only existing catalogs for no-save UX rehearsal."""
    who = actor()
    return jsonify(options=store().reviewer_options(who),
                   read_only=False, **runtime_response())


def require_command_safety() -> dict:
    """Same-origin custom header + server-issued token + verified actor."""
    current = actor()
    token = command_token(current)
    provided = request.headers.get("X-WO419-CSRF", "")
    allowed_length = 64 if runtime_mode() == "production" else 48
    if not re.fullmatch("[a-f0-9]{" + str(allowed_length) + "}", token) or not hmac.compare_digest(token, provided):
        raise WorkManagementError("Approved Work Orders session key required.", 403)
    if runtime_mode() == "production" and request.headers.get("X-MSB-Work-Order-Command") != "1":
        raise WorkManagementError("Protected Work Order command header missing.", 403)
    origin = request.headers.get("Origin", "")
    if origin and origin.rstrip("/") != request.host_url.rstrip("/"):
        raise WorkManagementError("Cross-origin ticket changes are not permitted.", 403)
    if not request.is_json:
        raise WorkManagementError("JSON command required.")
    return current


@app.post("/api/work-orders/commands")
def ticket_command() -> Response:
    current = require_command_safety()
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        raise WorkManagementError("Valid JSON command required.")
    action = body.get("action")
    ticket = body.get("ticket")
    result = command_store().perform(current, action, ticket, body)
    return jsonify(result=result, **runtime_response())


@app.get("/api/work-orders/tickets/<key>/activity")
def ticket_activity(key: str) -> Response:
    current = actor()
    result = command_store().activity(current, ticket_key(key))
    return jsonify(activity=result, **runtime_response())


@app.get("/api/work-orders/aging")
def open_work_order_aging() -> Response:
    """Full manager aging report; all undated WOs, including inactive exceptions."""
    who = actor()
    order = request.args.get("sort", "created_asc").strip().lower()
    include_planning = request.args.get("include_planning", "1") == "1"
    rows = store().aging_report(
        actor=who, sort=order, include_planning=include_planning)
    return jsonify(
        rows=rows,
        count=len(rows),
        inactive_count=sum(1 for row in rows if not row["active"]),
        unassigned_count=sum(1 for row in rows if not row["assigned_n"]),
        buckets={
            "0-7": sum(1 for row in rows if row["days_open"] is not None and row["days_open"] <= 7),
            "8-30": sum(1 for row in rows if row["days_open"] is not None and 8 <= row["days_open"] <= 30),
            "31-60": sum(1 for row in rows if row["days_open"] is not None and 31 <= row["days_open"] <= 60),
            "61+": sum(1 for row in rows if row["days_open"] is not None and row["days_open"] >= 61),
        },
        sort=order,
        read_only=True,
        all_open_work_orders=True,
        include_planning=include_planning,
    )


@app.get("/api/work-orders/manager-inbox")
def manager_inbox() -> Response:
    """Manager-only actionable Intake counts for the home-screen alert."""
    who = actor()
    return jsonify(inbox=store().manager_inbox(who),
                   **runtime_response())


@app.get("/api/work-orders/tickets")
def tickets() -> Response:
    who = actor()
    scope = request.args.get("scope", "mine").strip().lower()
    search = request.args.get("q", "").strip()
    if len(search) > 120:
        raise WorkManagementError("Search is too long.")
    raw_id = request.args.get("person_id", "").strip()
    if raw_id and (not raw_id.isdecimal() or int(raw_id) < 1):
        raise WorkManagementError("Invalid selected Person.")
    person_id = int(raw_id) if raw_id else None
    show_completed = request.args.get("show_completed", "0") == "1"
    sort = request.args.get("sort", "priority").strip().lower()
    include_planning = request.args.get("include_planning", "1") == "1"
    rows = store().tickets(
        actor=who, scope=scope, person_id=person_id,
        show_completed=show_completed, search=search, sort=sort,
        include_planning=include_planning,
    )
    for row in rows:
        row["category"] = (
            "Correction" if row["type"] == "TASK_FEEDBACK"
            else "Intake Request" if row["type"] == "INTAKE_REQUEST"
            else "Work Order"
        )
        row["status_label"] = (
            "Completed (date recorded)" if row["done_at"] is not None
            else "Submitted — awaiting review" if row["type"] != "WORK_ORDER"
            else "Not recorded complete"
        )
    return jsonify(tickets=rows, scope=scope, sort=sort,
                   include_planning=include_planning, read_only=True)


@app.get("/api/work-orders/tickets/<key>")
def ticket(key: str) -> Response:
    result = store().ticket(
        actor=actor(), ticket_key=ticket_key(key)
    )
    return jsonify(ticket=result, read_only=True)


@app.get("/api/work-orders/tickets/<key>/related-information")
def related_information(key: str) -> Response:
    result = store().related_information(
        actor=actor(), ticket_key=ticket_key(key)
    )
    return jsonify(related_information=result, read_only=True)


@app.errorhandler(WorkManagementError)
def work_error(exc: WorkManagementError) -> tuple[Response, int]:
    return jsonify(error=str(exc)), exc.status


@app.errorhandler(psycopg2.Error)
def database_error(exc: psycopg2.Error) -> tuple[Response, int]:
    app.logger.exception("Work Management disposable query failed")
    return jsonify(error="Work Management data is temporarily unavailable."), 503


@app.errorhandler(OSError)
def file_error(exc: OSError) -> tuple[Response, int]:
    app.logger.exception("Work Management preview resource missing")
    return jsonify(error="Work Management preview source unavailable."), 503


if __name__ == "__main__":
    raise SystemExit(
        "Work Management browser must be started by an approved disposable "
        "Server Management launcher, not by running backend.py directly."
    )
