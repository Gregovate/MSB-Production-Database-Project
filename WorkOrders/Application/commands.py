"""#419 V0.3: governed, clone-only ticket save commands; no Production or mail.

These commands intentionally mutate existing Work Order and assignment rows ONLY
on a privately networked disposable PostgreSQL clone. Feedback activity and
notification attempts use a clone-only acceptance ledger, not a new ticket DB.
No Directus Flows are invoked, and NO SMTP/email API exists here.
"""
from __future__ import annotations

import hmac
import os
import re
import uuid
from contextlib import contextmanager
from typing import Any, Iterator

import psycopg2
from psycopg2.extras import RealDictCursor, Json

from repository import WorkManagementError

TICKET_KEY = re.compile(r"^(WO|INTAKE)-([1-9][0-9]{0,12})$")
EVENT_KINDS = frozenset(("create", "assign", "progress", "complete", "link_setup", "promote",
                         "correction_owner", "clarify", "reply", "resolve"))


def numeric(value: Any, label: str) -> int:
    if isinstance(value, bool) or not str(value).isdecimal() or int(value) < 1:
        raise WorkManagementError(f"Valid {label} required.")
    return int(value)


def substantive(value: Any, label: str, minimum: int = 10) -> str:
    if not isinstance(value, str) or not minimum <= len(value.strip()) <= 5000:
        raise WorkManagementError(f"{label} must contain {minimum} to 5000 characters.")
    return value.strip()


def people(value: Any, required: bool = True) -> list[int]:
    if not isinstance(value, list) or len(value) > 50:
        raise WorkManagementError("Invalid volunteer selection.")
    result = [numeric(item, "Person ID") for item in value]
    if len(set(result)) != len(result) or (required and not result):
        raise WorkManagementError("Select unique existing volunteers.")
    return sorted(result)


