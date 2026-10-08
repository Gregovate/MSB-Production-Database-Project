"""#88 Manager report: existing movement evidence, never inferred physical work.

Movement/state reads share a read-only snapshot. Planning comes from the existing
Material Status projection and may change during report generation. No new model,
assignment edits, repair command or material-authority rules are introduced here.
"""
from __future__ import annotations

from datetime import datetime
from decimal import Decimal
from pathlib import Path
from zoneinfo import ZoneInfo

from flask import render_template_string
from psycopg2.extras import RealDictCursor

CHICAGO = ZoneInfo("America/Chicago")
# Same current-fix window as setup_record_location.js; stored evidence stays intact.
GPS_CURRENT_MS = 15000
TEMPLATE = Path(__file__).with_name("material_status_report.jinja2")


def chicago_time(value: object) -> str:
    if value is None:
        return "Not recorded"
    if isinstance(value, str):
        value = datetime.fromisoformat(value.replace("Z", "+00:00"))
    return value.astimezone(CHICAGO).strftime("%m/%d/%Y %H:%M:%S %Z")


def gps_text(row: dict) -> str:
    if row.get("gps_latitude") is None or row.get("gps_longitude") is None:
        return "No GPS recorded"
    text = f"GPS {Decimal(str(row['gps_latitude'])):.6f}, {Decimal(str(row['gps_longitude'])):.6f}"
    if row.get("gps_accuracy_m") is not None:
        feet = Decimal(str(row["gps_accuracy_m"])) / Decimal("0.3048")
        text += f" ±{feet:.0f} ft"
    if row.get("gps_quality") in {"QUESTIONABLE", "BAD"}:
        text += f" [{row['gps_quality']}]"
    if row.get("gps_fix_age_ms") is not None and row["gps_fix_age_ms"] > GPS_CURRENT_MS:
        text += " [STALE FIX]"
    return text


def movement_picture(repository, session_id: int) -> dict:
    """Use event effects for historical membership, not today's assigned count."""
    with repository.connect() as conn:
        conn.set_session(readonly=True, isolation_level="REPEATABLE READ")
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SET LOCAL statement_timeout = '30s'")
            cur.execute("SET LOCAL lock_timeout = '3s'")
            cur.execute("""
                SELECT current_database() AS database_name,
                       transaction_timestamp() AS generated_at,
                       coalesce(max(setup_movement_event_id),0) AS through_event_id
                FROM ops.setup_movement_event WHERE setup_session_id = %s
            """, (session_id,))
            metadata = dict(cur.fetchone())
            cur.execute("""
                SELECT e.setup_movement_event_id, e.event_type, e.container_id,
                       c.description AS container_name, e.occurred_at, e.received_at,
                       e.destination_stage_id, s.stage_key, s.stage_name,
                       e.destination_location_note, e.gps_latitude, e.gps_longitude,
                       e.gps_accuracy_m, e.gps_quality, e.gps_fix_age_ms,
                       e.capture_method, e.offline_captured,
                       e.captured_operator_email, e.notes,
                       med.display_id, d.display_name, med.movement_effect
                FROM ops.setup_movement_event e
                LEFT JOIN ref.container c ON c.container_id=e.container_id
                LEFT JOIN ref.stage s ON s.stage_id=e.destination_stage_id
                LEFT JOIN ops.setup_movement_event_display med USING (setup_movement_event_id)
                LEFT JOIN ref.display d ON d.display_id=med.display_id
                WHERE e.setup_session_id=%s
                ORDER BY e.occurred_at,e.setup_movement_event_id,med.display_id
            """, (session_id,))
            effect_rows = [dict(row) for row in cur.fetchall()]
            cur.execute("""
                SELECT cs.container_id, c.description AS container_name,
                       ct.container_type_name, c.location_code AS home_location_code,
                       cs.last_movement_event_id, cs.movement_status,
                       cs.current_stage_id, s.stage_key, s.stage_name,
                       cs.current_location_note
                FROM ops.setup_container_state cs
                JOIN ref.container c USING (container_id)
                LEFT JOIN ref.container_type ct USING (container_type_id)
                LEFT JOIN ref.stage s ON s.stage_id=cs.current_stage_id
                WHERE cs.setup_session_id=%s ORDER BY cs.container_id
            """, (session_id,))
            containers = [dict(row) for row in cur.fetchall()]
            cur.execute("""
                SELECT d.display_id, d.display_name, d.container_id,
                       coalesce(ds.position_mode,CASE WHEN d.container_id IS NULL
                         THEN 'NO_ASSIGNED_CONTAINER' ELSE 'WITH_CONTAINER' END) AS position_mode,
                       ds.last_movement_event_id, ds.current_stage_id,
                       s.stage_key, s.stage_name, ds.current_location_note
                FROM ref.display d
                JOIN ref.display_status st USING (display_status_id)
                LEFT JOIN ops.setup_display_state ds
                  ON ds.display_id=d.display_id AND ds.setup_session_id=%s
                LEFT JOIN ref.stage s ON s.stage_id=ds.current_stage_id
                WHERE upper(st.display_status_name)='ACTIVE'
                ORDER BY d.display_name,d.display_id
            """, (session_id,))
            displays = [dict(row) for row in cur.fetchall()]
    return {**metadata, "effect_rows": effect_rows, "containers": containers, "displays": displays}


