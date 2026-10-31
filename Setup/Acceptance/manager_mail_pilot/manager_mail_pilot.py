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
from html import escape as html_escape
import json
import os
from pathlib import Path
import re
import smtplib
import ssl
import time
from string import Template
from zoneinfo import ZoneInfo

CHICAGO = ZoneInfo("America/Chicago")
DAY = date(2026, 10, 17)
OCT18 = date(2026, 10, 18)
FIRST_RECURRING = date(2026, 10, 19)
SHOW_OPENING = date(2026, 11, 27)
SEASON_SEND_GUARD = "APPROVED_OCT_18_TO_SHOW_START_MANAGER_ONLY"
MISSED_DAY_SEND_GUARD = "APPROVED_OCT_18_IMMEDIATE_MANAGER_ONLY"
DEADLINE = date(2026, 11, 17)
FROM = "no-reply@sheboyganlights.org"
GOOGLE_RELAY = "smtp-relay.gmail.com"
DEFAULT_TEMPLATE = Path(__file__).with_name("manager_digest_template.txt")
DEFAULT_SUBJECT_TEMPLATE = Path(__file__).with_name("manager_digest_subject.txt")
DEFAULT_HTML_TEMPLATE = Path(__file__).with_name("manager_digest_html.html")
MANAGER_ADDRESS = re.compile(r"[a-z0-9._%+\-]+@sheboyganlights[.]org")
SEND_GUARD = "APPROVED_OCT_17_MANAGER_ONLY"
HTML_TEST_RECIPIENT = "gliebig@sheboyganlights.org"
LOGO_TEST_RECIPIENT = "gliebig@sheboyganlights.org"


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
        notes = []
        if not MANAGER_ADDRESS.fullmatch(email):
            reasons.append("Missing/invalid organizational Manager email")
        if email_counts.get(email, 0) > 1:
            reasons.append("Duplicate People email")
        if not person_name:
            reasons.append("Missing People display name")
        if not (row.get("is_manager") is True or row.get("can_manage_setup") is True):
            reasons.append("Neither a People Manager nor a current Setup Manager")
        if row.get("is_manager") is not True and row.get("can_manage_setup") is True:
            notes.append("Current Setup Manager; People Manager flag off")
        if row.get("is_manager") is True and row.get("can_manage_setup") is not True:
            notes.append("People Manager; no current Setup Manager application access")
        if not row.get("identity_linked"):
            notes.append("People-to-Directus link pending onboarding")
        row["email"] = email
        row["display_name"] = person_name
        row["send_eligible"] = not reasons
        row["review_status"] = "ELIGIBLE" if not reasons else "HELD"
        row["onboarding_note"] = "; ".join(notes)
        row["review_reason"] = "; ".join(reasons) if reasons else (
            "Active People contact; People Manager or current Setup Manager"
        )
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


# Content release only; delivery gates and receipts remain owned by #97.
CONTENT_VERSION = "2026.10.31-actionability-1"
SETUP_URL = "https://my.sheboyganlights.org/setup/"
PENDING = "Manager correction workflow pending"


def record_url(kind: str, ident: int) -> str:
    from urllib.parse import urlencode
    if kind in {"CONT", "DISP"}:
        return SETUP_URL + "record-location/?" + urlencode({"asset":f"{kind}:{int(ident)}", "season_year":2026})
    return SETUP_URL + "?" + urlencode({"view":"schedule", "manager_action":kind,
                                        "record_id":int(ident)})


def report_work_evidence(dsn: str, task_ids: list[int]) -> dict:
    """One bounded read; latest actual work date, then audit order breaks ties."""
    if not task_ids:
        return {}
    import psycopg2
    from psycopg2.extras import RealDictCursor
    with psycopg2.connect(dsn) as conn:
        conn.set_session(readonly=True)
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SET LOCAL statement_timeout = '30s'")
            cur.execute("""
                SELECT DISTINCT ON (p.setup_session_task_id)
                       p.setup_session_task_id, p.setup_task_progress_id, p.setup_work_day_task_id,
                       p.performed_on, p.percent_complete, p.progress_note,
                       p.recorded_at, p.updated_at,
                       coalesce(nullif(btrim(concat_ws(' ', a.first_name, a.last_name)),''),
                                a.email) AS recorded_by,
                       coalesce(nullif(btrim(concat_ws(' ', u.first_name, u.last_name)),''),
                                u.email) AS updated_by
                FROM ops.setup_task_progress p
                LEFT JOIN ref.person a ON a.person_id=p.created_by_person_id
                LEFT JOIN ref.person u ON u.person_id=p.updated_by_person_id
                WHERE p.setup_session_task_id = ANY(%s)
                ORDER BY p.setup_session_task_id, p.performed_on DESC NULLS LAST,
                         p.recorded_at DESC, p.setup_task_progress_id DESC
            """, (task_ids,))
            return {int(r["setup_session_task_id"]):dict(r) for r in cur.fetchall()}


def readable_date(value: object) -> str:
    """Work dates are calendar dates; audit instants explicitly use Central time."""
    if not value:
        return "Not recorded"
    try:
        raw = str(value)
        if len(raw) == 10:
            d = date.fromisoformat(raw)
            return f"{d:%b} {d.day}, {d.year}"
        instant = datetime.fromisoformat(raw.replace("Z", "+00:00"))
        if instant.tzinfo is None:
            return "Time zone not recorded"
        local = instant.astimezone(CHICAGO)
        return f"{local:%b} {local.day}, {local.year} at {local.hour % 12 or 12}:{local:%M %p %Z}"
    except (TypeError, ValueError):
        return "Date unavailable"


