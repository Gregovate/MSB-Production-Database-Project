#!/usr/bin/env python3
"""MSB #171: validate current Plain SVGs, stage all PNGs, optionally sync canonical G: PNGs.

No fixed icon count or pinned release hash. Hard max: 32 x 32 pixels (either
axis may be smaller). Default builds and audits a versioned staging folder on the canonical Shared Drive.
--apply backs up changed canonical PNGs before replacing them, adds new PNGs,
checks SHA-256, and writes a durable receipt. It never touches editable Masters,
Plain SVGs, installed ExpertGPS, webassets, GPX or draw.io.

Inkscape layered masters (e.g. LP-Combo) require separate intentional Plain SVG
exports; this tool does not guess a layer visibility configuration.
"""
from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import uuid
import xml.etree.ElementTree as ET
import zipfile

MAX_PX = 32
CANONICAL_NAME = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*\.svg$")
CANVAS = re.compile(r"^(\d+(?:\.\d+)?)(?:px)?$")
PARK = Path(r"G:\Shared drives\Display Folders\Park Drawings\MSB GIS\Symbols")
README_URL = "https://webassets.sheboyganlights.org/images/symbols/"
COLUMNS = ("SVG", "SVG_SHA256", "PNG", "Width_PX", "Height_PX", "PNG_SHA256")


class IconError(Exception):
    """Source, renderer or destination safety gate failed."""


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def svg_canvas(name: str, data: bytes) -> tuple[int, int]:
    try:
        root = ET.fromstring(data)
    except ET.ParseError as e:
        raise IconError(f"{name}: invalid SVG XML: {e}") from e
    if root.tag != "{http://www.w3.org/2000/svg}svg":
        raise IconError(f"{name}: document root is not SVG")
    sizes = []
    for attr in ("width", "height"):
        raw = root.attrib.get(attr, "").strip()
        match = CANVAS.fullmatch(raw)
        if not match:
            raise IconError(f"{name}: {attr}={raw!r} must be in px or unitless px, "
                            "not mm, cm, inches or percentages; save the Plain SVG in pixels")
        value = float(match.group(1))
        if value < 1 or value > MAX_PX or not value.is_integer():
            raise IconError(f"{name}: {attr}={raw!r}; each canvas axis must be an "
                            f"integer from 1 through {MAX_PX}px")
        sizes.append(int(value))
    # Reject linked external files because those could change without updating the
    # hash of this source SVG and generate different PNGs later.
    for node in root.iter():
        if "inkscape.org/namespaces/inkscape" in node.tag or "sodipodi.sourceforge.net" in node.tag:
            raise IconError(f"{name}: Plain SVG retains Inkscape/Sodipodi editing elements")
        for key, value in node.attrib.items():
            if "inkscape.org/namespaces/inkscape" in key or "sodipodi.sourceforge.net" in key:
                raise IconError(f"{name}: Plain SVG retains Inkscape/Sodipodi editing attributes")
            if key.split("}")[-1] == "href" and value and not (value.startswith("#") or value.startswith("data:")):
                raise IconError(f"{name}: linked external asset {value!r}; embed before export")
    return sizes[0], sizes[1]


def png_canvas(data: bytes, filename: str) -> tuple[int, int]:
    if len(data) < 33 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise IconError(f"{filename}: PNG signature/IHDR missing")
    width, height, bits, colortype, compression, filtering, interlace = struct.unpack(">IIBBBBB", data[16:29])
    if bits != 8 or colortype != 6 or compression != 0 or filtering != 0 or interlace not in (0, 1):
        raise IconError(f"{filename}: expected 8-bit RGBA PNG (PNG color type 6)")
    if not (1 <= width <= MAX_PX and 1 <= height <= MAX_PX):
        raise IconError(f"{filename}: exported {width} x {height}px exceeds maximum {MAX_PX} x {MAX_PX}px")
    return width, height


