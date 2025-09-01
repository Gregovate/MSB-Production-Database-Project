# preview_merger Documentation Pack (v2)

_Last updated: 2025-09-01 • Owner: Greg Liebig • Team: MSB Database_

This pack contains:

1) **`preview_merger.md`** – user guide, **must‑do user export location**, dry‑run default, report interpretation.  
2) **`REPORTING.md`** – **current** history DB schema (from script), local‑time stamps (no UTC), ready SQL, a reporter script.  
3) **`CODE_COMMENTS_GUIDE.md`** – comment/docstring style that captures our rules (DeviceType=None, comments, user export path).  
4) **`CHANGELOG.md`** – deltas since v1.

---

## 1) `preview_merger.md`

### What it does
`preview_merger.py` scans **per‑user** preview exports (`*.lorprev`), groups by **preview Key** (GUID preferred), picks a **WINNER**, compares to the current **STAGED** copy, and writes CSV/HTML reports. With `--apply`, it stages the winner and archives non‑winners.

**Time zone**: All timestamps are **local, tz‑aware** (e.g., `2025‑09‑01T12:04:45‑0500`). We do **not** use UTC.  
**Default run mode**: **Dry‑run** (no staging). Add `--apply` to perform file copies.

### Must‑do: where users save exports (critical)
Every user must export previews to their **own folder**:

```
G:\\Shared drives\\MSB Database\\UserPreviewStaging\\<username>\\*.lorprev
```

The tool only looks under `UserPreviewStaging` for user files and writes staged/copied winners to the **top level** of:

```
G:\\Shared drives\\MSB Database\\Database Previews
```

> If your folder doesn’t exist, the script will create it (it also seeds a few known users). But you still need to export your preview **there** before running.

### Quick start (dry‑run first)
```bash
# Dry‑run: builds CSV/HTML reports, no changes to staged files
py preview_merger.py

# Apply: copy winners into staging and archive non‑winners
py preview_merger.py --apply
```

Optional flags: `--policy`, `--force-winner`, `--user-map`, `--report`, `--report-html`, `--debug`, `--no-progress`.

### Default policy
Default is **`prefer-comments-then-revision`** (matches the script’s `GLOBAL_DEFAULTS`).

Tie‑breakers, in order:
1) Highest **CommentNoSpace** (stricter “real comments” count).  
2) Highest numeric **Revision**.  
3) Best fill ratio **CommentFilled/CommentTotal**.  
4) Latest **Exported** time.  
5) Deterministic path name.

Alternate: `prefer-revision-then-exported` or `prefer-exported`.

### How to read the report
Reports live in:
- CSV: `G:\\Shared drives\\MSB Database\\database\\merger\\reports\\lorprev_compare.csv`  
- HTML: `G:\\Shared drives\\MSB Database\\database\\merger\\reports\\lorprev_compare.html`  
- Missing‑comments CSV: `...\\reports\\lorprev_missing_comments.csv`

Each **preview Key** can show:
- **WINNER** – chosen user file.  
- **STAGED** – current staged file (top‑level only).  
- **CANDIDATE** – other user files for the same Key.  
- Tail **STAGED‑ONLY** – staged files with no matching user candidate this run.

**Columns you’ll use the most**
- **Key** – `GUID:<guid>` when available, else `NAME:<lowercased name>`.  
- **GUID** – parsed GUID string from the file.  
- **CommentFilled / CommentTotal / CommentNoSpace** – comment coverage: we count non‑empty values and separately the **no‑space** subset to enforce the _no spaces in DisplayName_ convention.
- **Action** (on WINNER): `noop` (identical to staged), `update-staging` (will overwrite), `stage-new` (no staged match).
- **Action** (on STAGED): `current`, `out-of-date`, `staged-only`.

#### Breaking‑change check (GUID)
- If a preview’s **GUID** changes (or the **Key** flips from a GUID to a name), that usually means the **preview structure** changed (channel names/assignments). This can affect **older sequences** and may be a **breaking change**. Treat such updates with caution; verify in Form View before applying.

#### Comment quality rule (DeviceType=None)
- We **ignore blank comments** for props whose `DeviceType` is **`None`** (as set by Sequencer). The missing‑comments scan also **skips** any staged `.lorprev` containing `DeviceType="None"` so these do not inflate “missing” counts. This matches the script’s behavior.

#### Is my naming convention good?
- If **CommentNoSpace ≈ CommentFilled** and both are close to **CommentTotal**, your display names are likely in good shape. If **CommentNoSpace** lags, you probably have spaces or blanks in DisplayNames.

