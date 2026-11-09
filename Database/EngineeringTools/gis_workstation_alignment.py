#!/usr/bin/env python3
"""#171 Office ExpertGPS GPX-settings alignment plan. Nothing writes in this file.

YOGA-GREG is the current operator-approved source for waypoint Types,
SymbolToType and canonical 37 PNGs. MSB-OFFICE-PC is the reconciliation
target. Maps, GPX, Garmin, app licensing and all other HKCU keys are excluded.

The verified proposal digest below is from the administrator's independent
laptop GUI submission screenshot, NOT a reusable workstation release approval
signature. Actual mutation must be separately approved and reversible.
"""
from __future__ import annotations

from pathlib import Path
import os

from gis_workstation_profile import ProfileError, read_current_user, sha256_file
from gis_workstation_proposal import SHARED_ROOT, workstation_hostname
from gis_workstation_release_candidate import inspect_saved_proposal

# Approved initial proposal input identity. Do NOT treat this as a general
# permission to synchronize other PCs or substitute future files by name.
LAPTOP_SOURCE_HOST = "YOGA-GREG"
OFFICE_TARGET_HOST = "MSB-OFFICE-PC"
PINNED_YOGA_PROPOSAL_SHA256 = (
    "bf09186a9913973c85aecd64f5290e3dd0efdb93459395557013af376e30cfc1"
)
MANAGED_TYPE_FIELDS = ("Symbol Type", "GPS Symbol", "Bitmap Symbol URL")


def load_pinned_laptop_source(path, shared_root=SHARED_ROOT, *,
                              approved_pin=PINNED_YOGA_PROPOSAL_SHA256):
    """Exact approved-source evidence; never infer trust from file name."""
    verified = inspect_saved_proposal(
        path, shared_root=shared_root, expected_sha256=approved_pin)
    if verified["hostname"] != LAPTOP_SOURCE_HOST:
        raise ProfileError("Only the YOGA-GREG master proposal may be used")
    source = verified["data"]
    if source.get("symbol_to_type") is None:
        raise ProfileError("Laptop source is missing the reverse symbol table")
    if (len(source["types"]) != 59 or len(source["files"]) != 37 or
            source["approval_status"] != "UNAPPROVED"):
        raise ProfileError("Unexpected laptop source identity/count; reapprove before use")
    if not source["maps"]:
        raise ProfileError("Pinned laptop evidence lacks calibrated map context")
    for name, fields in source["types"].items():
        if not isinstance(fields, dict):
            raise ProfileError("Unexpected Type fields in laptop source: " + name)
        if set(fields) - set(MANAGED_TYPE_FIELDS):
            raise ProfileError("Unrecognized laptop Type setting: " + name)
        if any(not isinstance(v, str) for v in fields.values()):
            raise ProfileError("Invalid laptop Type registry value: " + name)
    return verified


def plan_digest(plan):
    """Stable fingerprint of the exact reviewed no-write repair changes."""
    import json
    from gis_workstation_profile import sha256
    return sha256(json.dumps(plan, sort_keys=True, ensure_ascii=False).encode("utf-8"))


def make_office_repair_plan(laptop_proposal, canonical_png, *, local_symbols=None,
                            reg=None, shared_root=SHARED_ROOT, hostname=None,
                            approved_pin=PINNED_YOGA_PROPOSAL_SHA256):
    """Office-only pilot plan used by the separately gated backup/installer."""
    host = workstation_hostname(hostname)
    if host != OFFICE_TARGET_HOST:
        raise ProfileError("Pilot Office repair is restricted to MSB-OFFICE-PC")
    return make_target_alignment_plan(
        laptop_proposal, canonical_png, local_symbols=local_symbols,
        reg=reg, shared_root=shared_root, hostname=host,
        approved_pin=approved_pin)


