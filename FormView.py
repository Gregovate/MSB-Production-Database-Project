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
#
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

DEFAULT_DB = r"G:\Shared drives\MSB Database\database\lor_output_v6.db"

# Superset of columns used by both views; extra columns are filled when present
COLUMNS = [
    ("Source",         90),
    ("Channel_Name",  260),
    ("Display_Name",  260),
    ("Network",        90),
    ("Controller",     90),
    ("StartChannel",  110),
    ("EndChannel",    100),
    ("Color",          80),
    ("DeviceType",     90),
    ("LORTag",        300),
    ("ConnectionType",110),  # only present in field views
    ("CrossDisplay",  110),  # only present in field views
]

SQL_PREVIEWS = "SELECT Name FROM previews ORDER BY Name COLLATE NOCASE;"

SQL_VIEW_CHECKS = {
    "map":      "SELECT name FROM sqlite_master WHERE type='view' AND name='preview_wiring_map_v6';",
    "fieldmap": "SELECT name FROM sqlite_master WHERE type='view' AND name='preview_wiring_fieldmap_v6';",
    "lead":     "SELECT name FROM sqlite_master WHERE type='view' AND name='preview_wiring_fieldlead_v6';",
    "fieldonly":"SELECT name FROM sqlite_master WHERE type='view' AND name='preview_wiring_fieldonly_v6';",
}

SQL_MAP = """
SELECT
  Source, LORName AS Channel_Name, DisplayName AS Display_Name,
  Network, Controller, StartChannel, EndChannel, NULL AS Color, DeviceType, LORTag,
  '' AS ConnectionType, 0 AS CrossDisplay
FROM preview_wiring_sorted_v6
WHERE PreviewName = ?
{extra_filters}
ORDER BY {order_by};
"""

