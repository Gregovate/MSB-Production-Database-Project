#!/usr/bin/env python3
"""#171: Office-only targeted ExpertGPS GPX Type/icon repair with local rollback.

No full HKCU import. Maps, official GPX and Garmin are outside scope.
Existing source-only candidate: NOT an approved general workstation installer.
"""
from __future__ import annotations

from datetime import datetime, timezone
import csv
import json
import os
from pathlib import Path
import shutil
import subprocess
from uuid import uuid4

from gis_workstation_alignment import (
    OFFICE_TARGET_HOST, MANAGED_TYPE_FIELDS, PINNED_YOGA_PROPOSAL_SHA256,
    load_pinned_laptop_source, make_office_repair_plan)
from gis_workstation_profile import (
    ProfileError, TYPES_KEY, REVERSE_KEY, _open, _subkeys,
    read_current_user, sha256, sha256_file)
from gis_workstation_alignment import plan_digest
from gis_workstation_proposal import SHARED_ROOT, workstation_hostname

README_PARENT = "https://webassets.sheboyganlights.org/images/symbols/"
ALLOWED_KINDS = (1, 4)  # Windows REG_SZ and REG_DWORD
BACKUP_SCHEMA = "msb.gis.expertgps.office.backup.v1"


def assert_expertgps_closed(checker=None):
    """Fail closed if ExpertGPS process state cannot be proven closed."""
    if checker is not None:
        if not checker():
            raise ProfileError("ExpertGPS must be closed before profile mutation")
        return
    if os.name != "nt":
        raise ProfileError("ExpertGPS process check requires Windows")
    opts = {"capture_output": True, "text": True, "timeout": 12, "check": True,
            "creationflags": getattr(subprocess, "CREATE_NO_WINDOW", 0)}
    try:
        result = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], **opts)
        for row in csv.reader(result.stdout.splitlines()):
            if row and row[0].casefold().startswith("expertgps") and \
                    row[0].casefold().endswith(".exe"):
                raise ProfileError("ExpertGPS is running; close it and retry")
    except (subprocess.SubprocessError, OSError, UnicodeError) as exc:
        raise ProfileError("Unable to prove ExpertGPS is closed; STOP") from exc


def _all_values(reg, key):
    rows = {}
    i = 0
    while True:
        try:
            name, value, kind = reg.EnumValue(key, i)
        except OSError as exc:
            if getattr(exc, "winerror", None) not in (259, None):
                raise
            break
        if (kind not in ALLOWED_KINDS or
                (kind == reg.REG_SZ and not isinstance(value, str)) or
                (kind == reg.REG_DWORD and not isinstance(value, int))):
            raise ProfileError("Unsupported native registry value: " + name)
        rows[name] = {"kind": kind, "value": value}
        i += 1
    return rows


def snapshot_managed_registry(reg):
    """Complete, lossless supported fields from just two controlled branches."""
    with _open(reg, TYPES_KEY) as root:
        names = list(_subkeys(reg, root))
    types = {}
    folded = set()
    for name in names:
        if name.casefold() in folded:
            raise ProfileError("Case-ambiguous Office Type keys; stop")
        folded.add(name.casefold())
        with _open(reg, TYPES_KEY + "\\" + name) as key:
            if list(_subkeys(reg, key)):
                raise ProfileError("Nested ExpertGPS Type key unsupported: " + name)
            types[name] = _all_values(reg, key)
    with _open(reg, REVERSE_KEY) as key:
        if list(_subkeys(reg, key)):
            raise ProfileError("Unexpected SymbolToType nested keys")
        reverse = _all_values(reg, key)
    return {"types": types, "reverse": reverse}


def _replace_managed_registry(reg, desired):
    """Replace ONLY Waypoint Types child keys and SymbolToType values."""
    with _open(reg, TYPES_KEY) as root:
        current_names = list(_subkeys(reg, root))
    for name in current_names:
        # The snapshot preflight already checked these are leaf keys.
        reg.DeleteKey(reg.HKEY_CURRENT_USER, TYPES_KEY + "\\" + name)
    for name, fields in desired["types"].items():
        with reg.CreateKeyEx(reg.HKEY_CURRENT_USER, TYPES_KEY + "\\" + name,
                             0, reg.KEY_WRITE) as key:
            for field, spec in fields.items():
                reg.SetValueEx(key, field, 0, spec["kind"], spec["value"])
    with reg.OpenKey(reg.HKEY_CURRENT_USER, REVERSE_KEY,
                     0, reg.KEY_READ | reg.KEY_WRITE) as key:
        existing = list(_all_values(reg, key))
        for name in existing:
            reg.DeleteValue(key, name)
        for name, spec in desired["reverse"].items():
            reg.SetValueEx(key, name, 0, spec["kind"], spec["value"])


