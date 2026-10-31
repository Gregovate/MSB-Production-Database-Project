"""#171 read-only GIS source change review. Approval/promotion stays with #319.

This is a workstation operator preview, not another PostGIS importer.
"""
from __future__ import annotations
from collections import Counter
from pathlib import Path
import hashlib
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
import xml.etree.ElementTree as ET

GPX = "{http://www.topografix.com/GPX/1/1}"


def read_gpx(path: Path):
    root = ET.fromstring(path.read_bytes())
    if root.tag != GPX + "gpx":
        raise ValueError("Only GPX 1.1 source files are supported")
    items = {"Waypoint": {}, "Track": {}}
    for kind, element, collection in (
        ("Waypoint", GPX + "wpt", "Waypoint"), ("Track", GPX + "trk", "Track")
    ):
        for index, item in enumerate(root.findall(element), 1):
            name = item.findtext(GPX + "name") or f"(unnamed {kind.lower()} {index})"
            key = (name, sum(k[0] == name for k in items[collection]))
            items[collection][key] = item
    return items


def compare_sources(baseline: Path, candidate: Path):
    before = read_gpx(baseline)
    after = read_gpx(candidate)
    changes = []
    for kind in ("Waypoint", "Track"):
        older, newer = before[kind], after[kind]
        for identity in sorted(set(older) | set(newer)):
            left, right = older.get(identity), newer.get(identity)
            if left is None:
                change = "Added"
            elif right is None:
                change = "Missing from candidate"
            elif ET.tostring(left) != ET.tostring(right):
                change = "Changed"
            else:
                continue
            detail = "Review evidence; design, located as-built, or unverified"
            if kind == "Waypoint" and left is not None and right is not None:
                if (left.attrib.get("lat"), left.attrib.get("lon")) != (
                    right.attrib.get("lat"), right.attrib.get("lon")
                ):
                    detail = "Coordinates changed — waypoint recalibration review required"
                elif left.findtext(GPX + "sym") != right.findtext(GPX + "sym"):
                    detail = "GPS symbol changed; geometry unchanged"
                else:
                    detail = "Waypoint metadata changed"
            if kind == "Track" and left is not None and right is not None:
                pts = lambda v: [(p.attrib.get("lat"), p.attrib.get("lon"))
                                 for p in v.iter(GPX + "trkpt")]
                detail = ("Recorded geometry changed; review design vs painted-locate as-built"
                          if pts(left) != pts(right) else "Track metadata changed")
            changes.append((kind, identity[0], change, detail))
    return changes


def open_review(parent):
    window = tk.Toplevel(parent)
    window.title("MSB GIS Manager — GPX source change review")
    window.geometry("1050x640")
    window.minsize(750, 450)
    window.transient(parent)
    frame = ttk.Frame(window, padding=14)
    frame.pack(fill="both", expand=True)
    ttk.Label(frame, text="GIS Data Management — Review GPX changes",
              font=("Segoe UI", 16, "bold")).pack(anchor="w")
    ttk.Label(frame, text="Compare a maintained baseline to a new source. No database or GPX files are changed.",
              wraplength=990).pack(anchor="w", pady=(4, 10))
    inputs = ttk.Frame(frame)
    inputs.pack(fill="x")
    inputs.columnconfigure(1, weight=1)
    baseline, candidate = tk.StringVar(), tk.StringVar()
    def browse(target):
        path = filedialog.askopenfilename(parent=window, title="Choose GPX source",
                                          filetypes=[("GPX files", "*.gpx")])
        if path:
            target.set(path)
    for index, (label, var) in enumerate((("Maintained baseline GPX", baseline),
                                          ("New source GPX", candidate))):
        ttk.Label(inputs, text=label).grid(row=index, column=0, sticky="w", pady=3)
        ttk.Entry(inputs, textvariable=var).grid(row=index, column=1, sticky="ew", padx=9)
        ttk.Button(inputs, text="Browse", command=lambda v=var: browse(v)).grid(row=index, column=2)
    summary = tk.StringVar(value="Choose two GPX files, then compare.")
    ttk.Label(frame, textvariable=summary).pack(anchor="w", pady=(12, 6))
    tableframe = ttk.Frame(frame)
    tableframe.pack(fill="both", expand=True)
    tree = ttk.Treeview(tableframe, columns=("type", "name", "change", "review"), show="headings")
    for col, width in (("type", 95), ("name", 235), ("change", 180), ("review", 470)):
        tree.heading(col, text={"type":"Object", "name":"Name", "change":"Detected change",
                                "review":"What needs review"}[col])
        tree.column(col, width=width, stretch=(col == "review"))
    scroll = ttk.Scrollbar(tableframe, orient="vertical", command=tree.yview)
    tree.configure(yscrollcommand=scroll.set)
    scroll.pack(side="right", fill="y")
    tree.pack(side="left", fill="both", expand=True)
    def run():
        tree.delete(*tree.get_children())
        try:
            if not baseline.get() or not candidate.get():
                raise ValueError("Select both GPX files")
            changes = compare_sources(Path(baseline.get()), Path(candidate.get()))
        except (OSError, ValueError, ET.ParseError) as error:
            messagebox.showerror("Comparison stopped", str(error), parent=window)
            return
        tally = Counter(row[2] for row in changes)
        summary.set(f"{len(changes)} changes: " +
                    ", ".join(f"{count} {label.lower()}" for label, count in sorted(tally.items())) +
                    ". Unchanged items hidden.")
        for row in changes:
            tree.insert("", "end", values=row)
    controls = ttk.Frame(frame)
    controls.pack(fill="x", pady=(9, 0))
    ttk.Button(controls, text="Compare changes (read only)", command=run).pack(side="left")
    ttk.Label(controls, text="Approval and PostGIS promotion require the governed #319 workflow.",
              foreground="#8b4b16").pack(side="left", padx=15)
    ttk.Button(controls, text="Close", command=window.destroy).pack(side="right")
    return window
