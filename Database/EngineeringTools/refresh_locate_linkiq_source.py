"""#171/#319: rebuild existing Park Map's LinkIQ evidence from corrected FLW.

Read-only inputs; separate output and receipt; never write an FLW/GPX or
existing shipped JSON. One row per saved-test UUID, all source appearances
conserved as counts, physical cable identity and route links are UNREVIEWED.
Legacy draw.io/LOR source sections remain explicitly stale, not certified.
"""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import json
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from site_source_sync import extract_flw, sha256
from refresh_locate_gpx_source import separate_map
from reconcile_linkiq_map import parse_name
from reconcile_drawio_map import waypoint_keys, local_xy, geometry_matches


def rebuild_network_source(flw_path: Path, corrected_html: str, prior_source: dict):
    _, _, geo = separate_map(corrected_html)
    features = geo["features"]
    old_points = [f for f in features if f["geometry"]["type"] == "Point"]
    old_lines = [f for f in features if f["geometry"]["type"] in ("LineString", "MultiLineString")]
    if len(old_points) != 233 or len(old_lines) != 181:
        raise ValueError("Expected approved 233-point / 181-track GPX candidate")
    if not all(f["properties"]["id"] == f"t{i}" for i, f in enumerate(old_lines)):
        raise ValueError("GPX route IDs changed; evidence migration requires review")
    if prior_source.get("format_version") != 1:
        raise ValueError("Unexpected previous network evidence structure")
    old_route_ids = {
        v["route_id"] for key in ("mapped_routes", "unresolved_routes")
        for v in prior_source.get(key, [])
    }
    candidate_route_ids = {f["properties"]["id"] for f in old_lines}
    if old_route_ids != candidate_route_ids:
        raise ValueError("Changed/lost route IDs relative to the shipped network source")

    source = extract_flw(flw_path)
    if source["variant_measurement_conflicts"]:
        raise ValueError("Conflicting duplicated tester UUID measurements; review first")
    if source["source_row_count"] != 684 or source["unique_test_count"] != 476:
        raise ValueError("Source baseline differs from 684 rows / 476 distinct UUIDs")

    candidates = defaultdict(list)
    for feature in old_points:
        name = feature["properties"]["name"]
        point = {"id": feature["properties"]["id"], "source_name": name,
                 "xy": local_xy(feature["geometry"]["coordinates"])}
        for key in waypoint_keys(name):
            candidates[key].append(point)
    points = {k: values[0] for k, values in candidates.items() if len(values) == 1}

    parsed = []
    review = []
    for test in source["tests"]:
        appear = test["source_appearances"]
        preferred = appear[0]
        label = test["preferred_display_cable_name"] or ""
        deleted = str(preferred["deleted"] or "").upper() == "YES"
        identified = parse_name(label)
        test_props = {
            "UUID": test["test_uuid"], "CableId": label,
            "LengthF": preferred["length_ft"],
            "TimeSpan": preferred["record_time_span"],
            "TestStatus": preferred["test_status_code"],
            "Standard": preferred["test_standard"],
            "Deleted": preferred["deleted"],
            "Notes": preferred.get("notes") or "",
            "Faceplate": preferred.get("faceplate") or "",
            "OutletId": preferred.get("outlet_id") or "",
        }
        if deleted or identified is None:
            review.append({
                "source_id": test["test_uuid"],
                "attributes": test_props,
                "reason": "SOURCE_DELETED" if deleted else "NAME_REQUIRES_REVIEW",
                "project_appearances": len(appear),
                "physical_cable_identity": "UNREVIEWED",
            })
            continue
        endpoints, network, qualifier = identified
        parsed.append({
            "source_id": test["test_uuid"], "network": network,
            "endpoints": endpoints, "status": "NO_MATCHED_ROUTE",
            "route_ids": [], "test": test_props,
            "attributes": {
                "Cable_ID": label, "Network": network,
                "Waypoint_1": endpoints[0], "Waypoint_2": endpoints[1],
                "Feet": preferred["length_ft"], "Qualifier": qualifier,
            },
            "source_project": test["preferred_project"],
            "project_appearances": len(appear),
            "physical_cable_identity": "UNREVIEWED",
            "drawio_matches": [],  # Original snapshot is not current drawing proof.
        })

    mapped, unresolved = [], []
    for feature in old_lines:
        evidence = geometry_matches(feature, points, parsed)
        ids = {u for paths in evidence.values() for p in paths
               for u in p["cable_source_ids"]}
        geometry = feature["geometry"]
        segs = ([geometry["coordinates"]] if geometry["type"] == "LineString"
                else geometry["coordinates"])
        length = sum(math.dist(local_xy(a), local_xy(b))
                     for segment in segs for a, b in zip(segment, segment[1:]))
        route = {
            "route_id": feature["properties"]["id"],
            "source_name": feature["properties"]["name"],
            "layer": feature["properties"].get("class"),
            "source_properties": feature["properties"],
            "geometry_length_ft": round(length, 1),
        }
        if ids:
            route.update(
                cable_source_ids=sorted(ids), network_evidence=evidence,
                basis="Corrected LinkIQ endpoints + GPS source proximity; "
                      "candidate ONLY, not proven underground cable path")
            mapped.append(route)
        else:
            unresolved.append(route)
        for cable in parsed:
            if cable["source_id"] in ids:
                cable["route_ids"].append(route["route_id"])
                cable["status"] = "ROUTE_CANDIDATE_REVIEW_REQUIRED"

    # Preserve display of previous diagram devices as history, with NO implied
    # correspondence to the newly corrected FLW. Never recertify old matching.
    old_drawio = prior_source.get("drawio_cables", [])
    old_devices = prior_source.get("devices", [])
    old_edges = prior_source.get("legacy_edges", [])
    result = {
        "format_version": 1, "source_kind": "LinkIQ",
        "source_name": flw_path.name, "source_sha256": source["sha256"],
        "gpx_snapshot": "NEW_GPX_CANDIDATE_NOT_YET_DEPLOYED",
        "screen_radius_ft": prior_source.get("screen_radius_ft", 30.0),
        "cables": parsed, "mapped_routes": mapped,
        "unresolved_routes": unresolved,
        "legacy_edges": old_edges, "devices": old_devices,
        "review_records": review, "drawio_cables": old_drawio,
        "waypoint_lookup": {
            k: {"id": v["id"], "source_name": v["source_name"]}
            for k, v in points.items()},
        "lor_inventory": prior_source.get("lor_inventory", {}),
        "test_uuid_count": source["unique_test_count"],
        "source_appearance_count": source["source_row_count"],
        "duplicate_project_appearances": source["duplicate_project_appearances"],
        "source_identities_reviewed": False,
        "schematic_status": "PRIOR_DRAWIO_SNAPSHOT_UNREVIEWED",
        "lor_status": "PRIOR_LOR_SNAPSHOT_UNREVIEWED",
    }
    seen = [x["source_id"] for x in parsed + review]
    if len(seen) != len(set(seen)) or len(seen) != 476:
        raise ValueError("Not all 476 saved tester UUIDs accounted for exactly once")
    if sum(x["project_appearances"] for x in parsed + review) != 684:
        raise ValueError("Project appearance conservation failed")
    if {r["route_id"] for r in mapped + unresolved} != candidate_route_ids:
        raise ValueError("GPX route coverage failed")
    receipt = {
        "source_sha256": source["sha256"],
        "source_name": flw_path.name,
        "counts": {
            "saved_test_uuids": len(seen),
            "source_project_rows": source["source_row_count"],
            "duplicate_project_appearances": source["duplicate_project_appearances"],
            "cables_with_parseable_active_names": len(parsed),
            "tests_requiring_name_or_delete_review": len(review),
            "source_deleted_uuid_count": sum(
                r["reason"] == "SOURCE_DELETED" for r in review),
            "mapped_candidate_tracks": len(mapped),
            "unresolved_tracks": len(unresolved),
        },
        "review_records": [
            {"test_uuid": x["source_id"], "label": x["attributes"]["CableId"],
             "reason": x["reason"]} for x in review
        ],
        "stale_source_sections": ["drawio_cables", "devices", "legacy_edges",
                                  "lor_inventory"],
        "deployed": False,
    }
    return result, receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flw", required=True, type=Path)
    parser.add_argument("--map", required=True, type=Path)
    parser.add_argument("--prior-network", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("--output-network", required=True, type=Path)
    args = parser.parse_args()
    sources = [args.flw, args.map, args.prior_network]
    outputs = [args.report, args.output_network]
    if any(x.resolve() in [v.resolve() for v in sources] for x in outputs):
        parser.error("Refusing to overwrite a source file")
    if any(x.exists() for x in outputs):
        parser.error("Output exists; preserve previous review before rerun")
    before = sha256(args.flw)
    result, receipt = rebuild_network_source(
        args.flw, args.map.read_text(encoding="utf-8"),
        json.loads(args.prior_network.read_text(encoding="utf-8")))
    if sha256(args.flw) != before:
        parser.error("FLW changed during read-only inspection")
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(receipt, indent=2, ensure_ascii=False),
                           encoding="utf-8")
    args.output_network.parent.mkdir(parents=True, exist_ok=True)
    args.output_network.write_text(json.dumps(result, indent=2, ensure_ascii=False),
                                   encoding="utf-8")
    print(json.dumps(receipt["counts"], indent=2))
    print("NEW NETWORK CANDIDATE WRITTEN — SCHEMATIC AND TOPOLOGY UNREVIEWED; NOT DEPLOYED.")


if __name__ == "__main__":
    main()