# Field wiring mode: show exactly one FIELD row per display per circuit within the selected stage/preview
SQL_FIELDLEAD = """
SELECT
  Source, Channel_Name, Display_Name,
  Network, Controller, StartChannel, EndChannel, Color, DeviceType, LORTag,
  ConnectionType, CrossDisplay
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

class WiringViewer(tk.Tk):
    def __init__(self, db_path=DEFAULT_DB):
        super().__init__()
        self.title("Wiring Viewer (v6) v0.2.0 — Field wiring mode")
        self.geometry("1280x780")
        self.db_path = db_path
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
        self.preview_cbo.bind("<<ComboboxSelected>>", lambda e: self.refresh_rows())

        ttk.Button(top, text="Refresh", command=self.refresh_rows).pack(side=tk.LEFT, padx=(0,6))
        ttk.Button(top, text="Export CSV…", command=self.export_csv).pack(side=tk.LEFT)
        ttk.Button(top, text="Export Printable…", command=self.export_printable_html).pack(side=tk.LEFT, padx=(6,0))


        # Filters
        filt = ttk.Frame(self, padding=(6,0,6,6)); filt.pack(side=tk.TOP, fill=tk.X)

        self.field_mode = tk.BooleanVar(value=True)
        ttk.Checkbutton(
            filt, text="Field wiring mode (one lead per display/circuit)", variable=self.field_mode,
            command=self.refresh_rows
        ).pack(side=tk.LEFT, padx=(0,12))

        self.props_only = tk.BooleanVar(value=False)
        ttk.Checkbutton(
            filt, text="Props only", variable=self.props_only, command=self.refresh_rows
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
            self.after(50, self.refresh_rows)
        except Exception as e:
            messagebox.showerror("Query Error", str(e))

    # ------------------------ UI actions ------------------------
    def clear_rows(self):
        for iid in self.tree.get_children():
            self.tree.delete(iid)
        self.count_var.set("Rows: 0")

    def _order_by_clause(self):
        col = self.sort_col
        dirn = "ASC" if self.sort_asc else "DESC"

        CTRL_HEX_NUM = "(" \
        " (instr('0123456789ABCDEF', upper(substr(Controller,1,1))) - 1)*16 +" \
        " (instr('0123456789ABCDEF', upper(substr(Controller,2,1))) - 1) " \
        ")"

        text_cols = {
            "Source": "Source COLLATE NOCASE",
            "Channel_Name": "Channel_Name COLLATE NOCASE",
            "Display_Name": "Display_Name COLLATE NOCASE",
            "Network": "Network COLLATE NOCASE",
            "Color": "Color COLLATE NOCASE",
            "DeviceType": "DeviceType COLLATE NOCASE",
            "LORTag": "LORTag COLLATE NOCASE",
            "ConnectionType": "ConnectionType COLLATE NOCASE",
        }
        int_cols = {
            "Controller": CTRL_HEX_NUM,  # 👈 hex-aware numeric sort
            "StartChannel": "CAST(StartChannel AS INTEGER)",
            "EndChannel": "CAST(EndChannel AS INTEGER)",
            "CrossDisplay": "CAST(CrossDisplay AS INTEGER)",
        }

        primary = text_cols.get(col) or int_cols.get(col) or "Display_Name COLLATE NOCASE"

        # Always stabilize sorting: controller (hex) → channel → display name
        # GAL 2025-10-23 — default to Controller+StartChannel for field wiring
        if col in int_cols or col == "Controller":
            primary = CTRL_HEX_NUM
            dirn = "ASC"  # always ascending for controller hex
        elif col == "StartChannel":
            primary = "CAST(StartChannel AS INTEGER)"
        else:
            primary = text_cols.get(col) or "Display_Name COLLATE NOCASE"

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

            rows = self.conn.execute(sql, (preview,)).fetchall()
            for row in rows:
                vals = list(row)
                if len(vals) == 10:
                    vals += ["", 0]
                self.tree.insert("", "end", values=vals)
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

    # GAL 2025-10-23 — Export printable HTML
    # GAL 2025-10-23 — Export printable HTML (trim EndChannel + Color)
    # GAL 2025-10-23 — Export printable HTML (trim EndChannel + Color + add Preview Image)
    # GAL 2025-10-23 — Export printable HTML
    # - omits EndChannel + Color
    # - embeds preview image from previews.PicturePath (base64) if the file exists
    # GAL 2025-10-23 — Export printable HTML
    # Omits EndChannel + Color; embeds preview image from previews.PicturePath
    # GAL 2025-10-23 — Export printable HTML
    # Uses previews.BackgroundFile for stage image, omits EndChannel + Color
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

        preview_name = (self.preview_var.get() or "").strip()
        image_html = ""

        # ---- Pull BackgroundFile path from DB and embed if it exists ----
        if self.conn and preview_name:
            try:
                row = self.conn.execute(
                    "SELECT BackgroundFile FROM previews WHERE Name = ?;", (preview_name,)
                ).fetchone()
                if row:
                    bg_path = (row[0] or "").strip()
                    print(f"[DEBUG] BackgroundFile path: {bg_path}")
                    if bg_path and os.path.exists(bg_path):
                        mime = mimetypes.guess_type(bg_path)[0] or "image/jpeg"
                        with open(bg_path, "rb") as f:
                            b64 = base64.b64encode(f.read()).decode("ascii")
                        data_uri = f"data:{mime};base64,{b64}"
                        image_html = (
                            f'<div style="margin:12px 0;">'
                            f'<img src="{data_uri}" '
                            f'style="max-width:100%;height:auto;border:1px solid #ccc;border-radius:4px;">'
                            f'</div>'
                        )
                    else:
                        print(f"[DEBUG] BackgroundFile not found: {bg_path}")
            except Exception as e:
                print(f"[DEBUG] Error loading BackgroundFile: {e}")
                image_html = ""

        # ---- Build table, skipping EndChannel + Color ----
        exclude_cols = {"EndChannel", "Color"}
        all_headers = [c for c, _ in COLUMNS]
        headers = [h for h in all_headers if h not in exclude_cols]
        keep_idx = [i for i, h in enumerate(all_headers) if h not in exclude_cols]

        rows = []
        for iid in self.tree.get_children():
            vals = self.tree.item(iid, "values")
            rows.append([html.escape(str(vals[i])) for i in keep_idx])

        printed = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        preview = html.escape(preview_name)
        db_path = html.escape(self.db_path)

        css = """
        <style>
          body{font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif;margin:24px;}
          h1{margin:0 0 6px 0;font-size:20px}
          .meta{font-size:12px;color:#555;margin:0 0 12px 0}
          .warn{font-size:12px;color:#a00;margin:6px 0 12px 0;font-weight:600}
          table{border-collapse:collapse;width:100%;font-size:12px}
          th,td{border:1px solid #ccc;padding:6px 8px;vertical-align:top}
          th{background:#f5f5f5;position:sticky;top:0}
          tfoot td{border:none;color:#555;font-size:11px;padding-top:18px}
          @media print { .noprint{display:none} th{position:sticky;top:0} }
        </style>
        """
        head = f"""
        <h1>MSB Field Wiring — {preview}</h1>
        <p class="meta">DB: {db_path}</p>
        {image_html}
        <p class="warn">Printed: {printed} — Use immediately. Discard if not printed “today”.</p>
        """

        thead = "<thead><tr>" + "".join(f"<th>{html.escape(h)}</th>" for h in headers) + "</tr></thead>"
        tbody = "<tbody>" + "".join(
            "<tr>" + "".join(f"<td>{v}</td>" for v in row) + "</tr>" for row in rows
        ) + "</tbody>"
        foot = f"""
        <tfoot><tr><td colspan="{len(headers)}">
          Rows: {len(rows)} • Printed: {printed}
          • Guidance: paper copies expire as soon as a new database build or preview merge occurs.
        </td></tr></tfoot>
        """

        html_doc = (
            f"<!doctype html><meta charset='utf-8'><title>Wiring — {preview}</title>"
            f"{css}{head}<table>{thead}{tbody}{foot}</table>"
        )
        with open(path, "w", encoding="utf-8") as f:
            f.write(html_doc)

        webbrowser.open("file:///" + os.path.abspath(path).replace("\\", "/"))
        messagebox.showinfo("Export", f"Saved: {path}")



if __name__ == "__main__":
    app = WiringViewer(DEFAULT_DB)
    app.mainloop()
