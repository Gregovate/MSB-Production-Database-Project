from pathlib import Path
import csv
import re

# GAL 2025-11-10: Build Stage Master from directory names
ROOT = Path(r"G:\Shared drives\Display Folders")
OUT  = Path(r"G:\Shared drives\MSB Database\Spreadsheet\stage_master.csv")

stage_pattern = re.compile(r"^(\d{2})-([^-]+)-([A-Z]{2})$", re.IGNORECASE)
rows = []

for folder in ROOT.iterdir():
    if not folder.is_dir():
        continue
    m = stage_pattern.match(folder.name)
    if not m:
        continue
    stage_id, name, code = m.groups()
    stage_id = f"{int(stage_id):02d}"
    name = name.strip()
    code = code.upper()
    rows.append({
        "StageID": stage_id,
        "StageKey": f"{stage_id}-{name}-{code}",
        "StageName": name,
        "ShortCode": code,
        "FolderName": folder.name,
        "FolderPath": str(folder)
    })

rows.sort(key=lambda r: int(r["StageID"]))

OUT.parent.mkdir(parents=True, exist_ok=True)
with OUT.open("w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
    writer.writeheader()
    writer.writerows(rows)

print(f"[INFO] Wrote {len(rows)} stages → {OUT}")
