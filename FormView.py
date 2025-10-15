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

import sqlite3, csv, os, urllib.parse
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

# Default DB path
DEFAULT_DB = r"G:\Shared drives\MSB Database\database\lor_output_v6.db"

# Columns to show in the table (no PreviewName)
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
]

SQL_PREVIEWS = "SELECT Name FROM previews ORDER BY Name COLLATE NOCASE;"

SQL_VIEW_EXISTS = """
SELECT name FROM sqlite_master
WHERE type IN ('view','table') AND name='preview_wiring_map_v6';
"""

# We still filter by PreviewName, but we don't display it
SQL_WIRING_BASE = """
SELECT
  Source, Channel_Name, Display_Name,
  Network, Controller, StartChannel, EndChannel, Color, DeviceType, LORTag
FROM preview_wiring_map_v6
WHERE PreviewName = ?
{extra_filters}
ORDER BY {order_by};
"""

def connect_ro(db_path: str) -> sqlite3.Connection:
    """Open SQLite read-only (URI). Fall back to normal open if needed."""
    p = os.path.abspath(db_path).replace("\\", "/")
    uri_path = urllib.parse.quote(p)
    try:
        # immutable=0 so you can open while another writer updates
        return sqlite3.connect(f"file:///{uri_path}?mode=ro&immutable=0", uri=True, timeout=5.0)
    except Exception:
        return sqlite3.connect(db_path, timeout=5.0)

