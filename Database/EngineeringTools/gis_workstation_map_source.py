#!/usr/bin/env python3
"""#171 Office scanned-map inventory: capture selected native calibration READ ONLY.

Preserve ALL Office registrations, including deliberately incorrect test maps.
Only EvergreenParkCropped is the reviewed working source for later transfer.
No saved evidence is an installable release.
"""
from __future__ import annotations

from datetime import datetime, timezone
import json
from pathlib import Path
import re
from uuid import uuid4

from gis_workstation_profile import (
    ProfileError, MAPS_KEY, _open, _subkeys, sha256, sha256_file)
from gis_workstation_proposal import SHARED_ROOT, workstation_hostname

SOURCE_HOST = "MSB-OFFICE-PC"
SOURCE_MAP = "EvergreenParkCropped"
SHARED_IMAGE_ROOT = Path("G:/Shared drives/Display Folders/Park Drawings")
SCHEMA = "msb.gis.scanned-map-source.proposal.v1"
ALLOWED_KINDS = (1, 4)  # REG_SZ, REG_DWORD
STAMP_TOKEN = re.compile(r"^[0-9a-f]{12}$")


def _native_values(reg, key):
    result = {}
    index = 0
    while True:
        try:
            name, value, kind = reg.EnumValue(key, index)
        except OSError as exc:
            if getattr(exc, "winerror", None) not in (259, None):
                raise
            break
        if (not isinstance(name, str) or not name or
                kind not in ALLOWED_KINDS or
                (kind == 1 and not isinstance(value, str)) or
                (kind == 4 and (type(value) is not int or value < 0))):
            raise ProfileError("Unexpected ExpertGPS map registry field format")
        result[name] = {"kind": kind, "value": value}
        index += 1
    return result


def inspect_office_map(*, map_name=SOURCE_MAP, reg=None, hostname=None,
                       shared_image_root=SHARED_IMAGE_ROOT):
    """Read precisely the selected existing Office map; never edit any registration."""
    host = workstation_hostname(hostname)
    if host != SOURCE_HOST:
        raise ProfileError("Office working map source only on MSB-OFFICE-PC")
    if reg is None:
        import os
        if os.name != "nt":
            raise ProfileError("Office map capture requires the real Windows user")
        import winreg
        reg = winreg
    # An explicit selection may only name a direct existing map registration.
    if (not isinstance(map_name, str) or not map_name or
            map_name in (".", "..") or "\\\\" in map_name or "/" in map_name or
            any(ord(ch) < 32 for ch in map_name)):
        raise ProfileError("Invalid selected Office scanned-map name")
    with _open(reg, MAPS_KEY) as maps_key:
        if map_name not in list(_subkeys(reg, maps_key)):
            raise ProfileError("Selected scanned map is not registered on this Office PC")
    name = map_name
    with _open(reg, MAPS_KEY + "\\\\" + name) as key:
        keys = list(_subkeys(reg, key))
        unknown = [x for x in keys if x not in ("Point01", "Point02", "Point03")]
        if unknown:
            raise ProfileError("Unexpected nested scanned-map keys; inspect first")
        header = _native_values(reg, key)
    pts = {}
    for point in ("Point01", "Point02", "Point03"):
        if point in keys:
            with _open(reg, MAPS_KEY + "\\" + name + "\\" + point) as key:
                if list(_subkeys(reg, key)):
                    raise ProfileError("Unexpected nested map calibration points")
                pts[point] = _native_values(reg, key)
    if not all(pt in pts and pts[pt] for pt in ("Point01", "Point02")):
        raise ProfileError("Office source missing Point01/Point02 control evidence")
    image_setting = header.get("Map Path")
    if (not isinstance(image_setting, dict) or
            image_setting["kind"] != reg.REG_SZ):
        raise ProfileError("Office map image location is not a valid string")
    path = Path(image_setting["value"])
    shared_root = Path(shared_image_root)
    # Trusted drive location must be established before saving transferable data.
    if not path.is_file() or not path.resolve().is_relative_to(
            shared_root.resolve()):
        raise ProfileError("Office raster not an accessible approved shared-drive file")
    if path.is_symlink():
        raise ProfileError("Linked Office raster is not an acceptable shared source")
    if not all(field in header for field in ("Width", "Height", "Projection")):
        raise ProfileError("Office map dimensions/projection missing")
    raster_sha = sha256_file(path)
    sidecars = {}
    for extension in (".tfw", ".map"):
        candidate = path.with_suffix(extension)
        if candidate.is_symlink():
            raise ProfileError("Linked georeference sidecar refused")
        if candidate.is_file():
            sidecars[extension] = {
                "shared_path": str(candidate), "sha256": sha256_file(candidate)}
    immutable = {
        "schema": SCHEMA,
        "approval_status": "UNAPPROVED MAP SOURCE - NOT INSTALLABLE",
        "origin_host": host,
        "map_name": name,
        "shared_raster_path": str(path),
        "raster_sha256": raster_sha,
        "raster_bytes": path.stat().st_size,
        "native_header": header,
        "native_control_points": pts,
        "sidecars": sidecars,
        "target_roles": (["YOGA-GREG laptop", "Show PC (hostname to be discovered)"]
                         if name == SOURCE_MAP else []),
        "map_role": ("WORKING OFFICE SOURCE" if name == SOURCE_MAP
                     else "OTHER OFFICE REGISTRATION - REVIEW / POSSIBLE NEGATIVE TEST"),
        "preserve_office_working_map": True,
    }
    fingerprint = sha256(json.dumps(
        immutable, sort_keys=True, separators=(",", ":"),
        ensure_ascii=False).encode("utf-8"))
    return {"source": immutable, "fingerprint": fingerprint,
            "origin_host": host, "map_name": name,
            "projection": header["Projection"]["value"],
            "width": header["Width"]["value"],
            "height": header["Height"]["value"],
            "point_count": len(pts), "points": pts,
            "image_sha256": raster_sha,
            "sidecars_count": len(sidecars)}


