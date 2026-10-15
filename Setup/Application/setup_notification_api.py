"""Protected #205 Manager notification preview / controlled self-test / report follow-up."""
from __future__ import annotations

from datetime import datetime
import os

from flask import Blueprint, Response, jsonify

from setup_api import (
    SetupAuthenticationError, SetupCommandError, json_body, require_manager,
    require_setup_command, setup_database_dsn,
)
from setup_notification_service import (
    DirectusSetupOutboxClient, SetupNotificationError, eligible_people,
    local_today, manager_email, notification_context, captain_email,
    organizational_email,
)
from setup_scheduling_board_repository import SetupSchedulingBoardRepository

setup_notification_api = Blueprint("setup_notification_api", __name__)


def _manager_context():
    _repo, email, _access = require_manager()
    dsn = setup_database_dsn()
    people = eligible_people(dsn)
    managers = [p for p in people if p["can_manage_setup"]]
    operator = next((p for p in managers if p["email"] == email), None)
    if not operator or not organizational_email(operator["email"]):
        raise SetupCommandError("Signed-in Manager has no verified current MSB organizational identity")
    board = SetupSchedulingBoardRepository(dsn).board(2026)
    if not board.get("session") or int(board["session"]["season_year"]) != 2026:
        raise SetupNotificationError("2026 Setup session is unavailable")
    today = local_today()
    return operator, people, board, today


@setup_notification_api.get("/api/setup/notifications/preview")
def preview() -> Response:
    operator, people, board, today = _manager_context()
    summary = notification_context(board, today)
    subject, message = manager_email(summary, today)
    # No recipient list, private Captain email, or other Manager email disclosure.
    return jsonify(
        kind="MANAGER_DAILY", subject=subject, body_text=message,
        counts={k:len(v) for k,v in summary.items()},
        signed_in_manager=operator["display_name"],
        send_enabled=False,
        flow_status="NOT_VERIFIED",
    )


@setup_notification_api.post("/api/setup/notifications/email-myself")
def email_myself() -> tuple[Response, int]:
    require_setup_command()
    payload = json_body()
    if payload:  # Prevent browser-supplied recipient, subject, or message.
        raise SetupCommandError("Email to Myself does not accept user-supplied recipients or body")
    operator, _people, board, today = _manager_context()
    subject, body = manager_email(notification_context(board, today), today)
    notice = {
        "kind":"MANAGER_SELF_TEST", "notice_date":today.isoformat(),
        "season_year":2026, "recipient_person_id":operator["person_id"],
        "recipient_email":operator["email"],
        "subject":"TEST — " + subject,
        "body_text":"CONTROLLED REVIEW TEST — not a daily digest.\n\n" + body,
        "message_key":f'2026|{today.isoformat()}|MANAGER_SELF_TEST|{operator["email"]}',
    }
    receipt = DirectusSetupOutboxClient().queue(notice,test_mode=True)
    return jsonify(result=receipt, notice="Directus outbox accepted request; inbox delivery is not yet proven"),202


@setup_notification_api.post("/api/setup/notifications/request-report/<int:assignment_id>")
def request_report(assignment_id: int) -> tuple[Response,int]:
    require_setup_command()
    if json_body():
        raise SetupCommandError("Request Report cannot override recipient, report or assignment identity")
    _operator, people, board, today = _manager_context()
    missing = notification_context(board,today)["overdue"]
    row = next((r for r in missing if r["assignment_id"] == assignment_id), None)
    if row is None:
        raise SetupCommandError("The original assignment is not currently missing a report")
    captain_id = row["captain_person_id"]
    captain = next((p for p in people if p["person_id"] == captain_id and p["can_read_setup"]), None)
    if captain is None:
        raise SetupCommandError("Captain has no eligible active MSB identity; Manager follow-up required")
    subject, body = captain_email([row])
    notice = {
        "kind":"CAPTAIN_REQUEST","season_year":2026,"notice_date":today.isoformat(),
        "recipient_person_id":captain_id,"recipient_email":captain["email"],
        "assignment_id":assignment_id,"subject":subject,"body_text":body,
        "message_key":f'2026|{today.isoformat()}|CAPTAIN_REQUEST|{captain["email"]}|{assignment_id}',
    }
    receipt = DirectusSetupOutboxClient().queue(notice,test_mode=False)
    return jsonify(result=receipt,notice="Request queued via Directus; delivery is not yet verified"),202


@setup_notification_api.errorhandler(SetupCommandError)
def bad_command(exc: SetupCommandError):
    return jsonify(error=str(exc)),403


@setup_notification_api.errorhandler(SetupAuthenticationError)
def bad_identity(exc: SetupAuthenticationError):
    return jsonify(error="Setup sign-in identity unavailable"),401


@setup_notification_api.errorhandler(SetupNotificationError)
def notification_unavailable(exc: SetupNotificationError):
    # Operational message is intentionally redacted at public access boundary.
    return jsonify(error=str(exc)),503
