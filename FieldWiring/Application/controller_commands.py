"""Narrow write commands for authenticated Controller Management operations."""
from __future__ import annotations

from typing import Any, Iterable

import psycopg2
from psycopg2.extras import RealDictCursor

from repository import PostgresRepository, Repository


class ControllerCommandError(RuntimeError):
    """Raised when a controlled Controller command cannot be completed."""


class ControllerCommandAuthorizationError(ControllerCommandError):
    """Raised when the authenticated operator lacks the requested capability."""


class ControllerCommandNotFoundError(ControllerCommandError):
    """Raised when the requested permanent Controller or relationship does not exist."""


class ControllerCommandValidationError(ControllerCommandError):
    """Raised when submitted Controller data violates the governed contract."""


class ControllerCommandConflictError(ControllerCommandError):
    """Raised when a requested relationship already exists or otherwise conflicts."""


_CONTROLLER_FIELDS = {
    "controller_model_id",
    "controller_status_id",
    "hardware_revision",
    "installed_firmware_version_id",
    "firmware_verification_state",
    "firmware_verification_note",
    "serial_number",
    "year_deployed",
    "current_location_code",
    "is_display_attached",
    "verification_state",
    "notes",
    "label_required",
    "lor_network",
    "lor_uid_start",
    "lor_uid_count",
    "management_ip",
    "programmed_config_verification_state",
    "programmed_config_source_note",
}

_FIRMWARE_STATES = {"UNKNOWN", "RECORDED_UNVERIFIED", "VERIFIED"}
_PROGRAMMED_STATES = {"UNKNOWN", "RECORDED_UNVERIFIED", "VERIFIED"}
_PHYSICAL_STATES = {
    "ENGINEERING_ACCEPTED",
    "FIELD_VERIFICATION_REQUIRED",
    "PHYSICALLY_VERIFIED",
}


def _postgres(repo: Repository) -> PostgresRepository:
    if not isinstance(repo, PostgresRepository):
        raise ControllerCommandError(
            "Controller commands require the production PostgreSQL data source"
        )
    return repo


def _db_message(exc: psycopg2.Error) -> str:
    return (
        getattr(exc.diag, "message_primary", None)
        or str(exc).strip()
        or "Controller command failed"
    )


def _raise_db_error(exc: psycopg2.Error) -> None:
    message = _db_message(exc)
    if exc.pgcode == "42501":
        raise ControllerCommandAuthorizationError(message) from exc
    if exc.pgcode == "P0002":
        raise ControllerCommandNotFoundError(message) from exc
    if exc.pgcode == "23505":
        raise ControllerCommandConflictError(message) from exc
    if exc.pgcode in {"23503", "23514", "22P02", "22023", "22001", "P0001"}:
        raise ControllerCommandValidationError(message) from exc
    raise ControllerCommandError(message) from exc


def _run_write_command(
    repo: Repository,
    sql: str,
    params: Iterable[Any],
) -> dict[str, Any]:
    pg = _postgres(repo)
    conn = psycopg2.connect(pg.dsn)
    try:
        # The login defaults to read-only. A write transaction is opened only
        # for a narrow SECURITY DEFINER command explicitly granted to the role.
        conn.set_session(readonly=False, autocommit=False)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, tuple(params))
            row = cur.fetchone()
        conn.commit()
    except psycopg2.Error as exc:
        conn.rollback()
        _raise_db_error(exc)
    finally:
        conn.close()

    if row is None:
        raise ControllerCommandError("Controller command returned no result")
    return dict(row)


def _text(payload: dict[str, Any], key: str) -> str | None:
    value = payload.get(key)
    if value is None:
        return None
    if not isinstance(value, str):
        raise ControllerCommandValidationError(f"{key} must be text")
    value = value.strip()
    return value or None


