# preview_merger Documentation Pack (v1)

_Last updated: 2025‑09‑01 • Author: MSB Database Team • Owner: Greg Liebig_

This single doc contains:

1) **`preview_merger.md`** – user‑facing guide & workflow (with screenshot placeholders)  
2) **`REPORTING.md`** – how the history DB is structured + ready‑to‑run SQL & a Python reporter  
3) **`CODE_COMMENTS_GUIDE.md`** – comment style, docstrings, commit message format  
4) **`CHANGELOG.md`** – lightweight template for repo history  

---

## 1) `preview_merger.md`

### Overview
`preview_merger.py` consolidates Light‑O‑Rama preview assets and safely merges updates into the v6+ SQLite database used by wiring and inventory views. It also records a full audit trail to a separate history database so we can answer _who changed what and when_.

- **Inputs**: one or more `.lorprev` files and/or folders  
- **Primary DB**: `G:\Shared drives\MSB Database\database\lor_output_v6.db`  
- **History DB**: `G:\Shared drives\MSB Database\database\merger\preview_history.db`  
- **Modes**: Dry‑run (default), Apply (`--apply`), Report (`--report`)  

### Common CLI
```bash
# Dry‑run: parse files, compute diffs, write nothing to primary DB
python preview_merger.py --input "G:\\Shared drives\\MSB Database\\Database Previews" \
                         --history-db "G:\\Shared drives\\MSB Database\\database\\merger\\preview_history.db"

# Apply changes: writes to primary DB and logs every change to history DB
python preview_merger.py --input "…\Database Previews" --apply \
                         --history-db "…\database\merger\preview_history.db"

# Generate reports from the history DB (CSV + HTML into a dated folder)
python preview_merger.py --report \
  --history-db "…\database\merger\preview_history.db" \
  --report-out "…\database\merger\reports"
```

### Windows setup & how to run (no Python experience)
**Scripts live on your PC; data lives on the shared G: drive.** Default run is dry‑run.

1) **Install Python (once)**
   - Go to python.org → Download **Windows (64‑bit)** Python **3.11+**.
   - Run the installer and **check** “Add python.exe to PATH”.
   - Verify in PowerShell: `py -V` (should print `Python 3.x.y`). No extra packages are needed.

2) **Get the scripts (keep them updated)**
   - **Recommended (Git for Windows):** Install Git, then in PowerShell:
     ```powershell
     mkdir C:\MSB-Tools 2>$null; cd C:\MSB-Tools
     git clone https://github.com/Gregovate/MSB-Production-Database-Project.git msb-database
     cd msb-database
     git pull  # use later to update to the latest stable
     ```
   - **No‑Git option (ZIP):** Click "Download ZIP" on the repo, unzip to `C:\MSB-Tools\msb-database`. Repeat when you need updates.

3) **Confirm the shared drive is ready**
   - Google Drive for desktop is signed in and **G:** is mounted.
   - Folders exist:
     - `G:\Shared drives\MSB Database\UserPreviewStaging\<username>` (your exports)
     - `G:\Shared drives\MSB Database\Database Previews` (staging)
     - `G:\Shared drives\MSB Database\database\merger\preview_history.db` (history)

4) **Run a dry‑run (safe)**
   - In PowerShell, `cd` to where the script is (e.g., `C:\MSB-Tools\msb-database`):
     ```powershell
     py preview_merger.py
     ```
   - Open the HTML report at:
     `G:\Shared drives\MSB Database\database\merger\reports\lorprev_compare.html`

5) **Apply when the report looks good**
   ```powershell
   py preview_merger.py --apply
   ```

6) **(Optional) One‑click helpers** – create these files next to the script:
   - `run_preview_merger_dryrun.cmd`
     ```bat
     @echo off
     pushd %~dp0
     py preview_merger.py
     pause
     ```
   - `run_preview_merger_apply.cmd`
     ```bat
     @echo off
     pushd %~dp0
     py preview_merger.py --apply
     pause
     ```

> Tip: The script already knows the G: paths via its built‑in defaults. You should not need to pass any flags for normal use.

