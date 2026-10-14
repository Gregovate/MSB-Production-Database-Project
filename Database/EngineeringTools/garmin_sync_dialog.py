"""#171 Garmin review workspace for existing Icon Library Manager.

Preview-only by default; separate explicit export file action. Never writes to
Garmin volume or authoritative GPX. Source registry must be operator reviewed.
"""
from __future__ import annotations

import json
from pathlib import Path
import tkinter as tk
from tkinter import ttk, filedialog, messagebox, scrolledtext

from garmin_bmp_derivatives import prepare, GarminSyncError, digest
from garmin_gpx_export import export_waypoints
from garmin_mapping_audit import inventory
from sync_gis_icons import PARK


def open_garmin_workspace(parent):
    dialog = tk.Toplevel(parent)
    dialog.title("MSB GIS Manager — Garmin symbol review")
    dialog.geometry("850x565")
    dialog.minsize(690, 450)
    dialog.transient(parent)
    dialog.columnconfigure(0, weight=1)
    dialog.rowconfigure(2, weight=1)

    inputs = ttk.Frame(dialog, padding=12)
    inputs.grid(row=0, column=0, sticky="ew")
    inputs.columnconfigure(1, weight=1)
    registry = tk.StringVar(value=str(Path(__file__).with_name('garmin_symbol_registry.json')))
    png = tk.StringVar(value=str(PARK / "png"))
    bmp = tk.StringVar(value=str(PARK / "bmp"))
    master = tk.StringVar()
    output = tk.StringVar()
    state = {"last_preview": None}

    def choose(var, *, source=True, json_only=False):
        if source:
            var.set(filedialog.askopenfilename(
                parent=dialog, title="Select reviewed source",
                filetypes=[("JSON manifest", "*.json")] if json_only else [("GPX", "*.gpx")]))
        else:
            var.set(filedialog.asksaveasfilename(
                parent=dialog, title="Select new waypoint-only Garmin export",
                defaultextension=".gpx", filetypes=[("GPX", "*.gpx")]))

    for i, (label, var, command) in enumerate([
        ("Approved Type / artwork / Garmin mapping", registry, lambda: choose(registry, json_only=True)),
        ("Approved PNG folder", png, lambda: choose_directory(png)),
        ("Proposed BMP folder", bmp, lambda: choose_directory(bmp)),
        ("Master GPX (read only)", master, lambda: choose(master)),
        ("New device export path", output, lambda: choose(output, source=False)),
    ]):
        ttk.Label(inputs, text=label).grid(row=i, column=0, sticky="w", pady=3)
        ttk.Entry(inputs, textvariable=var).grid(row=i, column=1, sticky="ew", padx=(8, 6), pady=3)
        ttk.Button(inputs, text="Browse", command=command).grid(row=i, column=2, pady=3)

    def choose_directory(var):
        selection = filedialog.askdirectory(parent=dialog, title="Select approved directory")
        if selection:
            var.set(selection)

    ttk.Label(dialog, text="Review first. The Garmin drive, authoritative GPX, and web server are never changed.",
              foreground="#a12323", padding=(12, 2)).grid(row=1, column=0, sticky="w")
    log = scrolledtext.ScrolledText(dialog, wrap="word", height=16)
    log.grid(row=2, column=0, sticky="nsew", padx=12, pady=6)
    controls = ttk.Frame(dialog, padding=(12, 0, 12, 12))
    controls.grid(row=3, column=0, sticky="ew")

    def show(info):
        log.delete("1.0", tk.END)
        log.insert(tk.END, json.dumps(info, indent=2))
        log.see("1.0")

    def inspect_master():
        try:
            if not master.get():
                raise GarminSyncError("Select the authoritative master GPX first")
            show({"Master_Type_and_GPS_Symbol_inventory":
                  inventory(Path(master.get()), Path(png.get()))})
        except (GarminSyncError, OSError, ValueError) as exc:
            show({"status": "STOP", "error": str(exc)})
            messagebox.showerror("GPX audit stopped", str(exc), parent=dialog)

    def review():
        state["last_preview"] = None
        try:
            if not registry.get():
                raise GarminSyncError("Select the reviewed mapping JSON")
            b = prepare(Path(registry.get()), Path(png.get()), Path(bmp.get()))
            review_result = {"BMP_preview": b}
            if master.get() and output.get():
                review_result["GPX_preview"] = export_waypoints(
                    Path(master.get()), Path(output.get()), Path(registry.get()))
            state["last_preview"] = review_result
            show(review_result)
            messagebox.showinfo("Review ready", "Read the change list. No files were changed.", parent=dialog)
        except (GarminSyncError, OSError, ValueError) as exc:
            show({"status": "STOP", "error": str(exc)})
            messagebox.showerror("Garmin review stopped", str(exc), parent=dialog)

    def write_export():
        if state["last_preview"] is None or "GPX_preview" not in state["last_preview"]:
            messagebox.showwarning("Preview required", "Preview the complete BMP and GPX mapping first.", parent=dialog)
            return
        if not messagebox.askyesno("Create waypoint-only file",
                "Create a NEW GPX file using the reviewed mapping?\n"
                "The original GPX, Garmin, and Symbol Library remain unchanged.", parent=dialog):
            return
        try:
            # Fail closed if reviewed inputs changed since the preview.
            before = state["last_preview"]
            refreshed_bmp = prepare(Path(registry.get()), Path(png.get()), Path(bmp.get()))
            refreshed_gpx = export_waypoints(
                Path(master.get()), Path(output.get()), Path(registry.get()))
            if before["BMP_preview"] != refreshed_bmp or before["GPX_preview"] != refreshed_gpx:
                raise GarminSyncError("Inputs or requested destination changed since preview. Review again.")
            latest = export_waypoints(Path(master.get()), Path(output.get()),
                                      Path(registry.get()), approve=True)
            show({"GPX_export_written": latest})
        except (GarminSyncError, OSError, ValueError) as exc:
            messagebox.showerror("Garmin export stopped", str(exc), parent=dialog)

    ttk.Button(controls, text="Inventory master GPX", command=inspect_master).pack(side="left")
    ttk.Button(controls, text="Review BMP + GPX mapping", command=review).pack(side="left", padx=8)
    ttk.Button(controls, text="Create reviewed GPX export", command=write_export).pack(side="left", padx=10)
    ttk.Button(controls, text="Close", command=dialog.destroy).pack(side="right")
    return dialog
