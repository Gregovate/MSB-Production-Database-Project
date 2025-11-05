#!/usr/bin/env python3
# ShowPC_LORPreviews_Export.py
# GAL 2025-11-01 — v1.1.0
# 
# ShowPC LORPreviews exporter + wiring compare — SAFE PATH
# --------------------------------------------------------
# Purpose:
#   • Read the live LORPreviews.xml (or its .zip) from the Show PC.
#   • Extract selected PreviewClass entries into individual .lorprev files.
#   • Build a temporary SQLite (via parse_props_v7.py) and create wiring views.
#   • Compare wiring rows against the production lor_output_v6.db.
#   • Generate a dated Excel report (Overview, Matches, OnlyInDB, OnlyInXML),
#     plus preview metadata (including BackgroundFile) and background mismatches.

# Why this script now:
#   • Final two weeks before show: we avoid `--apply` in the merger.
#   • The Show PC exports are the operational source of truth.

# Outputs:
#   • <out>/lorprevs/*.lorprev          (clean extracts from the Show PC)
#   • <out>/showpc_extracted.db        (temp DB; deleted unless --keep-temp-db)
#   • <out>/LORPreviews_Manifest_<date>.csv
#   • <out>/ShowPC_WiringCompare_<date>.xlsx
#       - Sheets: Overview, Wiring_Matches, Wiring_OnlyInDB, Wiring_OnlyInXML,
#                 ParserStatus, Previews_XML, Background_Mismatches

# Safe defaults:
#   • Prompts for the live XML/ZIP (or pass --xml / --xml-zip).
#   • Writes to G:\Shared drives\MSB Database\UserPreviewStaging\ShowPC\ShowPC_Export_<date>\
#   • NEVER modifies prod DB. No `--apply`. No network moves. Just reports.

# Operator notes:
#   • Run after each editing session on the Show PC.
#   • Share the XLSX to the team; use FormView for wiring.
#     
# Changelog:
# 2025-10-26  V0.0.9  Initial code release
# 2025-10-31  V1.0.0  First stable operational release
#                     • Added GUI file picker for XML/ZIP input
#                     • Added DEFAULT_PROD_DB with fail-fast validation
#                     • Added MSB_SKIP_DISPLAYS_COMPARE=1 to skip display sheet compare
#                     • Added BackgroundFile capture in manifest + Excel
#                     • Added Previews_XML & Background_Mismatches Excel sheets
#                     • Parsing now writes to TEMP DB only (no production writes)
#                     • Timestamped output folders and filenames
#                     • Full operator workflow: “double-click → pick file → done”
# 2025-11-01  V1.1.0  Display Name audit enhancements
#                     • Added prop-level Display Name audits using TEMP DB
#                     • Joins props → previews via both GUID and IntPreviewID keys
#                     • Fallback join to preview_wiring_sorted_v6 for unmatched props
#                     • Ignores blanks when DeviceType == "None"
#                     • Flags Display Names containing whitespace
#                     • Adds two Excel sheets:
#                           - Blank_DisplayNames
#                           - Spaces_in_DisplayNames
#                     • Includes PreviewName and BackgroundFile context for repairs
#                     • Confirmed background path + auto-fit + auto-open all working



import argparse, os, re, sys, zipfile, sqlite3, hashlib, datetime
from pathlib import Path
from xml.etree import ElementTree as ET
import pandas as pd
import traceback
from contextlib import contextmanager

# ---- Defaults (paths live on Show PC / Shared Drive)
DEFAULT_PROD_DB = r"G:\Shared drives\MSB Database\database\lor_output_v6.db"  # read-only compare
DEFAULT_REPORT_ROOT = r"G:\Shared drives\MSB Database\Database Previews\reports\ShowPC"
DEFAULT_OUT_ROOT    = r"G:\Shared drives\MSB Database\UserPreviewStaging\ShowPC"
# Temporarily disable the Displays CSV compare step
RUN_DISPLAYS_COMPARE = False
#Skip displays compare by default 
os.environ["MSB_SKIP_DISPLAYS_COMPARE"] = "1"

try:
    import pandas as pd
except Exception:
    pd = None

# --- Optional GUI file picker fallback ---
def pick_zip_file():
    try:
        import tkinter as tk
        from tkinter import filedialog
        root = tk.Tk()
        root.withdraw()
        path = filedialog.askopenfilename(
            title="Select LORPreviews ZIP",
            filetypes=[("ZIP Files", "*.zip"), ("XML Files", "*.xml"), ("All Files", "*.*")]
        )
        return path
    except Exception:
        return None

