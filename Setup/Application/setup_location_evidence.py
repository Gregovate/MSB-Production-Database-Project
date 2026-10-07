"""Describe recorded WGS84 observations using the existing launch waypoints.

Nearest-reference information is derived presentation only. It does not assign
a Stage, confirm placement, rewrite observations, or change reference anchors.
"""
from functools import lru_cache
import json
import math
from pathlib import Path
from typing import Any


def _coordinate(value: Any, limit: float) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    try:
        number = float(value)
    except (TypeError, ValueError, OverflowError):
        return None
    return number if math.isfinite(number) and abs(number) <= limit else None


@lru_cache(maxsize=1)
def _reference_set() -> dict[str, Any]:
    """The exact candidate's versioned file is immutable for this process."""
    try:
        data = json.loads(Path(__file__).with_name("setup_location_references.json").read_text())
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


def nearest_recorded_reference(latitude: Any, longitude: Any) -> dict[str, Any] | None:
    latitude = _coordinate(latitude, 90)
    longitude = _coordinate(longitude, 180)
    if latitude is None or longitude is None:
        return None
    references = _reference_set()
    points = references.get("points")
    if not isinstance(points, list):
        return None
    nearest = None
    for point in points:
        if not isinstance(point, dict) or not str(point.get("name") or "").strip():
            continue
        lat = _coordinate(point.get("latitude"), 90)
        lon = _coordinate(point.get("longitude"), 180)
        if lat is None or lon is None:
            continue
        # Match Record Location's spherical distance calculation in feet.
        dlat = math.radians(lat - latitude)
        dlon = math.radians(lon - longitude)
        a = (math.sin(dlat / 2) ** 2
             + math.cos(math.radians(latitude)) * math.cos(math.radians(lat))
             * math.sin(dlon / 2) ** 2)
        a = min(1.0, max(0.0, a))
        distance = 20902260.958 * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        if nearest is None or distance < nearest["distance_ft"]:
            nearest = {
                "reference_id": point.get("reference_id"),
                "name": str(point["name"]).strip(),
                "distance_ft": distance,
                "reference_set_version": references.get("version"),
            }
    return nearest