def _source_native_values(verified):
    proposal = verified["data"]
    if "native_registry_kinds" not in proposal:
        raise ProfileError("Native source registry kinds were not captured; stop before repair")
    types = {
        name: {field: {"kind": 1, "value": value}
               for field, value in fields.items()}
        for name, fields in proposal["types"].items()
    }
    reverse = {name: {"kind": 1, "value": value}
               for name, value in proposal["symbol_to_type"].items()}
    return {"types": types, "reverse": reverse}


def _validate_symbol_folder(symbols, canonical, names):
    folder = Path(symbols)
    canonical = Path(canonical)
    if folder.is_symlink():
        raise ProfileError("Symbol folder is linked; refuse to install")
    if not folder.parent.is_dir() or folder.parent.is_symlink():
        raise ProfileError("Current user's TopoGrafix Symbols parent unavailable")
    if folder.exists() and not folder.is_dir():
        raise ProfileError("Local MSB symbol path is not a directory")
    case_aliases = {}
    if folder.exists():
        existing = {}
        for p in folder.iterdir():
            if p.is_symlink():
                raise ProfileError("Linked old ExpertGPS symbol file refused")
            if p.is_file():
                folded = p.name.casefold()
                if folded in existing:
                    raise ProfileError("Case-ambiguous Office MSB symbol filenames")
                existing[folded] = p.name
        for name in names:
            actual_case = existing.get(name.casefold())
            if actual_case and actual_case != name:
                # The old exact-case file is safely preserved by the COMPLETE
                # private folder backup before any canonical case repair.
                case_aliases[name] = actual_case
    readme = folder / "readme.txt"
    if readme.exists():
        if readme.is_symlink() or not readme.is_file():
            raise ProfileError("Unsafe ExpertGPS readme")
        readme_lines = readme.read_text(
            encoding="utf-8-sig").splitlines()
        if not readme_lines or readme_lines[0].strip() != README_PARENT:
            raise ProfileError("Existing ExpertGPS readme URL parent unexpected")
    for name in names:
        if (canonical / name).is_symlink():
            raise ProfileError("Linked approved PNG source: " + name)
    return case_aliases


def _private_backup_root(hostname, *, base=None):
    if base is None:
        local = os.environ.get("LOCALAPPDATA")
        if not local:
            raise ProfileError("LOCALAPPDATA unavailable for private rollback backup")
        base = Path(local) / "MSB-GIS" / "ExpertGPS-Profile-Backups"
    return Path(base) / workstation_hostname(hostname)


def _save_private_backup(reg, symbols, *, host, root):
    """Capture native field kinds and entire local msb folder BEFORE mutations."""
    root = Path(root)
    if root.exists() or root.is_symlink():
        raise ProfileError("Backup destination already exists")
    root.parent.mkdir(parents=True, exist_ok=True)
    root.mkdir(exist_ok=False)
    snapshot = snapshot_managed_registry(reg)
    symbol_folder = Path(symbols)
    had_folder = symbol_folder.is_dir()
    if had_folder:
        shutil.copytree(symbol_folder, root / "original-msb",
                        symlinks=True, dirs_exist_ok=False)
        if any(p.is_symlink() for p in (root / "original-msb").rglob("*")):
            raise ProfileError("Symbol backup contains linked paths; stop")
        hashes = {}
        for f in (root / "original-msb").rglob("*"):
            if f.is_file():
                hashes[f.relative_to(root / "original-msb").as_posix()] = sha256_file(f)
    else:
        hashes = {}
    payload = {
        "schema": BACKUP_SCHEMA,
        "hostname": host,
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "had_symbols": had_folder,
        "registry": snapshot,
        "symbol_sha256": hashes,
    }
    raw = (json.dumps(payload, sort_keys=True, indent=2, ensure_ascii=False)
           + "\n").encode("utf-8")
    with (root / "backup.json").open("xb") as f:
        f.write(raw)
    if sha256_file(root / "backup.json") != sha256(raw):
        raise ProfileError("Native registry backup verification failed")
    return payload


def _restore_private_backup(reg, symbols, backup_root):
    """Restore original narrow registry branches and msb files; never maps."""
    root = Path(backup_root)
    record = json.loads((root / "backup.json").read_text("utf-8"))
    if record.get("schema") != BACKUP_SCHEMA:
        raise ProfileError("Unrecognized private Office recovery backup")
    originals = root / "original-msb"
    for name, digest in record["symbol_sha256"].items():
        if (not (originals / name).is_file() or
                sha256_file(originals / name) != digest):
            raise ProfileError("Private rollback PNG fingerprint mismatch")
    _replace_managed_registry(reg, record["registry"])
    symbols = Path(symbols)
    if symbols.is_symlink():
        raise ProfileError("Unsafe local symbols path during rollback")
    if symbols.exists():
        shutil.rmtree(symbols)
    if record["had_symbols"]:
        shutil.copytree(originals, symbols)
    if snapshot_managed_registry(reg) != record["registry"]:
        raise ProfileError("Rollback registry readback differs from backup")
    if record["had_symbols"]:
        for name, digest in record["symbol_sha256"].items():
            if sha256_file(symbols / name) != digest:
                raise ProfileError("Rollback icon SHA-256 differs from backup")
    elif symbols.exists():
        raise ProfileError("Rollback did not restore absent symbol folder")
    return record