def save_office_map_source(review, *, map_name=None, reg=None, hostname=None,
                           shared_root=SHARED_ROOT,
                           shared_image_root=SHARED_IMAGE_ROOT,
                           now=None, token=None):
    """Recheck everything observed, then exclusively create shared evidence."""
    selected = map_name if map_name is not None else review.get("map_name")
    actual = inspect_office_map(
        map_name=selected, reg=reg, hostname=hostname,
        shared_image_root=shared_image_root)
    if actual["fingerprint"] != review.get("fingerprint"):
        raise ProfileError("Office map changed since preview; NO shared record saved")
    root = Path(shared_root)
    if not root.parent.is_dir() or root.parent.is_symlink():
        raise ProfileError("MSB GIS Shared Drive location unavailable")
    host = actual["origin_host"]
    moment = now or datetime.now(timezone.utc)
    if moment.tzinfo is None:
        raise ProfileError("Map capture time must include timezone")
    nonce = token if token is not None else uuid4().hex[:12]
    if not STAMP_TOKEN.fullmatch(nonce):
        raise ProfileError("Unsafe map capture token")
    stamp = moment.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    parent = root / "Map-Sources" / host
    dest = parent / f"MSB-Scanned-Map-{host}-{stamp}-{nonce}.json"
    for part in (root, root / "Map-Sources", parent):
        if part.is_symlink():
            raise ProfileError("Linked shared calibration evidence directory")
    if dest.exists() or dest.is_symlink():
        raise ProfileError("Existing map source file will never be overwritten")
    payload = dict(actual["source"])
    payload["captured_utc"] = moment.astimezone(timezone.utc).isoformat()
    payload["review_fingerprint"] = review["fingerprint"]
    raw = (json.dumps(payload, sort_keys=True, indent=2,
                      ensure_ascii=False) + "\n").encode("utf-8")
    parent.mkdir(parents=True, exist_ok=True)
    with dest.open("xb") as stream:
        stream.write(raw)
    digest = sha256_file(dest)
    if digest != sha256(raw):
        raise ProfileError("Shared map evidence SHA-256 verification FAILED")
    return {"destination": str(dest), "sha256": digest,
            "map_name": actual["map_name"], "origin_host": host,
            "status": "UNAPPROVED map source saved; no map changed"}
