# extract_drawio_with_picker.py
# Purpose:
#   Pick a draw.io file with a file dialog and export object data to CSV.
#
# Output:
#   - <original_name>_edges.csv
#   - <original_name>_vertices.csv
#
# Notes:
#   - Edge records are identified by mxCell edge="1"
#   - Vertex records are identified by mxCell vertex="1"
#   - All object attributes are preserved where practical
#   - Output files are written beside the selected .drawio file

from __future__ import annotations

import csv
import sys
import traceback
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Dict, List, Tuple
import tkinter as tk
from tkinter import filedialog, messagebox


def get_object_records(drawio_path: Path) -> Tuple[List[Dict[str, str]], List[Dict[str, str]]]:
    """Parse draw.io XML and return edge records and vertex records."""
    tree = ET.parse(drawio_path)
    root = tree.getroot()

    edges: List[Dict[str, str]] = []
    vertices: List[Dict[str, str]] = []

    for obj in root.findall(".//object"):
        record = dict(obj.attrib)

        cell = obj.find("mxCell")
        if cell is None:
            continue

        # Keep mxCell flags/metadata since they help with filtering later
        record["mx_edge"] = cell.attrib.get("edge", "")
        record["mx_vertex"] = cell.attrib.get("vertex", "")
        record["mx_parent"] = cell.attrib.get("parent", "")
        record["mx_style"] = cell.attrib.get("style", "")
        record["mx_source"] = cell.attrib.get("source", "")
        record["mx_target"] = cell.attrib.get("target", "")

        geo = cell.find("mxGeometry")
        if geo is not None:
            record["geo_x"] = geo.attrib.get("x", "")
            record["geo_y"] = geo.attrib.get("y", "")
            record["geo_width"] = geo.attrib.get("width", "")
            record["geo_height"] = geo.attrib.get("height", "")
            record["geo_relative"] = geo.attrib.get("relative", "")

        if record["mx_edge"] == "1":
            edges.append(record)
        elif record["mx_vertex"] == "1":
            vertices.append(record)

    return edges, vertices


def write_csv(rows: List[Dict[str, str]], output_path: Path) -> None:
    """Write rows to CSV using the union of all keys."""
    if not rows:
        output_path.write_text("", encoding="utf-8")
        return

    fieldnames = sorted({key for row in rows for key in row.keys()})

    with output_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def pick_file() -> Path | None:
    """Open a file picker and return the selected draw.io file path."""
    root = tk.Tk()
    root.withdraw()  # Hide the main Tk window

    file_path = filedialog.askopenfilename(
        title="Select draw.io file",
        filetypes=[
            ("draw.io files", "*.drawio *.xml"),
            ("All files", "*.*"),
        ],
    )

    root.destroy()

    if not file_path:
        return None

    return Path(file_path)


def main() -> int:
    try:
        drawio_path = pick_file()
        if drawio_path is None:
            print("No file selected. Exiting.")
            return 0

        if not drawio_path.exists():
            messagebox.showerror("File Not Found", f"Selected file does not exist:\n{drawio_path}")
            return 1

        edges, vertices = get_object_records(drawio_path)

        base_name = drawio_path.stem
        output_dir = drawio_path.parent

        edges_csv = output_dir / f"{base_name}_edges.csv"
        vertices_csv = output_dir / f"{base_name}_vertices.csv"

        write_csv(edges, edges_csv)
        write_csv(vertices, vertices_csv)

        message = (
            f"Export complete.\n\n"
            f"Edges: {len(edges)}\n"
            f"Vertices: {len(vertices)}\n\n"
            f"Files written:\n"
            f"{edges_csv}\n"
            f"{vertices_csv}"
        )
        print(message)
        messagebox.showinfo("Export Complete", message)
        return 0

    except ET.ParseError as exc:
        error_msg = f"XML parse error:\n{exc}"
        print(error_msg)
        messagebox.showerror("Parse Error", error_msg)
        return 1

    except Exception as exc:
        error_msg = f"Unexpected error:\n{exc}\n\n{traceback.format_exc()}"
        print(error_msg)
        messagebox.showerror("Unexpected Error", error_msg)
        return 1


if __name__ == "__main__":
    sys.exit(main())