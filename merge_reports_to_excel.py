#!/usr/bin/env python3
"""
merge_reports_to_excel.py
--------------------------------
Baseline, self-contained script to combine merger CSVs into a single Excel file
with multiple tabs, frozen headers, filters, auto-width, and simple coloring.

Usage (Windows PowerShell):
    python merge_reports_to_excel.py

Dependencies:
    pip install pandas openpyxl
"""

from pathlib import Path
from datetime import datetime
import warnings
import pandas as pd
import getpass
import platform
import argparse

from pandas.errors import ParserWarning
from openpyxl.formatting.rule import FormulaRule
from openpyxl.styles import PatternFill

# Silence noisy CSV parser warnings (optional)
warnings.simplefilter("ignore", ParserWarning)

# ================== CONFIG ==================
import argparse
from pathlib import Path
from datetime import datetime

parser = argparse.ArgumentParser(description="Merge CSV reports to a single Excel.")
parser.add_argument(
    "--root",
    default=r"G:\Shared drives\MSB Database\database\merger\reports",  # CSV input folder
    help="Folder containing the input CSVs (compare, ledger, etc.).",
)
parser.add_argument(
    "-o", "--out",
    default=r"G:\Shared drives\MSB Database\Database Previews",        # Excel output folder
    help="Folder to write the Excel into.",
)
args = parser.parse_args()

ROOT = Path(args.root)                 # where CSVs are read from
OUT_DIR = Path(args.out)               # where Excel is written
OUT_DIR.mkdir(parents=True, exist_ok=True)

# Which CSVs → which sheet names
FILES = [
    ("lorprev_compare.csv", "Compare"),
    ("lorprev_missing_comments.csv", "Missing_Comments"),
    ("lorprev_all_staged_comments.csv", "All_Staged_Comments"),
    ("excluded_winners.csv", "Excluded_Winners"),
    ("applied_this_run.csv", "Applied_This_Run"),
    ("apply_events.csv", "Apply_Events"),
    ("current_previews_ledger.csv", "Current_Previews_Ledger"),
]

STAMP = datetime.now().strftime("%Y%m%d-%H%M")
OUT_XLSX_STAMPED = OUT_DIR / f"lorprev_reports-{STAMP}.xlsx"
OUT_XLSX_FIXED   = OUT_DIR / "lorprev_reports.xlsx"

print(f"[cfg] CSV root: {ROOT}")
print(f"[cfg] Excel out: {OUT_DIR}")
# ============================================





def read_csv_safe(path: Path) -> pd.DataFrame:
    """
    Simple robust CSV reader:
    - UTF-8 with BOM support
    - engine='python' with delimiter sniffing (sep=None)
    - on_bad_lines='skip' to avoid fatal parse errors
    """
    if not path.exists():
        return pd.DataFrame()
    return pd.read_csv(
        path,
        dtype=str,
        keep_default_na=False,
        encoding="utf-8-sig",
        sep=None,            # auto-detect delimiter
        engine="python",
        on_bad_lines="skip", # skip malformed rows instead of crashing
        quoting=0            # QUOTE_MINIMAL
    )

def autosize_and_filter(ws):
    """Freeze header, add autofilter, and auto-fit columns (capped width)."""
    ws.freeze_panes = "A2"
    if ws.max_row >= 1 and ws.max_column >= 1:
        ws.auto_filter.ref = ws.dimensions
    for col in ws.columns:
        col_letter = col[0].column_letter
        max_len = 0
        for cell in col:
            val = "" if cell.value is None else str(cell.value)
            if len(val) > max_len:
                max_len = len(val)
        ws.column_dimensions[col_letter].width = min(max(10, max_len + 2), 80)

