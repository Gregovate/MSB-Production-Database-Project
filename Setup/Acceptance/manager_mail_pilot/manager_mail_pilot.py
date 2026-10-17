"""#205 governed one-day Manager-only mail pilot.

Reads current Production Setup and active authorized Manager identities. No DB
writes, Directus Flow, Captain email, webhook or recurring notification service.
Default is preview: an explicit single-day approval is required to send.
"""
from __future__ import annotations

import argparse
from datetime import date, datetime, timedelta
from email.message import EmailMessage
import hashlib
import json
import os
from pathlib import Path
import re
import smtplib
import ssl
from string import Template
from zoneinfo import ZoneInfo

CHICAGO = ZoneInfo("America/Chicago")
DAY = date(2026, 10, 17)
DEADLINE = date(2026, 11, 19)
FROM = "no-reply@sheboyganlights.org"
GOOGLE_RELAY = "smtp-relay.gmail.com"
DEFAULT_TEMPLATE = Path(__file__).with_name("manager_digest_template.txt")
DEFAULT_SUBJECT_TEMPLATE = Path(__file__).with_name("manager_digest_subject.txt")
MANAGER_ADDRESS = re.compile(r"[a-z0-9._%+\-]+@sheboyganlights[.]org")
SEND_GUARD = "APPROVED_OCT_17_MANAGER_ONLY"


class PilotStop(RuntimeError):
    """Do not silently retry or fall back after an uncertain result."""


def chicago_now():
    return datetime.now(CHICAGO)


def classify_manager_directory(rows: list[dict]) -> list[dict]:
    """People is the recipient directory; Setup capability is a separate gate.

    Return both eligible and held rows to the protected Admin preview.
    Do not silently omit People Managers without Setup access, or elevate anyone
    with Setup access but no People Manager designation.
    """
    if not 1 <= len(rows) <= 100:
        raise PilotStop("Unexpected Manager directory size; review People records")
    email_counts = {}
    for row in rows:
        address = str(row.get("email") or "").strip().lower()
        if address:
            email_counts[address] = email_counts.get(address, 0) + 1
    reviewed = []
    for original in rows:
        row = dict(original)
        email = str(row.get("email") or "").strip().lower()
        person_name = str(row.get("display_name") or "").strip()
        reasons = []
        if row.get("is_manager") is not True:
            reasons.append("Setup Manager access but not designated as Manager in People")
        if not MANAGER_ADDRESS.fullmatch(email):
            reasons.append("Missing/invalid organizational Manager email")
        if email_counts.get(email, 0) > 1:
            reasons.append("Duplicate People email")
        if not row.get("identity_linked"):
            reasons.append("No linked protected Setup identity")
        if row.get("can_manage_setup") is not True:
            reasons.append("No current Setup Manager access")
        if not person_name:
            reasons.append("Missing People display name")
        row["email"] = email
        row["display_name"] = person_name
        row["send_eligible"] = not reasons
        row["review_status"] = "ELIGIBLE" if not reasons else "HELD"
        row["review_reason"] = "Current People Manager and Setup authorization" if not reasons else "; ".join(reasons)
        reviewed.append(row)
    return reviewed


def manager_directory(dsn: str) -> list[dict]:
    """The accepted fieldwiring_app read boundary: ref.person + SECDEF function.

    Direct SELECT on public.directus_users is intentionally forbidden, and is
    never needed for the Manager recipient preview.
    """
    import psycopg2
    from psycopg2.extras import RealDictCursor

    sql = """
    SELECT p.person_id, lower(btrim(p.email)) AS email,
           coalesce(nullif(btrim(p.preferred_name),''),
                    nullif(btrim(concat_ws(' ',p.first_name,p.last_name)),''),
                    lower(btrim(p.email))) AS display_name,
           coalesce(p.is_manager,false) AS is_manager,
           p.directus_user_id IS NOT NULL AS identity_linked,
           coalesce(caps.can_manage_setup,false) AS can_manage_setup
    FROM ref.person p
    LEFT JOIN LATERAL ref.setup_browser_capabilities(lower(btrim(p.email))) caps ON true
    WHERE p.active_flag IS TRUE
      AND (p.is_manager IS TRUE OR caps.can_manage_setup IS TRUE)
    ORDER BY p.person_id
    """
    with psycopg2.connect(dsn) as conn:
        conn.set_session(readonly=True)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(sql)
            rows = [dict(row) for row in cur.fetchall()]
    return classify_manager_directory(rows)


