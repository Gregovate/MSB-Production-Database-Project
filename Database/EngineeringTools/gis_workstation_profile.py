#!/usr/bin/env python3
"""#171 ExpertGPS GIS workstation release: strictly read-only comparison.

An administrator-approved SHA-256 of a manifest is an external trust anchor.
Never treat fields within a self-described release as proof of approval.
No registry setters, GPX parsers/writers, or configuration import code here.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re

SCHEMA = "msb.gis.workstation.v1"
TYPES_KEY = r"Software\TopoGrafix\Common\Waypoint Types"
REVERSE_KEY = r"Software\TopoGrafix\Common\Settings\SymbolToType"
MAPS_KEY = r"Software\TopoGrafix\Common\Maps"
TYPE_FIELDS = ("Symbol Type", "GPS Symbol", "Bitmap Symbol URL")
MAP_FIELDS = ("Width", "Height", "Bits Per Pixel", "Use Worldfile Data",
              "Projection", r"Projection\EPSG", "Datum")
POINT_FIELDS = ("X", "Y", "Latitude", "Longitude", "Worldfile X", "Worldfile Y")
DIGEST = re.compile(r"^[0-9a-f]{64}$")
# Only capture known georeference values. Registration, device, account, paths
# and unrelated HKCU properties are expressly out of scope.


class ProfileError(ValueError):
    """Unverified package, missing registry state or unsafe release contents."""


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _read_values(reg, key, names):
    found = {}
    for name in names:
        try:
            value, kind = reg.QueryValueEx(key, name)
        except FileNotFoundError:
            continue
        if kind not in (reg.REG_SZ, reg.REG_DWORD):
            raise ProfileError(f"Unexpected registry value type for {name!r}")
        found[name] = str(value)
    return found


def _subkeys(reg, key):
    index = 0
    while True:
        try:
            yield reg.EnumKey(key, index)
        except OSError as exc:
            # winreg.EnumKey signals end-of-enumeration with ERROR_NO_MORE_ITEMS.
            if getattr(exc, "winerror", None) not in (259, None):
                raise
            break
        index += 1


def _open(reg, path):
    # KEY_READ prohibits writes even if caller has stronger OS permissions.
    return reg.OpenKey(reg.HKEY_CURRENT_USER, path, 0, reg.KEY_READ)


def _required_map_value(values, field):
    if field not in values:
        raise ProfileError(f"Scanned map lacks expected {field!r}; not verified")


def read_current_user(reg=None, local_symbols=None):
    """Read only the current Windows user's relevant ExpertGPS configuration.

    'reg' injection is solely for disposable fixtures. On non-Windows hosts no
    profile exists: do not pass mock data off as live workstation acceptance.
    """
    if reg is None:
        if os.name != "nt":
            raise ProfileError("Windows current-user ExpertGPS registry unavailable")
        import winreg
        reg = winreg
    if local_symbols is None:
        base = os.environ.get("LOCALAPPDATA")
        if not base:
            raise ProfileError("LOCALAPPDATA unavailable; current user cannot be proven")
        local_symbols = Path(base) / "TopoGrafix" / "Symbols" / "msb"
    else:
        local_symbols = Path(local_symbols)

    types = {}
    with _open(reg, TYPES_KEY) as root:
        for name in _subkeys(reg, root):
            with _open(reg, TYPES_KEY + "\\" + name) as key:
                # A missing field is distinct from an empty field.
                types[name] = _read_values(reg, key, TYPE_FIELDS)

    reverse = {}
    try:
        with _open(reg, REVERSE_KEY) as key:
            index = 0
            while True:
                try:
                    name, value, kind = reg.EnumValue(key, index)
                except OSError as exc:
                    if getattr(exc, "winerror", None) not in (259, None):
                        raise
                    break
                if kind != reg.REG_SZ:
                    raise ProfileError(f"Unexpected SymbolToType kind: {name!r}")
                reverse[name] = str(value)
                index += 1
    except FileNotFoundError:
        # Missing keys remain distinguishable from an approved empty dictionary
        # through 'available'; never silently certify an absent reverse table.
        reverse = None

    maps = {}
    try:
        with _open(reg, MAPS_KEY) as root:
            for name in _subkeys(reg, root):
                with _open(reg, MAPS_KEY + "\\" + name) as key:
                    vals = _read_values(reg, key, MAP_FIELDS + ("Map Path",))
                map_path = vals.pop("Map Path", "")
                points = {}
                for point in ("Point01", "Point02", "Point03"):
                    try:
                        with _open(reg, MAPS_KEY + "\\" + name + "\\" + point) as key:
                            vals_point = _read_values(reg, key, POINT_FIELDS)
                            if vals_point:
                                points[point] = vals_point
                    except FileNotFoundError:
                        continue
                image_sha = None
                if map_path and Path(map_path).is_file():
                    image_sha = sha256_file(Path(map_path))
                # Do not transmit/release a computer-specific Map Path.
                maps[name] = {"calibration": vals, "points": points,
                              "image_sha256": image_sha,
                              "image_file_verified": image_sha is not None}
    except FileNotFoundError:
        pass

    return {"types": types, "symbol_to_type": reverse, "maps": maps,
            "local_symbols": local_symbols}


def sha256_file(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _digest_field(value, label):
    if not isinstance(value, str) or not DIGEST.fullmatch(value):
        raise ProfileError(f"Invalid SHA-256 for {label}")
    return value


def _validate_named_map(mapping, label):
    if not isinstance(mapping, dict):
        raise ProfileError(f"Release {label} must be an object")
    seen = set()
    for name in mapping:
        if not isinstance(name, str) or not name or "\x00" in name:
            raise ProfileError(f"Unsafe name in {label}")
        folded = name.casefold()
        if folded in seen:
            raise ProfileError(f"Case-ambiguous entries in {label}: {name}")
        seen.add(folded)


def _release_relative(name):
    if (not isinstance(name, str) or "\\" in name or name.startswith("/") or
            not name or any(segment in ("", ".", "..") for segment in name.split("/")) or
            ":" in name):
        raise ProfileError(f"Unsafe relative release path: {name!r}")
    return name


def load_release(manifest_path, approved_manifest_sha256):
    """Read and hash-verify immutable release and every bundled portable artifact.

    Caller MUST supply a digest independently approved by the GIS administrator.
    No manifest 'approved_by' field or mutable file on the same share substitutes
    for that independent approval.
    """
    _digest_field(approved_manifest_sha256, "approved manifest")
    path = Path(manifest_path)
    if path.is_symlink() or not path.is_file():
        raise ProfileError("Approved manifest is missing or a symbolic link")
    raw = path.read_bytes()
    if sha256(raw) != approved_manifest_sha256:
        raise ProfileError("Release manifest SHA-256 disagrees with administrator pin")
    try:
        manifest = json.loads(raw)
    except (ValueError, UnicodeDecodeError) as exc:
        raise ProfileError("Release manifest is invalid JSON") from exc
    if not isinstance(manifest, dict) or manifest.get("schema") != SCHEMA:
        raise ProfileError("Unsupported GIS release manifest schema")
    for field in ("release_id", "approved_by", "approved_utc"):
        if not isinstance(manifest.get(field), str) or not manifest[field].strip():
            raise ProfileError(f"Release is missing {field}")
    for field in ("types", "symbol_to_type", "maps", "files"):
        _validate_named_map(manifest.get(field), field)
    for name, fields in manifest["types"].items():
        if not isinstance(fields, dict) or set(fields) - set(TYPE_FIELDS):
            raise ProfileError(f"Invalid Type fields: {name}")
        if any(not isinstance(v, str) for v in fields.values()):
            raise ProfileError(f"Nontext Type association: {name}")
    if any(not isinstance(v, str) for v in manifest["symbol_to_type"].values()):
        raise ProfileError("Invalid GPS Symbol reverse association")
    for name, row in manifest["maps"].items():
        if not isinstance(row, dict) or set(row) != {"calibration", "points", "image_sha256"}:
            raise ProfileError(f"Invalid calibration record: {name}")
        _validate_named_map(row["calibration"], "calibration")
        _validate_named_map(row["points"], "points")
        if set(row["calibration"]) - set(MAP_FIELDS):
            raise ProfileError(f"Unsupported map calibration field: {name}")
        if row["image_sha256"] is not None:
            _digest_field(row["image_sha256"], name)
        for point, fields in row["points"].items():
            if point not in ("Point01", "Point02", "Point03") or not isinstance(fields, dict):
                raise ProfileError(f"Unexpected scanned-map control point: {name}/{point}")
            if set(fields) - set(POINT_FIELDS):
                raise ProfileError(f"Unexpected point field: {name}/{point}")
    # The release may include an exported .map, .tfw, image, or legacy icon
    # only when each file is explicitly named and independently fingerprinted.
    for name, expected in manifest["files"].items():
        _release_relative(name)
        _digest_field(expected, name)
        item = path.parent.joinpath(*name.split("/"))
        # Resolve every ancestor, not just the leaf: a symlinked msb/
        # directory must not escape the hash-verified package root.
        if (item.is_symlink() or not item.resolve().is_relative_to(path.parent.resolve()) or
                not item.is_file()):
            raise ProfileError(f"Missing/linked release artifact: {name}")
        if sha256_file(item) != expected:
            raise ProfileError(f"Release artifact hash mismatch: {name}")
    return manifest


def _flatten(data, prefix=""):
    if not isinstance(data, dict):
        return {prefix: data}
    out = {}
    if not data:
        out[prefix] = {}
    for key, val in sorted(data.items()):
        path = prefix + "/" + key.replace("~", "~0").replace("/", "~1")
        out.update(_flatten(val, path))
    return out


def compare_release(manifest, profile, verified_base=None):
    """Produce auditable field diffs without inferring GPX semantics.

    Without a verified installed base, differences are NOT classifiable as
    remote updates versus local edits: report 'Not verified', never guess.
    """
    actual = {"types": profile["types"], "symbol_to_type": profile["symbol_to_type"],
              "maps": {}, "files": {}}
    # Strict byte checks for local PNGs and legacy aliases named in the release.
    symbols = Path(profile["local_symbols"])
    for name, digest in manifest["files"].items():
        if name.startswith("msb/"):
            rel = _release_relative(name)
            filename = rel[len("msb/"):]
            file_path = symbols.joinpath(*filename.split("/"))
            # No path escaping via nested symlinks.
            safe = (file_path.is_file() and not symbols.is_symlink() and
                    not file_path.is_symlink() and
                    file_path.resolve().is_relative_to(symbols.resolve()))
            actual["files"][name] = sha256_file(file_path) if safe else None
    expected = {"types": manifest["types"], "symbol_to_type": manifest["symbol_to_type"],
                "maps": {}, "files": {name: sha for name, sha in manifest["files"].items()
                                    if name.startswith("msb/")}}
    for name, data in manifest["maps"].items():
        expected["maps"][name] = data
    for name, data in profile["maps"].items():
        actual["maps"][name] = {"calibration": data["calibration"],
                                "points": data["points"],
                                "image_sha256": data["image_sha256"]}
    a, b = _flatten(actual), _flatten(expected)
    missing = object()
    differences = []
    for field in sorted(set(a) | set(b)):
        local, approved = a.get(field, missing), b.get(field, missing)
        if local != approved:
            differences.append({"field": field,
                                "local": "<absent>" if local is missing else local,
                                "approved": "<absent>" if approved is missing else approved})
    unverifiable = []
    for name, data in manifest["maps"].items():
        # A registry coordinate match is not proof of map image identity.
        if not data["image_sha256"] or name not in profile["maps"] or not profile["maps"][name]["image_file_verified"]:
            unverifiable.append(name)
    if not differences and not unverifiable:
        status = "Current"
    elif verified_base is None or unverifiable:
        status = "Not verified"
    else:
        # Three-way conflict classification needs the independently verified
        # previously installed approved release, never a self-reported version.
        base = _flatten(verified_base)
        local_changed = {f for f in set(a) | set(base) if a.get(f, missing) != base.get(f, missing)}
        release_changed = {f for f in set(b) | set(base) if b.get(f, missing) != base.get(f, missing)}
        overlapping = {f for f in local_changed & release_changed if a.get(f, missing) != b.get(f, missing)}
        status = ("Conflict" if overlapping else
                  "Local unpublished changes" if local_changed else "Update available")
    return {"release_id": manifest["release_id"], "status": status,
            "differences": differences, "unverifiable_maps": unverifiable,
            "workstation_accepted_for_two_way": False}


def compare_current_user(manifest_path, approved_sha256):
    """One read-only entry point used by the existing Icon Library Manager."""
    manifest = load_release(manifest_path, approved_sha256)
    local = read_current_user()
    return compare_release(manifest, local)