**Quick visual check**: open the preview in **`formview.py`** and scan the **DisplayName** column. If you see spaces or mismatches, fix the preview in Sequencer, **re‑export to your user folder**, and re‑run the merger.

> Real example: _Northern Lights_ required fixes to DisplayNames; see images in the repo for before/after.

### Team workflow
1) **Export** your updated preview(s) to `UserPreviewStaging\\<username>`.  
2) **Dry‑run**: `py preview_merger.py` → open the HTML/CSV.  
   - For any Key with GUID changes or weak comment coverage, review in `formview.py`, fix, and re‑export.  
3) **Re‑run dry‑run** to confirm most WINNER rows show `Action=noop` or desired updates.  
4) **Apply**: `py preview_merger.py --apply`.  
5) **Sanity check**: run once more (dry‑run) and confirm STAGED rows show `current` and winners show `noop`.

---

## 2) `REPORTING.md`

### What the history DB captures (current schema)
The script writes a **local‑time, tz‑aware** audit to:

```
G:\\Shared drives\\MSB Database\\database\\merger\\preview_history.db
```

Tables (exactly as in the script):

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

> `staging_decisions` rows are only written when you pass `--apply`. The CSV/HTML report is still available during dry‑runs.

### Handy views (paste once; idempotent)
```sql
-- Runs with quick counts
CREATE VIEW IF NOT EXISTS v_runs_summary AS
SELECT r.run_id, r.started, r.policy,
  (SELECT COUNT(*) FROM file_observations fo WHERE fo.run_id=r.run_id) AS observed,
  (SELECT COUNT(*) FROM staging_decisions sd WHERE sd.run_id=r.run_id AND sd.action='staged')   AS staged,
  (SELECT COUNT(*) FROM staging_decisions sd WHERE sd.run_id=r.run_id AND sd.action='skipped')  AS skipped,
  (SELECT COUNT(*) FROM staging_decisions sd WHERE sd.run_id=r.run_id AND sd.action='archived') AS archived
FROM runs r
ORDER BY r.started DESC;

-- Top contributors in a run
CREATE VIEW IF NOT EXISTS v_run_contributors AS
SELECT fo.run_id, fo.user, COUNT(*) AS files, SUM(fo.file_size) AS bytes
FROM file_observations fo
GROUP BY fo.run_id, fo.user
ORDER BY fo.run_id DESC, files DESC;

-- What we staged in a run
CREATE VIEW IF NOT EXISTS v_staged_in_run AS
SELECT sd.run_id, sd.preview_key, sd.staged_as, sd.decision_reason, sd.conflict
FROM staging_decisions sd
WHERE sd.action='staged'
ORDER BY sd.run_id DESC;
```

### Ready‑to‑run queries

**Latest run**
```sql
SELECT * FROM v_runs_summary LIMIT 1;
```

**Staged/archived/skipped in the latest applied run**
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

**Conflicts flagged during apply**
```sql
SELECT * FROM staging_decisions WHERE conflict=1 ORDER BY run_id DESC, id DESC;
```

**Who contributed what in a run**
```sql
SELECT * FROM v_run_contributors WHERE run_id=(SELECT run_id FROM v_runs_summary LIMIT 1);
```

### Reporter script (`tools/report_preview_history.py`)
Matches the current schema; emits an `index.html` and CSVs.

```python
#!/usr/bin/env python3
import sqlite3, csv, os, sys, datetime
from pathlib import Path

DEF_DB  = r"G:\\Shared drives\\MSB Database\\database\\merger\\preview_history.db"
DEF_OUT = r"G:\\Shared drives\\MSB Database\\database\\merger\\reports"

QUERIES = {
  'runs_summary':      'SELECT * FROM v_runs_summary;',
  'contributors_last': 'SELECT * FROM v_run_contributors;',
  'staged_last':       'SELECT * FROM v_staged_in_run;',
}

HTML = """<!doctype html><meta charset=utf-8><title>Preview History</title>
<h1>Preview History – {ts}</h1>
<ul>
  <li><a href=\"runs_summary.csv\">runs_summary.csv</a></li>
  <li><a href=\"contributors_last.csv\">contributors_last.csv</a></li>
  <li><a href=\"staged_last.csv\">staged_last.csv</a></li>
</ul>
<p>DB: {db}</p>"""

def export_csv(cur, sql, path):
    cur.execute(sql)
    cols = [d[0] for d in cur.description]
    with open(path, 'w', newline='', encoding='utf-8') as f:
        w = csv.writer(f); w.writerow(cols); w.writerows(cur.fetchall())

def main(db=DEF_DB, out_root=DEF_OUT):
    out = Path(out_root) / datetime.datetime.now().strftime('%Y%m%d-%H%M')
    out.mkdir(parents=True, exist_ok=True)
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
      FROM staging_decisions sd WHERE sd.action='staged' ORDER BY sd.run_id DESC;
    ''')
    con.commit()

    for name, sql in QUERIES.items():
        export_csv(cur, sql, out / f"{name}.csv")

    (out / 'index.html').write_text(HTML.format(ts=datetime.datetime.now().strftime('%Y-%m-%d %H:%M'), db=db), encoding='utf-8')
    print(f"Report written to: {out}")

if __name__ == '__main__':
    db = sys.argv[1] if len(sys.argv) > 1 else DEF_DB
    out = sys.argv[2] if len(sys.argv) > 2 else DEF_OUT
    main(db, out)
```