def people_managers(dsn: str) -> list[dict]:
    """Eligible, unique recipients only; held People Managers remain visible."""
    people = [row for row in manager_directory(dsn) if row["send_eligible"]]
    if not people:
        raise PilotStop("No eligible Manager recipients; review People and Setup permissions")
    return people


def summarize(board: dict, today: date) -> dict:
    if not board.get("session") or int(board["session"].get("season_year") or 0) != 2026:
        raise PilotStop("The active 2026 Setup Session was not found")
    tasks = list({int(t["setup_session_task_id"]): t for t in board.get("tasks", [])}.values())
    if not tasks:
        raise PilotStop("The 2026 annual task list is empty")
    complete = [t for t in tasks if t.get("effective_complete")]
    remaining = [t for t in tasks if not t.get("effective_complete")]
    actionable = [t for t in remaining if t.get("execution_status") != "DEFERRED"]
    blocked = [t for t in actionable if (
        t.get("prerequisites_complete") is False or
        t.get("readiness_state") == "NOT_READY" or
        (t.get("linked_work_order_gate") and t.get("linked_work_order_id")
         and not t.get("linked_work_order_completed_at"))
    )]
    continuations = [t for t in actionable if
        t.get("execution_status") == "IN_PROGRESS" and
        int(t.get("future_assignment_count") or 0) == 0]
    days = {int(d["setup_work_day_id"]): d for d in board.get("work_days", [])}
    crews = {int(c["setup_work_day_crew_id"]): c for c in board.get("crews", [])}
    past, imminent, tbd = [], [], []
    for a in board.get("assignments", []):
        day = days.get(int(a.get("setup_work_day_id") or 0), {})
        raw = a.get("work_date") or day.get("work_date")
        if not raw or str(day.get("day_status") or a.get("day_status") or "").upper() == "CANCELLED":
            continue
        try:
            work_day = date.fromisoformat(str(raw)[:10])
        except ValueError as exc:
            raise PilotStop("Invalid scheduled work-date evidence") from exc
        task = next((t for t in tasks if int(t["setup_session_task_id"]) ==
                    int(a.get("setup_session_task_id") or 0)), None)
        if task is None:
            continue
        crew = crews.get(int(a.get("setup_work_day_crew_id") or 0), {})
        row = {
            "date":work_day.isoformat(),
            "name":str(task.get("task_name") or "Unnamed task"),
            "stage":str(task.get("stage_name") or task.get("stage_key") or "Site-wide"),
            "shift":str(a.get("shift_code") or "ALL_DAY"),
            "crew":str(crew.get("crew_code") or a.get("crew_lane") or "TBD"),
            "captain":str(crew.get("captain_display_name") or "Captain TBD"),
            "id":int(a["setup_work_day_task_id"]),
        }
        if work_day < today and not int(a.get("work_report_count") or 0):
            past.append(row)
        if today <= work_day <= today + timedelta(days=7) and not task.get("effective_complete") and (
            task.get("prerequisites_complete") is False or
            task.get("readiness_state") == "NOT_READY" or
            (task.get("linked_work_order_gate") and task.get("linked_work_order_id") and
             not task.get("linked_work_order_completed_at"))
        ):
            imminent.append(row)
        if work_day >= today and not crew.get("captain_person_id"):
            tbd.append(row)

    first = today - timedelta(days=6)
    recent, undated = 0, 0
    for t in complete:
        raw = str(t.get("completion_work_date") or "")[:10]
        try:
            completed = date.fromisoformat(raw)
        except ValueError:
            undated += 1
            continue
        if completed > today:
            undated += 1
        elif first <= completed <= today:
            recent += 1
    pace = recent / 7
    calendar_days = max(0, (DEADLINE - today).days)
    required = len(actionable) / calendar_days if calendar_days else None
    trustworthy = undated == 0 and recent >= 7 and pace > 0
    from math import ceil
    finish = (today + timedelta(days=ceil(len(actionable) / pace))) if trustworthy else None
    past.sort(key=lambda x: (x["date"],x["id"]))
    lines = lambda values: "\n".join(values) if values else "- None"
    return {
        "report_date":today.isoformat(), "total_tasks":len(tasks),
        "completed_tasks":len(complete), "remaining_tasks":len(remaining),
        "blocked_tasks":len(blocked), "missing_report_occurrences":len(past),
        "continuation_needed":len(continuations),
        "readiness_exceptions":len(imminent), "captain_tbd_count":len(tbd),
        "actual_pace":f"{pace:.2f}",
        "required_pace":f"{required:.2f}" if required is not None else "Unavailable",
        "projected_finish":finish.isoformat() if finish else "INSUFFICIENT DATA",
        "projection_confidence":("Task-count estimate only; tasks vary in size" if trustworthy
                                 else "Not reliable; completion-date evidence/sample insufficient"),
        "overdue_lines":lines([
            f"- {r['name']} | {r['stage']} | {r['date']} {r['shift']} | "
            f"Crew {r['crew']} | {r['captain']} | original #{r['id']}"
            for r in past
        ]),
        "continuation_lines":lines([
            f"- {t.get('task_name') or 'Unnamed task'} | "
            f"{t.get('stage_name') or t.get('stage_key') or 'Site-wide'} | "
            f"{t.get('percent_complete') or 0}% reported | needs future assignment"
            for t in continuations
        ]),
    }