**Update scripts later (one click):** create `update_scripts.cmd`
```bat
@echo off
pushd %~dp0
if exist .git (
  git pull --ff-only
) else (
  echo This folder is not a Git clone. Re-download the ZIP from:
  echo https://github.com/Gregovate/MSB-Production-Database-Project
)
pause
```

#### Key Flags
- `--input PATH` – file or folder; repeatable  
- `--apply` – perform DB writes (otherwise dry‑run)  
- `--stage-id 007` – optional: limit/override Stage filter  
- `--history-db PATH` – where audit trail lives  
- `--report` / `--report-out PATH` – run canned reports  
- `--debug` – verbose logs (stderr)

### What gets logged to History
For each applied change, the tool writes a **row per atomic update** (e.g., a prop rename is one row; a new subprop expansion yields one row per subprop). See **REPORTING.md** for schema.

### Typical Workflow (team)
1. **Prep & Sync**  
   - Pull latest repo; confirm `lor_output_v6.db` is not locked.  
   - Confirm history DB path exists: `…\database\merger\preview_history.db`.
2. **Dry‑Run Merge**  
   - Run without `--apply` to see the change summary.  
   - Review terminal summary + `preview_merger_dryrun.csv` (auto‑written to `tmp/`).
3. **Apply Merge**  
   - Re‑run with `--apply`.  
   - Changes are committed to primary DB; audit rows go to history DB with a single `batch_id`.
4. **Generate Reports**  
   - `--report --report-out …\reports`  
   - Share the HTML summary and CSVs with the app team & stage leads.
5. **Archive Sources** (optional)  
   - Source `.lorprev` archived under dated folder `…\merger\archive\YYYYMMDD-HHMM`.

### Screenshots & Anchors (placeholders)
>
> Replace placeholders with your images. Keep filenames stable so links don’t break.

- `img/pm_cli_overview.png` – CLI arguments annotated  
- `img/pm_dry_run_summary.png` – dry‑run output sample  
- `img/pm_apply_summary.png` – applied changes summary  
- `img/pm_report_html.png` – HTML report index  

### FAQ

- **Q:** I ran with `--apply`. How do I know what changed?  
  **A:** Each run gets a `batch_id`. Use **REPORTING.md → “Find a batch by timestamp”** or run `--report` to see per‑batch HTML/CSV.

- **Q:** Can I undo a specific change?  
  **A:** Use history rows (old/new values) to craft a corrective update. If you stored `diff_json`, a small helper can re‑apply old values (see `REPORTING.md` → “Rollback helpers”).

---

## 2) `REPORTING.md`

### Purpose
Provide a dependable audit trail and simple, copy‑pasteable queries that answer:
- What changed in the last N days?
- Which previews/props churn the most?
- Who made the change, from which source file, and in which batch?
- Exactly which field changed from X → Y?

### Proposed Schema (SQLite)
> If your existing schema differs, adjust the view definitions below (keep column aliases intact).

```sql
-- Batches group all change rows from a single run of preview_merger.py
CREATE TABLE IF NOT EXISTS batches (
  batch_id      TEXT PRIMARY KEY,
  started_utc   TEXT NOT NULL,
  finished_utc  TEXT,
  run_mode      TEXT,            -- 'dry-run' or 'apply'
  user_name     TEXT,            -- from OS/env/arg
  host_name     TEXT,
  tool_version  TEXT,
  notes         TEXT
);

-- One row per atomic change
CREATE TABLE IF NOT EXISTS changes (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  batch_id      TEXT NOT NULL,   -- FK → batches.batch_id
  ts_utc        TEXT NOT NULL,
  user_name     TEXT,
  action        TEXT NOT NULL,   -- e.g., 'INSERT','UPDATE','DELETE','RENAME','UPSERT'
  entity_type   TEXT NOT NULL,   -- e.g., 'PREVIEW','PROP','SUBPROP','CHANNEL','ALIAS'
  preview_id    TEXT,            -- guid from .lorprev
  stage_id      TEXT,
  key           TEXT,            -- stable identity within preview (e.g., PropID or ScopedKey)
  field         TEXT,            -- column/attribute changed
  old_value     TEXT,
  new_value     TEXT,
  diff_json     TEXT,            -- optional: structured before/after
  source_file   TEXT,            -- path to .lorprev processed
  note          TEXT
);

CREATE INDEX IF NOT EXISTS idx_changes_batch ON changes(batch_id);
CREATE INDEX IF NOT EXISTS idx_changes_preview ON changes(preview_id);
CREATE INDEX IF NOT EXISTS idx_changes_key ON changes(key);
CREATE INDEX IF NOT EXISTS idx_changes_ts ON changes(ts_utc);
```

