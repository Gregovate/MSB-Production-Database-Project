#!/usr/bin/env python3
"""Issue #171: read-only inventory of scattered SVG sources and GIS symbol outputs.

Uses only Python standard library. No source files, PNGs, GPX, web assets, or
draw.io projects are changed. Results go to a new timestamped Downloads folder.
"""
import argparse
import collections
import csv
import hashlib
import json
import os
from pathlib import Path
import re
import sys
from datetime import datetime, timezone
from xml.etree import ElementTree as ET
import zipfile

PARK = r"G:\Shared drives\Display Folders\Park Drawings"
EXTENSIONS = {".svg", ".png", ".bmp"}
MASTER_SUFFIXES = ("-inkscape", "-inscape", "-inskape", "-inksccape")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def name_key(filename):
    value = Path(filename).stem.lower().replace("_", "-").replace(" ", "-")
    for suffix in MASTER_SUFFIXES:
        if value.endswith(suffix):
            value = value[:-len(suffix)]
            break
    return re.sub(r"-+", "-", value).strip("-")


def svg_details(data):
    try:
        root = ET.fromstring(data)
        if root.tag.split("}")[-1] != "svg":
            raise ValueError("root element is not svg")
        namespaces = ("inkscape.org/namespaces/inkscape",
                      "sodipodi.sourceforge.net/DTD/sodipodi")
        editor = 0
        for element in root.iter():
            editor += any(ns in str(element.tag) for ns in namespaces)
            editor += sum(any(ns in str(k) for ns in namespaces)
                          for k in element.attrib.keys())
        # Editor metadata is affirmative evidence, not a proof of file history.
        kind = "INKSCAPE_METADATA_PRESENT" if editor else "PLAIN_LIKE_NO_EDITOR_METADATA"
        title = next((x.text or "" for x in root.iter()
                      if isinstance(x.tag, str) and x.tag.split("}")[-1] == "title"), "")
        return kind, editor, root.get("width", ""), root.get("height", ""), root.get("viewBox", ""), title, ""
    except (ET.ParseError, ValueError, TypeError) as exc:
        return "INVALID_SVG", 0, "", "", "", "", str(exc)


def scope_for(location, park, local):
    n = location.replace("/", "\\").casefold()
    base = park.replace("/", "\\").casefold().rstrip("\\")
    if n.startswith(base + "\\msb gis\\symbols\\masters\\"):
        return "MASTERS"
    if n.startswith(base + "\\msb gis\\symbols\\plain\\"):
        return "PLAIN"
    if n.startswith(base + "\\msb gis\\symbols\\png\\"):
        return "CANONICAL_PNG"
    if n.startswith(local.replace("/", "\\").casefold().rstrip("\\") + "\\"):
        return "EXPERTGPS_LOCAL"
    return "SCATTERED"


def candidate_paths(park, local, extras, warnings):
    listed = set()
    for base in [park, *extras]:
        directory = Path(base)
        if not directory.is_dir():
            warnings.append("Unavailable scan root: " + str(directory))
            continue
        for parent, _, names in os.walk(directory):
            for filename in names:
                if Path(filename).suffix.lower() != ".svg":
                    continue
                path = Path(parent) / filename
                key = str(path).casefold()
                if key not in listed:
                    listed.add(key)
                    yield path

    for base in [Path(park) / "MSB GIS" / "Symbols" / "png", Path(local)]:
        if not base.is_dir():
            warnings.append("Unavailable output/reference root: " + str(base))
            continue
        for parent, _, names in os.walk(base):
            for filename in names:
                if Path(filename).suffix.lower() not in EXTENSIONS:
                    continue
                path = Path(parent) / filename
                key = str(path).casefold()
                if key not in listed:
                    listed.add(key)
                    yield path


