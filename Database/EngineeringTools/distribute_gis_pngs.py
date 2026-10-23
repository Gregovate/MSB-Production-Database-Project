#!/usr/bin/env python3
"""#171: controlled PNG distribution from current canonical G: Symbols/png.

Two independent destinations:
 * Synology public webassets/images/symbols/msb (legacy assets preserved)
 * Current Windows user's LOCALAPPDATA/TopoGrafix/Symbols/msb (readme preserved)

No implicit publishing, GPX rewriting or legacy cleanup. The manager requires
a valid source snapshot, approved matching canonical PNGs, read-only diff,
separate explicit operator confirmation, backups and per-file SHA receipts.
"""
from __future__ import annotations

import csv
import os
from pathlib import Path
import re
import shutil
import uuid

from sync_gis_icons import (IconError, check_source_snapshot, destination_preflight,
                            png_canvas, readme_bytes, preview_readme_bytes, sha_file)

WEB_PNG = Path(r"\\192.168.5.4\webassets\images\symbols\msb")
PUBLIC_PNG_BASE = "https://webassets.sheboyganlights.org/images/symbols/msb/"
EXPERTGPS_RELATIVE = Path("TopoGrafix") / "Symbols" / "msb"
FILENAME = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*\.png$")


def local_expertgps_folder():
    """Always use this Windows account; never another user's explicit profile."""
    local = os.environ.get("LOCALAPPDATA")
    if not local:
        raise IconError("LOCALAPPDATA unavailable: cannot identify current user's ExpertGPS symbols")
    return Path(local) / EXPERTGPS_RELATIVE


def checked_canonical_pngs(plain, canonical_png, sources, records):
    """Whole-library, exact approved SHA/canvas check before any distribution."""
    check_source_snapshot(plain, sources)
    if len(records) != len(sources):
        raise IconError("Staged icon count differs from current Plain source set")
    unique = set()
    for row in records:
        name = row["PNG"]
        stem = row["SVG"]
        if (not FILENAME.fullmatch(name) or name in unique or
                stem not in sources or Path(stem).stem + ".png" != name):
            raise IconError(f"Unapproved PNG identity: {stem} -> {name}")
        unique.add(name)
        source_path, source_hash, width, height = sources[stem]
        if (row["SVG_SHA256"] != source_hash or
                int(row["Width_PX"]) != width or int(row["Height_PX"]) != height):
            raise IconError(f"Source snapshot differs from reviewed icon: {name}")
    if {row["SVG"] for row in records} != set(sources):
        raise IconError("Staged PNG identities do not cover the entire Plain source set")
    state = destination_preflight(canonical_png, records)
    if len(state["identical"]) != len(records):
        raise IconError(
            f"Canonical Symbols/png not current: {len(state['add'])} missing and "
            f"{len(state['replace'])} different. Use 'Save approved PNG changes' first."
        )
    for row in records:
        p = canonical_png / row["PNG"]
        raw = p.read_bytes()
        if png_canvas(raw, row["PNG"]) != (int(row["Width_PX"]), int(row["Height_PX"])):
            raise IconError(f"Canonical PNG canvas does not match approved Plain SVG: {row['PNG']}")
        if sha_file(p) != row["PNG_SHA256"]:
            raise IconError(f"Canonical PNG hash differs from approved preview: {row['PNG']}")
    return True


