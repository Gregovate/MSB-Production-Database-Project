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
import webbrowser
import queue
import tkinter as tk
from tkinter import ttk, messagebox, scrolledtext, filedialog, simpledialog
from types import SimpleNamespace

# .pyw and the engineering pipeline deliberately live in the same repo folder.
from sync_gis_icons import (
    PARK, IconError, canonical_sources, check_source_snapshot,
    destination_preflight, make_stage, prepare_run, preview_readme_bytes,
    apply_canonical, sha_file, source_freshness_warnings,
)
from publish_gis_svgs import WEB_SVG, PUBLIC_SVG_BASE, web_svg_preflight, publish_web_svgs
from distribute_gis_pngs import (WEB_PNG, PUBLIC_PNG_BASE, local_expertgps_folder,
                                 png_distribution_preflight, distribute_pngs)
from gis_workstation_profile import compare_current_user

BACKGROUND = "#f5f8fb"


class Manager:
    def __init__(self, root):
        self.root = root
        self.root.title("MSB Icon Library Manager — #171")
        # The bundled application icon is separate from GIS waypoint artwork.
        # Neither the window nor shortcut needs an installed ExpertGPS folder.
        if os.name == "nt":
            try:
                self.root.iconbitmap(default=str(Path(__file__).resolve().parent /
                                   "assets" / "MSB-Icon-Library-Manager.ico"))
            except (OSError, tk.TclError):
                # Cosmetic asset failures must not block icon validation.
                pass
        # Compact 15-inch laptop layout. The action/footer dock stays visible
        # when Windows display scaling leaves little vertical room.
        self.root.geometry("930x615")
        self.root.minsize(800, 500)
        self.root.configure(bg=BACKGROUND)
        self.plain = PARK / "Plain"
        self.dest = PARK / "png"
        self.web_svg_dest = WEB_SVG
        self.web_png_dest = WEB_PNG
        self.releases = PARK / "release-history"
        self.readme = (Path(os.environ.get("LOCALAPPDATA", str(Path.home()))) /
                       "TopoGrafix" / "Symbols" / "msb" / "readme.txt")
        self.local_png_dest = self.readme.parent
        self.snapshot = None
        self.staged = None
        self.records = None
        self.plan = None
        self.preview_images = []
        self.preview_original = None
        self.preview_zoom = 0
        self.master_warnings = []
        self.in_progress = False
        self.events = queue.Queue()
        self.progress_mode = "determinate"

        heading = ttk.Frame(root, padding=(16, 9, 16, 5))
        heading.pack(fill="x")
        ttk.Label(heading, text="MSB Icon Library Manager", font=("Segoe UI", 16, "bold")).pack(anchor="w")
        ttk.Label(heading, text="Controlled source: Shared Drive / MSB GIS / Symbols   •   Maximum 32 × 32 px per icon",
                  font=("Segoe UI", 10)).pack(anchor="w", pady=(5, 0))
        ttk.Label(heading, text="Editable Masters → reviewed Plain SVG → verified canonical PNG. No Downloads copies required.",
                  font=("Segoe UI", 10)).pack(anchor="w")

        controls = ttk.Frame(root, padding=(16, 0, 16, 5))
        controls.pack(fill="x")
        self.scan_btn = ttk.Button(controls, text="1. Check and preview icons", command=self.check)
        self.scan_btn.pack(side="left", padx=(0, 8))
        self.apply_btn = ttk.Button(controls, text="2. Save approved PNG changes", command=self.confirm_apply, state="disabled")
        self.apply_btn.pack(side="left")
        self.warnings_btn = ttk.Button(controls, text="Source review (0)",
                                       command=self.show_warnings, state="disabled")
        self.warnings_btn.pack(side="left", padx=(8, 0))
        ttk.Button(controls, text="Open Plain SVG folder", command=lambda: self.open_dir(self.plain)).pack(side="right")
        ttk.Button(controls, text="Open Masters", command=lambda: self.open_dir(PARK / "Masters")).pack(side="right", padx=8)

        self.status = tk.StringVar(value="Ready. Use 'Check and preview icons' to validate every Plain SVG and render its PNG.")
        ttk.Label(root, textvariable=self.status, padding=(16, 3), font=("Segoe UI", 10)).pack(fill="x")
        progress_frame = ttk.Frame(root, padding=(16, 0, 16, 4))
        progress_frame.pack(fill="x")
        self.progress_bar = ttk.Progressbar(progress_frame, mode="determinate", maximum=100, value=0)
        self.progress_bar.pack(side="left", fill="x", expand=True)
        self.progress_count = tk.StringVar(value="Ready")
        ttk.Label(progress_frame, textvariable=self.progress_count, width=19, anchor="e").pack(side="right", padx=(10, 0))
        self.progress_detail = tk.StringVar(value="No operation running")
        ttk.Label(root, textvariable=self.progress_detail, padding=(16, 0, 16, 3)).pack(fill="x")

        # Reserve the bottom dock BEFORE packing the expanding icon preview.
        # Tk pack allocates in order; previously the huge preview consumed the
        # available space and clipped Steps 3-6 and the Close button on laptops.
        footer = ttk.Frame(root, padding=(16, 3, 16, 8))
        footer.pack(side="bottom", fill="x")
        action_dock = ttk.Frame(root, padding=(16, 0, 16, 3))
        action_dock.pack(side="bottom", fill="x")
        body = ttk.PanedWindow(root, orient="horizontal")
        body.pack(fill="both", expand=True, padx=16, pady=(3, 3))
        left = ttk.Frame(body)
        right_shell = ttk.Frame(body)
        body.add(left, weight=3)
        body.add(right_shell, weight=2)
        # #171: Preview is both viewport-fitted and independently scrollable.
        # Large previews must not be cropped when the bottom-docked buttons
        # reserve their space on a 15-inch Windows laptop.
        self.preview_canvas = tk.Canvas(right_shell, highlightthickness=0, bd=0)
        self.preview_scroll = ttk.Scrollbar(
            right_shell, orient="vertical", command=self.preview_canvas.yview)
        self.preview_canvas.configure(yscrollcommand=self.preview_scroll.set)
        self.preview_scroll.pack(side="right", fill="y")
        self.preview_canvas.pack(side="left", fill="both", expand=True)
        right = ttk.Frame(self.preview_canvas)
        self.preview_window = self.preview_canvas.create_window(
            (0, 0), window=right, anchor="nw")
        right.bind("<Configure>", lambda _event: self.preview_canvas.configure(
            scrollregion=self.preview_canvas.bbox("all")))
        self.preview_canvas.bind("<Configure>", self.resize_preview)
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
        self.prev_image.pack(pady=4)
        self.preview_info = ttk.Label(right, text="", wraplength=270, justify="center")
        self.preview_info.pack(pady=5)
        # Wheel scrolling is local to the preview: do not steal wheel events
        # from the icon tree or other application dialogs.
        for target in (self.preview_canvas, right, self.prev_head,
                       self.prev_image, self.preview_info):
            target.bind("<MouseWheel>", self.scroll_preview)
            target.bind("<Button-4>", self.scroll_preview)
            target.bind("<Button-5>", self.scroll_preview)
        ttk.Separator(action_dock).pack(fill="x")
        ttk.Label(action_dock, text=("Layered masters: save reviewed visible layers as Plain SVG first. "
                        "The manager never changes GPX Types."),
                  padding=(0, 3), wraplength=830).pack(fill="x")
        # Keep independent operations in their own rows. On Windows with
        # display scaling, a long Step 5 label used to be squeezed offscreen
        # by the Step 4 button and an unrelated section heading.
        publication_controls = ttk.Frame(action_dock, padding=(0, 0, 0, 3))
        publication_controls.pack(fill="x")
        ttk.Label(publication_controls, text="Web publishing (Synology administrator only):").pack(
            side="left", padx=(0, 10))
        self.web_publish_btn = ttk.Button(
            publication_controls, text="3. Review/publish Plain SVGs to web",
            command=self.check_web_publish, state="disabled")
        self.web_publish_btn.pack(side="left", padx=(0, 10))
        self.web_png_btn = ttk.Button(
            publication_controls, text="4. Publish PNGs to web",
            command=lambda: self.check_png_distribution("web"), state="disabled")
        self.web_png_btn.pack(side="left")

        # #171: Missing local symbols can change ExpertGPS Type/Map Marker
        # associations even when the GPX was not intentionally saved.
        ttk.Label(action_dock,
                  text=("CRITICAL: Install local MSB symbols BEFORE opening "
                        "an MSB GPX in ExpertGPS. Missing icons can replace "
                        "MSB markers with GPS Symbol even without Save."),
                  foreground="#a12323", font=("Segoe UI", 9, "bold"),
                  wraplength=830, padding=(0, 2, 0, 2)).pack(fill="x")

        local_controls = ttk.Frame(action_dock, padding=(0, 0, 0, 3))
        local_controls.pack(fill="x")
        ttk.Label(local_controls, text="Current Windows user / local ExpertGPS:").pack(
            side="left", padx=(0, 10))
        self.local_png_btn = ttk.Button(
            local_controls, text="5. Install PNGs for this ExpertGPS user",
            command=lambda: self.check_png_distribution("expertgps"), state="disabled")
        self.local_png_btn.pack(side="left")

        # #171 first phase: compare only. No HKCU write, GPX modification, or
        # installation callback exists for this separate workstation operation.
        profile_controls = ttk.Frame(action_dock, padding=(0, 0, 0, 2))
        profile_controls.pack(fill="x")
        self.profile_check_btn = ttk.Button(
            profile_controls, text="6. Compare GIS workstation release (READ ONLY)",
            command=self.check_workstation)
        self.profile_check_btn.pack(side="left")
        self.profile_release_status = tk.StringVar(
            value="GIS workstation configuration: Not verified — no administrator-pinned release selected")
        ttk.Label(action_dock, textvariable=self.profile_release_status,
                  padding=(0, 0, 0, 2), wraplength=830).pack(fill="x")

        ttk.Button(footer, text="Open release history / logs", command=lambda: self.open_dir(
            self.releases)).pack(side="left")
        ttk.Button(footer, text="Open selected SVG URL", command=self.open_web_svg).pack(
            side="left", padx=(12, 0))
        ttk.Button(footer, text="Open selected PNG URL", command=self.open_web_png).pack(
            side="left", padx=(12, 0))
        ttk.Button(footer, text="Close", command=self.root.destroy).pack(side="right")

    def check_workstation(self):
        """Compare a hash-pinned admin release; never propose/apply local writes."""
        manifest = filedialog.askopenfilename(
            parent=self.root, title="Select administrator-approved GIS release manifest",
            initialdir=str(self.releases), filetypes=[("JSON release", "*.json")])
        if not manifest:
            return
        approved_sha = simpledialog.askstring(
            "Verify GIS release approval",
            "Paste the exact 64-character SHA-256 from the GIS administrator's"
            " separate approval receipt. The selected manifest cannot approve itself.",
            parent=self.root)
        if not approved_sha:
            return
        approved_sha = approved_sha.strip().lower()
        self.profile_release_status.set("GIS workstation configuration: Checking read-only…")

        def done(result, error):
            self.set_busy(False)
            if error:
                self.profile_release_status.set("GIS workstation configuration: Not verified")
                messagebox.showerror(
                    "GIS release comparison not verified",
                    error + "\n\nNo ExpertGPS/registry/GPX/calibration files changed.",
                    parent=self.root)
                return
            self.profile_release_status.set(
                "GIS workstation configuration: " + result["status"] +
                " — two-way GPX/PostGIS editing NOT authorized by this check")
            dialog = tk.Toplevel(self.root)
            dialog.title("GIS workstation release — read-only differences")
            dialog.geometry("850x540")
            ttk.Label(dialog, text=("Approved release: " + result["release_id"] +
                      "     Status: " + result["status"]), padding=12).pack(fill="x")
            ttk.Label(dialog, text=("Comparison only: NO installed configuration"
                      " or two-way GPX/PostGIS acceptance is implied."),
                      padding=(12, 0, 12, 8)).pack(fill="x")
            viewer = scrolledtext.ScrolledText(dialog, wrap="word", font=("Consolas", 10))
            viewer.pack(fill="both", expand=True, padx=12, pady=8)
            if result.get("unverifiable_maps"):
                viewer.insert("end", "NOT VERIFIED: scanned map image missing or unhashed: " +
                              ", ".join(result["unverifiable_maps"]) + "\n\n")
            for change in result["differences"]:
                viewer.insert("end", change["field"] + "\n  Local: " +
                              str(change["local"]) + "\n  Approved: " +
                              str(change["approved"]) + "\n\n")
            if not result["differences"]:
                viewer.insert("end", "Named Type/style, reverse mapping, asset and"
                              " scanned-map values match this verified release.\n")
            viewer.configure(state="disabled")
            ttk.Button(dialog, text="Close", command=dialog.destroy).pack(pady=(0, 10))
        self.async_operation(lambda: compare_current_user(manifest, approved_sha), done)

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
        self.profile_check_btn.configure(state="disabled" if value else "normal")
        self.apply_btn.configure(state="disabled" if value or self.records is None or
                                 self.plan is None or not (self.plan["add"] or self.plan["replace"])
                                 else "normal")
        self.web_publish_btn.configure(state="disabled" if value or self.snapshot is None
                                       or self.staged is None else "normal")
        distribute_state = ("disabled" if value or self.snapshot is None or
                            self.staged is None or self.records is None else "normal")
        self.web_png_btn.configure(state=distribute_state)
        self.local_png_btn.configure(state=distribute_state)

    def publish_progress(self, phase, completed, total, detail):
        """Safe from worker thread: only place data on a queue, never touch Tk."""
        self.events.put(("progress", phase, completed, total, detail))

    def show_progress(self, phase, completed, total, detail):
        """Only main Tk thread updates widgets; no fake time estimates."""
        phases = {"validate": "Checking sources", "render": "Rendering icons",
                  "package": "Packaging and verifying", "ready": "Preview complete",
                  "preflight": "Checking files", "backup": "Backing up originals",
                  "apply": "Saving approved PNGs", "publish": "Publishing SVGs to web",
                  "distribute": "Distributing approved PNGs",
                  "finalize": "Checking destination"}
        if total is None:
            if self.progress_mode != "indeterminate":
                self.progress_bar.configure(mode="indeterminate")
                self.progress_bar.start(12)
                self.progress_mode = "indeterminate"
            self.progress_count.set("Working…")
        else:
            if self.progress_mode != "determinate":
                self.progress_bar.stop()
                self.progress_bar.configure(mode="determinate")
                self.progress_mode = "determinate"
            total = max(1, total)
            self.progress_bar.configure(maximum=total, value=min(completed, total))
            self.progress_count.set(f"{completed} / {total} ({completed * 100 // total}%)")
        self.progress_detail.set(f"{phases.get(phase, phase)} — {detail}")

    def finish_progress(self, error):
        if self.progress_mode == "indeterminate":
            self.progress_bar.stop()
            self.progress_bar.configure(mode="determinate")
            self.progress_mode = "determinate"
        if error:
            self.progress_count.set("Stopped")
            self.progress_detail.set("Operation stopped; see error details")
        else:
            self.progress_bar.configure(maximum=100, value=100)
            self.progress_count.set("Complete")
            self.progress_detail.set("Operation completed and verified")

    def poll_worker_events(self):
        """Poll from Tk's event loop; avoids calling root.after from worker threads."""
        while True:
            try:
                event = self.events.get_nowait()
            except queue.Empty:
                break
            if event[0] == "progress":
                self.show_progress(*event[1:])
            else:
                _type, data, error, callback = event
                self.finish_progress(error)
                callback(data, error)
        if self.in_progress:
            self.root.after(75, self.poll_worker_events)

    def async_operation(self, work, done):
        self.set_busy(True)
        self.events = queue.Queue()
        self.show_progress("preflight", 0, None, "Starting operation")
        def worker():
            try:
                result = work()
                self.events.put(("done", result, None, done))
            except Exception as exc:
                self.events.put(("done", None, str(exc), done))
        threading.Thread(target=worker, daemon=True).start()
        self.root.after(75, self.poll_worker_events)

    def check(self):
        self.snapshot = self.staged = self.records = self.plan = None
        self.web_publish_btn.configure(state="disabled")
        self.web_png_btn.configure(state="disabled")
        self.local_png_btn.configure(state="disabled")
        self.master_warnings = []
        self.warnings_btn.configure(text="Source review (0)", state="disabled")
        self.tree.delete(*self.tree.get_children())
        self.status.set("Checking every SVG and rendering previews from the current Shared Drive Plain folder…")
        def work():
            # Validate source before creating a release-history folder.
            canonical_sources(self.plain)
            # Staged ZIP metadata uses the approved URL contract, not the
            # current Windows user's optional ExpertGPS installation.
            readme = preview_readme_bytes()
            stage = make_stage(self.releases)
            try:
                sources, records, archive = prepare_run(
                    self.plain, stage, None, readme, progress=self.publish_progress)
                self.publish_progress("finalize", 0, None, "Comparing canonical PNGs")
                plan = destination_preflight(self.dest, records)
                warnings = source_freshness_warnings(self.plain, PARK / "Masters", sources)
                return sources, records, stage, plan, warnings
            except Exception as exc:
                (stage / "ERROR.txt").write_text(str(exc) + "\n", encoding="utf-8")
                raise IconError(f"{exc}\nDetails are in: {stage}") from exc
        def done(data, error):
            self.set_busy(False)
            if error:
                self.status.set("Validation stopped — no canonical PNG files changed.")
                messagebox.showerror("Icon validation needs attention", error)
                return
            self.snapshot, self.records, self.staged, self.plan, self.master_warnings = data
            groups = {}
            for group, items in self.plan.items():
                for row in items: groups[row["PNG"]] = group
            for row in self.records:
                action = {"add":"NEW", "replace":"UPDATE (backup)", "identical":"Unchanged"}[groups[row["PNG"]]]
                self.tree.insert("", "end", iid=row["PNG"], values=(row["PNG"],
                                 f'{row["Width_PX"]}×{row["Height_PX"]}', action))
            self.status.set(f"Validated {len(self.records)} icons. New {len(self.plan['add'])}; "
                            f"update with backup {len(self.plan['replace'])}; "
                            f"unchanged {len(self.plan['identical'])}. "
                            f"{len(self.master_warnings)} source timing warnings; click Source review to inspect.")
            self.set_busy(False)
            if self.master_warnings:
                self.warnings_btn.configure(text=f"Source review ({len(self.master_warnings)})",
                                            state="normal")
                (self.staged / "Master_Plain_Review_Warnings.txt").write_text(
                    "\n".join(self.master_warnings) + "\n", encoding="utf-8")
            # Warnings remain visible in the main window; no modal popup interrupts scan.
        self.async_operation(work, done)

    def open_web_svg(self):
        """Open the current selected SVG URL with a cache-busting source SHA query."""
        selection = self.tree.selection()
        if not selection or self.snapshot is None:
            messagebox.showinfo("Choose an icon", "Select an icon in the preview first.")
            return
        source_name = Path(selection[0]).stem + ".svg"
        record = self.snapshot.get(source_name)
        if record is None:
            messagebox.showerror("Unknown icon", f"No approved Plain SVG found: {source_name}")
            return
        webbrowser.open(PUBLIC_SVG_BASE + source_name + "?v=" + record[1][:12])

    def check_web_publish(self):
        """Separate explicit publication path; previews never publish implicitly."""
        if self.in_progress or self.snapshot is None or self.staged is None:
            return
        self.status.set("Comparing current Plain SVGs with published Synology msb-svg…")
        def work():
            self.publish_progress("preflight", 0, None, "Comparing existing server SVG bytes")
            check_source_snapshot(self.plain, self.snapshot)
            return web_svg_preflight(self.web_svg_dest, self.snapshot)
        def done(plan, error):
            self.set_busy(False)
            if error:
                self.status.set("SVG web publication preflight stopped; nothing published.")
                messagebox.showerror("Published SVG folder needs review",
                                     error + "\nNo web files changed. Check server share access and current Plain.")
                return
            changed = len(plan["add"]) + len(plan["replace"])
            self.status.set(f"Web SVG review: {len(plan['add'])} new, "
                            f"{len(plan['replace'])} changed, {len(plan['identical'])} identical, "
                            f"{len(plan['legacy_case_identical'])} byte-identical historical-case names.")
            if changed == 0:
                messagebox.showinfo("Web SVG library matches current Plain",
                                    f"Exact-case matches: {len(plan['identical'])}. "
                                    f"Historical-case matches: {len(plan['legacy_case_identical'])}. "
                                    "All match approved Plain bytes.\nHistorical-case URLs remain case-sensitive "
                                    "and were not renamed; lowercase URLs may return 404.")
                return
            self.review_web_plan(plan)
        self.async_operation(work, done)

    def review_web_plan(self, plan):
        """Human-readable, scrollable list before an explicit public asset write."""
        dialog = tk.Toplevel(self.root)
        dialog.title("Review LIVE web SVG publication — existing msb-svg")
        dialog.geometry("850x535")
        dialog.minsize(680, 400)
        dialog.transient(self.root)
        ttk.Label(dialog, text="Review publication to the LIVE web file server",
                  padding=(15, 12, 15, 5), font=("Segoe UI", 13, "bold")).pack(anchor="w")
        ttk.Label(dialog, wraplength=800, padding=(15, 0, 15, 8),
                  text=(f"Destination: {self.web_svg_dest}\n"
                        f"NEW: {len(plan['add'])}   UPDATE (backup): {len(plan['replace'])}   "
                        f"Unchanged: {len(plan['identical'])}   "
                        f"Historical-case (byte-identical): {len(plan['legacy_case_identical'])}\n"
                        "This copies currently validated Plain SVG bytes only. No GPX/PNG files "
                        "are renamed or deleted. Historical-case matches are NOT rewritten, "
                        "and their lowercase URL may still return HTTP 404. "
                        "The Park Map uses the separately approved lowercase SVG names."
                        "\nDo not publish if artwork looks wrong in the preview.")).pack(fill="x")
        text_area = scrolledtext.ScrolledText(dialog, wrap="word", font=("Consolas", 10))
        text_area.pack(fill="both", expand=True, padx=15, pady=8)
        details = []
        for category, label in (("add", "NEW"), ("replace", "UPDATE (backup)"), ("identical", "Unchanged")):
            details.extend(f"{label}: {name}" for name in plan[category])
        details.extend(
            f"HISTORICAL CASE (bytes identical; no rename): {name} -> {actual}"
            for name, actual in plan["legacy_case_identical"].items())
        text_area.insert("1.0", "\n".join(details))
        text_area.configure(state="disabled")
        footer = ttk.Frame(dialog, padding=(15, 0, 15, 12))
        footer.pack(fill="x")
        ttk.Button(footer, text="Cancel", command=dialog.destroy).pack(side="right")
        def start_publish():
            if not messagebox.askyesno("Confirm LIVE SVG publication",
                f"Publish current Plain SVGs to:\n{self.web_svg_dest}\n\n"
                f"{len(plan['add'])} new + {len(plan['replace'])} backed-up updates.\n"
                "This changes web-server files used by public consumers. Proceed?",
                parent=dialog):
                return
            dialog.destroy()
            self.status.set("Publishing reviewed Plain SVGs and verifying server hashes…")
            def work():
                return publish_web_svgs(self.plain, self.web_svg_dest,
                                        self.staged, self.snapshot,
                                        progress=self.publish_progress)
            def done(receipt, error):
                self.set_busy(False)
                if error:
                    self.status.set("SVG publication STOPPED — inspect partial receipt and backups.")
                    messagebox.showerror("Web SVG publication stopped",
                                         error + "\nReview: " + str(self.staged) +
                                         "\nSome files may already have been published; do not discard receipts.")
                    return
                aliases = [row for row in receipt if row["Action"] == "legacy-case-identical"]
                self.status.set(f"Web SVG publication PASS: {len(receipt)} entries SHA-256 verified; "
                                f"{len(aliases)} retained historical-case aliases.")
                messagebox.showinfo("Web SVG files synchronized",
                                    f"{len(receipt)} source SVG entries hash-verified.\n"
                                    f"{len(aliases)} historical-case aliases unchanged; their canonical "
                                    "lowercase URLs are NOT guaranteed to resolve.\n"
                                    f"Receipt/backups: {self.staged}\n\n"
                                    "Verify mapped Plain SVG URLs in the Park Map browser.")
            self.async_operation(work, done)
        ttk.Button(footer, text="Publish reviewed SVG changes",
                   command=start_publish).pack(side="right", padx=(0, 12))

    def open_web_png(self):
        selection = self.tree.selection()
        if not selection or self.records is None:
            messagebox.showinfo("Choose an icon", "Select an icon in the preview first.")
            return
        name = selection[0]
        row = next((r for r in self.records if r["PNG"] == name), None)
        if row is not None:
            webbrowser.open(PUBLIC_PNG_BASE + name + "?v=" + row["PNG_SHA256"][:12])

    def check_png_distribution(self, kind):
        """Read-only comparison before web or local distribution confirmation."""
        if self.in_progress or self.snapshot is None or self.records is None:
            return
        if kind == "web":
            destination = self.web_png_dest
            title = "Public web msb PNG library"
        else:
            destination = self.local_png_dest
            title = "This Windows user's ExpertGPS msb library"
        self.status.set(f"Checking canonical PNGs and {title}…")

        def work():
            self.publish_progress("preflight", 0, None, "Comparing canonical PNGs and destination")
            return png_distribution_preflight(kind, destination, self.plain, self.dest,
                                              self.snapshot, self.records,
                                              local_readme=self.readme)
        def done(plan, error):
            self.set_busy(False)
            if error:
                self.status.set(f"{title}: preflight blocked; no files copied.")
                messagebox.showerror("PNG distribution requires attention", error +
                      "\nNo files copied. First save approved canonical PNG changes if prompted.")
                return
            self.status.set(f"{title}: {len(plan['add'])} new, {len(plan['replace'])} changed, "
                            f"{len(plan['identical'])} identical.")
            if not (plan["add"] or plan["replace"] or
                    (kind == "expertgps" and plan.get("create_readme"))):
                messagebox.showinfo("PNG destination matches canonical",
                    f"All {len(plan['identical'])} PNG files at {destination} match canonical hashes."
                    "\nPublic URL/ExpertGPS behavior still requires independent verification.")
                return
            self.review_png_distribution(kind, destination, plan)
        self.async_operation(work, done)

    def review_png_distribution(self, kind, destination, plan):
        title = ("LIVE published web PNGs" if kind == "web"
                 else "THIS COMPUTER'S ExpertGPS icons")
        dialog = tk.Toplevel(self.root)
        dialog.title("Review " + title)
        dialog.geometry("850x525")
        dialog.minsize(690, 395)
        dialog.transient(self.root)
        ttk.Label(dialog, text="Review " + title, padding=(15, 12, 15, 3),
                  font=("Segoe UI", 13, "bold")).pack(anchor="w")
        note = ("Existing legacy PNG/BMP filenames and GPX URL aliases remain untouched. "
                "After copying, check a published URL in a browser."
                if kind == "web" else
                ("FIRST INSTALL: create the current Windows user's missing msb folder, "
                 "all approved canonical PNGs and the reviewed readme.txt URL. "
                 if plan.get("create_local_folder") else
                 "Use THIS Windows user's existing msb folder. Preserve legacy "
                 "symbols and any valid existing readme.txt. " )
                + ("CREATE approved readme.txt because none exists. "
                   if plan.get("create_readme") and
                      not plan.get("create_local_folder") else "")
                + "INSTALL before opening any MSB GPX. CLOSE ExpertGPS "
                  "before copying; restart it afterward. Check MSB Type and "
                  "Map Marker selections using only a disposable GPX copy.")
        ttk.Label(dialog, text=(f"Destination: {destination}\n"
                  f"NEW {len(plan['add'])} | UPDATE (backup) {len(plan['replace'])} | "
                  f"Unchanged {len(plan['identical'])}\n{note}"),
                  wraplength=810, padding=(15, 0, 15, 8)).pack(fill="x")
        preview = scrolledtext.ScrolledText(dialog, font=("Consolas", 10), wrap="word")
        preview.pack(fill="both", expand=True, padx=15, pady=5)
        for group, label in (("add", "NEW"), ("replace", "UPDATE (backup)"),
                             ("identical", "Unchanged")):
            for record in plan[group]:
                preview.insert("end", f"{label}: {record['PNG']}\n")
        preview.configure(state="disabled")
        actions = ttk.Frame(dialog, padding=(15, 6, 15, 12))
        actions.pack(fill="x")
        ttk.Button(actions, text="Cancel", command=dialog.destroy).pack(side="right")
        def confirmed():
            first_install = (kind == "expertgps" and plan.get("create_local_folder"))
            provision_note = (
                "FIRST-TIME INSTALL: Create the missing msb folder and approved "
                "readme.txt, then install ALL reviewed canonical PNGs.\n"
                if first_install else
                "Create the approved readme.txt in the existing msb folder.\n"
                if kind == "expertgps" and plan.get("create_readme") else "")
            if not messagebox.askyesno("Confirm " + title,
                f"Distribute current verified canonical PNGs to:\n{destination}\n\n"
                f"New: {len(plan['add'])}; backed-up updates: {len(plan['replace'])}.\n"
                + provision_note +
                ("This changes ONLY the current user's local ExpertGPS symbols. "
                 "CLOSE EXPERTGPS FIRST. Proceed?" if kind == "expertgps"
                 else "This changes public web PNGs used by GPX and browser consumers. Proceed?"),
                parent=dialog):
                return
            dialog.destroy()
            self.status.set("Updating " + title + " with exact hash checks…")
            def work():
                return distribute_pngs(
                    kind, destination, self.plain, self.dest, self.snapshot,
                    self.records, self.staged, local_readme=self.readme,
                    progress=self.publish_progress)
            def done(receipt, error):
                self.set_busy(False)
                if error:
                    self.status.set(title + ": STOPPED; inspect backups and partial receipt.")
                    messagebox.showerror("PNG distribution stopped", error +
                       "\nCheck release history: " + str(self.staged) +
                       "\nSome files may already have been updated. Do not discard backups.")
                    return
                self.status.set(f"{title}: {len(receipt)} PNGs verified by destination SHA-256.")
                messagebox.showinfo("Verified PNG distribution",
                    f"Verified {len(receipt)} PNGs at:\n{destination}\n\n"
                    f"Receipts and backups: {self.staged}\n\n" +
                    ("Check a public PNG URL in a browser. Existing map GPX references remain unchanged."
                     if kind == "web" else
                     "Restart ExpertGPS and test the icons and GPX-generated URLs. "
                     "Local installation is not web publication."))
            self.async_operation(work, done)
        ttk.Button(actions, text="Distribute reviewed PNGs",
                   command=confirmed).pack(side="right", padx=(0, 12))

    def show_warnings(self):
        if not self.master_warnings:
            return
        dialog = tk.Toplevel(self.root)
        dialog.title("Review master → Plain SVG export timestamps")
        dialog.geometry("820x450")
        dialog.minsize(600, 340)
        dialog.transient(self.root)
        ttk.Label(dialog, text=f"{len(self.master_warnings)} possible stale Plain SVGs",
                  padding=(15, 12, 15, 3), font=("Segoe UI", 13, "bold")).pack(anchor="w")
        ttk.Label(dialog, wraplength=780, padding=(15, 0, 15, 12),
                  text=("These are timestamp warnings, not confirmed artwork errors. "
                        "When you save a corrected editable master, you must also save "
                        "the corresponding Plain SVG. Layered masters may legitimately "
                        "have several Plain variants. Review affected icons in the preview "
                        "before confirming PNG changes.")).pack(fill="x")
        body = scrolledtext.ScrolledText(dialog, wrap="word", font=("Segoe UI", 10))
        body.pack(fill="both", expand=True, padx=15, pady=5)
        body.insert("1.0", "\n\n".join(self.master_warnings))
        body.configure(state="disabled")
        ttk.Button(dialog, text="Close", command=dialog.destroy).pack(anchor="e", padx=16, pady=12)

    def scroll_preview(self, event):
        """Scroll only the preview content; never touch the icon tree."""
        if getattr(event, "num", None) == 4:
            step = -2
        elif getattr(event, "num", None) == 5:
            step = 2
        else:
            delta = getattr(event, "delta", 0)
            if not delta:
                return
            step = -2 if delta > 0 else 2
        self.preview_canvas.yview_scroll(step, "units")

    def resize_preview(self, event=None):
        """Fit displayed enlargement inside current viewport, retaining PNG shape.

        Zoom is integer/nearest-neighbor only. The original image is unmodified.
        At very short window heights native-size icons remain scrollable.
        """
        if event is not None and getattr(event, "widget", None) == self.preview_canvas:
            self.preview_canvas.itemconfigure(
                self.preview_window, width=event.width)
        if self.preview_original is None:
            return
        original = self.preview_original
        available_height = max(
            1, self.preview_canvas.winfo_height()
            - self.prev_head.winfo_reqheight()
            - self.preview_info.winfo_reqheight() - 24)
        available_width = max(1, self.preview_canvas.winfo_width() - 24)
        zoom = max(1, min(6, 180 // max(original.width(), original.height()),
                          available_width // original.width(),
                          available_height // original.height()))
        if zoom != self.preview_zoom:
            enlarged = original.zoom(zoom, zoom)
            self.preview_images = [original, enlarged]
            self.prev_image.configure(image=enlarged)
            self.preview_zoom = zoom

    def show_preview(self, _event=None):
        selection = self.tree.selection()
        if not selection or self.staged is None:
            return
        name = selection[0]
        p = self.staged / "msb" / name
        self.prev_head.configure(text=name)
        try:
            original = tk.PhotoImage(file=str(p))
            self.preview_original = original
            self.preview_zoom = 0
            old = self.dest / name
            self.preview_info.configure(text=("Previous PNG exists. A backup will be saved before replacement."
                                             if old.is_file() and name in {r['PNG'] for r in self.plan['replace']}
                                             else "Source: current Shared Drive Plain SVG."))
            self.resize_preview()
            self.preview_canvas.yview_moveto(0)
            # A changed note can change the frame's requested height after
            # Tk finishes geometry calculation; recompute once if necessary.
            self.root.after_idle(self.resize_preview)
        except Exception as exc:
            self.preview_original = None
            self.preview_images = []
            self.prev_image.configure(image="")
            self.preview_info.configure(text=f"Preview unavailable: {exc}")

    def confirm_apply(self):
        if self.in_progress or self.records is None:
            return
        changes = len(self.plan["add"]) + len(self.plan["replace"])
        if not changes:
            return
        if self.master_warnings and not messagebox.askyesno("Master/Plain freshness warnings",
                f"{len(self.master_warnings)} possible source freshness warning(s) remain.\n"
                "Review their details under release history before approving. Continue only if the Plain SVG artwork is correct?"):
            return
        if not messagebox.askyesno("Confirm canonical PNG update",
                                   f"Update {changes} approved PNG file(s) in:\n{self.dest}\n\n"
                                   f"{len(self.plan['add'])} new, {len(self.plan['replace'])} replacements with backups.\n"
                                   "Plain/Masters, ExpertGPS, webassets, GPX and draw.io are NOT changed. Proceed?"):
            return
        self.status.set("Checking unchanged source snapshot and current destination, then updating canonical PNGs…")
        def work():
            receipt = apply_canonical(self.dest, self.staged, self.records, self.snapshot,
                                      self.plain, progress=self.publish_progress)
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