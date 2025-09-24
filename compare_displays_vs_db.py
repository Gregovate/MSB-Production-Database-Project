#!/usr/bin/env python3
r"""
Compare LOR v6 DB display names to the Google Sheet 'Displays' tab export,
and write a fully formatted Excel report to the Spreadsheet folder.

Inputs:
- SQLite DB:   G:\Shared drives\MSB Database\database\lor_output_v6.db
- Sheet CSV:   G:\Shared drives\MSB Database\Spreadsheet\displays_export.csv
               (produced by the Apps Script menu: DB Tools → Export Displays CSV)

Output:
- Excel:       G:\Shared drives\MSB Database\Spreadsheet\lor_display_compare.xlsx
               Tabs: Summary, Matches, DB_only, Sheet_only, Near_matches (optional)

Dependencies:
    pip install pandas openpyxl

Author: MSB Database project
"""

import os
import re
import sys
import sqlite3
import datetime
from pathlib import Path

import pandas as pd

# === Config (edit if you need to) ===
DB_PATH   = Path(r"G:\Shared drives\MSB Database\database\lor_output_v6.db")
CSV_PATH  = Path(r"G:\Shared drives\MSB Database\Spreadsheet\displays_export.csv")
XLSX_PATH = Path(r"G:\Shared drives\MSB Database\Spreadsheet\lor_display_compare.xlsx")

# Which DB column holds the "display name" text (your LOR comment)
DB_DISPLAY_COL = "LORComment"

# Enable fuzzy suggestions (Levenshtein distance) for near-matches
USE_FUZZY = True


# --------------- Helpers ---------------

def norm(s: str) -> str:
    """Normalize for matching: trim, collapse spaces, lowercase."""
    s = (s or "").strip()
    s = re.sub(r"\s+", " ", s)
    return s.lower()

def levenshtein(a: str, b: str) -> int:
    """Small Levenshtein for fuzzy suggestions."""
    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)
    prev = list(range(len(b) + 1))
    curr = [0] * (len(b) + 1)
    for i, ca in enumerate(a, 1):
        curr[0] = i
        for j, cb in enumerate(b, 1):
            cost = 0 if ca == cb else 1
            curr[j] = min(curr[j-1] + 1, prev[j] + 1, prev[j-1] + cost)
        prev, curr = curr, prev
    return prev[-1]

def load_db_names(db_path: Path) -> pd.DataFrame:
    con = sqlite3.connect(str(db_path))
    cur = con.cursor()
    # Ensure props + column exist
    cur.execute("PRAGMA table_info(props)")
    cols = [r[1] for r in cur.fetchall()]
    if DB_DISPLAY_COL not in cols:
        con.close()
        raise RuntimeError(f"Column '{DB_DISPLAY_COL}' not found in 'props'. Found: {cols}")

    # Pull display name + its preview name/revision; dedupe on display name
    df = pd.read_sql_query(
        f"""
        WITH base AS (
          SELECT
            TRIM(p.{DB_DISPLAY_COL})      AS display_name,
            TRIM(COALESCE(pv.Name,''))    AS Preview,
            TRIM(COALESCE(pv.Revision,'')) AS Revision
          FROM props p
          LEFT JOIN previews pv ON pv.id = p.PreviewId
          WHERE p.{DB_DISPLAY_COL} IS NOT NULL
            AND TRIM(p.{DB_DISPLAY_COL}) <> ''
        )
        SELECT display_name, MIN(Preview) AS Preview, MIN(Revision) AS Revision
        FROM base
        GROUP BY display_name
        """,
        con,
    )
    con.close()
    df["display_name_norm"] = df["display_name"].map(norm)
    df.drop_duplicates(subset=["display_name_norm"], inplace=True)
    return df


def load_sheet_names(csv_path: Path) -> pd.DataFrame:
    # Keep strings as-is, no NA coercion
    df = pd.read_csv(csv_path, dtype=str, keep_default_na=False)

    # Locate the "Display Name" column (case-insensitive fallbacks)
    disp_col = None
    for c in df.columns:
        if c.strip().lower() in ("display name", "display", "lor comment", "display_name"):
            disp_col = c
            break
    if disp_col is None:
        disp_col = df.columns[0]  # last resort

    df = df[[disp_col]].rename(columns={disp_col: "display_name"})
    df["display_name"] = df["display_name"].astype(str)
    df["display_name_norm"] = df["display_name"].map(norm)
    # Remove blanks and dups on the normalized key
    df = df[df["display_name_norm"] != ""].drop_duplicates(subset=["display_name_norm"])
    return df

def fuzzy_suggestions(missing_df: pd.DataFrame, universe_df: pd.DataFrame, k=3) -> pd.DataFrame:
    """Suggest up to k closest normalized names for each missing item."""
    if missing_df.empty or universe_df.empty:
        return pd.DataFrame(columns=["Missing_Side", "From_Name", "Suggested_Match", "Distance"])

    # Work on normalized keys
    miss = missing_df["display_name_norm"].tolist()
    uni  = universe_df["display_name_norm"].tolist()

    rows = []
    for key in miss:
        best = sorted(uni, key=lambda u: levenshtein(key, u))[:k]
        for cand in best:
            rows.append((key, cand, levenshtein(key, cand)))

    out = pd.DataFrame(rows, columns=["From_Key", "To_Key", "Distance"])
    # Map back to original (unnormalized) labels for readability
    key_to_name = pd.concat([
        missing_df[["display_name_norm", "display_name"]].rename(columns={"display_name_norm":"k","display_name":"v"}),
        universe_df[["display_name_norm", "display_name"]].rename(columns={"display_name_norm":"k","display_name":"v"})
    ], ignore_index=True).drop_duplicates("k").set_index("k")["v"].to_dict()

    out["From_Name"] = out["From_Key"].map(lambda k: key_to_name.get(k, k))
    out["Suggested_Match"] = out["To_Key"].map(lambda k: key_to_name.get(k, k))
    out = out.drop(columns=["From_Key","To_Key"]).sort_values(["Distance","From_Name","Suggested_Match"])
    return out


