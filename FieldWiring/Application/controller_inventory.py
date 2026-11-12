"""Read-only permanent Controller Inventory queries for the Wiring System."""
from __future__ import annotations

from typing import Any

from psycopg2.extras import RealDictCursor

from repository import PostgresRepository, Repository


class ControllerInventoryError(RuntimeError):
    """Raised when the permanent Controller Inventory cannot be read."""


def _postgres(repo: Repository) -> PostgresRepository:
    if not isinstance(repo, PostgresRepository):
        raise ControllerInventoryError(
            "Controller Inventory requires the production PostgreSQL data source"
        )
    return repo


def controller_list(
    repo: Repository,
    *,
    query: str = "",
    stage_id: int | None = None,
    status: str = "",
    model: str = "",
    assignment: str = "",
) -> dict[str, Any]:
    """Return permanent controllers with operational browse filters.

    Stage is derived from current Controller-to-Display relationships. It is not
    stored on ``ref.controller`` because one controller may serve multiple
    Displays and, legitimately, Displays from more than one Stage.
    """
    pg = _postgres(repo)
    query = query.strip()
    status = status.strip().upper()
    model = model.strip()
    assignment = assignment.strip().lower()

    where: list[str] = []
    params: list[Any] = []

    if query:
        token = f"%{query}%"
        where.append(
            "("
            "c.controller_id::text ILIKE %s OR "
            "m.model_code ILIKE %s OR "
            "m.model_name ILIKE %s OR "
            "coalesce(c.serial_number, '') ILIKE %s OR "
            "coalesce(c.current_location_code, '') ILIKE %s OR "
            "coalesce(c.lor_network, '') ILIKE %s OR "
            "coalesce(host(c.management_ip), '') ILIKE %s OR "
            "coalesce(upper(lpad(to_hex(c.lor_uid_start::integer), 2, '0')), '') ILIKE upper(%s) OR "
            "EXISTS ("
            "  SELECT 1 "
            "  FROM ref.controller_display qcd "
            "  JOIN ref.display qd ON qd.display_id = qcd.display_id "
            "  LEFT JOIN ref.stage qst ON qst.stage_id = qd.stage_id "
            "  WHERE qcd.controller_id = c.controller_id "
            "    AND ("
            "      qd.display_name ILIKE %s OR "
            "      coalesce(qst.stage_key, '') ILIKE %s OR "
            "      coalesce(qst.stage_name, '') ILIKE %s"
            "    )"
            ")"
            ")"
        )
        params.extend([
            token, token, token, token, token, token, token, token,
            token, token, token,
        ])

    if stage_id is not None:
        where.append(
            "EXISTS ("
            "  SELECT 1 "
            "  FROM ref.controller_display scd "
            "  JOIN ref.display sd ON sd.display_id = scd.display_id "
            "  WHERE scd.controller_id = c.controller_id "
            "    AND sd.stage_id = %s"
            ")"
        )
        params.append(stage_id)

    if status:
        where.append("s.controller_status_name = %s")
        params.append(status)

    if model:
        where.append("m.model_code = %s")
        params.append(model)

    if assignment == "assigned":
        where.append(
            "EXISTS (SELECT 1 FROM ref.controller_display acd "
            "WHERE acd.controller_id = c.controller_id)"
        )
    elif assignment == "unassigned":
        where.append(
            "NOT EXISTS (SELECT 1 FROM ref.controller_display acd "
            "WHERE acd.controller_id = c.controller_id)"
        )

    sql = """
        SELECT
            c.controller_id,
            m.model_code,
            m.manufacturer,
            m.model_name,
            m.device_family,
            m.lor_uid_capacity,
            s.controller_status_name,
            c.hardware_revision,
            c.serial_number,
            c.year_deployed,
            c.current_location_code,
            c.lor_network,
            c.lor_uid_start,
            c.lor_uid_count,
            c.lor_uid_end,
            host(c.management_ip) AS management_ip,
            c.programmed_config_verification_state,
            c.firmware_verification_state,
            fv.firmware_version AS installed_firmware,
            c.verification_state,
            c.label_required,
            c.print_label,
            count(cd.display_id) AS assignment_count,
            string_agg(d.display_name, ', ' ORDER BY d.display_name) AS display_names,
            string_agg(
                DISTINCT CASE
                    WHEN st.stage_id IS NULL THEN NULL
                    ELSE st.stage_key || ' · ' || st.stage_name
                END,
                ', '
            ) AS stage_names
        FROM ref.controller c
        JOIN ref.controller_model m
          ON m.controller_model_id = c.controller_model_id
        JOIN ref.controller_status s
          ON s.controller_status_id = c.controller_status_id
        LEFT JOIN ref.controller_firmware_version fv
          ON fv.controller_firmware_version_id = c.installed_firmware_version_id
        LEFT JOIN ref.controller_display cd
          ON cd.controller_id = c.controller_id
        LEFT JOIN ref.display d
          ON d.display_id = cd.display_id
        LEFT JOIN ref.stage st
          ON st.stage_id = d.stage_id
    """
    if where:
        sql += " WHERE " + " AND ".join(where)
    sql += """
        GROUP BY
            c.controller_id,
            m.controller_model_id,
            s.controller_status_id,
            fv.controller_firmware_version_id
        ORDER BY c.controller_id
    """

    with pg.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(sql, params)
        controllers = [dict(row) for row in cur.fetchall()]

        cur.execute(
            """
            SELECT
                count(*) AS total,
                count(*) FILTER (
                    WHERE EXISTS (
                        SELECT 1 FROM ref.controller_display cd
                        WHERE cd.controller_id = c.controller_id
                    )
                ) AS assigned,
                count(*) FILTER (
                    WHERE NOT EXISTS (
                        SELECT 1 FROM ref.controller_display cd
                        WHERE cd.controller_id = c.controller_id
                    )
                ) AS unassigned,
                count(*) FILTER (
                    WHERE c.firmware_verification_state <> 'VERIFIED'
                ) AS firmware_pending
            FROM ref.controller c
            """
        )
        summary = dict(cur.fetchone())

        cur.execute(
            """
            SELECT controller_status_name
            FROM ref.controller_status
            ORDER BY controller_status_id
            """
        )
        statuses = [row["controller_status_name"] for row in cur.fetchall()]

        cur.execute(
            """
            SELECT model_code, model_name, lor_uid_capacity
            FROM ref.controller_model
            ORDER BY model_code
            """
        )
        models = [dict(row) for row in cur.fetchall()]

        cur.execute(
            """
            SELECT
                st.stage_id,
                st.stage_key,
                st.stage_name
            FROM ref.controller_display cd
            JOIN ref.display d
              ON d.display_id = cd.display_id
            JOIN ref.stage st
              ON st.stage_id = d.stage_id
            GROUP BY st.stage_id, st.stage_key, st.stage_name
            ORDER BY
                min(st.park_order),
                min(st.sub_order),
                st.stage_key,
                st.stage_name
            """
        )
        stages = [dict(row) for row in cur.fetchall()]

    return {
        "summary": summary,
        "statuses": statuses,
        "models": models,
        "stages": stages,
        "controllers": controllers,
    }


