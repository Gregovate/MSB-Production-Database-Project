"""Protected read API for standalone Setup Kit/T-Post inventory routes."""
from __future__ import annotations

from contextlib import closing

import psycopg2
from psycopg2.extras import RealDictCursor
from flask import Blueprint, Response, jsonify

from setup_api import (
    SetupAuthenticationError,
    SetupCommandError,
    require_reader,
    setup_database_dsn,
)
from setup_repository import SetupRepositoryError

setup_kit_inventory_api = Blueprint("setup_kit_inventory_api", __name__)


@setup_kit_inventory_api.get("/api/setup/kit-inventory/kit-boxes")
def api_setup_kit_inventory_kit_boxes() -> Response:
    """List all physical Kit Boxes with assignment and inventory state."""
    require_reader()
    with closing(psycopg2.connect(setup_database_dsn())) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    c.container_id,
                    c.description AS container_description,
                    c.location_code AS home_location_code,
                    coalesce(contents.expected_item_rows, 0) AS expected_item_rows,
                    coalesce(contents.counted_item_rows, 0) AS counted_item_rows,
                    coalesce(contents.uncounted_item_rows, 0) AS uncounted_item_rows,
                    coalesce(displays.display_rows, 0) AS display_rows,
                    (review.container_id IS NOT NULL) AS has_unverified_items,
                    coalesce(assignments.assigned_task_count, 0) AS assigned_task_count,
                    assignments.assigned_task_names,
                    coalesce(assignments.assigned_tasks, '[]'::jsonb) AS assigned_tasks
                FROM ref.container AS c
                LEFT JOIN LATERAL (
                    SELECT
                        count(*) AS expected_item_rows,
                        count(*) FILTER (
                            WHERE coalesce(b.inventory_event_count, 0) > 0
                        ) AS counted_item_rows,
                        count(*) FILTER (
                            WHERE coalesce(b.inventory_event_count, 0) = 0
                        ) AS uncounted_item_rows
                    FROM ref.setup_container_extra_material AS cem
                    LEFT JOIN ops.setup_extra_material_inventory_balance AS b
                      ON b.setup_container_extra_material_id = cem.setup_container_extra_material_id
                    WHERE cem.container_id = c.container_id
                      AND cem.active_flag
                ) AS contents ON true
                LEFT JOIN LATERAL (
                    SELECT count(*) AS display_rows
                    FROM ref.display AS d
                    LEFT JOIN ref.display_status AS ds
                      ON ds.display_status_id = d.display_status_id
                    WHERE d.container_id = c.container_id
                      AND upper(coalesce(ds.display_status_name, '')) <> 'RECYCLED'
                ) AS displays ON true
                LEFT JOIN ref.setup_container_extra_material_review AS review
                  ON review.container_id = c.container_id
                LEFT JOIN LATERAL (
                    SELECT
                        count(*) AS assigned_task_count,
                        string_agg(
                            concat(t.setup_task_id, ' - ', t.task_name),
                            '; '
                            ORDER BY s.park_order NULLS LAST,
                                     s.sub_order NULLS LAST,
                                     t.display_order,
                                     t.setup_task_id
                        ) AS assigned_task_names,
                        jsonb_agg(
                            jsonb_build_object(
                                'setup_task_id', t.setup_task_id,
                                'task_name', t.task_name,
                                'stage_id', t.stage_id,
                                'stage_key', s.stage_key,
                                'stage_name', s.stage_name,
                                'relationship_notes', tc.notes
                            )
                            ORDER BY s.park_order NULLS LAST,
                                     s.sub_order NULLS LAST,
                                     t.display_order,
                                     t.setup_task_id
                        ) AS assigned_tasks
                    FROM ref.setup_task_container_support AS tc
                    JOIN ref.setup_task AS t
                      ON t.setup_task_id = tc.setup_task_id
                    LEFT JOIN ref.stage AS s
                      ON s.stage_id = t.stage_id
                    WHERE tc.container_id = c.container_id
                      AND tc.relationship_type = 'KIT'
                      AND t.active_flag
                ) AS assignments ON true
                WHERE c.container_type_id = 2
                ORDER BY c.description NULLS LAST, c.container_id
                """
            )
            rows = [dict(row) for row in cur.fetchall()]
    return jsonify(kit_boxes=rows)


@setup_kit_inventory_api.get("/api/setup/kit-inventory/kit-boxes/<int:container_id>/displays")
def api_setup_kit_inventory_displays(container_id: int) -> Response:
    """Return current physical Display identities stored in one Kit Box."""
    require_reader()
    with closing(psycopg2.connect(setup_database_dsn())) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    d.display_id,
                    d.display_name,
                    d.inventory_type,
                    d.lor_prop_id,
                    d.stage_id,
                    s.stage_key,
                    s.stage_name,
                    ds.display_status_name
                FROM ref.display AS d
                LEFT JOIN ref.display_status AS ds
                  ON ds.display_status_id = d.display_status_id
                LEFT JOIN ref.stage AS s
                  ON s.stage_id = d.stage_id
                JOIN ref.container AS c
                  ON c.container_id = d.container_id
                WHERE d.container_id = %s
                  AND c.container_type_id = 2
                  AND upper(coalesce(ds.display_status_name, '')) <> 'RECYCLED'
                ORDER BY d.display_name, d.display_id
                """,
                (container_id,),
            )
            rows = [dict(row) for row in cur.fetchall()]
    return jsonify(displays=rows)


