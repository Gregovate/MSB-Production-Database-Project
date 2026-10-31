#!/usr/bin/env python3
"""#171 targeted Office cropped-map calibration repair, no GPX/source raster edits.

This is deliberately NOT a general registry import. An exact native baseline,
closed ExpertGPS process, private backup and after-write readback are mandatory.
"""
from __future__ import annotations
import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path
from gis_workstation_map_source import inspect_office_map, SOURCE_HOST
from gis_workstation_profile import ProfileError, MAPS_KEY, sha256

MAP = "2019 Ortho Cropped for GPS Export"
RASTER = "cff28c2ac5bf04c780238171d68295a105b67e1f61ffdb6881916d3510d85174"
EXPECTED_OLD = {
    "Projection": "Mercator",
    "Datum": "North American 1983 (United States)",
    "Point01.Latitude": "1.69910207",
    "Point01.Longitude": "1.87947681",
    "Point02.Latitude": "1.67765309",
    "Point02.Longitude": "1.92052983",
}
TARGET = {
    "Projection": "National Grid Transverse Mercator",
    "Datum": "North American 1983 (United States)",
    "Projection\\EPSG": "103458",
    "Point01.Latitude": "43.78198693",
    "Point01.Longitude": "-87.74984560",
    "Point02.Latitude": "43.77550693",
    "Point02.Longitude": "-87.73252256",
}
OTHER = ("EvergreenParkCropped", "2019OrthoEvergreenParktoWorkshop")

def _values(review):
    head = review["source"]["native_header"]
    pts = review["source"]["native_control_points"]
    result = {k: v["value"] for k, v in head.items()}
    for point, fields in pts.items():
        result.update({point + "." + k: v["value"] for k, v in fields.items()})
    return result

def _snapshot(*, reg=None, hostname=None, shared_image_root=None):
    opts = {"reg": reg, "hostname": hostname}
    if shared_image_root is not None:
        opts["shared_image_root"] = shared_image_root
    return {name: inspect_office_map(map_name=name, **opts)
            for name in (MAP, *OTHER)}

def _check_baseline(snapshot):
    selected = snapshot[MAP]
    if selected["image_sha256"] != RASTER:
        raise ProfileError("Office cropped raster differs from approved laptop bytes")
    data = _values(selected)
    for field, expected in EXPECTED_OLD.items():
        if data.get(field) != expected:
            raise ProfileError("Office pre-repair calibration differs at " + field)
    if "Projection\\EPSG" in data:
        raise ProfileError("Unexpected pre-existing EPSG value: STOP")
    if any(selected["source"]["native_header"][f]["kind"] != 1
           for f in ("Projection", "Datum")):
        raise ProfileError("Unexpected native header type")
    for point in ("Point01", "Point02"):
        for f in ("Latitude", "Longitude"):
            if selected["source"]["native_control_points"][point][f]["kind"] != 1:
                raise ProfileError("Unexpected native control value type")

def _closed():
    if os.name != "nt":
        raise ProfileError("Windows current-user repair only")
    result = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True,
                            text=True, check=True, timeout=15)
    import csv
    names = [row[0].lower() for row in csv.reader(result.stdout.splitlines()) if row]
    if any("expertgps" in name for name in names):
        raise ProfileError("ExpertGPS running: close the application before repair")

def preview(*, reg=None, hostname=None, shared_image_root=None):
    observations = _snapshot(reg=reg, hostname=hostname,
                             shared_image_root=shared_image_root)
    _check_baseline(observations)
    return {"snapshot": observations, "target": dict(TARGET),
            "baseline_hash": sha256(json.dumps(
                {k: v["fingerprint"] for k,v in observations.items()},
                sort_keys=True).encode())}

def apply(review, *, reg=None, hostname=None, shared_image_root=None,
          private_backup_dir=None, process_check=True):
    """Require explicit operator confirmation at caller, then backup+write+verify.

    On failure, restore exact original values and verify before re-raising.
    """
    if process_check: _closed()
    if reg is None:
        import winreg
        reg = winreg
    current = preview(reg=reg, hostname=hostname, shared_image_root=shared_image_root)
    if current["baseline_hash"] != review["baseline_hash"]:
        raise ProfileError("Office map snapshot changed since review; STOP")
    root = Path(private_backup_dir or Path.home() / "Documents" / "MSB-GIS-171-Backup")
    if not root.is_dir() or root.is_symlink():
        raise ProfileError("Private map recovery folder not available")
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    dest = root / ("Office-Cropped-Map-Before-" + stamp + ".json")
    raw = (json.dumps(current["snapshot"], sort_keys=True, indent=2) + "\n").encode()
    with dest.open("xb") as stream:
        stream.write(raw)
        stream.flush()
        os.fsync(stream.fileno())
    if dest.read_bytes() != raw:
        raise ProfileError("Private calibration backup readback failed; STOP")
    base = MAPS_KEY + chr(92) + MAP
    original = current["snapshot"][MAP]["source"]["native_header"]
    points = current["snapshot"][MAP]["source"]["native_control_points"]
    absent_epsg = "Projection\\EPSG" not in original
    def set_value(name, value):
        parts = name.split(".", 1)
        if len(parts) == 2:
            path = base + chr(92) + parts[0]
            field = parts[1]
        else:
            path, field = base, name
        with reg.OpenKey(reg.HKEY_CURRENT_USER, path, 0, reg.KEY_SET_VALUE) as key:
            reg.SetValueEx(key, field, 0, reg.REG_SZ, value)
    def rollback():
        for name in TARGET:
            if name == "Projection\\EPSG" and absent_epsg:
                with reg.OpenKey(reg.HKEY_CURRENT_USER, base, 0, reg.KEY_SET_VALUE) as key:
                    reg.DeleteValue(key, name)
                continue
            part = name.split(".", 1)
            prior = points[part[0]][part[1]] if len(part) == 2 else original[name]
            set_value(name, prior["value"])
    try:
        for name, value in TARGET.items():
            set_value(name, value)
        after = _snapshot(reg=reg, hostname=hostname, shared_image_root=shared_image_root)
        if any(after[name]["fingerprint"] != current["snapshot"][name]["fingerprint"]
               for name in OTHER):
            raise ProfileError("Unrelated Office map changed; rollback")
        for name, value in TARGET.items():
            if _values(after[MAP]).get(name) != value:
                raise ProfileError("Target map readback mismatch at " + name)
        return {"backup": str(dest), "verified": True, "target_map": MAP}
    except Exception:
        rollback()
        restored = _snapshot(reg=reg, hostname=hostname,
                             shared_image_root=shared_image_root)
        if any(restored[name]["fingerprint"] != current["snapshot"][name]["fingerprint"]
               for name in current["snapshot"]):
            raise ProfileError("ROLLBACK VERIFICATION FAILED: keep ExpertGPS closed and recover from backup")
        raise