def report_context(material: dict, picture: dict, since_event_id: int) -> dict:
    """Keep actual destination, prior name and planned Stage separate."""
    events = {}
    for row in picture["effect_rows"]:
        event_id = row["setup_movement_event_id"]
        event = events.setdefault(event_id, {**row, "effects": [], "unloaded_names": []})
        if row.get("display_id") is not None:
            effect = {k: row.get(k) for k in ("display_id", "display_name", "movement_effect")}
            event["effects"].append(effect)
            if effect["movement_effect"] == "UNLOADED":
                event["unloaded_names"].append(effect["display_name"] or "Unnamed Display")
    # Event IDs indicate receipt order. Observation order may differ after sync.
    ordered = sorted(events.values(), key=lambda e: (e["occurred_at"], e["setup_movement_event_id"]))
    for event in ordered:
        event["new_receipt"] = since_event_id > 0 and event["setup_movement_event_id"] > since_event_id
        event["review_required"] = "contents_review_required=true" in (event.get("notes") or "")
        event["observed"] = chicago_time(event.get("occurred_at"))
        event["received"] = chicago_time(event.get("received_at"))
        event["gps"] = gps_text(event)
    containers = []
    for state in picture["containers"]:
        history = [e for e in ordered if e.get("container_id") == state["container_id"]]
        latest = events.get(state.get("last_movement_event_id"), {})
        # Match the existing C095 continuity rule: prior name is context only.
        prior_name = None
        for event in history:
            if latest and (event["occurred_at"],event["setup_movement_event_id"]) > (latest["occurred_at"],latest["setup_movement_event_id"]):
                continue
            if event["event_type"] == "RETURNED":
                prior_name = None
            elif (event.get("destination_location_note") or "").strip():
                prior_name = event["destination_location_note"]
        assigned = [{**d, "gps": gps_text(events.get(d.get("last_movement_event_id"), {}))}
                    for d in picture["displays"] if d.get("container_id") == state["container_id"]]
        containers.append({**state, "history": history, "latest": latest,
                           "prior_named_context": prior_name,
                           "attached": [d for d in assigned if d["position_mode"] == "WITH_CONTAINER"],
                           "detached": [d for d in assigned if d["position_mode"] == "DETACHED"],
                           "review_flags": [e for e in history if e["review_required"]]})
    def location_group(row):
        latest = row["latest"]
        if latest.get("event_type") == "RETURNED" and row.get("current_location_note"):
            return "Returned — " + row["current_location_note"]
        if latest.get("stage_name") or latest.get("destination_location_note"):
            return " — ".join(str(latest.get(k) or "") for k in ("stage_key","stage_name","destination_location_note") if latest.get(k))
        if latest.get("gps_latitude") is not None and latest.get("gps_longitude") is not None:
            return "GPS only" + (f" / prior named context {row['prior_named_context']}" if row["prior_named_context"] else " / no named reference")
        return "Picked / movement status only — no location in latest event"
    for row in containers:
        row["location_group"] = location_group(row)
    containers.sort(key=lambda c: (c["location_group"], c["container_id"]))
    return {"material": material, **picture, "events": ordered,
            "containers": containers, "since_event_id": since_event_id,
            "new_events": [e for e in ordered if e["new_receipt"]],
            "direct_events": [e for e in ordered if e.get("container_id") is None],
            "generated": chicago_time(picture.get("generated_at")),
            "gps_text": gps_text}


def render_report(material: dict, picture: dict, since_event_id: int) -> str:
    return render_template_string(TEMPLATE.read_text(encoding="utf-8"),
                                  **report_context(material,picture,since_event_id))
