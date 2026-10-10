"""Protected API for Setup #88 physical movement capture."""
from __future__ import annotations

from datetime import datetime
from uuid import UUID

import psycopg2
from flask import Blueprint, Response, jsonify, request

from setup_api import (
    SetupAuthenticationError,
    SetupCommandError,
    json_body,
    require_movement_operator,
    require_reader,
    require_setup_command,
    setup_database_dsn,
)
from setup_material_readiness_repository import SetupMaterialReadinessRepository
from setup_movement_repository import (
    SetupMovementConflictError,
    SetupMovementRepository,
    SetupMovementRepositoryError,
)

setup_movement_api = Blueprint("setup_movement_api", __name__)

_OUTBOUND_MOVEMENT = {
    "PICKED",
    "LOADED",
    "IN_TRANSIT",
    "DELIVERED",
    "UNLOADED",
    "STAGED",
    "PLACED",
    "RELOCATED",
}


def repo() -> SetupMovementRepository:
    return SetupMovementRepository(setup_database_dsn())


def positive_int(value: object, name: str) -> int:
    if isinstance(value, bool):
        raise SetupCommandError(f"{name} must be an integer")
    try:
        parsed = int(value)
    except (TypeError, ValueError) as exc:
        raise SetupCommandError(f"{name} is required") from exc
    if parsed <= 0:
        raise SetupCommandError(f"{name} must be greater than zero")
    return parsed


def optional_positive_int(value: object, name: str) -> int | None:
    if value in (None, ""):
        return None
    return positive_int(value, name)


def required_uuid(value: object, name: str) -> UUID:
    try:
        return UUID(str(value or "").strip())
    except (TypeError, ValueError, AttributeError) as exc:
        raise SetupCommandError(f"{name} must be a UUID") from exc


def required_timestamp(value: object, name: str) -> str:
    text = str(value or "").strip()
    if not text:
        raise SetupCommandError(f"{name} is required")
    candidate = text[:-1] + "+00:00" if text.endswith("Z") else text
    try:
        parsed = datetime.fromisoformat(candidate)
    except ValueError as exc:
        raise SetupCommandError(f"{name} must be an ISO-8601 timestamp") from exc
    if parsed.tzinfo is None:
        raise SetupCommandError(f"{name} must include a timezone")
    return text


def optional_float(value: object, name: str) -> float | None:
    if value in (None, ""):
        return None
    try:
        return float(value)
    except (TypeError, ValueError) as exc:
        raise SetupCommandError(f"{name} must be numeric") from exc


def optional_nonnegative_int(value: object, name: str) -> int | None:
    if value in (None, ""):
        return None
    if isinstance(value, bool):
        raise SetupCommandError(f"{name} must be an integer")
    try:
        parsed = int(value)
    except (TypeError, ValueError) as exc:
        raise SetupCommandError(f"{name} must be an integer") from exc
    if parsed < 0:
        raise SetupCommandError(f"{name} cannot be negative")
    return parsed


def optional_text(value: object) -> str | None:
    text = str(value or "").strip()
    return text or None


def optional_positive_int_list(value: object, name: str) -> list[int]:
    if value in (None, ""):
        return []
    if not isinstance(value, list):
        raise SetupCommandError(f"{name} must be a JSON array")
    result: list[int] = []
    for item in value:
        parsed = positive_int(item, name)
        if parsed not in result:
            result.append(parsed)
    return result


def normalize_gps_quality(value: object) -> str:
    quality = str(value or "UNASSESSED").strip().upper()
    if quality not in {"UNASSESSED", "QUESTIONABLE", "BAD"}:
        raise SetupCommandError("gps_quality must be UNASSESSED, QUESTIONABLE, or BAD")
    return quality


def normalize_asset_type(value: object) -> str:
    asset_type = str(value or "").strip().upper()
    if asset_type not in {"CONTAINER", "DISPLAY"}:
        raise SetupCommandError("asset_type must be CONTAINER or DISPLAY")
    return asset_type


def normalize_action(value: object) -> str:
    action = str(value or "").strip().upper()
    if action not in {
        "PICKED",
        "LOADED",
        "IN_TRANSIT",
        "DELIVERED",
        "UNLOADED",
        "STAGED",
        "PLACED",
        "RELOCATED",
        "RETURNED",
        "CONTAINER_MOVE",
        "DISPLAY_MOVE",
    }:
        raise SetupCommandError("Unsupported Setup movement action")
    return action


