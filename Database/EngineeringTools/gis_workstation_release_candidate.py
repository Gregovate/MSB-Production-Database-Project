#!/usr/bin/env python3
"""#171: independently review saved workstation proposals and stage safe candidates.

Candidates are NEVER administrator-approved releases or installable PC profiles.
No HKCU, GPX, calibration, PNG source, PostGIS or approved Release writes.
"""
from __future__ import annotations
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import shutil
import uuid

from gis_workstation_profile import ProfileError, sha256, sha256_file
from gis_workstation_proposal import SHARED_ROOT, PROPOSAL_SCHEMA, workstation_hostname

CANDIDATE_SCHEMA = "msb.gis.workstation.candidate.v1"
DIGEST = re.compile(r"^[0-9a-f]{64}$")
TOKEN = re.compile(r"^[0-9a-f]{12}$")


def _within(path: Path, root: Path):
    if not path.resolve().is_relative_to(root.resolve()):
        raise ProfileError("Path escapes controlled GIS workstation root")
    check = path
    while check != root.parent:
        if check.is_symlink():
            raise ProfileError("Linked GIS proposal/package path not allowed")
        if check == root:
            break
        if check.parent == check:
            raise ProfileError("Shared source not beneath GIS configuration root")
        check = check.parent


def _strict_json(path: Path):
    try:
        return json.loads(path.read_bytes())
    except (OSError, ValueError, UnicodeDecodeError) as exc:
        raise ProfileError("Missing or malformed workstation proposal") from exc


def inspect_saved_proposal(source, shared_root=SHARED_ROOT, *, expected_sha256=None):
    """Inspect an existing file, never bless self-declared approval or path."""
    root = Path(shared_root)
    source = Path(source)
    if not root.is_dir() or not source.is_file():
        raise ProfileError("Shared GIS workstation proposal unavailable")
    _within(source, root)
    if source.parent.parent != root / "Proposals":
        raise ProfileError("Proposal must live in a host-named G: Proposals folder")
    pc = workstation_hostname(source.parent.name)
    if source.parent.name != pc or not source.name.startswith(
            "MSB-GIS-Workstation-Proposal-" + pc + "-"):
        raise ProfileError("Proposal filename and host folder disagree")
    if source.suffix != ".json":
        raise ProfileError("Not an MSB GIS proposal JSON file")
    actual_sha = sha256_file(source)
    if expected_sha256 is not None and expected_sha256 != actual_sha:
        raise ProfileError("Proposal bytes differ from the externally reviewed SHA")
    data = _strict_json(source)
    if not isinstance(data, dict) or data.get("schema") != PROPOSAL_SCHEMA:
        raise ProfileError("File is not an UNAPPROVED MSB GIS proposal")
    if (data.get("approval_status") != "UNAPPROVED" or
            data.get("source_pc_hostname") != pc):
        raise ProfileError("Proposal approval/hostname field mismatch")
    for name in ("types", "symbol_to_type", "maps", "files",
                 "approved_plain_source_sha256"):
        if not isinstance(data.get(name), dict):
            raise ProfileError("Proposal missing expected configuration " + name)
    if not data["types"] or not data["files"] or not data["maps"]:
        raise ProfileError("Proposal Types, PNGs and selected map are required")
    if not isinstance(data.get("review_items"), list):
        raise ProfileError("Proposal historical/external URL review list absent")
    if not isinstance(data.get("captured_utc"), str) or not data["captured_utc"]:
        raise ProfileError("Proposal capture time is missing")
    for name, fields in data["types"].items():
        if not isinstance(name, str) or not name or not isinstance(fields, dict):
            raise ProfileError("Malformed ExpertGPS Type")
        if (set(fields) - {"Symbol Type", "GPS Symbol", "Bitmap Symbol URL"} or
                any(not isinstance(v, str) for v in fields.values())):
            raise ProfileError("Malformed ExpertGPS Type field")
    if any(not isinstance(v, str) for v in data["symbol_to_type"].values()):
        raise ProfileError("Invalid GPS Symbol reverse association")
    for name, digest in data["files"].items():
        if (not isinstance(name, str) or not name.startswith("msb/") or
                "/" in name[4:] or "\\" in name or
                not DIGEST.fullmatch(str(digest))):
            raise ProfileError("Unsafe/invalid proposed PNG name or SHA-256")
    for name, entry in data["maps"].items():
        if (not isinstance(name, str) or not name or not isinstance(entry, dict) or
                set(entry) != {"calibration", "points", "image_sha256"} or
                not DIGEST.fullmatch(str(entry.get("image_sha256"))) or
                not isinstance(entry["calibration"], dict) or
                not isinstance(entry["points"], dict)):
            raise ProfileError("Unverifiable scanned-map proposal")
    for item in data["review_items"]:
        if (not isinstance(item, dict) or not
                all(isinstance(item.get(k), str) for k in ("type", "reason", "url")) or
                item["type"] not in data["types"]):
            raise ProfileError("Invalid historical-marker review item")
    return {"path": str(source), "sha256": actual_sha, "hostname": pc,
            "types": len(data["types"]), "pngs": len(data["files"]),
            "maps": len(data["maps"]), "review_items": data["review_items"],
            "data": data, "status": "UNAPPROVED; NO INSTALLATION AUTHORIZED"}


