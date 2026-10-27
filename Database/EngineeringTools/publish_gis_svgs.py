#!/usr/bin/env python3
"""#171: governed, additive or backed-up Plain SVG publication to existing Synology msb-svg.

Read current Shared Drive Plain (approved browser artwork); do NOT write to
Masters, Plain, canonical png, ExpertGPS, GPX, Setup, or legacy web msb PNG/BMP.
Publishing requires a separate explicit UI confirmation. Never delete unknown
files or change names, even for obsolete GPX/ExpertGPS aliases.
"""
from __future__ import annotations

import csv
import os
from pathlib import Path
import shutil
import uuid
import re
import xml.etree.ElementTree as ET

from sync_gis_icons import IconError, canonical_sources, check_source_snapshot, sha, sha_file

WEB_SVG = Path(r"\\192.168.5.4\webassets\images\symbols\msb-svg")
PUBLIC_SVG_BASE = "https://webassets.sheboyganlights.org/images/symbols/msb-svg/"


def assert_public_svg_safe(name: str, raw: bytes):
    """Reject active content in public-origin SVGs; keep normal Inkscape path/style markup.

    Source SVG pixel/canvas validation is owned by canonical_sources().
    """
    try:
        root = ET.fromstring(raw)
    except ET.ParseError as error:
        raise IconError(f"{name}: malformed SVG before publication: {error}") from error
    prohibited = {"script", "foreignObject", "iframe", "object", "embed"}
    for node in root.iter():
        tag = node.tag.split("}")[-1]
        if tag in prohibited:
            raise IconError(f"{name}: active SVG element <{tag}> not permitted in published icons")
        for key, value in node.attrib.items():
            attr = key.split("}")[-1].lower()
            if attr.startswith("on") and "}" not in key:
                raise IconError(f"{name}: JavaScript event handler {key} not permitted")
            if "javascript:" in value.lower():
                raise IconError(f"{name}: JavaScript URI not permitted")
        if tag == "style" and node.text:
            css = node.text.lower()
            if "@import" in css:
                raise IconError(f"{name}: external CSS imports/resources not permitted")
            for match in re.finditer(r"url\(([^)]*)\)", css):
                asset = match.group(1).strip().strip("\\\"'")
                if not asset.startswith(("#", "data:")):
                    raise IconError(f"{name}: external CSS resource {asset!r} not permitted")
    return True


def web_svg_preflight(destination: Path, sources: dict) -> dict[str, list]:
    """Read-only full-set comparison of current validated Plain source and published folder."""
    if not destination.is_dir():
        raise IconError(f"Published SVG directory unavailable (do not create it): {destination}")
    existing = {}
    for p in destination.iterdir():
        if p.is_file():
            existing.setdefault(p.name.lower(), []).append(p)
    plan = {"add": [], "replace": [], "identical": [], "legacy_case_identical": {}}
    for name, (source, expected_hash, _width, _height) in sources.items():
        current_bytes = source.read_bytes()
        if sha(current_bytes) != expected_hash:
            raise IconError(f"Plain SVG changed during publication preflight: {name}")
        assert_public_svg_safe(name, current_bytes)
        found = existing.get(name.lower(), [])
        if not found:
            plan["add"].append(name)
        elif len(found) != 1 or not found[0].is_file():
            raise IconError(f"Ambiguous published SVG case collision: {name}; no publication allowed")
        elif found[0].name != name:
            # Windows SMB cannot always host two case-only names, while HTTPS is
            # case-sensitive. Preserve the historical URL ONLY when its bytes
            # already exactly match the approved current Plain SVG. A changed
            # source still stops rather than overwriting the old alias.
            if sha_file(found[0]) != expected_hash:
                raise IconError(
                    f"Published SVG legacy filename {found[0].name} conflicts with "
                    f"approved {name} and contains different bytes; no publication allowed")
            plan["legacy_case_identical"][name] = found[0].name
        elif sha_file(found[0]) == expected_hash:
            plan["identical"].append(name)
        else:
            plan["replace"].append(name)
    return plan