class CloneCommands:
    def __init__(self) -> None:
        self.dsn = os.environ.get("WORK_MGMT_DATABASE_DSN", "").strip()
        self.token = os.environ.get("WORK_MGMT_CLONE_WRITE_TOKEN", "").strip()
        self.ip = os.environ.get("WORK_MGMT_CLONE_IP", "").strip()
        if (os.environ.get("WORK_MGMT_PREVIEW_MODE") != "disposable"
                or not self.dsn or not re.fullmatch(r"[a-f0-9]{48}", self.token)
                or not self.ip):
            raise WorkManagementError("Disposable write boundary unavailable.", 503)

    @contextmanager
    def transaction(self, actor: dict[str, Any]) -> Iterator[Any]:
        """Connection cannot commit until clone marker and actor are proven."""
        conn = psycopg2.connect(self.dsn)
        try:
            conn.set_session(readonly=False, autocommit=False)
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                # Docker inspect returns a bare IP (e.g. 172.18.0.5).
                # PostgreSQL inet::text includes its mask (172.18.0.5/32),
                # so compare the host address, without weakening the exact
                # database-name, clone-token or resolved-actor gates.
                cur.execute(
                    "SELECT current_database() AS name, "
                    "host(inet_server_addr()) AS ip")
                found = cur.fetchone()
                if (found["name"] != "msb_wo419_preview"
                        or found["ip"] != self.ip):
                    raise WorkManagementError("Write target is not the verified clone.", 503)
                cur.execute(
                    "SELECT token FROM wo419_preview.authorization WHERE singleton=true")
                authorization = cur.fetchone()
                if not authorization or not hmac.compare_digest(
                    str(authorization["token"]), self.token
                ):
                    raise WorkManagementError("Clone write authorization missing.", 503)
                cur.execute(
                    "SELECT directus_user_id::text AS uuid FROM ref.person "
                    "WHERE person_id=%s AND active_flag AND directus_user_id IS NOT NULL",
                    (numeric(actor["person_id"], "actor"),))
                identity = cur.fetchone()
                if not identity or not identity["uuid"]:
                    raise WorkManagementError("Verified linked Person required.", 403)
                cur.execute("SELECT set_config('app.directus_user_uuid', %s, true)",
                            (identity["uuid"],))
                yield cur
                conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    @staticmethod
    def present_columns(cur: Any, table: str) -> set[str]:
        assert table in ("work_order", "work_order_assignment")
        cur.execute(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_schema='ops' AND table_name=%s", (table,))
        return {row["column_name"] for row in cur.fetchall()}

    @staticmethod
    def ensure_people(cur: Any, ids: list[int]) -> None:
        cur.execute("SELECT person_id FROM ref.person WHERE active_flag "
                    "AND person_id = ANY(%s)", (ids,))
        if {int(r["person_id"]) for r in cur.fetchall()} != set(ids):
            raise WorkManagementError("Some volunteers are not active People.", 400)

    @staticmethod
    def persist_event(cur: Any, request_key: uuid.UUID, ticket: str, kind: str,
                      actor: dict[str, Any], note: str = "",
                      target: int | None = None, details: dict | None = None) -> int:
        cur.execute(
            "INSERT INTO wo419_preview.activity "
            "(request_key,ticket_key,event_kind,actor_person_id,target_person_id,note,details) "
            "VALUES (%s,%s,%s,%s,%s,%s,%s) RETURNING activity_id",
            (str(request_key), ticket, kind, actor["person_id"],
             target, note, Json(details or {})))
        return int(cur.fetchone()["activity_id"])

    @staticmethod
    def capture(cur: Any, activity: int, ticket: str, kind: str, recipient: int | None) -> None:
        if recipient is not None:
            cur.execute("SELECT email FROM ref.person WHERE person_id=%s", (recipient,))
            record = cur.fetchone()
            email = (record["email"] if record else None) or None
        else:
            email = None
        cur.execute(
            "INSERT INTO wo419_preview.outbox "
            "(event_key,ticket_key,activity_id,recipient_person_id,recipient_email,delivery_status) "
            "VALUES (%s,%s,%s,%s,%s,%s) ON CONFLICT(event_key) DO NOTHING",
            (f"{ticket}:{kind}:{activity}:{recipient}", ticket, activity, recipient,
             email, "NO_SEND_CAPTURED" if email else "NO_REPORTER_EMAIL"))

    @staticmethod
    def new_work_order(cur: Any, actor: dict[str, Any], body: dict,
                       source: dict | None = None) -> int:
        problem = substantive(body.get("problem"), "Work description")
        task_type = numeric(body.get("task_type_id"), "Task Type")
        urgency = numeric(body.get("urgency") or 3, "urgency")
        if urgency not in range(1, 6):
            raise WorkManagementError("Urgency must be 1 through 5.")
        stage = body.get("stage_id")
        area = body.get("work_area_id")
        if bool(stage) == bool(area):
            raise WorkManagementError("Choose one Stage OR Work Area.")
        stage = numeric(stage, "Stage") if stage else None
        area = numeric(area, "Work Area") if area else None
        year = body.get("target_year")
        if urgency == 5:
            if year in (None, ""):
                raise WorkManagementError("Planning Work Orders require a target year.")
            year = numeric(year, "target year")
            if year < 2020 or year > 2100:
                raise WorkManagementError("Invalid target year.")
        elif year not in (None, ""):
            raise WorkManagementError("Target year applies only to Planning (urgency 5).")
        else:
            year = None
        if stage:
            cur.execute("SELECT 1 FROM ref.stage WHERE stage_id=%s", (stage,))
        else:
            cur.execute("SELECT 1 FROM ref.work_area WHERE work_area_id=%s", (area,))
        if cur.fetchone() is None:
            raise WorkManagementError("Location is not in current reference catalog.")
        cur.execute("SELECT 1 FROM ref.task_type WHERE task_type_id=%s AND active_flag",
                    (task_type,))
        if cur.fetchone() is None:
            raise WorkManagementError("Task Type is not active.")
        available = CloneCommands.present_columns(cur, "work_order")
        fields = {
            "problem": problem, "task_type_id": task_type, "urgency_id": urgency,
            "target_year": year, "stage_id": stage, "work_area_id": area,
            "created_by_person_id": actor["person_id"],
            "updated_by_person_id": actor["person_id"],
        }
        if "repair_complete" in available:
            fields["repair_complete"] = False
        if source:
            fields["source_intake_id"] = source["intake_id"]
            if "submitted_by_person_id" in available:
                fields["submitted_by_person_id"] = source.get("submitter_person_id")
            if "source_system" in available:
                fields["source_system"] = source.get("source_system") or "WORK_MANAGEMENT"
            if "source_form_name" in available:
                fields["source_form_name"] = source.get("source_form_name")
            if "notes" in available:
                fields["notes"] = source.get("notes_raw")
        else:
            if "source_system" in available:
                fields["source_system"] = "WORK_MANAGEMENT_INTERNAL"
            if "submitted_by_person_id" in available:
                fields["submitted_by_person_id"] = actor["person_id"]
            if "notes" in available:
                fields["notes"] = body.get("notes") or None
        if not set(fields).issubset(available) or not {"urgency_id", "date_completed"}.issubset(available):
            raise WorkManagementError("Current Work Order schema differs; HOLD for reconciliation.", 503)
        from psycopg2 import sql
        stmt = sql.SQL("INSERT INTO ops.work_order ({}) VALUES ({}) RETURNING work_order_id").format(
            sql.SQL(",").join(sql.Identifier(k) for k in fields),
            sql.SQL(",").join(sql.Placeholder() for _ in fields))
        cur.execute(stmt, tuple(fields.values()))
        return int(cur.fetchone()["work_order_id"])

    @staticmethod
    def create_season_only_work_order_gate(
        cur: Any, actor: dict[str, Any], work_order_id: int, body: dict
    ) -> int:
        """One transaction: existing Work Order plus governing Setup annual gate.

        The released Setup Board computes effective completion directly from
        linked WO date_completed; never invent duplicate Report Work or a
        reusable ref.setup_task definition.
        """
        if not actor["can_manage"]:
            raise WorkManagementError("Only a Manager may create seasonal Setup work.", 403)
        stage_id = body.get("stage_id")
        if not stage_id or body.get("work_area_id"):
            raise WorkManagementError("Seasonal Setup integration needs a Park Stage.")
        stage_id = numeric(stage_id, "Setup Stage")
        season_year = numeric(body.get("setup_season_year"), "Setup season")
        # This is a read-only precheck. PostgreSQL SELECT ... FOR SHARE
        # requires additional table privileges beyond the clone reader's
        # deliberately narrow SELECT grant; don't widen ops.setup_session
        # DML grants just to read it. The governing SECURITY DEFINER
        # ops.create_setup_season_task command checks open season/identity
        # itself, inside this same transaction.
        cur.execute(
            "SELECT setup_session_id FROM ops.setup_session "
            "WHERE season_year=%s AND session_status IN ('PLANNING','ACTIVE')",
            (season_year,),
        )
        if cur.fetchone() is None:
            raise WorkManagementError(
                "Selected Setup season is not open for new annual tasks.", 409
            )
        cur.execute(
            "SELECT 1 FROM ops.setup_session_task "
            "WHERE linked_work_order_id=%s AND setup_session_id IN "
            "(SELECT setup_session_id FROM ops.setup_session WHERE season_year=%s) "
            "LIMIT 1", (work_order_id, season_year),
        )
        if cur.fetchone() is not None:
            raise WorkManagementError("Work Order already has an annual Setup task.", 409)
        cur.execute(
            "SELECT email FROM ref.person WHERE person_id=%s "
            "AND active_flag AND directus_user_id IS NOT NULL",
            (actor["person_id"],),
        )
        current_person = cur.fetchone()
        if not current_person or not current_person["email"]:
            raise WorkManagementError("A verified Manager email is required.", 403)
        title = body.get("setup_task_name")
        if title is None or not str(title).strip():
            title = str(body.get("problem") or "").splitlines()[0][:160]
        title = substantive(title, "Seasonal Setup task name", minimum=5)
        # Existing SECURITY DEFINER Setup command enforces Manager authority,
        # Stage/Scene ownership and the real open seasonal Setup Session.
        # GATE + linked_work_order_gate avoids duplicate Crew Report Work:
        # Setup board marks effective_complete when WO.date_completed is set.
        cur.execute(
            """
            SELECT setup_session_task_id
            FROM ops.create_setup_season_task(
                %s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s
            )
            """,
            (
                current_person["email"], season_year, title, stage_id,
                None, "GATE", None, None, None, None, None,
                "Complete and verify linked Work Order",
                "Awaiting repair Work Order completion", None,
                work_order_id, True,
                "Season-only Work Order repair; native WO owns completion notes.",
            ),
        )
        created = cur.fetchone()
        if not created:
            raise WorkManagementError("Linked Setup annual task was not created.", 503)
        return int(created["setup_session_task_id"])

    @staticmethod
    def reassign(cur: Any, wo: int, selected: list[int]) -> tuple[list[int], list[int]]:
        """Preserve prior assignment rows; do not reuse arbitrary historical roles."""
        CloneCommands.ensure_people(cur, selected)
        cur.execute(
            "SELECT work_order_assignment_id,person_id,assignment_role "
            "FROM ops.work_order_assignment WHERE work_order_id=%s "
            "AND active_flag ORDER BY work_order_assignment_id FOR UPDATE", (wo,))
        existing = cur.fetchall()
        old = {int(row["person_id"]) for row in existing}
        removed = sorted(old - set(selected))
        added = sorted(set(selected) - old)
        if removed:
            cur.execute(
                "UPDATE ops.work_order_assignment SET active_flag=false, "
                "unassigned_at=now() WHERE work_order_id=%s AND active_flag "
                "AND person_id = ANY(%s)", (wo, removed))
        if added:
            cols = CloneCommands.present_columns(cur, "work_order_assignment")
            # Role field comes from an actual existing assignment, or a
            # reviewed column default. Never make up a live role enum value.
            for who in added:
                fields = {"work_order_id": wo, "person_id": who,
                          "active_flag": True}
                if "assigned_at" in cols:
                    fields["assigned_at"] = None  # use now() below
                if "created_by_person_id" in cols:
                    # shared audit trigger uses app.directus_user_uuid
                    pass
                from psycopg2 import sql
                if "assigned_at" in fields:
                    del fields["assigned_at"]
                q = sql.SQL("INSERT INTO ops.work_order_assignment ({}) VALUES ({})").format(
                    sql.SQL(",").join(sql.Identifier(k) for k in fields),
                    sql.SQL(",").join(sql.Placeholder() for _ in fields))
                cur.execute(q, tuple(fields.values()))
        return added, removed

    def perform(self, actor: dict[str, Any], action: str, ticket: str | None,
                body: dict) -> dict:
        if action not in EVENT_KINDS or not isinstance(body, dict):
            raise WorkManagementError("Unknown or invalid ticket command.")
        if ticket:
            match = TICKET_KEY.fullmatch(ticket)
            if not match:
                raise WorkManagementError("Invalid ticket identity.")
            kind, number = match.group(1), int(match.group(2))
        else:
            kind, number = None, None
        if action == "create":
            if ticket is not None:
                raise WorkManagementError("Internal Create cannot reuse an existing ticket.")
        elif ticket is None:
            raise WorkManagementError("Select the ticket being changed.")
        if action == "create" and not actor["can_manage"]:
            raise WorkManagementError(
                "Only Managers may create Work Orders directly. "
                "Submit a Work Order Request through the existing Intake form.", 403)
        if action in ("assign", "link_setup", "promote", "correction_owner", "clarify", "resolve") \
                and not actor["can_manage"]:
            raise WorkManagementError("Manager action is not authorized.", 403)
        # Manager triage/promote owns assignment. Intake requests do not
        # independently assign volunteers or create annual Setup tasks.
        setup_mode = body.get("setup_mode", "none")
        if setup_mode not in ("none", "request", "create"):
            raise WorkManagementError("Unknown seasonal Setup option.")
        if action not in ("create", "promote", "link_setup") and setup_mode != "none":
            raise WorkManagementError("Setup linkage applies to creation/promotion only.")
        if setup_mode == "create" and not actor["can_manage"]:
            raise WorkManagementError("Manager approval required for seasonal Setup.", 403)
        if action == "link_setup" and setup_mode != "create":
            raise WorkManagementError("Explicit Manager Setup link confirmation required.")
        if setup_mode != "none" and not body.get("stage_id"):
            raise WorkManagementError("A Park Stage is required for seasonal Setup.")

        if action in ("assign", "progress", "complete", "link_setup") and kind != "WO":
            raise WorkManagementError("This action requires an active Work Order.")
        if action in ("promote", "correction_owner", "clarify", "reply", "resolve") and kind != "INTAKE":
            raise WorkManagementError("This action requires original Intake.")
        try:
            request_key = uuid.UUID(str(body.get("request_key")))
            if request_key.version != 4:
                raise ValueError("Version 4 required")
        except (ValueError, TypeError, AttributeError):
            raise WorkManagementError("New client command key required.")
        selected = people(body.get("person_ids", []), required=(action != "create")) \
            if action in ("create", "assign", "promote", "correction_owner") else []
        with self.transaction(actor) as cur:
            cur.execute(
                "SELECT ticket_key,event_kind,details FROM wo419_preview.activity WHERE request_key=%s",
                (str(request_key),))
            prior = cur.fetchone()
            if prior:
                if prior["event_kind"] != action:
                    raise WorkManagementError("Command key already used for another action.", 409)
                return {
                    "ticket": prior["ticket_key"], "saved": True,
                    "repeat": True, "notifications": "NO_SEND",
                    "linked_setup_session_task_id": (
                        prior["details"].get("linked_setup_session_task_id")
                        if isinstance(prior["details"], dict) else None
                    ),
                }
            if kind == "WO":
                cur.execute(
                    "SELECT work_order_id,date_completed,display_test_session_id, "
                    "submitted_by_person_id,source_intake_id,stage_id,work_area_id,problem "
                    "FROM ops.work_order WHERE work_order_id=%s FOR UPDATE", (number,))
                work_order = cur.fetchone()
                if not work_order:
                    raise WorkManagementError("Work Order not found.", 404)
            else:
                work_order = None
            if kind == "INTAKE":
                cur.execute(
                    "SELECT intake_id,problem_raw,notes_raw,stage_id,work_area_id,urgency_id,"
                    "task_type_id,target_year,source_system,source_form_name,"
                    "submitter_person_id FROM stage.work_order_intake "
                    "WHERE intake_id=%s FOR UPDATE", (number,))
                intake = cur.fetchone()
                if not intake:
                    raise WorkManagementError("Intake not found.", 404)
            else:
                intake = None

            if action == "create" or action == "promote":
                if action == "promote":
                    cur.execute("SELECT work_order_id FROM ops.work_order "
                                "WHERE source_intake_id=%s LIMIT 1", (number,))
                    if cur.fetchone():
                        raise WorkManagementError("Intake is already promoted.", 409)
                    cur.execute(
                        "SELECT 1 FROM wo419_preview.activity "
                        "WHERE ticket_key=%s AND event_kind='resolve' LIMIT 1", (ticket,))
                    if cur.fetchone():
                        raise WorkManagementError(
                            "Disposed Intake cannot be promoted into a Work Order.", 409)
                wo = self.new_work_order(cur, actor, body, intake)
                # Manager may create unassigned Work Orders; new Intake requests
                # receive no assignment until the Manager triages/promotes.
                added, _ = self.reassign(cur, wo, selected) if selected else ([], [])
                linked_setup_task_id = None
                if setup_mode == "create":
                    linked_setup_task_id = self.create_season_only_work_order_gate(
                        cur, actor, wo, body
                    )
                result_ticket = f"WO-{wo}"
                note = "Work Order created" if action == "create" else "Intake promoted and assigned"
                if setup_mode == "request":
                    note += " · Seasonal Setup review requested"
                elif linked_setup_task_id is not None:
                    note += f" · Linked season-only Setup task #{linked_setup_task_id}"
                event = self.persist_event(
                    cur, request_key, result_ticket, action, actor, note,
                    details={
                        "source_intake": number, "assignee_ids": selected,
                        "setup_mode": setup_mode,
                        "linked_setup_session_task_id": linked_setup_task_id,
                    },
                )
                for who in added:
                    self.capture(cur, event, result_ticket, "assignment", who)
                if action == "promote":
                    # Retain Intake row exactly as received. Only clone activity
                    # records promotion: never run destructive triage trigger.
                    self.persist_event(cur, uuid.uuid4(), ticket, "promoted_source",
                                       actor, "Promoted to " + result_ticket,
                                       details={"work_order_id": wo})
            elif action == "link_setup":
                # Work Order already exists (often created by Crew). Reuse
                # that exact permanent identity; no duplicate WO/Intake.
                # Ignore client-supplied Stage/name in favor of the native WO.
                linked_setup_task_id = self.create_season_only_work_order_gate(
                    cur, actor, number, {
                        "stage_id": work_order["stage_id"],
                        "work_area_id": work_order["work_area_id"],
                        "problem": work_order["problem"],
                        "setup_season_year": body.get("setup_season_year"),
                        "setup_task_name": body.get("setup_task_name"),
                    }
                )
                result_ticket = ticket
                event = self.persist_event(
                    cur, request_key, ticket, action, actor,
                    f"Manager linked existing repair to season-only Setup task #{linked_setup_task_id}",
                    details={"linked_setup_session_task_id": linked_setup_task_id,
                             "setup_season_year": int(body["setup_season_year"])},
                )
            elif action == "assign":
                if work_order["date_completed"] is not None:
                    raise WorkManagementError("Completed work cannot be reassigned.", 409)
                added, removed = self.reassign(cur, number, selected)
                result_ticket = ticket
                event = self.persist_event(cur, request_key, ticket, action, actor,
                                           "Current assignment changed",
                                           details={"added": added, "removed": removed})
                for who in added:
                    self.capture(cur, event, ticket, "assignment", who)
            elif action in ("progress", "complete"):
                if work_order["date_completed"] is not None:
                    raise WorkManagementError("Already recorded complete.", 409)
                if not actor["can_manage"]:
                    cur.execute(
                        "SELECT 1 FROM ops.work_order_assignment "
                        "WHERE work_order_id=%s AND person_id=%s AND active_flag",
                        (number, actor["person_id"]))
                    if cur.fetchone() is None:
                        raise WorkManagementError("Only assignees or Manager may complete.", 403)
                result_ticket = ticket
                if action == "progress":
                    progress = substantive(body.get("progress_note"), "Work progress note")
                    cur.execute(
                        "UPDATE ops.work_order SET notes=concat_ws(E'\\n', "
                        "NULLIF(btrim(notes), ''), "
                        "'[' || to_char(clock_timestamp() AT TIME ZONE 'UTC', "
                        "'YYYY-MM-DD HH24:MI') || ' UTC | Person #' || "
                        "%s::text || '] ' || %s) "
                        "WHERE work_order_id=%s AND date_completed IS NULL",
                        (actor["person_id"], progress, number))
                    if cur.rowcount != 1:
                        raise WorkManagementError("Work note was not recorded.", 409)
                    event = self.persist_event(
                        cur, request_key, ticket, action, actor, progress)
                    # Progress alone never marks repair complete, releases a
                    # Testing gate or sends the reporter a closure email.
                else:
                    completed_note = substantive(body.get("completion_notes"), "Completion notes")
                    cur.execute(
                        "UPDATE ops.work_order SET completion_notes=%s, "
                        "completed_by_person_id=%s, repair_complete=true,"
                        "date_completed=now() WHERE work_order_id=%s AND date_completed IS NULL",
                        (completed_note, actor["person_id"], number))
                    if cur.rowcount != 1:
                        raise WorkManagementError("Completion did not update native Work Order.", 409)
                    event = self.persist_event(cur, request_key, ticket, action,
                                               actor, completed_note)
                    # Capture only genuine human-reporter outcome, never a guessed
                    # Testing-origin reporter. No message is actually dispatched.
                    if work_order["display_test_session_id"] is None:
                        self.capture(cur, event, ticket, "completion",
                                     work_order["submitted_by_person_id"])
                    # Existing database triggers own Testing completion feedback;
                    # no invented Testing message or new testing record.
            else:
                # Correction decisions are additional attributed activity on
                # retained Intake, never a fake Work Order.
                result_ticket = ticket
                if action == "correction_owner" and \
                        intake["source_form_name"] != "SETUP_CORRECTION":
                    raise WorkManagementError("Correction owner applies to Setup feedback.")
                if action in ("clarify", "resolve"):
                    cur.execute("SELECT 1 FROM ops.work_order WHERE source_intake_id=%s", (number,))
                    if cur.fetchone():
                        raise WorkManagementError("Linked Work Order owns this outcome.", 409)
                if action == "correction_owner":
                    if len(selected) != 1:
                        raise WorkManagementError("Choose one responsible correction owner.")
                    self.ensure_people(cur, selected)
                    event = self.persist_event(cur, request_key, ticket, action, actor,
                                               "Correction owner assigned", selected[0])
                elif action == "clarify":
                    note = substantive(body.get("response"), "Clarification question")
                    recipient = intake["submitter_person_id"]
                    event = self.persist_event(
                        cur, request_key, ticket, action, actor, note,
                        details={"communication": "MISSING_RECIPIENT"} if recipient is None else {})
                    self.capture(cur, event, ticket, "clarification",
                                 int(recipient) if recipient is not None else None)
                elif action == "reply":
                    if intake["submitter_person_id"] != actor["person_id"]:
                        raise WorkManagementError("Only original reporter can reply.", 403)
                    note = substantive(body.get("response"), "Reporter reply")
                    event = self.persist_event(cur, request_key, ticket, action, actor, note)
                elif action == "resolve":
                    disposition = str(body.get("disposition") or "")
                    if disposition not in ("resolved", "deferred", "rejected", "duplicate"):
                        raise WorkManagementError("Choose a governed correction disposition.")
                    note = substantive(body.get("response"), "Resolution reason")
                    cur.execute(
                        "SELECT 1 FROM wo419_preview.activity WHERE ticket_key=%s "
                        "AND event_kind='resolve' LIMIT 1", (ticket,))
                    if cur.fetchone():
                        raise WorkManagementError("Correction already has final disposition.", 409)
                    event = self.persist_event(cur, request_key, ticket, action, actor,
                                               note, details={"disposition": disposition})
                    self.capture(cur, event, ticket, "resolution",
                                 intake["submitter_person_id"])
                else:
                    raise WorkManagementError("Unsupported correction command.")
            return {"ticket": result_ticket, "saved": True, "repeat": False,
                    "notifications": (
                        "MISSING_RECIPIENT" if action in ("clarify", "resolve")
                        and intake is not None and intake["submitter_person_id"] is None
                        else "NO_SEND"
                    ), "activity_id": event,
                    "linked_setup_session_task_id": (
                        linked_setup_task_id if action in ("create", "promote", "link_setup") else None
                    )}

    def activity(self, actor: dict[str, Any], ticket: str) -> list[dict]:
        if not TICKET_KEY.fullmatch(ticket):
            raise WorkManagementError("Invalid ticket.")
        with self.transaction(actor) as cur:
            if ticket.startswith("INTAKE-") and not actor["can_manage"]:
                cur.execute(
                    "SELECT submitter_person_id FROM stage.work_order_intake "
                    "WHERE intake_id=%s", (int(ticket.split("-")[1]),))
                item = cur.fetchone()
                if not item or item["submitter_person_id"] != actor["person_id"]:
                    raise WorkManagementError("Ticket history not authorized.", 403)
            cur.execute(
                "SELECT event_kind,actor_person_id,target_person_id,note,details,created_at "
                "FROM wo419_preview.activity WHERE ticket_key=%s "
                "ORDER BY activity_id", (ticket,))
            return [dict(row) for row in cur.fetchall()]
