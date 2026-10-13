#!/usr/bin/env python3
"""#171: collect an UNAPPROVED GIS configuration proposal on the shared G: drive.

Uses current Windows user's narrowly scoped ExpertGPS values in KEY_READ mode.
The sole optional write is a new host-named proposal in shared MSB GIS.
No approved release, registry import, GPX edit, local proposal or DB update.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import socket
from urllib.parse import unquote, urlsplit
from uuid import uuid4

from gis_workstation_profile import ProfileError, read_current_user, sha256, sha256_file
from sync_gis_icons import PARK, canonical_sources, png_canvas

PROPOSAL_SCHEMA = "msb.gis.workstation.proposal.v1"
PUBLIC_MSB_PNG = "https://webassets.sheboyganlights.org/images/symbols/msb/"
SHARED_ROOT = PARK.parent / "Workstation-Configuration"
HOST_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,62}$")


def workstation_hostname(hostname=None):
    """Hostname is an audit label, NOT an authentication or approval credential."""
    name = hostname if hostname is not None else (os.environ.get("COMPUTERNAME") or socket.gethostname())
    if not isinstance(name, str) or not HOST_PATTERN.fullmatch(name):
        raise ProfileError("Windows PC hostname unsuitable for safe shared folder naming")
    return name.upper()


def proposal_destination(shared_root, hostname, now=None, token=None):
    """Predict a new host-specific destination without creating any directories."""
    root = Path(shared_root)
    when = now or datetime.now(timezone.utc)
    if when.tzinfo is None:
        raise ProfileError("Proposal timestamp must have timezone")
    stamp = when.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    nonce = token if token is not None else uuid4().hex[:12]
    if not re.fullmatch(r"[0-9a-f]{12}", nonce):
        raise ProfileError("Invalid proposal nonce")
    name = workstation_hostname(hostname)
    return root / "Proposals" / name / (
        f"MSB-GIS-Workstation-Proposal-{name}-{stamp}-{nonce}.json")


def _safe_shared_parents(destination, shared_root):
    """Prevent symlink escape or writing anywhere except host's Proposals folder."""
    root = Path(shared_root)
    expected = root / "Proposals" / destination.parent.name
    if destination.parent != expected:
        raise ProfileError("Proposal must use the expected host-specific Shared Drive folder")
    for part in (root, root / "Proposals", destination.parent):
        if part.is_symlink():
            raise ProfileError("Linked Shared Drive output folder not allowed")
    if not root.parent.is_dir() or root.parent.is_symlink():
        raise ProfileError("MSB GIS Shared Drive parent is unavailable")
    if not root.resolve().is_relative_to(root.parent.resolve()):
        raise ProfileError("Shared GIS output path escapes approved root")


