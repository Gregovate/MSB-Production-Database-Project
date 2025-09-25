#!/usr/bin/env python3
"""
merge_reports_to_excel_CLEAN.py
--------------------------------
Baseline, self-contained script to combine merger CSVs into a single Excel file
with multiple tabs, frozen headers, filters, auto-width, and simple coloring.

Usage (Windows PowerShell):
    python merge_reports_to_excel_CLEAN.py

Dependencies:
    pip install pandas openpyxl
"""

from pathlib import Path
from datetime import datetime
import warnings
import pandas as pd
from pandas.errors import ParserWarning
from openpyxl.formatting.rule import FormulaRule
from openpyxl.styles import PatternFill

# Silence noisy CSV parser warnings (optional)
warnings.simplefilter("ignore", ParserWarning)

# ================== CONFIG ==================
# Edit ROOT if your reports folder is different
ROOT = Path(r"G:\Shared drives\MSB Database\database\merger\reports")

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
OUT_XLSX_STAMPED = ROOT / f"lorprev_reports-{STAMP}.xlsx"
OUT_XLSX_FIXED   = ROOT / "lorprev_reports.xlsx"
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

def add_action_colors(ws, header_row=1):
    """
    Color rows in sheets that have an Action-like column ('action' in header).
    - Green: update-staging / applied
    - Red: blocked
    - Gray: skip / identical / no-op
    """
    # Find a column whose header contains "action"
    action_col_letter = None
    for cell in ws[header_row]:
        if cell.value and "action" in str(cell.value).strip().lower():
            action_col_letter = cell.column_letter
            break
    if not action_col_letter or ws.max_row <= header_row:
        return

    rng = f"${action_col_letter}${header_row+1}:${action_col_letter}${ws.max_row}"

    # green for update-staging / applied
    ws.conditional_formatting.add(
        rng,
        FormulaRule(
            formula=[f'ISNUMBER(SEARCH("update-staging",$${action_col_letter}{header_row+1}))'.replace("$$","$")],
            fill=PatternFill(start_color="C6EFCE", end_color="C6EFCE", fill_type="solid")
        )
    )
    ws.conditional_formatting.add(
        rng,
        FormulaRule(
            formula=[f'ISNUMBER(SEARCH("applied",$${action_col_letter}{header_row+1}))'.replace("$$","$")],
            fill=PatternFill(start_color="C6EFCE", end_color="C6EFCE", fill_type="solid")
        )
    )
    # red for blocked
    ws.conditional_formatting.add(
        rng,
        FormulaRule(
            formula=[f'ISNUMBER(SEARCH("blocked",$${action_col_letter}{header_row+1}))'.replace("$$","$")],
            fill=PatternFill(start_color="FFC7CE", end_color="FFC7CE", fill_type="solid")
        )
    )
    # gray for skip / identical / no-op
    ws.conditional_formatting.add(
        rng,
        FormulaRule(
            formula=[f'OR(ISNUMBER(SEARCH("skip",$${action_col_letter}{header_row+1})),ISNUMBER(SEARCH("identical",$${action_col_letter}{header_row+1})),ISNUMBER(SEARCH("no-op",$${action_col_letter}{header_row+1})))'.replace("$$","$")],
            fill=PatternFill(start_color="E7E6E6", end_color="E7E6E6", fill_type="solid")
        )
    )

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
        # Write each DataFrame to its own sheet
        for sheet_name, df in tables.items():
            df.to_excel(writer, index=False, sheet_name=sheet_name)

        # Post-format all sheets
        wb = writer.book
        for sheet_name in wb.sheetnames:
            ws = wb[sheet_name]
            autosize_and_filter(ws)
            if sheet_name in ("Compare", "Applied_This_Run", "Apply_Events"):
                add_action_colors(ws)
            if sheet_name == "Missing_Comments":
                add_missing_comments_colors(ws)

    print(f"[OK] Wrote Excel (timestamped): {OUT_XLSX_STAMPED}")

    # Best-effort copy to fixed name (skip if locked/open)
    try:
        OUT_XLSX_FIXED.write_bytes(OUT_XLSX_STAMPED.read_bytes())
        print(f"[OK] Also wrote: {OUT_XLSX_FIXED}")
    except PermissionError:
        print(f"[WARN] Could not overwrite {OUT_XLSX_FIXED} (file in use). Using timestamped output.")

if __name__ == "__main__":
    main()
