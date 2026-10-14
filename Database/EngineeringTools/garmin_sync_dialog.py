"""#171 Garmin review workspace for existing Icon Library Manager.

Preview-only by default; separate explicit export file action. Never writes to
Garmin volume or authoritative GPX. Source registry must be operator reviewed.
"""
from __future__ import annotations

import json
from pathlib import Path
import tkinter as tk
from tkinter import ttk, filedialog, messagebox, scrolledtext

from garmin_bmp_derivatives import GarminSyncError
from garmin_bmp_promotion import review as review_bmp_promotion, promote as promote_bmp
from garmin_gpx_export import export_waypoints
from garmin_mapping_audit import inventory
from sync_gis_icons import PARK


def open_garmin_workspace(parent):
    dialog = tk.Toplevel(parent)
    dialog.title("MSB GIS Manager — Prepare Garmin symbols")
    dialog.geometry("920x615")
    dialog.minsize(740, 490)
    dialog.transient(parent)
    dialog.columnconfigure(0, weight=1)
    dialog.rowconfigure(3, weight=1)

    header = ttk.Frame(dialog, padding=(14, 12, 14, 8))
    header.grid(row=0, column=0, sticky="ew")
    ttk.Label(header, text="Prepare Garmin symbols", font=("Segoe UI", 16, "bold")).pack(anchor="w")
    ttk.Label(header, text="1. Review artwork and symbol mapping   →   2. Save approved BMPs   →   3. Export waypoint-only GPX",
              wraplength=840).pack(anchor="w", pady=(5, 0))
    ttk.Label(header, text="The original GPX and published web symbols are not modified.",
              foreground="#42566b").pack(anchor="w", pady=(3, 0))

    options = ttk.LabelFrame(dialog, text="Advanced settings — show only when changing sources", padding=8)
    options.grid(row=1, column=0, sticky="ew", padx=12)
    options.columnconfigure(0, weight=1)
    inputs = ttk.Frame(options)
    inputs.grid(row=1, column=0, sticky="ew")
    inputs.columnconfigure(1, weight=1)
    registry = tk.StringVar(value=str(Path(__file__).with_name('garmin_symbol_registry.json')))
    png = tk.StringVar(value=str(PARK / "png"))
    bmp = tk.StringVar(value=str(PARK / "bmp"))
    master = tk.StringVar(value=str(PARK.parent / "MSB-Park-Infrastructure.gpx"))
    output = tk.StringVar()
    backups = tk.StringVar(value=str(PARK / "release-history"))
    state = {"last_preview": None}
    advanced_open = tk.BooleanVar(value=False)
    def toggle_advanced():
        if advanced_open.get():
            inputs.grid()
        else:
            inputs.grid_remove()

    ttk.Checkbutton(options, text="Show file locations and expert settings",
                    variable=advanced_open, command=toggle_advanced).grid(row=0, column=0, sticky="w")

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
        ("Separate BMP backup history folder", backups, lambda: choose_directory(backups)),
    ]):
        ttk.Label(inputs, text=label).grid(row=i, column=0, sticky="w", pady=3)
        ttk.Entry(inputs, textvariable=var).grid(row=i, column=1, sticky="ew", padx=(8, 6), pady=3)
        ttk.Button(inputs, text="Browse", command=command).grid(row=i, column=2, pady=3)

    def choose_directory(var):
        selection = filedialog.askdirectory(parent=dialog, title="Select approved directory")
        if selection:
            var.set(selection)

    toggle_advanced()
    state_label = tk.StringVar(value="Ready: review the proposed six-Type mapping and approved artwork.")
    ttk.Label(dialog, textvariable=state_label, padding=(14, 6),
              wraplength=850).grid(row=2, column=0, sticky="ew")
    log = scrolledtext.ScrolledText(dialog, wrap="word", height=16)
    log.grid(row=3, column=0, sticky="nsew", padx=12, pady=6)
    log.insert(tk.END, "Start with Step 1: Review Garmin mapping and BMP changes.\n"
               "The default mapping is still a review candidate, not a full Garmin release.\n"
               "Advanced settings contain the file paths if needed.")
    controls = ttk.Frame(dialog, padding=(12, 0, 12, 12))
    controls.grid(row=4, column=0, sticky="ew")

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
            b = review_bmp_promotion(Path(registry.get()), Path(png.get()), Path(bmp.get()))
            review_result = {"BMP_preview": b}
            if master.get() and output.get():
                review_result["GPX_preview"] = export_waypoints(
                    Path(master.get()), Path(output.get()), Path(registry.get()))
            state["last_preview"] = review_result
            state_label.set("Reviewed: check the changes below. BMP saving and GPX export each require separate approval.")
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
            refreshed_bmp = review_bmp_promotion(Path(registry.get()), Path(png.get()), Path(bmp.get()))
            refreshed_gpx = export_waypoints(
                Path(master.get()), Path(output.get()), Path(registry.get()))
            if before["BMP_preview"] != refreshed_bmp or before["GPX_preview"] != refreshed_gpx:
                raise GarminSyncError("Inputs or requested destination changed since preview. Review again.")
            latest = export_waypoints(Path(master.get()), Path(output.get()),
                                      Path(registry.get()), approve=True)
            state_label.set("New waypoint-only GPX created. Original master preserved.")
            show({"GPX_export_written": latest})
        except (GarminSyncError, OSError, ValueError) as exc:
            messagebox.showerror("Garmin export stopped", str(exc), parent=dialog)

    def promote_bmps():
        prior = state["last_preview"]
        if prior is None:
            messagebox.showwarning("Review required", "Review the BMP mapping first.", parent=dialog)
            return
        try:
            current = review_bmp_promotion(Path(registry.get()), Path(png.get()), Path(bmp.get()))
            if current != prior["BMP_preview"]:
                raise GarminSyncError("BMP plan changed since review. Review again.")
            if not backups.get():
                raise GarminSyncError("Select a separate existing backup history folder")
            target = Path(bmp.get())
            backup_root = Path(backups.get())
            if not target.is_dir() or not backup_root.is_dir():
                raise GarminSyncError("BMP destination and separate backup folder must already exist")
            changes = [r for r in current["icons"] if r["action"] != "identical"]
            if not changes:
                messagebox.showinfo("No BMP changes", "All reviewed BMPs already match.", parent=dialog)
                return
            summary = ", ".join(f"{r['action']} {r['bmp']}" for r in changes)
            if not messagebox.askyesno(
                "Approve reviewed BMP promotion",
                f"Apply {len(changes)} reviewed BMP change(s) to:\n{target}\n\n"
                f"Backups and receipt:\n{backup_root}\n\n"
                f"{summary}\n\nNo GPX or web changes. Proceed?", parent=dialog):
                return
            # The promotion module verifies the exact preview digest again.
            receipt = promote_bmp(Path(registry.get()), Path(png.get()), target,
                                  backup_root, current["review_digest"])
            state_label.set("BMP files saved and verified. Next: review again before preparing GPS waypoints.")
            show({"BMP_promotion_verified": str(receipt), "review": current})
            state["last_preview"] = None
            messagebox.showinfo("BMPs verified", f"Receipt and recovery copies:\n{receipt}", parent=dialog)
        except (GarminSyncError, OSError, ValueError) as exc:
            state["last_preview"] = None
            messagebox.showerror("BMP promotion stopped", str(exc), parent=dialog)

    ttk.Button(controls, text="1. Review mapping and artwork", command=review).pack(side="left")
    ttk.Button(controls, text="2. Save approved BMPs", command=promote_bmps).pack(side="left", padx=8)
    ttk.Button(controls, text="3. Export Garmin waypoints", command=write_export).pack(side="left", padx=8)
    ttk.Button(controls, text="Details", command=inspect_master).pack(side="left", padx=8)
    ttk.Button(controls, text="Close", command=dialog.destroy).pack(side="right")
    return dialog
