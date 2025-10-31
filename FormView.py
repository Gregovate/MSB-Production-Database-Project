# Wiring Viewer (v6) – MSB Database (Field wiring aware)
# Initial Release : 2025-08-28  V0.1.3
# Author          : Greg Liebig, Engineering Innovations, LLC.
#
# Description
# -----------
# Tkinter GUI to inspect and export field wiring data from lor_output_v6.db.
# Provides toggles for props-only, spare suppression, and field wiring mode.
# Includes CSV and printable HTML exports.
#
# Revision History
# ----------------
# 2025-08-28  V0.1.3  Added Hide SPAREs toggle, sortable columns,
#                     and Suggested column toggle.
# 2025-10-15  V0.1.4  Removed "Show Suggested" checkbox and simplified columns.
# 2025-10-15  V0.2.0  Added "Field wiring mode" for per-stage field leads.
# 2025-10-23  V0.2.1  Added Export Printable HTML with embedded preview image,
#                     omitted EndChannel/Color columns, and prefilled export names.
#                     Fixed scope/indent issues, safe filename handling, and event binding.
# 2025-10-23  V0.2.2  Changed default sort order to Controller → StartChannel (hex/numeric),
#                     preserving user sort toggle behavior.
# 2025-10-23  V0.2.3  Added Stage View tab placeholder and Notebook shell;
#                     moved Image path field below Stage/Preview for better layout,
#                     and implemented "Open Folder" button for quick access to background images.
# 2025-10-28  V0.2.4  Refined wiring columns (Controller → StartChannel → Channel_Name …);
#                     removed EndChannel/Color/CrossDisplay; printable HTML now omits
#                     LORTag/ConnectionType/CrossDisplay and shows image path above image.
# 2025-10-28  V0.2.5  Added on-screen preview image with “Show image” toggle (default ON);
#                     echoed image path above image; anchored image to stay above grid when toggled.
# 2025-10-29  V0.2.6  Added image Scale slider (0.2×–2.0×); use bitmap scaling (no ttk height);
#                     fixed prior “image load error” and kept grid layout stable.
# 2025-10-29  V0.2.7  Added startup splash (icon + title + version/date); instant show, auto-close on UI ready.
# 2025-10-29  V0.2.8  Windows icon fix + splash order:
#                     - Set AppUserModelID for taskbar grouping
#                     - Apply iconbitmap(.ico) + iconphoto(True) before splash
#                     - Bundle Docs/images for reliable runtime lookup
# 2025-10-29  V0.2.9  Increased splash screen delay to 3000 ms

# Notes
# -----
# • CSV Export: retains full columns for data completeness.
# • HTML Export: trims EndChannel + Color, embeds preview background (from previews.BackgroundFile)
#   as base64 for reliable printing, and stamps date/time to mark print validity.
# • Default Sort: Controller (hex-aware) → StartChannel → Display_Name for intuitive field wiring layout.
# • Compatible with all parse_props_v6-generated databases (v6.x and later).
#
# GAL 25-10-23 — Engineering Innovations, LLC.

import sqlite3, csv, os, urllib.parse
import tkinter as tk
import re
from tkinter import ttk, filedialog, messagebox
from pathlib import Path
import datetime

# --- GAL 25-10-25: Added robust shared-drive path resolver for teammate PCs ---
import sys
import tkinter.messagebox as m

APP_VERSION = "0.2.9"

# --- GAL 25-10-29c: Windows taskbar grouping + icon pick-up ---
try:
    import ctypes  # type: ignore
    ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(
        "EngineeringInnovations.MSB.FormView"
    )
except Exception:
    pass

# --- Splash helpers (GAL 25-10-29) ---
def resource_path(rel_path: str) -> str:
    """Return an absolute path to resource, works for dev & PyInstaller."""
    if hasattr(sys, "_MEIPASS"):
        return os.path.join(sys._MEIPASS, rel_path)
    return os.path.join(os.path.dirname(__file__), rel_path)

class Splash:
    def __init__(self, root: tk.Tk, image_path: str, min_ms: int = 800):
        """
        root: the ONE Tk() instance (hidden while splash shows)
        image_path: PNG path via resource_path('Docs/images/splash.png')
        min_ms: minimum time to show splash while we init heavy stuff
        """
        from PIL import Image, ImageTk  # Pillow required
        self._root = root
        self._min_ms = min_ms
        self._shown_at = None

        # Top-level splash (no titlebar)
        self.top = tk.Toplevel(root)
        self.top.overrideredirect(True)
        self.top.attributes("-topmost", True)
        try:
            apply_window_icons(self.top)
        except Exception:
            pass

        # Load image
        ipath = image_path
        try:
            im = Image.open(ipath)
            im = im.convert("RGBA")
            self._img = ImageTk.PhotoImage(im)
        except Exception as e:
            # fallback: colored panel with text
            self._img = None
            frm = ttk.Frame(self.top, padding=20)
            frm.pack()
            ttk.Label(frm, text="Loading FormView…", font=("Segoe UI", 14)).pack()
        else:
            lbl = ttk.Label(self.top, image=self._img, borderwidth=0)
            lbl.pack()

        self._center_on_screen(self.top)
        self._shown_at = self._root.after(0, lambda: None)

    def _center_on_screen(self, win):
        win.update_idletasks()
        w = win.winfo_width()
        h = win.winfo_height()
        sw = win.winfo_screenwidth()
        sh = win.winfo_screenheight()
        x = (sw - w) // 2
        y = (sh - h) // 3
        win.geometry(f"{w}x{h}+{x}+{y}")

    def close(self):
        # ensure min show time
        self.top.destroy()

# --- GAL 25-10-29c: one place to set all window icons (titlebar + taskbar) ---
def apply_window_icons(win: tk.Misc):
    """
    Set both the .ico (title bar) and a PNG via iconphoto, which becomes the
    default for taskbar/alt-tab and all future Toplevels.
    """
    # Try ICO first (titlebar on Windows)
    try:
        ico = resource_path(os.path.join("Docs", "images", "formview.ico"))
        if not os.path.exists(ico):
            ico = os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "formview.ico")
        if os.path.exists(ico) and hasattr(win, "iconbitmap"):
            win.iconbitmap(ico)  # may raise on some Tk builds
    except Exception:
        pass

    # Also set a PNG iconphoto; Tk uses it broadly (incl. taskbar)
    try:
        png = resource_path(os.path.join("Docs", "images", "formview.png"))
        if not os.path.exists(png):
            png = os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "formview.png")
        if os.path.exists(png):
            _icon_img = tk.PhotoImage(file=png)
            # True => make it the default for future toplevels, too
            win.iconphoto(True, _icon_img)
            # keep a reference to avoid GC
            setattr(win, "_iconphoto_ref", _icon_img)
    except Exception:
        pass