def _choose_action_like_column(ws, header_row=1):
    """Return (column_letter, header_text) most suitable for status/action coloring."""
    headers = [(cell.column_letter, str(cell.value).strip())
               for cell in ws[header_row] if cell.value]
    # Normalize + exclude obvious date/time columns
    norm = [(col, txt, txt.lower()) for col, txt in headers]
    candidates = [(c, t, tl) for c, t, tl in norm if "date" not in tl and "time" not in tl]

    # Priority headers to prefer
    priority = ("status", "action", "result", "decision", "outcome", "operation")

    # Quick content score based on expected keywords
    green_terms  = ("applied", "update-staging", "allow", "allowed", "pass", "passed")
    red_terms    = ("blocked", "error", "fail", "failed", "exclude", "excluded", "work needed")
    gray_terms   = ("skip", "identical", "no-op", "not needed", "unchanged")
    yellow_terms = ("ready to apply",)

    def score_col(letter):
        hits = 0
        max_row = min(ws.max_row, 400)
        for r in range(2, max_row + 1):
            v = ws[f"{letter}{r}"].value
            if not v:
                continue
            s = str(v).lower()
            if any(t in s for t in green_terms + red_terms + gray_terms + yellow_terms):
                hits += 1
        return hits

    # Prefer priority headers if present
    for key in priority:
        for col, txt, tl in candidates:
            if key in tl:
                return col, txt

    # Otherwise, choose the column whose cells look most like status/action
    scored = [(score_col(col), col, txt) for col, txt, _ in candidates]
    if scored:
        scored.sort(reverse=True)
        if scored[0][0] > 0:
            return scored[0][1], scored[0][2]

    return None, None


def add_action_colors(ws, header_row=1):
    """Apply conditional colors to the most action/status-like column on this sheet."""
    from openpyxl.formatting.rule import FormulaRule
    from openpyxl.styles import PatternFill

    col_letter, header_text = _choose_action_like_column(ws, header_row=header_row)
    if not col_letter or ws.max_row <= header_row:
        return

    rng = f"${col_letter}${header_row+1}:${col_letter}${ws.max_row}"
    top_left = f"{col_letter}{header_row+1}"  # e.g., D2 (row-relative)

    def any_of(cell_ref, terms):
        parts = [f'ISNUMBER(SEARCH("{t}",{cell_ref}))' for t in terms]
        return f"OR({','.join(parts)})"

    # Rules
    green  = any_of(top_left, ("applied", "update-staging", "allow", "allowed", "pass", "passed"))
    yellow = any_of(top_left, ("ready to apply",))
    red    = any_of(top_left, ("blocked", "error", "fail", "failed", "exclude", "excluded", "work needed"))
    gray   = any_of(top_left, ("skip", "identical", "no-op", "not needed", "unchanged"))

    for formula, color in (
        (green,  "C6EFCE"),   # light green
        (yellow, "FFF2CC"),   # light yellow
        (red,    "FFC7CE"),   # light red
        (gray,   "E7E6E6"),   # light gray
    ):
        ws.conditional_formatting.add(
            rng,
            FormulaRule(
                formula=[formula],
                fill=PatternFill(start_color=color, end_color=color, fill_type="solid"),
            ),
        )

    # Optional: keep this if you like the console hint
    print(f"[format] {ws.title}: using '{header_text}' column for color rules")

def add_missing_comments_colors(ws, header_row=1):
    """
    Highlight status-like columns in Missing_Comments:
    - Red if cell contains: needs / missing / blocked
    - Green if cell contains: ok / clean / complete
    Candidate columns: headers containing status/need/missing/reason/comment
    """
    # Identify candidate columns by header keywords
    status_cols = []
    for cell in ws[header_row]:
        if not cell.value:
            continue
        name = str(cell.value).strip().lower()
        if any(key in name for key in ("status", "need", "missing", "reason", "comment")):
            status_cols.append(cell.column_letter)

    if not status_cols or ws.max_row <= header_row:
        return

    last = ws.max_row
    for col_letter in status_cols:
        rng = f"${col_letter}${header_row+1}:${col_letter}${last}"
        # Red for needs/missing/blocked
        ws.conditional_formatting.add(
            rng,
            FormulaRule(
                formula=[f'OR(ISNUMBER(SEARCH("needs",$${col_letter}{header_row+1})),ISNUMBER(SEARCH("missing",$${col_letter}{header_row+1})),ISNUMBER(SEARCH("blocked",$${col_letter}{header_row+1})))'.replace("$$","$")],
                fill=PatternFill(start_color="FFC7CE", end_color="FFC7CE", fill_type="solid")
            )
        )
        # Green for ok/clean/complete
        ws.conditional_formatting.add(
            rng,
            FormulaRule(
                formula=[f'OR(ISNUMBER(SEARCH("ok",$${col_letter}{header_row+1})),ISNUMBER(SEARCH("clean",$${col_letter}{header_row+1})),ISNUMBER(SEARCH("complete",$${col_letter}{header_row+1})))'.replace("$$","$")],
                fill=PatternFill(start_color="C6EFCE", end_color="C6EFCE", fill_type="solid")
            )
        )

