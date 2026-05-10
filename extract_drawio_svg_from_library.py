# extract_svg_icons_from_drawio_library.py
# Purpose:
#   Extract embedded SVG icons from a draw.io library XML export.
#
# What it does:
#   - Opens a file picker for the draw.io library XML file
#   - Parses the <mxlibrary> JSON payload
#   - Extracts SVGs embedded as image=data:image/svg+xml,...
#   - Saves each SVG to a chosen output folder
#   - Names files from the library item's "title"
#
# Notes:
#   - This script is intentionally conservative and readable
#   - It only extracts SVG-based icons, not PNG-based assets
#   - Duplicate names get a numeric suffix

from __future__ import annotations

import base64
import json
import re
import sys
import html
import urllib.parse
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox


def pick_input_file() -> Path | None:
    root = tk.Tk()
    root.withdraw()
    file_path = filedialog.askopenfilename(
        title="Select draw.io library XML file",
        filetypes=[
            ("XML files", "*.xml"),
            ("All files", "*.*"),
        ],
    )
    root.destroy()
    return Path(file_path) if file_path else None


def pick_output_folder() -> Path | None:
    root = tk.Tk()
    root.withdraw()
    folder_path = filedialog.askdirectory(title="Select output folder for SVG icons")
    root.destroy()
    return Path(folder_path) if folder_path else None


def sanitize_filename(name: str) -> str:
    # Keep it boring and filesystem-safe
    cleaned = re.sub(r"[^\w\- ]+", "", name).strip()
    cleaned = cleaned.replace(" ", "_")
    return cleaned or "icon"


def unique_path(base_folder: Path, base_name: str, suffix: str = ".svg") -> Path:
    candidate = base_folder / f"{base_name}{suffix}"
    if not candidate.exists():
        return candidate

    counter = 2
    while True:
        candidate = base_folder / f"{base_name}_{counter}{suffix}"
        if not candidate.exists():
            return candidate
        counter += 1


def extract_svg_data_from_xml_blob(xml_blob: str) -> str | None:
    """
    Extract the SVG payload from something like:
      image=data:image/svg+xml,PHN2ZyB4bWxucz0i...
    or
      image=data:image/svg+xml,<svg ...>
    inside the embedded draw.io XML string.
    """
    # Undo XML escaping first
    xml_blob = html.unescape(xml_blob)

    match = re.search(r"image=data:image/svg\+xml,([^\";]+)", xml_blob)
    if not match:
        return None

    payload = match.group(1)

    # URL-decode first
    payload = urllib.parse.unquote(payload)

    # In many draw.io exports the SVG is plain XML after URL-decoding.
    # In some cases it may still be base64-looking text, but your file
    # appears to contain plain SVG XML after decoding.
    # Try base64 decode first
    try:
        decoded = base64.b64decode(payload).decode("utf-8")
        if "<svg" in decoded:
            return decoded
    except Exception:
        pass

    # Fallback (plain SVG case)
    if "<svg" in payload:
        return payload

    return None


def main() -> int:
    input_file = pick_input_file()
    if input_file is None:
        print("No input file selected. Exiting.")
        return 0

    output_folder = pick_output_folder()
    if output_folder is None:
        print("No output folder selected. Exiting.")
        return 0

    try:
        raw_text = input_file.read_text(encoding="utf-8")
    except Exception as exc:
        messagebox.showerror("Read Error", f"Could not read file:\n{exc}")
        return 1

    raw_text = raw_text.strip()

    try:
        library_items = json.loads(raw_text)
    except json.JSONDecodeError:
        # Some draw.io library exports wrap the JSON in <mxlibrary> ... </mxlibrary>
        match = re.search(r"<mxlibrary>(.*)</mxlibrary>", raw_text, flags=re.DOTALL)
        if not match:
            messagebox.showerror("Parse Error", "Could not locate valid mxlibrary JSON.")
            return 1
        try:
            library_items = json.loads(match.group(1))
        except json.JSONDecodeError as exc:
            messagebox.showerror("Parse Error", f"Could not parse mxlibrary JSON:\n{exc}")
            return 1

    extracted = 0
    skipped = 0

    for item in library_items:
        title = sanitize_filename(str(item.get("title", "icon")))
        xml_blob = item.get("xml", "")

        if not xml_blob:
            skipped += 1
            continue

        svg_text = extract_svg_data_from_xml_blob(xml_blob)
        if svg_text is None:
            skipped += 1
            continue

        out_path = unique_path(output_folder, title, ".svg")
        try:
            out_path.write_text(svg_text, encoding="utf-8")
            extracted += 1
        except Exception as exc:
            messagebox.showwarning("Write Warning", f"Could not write {out_path.name}:\n{exc}")
            skipped += 1

    message = (
        f"Done.\n\n"
        f"Extracted SVGs: {extracted}\n"
        f"Skipped items: {skipped}\n\n"
        f"Output folder:\n{output_folder}"
    )
    print(message)
    messagebox.showinfo("SVG Extraction Complete", message)
    return 0


if __name__ == "__main__":
    sys.exit(main())