# Wiring Viewer (v6) – MSB Database
# Initial Release: 2025-08-28 V0.1.3
# Written by: Greg Liebig, Engineering Innovations, LLC.
#
# Description:
#   Tkinter GUI to inspect preview_wiring_map_v6 data from lor_output_v6.db.
#   Features:
#     • Toggle: Props only
#     • Toggle: Hide SPAREs
#     • Clickable column headers for sort
#     • CSV export of visible data
#
# Revision History:
#   2025-08-28  V0.1.0  Added Hide SPAREs toggle, sortable columns,
#                       Suggested column toggle.
#   2025-10-15  V0.1.4  Removed "Show Suggested" checkbox and all Suggested_Name column logic.
#                       Simplified columns and SQL accordingly.

# Wiring Viewer (v6) – MSB Database (Field wiring aware) 25-10-15
# V0.2.0 — Add "Field wiring mode" for per-stage field leads (no internals)
# Author: Greg Liebig, Engineering Innovations, LLC.

import sqlite3, csv, os, urllib.parse
import tkinter as tk
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

        self.sort_col = "Display_Name"
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
        self.preview_cbo.bind("<<ComboboxSelected>>", self.refresh_rows)

        ttk.Button(top, text="Refresh", command=self.refresh_rows).pack(side=tk.LEFT, padx=(0,6))
        ttk.Button(top, text="Export CSV…", command=self.export_csv).pack(side=tk.LEFT)

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

        # Always stabilize with controller(hex numeric) → channel → name
        return (
            f"{primary} {dirn}, "
            f"{CTRL_HEX_NUM} ASC, "
            "CAST(StartChannel AS INTEGER) ASC, "
            "Display_Name COLLATE NOCASE ASC"
        )



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
            initialfile="wiring_export.csv",
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

if __name__ == "__main__":
    app = WiringViewer(DEFAULT_DB)
    app.mainloop()