# --- Prevent the parser from killing this wrapper via sys.exit() ---
# import sys
# from contextlib import contextmanager

@contextmanager
def suppress_sys_exit():
    """Temporarily replace sys.exit so parser can't terminate this wrapper."""
    original_exit = sys.exit
    try:
        sys.exit = lambda code=0: (_ for _ in ()).throw(SystemExit(code))
        yield
    finally:
        sys.exit = original_exit

# --- Make input() non-interactive (auto-press Enter / supply default) ---
from contextlib import contextmanager
@contextmanager
def override_input(default=""):
    import builtins
    old_input = builtins.input
    builtins.input = lambda prompt='': (print(prompt, end='') or default)
    try:
        yield
    finally:
        builtins.input = old_input

def wrap_parser_audits_soft(parser_mod, verbose=False):
    """
    If parse_props_v7 has an audit function that raises/stops, wrap it so it only warns.
    Safe: no-op if not present.
    """
    candidates = [
        "audit_displayname_masters_unique_across_previews",
    ]
    for name in candidates:
        if hasattr(parser_mod, name):
            original = getattr(parser_mod, name)
            def soft_audit(db_file, _orig=original, _audit_name=name):
                try:
                    return _orig(db_file)
                except Exception as e:
                    print(f"[WARN] {_audit_name} suppressed: {e}")
                    return None
            setattr(parser_mod, name, soft_audit)
            if verbose:
                print(f"[DEBUG] Wrapped {name} with soft handler.")

def strip_ns_tree(tree: ET.ElementTree) -> ET.ElementTree:
    root = tree.getroot()
    for el in root.iter():
        if '}' in el.tag:
            el.tag = el.tag.split('}', 1)[1]
        if el.attrib:
            el.attrib = { (k.split('}',1)[-1] if '}' in k else k): v for k,v in el.attrib.items() }
    return tree

def safe_name(s: str) -> str:
    keep = "-_.() []"
    return ''.join(ch for ch in s if ch.isalnum() or ch in keep).strip() or "Preview"

def sha256_text(s: str) -> str:
    import hashlib
    return hashlib.sha256(s.encode('utf-8')).hexdigest()

def load_parser_module(path: Path):
    import importlib.util, types
    spec = importlib.util.spec_from_file_location('parse_props_v7', str(path))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod

def extract_previews(xml_bytes: bytes, out_dir: Path, name_filter: str|None=None):
    out_dir.mkdir(parents=True, exist_ok=True)
    tree = ET.ElementTree(ET.fromstring(xml_bytes))
    strip_ns_tree(tree)
    root = tree.getroot()
    previews = [el for el in root.iter() if el.tag.endswith('PreviewClass')]
    rx = re.compile(name_filter) if name_filter else None
    manifest = []
    for i, prev in enumerate(previews, start=1):
        nm = prev.get('Name') or f'Preview_{i:03d}'
        if rx and not rx.search(nm):
            continue
        pid = prev.get('ID') or prev.get('Id') or prev.get('id') or ''
        rev = prev.get('Revision') or prev.get('revision') or ''
        bg = prev.get('BackgroundFile') or ''
        # NEW: LOR “Display Name” lives in the comment; different exports use different keys
        display_name = (prev.get('Comment') or prev.get('LORComment') or '').strip()

        xml_str = ET.tostring(prev, encoding='utf-8').decode('utf-8')
        fname = f"{safe_name(nm)}.lorprev"
        (out_dir / fname).write_text('<?xml version="1.0" encoding="utf-8"?>\n' + xml_str, encoding='utf-8')
        propcount = len(prev.findall('.//PropClass'))
        manifest.append({
            'PreviewName': nm,
            'PreviewID': pid,
            'Revision': rev,
            'PropCount': propcount,
            'HashFullXML': sha256_text(xml_str),
            'FileName': fname,
            'BackgroundFile': bg,
            'LORComment': display_name,   # <— add this
        })
    return manifest

