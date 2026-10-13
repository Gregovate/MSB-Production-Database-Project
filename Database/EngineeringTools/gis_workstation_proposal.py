#!/usr/bin/env python3
"""#171: create an UNAPPROVED, sanitized laptop GIS configuration proposal.

This helper belongs to the existing Icon Library Manager's engineering tools.
It never imports/changes HKCU, GPX, source SVG/PNG, scanned maps or PostGIS.
The output is evidence for administrator review, NOT a release or trust pin.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
from urllib.parse import unquote, urlsplit

from gis_workstation_profile import ProfileError, read_current_user, sha256, sha256_file
from sync_gis_icons import PARK, canonical_sources, png_canvas

PROPOSAL_SCHEMA = "msb.gis.workstation.proposal.v1"
PUBLIC_MSB_PNG = "https://webassets.sheboyganlights.org/images/symbols/msb/"


def prepare_laptop_proposal(plain: Path, canonical_png: Path, output: Path,
                            map_name: str, *, reg=None, local_symbols=None):
    """Collect only approved configuration fields and file hashes, with no mutations.

    Registry is read using KEY_READ. Only output is a new local JSON proposal;
    it is deliberately incompatible with load_release() until independently
    reviewed, approved and packaged using a separate release process.
    """
    plain, canonical_png, output = Path(plain), Path(canonical_png), Path(output)
    if (not map_name or "/" in map_name or "\\" in map_name or
            "\x00" in map_name):
        raise ProfileError("Specify one existing approved laptop map identity")
    if output.exists() or output.is_symlink():
        raise ProfileError("Refusing to overwrite an existing proposal")
    if not output.parent.is_dir() or output.parent.is_symlink():
        raise ProfileError("Proposal parent must be an existing local folder")
    # Fail closed on accidental G:/Shared Drive publication of unapproved data.
    if output.drive.lower() == "g:":
        raise ProfileError("Unapproved proposal cannot be written to shared G: drive")

    profile = read_current_user(reg=reg, local_symbols=local_symbols,
                                map_names={map_name})
    if profile["symbol_to_type"] is None:
        raise ProfileError("Missing SymbolToType: review before proposing a release")
    if map_name not in profile["maps"]:
        raise ProfileError("Required laptop scanned-map entry not found")
    map_entry = profile["maps"][map_name]
    if not map_entry["image_file_verified"] or not map_entry["image_sha256"]:
        raise ProfileError("Cannot verify laptop cropped scanned-map image")
    if not all(name in map_entry["points"] for name in ("Point01", "Point02")):
        raise ProfileError("Required reviewed map calibration Point01/Point02 absent")

    # The canonical approved Plain SVG set determines expected PNG filenames.
    sources = canonical_sources(plain)
    if not sources:
        raise ProfileError("Approved Plain SVG source set empty")
    files = {}
    local = Path(profile["local_symbols"])
    mismatches = []
    for svg_name, (_path, _svg_sha, width, height) in sorted(sources.items()):
        name = Path(svg_name).stem + ".png"
        png = canonical_png / name
        installed = local / name
        if png.is_symlink() or not png.is_file() or not installed.is_file() or installed.is_symlink():
            mismatches.append(name + ": canonical/installed PNG missing or linked")
            continue
        # Approved 32px image canvas: never infer resizing or copy old aliases.
        size = png_canvas(png.read_bytes(), name)
        if size != (width, height):
            mismatches.append(name + ": PNG dimensions differ from approved Plain")
            continue
        digest = sha256_file(png)
        if sha256_file(installed) != digest:
            mismatches.append(name + ": installed PNG differs from canonical")
            continue
        files["msb/" + name] = digest
    if mismatches:
        raise ProfileError("Proposal blocked: " + "; ".join(mismatches[:8]))
    # Case-sensitive original Type URLs and GPS reverse associations are retained.
    # Unknown aliases/non-MSB URLs remain review items, not silent replacements.
    review = []
    for name, fields in sorted(profile["types"].items()):
        url = fields.get("Bitmap Symbol URL", "")
        if not url:
            continue
        if not url.startswith(PUBLIC_MSB_PNG):
            review.append({"type": name, "reason": "External/noncanonical map marker URL",
                           "url": url})
            continue
        filename = unquote(url[len(PUBLIC_MSB_PNG):])
        if "/" in filename or "\\" in filename or "msb/" + filename not in files:
            review.append({"type": name, "reason": "Historical/unknown MSB filename",
                           "url": url})

    proposed = {
        "schema": PROPOSAL_SCHEMA,
        "approval_status": "UNAPPROVED",
        "source_role": "laptop (initial evidence, not permanent master)",
        "captured_utc": datetime.now(timezone.utc).isoformat(),
        "types": profile["types"],
        "symbol_to_type": profile["symbol_to_type"],
        "maps": {map_name: {
            "calibration": map_entry["calibration"],
            "points": map_entry["points"],
            "image_sha256": map_entry["image_sha256"],
        }},
        "files": files,
        "review_items": review,
        "open_gates": [
            "MSB GIS administrator must explicitly review and approve release identity/content",
            "Immutable package must include checked, approved PNG and portable map artifacts",
            "Office full aerial is a separate reviewed calibration/required-role map variant",
            "Show PC and clean Windows profile must pass acceptance",
            "No GPX/PostGIS two-way editing is authorized by this proposal",
        ],
    }
    payload = (json.dumps(proposed, indent=2, sort_keys=True, ensure_ascii=False)
               + "\n").encode("utf-8")
    # Exclusive file creation; no replacement or release-history publication.
    with output.open("xb") as stream:
        stream.write(payload)
    return {"file": str(output), "proposal_sha256_not_approval": sha256(payload),
            "type_count": len(proposed["types"]), "png_count": len(files),
            "map_count": 1, "review_count": len(review)}


def main(argv=None):
    parser = argparse.ArgumentParser(description="Create unapproved laptop GIS profile proposal")
    parser.add_argument("--output", required=True,
                        help="NEW LOCAL JSON path only; never Shared Drive, GPX or release publication")
    parser.add_argument("--map-name", default="2019 Ortho Cropped for GPS Export")
    parser.add_argument("--plain", default=str(PARK / "Plain"))
    parser.add_argument("--canonical-png", default=str(PARK / "png"))
    args = parser.parse_args(argv)
    result = prepare_laptop_proposal(Path(args.plain), Path(args.canonical_png),
                                      Path(args.output), args.map_name)
    for key, value in result.items():
        print(f"{key}: {value}")
    print("UNAPPROVED proposal only. Do not paste its SHA into Step 6 as administrator approval.")


if __name__ == "__main__":
    main()
