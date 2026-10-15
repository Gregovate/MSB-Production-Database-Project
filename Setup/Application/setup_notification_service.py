"""#205 Setup notification planning and Directus *event-flow* handoff.

No SMTP stack, no Work Order events, no publicly triggerable webhook.
Directus items.create on a dedicated, default-deny outbox collection is the
only transport. QUEUED means accepted by the Items API, *not* delivered.
"""
from __future__ import annotations

from collections import defaultdict
from datetime import date, datetime, timedelta
import json
import os
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import ProxyHandler, Request, build_opener
from zoneinfo import ZoneInfo

import psycopg2
from psycopg2.extras import RealDictCursor

from setup_scheduling_board_repository import SetupSchedulingBoardRepository

CHICAGO = ZoneInfo("America/Chicago")
DIRECTUS_OPENER = build_opener(ProxyHandler({}))
SETUP_BASE = "https://my.sheboyganlights.org/setup/"
SOP_URL = "https://github.com/Gregovate/MSB-Production-Database-Project/blob/main/Docs/02_Production_Database/01_System_Architecture/12_Setup_and_Deployment/operatorSOP/Perform_and_Report_Setup_Work.md"


class SetupNotificationError(RuntimeError):
    """A notification has not been demonstrated safe to queue."""


def local_today() -> date:
    return datetime.now(CHICAGO).date()


def organizational_email(value: Any) -> str | None:
    email = str(value or "").strip().lower()
    if (
        email.endswith("@sheboyganlights.org")
        and email.count("@") == 1
        and 3 <= len(email) <= 254
        and not any(c.isspace() for c in email)
    ):
        return email
    return None


def eligible_people(dsn: str) -> list[dict[str, Any]]:
    """Dynamic People+Directus+capability eligibility, never Person flag only.

    This is intentionally executed on EACH dispatch and self-send, not cached.
    A Captain qualifies only through current assignment identity and Setup read
    capability; a Manager qualifies only via can_manage_setup.
    """
    sql = """
      SELECT p.person_id, lower(p.email) AS email,
             coalesce(nullif(btrim(p.preferred_name),''),
                nullif(btrim(concat_ws(' ',p.first_name,p.last_name)),''),
                lower(p.email)) AS display_name,
             caps.can_manage_setup, caps.can_read_setup
      FROM ref.person p
      JOIN public.directus_users u ON u.id=p.directus_user_id
      JOIN LATERAL ref.setup_browser_capabilities(lower(p.email)) caps ON true
      WHERE p.active_flag IS TRUE AND u.status='active'
        AND u.provider='google'
        AND lower(btrim(u.email))=lower(btrim(p.email))
        AND lower(btrim(u.external_identifier))=lower(btrim(p.email))
        AND lower(btrim(p.email)) LIKE '%@sheboyganlights.org'
        AND (caps.can_manage_setup OR caps.can_read_setup)
      ORDER BY p.person_id
    """
    with psycopg2.connect(dsn) as conn, conn.cursor(cursor_factory=RealDictCursor) as cur:
        conn.set_session(readonly=True)
        cur.execute(sql)
        rows = [dict(row) for row in cur.fetchall()]
    result, seen = [], set()
    for row in rows:
        email = organizational_email(row.get("email"))
        if not email or email in seen:
            continue
        seen.add(email)
        row["email"] = email
        result.append(row)
    return result


def covered_assignments(dsn: str, today: date) -> set[tuple[int,int]]:
    """Get only assignment/recipient IDs already covered by a notice today."""
    with psycopg2.connect(dsn) as conn, conn.cursor() as cur:
        conn.set_session(readonly=True)
        cur.execute(
            "SELECT recipient_person_id,assignment_id "
            "FROM ops.setup_notice_covered_assignments(%s::date)",
            (today.isoformat(),),
        )
        return {(int(p),int(a)) for p,a in cur.fetchall()}


def _date_of(a: dict, days: dict) -> str | None:
    d = days.get(int(a.get("setup_work_day_id") or 0), {})
    return a.get("work_date") or d.get("work_date")


