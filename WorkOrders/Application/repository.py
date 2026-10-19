"""#419 Work Management: read-only projection of existing PostgreSQL authority.

Disposable preview: role-scoped reads and clone-only saves; no email.
The Server Management launcher must supply an isolated current-Production clone.
"""
from __future__ import annotations

import os
from contextlib import contextmanager
from pathlib import Path
from typing import Any, Iterator

import psycopg2
from psycopg2.extras import RealDictCursor


ROOT = Path(__file__).resolve().parents[2]
LEDGER_PATH = (
    ROOT
    / "Docs/02_Production_Database/01_System_Architecture/06_Work_Orders"
    / "engineering/WO419_Unified_Ticket_Read_Only_Candidate.sql"
)


class WorkManagementError(RuntimeError):
    def __init__(self, message: str, status: int = 400):
        super().__init__(message)
        self.status = status


def ledger_select() -> str:
    """Reuse the already documented DB-owned ledger rather than a second model."""
    sql = LEDGER_PATH.read_text(encoding="utf-8").strip().rstrip(";")
    if not sql.startswith("-- WO419-M01") or "FROM stage.work_order_intake i" not in sql:
        raise WorkManagementError("Approved read model unavailable.", 503)
    return sql


def work_management_role_permissions(cap: dict[str, Any]) -> dict[str, bool]:
    """Map existing Directus role/policies; never infer Crew from Person flags.

    Setup read permission includes generic Volunteers, but internal Work Order
    creation requires real Production Crew or Manager/Administrator authority.
    """
    policies = set(cap.get("policy_names") or [])
    can_manage = bool(cap.get("can_manage_setup"))
    can_create = can_manage or cap.get("role_name") in (
        "Production Crew", "Manager", "Administrator"
    ) or bool(policies.intersection(
        {"Production Crew", "Manager", "Administrator"}
    ))
    return {"can_manage": can_manage, "can_create": can_create,
            "can_assign": can_manage, "can_triage": can_manage}


