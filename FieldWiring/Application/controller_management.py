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
    """Return governed Manager form choices plus read-only planning evidence.

    The write-side lookup catalogs continue to come through the narrow
    SECURITY DEFINER function. Planning evidence is read from relations already
    granted SELECT to ``fieldwiring_app`` and never changes LOR or Controller
    data.
    """
    pg = _postgres(repo)
    try:
        with pg.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT ref.controller_management_options(%s) AS options",
                (email.strip().lower(),),
            )
            row = cur.fetchone()
            if row is None or row.get("options") is None:
                raise ControllerManagementError(
                    "Controller management options returned no result"
                )
            options = dict(row["options"])

            # Permanent Stage choices are useful before a new Display exists.
            cur.execute(
                """
                SELECT stage_id, stage_key, stage_name, park_order, sub_order
                FROM ref.stage
                ORDER BY park_order, sub_order, stage_key, stage_name
                """
            )
            options["planning_stages"] = [dict(item) for item in cur.fetchall()]

            # Current approved LOR/V7 Unit-ID usage. Network + UID is the
            # address space; repeated UIDs on different networks are unrelated.
            cur.execute(
                """
                SELECT
                    fw.preview_name,
                    btrim(fw.network) AS network,
                    upper(btrim(fw.controller)) AS uid_hex,
                    fw.start_channel,
                    fw.end_channel,
                    fw.display_name,
                    fw.channel_name,
                    fw.device_type
                FROM lor_snap.preview_wiring_fieldlead_v6 AS fw
                WHERE nullif(btrim(fw.network), '') IS NOT NULL
                  AND btrim(fw.controller) ~* '^[0-9a-f]{1,2}$'
                ORDER BY
                    lower(btrim(fw.network)),
                    ('x' || btrim(fw.controller))::bit(32)::int,
                    fw.start_channel,
                    fw.display_name
                """
            )
            options["planning_lor_uid_usage"] = [
                dict(item) for item in cur.fetchall()
            ]

            # Physical Controller current programming is deliberately separate
            # from current LOR use. AVAILABLE stock may retain old programming.
            cur.execute(
                """
                SELECT
                    c.controller_id,
                    c.controller_model_id,
                    m.model_code,
                    m.model_name,
                    s.controller_status_name,
                    c.current_location_code,
                    c.lor_network,
                    c.lor_uid_start,
                    c.lor_uid_count,
                    c.lor_uid_end,
                    c.programmed_config_verification_state,
                    count(cd.display_id) AS assignment_count,
                    string_agg(d.display_name, ', ' ORDER BY d.display_name)
                        AS display_names,
                    string_agg(
                        DISTINCT CASE
                            WHEN st.stage_id IS NULL THEN NULL
                            ELSE st.stage_key || ' · ' || st.stage_name
                        END,
                        ', '
                    ) AS stage_names
                FROM ref.controller AS c
                JOIN ref.controller_model AS m
                  ON m.controller_model_id = c.controller_model_id
                JOIN ref.controller_status AS s
                  ON s.controller_status_id = c.controller_status_id
                LEFT JOIN ref.controller_display AS cd
                  ON cd.controller_id = c.controller_id
                LEFT JOIN ref.display AS d
                  ON d.display_id = cd.display_id
                LEFT JOIN ref.stage AS st
                  ON st.stage_id = d.stage_id
                GROUP BY c.controller_id, m.controller_model_id, s.controller_status_id
                ORDER BY c.controller_id
                """
            )
            options["planning_controller_programming"] = [
                dict(item) for item in cur.fetchall()
            ]

            # Explicit SPARE rows that can be safely attributed to a direct
            # Stage Preview. Shared/master Preview SPARE attribution is omitted
            # rather than guessed and is surfaced by the UI as review-needed.
            cur.execute(
                """
                SELECT
                    st.stage_id,
                    st.stage_key,
                    st.stage_name,
                    fw.preview_name,
                    btrim(fw.network) AS network,
                    upper(btrim(fw.controller)) AS uid_hex,
                    fw.start_channel,
                    fw.end_channel,
                    fw.display_name,
                    fw.channel_name,
                    fw.device_type
                FROM lor_snap.preview_wiring_fieldlead_v6 AS fw
                JOIN lor_snap.v_current_previews AS pv
                  ON pv.name = fw.preview_name
                JOIN ref.stage AS st
                  ON lower(st.stage_key) = lower(btrim(pv.stage_id))
                WHERE (
                    coalesce(fw.display_name, '') ILIKE '%SPARE%'
                    OR coalesce(fw.channel_name, '') ILIKE '%SPARE%'
                )
                  AND nullif(btrim(fw.network), '') IS NOT NULL
                  AND btrim(fw.controller) ~* '^[0-9a-f]{1,2}$'
                ORDER BY
                    st.park_order,
                    st.sub_order,
                    lower(btrim(fw.network)),
                    ('x' || btrim(fw.controller))::bit(32)::int,
                    fw.start_channel
                """
            )
            options["planning_explicit_spares"] = [
                dict(item) for item in cur.fetchall()
            ]

    except ControllerManagementError:
        raise
    except psycopg2.Error as exc:
        message = (getattr(exc.diag, "message_primary", None) or str(exc).strip())
        if exc.pgcode == "42501":
            raise ControllerManagementAuthorizationError(message) from exc
        raise ControllerManagementError(message) from exc

    return options


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
