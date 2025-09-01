# Reporting & History (v1) — preview_history.db

_Companion to **MSB Preview Update — Operator Quickstart** and **Preview Merger — Reference**._

## Purpose
Track **who contributed which preview files**, when merges were applied, and what got staged/archived/skipped — using the local‑time audit DB at:
```
G:\Shared drives\MSB Database\database\merger\preview_history.db
```
All timestamps are **local, tz‑aware** strings. No UTC.

## Tables (as used by the tools)
```sql
PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON;

CREATE TABLE IF NOT EXISTS runs (
  run_id   TEXT PRIMARY KEY,
  started  TEXT NOT NULL,   -- local ISO with offset, e.g., 2025-09-01T12:04:45-05:00
  policy   TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS file_observations (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id       TEXT NOT NULL,
  user         TEXT,
  user_email   TEXT,
  path         TEXT,
  file_name    TEXT,
  preview_key  TEXT,
  preview_guid TEXT,
  preview_name TEXT,
  revision_raw TEXT,
  revision_num REAL,
  file_size    INTEGER,
  exported     TEXT NOT NULL,  -- local ISO with offset
  sha256       TEXT NOT NULL,
  FOREIGN KEY(run_id) REFERENCES runs(run_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS staging_decisions (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id          TEXT NOT NULL,
  preview_key     TEXT NOT NULL,
  winner_path     TEXT,
  staged_as       TEXT,
  decision_reason TEXT,
  conflict        INTEGER DEFAULT 0,
  action          TEXT  -- staged | skipped | archived
);

CREATE TABLE IF NOT EXISTS preview_state (
  preview_key  TEXT PRIMARY KEY,
  preview_guid TEXT,
  preview_name TEXT,
  revision_num REAL,
  sha256       TEXT,
  staged_as    TEXT,
  last_run_id  TEXT,
  last_seen    TEXT  -- local ISO with offset
);

CREATE INDEX IF NOT EXISTS idx_obs_run_id        ON file_observations(run_id);
CREATE INDEX IF NOT EXISTS idx_obs_preview_guid  ON file_observations(preview_guid);
CREATE INDEX IF NOT EXISTS idx_obs_sha256        ON file_observations(sha256);
CREATE INDEX IF NOT EXISTS idx_decisions_run_id  ON staging_decisions(run_id);
```

## Canned views (paste once; idempotent)
```sql
-- High-level summary per run
CREATE VIEW IF NOT EXISTS v_runs_summary AS
SELECT r.run_id, r.started, r.policy,
  (SELECT COUNT(*) FROM file_observations fo WHERE fo.run_id=r.run_id) AS observed,
  (SELECT COUNT(*) FROM staging_decisions sd WHERE sd.run_id=r.run_id AND sd.action='staged')   AS staged,
  (SELECT COUNT(*) FROM staging_decisions sd WHERE sd.run_id=r.run_id AND sd.action='skipped')  AS skipped,
  (SELECT COUNT(*) FROM staging_decisions sd WHERE sd.run_id=r.run_id AND sd.action='archived') AS archived
FROM runs r
ORDER BY r.started DESC;

-- Contributors per run
CREATE VIEW IF NOT EXISTS v_run_contributors AS
SELECT fo.run_id, fo.user, COUNT(*) AS files, SUM(fo.file_size) AS bytes
FROM file_observations fo
GROUP BY fo.run_id, fo.user
ORDER BY fo.run_id DESC, files DESC;

-- What was staged in a run
CREATE VIEW IF NOT EXISTS v_staged_in_run AS
SELECT sd.run_id, sd.preview_key, sd.staged_as, sd.decision_reason, sd.conflict
FROM staging_decisions sd
WHERE sd.action='staged'
ORDER BY sd.run_id DESC;
```

## Ready-to-run queries
**Latest run summary**
```sql
SELECT * FROM v_runs_summary LIMIT 1;
```
**Actions in the most recent applied run**
```sql
WITH last_applied AS (
  SELECT run_id FROM runs
  WHERE run_id IN (SELECT DISTINCT run_id FROM staging_decisions)
  ORDER BY started DESC LIMIT 1
)
SELECT action, COUNT(*) FROM staging_decisions
WHERE run_id=(SELECT run_id FROM last_applied)
GROUP BY action;
```
**Conflicts in recent applies**
```sql
SELECT * FROM staging_decisions WHERE conflict=1 ORDER BY run_id DESC, id DESC;
```
**Top contributors in a given run**
```sql
SELECT * FROM v_run_contributors WHERE run_id=:run;
```

