"""Controller browser authentication/authorization boundary.

Cloudflare Access authenticates the browser before requests reach FieldWiring.
This module accepts that authenticated email and resolves Controller-specific
capabilities through the narrow PostgreSQL function installed by Controller
Inventory. It does not grant table writes and does not use a Directus browser
session/cookie.
"""
from __future__ import annotations

from typing import Any, Mapping

from psycopg2.extras import RealDictCursor

from repository import PostgresRepository, Repository


class ControllerAccessError(RuntimeError):
    """Raised when Controller authorization cannot be resolved safely."""


class ControllerAuthenticationError(ControllerAccessError):
    """Raised when the protected request is missing Cloudflare identity."""


CLOUDFLARE_EMAIL_HEADER = "Cf-Access-Authenticated-User-Email"


def cloudflare_operator_email(headers: Mapping[str, str]) -> str:
    """Return the normalized Cloudflare Access email or reject the request."""
    email = (headers.get(CLOUDFLARE_EMAIL_HEADER) or "").strip().lower()
    if not email:
        raise ControllerAuthenticationError(
            "Cloudflare Access operator identity is missing"
        )
    return email


def controller_browser_access(repo: Repository, email: str) -> dict[str, Any]:
    """Resolve Controller capabilities for one authenticated operator email.

    Unknown/inactive Directus users intentionally receive no write capability.
    Browsing remains governed by the protected FieldWiring perimeter and the
    existing read-only Controller API.
    """
    if not isinstance(repo, PostgresRepository):
        raise ControllerAccessError(
            "Controller authorization requires the production PostgreSQL data source"
        )

    normalized = email.strip().lower()
    with repo.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT
                email,
                display_name,
                role_name,
                policy_names,
                can_print_label,
                can_manage_controllers
            FROM ref.controller_browser_capabilities(%s)
            """,
            (normalized,),
        )
        row = cur.fetchone()

    if row is None:
        return {
            "authenticated_email": normalized,
            "known_user": False,
            "display_name": normalized,
            "role_name": None,
            "policy_names": [],
            "can_print_label": False,
            "can_manage_controllers": False,
        }

    item = dict(row)
    return {
        "authenticated_email": normalized,
        "known_user": True,
        "display_name": item.get("display_name") or normalized,
        "role_name": item.get("role_name"),
        "policy_names": list(item.get("policy_names") or []),
        "can_print_label": bool(item.get("can_print_label")),
        "can_manage_controllers": bool(item.get("can_manage_controllers")),
    }
