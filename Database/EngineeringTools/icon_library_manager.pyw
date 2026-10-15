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
from gis_workstation_proposal import prepare_laptop_proposal, SHARED_ROOT
from gis_workstation_release_candidate import (inspect_saved_proposal, prepare_release_candidate)
from gis_workstation_observation import (list_scanned_map_names, read_observation,
    compare_with_laptop, save_observation)
from gis_workstation_comparison_report import (format_comparison_report,
    save_comparison_report)
from gis_workstation_alignment import (make_office_repair_plan,
    make_target_alignment_plan, plan_digest,
    PINNED_YOGA_PROPOSAL_SHA256)
from gis_workstation_install import (apply_office_repair, restore_office_private_backup,
    OFFICE_TARGET_HOST)
from gis_workstation_map_repair import preview as preview_map_repair, apply as apply_map_repair, MAP as OFFICE_CORRECT_MAP
from gis_workstation_map_source import (inspect_office_map, save_office_map_source,
    SOURCE_HOST as OFFICE_MAP_SOURCE_HOST, SOURCE_MAP as OFFICE_WORKING_MAP)

BACKGROUND = "#f5f8fb"
# Source-only candidate identity, separate from approved GIS profile releases
# or the Production Setup application version. Never guess a successful SHA.
APP_VERSION = "V0.4.5-office-test-map-repair"
APP_PHASE = "PR #378 CANDIDATE"


def source_build_identity():
    """Read the exact Git checkout SHA; works from a detached Windows worktree.

    Uses the repository containing this checked-in script, never the PowerShell
    current directory or the independently approved GIS profile release ID.
    """
    repo = Path(__file__).resolve().parents[2]
    try:
        kwargs = {"capture_output": True, "text": True, "check": True,
                  "timeout": 5}
        if os.name == "nt":
            kwargs["creationflags"] = subprocess.CREATE_NO_WINDOW
        result = subprocess.run(
            ["git", "-C", str(repo), "rev-parse", "--verify", "HEAD"],
            **kwargs)
        sha = result.stdout.strip().lower()
        if len(sha) == 40 and all(ch in "0123456789abcdef" for ch in sha):
            return sha[:8]
    except (OSError, ValueError, subprocess.SubprocessError):
        pass
    return "unverified"