> Future enhancement: wire `preview_state` upserts after a successful `--apply` so we can diff against prior runs inside the DB (today, the per‑run **Change** label exists in the CSV/HTML only).

---

## 3) `CODE_COMMENTS_GUIDE.md`

### Header block
```python
"""
File: preview_merger.py
Purpose: Per‑user LOR preview staging + reporting (local‑time audit).
Owner: Greg Liebig • Team: MSB Database
Notes:
  - Users **must** export to G:\\Shared drives\\MSB Database\\UserPreviewStaging\\<user>.
  - Default run is **dry‑run**; pass --apply to stage files.
  - Time stamps are **local tz‑aware** strings (no UTC).
  - We **ignore blank comments** for props when DeviceType=="None".
  - Comment coverage uses three counters: CommentFilled, CommentTotal, CommentNoSpace.
"""
```

### Function docstrings
Keep them short and intentional — what/why/side‑effects. Example:
```python
def comment_stats(path: Path) -> tuple[int,int,int]:
    """Return (total, filled, no_space) comment counters for a .lorprev.

    Why: We need both raw coverage and the stricter no‑space metric that aligns with DisplayName rules.
    Side‑effects: None. Missing/invalid files return (0,0,0).
    """
```

### Inline conventions
- Use `# RULE:` for policy/eligibility logic (e.g., DeviceType==None skip).  
- Use `# SAFETY:` for filesystem protections (e.g., .bak creation on overwrite).  
- TODOs: `# TODO[GL 2025‑09‑01]: …`.

### Commit template
```
feat(merger): local‑time history DB + per‑user staging + report interpretation

- enforce UserPreviewStaging export path in docs
- default dry‑run; clarify --apply
- comment coverage (Filled/Total/NoSpace); DeviceType=None skip
- add GUID breaking‑change guidance and formview check
- align REPORTING.md with current schema; add reporter script
```

---

## 4) `CHANGELOG.md`

```
# Changelog – MSB Production Database

## [v6.2] – 2025‑09‑01
### Added
- Explicit per‑user export location requirement in docs.
- Report interpretation section: GUID breaking‑change check; comment coverage math; DeviceType=None skip.
- Reporter aligned to current `preview_history.db` schema with local‑time stamps.

### Changed
- Default policy documented as `prefer-comments-then-revision` to match script defaults.
- Rewrote REPORTING.md to reflect `runs`, `file_observations`, `staging_decisions`, `preview_state` tables.

### Future
- Rollback helpers (see below) and `preview_state` upserts post‑apply.
```

---

## Appendix: Rollback (future plan)
**Why**: Occasionally we’ll want to revert a staged file to a previous copy or undo an apply.

**What we already have**
- The script makes timestamped **`.bak`** files when it overwrites a different staged file.
- Non‑winning candidates can be optionally **archived** under `...\\database\\merger\\archive\\YYYY‑MM‑DD\\` when `--apply` is used.

**Lightweight rollback recipe (manual today)**
1) Locate the desired `.bak` in `Database Previews` or the archived non‑winner under `archive/`.
2) Copy it over the current staged file (keep a fresh `.bak` just in case).  
3) Re‑run `py preview_merger.py` (dry‑run) and confirm the STAGED row shows `current` and Winner `noop`.

**Potential automation**
- `tools/rollback_staged.py --key GUID:<...> --to <path or sha>` that finds a prior copy by SHA and restores it, then records a `staging_decisions` row with `action='rollback'`.