@setup_kit_inventory_api.get("/api/setup/t-post-inventory/containers")
def api_setup_tpost_inventory_containers() -> Response:
    """List physical Containers that currently carry the normalized T-Post family.

    This is intentionally separate from Kit Box inventory. The relationship is
    derived from active ref.setup_container_extra_material rows rather than from
    Container type, so the physical stock can remain on Steel/Wood pallets.
    """
    require_reader()
    with closing(psycopg2.connect(setup_database_dsn())) as conn:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    c.container_id,
                    c.description AS container_description,
                    c.location_code AS home_location_code,
                    count(*) AS tpost_stock_rows,
                    count(*) FILTER (WHERE coalesce(b.inventory_event_count, 0) > 0)
                        AS counted_stock_rows,
                    count(*) FILTER (WHERE coalesce(b.inventory_event_count, 0) = 0)
                        AS uncounted_stock_rows
                FROM ref.container c
                JOIN ref.setup_container_extra_material cem
                  ON cem.container_id = c.container_id
                 AND cem.active_flag
                JOIN ref.setup_extra_material m
                  ON m.setup_extra_material_id = cem.setup_extra_material_id
                 AND m.active_flag
                 AND m.material_name = 'T-Post'
                LEFT JOIN ops.setup_extra_material_inventory_balance b
                  ON b.setup_container_extra_material_id = cem.setup_container_extra_material_id
                GROUP BY c.container_id, c.description, c.location_code
                ORDER BY c.container_id
                """
            )
            rows = [dict(row) for row in cur.fetchall()]
    return jsonify(containers=rows)


@setup_kit_inventory_api.errorhandler(SetupAuthenticationError)
def authentication_error(exc: SetupAuthenticationError) -> tuple[Response, int]:
    return jsonify(
        error="Setup Session sign-in identity is unavailable",
        engineering_error=str(exc),
    ), 401


@setup_kit_inventory_api.errorhandler(SetupCommandError)
def command_error(exc: SetupCommandError) -> tuple[Response, int]:
    return jsonify(error=str(exc), engineering_error=str(exc)), 403


@setup_kit_inventory_api.errorhandler(SetupRepositoryError)
def repository_error(exc: SetupRepositoryError) -> tuple[Response, int]:
    return jsonify(
        error="Setup inventory is temporarily unavailable.",
        engineering_error=str(exc),
    ), 503


@setup_kit_inventory_api.errorhandler(psycopg2.Error)
def database_error(exc: psycopg2.Error) -> tuple[Response, int]:
    message = (exc.diag.message_primary or "Setup inventory database query failed").strip()
    return jsonify(error=message, engineering_error=str(exc)), 500