def apply_office_repair(laptop_proposal, canonical_png, *,
                        expected_plan_sha256, local_symbols=None,
                        reg=None, shared_root=SHARED_ROOT, hostname=None,
                        private_backup_base=None, closed_checker=None,
                        approval_confirmed=False,
                        source_pin=PINNED_YOGA_PROPOSAL_SHA256):
    """One-time explicit target repair. Never silently approve the proposal.

    No mutation unless the exact preflight plan fingerprint is supplied and
    operator consent is recorded by the GUI. Crash recovery uses retained
    local backup.json + original-msb directory, not the shared G: drive.
    """
    if not approval_confirmed:
        raise ProfileError("Explicit reviewed operator confirmation required")
    host = workstation_hostname(hostname)
    if host != OFFICE_TARGET_HOST:
        raise ProfileError("Office-only repair is restricted to MSB-OFFICE-PC")
    assert_expertgps_closed(closed_checker)
    if reg is None:
        if os.name != "nt":
            raise ProfileError("Target registry mutation requires Windows")
        import winreg
        reg = winreg
    verified = load_pinned_laptop_source(
        laptop_proposal, shared_root=shared_root, approved_pin=source_pin)
    plan = make_office_repair_plan(
        laptop_proposal, canonical_png, local_symbols=local_symbols, reg=reg,
        shared_root=shared_root, hostname=host, approved_pin=source_pin)
    digest = plan_digest(plan)
    if expected_plan_sha256 != digest:
        raise ProfileError("Office settings changed since preview; redo plan")
    symbols = (Path(local_symbols) if local_symbols is not None else
               Path(os.environ["LOCALAPPDATA"]) / "TopoGrafix" /
               "Symbols" / "msb")
    desired = verified["data"]
    case_aliases = _validate_symbol_folder(
        symbols, canonical_png, [name[4:] for name in desired["files"]])
    snapshot_managed_registry(reg)  # reject unexpected Type trees/native kinds
    base = _private_backup_root(host, base=private_backup_base)
    name = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + \
        uuid4().hex[:12]
    backup = base / name
    _save_private_backup(reg, symbols, host=host, root=backup)
    assert_expertgps_closed(closed_checker)
    # The backup is now fully written and independently fingerprinted.
    mutation_started = False
    try:
        mutation_started = True
        _replace_managed_registry(reg, _source_native_values(verified))
        symbols.mkdir(parents=True, exist_ok=True)
        for relative, digest in sorted(desired["files"].items()):
            filename = relative[4:]
            source = Path(canonical_png) / filename
            if sha256_file(source) != digest:
                raise ProfileError("Canonical PNG changed during repair")
            if filename in case_aliases:
                # Windows cannot retain both Panel.png and panel.png in the
                # same directory. Preserve original under private backup, then
                # create approved canonical filename case; never alter web URLs.
                legacy = symbols / case_aliases[filename]
                if legacy.is_symlink() or not legacy.is_file():
                    raise ProfileError("Legacy symbol changed since backup: " + filename)
                legacy.unlink()
            shutil.copy2(source, symbols / filename)
            if sha256_file(symbols / filename) != digest:
                raise ProfileError("Office icon installation verification failed")
        readme = symbols / "readme.txt"
        if not readme.exists():
            readme.write_text(README_PARENT + "\n", encoding="utf-8")
        observed = read_current_user(reg=reg, local_symbols=symbols,
                                     map_names=set())
        if (observed["types"] != desired["types"] or
                observed["symbol_to_type"] != desired["symbol_to_type"]):
            raise ProfileError("Post-install ExpertGPS Type/reverse parity FAILED")
        for relative, digest in desired["files"].items():
            if sha256_file(symbols / relative[4:]) != digest:
                raise ProfileError("Post-install canonical PNG verification FAILED")
        installed_names = {entry.name.casefold(): entry.name
                           for entry in symbols.iterdir() if entry.is_file()}
        for relative in desired["files"]:
            expected_name = relative[4:]
            if installed_names.get(expected_name.casefold()) != expected_name:
                raise ProfileError(
                    "Post-install PNG case verification FAILED: " + expected_name)
        # A public/shared receipt contains NO raw HKCU, account keys or
        # private backup path. A matching machine-private receipt identifies
        # where rollback material can be found on this PC.
        public_receipt = {
            "schema": "msb.gis.expertgps.office.repair-receipt.v1",
            "status": "OFFICE GPX CONFIG MATCHES PINNED LAPTOP FIELDS/37 PNGS",
            "host": host, "source_host": "YOGA-GREG",
            "source_sha256": PINNED_YOGA_PROPOSAL_SHA256,
            "type_count": len(desired["types"]),
            "symbol_to_type_count": len(desired["symbol_to_type"]),
            "canonical_png_count": len(desired["files"]),
            "maps": "NOT READ OR MODIFIED",
            "authoritative_gpx": "NOT OPENED OR MODIFIED",
            "verified_utc": datetime.now(timezone.utc).isoformat(),
            "backup_id": name,
            "gpxtest_status": "NOT YET ACCEPTED",
        }
        report_root = Path(shared_root)
        dest_dir = report_root / "Receipts" / host
        for part in (report_root, report_root / "Receipts", dest_dir):
            if part.is_symlink():
                raise ProfileError("Linked shared repair receipt folder refused")
        dest_dir.mkdir(parents=True, exist_ok=True)
        report = dest_dir / ("Office-GPX-Repair-" + name + ".json")
        payload = (json.dumps(public_receipt, sort_keys=True, indent=2)
                   + "\n").encode("utf-8")
        with report.open("xb") as out:
            out.write(payload)
        if sha256_file(report) != sha256(payload):
            raise ProfileError("Shared Office repair receipt verification FAILED")
        receipt = dict(public_receipt)
        receipt["private_rollback_backup"] = str(backup)
        receipt["shared_receipt"] = str(report)
        with (backup / "repair-receipt.json").open("xb") as out:
            out.write((json.dumps(receipt, sort_keys=True, indent=2)
                       + "\n").encode("utf-8"))
    except Exception as failure:
        if mutation_started:
            try:
                _restore_private_backup(reg, symbols, backup)
            except Exception as recovery:
                raise ProfileError(
                    "CRITICAL: Office repair failed and AUTO-ROLLBACK FAILED. "
                    f"Private backup retained: {backup}. "
                    "Do not open ExpertGPS/GPX; investigate recovery."
                ) from recovery
        raise ProfileError(
            f"Office repair stopped; original targeted settings restored from "
            f"private backup {backup}. Error: {failure}"
        ) from failure
    return receipt


