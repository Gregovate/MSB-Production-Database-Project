"""#205 protected, read-only Administrator email recipient/content review.

This exposes no send, toggle, mass-mail action or arbitrary recipient input.
It consumes the SAME candidate digest classification and People lookup as the
one-day Manager SMTP pilot. The real 2026 Production session is never modified.
"""
from __future__ import annotations

from datetime import datetime
import importlib.util
from pathlib import Path
from string import Template
from zoneinfo import ZoneInfo

from flask import Blueprint, jsonify, make_response, send_from_directory

from setup_api import (
    SetupAuthenticationError, SetupCommandError, require_admin, setup_database_dsn,
)
from setup_scheduling_board_repository import SetupSchedulingBoardRepository

setup_manager_mail_admin_api = Blueprint("setup_manager_mail_admin_api", __name__)
CHICAGO = ZoneInfo("America/Chicago")
_PILOT_DIR = Path(__file__).resolve().parents[1] / "Acceptance" / "manager_mail_pilot"


def _piloted_digest_module():
    """Fail if the reviewed one-day Manager source isn't in the exact checkout."""
    filename = _PILOT_DIR / "manager_mail_pilot.py"
    if not filename.is_file():
        raise RuntimeError("Manager mail candidate source unavailable")
    spec = importlib.util.spec_from_file_location("_setup_205_mail_admin_preview", filename)
    if spec is None or spec.loader is None:
        raise RuntimeError("Manager mail candidate cannot be loaded")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _no_store(resp):
    resp.headers["Cache-Control"] = "private, no-store, max-age=0"
    resp.headers["Pragma"] = "no-cache"
    resp.headers["X-Content-Type-Options"] = "nosniff"
    return resp


@setup_manager_mail_admin_api.get("/notifications/")
def manager_email_admin_screen():
    """Only existing authenticated Setup Administrators may view recipient UI."""
    require_admin()
    response = make_response(send_from_directory(Path(__file__).resolve().parent, "setup_manager_mail_admin.html"))
    return _no_store(response)


@setup_manager_mail_admin_api.get("/api/setup/notifications/manager-preview")
def manager_email_preview():
    """Current authorized Manager roster plus 2026 report; NO SMTP, no writes."""
    _repo, authenticated, _access = require_admin()
    pilot = _piloted_digest_module()
    dsn = pilot.accepted_setup_dsn()
    roster = pilot.manager_directory(dsn)
    managers = [p for p in roster if p["send_eligible"]]
    if not managers:
        raise RuntimeError("No eligible Manager recipients; review People directory")
    board = SetupSchedulingBoardRepository(dsn).board(2026)
    now = datetime.now(CHICAGO)
    report = pilot.summarize(board, now.date())
    pilot.enrich_continuations(report, pilot.report_work_evidence(dsn, [r["id"] for r in report["continuation_rows"]]))
    report.update(pilot.container_summary(dsn, season_year=2026))
    subject = Template((_PILOT_DIR / "manager_digest_subject.txt").read_text(encoding="utf-8")).substitute(report).strip()
    if not subject or len(subject) > 250 or any(c in subject for c in "\r\n\x00"):
        raise RuntimeError("Email subject validation failed")

    # When the signed-in Administrator is a recipient, preview their exact mail.
    # A non-recipient Administrator sees an explicit sample recipient identity.
    preview_manager = next((p for p in managers if p["email"] == authenticated), managers[0])
    body = pilot.render((_PILOT_DIR / "manager_digest_template.txt").read_text(encoding="utf-8"), preview_manager, report)
    html_body = pilot.render_html((_PILOT_DIR / "manager_digest_html.html").read_text(encoding="utf-8"), preview_manager, report)
    from flask import request
    prefix = (request.script_root.rstrip("/") + "/") if request.host.split(":")[0] in {"localhost", "127.0.0.1"} else pilot.SETUP_URL
    html_body = html_body.replace(pilot.SETUP_URL, prefix)
    body = body.replace(pilot.SETUP_URL, prefix)
    recipients = [
        {"person_id":int(p["person_id"]), "name":p["display_name"], "email":p["email"],
         "status":p["review_status"], "reason":p["review_reason"],
         "people_manager":bool(p["is_manager"]),
         "setup_authorized":bool(p["can_manage_setup"])}
        for p in roster
    ]
    return _no_store(jsonify(
        mode="READ_ONLY_NO_SEND",
        generated_at_chicago=now.isoformat(),
        sender="MSB Production DB <no-reply@sheboyganlights.org>",
        intended_schedule="Existing 4:00 AM America/Chicago Manager brief",
        automatic_status="Existing scheduled sender; preview does not inspect or change delivery",
        captain_status="OFF",
        audience="Current authorized Setup Managers",
        recipient_count=len(managers), held_count=len(roster) - len(managers),
        reviewed_count=len(roster), recipients=recipients,
        subject=subject, body_text=body, body_html=html_body,
        continuation_evidence=report["continuation_rows"],
        preview_for=preview_manager["display_name"],
        report_date=report["report_date"],
        metrics={key:report[key] for key in (
            "total_tasks", "completed_tasks", "remaining_tasks",
            "blocked_tasks", "actual_pace", "required_pace",
            "projected_finish", "projection_confidence",
            "missing_report_occurrences", "continuation_needed",
            "readiness_exceptions", "captain_tbd_count",
            "completion_percent", "containers_total", "containers_park_recorded",
            "containers_outbound", "containers_empty_at_park",
            "containers_partial_at_park", "containers_returned",
            "containers_no_movement", "containers_location_review",
            "containers_contents_review_history", "containers_snapshot_as_of",
        )},
    ))


@setup_manager_mail_admin_api.errorhandler(SetupAuthenticationError)
def _missing_identity(_exc):
    return _no_store(jsonify(error="Protected Setup sign-in required")), 401


@setup_manager_mail_admin_api.errorhandler(SetupCommandError)
def _not_authorized(_exc):
    return _no_store(jsonify(error="Setup Administrator permission required")), 403


@setup_manager_mail_admin_api.errorhandler(Exception)
def _preview_stop(_exc):
    # Do not leak database/identity exceptions at the HTTP boundary.
    return _no_store(jsonify(
        error="STOP: Email recipient/report preview unavailable. No messages sent."
    )), 503
