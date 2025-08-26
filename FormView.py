# wiring_form.py (no PreviewName column in the grid)
import sqlite3, csv, os, sys, urllib.parse
import tkinter as tk
from tkinter import ttk, filedialog, messagebox

# Your default DB path
DEFAULT_DB = r"G:\Shared drives\MSB Database\database\lor_output_v6.db"

# Columns to show in the table (no PreviewName)
COLUMNS = [
    ("Source",         90),
    ("Channel_Name",  260),
    ("Display_Name",  260),
    ("Suggested_Name",280),
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
SQL_WIRING = """
SELECT
  Source, Channel_Name, Display_Name, Suggested_Name,
  Network, Controller, StartChannel, EndChannel, Color, DeviceType, LORTag
FROM preview_wiring_map_v6
WHERE PreviewName = ?
ORDER BY PreviewName COLLATE NOCASE, Network COLLATE NOCASE, Controller, StartChannel;
"""

def connect_ro(db_path):
    """Open SQLite read-only, robust to Windows paths/spaces."""
    try:
        p = os.path.abspath(db_path).replace("\\", "/")
        uri_path = urllib.parse.quote(p)
        # file:///G:/path... works cross-platform enough for Windows drive paths
        return sqlite3.connect(f"file:///{uri_path}?mode=ro&immutable=0", uri=True, timeout=5.0)
    except Exception:
        # Fallback writable open if URI fails
        return sqlite3.connect(db_path, timeout=5.0)

class WiringViewer(tk.Tk):
    def __init__(self, db_path=DEFAULT_DB):
        super().__init__()
        self.title("Wiring Viewer (v6)")
        self.geometry("1200x700")
        self.db_path = db_path
        self.conn = None

        # Top bar
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
        self.preview_cbo.bind("<<ComboboxSelected>>", lambda e: self.refresh_rows())

        ttk.Button(top, text="Refresh",    command=self.refresh_rows).pack(side=tk.LEFT, padx=(0,6))
        ttk.Button(top, text="Export CSV…", command=self.export_csv).pack(side=tk.LEFT)

        self.count_var = tk.StringVar(value="Rows: 0")
        ttk.Label(top, textvariable=self.count_var).pack(side=tk.RIGHT)

        # Table (Treeview)
        self.tree = ttk.Treeview(self, columns=[c for c,_ in COLUMNS], show="headings")
        self.tree.pack(side=tk.TOP, fill=tk.BOTH, expand=True)
        for col, width in COLUMNS:
            self.tree.heading(col, text=col)
            self.tree.column(col, width=width, anchor=tk.W, stretch=True)

        # Scrollbars
        ysb = ttk.Scrollbar(self, orient="vertical",   command=self.tree.yview)
        xsb = ttk.Scrollbar(self, orient="horizontal", command=self.tree.xview)
        self.tree.configure(yscroll=ysb.set, xscroll=xsb.set)
        ysb.pack(side=tk.RIGHT, fill=tk.Y)
        xsb.pack(side=tk.BOTTOM, fill=tk.X)

        # Init
        self.safe_connect()
        self.load_previews()

    def safe_connect(self):
        if self.conn:
            try: self.conn.close()
            except: pass
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

    def load_previews(self):
        self.preview_cbo["values"] = []
        if not self.conn: return
        try:
            cur = self.conn.execute(SQL_VIEW_EXISTS)
            if cur.fetchone() is None:
                messagebox.showwarning(
                    "View missing",
                    "preview_wiring_map_v6 not found.\nRun your script to create wiring views before using this tool."
                )
                return
            cur = self.conn.execute(SQL_PREVIEWS)
            names = [row[0] for row in cur.fetchall()]
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

    def clear_rows(self):
        for iid in self.tree.get_children():
            self.tree.delete(iid)
        self.count_var.set("Rows: 0")

    def refresh_rows(self):
        self.clear_rows()
        if not self.conn: return
        preview = self.preview_var.get()
        if not preview: return
        try:
            cur = self.conn.execute(SQL_WIRING, (preview,))
            rows = cur.fetchall()
            for row in rows:
                self.tree.insert("", "end", values=row)
            self.count_var.set(f"Rows: {len(rows)}")
        except sqlite3.OperationalError as e:
            messagebox.showwarning("Busy/Locked", f"{e}\n\nIf your import script is running, try again after it finishes.")
        except Exception as e:
            messagebox.showerror("Query Error", str(e))

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
        if not path: return
        try:
            with open(path, "w", newline="", encoding="utf-8") as f:
                writer = csv.writer(f)
                headers = [c for c,_ in COLUMNS]
                writer.writerow(headers)
                for iid in self.tree.get_children():
                    writer.writerow(self.tree.item(iid, "values"))
            messagebox.showinfo("Export", f"Saved: {path}")
        except Exception as e:
            messagebox.showerror("Export Error", str(e))

if __name__ == "__main__":
    app = WiringViewer(DEFAULT_DB)
    app.mainloop()