def _validate_live_pick_demand(
    *,
    season_year: int,
    asset_type: str,
    asset_id: int,
) -> None:
    status = SetupMaterialReadinessRepository(
        setup_database_dsn()
    ).pick_demand_status(
        season_year=season_year,
        asset_type=asset_type,
        asset_id=asset_id,
    )

    if not status.get("demanded"):
        raise SetupMovementConflictError("Asset is not on the current Pick List.")

    if status.get("pick_delayed"):
        raise SetupMovementConflictError("DELAYED — DO NOT PICK YET")

    observation = status.get("current_observation") or {}
    movement_status = str(observation.get("movement_status") or "").upper()
    if movement_status in _OUTBOUND_MOVEMENT:
        raise SetupMovementConflictError(
            f"Asset is already in {movement_status} movement state."
        )

    # Preserve conservative behavior for movement evidence created before
    # explicit movement_status existed. RETURNED is the explicit future reset.
    if not movement_status and observation.get("last_movement_event_id") is not None:
        raise SetupMovementConflictError(
            "Asset already has Setup movement evidence and is not an active home pick."
        )


@setup_movement_api.get("/api/setup/locate/assets")
def api_setup_locate_assets() -> Response:
    """Read #88 state only; never repair missing geographic continuity here."""
    base_repo, _email, _access = require_reader()
    raw_year = request.args.get("season_year", "").strip()
    if not raw_year.isdigit() or len(raw_year) != 4:
        raise SetupCommandError("A four-digit season_year is required")
    session = base_repo.movement_summary(int(raw_year))
    if session.get("setup_session_id") is None:
        return jsonify(error="No Setup Session exists for this year"), 404
    from setup_production_report import movement_picture
    from setup_locate_assets import locate_assets
    response = jsonify(locate_assets(movement_picture(repo(), session["setup_session_id"], include_unobserved=True)))
    response.headers["Cache-Control"] = "no-store, max-age=0"
    return response


@setup_movement_api.get("/api/setup/movements/search")
def api_setup_movement_search() -> Response:
    require_movement_operator()
    query = str(request.args.get("q") or "").strip()
    if not query:
        return jsonify(assets=[])
    if len(query) > 120:
        raise SetupCommandError("Movement asset search is too long")
    return jsonify(assets=repo().search_assets(query=query))


@setup_movement_api.get("/api/setup/movements/state")
def api_setup_movement_state() -> Response:
    require_reader()
    raw_year = request.args.get("season_year", "").strip()
    if not raw_year.isdigit():
        raise SetupCommandError("season_year is required")
    asset_type = normalize_asset_type(request.args.get("asset_type"))
    asset_id = positive_int(request.args.get("asset_id"), "asset_id")
    state = repo().current_state(
        season_year=int(raw_year),
        asset_type=asset_type,
        asset_id=asset_id,
    )
    if state is None:
        return jsonify(error="Movement asset was not found"), 404
    return jsonify(state=state)


@setup_movement_api.get("/api/setup/movements/container-contents")
def api_setup_container_contents() -> Response:
    require_movement_operator()
    raw_year = request.args.get("season_year", "").strip()
    if not raw_year.isdigit():
        raise SetupCommandError("season_year is required")
    container_id = positive_int(request.args.get("container_id"), "container_id")
    contents = repo().container_contents(
        season_year=int(raw_year),
        container_id=container_id,
    )
    if contents is None:
        return jsonify(error="Container was not found"), 404
    return jsonify(container=contents)