def png_distribution_preflight(kind, destination, plain, canonical_png, sources, records,
                               local_readme=None):
    """Read-only reviewed difference. First-run user msb provisioning is opt-in.

    The obsolete local_readme argument is retained for existing callers; the
    verified source URL comes from the controlled preview_readme_bytes() helper,
    never another Windows account's readme or a guessed external URL.
    """
    if kind not in ("web", "expertgps"):
        raise IconError(f"Unknown PNG distribution kind: {kind}")
    checked_canonical_pngs(plain, canonical_png, sources, records)
    if kind == "web":
        if not destination.is_dir():
            raise IconError(f"web destination folder is unavailable (not created): {destination}")
        return destination_preflight(destination, records)

    # Never allow a caller to install in a different user's profile.
    if destination != local_expertgps_folder():
        raise IconError("ExpertGPS target must be the current Windows user's LOCALAPPDATA msb folder")
    if not destination.parent.is_dir():
        raise IconError(f"ExpertGPS Symbols parent folder unavailable: {destination.parent}; "
                        "open/install ExpertGPS for this Windows user first")
    if destination.is_symlink() or getattr(destination, "is_junction", lambda: False)():
        raise IconError("ExpertGPS msb destination must not be a symbolic link or junction")
    if not destination.is_dir() and destination.exists():
        raise IconError(f"ExpertGPS msb destination is not a directory: {destination}")

    # A missing msb folder is normal on an otherwise installed ExpertGPS PC.
    # destination_preflight() only reads the directory and will plan all PNGs
    # as NEW when it does not exist. No local files are created here.
    plan = destination_preflight(destination, records)
    plan["create_local_folder"] = not destination.is_dir()
    readme = destination / "readme.txt"
    if readme.is_file():
        readme_bytes(readme)  # Reject incorrect URL, preserve valid full bytes.
        plan["create_readme"] = False
    elif readme.exists():
        raise IconError(f"ExpertGPS readme.txt is not a regular file: {readme}")
    else:
        plan["create_readme"] = True
    return plan


def _write_local_readme(folder: Path):
    """Create only approved canonical metadata; never overwrite existing bytes."""
    target = folder / "readme.txt"
    with target.open("xb") as out:
        out.write(preview_readme_bytes())
        out.flush()
        os.fsync(out.fileno())
    readme_bytes(target)
    return target


def _first_install_expertgps(destination, canonical_png, plain, sources, records,
                             stage, progress=None):
    """Stage all symbols and metadata, then expose first-use msb in one rename.

    Failure before rename removes only our disposable folder; unrelated
    TopoGrafix symbols and legacy aliases are never modified.
    """
    temp = destination.parent / (".msb-icon-setup-" + uuid.uuid4().hex + ".tmp")
    temp.mkdir(exist_ok=False)
    receipt_path = stage / "MSB_GIS_expertgps_PNG_Distribution_Receipt.csv"
    rows = []
    try:
        _write_local_readme(temp)
        if progress:
            progress("distribute", 0, len(records), "Preparing first-use ExpertGPS msb icons")
        for index, row in enumerate(records, 1):
            name = row["PNG"]
            source = canonical_png / name
            if sha_file(source) != row["PNG_SHA256"]:
                raise IconError(f"Canonical PNG changed during first-use ExpertGPS install: {name}")
            target = temp / name
            with target.open("xb") as out, source.open("rb") as src:
                shutil.copyfileobj(src, out)
                out.flush()
                os.fsync(out.fileno())
            if sha_file(target) != row["PNG_SHA256"]:
                raise IconError(f"First-use ExpertGPS PNG hash mismatch: {name}")
            rows.append(dict(PNG=name, Action="created", SHA256=row["PNG_SHA256"],
                             Destination=str(destination / name), Public_URL=""))
            if progress:
                progress("distribute", index, len(records), f"{name}: staged; hash verified")
        checked_canonical_pngs(plain, canonical_png, sources, records)
        readme_bytes(temp / "readme.txt")
        if destination.exists() or destination.is_symlink():
            raise IconError("ExpertGPS msb folder was created by another process; no install performed")
        temp.rename(destination)
    finally:
        if temp.exists():
            shutil.rmtree(temp)
    # A receipt is written only after the whole new folder becomes visible.
    with receipt_path.open("w", newline="", encoding="utf-8-sig") as fp:
        writer = csv.DictWriter(fp, fieldnames=("PNG", "Action", "SHA256",
                                                "Destination", "Public_URL"))
        writer.writeheader()
        writer.writerows(rows)
    return rows