def choose_inkscape(explicit: str | None) -> str:
    if explicit:
        if not Path(explicit).is_file() and not shutil.which(explicit):
            raise IconError(f"Inkscape executable not found: {explicit}")
        return explicit
    candidates = []
    if os.name == "nt":
        candidates.append(r"C:\Program Files\Inkscape\bin\inkscape.com")
        candidates.append("inkscape.com")
    candidates.append("inkscape")
    for x in candidates:
        if Path(x).is_file() or shutil.which(x):
            return x
    raise IconError("Inkscape CLI unavailable: supply --inkscape path to inkscape.com")


def canonical_sources(folder: Path) -> dict[str, tuple[Path, str, int, int]]:
    if not folder.is_dir():
        raise IconError(f"Missing canonical Plain SVG source folder: {folder}")
    svg_paths = sorted((p for p in folder.iterdir() if p.is_file() and p.suffix.lower() == ".svg"),
                       key=lambda p: p.name.lower())
    if not svg_paths:
        raise IconError(f"No SVGs found in canonical Plain folder: {folder}")
    result = {}
    for p in svg_paths:
        if not CANONICAL_NAME.fullmatch(p.name):
            raise IconError(f"{p.name}: canonical SVG names require lowercase letters, digits, hyphens")
        if p.name.lower() in result:
            raise IconError(f"Duplicate/case-clashing SVG filename: {p.name}")
        data = p.read_bytes()
        w, h = svg_canvas(p.name, data)
        result[p.name.lower()] = (p, sha(data), w, h)
    return result


def check_source_snapshot(folder: Path, approved: dict):
    actual = canonical_sources(folder)
    if set(actual) != set(approved):
        raise IconError(f"Plain SVG set changed during run. Added: {sorted(set(actual)-set(approved))}; "
                        f"removed: {sorted(set(approved)-set(actual))}. No destination writes allowed")
    for name in approved:
        if actual[name][1] != approved[name][1]:
            raise IconError(f"Plain SVG changed during export: {name}. No destination writes allowed")


def staged_record(srcname: str, original: tuple, png_data: bytes) -> dict:
    p, source_sha, width, height = original
    out_name = p.stem + ".png"
    png_w, png_h = png_canvas(png_data, out_name)
    if (png_w, png_h) != (width, height):
        raise IconError(f"{srcname}: source says {width}x{height}px but PNG is {png_w}x{png_h}px")
    return dict(zip(COLUMNS, (p.name, source_sha, out_name, width, height, sha(png_data))))


def readme_bytes(readme_path: Path) -> bytes:
    if not readme_path.is_file():
        raise IconError(f"Existing ExpertGPS readme.txt unavailable: {readme_path}")
    data = readme_path.read_bytes()
    first = data.decode("utf-8-sig").splitlines()[0] if data else ""
    if first != README_URL:
        raise IconError(f"ExpertGPS readme first line wrong: expected {README_URL!r}, found {first!r}")
    return data


def destination_preflight(destination: Path, records: list[dict]) -> dict[str, list]:
    plan = {"add": [], "replace": [], "identical": []}
    if destination.exists() and not destination.is_dir():
        raise IconError(f"Destination is not a folder: {destination}")
    existing = {}
    if destination.exists():
        for p in destination.iterdir():
            if p.is_file():
                existing.setdefault(p.name.lower(), []).append(p)
    for record in records:
        out = record["PNG"]
        found = existing.get(out.lower(), [])
        if not found:
            plan["add"].append(record)
        elif len(found) != 1 or found[0].name != out:
            raise IconError(f"Canonical PNG destination filename-case collision for {out}; no files copied")
        elif sha_file(found[0]) == record["PNG_SHA256"]:
            plan["identical"].append(record)
        else:
            plan["replace"].append(record)
    return plan


def make_stage(root: Path) -> Path:
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    p = root / f"MSB-GIS-Icon-Sync-{stamp}-{uuid.uuid4().hex[:6]}"
    p.mkdir(parents=True, exist_ok=False)
    (p / "msb").mkdir()
    return p