#### Minimal Writer API in `preview_merger.py`
```python
write_change(
  batch_id, ts_utc, user_name, action,
  entity_type, preview_id, stage_id, key,
  field, old_value, new_value, diff_json, source_file, note
)
```

### Canonical Views

```sql
-- v_changes_recent: last 30 days (edit window as needed)
CREATE VIEW IF NOT EXISTS v_changes_recent AS
SELECT *
FROM changes
WHERE ts_utc >= datetime('now','-30 days');

-- v_change_summary_by_preview: counts per preview
CREATE VIEW IF NOT EXISTS v_change_summary_by_preview AS
SELECT preview_id,
       COUNT(*) AS change_count,
       MIN(ts_utc) AS first_change,
       MAX(ts_utc) AS last_change
FROM changes
GROUP BY preview_id;

-- v_prop_churn: entities with most field flips
CREATE VIEW IF NOT EXISTS v_prop_churn AS
SELECT preview_id, key, COUNT(*) AS change_events,
       SUM(CASE WHEN field='Name' AND old_value<>new_value THEN 1 ELSE 0 END) AS renames,
       SUM(CASE WHEN field IN ('Network','Controller','StartChannel') AND old_value<>new_value THEN 1 ELSE 0 END) AS rewires
FROM changes
GROUP BY preview_id, key
ORDER BY change_events DESC;

-- v_batches: quick batch info
CREATE VIEW IF NOT EXISTS v_batches AS
SELECT b.batch_id, b.started_utc, b.finished_utc, b.run_mode, b.user_name,
       (SELECT COUNT(*) FROM changes c WHERE c.batch_id=b.batch_id) AS rowcount
FROM batches b
ORDER BY b.started_utc DESC;
```

### Ready‑to‑Run Queries

**1) Find a batch by a rough time window**
```sql
SELECT * FROM v_batches
WHERE started_utc BETWEEN '2025-09-01 00:00:00' AND '2025-09-01 23:59:59';
```

**2) Show all changes inside a batch (most recent first)**
```sql
SELECT ts_utc, action, entity_type, preview_id, key, field, old_value, new_value, source_file
FROM changes
WHERE batch_id = :batch
ORDER BY ts_utc DESC, id DESC;
```

**3) Daily digest (last 7 days)**
```sql
SELECT DATE(ts_utc) AS day, COUNT(*) AS changes
FROM changes
WHERE ts_utc >= datetime('now','-7 days')
GROUP BY day
ORDER BY day DESC;
```

**4) Top churn props (last 30 days)**
```sql
SELECT * FROM v_prop_churn
WHERE preview_id = :preview
ORDER BY change_events DESC
LIMIT 50;
```

**5) Rewire activity by stage**
```sql
SELECT stage_id,
       SUM(CASE WHEN field IN ('Network','Controller','StartChannel') AND old_value<>new_value THEN 1 ELSE 0 END) AS rewires
FROM changes
GROUP BY stage_id
ORDER BY rewires DESC;
```

**6) Who changed what**
```sql
SELECT user_name, COUNT(*) AS changes,
       MIN(ts_utc) AS first, MAX(ts_utc) AS last
FROM changes
GROUP BY user_name
ORDER BY changes DESC;
```