def _int(payload: dict[str, Any], key: str, *, required: bool = False) -> int | None:
    value = payload.get(key)
    if value is None or value == "":
        if required:
            raise ControllerCommandValidationError(f"{key} is required")
        return None
    if isinstance(value, bool):
        raise ControllerCommandValidationError(f"{key} must be an integer")
    try:
        parsed = int(value)
    except (TypeError, ValueError) as exc:
        raise ControllerCommandValidationError(f"{key} must be an integer") from exc
    if parsed <= 0:
        raise ControllerCommandValidationError(f"{key} must be greater than zero")
    return parsed


def _bool(payload: dict[str, Any], key: str, *, nullable: bool = False) -> bool | None:
    value = payload.get(key)
    if value is None and nullable:
        return None
    if not isinstance(value, bool):
        raise ControllerCommandValidationError(f"{key} must be true or false")
    return value


def _state(payload: dict[str, Any], key: str, allowed: set[str]) -> str:
    value = _text(payload, key)
    if value is None:
        raise ControllerCommandValidationError(f"{key} is required")
    value = value.upper()
    if value not in allowed:
        raise ControllerCommandValidationError(f"Invalid {key}: {value}")
    return value


def _controller_params(payload: dict[str, Any]) -> tuple[Any, ...]:
    if not isinstance(payload, dict):
        raise ControllerCommandValidationError("Controller payload must be an object")
    unknown = set(payload) - _CONTROLLER_FIELDS
    if unknown:
        raise ControllerCommandValidationError(
            "Unsupported Controller field(s): " + ", ".join(sorted(unknown))
        )

    return (
        _int(payload, "controller_model_id", required=True),
        _int(payload, "controller_status_id", required=True),
        _text(payload, "hardware_revision"),
        _int(payload, "installed_firmware_version_id"),
        _state(payload, "firmware_verification_state", _FIRMWARE_STATES),
        _text(payload, "firmware_verification_note"),
        _text(payload, "serial_number"),
        _int(payload, "year_deployed"),
        _text(payload, "current_location_code"),
        _bool(payload, "is_display_attached", nullable=True),
        _state(payload, "verification_state", _PHYSICAL_STATES),
        _text(payload, "notes"),
        _bool(payload, "label_required"),
        _text(payload, "lor_network"),
        _int(payload, "lor_uid_start"),
        _int(payload, "lor_uid_count"),
        _text(payload, "management_ip"),
        _state(payload, "programmed_config_verification_state", _PROGRAMMED_STATES),
        _text(payload, "programmed_config_source_note"),
    )