def prepare_laptop_proposal(plain: Path, canonical_png: Path, shared_root: Path,
                            map_name: str, *, hostname=None, reg=None,
                            local_symbols=None, save=False, now=None, token=None,
                            expected_source_sha256=None):
    """Inspect current-user settings and either preflight or save a NEW shared proposal.

    save=False (default) is entirely read-only. save=True creates one new
    proposal file, under the host's dedicated shared folder, after validations.
    It neither declares release approval nor installs any settings.
    """
    plain, canonical_png, shared_root = (
        Path(plain), Path(canonical_png), Path(shared_root))
    pc = workstation_hostname(hostname)
    if not map_name or "/" in map_name or "\\" in map_name or "\x00" in map_name:
        raise ProfileError("Specify one existing laptop scanned-map identity")
    destination = proposal_destination(shared_root, pc, now=now, token=token)
    _safe_shared_parents(destination, shared_root)

    profile = read_current_user(reg=reg, local_symbols=local_symbols,
                                map_names={map_name})
    if profile["symbol_to_type"] is None:
        raise ProfileError("Missing SymbolToType: review before proposing a release")
    if map_name not in profile["maps"]:
        raise ProfileError("Required laptop scanned-map entry not found")
    map_entry = profile["maps"][map_name]
    if not map_entry["image_file_verified"] or not map_entry["image_sha256"]:
        raise ProfileError("Cannot verify laptop cropped scanned-map image")
    if not all(point in map_entry["points"] for point in ("Point01", "Point02")):
        raise ProfileError("Required reviewed map calibration Point01/Point02 absent")

    sources = canonical_sources(plain)
    files = {}
    source_svgs = {}
    local = Path(profile["local_symbols"])
    mismatches = []
    for svg_name, (_path, svg_sha, width, height) in sorted(sources.items()):
        source_svgs[svg_name] = svg_sha
        name = Path(svg_name).stem + ".png"
        png = canonical_png / name
        installed = local / name
        if (png.is_symlink() or not png.is_file() or not installed.is_file()
                or installed.is_symlink()):
            mismatches.append(name + ": canonical/installed PNG missing or linked")
            continue
        if png_canvas(png.read_bytes(), name) != (width, height):
            mismatches.append(name + ": PNG dimensions differ from approved Plain")
            continue
        digest = sha256_file(png)
        if sha256_file(installed) != digest:
            mismatches.append(name + ": installed PNG differs from canonical")
            continue
        files["msb/" + name] = digest
    if mismatches:
        raise ProfileError("Proposal blocked: " + "; ".join(mismatches[:8]))

    # Capture exact URL spellings; never normalize historical case or guess icons.
    review = []
    for name, fields in sorted(profile["types"].items()):
        url = fields.get("Bitmap Symbol URL", "")
        if not url:
            continue
        if not url.startswith(PUBLIC_MSB_PNG):
            review.append({"type": name, "reason": "External/noncanonical marker URL",
                           "url": url})
            continue
        filename = unquote(url[len(PUBLIC_MSB_PNG):])
        if "/" in filename or "\\" in filename or "msb/" + filename not in files:
            review.append({"type": name, "reason": "Historical/unknown MSB filename",
                           "url": url})

    captured = now or datetime.now(timezone.utc)
    proposed = {
        "schema": PROPOSAL_SCHEMA,
        "approval_status": "UNAPPROVED",
        "source_pc_hostname": pc,
        "source_role": "initial laptop candidate — not permanent master",
        "captured_utc": captured.astimezone(timezone.utc).isoformat(),
        "types": profile["types"],
        "symbol_to_type": profile["symbol_to_type"],
        "maps": {map_name: {
            "calibration": map_entry["calibration"],
            "points": map_entry["points"],
            "image_sha256": map_entry["image_sha256"],
        }},
        "files": files,
        "approved_plain_source_sha256": source_svgs,
        "review_items": review,
        "open_gates": [
            "MSB GIS administrator must explicitly review and approve release content",
            "Immutable machine-independent release package/independent approval SHA required",
            "Only verified approved PNG/calibration assets may be installed on Show PC",
            "Targeted Show PC HKCU backups, rollback and ExpertGPS-closed checks are required",
            "Office full aerial is separate from laptop/Show cropped aerial variant",
            "No GPX/PostGIS two-way editing is authorized by this proposal",
        ],
    }
    # Prevent a click-through GUI approval of different data if the operator
    # changes ExpertGPS settings or approved Plain/PNG files after reviewing.
    review_payload = {
        key: proposed[key] for key in (
            "types", "symbol_to_type", "maps", "files",
            "approved_plain_source_sha256", "review_items")
    }
    review_sha256 = sha256(json.dumps(
        review_payload, sort_keys=True, ensure_ascii=False,
        separators=(",", ":")).encode("utf-8"))
    if expected_source_sha256 is not None and expected_source_sha256 != review_sha256:
        raise ProfileError(
            "Current GIS settings/assets changed since review; recheck this PC "
            "before saving a proposal. No shared file written.")
    payload = (json.dumps(proposed, indent=2, sort_keys=True, ensure_ascii=False)
               + "\n").encode("utf-8")
    if save:
        # Only the shared MSB GIS host folder is created, after source preflight.
        # Never replace an older proposal or alter a published Release.
        destination.parent.mkdir(parents=True, exist_ok=True)
        _safe_shared_parents(destination, shared_root)
        with destination.open("xb") as stream:
            stream.write(payload)
        if sha256_file(destination) != sha256(payload):
            raise ProfileError("Shared proposal write verification failed; inspect file")
    return {
        "status": "UNAPPROVED proposal saved" if save else "Read-only preflight",
        "hostname": pc,
        "destination": str(destination) if save else str(destination.parent),
        "proposal_sha256_not_approval": sha256(payload) if save else "not issued",
        "type_count": len(proposed["types"]),
        "png_count": len(files),
        "map_count": len(proposed["maps"]),
        "review_count": len(review),
        "review_source_sha256": review_sha256,
        # Preflight must display discrepancies before any G: write is requested.
        "review_items": review,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Read/optionally save UNAPPROVED laptop proposal under Shared MSB GIS")
    parser.add_argument("--save-proposal", action="store_true",
                        help="Write one new host-specific proposal to MSB GIS Shared Drive")
    parser.add_argument("--map-name", default="2019 Ortho Cropped for GPS Export")
    args = parser.parse_args(argv)
    if os.name != "nt":
        raise ProfileError("Real current-user proposal requires Windows")
    result = prepare_laptop_proposal(
        PARK / "Plain", PARK / "png", SHARED_ROOT, args.map_name,
        save=args.save_proposal)
    for key, value in result.items():
        if key != "review_items":
            print(f"{key}: {value}")
    if result["review_items"]:
        print("\nTYPE/MAP MARKER REFERENCES REQUIRING REVIEW:")
        for item in result["review_items"]:
            # Readable filename/host only; omit URL query and fragment.
            url = urlsplit(item["url"])
            filename = unquote(url.path.rsplit("/", 1)[-1]) or "(none)"
            print(f"  {item['type']}: {item['reason']} "
                  f"[{url.netloc}/{filename}]")
    if not args.save_proposal:
        print("READ-ONLY preflight. To save an UNAPPROVED shared proposal, "
              "run again with --save-proposal after review.")
    else:
        print("Shared evidence only. No approved release or Step-6 trust pin created.")


if __name__ == "__main__":
    main()
