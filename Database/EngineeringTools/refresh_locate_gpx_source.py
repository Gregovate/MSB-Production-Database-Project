"""#171: reconcile accepted ExpertGPS map-label waypoints with existing Setup map.

This writes a SEPARATE candidate HTML and JSON receipt only after every existing
mapped point and track is uniquely accounted for. It cannot deploy or overwrite
the current app, the shared GPX, or an existing report. Network evidence must be
rebuilt independently from the accepted FLW before this map candidate can ship.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, str(Path(__file__).resolve().parent))
from site_source_sync import extract_gpx, sha256

START = "const data="
END = ";data.features.push"
GPX = "{http://www.topografix.com/GPX/1/1}"


def separate_map(html: str):
    start = html.find(START)
    if start < 0 or html.find(START, start + 1) >= 0:
        raise ValueError("Missing/duplicate embedded map data anchor")
    end = html.find(END, start)
    if end < 0 or html.find(END, end + 1) >= 0:
        raise ValueError("Missing/duplicate embedded map end anchor")
    geo = json.loads(html[start + len(START):end])
    if geo.get("type") != "FeatureCollection":
        raise ValueError("Expected GeoJSON FeatureCollection")
    return start + len(START), end, geo


def distance_ft(a, b):
    # For identity screening only; not surveying or ground-penetration clearance.
    lon_a, lat_a = a
    lon_b, lat_b = b
    return math.hypot((lat_a - lat_b) * 364000,
                      (lon_a - lon_b) * math.cos(math.radians(43.78)) * 364000)


def source_features(gpx_path: Path):
    extracted = extract_gpx(gpx_path)
    root = ET.parse(gpx_path).getroot()
    raw_waypoints = root.findall(GPX + "wpt")
    if len(raw_waypoints) != len(extracted["waypoints"]):
        raise ValueError("Unexpected GPX waypoint extraction mismatch")
    points = []
    for w, raw in zip(extracted["waypoints"], raw_waypoints):
        points.append({
            "map_label": w["map_label"],
            "garmin_name": w["garmin_name"],
            "coords": [float(w["longitude"]), float(w["latitude"])],
            "type": w["type"],
            "cmt": w["comment"],
            "desc": w["description"],
            "time": w["source_time"],
            "sym": raw.findtext(GPX + "sym", default=""),
        })
    lines = []
    for trk in extracted["tracks"]:
        segments = [[[float(p["lon"]), float(p["lat"])] for p in seg]
                    for seg in trk["segments"]]
        if not segments or any(len(seg) < 2 for seg in segments):
            raise ValueError("Track without usable line geometry: " + trk["name"])
        lines.append({
            "name": trk["name"],
            "type": trk["type"],
            "desc": trk["description"],
            "geometry": {"type": "LineString", "coordinates": segments[0]}
                        if len(segments) == 1 else
                        {"type": "MultiLineString", "coordinates": segments}
        })
    return extracted["sha256"], points, lines


def rebuild(html: str, gpx_path: Path, *, max_distance_ft=1.5):
    begin, end, geo = separate_map(html)
    source_hash, current, tracks = source_features(gpx_path)
    prior_points = [f for f in geo["features"] if f["geometry"]["type"] == "Point"]
    prior_tracks = [f for f in geo["features"]
                    if f["geometry"]["type"] in ("LineString", "MultiLineString")]
    if len(prior_tracks) != len(tracks):
        raise ValueError("GPX track count changed; stable network route IDs require review")
    if any(f["properties"]["id"] != f"t{i}" for i, f in enumerate(prior_tracks)):
        raise ValueError("Existing track IDs/order changed; route reconciliation required")
    if any(f["properties"]["id"] != f"w{i}" for i, f in enumerate(prior_points)):
        raise ValueError("Existing waypoint IDs/order changed; reviewed identity map required")

    icon_by_type = {}
    for f in prior_points:
        props = f["properties"]
        icon_by_type.setdefault(props.get("type"), props.get("marker_url"))

    claimed = set()
    name_edits = []
    new_labels = []
    conflicts = []
    updated_points = []
    for item in current:
        distances = sorted(
            ((distance_ft(item["coords"], f["geometry"]["coordinates"]), i)
             for i, f in enumerate(prior_points) if i not in claimed),
            key=lambda x: (x[0], x[1]))
        close = [v for v in distances if v[0] <= max_distance_ft]
        if len(close) > 1:
            # Coincident equipment identities are distinct. Exact old names may
            # disambiguate; otherwise stop rather than merge two waypoints.
            exact = [v for v in close
                     if prior_points[v[1]]["properties"]["name"].casefold()
                     in (item["map_label"].casefold(), item["garmin_name"].casefold())]
            close = exact if len(exact) == 1 else close
        if len(close) > 1:
            conflicts.append({"map_label": item["map_label"],
                              "reason": "Ambiguous co-located source features",
                              "candidate_old_labels": [
                                  prior_points[i]["properties"]["name"] for _, i in close]})
            continue
        if close:
            distance, index = close[0]
            claimed.add(index)
            feature = json.loads(json.dumps(prior_points[index]))
            old_name = feature["properties"]["name"]
            if old_name != item["map_label"]:
                name_edits.append({"feature_id": feature["properties"]["id"],
                                   "old": old_name, "corrected": item["map_label"]})
        else:
            # Newly added GPX waypoint. Never reuse an existing reference ID.
            index = None
            feature = {"type": "Feature", "geometry": {"type": "Point"},
                       "properties": {"id": f"w{len(prior_points) + len(new_labels)}"}}
            new_labels.append(item["map_label"])
        props = feature["properties"]
        props.update(name=item["map_label"], type=item["type"], sym=item["sym"],
                     cmt=item["cmt"], desc=item["desc"], time=item["time"])
        if index is None:
            if item["type"] not in icon_by_type:
                conflicts.append({"map_label": item["map_label"],
                                  "reason": "No reviewed icon/type mapping"})
            props["marker_url"] = icon_by_type.get(item["type"])
        feature["geometry"]["coordinates"] = item["coords"]
        updated_points.append(feature)

    unmatched = [f["properties"]["name"] for i, f in enumerate(prior_points)
                 if i not in claimed]
    if unmatched:
        conflicts.append({"reason": "Old mapped points lack unique GPX positions",
                          "old_labels": unmatched})
    for i, (old, new) in enumerate(zip(prior_tracks, tracks)):
        old_geometry = old["geometry"]
        new_geometry = new["geometry"]
        original_segments = ([old_geometry["coordinates"]]
                             if old_geometry["type"] == "LineString"
                             else old_geometry["coordinates"])
        revised_segments = ([new_geometry["coordinates"]]
                            if new_geometry["type"] == "LineString"
                            else new_geometry["coordinates"])
        if len(original_segments) != len(revised_segments) or any(
            distance_ft(a[0], b[0]) > max_distance_ft or
            distance_ft(a[-1], b[-1]) > max_distance_ft
            for a, b in zip(original_segments, revised_segments)
        ):
            conflicts.append({"track_id": f"t{i}", "reason": "Track geometry/ordering changed",
                              "old_name": old["properties"]["name"],
                              "new_name": new["name"]})
            continue
        old["geometry"] = new_geometry
        old["properties"].update(name=new["name"], type=new["type"],
                                 desc=new["desc"])

    counts = {"old_map_waypoints": len(prior_points),
              "gpx_waypoints": len(current),
              "old_map_tracks": len(prior_tracks),
              "gpx_tracks": len(tracks),
              "corrected_names": len(name_edits),
              "new_waypoints": len(new_labels),
              "conflicts": len(conflicts)}
    receipt = {"gpx_sha256": source_hash, "counts": counts,
               "name_changes": name_edits, "new_labels": new_labels,
               "conflicts": conflicts, "network_status": "STALE_PENDING_CORRECTED_FLW"}
    if conflicts:
        return None, receipt

    # Preserve the original map UI and every feature id; append new source
    # waypoint features with new stable IDs, never touch Workshop or #88 assets.
    old_ids = {f["properties"]["id"] for f in prior_points}
    updated_points.sort(key=lambda f: (
        0 if f["properties"]["id"] in old_ids else 1,
        int(f["properties"]["id"][1:])))
    geo["features"] = updated_points + prior_tracks
    refreshed = html[:begin] + json.dumps(geo, separators=(",", ":"), ensure_ascii=False) + html[end:]
    # Never present this GPX-only refresh as a complete corrected network map.
    # Put the warning into the actual candidate UI, not solely in a JSON report.
    warning = ('<p class="banner" id="source-refresh-warning">'
               'CANDIDATE ONLY: waypoint/track GPX refreshed; LinkIQ network '
               'evidence is still the older snapshot. Do not deploy as current.'
               '</p>')
    marker = '<div id="network-status"'
    if refreshed.count(marker) != 1:
        raise ValueError("Cannot attach source-staleness warning to current map UI")
    refreshed = refreshed.replace(marker, warning + marker, 1)
    # Do not leave the October 10 source fingerprint as though it described
    # this corrected GPX. The candidate About panel must show its real source.
    refreshed, source_replacements = re.subn(
        r'GPX snapshot [0-9a-f]{16}', 'GPX candidate SHA ' + source_hash[:16],
        refreshed
    )
    if source_replacements != 1:
        raise ValueError("Cannot update the map's old GPX snapshot fingerprint")
    return refreshed, receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--map", type=Path, required=True)
    parser.add_argument("--gpx", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--output-map", type=Path)
    args = parser.parse_args()
    for out in (args.report, args.output_map):
        if out and out.resolve() in (args.map.resolve(), args.gpx.resolve()):
            parser.error("Refusing to overwrite source map or GPX")
        if out and out.exists():
            parser.error(f"Refusing to overwrite existing output: {out}")
    before = sha256(args.gpx)
    refreshed, receipt = rebuild(args.map.read_text(encoding="utf-8"), args.gpx)
    if sha256(args.gpx) != before:
        parser.error("Source GPX changed during reconciliation; stop")
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(receipt, indent=2, ensure_ascii=False) + "\n",
                           encoding="utf-8")
    if receipt["conflicts"]:
        raise SystemExit("Map/GPX identity conflicts; review report. No map written.")
    if args.output_map:
        args.output_map.parent.mkdir(parents=True, exist_ok=True)
        args.output_map.write_text(refreshed, encoding="utf-8")
    print(json.dumps(receipt["counts"], indent=2))
    if args.output_map:
        print("REFERENCE CANDIDATE WRITTEN. NETWORK JSON IS STALE; NOT DEPLOYABLE.")


if __name__ == "__main__":
    main()
