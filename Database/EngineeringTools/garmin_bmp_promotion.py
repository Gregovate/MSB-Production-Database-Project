"""#171 guarded promotion of reviewed Garmin BMP derivatives to a local folder.

No direct Garmin-volume discovery or production changes. The caller supplies a
separate backup root and the exact digest of a previously reviewed plan.
"""
from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import uuid

from garmin_bmp_derivatives import GarminSyncError, prepare, digest


def review(registry: Path, png: Path, destination: Path):
    details = prepare(registry, png, destination, apply=False)
    current = {}
    if destination.exists():
        if destination.is_symlink():
            raise GarminSyncError("Symlink destination forbidden")
        lower = {}
        for file in destination.iterdir():
            if file.is_file():
                lower.setdefault(file.name.casefold(), []).append(file.name)
        for row in details["icons"]:
            colliding = lower.get(row["bmp"].casefold(), [])
            if colliding and colliding != [row["bmp"]]:
                raise GarminSyncError("BMP filename-case collision: " + row["bmp"])
    for row in details["icons"]:
        target = destination / row["bmp"]
        if target.is_symlink():
            raise GarminSyncError("Symlink BMP forbidden")
        current[row["bmp"]] = digest(target.read_bytes()) if target.exists() else None
    details["existing_sha256"] = current
    canonical = json.dumps(details, sort_keys=True).encode("utf-8")
    details["review_digest"] = hashlib.sha256(canonical).hexdigest()
    return details


def promote(registry: Path, png: Path, destination: Path, backups: Path, approved_digest: str):
    plan = review(registry, png, destination)
    if plan["review_digest"] != approved_digest:
        raise GarminSyncError("Plan changed since review; stop and review again")
    if not backups.is_dir() or backups.is_symlink():
        raise GarminSyncError("Existing separate backup root required")
    if backups.resolve() == destination.resolve() or backups.resolve() in destination.resolve().parents:
        raise GarminSyncError("Backups may not be inside destination")
    if destination.resolve() in backups.resolve().parents:
        raise GarminSyncError("Backup root may not contain destination")
    # Initial controlled publication may create only the expected canonical bmp
    # directory. Keep unexpected paths and missing source library fail-closed.
    initial = not destination.exists()
    if initial:
        if destination.name != "bmp" or not destination.parent.is_dir() or destination.is_symlink():
            raise GarminSyncError("First BMP destination must be a new bmp folder under an existing library")
    elif not destination.is_dir() or destination.is_symlink():
        raise GarminSyncError("BMP destination is not an ordinary directory")
    release = backups / ("Garmin-BMP-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
                         + "-" + uuid.uuid4().hex[:8])
    release.mkdir(exist_ok=False)
    try:
        (release / "before").mkdir()
        for row in plan["icons"]:
            if row["action"] == "replace":
                name = row["bmp"]
                original = destination / name
                saved = release / "before" / name
                shutil.copy2(original, saved)
                if digest(saved.read_bytes()) != plan["existing_sha256"][name]:
                    raise GarminSyncError("Backup failed verification: " + name)
        (release / "review.json").write_text(json.dumps(plan, indent=2), encoding="utf-8")
        # Recompute before any destination mutation; prevents stale/mixed releases.
        if review(registry, png, destination)["review_digest"] != approved_digest:
            raise GarminSyncError("Concurrent source/destination change; no files promoted")
        if initial:
            destination.mkdir(exist_ok=False)
        # This is the first destination mutation, after the separate review
        # receipt and all preflight checks are complete.
        receipt = []
        for row in plan["icons"]:
            name = row["bmp"]
            source = png / row["source"]
            from garmin_bmp_derivatives import bmp_from_png
            payload, _ = bmp_from_png(source.read_bytes(), source.name)
            if digest(payload) != row["bmp_sha256"]:
                raise GarminSyncError("Source changed during installation: " + name)
            target = destination / name
            if row["action"] == "identical":
                pass
            elif row["action"] == "create":
                with target.open("xb") as fp:
                    fp.write(payload)
            else:
                if digest(target.read_bytes()) != plan["existing_sha256"][name]:
                    raise GarminSyncError("Destination changed since backup: " + name)
                tmp = destination / (".msb-bmp-" + uuid.uuid4().hex + ".tmp")
                try:
                    with tmp.open("xb") as fp:
                        fp.write(payload)
                    if digest(tmp.read_bytes()) != digest(payload):
                        raise GarminSyncError("Staged BMP mismatch")
                    os.replace(tmp, target)
                finally:
                    tmp.unlink(missing_ok=True)
            actual = digest(target.read_bytes())
            if actual != row["bmp_sha256"]:
                raise GarminSyncError("BMP readback mismatch: " + name)
            receipt.append({"file": name, "action": row["action"], "sha256": actual})
            (release / "receipt.json").write_text(
                json.dumps({"status": "IN_PROGRESS", "files": receipt}, indent=2), encoding="utf-8")
        (release / "receipt.json").write_text(
            json.dumps({"status": "VERIFIED", "files": receipt}, indent=2), encoding="utf-8")
        return release
    except Exception:
        (release / "FAILED_STOP.txt").write_text(
            "Promotion interrupted; preserve backups, inspect receipt and manually recover.\n",
            encoding="utf-8")
        raise