def _resolve_db_path() -> str:
    """
    Find a usable DB path in this order:
      1) MSB_DB_PATH env var (lets you override per-PC)
      2) Standard shared path on G:
      3) Local copy next to script/exe
      4) Prompt user if all else fails
    """
    env = os.environ.get("MSB_DB_PATH")
    if env and os.path.exists(env):
        return env

    std = r"G:\Shared drives\MSB Database\database\lor_output_v6.db"
    if os.path.exists(std):
        return std

    here = Path(getattr(sys, "_MEIPASS", Path(__file__).parent))
    local = here / "lor_output_v6.db"
    if local.exists():
        return str(local)

    root = tk.Tk(); root.withdraw()
    m.showwarning("Locate Database",
                  "Could not find the MSB database automatically.\n\n"
                  "Please select lor_output_v6.db.")
    sel = filedialog.askopenfilename(
        title="Locate lor_output_v6.db",
        filetypes=[("SQLite DB", "*.db *.sqlite *.sqlite3"), ("All files", "*.*")]
    )
    root.destroy()

    if sel and os.path.exists(sel):
        return sel

    root = tk.Tk(); root.withdraw()
    m.showerror(
        "Path Error",
        "Database not found:\n\n"
        "• Expected: G:\\Shared drives\\MSB Database\\database\\lor_output_v6.db\n"
        "• Or set MSB_DB_PATH to a valid .db file\n\n"
        "Ask a lead to map your G: drive to the Shared Drive or browse to the DB."
    )
    root.destroy()
    raise SystemExit(1)

DEFAULT_DB = _resolve_db_path()
# --- End of path resolver (GAL 25-10-25) ---

# # Superset of columns used by both views; extra columns are filled when present
# COLUMNS = [
#     ("Source",         90),
#     ("Channel_Name",  260),
#     ("Display_Name",  260),
#     ("Network",        90),
#     ("Controller",     90),
#     ("StartChannel",  110),
#     ("EndChannel",    100),
#     ("Color",          80),
#     ("DeviceType",     90),
#     ("LORTag",        300),
#     ("ConnectionType",110),  # only present in field views
#     ("CrossDisplay",  110),  # only present in field views
# ]

# --- GAL 25-10-28: streamlined wiring columns for field clarity ---
# Order: Controller, StartChannel, Channel_Name, Display_Name, Network, Source, ConnectionType, DeviceType, LORTag
COLUMNS = [
    ("Controller",     90),
    ("StartChannel",  110),
    ("Channel_Name",  260),
    ("Display_Name",  260),
    ("Network",        90),
    ("Source",         90),
    ("ConnectionType",110),  # blank in non-field maps
    ("DeviceType",     90),
    ("LORTag",        300),
]

SQL_PREVIEWS = "SELECT Name FROM previews ORDER BY Name COLLATE NOCASE;"

SQL_VIEW_CHECKS = {
    "map":      "SELECT name FROM sqlite_master WHERE type='view' AND name='preview_wiring_map_v6';",
    "fieldmap": "SELECT name FROM sqlite_master WHERE type='view' AND name='preview_wiring_fieldmap_v6';",
    "lead":     "SELECT name FROM sqlite_master WHERE type='view' AND name='preview_wiring_fieldlead_v6';",
    "fieldonly":"SELECT name FROM sqlite_master WHERE type='view' AND name='preview_wiring_fieldonly_v6';",
}

# SQL_MAP = """
# SELECT
#   Source, LORName AS Channel_Name, DisplayName AS Display_Name,
#   Network, Controller, StartChannel, EndChannel, NULL AS Color, DeviceType, LORTag,
#   '' AS ConnectionType, 0 AS CrossDisplay
# FROM preview_wiring_sorted_v6
# WHERE PreviewName = ?
# {extra_filters}
# ORDER BY {order_by};
# """

# --- GAL 25-10-28: streamlined wiring columns for field clarity ---
SQL_MAP = """
SELECT
  Controller,                      -- Controller
  StartChannel,                    -- StartChannel
  LORName       AS Channel_Name,   -- Channel_Name
  DisplayName   AS Display_Name,   -- Display_Name
  Network,                         -- Network
  Source,                          -- Source
  ''            AS ConnectionType, -- ConnectionType (not used in map view)
  DeviceType,                      -- DeviceType
  LORTag                           -- LORTag
FROM preview_wiring_sorted_v6
WHERE PreviewName = ?
{extra_filters}
ORDER BY {order_by};
"""

# Field wiring mode: show exactly one FIELD row per display per circuit within the selected stage/preview

# SQL_FIELDLEAD = """
# SELECT
#   Source, Channel_Name, Display_Name,
#   Network, Controller, StartChannel, EndChannel, Color, DeviceType, LORTag,
#   ConnectionType, CrossDisplay
# FROM preview_wiring_fieldlead_v6
# WHERE PreviewName = ?
# {extra_filters}
# ORDER BY {order_by};
#"""

# --- GAL 25-10-28: streamlined wiring columns for field clarity ---
# Field wiring mode: one FIELD row per display/circuit for the selected preview
SQL_FIELDLEAD = """
SELECT
  Controller,                      -- Controller
  StartChannel,                    -- StartChannel
  Channel_Name,                    -- Channel_Name
  Display_Name,                    -- Display_Name
  Network,                         -- Network
  Source,                          -- Source
  ConnectionType,                  -- ConnectionType
  DeviceType,                      -- DeviceType
  LORTag                           -- LORTag
FROM preview_wiring_fieldlead_v6
WHERE PreviewName = ?
{extra_filters}
ORDER BY {order_by};
"""

def connect_ro(db_path: str) -> sqlite3.Connection:
    p = os.path.abspath(db_path).replace("\\", "/")
    uri_path = urllib.parse.quote(p)
    try:
        return sqlite3.connect(f"file:///{uri_path}?mode=ro&immutable=0", uri=True, timeout=5.0)
    except Exception:
        return sqlite3.connect(db_path, timeout=5.0)

