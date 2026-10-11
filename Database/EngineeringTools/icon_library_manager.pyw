"""MSB #171 one-window icon manager. Start from a desktop shortcut, not PowerShell.

The canonical source is Shared Drive Symbols/Plain. Layer-derived Inkscape
masters must first be saved as the corresponding Plain SVGs. No Downloads,
no manual ZIP promotion, and no automatic ExpertGPS/web/GPX changes.
"""
from __future__ import annotations

import csv
from pathlib import Path
import os
import subprocess
import sys
import threading
import tkinter as tk
from tkinter import ttk, messagebox
from types import SimpleNamespace

# .pyw and the engineering pipeline deliberately live in the same repo folder.
from sync_gis_icons import (
    PARK, IconError, canonical_sources, check_source_snapshot, choose_inkscape,
    destination_preflight, make_stage, prepare_run, readme_bytes,
    apply_canonical, sha_file,
)

BACKGROUND = "#f5f8fb"


class Manager:
    def __init__(self, root):
        self.root = root
        self.root.title("MSB Icon Library Manager — #171")
        self.root.geometry("890x610")
        self.root.minsize(760, 540)
        self.root.configure(bg=BACKGROUND)
        self.plain = PARK / "Plain"
        self.dest = PARK / "png"
        self.releases = PARK / "release-history"
        self.readme = (Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) /
                       "TopoGrafix" / "Symbols" / "msb" / "readme.txt")
        self.snapshot = None
        self.staged = None
        self.records = None
        self.plan = None
        self.preview_images = []
        self.in_progress = False

        heading = ttk.Frame(root, padding=(20, 17))
        heading.pack(fill="x")
        ttk.Label(heading, text="MSB Icon Library Manager", font=("Segoe UI", 19, "bold")).pack(anchor="w")
        ttk.Label(heading, text="Controlled source: Shared Drive / MSB GIS / Symbols   •   Maximum 32 × 32 px per icon",
                  font=("Segoe UI", 10)).pack(anchor="w", pady=(5, 0))
        ttk.Label(heading, text="Editable Masters → reviewed Plain SVG → verified canonical PNG. No Downloads copies required.",
                  font=("Segoe UI", 10)).pack(anchor="w")

        controls = ttk.Frame(root, padding=(20, 0, 20, 10))
        controls.pack(fill="x")
        self.scan_btn = ttk.Button(controls, text="1. Check and preview icons", command=self.check)
        self.scan_btn.pack(side="left", padx=(0, 8))
        self.apply_btn = ttk.Button(controls, text="2. Save approved PNG changes", command=self.confirm_apply, state="disabled")
        self.apply_btn.pack(side="left")
        ttk.Button(controls, text="Open Plain SVG folder", command=lambda: self.open_dir(self.plain)).pack(side="right")
        ttk.Button(controls, text="Open Masters", command=lambda: self.open_dir(PARK / "Masters")).pack(side="right", padx=8)

        self.status = tk.StringVar(value="Ready. Use 'Check and preview icons' to validate every Plain SVG and render its PNG.")
        ttk.Label(root, textvariable=self.status, padding=(20, 6), font=("Segoe UI", 10)).pack(fill="x")
        body = ttk.PanedWindow(root, orient="horizontal")
        body.pack(fill="both", expand=True, padx=20, pady=8)
        left = ttk.Frame(body)
        right = ttk.Frame(body)
        body.add(left, weight=3)
        body.add(right, weight=2)
        columns = ("icon", "size", "change")
        self.tree = ttk.Treeview(left, columns=columns, show="headings", selectmode="browse")
        for name, width in (("icon", 190), ("size", 80), ("change", 140)):
            self.tree.heading(name, text={"icon":"Icon", "size":"Canvas", "change":"Destination change"}[name])
            self.tree.column(name, width=width, anchor="w")
        bar = ttk.Scrollbar(left, command=self.tree.yview)
        self.tree.configure(yscrollcommand=bar.set)
        bar.pack(side="right", fill="y")
        self.tree.pack(side="left", fill="both", expand=True)
        self.tree.bind("<<TreeviewSelect>>", self.show_preview)
        self.prev_head = ttk.Label(right, text="Select an icon to preview", font=("Segoe UI", 11, "bold"))
        self.prev_head.pack(anchor="center", pady=(10, 4))
        self.prev_image = ttk.Label(right)
        self.prev_image.pack(pady=14)
        self.preview_info = ttk.Label(right, text="", wraplength=270, justify="center")
        self.preview_info.pack(pady=5)
        ttk.Separator(root).pack(fill="x", padx=20)
        ttk.Label(root, text="Important: for layered Inkscape masters, save the correct visible layers as Plain SVG first. "
                        "This tool will never guess layer combinations or rename GPX types.",
                  padding=(20, 10), wraplength=830).pack(fill="x")
        footer = ttk.Frame(root, padding=(20, 0, 20, 15))
        footer.pack(fill="x")
        ttk.Button(footer, text="Open release history / logs", command=lambda: self.open_dir(self.releases)).pack(side="left")
        ttk.Button(footer, text="Close", command=self.root.destroy).pack(side="right")

    def open_dir(self, path):
        try:
            if not path.is_dir():
                raise FileNotFoundError(f"Folder not available: {path}")
            if os.name == "nt":
                os.startfile(str(path))
            else:
                subprocess.Popen(["xdg-open", str(path)])
        except Exception as exc:
            messagebox.showerror("Folder unavailable", str(exc))

    def set_busy(self, value):
        self.in_progress = value
        self.scan_btn.configure(state="disabled" if value else "normal")
        self.apply_btn.configure(state="disabled" if value or self.records is None or
                                 self.plan is None or not (self.plan["add"] or self.plan["replace"])
                                 else "normal")

    def async_operation(self, work, done):
        self.set_busy(True)
        def worker():
            try:
                result = work()
                self.root.after(0, lambda: done(result, None))
            except Exception as exc:
                detail = str(exc)
                self.root.after(0, lambda: done(None, detail))
        threading.Thread(target=worker, daemon=True).start()

    def check(self):
        self.snapshot = self.staged = self.records = self.plan = None
        self.tree.delete(*self.tree.get_children())
        self.status.set("Checking every SVG and rendering previews from the current Shared Drive Plain folder…")
        def work():
            # Validate source before creating a release-history folder.
            canonical_sources(self.plain)
            readme = readme_bytes(self.readme)
            stage = make_stage(self.releases)
            try:
                sources, records, archive = prepare_run(self.plain, stage, choose_inkscape(None), readme)
                plan = destination_preflight(self.dest, records)
                return sources, records, stage, plan
            except Exception as exc:
                (stage / "ERROR.txt").write_text(str(exc) + "\n", encoding="utf-8")
                raise IconError(f"{exc}\nDetails are in: {stage}") from exc
        def done(data, error):
            self.set_busy(False)
            if error:
                self.status.set("Validation stopped — no canonical PNG files changed.")
                messagebox.showerror("Icon validation needs attention", error)
                return
            self.snapshot, self.records, self.staged, self.plan = data
            groups = {}
            for group, items in self.plan.items():
                for row in items: groups[row["PNG"]] = group
            for row in self.records:
                action = {"add":"NEW", "replace":"UPDATE (backup)", "identical":"Unchanged"}[groups[row["PNG"]]]
                self.tree.insert("", "end", iid=row["PNG"], values=(row["PNG"],
                                 f'{row["Width_PX"]}×{row["Height_PX"]}', action))
            self.status.set(f"Validated {len(self.records)} icons. "
                            f"New {len(self.plan['add'])}; changes with backup {len(self.plan['replace'])}; "
                            f"unchanged {len(self.plan['identical'])}. See the list below.")
            self.set_busy(False)
        self.async_operation(work, done)

    def show_preview(self, _event=None):
        selection = self.tree.selection()
        if not selection or self.staged is None:
            return
        name = selection[0]
        p = self.staged / "msb" / name
        self.prev_head.configure(text=name)
        try:
            photo = tk.PhotoImage(file=str(p))
            ratio = max(1, min(6, 180 // max(photo.width(), photo.height())))
            larger = photo.zoom(ratio, ratio)
            self.preview_images = [photo, larger]
            self.prev_image.configure(image=larger)
            old = self.dest / name
            self.preview_info.configure(text=("Previous PNG exists. A backup will be saved before replacement."
                                             if old.is_file() and name in {r['PNG'] for r in self.plan['replace']}
                                             else "Source: current Shared Drive Plain SVG."))
        except Exception as exc:
            self.preview_info.configure(text=f"Preview unavailable: {exc}")

    def confirm_apply(self):
        if self.in_progress or self.records is None:
            return
        changes = len(self.plan["add"]) + len(self.plan["replace"])
        if not changes:
            return
        if not messagebox.askyesno("Confirm canonical PNG update",
                                   f"Update {changes} approved PNG file(s) in:\n{self.dest}\n\n"
                                   f"{len(self.plan['add'])} new, {len(self.plan['replace'])} replacements with backups.\n"
                                   "Plain/Masters, ExpertGPS, webassets, GPX and draw.io are NOT changed. Proceed?"):
            return
        self.status.set("Checking unchanged source snapshot and current destination, then updating canonical PNGs…")
        def work():
            receipt = apply_canonical(self.dest, self.staged, self.records, self.snapshot, self.plain)
            return receipt
        def done(receipt, error):
            self.set_busy(False)
            if error:
                self.status.set("Promotion stopped; check logs and any partial receipt. No success claimed.")
                messagebox.showerror("Canonical PNG update stopped", error + "\nSee release history: " + str(self.staged))
                return
            self.status.set(f"Done. {len(receipt)} PNGs verified in the canonical Shared Drive library.")
            self.plan = {"add": [], "replace": [], "identical": self.records}
            self.set_busy(False)
            messagebox.showinfo("Verified canonical library",
                                f"All {len(receipt)} PNGs verified. Receipt and backups:\n{self.staged}\n\n"
                                "ExpertGPS/web/draw.io were NOT changed.")
        self.async_operation(work, done)


def main():
    root = tk.Tk()
    ttk.Style().theme_use("clam")
    Manager(root)
    root.mainloop()


if __name__ == "__main__":
    main()