def read_xml_from_source(xml_path: str | None = None, zip_path: str | None = None) -> bytes:
    """Return XML bytes from either a .xml file or a .zip containing one."""
    from pathlib import Path
    import zipfile

    # case 1: plain XML file
    if xml_path and Path(xml_path).is_file() and xml_path.lower().endswith(".xml"):
        return Path(xml_path).read_bytes()

    # case 2: zipped file
    if zip_path and Path(zip_path).is_file() and zip_path.lower().endswith(".zip"):
        with zipfile.ZipFile(zip_path, "r") as zf:
            xml_names = [n for n in zf.namelist() if n.lower().endswith(".xml")]
            if not xml_names:
                raise FileNotFoundError("No .xml found inside the provided ZIP.")
            return zf.read(xml_names[0])

    raise FileNotFoundError(
        "Provide --xml (for .xml file) or --xml-zip (for .zip file) — neither was found."
    )
def write_manifest_csv(manifest: list[dict], out_csv: Path):
    if not pd:
        return
    pd.DataFrame(manifest).to_csv(out_csv, index=False)

def run_parser_on_folder(parser_mod, lorprev_dir: Path, temp_db: Path, verbose=False, continue_on_error=False):
    parser_mod.DB_FILE = str(temp_db)
    if verbose:
        print(f"[INFO] Building temp DB: {temp_db}")
    parser_mod.setup_database()

    wrap_parser_audits_soft(parser_mod, verbose=verbose)

    # Prevent sys.exit() from killing this wrapper AND make the parser non-interactive
    with suppress_sys_exit(), override_input(default=""):
        try:
            parser_mod.process_folder(str(lorprev_dir))
            try:
                parser_mod.collapse_duplicate_masters(str(temp_db))
                parser_mod.reconcile_subprops_to_canonical_master(str(temp_db))
            except Exception as e:
                if verbose:
                    print(f"[WARN] reconcile/collapse skipped: {e}")
        except SystemExit as se:
            if not continue_on_error:
                raise
            print(f"[WARN] Parser attempted to exit: SystemExit({se}). Continuing due to --continue-on-error.")
        except Exception as e:
            if not continue_on_error:
                raise
            print(f"[WARN] Parser aborted early: {e}")
            print("[WARN] Continuing to build whatever wiring views we can…")

    # Always try to build views; keep non-interactive here too
    with suppress_sys_exit(), override_input(default=""):
        try:
            parser_mod.create_wiring_views_v6(str(temp_db))
        except SystemExit as se2:
            if not continue_on_error:
                raise
            print(f"[WARN] create_wiring_views_v6 attempted to exit: {se2}.")
        except Exception as e2:
            if verbose:
                print(f"[WARN] Could not create views: {e2}")


def build_wiring_excel(temp_db: Path, prod_db: Path, out_xlsx: Path, verbose=False):
    if not pd:
        print('[WARN] pandas not available; skipping Excel.', flush=True)
        return
    import pandas as _pd, sqlite3
    prod_conn = sqlite3.connect(str(prod_db))
    temp_conn = sqlite3.connect(str(temp_db))
    try:
        df_prod = _pd.read_sql_query('SELECT * FROM preview_wiring_sorted_v6', prod_conn)
        df_temp = _pd.read_sql_query('SELECT * FROM preview_wiring_sorted_v6', temp_conn)
        join_cols = ['PreviewName','DisplayName','Network','Controller','StartChannel']
        prod_keys = set(tuple(r) for r in df_prod[join_cols].itertuples(index=False, name=None))
        temp_keys = set(tuple(r) for r in df_temp[join_cols].itertuples(index=False, name=None))
        only_in_db = prod_keys - temp_keys
        only_in_xml = temp_keys - prod_keys
        in_both = prod_keys & temp_keys
        df_only_in_db = _pd.DataFrame(list(only_in_db), columns=join_cols).sort_values(join_cols)
        df_only_in_xml = _pd.DataFrame(list(only_in_xml), columns=join_cols).sort_values(join_cols)
        df_in_both = _pd.DataFrame(list(in_both), columns=join_cols).sort_values(join_cols)
        overview = _pd.DataFrame([{
            'Rows_DB': len(prod_keys),
            'Rows_XML': len(temp_keys),
            'Matches': len(in_both),
            'Only_in_DB': len(only_in_db),
            'Only_in_XML': len(only_in_xml),
            'Distinct_Previews_DB': df_prod['PreviewName'].nunique(),
            'Distinct_Previews_XML': df_temp['PreviewName'].nunique()
        }])
        with _pd.ExcelWriter(out_xlsx, engine='openpyxl') as writer:
            overview.to_excel(writer, index=False, sheet_name='Overview')
            df_in_both.to_excel(writer, index=False, sheet_name='Wiring_Matches')
            df_only_in_db.to_excel(writer, index=False, sheet_name='Wiring_OnlyInDB')
            df_only_in_xml.to_excel(writer, index=False, sheet_name='Wiring_OnlyInXML')
        if verbose:
            print(f"[INFO] Wrote wiring Excel: {out_xlsx}")
    finally:
        prod_conn.close(); temp_conn.close()