class Manager:
    def __init__(self, root):
        self.root = root
        self.build_identity = source_build_identity()
        self.root.title(
            f"MSB GIS Manager — {APP_VERSION} [{self.build_identity}]")
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
        # Keep the Garmin workflow accessible without more stacked footer buttons.
        main_menu = tk.Menu(self.root)
        symbol_menu = tk.Menu(main_menu, tearoff=False)
        symbol_menu.add_command(label="Artwork library and publication", command=self.show_symbol_page)
        symbol_menu.add_command(label="Garmin symbols and GPX", command=self.open_garmin_review)
        main_menu.add_cascade(label="Symbol Management", menu=symbol_menu)
        station_menu = tk.Menu(main_menu, tearoff=False)
        station_menu.add_command(label="Check this computer", command=self.open_workstation_workspace)
        main_menu.add_cascade(label="Workstation Management", menu=station_menu)
        data_menu = tk.Menu(main_menu, tearoff=False)
        data_menu.add_command(label="Review GPX changes", command=self.open_gis_source_review)
        main_menu.add_cascade(label="GIS Data Management", menu=data_menu)
        utility_menu = tk.Menu(main_menu, tearoff=False)
        utility_menu.add_command(label="Inspect ExpertGPS settings", command=self.inspect_this_pc)
        utility_menu.add_command(label="Compare workstation release", command=self.check_workstation)
        utility_menu.add_command(label="Review workstation alignment", command=self.review_office_repair)
        utility_menu.add_command(label="Laptop source proposal", command=self.review_current_profile)
        utility_menu.add_command(label="Office map calibration review", command=self.review_map_repair)
        utility_menu.add_separator()
        utility_menu.add_command(label="Open release history", command=lambda: self.open_dir(self.releases))
        main_menu.add_cascade(label="Utilities (Advanced)", menu=utility_menu)
        main_menu.add_command(label="Home", command=self.show_home)
        self.root.config(menu=main_menu)
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
        title_line = ttk.Frame(heading)
        title_line.pack(fill="x")
        ttk.Label(title_line, text="Symbol Management — Artwork Library",
                  font=("Segoe UI", 16, "bold")).pack(side="left")
        ttk.Label(title_line, text=f"{APP_VERSION} • {APP_PHASE} • {self.build_identity}",
                  font=("Segoe UI", 9), foreground="#33495b").pack(side="right")
        ttk.Label(heading, text=f"Active source: Shared Drive / MSB GIS / {PARK.name}   •   Target: Symbol Library   •   Max 32 × 32 px",
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
        # Workstation controls are accessed from the workstation workspace.
        ttk.Label(local_controls, text="Current Windows user / local ExpertGPS:").pack(
            side="left", padx=(0, 10))
        self.local_png_btn = ttk.Button(
            local_controls, text="5. Install PNGs for this ExpertGPS user",
            command=lambda: self.check_png_distribution("expertgps"), state="disabled")
        self.local_png_btn.pack(side="left")

        # #171 first phase: compare only. No HKCU write, GPX modification, or
        # installation callback exists for this separate workstation operation.
        profile_controls = ttk.Frame(action_dock, padding=(0, 0, 0, 2))
        # Workstation controls are accessed from the workstation workspace.
        self.profile_check_btn = ttk.Button(
            profile_controls, text="6. Compare GIS workstation release (READ ONLY)",
            command=self.check_workstation)
        self.profile_check_btn.pack(side="left", padx=(0, 8))
        self.profile_proposal_btn = ttk.Button(
            profile_controls, text="Submit laptop cropped-map proposal",
            command=self.review_current_profile)
        self.profile_proposal_btn.pack(side="left")
        profile_advanced = ttk.Frame(action_dock, padding=(0, 1, 0, 1))
        # Workstation controls are accessed from the workstation workspace.
        self.profile_candidate_btn = ttk.Button(
            profile_advanced, text="Inspect this PC / compare with laptop (READ ONLY)",
            command=self.inspect_this_pc)
        self.profile_candidate_btn.pack(side="left", padx=(0, 8))
        self.profile_align_btn = ttk.Button(
            profile_advanced,
            text="Review laptop alignment — this PC (READ ONLY)",
            command=self.review_office_repair)
        self.profile_align_btn.pack(side="left")
        # Targeted, separately confirmed correction of the Office TEST map only.
        self.map_repair_btn = ttk.Button(
            profile_advanced, text="Review Office cropped-map repair (READ ONLY)",
            command=self.review_map_repair)
        self.map_repair_btn.pack(side="left", padx=(8, 0))
        self.profile_release_status = tk.StringVar(
            value="GIS workstation configuration: Not verified — no administrator-pinned release selected")
        # Show workstation status on Home and workstation overview, not artwork.

        ttk.Button(footer, text="Open release history / logs", command=lambda: self.open_dir(
            self.releases)).pack(side="left")
        ttk.Button(footer, text="Open selected SVG URL", command=self.open_web_svg).pack(
            side="left", padx=(12, 0))
        ttk.Button(footer, text="Open selected PNG URL", command=self.open_web_png).pack(
            side="left", padx=(12, 0))
        ttk.Button(footer, text="Close", command=self.root.destroy).pack(side="right")
        self.root.after_idle(self.show_home)


    def scan_operator_readiness(self):
        """Read-only local readiness signals. Never treat these as an approved release comparison."""
        from collections import Counter
        from garmin_bmp_derivatives import load_registry
        states = []
        canonical = PARK / "png"
        local = self.local_png_dest
        try:
            approved = {p.name.casefold(): p for p in canonical.glob("*.png") if p.is_file()}
            existing = {p.name.casefold(): p for p in local.glob("*.png") if p.is_file()}
            missing = sorted(set(approved) - set(existing))
            changed = sorted(k for k in set(approved) & set(existing)
                             if sha_file(approved[k]) != sha_file(existing[k]))
            if not approved:
                states.append(("Local ExpertGPS icons", "Needs review", "Approved PNG folder is empty/unavailable"))
            elif missing or changed:
                states.append(("Local ExpertGPS icons", "Update available",
                               f"{len(missing)} missing and {len(changed)} different"))
            else:
                states.append(("Local ExpertGPS icons", "Matched",
                               f"{len(approved)} approved PNG files verified"))
        except (OSError, ValueError) as exc:
            states.append(("Local ExpertGPS icons", "Check needed", str(exc)))
        # Device discovery is read-only, drive-letter independent and opt-in for writes.
        connected = []
        if os.name == "nt":
            import string
            for drive in string.ascii_uppercase:
                folder = Path(f"{drive}:/Garmin/CustomSymbols")
                if folder.is_dir():
                    connected.append(folder)
        if connected:
            states.append(("Garmin device", "Connected",
                           f"{len(connected)} symbol folder(s) detected; review before updating or importing"))
        else:
            states.append(("Garmin device", "Not connected", "Connect a Garmin when ready"))
        states.append(("Workstation configuration", "Approval pending",
                       "Exact ExpertGPS Type, reverse mapping and maps require an approved release comparison"))
        return states

    def refresh_operator_readiness(self):
        if not hasattr(self, "_readiness_rows"):
            return
        for child in self._readiness_rows.winfo_children():
            child.destroy()
        for name, status, detail in self.scan_operator_readiness():
            line = ttk.Frame(self._readiness_rows)
            line.pack(fill="x", pady=4)
            ttk.Label(line, text=name, width=24, anchor="w").pack(side="left")
            ttk.Label(line, text=status, width=18, anchor="w").pack(side="left")
            ttk.Label(line, text=detail, wraplength=410).pack(side="left", fill="x", expand=True)

    def show_home(self):
        """Operator-first status and next actions, never mutate on startup."""
        if not hasattr(self, "_home_overlay"):
            home = ttk.Frame(self.root, padding=20)
            self._home_overlay = home
            ttk.Label(home, text="MSB GIS Manager",
                      font=("Segoe UI", 19, "bold")).pack(anchor="w")
            ttk.Label(home, text="Check what needs attention, then choose an action.",
                      font=("Segoe UI", 10)).pack(anchor="w", pady=(3, 10))
            state = ttk.LabelFrame(home, text="This computer and connected equipment", padding=12)
            state.pack(fill="x")
            self._readiness_rows = ttk.Frame(state)
            self._readiness_rows.pack(fill="x")
            ttk.Button(state, text="Check again (read only)",
                       command=self.refresh_operator_readiness).pack(anchor="w", pady=(8, 0))
            ttk.Label(home,
                      text="IMPORTANT: Install local MSB symbols BEFORE opening an MSB GPX in ExpertGPS. Missing symbols can change markers even without Save.",
                      foreground="#a12323", wraplength=780).pack(anchor="w", pady=(12, 8))
            choices = ttk.Frame(home)
            choices.pack(fill="x")
            for label, callback in (
                ("Review workstation differences", self.open_workstation_workspace),
                ("Review artwork updates", self.show_symbol_page),
                ("Garmin symbols / recordings", self.open_garmin_review),
                ("Review GPX source changes", self.open_gis_source_review),
            ):
                ttk.Button(choices, text=label, command=callback).pack(side="left", padx=(0, 7), pady=2)
            ttk.Label(home, text="Advanced diagnostics and manual operations: Utilities menu.",
                      foreground="#42566b").pack(anchor="w", pady=(10, 0))
            ttk.Label(home, text="Approved workstation release and installer not yet accepted.",
                      foreground="#8b4b16").pack(anchor="w")
            ttk.Button(home, text="Close", command=self.root.destroy).pack(side="bottom", anchor="e")
        self._home_overlay.place(x=0, y=0, relwidth=1, relheight=1)
        self._home_overlay.lift()
        self.refresh_operator_readiness()

    def open_workstation_workspace(self):
        win = tk.Toplevel(self.root)
        win.title("MSB GIS Manager — Workstation Management")
        win.geometry("750x460")
        win.minsize(610, 410)
        pane = ttk.Frame(win, padding=16)
        pane.pack(fill="both", expand=True)
        ttk.Label(pane, text="Workstation Management",
                  font=("Segoe UI", 16, "bold")).pack(anchor="w")
        ttk.Label(pane, text="Protect existing ExpertGPS settings and scanned maps before making changes.",
                  wraplength=690).pack(anchor="w", pady=(6, 8))
        ttk.Label(pane, text="CRITICAL: Install local MSB symbols before opening an MSB GPX in ExpertGPS.",
                  foreground="#a12323", wraplength=690).pack(anchor="w", pady=(3, 8))
        ttk.Label(pane, textvariable=self.profile_release_status,
                  wraplength=690).pack(anchor="w", pady=(3, 9))
        for label, callback in (
            ("Inspect this workstation (read only)", self.inspect_this_pc),
            ("Compare workstation release (read only)", self.check_workstation),
            ("Install reviewed PNGs for this ExpertGPS user", lambda: self.check_png_distribution("expertgps")),
            ("Review workstation alignment — advanced", self.review_office_repair),
            ("Laptop source proposal — advanced", self.review_current_profile),
            ("Office calibration review — advanced", self.review_map_repair),
        ):
            ttk.Button(pane, text=label, command=callback).pack(fill="x", pady=3)
        ttk.Button(pane, text="Close", command=win.destroy).pack(anchor="e", pady=(10, 0))

    def show_symbol_page(self):
        if hasattr(self, "_home_overlay"):
            self._home_overlay.place_forget()

    def open_gis_source_review(self):
        from gis_source_review_dialog import open_review
        open_review(self.root)

    def open_garmin_review(self):
        from garmin_sync_dialog import open_garmin_workspace
        open_garmin_workspace(self.root)

    def review_current_profile(self):
        """Laptop-only source proposal, not Office/Show PC reconnaissance.

        This is NOT an installer or an approval of a shared GIS release. The
        worker revalidates current HKCU/Plain/PNG/map identity at commit time.
        """
        if self.in_progress:
            return
        from gis_workstation_proposal import workstation_hostname
        if workstation_hostname() != "YOGA-GREG":
            messagebox.showwarning(
                "Laptop-source proposal only",
                "For this Office/other PC, use Inspect this PC / compare with laptop. "
                "The laptop-source submit action requires YOGA-GREG.",
                parent=self.root)
            return
        self.status.set("Reviewing this PC's GIS configuration (read-only)…")

        def run_preflight():
            return prepare_laptop_proposal(
                self.plain, self.dest, SHARED_ROOT,
                "2019 Ortho Cropped for GPS Export", save=False)

        def preflight_done(data, error):
            self.set_busy(False)
            if error:
                self.status.set("GIS configuration review blocked — nothing saved.")
                messagebox.showerror(
                    "GIS configuration review stopped",
                    error + "\nNo GIS settings, GPX, or shared proposals changed.",
                    parent=self.root)
                return
            self.status.set(
                f"Reviewed {data['type_count']} Types, {data['png_count']} PNGs; "
                f"{data['review_count']} marker references need review. Not saved.")
            self.show_proposal_review(data)

        self.async_operation(run_preflight, preflight_done)

    def show_proposal_review(self, data):
        """Review exact existing aliases before enabling any optional G: write."""
        dialog = tk.Toplevel(self.root)
        dialog.title("Review this PC's GIS settings — UNAPPROVED proposal")
        dialog.geometry("820x490")
        dialog.minsize(620, 370)
        dialog.transient(self.root)
        ttk.Label(
            dialog, text=(f"Source PC: {data['hostname']}   "
                          f"Types: {data['type_count']}   PNGs: {data['png_count']}   "
                          f"Maps: {data['map_count']}"),
            padding=(12, 10, 12, 5),
            font=("Segoe UI", 11, "bold")).pack(fill="x")
        ttk.Label(
            dialog, text=("This is a proposed configuration only — NOT an approved release "
                          "and NOT an ExpertGPS installation. Historical mappings stay unchanged."),
            padding=(12, 0, 12, 6), wraplength=770).pack(fill="x")
        ttk.Label(
            dialog, text=("Shared G: proposal folder: " + data["destination"]),
            padding=(12, 0, 12, 6), wraplength=770).pack(fill="x")
        actions = ttk.Frame(dialog, padding=(12, 5, 12, 12))
        actions.pack(side="bottom", fill="x")
        viewer = scrolledtext.ScrolledText(
            dialog, wrap="word", font=("Consolas", 10))
        viewer.pack(fill="both", expand=True, padx=12, pady=5)
        if data["review_items"]:
            viewer.insert(
                "end", f"{len(data['review_items'])} existing marker references "
                "need administrator review:\n\n")
            for item in data["review_items"]:
                viewer.insert(
                    "end", f"{item['type']} — {item['reason']}\n"
                    f"  Existing URL: {item['url']}\n\n")
        else:
            viewer.insert("end", "All named local Type marker URLs are canonical.\n")
        viewer.insert(
            "end", "\nNo automatic substitutions, renaming, registry imports, "
            "or GPX changes will be made.\n")
        viewer.configure(state="disabled")
        ttk.Button(actions, text="Cancel", command=dialog.destroy).pack(side="right")
        save_button = ttk.Button(actions, text="Save UNAPPROVED proposal to shared G:")
        save_button.pack(side="right", padx=(0, 10))

        def submit():
            if self.in_progress:
                return
            if not messagebox.askyesno(
                    "Confirm shared UNAPPROVED proposal",
                    f"Create ONE new host-named GIS configuration proposal in:\n"
                    f"{data['destination']}\n\n"
                    f"Preserve all {data['review_count']} existing marker review items. "
                    "This does NOT approve the configuration, install ExpertGPS, "
                    "or modify the working GPX.\n\nSave now?",
                    parent=dialog):
                return
            save_button.configure(state="disabled")
            self.status.set("Rechecking current GIS settings before saving proposal…")
            def save():
                return prepare_laptop_proposal(
                    self.plain, self.dest, SHARED_ROOT,
                    "2019 Ortho Cropped for GPS Export", save=True,
                    expected_source_sha256=data["review_source_sha256"])

            def saved(receipt, error):
                self.set_busy(False)
                if error:
                    if dialog.winfo_exists():
                        dialog.destroy()
                    self.status.set("GIS proposal NOT saved — review/check again.")
                    messagebox.showerror(
                        "GIS proposal save stopped",
                        error + "\nNo approval or installation was performed.",
                        parent=self.root)
                    return
                if dialog.winfo_exists():
                    dialog.destroy()
                self.status.set(
                    f"UNAPPROVED proposal saved for {receipt['hostname']}; "
                    "no settings installed.")
                messagebox.showinfo(
                    "Shared GIS proposal saved — NOT approved",
                    f"New proposal:\n{receipt['destination']}\n\n"
                    f"SHA-256 evidence (NOT an approval pin):\n"
                    f"{receipt['proposal_sha256_not_approval']}\n\n"
                    "The GIS administrator must review and approve a separate "
                    "immutable release before any Show PC installation.",
                    parent=self.root)
            self.async_operation(save, saved)
        save_button.configure(command=submit)

    def review_office_repair(self):
        """Office GPX Type+reverse+PNG parity, not Office map or live GPX repair."""
        if self.in_progress:
            return
        source = SHARED_ROOT / "Proposals" / "YOGA-GREG" / (
            "MSB-GIS-Workstation-Proposal-YOGA-GREG-"
            "20261014T063601Z-a2f49947d090.json")
        from gis_workstation_proposal import workstation_hostname
        target = workstation_hostname()
        self.status.set(
            f"Preparing YOGA-GREG → {target} alignment plan (READ ONLY)…")
        def work():
            if target == OFFICE_TARGET_HOST:
                plan = make_office_repair_plan(source, self.dest)
            else:
                plan = make_target_alignment_plan(
                    source, self.dest, hostname=target)
            return plan, plan_digest(plan)
        def done(result, error):
            self.set_busy(False)
            if error:
                self.status.set("Workstation alignment preview BLOCKED — nothing changed.")
                messagebox.showerror(
                    "ExpertGPS alignment review not verified",
                    str(error) + "\nNo registry, map, PNG, or GPX changed.",
                    parent=self.root)
                return
            if target == OFFICE_TARGET_HOST:
                self.show_office_repair_plan(source, *result)
            else:
                self.show_target_alignment_review(*result)
        self.async_operation(work, done)

    def show_target_alignment_review(self, plan, digest):
        """Non-Office PCs see the same laptop parity plan, with NO install path."""
        dialog = tk.Toplevel(self.root)
        dialog.title("GPX settings comparison — READ ONLY — NOT INSTALLABLE")
        dialog.geometry("890x575")
        dialog.minsize(670, 395)
        dialog.transient(self.root)
        ttk.Label(
            dialog, text="THIS PC VS YOGA-GREG — READ ONLY / NO INSTALL",
            font=("Segoe UI", 12, "bold"),
            padding=(12, 10, 12, 5)).pack(fill="x")
        ttk.Label(
            dialog, text=(f"Target: {plan['target_pc_hostname']}  "
                          f"Source: YOGA-GREG  "
                          f"Types: {plan['office_types_before']} → "
                          f"{plan['laptop_type_count']}  "
                          f"GPS reverse: {plan['office_reverse_before']} → "
                          f"{plan['laptop_reverse_count']}"),
            padding=(12, 0, 12, 6)).pack(fill="x")
        ttk.Label(
            dialog, text=("This is a proposed Type/icon alignment, NOT an approved "
                          "installation. Existing map calibration and master GPX "
                          "are excluded. The Office pilot must pass first."),
            wraplength=830, padding=(12, 0, 12, 7)).pack(fill="x")
        view = scrolledtext.ScrolledText(
            dialog, wrap="word", font=("Consolas", 10))
        view.pack(fill="both", expand=True, padx=12, pady=6)
        view.insert("end", f"Source proposal SHA: {PINNED_YOGA_PROPOSAL_SHA256}\n")
        view.insert("end", f"Plan fingerprint (evidence only): {digest}\n\n")
        for action in plan["type_actions"]:
            view.insert("end", f"{action['action']}: {action['type']}\n")
            for name, row in action.get("changes", {}).items():
                view.insert(
                    "end", f"  {name}: current={row['office']} "
                    f"→ laptop={row['laptop']}\n")
        view.insert("end", "\nGPS SYMBOL REVERSE ASSIGNMENTS\n")
        for action in plan["reverse_actions"]:
            view.insert(
                "end", f"{action['action']} {action['gps_symbol']}: "
                f"{action['office']} → {action['laptop']}\n")
        view.insert("end", "\nLOCAL CANONICAL PNG DIFFERENCES\n")
        for action in plan["png_actions"]:
            view.insert("end", f"{action['action']}: {action['file']}\n")
        view.insert("end", "\nNO INSTALLATION IS AUTHORIZED FOR THIS HOST.\n")
        view.configure(state="disabled")
        ttk.Button(dialog, text="Close", command=dialog.destroy).pack(
            side="bottom", pady=(0, 10))

    def show_office_repair_plan(self, source, plan, digest):
        """Mandatory inspectable plan; confirmation binds exact source/target."""
        dialog = tk.Toplevel(self.root)
        dialog.title("MSB OFFICE PC — PREVIEW TARGETED GPX SETTINGS REPAIR")
        dialog.geometry("920x585")
        dialog.minsize(670, 390)
        dialog.transient(self.root)
        ttk.Label(dialog, text="OFFICE PC WRONG — ALIGN GPX SETTINGS TO YOGA-GREG",
                  font=("Segoe UI", 12, "bold"), padding=(12, 10, 12, 5)
                  ).pack(fill="x")
        ttk.Label(
            dialog, text=(f"Target: {plan['office_pc_hostname']}  "
                          f"Source: YOGA-GREG   "
                          f"Types: {plan['office_types_before']} → "
                          f"{plan['laptop_type_count']}   "
                          f"Reverse: {plan['office_reverse_before']} → "
                          f"{plan['laptop_reverse_count']}"),
            padding=(12, 0, 12, 6)).pack(fill="x")
        ttk.Label(
            dialog, text=(f"Planned edits: {len(plan['type_actions'])} Type actions; "
                          f"{len(plan['reverse_actions'])} GPS reverse changes; "
                          f"{len(plan['png_actions'])} PNG files. "
                          "ALL Office aerial registrations and MASTER GPX excluded."),
            wraplength=875, padding=(12, 0, 12, 6)).pack(fill="x")
        controls = ttk.Frame(dialog, padding=(12, 5, 12, 12))
        controls.pack(fill="x", side="bottom")
        viewer = scrolledtext.ScrolledText(
            dialog, wrap="word", font=("Consolas", 10))
        viewer.pack(fill="both", expand=True, padx=12, pady=5)
        viewer.insert("end", "PINNED LAPTOP SHA-256:\n" +
                      PINNED_YOGA_PROPOSAL_SHA256 + "\n\n")
        viewer.insert("end", "OFFICE TYPE ACTIONS\n")
        for action in plan["type_actions"]:
            viewer.insert("end", f"{action['action']}: {action['type']}\n")
            for field, data in action.get("changes", {}).items():
                viewer.insert("end", f"  {field}: Office={data['office']} "
                              f"→ Laptop={data['laptop']}\n")
        viewer.insert("end", "\nGPS SYMBOL → TYPE REVERSE TABLE\n")
        for action in plan["reverse_actions"]:
            viewer.insert("end", f"{action['action']} {action['gps_symbol']}: "
                          f"{action['office']} → {action['laptop']}\n")
        viewer.insert("end", "\nCANONICAL PNGS TO INSTALL/REPLACE\n")
        for action in plan["png_actions"]:
            viewer.insert("end", f"{action['action']}: {action['file']}\n")
        viewer.insert("end", "\nMANDATORY BACKUP/ACCEPTANCE GATES\n")
        for item in plan["required_gates"]:
            viewer.insert("end", " • " + item + "\n")
        viewer.configure(state="disabled")
        ttk.Button(controls, text="Close without changes",
                   command=dialog.destroy).pack(side="right")
        install_button = ttk.Button(
            controls, text="Back up and repair Office GPX settings")
        install_button.pack(side="right", padx=(0, 10))
        if not plan.get("native_source_kinds_available"):
            install_button.configure(state="disabled")
            viewer.configure(state="normal")
            viewer.insert(
                "end", "\nBLOCKED: pinned laptop source lacks native "
                "REG_SZ/REG_DWORD kind evidence. Capture, review and pin a "
                "new typed YOGA-GREG source proposal before any real Office "
                "installation.\n")
            viewer.configure(state="disabled")
        ttk.Button(
            controls, text="Restore previous Office backup…",
            command=self.restore_office_backup).pack(side="left")

        def install():
            if self.in_progress or not dialog.winfo_exists():
                return
            if not messagebox.askyesno(
                    "Confirm targeted Office ExpertGPS repair",
                    "Repair THIS Office PC's Type definitions, GPS Symbol reverse "
                    "table, and 37 PNG files to the exact pinned YOGA-GREG "
                    "master configuration?\n\n"
                    "The application will first create a LOCAL private backup "
                    "of the complete affected Type/reverse keys and entire "
                    "existing MSB symbol folder. It will auto-restore if "
                    "verification fails. The Office aerial maps and the "
                    "authoritative GPX are OUT OF SCOPE.\n\n"
                    "ExpertGPS MUST BE CLOSED. Continue?",
                    parent=dialog):
                return
            confirmation = simpledialog.askstring(
                "Confirm exact Office repair target",
                "Type REPAIR MSB-OFFICE-PC to approve these reviewed changes:",
                parent=dialog)
            if confirmation != "REPAIR MSB-OFFICE-PC":
                return
            install_button.configure(state="disabled")
            self.status.set("Office GPX config backup, repair and verification running…")
            def work():
                return apply_office_repair(
                    source, self.dest, expected_plan_sha256=digest,
                    approval_confirmed=True)
            def done(receipt, error):
                self.set_busy(False)
                if error:
                    self.status.set("Office GPX repair STOPPED — read recovery message.")
                    if dialog.winfo_exists():
                        dialog.destroy()
                    messagebox.showerror(
                        "Office GPX settings repair stopped",
                        str(error) + "\nDO NOT OPEN THE MASTER GPX.",
                        parent=self.root)
                    return
                if dialog.winfo_exists():
                    dialog.destroy()
                self.status.set(
                    "Office GPX Type/Reverse/37 PNG parity VERIFIED; "
                    "disposable GPX acceptance pending.")
                messagebox.showinfo(
                    "Office GPX settings matched YOGA-GREG — GPX TEST PENDING",
                    "Targeted settings and canonical PNGs verified.\n"
                    "The Office aerial maps and master GPX were NOT modified.\n\n"
                    "Local private recovery backup:\n" +
                    receipt["private_rollback_backup"] +
                    "\n\nShared audit receipt:\n" + receipt["shared_receipt"] +
                    "\n\nNext: disposable-copy ExpertGPS GPX roundtrip. "
                    "Do not use the master GPX yet.",
                    parent=self.root)
            self.async_operation(work, done)
        install_button.configure(command=install)

    def restore_office_backup(self):
        """Explicit private-backup recovery entry point after interruption."""
        if self.in_progress:
            return
        local = os.environ.get("LOCALAPPDATA")
        if not local:
            messagebox.showerror("Recovery unavailable", "LOCALAPPDATA missing",
                                 parent=self.root)
            return
        root = Path(local) / "MSB-GIS" / "ExpertGPS-Profile-Backups" / "MSB-OFFICE-PC"
        path = filedialog.askopenfilename(
            parent=self.root, title="Select Office private BACKUP.JSON to restore",
            initialdir=str(root), filetypes=[("Private Office backup JSON", "backup.json")])
        if not path:
            return
        if not messagebox.askyesno(
                "Confirm restore original Office profile",
                "Restore original Office Type/reverse values and complete MSB "
                "symbol folder from selected LOCAL private backup?\n"
                "Office aerial/GPX remains untouched. ExpertGPS must be closed.",
                parent=self.root):
            return
        if simpledialog.askstring(
                "Verify restore intention", "Type RESTORE MSB-OFFICE-PC:",
                parent=self.root) != "RESTORE MSB-OFFICE-PC":
            return
        def work():
            return restore_office_private_backup(
                Path(path).parent, approval_confirmed=True)
        def done(receipt, error):
            self.set_busy(False)
            if error:
                messagebox.showerror(
                    "Office recovery stopped", str(error), parent=self.root)
                return
            self.status.set("Office original targeted profile RESTORED.")
            messagebox.showinfo(
                "Office targeted profile restored",
                "Restored original registry Types, reverse mappings and "
                "MSB symbol folder from:\n" + receipt["source_backup"] +
                "\n\nNo scanned map or GPX changed.",
                parent=self.root)
        self.async_operation(work, done)

    def inspect_this_pc(self):
        """Generic Office/other workstation reconnaissance before any sync."""
        if self.in_progress:
            return
        try:
            names = list_scanned_map_names()
        except Exception as exc:
            messagebox.showerror(
                "Cannot list scanned maps", str(exc), parent=self.root)
            return
        if not names:
            messagebox.showwarning(
                "No scanned maps detected",
                "No ExpertGPS current-user scanned-map keys were found. "
                "The PC must be inspected before choosing calibration; "
                "do not import laptop registry settings.",
                parent=self.root)
            return
        chooser = tk.Toplevel(self.root)
        chooser.title("Office/other PC — choose existing scanned map")
        chooser.geometry("570x380")
        chooser.transient(self.root)
        ttk.Label(
            chooser, text="Choose this PC's existing aerial map for READ-ONLY reconnaissance",
            padding=12, wraplength=510).pack(fill="x")
        ttk.Label(
            chooser, text=("Only the selected map's registry/calibration and image "
                          "hash are examined. Other personal maps are not opened."),
            padding=(12, 0, 12, 8), wraplength=510).pack(fill="x")
        choices = tk.Listbox(chooser, exportselection=False, height=9)
        choices.pack(fill="both", expand=True, padx=12, pady=5)
        for name in names:
            choices.insert("end", name)
        if len(names) == 1:
            choices.selection_set(0)
        footer = ttk.Frame(chooser, padding=12)
        footer.pack(fill="x", side="bottom")
        ttk.Button(footer, text="Cancel", command=chooser.destroy).pack(side="right")

        def inspect_selected():
            chosen = choices.curselection()
            if len(chosen) != 1:
                messagebox.showwarning(
                    "Select one map",
                    "Choose the Office PC's actual full aerial map, not the "
                    "laptop cropped map unless that is truly installed.",
                    parent=chooser)
                return
            map_name = names[chosen[0]]
            chooser.destroy()
            self.status.set("Inspecting this PC's ExpertGPS profile (READ ONLY)…")
            def work():
                return read_observation(
                    self.plain, self.dest, map_name=map_name)
            def done(result, error):
                self.set_busy(False)
                if error:
                    self.status.set("Office/other PC reconnaissance stopped — no writes.")
                    messagebox.showerror(
                        "Workstation observation not verified", str(error),
                        parent=self.root)
                    return
                self.status.set(
                    f"Inspected {result['hostname']}: {result['type_count']} Types; "
                    f"local PNG match {result['png_matched']}/{result['png_total']}. "
                    "No settings changed.")
                self.show_pc_observation(result)
            self.async_operation(work, done)

        ttk.Button(
            footer, text="Inspect selected map (READ ONLY)",
            command=inspect_selected).pack(side="right", padx=(0, 8))

    def show_pc_observation(self, observation):
        """Review per-PC snapshot and optionally compare to laptop or save to G:."""
        dialog = tk.Toplevel(self.root)
        dialog.title("This PC — GIS reconnaissance / not synchronized")
        dialog.geometry("880x570")
        dialog.minsize(680, 400)
        dialog.transient(self.root)
        # Put the window's purpose in the BODY, not just a faint OS title bar:
        # field operators must identify the right inspection without hunting.
        ttk.Label(
            dialog, text="THIS PC — GIS RECONNAISSANCE (READ ONLY; NOT SYNCHRONIZED)",
            padding=(12, 9, 12, 3),
            font=("Segoe UI", 12, "bold")).pack(fill="x")
        ttk.Label(
            dialog, text=(f"PC: {observation['hostname']}  "
                          f"ExpertGPS Types: {observation['type_count']}  "
                          f"GPS reverse entries: {observation['reverse_count']}"),
            padding=(12, 0, 12, 6),
            font=("Segoe UI", 11, "bold")).pack(fill="x")
        ttk.Label(
            dialog, text=("Selected map: " + observation["selected_map"] +
                          (" — image SHA verified" if observation["map_image_verified"]
                           else " — IMAGE MISSING OR UNVERIFIED")),
            padding=(12, 0, 12, 6), wraplength=830).pack(fill="x")
        ttk.Label(
            dialog, text=(f"Canonical PNGs on THIS PC: "
                          f"{observation['png_matched']} matched; "
                          f"{observation['png_missing']} missing; "
                          f"{observation['png_different']} different. "
                          "Differences are observations, NOT authorization to overwrite."),
            padding=(12, 0, 12, 6), wraplength=830).pack(fill="x")
        actions = ttk.Frame(dialog, padding=(12, 5, 12, 12))
        actions.pack(side="bottom", fill="x")
        viewer = scrolledtext.ScrolledText(
            dialog, wrap="word", font=("Consolas", 10))
        viewer.pack(fill="both", expand=True, padx=12, pady=5)
        viewer.insert("end", "READ-ONLY OFFICE / WORKSTATION EVIDENCE\n\n")
        viewer.insert("end", "No registry, GPX, map, or symbol installations.\n")
        viewer.insert("end", "Review fingerprint: " + observation["fingerprint"] + "\n\n")
        for name, fields in sorted(observation["profile"]["types"].items()):
            viewer.insert("end", f"{name}\n"
                          f"  GPS Symbol: {fields.get('GPS Symbol', '(absent)')}\n"
                          f"  Map Marker: {fields.get('Bitmap Symbol URL', '(absent)')}\n\n")
        viewer.configure(state="disabled")
        ttk.Button(actions, text="Close", command=dialog.destroy).pack(side="right")
        btn_compare = ttk.Button(actions, text="Compare with YOGA-GREG laptop")
        btn_compare.pack(side="left")
        btn_save = ttk.Button(actions, text="Save THIS PC observation to shared G:")
        btn_save.pack(side="left", padx=(8, 0))
        if observation["hostname"] == OFFICE_MAP_SOURCE_HOST:
            btn_map = ttk.Button(
                actions, text="Capture OFFICE map source to G:",
                command=lambda name=observation["selected_map"]: self.review_office_map_source(name))
            btn_map.pack(side="left", padx=(8, 0))

        def compare():
            if self.in_progress or not dialog.winfo_exists():
                return
            path = filedialog.askopenfilename(
                parent=dialog, title="Select YOGA-GREG laptop proposal on G:",
                initialdir=str(SHARED_ROOT / "Proposals" / "YOGA-GREG"),
                filetypes=[("MSB laptop proposal JSON", "*.json")])
            if not path:
                return
            def work():
                return compare_with_laptop(observation, path, shared_root=SHARED_ROOT)
            def done(result, error):
                self.set_busy(False)
                if error:
                    messagebox.showerror(
                        "Laptop/Office comparison stopped", str(error),
                        parent=dialog if dialog.winfo_exists() else self.root)
                    return
                if not dialog.winfo_exists():
                    return
                diff = tk.Toplevel(dialog)
                diff.title("Office PC versus YOGA-GREG — differences ONLY")
                diff.geometry("950x590")
                diff.minsize(720, 440)
                ttk.Label(
                    diff, text="THIS PC VS YOGA-GREG — READ-ONLY DIFFERENCE REPORT",
                    font=("Segoe UI", 12, "bold"),
                    padding=(12, 8, 12, 4)).pack(fill="x")
                ttk.Label(diff, text=(f"This PC: {result['office_type_count']} Types | "
                    f"Laptop: {result['laptop_type_count']} Types | "
                    f"{len(result['rows'])} field/status differences"),
                    padding=(12, 0, 12, 7)).pack(fill="x")
                ttk.Label(diff, text=("Different named aerial maps require separate "
                    "calibration review; NEVER automatically replace Office imagery."),
                    padding=(12, 0, 12, 8), wraplength=900).pack(fill="x")
                actions = ttk.Frame(diff, padding=(12, 5, 12, 12))
                actions.pack(side="bottom", fill="x")
                report_text = format_comparison_report(result, observation)
                txt = scrolledtext.ScrolledText(
                    diff, wrap="word", font=("Consolas", 10))
                txt.pack(fill="both", expand=True, padx=12, pady=5)
                txt.insert("end", report_text)
                txt.configure(state="disabled")
                ttk.Button(
                    actions, text="Close", command=diff.destroy
                ).pack(side="right")
                copy_button = ttk.Button(actions, text="Copy entire report")
                copy_button.pack(side="left")
                save_button = ttk.Button(
                    actions, text="Save report to shared G:")
                save_button.pack(side="left", padx=(8, 0))

                def copy_report():
                    if not diff.winfo_exists():
                        return
                    try:
                        diff.clipboard_clear()
                        diff.clipboard_append(report_text)
                        diff.update()
                        self.status.set(
                            f"Copied all {len(result['rows'])} comparison differences.")
                    except tk.TclError as exc:
                        messagebox.showerror(
                            "Could not copy report", str(exc), parent=diff)
                copy_button.configure(command=copy_report)

                def save_report():
                    if self.in_progress or not diff.winfo_exists():
                        return
                    if not messagebox.askyesno(
                            "Save Office/laptop comparison to shared G:",
                            f"Save the current {len(result['rows'])}-difference "
                            f"read-only report for {observation['hostname']} under:\n"
                            f"{SHARED_ROOT / 'Comparisons' / observation['hostname']}\n\n"
                            "The report records observed differences ONLY. It "
                            "does not approve a GIS release, install PNGs or "
                            "modify ExpertGPS, GPX or scanned maps.\n\nSave?",
                            parent=diff):
                        return
                    save_button.configure(state="disabled")
                    def work():
                        return save_comparison_report(
                            result, observation, shared_root=SHARED_ROOT)
                    def saved(receipt, error):
                        self.set_busy(False)
                        if error:
                            if diff.winfo_exists():
                                save_button.configure(state="normal")
                            messagebox.showerror(
                                "Comparison report not saved",
                                str(error) + "\nNo settings were changed.",
                                parent=diff if diff.winfo_exists() else self.root)
                            return
                        self.status.set(
                            f"{receipt['differences']} comparison differences "
                            "saved to shared G:; no settings installed.")
                        messagebox.showinfo(
                            "Comparison report saved (UNAPPROVED)",
                            "Text report:\n" + receipt["text_file"] +
                            "\n\nSHA-256:\n" + receipt["text_sha256"] +
                            "\n\nStructured JSON report:\n" +
                            receipt["json_file"] +
                            "\n\nThis is diagnostic evidence, not an "
                            "approved release or workstation install.",
                            parent=diff if diff.winfo_exists() else self.root)
                    self.async_operation(work, saved)
                save_button.configure(command=save_report)
            self.async_operation(work, done)

        def save():
            if self.in_progress or not dialog.winfo_exists():
                return
            if not messagebox.askyesno(
                    "Confirm shared PC observation",
                    f"Save a NEW UNAPPROVED, host-named observation for "
                    f"{observation['hostname']} under:\n"
                    f"{SHARED_ROOT / 'Observations' / observation['hostname']}\n\n"
                    "The source fingerprint will be rechecked. "
                    "No approved GIS release or ExpertGPS installation is created. "
                    "Save the observation?",
                    parent=dialog):
                return
            btn_save.configure(state="disabled")
            btn_compare.configure(state="disabled")
            def work():
                return save_observation(
                    observation, plain=self.plain, canonical_png=self.dest,
                    shared_root=SHARED_ROOT)
            def done(receipt, error):
                self.set_busy(False)
                if error:
                    if dialog.winfo_exists():
                        btn_save.configure(state="normal")
                        btn_compare.configure(state="normal")
                    messagebox.showerror(
                        "Observation save refused", str(error),
                        parent=dialog if dialog.winfo_exists() else self.root)
                    return
                self.status.set(
                    f"{receipt['hostname']} observation saved on G:; "
                    "NO settings installed.")
                messagebox.showinfo(
                    "This PC observation saved — NOT approved",
                    "Shared file:\n" + receipt["destination"] +
                    "\n\nSHA-256:\n" + receipt["sha256"] +
                    "\n\nNo profile synchronization or map change occurred.",
                    parent=dialog if dialog.winfo_exists() else self.root)
            self.async_operation(work, done)

        btn_compare.configure(command=compare)
        btn_save.configure(command=save)

    def review_office_map_source(self, map_name):
        """Never modify Office active scanned map; capture exact native values."""
        if self.in_progress:
            return
        self.status.set(
            f"Reading MSB Office scanned map {map_name} (READ ONLY)…")

        def work():
            return inspect_office_map(map_name=map_name)

        def done(result, error):
            self.set_busy(False)
            if error:
                self.status.set("Office scanned-map source not verified — no save.")
                messagebox.showerror(
                    "Office map-source capture blocked",
                    str(error) + "\nNo registry/maps/GPX/shared records changed.",
                    parent=self.root)
                return
            self.show_office_map_source(result)

        self.async_operation(work, done)

    def show_office_map_source(self, review):
        """Expose exact source settings/points BEFORE confirming G: evidence."""
        dialog = tk.Toplevel(self.root)
        dialog.title("OFFICE scanned-map capture — UNAPPROVED EVIDENCE")
        dialog.geometry("900x590")
        dialog.minsize(660, 410)
        dialog.transient(self.root)
        ttk.Label(
            dialog, text="OFFICE SCANNED MAP — READ ONLY / PRESERVE ALL REGISTRATIONS",
            font=("Segoe UI", 12, "bold"),
            padding=(12, 8, 12, 4)).pack(fill="x")
        ttk.Label(
            dialog, text=(f"Source: {review['origin_host']}  "
                          f"Selected map: {review['map_name']}  "
                          f"Control points: {review['point_count']}"),
            padding=(12, 0, 12, 5)).pack(fill="x")
        ttk.Label(
            dialog, text=(f"Projection: {review['projection']}  "
                          f"Image: {review['width']} × {review['height']}  "
                          f"Image SHA-256: {review['image_sha256']}"),
            padding=(12, 0, 12, 8), wraplength=850).pack(fill="x")
        ttk.Label(
            dialog, text=("This saves ONLY UNAPPROVED MAP SOURCE evidence to G:. "
                          "It does not edit the Office map, laptop map, Show PC, "
                          "current GPX or any calibration."),
            padding=(12, 0, 12, 6), wraplength=850).pack(fill="x")
        buttons = ttk.Frame(dialog, padding=(12, 4, 12, 12))
        buttons.pack(fill="x", side="bottom")
        viewer = scrolledtext.ScrolledText(
            dialog, wrap="word", font=("Consolas", 10))
        viewer.pack(fill="both", expand=True, padx=12, pady=6)
        entry = review["source"]
        viewer.insert("end", "NATIVE EXPERTGPS MAP HEADER SETTINGS\n")
        for field, spec in sorted(entry["native_header"].items()):
            viewer.insert("end", f"{field}: {spec['value']} "
                          f"[registry kind {spec['kind']}]\n")
        for point, values in sorted(review["points"].items()):
            viewer.insert("end", f"\n{point} EXACT CONTROL VALUES\n")
            for field, spec in sorted(values.items()):
                viewer.insert("end", f"  {field}: {spec['value']} "
                              f"[kind {spec['kind']}]\n")
        viewer.insert("end", "\nShared raster identity: " +
                      entry["shared_raster_path"] + "\n")
        for extension, asset in entry["sidecars"].items():
            viewer.insert("end", f"{extension} SHA: {asset['sha256']}\n")
        viewer.insert("end", "\nOFFICE CALIBRATION REMAINS UNCHANGED.\n")
        viewer.configure(state="disabled")
        ttk.Button(buttons, text="Cancel", command=dialog.destroy).pack(
            side="right")
        save_btn = ttk.Button(
            buttons, text="Save UNAPPROVED Office map source to G:")
        save_btn.pack(side="right", padx=(0, 10))

        def save():
            if self.in_progress or not dialog.winfo_exists():
                return
            if not messagebox.askyesno(
                    "Confirm Office map source evidence",
                    f"Record the verified map {review['map_name']} and exact "
                    "existing calibration under the MSB GIS shared Map-Sources "
                    "folder?\n\nThis will NOT change any PC's map or GPX. "
                    "The image and control points will be rechecked. Save?",
                    parent=dialog):
                return
            save_btn.configure(state="disabled")

            def work():
                return save_office_map_source(review)

            def saved(receipt, error):
                self.set_busy(False)
                if error:
                    if dialog.winfo_exists():
                        save_btn.configure(state="normal")
                    messagebox.showerror(
                        "Map source NOT saved",
                        str(error) + "\nNo workstation calibration was changed.",
                        parent=dialog if dialog.winfo_exists() else self.root)
                    return
                self.status.set(
                    "Office map source captured to G:; NO maps changed.")
                messagebox.showinfo(
                    "Office map source saved — NOT installed",
                    "New shared map source:\n" + receipt["destination"] +
                    "\n\nSHA-256 evidence:\n" + receipt["sha256"] +
                    "\n\nOffice, laptop and Show calibration UNCHANGED. "
                    "Target map transfer requires a separate reviewed step.",
                    parent=dialog if dialog.winfo_exists() else self.root)
                if dialog.winfo_exists():
                    dialog.destroy()
            self.async_operation(work, saved)
        save_btn.configure(command=save)

    def review_map_repair(self):
        """Offer a separately confirmed, private-backed fix to one Office map."""
        if self.in_progress:
            return
        self.status.set("Checking Office cropped-map repair baseline (READ ONLY)…")
        def work():
            return preview_map_repair()
        def done(review, error):
            self.set_busy(False)
            if error:
                messagebox.showerror(
                    "Office calibration repair refused", str(error),
                    parent=self.root)
                return
            dialog = tk.Toplevel(self.root)
            dialog.title("OFFICE TEST MAP ONLY — CALIBRATION REPAIR")
            dialog.geometry("790x510")
            ttk.Label(dialog, text="ONLY: " + OFFICE_CORRECT_MAP,
                      font=("Segoe UI", 12, "bold"), padding=10).pack(fill="x")
            ttk.Label(dialog, text=(
                "Does not modify EvergreenParkCropped or the Workshop map. "
                "Requires ExpertGPS closed. Saves a private calibration backup, "
                "reads back all 3 maps and rolls back on failure."),
                wraplength=740, padding=10).pack(fill="x")
            viewer = scrolledtext.ScrolledText(dialog, height=14, wrap="word")
            viewer.pack(fill="both", expand=True, padx=10)
            for key, value in review["target"].items():
                viewer.insert("end", f"{key}: {value}\n")
            viewer.insert("end", "\nSource image and pixel/worldfile controls will NOT change.")
            viewer.configure(state="disabled")
            buttons = ttk.Frame(dialog, padding=10)
            buttons.pack(fill="x", side="bottom")
            ttk.Button(buttons, text="Cancel", command=dialog.destroy).pack(side="right")
            def confirm():
                if not messagebox.askyesno("Approve Office test-map correction",
                        "Correct ONLY the existing Office test-map calibration?\n"
                        "Private backup and exact readback are mandatory.",
                        parent=dialog):
                    return
                typed = simpledialog.askstring("Type confirmation",
                        "Type REPAIR OFFICE TEST MAP", parent=dialog)
                if typed != "REPAIR OFFICE TEST MAP":
                    return
                dialog.destroy()
                def worker():
                    return apply_map_repair(review)
                def finished(receipt, failure):
                    self.set_busy(False)
                    if failure:
                        messagebox.showerror("Office map repair FAILED",
                            str(failure) + "\nKeep ExpertGPS closed.", parent=self.root)
                        return
                    messagebox.showinfo("Office test map repaired and verified",
                        "Verified exact calibration; other two maps unchanged.\n"
                        "Private recovery file: " + receipt["backup"],
                        parent=self.root)
                self.async_operation(worker, finished)
            ttk.Button(buttons, text="Back up and repair OFFICE TEST MAP",
                       command=confirm).pack(side="left")
        self.async_operation(work, done)

    def review_saved_proposal(self):
        """Open the selected *shared G:* proposal, never self-approve it."""
        if self.in_progress:
            return
        path = filedialog.askopenfilename(
            parent=self.root, title="Select submitted UNAPPROVED GIS proposal",
            initialdir=str(SHARED_ROOT / "Proposals"),
            filetypes=[("MSB GIS JSON proposal", "*.json")])
        if not path:
            return
        self.status.set("Inspecting saved shared GIS proposal (READ ONLY)…")

        def inspect():
            result = inspect_saved_proposal(path, SHARED_ROOT)
            staging = prepare_release_candidate(
                path, self.dest, shared_root=SHARED_ROOT,
                reviewed_sha256=result["sha256"], save=False)
            return result, staging

        def done(data, error):
            self.set_busy(False)
            if error:
                self.status.set("Shared proposal review blocked — nothing staged.")
                messagebox.showerror(
                    "Shared proposal not accepted for candidate review",
                    str(error) + "\nNo shared release, registry or GPX changed.",
                    parent=self.root)
                return
            self.show_saved_proposal_review(*data)

        self.async_operation(inspect, done)

    def show_saved_proposal_review(self, review, staging):
        """Review existing historical references before staging UNAPPROVED assets."""
        dialog = tk.Toplevel(self.root)
        dialog.title("Submitted GIS proposal — NOT a release approval")
        dialog.geometry("850x520")
        dialog.minsize(650, 370)
        dialog.transient(self.root)
        ttk.Label(
            dialog, text=(f"Source: {review['hostname']}   "
                          f"Types: {review['types']}   PNGs: {review['pngs']}   "
                          f"Maps: {review['maps']}   Review flags: "
                          f"{len(review['review_items'])}"),
            font=("Segoe UI", 11, "bold"), padding=(12, 10, 12, 5)
        ).pack(fill="x")
        ttk.Label(
            dialog, text=("Verified submitted proposal SHA-256: " + review["sha256"]),
            wraplength=800, padding=(12, 0, 12, 6)).pack(fill="x")
        ttk.Label(
            dialog, text=("Candidate output: " + staging["destination"] +
                          "\nNO approved manifest, map image, calibration installer "
                          "or Show PC configuration will be created."),
            wraplength=800, padding=(12, 0, 12, 6)).pack(fill="x")
        actions = ttk.Frame(dialog, padding=(12, 5, 12, 12))
        actions.pack(side="bottom", fill="x")
        viewer = scrolledtext.ScrolledText(dialog, wrap="word", font=("Consolas", 10))
        viewer.pack(fill="both", expand=True, padx=12, pady=5)
        for item in review["review_items"]:
            viewer.insert("end", f"{item['type']} — {item['reason']}\n"
                          f"  {item['url']}\n\n")
        viewer.insert("end", "\nUnresolved mandatory gates:\n")
        for gate in staging["gates"]:
            viewer.insert("end", " • " + gate + "\n")
        viewer.configure(state="disabled")
        ttk.Button(actions, text="Cancel", command=dialog.destroy).pack(side="right")
        stage_btn = ttk.Button(actions, text="Stage UNAPPROVED release candidate")
        stage_btn.pack(side="right", padx=(0, 10))

        def stage():
            if self.in_progress:
                return
            if not messagebox.askyesno(
                    "Confirm UNAPPROVED candidate staging",
                    f"Package the verified canonical PNGs for {review['hostname']} "
                    f"under the shared Candidates folder?\n\n"
                    "This does NOT approve the source profile, include the "
                    "map image/calibration sidecars, or install ExpertGPS. "
                    "The exact saved proposal and icon SHA-256 will be "
                    "rechecked before writing.\n\nStage candidate?",
                    parent=dialog):
                return
            stage_btn.configure(state="disabled")

            def work():
                return prepare_release_candidate(
                    review["path"], self.dest, shared_root=SHARED_ROOT,
                    reviewed_sha256=review["sha256"], save=True)

            def staged(receipt, error):
                self.set_busy(False)
                if dialog.winfo_exists():
                    dialog.destroy()
                if error:
                    self.status.set("Candidate staging stopped; inspect shared evidence.")
                    messagebox.showerror(
                        "Candidate staging not accepted",
                        str(error) + "\nNo approved GIS release installed.",
                        parent=self.root)
                    return
                self.status.set("UNAPPROVED candidate staged; Show PC still NOT ready.")
                messagebox.showinfo(
                    "Candidate staged — NOT approved",
                    "New shared candidate:\n" + receipt["destination"] +
                    "\n\nCandidate SHA-256 evidence only:\n" +
                    receipt["candidate_sha256_not_approval"] +
                    "\n\nMap imagery, administrator approval and the "
                    "targeted Show PC installer remain open.",
                    parent=self.root)
            self.async_operation(work, staged)
        stage_btn.configure(command=stage)

    def cancel_workstation_compare(self):
        """A canceled Step 6 must not retain a preceding PNG preflight STOP."""
        self.status.set("GIS release comparison canceled — no settings changed.")
        self.progress_count.set("Canceled")
        self.progress_detail.set("No GIS workstation comparison performed")
        # The independent profile status remains Not verified; cancellation
        # cannot certify or invalidate the current user's ExpertGPS settings.

    def check_workstation(self):
        """Compare a hash-pinned admin release; never propose/apply local writes."""
        manifest = filedialog.askopenfilename(
            parent=self.root, title="Select administrator-approved GIS release manifest",
            initialdir=str(self.releases), filetypes=[("JSON release", "*.json")])
        if not manifest:
            self.cancel_workstation_compare()
            return
        approved_sha = simpledialog.askstring(
            "Verify GIS release approval",
            "Paste the exact 64-character SHA-256 from the GIS administrator's"
            " separate approval receipt. The selected manifest cannot approve itself.",
            parent=self.root)
        if not approved_sha:
            self.cancel_workstation_compare()
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
        self.profile_proposal_btn.configure(state="disabled" if value else "normal")
        self.profile_candidate_btn.configure(state="disabled" if value else "normal")
        self.profile_align_btn.configure(state="disabled" if value else "normal")
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
                # A historical case collision is NOT solved by re-saving
                # current canonical PNG files (37 were already verified).
                if "filename-case collision" in error.casefold():
                    guidance = ("\nNo files copied. Historical filename-case conflict "
                                "needs administrator review; do not rename legacy "
                                "files or re-save unchanged canonical PNGs.")
                else:
                    guidance = ("\nNo files copied. Review the source/destination "
                                "details before trying again.")
                messagebox.showerror("PNG distribution requires attention",
                                     error + guidance)
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