def render(template: str, person: dict, report: dict) -> str:
    try:
        return Template(template).substitute(dict(report, recipient_name=person["display_name"]))
    except (KeyError, ValueError) as exc:
        raise PilotStop("Template contains an unsupported placeholder") from exc


def deliver(recipient: str, subject: str, body: str) -> str:
    """No passwords, no non-TLS fallback and never a Captain recipient."""
    if not MANAGER_ADDRESS.fullmatch(recipient):
        raise PilotStop("Manager recipient email rejected")
    message = EmailMessage()
    message["From"] = f"MSB Production DB <{FROM}>"
    message["To"] = recipient
    message["Subject"] = subject
    message.set_content(body, charset="utf-8")
    with smtplib.SMTP(GOOGLE_RELAY, 587, timeout=20) as smtp:
        smtp.ehlo()
        if not smtp.has_extn("starttls"):
            raise PilotStop("Google did not offer STARTTLS")
        smtp.starttls(context=ssl.create_default_context())
        smtp.ehlo()
        refused = smtp.send_message(message, from_addr=FROM, to_addrs=[recipient])
        if refused:
            raise PilotStop("SMTP recipient was rejected")
    return "SMTP_ACCEPTED_NOT_DELIVERED"


def send(dsn: str, path: Path, ledger: Path, now: datetime, mode: str, test_to: str | None) -> dict:
    """Every send must pass a second dispatch-time Manager lookup and guards."""
    local = now.astimezone(CHICAGO)
    today = local.date()
    if mode == "live" and (today != DAY or not (local.hour == 4 and local.minute <= 30)):
        raise PilotStop("One-day pilot send window is closed")
    if mode == "test" and today not in (date(2026,10,16), DAY):
        raise PilotStop("One-recipient test window is closed")

    from setup_scheduling_board_repository import SetupSchedulingBoardRepository
    roster = manager_directory(dsn)
    managers = [p for p in roster if p["send_eligible"]]
    if not managers:
        raise PilotStop("No eligible Manager recipients; review People and Setup permissions")
    if mode == "live" and any(p.get("is_manager") and not p["send_eligible"] for p in roster):
        raise PilotStop("People Manager roster has HELD recipients; review before live broadcast")
    board = SetupSchedulingBoardRepository(dsn).board(2026)
    report = summarize(board, today)
    template = path.read_text(encoding="utf-8")
    if not template.strip() or len(template) > 25000:
        raise PilotStop("Template is empty or unexpectedly large")
    messages = [(p,render(template,p,report)) for p in managers]
    if test_to:
        messages = [(p,s) for p,s in messages if p["email"] == test_to.lower().strip()]
        if len(messages) != 1:
            raise PilotStop("Test address is not exactly one current authorized Manager")
    try:
        subject = Template(DEFAULT_SUBJECT_TEMPLATE.read_text(encoding="utf-8")).substitute(report).strip()
    except (KeyError,ValueError,OSError) as exc:
        raise PilotStop("Subject template is missing or contains unsupported placeholders") from exc
    if not subject or len(subject) > 250 or any(c in subject for c in "\r\n\x00"):
        raise PilotStop("Subject template cannot produce a safe email header")
    if mode == "test":
        subject = "TEST — " + subject
    if mode == "preview":
        print(json.dumps({
            "mode":"NO_SEND_PREVIEW", "chicago_date":str(today),
            "eligible_managers":[
                {"name":p["display_name"],"email":p["email"],"status":"ELIGIBLE"}
                for p in managers
            ],
            "held_manager_review":[
                {"name":p["display_name"],"email":p["email"],"reason":p["review_reason"]}
                for p in roster if not p["send_eligible"]
            ],
            "manager_count":len(managers), "reviewed_count":len(roster),
            "counts":{k:report[k] for k in (
                "total_tasks","completed_tasks","remaining_tasks","blocked_tasks",
                "missing_report_occurrences","continuation_needed","readiness_exceptions",
                "captain_tbd_count","actual_pace","required_pace","projected_finish")},
            "subject":subject,
        },indent=2))
        print("--- FIRST MANAGER BODY — PREVIEW ONLY ---")
        print(messages[0][1])
        return {"status":"PREVIEW_ONLY","sent":0}
    if os.environ.get("MSB_SETUP_MANAGER_PILOT_SEND") != "APPROVED_OCT_17_MANAGER_ONLY" or (
        os.environ.get("SETUP_NOTIFICATION_SMTP_SEND_ENABLED") != "1"):
        raise PilotStop("SMTP production approval is OFF")
    if not ledger.is_dir():
        raise PilotStop("Protected SMTP attempt directory unavailable")

    for person, body in messages:
        digest = hashlib.sha256(person["email"].encode("ascii")).hexdigest()[:24]
        filename = (f"test-{today}-{digest}.json" if mode == "test"
                    else f"manager-{today}-{digest}.json")
        record_path = ledger / filename
        try:
            fd = os.open(record_path,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600)
        except FileExistsError as exc:
            raise PilotStop("Prior recipient attempt exists; do not retry automatically") from exc
        receipt={"recipient":person["email"],"purpose":"MANAGER_TEST" if mode == "test" else "MANAGER_DAILY",
                 "date":str(today),"status":"ATTEMPTED_UNCONFIRMED",
                 "at":local.isoformat()}
        with os.fdopen(fd,"w",encoding="utf-8") as stream:
            stream.write(json.dumps(receipt)+"\n")
            stream.flush()
            os.fsync(stream.fileno())
        try:
            receipt["status"]=deliver(person["email"],subject,body)
        except (OSError,smtplib.SMTPException,PilotStop) as exc:
            receipt["status"]="UNKNOWN_NO_AUTORETRY"
            receipt["error_class"]=type(exc).__name__
            record_path.write_text(json.dumps(receipt)+"\n",encoding="utf-8")
            raise PilotStop("SMTP outcome uncertain; inspect audit; STOP") from exc
        receipt["accepted_at"]=chicago_now().isoformat()
        record_path.write_text(json.dumps(receipt)+"\n",encoding="utf-8")
    return {"status":"SMTP_ACCEPTED_NOT_INBOX_PROOF","recipients":len(messages),"day":str(today)}


