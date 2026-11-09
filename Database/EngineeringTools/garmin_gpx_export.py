#!/usr/bin/env python3
"""#171: reviewed waypoint-only Garmin GPX export, never edit the shared master.

Uses EXACTLY the same externally reviewed Type -> Garmin symbol mapping as
garmin_bmp_derivatives.py. Unmapped Types retain their original sym and are
reported for human review; no guessed stock-name replacements.
"""
from __future__ import annotations

import argparse
from collections import Counter
from copy import deepcopy
from hashlib import sha256
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

from garmin_bmp_derivatives import GarminSyncError, load_registry

GPX = "{http://www.topografix.com/GPX/1/1}"
GEO_FIELDS = ("name", "ele", "time", "cmt", "desc", "type", "extensions")


def export_waypoints(source: Path, output: Path, registry: Path, *, approve: bool = False):
    mapping = {row["type"]: row["symbol"] for row in load_registry(registry)}
    if not source.is_file() or source.is_symlink():
        raise GarminSyncError("Master GPX source unavailable or symlink")
    if source.resolve() == output.resolve():
        raise GarminSyncError("Garmin export may never overwrite input GPX")
    if output.exists():
        raise GarminSyncError("Output exists: never overwrite an existing GPX")
    raw = source.read_bytes()
    root = ET.fromstring(raw)
    if root.tag != GPX + "gpx":
        raise GarminSyncError("Expected GPX 1.1 default namespace")
    waypoints = root.findall(GPX + "wpt")
    if not waypoints:
        raise GarminSyncError("Master contains no waypoints")
    device = ET.Element(root.tag, root.attrib)
    summary = Counter()
    differences = []
    for index, orig in enumerate(waypoints, 1):
        wp = deepcopy(orig)
        kind = wp.find(GPX + "type")
        sym = wp.find(GPX + "sym")
        name = wp.find(GPX + "name")
        kind_value = kind.text if kind is not None else None
        intended = mapping.get(kind_value)
        previous = sym.text if sym is not None else None
        if intended is None:
            summary["unmapped"] += 1
        elif previous == intended:
            summary["already_correct"] += 1
        else:
            if sym is None:
                sym = ET.Element(GPX + "sym")
                # Garmin GPX standard orders sym before type / extensions.
                child_list = list(wp)
                at = next((i for i, child in enumerate(child_list)
                           if child.tag in (GPX + "type", GPX + "extensions")), len(child_list))
                wp.insert(at, sym)
            sym.text = intended
            summary["modified"] += 1
            differences.append({"index": index, "name": name.text if name is not None else None,
                                "type": kind_value, "before": previous, "after": intended})
        # Semantic guard: no other waypoint element, extension, coordinate or value changed.
        original_fields = deepcopy(orig)
        modified_fields = deepcopy(wp)
        for elem in (original_fields, modified_fields):
            old = elem.find(GPX + "sym")
            if old is not None:
                elem.remove(old)
        if ET.tostring(original_fields) != ET.tostring(modified_fields):
            raise GarminSyncError(f"Non-symbol waypoint change at index {index}")
        device.append(wp)
    summary["waypoints"] = len(waypoints)
    summary["tracks_removed_from_device_export"] = len(root.findall(GPX + "trk"))
    summary["routes_removed_from_device_export"] = len(root.findall(GPX + "rte"))
    result = {"master_sha256": sha256(raw).hexdigest(),
              "mapping_sha256": sha256(registry.read_bytes()).hexdigest(),
              "output": str(output), "summary": dict(summary), "symbol_changes": differences}
    if approve:
        output.parent.mkdir(parents=True, exist_ok=True)
        data = ET.tostring(device, encoding="utf-8", xml_declaration=True)
        with output.open("xb") as fp:
            fp.write(data)
        if len(ET.fromstring(output.read_bytes()).findall(GPX + "wpt")) != len(waypoints):
            raise GarminSyncError("Export readback waypoint count mismatch")
        result["output_sha256"] = sha256(output.read_bytes()).hexdigest()
    return result


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--master", type=Path, required=True)
    p.add_argument("--registry", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--write-reviewed-export", action="store_true")
    args = p.parse_args(argv)
    try:
        result = export_waypoints(args.master, args.output, args.registry,
                                  approve=args.write_reviewed_export)
        print(json.dumps(result, indent=2))
        return 0
    except (GarminSyncError, OSError, ET.ParseError, ValueError) as exc:
        print(f"STOP: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
