"""Repository projection for Issue #145 Manager Material Completeness Audit."""
from __future__ import annotations

from collections import defaultdict
from contextlib import contextmanager
from typing import Any, Iterator

import psycopg2
from psycopg2.extras import RealDictCursor

from setup_assignment_layer import _scope_key
from setup_next_repository import SetupNextRepository, SetupNextRepositoryError


class SetupMaterialAuditRepositoryError(RuntimeError):
    pass


def classify_kit_coverage(
    active_assignment_count: int,
    total_assignment_count: int,
    disposition_active: bool,
) -> str:
    """Classify one physical Kit Box without inferring intent from unrelated facts."""
    if int(active_assignment_count or 0) > 0:
        return "ASSIGNED_ACTIVE"
    if int(total_assignment_count or 0) > 0:
        return "INACTIVE_OBSOLETE_ONLY"
    if bool(disposition_active):
        return "REVIEWED_SHARED_NON_TASK"
    return "UNASSIGNED_UNRESOLVED"


class SetupMaterialAuditRepository:
    def __init__(self, dsn: str):
        self.dsn = (dsn or "").strip()
        if not self.dsn:
            raise SetupMaterialAuditRepositoryError("Setup PostgreSQL DSN is required")

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

    def _context_season_year(self) -> int:
        with self.connect() as conn, conn.cursor() as cur:
            cur.execute(
                """
                SELECT coalesce(
                    max(ss.season_year),
                    extract(year from current_date)::integer
                )
                FROM ops.setup_session AS ss
                """
            )
            row = cur.fetchone()
        return int(row[0])

    def _active_scope_tasks(self) -> list[dict[str, Any]]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    t.setup_task_id,
                    t.task_name,
                    t.stage_id,
                    s.stage_key,
                    s.stage_name,
                    s.park_order,
                    s.sub_order,
                    t.lor_scene_id,
                    ls.scene_name,
                    t.display_order,
                    t.requires_display_material,
                    EXISTS (
                        SELECT 1
                        FROM ref.setup_task_display AS td
                        WHERE td.setup_task_id = t.setup_task_id
                    ) AS has_explicit_owner_rows
                FROM ref.setup_task AS t
                LEFT JOIN ref.stage AS s
                  ON s.stage_id = t.stage_id
                LEFT JOIN ref.lor_scene AS ls
                  ON ls.lor_scene_id = t.lor_scene_id
                WHERE t.active_flag
                ORDER BY
                    s.park_order NULLS LAST,
                    s.sub_order NULLS LAST,
                    s.stage_key NULLS LAST,
                    ls.scene_name NULLS LAST,
                    t.display_order,
                    t.setup_task_id
                """
            )
            return [dict(row) for row in cur.fetchall()]

    @staticmethod
    def _scope_label(tasks: list[dict[str, Any]], scope_key: tuple[str, int] | tuple[str, int, int]) -> str:
        first = tasks[0]
        stage = " · ".join(
            bit for bit in (str(first.get("stage_key") or "").strip(), str(first.get("stage_name") or "").strip())
            if bit
        ) or "Unscoped"
        if scope_key[0] == "SCENE":
            return f"{stage} · {first.get('scene_name') or 'Scene'}"
        if scope_key[0] == "UNSCOPED":
            return f"Unscoped · Task {first.get('setup_task_id')}"
        return stage

    def future_session_audit(self) -> dict[str, Any]:
        """Show reusable tasks that future Session creation will omit.

        ops.create_setup_session seeds only ref.setup_task rows with active_flag=true.
        Inactive rows are therefore review items before creating a future Session,
        even when some are intentionally retired.
        """
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    t.setup_task_id,
                    t.task_name,
                    t.stage_id,
                    s.stage_key,
                    s.stage_name,
                    t.lor_scene_id,
                    ls.scene_name,
                    t.display_order,
                    t.task_action_type,
                    t.requires_display_material,
                    t.updated_at AS task_updated_at,
                    t.updated_by AS task_updated_by,
                    t.updated_by_person_id AS task_updated_by_person_id,
                    coalesce(
                        nullif(btrim(pg_catalog.concat_ws(' ', updater.first_name, updater.last_name)), ''),
                        nullif(btrim(updater.email), ''),
                        CASE
                            WHEN t.updated_by_person_id IS NOT NULL
                            THEN 'Person ' || t.updated_by_person_id::text
                            ELSE NULL
                        END,
                        nullif(btrim(t.updated_by), ''),
                        'Unknown actor'
                    ) AS task_updated_by_display,
                    (
                        SELECT count(*)
                        FROM ops.setup_session_task AS st
                        WHERE st.setup_task_id = t.setup_task_id
                    ) AS annual_history_count,
                    (
                        SELECT max(ss.season_year)
                        FROM ops.setup_session_task AS st
                        JOIN ops.setup_session AS ss
                          ON ss.setup_session_id = st.setup_session_id
                        WHERE st.setup_task_id = t.setup_task_id
                    ) AS latest_season_year,
                    (
                        SELECT count(*)
                        FROM ref.setup_task_container_support AS tc
                        WHERE tc.setup_task_id = t.setup_task_id
                          AND tc.relationship_type = 'KIT'
                    ) AS kit_assignment_count,
                    (
                        SELECT count(*)
                        FROM ref.setup_task_extra_material AS tm
                        WHERE tm.setup_task_id = t.setup_task_id
                          AND tm.active_flag
                    ) AS extra_material_count,
                    (
                        SELECT count(*)
                        FROM ref.setup_task_dependency AS dep
                        JOIN ref.setup_task AS dependent
                          ON dependent.setup_task_id = dep.setup_task_id
                        WHERE dep.prerequisite_setup_task_id = t.setup_task_id
                          AND dependent.active_flag
                    ) AS active_dependent_count
                FROM ref.setup_task AS t
                LEFT JOIN ref.stage AS s
                  ON s.stage_id = t.stage_id
                LEFT JOIN ref.lor_scene AS ls
                  ON ls.lor_scene_id = t.lor_scene_id
                LEFT JOIN ref.person AS updater
                  ON updater.person_id = t.updated_by_person_id
                WHERE NOT t.active_flag
                ORDER BY
                    s.park_order NULLS LAST,
                    s.sub_order NULLS LAST,
                    s.stage_key NULLS LAST,
                    ls.scene_name NULLS LAST,
                    t.display_order,
                    t.setup_task_id
                """
            )
            inactive = [dict(row) for row in cur.fetchall()]

            cur.execute(
                """
                SELECT count(*) AS active_count
                FROM ref.setup_task
                WHERE active_flag
                """
            )
            active_row = cur.fetchone()
            active_count = int(active_row["active_count"] if active_row else 0)

        for row in inactive:
            row["annual_history_count"] = int(row.get("annual_history_count") or 0)
            row["kit_assignment_count"] = int(row.get("kit_assignment_count") or 0)
            row["extra_material_count"] = int(row.get("extra_material_count") or 0)
            row["active_dependent_count"] = int(row.get("active_dependent_count") or 0)
            row["impact_signals"] = [
                label
                for present, label in (
                    (row["annual_history_count"] > 0, "Prior annual history"),
                    (bool(row.get("requires_display_material")), "Display material"),
                    (row["kit_assignment_count"] > 0, "Kit assignment"),
                    (row["extra_material_count"] > 0, "Extra material"),
                    (row["active_dependent_count"] > 0, "Active task depends on it"),
                )
                if present
            ]

        summary = {
            "active_will_seed": active_count,
            "inactive_will_not_seed": len(inactive),
            "inactive_with_history": sum(1 for row in inactive if row["annual_history_count"] > 0),
            "inactive_with_material": sum(
                1
                for row in inactive
                if bool(row.get("requires_display_material"))
                or row["kit_assignment_count"] > 0
                or row["extra_material_count"] > 0
            ),
            "inactive_prerequisites": sum(1 for row in inactive if row["active_dependent_count"] > 0),
            "inactive_with_signals": sum(1 for row in inactive if row["impact_signals"]),
        }
        return {"summary": summary, "inactive_tasks": inactive}

    def display_audit(self) -> dict[str, Any]:
        task_rows = self._active_scope_tasks()
        grouped: dict[tuple[Any, ...], list[dict[str, Any]]] = defaultdict(list)

        for task in task_rows:
            key = _scope_key(task.get("stage_id"), task.get("lor_scene_id"), task.get("scene_name"))
            if key is None:
                if task.get("requires_display_material") or task.get("has_explicit_owner_rows"):
                    grouped[("UNSCOPED", int(task["setup_task_id"]), int(task["setup_task_id"]))].append(task)
                continue
            grouped[key].append(task)

        context_year = self._context_season_year()
        next_repo = SetupNextRepository(self.dsn)
        rows: list[dict[str, Any]] = []

        for key, tasks in grouped.items():
            material_tasks = [
                task for task in tasks
                if bool(task.get("requires_display_material")) or bool(task.get("has_explicit_owner_rows"))
            ]
            if not material_tasks:
                continue

            correction_task = material_tasks[0]
            if key[0] == "UNSCOPED":
                rows.append(
                    {
                        "scope_type": "UNSCOPED",
                        "scope_id": None,
                        "scope_label": self._scope_label(tasks, key),
                        "active_tasks": tasks,
                        "material_tasks": material_tasks,
                        "source_display_count": 0,
                        "ownership_mode": "NOT_APPLICABLE",
                        "coverage_status": "REVIEW_REQUIRED",
                        "missing_owner_count": 0,
                        "invalid_owner_count": 0,
                        "duplicate_owner_count": 0,
                        "stale_owner_count": 0,
                        "uncontained_display_count": 0,
                        "scope_issue": "MATERIAL_TASK_WITHOUT_STAGE_SCOPE",
                        "correction_setup_task_id": int(correction_task["setup_task_id"]),
                    }
                )
                continue

            try:
                context = next_repo.field_context(
                    task_id=int(correction_task["setup_task_id"]),
                    season_year=context_year,
                )
            except SetupNextRepositoryError as exc:
                raise SetupMaterialAuditRepositoryError(str(exc)) from exc

            ownership = context.get("display_ownership") or {}
            material_resolution = context.get("material_resolution") or {}
            rows.append(
                {
                    "scope_type": str(key[0]),
                    "scope_id": int(key[1]),
                    "scope_label": self._scope_label(tasks, key),
                    "stage_id": correction_task.get("stage_id"),
                    "stage_key": correction_task.get("stage_key"),
                    "stage_name": correction_task.get("stage_name"),
                    "lor_scene_id": correction_task.get("lor_scene_id") if key[0] == "SCENE" else None,
                    "scene_name": correction_task.get("scene_name") if key[0] == "SCENE" else None,
                    "active_tasks": tasks,
                    "material_tasks": ownership.get("material_tasks") or material_tasks,
                    "source_display_count": int(ownership.get("resolved_display_count") or 0),
                    "ownership_mode": ownership.get("mode") or material_resolution.get("ownership_mode"),
                    "coverage_status": ownership.get("coverage_status") or material_resolution.get("ownership_status"),
                    "missing_owner_count": int(ownership.get("missing_owner_count") or 0),
                    "invalid_owner_count": int(ownership.get("invalid_owner_count") or 0),
                    "duplicate_owner_count": int(ownership.get("duplicate_owner_count") or 0),
                    "stale_owner_count": int(ownership.get("stale_owner_count") or 0),
                    "uncontained_display_count": int(material_resolution.get("uncontained_display_count") or 0),
                    "scope_issue": None,
                    "correction_setup_task_id": int(correction_task["setup_task_id"]),
                }
            )

        rows.sort(
            key=lambda row: (
                0 if row.get("stage_id") is None else 1,
                str(row.get("stage_key") or ""),
                str(row.get("scene_name") or ""),
                int(row.get("scope_id") or 0),
            )
        )
        summary = {
            "scopes_reviewed": len(rows),
            "complete": sum(1 for row in rows if row.get("coverage_status") == "COMPLETE"),
            "review_required": sum(1 for row in rows if row.get("coverage_status") != "COMPLETE"),
            "missing": sum(int(row.get("missing_owner_count") or 0) for row in rows),
            "invalid": sum(int(row.get("invalid_owner_count") or 0) for row in rows),
            "duplicate": sum(int(row.get("duplicate_owner_count") or 0) for row in rows),
            "stale": sum(int(row.get("stale_owner_count") or 0) for row in rows),
        }
        return {"context_season_year": context_year, "summary": summary, "scopes": rows}

    def kit_audit(self) -> dict[str, Any]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    c.container_id,
                    c.description AS container_description,
                    c.location_code AS home_location_code,
                    d.disposition,
                    coalesce(d.active_flag, false) AS disposition_active,
                    d.review_note AS disposition_note,
                    d.reviewed_at AS disposition_reviewed_at,
                    d.reviewed_by_person_id,
                    coalesce(
                        nullif(btrim(pg_catalog.concat_ws(' ', p.first_name, p.last_name)), ''),
                        nullif(btrim(p.email), ''),
                        'Person ' || p.person_id::text
                    ) AS disposition_reviewed_by
                FROM ref.container AS c
                LEFT JOIN ref.setup_kit_assignment_disposition AS d
                  ON d.container_id = c.container_id
                LEFT JOIN ref.person AS p
                  ON p.person_id = d.reviewed_by_person_id
                WHERE c.container_type_id = 2
                ORDER BY lower(coalesce(c.description, '')), c.container_id
                """
            )
            containers = [dict(row) for row in cur.fetchall()]

            cur.execute(
                """
                SELECT
                    tc.container_id,
                    tc.setup_task_id,
                    tc.notes AS relationship_notes,
                    t.task_name,
                    t.active_flag AS task_active_flag,
                    t.stage_id,
                    s.stage_key,
                    s.stage_name,
                    t.lor_scene_id,
                    ls.scene_name
                FROM ref.setup_task_container_support AS tc
                JOIN ref.setup_task AS t
                  ON t.setup_task_id = tc.setup_task_id
                LEFT JOIN ref.stage AS s
                  ON s.stage_id = t.stage_id
                LEFT JOIN ref.lor_scene AS ls
                  ON ls.lor_scene_id = t.lor_scene_id
                JOIN ref.container AS c
                  ON c.container_id = tc.container_id
                 AND c.container_type_id = 2
                WHERE tc.relationship_type = 'KIT'
                ORDER BY
                    tc.container_id,
                    t.active_flag DESC,
                    s.park_order NULLS LAST,
                    s.sub_order NULLS LAST,
                    s.stage_key NULLS LAST,
                    t.display_order,
                    t.setup_task_id
                """
            )
            relationships = [dict(row) for row in cur.fetchall()]

        by_container: dict[int, list[dict[str, Any]]] = defaultdict(list)
        for relationship in relationships:
            by_container[int(relationship["container_id"])].append(relationship)

        rows: list[dict[str, Any]] = []
        for container in containers:
            container_id = int(container["container_id"])
            assignments = by_container.get(container_id, [])
            active_assignments = [row for row in assignments if bool(row.get("task_active_flag"))]
            inactive_assignments = [row for row in assignments if not bool(row.get("task_active_flag"))]
            disposition_active = bool(container.get("disposition_active"))
            classification = classify_kit_coverage(
                len(active_assignments),
                len(assignments),
                disposition_active,
            )
            disposition_conflict = bool(disposition_active and assignments)
            rows.append(
                {
                    **container,
                    "active_assignment_count": len(active_assignments),
                    "inactive_assignment_count": len(inactive_assignments),
                    "total_assignment_count": len(assignments),
                    "active_assignments": active_assignments,
                    "inactive_assignments": inactive_assignments,
                    "coverage_state": classification,
                    "disposition_conflict": disposition_conflict,
                    "needs_review": classification in {
                        "INACTIVE_OBSOLETE_ONLY",
                        "UNASSIGNED_UNRESOLVED",
                    } or disposition_conflict,
                }
            )

        summary = {
            "physical_kit_boxes": len(rows),
            "assigned_active": sum(1 for row in rows if row["coverage_state"] == "ASSIGNED_ACTIVE"),
            "inactive_obsolete_only": sum(1 for row in rows if row["coverage_state"] == "INACTIVE_OBSOLETE_ONLY"),
            "reviewed_shared_non_task": sum(1 for row in rows if row["coverage_state"] == "REVIEWED_SHARED_NON_TASK"),
            "unresolved_unassigned": sum(1 for row in rows if row["coverage_state"] == "UNASSIGNED_UNRESOLVED"),
            "disposition_conflicts": sum(1 for row in rows if row["disposition_conflict"]),
        }
        return {"summary": summary, "kits": rows}

    def audit(self) -> dict[str, Any]:
        return {
            "future_session": self.future_session_audit(),
            "display": self.display_audit(),
            "kit": self.kit_audit(),
        }

    def set_kit_disposition(
        self,
        *,
        email: str,
        container_id: int,
        reviewed_shared_non_task: bool,
        note: str | None,
    ) -> dict[str, Any]:
        with self.write_connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT *
                FROM ref.set_setup_kit_assignment_disposition(%s,%s,%s,%s)
                """,
                (email, container_id, bool(reviewed_shared_non_task), note),
            )
            row = cur.fetchone()
            if row is None:
                raise SetupMaterialAuditRepositoryError(
                    "Setup Kit assignment disposition command returned no result"
                )
            conn.commit()
            return dict(row)