**7) Exact rename map for a prop key**
```sql
SELECT ts_utc, old_value AS old_name, new_value AS new_name
FROM changes
WHERE key = :prop_key AND field = 'Name'
ORDER BY ts_utc;
```

### Rollback Helpers (concept)
1. Locate the batch and affected rows.
2. For each row, swap `old_value` back into the relevant DB column.  
   - If `diff_json` exists, parse and apply multiple fields atomically.  
3. Record the corrective action as a **new** batch.

> Keep rollback as an explicit script (`tools/rollback_from_history.py`) to avoid accidental mass reverts.

### Python Reporter (HTML + CSV)
Save as `tools/report_preview_history.py` and wire `--report` to call it.

```python
#!/usr/bin/env python3
import sqlite3, csv, os, sys, datetime, json
from pathlib import Path

DEF_OUT = Path(r"G:\\Shared drives\\MSB Database\\database\\merger\\reports")

QUERIES = {
  'batches': "SELECT * FROM v_batches;",
  'daily_7d': "SELECT DATE(ts_utc) AS day, COUNT(*) AS changes FROM changes WHERE ts_utc >= datetime('now','-7 days') GROUP BY day ORDER BY day DESC;",
  'top_churn': "SELECT * FROM v_prop_churn ORDER BY change_events DESC LIMIT 200;",
}

HTML_BLOCK = """
<!doctype html><meta charset="utf-8"><title>Preview History Report</title>
<h1>Preview History – {stamp}</h1>
<ul>
<li><a href="batches.csv">batches.csv</a></li>
<li><a href="daily_7d.csv">daily_7d.csv</a></li>
<li><a href="top_churn.csv">top_churn.csv</a></li>
</ul>
<p>Source: {db}</p>
"""

def export_csv(cur, sql, path):
    cur.execute(sql)
    cols = [d[0] for d in cur.description]
    with open(path, 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f)
        w.writerow(cols)
        for row in cur.fetchall():
            w.writerow(row)


def main(db_path, out_dir=None):
    out = Path(out_dir or DEF_OUT) / datetime.datetime.utcnow().strftime('%Y%m%d-%H%M')
    out.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(db_path)
    cur = con.cursor()
    # Ensure views exist (no‑ops if created by the tool already)
    cur.executescript('''
      CREATE VIEW IF NOT EXISTS v_batches AS
      SELECT b.batch_id, b.started_utc, b.finished_utc, b.run_mode, b.user_name,
             (SELECT COUNT(*) FROM changes c WHERE c.batch_id=b.batch_id) AS rowcount
      FROM batches b ORDER BY b.started_utc DESC;

      CREATE VIEW IF NOT EXISTS v_prop_churn AS
      SELECT preview_id, key, COUNT(*) AS change_events,
             SUM(CASE WHEN field='Name' AND old_value<>new_value THEN 1 ELSE 0 END) AS renames,
             SUM(CASE WHEN field IN ('Network','Controller','StartChannel') AND old_value<>new_value THEN 1 ELSE 0 END) AS rewires
      FROM changes GROUP BY preview_id, key ORDER BY change_events DESC;
    ''')
    con.commit()

    for name, sql in QUERIES.items():
        export_csv(cur, sql, out / f"{name}.csv")

    (out / 'index.html').write_text(HTML_BLOCK.format(
        stamp=datetime.datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC'), db=db_path
    ), encoding='utf-8')

    print(f"Report written to: {out}")

if __name__ == '__main__':
    db = sys.argv[1] if len(sys.argv) > 1 else r"G:\\Shared drives\\MSB Database\\database\\merger\\preview_history.db"
    out = sys.argv[2] if len(sys.argv) > 2 else None
    main(db, out)
```

---

## 3) `CODE_COMMENTS_GUIDE.md`

### Header Block (add to every Python file)
```python
"""
File: preview_merger.py
Purpose: Merge .lorprev updates into primary DB with full audit logging.
Owner: Greg Liebig • Team: MSB Database
Revision: 2025‑09‑01 (v6.1)

Key Paths
  - Primary DB: G:\\Shared drives\\MSB Database\\database\\lor_output_v6.db
  - History DB: G:\\Shared drives\\MSB Database\\database\\merger\\preview_history.db

Notes
  - Do not process records with blank comments.
  - Use channel name as description for parsed props where appropriate.
"""
```