def main():
    ap = argparse.ArgumentParser(description='ShowPC LORPreviews exporter + wiring compare')
    ap.add_argument('--xml', help='Path to LORPreviews.xml (CommonData)')
    ap.add_argument('--xml-zip', help='Path to a ZIP containing LORPreviews.xml')
    ap.add_argument('--out', help='Output folder (staging); defaults to dated ShowPC_Export folder')
    ap.add_argument('--out-previews', help='Folder for extracted .lorprev files (default: <out>/lorprevs)')
    ap.add_argument('--filter', default=r'^(RGB Plus Stage|Show Animation|Show Background Stage)',
                    help='Regex to select PreviewClass @Name; default limits to show masters')
    ap.add_argument('--all-previews', action='store_true',
                    help='Ignore --filter and export every PreviewClass in LORPreviews.xml')    
    ap.add_argument('--parser', help='Optional path to parse_props_v7.py (defaults to next to this script)')
    ap.add_argument('--keep-temp-db', action='store_true', help='Keep temp DB after report creation')
    ap.add_argument('--verbose', action='store_true')
    ap.add_argument('--continue-on-error', action='store_true',
                help='Keep going even if parser audits/errors occur')
    ap.add_argument('--prod-db',
        default=DEFAULT_PROD_DB,
        help='Production lor_output_v6.db to compare against (read-only). '
            f'Default: {DEFAULT_PROD_DB}')
    ap.add_argument('--no-wiring-compare', action='store_true',
        help='Skip wiring compare + Excel build (useful if prod DB not mapped)')

    args = ap.parse_args()

    run_stamp = datetime.datetime.now().strftime("%Y-%m-%d_%H%M%S")


    # --- Default output location if not specified ---
    if not args.out:
        base = Path(r"G:\Shared drives\MSB Database\UserPreviewStaging\ShowPC")
        date_tag = datetime.datetime.now().strftime("%Y-%m-%d")
        args.out = str(base / f"ShowPC_Export_{run_stamp}")
        print(f"[INFO] No --out specified; using default export folder:")
        print(f"       {args.out}")

    # --- Default preview folder if not provided ---
    if not args.out_previews:
        args.out_previews = str(Path(args.out) / "lorprevs")

    # --- Create all folders ---
    out_dir = Path(args.out); out_dir.mkdir(parents=True, exist_ok=True)
    lorprev_dir = Path(args.out_previews); lorprev_dir.mkdir(parents=True, exist_ok=True)

    manifest_csv = out_dir / f"LORPreviews_Manifest_{run_stamp}.csv"
    temp_db = out_dir / 'showpc_extracted.db'
    excel_path   = out_dir / f"ShowPC_WiringCompare_{run_stamp}.xlsx"

    parser_path = Path(args.parser) if args.parser else (Path(__file__).parent / 'parse_props_v7.py')
    if not parser_path.exists():
        print(f"[FATAL] parse_props_v7.py not found at {parser_path}")
        sys.exit(2)
 
    parse_log = []   # [(preview, status, message)]

    parser_mod = load_parser_module(parser_path)

    print(f"[INFO] Output base: {out_dir}")
    print(f"[INFO] Preview extracts: {lorprev_dir}")

    # --- Choose input file (CLI arg or GUI picker) ---
    xml_path = args.xml or args.xml_zip
    if not xml_path:
        # Friendly banner so the user knows exactly what to pick
        print("\n" + "-" * 66)
        print(" ShowPC LOR Preview Export Utility")
        print("-" * 66)
        print("Please select the current LORPreviews ZIP or XML file.")
        print("\n👉  Typically found at:")
        print("    C:\\lor\\CommonData\\LORPreviews.xml")
        print("    or a recent export like:")
        print("    G:\\Shared drives\\MSB Database\\UserPreviewStaging\\ShowPC_Test\\LORPreviews-25-10-21.zip")
        print("\nSelect the correct file and click OPEN to continue.")
        print("-" * 66 + "\n")

        xml_path = pick_zip_file()
        if not xml_path:
            print("[FATAL] No file selected; exiting.")
            sys.exit(1)

    # Confirm exactly what was chosen (whether from CLI or picker)
    print(f"[INFO] Selected file: {xml_path}")

    # Route selection into the normal loader
    if xml_path.lower().endswith(".zip"):
        args.xml_zip = xml_path
    else:
        args.xml = xml_path

    # Load bytes the usual way
    xml_bytes = read_xml_from_source(args.xml, args.xml_zip)
    if args.verbose:
        print("[INFO] XML loaded. Extracting previews...")

    # Decide which name filter to use
    if getattr(args, "all_previews", False):
        effective_filter = None
        if args.verbose:
            print("[INFO] --all-previews set; exporting every PreviewClass (no name filter).")
    else:
        effective_filter = args.filter

    manifest = extract_previews(xml_bytes, lorprev_dir, name_filter=effective_filter)

    print(f"[INFO] Extracted {len(manifest)} previews to {lorprev_dir}")
    if manifest:
        sample = [m["PreviewName"] for m in manifest[:10]]
        print("[INFO] First previews:", ", ".join(sample))    
        if pd:
            write_manifest_csv(manifest, manifest_csv)
        if args.verbose:
            print(f"[INFO] Extracted {len(manifest)} previews matching filter to {lorprev_dir}")

    # Track any parser error so we can report it in Excel
    parser_error_msg = ""

    try:
        run_parser_on_folder(parser_mod, lorprev_dir, temp_db,
                            verbose=args.verbose,
                            continue_on_error=getattr(args, "continue_on_error", False))
    except Exception as e:
        if not getattr(args, "continue_on_error", False):
            raise
        parser_error_msg = f"{type(e).__name__}: {e}"
        print(f"[WARN] Parser aborted early: {parser_error_msg}")
        print("[WARN] Continuing to build whatever wiring views we can…")
        try:
            parser_mod.create_wiring_views_v6(str(temp_db))
        except Exception as e2:
            print(f"[WARN] Could not create views: {e2}")
 
    # ---- Build ParserStatus (OK/FAIL per preview) BEFORE we write Excel ----
    # Requires: `manifest`, `temp_db`
    # import sqlite3
    if pd is not None:
        # previews we attempted (from manifest just created by extract_previews)
        attempted = [m["PreviewName"] for m in manifest]

        # previews that actually made it into the temp DB
        parsed_names = set()
        try:
            conn_tmp = sqlite3.connect(str(temp_db))
            try:
                # Prefer the parser's 'previews' table; fall back to the wiring view if needed
                exists_df = pd.read_sql_query(
                    "SELECT name FROM sqlite_master WHERE type IN ('table','view') AND name IN ('previews','preview_wiring_sorted_v6')",
                    conn_tmp
                )
                if (exists_df["name"] == "previews").any():
                    df_parsed = pd.read_sql_query("SELECT DISTINCT Name FROM previews", conn_tmp)
                else:
                    df_parsed = pd.read_sql_query(
                        "SELECT DISTINCT PreviewName AS Name FROM preview_wiring_sorted_v6", conn_tmp
                    )
                parsed_names = set(df_parsed["Name"].astype(str))
            finally:
                conn_tmp.close()
        except Exception as e:
            print(f"[WARN] Could not read parsed preview names from temp DB: {e}")
            parsed_names = set()

        # Build status rows (every attempted preview gets a row)
        status_rows = []
        # If you captured a top-level parser error earlier, plug it in here:
        # parser_error_msg = parser_error_msg if 'parser_error_msg' in locals() else ""
        for name in attempted:
            if name in parsed_names:
                status_rows.append({"PreviewName": name, "Status": "OK", "Message": "Parsed successfully"})
            else:
                status_rows.append({"PreviewName": name, "Status": "FAIL",
                                    "Message": "Not parsed (audit/exception before this preview)"})

        df_parser_status = pd.DataFrame(status_rows).sort_values(["Status", "PreviewName"]).reset_index(drop=True)
    else:
        df_parser_status = None

    build_wiring_excel(temp_db, Path(args.prod_db), excel_path, verbose=args.verbose)

    # ---- Append Preview background info and mismatches ----
    if pd is not None:
        try:
            import sqlite3 as _sqlite
            # Read previews from TEMP (XML side)
            conn_tmp = _sqlite.connect(str(temp_db))
            df_xml_prev = pd.read_sql_query(
                "SELECT Name AS PreviewName, BackgroundFile AS Background_XML FROM previews", conn_tmp
            )
            conn_tmp.close()

            # Read previews from PROD (DB side)
            conn_prod = _sqlite.connect(str(Path(args.prod_db)))
            df_db_prev = pd.read_sql_query(
                "SELECT Name AS PreviewName, BackgroundFile AS Background_DB FROM previews", conn_prod
            )
            conn_prod.close()

            # Left join XML → DB to spot deltas
            df_bg = df_xml_prev.merge(df_db_prev, on="PreviewName", how="left")
            df_mismatch = df_bg[df_bg["Background_XML"].fillna("") != df_bg["Background_DB"].fillna("")] \
                            .sort_values("PreviewName")

            with pd.ExcelWriter(excel_path, engine="openpyxl", mode="a", if_sheet_exists="overlay") as writer:
                df_xml_prev.sort_values("PreviewName").to_excel(writer, index=False, sheet_name="Previews_XML")
                df_mismatch.to_excel(writer, index=False, sheet_name="Background_Mismatches")
            print(f"[INFO] Added Previews_XML and Background_Mismatches to {excel_path}")
        except Exception as e:
            print(f"[WARN] Could not append preview background sheets: {e}")

    # --- Prop-level Display Name audits (robust): blanks + spaces + solid preview join ---
    try:
        # import sqlite3 as _sqlite
        # import pandas as pd

        conn = _sqlite.connect(str(temp_db))

        # 1) First, build a preview lookup that carries both keys (GUID + Int)
        q_pv = """
        SELECT
            CAST(IntPreviewID AS TEXT) AS IntKey,
            CAST(id AS TEXT)           AS GuidKey,
            Name                       AS PreviewName,
            BackgroundFile
        FROM previews
        """
        df_pv = pd.read_sql_query(q_pv, conn)

        # 2) Pull props with DisplayName (LORComment), DeviceType, and raw PreviewId
        q_props = """
        SELECT
            PropID,
            Name                          AS PropName,
            COALESCE(DeviceType,'')       AS DeviceType,
            TRIM(COALESCE(LORComment,'')) AS DisplayName,
            CAST(PreviewId AS TEXT)       AS PreviewIdRaw
        FROM props
        """
        df_props = pd.read_sql_query(q_props, conn)

        # 3) Try to resolve preview via either Int or GUID key
        #    (two left-joins then coalesce the matched columns)
        df_join_int  = df_props.merge(df_pv.add_prefix("Int_"),  left_on="PreviewIdRaw", right_on="Int_IntKey",  how="left")
        df_join_both = df_join_int.merge(df_pv.add_prefix("Guid_"), left_on="PreviewIdRaw", right_on="Guid_GuidKey", how="left")

        # Coalesce preview columns from either side
        df_join_both["PreviewName"]   = df_join_both["Int_PreviewName"].fillna(df_join_both["Guid_PreviewName"])
        df_join_both["BackgroundFile"] = df_join_both["Int_BackgroundFile"].fillna(df_join_both["Guid_BackgroundFile"])

        # 4) Fallback: if still missing, use wiring view (has PreviewName by PropID)
        try:
            q_wiring = """
            SELECT DISTINCT
                PropID,
                PreviewName
            FROM preview_wiring_sorted_v6
            """
            df_wiring = pd.read_sql_query(q_wiring, conn)
            # fill only where PreviewName is still null
            mask_missing = df_join_both["PreviewName"].isna()
            df_join_both.loc[mask_missing, "PreviewName"] = df_join_both[mask_missing].merge(
                df_wiring, on="PropID", how="left"
            )["PreviewName"].values
        except Exception:
            # wiring view may not exist if parser failed early; ignore
            pass

        conn.close()

        # Normalize helper and build audits
        df_all = df_join_both[[
            "PropID","PropName","DeviceType","DisplayName","PreviewName","BackgroundFile","PreviewIdRaw"
        ]].copy()

        df_all["DeviceType_lc"] = df_all["DeviceType"].astype(str).str.lower()

        # Rule 1: Blank display names (excluding DeviceType == "none")
        df_blanks = df_all[
            (df_all["DisplayName"] == "") &
            (df_all["DeviceType_lc"] != "none")
        ].drop(columns=["DeviceType_lc"]).sort_values(["PreviewName", "PropName"], na_position="last")

        # Rule 2: Names containing spaces (any whitespace)
        df_spaces = df_all[
            df_all["DisplayName"].astype(str).str.contains(r"\s", regex=True, na=False)
        ].drop(columns=["DeviceType_lc"]).sort_values(["PreviewName", "PropName"], na_position="last")

        # Write both tabs (replace-or-create)
        with pd.ExcelWriter(excel_path, engine="openpyxl", mode="a", if_sheet_exists="replace") as writer:
            if df_blanks.empty:
                pd.DataFrame([{"Status": "No blank Display Names (excluding DeviceType=None)"}]).to_excel(
                    writer, index=False, sheet_name="Blank_DisplayNames"
                )
            else:
                df_blanks.to_excel(writer, index=False, sheet_name="Blank_DisplayNames")

            if df_spaces.empty:
                pd.DataFrame([{"Status": "No Display Names with spaces"}]).to_excel(
                    writer, index=False, sheet_name="Spaces_in_DisplayNames"
                )
            else:
                df_spaces.to_excel(writer, index=False, sheet_name="Spaces_in_DisplayNames")

        print(f"[INFO] Audited Display Names → Blank: {len(df_blanks)}; Spaces: {len(df_spaces)}")

    except Exception as e:
        print(f"[WARN] Could not build Display Name audit sheets: {e}")

    # ---- Append ParserStatus to the Excel we just created ----
    if pd is not None and df_parser_status is not None:
        try:
            with pd.ExcelWriter(excel_path, engine="openpyxl", mode="a", if_sheet_exists="replace") as writer:
                df_parser_status.to_excel(writer, index=False, sheet_name="ParserStatus")
            print(f"[INFO] Added ParserStatus sheet to {excel_path}")
        except Exception as e:
            print(f"[WARN] Could not append ParserStatus sheet: {e}")


    if not args.keep_temp_db:
        try:
            temp_db.unlink()
        except Exception:
            pass

    print('[DONE] ShowPC export + compare complete.')
    print(f'  Staging: {lorprev_dir}')
    if pd:
        print(f'  Manifest: {manifest_csv}')
        print(f'  Excel: {excel_path}')
    print(f"[INFO] Output base: {out_dir}")
    print(f"[INFO] Preview extracts: {lorprev_dir}")
    print(f"[INFO] Temp DB: {temp_db} (deleted after run unless --keep-temp-db)")
    print(f"[INFO] Manifest: {manifest_csv}")
    print(f"[INFO] Excel: {excel_path}")
    
    # --- Auto-fit columns in the Excel report ---
    try:
        from openpyxl import load_workbook

        wb = load_workbook(excel_path)
        for ws in wb.worksheets:
            for col in ws.columns:
                max_len = 0
                col_letter = col[0].column_letter
                for cell in col:
                    try:
                        # Convert cell value to string and measure length
                        val_len = len(str(cell.value)) if cell.value is not None else 0
                        if val_len > max_len:
                            max_len = val_len
                    except Exception:
                        pass
                # Add a small buffer (2 chars)
                ws.column_dimensions[col_letter].width = max_len + 2
        wb.save(excel_path)
        print(f"[INFO] Auto-fitted columns in: {excel_path}")
    except Exception as e:
        print(f"[WARN] Could not auto-fit columns: {e}")
    
    # --- Open the Excel report for the operator ---
    try:
        from pathlib import Path as _P
        import os, subprocess, platform, time

        # Give the filesystem a brief moment (handles network share latency)
        time.sleep(0.2)

        xls = _P(excel_path)
        if xls.exists():
            sysname = platform.system()
            if sysname == "Windows":
                os.startfile(str(xls))  # opens in default Excel
            elif sysname == "Darwin":  # macOS
                subprocess.run(["open", str(xls)], check=False)
            else:  # Linux/other
                subprocess.run(["xdg-open", str(xls)], check=False)
            print(f"[INFO] Opened Excel report: {xls}")
        else:
            print(f"[WARN] Excel report not found to open: {xls}")
    except Exception as e:
        print(f"[WARN] Could not open Excel automatically: {e}")


if __name__ == '__main__':
    main()