def controller_detail(repo: Repository, controller_id: int) -> dict[str, Any] | None:
    pg = _postgres(repo)
    with pg.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT
                c.controller_id,
                c.controller_model_id,
                m.model_code,
                m.manufacturer,
                m.model_name,
                m.device_family,
                m.display_assignment_capable,
                m.lor_uid_capacity,
                c.controller_status_id,
                s.controller_status_name,
                c.hardware_revision,
                c.serial_number,
                c.year_deployed,
                c.current_location_code,
                c.lor_network,
                c.lor_uid_start,
                c.lor_uid_count,
                c.lor_uid_end,
                host(c.management_ip) AS management_ip,
                c.programmed_config_verification_state,
                c.programmed_config_verified_at,
                c.programmed_config_source_note,
                c.is_display_attached,
                c.verification_state,
                c.firmware_verification_state,
                c.firmware_verified_at,
                c.firmware_verification_note,
                fv.firmware_version AS installed_firmware,
                c.notes,
                c.label_required,
                c.print_label,
                c.label_print_count_cached,
                c.label_print_last_at_cached,
                c.created_at,
                c.updated_at
            FROM ref.controller c
            JOIN ref.controller_model m
              ON m.controller_model_id = c.controller_model_id
            JOIN ref.controller_status s
              ON s.controller_status_id = c.controller_status_id
            LEFT JOIN ref.controller_firmware_version fv
              ON fv.controller_firmware_version_id = c.installed_firmware_version_id
            WHERE c.controller_id = %s
            """,
            (controller_id,),
        )
        row = cur.fetchone()
        if row is None:
            return None
        controller = dict(row)

        cur.execute(
            """
            SELECT
                cd.display_id,
                d.display_name,
                d.stage_id,
                st.stage_key,
                st.stage_name,
                cd.wiring_source_display_id,
                ws.display_name AS wiring_source_display,
                coalesce(cd.wiring_source_display_id, cd.display_id) AS wiring_display_id,
                EXISTS (
                    SELECT 1
                    FROM ref.display wd
                    JOIN lor_snap.v_current_props p
                      ON p.raw_prop_id = wd.lor_prop_id
                    WHERE wd.display_id = coalesce(cd.wiring_source_display_id, cd.display_id)
                      AND upper(coalesce(p.device_type, '')) <> 'NONE'
                ) AS has_current_wiring,
                cd.placement_note,
                cd.notes
            FROM ref.controller_display cd
            JOIN ref.display d
              ON d.display_id = cd.display_id
            LEFT JOIN ref.stage st
              ON st.stage_id = d.stage_id
            LEFT JOIN ref.display ws
              ON ws.display_id = cd.wiring_source_display_id
            WHERE cd.controller_id = %s
            ORDER BY
                st.park_order,
                st.sub_order,
                d.display_name
            """,
            (controller_id,),
        )
        assignments = [dict(item) for item in cur.fetchall()]

        cur.execute(
            """
            SELECT
                h.controller_firmware_history_id,
                fv.firmware_version,
                h.firmware_recorded_at,
                h.verification_state,
                h.verified_at,
                coalesce(p.preferred_name, p.first_name) AS verified_by,
                h.source_note,
                h.notes
            FROM ref.controller_firmware_history h
            JOIN ref.controller_firmware_version fv
              ON fv.controller_firmware_version_id = h.controller_firmware_version_id
            LEFT JOIN ref.person p
              ON p.person_id = h.verified_by_person_id
            WHERE h.controller_id = %s
            ORDER BY h.firmware_recorded_at DESC,
                     h.controller_firmware_history_id DESC
            """,
            (controller_id,),
        )
        firmware_history = [dict(item) for item in cur.fetchall()]

    return {
        "controller": controller,
        "assignments": assignments,
        "firmware_history": firmware_history,
    }
