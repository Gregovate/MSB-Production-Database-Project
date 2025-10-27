#!/usr/bin/env python3
# ShowPC_LORPreviews_Export.py
# GAL 2025-10-26 — v0.9

import argparse, os, re, sys, zipfile, sqlite3, hashlib, datetime
from pathlib import Path
from xml.etree import ElementTree as ET

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
    spec = importlib.util.spec_from_file_location('parse_props_v6', str(path))
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
        xml_str = ET.tostring(prev, encoding='utf-8').decode('utf-8')
        fname = f"{safe_name(nm)}.lorprev"
        (out_dir / fname).write_text('<?xml version="1.0" encoding="utf-8"?>\n' + xml_str, encoding='utf-8')
        propcount = len(prev.findall('.//PropClass'))
        manifest.append({
            'PreviewName': nm, 'PreviewID': pid, 'Revision': rev,
            'PropCount': propcount, 'HashFullXML': sha256_text(xml_str), 'FileName': fname
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

def run_parser_on_folder(parser_mod, lorprev_dir: Path, temp_db: Path, verbose=False):
    parser_mod.DB_FILE = str(temp_db)
    if verbose:
        print(f"[INFO] Building temp DB: {temp_db}")
    parser_mod.setup_database()
    parser_mod.process_folder(str(lorprev_dir))
    try:
        parser_mod.collapse_duplicate_masters(str(temp_db))
        parser_mod.reconcile_subprops_to_canonical_master(str(temp_db))
    except Exception as e:
        if verbose:
            print(f"[WARN] reconcile/collapse skipped: {e}")
    parser_mod.create_wiring_views_v6(str(temp_db))

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
    ap.add_argument('--out', required=True, help='Output folder (staging)')
    ap.add_argument('--prod-db', required=True, help='Production lor_output_v6.db to compare against')
    ap.add_argument('--filter', default=r'^(RGB Plus Background|Show Animation|Show Background)',
                    help='Regex to select PreviewClass @Name; default limits to show masters')
    ap.add_argument('--parser', help='Optional path to parse_props_v6.py (defaults to next to this script)')
    ap.add_argument('--keep-temp-db', action='store_true', help='Keep temp DB after report creation')
    ap.add_argument('--verbose', action='store_true')
    args = ap.parse_args()

    out_dir = Path(args.out); out_dir.mkdir(parents=True, exist_ok=True)
    lorprev_dir = out_dir / 'lorprevs'; lorprev_dir.mkdir(exist_ok=True)
    manifest_csv = out_dir / f"LORPreviews_Manifest_{datetime.datetime.now().strftime('%Y-%m-%d')}.csv"
    temp_db = out_dir / 'showpc_extracted.db'
    excel_path = out_dir / f"ShowPC_WiringCompare_{datetime.datetime.now().strftime('%Y-%m-%d')}.xlsx"

    parser_path = Path(args.parser) if args.parser else (Path(__file__).parent / 'parse_props_v6.py')
    if not parser_path.exists():
        print(f"[FATAL] parse_props_v6.py not found at {parser_path}")
        sys.exit(2)
    parser_mod = load_parser_module(parser_path)

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


    manifest = extract_previews(xml_bytes, lorprev_dir, name_filter=args.filter)
    if pd:
        write_manifest_csv(manifest, manifest_csv)
    if args.verbose:
        print(f"[INFO] Extracted {len(manifest)} previews matching filter to {lorprev_dir}")

    run_parser_on_folder(parser_mod, lorprev_dir, temp_db, verbose=args.verbose)
    build_wiring_excel(temp_db, Path(args.prod_db), excel_path, verbose=args.verbose)

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

if __name__ == '__main__':
    main()
