#!/usr/bin/env python3
"""#171: Office/other Windows PC reconnaissance and laptop source comparison.

Inventory uses KEY_READ; a host-named Shared Drive observation is optional
and intentionally cannot be consumed as an approved workstation release.
Never mutate HKCU, scanned maps, GPX, source artwork, or Production.
"""
from __future__ import annotations

from datetime import datetime, timezone
import json
import os
from pathlib import Path
from uuid import uuid4

from gis_workstation_profile import (
    MAPS_KEY, ProfileError, _open, _subkeys, read_current_user,
    sha256, sha256_file)
from gis_workstation_proposal import SHARED_ROOT, workstation_hostname
from gis_workstation_release_candidate import inspect_saved_proposal

SCHEMA = "msb.gis.workstation.observation.v1"
MAP_SELECTOR = "selected-current-user-map"


def list_scanned_map_names(reg=None):
    """Read only scanned-map key *names*; do not enumerate personal map data."""
    if reg is None:
        if os.name != "nt":
            raise ProfileError("Windows current-user registry required")
        import winreg
        reg = winreg
    try:
        with _open(reg, MAPS_KEY) as root:
            return sorted(_subkeys(reg, root), key=str.casefold)
    except FileNotFoundError:
        return []


def observation_destination(shared_root, hostname, now=None, token=None):
    moment = now or datetime.now(timezone.utc)
    if moment.tzinfo is None:
        raise ProfileError("Observation timestamp must be timezone aware")
    pc = workstation_hostname(hostname)
    nonce = token if token is not None else uuid4().hex[:12]
    if (len(nonce) != 12 or any(ch not in "0123456789abcdef" for ch in nonce)):
        raise ProfileError("Invalid observation nonce")
    stamp = moment.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return (Path(shared_root) / "Observations" / pc /
            f"MSB-GIS-Workstation-Observation-{pc}-{stamp}-{nonce}.json")


def _verify_destination(destination, shared_root):
    root = Path(shared_root)
    if destination.parent.parent != root / "Observations":
        raise ProfileError("Observations must stay in the shared workstation root")
    if root.parent.is_symlink() or not root.parent.is_dir():
        raise ProfileError("Shared MSB GIS folder not available")
    for part in (root, root / "Observations", destination.parent):
        if part.is_symlink():
            raise ProfileError("Linked shared workstation folder not allowed")
    if not root.resolve().is_relative_to(root.parent.resolve()):
        raise ProfileError("Shared workstation path escaped approved root")


def read_observation(plain, canonical_png, *, map_name, reg=None,
                     local_symbols=None, hostname=None):
    """Read entire Type/symbol configuration, one explicitly selected map.

    Unlike laptop's proposed *release source*, this observation records
    mismatched/missing icons instead of blocking reconnaissance. Registry
    remains read-only and paths/account/vendor settings are excluded.
    """
    if not isinstance(map_name, str) or "/" in map_name or "\\" in map_name:
        raise ProfileError("Select one existing scanned map from the list")
    if not map_name.strip() or "\x00" in map_name:
        raise ProfileError("Select an existing map, not an empty name")
    known_maps = list_scanned_map_names(reg=reg)
    if map_name not in known_maps:
        raise ProfileError("Selected map is not currently configured in ExpertGPS")
    profile = read_current_user(
        reg=reg, local_symbols=local_symbols, map_names={map_name})
    map_data = profile["maps"].get(map_name)
    if map_data is None:
        raise ProfileError("Selected scanned-map registration disappeared")
    installed = Path(profile["local_symbols"])
    source = Path(canonical_png)
    if not source.is_dir():
        raise ProfileError("Canonical G: PNG source not available for comparison")
    from sync_gis_icons import canonical_sources
    canon = canonical_sources(Path(plain))
    expected = {}
    for svg_name in sorted(canon):
        basename = Path(svg_name).stem + ".png"
        p = source / basename
        if p.is_symlink() or not p.is_file():
            raise ProfileError("Approved canonical PNG missing: " + basename)
        expected[basename] = sha256_file(p)
    asset_state = {}
    for name, digest in expected.items():
        f = installed / name
        if (f.is_file() and not f.is_symlink() and not installed.is_symlink()):
            actual = sha256_file(f)
            asset_state[name] = {
                "status": "match" if actual == digest else "different",
                "sha256": actual}
        else:
            asset_state[name] = {"status": "missing", "sha256": None}
    # Don't expose unrelated personal local icon names or their paths.
    snapshot = {
        "schema": SCHEMA,
        "approval_status": "UNAPPROVED OBSERVATION - NOT AN INSTALL SOURCE",
        "source_pc_hostname": workstation_hostname(hostname),
        "types": profile["types"],
        "symbol_to_type": profile["symbol_to_type"],
        "maps": {map_name: {
            "calibration": map_data["calibration"],
            "points": map_data["points"],
            "image_sha256": map_data["image_sha256"],
            "image_file_verified": map_data["image_file_verified"],
        }},
        "selected_map": map_name,
        "canonical_png_sha256": expected,
        "local_png_status": asset_state,
    }
    # Stable digest across repeated reads until actual registry/assets change.
    fingerprint = sha256(json.dumps(
        snapshot, sort_keys=True, separators=(",", ":"),
        ensure_ascii=False).encode("utf-8"))
    missing = sum(v["status"] == "missing" for v in asset_state.values())
    different = sum(v["status"] == "different" for v in asset_state.values())
    matched = len(asset_state) - missing - different
    return {
        "profile": snapshot, "fingerprint": fingerprint,
        "hostname": snapshot["source_pc_hostname"],
        "type_count": len(profile["types"]),
        "reverse_count": len(profile["symbol_to_type"] or {}),
        "selected_map": map_name,
        "map_image_verified": map_data["image_file_verified"],
        "png_matched": matched, "png_missing": missing,
        "png_different": different, "png_total": len(asset_state),
    }


