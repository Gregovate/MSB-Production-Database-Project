#!/usr/bin/env python3
"""#171 controlled Garmin BMP derivative builder; no device or GPX writes.

Input is the APPROVED Plain SVG derivative PNG folder and an independently
reviewed Type-to-symbol JSON manifest. BMP names are explicitly mapped; never
infer identifiers from legacy Garmin snapshots. Runs preview-only by default.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path
import re
import sys

LIBRARY = Path(r"G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbol Library")
MAGENTA = (255, 0, 255)
NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,62}$")


class GarminSyncError(ValueError):
    pass


def digest(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def load_registry(path: Path) -> list[dict]:
    """Example: {"symbols":[{"type":"Panel","source":"panel.png","symbol":"PANEL"}]}."""
    data = json.loads(path.read_text(encoding="utf-8"))
    records = data.get("symbols")
    if not isinstance(records, list) or not records:
        raise GarminSyncError("Approved nonempty symbols registry is required")
    types, symbols, sources = set(), set(), set()
    for row in records:
        if not isinstance(row, dict) or set(row) != {"type", "source", "symbol"}:
            raise GarminSyncError("Each registry entry requires type, source and symbol only")
        t, src, sym = row["type"], row["source"], row["symbol"]
        if not isinstance(t, str) or not t.strip() or not isinstance(src, str) or not isinstance(sym, str):
            raise GarminSyncError("Malformed Type/source/symbol")
        if not NAME.fullmatch(sym) or not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*\.png", src):
            raise GarminSyncError(f"Unsafe source or Garmin filename: {src!r} -> {sym!r}")
        if t.casefold() in types or sym.casefold() in symbols:
            raise GarminSyncError("Conflicting Type or Garmin symbol name")
        types.add(t.casefold())
        symbols.add(sym.casefold())
        sources.add(src)
    return records


def bmp_from_png(png: bytes, filename: str) -> tuple[bytes, tuple[int, int]]:
    try:
        from PIL import Image
    except ImportError as exc:
        raise GarminSyncError("Pillow required for reviewed Garmin BMP conversion") from exc
    with Image.open(io.BytesIO(png)) as image:
        if image.format != "PNG":
            raise GarminSyncError(f"{filename}: source must be PNG")
        image.load()
        if not (1 <= image.width <= 32 and 1 <= image.height <= 32):
            raise GarminSyncError(f"{filename}: exceeds 32x32 Garmin limit")
        rgba = image.convert("RGBA")
        # The Garmin's BMP format has no alpha: solid pixels are preserved,
        # transparent pixels become the documented magenta transparency key.
        # A 24-bit Garmin BMP cannot store partial alpha. Apply an explicit
        # midpoint opacity threshold to anti-aliased edges, retaining the
        # original visible RGB and using magenta only for transparent pixels.
        pixels = list(rgba.get_flattened_data())
        if any(px[:3] == MAGENTA and px[3] >= 128 for px in pixels):
            raise GarminSyncError(f"{filename}: visible magenta conflicts with transparency key")
        rgb = Image.new("RGB", rgba.size, MAGENTA)
        rgb.putdata([px[:3] if px[3] >= 128 else MAGENTA for px in pixels])
        output = io.BytesIO()
        rgb.save(output, format="BMP")
        value = output.getvalue()
        if int.from_bytes(value[28:30], "little") != 24:
            raise GarminSyncError("BMP exporter produced unexpected bit depth")
        return value, rgba.size


def prepare(registry: Path, approved_png: Path, output: Path, *, apply: bool = False) -> dict:
    mapping = load_registry(registry)
    if not approved_png.is_dir():
        raise GarminSyncError(f"Approved PNG folder missing: {approved_png}")
    if output.exists() and not output.is_dir():
        raise GarminSyncError("Destination is not a directory")
    pending, report = {}, []
    for row in mapping:
        src = approved_png / row["source"]
        if not src.is_file() or src.is_symlink():
            raise GarminSyncError(f"Missing/invalid approved PNG: {src}")
        data = src.read_bytes()
        payload, dimensions = bmp_from_png(data, src.name)
        filename = row["symbol"] + ".bmp"
        dest = output / filename
        if dest.is_symlink():
            raise GarminSyncError(f"Refuse symlink destination: {dest}")
        old = dest.read_bytes() if dest.is_file() else None
        action = "create" if old is None else ("identical" if old == payload else "replace")
        pending[filename] = payload
        report.append(dict(type=row["type"], source=src.name,
                           source_sha256=digest(data), symbol=row["symbol"],
                           bmp=filename, bmp_sha256=digest(payload),
                           width=dimensions[0], height=dimensions[1], bit_depth=24, action=action))
    # Read all inputs and validate all destinations before any optional write.
    if apply:
        if output.exists() and any((output / name).is_file() and (output / name).read_bytes() != data
                                   for name, data in pending.items()):
            raise GarminSyncError("Replacement requires separate reviewed backup/install workflow; no writes made")
        output.mkdir(parents=True, exist_ok=True)
        for name, data in pending.items():
            target = output / name
            if not target.exists():
                with target.open("xb") as stream:
                    stream.write(data)
            if digest(target.read_bytes()) != digest(data):
                raise GarminSyncError(f"Post-write mismatch: {target}")
    return {"registry_sha256": digest(registry.read_bytes()), "source": str(approved_png),
            "destination": str(output), "applied": apply, "icons": report}


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--registry", required=True, type=Path,
                   help="Reviewed and approved explicit Type/source/Garmin symbol JSON")
    p.add_argument("--png", type=Path, default=LIBRARY / "png")
    p.add_argument("--bmp", type=Path, default=LIBRARY / "bmp")
    p.add_argument("--apply-additions-only", action="store_true",
                   help="Allow new canonical BMPs only; existing differing files fail closed")
    args = p.parse_args(argv)
    try:
        report = prepare(args.registry, args.png, args.bmp, apply=args.apply_additions_only)
    except (GarminSyncError, OSError, ValueError) as exc:
        print(f"STOP: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