def request_controller_label(
    repo: Repository,
    *,
    email: str,
    controller_id: int,
) -> dict[str, Any]:
    """Request one Controller label through the existing narrow DB command."""
    pg = _postgres(repo)
    normalized_email = email.strip().lower()
    conn = psycopg2.connect(pg.dsn)
    try:
        conn.set_session(readonly=False, autocommit=False)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    controller_id,
                    print_label,
                    request_already_pending,
                    updated_at,
                    updated_by,
                    updated_by_person_id
                FROM ref.request_controller_label(%s, %s)
                """,
                (normalized_email, controller_id),
            )
            row = cur.fetchone()
            cur.execute(
                """
                SELECT display_name
                FROM ref.controller_browser_capabilities(%s)
                """,
                (normalized_email,),
            )
            actor = cur.fetchone()
        conn.commit()
    except psycopg2.Error as exc:
        conn.rollback()
        _raise_db_error(exc)
    finally:
        conn.close()

    if row is None:
        raise ControllerCommandError("Controller label command returned no result")
    result = dict(row)
    # updated_by is the database audit text. Human-facing attribution uses the
    # already-authenticated Directus display identity; updated_by_person_id
    # remains the durable mapped-person audit fact.
    result["requested_by"] = (
        (actor or {}).get("display_name") if actor is not None else None
    ) or normalized_email
    return result


def create_controller(
    repo: Repository,
    *,
    email: str,
    payload: dict[str, Any],
) -> dict[str, Any]:
    values = _controller_params(payload)
    return _run_write_command(
        repo,
        """
        SELECT controller_id, operator_display_name
        FROM ref.create_controller(
            %s,%s,%s,%s,%s,%s,%s,%s,%s,%s,
            %s,%s,%s,%s,%s,%s,%s,%s,%s,%s
        )
        """,
        (email.strip().lower(), *values),
    )


def update_controller(
    repo: Repository,
    *,
    email: str,
    controller_id: int,
    payload: dict[str, Any],
) -> dict[str, Any]:
    values = _controller_params(payload)
    return _run_write_command(
        repo,
        """
        SELECT controller_id, operator_display_name
        FROM ref.update_controller(
            %s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,
            %s,%s,%s,%s,%s,%s,%s,%s,%s,%s
        )
        """,
        (email.strip().lower(), controller_id, *values),
    )


def assign_controller_display(
    repo: Repository,
    *,
    email: str,
    controller_id: int,
    payload: dict[str, Any],
) -> dict[str, Any]:
    display_id = _int(payload, "display_id", required=True)
    wiring_source = _int(payload, "wiring_source_display_id")
    placement_note = _text(payload, "placement_note")
    notes = _text(payload, "notes")
    mark_deployed = payload.get("mark_deployed", True)
    if not isinstance(mark_deployed, bool):
        raise ControllerCommandValidationError("mark_deployed must be true or false")
    return _run_write_command(
        repo,
        """
        SELECT controller_id, display_id, controller_status_name, operator_display_name
        FROM ref.assign_controller_display(%s,%s,%s,%s,%s,%s,%s)
        """,
        (
            email.strip().lower(),
            controller_id,
            display_id,
            wiring_source,
            placement_note,
            notes,
            mark_deployed,
        ),
    )


def update_controller_display_assignment(
    repo: Repository,
    *,
    email: str,
    controller_id: int,
    display_id: int,
    payload: dict[str, Any],
) -> dict[str, Any]:
    wiring_source = _int(payload, "wiring_source_display_id")
    placement_note = _text(payload, "placement_note")
    notes = _text(payload, "notes")
    return _run_write_command(
        repo,
        """
        SELECT controller_id, display_id, operator_display_name
        FROM ref.update_controller_display_assignment(%s,%s,%s,%s,%s,%s)
        """,
        (
            email.strip().lower(),
            controller_id,
            display_id,
            wiring_source,
            placement_note,
            notes,
        ),
    )


def reassign_controller_display(
    repo: Repository,
    *,
    email: str,
    controller_id: int,
    old_display_id: int,
    payload: dict[str, Any],
) -> dict[str, Any]:
    new_display_id = _int(payload, "display_id", required=True)
    wiring_source = _int(payload, "wiring_source_display_id")
    placement_note = _text(payload, "placement_note")
    notes = _text(payload, "notes")
    return _run_write_command(
        repo,
        """
        SELECT controller_id, old_display_id, new_display_id, operator_display_name
        FROM ref.reassign_controller_display(%s,%s,%s,%s,%s,%s,%s)
        """,
        (
            email.strip().lower(),
            controller_id,
            old_display_id,
            new_display_id,
            wiring_source,
            placement_note,
            notes,
        ),
    )


def unassign_controller_display(
    repo: Repository,
    *,
    email: str,
    controller_id: int,
    display_id: int,
    return_available: bool,
) -> dict[str, Any]:
    if not isinstance(return_available, bool):
        raise ControllerCommandValidationError("return_available must be true or false")
    return _run_write_command(
        repo,
        """
        SELECT
            controller_id,
            display_id,
            remaining_assignment_count,
            controller_status_name,
            operator_display_name
        FROM ref.unassign_controller_display(%s,%s,%s,%s)
        """,
        (email.strip().lower(), controller_id, display_id, return_available),
    )