def make_target_alignment_plan(laptop_proposal, canonical_png, *, local_symbols=None,
                               reg=None, shared_root=SHARED_ROOT, hostname=None,
                               approved_pin=PINNED_YOGA_PROPOSAL_SHA256):
    """READ ONLY for any target PC, including future Show PC.

    This is inspection, not permission to install on an unknown computer.
    Never read/copy map registration values or touch official GPX.
    """
    host = workstation_hostname(hostname)
    if host == LAPTOP_SOURCE_HOST:
        raise ProfileError("Master laptop is not a target workstation")
    verified = load_pinned_laptop_source(
        laptop_proposal, shared_root=shared_root, approved_pin=approved_pin)
    desired = verified["data"]
    office = read_current_user(reg=reg, local_symbols=local_symbols,
                               map_names=set())  # Do not even inspect map values
    if office["symbol_to_type"] is None:
        raise ProfileError("Office reverse GPS Symbol table missing; investigate first")
    current_types = office["types"]
    desired_types = desired["types"]
    target_symbols = Path(office["local_symbols"])
    root = Path(canonical_png)
    if not root.is_dir() or root.is_symlink():
        raise ProfileError("Canonical PNG source missing or linked")

    type_actions = []
    for name in sorted(set(current_types) | set(desired_types), key=str.casefold):
        if name not in desired_types:
            type_actions.append({"action": "remove_obsolete_Office_Type",
                                 "type": name, "current": current_types[name],
                                 "laptop": None})
        elif name not in current_types:
            type_actions.append({"action": "add_laptop_Type", "type": name,
                                 "current": None, "laptop": desired_types[name]})
        else:
            before = current_types[name]
            after = desired_types[name]
            changed = {field: {"office": before.get(field, "<absent>"),
                               "laptop": after.get(field, "<absent>")}
                       for field in MANAGED_TYPE_FIELDS
                       if before.get(field) != after.get(field)}
            if changed:
                type_actions.append({"action": "update_Type_fields", "type": name,
                                     "changes": changed})
    reverse_actions = []
    current_reverse = office["symbol_to_type"]
    for sym in sorted(set(current_reverse) | set(desired["symbol_to_type"]),
                      key=str.casefold):
        old = current_reverse.get(sym)
        new = desired["symbol_to_type"].get(sym)
        if old != new:
            reverse_actions.append({"gps_symbol": sym,
                                    "action": ("remove" if new is None else "set"),
                                    "office": old, "laptop": new})
    icon_actions = []
    # NTFS is usually case-insensitive: an old Panel.png can resolve when
    # opening canonical panel.png, but the on-disk case still matters.
    existing_names = {}
    if target_symbols.is_dir():
        for entry in target_symbols.iterdir():
            if entry.is_file():
                folded = entry.name.casefold()
                if folded in existing_names:
                    raise ProfileError("Case-ambiguous existing MSB symbol files")
                existing_names[folded] = entry.name
    for relative, expected in sorted(desired["files"].items()):
        if not relative.startswith("msb/") or "/" in relative[4:] or "\\" in relative:
            raise ProfileError("Unsafe laptop PNG name")
        name = relative[4:]
        source = root / name
        if source.is_symlink() or not source.is_file() or sha256_file(source) != expected:
            raise ProfileError("Canonical PNG no longer matches pinned laptop: " + name)
        target = target_symbols / name
        if target.is_symlink() or target_symbols.is_symlink():
            raise ProfileError("Linked Office local symbols target refused")
        installed_case = existing_names.get(name.casefold())
        current_file = target_symbols / installed_case if installed_case else target
        if current_file.is_symlink():
            raise ProfileError("Linked Office icon refused: " + name)
        present_sha = sha256_file(current_file) if current_file.is_file() else None
        case_alias = installed_case is not None and installed_case != name
        if present_sha != expected or case_alias:
            icon_actions.append({
                "file": name,
                "action": ("replace_legacy_case_with_backup" if case_alias else
                           "replace_with_backup" if present_sha else "install_missing"),
                "existing_filename": installed_case,
                "case_alias": case_alias,
                "office_sha256": present_sha, "laptop_sha256": expected})
    return {
        "status": ("READ-ONLY PLAN — OFFICE NOT YET REPAIRED" if host ==
                   OFFICE_TARGET_HOST else
                   "READ-ONLY TARGET COMPARISON — INSTALLATION NOT AUTHORIZED"),
        "target_pc_hostname": host,
        "office_pc_hostname": host,
        "master_pc_hostname": LAPTOP_SOURCE_HOST,
        "pinned_laptop_proposal_sha256": approved_pin,
        "type_actions": type_actions,
        "reverse_actions": reverse_actions,
        "png_actions": icon_actions,
        "laptop_type_count": len(desired_types),
        "laptop_reverse_count": len(desired["symbol_to_type"]),
        "canonical_png_count": len(desired["files"]),
        "native_source_kinds_available": (
            isinstance(desired.get("native_registry_kinds"), dict)),
        "office_types_before": len(current_types),
        "office_reverse_before": len(current_reverse),
        "office_existing_maps": "NOT TOUCHED OR EVEN READ",
        "gpx": "MASTER GPX MUST NOT BE OPENED OR CHANGED",
        "required_gates": [
            "Administrator explicitly approves the complete change/removal plan",
            "ExpertGPS is confirmed closed on this Windows user",
            "Recoverable targeted registry and full local symbol-folder backup",
            "Verified REG_SZ/REG_DWORD kinds recorded for every laptop Type",
            "All Type registry native field kinds verified before any modification",
            "Only pinned laptop Type/reverse mapping and approved PNGs changed",
            "Office EvergreenParkCropped and all other map registrations untouched",
            "Post-apply Type/reverse and 37 PNG hashes independently verified",
            "Auto-rollback and local recovery receipt on any partial failure",
            "Disposable GPX roundtrip before authentic Office GPX use",
        ],
    }
