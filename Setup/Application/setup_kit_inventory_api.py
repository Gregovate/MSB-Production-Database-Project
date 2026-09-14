"""Protected read API for the standalone Setup Kit Inventory route."""
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
    """List existing physical Kit Boxes with reusable assignment/inventory state.

    This does not create another task -> KIT relationship. It reads the accepted
    #141 relationship_type='KIT' rows and the #167 expected-content/inventory
    tables so the standalone inventory route can navigate current Kit Boxes.
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
                    coalesce(contents.expected_item_rows, 0) AS expected_item_rows,
                    coalesce(contents.counted_item_rows, 0) AS counted_item_rows,
                    coalesce(contents.uncounted_item_rows, 0) AS uncounted_item_rows,
                    (review.container_id IS NOT NULL) AS has_unverified_items,
                    coalesce(assignments.assigned_task_count, 0) AS assigned_task_count,
                    assignments.assigned_task_names
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
                LEFT JOIN ref.setup_container_extra_material_review AS review
                  ON review.container_id = c.container_id
                LEFT JOIN LATERAL (
                    SELECT
                        count(*) AS assigned_task_count,
                        string_agg(
                            t.task_name,
                            '; '
                            ORDER BY t.display_order, t.setup_task_id
                        ) AS assigned_task_names
                    FROM ref.setup_task_container_support AS tc
                    JOIN ref.setup_task AS t
                      ON t.setup_task_id = tc.setup_task_id
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
        error="Setup Kit Inventory is temporarily unavailable.",
        engineering_error=str(exc),
    ), 503


@setup_kit_inventory_api.errorhandler(psycopg2.Error)
def database_error(exc: psycopg2.Error) -> tuple[Response, int]:
    message = (exc.diag.message_primary or "Setup Kit Inventory database query failed").strip()
    return jsonify(error=message, engineering_error=str(exc)), 500
