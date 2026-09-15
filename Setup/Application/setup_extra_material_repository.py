"""Structured Extra Material / Container inventory access for Setup."""
from __future__ import annotations

from contextlib import contextmanager
from typing import Any, Iterator

import psycopg2
from psycopg2.extras import RealDictCursor


class SetupExtraMaterialRepositoryError(RuntimeError):
    """Setup Extra Material work failed safely."""


class SetupExtraMaterialRepository:
    def __init__(self, dsn: str):
        self.dsn = dsn.strip()
        if not self.dsn:
            raise SetupExtraMaterialRepositoryError("Setup PostgreSQL DSN is required")

    @contextmanager
    def connect(self) -> Iterator[Any]:
        conn = psycopg2.connect(self.dsn)
        try:
            yield conn
        finally:
            conn.close()

    @contextmanager
    def write_connect(self) -> Iterator[Any]:
        conn = psycopg2.connect(self.dsn)
        try:
            conn.set_session(readonly=False, autocommit=False)
            yield conn
        finally:
            conn.close()

    def catalog(self, *, include_inactive: bool = False) -> list[dict[str, Any]]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT setup_extra_material_id, material_name, lifecycle_class,
                       default_uom, active_flag, display_order, notes
                FROM ref.setup_extra_material
                WHERE (%s OR active_flag)
                ORDER BY display_order, material_name, setup_extra_material_id
                """,
                (include_inactive,),
            )
            return [dict(row) for row in cur.fetchall()]

    def task_materials(self, setup_task_id: int) -> list[dict[str, Any]]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    tm.setup_task_extra_material_id,
                    tm.setup_task_id,
                    tm.setup_extra_material_id,
                    m.material_name,
                    m.lifecycle_class,
                    tm.quantity_required,
                    tm.quantity_uom,
                    tm.size_text,
                    tm.length_value,
                    tm.length_unit,
                    tm.color,
                    tm.quantity_qualifier,
                    tm.verification_state,
                    tm.notes,
                    tm.active_flag,
                    coalesce(src.sources, '[]'::jsonb) AS sources
                FROM ref.setup_task_extra_material tm
                JOIN ref.setup_extra_material m
                  ON m.setup_extra_material_id = tm.setup_extra_material_id
                LEFT JOIN LATERAL (
                    SELECT jsonb_agg(
                        jsonb_build_object(
                            'setup_task_extra_material_source_id', s.setup_task_extra_material_source_id,
                            'container_id', s.container_id,
                            'container_description', c.description,
                            'expected_quantity', s.expected_quantity,
                            'verification_state', s.verification_state,
                            'notes', s.notes,
                            'active_flag', s.active_flag
                        ) ORDER BY s.setup_task_extra_material_source_id
                    ) AS sources
                    FROM ref.setup_task_extra_material_source s
                    JOIN ref.container c ON c.container_id = s.container_id
                    WHERE s.setup_task_extra_material_id = tm.setup_task_extra_material_id
                      AND s.active_flag
                ) src ON true
                WHERE tm.setup_task_id = %s
                  AND tm.active_flag
                ORDER BY m.display_order, m.material_name,
                         tm.length_value NULLS LAST, tm.size_text NULLS LAST,
                         tm.color NULLS LAST, tm.setup_task_extra_material_id
                """,
                (setup_task_id,),
            )
            result: list[dict[str, Any]] = []
            for row in cur.fetchall():
                item = dict(row)
                sources = item.get("sources")
                item["sources"] = sources if isinstance(sources, list) else list(sources or [])
                result.append(item)
            return result

    def container_contents(self, container_id: int) -> dict[str, Any]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT c.container_id,
                       c.description,
                       c.container_type_id,
                       CASE WHEN c.container_type_id = 2 THEN 'Kit Box' END AS container_type_name,
                       c.location_code,
                       r.unverified_items_text
                FROM ref.container c
                LEFT JOIN ref.setup_container_extra_material_review r
                  ON r.container_id = c.container_id
                WHERE c.container_id = %s
                """,
                (container_id,),
            )
            container = cur.fetchone()
            if container is None:
                raise SetupExtraMaterialRepositoryError("Container was not found")

            cur.execute(
                """
                SELECT
                    cem.setup_container_extra_material_id,
                    cem.container_id,
                    cem.setup_extra_material_id,
                    m.material_name,
                    m.lifecycle_class,
                    cem.expected_quantity,
                    cem.quantity_uom,
                    cem.size_text,
                    cem.length_value,
                    cem.length_unit,
                    cem.color,
                    cem.verification_state,
                    cem.notes,
                    cem.active_flag,
                    b.inventory_event_count,
                    b.on_hand_quantity,
                    b.last_inventory_event_at
                FROM ref.setup_container_extra_material cem
                JOIN ref.setup_extra_material m
                  ON m.setup_extra_material_id = cem.setup_extra_material_id
                LEFT JOIN ops.setup_extra_material_inventory_balance b
                  ON b.setup_container_extra_material_id = cem.setup_container_extra_material_id
                WHERE cem.container_id = %s
                  AND cem.active_flag
                ORDER BY m.display_order, m.material_name,
                         cem.length_value NULLS LAST, cem.size_text NULLS LAST,
                         cem.color NULLS LAST, cem.setup_container_extra_material_id
                """,
                (container_id,),
            )
            contents = [dict(row) for row in cur.fetchall()]
        return {"container": dict(container), "contents": contents}

    def inventory_history(self, setup_container_extra_material_id: int) -> list[dict[str, Any]]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    e.setup_extra_material_inventory_event_id,
                    e.setup_container_extra_material_id,
                    e.event_type,
                    e.quantity_delta,
                    e.event_note,
                    e.occurred_at,
                    e.created_at,
                    e.created_by_person_id,
                    coalesce(
                        nullif(btrim(concat_ws(' ', p.first_name, p.last_name)), ''),
                        nullif(btrim(p.email), ''),
                        CASE WHEN p.person_id IS NULL THEN NULL
                             ELSE 'Person ' || p.person_id::text END
                    ) AS actor_display_name
                FROM ops.setup_extra_material_inventory_event e
                LEFT JOIN ref.person p ON p.person_id = e.created_by_person_id
                WHERE e.setup_container_extra_material_id = %s
                ORDER BY e.occurred_at DESC,
                         e.setup_extra_material_inventory_event_id DESC
                """,
                (setup_container_extra_material_id,),
            )
            return [dict(row) for row in cur.fetchall()]

    def balance_summary(self, *, material_name: str | None = None) -> list[dict[str, Any]]:
        """Compare reusable requirements to physical stock by material/spec.

        A missing physical count remains NULL, never zero. If any stock row for a
        specification is still uncounted, the aggregate on-hand/available result
        remains NULL so operators cannot mistake partial inventory for truth.
        """
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                WITH req AS (
                    SELECT
                        tm.setup_extra_material_id,
                        m.material_name,
                        tm.size_text,
                        tm.length_value,
                        tm.length_unit,
                        tm.color,
                        tm.quantity_uom,
                        sum(tm.quantity_required) AS required_quantity,
                        count(*) AS requirement_rows,
                        count(*) FILTER (WHERE tm.verification_state <> 'VERIFIED') AS unverified_requirement_rows
                    FROM ref.setup_task_extra_material tm
                    JOIN ref.setup_extra_material m
                      ON m.setup_extra_material_id = tm.setup_extra_material_id
                    JOIN ref.setup_task t ON t.setup_task_id = tm.setup_task_id
                    WHERE tm.active_flag AND t.active_flag
                      AND tm.quantity_required IS NOT NULL
                      AND (%s IS NULL OR lower(m.material_name) = lower(%s))
                    GROUP BY tm.setup_extra_material_id, m.material_name,
                             tm.size_text, tm.length_value, tm.length_unit,
                             tm.color, tm.quantity_uom
                ), inv AS (
                    SELECT
                        b.setup_extra_material_id,
                        b.material_name,
                        b.size_text,
                        b.length_value,
                        b.length_unit,
                        b.color,
                        b.quantity_uom,
                        sum(b.on_hand_quantity) FILTER (WHERE b.on_hand_quantity IS NOT NULL) AS counted_on_hand_quantity,
                        count(*) AS stock_rows,
                        count(*) FILTER (WHERE b.on_hand_quantity IS NULL) AS uncounted_stock_rows
                    FROM ops.setup_extra_material_inventory_balance b
                    WHERE (%s IS NULL OR lower(b.material_name) = lower(%s))
                    GROUP BY b.setup_extra_material_id, b.material_name,
                             b.size_text, b.length_value, b.length_unit,
                             b.color, b.quantity_uom
                )
                SELECT
                    coalesce(req.setup_extra_material_id, inv.setup_extra_material_id) AS setup_extra_material_id,
                    coalesce(req.material_name, inv.material_name) AS material_name,
                    coalesce(req.size_text, inv.size_text) AS size_text,
                    coalesce(req.length_value, inv.length_value) AS length_value,
                    coalesce(req.length_unit, inv.length_unit) AS length_unit,
                    coalesce(req.color, inv.color) AS color,
                    coalesce(req.quantity_uom, inv.quantity_uom) AS quantity_uom,
                    req.required_quantity,
                    req.requirement_rows,
                    req.unverified_requirement_rows,
                    CASE WHEN coalesce(inv.uncounted_stock_rows, 0) > 0
                         THEN NULL ELSE inv.counted_on_hand_quantity END AS on_hand_quantity,
                    coalesce(inv.stock_rows, 0) AS stock_rows,
                    coalesce(inv.uncounted_stock_rows, 0) AS uncounted_stock_rows,
                    CASE
                        WHEN coalesce(inv.uncounted_stock_rows, 0) > 0 THEN NULL
                        WHEN req.required_quantity IS NULL THEN inv.counted_on_hand_quantity
                        WHEN inv.counted_on_hand_quantity IS NULL THEN NULL
                        ELSE inv.counted_on_hand_quantity - req.required_quantity
                    END AS available_after_requirement
                FROM req
                FULL OUTER JOIN inv
                  ON req.setup_extra_material_id = inv.setup_extra_material_id
                 AND req.size_text IS NOT DISTINCT FROM inv.size_text
                 AND req.length_value IS NOT DISTINCT FROM inv.length_value
                 AND req.length_unit IS NOT DISTINCT FROM inv.length_unit
                 AND req.color IS NOT DISTINCT FROM inv.color
                 AND req.quantity_uom = inv.quantity_uom
                ORDER BY coalesce(req.material_name, inv.material_name),
                         coalesce(req.length_value, inv.length_value) NULLS LAST,
                         coalesce(req.size_text, inv.size_text) NULLS LAST,
                         coalesce(req.color, inv.color) NULLS LAST
                """,
                (material_name, material_name, material_name, material_name),
            )
            return [dict(row) for row in cur.fetchall()]

    def _command(self, sql: str, values: tuple[Any, ...], empty_error: str) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql, values)
            row = cur.fetchone()
            conn.commit()
            if row is None:
                raise SetupExtraMaterialRepositoryError(empty_error)
            return dict(row)

    def create_material(self, *, email: str, payload: dict[str, Any]) -> dict[str, Any]:
        return self._command(
            "SELECT * FROM ref.create_setup_extra_material(%s,%s,%s,%s,%s)",
            (email, payload.get("material_name"), payload.get("lifecycle_class", "REUSABLE"),
             payload.get("default_uom", "EA"), payload.get("notes")),
            "Extra Material creation returned no result",
        )

    def update_material(self, *, email: str, material_id: int, payload: dict[str, Any]) -> dict[str, Any]:
        return self._command(
            "SELECT * FROM ref.update_setup_extra_material(%s,%s,%s,%s,%s,%s,%s,%s)",
            (email, material_id, payload.get("material_name"), payload.get("lifecycle_class"),
             payload.get("default_uom"), payload.get("notes"), payload.get("active_flag", True),
             payload.get("display_order", 100)),
            "Extra Material update returned no result",
        )

    def set_task_material(self, *, email: str, setup_task_id: int, row_id: int | None, payload: dict[str, Any]) -> dict[str, Any]:
        return self._command(
            "SELECT * FROM ref.set_setup_task_extra_material(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
            (email, row_id, setup_task_id, payload.get("setup_extra_material_id"),
             payload.get("quantity_required"), payload.get("quantity_uom", "EA"),
             payload.get("size_text"), payload.get("length_value"), payload.get("length_unit"),
             payload.get("color"), payload.get("quantity_qualifier", "EXACT"),
             payload.get("verification_state", "UNVERIFIED"), payload.get("notes"),
             payload.get("active_flag", True)),
            "Task Extra Material update returned no result",
        )

    def set_task_source(self, *, email: str, requirement_id: int, row_id: int | None, payload: dict[str, Any]) -> dict[str, Any]:
        return self._command(
            "SELECT * FROM ref.set_setup_task_extra_material_source(%s,%s,%s,%s,%s,%s,%s,%s)",
            (email, row_id, requirement_id, payload.get("container_id"),
             payload.get("expected_quantity"), payload.get("verification_state", "UNVERIFIED"),
             payload.get("notes"), payload.get("active_flag", True)),
            "Task Extra Material source update returned no result",
        )

    def set_container_content(self, *, email: str, container_id: int, row_id: int | None, payload: dict[str, Any]) -> dict[str, Any]:
        return self._command(
            "SELECT * FROM ref.set_setup_container_extra_material(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
            (email, row_id, container_id, payload.get("setup_extra_material_id"),
             payload.get("expected_quantity"), payload.get("quantity_uom", "EA"),
             payload.get("size_text"), payload.get("length_value"), payload.get("length_unit"),
             payload.get("color"), payload.get("verification_state", "UNVERIFIED"),
             payload.get("notes"), payload.get("active_flag", True)),
            "Container Extra Material update returned no result",
        )

    def set_unverified_items(self, *, email: str, container_id: int, text: str | None) -> dict[str, Any]:
        return self._command(
            "SELECT * FROM ref.set_setup_container_unverified_items(%s,%s,%s)",
            (email, container_id, text),
            "Container unverified-items update returned no result",
        )

    def record_inventory_event(self, *, email: str, content_id: int, payload: dict[str, Any]) -> dict[str, Any]:
        return self._command(
            "SELECT * FROM ops.record_setup_extra_material_inventory_event(%s,%s,%s,%s,%s,%s)",
            (email, content_id, payload.get("event_type"), payload.get("quantity_delta"),
             payload.get("event_note"), payload.get("occurred_at")),
            "Inventory event returned no result",
        )