def restore_office_private_backup(backup_path, *, reg=None,
                                   local_symbols=None, hostname=None,
                                   private_backup_base=None,
                                   closed_checker=None,
                                   approval_confirmed=False):
    """User-confirmed recovery of EXACT Office private backup only.

    Does not touch unrelated application state or scanned maps. For a crash,
    the backup must still contain its original native-kind registry snapshot.
    """
    if not approval_confirmed:
        raise ProfileError("Explicit restore confirmation required")
    host = workstation_hostname(hostname)
    if host != OFFICE_TARGET_HOST:
        raise ProfileError("Recovery restricted to MSB-OFFICE-PC")
    assert_expertgps_closed(closed_checker)
    if reg is None:
        if os.name != "nt":
            raise ProfileError("Windows registry required for recovery")
        import winreg
        reg = winreg
    trusted_root = _private_backup_root(
        host, base=private_backup_base).resolve()
    backup = Path(backup_path)
    if (backup.is_symlink() or backup.resolve().parent != trusted_root or
            not backup.is_dir()):
        raise ProfileError("Backup is not directly beneath this PC's private recovery root")
    payload = json.loads((backup / "backup.json").read_text("utf-8"))
    if payload.get("hostname") != host or payload.get("schema") != BACKUP_SCHEMA:
        raise ProfileError("Private backup hostname/schema does not match Office")
    symbols = (Path(local_symbols) if local_symbols is not None else
               Path(os.environ["LOCALAPPDATA"]) / "TopoGrafix" /
               "Symbols" / "msb")
    recovered = _restore_private_backup(reg, symbols, backup)
    if snapshot_managed_registry(reg) != recovered["registry"]:
        raise ProfileError(
            "Original Office targeted registry values failed readback verification")
    for name, expected in recovered["symbol_sha256"].items():
        if sha256_file(symbols / name) != expected:
            raise ProfileError("Original Office MSB symbol failed recovery SHA-256")
    return {"status": "ORIGINAL OFFICE TYPES/REVERSE/PNGS RESTORED",
            "host": host, "source_backup": str(backup),
            "maps": "NOT READ OR MODIFIED",
            "gpx": "NOT READ OR MODIFIED"}
