"""Read helpers for authenticated Controller Management forms and assignments."""
from __future__ import annotations

from typing import Any

import psycopg2
from psycopg2.extras import RealDictCursor

from repository import PostgresRepository, Repository


class ControllerManagementError(RuntimeError):
    """Raised when Controller management reference data cannot be read safely."""


class ControllerManagementAuthorizationError(ControllerManagementError):
    """Raised when Manager-only reference data is not authorized."""


def _postgres(repo: Repository) -> PostgresRepository:
    if not isinstance(repo, PostgresRepository):
        raise ControllerManagementError(
            "Controller management requires the production PostgreSQL data source"
        )
    return repo


def controller_management_options(repo: Repository, email: str) -> dict[str, Any]:
    """Return controlled Manager form choices through the narrow DB function."""
    pg = _postgres(repo)
    try:
        with pg.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT ref.controller_management_options(%s) AS options",
                (email.strip().lower(),),
            )
            row = cur.fetchone()
    except psycopg2.Error as exc:
        message = (getattr(exc.diag, "message_primary", None) or str(exc).strip())
        if exc.pgcode == "42501":
            raise ControllerManagementAuthorizationError(message) from exc
        raise ControllerManagementError(message) from exc
    if row is None or row.get("options") is None:
        raise ControllerManagementError("Controller management options returned no result")
    return dict(row["options"])


def controller_assignment_display_search(
    repo: Repository,
    query: str,
    *,
    limit: int = 40,
) -> list[dict[str, Any]]:
    """Search active Displays for the assignment workbench.

    This intentionally uses the Production Database Display identity rather than
    FieldWiring eligibility. A Controller may be assigned before current LOR
    wiring is available; the result separately reports whether current wiring
    exists.
    """
    pg = _postgres(repo)
    token = query.strip()
    if not token:
        return []
    limit = max(1, min(int(limit), 80))

    with pg.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        if token.isdigit():
            cur.execute(
                """
                SELECT
                    d.display_id,
                    d.display_name,
                    d.stage_id,
                    st.stage_key,
                    st.stage_name,
                    count(cd.controller_id) AS controller_count,
                    string_agg(cd.controller_id::text, ', ' ORDER BY cd.controller_id)
                        AS controller_ids,
                    EXISTS (
                        SELECT 1
                        FROM lor_snap.v_current_props p
                        WHERE p.raw_prop_id = d.lor_prop_id
                          AND upper(coalesce(p.device_type, '')) <> 'NONE'
                    ) AS has_current_wiring
                FROM ref.display d
                LEFT JOIN ref.stage st ON st.stage_id = d.stage_id
                LEFT JOIN ref.controller_display cd ON cd.display_id = d.display_id
                WHERE d.display_status_id = 1
                  AND d.display_id = %s
                GROUP BY d.display_id, st.stage_id
                """,
                (int(token),),
            )
        else:
            cur.execute(
                """
                SELECT
                    d.display_id,
                    d.display_name,
                    d.stage_id,
                    st.stage_key,
                    st.stage_name,
                    count(cd.controller_id) AS controller_count,
                    string_agg(cd.controller_id::text, ', ' ORDER BY cd.controller_id)
                        AS controller_ids,
                    EXISTS (
                        SELECT 1
                        FROM lor_snap.v_current_props p
                        WHERE p.raw_prop_id = d.lor_prop_id
                          AND upper(coalesce(p.device_type, '')) <> 'NONE'
                    ) AS has_current_wiring
                FROM ref.display d
                LEFT JOIN ref.stage st ON st.stage_id = d.stage_id
                LEFT JOIN ref.controller_display cd ON cd.display_id = d.display_id
                WHERE d.display_status_id = 1
                  AND d.display_name ILIKE %s
                GROUP BY d.display_id, st.stage_id
                ORDER BY
                    CASE WHEN lower(d.display_name) = lower(%s) THEN 0 ELSE 1 END,
                    st.park_order,
                    st.sub_order,
                    d.display_name
                LIMIT %s
                """,
                (f"%{token}%", token, limit),
            )
        return [dict(row) for row in cur.fetchall()]