class WorkManagementRepository:
    def __init__(self) -> None:
        self.dsn = os.environ.get("WORK_MGMT_DATABASE_DSN", "").strip()
        if os.environ.get("WORK_MGMT_PREVIEW_MODE") != "disposable" or not self.dsn:
            raise WorkManagementError(
                "Work Management preview requires disposable mode and a clone DSN.", 503
            )

    @contextmanager
    def connect(self) -> Iterator[Any]:
        conn = psycopg2.connect(self.dsn)
        try:
            conn.set_session(readonly=True, autocommit=False)
            with conn.cursor() as cur:
                cur.execute("SELECT current_database()")
                database_name = str(cur.fetchone()[0] or "").lower()
                if database_name == "msb" or not database_name:
                    raise WorkManagementError(
                        "Work Management preview refuses the Production database.", 503
                    )
            yield conn
        finally:
            conn.close()

    def access(self, email: str) -> dict[str, Any]:
        """Reuse deployed Directus capability authority and exact Person identity.

        This first slice uses existing Setup browsing capabilities, NOT a new
        grant. It fails closed if the signed-in human Person is not reconciled.
        """
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT caps.email, caps.display_name, caps.role_name,
                       caps.policy_names, caps.can_read_setup,
                       caps.can_manage_setup
                FROM ref.setup_browser_capabilities(%s) AS caps
                """,
                (email,),
            )
            cap = cur.fetchone()
            if not cap or not cap["can_read_setup"]:
                raise WorkManagementError("Work Order access is not authorized.", 403)
            cur.execute(
                """
                SELECT p.person_id
                FROM ref.person AS p
                WHERE lower(p.email) = %s
                  AND p.active_flag
                  AND p.directus_user_id IS NOT NULL
                """,
                (email,),
            )
            matches = cur.fetchall()
        if len(matches) != 1:
            raise WorkManagementError(
                "A unique active linked Person is required for My Work.", 403
            )
        permissions = work_management_role_permissions(cap)
        return {
            "person_id": int(matches[0]["person_id"]),
            "display_name": cap["display_name"] or email,
            **permissions,
            "can_read": True,
        }

    def assignees(self) -> list[dict[str, Any]]:
        """Person-ID based selector; no private contact fields returned."""
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT DISTINCT p.person_id,
                       COALESCE(
                           NULLIF(btrim(concat_ws(' ',
                               COALESCE(NULLIF(btrim(p.preferred_name), ''),
                                        NULLIF(btrim(p.first_name), '')),
                               NULLIF(btrim(p.last_name), '')
                           )), ''),
                           'Person #' || p.person_id::text
                       ) AS display_name
                FROM ops.work_order_assignment a
                JOIN ref.person p ON p.person_id = a.person_id
                WHERE a.active_flag AND p.active_flag
                ORDER BY display_name, person_id
                """
            )
            return [dict(row) for row in cur.fetchall()]

    def reviewer_options(self, actor: dict[str, Any]) -> dict[str, Any]:
        """Read Task Type/Stage/Work Area for authorized internal Creators.

        Only Managers may receive the People assignment selector. Read
        catalog access is not itself a Work Order mutation permission.
        """
        if not actor.get("can_create", actor.get("can_read", False)):
            raise WorkManagementError("Work Order creation is not authorized.", 403)
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            if actor["can_manage"]:
                cur.execute(
                    """
                    SELECT person_id,
                       coalesce(nullif(btrim(concat_ws(' ',
                           coalesce(nullif(btrim(preferred_name), ''),
                                    nullif(btrim(first_name), '')),
                           nullif(btrim(last_name), ''))), ''),
                           'Person #' || person_id::text) AS display_name
                FROM ref.person
                WHERE active_flag
                ORDER BY display_name, person_id
                    LIMIT 600
                    """
                )
                people = [dict(item) for item in cur.fetchall()]
            else:
                # Crew have no Person assignment selector.
                people = []
            cur.execute(
                "SELECT task_type_id AS id, task_type_name AS name "
                "FROM ref.task_type WHERE active_flag ORDER BY sort_order, task_type_name"
            )
            task_types = [dict(item) for item in cur.fetchall()]
            cur.execute(
                "SELECT stage_id AS id, concat_ws(' — ', 'Stage ' || stage_key, stage_name) AS name "
                "FROM ref.stage ORDER BY stage_key LIMIT 300"
            )
            stages = [dict(item) for item in cur.fetchall()]
            cur.execute(
                "SELECT work_area_id AS id, work_area_name AS name "
                "FROM ref.work_area ORDER BY work_area_name LIMIT 150"
            )
            areas = [dict(item) for item in cur.fetchall()]
            # Only Managers may create governed season-only Setup tasks.
            # Never offer HISTORICAL_VERIFICATION as a live season.
            seasons = []
            if actor["can_manage"]:
                cur.execute(
                    "SELECT season_year AS id, "
                    "season_year::text || ' · ' || session_status AS name "
                    "FROM ops.setup_session "
                    "WHERE session_status IN ('PLANNING','ACTIVE') "
                    "ORDER BY season_year DESC"
                )
                seasons = [dict(item) for item in cur.fetchall()]
        return {"people": people, "task_types": task_types,
                "stages": stages, "work_areas": areas,
                "setup_seasons": seasons}

    @staticmethod
    def enrich_feedback(cur: Any, rows: list[dict[str, Any]]) -> None:
        """Overlay clone-only correction decisions without rewriting Intake truth."""
        intake = [r["ticket"] for r in rows if r["type"] == "TASK_FEEDBACK"]
        if not intake:
            return
        cur.execute(
            "SELECT DISTINCT ON (ticket_key) ticket_key,event_kind,details "
            "FROM wo419_preview.activity WHERE ticket_key = ANY(%s) "
            "ORDER BY ticket_key,activity_id DESC", (intake,))
        latest = {r["ticket_key"]: r for r in cur.fetchall()}
        cur.execute(
            "SELECT a.ticket_key, a.target_person_id, "
            "COALESCE(NULLIF(btrim(concat_ws(' ',p.preferred_name,p.last_name)),''), "
            " 'Person #' || a.target_person_id::text) AS owner "
            "FROM wo419_preview.activity a JOIN ref.person p "
            "ON p.person_id=a.target_person_id "
            "WHERE a.event_kind='correction_owner' AND a.ticket_key=ANY(%s) "
            "ORDER BY a.activity_id DESC", (intake,))
        owners: dict[str, str] = {}
        for item in cur.fetchall():
            owners.setdefault(item["ticket_key"], item["owner"])
        for row in rows:
            if row["type"] != "TASK_FEEDBACK":
                continue
            if row["ticket"] in owners:
                row["owners"] = owners[row["ticket"]]
            info = latest.get(row["ticket"])
            if info and info["event_kind"] == "resolve":
                row["state"] = str(info["details"].get("disposition", "resolved")).upper()
                row["state_from"] = "DISPOSABLE_CORRECTION_ACTIVITY"
            elif info and info["event_kind"] == "clarify":
                row["state"] = "WAITING_ON_REPORTER"
            elif info and info["event_kind"] == "promoted_source":
                row["state"] = "PROMOTED_TO_WO"

    def tickets(
        self, *, actor: dict[str, Any], scope: str, person_id: int | None,
        show_completed: bool, search: str, sort: str = "priority",
        include_planning: bool = True, limit: int = 80,
    ) -> list[dict[str, Any]]:
        manager_scopes = ("all", "tickets", "person", "repairs", "testing",
                          "intake", "feedback", "unassigned", "critical")
        if scope not in ("mine", "my-created", "my-feedback", *manager_scopes):
            raise WorkManagementError("Unknown Work Order scope.")
        if scope in manager_scopes and not actor["can_manage"]:
            raise WorkManagementError("Manager view requires Manager permission.", 403)
        if scope == "person" and (person_id is None or person_id < 1):
            raise WorkManagementError("Select a valid assignee.")
        sort_modes = {
            "priority": "t.urgency ASC NULLS LAST, COALESCE(t.wo_id, t.in_id) DESC",
            "priority_desc": "t.urgency DESC NULLS LAST, COALESCE(t.wo_id, t.in_id) DESC",
            "number_asc": "COALESCE(t.wo_id, t.in_id) ASC",
            "number_desc": "COALESCE(t.wo_id, t.in_id) DESC",
            "created_asc": "t.opened_at ASC NULLS LAST, COALESCE(t.wo_id, t.in_id) ASC",
            "created_desc": "t.opened_at DESC NULLS LAST, COALESCE(t.wo_id, t.in_id) DESC",
        }
        if sort not in sort_modes:
            raise WorkManagementError("Unknown Work Order sort.")
        # These ORDER BY expressions are constants, never client-authored SQL.
        limit = max(1, min(int(limit), 100))
        user = int(actor["person_id"])
        selected = user if scope == "mine" else person_id
        conditions: list[str] = []
        params: list[Any] = []
        if not show_completed:
            conditions.append("t.done_at IS NULL AND t.active")
        # The existing native urgency catalog defines 5=Planning.
        # This is a reversible VIEW filter, not a destructive status change.
        # Include null/unknown priority rather than silently discarding it.
        if not include_planning:
            conditions.append(
                "(t.type <> 'WORK_ORDER' OR t.urgency IS DISTINCT FROM 5)"
            )
        if scope in ("mine", "person"):
            conditions.append("t.type = 'WORK_ORDER' AND %s = ANY(t.assignee_ids)")
            params.append(selected)
        if scope == "all":
            conditions.append("t.type = 'WORK_ORDER'")
        elif scope == "my-created":
            # Newly created Crew WO is initially unassigned, but discoverable
            # to its creator without granting access to Manager queues.
            conditions.append("t.type = 'WORK_ORDER' AND t.reporter_id = %s")
            params.append(user)
        elif scope == "my-feedback":
            conditions.append("t.type = 'TASK_FEEDBACK' AND t.reporter_id = %s")
            params.append(user)
        elif scope == "unassigned":
            conditions.append("t.type = 'WORK_ORDER' AND COALESCE(t.assigned_n, 0) = 0")
        elif scope == "critical":
            conditions.append("t.type = 'WORK_ORDER' AND t.urgency = 1")
        elif scope == "repairs":
            conditions.append("t.type = 'WORK_ORDER' AND t.test_id IS NULL")
        elif scope == "testing":
            conditions.append("t.type = 'WORK_ORDER' AND t.test_id IS NOT NULL")
        elif scope == "intake":
            # Original Intake remains immutable on clone promotion.
            # The actionable queue omits records already promoted.
            conditions.append(
                "t.type = 'INTAKE_REQUEST' AND NOT EXISTS ("
                "SELECT 1 FROM wo419_preview.activity a "
                "WHERE a.ticket_key=t.ticket AND a.event_kind='promoted_source')"
            )
        elif scope == "feedback":
            # Resolved/promoted correction history remains searchable in All,
            # not in the pending review queue.
            conditions.append(
                "t.type = 'TASK_FEEDBACK' AND NOT EXISTS ("
                "SELECT 1 FROM wo419_preview.activity a "
                "WHERE a.ticket_key=t.ticket "
                "AND a.event_kind IN ('resolve','promoted_source'))"
            )
        if search:
            conditions.append(
                "(t.ticket ILIKE %s OR t.title ILIKE %s "
                "OR t.location ILIKE %s OR t.owners ILIKE %s "
                "OR t.reported_by ILIKE %s OR t.state ILIKE %s "
                "OR t.source ILIKE %s "
                "OR replace(t.ticket, '-', '') ILIKE %s)"
            )
            params.extend([f"%{search}%" for _ in range(7)])
            params.append(f"%{search.replace('-', '').replace(' ', '')}%")
        where = " AND ".join(conditions) if conditions else "TRUE"
        query = (
            "SELECT t.* FROM (" + ledger_select() + ") AS t "
            "WHERE " + where + " "
            "ORDER BY " + sort_modes[sort] + ", "
            "t.last_at DESC NULLS LAST, t.ticket LIMIT %s"
        )
        params.append(limit)
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(query, params)
            rows = [dict(row) for row in cur.fetchall()]
            self.enrich_feedback(cur, rows)
            return rows

    def aging_report(self, *, actor: dict[str, Any],
                     sort: str = "created_asc",
                     include_planning: bool = True) -> list[dict[str, Any]]:
        """ALL recorded-open Work Orders, including inactive exceptions.

        Use native created_at, not last activity or assignment date. No
        LIMIT or active_flag predicate: this is an exception/audit report,
        not just the first page of the active repair dispatch queue.
        """
        if not actor["can_manage"]:
            raise WorkManagementError("Manager aging report is not authorized.", 403)
        sorts = {
            "created_asc": "t.opened_at ASC NULLS LAST, t.wo_id ASC",
            "created_desc": "t.opened_at DESC NULLS LAST, t.wo_id DESC",
            "priority": "t.urgency ASC NULLS LAST, t.opened_at ASC NULLS LAST, t.wo_id",
            "priority_desc": "t.urgency DESC NULLS LAST, t.opened_at ASC NULLS LAST, t.wo_id",
            "number_asc": "t.wo_id ASC",
            "number_desc": "t.wo_id DESC",
        }
        if sort not in sorts:
            raise WorkManagementError("Unknown aging-report sort.")
        sql_text = (
            "SELECT t.ticket, t.wo_id, t.title, t.opened_at, "
            "GREATEST(0, FLOOR(EXTRACT(EPOCH FROM "
            "(CURRENT_TIMESTAMP - t.opened_at)) / 86400))::integer AS days_open, "
            "t.urgency, t.owners, t.assigned_n, t.location, t.yr, "
            "t.active, t.test_id, t.state, t.review_flag "
            "FROM (" + ledger_select() + ") t "
            "WHERE t.type = 'WORK_ORDER' AND t.done_at IS NULL "
            + ("" if include_planning else
               "AND t.urgency IS DISTINCT FROM 5 ")
            + "ORDER BY " + sorts[sort]
        )
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql_text)
            return [dict(item) for item in cur.fetchall()]

    def manager_inbox(self, actor: dict[str, Any]) -> dict[str, int]:
        """Actionable Public Intake versus pending feedback for Managers ONLY."""
        if not actor["can_manage"]:
            raise WorkManagementError("Manager Intake is not authorized.", 403)
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                  count(*) FILTER (
                    WHERE i.source_form_name IS DISTINCT FROM 'SETUP_CORRECTION'
                    AND NOT EXISTS (
                      SELECT 1 FROM wo419_preview.activity a
                      WHERE a.ticket_key = 'INTAKE-' || i.intake_id::text
                        AND a.event_kind = 'promoted_source'
                    )
                  ) AS public_intake,
                  count(*) FILTER (
                    WHERE i.source_form_name = 'SETUP_CORRECTION'
                    AND NOT EXISTS (
                      SELECT 1 FROM wo419_preview.activity a
                      WHERE a.ticket_key = 'INTAKE-' || i.intake_id::text
                        AND a.event_kind IN ('resolve','promoted_source')
                    )
                  ) AS task_feedback
                FROM stage.work_order_intake i
                WHERE i.triage_dropdown IS NULL OR i.triage_dropdown = '1'
                """
            )
            row = cur.fetchone()
            return {"public_intake": int(row["public_intake"] or 0),
                    "task_feedback": int(row["task_feedback"] or 0)}

    def ticket(self, *, actor: dict[str, Any], ticket_key: str) -> dict[str, Any]:
        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT t.* FROM (" + ledger_select() + ") t WHERE t.ticket = %s",
                (ticket_key,),
            )
            row = cur.fetchone()
            if row is None:
                raise WorkManagementError("Ticket not found.", 404)
            row = dict(row)
            if row["type"] == "TASK_FEEDBACK":
                self.enrich_feedback(cur, [row])
            if row["type"] != "WORK_ORDER" and not (
                actor["can_manage"] or row["reporter_id"] == actor["person_id"]
            ):
                raise WorkManagementError("Ticket is not authorized.", 403)
            if row["type"] == "WORK_ORDER":
                cur.execute(
                    """
                    SELECT w.stage_id, w.work_area_id, w.notes,
                           w.problem, w.source_form_name, w.completion_notes,
                           w.display_test_session_id
                    FROM ops.work_order w WHERE w.work_order_id = %s
                    """,
                    (row["wo_id"],),
                )
                detail = dict(cur.fetchone() or {})
                context = {}
            else:
                cur.execute(
                    """
                    SELECT i.stage_id, i.work_area_id, i.problem_raw, i.notes_raw,
                           i.source_form_name, i.source_payload
                    FROM stage.work_order_intake i WHERE i.intake_id = %s
                    """,
                    (row["in_id"],),
                )
                raw = dict(cur.fetchone() or {})
                # Whitelist context. Do not return raw reporter contact or
                # internal Directus/Setup audit identity via this read endpoint.
                payload = raw.pop("source_payload", None) or {}
                context_keys = (
                    "season_year", "setup_session_task_id", "setup_task_id",
                    "task_name", "stage_id", "stage_name", "stage_key",
                    "lor_scene_id", "scene_name", "setup_work_day_task_id",
                    "work_date", "shift_code", "crew_code", "procedure_context",
                )
                context = {k: payload[k] for k in context_keys if k in payload}
                if "procedure_context" in context:
                    proc = context["procedure_context"]
                    if not isinstance(proc, dict):
                        context["procedure_context"] = {}
                    else:
                        context["procedure_context"] = {
                            k: proc.get(k) for k in ("status", "scope_type", "summary", "documents")
                        }
                detail = raw
            row["detail"] = detail
            row["setup_context"] = context
            return row

    def related_information(
        self, *, actor: dict[str, Any], ticket_key: str,
    ) -> dict[str, Any]:
        """Discover existing sources without creating task links or new inventory."""
        record = self.ticket(actor=actor, ticket_key=ticket_key)
        ctx = record["setup_context"]
        stage_id = ctx.get("stage_id") or record["detail"].get("stage_id")
        task_id = ctx.get("setup_task_id")
        if not isinstance(stage_id, int) or stage_id < 1:
            return {"stage_id": None, "groups": [], "notice": "No Stage recorded."}
        if not isinstance(task_id, int) or task_id < 1:
            task_id = None

        entries: dict[tuple[str, int], dict[str, Any]] = {}

        def register(kind: str, key: int, label: str, relation: str, source: str,
                     *, url: str | None = None) -> None:
            identity = (kind, int(key))
            found = entries.get(identity)
            entry = {
                "kind": kind, "id": int(key), "name": str(label),
                "relation": relation, "source": source, "url": url,
            }
            if found is None or (relation == "DIRECT_TASK" and found["relation"] != "DIRECT_TASK"):
                entries[identity] = entry

        with self.connect() as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT DISTINCT c.container_id, c.description, c.container_type_id,
                       tc.setup_task_id, tc.relationship_type
                FROM ref.setup_task_container_support tc
                JOIN ref.setup_task t ON t.setup_task_id = tc.setup_task_id
                JOIN ref.container c ON c.container_id = tc.container_id
                WHERE t.stage_id = %s OR (%s IS NOT NULL AND tc.setup_task_id = %s)
                ORDER BY c.container_id, tc.setup_task_id
                LIMIT 180
                """,
                (stage_id, task_id, task_id),
            )
            for c in cur.fetchall():
                cid = int(c["container_id"])
                is_kit = int(c["container_type_id"]) == 2
                kind = "Kit Box" if is_kit else "Container"
                direct = task_id is not None and c["setup_task_id"] == task_id
                url = (f"/setup/kit-inventory/{cid}" if is_kit
                       else f"/scan/CONT/{cid}")
                register(
                    kind, cid, f"C{cid:03d} · {c['description'] or kind}",
                    "DIRECT_TASK" if direct else "STAGE_RELATED",
                    str(c["relationship_type"]), url=url,
                )

            cur.execute(
                """
                SELECT d.display_id, d.display_name, d.container_id,
                       td.setup_task_id AS direct_task_id
                FROM ref.display d
                LEFT JOIN ref.setup_task_display td
                  ON td.display_id = d.display_id AND td.setup_task_id = %s
                WHERE d.stage_id = %s OR EXISTS (
                    SELECT 1 FROM ref.lor_scene_display lsd
                    JOIN ref.lor_scene ls ON ls.lor_scene_id = lsd.lor_scene_id
                    WHERE lsd.display_id = d.display_id AND ls.stage_id = %s
                )
                ORDER BY d.display_name, d.display_id
                LIMIT 160
                """,
                (task_id, stage_id, stage_id),
            )
            for display in cur.fetchall():
                did = int(display["display_id"])
                register(
                    "Display", did,
                    display["display_name"] or f"Display #{did}",
                    "DIRECT_TASK" if display["direct_task_id"] is not None else "STAGE_RELATED",
                    "LOR/Stage or current Display reference",
                    url=f"/scan/DISP/{did}",
                )

            cur.execute(
                """
                SELECT m.setup_extra_material_id, m.material_name,
                       tm.setup_task_id
                FROM ref.setup_task_extra_material tm
                JOIN ref.setup_extra_material m
                  ON m.setup_extra_material_id = tm.setup_extra_material_id
                JOIN ref.setup_task t ON t.setup_task_id = tm.setup_task_id
                WHERE tm.active_flag AND t.stage_id = %s
                ORDER BY m.material_name, m.setup_extra_material_id
                LIMIT 120
                """,
                (stage_id,),
            )
            for mat in cur.fetchall():
                mid = int(mat["setup_extra_material_id"])
                register(
                    "Extra Material", mid, mat["material_name"],
                    "DIRECT_TASK" if task_id == mat["setup_task_id"] else "STAGE_RELATED",
                    "Setup task Extra Materials",
                )

        original_procedures = []
        proc = ctx.get("procedure_context")
        if isinstance(proc, dict):
            names = [
                item.get("name", "").strip()
                for item in (proc.get("documents") or [])
                if isinstance(item, dict) and isinstance(item.get("name"), str)
            ]
            for name in sorted(set(n for n in names if n)):
                # Procedure documents have no proven stable procedure_id.
                # Never fabricate IDs 1,2,... merely to render related UI.
                original_procedures.append({
                    "kind": "Procedure", "id": None, "name": name,
                    "relation": "SUBMITTED_CONTEXT",
                    "source": "Original Setup Procedure", "url": None,
                })

        order = {"DIRECT_TASK": 0, "SUBMITTED_CONTEXT": 1, "STAGE_RELATED": 2}
        values = sorted(
            [*entries.values(), *original_procedures],
            key=lambda entry: (
                order.get(entry["relation"], 3), entry["kind"], entry["name"].lower()
            ),
        )
        return {
            "stage_id": stage_id,
            "groups": values,
            "notice": "Stage candidates are not confirmed task assignments.",
        }