@setup_movement_api.post("/api/setup/movements")
def api_setup_movement_record() -> tuple[Response, int] | Response:
    require_setup_command()
    _base_repo, email, access = require_movement_operator()
    payload = json_body()

    season_year = positive_int(payload.get("season_year"), "season_year")
    asset_type = normalize_asset_type(payload.get("asset_type"))
    asset_id = positive_int(payload.get("asset_id"), "asset_id")
    movement_action = normalize_action(payload.get("movement_action"))
    offline_captured = bool(payload.get("offline_captured", False))

    # Online PICKED is checked against the current authoritative Pick List.
    # Offline replay preserves the original field observation even if the live
    # schedule has changed since capture; the client only queues cached-valid
    # active demand and the DB still enforces identity/idempotency/state safety.
    if movement_action == "PICKED" and not offline_captured:
        _validate_live_pick_demand(
            season_year=season_year,
            asset_type=asset_type,
            asset_id=asset_id,
        )

    placement = payload.get("display_placement")
    if placement is not None:
        if asset_type != "DISPLAY" or movement_action != "DISPLAY_MOVE" or placement != "YES":
            raise SetupCommandError("Only confirmed Display placement can detach a Display")
        if not optional_positive_int(payload.get("destination_stage_id"), "destination_stage_id"):
            raise SetupCommandError("Confirm the actual Stage for this Display placement")

    reconciliation = payload.get("reconciliation")
    if reconciliation is not None:
        if not isinstance(reconciliation, dict) or reconciliation.get("decision") not in {"EMPTY", "NOT_EMPTY", "NOT_SURE"}:
            raise SetupCommandError("Choose Empty, Not Empty, or Not Sure")
        if asset_type != "CONTAINER" or movement_action not in {"CONTAINER_MOVE", "RETURNED"}:
            raise SetupCommandError("Contents reconciliation requires a Container location or return")
        if payload.get("unloaded_display_ids"):
            raise SetupCommandError("Use remaining Display Names for reconciliation")
        for key in ("expected_display_ids", "remaining_display_ids"):
            if key in reconciliation:
                reconciliation[key] = optional_positive_int_list(reconciliation[key], key)
        if "prior_event_id" in reconciliation:
            reconciliation["prior_event_id"] = optional_positive_int(reconciliation["prior_event_id"], "prior_event_id")
        if reconciliation.get("prior_client_event_id"):
            reconciliation["prior_client_event_id"] = str(required_uuid(reconciliation["prior_client_event_id"], "prior_client_event_id"))
        if "identify_remaining" in reconciliation and not isinstance(reconciliation["identify_remaining"], bool):
            raise SetupCommandError("identify_remaining must be true or false")

    result = repo().record_event(
        email=email,
        season_year=season_year,
        client_event_id=required_uuid(payload.get("client_event_id"), "client_event_id"),
        asset_type=asset_type,
        asset_id=asset_id,
        movement_action=movement_action,
        occurred_at=required_timestamp(payload.get("occurred_at"), "occurred_at"),
        device_id=optional_text(payload.get("device_id")),
        captured_operator_email=(
            optional_text(payload.get("captured_operator_email"))
            if offline_captured
            else email
        ) or str(access.get("authenticated_email") or email),
        capture_method=str(payload.get("capture_method") or "HID_SCAN").strip().upper(),
        offline_captured=offline_captured,
        gps_latitude=optional_float(payload.get("gps_latitude"), "gps_latitude"),
        gps_longitude=optional_float(payload.get("gps_longitude"), "gps_longitude"),
        gps_accuracy_m=optional_float(payload.get("gps_accuracy_m"), "gps_accuracy_m"),
        destination_stage_id=optional_positive_int(
            payload.get("destination_stage_id"),
            "destination_stage_id",
        ),
        destination_location_note=optional_text(
            payload.get("destination_location_note")
        ),
        notes=optional_text(payload.get("notes")),
        unloaded_display_ids=optional_positive_int_list(
            payload.get("unloaded_display_ids"),
            "unloaded_display_ids",
        ),
        gps_fix_at=(
            required_timestamp(payload.get("gps_fix_at"), "gps_fix_at")
            if payload.get("gps_fix_at")
            else None
        ),
        gps_fix_age_ms=optional_nonnegative_int(
            payload.get("gps_fix_age_ms"),
            "gps_fix_age_ms",
        ),
        gps_quality=normalize_gps_quality(payload.get("gps_quality")),
        gps_quality_note=optional_text(payload.get("gps_quality_note")),
        reconciliation=reconciliation,
    )
    status = 200 if result.get("duplicate_event") else 201
    return jsonify(movement=result), status


@setup_movement_api.errorhandler(SetupAuthenticationError)
def movement_authentication_error(
    exc: SetupAuthenticationError,
) -> tuple[Response, int]:
    return jsonify(
        error="Setup Session sign-in identity is unavailable",
        engineering_error=str(exc),
    ), 401


@setup_movement_api.errorhandler(SetupCommandError)
def movement_command_error(exc: SetupCommandError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 403


@setup_movement_api.errorhandler(SetupMovementConflictError)
def movement_conflict_error(
    exc: SetupMovementConflictError,
) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 409


@setup_movement_api.errorhandler(SetupMovementRepositoryError)
def movement_repository_error(
    exc: SetupMovementRepositoryError,
) -> tuple[Response, int]:
    return jsonify(
        error="Setup movement is temporarily unavailable.",
        engineering_error=str(exc),
    ), 503


@setup_movement_api.errorhandler(psycopg2.Error)
def movement_database_error(exc: psycopg2.Error) -> tuple[Response, int]:
    sqlstate = exc.pgcode or ""
    if sqlstate == "42501":
        status = 403
    elif sqlstate in {"23505", "23514"}:
        status = 409
    elif sqlstate in {"22023", "23503"}:
        status = 400
    elif sqlstate == "P0002":
        status = 404
    else:
        status = 500
    message = (
        exc.diag.message_primary
        or "Setup movement database command failed"
    ).strip()
    return jsonify(error=message, engineering_error=str(exc)), status