def main(argv=None) -> int:
    parser=argparse.ArgumentParser(description="Manager-only single-day 2026 Setup mail pilot")
    mode=parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--preview",action="store_true",help="Read-only, sends nothing")
    mode.add_argument("--live",action="store_true",help="One-day gated Manager only")
    mode.add_argument("--test-to",metavar="AUTHORIZED_MANAGER_EMAIL",help="One-recipient approved test")
    parser.add_argument("--template",type=Path,default=DEFAULT_TEMPLATE)
    parser.add_argument("--ledger",type=Path,default=Path("/var/lib/msb-setup-manager-mail-pilot"))
    args=parser.parse_args(argv)
    dsn=next((os.environ[v] for v in (
        "SETUP_DATABASE_DSN","FIELDWIRING_DATABASE_DSN","PROCEDURE_DATABASE_DSN"
    ) if os.environ.get(v)),None)
    if not dsn:
        print("STOP: Existing protected PostgreSQL DSN unavailable")
        return 2
    try:
        result=send(dsn,args.template,args.ledger,chicago_now(),
                    "preview" if args.preview else "test" if args.test_to else "live",
                    args.test_to)
        print(json.dumps(result))
    except (PilotStop,ValueError,OSError) as exc:
        print("STOP:",str(exc))
        return 2
    return 0


if __name__=="__main__":
    raise SystemExit(main())