def publish_web_svgs(plain: Path, destination: Path, stage: Path, sources: dict, progress=None):
    """Back up every changed public SVG; copy only from the validated Plain snapshot.

    Creates a continuously updated receipt. Any failure stops; previously
    completed file actions remain in receipt with backup copies for recovery.
    """
    if progress:
        progress("preflight", 0, None, "Verifying current Plain SVG and published files")
    check_source_snapshot(plain, sources)
    plan = web_svg_preflight(destination, sources)
    backup_dir = stage / "web-svg-backups-before-replacement"
    if plan["replace"]:
        if progress:
            progress("backup", 0, None, f"Backing up {len(plan['replace'])} published SVGs")
        backup_dir.mkdir(parents=True, exist_ok=False)
        for name in plan["replace"]:
            existing = destination / name
            backup = backup_dir / name
            original_hash = sha_file(existing)
            shutil.copy2(existing, backup)
            if sha_file(backup) != original_hash or sha_file(existing) != original_hash:
                raise IconError(f"Published SVG backup changed during capture: {name}; no copies made")

    if progress:
        progress("publish", 0, len(sources), "Publishing approved Plain SVG bytes to Synology")
    receipt_path = stage / "MSB_GIS_Web_SVG_Publication_Receipt.csv"
    receipt = []
    for completed, (name, (source, expected_hash, _width, _height)) in enumerate(sources.items(), 1):
        if progress:
            progress("publish", completed - 1, len(sources), f"Processing {name}")
        source_bytes = source.read_bytes()
        if sha(source_bytes) != expected_hash:
            raise IconError(f"Plain source changed before SVG publication: {name}")
        target = destination / name
        if name in plan["legacy_case_identical"]:
            # Never rename or replace the old exact-case URL as a side effect
            # of publishing unrelated approved SVGs.
            target = destination / plan["legacy_case_identical"][name]
            if sha_file(target) != expected_hash:
                raise IconError(
                    f"Legacy SVG alias changed since preflight: {target.name}; stop")
            action = "legacy-case-identical"
        elif name in plan["identical"]:
            if sha_file(target) != expected_hash:
                raise IconError(f"Published SVG changed since preflight: {name}")
            action = "identical"
        elif name in plan["add"]:
            # Creation is exclusive: do not replace a concurrently-created file.
            with target.open("xb") as fp:
                fp.write(source_bytes)
                fp.flush()
                os.fsync(fp.fileno())
            action = "created"
        elif name in plan["replace"]:
            previous = backup_dir / name
            if sha_file(previous) != sha_file(target):
                raise IconError(f"Published target changed after backup: {name}; preserve backup")
            temporary = destination / (".msb-svg-" + uuid.uuid4().hex + ".tmp")
            try:
                with temporary.open("xb") as fp:
                    fp.write(source_bytes)
                    fp.flush()
                    os.fsync(fp.fileno())
                if sha_file(temporary) != expected_hash:
                    raise IconError(f"Temporary published SVG bytes corrupt: {name}")
                os.replace(temporary, target)
            finally:
                if temporary.exists():
                    temporary.unlink()
            action = "replaced-with-backup"
        else:
            raise IconError(f"Internal published SVG plan missing: {name}")

        remote_hash = sha_file(target)
        if remote_hash != expected_hash:
            raise IconError(f"Published SVG post-write hash differs: {name}; stop and preserve receipts")
        receipt.append({"SVG": name, "Action": action, "SHA256": remote_hash,
                        "Destination": str(target), "Public_URL": PUBLIC_SVG_BASE + target.name})
        with receipt_path.open("w", newline="", encoding="utf-8-sig") as fp:
            writer = csv.DictWriter(fp, fieldnames=("SVG", "Action", "SHA256", "Destination", "Public_URL"))
            writer.writeheader()
            writer.writerows(receipt)
        if progress:
            progress("publish", completed, len(sources), f"{name}: {action}, remote hash verified")
    check_source_snapshot(plain, sources)
    return receipt