def notification_context(board: dict, today: date) -> dict:
    """One shared historical-occurrence classification; no Captain totals leak."""
    by_task = {int(t["setup_session_task_id"]): t for t in board.get("tasks", [])}
    days = {int(d["setup_work_day_id"]): d for d in board.get("work_days", [])}
    crews = {int(c["setup_work_day_crew_id"]): c for c in board.get("crews", [])}
    overdue = []
    imminent = []
    captain_tbd = []
    next_week = (today + timedelta(days=7)).isoformat()
    for a in board.get("assignments", []):
        work_date = _date_of(a, days)
        day = days.get(int(a.get("setup_work_day_id") or 0), {})
        if not work_date or str(day.get("day_status") or a.get("day_status") or "").upper() == "CANCELLED":
            continue
        task = by_task.get(int(a.get("setup_session_task_id") or 0))
        if task is None:
            continue
        crew = crews.get(int(a.get("setup_work_day_crew_id") or 0), {})
        row = {
            "assignment_id": int(a["setup_work_day_task_id"]),
            "task_id": int(task["setup_session_task_id"]),
            "task_name": task.get("task_name") or "Unnamed task",
            "stage": task.get("stage_name") or task.get("stage_key") or "Site-wide",
            "scene": task.get("scene_name"),
            "work_date": work_date,
            "day_number": day.get("setup_day_number") or a.get("setup_day_number"),
            "shift": a.get("shift_code") or "ALL_DAY",
            "crew": crew.get("crew_code") or a.get("crew_lane") or "TBD",
            "captain_person_id": crew.get("captain_person_id"),
            "captain": crew.get("captain_display_name") or "Captain TBD",
            "percent_complete": task.get("percent_complete") or 0,
            "readiness_note": task.get("readiness_note") or "",
            "reasons": [],
        }
        if work_date < today.isoformat() and int(a.get("work_report_count") or 0) == 0:
            overdue.append(row)
        if work_date >= today.isoformat() and work_date <= next_week and not task.get("effective_complete"):
            reasons = []
            if task.get("prerequisites_complete") is False:
                reasons.append("Incomplete hard predecessor")
            if (task.get("linked_work_order_gate") and task.get("linked_work_order_id")
                    and not task.get("linked_work_order_completed_at")):
                reasons.append("Open Work Order gate")
            if task.get("readiness_state") == "NOT_READY":
                reasons.append("NOT READY: " + str(task.get("readiness_note") or "No readiness reason"))
            if reasons:
                imminent.append({**row, "reasons": reasons})
        if not crew.get("captain_person_id") and work_date >= today.isoformat():
            captain_tbd.append(row)
    continuation = [
        {
            "task_id": int(t["setup_session_task_id"]),
            "task_name": t.get("task_name") or "Unnamed task",
            "stage": t.get("stage_name") or t.get("stage_key") or "Site-wide",
            "percent_complete": t.get("percent_complete") or 0,
        }
        for t in by_task.values()
        if not t.get("effective_complete") and t.get("execution_status") == "IN_PROGRESS"
        and int(t.get("future_assignment_count") or 0) == 0
    ]
    overdue.sort(key=lambda r: (r["work_date"], r["assignment_id"]))
    return {"overdue": overdue, "continuation": continuation,
            "imminent": imminent, "captain_tbd": captain_tbd}


def _assignment_text(row: dict) -> str:
    stage = row["stage"] + ((" / " + row["scene"]) if row.get("scene") else "")
    return (f'{row["task_name"]} | {stage} | Setup Day {row["day_number"] or "?"}'
            f' / {row["work_date"]} | Crew {row["crew"]} {row["shift"]} | '
            f'{row["captain"]} | {row["percent_complete"]}% | '
            f'Assignment {row["assignment_id"]}')