def compare_with_laptop(observation, laptop_proposal, *, shared_root=SHARED_ROOT):
    """Read-only comparison of exact observed Type fields, reverse and icons.

    Different named full vs cropped maps are expected separate image variants
    rather than evidence that either PC is incorrectly configured.
    """
    current = observation["profile"]
    verified = inspect_saved_proposal(laptop_proposal, shared_root)
    if verified["hostname"] != "YOGA-GREG":
        raise ProfileError(
            "Select the YOGA-GREG laptop proposal, not another PC's observation")
    laptop = verified["data"]
    rows = []
    for typ in sorted(set(current["types"]) | set(laptop["types"])):
        a, b = current["types"].get(typ), laptop["types"].get(typ)
        if a is None:
            rows.append(("Laptop-only Type", typ, "", ""))
        elif b is None:
            rows.append(("Office-only Type", typ, "", ""))
        else:
            for field in ("Symbol Type", "GPS Symbol", "Bitmap Symbol URL"):
                if a.get(field) != b.get(field):
                    rows.append(("Type field differs", typ, field,
                                 f"Office: {a.get(field, '<absent>')} | "
                                 f"Laptop: {b.get(field, '<absent>')}"))
    a = current.get("symbol_to_type") or {}
    b = laptop.get("symbol_to_type") or {}
    for key in sorted(set(a) | set(b)):
        if a.get(key) != b.get(key):
            rows.append(("GPS Symbol reverse differs", key, "",
                         f"Office: {a.get(key, '<absent>')} | "
                         f"Laptop: {b.get(key, '<absent>')}"))
    for filename, state in current["local_png_status"].items():
        if state["status"] != "match":
            rows.append(("Local PNG not verified", filename, state["status"], ""))
    laptop_maps = set(laptop["maps"])
    office_maps = set(current["maps"])
    if laptop_maps != office_maps:
        rows.append(("Different map registrations (review separately)",
                     "Office: " + ", ".join(sorted(office_maps)),
                     "Laptop: " + ", ".join(sorted(laptop_maps)),
                     "Do not assume identical or interchangeable calibration"))
    # A renamed image can be EXACTLY the same bytes but intentionally have
    # wrong projection/control points on one PC. Do not certify it as an
    # expected independent map variant solely because the names differ.
    for office_name, office_entry in current["maps"].items():
        for laptop_name, laptop_entry in laptop["maps"].items():
            identical_image = (
                office_entry["image_sha256"] is not None and
                office_entry["image_sha256"] == laptop_entry["image_sha256"])
            label = office_name if office_name == laptop_name else (
                office_name + " ↔ " + laptop_name)
            if identical_image:
                for field in ("calibration", "points"):
                    if office_entry[field] != laptop_entry[field]:
                        rows.append((
                            "SAME IMAGE, DIFFERENT GEOREFERENCE — REVIEW", label,
                            field,
                            "Equal image SHA, differing projection/dimensions or "
                            "control points. Do not apply or auto-correct."))
            elif office_name == laptop_name:
                rows.append((
                    "Matching map name but DIFFERENT IMAGE — REVIEW",
                    label, "image_sha256",
                    "Map names alone cannot prove image/coordinate equivalence"))
    for office_name, office_entry in current["maps"].items():
        if not office_entry.get("image_file_verified"):
            rows.append((
                "Selected Office map image NOT VERIFIED", office_name, "",
                "Missing image hash cannot establish calibration identity"))
    return {"rows": rows, "office_type_count": len(current["types"]),
            "laptop_type_count": len(laptop["types"]),
            "office_map": observation["selected_map"],
            "laptop_maps": sorted(laptop["maps"]),
            "laptop_proposal_sha256": sha256_file(laptop_proposal),
            "status": "READ-ONLY COMPARISON - NOTHING TO INSTALL"}


def save_observation(observation, *, plain, canonical_png,
                     shared_root=SHARED_ROOT, reg=None,
                     local_symbols=None, now=None, token=None):
    """After UI review, reconfirm current-state fingerprint before G: save."""
    current = read_observation(
        plain, canonical_png, map_name=observation["selected_map"],
        reg=reg, local_symbols=local_symbols,
        hostname=observation["hostname"])
    if current["fingerprint"] != observation["fingerprint"]:
        raise ProfileError(
            "This PC's GIS settings changed since review; re-inspect before saving")
    dest = observation_destination(
        shared_root, observation["hostname"], now=now, token=token)
    _verify_destination(dest, shared_root)
    data = dict(current["profile"])
    data["captured_utc"] = (now or datetime.now(timezone.utc)).astimezone(
        timezone.utc).isoformat()
    data["review_source_sha256"] = observation["fingerprint"]
    raw = (json.dumps(data, sort_keys=True, indent=2,
                      ensure_ascii=False) + "\n").encode("utf-8")
    dest.parent.mkdir(parents=True, exist_ok=True)
    _verify_destination(dest, shared_root)
    with dest.open("xb") as f:
        f.write(raw)
    result = sha256_file(dest)
    if result != sha256(raw):
        raise ProfileError("G: observation SHA-256 post-write mismatch")
    return {"destination": str(dest), "sha256": result,
            "hostname": observation["hostname"],
            "status": "UNAPPROVED observation saved - not an install"}