def report_was_updated(report: dict) -> bool:
    """Only a later audit instant supports an update label, not insert defaults."""
    try:
        recorded = datetime.fromisoformat(str(report.get("recorded_at")).replace("Z", "+00:00"))
        updated = datetime.fromisoformat(str(report.get("updated_at")).replace("Z", "+00:00"))
        return updated > recorded
    except (TypeError, ValueError):
        return False


def enrich_continuations(report: dict, evidence: dict) -> None:
    """Never change selection or completion based on a note's wording."""
    for row in report["continuation_rows"]:
        p = evidence.get(row["id"], {})
        if p.get("setup_work_day_task_id"):
            row["url"] = record_url("report", p["setup_work_day_task_id"])
        note = p.get("progress_note")
        row["note"] = note if note is not None else "No Report Work note recorded"
        row["detail"] = (
            f"Annual task #{row['id']} · {row['percent']}% current · "
            f"Report Work #{p.get('setup_task_progress_id', 'not recorded')} · "
            f"Work date: {readable_date(p.get('performed_on'))} · "
            f"Report percentage: {p.get('percent_complete') if p.get('percent_complete') is not None else 'Not recorded'} · "
            f"Reported by: {p.get('recorded_by') or 'Attribution not recorded'} · "
            f"Recorded: {readable_date(p.get('recorded_at'))}" +
            (f" · Updated by: {p.get('updated_by') or 'Attribution not recorded'} · {readable_date(p.get('updated_at'))}" if report_was_updated(p) else '') +
            "\nReport Work note: " + row["note"] +
            "\nTask completion note: " + (row.get("completion_note") or "No task completion note recorded") +
            "\nReview the original report if the note or reported percentage needs correction." +
            "".join(f"\nNext task: {n['name']} — blocked because this task is incomplete." for n in row.get("blocked_next_tasks", []))
        )
    report["continuation_lines"] = rows_text(report["continuation_rows"])


def rows_text(rows: list[dict]) -> str:
    return "\n\n".join(f"- {r['name']} | {r.get('stage', '')}\n{r['detail']}\nReview record: {r['url']}" +
                         ''.join(f"\nReview next task #{n['id']}: {n['url']}" for n in r.get('blocked_next_tasks', []))
                         for r in rows) or "- None"


def event_text(e: dict) -> str:
    location = e.get('destination_location_note') or e.get('stage_name')
    if not location and e.get('gps_latitude') is not None and e.get('gps_longitude') is not None:
        location = f"GPS {e['gps_latitude']}, {e['gps_longitude']}"
    return (f"#{e.get('setup_movement_event_id', 'none')} {e.get('event_type') or 'No movement recorded'}; "
            f"{location or 'Location not recorded'}; {readable_date(e.get('occurred_at'))}; "
            f"{e.get('capture_method') or 'Source not recorded'}; "
            f"{e.get('recorded_by_name') or e.get('captured_operator_email') or 'Actor not recorded'}")


def contents_observation(event: dict) -> dict:
    """Decode the installed #070 event envelope, never membership-derived EMPTY."""
    note = event.get('notes') or ''
    marker = 'contents_reconciliation='
    if marker not in note:
        return {}
    try:
        value, _ = json.JSONDecoder().raw_decode(note.rsplit(marker, 1)[1].lstrip())
        return value if isinstance(value, dict) else {}
    except (ValueError, TypeError):
        return {}


def display_placement_sets(picture: dict, events: dict) -> tuple[set, set]:
    """Accepted existing placement scans; never upgrade inferred unload evidence."""
    from setup_locate_assets import geographic_position
    parents = {c['container_id']: c for c in picture['containers']}
    memberships = {}
    for effect in picture['effect_rows']:
        if effect.get('display_id') is not None:
            memberships.setdefault(effect['setup_movement_event_id'], set()).add(
                (effect['display_id'], effect.get('movement_effect')))
    groups, candidates = {}, set()
    for d in picture['displays']:
        ident = d['display_id']
        event_id = d.get('last_movement_event_id')
        event = events.get(event_id, {})
        location = events.get(parents.get(d.get('container_id'), {}).get('last_movement_event_id'), {}) if d.get('position_mode') == 'WITH_CONTAINER' else event
        point = geographic_position(location)
        if point is not None and d.get('container_id') is not None:
            groups.setdefault((d['container_id'], *point), set()).add(ident)
        if (d.get('position_mode') == 'DETACHED' and event.get('event_type') == 'DISPLAY_MOVE'
                and event.get('capture_method') in {'CAMERA_SCAN', 'HID_SCAN'}
                and 'inferred_unload=true' not in (event.get('notes') or '')
                and memberships.get(event_id) == {(ident, 'DETACHED')}):
            candidates.add(ident)
    shared = set().union(*(ids for ids in groups.values() if len(ids) > 1)) if groups else set()
    return candidates - shared, shared