# --- GAL 25-10-29: simple splash screen (icon + title + version/date) ---
class Splash(tk.Toplevel):
    def __init__(self, master, image_path: str, title_text: str, subtitle_text: str):
        super().__init__(master)
        self.overrideredirect(True)              # borderless
        self.attributes("-topmost", True)        # stay above while loading
        try:
            self.wm_attributes("-toolwindow", True)
        except Exception:
            pass

        # Size/center
        w, h = 520, 340
        self.update_idletasks()
        x = self.winfo_screenwidth() // 2 - w // 2
        y = self.winfo_screenheight() // 2 - h // 2
        self.geometry(f"{w}x{h}+{x}+{y}")

        # UI
        outer = ttk.Frame(self, padding=16)
        outer.pack(fill=tk.BOTH, expand=True)

        # Try to show PNG icon (fallback to text)
        img_ok = False
        try:
            from PIL import Image, ImageTk, ImageOps
            if image_path and os.path.exists(image_path):
                im = Image.open(image_path)
                im = ImageOps.exif_transpose(im)
                im.thumbnail((160, 160), Image.LANCZOS)
                self._img = ImageTk.PhotoImage(im)  # keep ref
                ttk.Label(outer, image=self._img, anchor="center").pack(pady=(4, 10))
                img_ok = True
        except Exception:
            pass

        if not img_ok:
            ttk.Label(outer, text="MSB FormView", font=("Segoe UI", 18, "bold")).pack(pady=(12, 10))

        ttk.Label(outer, text=title_text, font=("Segoe UI", 16, "bold")).pack()
        ttk.Label(outer, text=subtitle_text, font=("Segoe UI", 10)).pack(pady=(2, 8))
        ttk.Label(outer, text="Loading…", font=("Segoe UI", 9)).pack(pady=(10, 0))

    def close(self, fade_ms: int = 160):
        """Optional quick fade-out for polish."""
        try:
            for i in range(10, -1, -1):
                self.attributes("-alpha", i / 10)
                self.update_idletasks()
                self.after(max(1, fade_ms // 10))
        except Exception:
            pass
        self.destroy()

    def close(self, fade_ms: int = 160):
        """Optional quick fade-out for polish."""
        try:
            for i in range(10, -1, -1):
                self.attributes("-alpha", i / 10)
                self.update_idletasks()
                self.after(max(1, fade_ms // 10))
        except Exception:
            pass
        self.destroy()

class StageViewFrame(ttk.Frame):
    """
    Read-only stage listing, grouped Stage -> Preview -> Displays.
    Uses the views created by parse_props_v6.py (stage_display_list_all_v1).
    """
    def __init__(self, master, db_path: str, reports_root: Path):
        super().__init__(master)
        self.db_path = db_path
        self.reports_root = reports_root

        # Top bar
        top = ttk.Frame(self)
        top.pack(fill="x", pady=6)
        ttk.Button(top, text="Export HTML for Print", command=self.on_export).pack(side="right")

        # Tree
        self.tree = ttk.Treeview(self, columns=("type",), show="tree")
        self.tree.pack(fill="both", expand=True)
        

        self.refresh()

    def _guess_stage_name(self, label: str, stage: str) -> str:
        """
        Extract a human title from a StagePreviewLabel like:
        'Show Background Stage 09 Global Warming'
        'RGB Plus Prop Stage 15 Church'
        Returns the part after 'Stage <num>'.
        """
        try:
            n = int(stage)  # handle '09' -> 9
        except Exception:
            n = stage
        # look for "Stage <n> <Title...>"
        m = re.search(rf"\bStage\s*0?{n}\s*(.+)$", label, flags=re.IGNORECASE)
        if m:
            title = m.group(1).strip(" -:–—\t")
            return title
        return ""


    def refresh(self):
        for i in self.tree.get_children():
            self.tree.delete(i)

        rows = self._fetch_rows()
        from collections import defaultdict, OrderedDict
        stages = defaultdict(lambda: OrderedDict())
        stage_titles = {}  # NEW: stage -> derived title

        for stage, label, name, has in rows:
            stages[stage].setdefault(label, []).append((name, has))
            # NEW: remember the first non-empty title we can extract
            if stage not in stage_titles:
                t = self._guess_stage_name(label, stage)
                if t:
                    stage_titles[stage] = t

        # Render
        for stage in sorted(stages.keys(), key=lambda s: (s=='Unassigned', len(s), s)):
            # NEW: append " — <title>" if we have one
            title = stage_titles.get(stage, "")
            text = f"Stage {stage}" + (f" — {title}" if title else "")
            sid = self.tree.insert("", "end", text=text, open=True)

            for label, items in stages[stage].items():
                lid = self.tree.insert(sid, "end", text=label, open=False)
                for name, has in items:
                    suffix = "" if has else "  [no wiring]"
                    self.tree.insert(lid, "end", text=f"{name}{suffix}")


    def _fetch_rows(self):
        q = """
        SELECT StageBucket, StagePreviewLabel, DisplayName, HasWiring
        FROM stage_display_list_all_v1
        ORDER BY
          (StageBucket='Unassigned') ASC,
          LENGTH(StageBucket), StageBucket,
          (StagePreviewLabel LIKE '%Show Background Stage%') DESC,
          (StagePreviewLabel LIKE '%RGB Plus Prop Stage%') DESC,
          StagePreviewLabel COLLATE NOCASE ASC,
          DisplayName COLLATE NOCASE ASC
        """
        conn = sqlite3.connect(self.db_path)
        try:
            rows = conn.execute(q).fetchall()
        finally:
            conn.close()
        return rows

    def on_export(self):
        # Mirror the parser’s output location
        self.reports_root.mkdir(parents=True, exist_ok=True)
        out = self.reports_root / "stage_display_list.html"
        try:
            # Recreate the same HTML structure the parser writes (lightweight re-gen here)
            rows = self._fetch_rows()
            from collections import defaultdict, OrderedDict
            stages = defaultdict(lambda: OrderedDict())
            for stage, label, name, has in rows:
                stages[stage].setdefault(label, []).append((name, has))

            # GAL 25-10-23 — local import avoids any module-scope shadowing
            from datetime import datetime
            ts = datetime.now().strftime("%Y-%m-%d %H:%M")

            html = [
                "<!doctype html><meta charset='utf-8'>",
                "<title>MSB — Stage Display Listing</title>",
                "<style>body{font:14px/1.4 system-ui,Segoe UI,Arial} h1{font-size:20px} "
                "h2{font-size:16px;margin:14px 0 6px} h3{margin:8px 0 4px} "
                "ul{margin:0 0 14px 20px} .stage{page-break-inside:avoid} "
                ".inv{opacity:.85} .tag{font-size:11px;padding:0 6px;border:1px solid #aaa;"
                "border-radius:8px;margin-left:6px}</style>",
                f"<h1>Stage Display Listing <small style='font-weight:normal;color:#666'>(generated {ts})</small></h1>"
            ]
            for stage in sorted(stages.keys(), key=lambda s: (s=='Unassigned', len(s), s)):
                html.append(f"<div class='stage'><h2>Stage {stage}</h2>")
                for label, items in stages[stage].items():
                    html.append(f"<h3>{label}</h3><ul>")
                    for name, has in items:
                        tag = "" if has else '<span class="tag">no wiring</span>'
                        cls = "" if has else ' class="inv"'
                        html.append(f"<li{cls}>{name}{tag}</li>")
                    html.append("</ul>")
                html.append("</div>")

            out.write_text("\n".join(html), encoding="utf-8")
            messagebox.showinfo("Export", f"Stage report written:\n{out}")
        except Exception as e:
            messagebox.showerror("Export failed", str(e))



from tkinter import ttk

class WiringViewer(ttk.Frame):
    def __init__(self, master, db_path):
        super().__init__(master)            # <— we are a Frame hosted by a parent
        self.db_path = db_path
        # --- GAL 25-10-30a [IMG_PAGING_STATE] ---------------------------------------
        # Image paging state: page list + current index.
        # Page 0 = the BackgroundFile shown by the preview (Page 01 visually)
        self._image_pages: list[str] = []
        self._image_page_idx: int = 0
        # ---------------------------------------------------------------------------

        # DO NOT set title/geometry here (those belong to the root)
        # build UI on self...
        # e.g., self.tree = ttk.Treeview(self); self.tree.pack(...)

        self.conn: sqlite3.Connection | None = None

        self.sort_col = "Controller"
        self.sort_asc = True

        top = ttk.Frame(self, padding=6); top.pack(side=tk.TOP, fill=tk.X)

        self.db_label_var = tk.StringVar(value=os.path.abspath(self.db_path))
        ttk.Label(top, text="DB:").pack(side=tk.LEFT)
        ttk.Entry(top, textvariable=self.db_label_var, width=60, state="readonly").pack(side=tk.LEFT, padx=(2,6))
        ttk.Button(top, text="Choose DB…", command=self.choose_db).pack(side=tk.LEFT, padx=(0,10))

        ttk.Label(top, text="Stage / Preview:").pack(side=tk.LEFT)
        self.preview_var = tk.StringVar()
        self.preview_cbo = ttk.Combobox(top, textvariable=self.preview_var, width=55, state="readonly")
        self.preview_cbo.pack(side=tk.LEFT, padx=(2,6))
        self.preview_cbo.bind("<<ComboboxSelected>>",
                            lambda e: (self._update_bg_path_ui(), self.refresh_rows()))

        # GAL 25-10-23 — show BackgroundFile path to the right of the preview picker
        ttk.Button(top, text="Refresh", command=self.refresh_rows).pack(side=tk.LEFT, padx=(0,6))
        ttk.Button(top, text="Export CSV…", command=self.export_csv).pack(side=tk.LEFT)
        ttk.Button(top, text="Export Printable…", command=self.export_printable_html).pack(side=tk.LEFT, padx=(6,0))

        # --- second row: preview image path (full width) ---  GAL 25-10-23
        # --- second row: preview image path (full width) ---  GAL 25-10-23
        row2 = ttk.Frame(self, padding=(6, 0, 6, 6))
        row2.pack(side=tk.TOP, fill=tk.X)

        ttk.Label(row2, text="Image:").pack(side=tk.LEFT, padx=(0, 6))
        self.bg_path_var = tk.StringVar(value="")
        self.bg_entry = ttk.Entry(row2, textvariable=self.bg_path_var, state="readonly")
        self.bg_entry.pack(side=tk.LEFT, fill=tk.X, expand=True)

        ttk.Button(row2, text="Open Folder", command=self._open_image_folder).pack(side=tk.LEFT, padx=(6, 0))

        # --- GAL 25-10-30d [IMG_NAVIGATION_UI_BLOCK] -------------------------------
        # Image pager controls: << Page x/y >>
        # These allow cycling through multiple background images for the same stage.
        self.img_prev_btn = ttk.Button(row2, text="<<", width=3, command=lambda: self._go_prev_image())
        self.img_prev_btn.pack(side=tk.LEFT, padx=(8, 2))

        self.img_page_label_var = tk.StringVar(value="Page 1/1")
        self.img_page_label = ttk.Label(row2, textvariable=self.img_page_label_var)
        self.img_page_label.pack(side=tk.LEFT, padx=(4, 4))

        self.img_next_btn = ttk.Button(row2, text=">>", width=3, command=lambda: self._go_next_image())
        self.img_next_btn.pack(side=tk.LEFT, padx=(2, 0))
        # ---------------------------------------------------------------------------

        # --- GAL 25-10-28c: toggle to show/hide on-screen image (default ON) ---
        self.show_image_var = tk.BooleanVar(value=True)
        ttk.Checkbutton(
            row2,
            text="Show image",
            variable=self.show_image_var,
            command=self._toggle_image_visibility
        ).pack(side=tk.LEFT, padx=(12, 0))

        # --- GAL 25-10-28e: on-screen image area (path echo + image) ---
        from PIL import Image, ImageTk  # safe to repeat import, no harm

        # This frame holds both the small path label and the preview image
        self.image_frame = ttk.Frame(self, padding=(6, 6, 6, 6))
        self.image_frame.pack(side=tk.TOP, fill=tk.BOTH, expand=False)

        # Show the image path again above the image (small font)
        try:
            style = ttk.Style()
            style.configure("Small.TLabel", font=("Segoe UI", 8))
        except Exception:
            pass
        self.bg_path_echo = ttk.Label(
            self.image_frame,
            textvariable=self.bg_path_var,
            style="Small.TLabel",
            anchor="w"
        )
        self.bg_path_echo.pack(side=tk.TOP, fill=tk.X, padx=6, pady=(0, 4))

        # This label will hold the actual image
        self.image_label = ttk.Label(self.image_frame, anchor="center")
        self.image_label.pack(side=tk.TOP, fill=tk.X, padx=6, pady=(0, 6))

        # Keep a reference to avoid image disappearing
        self._current_img = None

        # Update the image whenever the path changes
        self.bg_path_var.trace_add("write", lambda *_: self._update_preview_image())

        # Make sure it’s visible if the toggle is ON
        self._toggle_image_visibility()
        self._update_preview_image()

        # --- GAL 25-10-29a: image scale slider ---
        ttk.Label(row2, text="Scale:").pack(side=tk.LEFT, padx=(12, 2))
        self.image_scale_var = tk.DoubleVar(value=1.0)
        scale = ttk.Scale(
            row2,
            from_=0.2, to=2.0, orient="horizontal",
            variable=self.image_scale_var,
            command=lambda *_: self._update_preview_image()
        )
        scale.pack(side=tk.LEFT, padx=(0, 6))


        # Filters
        filt = ttk.Frame(self, padding=(6,0,6,6))
        filt.pack(side=tk.TOP, fill=tk.X)
        self.filters_frame = filt   # GAL 25-10-28f: anchor for image re-pack placement

        self.field_mode = tk.BooleanVar(value=True)
        ttk.Checkbutton(
            filt, text="Field wiring mode (one lead per display/circuit)", variable=self.field_mode,
            command=self.refresh_rows
        ).pack(side=tk.LEFT, padx=(0,12))

        self.props_only = tk.BooleanVar(value=False)
        ttk.Checkbutton(
            filt, text="Displays only", variable=self.props_only, command=self.refresh_rows
        ).pack(side=tk.LEFT, padx=(0,12))

        self.hide_spares = tk.BooleanVar(value=True)
        ttk.Checkbutton(
            filt, text="Hide SPAREs", variable=self.hide_spares, command=self.refresh_rows,
            takefocus=False
        ).pack(side=tk.LEFT, padx=(0,12))

        self.count_var = tk.StringVar(value="Rows: 0")
        ttk.Label(filt, textvariable=self.count_var).pack(side=tk.RIGHT)

        # Table
        self.tree = ttk.Treeview(self, columns=[c for c,_ in COLUMNS], show="headings")
        self.tree.pack(side=tk.TOP, fill=tk.BOTH, expand=True)

        for col, width in COLUMNS:
            self.tree.heading(col, text=col, command=lambda c=col: self.on_sort(c))
            self.tree.column(col, width=width, anchor=tk.W, stretch=True)

        ysb = ttk.Scrollbar(self, orient="vertical",   command=self.tree.yview)
        xsb = ttk.Scrollbar(self, orient="horizontal", command=self.tree.xview)
        self.tree.configure(yscroll=ysb.set, xscroll=xsb.set)
        ysb.pack(side=tk.RIGHT, fill=tk.Y)
        xsb.pack(side=tk.BOTTOM, fill=tk.X)

        # --- GAL 25-10-31 [IMG_NAV_BINDINGS] --------------------------------------
        # Keyboard shortcuts for image paging (Wiring View only)
        root = self.winfo_toplevel()

        def _bind(seq, fn):
            root.bind_all(seq, lambda e, f=fn: f(), add="+")

        # Reliable bracket keysyms on Windows + convenience keys
        _bind("<KeyPress-bracketleft>",  self._go_prev_image)   # [
        _bind("<KeyPress-bracketright>", self._go_next_image)   # ]
        _bind("<Prior>",                 self._go_prev_image)   # PageUp
        _bind("<Next>",                  self._go_next_image)   # PageDown
        _bind("<Alt-Left>",              self._go_prev_image)   # Alt+←
        _bind("<Alt-Right>",             self._go_next_image)   # Alt+→
        # ---------------------------------------------------------------------------

        self.safe_connect()
        self.load_previews()

    # ------------------------ DB helpers ------------------------
    def safe_connect(self):
        if self.conn:
            try: self.conn.close()
            except Exception: pass
            self.conn = None
        try:
            self.conn = connect_ro(self.db_path)
            self.conn.execute("PRAGMA busy_timeout=3000;")
        except Exception as e:
            messagebox.showerror("DB Error", f"Could not open database:\n{self.db_path}\n\n{e}")
            self.conn = None

    def choose_db(self):
        path = filedialog.askopenfilename(
            title="Select SQLite DB",
            filetypes=[("SQLite DB","*.db *.sqlite *.sqlite3"), ("All files","*.*")]
        )
        if not path: return
        self.db_path = path
        self.db_label_var.set(os.path.abspath(path))
        self.safe_connect()
        self.load_previews()

    def _view_exists(self, key: str) -> bool:
        try:
            row = self.conn.execute(SQL_VIEW_CHECKS[key]).fetchone()
            return row is not None
        except Exception:
            return False

    def load_previews(self):
        self.preview_cbo["values"] = []
        if not self.conn: return
        try:
            names = [r[0] for r in self.conn.execute(SQL_PREVIEWS).fetchall()]
            self.preview_cbo["values"] = names
            if names and (self.preview_var.get() not in names):
                self.preview_var.set(names[0])

            # GAL 25-10-23 — update BackgroundFile path display
            self._update_bg_path_ui()

            self.after(50, self.refresh_rows)
        except Exception as e:
            messagebox.showerror("Query Error", str(e))

    def _open_image_folder(self):
        p = (self.bg_path_var.get() or "").strip()
        if not p:
            messagebox.showinfo("Open Folder", "No image path for this preview.")
            return
        try:
            folder = os.path.dirname(p) if os.path.splitext(p)[1] else p
            os.startfile(folder)  # Windows
        except Exception as e:
            messagebox.showerror("Open Folder", str(e))

    # --- GAL 25-10-28c: helpers for image loading and visibility ---
    def _toggle_image_visibility(self):
        """Show/hide the on-screen preview image area."""
        if self.show_image_var.get():
            # Ensure we re-pack the image above Filters (and thus above the grid)
            try:
                self.image_frame.pack_forget()
            except Exception:
                pass

            kwargs = dict(side=tk.TOP, fill=tk.BOTH, expand=False)
            anchor = getattr(self, "filters_frame", None)
            # Only use 'before' if the anchor shares the same parent and uses pack
            if anchor is not None and str(anchor.winfo_manager()) == "pack" and anchor.winfo_parent() == self.winfo_name():
                kwargs["before"] = anchor
            else:
                # Fallback: still pack at top (most layouts will be fine)
                kwargs["before"] = anchor

            self.image_frame.pack(**kwargs)
            self._update_preview_image()
        else:
            self.image_frame.pack_forget()

    # --- GAL 25-10-28h: image update helper (must live INSIDE the WiringViewer class) ---
    def _update_preview_image(self):
        """Load and display the preview image on screen (resized), if the toggle is ON."""
        # If the toggle isn’t present or is OFF, do nothing
        if not hasattr(self, "show_image_var") or not self.show_image_var.get():
            return
        if not hasattr(self, "image_label"):
            return

        # Path from the on-screen entry/echo
        path = (self.bg_path_var.get().strip() if hasattr(self, "bg_path_var") else "")
        if not path or not os.path.exists(path):
            self.image_label.configure(image="", text="(no image)")
            self._current_img = None
            return

        # Try to import Pillow on-demand so app still runs even if Pillow is missing
        try:
            from PIL import Image, ImageTk, ImageOps
        except Exception:
            # Pillow isn’t installed — just show a friendly message
            self.image_label.configure(image="", text="(install Pillow to show image)")
            self._current_img = None
            return

        try:
            im = Image.open(path)
            # Correct EXIF rotation if present
            try:
                im = ImageOps.exif_transpose(im)
            except Exception:
                pass

            # Normalize mode
            if im.mode not in ("RGB", "RGBA"):
                im = im.convert("RGB")

            # # Reasonable size for the UI
            # max_w, max_h = 900, 600
            # im.thumbnail((max_w, max_h), Image.LANCZOS)

            # --- GAL 25-10-29a: dynamic scale + fixed frame height ---
            # --- GAL 25-10-29b: dynamic scale — constrain by target height (no widget 'height') ---
            scale_factor = 1.0
            if hasattr(self, "image_scale_var"):
                try:
                    scale_factor = float(self.image_scale_var.get())
                except Exception:
                    pass

            # Base viewport; keep modest height so the grid doesn’t shrink
            BASE_W, BASE_H = 900, 300           # 300px tall by default
            target_w = max(1, int(BASE_W * scale_factor))
            target_h = max(1, int(BASE_H * scale_factor))

            im.thumbnail((target_w, target_h), Image.LANCZOS)

            # Show it and keep a reference to avoid GC
            tk_img = ImageTk.PhotoImage(im)
            self.image_label.configure(image=tk_img, text="")
            self._current_img = tk_img

            # Prevent frame from collapsing smaller than 300 px
            self.image_frame.update_idletasks()
            # self.image_label.configure(height=300)


            # Show it and keep a reference to avoid GC
            tk_img = ImageTk.PhotoImage(im)
            self.image_label.configure(image=tk_img, text="")
            self._current_img = tk_img
        except Exception as e:
            print(f"[DEBUG] Failed to load image: {e}")
            self.image_label.configure(image="", text="(image load error)")
            self._current_img = None

    # --- GAL 25-10-30e [IMG_NAV_HANDLERS] --------------------------------------
    def _update_image_from_index(self) -> None:
        """Apply current index → path box + on-screen image + pager label."""
        try:
            pages = self._image_pages or []
            idx = max(0, min(self._image_page_idx, max(0, len(pages) - 1)))
            self._image_page_idx = idx

            # Determine path to show
            if pages:
                path = pages[idx]
            else:
                # fall back to whatever is in bg_path_var (may be '(no background image)')
                path = self.bg_path_var.get().strip()

            # Update the path entry so the preview image follows
            self.bg_path_var.set(path if path else "(no background image)")

            # Update the pager label
            total = max(1, len(pages))   # show 1/1 if empty
            self.img_page_label_var.set(f"Page {idx+1}/{total}")

            # Enable/disable buttons
            can_prev = idx > 0
            can_next = idx < (total - 1)
            try:
                self.img_prev_btn.state(["!disabled"] if can_prev else ["disabled"])
                self.img_next_btn.state(["!disabled"] if can_next else ["disabled"])
            except Exception:
                # Fallback for older ttk on Windows if .state() not available
                self.img_prev_btn["state"] = ("normal" if can_prev else "disabled")
                self.img_next_btn["state"] = ("normal" if can_next else "disabled")

            # If your image view needs a refresh call, do it here (e.g., self._refresh_image())
            # self._refresh_image()
        except Exception as ex:
            print("[WARN] _update_image_from_index failed:", ex)

    def _go_prev_image(self) -> None:
        if self._image_pages and self._image_page_idx > 0:
            self._image_page_idx -= 1
        self._update_image_from_index()

    def _go_next_image(self) -> None:
        if self._image_pages and self._image_page_idx < (len(self._image_pages) - 1):
            self._image_page_idx += 1
        self._update_image_from_index()
    # ---------------------------------------------------------------------------

    # --- GAL 25-10-31d [IMG_EXPORT_HTML_BLOCK] ------------------------------------
    def _html_image_section(self) -> str:
        """
        Return HTML for all discovered images (self._image_pages).
        Automatically includes captions and page breaks for printing.
        """
        import os
        if not getattr(self, "_image_pages", None):
            return "<p><em>No images found for this preview.</em></p>"

        html_parts = [
            '<div class="image-section" style="margin-bottom:1em;">'
        ]

        # Identify the currently displayed image (whatever is active onscreen)
        current_img = (self.bg_path_var.get() or "").strip().lower()

        total = len(self._image_pages)
        shown = 0
        for img_path in self._image_pages:
            if img_path.strip().lower() == current_img:
                continue  # skip current image shown in header
            shown += 1
            name = os.path.basename(img_path)
            html_parts.append(f"""
            <figure style="text-align:center; margin-bottom:1.5em; page-break-after:always;">
                <img src="file:///{img_path}" style="max-width:95%; height:auto; border:1px solid #ccc;">
                <figcaption style="font-size:0.9em; color:#555;">
                    Page {shown}/{total-1 if total>1 else 1} — {name}
                </figcaption>
            </figure>
            """)




        html_parts.append("</div>")
        return "\n".join(html_parts)
    # ---------------------------------------------------------------------------


    # --- GAL 25-10-30b [IMG_DISCOVERY_BLOCK] ------------------------------------
    def _discover_image_pages(self, primary_path: str) -> list[str]:
        """
        Given the BackgroundFile path (primary_path), return an ordered list
        of image paths for paging. Rules:

        • Page 1 is the primary BackgroundFile (if present on disk).
        • Additional pages are discovered in the *same folder* as primary.
        • We prefer files that match the same Stage number token.
            - Robust detection for both 'Stage 21' and 'Stage-21' styles.
        • Allowed extensions: .jpg, .jpeg, .png (case-insensitive).
        • If no stage token is found, fall back to 'all images in folder'.
        • The returned list is deduped and alphabetically/naturally ordered
            with the primary first.

        This function *does not* change UI state. Caller sets self._image_pages
        and self._image_page_idx as needed.
        """
        try:
            import os, re
            from pathlib import Path
            p = (primary_path or "").strip()
            if not p:
                return []

            # Normalize
            p = os.path.normpath(p)
            folder = os.path.dirname(p)
            name   = os.path.basename(p)

            # If primary isn't a file on disk, we still treat it as Page 1 *display*,
            # but discovery will have nothing to add (unless we still scan the folder).
            primary_exists = os.path.exists(p)

            # Stage token extraction (accepts "Stage 21", "Stage-21", "Stage:21")
            stage_num = None
            m = re.search(r"\bStage[\s\-_:]*0?(\d{1,2})\b", name, flags=re.IGNORECASE)
            if m:
                stage_num = m.group(1)

            # Gather candidates from folder
            exts = {".jpg", ".jpeg", ".png"}
            try:
                entries = list(Path(folder).glob("*"))
            except Exception:
                entries = []

            # First pass: allowed image files
            imgs = [str(e) for e in entries
                    if e.is_file() and e.suffix.lower() in exts]

            # Filter by Stage token if we found one
            if stage_num is not None:
                # Build tolerant regex that matches "... Stage 21 ..." or "... Stage-21 ..."
                # (ignore case; allow multiple spaces/dashes/underscores)
                token = re.compile(rf"\bStage[\s\-_:]*0?{re.escape(stage_num)}\b",
                                flags=re.IGNORECASE)
                imgs = [f for f in imgs if token.search(os.path.basename(f))]

            # Natural-ish sort (alphabetic is fine for now)
            imgs = sorted(imgs, key=lambda s: s.lower())

            # Ensure primary is first (even if it wouldn't pass stage filter).
            out = []

            if p not in imgs:
                # Include the primary even if missing (shows as 'no image' later),
                # because we want page 1 to track the selected BackgroundFile.
                out.append(p)
            else:
                # Remove from the list so we can prepend it exactly once
                imgs = [x for x in imgs if x != p]
                out.append(p)

            # Append the rest; dedupe just in case
            seen = {out[0]}
            for x in imgs:
                if x not in seen:
                    out.append(x); seen.add(x)

            # If primary doesn't exist and there are zero other images,
            # return just [primary] to keep paging logic consistent.
            return out
        except Exception:
            # Fail safe: only the primary, if any
            return [primary_path] if primary_path else []
    # ---------------------------------------------------------------------------


    # GAL 25-10-23 — resolve image by PreviewName OR StagePreviewLabel
    def _get_preview_bg_path(self, selected: str) -> str:
        """
        Look up BackgroundFile from previews using Name (combobox text),
        with a fallback to StageID. Returns a normalized absolute/empty string.
        """
        try:
            con = self.conn if self.conn else sqlite3.connect(self.db_path)
            row = con.execute(
                "SELECT BackgroundFile FROM previews WHERE Name = ? OR StageID = ? LIMIT 1",
                (selected, selected),
            ).fetchone()
            if con is not self.conn:
                con.close()
            path = (row[0] or "").strip() if row else ""
            return os.path.normpath(path) if path else ""
        except Exception:
            return ""

    # --- GAL 25-10-30c [IMG_DISCOVERY_INTEGRATION] ------------------------------
    def _update_bg_path_ui(self):
        name = self.preview_var.get().strip()
        primary = self._get_preview_bg_path(name) or ""
        self.bg_path_var.set(primary or "(no background image)")

        # NEW: discover pages whenever the primary path changes
        pages = self._discover_image_pages(primary) if primary else []
        # Always keep a consistent list (even if primary is empty)
        self._image_pages = pages if pages else ([primary] if primary else [])
        # Reset index to 0 (primary page)
        self._image_page_idx = 0

        # --- GAL 25-10-30f [IMG_DISCOVERY_INTEGRATION_APPLY] -----------------------
        # Apply the new page list to update the path display, pager label, and buttons.
        self._update_image_from_index()
        # ---------------------------------------------------------------------------
    # ---------------------------------------------------------------------------


    # ------------------------ UI actions ------------------------
    def clear_rows(self):
        for iid in self.tree.get_children():
            self.tree.delete(iid)
        self.count_var.set("Rows: 0")

    # --- GAL 25-10-28: streamlined wiring columns for field clarity ---
    def _order_by_clause(self):
        col = self.sort_col
        dirn = "ASC" if self.sort_asc else "DESC"

        CTRL_HEX_NUM = "(" \
        " (instr('0123456789ABCDEF', upper(substr(Controller,1,1))) - 1)*16 +" \
        " (instr('0123456789ABCDEF', upper(substr(Controller,2,1))) - 1) " \
        ")"

        text_cols = {
            "Channel_Name": "Channel_Name COLLATE NOCASE",
            "Display_Name": "Display_Name COLLATE NOCASE",
            "Network":      "Network COLLATE NOCASE",
            "Source":       "Source COLLATE NOCASE",
            "ConnectionType":"ConnectionType COLLATE NOCASE",
            "DeviceType":   "DeviceType COLLATE NOCASE",
            "LORTag":       "LORTag COLLATE NOCASE",
        }
        int_cols = {
            "Controller":   CTRL_HEX_NUM,  # hex-aware
            "StartChannel": "CAST(StartChannel AS INTEGER)",
        }

        primary = text_cols.get(col) or int_cols.get(col) or "Display_Name COLLATE NOCASE"

        # Stabilize: Controller (hex) → StartChannel → Display_Name
        if col == "Controller":
            primary = CTRL_HEX_NUM
            dirn = "ASC"
        elif col == "StartChannel":
            primary = "CAST(StartChannel AS INTEGER)"

        return (
            f"{primary} {dirn}, "
            f"{CTRL_HEX_NUM} ASC, "
            "CAST(StartChannel AS INTEGER) ASC, "
            "Display_Name COLLATE NOCASE ASC"
        )


    def _safe_export_name(self, preview_name: str | None, suffix: str) -> str:
        """
        Build a filesystem-safe default export name using the current preview.
        Examples:
            Preview 'Stage 07 – Whoville (Background)' + 'wiring.csv'
            -> 'Stage_07_Whoville_Background_wiring.csv'
        """
        import re
        base = (preview_name or "").strip() or "Preview"
        base = re.sub(r"[^A-Za-z0-9._-]+", "_", base)  # squash weird chars/spaces
        base = re.sub(r"_+", "_", base).strip("_") or "Preview"
        return f"{base}_{suffix}"
            

    def refresh_rows(self, *_):
        self.clear_rows()
        if not self.conn: return
        preview = (self.preview_var.get() or "").strip()
        if not preview: return
        try:
            filters = []
            if self.props_only.get():
                filters.append("Source = 'PROP'")
            if self.hide_spares.get():
                filters.append("UPPER(Display_Name) NOT LIKE '%SPARE%'")
                filters.append("UPPER(Channel_Name) NOT LIKE '%SPARE%'")
            extra_filters = (" AND " + " AND ".join(filters)) if filters else ""

            field_mode_ok = self._view_exists("lead")
            if self.field_mode.get() and field_mode_ok:
                sql = SQL_FIELDLEAD.format(extra_filters=extra_filters, order_by=self._order_by_clause())
            else:
                sql = SQL_MAP.format(extra_filters=extra_filters, order_by=self._order_by_clause())

            # --- GAL 25-10-28: streamlined wiring columns for field clarity ---
            rows = self.conn.execute(sql, (preview,)).fetchall()
            for row in rows:
                self.tree.insert("", "end", values=list(row))
            self.count_var.set(f"Rows: {len(rows)}")

            if self.field_mode.get() and not field_mode_ok:
                messagebox.showinfo(
                    "Field wiring views missing",
                    "This DB doesn't have the field wiring helpers yet.\n"
                    "Paste field_helpers.sql into parse_props_v6.py (inside create_wiring_views_v6) and rebuild the DB."
                )
        except sqlite3.OperationalError as e:
            messagebox.showwarning("Busy/Locked", f"{e}\n\nIf your import script is running, try again after it finishes.")
        except Exception as e:
            messagebox.showerror("Query Error", str(e))

    def on_sort(self, column_name: str):
        if column_name == self.sort_col:
            self.sort_asc = not self.sort_asc
        else:
            self.sort_col = column_name
            self.sort_asc = True
        self.refresh_rows()

    def export_csv(self):
        if not self.tree.get_children():
            messagebox.showinfo("Export", "Nothing to export."); return
        path = filedialog.asksaveasfilename(
            defaultextension=".csv",
            filetypes=[("CSV Files","*.csv"), ("All Files","*.*")],
            initialfile=self._safe_export_name(self.preview_var.get(), "wiring.csv"),
            title="Export CSV"
        )
        if not path: return
        try:
            headers = [c for c,_ in COLUMNS]
            with open(path, "w", newline="", encoding="utf-8") as f:
                writer = csv.writer(f); writer.writerow(headers)
                for iid in self.tree.get_children():
                    vals = self.tree.item(iid, "values")
                    writer.writerow(vals)
            messagebox.showinfo("Export", f"Saved: {path}")
        except Exception as e:
            messagebox.showerror("Export Error", str(e))

    # --- GAL 25-10-28: streamlined wiring columns for field clarity ---
    def export_printable_html(self):
        if not self.tree.get_children():
            messagebox.showinfo("Export", "Nothing to export.")
            return

        path = filedialog.asksaveasfilename(
            defaultextension=".html",
            filetypes=[("HTML Files","*.html"), ("All Files","*.*")],
            initialfile=self._safe_export_name(self.preview_var.get(), "wiring.html"),
            title="Export Printable HTML"
        )
        if not path:
            return

        import datetime, html, webbrowser, base64, mimetypes, os

        # --- GAL 25-10-28b: prefer on-screen path value for reliability ---
        preview_name = (self.preview_var.get() or "").strip()
        bg_path = (self.bg_path_var.get().strip() if hasattr(self, "bg_path_var") else "")

        # If empty, fall back to DB
        if (not bg_path) and self.conn and preview_name:
            try:
                row = self.conn.execute(
                    "SELECT BackgroundFile FROM previews WHERE Name = ?;", (preview_name,)
                ).fetchone()
                if row:
                    bg_path = (row[0] or "").strip()
            except Exception as e:
                print(f"[DEBUG] BackgroundFile lookup failed: {e}")

        # --- Build the image path line + embedded image (if file resolves) ---
        image_path_text = ""
        image_html = ""
        if bg_path:
            image_path_text = f"<p class='meta'>Image path: {html.escape(bg_path)}</p>"
            try:
                if os.path.exists(bg_path):
                    mime = mimetypes.guess_type(bg_path)[0] or "image/jpeg"
                    with open(bg_path, "rb") as f:
                        b64 = base64.b64encode(f.read()).decode("ascii")
                    data_uri = f"data:{mime};base64,{b64}"
                    image_html = (
                        f'<div style="margin:8px 0 14px 0;">'
                        f'<img src="{data_uri}" style="max-width:100%;height:auto;'
                        f'border:1px solid #ccc;border-radius:4px;">'
                        f'</div>'
                    )
            except Exception as e:
                print(f"[DEBUG] Image embed failed: {e}")

        # --- Collect grid data, then FILTER unwanted columns for export ---
        # Columns to hide in HTML:
        HIDE_FOR_EXPORT = {"LORTag", "ConnectionType", "CrossDisplay"}  # GAL 25-10-28b

        all_headers = [c for c, _ in COLUMNS]
        keep_idx = [i for i, h in enumerate(all_headers) if h not in HIDE_FOR_EXPORT]
        headers = [all_headers[i] for i in keep_idx]

        rows = []
        for iid in self.tree.get_children():
            vals = list(self.tree.item(iid, "values"))
            pruned = [html.escape(str(vals[i])) for i in keep_idx if i < len(vals)]
            rows.append(pruned)

        printed = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        preview = html.escape(preview_name)
        db_path = html.escape(self.db_path)

        css = """
        <style>
        body{
            font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif;
            margin:24px;
        }
        h1{
            margin:0 0 6px 0;
            font-size:20px;
        }
        .meta{
            font-size:12px;
            color:#555;
            margin:0 0 6px 0;
        }
        .warn{
            font-size:14px;               /* bigger and bolder than before */
            color:#c00;                   /* brighter red */
            margin:10px 0 12px 0;
            font-weight:700;
        }
        .dbpath{
            font-size:10px;               /* small, gray DB path */
            color:#777;
        }
        table{
            border-collapse:collapse;
            width:100%;
            font-size:12px;
        }
        th,td{
            border:1px solid #ccc;
            padding:6px 8px;
            vertical-align:top;
        }
        th{
            background:#f5f5f5;
            position:sticky;
            top:0;
        }
        tfoot td{
            border:none;
            color:#555;
            font-size:11px;
            padding-top:18px;
        }
        @media print {
            .noprint{display:none}
            th{position:sticky;top:0}
        }
        </style>
        """

        head = f"""
        <h1>MSB Field Wiring — {preview}</h1>
        <p class="warn">Printed: {printed} — Use immediately. Discard if not printed “today”.</p>
        {image_path_text}
        {image_html}
        """

        # --- GAL 25-10-31e [IMG_EXPORT_HTML_INSERT] -------------------------------
        # Insert discovered images (all pages) before the wiring grid.
        html_image_section = self._html_image_section()
        # ---------------------------------------------------------------------------


        thead = "<thead><tr>" + "".join(f"<th>{html.escape(h)}</th>" for h in headers) + "</tr></thead>"
        tbody = "<tbody>" + "".join(
            "<tr>" + "".join(f"<td>{v}</td>" for v in row) + "</tr>" for row in rows
        ) + "</tbody>"
 
        foot = f"""
        <tfoot><tr><td colspan="{len(headers)}">
        Rows: {len(rows)} • Database: <span class="dbpath">{db_path}</span><br>
        Guidance: paper copies expire as soon as a new database build or preview merge occurs.
        </td></tr></tfoot>
        """

        # --- GAL 25-11-01f [IMG_EXPORT_CONDITIONAL_SECTION] ------------------------
        extra_images_exist = (
            hasattr(self, "_image_pages") and
            len(self._image_pages) > 1
        )

        html_doc = (
            f"<!doctype html><meta charset='utf-8'><title>Wiring — {preview}</title>"
            f"{css}{head}"
            +
            (
                f"<h2>Additional Wiring Images</h2>{html_image_section}"
                if extra_images_exist else
                ""
            )
            +
            f"<table>{thead}{tbody}{foot}</table>"
        )
        # ---------------------------------------------------------------------------


        with open(path, "w", encoding="utf-8") as f:
            f.write(html_doc)

        import webbrowser, os
        webbrowser.open("file:///" + os.path.abspath(path).replace("\\", "/"))
        messagebox.showinfo("Export", f"Saved: {path}")

# === Combined main window with tabs (GAL 25-10-23) ===========================
# GAL 25-10-23 — minimal tabbed shell around WiringViewer (no class changes)
# === Combined main window with tabs (GAL 25-10-29, splash-enabled) ===========
if __name__ == "__main__":
    # Pick your DB path constant; fall back if not defined
    try:
        DB_PATH = DEFAULT_DB
    except NameError:
        DB_PATH = r"G:\Shared drives\MSB Database\database\lor_output_v6.db"

    # Build splash bits (use bundled, then exe folder, then shared path)
    icon_png = resource_path(os.path.join("Docs", "images", "formview.png"))
    if not os.path.exists(icon_png):
        icon_png = os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "formview.png")
    if not os.path.exists(icon_png):
        icon_png = r"G:\Shared drives\MSB Database\Apps\FormView\current\formview.png"

    subtitle = f"v{APP_VERSION} — {datetime.date.today():%Y-%m-%d}"

    # Start Tk and set icons BEFORE any toplevels (splash) are created
    root = tk.Tk()
    apply_window_icons(root)   # <-- GAL 25-10-28: critical for taskbar icon
    root.withdraw()

    # Splash window (created after icons are set)
    splash = Splash(root, icon_png, "MSB Database — FormView", subtitle)
    splash.update()  # paint now, before heavier init

    # close splash after ~900ms and show main window
    root.after(3000, splash.close)
    root.after(3000, root.deiconify)

    # Main UI
    root.geometry("1280x780")
    notebook = ttk.Notebook(root); notebook.pack(fill=tk.BOTH, expand=True)

    # Tab 1: Wiring
    wiring_tab = WiringViewer(notebook, db_path=DB_PATH)
    notebook.add(wiring_tab, text="Wiring View")

    # Tab 2: Stage View
    REPORTS_ROOT = Path(r"G:\Shared drives\MSB Database\Database Previews\reports")
    stage_tab = StageViewFrame(notebook, db_path=DB_PATH, reports_root=REPORTS_ROOT)
    notebook.add(stage_tab, text="Stage View")

    root.title(f"MSB Database — Wiring & Stage Tools (v{APP_VERSION})")

    # Optional legacy fallback; apply_window_icons already did this
    try:
        root.iconbitmap(os.path.join(os.path.dirname(__file__), "Docs", "images", "formview.ico"))
    except Exception:
        pass

    root.mainloop()



# ============================================================================


