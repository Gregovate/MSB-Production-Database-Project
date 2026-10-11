"""Check what the browser actually receives for the existing Park Map.

Read-only localhost inspection; never requests Production URLs or writes anything.
A passing source builder is not proof that http.server serves its NEW output.
"""
from __future__ import annotations
import argparse
import json
import re
from urllib.parse import urlsplit
from urllib.request import urlopen


def inspect_served_html(html: str) -> dict:
    found = re.search(r"const data=(.*?);(?:data.features.push|const map=)",
                      html, flags=re.DOTALL)
    if not found:
        raise ValueError("No recognizable embedded GPX GeoJSON in served page")
    data = json.loads(found.group(1))
    features = data.get("features", [])
    points = [f for f in features if f.get("geometry", {}).get("type") == "Point"]
    tracks = [f for f in features if f.get("geometry", {}).get("type") in
              ("LineString", "MultiLineString")]
    real = [f for f in points if f.get("properties", {}).get("name") == "Workshop"
            and f.get("properties", {}).get("type") == "Waypoint"]
    wrong = ("temporary-workshop" in html
             or "Temporary operator-provided reference, October 8, 2026" in html)
    preview = "SOURCE-CORRECTION LOCAL REVIEW" in html
    verified = (
        len(real) == 1
        and real[0]["geometry"]["coordinates"] == [-87.73321549, 43.77840207]
        and not wrong and preview
        and len(points) == 233 and len(tracks) == 181
    )
    return {
        "result": "CORRECTED_GPXP_PREVIEW" if verified else "STALE_OR_WRONG_MAP",
        "expected_real_workshop": "Workshop / Waypoint",
        "real_workshop_count": len(real),
        "real_workshop_coordinates": (real[0]["geometry"]["coordinates"]
                                       if len(real) == 1 else None),
        "obsolete_temporary_workshop_present": wrong,
        "source_correction_banner_present": preview,
        "gpx_points": len(points),
        "gpx_tracks": len(tracks),
        "next_action": (
            "Keep reviewing the correct current localhost preview"
            if verified else
            "Stop the old localhost server, create a new timestamped source "
            "preview using the newest #319 stager, and start http.server "
            "against THAT output folder."
        ),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default=
                        "http://127.0.0.1:8898/setup/locate/?view=fieldwiring")
    args = parser.parse_args()
    u = urlsplit(args.url)
    if u.scheme != "http" or u.hostname not in ("127.0.0.1", "localhost"):
        parser.error("Only a local HTTP preview is allowed; do not probe Production")
    with urlopen(args.url, timeout=7) as response:
        page = response.read().decode("utf-8-sig")
    outcome = inspect_served_html(page)
    print(json.dumps(outcome, indent=2))
    if outcome["result"] != "CORRECTED_GPXP_PREVIEW":
        raise SystemExit("WRONG OR STALE WORKSHOP MAP IS BEING SERVED: NOT ACCEPTED")


if __name__ == "__main__":
    main()
