"""Narrow write commands for authenticated Controller Management operations."""
from __future__ import annotations

from typing import Any

import psycopg2
from psycopg2.extras import RealDictCursor

from repository import PostgresRepository, Repository


class ControllerCommandError(RuntimeError):
    """Raised when a controlled Controller command cannot be completed."""


class ControllerCommandAuthorizationError(ControllerCommandError):
    """Raised when the authenticated operator lacks the requested capability."""


class ControllerCommandNotFoundError(ControllerCommandError):
    """Raised when the requested permanent Controller does not exist."""


def request_controller_label(
    repo: Repository,
    *,
    email: str,
    controller_id: int,
) -> dict[str, Any]:
    """Request one Controller label through the narrow DB command boundary.

    ``PostgresRepository.connect()`` is intentionally read-only. Controller
    commands use a separate explicit read-write transaction, while the
    ``fieldwiring_app`` login still has no direct table DML privileges. The
    only write available here is the SECURITY DEFINER function explicitly
    granted to that role.
    """
    if not isinstance(repo, PostgresRepository):
        raise ControllerCommandError(
            "Controller commands require the production PostgreSQL data source"
        )

    normalized_email = email.strip().lower()
    conn = psycopg2.connect(repo.dsn)
    try:
        # fieldwiring_app defaults to read-only as a defensive backstop. Opt in
        # to a write transaction only for this narrow command connection.
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
        conn.commit()
    except psycopg2.Error as exc:
        conn.rollback()
        message = (
            getattr(exc.diag, "message_primary", None)
            or str(exc).strip()
            or "Controller command failed"
        )
        if exc.pgcode == "42501":
            raise ControllerCommandAuthorizationError(message) from exc
        if exc.pgcode == "P0002":
            raise ControllerCommandNotFoundError(message) from exc
        raise ControllerCommandError(message) from exc
    finally:
        conn.close()

    if row is None:
        raise ControllerCommandError("Controller label command returned no result")
    return dict(row)