def distribute_pngs(kind, destination, plain, canonical_png, sources, records, stage,
                    local_readme=None, progress=None):
    """Apply only after separate UI confirmation; verify destination + receipt.

    Failed/partial copy does not claim success. Backups and a per-file receipt
    remain in the existing controlled G: release-history staging folder.
    """
    if progress:
        progress("preflight", 0, None, f"Rechecking {kind} destination and all source PNG hashes")
    plan = png_distribution_preflight(kind, destination, plain, canonical_png, sources, records,
                                      local_readme=local_readme)
    if kind == "expertgps" and plan.get("create_local_folder"):
        return _first_install_expertgps(destination, canonical_png, plain, sources,
                                        records, stage, progress=progress)
    if kind == "expertgps" and plan.get("create_readme"):
        # An existing msb directory may lack only metadata. Provision it
        # exclusively after explicit GUI confirmation, never during preview.
        if not destination.is_dir():
            raise IconError("ExpertGPS msb folder disappeared during installation")
        _write_local_readme(destination)

    backup = stage / f"{kind}-png-backups-before-replacement"
    previous_hashes = {}
    if plan["replace"]:
        if progress:
            progress("backup", 0, None, f"Backing up {len(plan['replace'])} existing {kind} PNGs")
        backup.mkdir(parents=True, exist_ok=False)
        for row in plan["replace"]:
            name = row["PNG"]
            target = destination / name
            original_hash = sha_file(target)
            shutil.copy2(target, backup / name)
            if sha_file(backup / name) != original_hash or sha_file(target) != original_hash:
                raise IconError(f"Existing {kind} PNG changed while backing up: {name}")
            previous_hashes[name] = original_hash

    receipt_path = stage / f"MSB_GIS_{kind}_PNG_Distribution_Receipt.csv"
    rows = []
    if progress:
        progress("distribute", 0, len(records), f"Updating {kind} PNG files")
    for index, row in enumerate(records, 1):
        name = row["PNG"]
        if progress:
            progress("distribute", index - 1, len(records), f"Processing {name}")
        source = canonical_png / name
        if sha_file(source) != row["PNG_SHA256"]:
            raise IconError(f"Canonical source PNG changed during {kind} distribution: {name}")
        target = destination / name
        if row in plan["identical"]:
            if sha_file(target) != row["PNG_SHA256"]:
                raise IconError(f"{kind} existing identical PNG changed: {name}")
            action = "identical"
        elif row in plan["add"]:
            # Exclusive-create is fail closed on a new concurrent destination.
            with target.open("xb") as fp:
                with source.open("rb") as src:
                    shutil.copyfileobj(src, fp)
                fp.flush()
                os.fsync(fp.fileno())
            action = "created"
        elif row in plan["replace"]:
            if sha_file(target) != previous_hashes[name]:
                raise IconError(f"{kind} existing PNG changed after backup: {name}")
            tmp = destination / (".msb-png-" + uuid.uuid4().hex + ".tmp")
            try:
                with tmp.open("xb") as fp:
                    with source.open("rb") as src:
                        shutil.copyfileobj(src, fp)
                    fp.flush()
                    os.fsync(fp.fileno())
                if sha_file(tmp) != row["PNG_SHA256"]:
                    raise IconError(f"Temporary {kind} PNG corrupt: {name}")
                os.replace(tmp, target)
            finally:
                if tmp.exists():
                    tmp.unlink()
            action = "replaced-with-backup"
        else:
            raise IconError(f"Internal distribution plan missing {name}")

        if sha_file(target) != row["PNG_SHA256"]:
            raise IconError(f"Post-copy SHA256 FAILED: {kind}/{name}")
        rows.append(dict(PNG=name, Action=action, SHA256=row["PNG_SHA256"],
                         Destination=str(target),
                         Public_URL=PUBLIC_PNG_BASE + name if kind == "web" else ""))
        with receipt_path.open("w", newline="", encoding="utf-8-sig") as fp:
            writer = csv.DictWriter(fp, fieldnames=("PNG", "Action", "SHA256",
                                                    "Destination", "Public_URL"))
            writer.writeheader()
            writer.writerows(rows)
        if progress:
            progress("distribute", index, len(records), f"{name}: {action}; hash verified")
    checked_canonical_pngs(plain, canonical_png, sources, records)
    if kind == "expertgps":
        readme_bytes(destination / "readme.txt")
    return rows