## Reporter tool
Generate CSVs + `index.html` under:
```
G:\Shared drives\MSB Database\database\merger\reports\YYYYMMDD-HHMM\
```

**tools/report_preview_history.py**
```python
#!/usr/bin/env python3
import sqlite3, csv, sys, datetime
from pathlib import Path

DEF_DB  = r"G:\\Shared drives\\MSB Database\\database\\merger\\preview_history.db"
DEF_OUT = r"G:\\Shared drives\\MSB Database\\database\\merger\\reports"

QUERIES = {
    "runs_summary":      "SELECT * FROM v_runs_summary;",
    "contributors_last": "SELECT * FROM v_run_contributors;",
    "staged_last":       "SELECT * FROM v_staged_in_run;",
}

HTML = """<!doctype html><meta charset=\"utf-8\"><title>Preview History</title>
<h1>Preview History – {ts}</h1>
<ul>
  <li><a href=\"runs_summary.csv\">runs_summary.csv</a></li>
  <li><a href=\"contributors_last.csv\">contributors_last.csv</a></li>
  <li><a href=\"staged_last.csv\">staged_last.csv</a></li>
</ul>
<p>DB: {db}</p>"""

def export_csv(cur, sql, path: Path) -> None:
    cur.execute(sql)
    cols = [d[0] for d in cur.description]
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f); w.writerow(cols); w.writerows(cur.fetchall())

def main(db: str = DEF_DB, out_root: str = DEF_OUT) -> None:
    out_dir = Path(out_root) / datetime.datetime.now().strftime("%Y%m%d-%H%M")
    out_dir.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(db); cur = con.cursor()
    cur.executescript('''
      CREATE VIEW IF NOT EXISTS v_runs_summary AS
      SELECT r.run_id, r.started, r.policy,
        (SELECT COUNT(*) FROM file_observations fo WHERE fo.run_id=r.run_id) AS observed,
        (SELECT COUNT(*) FROM staging_decisions sd WHERE sd.run_id=r.run_id AND sd.action='staged')   AS staged,
        (SELECT COUNT(*) FROM staging_decisions sd WHERE sd.run_id=r.run_id AND sd.action='skipped')  AS skipped,
        (SELECT COUNT(*) FROM staging_decisions sd WHERE sd.run_id=r.run_id AND sd.action='archived') AS archived
      FROM runs r ORDER BY r.started DESC;

      CREATE VIEW IF NOT EXISTS v_run_contributors AS
      SELECT fo.run_id, fo.user, COUNT(*) AS files, SUM(fo.file_size) AS bytes
      FROM file_observations fo GROUP BY fo.run_id, fo.user
      ORDER BY fo.run_id DESC, files DESC;

      CREATE VIEW IF NOT EXISTS v_staged_in_run AS
      SELECT sd.run_id, sd.preview_key, sd.staged_as, sd.decision_reason, sd.conflict
      FROM staging_decisions sd WHERE sd.action='staged' ORDER BY run_id DESC;
    ''')
    con.commit()

    for name, sql in QUERIES.items():
        export_csv(cur, sql, out_dir / f"{name}.csv")

    (out_dir / "index.html").write_text(
        HTML.format(ts=datetime.datetime.now().strftime("%Y-%m-%d %H:%M"), db=db),
        encoding="utf-8"
    )

    print(f"Report written to: {out_dir}")

if __name__ == "__main__":
    db  = sys.argv[1] if len(sys.argv) > 1 else DEF_DB
    out = sys.argv[2] if len(sys.argv) > 2 else DEF_OUT
    main(db, out)
```

**helpers/report_preview_history.cmd** (optional)
```bat
@echo off
pushd %~dp0\..
py tools\report_preview_history.py
set "R=G:\Shared drives\MSB Database\database\merger\reports"
for /f "delims=" %%D in ('dir /b /ad /o-d "%R%"') do (
  if exist "%R%\%%D\index.html" start "" "%R%\%%D\index.html" & goto :done
)
:done
pause
```

## Reading the outputs
- **runs_summary.csv** — run IDs, start time, policy, and counts (observed/staged/skipped/archived).
- **contributors_last.csv** — per‑run list of users who supplied files (count, bytes).
- **staged_last.csv** — items actually staged in the latest applied run (with conflict flag).

## FAQ
- **Does this touch the live previews?** No. Reporter is read‑only; it creates files under `/reports/`.
- **What if views are missing?** The reporter will create them automatically.
- **Privacy**: `user_email` is used only for audit; avoid exporting or sharing this column outside the team.

## Future (optional)
- Add a `rollback_staged.py` helper that restores a prior file by SHA from `.bak` or `archive/` and logs a `staging_decisions` row with `action='rollback'`.

