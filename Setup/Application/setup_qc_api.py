"""#122 QC findings API; no scheduling, WO promotion or direct table writes."""
from __future__ import annotations

from flask import Blueprint, Response, jsonify, request
import psycopg2

from setup_api import (
    SetupAuthenticationError, SetupCommandError, require_reader, require_manager,
    require_setup_command, json_body, setup_database_dsn
)
from setup_qc_repository import SetupQcRepository

setup_qc_api = Blueprint("setup_qc_api", __name__)


def qc_repo() -> SetupQcRepository:
    return SetupQcRepository(setup_database_dsn())


def qc_integer(value, label: str, *, optional=False):
    if value is None and optional:
        return None
    if isinstance(value, bool):
        raise SetupCommandError(f"{label} must be a positive integer")
    try:
        number = int(value)
    except (ValueError, TypeError):
        raise SetupCommandError(f"{label} must be a positive integer")
    if number < 1:
        raise SetupCommandError(f"{label} must be a positive integer")
    return number


@setup_qc_api.get("/api/setup/qc")
def api_setup_qc_read() -> Response:
    _repo,email,_access=require_reader()
    year=qc_integer(request.args.get("season_year"),"season_year")
    return jsonify(qc=qc_repo().snapshot(email,year))


@setup_qc_api.get("/api/setup/qc/intake-candidates")
def api_setup_qc_intake_candidates() -> Response:
    _repo,email,_access=require_manager()
    year=qc_integer(request.args.get("season_year"),"season_year")
    return jsonify(intake_candidates=qc_repo().intake_candidates(email,year))


@setup_qc_api.post("/api/setup/qc/action")
def api_setup_qc_action() -> Response:
    require_setup_command()
    _repo,email,_access=require_reader()
    data=json_body()
    action=str(data.get("action") or "").strip().upper()
    allowed={"CLAIM_AUDIT","REPORT","REPORT_LINES","OBSERVATION","CLAIM_REPAIR","REPAIRED",
             "RETEST_PASS","RETEST_FAIL","REOPEN","LINK_INTAKE"}
    if action not in allowed:
        raise SetupCommandError("Unknown QC action")
    cmd={
        "action":action,
        "setup_session_task_id":qc_integer(data.get("setup_session_task_id"),"setup_session_task_id"),
        "qc_finding_id":qc_integer(data.get("qc_finding_id"),"qc_finding_id",optional=True),
        "intake_id":qc_integer(data.get("intake_id"),"intake_id",optional=True),
    }
    for key, limit in (("note",6000),("title",200),("location_detail",500),
                       ("discovery_phase",32)):
        text=str(data.get(key) or "").strip()
        if len(text)>limit:
            raise SetupCommandError(f"{key} is too long")
        cmd[key]=text or None
    return jsonify(result=qc_repo().command(email,cmd))


@setup_qc_api.errorhandler(SetupAuthenticationError)
def qc_auth_error(exc: SetupAuthenticationError):
    return jsonify(error="Sign-in identity is unavailable"),401


@setup_qc_api.errorhandler(SetupCommandError)
def qc_command_error(exc: SetupCommandError):
    return jsonify(error=str(exc)),403


@setup_qc_api.errorhandler(psycopg2.Error)
def qc_db_error(exc: psycopg2.Error):
    status={"42501":403,"23505":409,"23514":409,"22023":400,"P0002":404}.get(exc.pgcode,503)
    detail=exc.diag.message_primary or "QC operation unavailable"
    return jsonify(error=detail),status