def container_display_evidence(ident: int, picture: dict, events: dict, last: dict, in_position=None) -> str:
    """Classify recorded provenance only; equal GPS never proves final placement."""
    if in_position is None:
        in_position, _ = display_placement_sets(picture, events)
    counts = {"In position": 0, "Container-linked": 0, "inferred unload": 0, "Display observation": 0,
              "unload only": 0, "no usable location": 0}
    positions = {}
    for d in picture['displays']:
        if d.get('container_id') != ident:
            continue
        e = last if d.get('position_mode') == 'WITH_CONTAINER' else events.get(d.get('last_movement_event_id'), {})
        usable = e.get('gps_latitude') is not None and e.get('gps_longitude') is not None
        if d['display_id'] in in_position:
            key = 'In position'
        elif not usable and not (e.get('stage_name') or e.get('destination_location_note')):
            key = 'no usable location'
        elif d.get('position_mode') == 'WITH_CONTAINER':
            key = 'Container-linked'
        elif 'inferred_unload=true' in (e.get('notes') or ''):
            key = 'inferred unload'
        elif e.get('event_type') == 'DISPLAY_MOVE':
            key = 'Display observation'
        else:
            key = 'unload only'
        counts[key] += 1
        if usable:
            point = (str(e['gps_latitude']), str(e['gps_longitude']))
            positions[point] = positions.get(point, 0) + 1
    total = sum(counts.values())
    if not total:
        return 'Displays: no active associations.'
    shared = max(positions.values(), default=0)
    return ('Displays: ' + ', '.join(f'{n} {key}' for key, n in counts.items() if n) +
            (f'; {shared}/{total} share recorded GPS — placement review required' if shared > 1 else '') +
            ('. Other positions unconfirmed.' if counts['In position'] and counts['In position'] < total else
             '.' if counts['In position'] == total else '. Final positions unconfirmed.'))


def movement_details(picture: dict, projected: dict) -> dict:
    """Read-only explanation of #88 evidence; no #077/#430/#431 dependency."""
    events = {e['setup_movement_event_id']:e for e in picture['effect_rows']}
    containers = {c['container_id']:c for c in picture['containers']}
    pickups = {p['container_id']:p for p in picture.get('pickup_requests', [])}
    in_position, shared_gps = display_placement_sets(picture, events)
    container_rows = []
    for c in projected['containers']:
        ident = c['container_id']
        state = containers[ident]
        trail = [e for e in events.values() if e.get('container_id') == ident]
        last = events.get(state.get('last_movement_event_id'), {})
        observed = [(e, contents_observation(e)) for e in trail]
        observed = [(e, v) for e, v in observed if v]
        load_event, load = observed[-1] if observed else ({}, {})
        decision = load.get('decision')
        load_label = {'EMPTY':'Recorded physical EMPTY observation',
                      'NOT_EMPTY':'Recorded cargo remains',
                      'NOT_SURE':'Physical contents unknown / review required'}.get(decision,
                      'No usable physical load observation')
        flags = [e for e in trail if 'contents_review_required=true' in (e.get('notes') or '')]
        reasons = []
        for e in flags:
            v = contents_observation(e)
            reason = ('Operator selected NOT_SURE' if v.get('decision') == 'NOT_SURE' else
                      'Operator reported NOT_EMPTY without identifying remaining cargo' if v.get('decision') == 'NOT_EMPTY' else
                      'Recorded contents_review_required=true; structured reason unavailable')
            reasons.append(f"#{e.get('setup_movement_event_id')}: {reason}")
        # #078 requests require an explicit empty confirmation and are removed
        # by cancellation or a later actual RETURNED record. Never infer readiness.
        pickup = pickups.get(ident)
        if pickup:
            status = (f"Confirmed Ready for Pickup — active request #{pickup['pickup_event_id']}; "
                      f"{readable_date(pickup['requested_at'])}; {pickup['operator_email']}; "
                      f"{pickup.get('stage_name') or ''} / {pickup.get('location_note') or ''}")
            load_label += "; pickup request also confirms empty"
        else:
            status = 'Returned Home — actual RETURNED record' if c.get('reported_home') else 'Pickup readiness unverified — no active request'
        kind = state.get('container_type_name')
        role = ('Integral show equipment (Standalone Display)' if kind == 'Standalone Display'
                else f"{kind or 'Type not recorded'}; equipment role unverified")
        # Avoid repeating the same actor, GPS and timestamp for the same event.
        same_event = bool(load_event) and load_event.get('setup_movement_event_id') == last.get('setup_movement_event_id')
        load_source = 'same event as last movement' if same_event else event_text(load_event) if load_event else 'no observation recorded'
        detail = (f"Status: {status}\n"
                  f"Last movement: {event_text(last)}\n"
                  f"Load: {load_label} ({load_source})\n"
                  f"Home: {c.get('home_location_code') or 'Not recorded'} · Type: {role}\n" +
                  container_display_evidence(ident, picture, events, last, in_position) + "\n" +
                  ("Contents review — resolution unverified: " + ' | '.join(reasons) if reasons else
                   'Contents review: no flag recorded.') +
                  f"\n{PENDING}.")
        container_rows.append({'name':f"C{ident:03d} — {c.get('name') or 'Description not recorded'}",
                               'detail':detail, 'url':(SETUP_URL + f'container-pickups/?asset=CONT%3A{ident}&season_year=2026' if pickup else record_url('CONT', ident))})
    display_rows = []
    for d in picture['displays']:
        if d['display_id'] in in_position:
            continue  # Existing independent placement scan: not an exception.
        e = events.get(d.get('last_movement_event_id'), {})
        parent = containers.get(d.get('container_id'), {})
        parent_event = events.get(parent.get('last_movement_event_id'), {})
        mode = d.get('position_mode')
        effects = [x for x in picture['effect_rows'] if x.get('display_id') == d['display_id']
                   and x.get('setup_movement_event_id') == d.get('last_movement_event_id')]
        conflict = (bool(e and not effects) or
                    (mode == 'DETACHED' and any(x.get('movement_effect') != 'DETACHED' for x in effects)) or
                    (mode == 'WITH_CONTAINER' and bool(parent.get('movement_status') == 'RETURNED')))
        if conflict:
            label = 'Conflicting observations — review required'
            reason = 'Current Display state conflicts with event membership or returned-Home Container association.'
        elif d['display_id'] in shared_gps:
            label = 'Shared GPS with other Displays from this Container — placement review required'
            reason = event_text(parent_event if mode == 'WITH_CONTAINER' else e)
            if 'inferred_unload=true' in (e.get('notes') or ''):
                reason += '; location inherited from Container, not an independent scan'
        elif mode == 'WITH_CONTAINER' and parent_event:
            label = 'Last location inferred from a Container'
            reason = f"C{d['container_id']:03d}: {event_text(parent_event)}; not an independent Display observation."
        elif mode == 'DETACHED' and e:
            label = 'Unloaded / independent location recorded; final position unconfirmed'
            reason = event_text(e)
            if 'inferred_unload=true' in (e.get('notes') or ''):
                label = 'Unloaded; location inherited from Container; final position unconfirmed'
                reason += '; inferred prior unload, not a physical Display scan'
        else:
            label = 'No usable placement evidence'
            reason = event_text(e)
        display_rows.append({'name':f"{d['display_name']} — Display {d['display_id']}",
            'detail':f"{label}. {reason}\nScan the Display in position using Record Location. "
                     f"Historical corrections: {PENDING}.",
            'url':record_url('DISP', d['display_id'])})
    return {'container_rows':container_rows, 'display_rows':display_rows,
            'display_in_position_ids':sorted(in_position),
            'container_detail_lines':rows_text(container_rows), 'display_detail_lines':rows_text(display_rows)}