### Docstrings (functions)
Use short **what/why** up top; arguments and returns; side‑effects; invariants.

```python
def write_change(batch_id: str, *, action: str, entity_type: str, key: str, field: str,
                 old_value: str|None, new_value: str|None, preview_id: str|None,
                 stage_id: str|None, source_file: str|None, note: str|None=None) -> None:
    """Append one audit row to the history DB.

    Why: Centralized writer keeps the audit schema stable and guarantees indexes/constraints.
    Args:
      batch_id: Stable id for this run (e.g., UTC timestamp + host).
      action: 'INSERT' | 'UPDATE' | 'DELETE' | 'RENAME' | 'UPSERT'.
      entity_type: 'PREVIEW' | 'PROP' | 'SUBPROP' | 'CHANNEL' | 'ALIAS'.
      key: Stable entity identity (scoped to preview); see identity_key().
      field: Column/attribute that changed (e.g., 'Name', 'Network').
      old_value/new_value: Before/after values as strings; may be NULL for inserts/deletes.
      preview_id, stage_id: Optional scoping for reporting.
      source_file: Path to the .lorprev where change originated.
      note: Optional human note (e.g., migration reason).
    Returns: None. Commits immediately (single‑row transaction).
    Side‑effects: Ensures indexes exist once per process (idempotent).
    """
```

### Inline Commenting
- **Explain intent**, not the obvious syntax.  
- **Mark decision points**: `# RULE:`, `# SAFETY:`, `# COMPAT:` prefixes.  
- **Keep TODOs actionable** with owner + date: `# TODO[GL 2025‑09‑01]: Break out history writer into module.`

### Commit Message Template
```
feat(merger): batch logging + reports; doc pass

- add history schema (batches, changes) + writer
- wire --report → tools/report_preview_history.py
- docs: preview_merger.md, REPORTING.md, comments guide
- guard: ignore blank LOR comments; stage filter; dry‑run CSV

Refs: #msbdb‑merger, v6‑wiring‑views
```

---

## 4) `CHANGELOG.md`

```
# Changelog – MSB Production Database

## [v6.1] – 2025‑09‑01
### Added
- History DB schema (batches, changes) and writer in preview_merger.py
- HTML/CSV reporting via --report (tools/report_preview_history.py)
- Documentation pack (user guide, reporting, code comments)

### Changed
- Dry‑run output now saves to tmp/preview_merger_dryrun.csv

### Fixed
- Respect 'do not process blank comment' rule consistently in merger path

---
```

---

## Appendix: Simple ERD (ASCII)
```
+----------+             +-----------+
| batches  | 1        n  |  changes  |
+----------+-------------+-----------+
| batch_id |<------------| batch_id  |
| started  |             | id (PK)   |
| finished |             | ts_utc    |
| run_mode |             | action    |
| user     |             | entity    |
| host     |             | preview_id|
| version  |             | stage_id  |
| notes    |             | key       |
+----------+             | field     |
                         | old_value |
                         | new_value |
                         | diff_json |
                         | source    |
                         | note      |
                         +-----------+
```



## Appendix: Future TODOs

- **Defer centralized writer:** The `write_change(...)` example docstring is **not** for current use. Marking this as a future TODO.
- **Future helper functions (post v6.2):** Consider adding small logging helpers that match the current schema and local‑time policy:
  - `log_run_start(conn, run_id, started_local, policy)` → inserts into `runs`.
  - `log_file_observation(conn, run_id, candidate)` → inserts into `file_observations`.
  - `log_staging_decision(conn, run_id, preview_key, winner_path, staged_as, reason, conflict, action)` → inserts into `staging_decisions`.
- **Scope of future work:** Only add these after the team validates the new reporting flow; keep all timestamps **local** (no UTC) and keep the per‑user export path requirement in docs.

