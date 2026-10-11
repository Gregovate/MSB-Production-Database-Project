"""Stage the EXISTING Setup Park Map with corrected GPX/LinkIQ source snapshots.

Source-only browser review on localhost. Does not write the shared GPX/FLW,
the repository's live map assets, PostgreSQL, or any Production service.
Never label historical schematic/LOR data or #88 assets as current.
"""
from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil


ASSETS = (
    "setup_locate_search.js",
    "setup_locate_networks.js",
    "setup_locate_assets.js",
    "container-loaded.svg",
    "container-partial.svg",
    "container-empty.svg",
    "container-unknown.svg",
)
OLD_BANNER = (
    "CANDIDATE ONLY: waypoint/track GPX refreshed; LinkIQ network "
    "evidence is still the older snapshot. Do not deploy as current."
)
NEW_BANNER = (
    "SOURCE-CORRECTION LOCAL REVIEW — GPX and LinkIQ sources refreshed; "
    "old schematic/LOR evidence remains unreviewed. Not deployed. "
    "Seasonal assets need the live Setup API."
)
GEO_PATTERN = r"const data=(.*?);data\.features\.push"


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def assert_hash(path: Path, fingerprint: str, label: str) -> None:
    if not path.is_file():
        raise ValueError(f"Missing {label}: {path}")
    if digest(path).lower() != str(fingerprint).lower():
        raise ValueError(f"{label} does not match saved SHA-256: {path}")


