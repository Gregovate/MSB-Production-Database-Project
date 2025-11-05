# GAL 2025-11-05  V0.4.1
# Light-O-Rama .lorprev Group/Tag Explorer → Excel
#
# Adds automatic Excel open after export.
#
# Produces:
#   • Groups        – one row per PropGroup
#   • GroupMembers  – one row per (Group, Member Prop)
#   • TagsIndex     – all unique Tags with role info
#
# Requires: pandas, openpyxl
# Install once via:  pip install pandas openpyxl

import xml.etree.ElementTree as ET
from pathlib import Path
import pandas as pd
from collections import defaultdict
import tkinter as tk
from tkinter import filedialog, messagebox
import os
import subprocess


def parse_lorprev(path: Path):
    tree = ET.parse(path)
    root = tree.getroot()
    if root.tag != "PreviewClass":
        raise ValueError(f"Unexpected root tag {root.tag!r}, expected 'PreviewClass'")
    props = {p.get("id"): p for p in root.findall("PropClass")}
    groups = list(root.findall("PropGroup"))
    return props, groups


def build_groups_df(groups):
    rows = []
    for g in sorted(groups, key=lambda g: g.get("Tag") or ""):
        rows.append(
            {
                "GroupTag": g.get("Tag", ""),
                "GroupName": g.get("Name", ""),
                "GroupID": g.get("id", ""),
                "MemberCount": len(g.findall("member")),
            }
        )
    return pd.DataFrame(rows)


def build_group_members_df(groups, props):
    rows = []
    for g in sorted(groups, key=lambda g: g.get("Tag") or ""):
        for m in g.findall("member"):
            pid = m.get("id")
            p = props.get(pid)
            if not p:
                continue
            rows.append(
                {
                    "GroupTag": g.get("Tag", ""),
                    "GroupName": g.get("Name", ""),
                    "GroupID": g.get("id", ""),
                    "MemberPropTag": p.get("Tag", ""),
                    "MemberPropName": p.get("Name", ""),
                    "MemberPropID": pid,
                    "ChannelGrid": p.get("ChannelGrid", ""),
                    "DeviceType": p.get("DeviceType", ""),
                    "MaxChannels": p.get("MaxChannels", ""),
                }
            )
    return pd.DataFrame(rows)


def build_tags_index_df(groups, props):
    tag_roles = defaultdict(set)
    for p in props.values():
        t = p.get("Tag") or ""
        if t:
            tag_roles[t].add("prop")
    for g in groups:
        t = g.get("Tag") or ""
        if t:
            tag_roles[t].add("group")

    rows = []
    for tag in sorted(tag_roles.keys()):
        roles = tag_roles[tag]
        rows.append(
            {
                "Tag": tag,
                "IsProp": "Y" if "prop" in roles else "",
                "IsGroup": "Y" if "group" in roles else "",
                "Role": (
                    "prop-only"
                    if roles == {"prop"}
                    else "group-only"
                    if roles == {"group"}
                    else "prop+group"
                ),
            }
        )
    return pd.DataFrame(rows)


def pick_input_output():
    root = tk.Tk()
    root.withdraw()

    lorprev_path = filedialog.askopenfilename(
        title="Select Light-O-Rama .lorprev file",
        filetypes=[("LOR Preview Files", "*.lorprev"), ("All Files", "*.*")],
    )
    if not lorprev_path:
        return None, None

    default_name = Path(lorprev_path).stem + "_lor_groups.xlsx"
    out_path = filedialog.asksaveasfilename(
        title="Save Excel Workbook As",
        defaultextension=".xlsx",
        initialfile=default_name,
        filetypes=[("Excel Workbook", "*.xlsx")],
    )
    if not out_path:
        return lorprev_path, None

    return lorprev_path, out_path


def autofit(writer):
    """Auto-fit all columns (max width 60)."""
    for ws in writer.sheets.values():
        for col_cells in ws.columns:
            max_len = max(
                (len(str(c.value)) if c.value is not None else 0) for c in col_cells
            )
            ws.column_dimensions[col_cells[0].column_letter].width = min(
                max_len + 2, 60
            )


def open_excel(path: Path):
    """Open the resulting Excel file using the default system app."""
    try:
        if os.name == "nt":  # Windows
            os.startfile(path)
        else:  # macOS / Linux fallback
            subprocess.Popen(["open" if sys.platform == "darwin" else "xdg-open", path])
    except Exception as e:
        print(f"[WARN] Could not open Excel automatically: {e}")


def main():
    lorprev_file, out_file = pick_input_output()
    if not lorprev_file:
        print("No input selected.")
        return
    if not out_file:
        print("No output selected.")
        return

    lor_path = Path(lorprev_file)
    print(f"[INFO] Parsing: {lor_path.name}")

    try:
        props, groups = parse_lorprev(lor_path)
    except Exception as e:
        messagebox.showerror("Parse Error", f"Failed to parse {lor_path.name}\n\n{e}")
        return

    # Build dataframes
    groups_df = build_groups_df(groups)
    members_df = build_group_members_df(groups, props)
    tags_df = build_tags_index_df(groups, props)

    # Write Excel
    out_path = Path(out_file)
    with pd.ExcelWriter(out_path, engine="openpyxl") as writer:
        groups_df.to_excel(writer, index=False, sheet_name="Groups")
        members_df.to_excel(writer, index=False, sheet_name="GroupMembers")
        tags_df.to_excel(writer, index=False, sheet_name="TagsIndex")
        autofit(writer)

    messagebox.showinfo("Export Complete", f"Excel workbook created:\n{out_path}")
    print(f"[DONE] Excel written: {out_path}")

    open_excel(out_path)


if __name__ == "__main__":
    main()