def candidate_destination(shared_root, host, *, now=None, token=None):
    moment = now or datetime.now(timezone.utc)
    if moment.tzinfo is None:
        raise ProfileError("Candidate timestamp lacks timezone")
    nonce = token or uuid.uuid4().hex[:12]
    if not TOKEN.fullmatch(nonce):
        raise ProfileError("Unsafe candidate token")
    stamp = moment.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return Path(shared_root) / "Candidates" / (
        f"MSB-GIS-CANDIDATE-{workstation_hostname(host)}-{stamp}-{nonce}")


def prepare_release_candidate(source, canonical_png, *,
                              shared_root=SHARED_ROOT, reviewed_sha256,
                              save=False, now=None, token=None):
    """Revalidate exact reviewed proposal and artwork; optionally stage candidate.

    A staged candidate intentionally lacks approved_by/approved_utc and uses a
    different schema than Step 6's approved manifest. Portable maps are NOT
    bundled until reviewed/exported separately.
    """
    if not isinstance(reviewed_sha256, str) or not DIGEST.fullmatch(reviewed_sha256):
        raise ProfileError("Exact reviewed proposal SHA-256 required")
    reviewed = inspect_saved_proposal(
        source, shared_root, expected_sha256=reviewed_sha256)
    data = reviewed["data"]
    root = Path(shared_root)
    png_root = Path(canonical_png)
    if png_root.is_symlink() or not png_root.is_dir():
        raise ProfileError("Canonical PNG folder unavailable or linked")
    for name, expected in data["files"].items():
        target = png_root / name[4:]
        if target.is_symlink() or not target.is_file() or sha256_file(target) != expected:
            raise ProfileError("Canonical artwork changed since the source proposal: " + name)
    destination = candidate_destination(
        root, reviewed["hostname"], now=now, token=token)
    candidate = {
        "schema": CANDIDATE_SCHEMA,
        "status": "UNAPPROVED; NOT INSTALLABLE",
        "source_pc_hostname": reviewed["hostname"],
        "source_proposal_sha256": reviewed_sha256,
        "types": data["types"],
        "symbol_to_type": data["symbol_to_type"],
        "maps": data["maps"],
        "files": data["files"],
        "review_items": data["review_items"],
        "gates": [
            "Administrator must review all historical Map Marker URLs",
            "Map imagery and .map/.tfw portable sidecars are not packaged",
            "Verify Show PC ExpertGPS is closed and backups/rollback exist",
            "Administrator must publish an independently approved immutable release",
            "Office full aerial must be reviewed separately",
        ],
    }
    raw = (json.dumps(candidate, indent=2, sort_keys=True,
                      ensure_ascii=False) + "\n").encode("utf-8")
    if save:
        parent = destination.parent
        if parent.is_symlink():
            raise ProfileError("Linked candidate destination not permitted")
        parent.mkdir(parents=True, exist_ok=True)
        if destination.exists() or destination.is_symlink():
            raise ProfileError("Candidate already exists; never overwrite")
        destination.mkdir(exist_ok=False)
        try:
            (destination / "msb").mkdir()
            for name, digest in sorted(data["files"].items()):
                file = destination / "msb" / name[4:]
                shutil.copyfile(png_root / name[4:], file)
                if sha256_file(file) != digest:
                    raise ProfileError("Candidate packaged PNG hash mismatch")
            with (destination / "candidate.json").open("xb") as stream:
                stream.write(raw)
            if sha256_file(destination / "candidate.json") != sha256(raw):
                raise ProfileError("Candidate JSON post-write hash mismatch")
        except Exception:
            # Preserve failed candidate for administrator forensics. Never
            # remove partially committed files or claim publication succeeded.
            raise
    return {
        "status": "UNAPPROVED candidate staged" if save else "Candidate preflight only",
        "source_pc_hostname": reviewed["hostname"],
        "destination": str(destination),
        "candidate_sha256_not_approval": sha256(raw),
        "proposal_sha256": reviewed_sha256,
        "types": len(data["types"]), "pngs": len(data["files"]),
        "maps": len(data["maps"]), "review_count": len(data["review_items"]),
        "gates": candidate["gates"],
    }