def summarize_container_snapshot(containers: list[dict], generated_at: object) -> dict:
    """#88 movement + #171 read-only association projection, not physical proof."""
    if not containers:
        raise PilotStop("Container reference inventory unavailable")
    seen=set()
    counts = {
        "containers_total":len(containers),
        "containers_park_recorded":0,
        "containers_outbound":0,
        "containers_empty_at_park":0,
        "containers_partial_at_park":0,
        "containers_returned":0,
        "containers_no_movement":0,
        "containers_location_review":0,
        "containers_contents_review_history":0,
    }
    for c in containers:
        ident = int(c["container_id"])
        if ident in seen:
            raise PilotStop("Duplicate Container in current movement snapshot")
        seen.add(ident)
        status = str(c.get("movement_status") or "").upper()
        observation = c.get("observation") or {}
        event_type = str(observation.get("event_type") or "").upper()
        if c.get("review_event_ids"):
            counts["containers_contents_review_history"] += 1
        if c.get("reported_home") or status == "RETURNED" or event_type == "RETURNED":
            counts["containers_returned"] += 1
        elif status in {"PICKED", "LOADED", "IN_TRANSIT"}:
            counts["containers_outbound"] += 1
        elif status in {"DELIVERED", "UNLOADED", "STAGED", "PLACED", "RELOCATED"} or (
            status == "CONTAINER_MOVE" and (
                c.get("current_location_note") or
                observation.get("destination_location_note") or
                observation.get("stage_name") or
                c.get("position_source") == "movement-event" and c.get("position")
            )
        ):
            counts["containers_park_recorded"] += 1
            if c.get("load_state") == "EMPTY":
                counts["containers_empty_at_park"] += 1
            elif c.get("load_state") == "PARTIAL":
                counts["containers_partial_at_park"] += 1
        elif not status and not c.get("movement_status") and not observation.get("event_type"):
            counts["containers_no_movement"] += 1
        else:
            counts["containers_location_review"] += 1
    if sum(counts[k] for k in (
        "containers_park_recorded","containers_outbound","containers_returned",
        "containers_no_movement","containers_location_review")) != len(containers):
        raise PilotStop("Container movement categories did not partition the inventory")
    counts["containers_snapshot_as_of"] = readable_date(generated_at)
    counts["containers_evidence_note"] = (
        "Recorded #88 movement/#171 associations. Picked is not park delivery; "
        "empty/partial are subsets of recorded park stops and not physical inspections."
    )
    return counts


