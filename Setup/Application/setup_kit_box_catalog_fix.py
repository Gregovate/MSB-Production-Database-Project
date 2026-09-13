"""Issue #141 browser-review fix for Kit Box catalog reads.

The first browser candidate joined ref.container_type only to rediscover the
already-governed type name for rows filtered by container_type_id=2. The Setup
runtime does not otherwise need that lookup for Kit assignment. Keep the read
surface on the already-used container/task relationship tables and expose the
known governed type label directly.
"""
from __future__ import annotations

from typing import Any

from psycopg2.extras import RealDictCursor

from setup_next_repository import SetupNextRepository, SetupNextRepositoryError


def _kit_box_catalog(self: SetupNextRepository, *, task_id: int) -> list[dict[str, Any]]:
    with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        cur.execute(
            """
            SELECT t.setup_task_id, t.active_flag, t.stage_id
            FROM ref.setup_task AS t
            WHERE t.setup_task_id = %s
            """,
            (task_id,),
        )
        task = cur.fetchone()
        if task is None:
            raise SetupNextRepositoryError("Setup task was not found")

        cur.execute(
            """
            SELECT
                c.container_id,
                c.description AS container_description,
                c.location_code AS home_location_code,
                c.container_type_id,
                'Kit Box'::text AS container_type_name,
                (current_tc.container_id IS NOT NULL) AS assigned,
                current_tc.notes AS assignment_notes,
                coalesce(shared.other_task_count, 0) AS other_task_count,
                shared.other_task_assignments
            FROM ref.container AS c
            LEFT JOIN ref.setup_task_container_support AS current_tc
              ON current_tc.setup_task_id = %s
             AND current_tc.container_id = c.container_id
             AND current_tc.relationship_type = 'KIT'
            LEFT JOIN LATERAL (
                SELECT
                    count(*) AS other_task_count,
                    string_agg(
                        coalesce(s.stage_key || ' · ', '') || other_t.task_name,
                        '; ' ORDER BY s.park_order NULLS LAST,
                                     s.sub_order NULLS LAST,
                                     s.stage_key,
                                     other_t.display_order,
                                     other_t.setup_task_id
                    ) AS other_task_assignments
                FROM ref.setup_task_container_support AS other_tc
                JOIN ref.setup_task AS other_t
                  ON other_t.setup_task_id = other_tc.setup_task_id
                LEFT JOIN ref.stage AS s
                  ON s.stage_id = other_t.stage_id
                WHERE other_tc.container_id = c.container_id
                  AND other_tc.relationship_type = 'KIT'
                  AND other_tc.setup_task_id <> %s
            ) AS shared ON true
            WHERE c.container_type_id = 2
            ORDER BY lower(coalesce(c.description, '')), c.container_id
            """,
            (task_id, task_id),
        )
        return [dict(row) for row in cur.fetchall()]


def install_setup_kit_box_catalog_fix() -> None:
    SetupNextRepository.kit_box_catalog = _kit_box_catalog