def prepare_run(plain: Path, stage: Path, inkscape: str, readme: bytes):
    sources = canonical_sources(plain)  # ALL source validation before any rendering.
    records = []
    log = stage / "Inkscape-export.log"
    log.write_text(f"MSB #171 Inkscape export; source={plain}; executable={inkscape}\n", encoding="utf-8")
    for item in sources.values():
        p, expected_hash, width, height = item
        out = stage / "msb" / (p.stem + ".png")
        args = [inkscape, str(p), "--export-type=png", f"--export-filename={out}"]
        result = subprocess.run(args, capture_output=True, text=True, errors="replace", check=False)
        with log.open("a", encoding="utf-8") as fp:
            fp.write(f"\nSVG {p.name}: exit={result.returncode}\nSTDOUT: {result.stdout}\nSTDERR: {result.stderr}\n")
        if result.returncode != 0 or not out.is_file():
            raise IconError(f"{p.name}: Inkscape failed (exit {result.returncode}); "
                            f"see {log}: {result.stderr.strip()[:500]}")
        data = out.read_bytes()
        records.append(staged_record(p.name, item, data))
        if sha_file(p) != expected_hash:
            raise IconError(f"{p.name}: source modified during rendering; abort")
    check_source_snapshot(plain, sources)
    with (stage / "MSB_GIS_PNG_Manifest.csv").open("w", newline="", encoding="utf-8-sig") as fp:
        writer = csv.DictWriter(fp, fieldnames=COLUMNS)
        writer.writeheader()
        writer.writerows(records)
    (stage / "msb" / "readme.txt").write_bytes(readme)
    zip_path = stage / "MSB_GIS_Current_Staged.zip"
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for file in sorted((stage / "msb").iterdir()):
            z.write(file, "msb/" + file.name)
        z.write(stage / "MSB_GIS_PNG_Manifest.csv", "MSB_GIS_PNG_Manifest.csv")
    with zipfile.ZipFile(zip_path) as z:
        if z.testzip() is not None or len(z.namelist()) != len(records) + 2:
            raise IconError(f"Staged ZIP failed integrity / member count: {zip_path}")
    return sources, records, zip_path


def apply_canonical(destination: Path, stage: Path, records: list[dict], sources: dict, plain: Path):
    """Back up all changed assets before writes; exclusive create and verified replacement."""
    # Preflight complete source set AND all destination identities immediately before writes.
    check_source_snapshot(plain, sources)
    plan = destination_preflight(destination, records)
    backups = stage / "backups-before-replacement"
    if plan["replace"]:
        backups.mkdir()
        for row in plan["replace"]:
            existing = destination / row["PNG"]
            preserved = backups / row["PNG"]
            shutil.copy2(existing, preserved)
            if sha_file(preserved) != sha_file(existing):
                raise IconError(f"Backup verification failed: {row['PNG']}. Nothing promoted")
    if not destination.exists():
        destination.mkdir(parents=True, exist_ok=False)
    receipt = []
    for row in records:
        target = destination / row["PNG"]
        payload = (stage / "msb" / row["PNG"]).read_bytes()
        if sha(payload) != row["PNG_SHA256"]:
            raise IconError(f"Staging changed after validation: {row['PNG']}; STOP")
        if row in plan["identical"]:
            action = "identical"
            if sha_file(target) != row["PNG_SHA256"]:
                raise IconError(f"Concurrent mutation of identical target {target}")
        elif row in plan["add"]:
            # Exclusive-create ensures an unexpected concurrent new file is never overwritten.
            with target.open("xb") as fp:
                fp.write(payload)
                fp.flush()
                os.fsync(fp.fileno())
            action = "created"
        elif row in plan["replace"]:
            original = backups / row["PNG"]
            if sha_file(original) != sha_file(target):
                raise IconError(f"Concurrent mutation of target {target}; original backup retained")
            temp = destination / (".msb-sync-" + uuid.uuid4().hex + ".tmp")
            try:
                with temp.open("xb") as fp:
                    fp.write(payload)
                    fp.flush()
                    os.fsync(fp.fileno())
                if sha_file(temp) != row["PNG_SHA256"]:
                    raise IconError(f"Temporary copy corrupt for {target}")
                # Local rename/replace keeps a copy of previous contents in stage/backup.
                os.replace(temp, target)
            finally:
                if temp.exists():
                    temp.unlink()
            action = "replaced-with-backup"
        else:
            raise IconError(f"Internal promotion plan missing icon: {row['PNG']}")
        actual_hash = sha_file(target)
        if actual_hash != row["PNG_SHA256"]:
            raise IconError(f"Post-write hash mismatch for {target}; preserve receipt and backups")
        receipt.append({"PNG": row["PNG"], "Action": action, "SHA256": actual_hash, "Destination": str(target)})
        with (stage / "MSB_GIS_Promotion_Receipt.csv").open("w", newline="", encoding="utf-8-sig") as fp:
            writer = csv.DictWriter(fp, fieldnames=("PNG", "Action", "SHA256", "Destination"))
            writer.writeheader()
            writer.writerows(receipt)
    return receipt