def manager_email(context: dict, today: date) -> tuple[str, str]:
    subject = f"MSB Setup — Manager action digest — {today.isoformat()}"
    body = [f"MSB Setup Manager action digest — {today.isoformat()} (America/Chicago)",
            "Outstanding items are not proof that no work happened.",
            "A completed annual task does not erase a missing historical work-period report.",
            ""]
    for title, key in [
        ("Past assignments missing reports", "overdue"),
        ("Incomplete tasks without future continuation", "continuation"),
        ("Scheduled readiness exceptions through next 7 days", "imminent"),
        ("Scheduled Captain TBD", "captain_tbd"),
    ]:
        rows = context[key]
        body += [f"{title} ({len(rows)}):"]
        for row in rows:
            if key == "continuation":
                body.append(f' - {row["task_name"]} | {row["stage"]} | {row["percent_complete"]}% | Manager schedule continuation')
            else:
                body.append(" - " + _assignment_text(row)
                            + (" | " + "; ".join(row["reasons"]) if row.get("reasons") else ""))
        if not rows:
            body.append(" - None")
        body.append("")
    body += ["Manager actions: request the original report, arrange continuation, review readiness or correct history through approved operations.",
             f"Open authenticated Setup: {SETUP_BASE}?view=perform",
             f"Reporting instructions: {SOP_URL}"]
    return subject, "\n".join(body)


def captain_email(rows: list[dict]) -> tuple[str, str]:
    if not rows:
        raise SetupNotificationError("Cannot send a Captain missing-report reminder with no missing occurrences")
    date_label = rows[0]["work_date"] if len({r["work_date"] for r in rows}) == 1 else "earlier Setup days"
    subject = f"MSB Setup — Please report your work from {date_label}"
    body = ["MSB Setup needs your work report for these scheduled assignments.",
            "A missing report does not prove that no work happened.", ""]
    for row in rows:
        body.append(" - " + _assignment_text(row))
    body.extend([
        "", "How to report your actual work:",
        f"1. Open {SETUP_BASE}?view=perform and sign in with your MSB account.",
        "2. Confirm Season 2026; open Perform Work.",
        "3. Select your name under Captain; a helping Manager may choose All scheduled work.",
        "4. Find the exact original Setup Day, task name, Crew and AM/PM. Do not use a similar task.",
        "5. Open the task and choose Report Work.",
        "6. Enter Date work actually happened (even if different from scheduled date), actual Crew size, Hours worked and Minutes worked.",
        "7. Enter cumulative whole-task % complete; use 100 only if the entire task is finished.",
        "8. Explain what was done/what remains if unfinished; optional quantity only for countable work.",
        "9. Verify the values, save the work report, confirm the actual work date and check Progress history.",
        "10. If unfinished, tell the Manager what remains. Reporting does not reschedule automatically.",
        "If no work happened, tell your Manager; DO NOT invent hours, percent, or reports.",
        "For a mistaken report, ask a Manager to use Correct report, not another report.",
        "For incorrect task/procedure information, use Report Correction.",
        f"Instructions: {SOP_URL}",
    ])
    return subject, "\n".join(body)


def notice_plans(board: dict, people: list[dict], today: date,
                 already_covered: set[tuple[int,int]] | None = None) -> list[dict]:
    context = notification_context(board, today)
    year = int(board.get("session", {}).get("season_year") or today.year)
    if year != 2026:
        raise SetupNotificationError("Daily #205 notices require the authoritative 2026 Setup Session")
    plans = []
    manager_subject, manager_body = manager_email(context, today)
    by_person = {int(p["person_id"]):p for p in people}
    for person in people:
        if not person.get("can_manage_setup"):
            continue
        plans.append({"kind":"MANAGER_DAILY", "recipient_person_id":int(person["person_id"]),
            "recipient_email":person["email"], "subject":manager_subject, "body_text":manager_body,
            "assignment_id":None, "covered_assignment_ids":[]})
    covered = already_covered or set()
    by_captain = defaultdict(list)
    for row in context["overdue"]:
        if row["captain_person_id"] is not None:
            recipient_id = int(row["captain_person_id"])
            if (recipient_id,int(row["assignment_id"])) not in covered:
                by_captain[recipient_id].append(row)
    for person_id, rows in by_captain.items():
        person = by_person.get(person_id)
        if not person or not person.get("can_read_setup"):
            continue  # Manager digest covers unverified Captain identities.
        subject, body = captain_email(rows)
        plans.append({"kind":"CAPTAIN_DAILY","recipient_person_id":person_id,
            "recipient_email":person["email"],"subject":subject,"body_text":body,
            "assignment_id":None, "covered_assignment_ids":[r["assignment_id"] for r in rows]})
    for p in plans:
        p["notice_date"]=today.isoformat()
        p["season_year"]=year
        p["message_key"]=f'{year}|{today.isoformat()}|{p["kind"]}|{p["recipient_email"]}'
    return plans