def build_review(*, config: Path, review_folder: Path,
                 repo: Path, output_root: Path) -> dict:
    if output_root.exists():
        raise ValueError(f"Refusing to overwrite existing preview: {output_root}")

    local = load_json(config)
    gpx = Path(local["GPX"])
    flw = Path(local["FLW"])
    assert_hash(gpx, local["GPX_SHA256"], "approved GPX")
    assert_hash(flw, local["FLW_SHA256"], "approved LinkIQ FLW")
    gpshash = local["GPX_SHA256"].lower()
    flwhash = local["FLW_SHA256"].lower()

    files = {
        "map": review_folder / "park-map-corrected-candidate.html",
        "map_report": review_folder / "park-map-correction-report.json",
        "network": review_folder / "park-network-corrected-candidate.json",
        "network_report": review_folder / "park-network-correction-report.json",
    }
    for name, path in files.items():
        if not path.is_file():
            raise ValueError(f"Missing {name} output: {path}")

    map_report = load_json(files["map_report"])
    network_report = load_json(files["network_report"])
    net = load_json(files["network"])
    if (map_report.get("gpx_sha256", "").lower() != gpshash or
            network_report.get("source_sha256", "").lower() != flwhash or
            net.get("source_sha256", "").lower() != flwhash):
        raise ValueError("Candidate receipts do not match saved source fingerprints")

    counts = map_report["counts"]
    required = {
        "old_map_waypoints": 229, "gpx_waypoints": 233,
        "old_map_tracks": 181, "gpx_tracks": 181,
        "corrected_names": 14, "new_waypoints": 4,
        "coordinate_matches": 229, "conflicts": 0,
    }
    for field, expected in required.items():
        if counts.get(field) != expected:
            raise ValueError(f"Map report {field} differs from reviewed {expected}")

    ncounts = network_report["counts"]
    needed = {
        "saved_test_uuids": 476, "source_project_rows": 684,
        "duplicate_project_appearances": 208,
        "cables_with_parseable_active_names": 455,
        "tests_requiring_name_or_delete_review": 21,
        "source_deleted_uuid_count": 7,
        "mapped_candidate_tracks": 32, "unresolved_tracks": 149,
    }
    for field, expected in needed.items():
        if ncounts.get(field) != expected:
            raise ValueError(f"LinkIQ report {field} differs from reviewed {expected}")
    cable_rows = net["cables"] + net["review_records"]
    uuids = [item["source_id"] for item in cable_rows]
    route_ids = [r["route_id"] for r in net["mapped_routes"] + net["unresolved_routes"]]
    if (len(uuids) != 476 or len(set(uuids)) != 476 or
            sum(int(item["project_appearances"]) for item in cable_rows) != 684 or
            len(route_ids) != 181 or len(set(route_ids)) != 181):
        raise ValueError("Corrected LinkIQ source conservation failed")
    if (net.get("schematic_status") != "PRIOR_DRAWIO_SNAPSHOT_UNREVIEWED" or
            net.get("lor_status") != "PRIOR_LOR_SNAPSHOT_UNREVIEWED"):
        raise ValueError("Stale schematic/LOR warnings absent from source JSON")

    html = files["map"].read_text(encoding="utf-8")
    matches = list(re.finditer(GEO_PATTERN, html, flags=re.DOTALL))
    if len(matches) != 1:
        raise ValueError("Expected exactly one embedded GeoJSON map data block")
    geo = json.loads(matches[0].group(1))
    geom_counts = Counter(f["geometry"]["type"] for f in geo["features"])
    if geom_counts["Point"] != 233 or sum(
        geom_counts[k] for k in ("LineString", "MultiLineString")) != 181:
        raise ValueError("Candidate rendered map point/track counts do not agree")
    labels = {f["properties"]["name"] for f in geo["features"]
              if f["geometry"]["type"] == "Point"}
    for name in ("PANEL A5-00", "A5-07/09", "42-02S"):
        if name not in labels:
            raise ValueError(f"Corrected map label not present: {name}")
    # The operator has a real ExpertGPS Workshop waypoint. Do not append
    # the one-off October 8 temporary Workshop observation as a second pin.
    workshop = [f for f in geo["features"]
                if f["geometry"]["type"] == "Point"
                and f["properties"].get("name") == "Workshop"
                and f["properties"].get("type") == "Waypoint"]
    if len(workshop) != 1:
        raise ValueError("Expected one authoritative GPX Workshop / Waypoint")
    # The Home Container anchor is a separate #88 storage-state projection.
    # It must be preserved, and it already agrees with the corrected GPX point.
    # Do not let removing the obsolete viewer-only marker disrupt it.
    home_ref_file = repo / "Setup" / "Application" / "setup_workshop_reference.json"
    if not home_ref_file.is_file():
        raise ValueError("Missing #88 Workshop home location reference")
    home_anchor = load_json(home_ref_file)["map_coordinates"]
    lon, lat = workshop[0]["geometry"]["coordinates"]
    separation_ft = ((lat - home_anchor["latitude"]) ** 2 * 364000**2
                     + ((lon - home_anchor["longitude"]) * 364000 * 0.722)**2) ** 0.5
    if separation_ft > 0.2:
        raise ValueError("Correct GPX Workshop location disagrees with #88 Home anchor")
    tower = [f for f in geo["features"]
             if f["geometry"]["type"] == "Point"
             and f["properties"].get("name") == "LB WiFi Antenna"]
    if len(tower) != 1 or tower[0]["properties"].get("type") != "Tower":
        raise ValueError("Expected GPX LB WiFi Antenna / Tower; do not replace icon/type")
    if tower[0]["properties"].get("time") != "2026-10-10T18:40:42.586Z":
        raise ValueError("LB WiFi Antenna GPX source timestamp mismatch")

    # Explicitly remove only the known legacy injected map point, leaving
    # the authored real GPX Workshop at its real source coordinates. This
    # removes the source-time false double pin without changing the source
    # GPX, persistent waypoints or network route IDs.
    injection = re.compile(
        r";data\.features\.push\((\{.*?\})\);const map=", flags=re.DOTALL
    )
    injections = list(injection.finditer(html))
    if len(injections) != 1:
        raise ValueError("Expected exactly one historical injected Workshop marker")
    legacy = json.loads(injections[0].group(1))
    if legacy.get("properties", {}).get("id") != "temporary-workshop":
        raise ValueError("Unexpected extra map feature injection; review before removal")
    if (legacy.get("properties", {}).get("name") != "Workshop"
            or legacy.get("properties", {}).get("type") != "Workshop"
            or "Temporary operator-provided reference, October 8, 2026"
               not in legacy.get("properties", {}).get("desc", "")):
        raise ValueError("Obsolete marker details are unrecognized; do not remove")
    legacy_lon, legacy_lat = legacy["geometry"]["coordinates"]
    if not (-87.73316 < legacy_lon < -87.73314
            and 43.77846 < legacy_lat < 43.77849):
        raise ValueError("Unexpected temporary Workshop coordinates; stop")
    html = (html[:injections[0].start()] + ";const map="
            + html[injections[0].end():])
    if OLD_BANNER not in html or html.count(OLD_BANNER) != 1:
        raise ValueError("Expected one original GPX-only warning")
    if "GPX candidate SHA " + gpshash[:16] not in html:
        raise ValueError("Map About panel lacks approved corrected GPX hash")
    html = html.replace(OLD_BANNER, NEW_BANNER)
    html = "<!-- MSB SOURCE PREVIEW: GPX Workshop / Waypoint retained; October 8 Workshop / Workshop excluded -->\n" + html
    if "temporary-workshop" in html:
        raise ValueError("Legacy temporary Workshop reference remains in candidate HTML")

    app = repo / "Setup" / "Application"
    for asset in ASSETS:
        if not (app / asset).is_file():
            raise ValueError(f"Missing shipped Setup map asset: {asset}")
    network_js = (app / "setup_locate_networks.js").read_text(encoding="utf-8")
    if ("PRIOR_DRAWIO_SNAPSHOT_UNREVIEWED" not in network_js or
            "PRIOR_LOR_SNAPSHOT_UNREVIEWED" not in network_js):
        raise ValueError("Candidate network JS does not disclose stale evidence")

    root = output_root / "setup" / "locate"
    assets = root / "assets"
    assets.mkdir(parents=True)
    (root / "index.html").write_text(html, encoding="utf-8")
    (assets / "setup_locate_networks.json").write_text(
        json.dumps(net, ensure_ascii=False, indent=2), encoding="utf-8")
    for asset in ASSETS:
        shutil.copy2(app / asset, assets / asset)

    manifest = {
        "status": "LOCAL_SOURCE_PREVIEW_NOT_DEPLOYED",
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "gpx_sha256": gpshash, "flw_sha256": flwhash,
        "map_file_sha256": digest(files["map"]),
        "network_file_sha256": digest(files["network"]),
        "map_counts": counts, "linkiq_counts": ncounts,
        "workshop_source": "GPX Label on Map / Workshop / Waypoint",
        "legacy_temporary_workshop_removed": True,
        "workshop_gpx_coordinate": workshop[0]["geometry"]["coordinates"],
        "container_home_anchor_coordinate": [
            home_anchor["longitude"], home_anchor["latitude"]],
        "workshop_home_anchor_separation_ft": round(separation_ft, 4),
        "operator_findings": [
            "Waypoint names visually accepted in existing Park Map preview",
            "LB WiFi Antenna remains Tower; icon repairs are a different workstream",
            "AUX-I still has missing route segments; other two reported gaps now resolve",
        ],
        "uncertainties": [
            "Routes are GPX/LinkIQ correspondence candidates; not verified buried cabling",
            "Schematic devices, edges and LOR inventory are retained from older unreviewed snapshots",
            "Seasonal Container/Display API is unavailable in localhost-only preview",
            "Aerial tiles, symbols and Leaflet CDN still require network access",
        ],
        "url_path": "/setup/locate/?view=fieldwiring",
    }
    (output_root / "preview-manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--review-folder", type=Path, required=True)
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    args = parser.parse_args()
    result = build_review(config=args.config, review_folder=args.review_folder,
                          repo=args.repo, output_root=args.output_root)
    print(json.dumps({"status": result["status"],
                      "output_root": str(args.output_root),
                      "map_counts": result["map_counts"],
                      "linkiq_counts": result["linkiq_counts"]}, indent=2))
    print("LOCAL SOURCE PREVIEW READY — NOT DEPLOYED; NOT YET OFFLINE-CAPABLE")


if __name__ == "__main__":
    main()