def run(args):
    plain = Path(args.plain)
    destination = Path(args.canonical_png)
    base = Path(args.report_parent)
    base.mkdir(parents=True, exist_ok=True)
    stage = make_stage(base)
    try:
        readme = readme_bytes(Path(args.readme))
        inkscape = choose_inkscape(args.inkscape)
        sources, records, zip_path = prepare_run(plain, stage, inkscape, readme)
        # All sources & PNGs are now complete before checking destination.
        plan = destination_preflight(destination, records)
        summary = {"status": "staged", "max_canvas_px": MAX_PX,
                   "source_svg_count": len(records), "staging_zip_sha256": sha_file(zip_path),
                   "staging_zip": str(zip_path), "canonical_png": str(destination),
                   "plan": {k: len(v) for k,v in plan.items()},
                   "note": "Master-to-Plain layer variants must still be saved/exported in Inkscape.",
                   "expertgps_installed": False, "synology_published": False}
        if args.apply:
            receipt = apply_canonical(destination, stage, records, sources, plain)
            summary.update(status="applied", promoted=len(receipt))
        (stage / "MSB_GIS_Icon_Sync_Summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
        print(f"PASS: {len(records)} Plain SVGs -> {len(records)} validated RGBA PNGs (each max {MAX_PX}x{MAX_PX}px)")
        print("Canonical PNG: add={add}, replace-with-backup={replace}, identical={identical}".format(**summary["plan"]))
        print(f"Staging and receipts: {stage}")
        print("APPLIED to canonical PNG folder." if args.apply else "DRY RUN ONLY; canonical folder untouched. Run with --apply after reviewing plan.")
        print("NOT installed in ExpertGPS, Synology, browser or draw.io.")
        return summary
    except Exception as exc:
        (stage / "ERROR.txt").write_text(f"ERROR: {type(exc).__name__}: {exc}\n", encoding="utf-8")
        print(f"FAILED: {exc}\nDiagnostic stage: {stage}", file=sys.stderr)
        raise


def cli(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plain", default=str(PARK / "Plain"))
    parser.add_argument("--canonical-png", default=str(PARK / "png"))
    parser.add_argument("--readme", default=str(Path(os.getenv("LOCALAPPDATA", str(Path.home()))) / "TopoGrafix" / "Symbols" / "msb" / "readme.txt"))
    parser.add_argument("--inkscape", default=None, help="Windows uses inkscape.com by default")
    parser.add_argument("--report-parent", default=str(PARK / "release-history"))
    parser.add_argument("--apply", action="store_true", help="update canonical PNGs after validated export; backs up changed originals")
    args = parser.parse_args(argv)
    try:
        run(args)
    except (OSError, IconError, ValueError, subprocess.SubprocessError) as e:
        print(f"Sync aborted without claiming success: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(cli())