def container_summary(dsn: str, season_year: int = 2026) -> dict:
    """Reuse the installed #88 movement snapshot and #171 Container projection."""
    from setup_repository import SetupRepository
    from setup_production_report import movement_picture
    from setup_locate_assets import locate_assets

    repository = SetupRepository(dsn)
    session = repository.movement_summary(season_year)
    session_id = session.get("setup_session_id")
    if not session_id:
        raise PilotStop("2026 Setup Session missing for Container snapshot")
    picture = movement_picture(repository, session_id, include_unobserved=True)
    from setup_movement_repository import SetupMovementRepository
    picture["pickup_requests"] = SetupMovementRepository(dsn).pickup_list(season_year)["containers"]
    projected = locate_assets(picture)
    counts = summarize_container_snapshot(
        projected["containers"], picture.get("generated_at")
    )
    counts["containers_session_id"] = int(session_id)
    counts.update(movement_details(picture, projected))
    return counts


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
            "url":record_url("report", a["setup_work_day_task_id"]),
        }
        # A completed Work Order satisfies its Setup gate without a second
        # Setup report; stored execution_status may correctly remain PLANNED.
        completed_gate = task.get("linked_work_order_gate") and task.get("effective_complete")
        if work_day < today and not completed_gate and not int(a.get("work_report_count") or 0):
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
        "completion_percent":f"{(len(complete) * 100 / len(tasks)):.1f}",
        "completed_tasks":len(complete), "remaining_tasks":len(remaining),
        "blocked_tasks":len(blocked), "missing_report_occurrences":len(past),
        "continuation_needed":len(continuations),
        "readiness_exceptions":len(imminent), "captain_tbd_count":len(tbd),
        "actual_pace":f"{pace:.2f}",
        "required_pace":f"{required:.2f}" if required is not None else "Unavailable",
        "projected_finish":finish.isoformat() if finish else "INSUFFICIENT DATA",
        "projection_confidence":("Task-count estimate only; tasks vary in size" if trustworthy
                                 else "Not reliable; completion-date evidence/sample insufficient"),
        "past_rows":past,
        "continuation_rows":[{
            "id":int(t["setup_session_task_id"]),
            "url":record_url("planning", t["setup_session_task_id"]),
            "name":str(t.get("task_name") or "Unnamed task"),
            "stage":str(t.get("stage_name") or t.get("stage_key") or "Site-wide"),
            "completion_note":t.get("completion_note"),
            "blocked_next_tasks":[{**n, "url":record_url("planning", n["id"])} for n in t.get("blocked_next_tasks", [])],
            "percent":str(t.get("percent_complete") or 0)
        } for t in continuations],
        "overdue_lines":lines([
            f"- {r['name']} | {r['stage']} | {r['date']} {r['shift']} | "
            f"Crew {r['crew']} | {r['captain']} | original #{r['id']} | {r['url']}"
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
        return Template(template).substitute(dict({"container_detail_lines":"Not loaded", "display_detail_lines":"Not loaded"}, **report, recipient_name=person["display_name"]))
    except (KeyError, ValueError) as exc:
        raise PilotStop("Template contains an unsupported placeholder") from exc


def render_html(template: str, person: dict, report: dict) -> str:
    """Source-reviewed HTML structure; ALL injected PostgreSQL values escaped."""
    values = {key: html_escape(str(value), quote=True)
              for key,value in report.items() if not isinstance(value, (list,dict))}
    values["recipient_name"] = html_escape(str(person["display_name"]), quote=True)

    def td(value: object, *, right: bool = False) -> str:
        align = ' align="right"' if right else ''
        return ('<td' + align + ' style="padding:9px 8px;border-bottom:1px solid '
                '#e6edf2;vertical-align:top;">' +
                html_escape(str(value), quote=True) + '</td>')

    def rows_or_none(lines: list[str]) -> str:
        return '\n'.join(lines) if lines else (
            '<tr><td colspan="3" style="padding:11px 8px;color:#587085;">'
            'None recorded</td></tr>'
        )

    def linked_cell(text: str, url: str, next_tasks=()) -> str:
        links = ''.join('<br><a target="_blank" rel="noopener" href="' + html_escape(n["url"], quote=True) + '">Review next task: ' + html_escape(n["name"], quote=True) + '</a>' for n in next_tasks)
        return '<td style="padding:9px 8px;border-bottom:1px solid #e6edf2;vertical-align:top;white-space:pre-wrap">' + html_escape(text, quote=True) + '<br><a target="_blank" rel="noopener" href="' + html_escape(url, quote=True) + '">Review record</a>' + links + '</td>'

    for key in ('container', 'display'):
        values[key + '_detail_html'] = rows_or_none([
            '<tr>' + linked_cell(r['name'] + '\n' + r['detail'], r['url']) + '</tr>'
            for r in report.get(key + '_rows', [])])
    past = []
    for row in report.get("past_rows") or []:
        # Restrict markup to known table tags; stage and names are escaped by td.
        task = str(row["name"]) + " — " + str(row["stage"])
        crew = "Crew " + str(row["crew"]) + " / " + str(row["captain"])
        original = str(row["date"]) + " " + str(row["shift"])
        past.append("<tr>" + td(original) + linked_cell(task, row["url"]) + td(crew) + "</tr>")
    values["overdue_html_rows"] = rows_or_none(past)

    continuation = []
    for row in report.get("continuation_rows") or []:
        task = str(row["name"]) + " — " + str(row["stage"])
        continuation.append("<tr>" + linked_cell(task + "\n" + row.get("detail", "Report Work evidence not loaded"), row["url"], row.get("blocked_next_tasks", [])) + td(str(row["percent"]) + "%",right=True) + "</tr>")
    values["continuation_html_rows"] = rows_or_none(continuation).replace(
        'colspan="3"', 'colspan="2"'
    )

    try:
        body = Template(template).substitute(values)
    except (KeyError, ValueError) as exc:
        raise PilotStop("HTML template contains an unsupported placeholder") from exc
    if len(body) > 2000000:
        raise PilotStop("HTML email unexpectedly large")
    return body


class MailDeliveryError(PilotStop):
    """Keep submission uncertainty separate from connection preparation failures."""

    def __init__(self, stage, cause, attempts):
        self.stage = stage
        self.error_class = type(cause).__name__
        self.attempts = attempts
        self.uncertain = stage == "submission"
        self.smtp_code = getattr(cause, "smtp_code", None)
        super().__init__(f"SMTP {stage} failed ({self.error_class}); "
                         f"attempts={attempts}; no automatic resubmission")


def deliver(recipient: str, subject: str, body: str, html_body: str | None = None) -> str:
    """Retry connection preparation only; never retry message submission."""
    if not MANAGER_ADDRESS.fullmatch(recipient):
        raise PilotStop("Manager recipient email rejected")
    message = EmailMessage()
    message["From"] = f"MSB Production DB <{FROM}>"
    message["To"] = recipient
    message["Subject"] = subject
    message.set_content(body, charset="utf-8")
    if html_body is not None:
        message.add_alternative(html_body, subtype="html", charset="utf-8")
    for attempt in range(1, 4):
        smtp = None
        stage = "connect"
        try:
            smtp = smtplib.SMTP(GOOGLE_RELAY, 587, timeout=20)
            stage = "ehlo"
            code, _ = smtp.ehlo()
            if code != 250:
                raise smtplib.SMTPHeloError(code, b"EHLO rejected")
            stage = "starttls"
            if not smtp.has_extn("starttls"):
                raise PilotStop("Google did not offer STARTTLS")
            smtp.starttls(context=ssl.create_default_context())
            stage = "tls_ehlo"
            code, _ = smtp.ehlo()
            if code != 250:
                raise smtplib.SMTPHeloError(code, b"TLS EHLO rejected")
            # Once send_message begins, conservatively treat any failure as
            # uncertain. No second call is allowed for this recipient.
            stage = "submission"
            refused = smtp.send_message(message, from_addr=FROM, to_addrs=[recipient])
            if refused:
                raise PilotStop("SMTP recipient was rejected")
            # Successful DATA acknowledgement is authoritative even if closing
            # the socket subsequently fails. QUIT must not erase acceptance.
            return "SMTP_ACCEPTED_NOT_DELIVERED"
        except (OSError, smtplib.SMTPException, PilotStop) as exc:
            transient = isinstance(exc, (smtplib.SMTPServerDisconnected,
                                         TimeoutError, ConnectionError))
            if stage != "submission" and transient and attempt < 3:
                time.sleep(attempt)
                continue
            raise MailDeliveryError(stage, exc, attempt) from exc
        finally:
            if smtp is not None:
                try:
                    smtp.close()
                except OSError:
                    pass


def enforce_approved_manager_audience(managers: list[dict], roster: list[dict]) -> None:
    """Require exact recipient acknowledgement, including any held People Managers.

    No static email list lives in source; operator-approved root-only systemd
    environment determines the one-day send and is checked against LIVE People.
    """
    approved = os.environ.get("MSB_SETUP_MANAGER_PILOT_APPROVED_ROSTER", "").strip()
    if not approved:
        raise PilotStop("Manager fan-out STOP: exact recipient roster not approved")
    actual = {p["email"] for p in managers}
    values = [value.strip().lower() for value in approved.split(",")]
    if (not values or any(not MANAGER_ADDRESS.fullmatch(x) for x in values)
            or len(set(values)) != len(values) or set(values) != actual):
        raise PilotStop("Manager fan-out STOP: approved roster differs from current eligible People")
    if any(not p["send_eligible"] for p in roster):
        raise PilotStop("Manager fan-out STOP: unknown or malformed manager contact")
    # Identity-link and People-flag discrepancies remain visible but are not
    # blanket SMTP disqualifiers. No silent privilege changes are performed.


def send(dsn: str, path: Path, ledger: Path, now: datetime, mode: str, test_to: str | None, *, dry_run: bool = False) -> dict:
    """Every send must pass a second dispatch-time Manager lookup and guards."""
    local = now.astimezone(CHICAGO)
    today = local.date()
    if mode == "live" and (today != DAY or not (local.hour == 4 and local.minute <= 30)):
        raise PilotStop("One-day pilot send window is closed")
    if mode in ("today", "daily", "recover"):
        raw = os.environ.get("MSB_MANAGER_MAIL_STOP_DATE", "").strip()
        try:
            stop_date = date.fromisoformat(raw)
        except ValueError as exc:
            raise PilotStop("Bounded Manager mail end date missing or invalid") from exc
        if stop_date < OCT18 or stop_date > SHOW_OPENING:
            raise PilotStop("Manager mail end date must be Oct 18 through Nov 27, 2026")
        if mode == "recover":
            if today != date(2026,10,22) or os.environ.get("MSB_SETUP_MANAGER_RECOVERY_DATE") != str(today):
                raise PilotStop("Recovery requires explicit October 22 approval")
            if not FIRST_RECURRING <= today <= stop_date:
                raise PilotStop("Recovery outside approved season")
        elif mode == "today":
            if today != OCT18:
                raise PilotStop("Oct 18 immediate Manager send only; no other catch-up")
            if os.environ.get("MSB_SETUP_MANAGER_TODAY_SEND") != MISSED_DAY_SEND_GUARD:
                raise PilotStop("Immediate Oct 18 Manager mail approval is OFF")
        elif not (FIRST_RECURRING <= today <= stop_date
                  and local.hour == 4 and 0 <= local.minute <= 30):
            raise PilotStop("Bounded Manager 04:00 daily send window is closed")
    if mode == "test" and today not in (date(2026,10,16), DAY):
        raise PilotStop("One-recipient test window is closed")
    if mode == "html_test" and (
        today != DAY or
        str(test_to or "").strip().lower() != HTML_TEST_RECIPIENT
    ):
        raise PilotStop("Formatted test limited to October 17 and the single reviewed Manager mailbox")
    if mode == "logo_test" and (
        today != DAY or
        str(test_to or "").strip().lower() != LOGO_TEST_RECIPIENT
    ):
        raise PilotStop("Final logo test limited to October 17 and the single reviewed Manager mailbox")
    if mode in ("today", "daily", "recover"):
        if (os.environ.get("MSB_SETUP_MANAGER_SEASON_SEND") != SEASON_SEND_GUARD
                or os.environ.get("SETUP_NOTIFICATION_SMTP_SEND_ENABLED") != "1"):
            raise PilotStop("Bounded season Manager SMTP approval is OFF")
    elif mode != "preview" and (
        os.environ.get("MSB_SETUP_MANAGER_PILOT_SEND") != SEND_GUARD or
        os.environ.get("SETUP_NOTIFICATION_SMTP_SEND_ENABLED") != "1"
    ):
        raise PilotStop("SMTP production approval is OFF")

    from setup_scheduling_board_repository import SetupSchedulingBoardRepository
    roster = manager_directory(dsn)
    managers = [p for p in roster if p["send_eligible"]]
    if not managers:
        raise PilotStop("No eligible Manager recipients; review People and Setup permissions")
    if mode in ("live", "today", "daily", "recover"):
        enforce_approved_manager_audience(managers, roster)
    board = SetupSchedulingBoardRepository(dsn).board(2026)
    report = summarize(board, today)
    enrich_continuations(report, report_work_evidence(dsn, [r["id"] for r in report["continuation_rows"]]))
    report.update(container_summary(dsn, season_year=2026))
    template = path.read_text(encoding="utf-8")
    if not template.strip() or len(template) > 25000:
        raise PilotStop("Template is empty or unexpectedly large")
    html_source = DEFAULT_HTML_TEMPLATE.read_text(encoding="utf-8")
    if not html_source.strip() or len(html_source) > 30000:
        raise PilotStop("HTML email template unavailable or unexpectedly large")
    messages = [(p,render(template,p,report),render_html(html_source,p,report))
                for p in managers]
    if test_to:
        messages = [(p,s,h) for p,s,h in messages if p["email"] == test_to.lower().strip()]
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
    elif mode == "html_test":
        subject = "FORMATTED TEST — " + subject
    elif mode == "logo_test":
        subject = "FINAL LOGO TEST — " + subject
    if dry_run and not ledger.is_dir():
        raise PilotStop("Protected SMTP attempt directory unavailable")
    if mode == "preview" or dry_run:
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
                "captain_tbd_count","actual_pace","required_pace","projected_finish",
                "containers_total","containers_park_recorded","containers_outbound",
                "containers_empty_at_park","containers_partial_at_park",
                "containers_returned","containers_no_movement",
                "containers_location_review","containers_contents_review_history",
                "containers_snapshot_as_of")},
            "subject":subject,
        },indent=2))
        print("--- FIRST MANAGER BODY — PREVIEW ONLY ---")
        print(messages[0][1])
        print("--- REVIEWED HTML ALTERNATIVE: prepared, NOT SENT ---")
        print("HTML characters:",len(messages[0][2]))
        return {"status":"PREVIEW_ONLY","sent":0}
    if mode in ("today", "daily", "recover"):
        if (os.environ.get("MSB_SETUP_MANAGER_SEASON_SEND") != SEASON_SEND_GUARD
                or os.environ.get("SETUP_NOTIFICATION_SMTP_SEND_ENABLED") != "1"):
            raise PilotStop("Bounded season Manager SMTP approval is OFF")
    elif os.environ.get("MSB_SETUP_MANAGER_PILOT_SEND") != SEND_GUARD or (
        os.environ.get("SETUP_NOTIFICATION_SMTP_SEND_ENABLED") != "1"):
        raise PilotStop("SMTP production approval is OFF")
    if not ledger.is_dir():
        raise PilotStop("Protected SMTP attempt directory unavailable")

    accepted = 0
    skipped = 0
    failures = 0
    for person, body, html_body in messages:
        digest = hashlib.sha256(person["email"].encode("ascii")).hexdigest()[:24]
        filename = (f"test-{today}-{digest}.json" if mode == "test"
                    else f"html-test-{today}-{digest}.json" if mode == "html_test"
                    else f"logo-test-{today}-{digest}.json" if mode == "logo_test"
                    else f"manager-{today}-{digest}.json")
        record_path = ledger / filename
        try:
            fd = os.open(record_path,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600)
        except FileExistsError as exc:
            if mode == "recover":
                skipped += 1
                continue  # Preserve every prior attempt, including uncertain sends.
            raise PilotStop("Prior recipient attempt exists; do not retry automatically") from exc
        purpose = ("MANAGER_LOGO_REVIEW_TEST" if mode == "logo_test"
                   else "MANAGER_HTML_REVIEW_TEST" if mode == "html_test"
                   else "MANAGER_TEST" if mode == "test" else "MANAGER_DAILY")
        receipt={"recipient":person["email"],"purpose":purpose,
                 "date":str(today),"status":"ATTEMPTED_UNCONFIRMED",
                 "at":local.isoformat()}
        with os.fdopen(fd,"w",encoding="utf-8") as stream:
            stream.write(json.dumps(receipt)+"\n")
            stream.flush()
            os.fsync(stream.fileno())
        try:
            receipt["status"]=deliver(person["email"],subject,body,html_body)
        except (OSError,smtplib.SMTPException,PilotStop) as exc:
            receipt["status"]="UNKNOWN_NO_AUTORETRY"
            receipt["error_class"]=getattr(exc,"error_class",type(exc).__name__)
            receipt["smtp_stage"]=getattr(exc,"stage","unknown")
            receipt["connection_attempts"]=getattr(exc,"attempts",1)
            receipt["smtp_code"]=getattr(exc,"smtp_code",None)
            if isinstance(exc,MailDeliveryError) and not exc.uncertain:
                receipt["status"]="FAILED_BEFORE_SUBMISSION"
            record_path.write_text(json.dumps(receipt)+"\n",encoding="utf-8")
            failures += 1
            print(f"SMTP recipient attempt held: stage={receipt['smtp_stage']} "
                  f"error={receipt['error_class']} status={receipt['status']}")
            continue  # Other distinct recipients have independent attempt claims.
        accepted += 1
        receipt["accepted_at"]=chicago_now().isoformat()
        record_path.write_text(json.dumps(receipt)+"\n",encoding="utf-8")
    if failures:
        raise PilotStop(f"SMTP batch incomplete: accepted={accepted}, held={failures}, skipped={skipped}; inspect audit")
    return {"status":"SMTP_ACCEPTED_NOT_INBOX_PROOF","recipients":accepted,"skipped_existing":skipped,"day":str(today)}