class WiringViewer(tk.Tk):
    def __init__(self, db_path=DEFAULT_DB):
        super().__init__()
        self.title("Wiring Viewer (v6) v0.1.4")
        self.geometry("1200x740")
        self.db_path = db_path
        self.conn: sqlite3.Connection | None = None

        # current sort
        self.sort_col = "Display_Name"
        self.sort_asc = True

        # --- Top bar
        top = ttk.Frame(self, padding=6)
        top.pack(side=tk.TOP, fill=tk.X)

        self.db_label_var = tk.StringVar(value=os.path.abspath(self.db_path))
        ttk.Label(top, text="DB:").pack(side=tk.LEFT)
        ttk.Entry(top, textvariable=self.db_label_var, width=60, state="readonly").pack(side=tk.LEFT, padx=(2,6))
        ttk.Button(top, text="Choose DB…", command=self.choose_db).pack(side=tk.LEFT, padx=(0,10))

        ttk.Label(top, text="Preview:").pack(side=tk.LEFT)
        self.preview_var = tk.StringVar()
        self.preview_cbo = ttk.Combobox(top, textvariable=self.preview_var, width=55, state="readonly")
        self.preview_cbo.pack(side=tk.LEFT, padx=(2,6))
        self.preview_cbo.bind("<<ComboboxSelected>>", self.refresh_rows)

        ttk.Button(top, text="Refresh", command=self.refresh_rows).pack(side=tk.LEFT, padx=(0,6))
        ttk.Button(top, text="Export CSV…", command=self.export_csv).pack(side=tk.LEFT)

        # Filters
        filt = ttk.Frame(self, padding=(6,0,6,6))
        filt.pack(side=tk.TOP, fill=tk.X)

        self.props_only = tk.BooleanVar(value=False)
        ttk.Checkbutton(
            filt, text="Props only", variable=self.props_only, command=self.refresh_rows
        ).pack(side=tk.LEFT, padx=(0,12))

        self.hide_spares = tk.BooleanVar(value=False)
        ttk.Checkbutton(
            filt, text="Hide SPAREs", variable=self.hide_spares, command=self.refresh_rows,
            takefocus=False
        ).pack(side=tk.LEFT, padx=(0,12))

        self.count_var = tk.StringVar(value="Rows: 0")
        ttk.Label(filt, textvariable=self.count_var).pack(side=tk.RIGHT)

        # --- Table
        self.tree = ttk.Treeview(self, columns=[c for c,_ in COLUMNS], show="headings")
        self.tree.pack(side=tk.TOP, fill=tk.BOTH, expand=True)

        # headings with click-to-sort
        for col, width in COLUMNS:
            self.tree.heading(col, text=col, command=lambda c=col: self.on_sort(c))
            self.tree.column(col, width=width, anchor=tk.W, stretch=True)

        # Scrollbars
        ysb = ttk.Scrollbar(self, orient="vertical",   command=self.tree.yview)
        xsb = ttk.Scrollbar(self, orient="horizontal", command=self.tree.xview)
        self.tree.configure(yscroll=ysb.set, xscroll=xsb.set)
        ysb.pack(side=tk.RIGHT, fill=tk.Y)
        xsb.pack(side=tk.BOTTOM, fill=tk.X)

        # Init DB + data
        self.safe_connect()
        self.load_previews()

    # ------------------------ DB helpers ------------------------
    def safe_connect(self):
        if self.conn:
            try:
                self.conn.close()
            except Exception:
                pass
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
        if not path:
            return
        self.db_path = path
        self.db_label_var.set(os.path.abspath(path))
        self.safe_connect()
        self.load_previews()

    def load_previews(self):
        self.preview_cbo["values"] = []
        if not self.conn:
            return
        try:
            if self.conn.execute(SQL_VIEW_EXISTS).fetchone() is None:
                messagebox.showwarning(
                    "View missing",
                    "preview_wiring_map_v6 not found.\nRun your import script to create wiring views before using this tool."
                )
                return
            names = [r[0] for r in self.conn.execute(SQL_PREVIEWS).fetchall()]
            self.preview_cbo["values"] = names
            if names:
                if self.preview_var.get() not in names:
                    self.preview_var.set(names[0])
                self.after(50, self.refresh_rows)
            else:
                self.preview_var.set("")
                self.clear_rows()
        except Exception as e:
            messagebox.showerror("Query Error", str(e))

    # ------------------------ UI actions ------------------------
    def clear_rows(self):
        for iid in self.tree.get_children():
            self.tree.delete(iid)
        self.count_var.set("Rows: 0")

    def _order_by_clause(self):
        # Map visible column → SQL expression with type-aware sorting
        col = self.sort_col
        dirn = "ASC" if self.sort_asc else "DESC"

        text_cols = {
            "Source": "Source COLLATE NOCASE",
            "Channel_Name": "Channel_Name COLLATE NOCASE",
            "Display_Name": "Display_Name COLLATE NOCASE",
            "Network": "Network COLLATE NOCASE",
            "Color": "Color COLLATE NOCASE",
            "DeviceType": "DeviceType COLLATE NOCASE",
            "LORTag": "LORTag COLLATE NOCASE",
        }
        int_cols = {"Controller": "CAST(Controller AS INTEGER)",
                    "StartChannel": "CAST(StartChannel AS INTEGER)",
                    "EndChannel": "CAST(EndChannel AS INTEGER)"}

        if col in text_cols:
            primary = text_cols[col]
        else:
            primary = int_cols.get(col, "Display_Name COLLATE NOCASE")

        # Add secondary keys for stable sort
        return f"{primary} {dirn}, Network COLLATE NOCASE, Controller, StartChannel"

    def refresh_rows(self, *_):
        self.clear_rows()
        if not self.conn:
            return
        preview = (self.preview_var.get() or "").strip()
        if not preview:
            return
        try:
            filters = []
            if self.props_only.get():
                filters.append("Source = 'PROP'")
            if self.hide_spares.get():
                # Suppress rows whose Channel_Name or Display_Name contains 'SPARE' (case-insensitive)
                filters.append("UPPER(Display_Name) NOT LIKE '%SPARE%'")
                filters.append("UPPER(Channel_Name) NOT LIKE '%SPARE%'")

            extra_filters = ""
            if filters:
                extra_filters = " AND " + " AND ".join(filters)

            sql = SQL_WIRING_BASE.format(
                extra_filters=extra_filters,
                order_by=self._order_by_clause()
            )
            rows = self.conn.execute(sql, (preview,)).fetchall()
            for row in rows:
                self.tree.insert("", "end", values=row)
            self.count_var.set(f"Rows: {len(rows)}")
        except sqlite3.OperationalError as e:
            messagebox.showwarning(
                "Busy/Locked",
                f"{e}\n\nIf your import script is running, try again after it finishes."
            )
        except Exception as e:
            messagebox.showerror("Query Error", str(e))

    def on_sort(self, column_name: str):
        # toggle if same col, otherwise set new col asc
        if column_name == self.sort_col:
            self.sort_asc = not self.sort_asc
        else:
            self.sort_col = column_name
            self.sort_asc = True
        self.refresh_rows()

    def export_csv(self):
        if not self.tree.get_children():
            messagebox.showinfo("Export", "Nothing to export.")
            return
        path = filedialog.asksaveasfilename(
            defaultextension=".csv",
            filetypes=[("CSV Files","*.csv"), ("All Files","*.*")],
            initialfile="wiring_export.csv",
            title="Export CSV"
        )
        if not path:
            return
        try:
            # Export all visible columns (same as defined COLUMNS since we no longer toggle columns)
            headers = [c for c,_ in COLUMNS]
            with open(path, "w", newline="", encoding="utf-8") as f:
                writer = csv.writer(f)
                writer.writerow(headers)
                for iid in self.tree.get_children():
                    vals = self.tree.item(iid, "values")
                    writer.writerow(vals)
            messagebox.showinfo("Export", f"Saved: {path}")
        except Exception as e:
            messagebox.showerror("Export Error", str(e))

if __name__ == "__main__":
    app = WiringViewer(DEFAULT_DB)
    app.mainloop()