# --------------- Main compare ---------------

def run_compare(db_path: Path, csv_path: Path) -> dict:
    if not db_path.exists():
        raise FileNotFoundError(f"DB not found: {db_path}")
    if not csv_path.exists():
        raise FileNotFoundError(f"CSV not found: {csv_path}\n(Hint: run Sheets menu 'DB Tools → Export Displays CSV')")

    db_df = load_db_names(db_path)
    sh_df = load_sheet_names(csv_path)

    # Exact matches (on normalized key)
    matches = db_df.merge(sh_df, on="display_name_norm", suffixes=("_db","_sheet"))
    matches = matches.rename(columns={
        "display_name_db": "DB_Display_Name",
        "display_name_sheet": "Sheet_Display_Name",
        "display_name_norm": "Normalized_Key",
    })
    # Keep Preview + Revision coming from the DB side
    matches = matches[["DB_Display_Name", "Sheet_Display_Name", "Normalized_Key", "Preview", "Revision"]] \
                    .sort_values("Normalized_Key")

    # DB-only
    db_only = db_df[~db_df["display_name_norm"].isin(sh_df["display_name_norm"])]
    db_only = db_only.rename(columns={
        "display_name": "DB_Display_Name",
        "display_name_norm": "Normalized_Key",
    })
    db_only = db_only[["DB_Display_Name", "Normalized_Key", "Preview", "Revision"]] \
                    .sort_values("DB_Display_Name")

    # Sheet-only (no preview info on the sheet)
    sheet_only = sh_df[~sh_df["display_name_norm"].isin(db_df["display_name_norm"])]
    sheet_only = sheet_only.rename(columns={
        "display_name": "Sheet_Display_Name",
        "display_name_norm": "Normalized_Key",
    })
    sheet_only = sheet_only[["Sheet_Display_Name", "Normalized_Key"]] \
                        .sort_values("Sheet_Display_Name")

    # Fuzzy (optional) — unchanged
    near_matches = pd.DataFrame(columns=["Missing_Side","From_Name","Suggested_Match","Distance"])
    if USE_FUZZY:
        sug_db  = fuzzy_suggestions(
            db_only.rename(columns={"DB_Display_Name":"display_name","Normalized_Key":"display_name_norm"}),
            pd.concat([
                sheet_only.rename(columns={"Sheet_Display_Name":"display_name","Normalized_Key":"display_name_norm"}),
                matches.rename(columns={"DB_Display_Name":"display_name","Normalized_Key":"display_name_norm"})[["display_name","display_name_norm"]],
            ], ignore_index=True),
        )
        sug_db.insert(0, "Missing_Side", "DB_only")

        sug_sh  = fuzzy_suggestions(
            sheet_only.rename(columns={"Sheet_Display_Name":"display_name","Normalized_Key":"display_name_norm"}),
            pd.concat([
                db_only.rename(columns={"DB_Display_Name":"display_name","Normalized_Key":"display_name_norm"}),
                matches.rename(columns={"Sheet_Display_Name":"display_name","Normalized_Key":"display_name_norm"})[["display_name","display_name_norm"]],
            ], ignore_index=True),
        )
        sug_sh.insert(0, "Missing_Side", "Sheet_only")

        near_matches = pd.concat([sug_db, sug_sh], ignore_index=True)

        summary = pd.DataFrame([{
            "As of": datetime.datetime.now().strftime("%Y-%m-%d %H:%M"),
            "DB total (unique)": len(db_df),
            "Sheet total (unique)": len(sh_df),
            "Exact matches": len(matches),
            "DB-only": len(db_only),
            "Sheet-only": len(sheet_only),
        }])

    return {
        "summary": summary,
        "matches": matches,
        "db_only": db_only,
        "sheet_only": sheet_only,
        "near_matches": near_matches,
    }


# --------------- Excel writer ---------------

def autosize_and_filter(ws):
    # Freeze top row and add filters if data exists
    ws.freeze_panes = "A2"
    if ws.max_row >= 1 and ws.max_column >= 1:
        ws.auto_filter.ref = ws.dimensions
    # Auto-width (simple heuristic)
    for col in ws.columns:
        max_len = 0
        col_letter = col[0].column_letter
        for cell in col:
            try:
                val = str(cell.value) if cell.value is not None else ""
                if len(val) > max_len:
                    max_len = len(val)
            except Exception:
                pass
        ws.column_dimensions[col_letter].width = min(max(10, max_len + 2), 80)

def write_excel(out_path: Path, tables: dict):
    with pd.ExcelWriter(out_path, engine="openpyxl") as writer:
        for name, df in [
            ("Summary",      tables["summary"]),
            ("Matches",      tables["matches"]),
            ("DB_only",      tables["db_only"]),
            ("Sheet_only",   tables["sheet_only"]),
            ("Near_matches", tables["near_matches"]),
        ]:
            df.to_excel(writer, sheet_name=name, index=False)

        # Post-format
        wb = writer.book
        for sheet in wb.sheetnames:
            ws = wb[sheet]
            autosize_and_filter(ws)

    print(f"[OK] Wrote Excel report: {out_path}")


# --------------- Entrypoint ---------------

def main():
    try:
        tables = run_compare(DB_PATH, CSV_PATH)
        write_excel(XLSX_PATH, tables)
    except Exception as e:
        print(f"[ERROR] {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
