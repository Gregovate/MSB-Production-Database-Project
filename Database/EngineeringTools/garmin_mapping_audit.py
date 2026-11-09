#!/usr/bin/env python3
"""#171: read-only master GPX Type/Garmin symbol evidence, never infer approved mapping."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import xml.etree.ElementTree as ET


def inventory(source: Path, png_folder: Path):
    raw = source.read_bytes()
    root = ET.fromstring(raw)
    if root.tag != "{http://www.topografix.com/GPX/1/1}gpx":
        raise ValueError("GPX 1.1 source required")
    ns = "{http://www.topografix.com/GPX/1/1}"
    present_png = sorted(p.name for p in png_folder.glob("*.png") if p.is_file())
    groups = defaultdict(lambda: {"total": 0, "gps_symbols": Counter(), "sample_waypoints": []})
    for wpt in root.findall(ns + "wpt"):
        kind = wpt.findtext(ns + "type") or "(no Type)"
        sym = wpt.findtext(ns + "sym") or "(no GPS Symbol)"
        label = wpt.findtext(ns + "name") or "(unnamed)"
        item = groups[kind]
        item["total"] += 1
        item["gps_symbols"][sym] += 1
        if len(item["sample_waypoints"]) < 6:
            item["sample_waypoints"].append({"name": label, "sym": sym})
    return {"source": str(source), "waypoint_count": sum(d["total"] for d in groups.values()),
            "types": [{"type": typ, "waypoints": val["total"],
                       "gps_symbols": dict(val["gps_symbols"]),
                       "samples": val["sample_waypoints"]}
                      for typ, val in sorted(groups.items())],
            "approved_png_names_available": present_png,
            "action": "REVIEW REQUIRED: no Type-to-Garmin mapping approved or GPX changed"}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--master", required=True, type=Path)
    parser.add_argument("--png", required=True, type=Path)
    args = parser.parse_args(argv)
    print(json.dumps(inventory(args.master, args.png), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