def accepted_setup_dsn() -> str:
    """Resolve *only* the existing msb/fieldwiring_app service identity.

    The installed Setup env can contain host-only SETUP_DATABASE_DSN; libpq's
    implicit OS user/dbname then fails despite a valid existing .pgpass entry.
    Never accept another supplied role/db or grant Directus privileges.
    """
    from psycopg2.extensions import make_dsn, parse_dsn
    raw = next((os.environ[key] for key in (
        "SETUP_DATABASE_DSN", "FIELDWIRING_DATABASE_DSN", "PROCEDURE_DATABASE_DSN"
    ) if os.environ.get(key, "").strip()), "")
    if not raw:
        raise PilotStop("Protected Setup PostgreSQL connection is not configured")
    try:
        opts = parse_dsn(raw)
    except Exception as exc:
        raise PilotStop("Protected Setup DSN is invalid") from exc
    expected = {"host":"127.0.0.1","port":"5432","dbname":"msb","user":"fieldwiring_app"}
    for key,value in expected.items():
        if opts.get(key) and str(opts[key]) != value:
            raise PilotStop("Setup DSN does not match accepted msb fieldwiring_app identity")
    return make_dsn(raw, **expected)


def main(argv=None) -> int:
    parser=argparse.ArgumentParser(description="Manager-only single-day 2026 Setup mail pilot")
    mode=parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--preview",action="store_true",help="Read-only, sends nothing")
    mode.add_argument("--preview-recovery", action="store_true", help="Validate all recovery guards and rendering; no SMTP or receipts")
    mode.add_argument("--live",action="store_true",help="Historic Oct 17 one-day Manager only")
    mode.add_argument("--send-today",action="store_true",help="One immediate Oct 18 Manager digest only")
    mode.add_argument("--recover-unattempted",action="store_true",help="Explicit October 22 recovery; preserve and skip all existing receipts")
    mode.add_argument("--daily",action="store_true",help="Bounded daily 04:00 Manager digest until opening")
    mode.add_argument("--test-to",metavar="AUTHORIZED_MANAGER_EMAIL",help="Original one-recipient test (not a resend)")
    mode.add_argument("--html-test-to",metavar="OPERATOR_MAILBOX",help="One distinct formatted Manager review email, Oct 17 only")
    mode.add_argument("--logo-test-to",metavar="OPERATOR_MAILBOX",help="One final white PNG logo review email, Oct 17 only")
    parser.add_argument("--template",type=Path,default=DEFAULT_TEMPLATE)
    parser.add_argument("--ledger",type=Path,default=Path("/var/lib/msb-setup-manager-mail-pilot"))
    args=parser.parse_args(argv)
    if (args.preview_recovery or args.recover_unattempted or args.send_today or args.daily or args.html_test_to or args.logo_test_to) and args.ledger != Path("/var/lib/msb-setup-manager-mail-pilot"):
        print("STOP: Review must use the same protected Production receipt directory")
        return 2
    try:
        dsn = accepted_setup_dsn()
        result=send(dsn,args.template,args.ledger,chicago_now(),
                    "preview" if args.preview else "today" if args.send_today
                    else "recover" if (args.preview_recovery or args.recover_unattempted) else "daily" if args.daily else "logo_test" if args.logo_test_to
                    else "html_test" if args.html_test_to
                    else "test" if args.test_to else "live",
                    args.logo_test_to or args.html_test_to or args.test_to,
                    dry_run=args.preview_recovery)
        print(json.dumps(result))
    except (PilotStop,ValueError,OSError) as exc:
        print("STOP:",str(exc))
        return 2
    return 0


if __name__=="__main__":
    raise SystemExit(main())
