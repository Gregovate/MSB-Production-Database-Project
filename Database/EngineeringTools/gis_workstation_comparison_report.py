#!/usr/bin/env python3
"""#171 Export Office-versus-laptop GIS difference evidence.

Text copy is in-memory; shared reporting creates new, hostname-specific evidence
only after explicit operator confirmation. Never installs settings or edits GPX.
"""
from __future__ import annotations

from datetime import datetime, timezone
import json
from pathlib import Path
import re
from uuid import uuid4

from gis_workstation_profile import ProfileError, sha256, sha256_file
from gis_workstation_proposal import SHARED_ROOT, workstation_hostname

SCHEMA = "msb.gis.workstation.comparison.v1"
NONCE = re.compile(r"^[0-9a-f]{12}$")


def format_comparison_report(comparison, office):
    """Render precisely the per-field comparisons shown in the application."""
    rows = comparison["rows"]
    lines = [
        "MSB GIS WORKSTATION CONFIGURATION COMPARISON — READ ONLY",
        "Office PC: " + office["hostname"],
        f"Office ExpertGPS Types: {comparison['office_type_count']}",
        f"YOGA-GREG laptop ExpertGPS Types: {comparison['laptop_type_count']}",
        f"Office map: {office['selected_map']}",
        "Laptop map(s): " + ", ".join(comparison["laptop_maps"]),
        f"Office canonical PNGs: {office['png_matched']} match, "
        f"{office['png_missing']} missing, {office['png_different']} different",
        "Office snapshot fingerprint: " + office["fingerprint"],
        "Laptop proposal SHA-256: " + comparison["laptop_proposal_sha256"],
        f"Field/status differences: {len(rows)}",
        "NOT AN APPROVED GIS RELEASE. NO SETTINGS INSTALLED.",
        "",
    ]
    for category, name, field, detail in rows:
        lines.append(f"{category}: {name}")
        if field:
            lines.append("  " + field)
        if detail:
            lines.append("  " + detail)
        lines.append("")
    if not rows:
        lines.append("No differences in compared fields.")
    return "\n".join(lines).rstrip() + "\n"


def save_comparison_report(comparison, office, shared_root=SHARED_ROOT, *,
                           now=None, token=None):
    """Create one new immutable-ish directory with exact TXT and JSON evidence.

    This is a saved observation, NOT an approved release or an installation.
    Existing reports never overwritten. No HKCU read/write occurs.
    """
    root = Path(shared_root)
    hostname = workstation_hostname(office["hostname"])
    if hostname != office["hostname"]:
        raise ProfileError("Office observation hostname mismatch")
    if not root.parent.is_dir() or root.parent.is_symlink():
        raise ProfileError("Shared MSB GIS folder unavailable")
    moment = now or datetime.now(timezone.utc)
    if moment.tzinfo is None:
        raise ProfileError("Report timestamp lacks timezone")
    nonce = token if token is not None else uuid4().hex[:12]
    if not NONCE.fullmatch(nonce):
        raise ProfileError("Invalid report token")
    stamp = moment.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    report_name = f"MSB-GIS-Compare-{hostname}-{stamp}-{nonce}"
    parent = root / "Comparisons" / hostname
    target = parent / report_name
    for ancestor in (root, root / "Comparisons", parent):
        if ancestor.is_symlink():
            raise ProfileError("Linked shared report folder not allowed")
    if not root.resolve().is_relative_to(root.parent.resolve()):
        raise ProfileError("Shared GIS comparison path escaped root")
    if target.exists() or target.is_symlink():
        raise ProfileError("Comparison report already exists. Refusing overwrite.")
    text = format_comparison_report(comparison, office)
    payload = {
        "schema": SCHEMA,
        "approval_status": "UNAPPROVED OBSERVATION — NOT AN INSTALL SOURCE",
        "office_pc_hostname": hostname,
        "office_snapshot_sha256": office["fingerprint"],
        "office_map": office["selected_map"],
        "laptop_proposal_sha256": comparison["laptop_proposal_sha256"],
        "laptop_maps": comparison["laptop_maps"],
        "office_type_count": comparison["office_type_count"],
        "laptop_type_count": comparison["laptop_type_count"],
        "office_png_summary": {
            "matched": office["png_matched"],
            "missing": office["png_missing"],
            "different": office["png_different"],
        },
        "differences": [{
            "category": category, "name": name, "field": field,
            "detail": detail
        } for category, name, field, detail in comparison["rows"]],
        "captured_utc": moment.astimezone(timezone.utc).isoformat(),
    }
    raw = (json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True)
           + "\n").encode("utf-8")
    parent.mkdir(parents=True, exist_ok=True)
    for ancestor in (root, root / "Comparisons", parent):
        if ancestor.is_symlink():
            raise ProfileError("Linked shared report folder not allowed")
    # A unique new directory makes both files one visible report entity.
    target.mkdir(exist_ok=False)
    with (target / "comparison.txt").open("xb") as out:
        out.write(text.encode("utf-8"))
    with (target / "comparison.json").open("xb") as out:
        out.write(raw)
    text_hash = sha256_file(target / "comparison.txt")
    json_hash = sha256_file(target / "comparison.json")
    if text_hash != sha256(text.encode("utf-8")) or json_hash != sha256(raw):
        raise ProfileError("Shared comparison report post-write verification failed")
    return {
        "directory": str(target),
        "text_file": str(target / "comparison.txt"),
        "text_sha256": text_hash,
        "json_file": str(target / "comparison.json"),
        "json_sha256": json_hash,
        "differences": len(comparison["rows"]),
        "status": "UNAPPROVED report saved; NO PC settings modified",
    }