STATUS_LIKE = ("status","action","result","decision","outcome","operation")  # not dates

def pick_status_column(df: pd.DataFrame) -> str | None:
    if df is None or df.empty:
        return None
    cols = [c for c in df.columns if c]
    # avoid columns that look like dates
    def ok(name: str) -> bool:
        l = name.lower()
        return any(k in l for k in STATUS_LIKE) and "date" not in l and "time" not in l
    for c in cols:
        if ok(c):
            return c
    return None

def build_overview(tables: dict[str, pd.DataFrame]) -> pd.DataFrame:
    rows = []
    for sheet, df in tables.items():
        col = pick_status_column(df)
        if not col:
            continue
        vc = (
            df[col].astype(str)
                  .str.strip()
                  .replace({"": "(blank)"})
                  .str.lower()
                  .value_counts(dropna=False)
        )
        for value, count in vc.items():
            rows.append({"Sheet": sheet, "StatusColumn": col, "Value": value, "Count": int(count)})
    if not rows:
        return pd.DataFrame({"Info": ["No status-like columns found to summarize."]})
    return (pd.DataFrame(rows)
              .sort_values(["Sheet","Count"], ascending=[True, False], ignore_index=True))

def write_info_tab(writer):
    import datetime as _dt  # ensure we get the module regardless of outer imports
    info = pd.DataFrame([{
        "Generated": _dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "User": getpass.getuser(),
        "Machine": platform.node(),
    }])
    info.to_excel(writer, index=False, sheet_name="Info")

def main():
    tables = {}
    for filename, sheet in FILES:
        df = read_csv_safe(ROOT / filename)
        if df is not None and not df.empty:
            tables[sheet] = df

    if not tables:
        print("[ERROR] No report CSVs found in:", ROOT)
        return

    with pd.ExcelWriter(OUT_XLSX_STAMPED, engine="openpyxl") as writer:
        # ---- Write Overview + Info FIRST so they appear at the front ----
        overview = build_overview(tables)
        overview.to_excel(writer, index=False, sheet_name="Overview")
        write_info_tab(writer)

        # ---- Now write the normal report tabs ----
        for sheet_name, df in tables.items():
            df.to_excel(writer, index=False, sheet_name=sheet_name)

        # ---- Post-format all sheets (keep your existing helpers/calls) ----
        wb = writer.book
        for sheet_name in wb.sheetnames:
            ws = wb[sheet_name]
            autosize_and_filter(ws)
            if sheet_name not in ("Overview", "Info"):
                add_action_colors(ws)
            if sheet_name == "Missing_Comments":
                add_missing_comments_colors(ws)

        # Make Overview the active sheet when the workbook opens
        if "Overview" in wb.sheetnames:
            wb.active = wb.sheetnames.index("Overview")


    print(f"[OK] Wrote Excel (timestamped): {OUT_XLSX_STAMPED}")

    # Best-effort copy to fixed name (skip if locked/open)
    try:
        OUT_XLSX_FIXED.write_bytes(OUT_XLSX_STAMPED.read_bytes())
        print(f"[OK] Also wrote: {OUT_XLSX_FIXED}")
    except PermissionError:
        print(f"[WARN] Could not overwrite {OUT_XLSX_FIXED} (file in use). Using timestamped output.")

if __name__ == "__main__":
    main()