def record(source, data, scope, mtime=""):
    filename = source.split("::")[-1].replace("\\", "/").split("/")[-1]
    ext = Path(filename).suffix.lower()
    kind, meta, width, height, viewbox, title, error = ("NOT_SVG", 0, "", "", "", "", "")
    if ext == ".svg":
        kind, meta, width, height, viewbox, title, error = svg_details(data)
    canonical = bool(re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*\.(?:svg|png)", filename))
    return {
        "Location": source, "Role": scope, "Filename": filename,
        "KeyHint_NotApprovedIdentity": name_key(filename),
        "Extension": ext, "Bytes": len(data), "SHA256": digest(data),
        "ModifiedUTC": mtime, "SVGClassification": kind,
        "EditorMetadataCount": meta, "SVGWidth": width, "SVGHeight": height,
        "SVGViewBox": viewbox, "SVGTitle": title,
        "NoncanonicalFilename": "YES" if scope == "PLAIN" and not canonical else "",
        "Error": error,
    }


def inventory(args):
    local = str(Path(os.environ.get("LOCALAPPDATA", str(Path.home() / "AppData" / "Local"))) /
                "TopoGrafix" / "Symbols")
    warnings = []
    rows = []
    for path in candidate_paths(args.park, local, args.extra_root, warnings):
        try:
            stat = path.stat()
            when = datetime.fromtimestamp(stat.st_mtime, timezone.utc).isoformat(timespec="seconds")
            rows.append(record(str(path), path.read_bytes(), scope_for(str(path), args.park, local), when))
        except OSError as exc:
            warnings.append(f"Could not read {path}: {exc}")

    for archive in args.archive:
        try:
            with zipfile.ZipFile(archive) as z:
                for member in z.infolist():
                    if member.is_dir() or Path(member.filename).suffix.lower() not in EXTENSIONS:
                        continue
                    rows.append(record(f"{archive}::{member.filename}", z.read(member),
                                       "HISTORICAL_ARCHIVE"))
        except (OSError, zipfile.BadZipFile) as exc:
            warnings.append(f"Could not read archive {archive}: {exc}")

    for library in args.library:
        try:
            src = Path(library).read_text(encoding="utf-8-sig").strip()
            if not (src.startswith("<mxlibrary>") and src.endswith("</mxlibrary>")):
                warnings.append(f"Not a draw.io mxlibrary wrapper: {library}")
                continue
            values = json.loads(src[len("<mxlibrary>"):-len("</mxlibrary>")])
            formats = collections.Counter(("embedded_data" if item.get("data") else
                                           "embedded_xml" if item.get("xml") else "other")
                                          for item in values)
            warnings.append(f"Library {library}: {len(values)} entries: {dict(formats)}; "
                            "contents embedded, separate from current Plain SVG files")
        except (OSError, ValueError, TypeError) as exc:
            warnings.append(f"Cannot analyze library {library}: {exc}")

    issues = []
    master_keys = {r["KeyHint_NotApprovedIdentity"] for r in rows if r["Role"] == "MASTERS" and r["Extension"] == ".svg"}
    plain_keys = {r["KeyHint_NotApprovedIdentity"] for r in rows if r["Role"] == "PLAIN" and r["Extension"] == ".svg"}
    for row in rows:
        key, role = row["KeyHint_NotApprovedIdentity"], row["Role"]
        if row["NoncanonicalFilename"]:
            issues.append(("NONCANONICAL_PLAIN_FILENAME", row["Location"], "Manual review; do not silently rename"))
        if row["SVGClassification"] == "INVALID_SVG":
            issues.append(("INVALID_SVG", row["Location"], row["Error"]))
        if role == "PLAIN" and row["SVGClassification"] == "INKSCAPE_METADATA_PRESENT":
            issues.append(("PLAIN_RETAINS_EDITOR_METADATA", row["Location"], "Likely not exported as clean Plain SVG"))
        if role == "MASTERS" and row["SVGClassification"] == "PLAIN_LIKE_NO_EDITOR_METADATA":
            issues.append(("MASTER_LACKS_EDITOR_METADATA", row["Location"], "Not proof it lacks editable objects; inspect revision"))
        if role == "PLAIN" and key not in master_keys:
            issues.append(("NO_MATCHING_MASTER_NAME", row["Location"], "Check alias/rename and scattered copies"))
        if role == "MASTERS" and key not in plain_keys:
            issues.append(("NO_MATCHING_PLAIN_NAME", row["Location"], "Check alternate source names and exports"))
    grouped = collections.defaultdict(list)
    for row in rows:
        if row["Extension"] == ".svg":
            grouped[row["KeyHint_NotApprovedIdentity"]].append(row)
    for key, group in grouped.items():
        hashes = {x["SHA256"] for x in group}
        if len(group) > 1 and len(hashes) > 1:
            issues.append(("MULTIPLE_SVG_REVISIONS", key,
                           f"{len(group)} SVG files / {len(hashes)} distinct byte hashes; compare, do not replace by date"))
    report = Path(args.output) if args.output else Path.home() / "Downloads" / ("MSB-GIS-Symbol-Inventory-" + datetime.now().strftime("%Y%m%d-%H%M%S"))
    report.mkdir(parents=True, exist_ok=False)

    with (report / "svg_and_raster_inventory.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(record("x.svg", b"<svg/>", "").keys()))
        writer.writeheader()
        writer.writerows(sorted(rows, key=lambda x: (x["KeyHint_NotApprovedIdentity"], x["Location"])))
    with (report / "review_required.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["Finding", "LocationOrKey", "Interpretation"])
        writer.writerows(sorted(issues))
    with (report / "summary.txt").open("w", encoding="utf-8") as f:
        f.write("MSB #171 READ-ONLY SYMBOL INVENTORY\n")
        f.write("Editor metadata is evidence, not guaranteed SVG file format identity.\n")
        f.write("No files were copied, deleted, renamed, converted, or published.\n\n")
        f.write("Files: " + str(len(rows)) + "\n")
        f.write("Role counts: " + str(dict(collections.Counter(r["Role"] for r in rows))) + "\n")
        f.write("SVG classification: " + str(dict(collections.Counter(r["SVGClassification"] for r in rows if r["Extension"] == ".svg"))) + "\n")
        f.write("Review findings: " + str(len(issues)) + "\n\n")
        f.write("\n".join(warnings) + "\n")
    print(f"Read-only inventory complete: {len(rows)} files, {len(issues)} review findings")
    print("Reports:", report)
    return 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--park", default=PARK, help="Park Drawings folder")
    parser.add_argument("--extra-root", action="append", default=[], help="Additional scattered SVG folder; repeat")
    parser.add_argument("--archive", action="append", default=[], help="Historical icon ZIP to compare; repeat")
    parser.add_argument("--library", action="append", default=[], help="draw.io XML library to summarize; repeat")
    parser.add_argument("--output", help="New report directory; must not exist")
    sys.exit(inventory(parser.parse_args()))
