"""#419 Work Management: protected disposable-only save-capable browser candidate.

Run ONLY through the existing Server Management isolated-clone runner.
POST writes are clone-token/CSRF guarded. No email transport or Directus Flows.
"""
from __future__ import annotations

import logging
import os
import hmac
import re
from pathlib import Path

import psycopg2
from flask import Flask, Response, jsonify, request, send_from_directory

from repository import WorkManagementError, WorkManagementRepository
from commands import CloneCommands

APP_VERSION = "V0.3.0-disposable-write-review"
BASE_DIR = Path(__file__).resolve().parent
CLOUDFLARE_HEADER = "Cf-Access-Authenticated-User-Email"
TICKET_KEY = re.compile(r"^(?:WO|INTAKE)-[1-9][0-9]{0,12}$")

app = Flask(__name__, static_folder=None)
app.logger.setLevel(logging.INFO)


def actor() -> dict:
    """The trusted perimeter must remove client-supplied identity headers."""
    # Temporary preview must remain localhost-only even if a port is misbound.
    if request.remote_addr not in ("127.0.0.1", "::1"):
        raise WorkManagementError("Preview is restricted to the approved local tunnel.", 403)
    email = request.headers.get(CLOUDFLARE_HEADER, "").strip().lower()
    if not email or len(email) > 254 or "@" not in email:
        raise WorkManagementError("Cloudflare Access identity is required.", 401)
    return WorkManagementRepository().access(email)


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
        status="preview",
        version=APP_VERSION,
        read_only=False,
        disposable_only=True,
        person_id=current["person_id"],
    )


@app.get("/api/work-orders/access")
def access() -> Response:
    return jsonify(access=actor(), version=APP_VERSION, read_only=False,
                   csrf_token=os.environ.get("WORK_MGMT_PREVIEW_CSRF_TOKEN", ""))


@app.get("/api/work-orders/assignees")
def assignees() -> Response:
    actor()
    return jsonify(assignees=WorkManagementRepository().assignees())


@app.get("/api/work-orders/reviewer-options")
def reviewer_options() -> Response:
    """Manager-only existing catalogs for no-save UX rehearsal."""
    who = actor()
    return jsonify(options=WorkManagementRepository().reviewer_options(who),
                   read_only=False, disposable_only=True)


def require_command_safety() -> dict:
    """Reject cross-site requests and any missing disposable session key."""
    current = actor()
    token = os.environ.get("WORK_MGMT_PREVIEW_CSRF_TOKEN", "")
    provided = request.headers.get("X-WO419-CSRF", "")
    if not re.fullmatch(r"[a-f0-9]{48}", token) or not hmac.compare_digest(token, provided):
        raise WorkManagementError("Approved disposable session key required.", 403)
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
    result = CloneCommands().perform(current, action, ticket, body)
    return jsonify(result=result, disposable_only=True, notifications="NO_SEND")


@app.get("/api/work-orders/tickets/<key>/activity")
def ticket_activity(key: str) -> Response:
    current = actor()
    result = CloneCommands().activity(current, ticket_key(key))
    return jsonify(activity=result, disposable_only=True, notifications="NO_SEND")


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
    rows = WorkManagementRepository().tickets(
        actor=who, scope=scope, person_id=person_id,
        show_completed=show_completed, search=search,
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
    return jsonify(tickets=rows, scope=scope, read_only=True)


@app.get("/api/work-orders/tickets/<key>")
def ticket(key: str) -> Response:
    result = WorkManagementRepository().ticket(
        actor=actor(), ticket_key=ticket_key(key)
    )
    return jsonify(ticket=result, read_only=True)


@app.get("/api/work-orders/tickets/<key>/related-information")
def related_information(key: str) -> Response:
    result = WorkManagementRepository().related_information(
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