class DirectusSetupOutboxClient:
    """Creates authenticated Directus items; its event Flow owns mail delivery.

    A successful POST means queued only. A duplicate-key rejection is NOT a
    reason to retry under a new ID. Sending is disabled unless explicitly enabled.
    """
    def __init__(self, *, base_url: str | None = None, token: str | None = None):
        base = (base_url or os.getenv("SETUP_DIRECTUS_URL", "http://127.0.0.1:8055")).rstrip("/")
        parsed = urlsplit(base)
        if parsed.scheme != "http" or parsed.hostname not in {"localhost","127.0.0.1","::1"} or parsed.username:
            raise SetupNotificationError("Directus notification Items API must use a loopback-only HTTP origin")
        self.base_url = base
        self.token = token if token is not None else os.getenv("SETUP_DIRECTUS_NOTIFICATION_TOKEN", "")

    def queue(self, notice: dict, *, test_mode: bool = False) -> dict:
        enable = "SETUP_NOTIFICATION_TEST_SEND_ENABLED" if test_mode else "SETUP_NOTIFICATION_DAILY_ENABLED"
        if os.getenv(enable) != "1":
            raise SetupNotificationError(f"{enable} is not enabled")
        if not self.token:
            raise SetupNotificationError("Dedicated Directus notification token is not configured")
        if not organizational_email(notice.get("recipient_email")):
            raise SetupNotificationError("Recipient is not an organizational email")
        allowed = {"message_key","season_year","notice_date","kind","recipient_email",
                   "recipient_person_id","assignment_id","covered_assignment_ids","subject","body_text"}
        payload = {k:notice[k] for k in allowed if k in notice}
        request_object = Request(
            self.base_url + "/items/setup_notification_outbox",
            data=json.dumps(payload,separators=(",",":")).encode(),
            headers={"Authorization":"Bearer "+self.token,"Content-Type":"application/json"},
            method="POST",
        )
        try:
            with DIRECTUS_OPENER.open(request_object, timeout=15) as response:
                result = json.loads(response.read().decode())
        except HTTPError as exc:
            # A repeat unique-key request has not queued another email.
            raise SetupNotificationError(f"Directus notification outbox rejected request (HTTP {exc.code}); do not retry with a new key") from exc
        except (URLError, TimeoutError) as exc:
            raise SetupNotificationError(
                "Directus notification outcome UNKNOWN after transport failure; inspect outbox by message_key before retry"
            ) from exc
        data = result.get("data") if isinstance(result,dict) else None
        if not isinstance(data,dict) or not data.get("id"):
            raise SetupNotificationError("Directus notification returned no outbox item ID; verify before retry")
        return {"outbox_id":str(data["id"]), "status":"QUEUED_NOT_DELIVERED"}


def daily_dispatch(dsn: str, *, today: date | None = None, dry_run: bool = True,
                   client: DirectusSetupOutboxClient | None = None) -> dict:
    today = today or local_today()
    board = SetupSchedulingBoardRepository(dsn).board(2026)
    if not board.get("session"):
        raise SetupNotificationError("2026 Setup Session not found")
    people = eligible_people(dsn)
    plans = notice_plans(board, people, today, already_covered=covered_assignments(dsn,today))
    if dry_run:
        return {"date":today.isoformat(),"mode":"DRY_RUN","planned":len(plans),
                "manager":sum(p["kind"]=="MANAGER_DAILY" for p in plans),
                "captain":sum(p["kind"]=="CAPTAIN_DAILY" for p in plans),
                "unreported":len(notification_context(board,today)["overdue"])}
    transport = client or DirectusSetupOutboxClient()
    queued, errors = [], []
    for p in plans:
        try:
            queued.append(transport.queue(p))
        except SetupNotificationError as exc:
            errors.append({"message_key":p["message_key"],"error":str(exc)})
    return {"date":today.isoformat(),"mode":"LIVE_QUEUE","queued":len(queued),
            "errors":errors,"status":"FAILED" if errors else "QUEUED_NOT_DELIVERED"}
