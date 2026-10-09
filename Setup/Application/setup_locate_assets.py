"""Read-only map adapter for the accepted #88 snapshot. No history inference."""
from math import isfinite


def geographic_position(event):
    """Reject missing/invalid pairs; RETURNED is storage, never a park pin."""
    if event.get("event_type") == "RETURNED":
        return None
    try:
        lat, lon = float(event["gps_latitude"]), float(event["gps_longitude"])
    except (KeyError, TypeError, ValueError):
        return None
    if not (isfinite(lat) and isfinite(lon) and -90 <= lat <= 90 and -180 <= lon <= 180):
        return None
    return [lat, lon]


def locate_assets(picture):
    events = {e["setup_movement_event_id"]: e for e in picture["effect_rows"]}
    fields = ("setup_movement_event_id", "event_type", "occurred_at", "received_at",
              "gps_latitude", "gps_longitude", "gps_accuracy_m", "gps_quality",
              "gps_fix_age_ms", "capture_method", "offline_captured",
              "destination_location_note", "stage_key", "stage_name")

    def observation(event):
        return {k: event.get(k) for k in fields}

    containers = []
    for state in picture["containers"]:
        event = events.get(state.get("last_movement_event_id"), {})
        assigned = [d for d in picture["displays"] if d.get("container_id") == state["container_id"]]
        containers.append({"container_id": state["container_id"],
                           "name": state.get("container_name"),
                           "position": geographic_position(event),
                           "observation": observation(event),
                           "movement_status": state.get("movement_status"),
                           "current_location_note": state.get("current_location_note"),
                           "home_location_code": state.get("home_location_code"),
                           "load_state": "UNKNOWN",
                           "review_event_ids": sorted({e["setup_movement_event_id"] for e in picture["effect_rows"]
                               if e.get("container_id") == state["container_id"]
                               and "contents_review_required=true" in (e.get("notes") or "")}),
                           "contents": [{"display_name": d["display_name"],
                                         "position_mode": d["position_mode"]} for d in assigned],
                           "uncertainty": "Physical load unconfirmed; associations are recorded state, not a contents check."})
    displays = []
    for state in picture["displays"]:
        if state["position_mode"] == "WITH_CONTAINER":
            continue
        event = events.get(state.get("last_movement_event_id"), {})
        displays.append({"display_id": state["display_id"], "name": state["display_name"],
                         "position_mode": state["position_mode"],
                         "position": geographic_position(event), "observation": observation(event)})
    return {"generated_at": picture["generated_at"], "through_event_id": picture["through_event_id"],
            "containers": containers, "displays": displays,
            "scope": "All reference Containers and active independent Displays. No prior-GPS fallback."}
