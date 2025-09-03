#!/usr/bin/env python3
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

preview_merger.py — Windows‑friendly, per‑user .lorprev collector with conflict detection,
safe staging, and a history SQLite database for audit/reporting.

Now with **GLOBAL DEFAULTS** and optional **JSON config** so you can just run:

  py preview_merger.py

Override via CLI when needed. Precedence: CLI > JSON config > GLOBAL_DEFAULTS.

JSON config (optional):
  Same folder as this script, named `preview_merger.config.json`, e.g.:
  {
    "input_root": "G:/Shared drives/MSB Database/UserPreviewStaging",
    "staging_root": "G:/Shared drives/MSB Database/Database Previews",
    "archive_root": "G:/Shared drives/MSB Database/database/merger/archive",
    "history_db": "G:/Shared drives/MSB Database/database/merger/preview_history.db",
    "report_csv": "G:/Shared drives/MSB Database/database/merger/reports/lorprev_compare.csv",
    "report_html": "G:/Shared drives/MSB Database/database/merger/reports/lorprev_compare.html",
    "policy": "prefer-comments-then-revision"
    "ensure_users": "abiebel,rneerhof,gliebig,showpc,officepc",
    "email_domain": "sheboyganlights.org"
  }

(You can point to another file with --config <path>.)
"""
from __future__ import annotations

import argparse
import csv
import re
import hashlib
import json
import os
import sqlite3
import time
import socket  # used for ledger 25-09-03 GAL
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import xml.etree.ElementTree as ET
import shutil
import sys
import traceback  # (optional, if you print tracebacks elsewhere)

# ============================= GLOBAL DEFAULTS ============================= #
GLOBAL_DEFAULTS = {
    # Folders
    "input_root": r"G:\Shared drives\MSB Database\UserPreviewStaging",
    # "Secret" location used by LOR parser today
    "staging_root": r"G:\Shared drives\MSB Database\Database Previews",
    #"staging_root": r"G:\Shared drives\MSB Database\database\_secret_staging",
    # Keep merger artifacts under /database/merger
    "archive_root": r"G:\Shared drives\MSB Database\database\merger\archive",
    "history_db":   r"G:\Shared drives\MSB Database\database\merger\preview_history.db",
    "report_csv":   r"G:\Shared drives\MSB Database\database\merger\reports\lorprev_compare.csv",
    "report_html":  r"G:\Shared drives\MSB Database\database\merger\reports\lorprev_compare.html",
    # Behavior
    "policy": "prefer-comments-then-revision",
    # Users and email
    "ensure_users": "abiebel,rneerhof,gliebig,showpc,officepc",
    "email_domain": "sheboyganlights.org",
}

# ============================= Data models ============================= #

BLOCKED_ACTION = 'needs-DisplayName Fixes'

@dataclass
class PreviewIdentity:
    guid: Optional[str]
    name: Optional[str]
    revision_raw: Optional[str]
    revision_num: Optional[float]

@dataclass
class Candidate:
    key: str                    # "GUID:<guid>" or "NAME:<name>"
    identity: PreviewIdentity
    user: str                   # top-level folder name beneath input_root
    user_email: Optional[str]   # from mapping or domain
    path: str
    size: int
    mtime: float
    sha256: str
    c_total: int = 0            # total comment fields found
    c_filled: int = 0           # comment fields with non-empty value
    c_nospace: int = 0          # comment fields with no spaces

# ====================== Utilities / Helpers ============================ #


class Progress:
    def __init__(self, enabled: bool):
        self.enabled = enabled
        self.total = 1
        self.cur = 0
        self.label = ""

    def start(self, total: int, label: str):
        self.total = max(1, int(total or 1))
        self.cur = 0
        self.label = label
        if self.enabled:
            sys.stderr.write(f"{label}: 0/{self.total} (0%)\r")
            sys.stderr.flush()

    def tick(self, step: int = 1):
        if not self.enabled:
            return
        self.cur += step
        if self.cur > self.total:
            self.cur = self.total
        pct = int(self.cur * 100 / self.total)
        sys.stderr.write(f"{self.label}: {self.cur}/{self.total} ({pct:3d}%)\r")
        sys.stderr.flush()

    def done(self):
        if not self.enabled:
            return
        sys.stderr.write(" " * 80 + "\r")  # clear line
        sys.stderr.write(f"{self.label}: {self.total}/{self.total} (100%)\n")
        sys.stderr.flush()

def ensure_dir(p: Path) -> None:
    p.mkdir(parents=True, exist_ok=True)


def _fail_if_locked(paths: Iterable[Optional[Path]]) -> None:
    """Exit early if any *existing* report file is write-locked (e.g., open in Excel)."""
    locked = []
    for p in paths:
        if not p:
            continue
        p = Path(p)
        if not p.exists():
            continue  # only test existing files
        try:
            with p.open('a', encoding='utf-8-sig'):
                pass
        except PermissionError:
            locked.append(p)
    if locked:
        print("\n[locked] The following report files are open in another program:", file=sys.stderr)
        for p in locked:
            print(f"  - {p}", file=sys.stderr)
        print("[locked] Close them and run preview_merger.py again.", file=sys.stderr)
        sys.exit(4)  # distinct code: report outputs locked

# Ignore Device type = None for staged previews 25-09-01 GAL
from pathlib import Path
def device_type_is_none(p: Path) -> bool:
    """Best-effort check for DeviceType='None' inside a .lorprev (XML-ish) file."""
    try:
        with p.open('rb') as f:
            chunk = f.read(131072)  # 128KB is plenty for headers
        txt = chunk.decode('utf-8', errors='ignore')
        return ('DeviceType="None"' in txt) or ('deviceType="None"' in txt)
    except Exception:
        return False

# Time utilities
def now_local():
    """Return a timezone-aware local datetime."""
    # Use OS local time with offset (handles DST)
    return datetime.now().astimezone()
    # If forcing a specific zone:
    # return datetime.now(tz=LOCAL_TZ)

def ymd_hms(ts: float) -> str:
    """
    Format an epoch seconds timestamp in LOCAL time with offset,
    e.g. '2025-08-31 08:25:33-0500'
    """
    try:
        # OS local:
        dt = datetime.fromtimestamp(ts).astimezone()
        # Or forced zone:
        # dt = datetime.fromtimestamp(ts, tz=LOCAL_TZ)
        return dt.strftime('%Y-%m-%d %H:%M:%S%z')
    except Exception:
        return ''

def sanitize_name(s: str) -> str:
    return ''.join(ch if ch.isalnum() or ch in (' ', '-', '_', '.') else '_' for ch in s).strip()


def sha256_file(path: Path, chunk: int = 1 << 20) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        while True:
            b = f.read(chunk)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def parse_preview_identity(file_path: Path) -> Optional[PreviewIdentity]:
    try:
        tree = ET.parse(file_path)
        root = tree.getroot()
        for el in root.iter():
            if el.tag.endswith('PreviewClass'):
                guid = el.get('id') or None
                name = el.get('Name') or None
                rev  = el.get('Revision') or None
                try:
                    rev_num = float(rev) if rev is not None else None
                except Exception:
                    rev_num = None
                return PreviewIdentity(guid=guid, name=name, revision_raw=rev, revision_num=rev_num)
        return None
    except Exception:
        return None


def identity_key(idy: PreviewIdentity) -> Optional[str]:
    if idy.guid:
        return f"GUID:{idy.guid}"
    if idy.name:
        return f"NAME:{idy.name.strip().lower()}"
    return None

def comment_stats(path: Path) -> tuple[int, int, int]:
    """(total, filled, no_space) across comment-like attrs/tags."""
    try:
        root = ET.parse(path).getroot()
    except Exception:
        return (0, 0, 0)
    total = filled = nospace = 0
    attrs = ('Comment', 'LORComment', 'Comments')
    for el in root.iter():
        for a in attrs:
            if a in el.attrib:
                total += 1
                v = (el.attrib.get(a) or '').strip()
                if v:
                    filled += 1
                    if ' ' not in v:
                        nospace += 1
        tag = el.tag.split('}')[-1]
        if tag in ('Comment', 'Comments'):
            total += 1
            v = (el.text or '').strip()
            if v:
                filled += 1
                if ' ' not in v:
                    nospace += 1
    return total, filled, nospace

from pathlib import Path
def _in_dir(p: Path, root: Path) -> bool:
    try:
        Path(p).resolve().relative_to(Path(root).resolve())
        return True
    except Exception:
        return False

def scan_staged_for_comments(staging_root: Path) -> Dict[str, Dict]:
    """Return comment stats for every .lorprev currently staged, keyed by identity."""
    out: Dict[str, Dict] = {}
    if not staging_root.exists():
        return out
    for p in sorted(staging_root.glob('*.lorprev')):
        idy = parse_preview_identity(p)
        # If identity is unreadable, fall back to name-based key so it still shows up
        key = identity_key(idy) if idy else f"NAME:{p.stem.lower()}"
        if not key:
            key = f"NAME:{p.stem.lower()}"
        ct, cf, cn = comment_stats(p)
        stat = p.stat()
        out[key] = {
            'PreviewName': (idy.name if idy and idy.name else p.stem),
            'Revision': (idy.revision_raw if idy and idy.revision_raw else ''),
            'GUID': (idy.guid if idy and idy.guid else ''),
            'Size': stat.st_size,
            'MTimeUtc': ymd_hms(stat.st_mtime),
            'CommentTotal': ct,
            'CommentFilled': cf,
            'NoSpace': cn,
            'SHA256': sha256_file(p),
            'Path': str(p),
        }
    return out

def append_staged_row(key: str, staged_path: Path, winner: Candidate, rows: List[Dict]) -> None:
    """Append a STAGED row (with comment stats) using the new report columns."""
    try:
        st_stat = staged_path.stat()
        st_idy  = parse_preview_identity(staged_path) or PreviewIdentity(None, None, None, None)
        st_ct, st_cf, st_cn = comment_stats(staged_path)

        # Hashes (staged) + compare vs winner to set Action
        staged_sha  = sha256_file(staged_path)
        staged_sha8 = staged_sha[:8]
        winner_sha  = winner.sha256 or ''
        action      = 'current' if staged_sha == winner_sha else 'out-of-date'

        rows.append({
            'Key': key,
            'PreviewName': st_idy.name or (winner.identity.name or ''),
            'Revision': st_idy.revision_raw or '',
            'User': 'Staging root',
            'Size': st_stat.st_size,
            'Exported': ymd_hms(st_stat.st_mtime),
            'Change': '',

            'CommentFilled': st_cf,
            'CommentTotal':  st_ct,
            'CommentNoSpace': st_cn,

            'Role': 'STAGED',
            'WinnerFrom': '',
            'WinnerReason': '',
            'Action': action,
            'WinnerPolicy': args.policy,   # uses global args

            # Short hashes
            'Sha8': staged_sha8,           # this row's file
            'WinnerSha8': '',              # blank on staged row
            'StagedSha8': staged_sha8,     # explicit for readability

            'GUID': st_idy.guid or (winner.identity.guid or ''),
            'SHA256': staged_sha,
            'UserEmail': '',
        })
    except Exception:
        # Fallback placeholder if the staged file can't be read
        rows.append({
            'Key': key,
            'PreviewName': winner.identity.name or '',
            'Revision': '',
            'User': 'Staging root',
            'Size': '',
            'Exported': '',
            'Change': '',
            'CommentFilled': '',
            'CommentTotal':  '',
            'CommentNoSpace': '',
            'Role': 'STAGED',
            'WinnerFrom': '',
            'WinnerReason': 'staged unreadable',
            'Action': 'out-of-date',
            'WinnerPolicy': args.policy,
            'Sha8': '',
            'WinnerSha8': '',
            'StagedSha8': '',
            'GUID': winner.identity.guid or '',
            'SHA256': '',
            'UserEmail': '',
        })
# ============================ Modules to Build Ledger 25-09-03 GAL ==================== #
RUN_LEDGER_NAME = 'apply_events.csv'
LEDGER_BASENAME = 'current_previews_ledger'

def _parse_author(winner_from: str) -> str:
    s = (winner_from or '').strip()
    return s.split(':', 1)[1].strip() if s.upper().startswith('USER:') else s

def _pct_display_names(total: str|int, nospace: str|int) -> int:
    try:
        t = int(total or 0)
        n = int(nospace or 0)
    except Exception:
        return 0
    if t <= 0:
        return 100
    return round(100 * n / t)

def _status_for_row(action: str, total: int, nospace: int) -> str:
    act = (action or '').lower()
    clean = (total == 0) or (nospace == total)
    if act in ('stage-new', 'update-staging') and clean:
        return 'Ready to Apply'
    if act == 'noop':
        return 'Already Applied'
    # includes REPORT-ONLY / needs-* / partial / blocked
    return 'Work Needed'

def emit_run_ledger(
    report_csv: Path,
    rows: list[dict],
    applied_this_run: list[dict],
) -> tuple[Path, Path, Path]:
    """
    Build a complete 'current previews' ledger for this apply run:
      - One row per current preview (WINNER or REPORT-ONLY)
      - Status + DisplayNamesFilledPct
      - ApplyDate/AppliedBy from this run if applied; otherwise last known from run ledger CSV
    Also appends per-item apply events to RUN_LEDGER_NAME for future runs.
    """
    out_dir = report_csv.parent
    ledger_csv = out_dir / f'{LEDGER_BASENAME}.csv'
    ledger_html = out_dir / f'{LEDGER_BASENAME}.html'
    run_ledger = out_dir / RUN_LEDGER_NAME

    # Append this run’s apply events to the small run ledger
    if applied_this_run:
        write_header = not run_ledger.exists()
        with run_ledger.open('a', encoding='utf-8-sig', newline='') as f:
            import csv
            cols = ['Key','PreviewName','Author','Revision','Size','Exported','ApplyDate','AppliedBy']
            w = csv.DictWriter(f, fieldnames=cols)
            if write_header:
                w.writeheader()
            for r in applied_this_run:
                w.writerow({c: r.get(c, '') for c in cols})

    # Build a Key -> (ApplyDate, AppliedBy) map from the accumulated run ledger
    last_apply = {}
    if run_ledger.exists():
        import csv
        with run_ledger.open('r', encoding='utf-8-sig', newline='') as f:
            for r in csv.DictReader(f):
                k = r.get('Key') or ''
                ad = r.get('ApplyDate') or ''
                ab = r.get('AppliedBy') or ''
                # keep the latest ApplyDate per key
                prev = last_apply.get(k)
                if not prev or (ad > prev[0]):
                    last_apply[k] = (ad, ab)

    # Filter the in-memory compare rows to the single “current” row per key
    current = [r for r in rows if r.get('Role') in ('WINNER', 'REPORT-ONLY')]

    # Normalize and compute display %
    for r in current:
        r['Author'] = _parse_author(r.get('WinnerFrom', ''))
        t = int(r.get('CommentTotal') or 0)
        n = int(r.get('CommentNoSpace') or 0)
        r['DisplayNamesFilledPct'] = _pct_display_names(t, n)
        r['Status'] = _status_for_row(r.get('Action',''), t, n)

        k = r.get('Key') or ''
        ad, ab = last_apply.get(k, ('', ''))
        r['ApplyDate'] = ad
        r['AppliedBy'] = ab

    # If this run applied some items, stamp those ApplyDate/AppliedBy now
    if applied_this_run:
        apply_now = {r['Key']: (r['ApplyDate'], r['AppliedBy']) for r in applied_this_run}
        for r in current:
            k = r.get('Key') or ''
            if k in apply_now:
                r['ApplyDate'], r['AppliedBy'] = apply_now[k]

    # Sort and write CSV
    import csv, html
    current.sort(key=lambda r: (r.get('Author') or '', r.get('PreviewName') or '', r.get('Revision') or ''))
    cols = ['PreviewName','Size','Revision','Author','Exported','ApplyDate','AppliedBy','Status','DisplayNamesFilledPct','Key']
    with ledger_csv.open('w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        for r in current:
            w.writerow({c: r.get(c, '') for c in cols})

    # Simple grouped HTML
    def _table(rows_, cols_):
        if not rows_: return '<em>None</em>'
        thead = ''.join(f'<th>{html.escape(c)}</th>' for c in cols_)
        trs = []
        for r in rows_:
            tds = ''.join(f'<td>{html.escape(str(r.get(c,"") or ""))}</td>' for c in cols_)
            trs.append(f'<tr>{tds}</tr>')
        return f'<table><thead><tr>{thead}</tr></thead><tbody>{"".join(trs)}</tbody></table>'

    style = """
    <style>
      body { font-family: system-ui, Segoe UI, Roboto, Arial, sans-serif; margin:24px; }
      h1 { font-size:22px; margin:0 0 8px 0; }
      h2 { font-size:18px; margin:20px 0 8px 0; }
      .meta { color:#666; margin-bottom:16px; }
      table { border-collapse: collapse; width:100%; font-size:13px; }
      th, td { padding:6px 8px; border-bottom:1px solid #eee; text-align:left; }
    </style>
    """.strip()

    html_parts = [f"<!doctype html><meta charset='utf-8'><title>Current Previews Ledger</title>{style}"]
    html_parts.append("<h1>Current Previews Ledger (grouped by Author)</h1>")
    html_parts.append(f"<div class='meta'>Generated {datetime.now().astimezone().isoformat(timespec='seconds')}</div>")

    # Grouped by Author
    from itertools import groupby
    for author, group in groupby(current, key=lambda r: r.get('Author') or ''):
        rows_ = list(group)
        html_parts.append(f"<h2>{(author or '(unknown)')}</h2>")
        html_parts.append(_table(rows_, ['PreviewName','Size','Revision','Exported','ApplyDate','AppliedBy','Status','DisplayNamesFilledPct']))

    ledger_html.write_text('\n'.join(html_parts), encoding='utf-8')
    return ledger_csv, ledger_html, run_ledger

# ---- Backfill Apply Events from history DB / staged files ----
def backfill_apply_events(report_csv: Path, history_db: Path, staging_root: Path, overwrite: bool=False) -> tuple[Path, int]:
    """
    Populate apply_events.csv for current winners using preview_history.db (if available),
    falling back to filesystem mtimes for staged files. Returns (events_path, rows_written).
    """
    import csv, os, sqlite3

    # Read the current compare rows
    with open(report_csv, 'r', encoding='utf-8-sig', newline='') as f:
        compare_rows = list(csv.DictReader(f))

    # Winners only (current "latest-and-greatest")
    winners = [r for r in compare_rows if r.get('Role') in ('WINNER','REPORT-ONLY')]
    by_key = {r.get('Key',''): r for r in winners if r.get('Key')}

    events_path = Path(report_csv).parent / RUN_LEDGER_NAME

    # Read existing events to avoid duplicate/older inserts
    existing = {}
    if events_path.exists() and not overwrite:
        with open(events_path, 'r', encoding='utf-8-sig', newline='') as f:
            for r in csv.DictReader(f):
                k = r.get('Key') or ''
                if k:
                    existing[k] = (r.get('ApplyDate','') or '', r.get('AppliedBy','') or '')

    # Query DB for staged decisions (latest per key)
    latest = {}  # key -> (staged_as, apply_date_from_run, applied_by)
    applied_by_field_names = ('host','hostname','machine','applied_by')
    run_time_field_names   = ('started_at','created_at','run_started_at','run_time')

    try:
        import sqlite3
        conn = sqlite3.connect(str(history_db))
        cur  = conn.cursor()
        # Try to join runs → staging_decisions for timestamps & host/user
        q = f"""
            SELECT sd.preview_key,
                   sd.staged_as,
                   { "COALESCE(" + ",".join("r."+c for c in run_time_field_names) + ")" } AS run_started,
                   { "COALESCE(" + ",".join("r."+c for c in applied_by_field_names) + ")" } AS applied_by
            FROM staging_decisions sd
            LEFT JOIN runs r ON r.id = sd.run_id
            WHERE sd.action='staged'
            ORDER BY run_started DESC, sd.rowid DESC
        """
        cur.execute(q)
        for key, staged_as, run_started, applied_by in cur.fetchall():
            if key not in by_key:   # only fill for current winners
                continue
            if key in latest:       # keep newest only
                continue
            latest[key] = (staged_as, run_started or '', applied_by or '')
    except Exception:
        # Fallback: no runs table; get latest staged_as per key by rowid
        try:
            cur.execute("SELECT preview_key, staged_as FROM staging_decisions WHERE action='staged' ORDER BY rowid DESC")
            for key, staged_as in cur.fetchall():
                if key not in by_key:
                    continue
                if key in latest:
                    continue
                latest[key] = (staged_as, '', '')
        except Exception:
            pass
    finally:
        try:
            conn.close()
        except Exception:
            pass

    # Build rows to append
    rows_to_write = []
    for key, r in by_key.items():
        staged_as, run_started, applied_by = latest.get(key, ('', '', ''))
        apply_date = run_started
        if not apply_date and staged_as:
            try:
                ts = os.path.getmtime(staged_as)
                apply_date = datetime.fromtimestamp(ts).astimezone().isoformat(timespec='seconds')
            except Exception:
                apply_date = ''
        # Skip if we already have an equal/newer ApplyDate recorded
        if key in existing and existing[key][0] >= (apply_date or ''):
            continue

        # Author from WinnerFrom (USER:xyz → xyz)
        wf = (r.get('WinnerFrom','') or '').strip()
        author = wf.split(':',1)[1].strip() if wf.upper().startswith('USER:') else wf

        rows_to_write.append({
            'Key':         key,
            'PreviewName': r.get('PreviewName',''),
            'Author':      author,
            'Revision':    r.get('Revision',''),
            'Size':        r.get('Size',''),
            'Exported':    r.get('Exported',''),
            'ApplyDate':   apply_date,
            'AppliedBy':   applied_by or '',
        })

    # Write/append
    write_header = overwrite or not events_path.exists()
    mode = 'w' if overwrite else 'a'
    with open(events_path, mode, encoding='utf-8-sig', newline='') as f:
        cols = ['Key','PreviewName','Author','Revision','Size','Exported','ApplyDate','AppliedBy']
        w = csv.DictWriter(f, fieldnames=cols)
        if write_header:
            w.writeheader()
        for row in rows_to_write:
            w.writerow(row)

    return events_path, len(rows_to_write)


# ==================== Preview_History DB (LOCAL time, tz-aware) ==================== #

DDL_HISTORY = """
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

CREATE TABLE IF NOT EXISTS runs (
  run_id   TEXT PRIMARY KEY,
  started  TEXT NOT NULL,   -- local tz-aware ISO, e.g. 2025-08-31T08:25:33-05:00
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
  exported     TEXT NOT NULL,  -- local tz-aware ISO (was mtime_utc)
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
  action          TEXT,  -- staged | skipped | conflict | archived
  FOREIGN KEY(run_id) REFERENCES runs(run_id) ON DELETE CASCADE
);

-- persists last winner so we can compute Change on the next run
CREATE TABLE IF NOT EXISTS preview_state (
  preview_key  TEXT PRIMARY KEY,
  preview_guid TEXT,
  preview_name TEXT,
  revision_num REAL,
  sha256       TEXT,
  staged_as    TEXT,
  last_run_id  TEXT,
  last_seen    TEXT,  -- local tz-aware ISO (was last_seen_utc)
  FOREIGN KEY(last_run_id) REFERENCES runs(run_id) ON DELETE SET NULL
);

-- helpful indexes
CREATE INDEX IF NOT EXISTS idx_obs_run_id        ON file_observations(run_id);
CREATE INDEX IF NOT EXISTS idx_obs_preview_guid  ON file_observations(preview_guid);
CREATE INDEX IF NOT EXISTS idx_obs_sha256        ON file_observations(sha256);
CREATE INDEX IF NOT EXISTS idx_decisions_run_id  ON staging_decisions(run_id);
"""


def history_connect(db_path: Path) -> sqlite3.Connection:
    ensure_dir(db_path.parent)
    conn = sqlite3.connect(str(db_path))
    conn.execute('PRAGMA foreign_keys=ON')
    conn.executescript(DDL_HISTORY)
    return conn

# ============================= Core logic ============================= #

def load_user_map(arg_map: Optional[str], json_path: Optional[str]) -> Dict[str, str]:
    out: Dict[str, str] = {}
    if json_path:
        p = Path(json_path)
        if p.is_file():
            try:
                data = json.loads(p.read_text(encoding='utf-8-sig'))
                if isinstance(data, dict):
                    out.update({str(k): str(v) for k, v in data.items()})
            except Exception:
                pass
    if arg_map:
        # Format: "greg=greg@x;rich=rich@x"
        pairs = [s for s in arg_map.split(';') if s.strip()]
        for pair in pairs:
            if '=' in pair:
                k, v = pair.split('=', 1)
                out[k.strip()] = v.strip()
    return out


def scan_input(input_root: Path, user_map: Dict[str, str], email_domain: Optional[str]) -> List[Candidate]:
    candidates: List[Candidate] = []
    ensure_dir(input_root)

    for user_dir in sorted([d for d in input_root.iterdir() if d.is_dir()]):
        user = user_dir.name
        for path in user_dir.glob('*.lorprev'):
            idy = parse_preview_identity(path)
            if not idy:
                continue
            key = identity_key(idy)
            if not key:
                continue

            stat = path.stat()
            email = user_map.get(user) or (f"{user}@{email_domain}" if email_domain else None)
            ct, cf, cn = comment_stats(path)

            candidates.append(
                Candidate(
                    key=key,
                    identity=idy,
                    user=user,
                    user_email=email,
                    path=str(path),
                    size=stat.st_size,
                    mtime=stat.st_mtime,
                    sha256=sha256_file(path),
                    c_total=ct,
                    c_filled=cf,
                    c_nospace=cn,
                )
            )
    return candidates


def group_by_key(candidates: List[Candidate]) -> Dict[str, List[Candidate]]:
    groups: Dict[str, List[Candidate]] = {}
    for c in candidates:
        groups.setdefault(c.key, []).append(c)
    return groups

def choose_winner(group: List[Candidate], policy: str) -> Tuple[Candidate, List[Candidate], str, bool]:
    # --- NEW: Disqualify any candidate that has comment fields but commentsNoSpace == 0 25-09-02 GAL
    eligible = [c for c in group if not (getattr(c, 'c_total', 0) > 0 and getattr(c, 'c_nospace', 0) == 0)]
    if not eligible:
        # Everyone disqualified → pick latest purely for reporting, mark conflict
        winner = sorted(group, key=lambda c: c.mtime, reverse=True)[0]
        losers = [c for c in group if c is not winner]
        return winner, losers, 'all candidates disqualified (commentsNoSpace=0) — reporting only', True
    group = eligible
    
    # Single candidate fast-path
    if len(group) == 1:
        return group[0], [], 'single candidate', False

    def latest_by_mtime(items: List[Candidate]) -> Candidate:
        return sorted(items, key=lambda c: c.mtime, reverse=True)[0]

    def _revnum(c: Candidate) -> float:
        return c.identity.revision_num if c.identity.revision_num is not None else -1

    def _fill_ratio(c: Candidate) -> float:
        t = getattr(c, 'c_total', 0)
        f = getattr(c, 'c_filled', 0)
        return (f / t) if t else 0.0

    reason = ''
    conflict = False

    # ------------------ policy: prefer latest Exported time ------------------
    if policy == 'prefer-exported':
        winner = latest_by_mtime(group)
        reason = 'latest Exported time'

    # --------- NEW policy: comments first, then revision, etc. -------
    elif policy == 'prefer-comments-then-revision':
        # 1) Most non-empty-after-trim comments wins
        max_ns = max(getattr(c, 'c_nospace', 0) for c in group)
        ns_best = [c for c in group if getattr(c, 'c_nospace', 0) == max_ns]
        if len(ns_best) == 1:
            winner = ns_best[0]
            reason = f'most no-space comments={max_ns}'
            conflict = False
        else:
            # 2) Tie → highest numeric Revision (if any exist)
            nums = [c.identity.revision_num for c in ns_best if c.identity.revision_num is not None]
            if nums:
                max_rev = max(nums)
                rev_best = [c for c in ns_best if c.identity.revision_num == max_rev]
                if len(rev_best) == 1:
                    winner = rev_best[0]
                    reason = f'most no-space={max_ns}; highest Revision={max_rev}'
                    conflict = False
                else:
                    # 3) Tie → best fill ratio
                    def _fill_ratio(c):
                        t = getattr(c, 'c_total', 0)
                        return (getattr(c, 'c_filled', 0) / t) if t else 0.0
                    best_fill = max(_fill_ratio(c) for c in rev_best)
                    fill_best = [c for c in rev_best if _fill_ratio(c) == best_fill]
                    if len(fill_best) == 1:
                        winner = fill_best[0]
                        reason = (f'most no-space={max_ns}; Revision={max_rev}; '
                                f'best fill {getattr(winner,"c_filled",0)}/{getattr(winner,"c_total",0)}')
                        conflict = False
                    else:
                        # 4) Still tied → latest Exported time, then deterministic path
                        time_best = sorted(fill_best, key=lambda c: c.mtime, reverse=True)
                        top_time = [c for c in fill_best if c.mtime == time_best[0].mtime]
                        if len(top_time) == 1:
                            winner = top_time[0]
                            reason = (f'most no-space={max_ns}; Revision={max_rev}; fill tied; latest Exported time')
                            conflict = len({c.sha256 for c in top_time}) > 1
                        else:
                            # final tie → pick by path (stable), flag conflict if bytes differ
                            winner = sorted(top_time, key=lambda x: x.path.lower())[0]
                            conflict = len({c.sha256 for c in top_time}) > 1
                            reason = (f"most no-space={max_ns}; Revision={max_rev}; fill & time tied; "
                                f"{'different content' if conflict else 'identical content'}")
            else:
                # No numeric revisions at all → tie on ns; go fill → time → path
                def _fill_ratio(c):
                    t = getattr(c, 'c_total', 0)
                    return (getattr(c, 'c_filled', 0) / t) if t else 0.0
                best_fill = max(_fill_ratio(c) for c in ns_best)
                fill_best = [c for c in ns_best if _fill_ratio(c) == best_fill]
                if len(fill_best) == 1:
                    winner = fill_best[0]
                    reason = f'most no-space={max_ns}; no numeric Revision; best fill'
                    conflict = False
                else:
                    time_best = sorted(fill_best, key=lambda c: c.mtime, reverse=True)
                    top_time = [c for c in fill_best if c.mtime == time_best[0].mtime]
                    if len(top_time) == 1:
                        winner = top_time[0]
                        reason = 'most no-space; no numeric Revision; fill tied; latest Exported time'
                        conflict = len({c.sha256 for c in top_time}) > 1
                    else:
                        winner = sorted(top_time, key=lambda x: x.path.lower())[0]
                        conflict = len({c.sha256 for c in top_time}) > 1
                        reason = ('most no-space; no numeric Revision; fill & time tied; ' +
                                ('different content' if conflict else 'identical content'))


    losers = [c for c in group if c is not winner]
    return winner, losers, reason, conflict



def default_stage_name(idy: PreviewIdentity, src: Path) -> str:
    base = sanitize_name(idy.name) if idy.name else (f'preview_{idy.guid[:8]}' if idy.guid else src.stem)
    tag = f"__{idy.guid[:8]}" if idy.guid else ''
    return f"{base}{tag}.lorprev"


def stage_copy(src: Path, dst: Path) -> None:
    # backup existing different content
    if dst.exists():
        try:
            if sha256_file(dst) != sha256_file(src):
                backup = dst.with_suffix(dst.suffix + f".bak.{datetime.now().strftime('%Y%m%d-%H%M%S')}")
                shutil.copy2(dst, backup)
        except Exception:
            pass
    ensure_dir(dst.parent)
    shutil.copy2(src, dst)

# ============================= Reporting ============================= #

def write_csv(report_csv: Path, rows: List[Dict], input_root: str, staging_root: str) -> None:
    ensure_dir(report_csv.parent)
    fieldnames = [
        'Key','PreviewName','Revision','User','Size','Exported','Change',
        'CommentFilled','CommentTotal','CommentNoSpace',
        'Role','WinnerFrom','WinnerReason','Action','WinnerPolicy',
        'Sha8','WinnerSha8','StagedSha8','GUID','SHA256','UserEmail'
    ]
    with report_csv.open('w', newline='', encoding='utf-8-sig') as f:
        f.write(f"Input root,{input_root}\n")
        f.write(f"Staging root,{staging_root}\n\n")
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, '') for k in fieldnames})


def write_html(report_html: Path, rows: List[Dict], input_root: str, staging_root: str) -> None:
    ensure_dir(report_html.parent)
    def esc(s: str) -> str:
        return (s or '').replace('&','&amp;').replace('<','&lt;').replace('>','&gt;')
    headers = [
        'Key','PreviewName','Revision','User','Size','Exported','Change',
        'CommentFilled','CommentTotal','CommentNoSpace',
        'Role','WinnerFrom','WinnerReason','Action','WinnerPolicy',
        'Sha8','WinnerSha8','StagedSha8','GUID','SHA256','UserEmail'
    ]
    html = [
        '<!doctype html><meta charset="utf-8"><title>LOR Preview Compare</title>',
        '<style>body{font:14px system-ui,Segoe UI,Arial}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ddd;padding:6px}th{background:#f4f6f8;text-align:left}tr:nth-child(even){background:#fafafa}</style>',
        '<h2>LOR Preview Compare</h2>',
        f"<p><b>Input root:</b> {esc(input_root)}</p>",
        f"<p><b>Staging root:</b> {esc(staging_root)}</p>",
        f"<p>Generated: {datetime.now().astimezone().strftime('%Y-%m-%d %H:%M:%S%z')}</p>",
        '<table><thead><tr>' + ''.join(f'<th>{h}</th>' for h in headers) + '</tr></thead><tbody>'
    ]
    for r in rows:
        html.append('<tr>' + ''.join(f'<td>{esc(str(r.get(h, "")))}</td>' for h in headers) + '</tr>')
    html.append('</tbody></table>')
    report_html.write_text('\n'.join(html), encoding='utf-8-sig')

# ============================= Config & Args ============================= #

def _preparse_config_path(argv: List[str]) -> Optional[str]:
    # allow --config PATH or --config=PATH
    for i, a in enumerate(argv):
        if a == '--config' and i + 1 < len(argv):
            return argv[i + 1]
        if a.startswith('--config='):
            return a.split('=', 1)[1]
    return None


def _load_config_json(path: Optional[str]) -> Dict[str, str]:
    if not path:
        # default next to script
        default = Path(__file__).with_suffix('.config.json')
        path = str(default)
    p = Path(path)
    if p.is_file():
        try:
            data = json.loads(p.read_text(encoding='utf-8-sig'))
            if isinstance(data, dict):
                # only accept known keys
                return {k: str(v) for k, v in data.items() if k in GLOBAL_DEFAULTS}
        except Exception:
            pass
    return {}


# ----------------------------- Main -----------------------------

def main():
    # Merge defaults ← config ← CLI
    cfg_path = _preparse_config_path(sys.argv)
    cfg = _load_config_json(cfg_path)
    defaults = {**GLOBAL_DEFAULTS, **cfg}

    # --------------- Added for ledger 25-09-03 GAL -------------
    # … inside main(), before processing any previews:
    applied_this_run: list[dict] = []
    run_started_local = datetime.now().astimezone().isoformat(timespec='seconds')
    applied_by = socket.gethostname()  # or os.getlogin()

    ap = argparse.ArgumentParser(description='Collect and stage LOR .lorprev files with conflict detection and history DB.', fromfile_prefix_chars='@')
    ap.add_argument('--config', help='Path to JSON config file (optional)')
    ap.add_argument('--input-root', default=defaults['input_root'])
    ap.add_argument('--staging-root', default=defaults['staging_root'])
    ap.add_argument('--archive-root', default=defaults['archive_root'])
    ap.add_argument('--history-db', default=defaults['history_db'])
    ap.add_argument('--report', default=defaults['report_csv'])
    ap.add_argument('--report-html', default=defaults['report_html'])
    ap.add_argument('--policy',choices=['prefer-revision-then-exported','prefer-exported','prefer-comments-then-revision'],default=defaults['policy'])
    ap.add_argument('--apply', action='store_true', help='Stage/archive changes (default is dry-run)')
    #ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--force-winner', action='append', default=[])
    ap.add_argument('--ensure-users', default=defaults['ensure_users'], help='Comma-separated list to ensure folders exist under input-root (e.g., usernames)')
    ap.add_argument('--user-map', help='Semicolon-separated username=email pairs, e.g. "gliebig=greg@sheboyganlights.org"')
    ap.add_argument('--user-map-json', help='Path to JSON mapping {"gliebig":"greg@sheboyganlights.org"}')
    ap.add_argument('--email-domain', default=defaults['email_domain'], help='If set, any username without a mapping gets username@<domain>')
    ap.add_argument('--debug', action='store_true', help='Print debug info to stderr')
    # Progress is ON by default; use --no-progress to turn it off
    ap.add_argument('--progress', dest='progress', action='store_true', default=True,
                    help='Show progress while building report (default: on)')
    ap.add_argument('--no-progress', dest='progress', action='store_false',
                    help='Disable progress output')


    args = ap.parse_args()

    # ---- compute report paths EARLY
    input_root   = Path(args.input_root)
    staging_root = Path(args.staging_root)
    archive_root = Path(args.archive_root) if args.archive_root else None
    history_db   = Path(args.history_db)

    report_csv   = Path(args.report)
    report_html  = Path(args.report_html) if args.report_html else None
    ensure_dir(report_csv.parent)  # safe if already exists

    # Canonical companion files (define ONCE here)
    miss_csv      = report_csv.with_name('lorprev_missing_comments.csv')
    manifest_path = report_csv.with_suffix('.manifest.json')

    # ---- FAIL FAST if any existing outputs are open (Excel etc.)
    _fail_if_locked([report_csv, report_html, miss_csv, manifest_path])
    print(f"[script] running: {__file__}")

    # Always show which staging root we’re using (helps when testing different folders)
    print(f"Staging root: {staging_root}")

    if args.debug:
        def dprint(*a, **k): print(*a, file=sys.stderr, flush=True, **k)
    else:
        def dprint(*a, **k): pass

    # Ensure required folders
    ensure_dir(input_root)
    ensure_dir(staging_root)
    if archive_root: ensure_dir(archive_root)
    ensure_dir(report_csv.parent)
    ensure_dir(history_db.parent)

    # ---- forced winners (from --force-winner) -------------------------------
    # Accept PATH or KEY=PATH. We always keep a set of resolved PATHs for quick checks.
    force_set: set[str] = set()
    force_by_key: dict[str, str] = {}

    for spec in (args.force_winner or []):
        s = spec.strip()
        if not s:
            continue
        if '=' in s:
            k, p = s.split('=', 1)
            rp = str(Path(p.strip()).resolve())
            force_by_key[k.strip()] = rp
            force_set.add(rp)
        else:
            force_set.add(str(Path(s).resolve()))

    dprint(f"[debug] forced paths: {len(force_set)} "
        f"({', '.join(list(force_set)[:3])}{' ...' if len(force_set) > 3 else ''})")
    if force_by_key:
        dprint(f"[debug] forced by key: {', '.join(force_by_key.keys())}")
    # ------------------------------------------------------------------------



    # --- DEBUG: what is actually in the top level of staging? (no recursion)
    dprint(f"[debug] staging_root = {staging_root}", file=sys.stderr)
    _staged_top = sorted([p for p in Path(staging_root).glob('*.lorprev') if p.is_file()])
    dprint(f"[debug] top-level staged *.lorprev files = {len(_staged_top)}", file=sys.stderr)
    for p in _staged_top[:10]:
        dprint(f"[debug] staged(top): {p.name}", file=sys.stderr)

    # --- Build a top-level index to resolve staged files by identity (Key → Path, GUID → Path)
    staged_by_key: dict[str, Path] = {}
    staged_by_guid: dict[str, Path] = {}
    try:
        for p in _staged_top:  # NON-RECURSIVE on purpose
            try:
                idy = parse_preview_identity(p) or PreviewIdentity(None, None, None, None)
                k = identity_key(idy)
                st = p.stat().st_mtime
                if k:
                    prev = staged_by_key.get(k)
                    if (prev is None) or (st > prev.stat().st_mtime):
                        staged_by_key[k] = p
                if idy.guid:
                    prev = staged_by_guid.get(idy.guid)
                    if (prev is None) or (st > prev.stat().st_mtime):
                        staged_by_guid[idy.guid] = p
            except Exception as e:
                print(f"[warn] index staged failed for {p}: {e}", file=sys.stderr)
    except Exception as e:
        print(f"[warn] scanning staging_root failed: {e}", file=sys.stderr)
        staged_by_key = {}
        staged_by_guid = {}






    # Optionally ensure user subfolders
    if args.ensure_users:
        for u in [s.strip() for s in args.ensure_users.split(',') if s.strip()]:
            ensure_dir(input_root / u)

    # Index what's already in staging (top-level only; no recursion)
    staged_by_key: dict[str, Path] = {}
    staged_by_guid: dict[str, Path] = {}
    try:
        for p in Path(staging_root).glob('*.lorprev'):  # NON-RECURSIVE on purpose
            if not p.is_file():
                continue
            try:
                idy = parse_preview_identity(p) or PreviewIdentity(None, None, None, None)
                k = identity_key(idy)  # same key you group candidates with
                # keep newest by mtime if duplicates
                st = p.stat().st_mtime
                if k:
                    prev = staged_by_key.get(k)
                    if (prev is None) or (st > prev.stat().st_mtime):
                        staged_by_key[k] = p
                if idy.guid:
                    prev = staged_by_guid.get(idy.guid)
                    if (prev is None) or (st > prev.stat().st_mtime):
                        staged_by_guid[idy.guid] = p
            except Exception:
                continue
    except Exception:
        staged_by_key = {}
        staged_by_guid = {}



    # Build user→email map
    user_map = load_user_map(args.user_map, args.user_map_json)

    # History DB: start run
    conn = history_connect(history_db)
    run_id = hashlib.sha256(os.urandom(16)).hexdigest()

    # Local, tz-aware timestamp (fixes utcnow() deprecation)
    _now_local = datetime.now().astimezone()
    started_local = _now_local.isoformat(timespec='seconds')  # e.g. 2025-08-31T08:25:33-05:00

    # Keeping the column name started for now, but storing local ISO with offset
    conn.execute(
        'INSERT INTO runs(run_id, started, policy) VALUES (?,?,?)',
        (run_id, started_local, args.policy)
    )
    conn.commit()

    # Load prior state for cross-run change detection
    prior: Dict[str, Dict] = {}
    for row in conn.execute(
        "SELECT preview_key, preview_name, revision_num, sha256 FROM preview_state"
    ):
        prior[row[0]] = {
            "preview_name": row[1],
            "revision_num": row[2],
            "sha256": row[3],
        }
        
    # Scan candidates (root only)
    candidates = scan_input(input_root, user_map, args.email_domain)

    # Record file observations
    with conn:
        for c in candidates:
            conn.execute(
                'INSERT INTO file_observations(run_id,user,user_email,path,file_name,preview_key,preview_guid,preview_name,revision_raw,revision_num,file_size,exported,sha256) '
                'VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
                (
                    run_id, c.user, c.user_email, c.path, Path(c.path).name, c.key,
                    c.identity.guid, c.identity.name, c.identity.revision_raw, c.identity.revision_num,
                    c.size, ymd_hms(c.mtime), c.sha256
                )
            )

    groups = group_by_key(candidates)

    rows: List[Dict] = []
    manifest: List[Dict] = []
    conflicts_found = False
    winners: Dict[str, Candidate] = {}

    # NEW: track which keys already had a STAGED row emitted
    emitted_staged_keys: set[str] = set()

    items = sorted(groups.items(), key=lambda kv: kv[0])
    prog = Progress(args.progress)
    prog.start(len(items), "Building report")

    for key, group in items:



    #for key, group in sorted(groups.items(), key=lambda kv: kv[0]):
        forced = None
        for c in group:
            if str(Path(c.path).resolve()) in force_set:
                forced = c
                break

        if forced:
            winner = forced
            losers = [c for c in group if c is not winner]
            reason = 'forced winner by --force-winner'
            conflict = False
        else:
            winner, losers, reason, conflict = choose_winner(group, args.policy)

        if conflict:
            conflicts_found = True

        staged_filename = default_stage_name(winner.identity, Path(winner.path))

        # Resolve the staged file for this preview by identity (no recursion)
        # 1) exact Key match (preferred)
        staged_dest = staged_by_key.get(key)

        # 2) fallback to GUID match
        if staged_dest is None:
            gid = getattr(winner.identity, 'guid', None)
            if gid:
                staged_dest = staged_by_guid.get(gid)

        # 3) final fallback: canonical filename (legacy behavior)
        if staged_dest is None:
            staged_filename = default_stage_name(winner.identity, Path(winner.path))
            staged_dest = Path(staging_root) / staged_filename


        # Record winner for post-run reporting
        winners[key] = winner

        # ---- winner origin & staged diff (report-only context) ----
        winner_from  = f"USER:{winner.user or 'unknown'}"
        winner_sha   = winner.sha256 or ''
        winner_sha8  = (winner_sha[:8] if winner_sha else '')

        staged_exists = staged_dest.exists()
        staged_sha    = sha256_file(staged_dest) if staged_exists else ''
        staged_sha8   = (staged_sha[:8] if staged_sha else '')

        if not staged_exists:
            action = 'stage-new'
        elif staged_sha == winner_sha:
            action = 'noop'
        else:
            action = 'update-staging'

        # NEW: compute once for this key 25-09-02 GAL
        blocked_no_space = (getattr(winner, 'c_total', 0) > 0 and getattr(winner, 'c_nospace', 0) == 0)

        # Override: a blocked winner cannot be staged
        if blocked_no_space:
            action = BLOCKED_ACTION  # 'needs-DisplayName Fixes'

        winner_policy = args.policy




        # ---- pre-stage compare vs existing staged ----
        def _score(total: int, filled: int, nospace: int) -> tuple[float, float]:
            fill_ratio = (filled / total) if total else 0.0
            return (nospace, fill_ratio)

        should_stage = True
        stage_reason = reason  # from choose_winner()

        # If there are problems with missing/bad display names don't stage 25-09-02 GAL
        if blocked_no_space:
            should_stage = False
            stage_reason = (stage_reason + '; ' if stage_reason else '') + f'blocked: {BLOCKED_ACTION} (commentsNoSpace=0)'
     
        if staged_dest.exists():
            try:
                st_idy = parse_preview_identity(staged_dest)
                st_sha = sha256_file(staged_dest)
                st_ct, st_cf, st_cn = comment_stats(staged_dest)

                if st_sha == winner.sha256:
                    should_stage = False
                    stage_reason += '; skip: identical to staged'
                else:
                    w_rev = winner.identity.revision_num or -1
                    s_rev = (st_idy.revision_num if st_idy and st_idy.revision_num is not None else -1)
                    if s_rev > w_rev:
                        should_stage = False
                        stage_reason += f'; skip: staged has higher Revision={s_rev}'
                    elif s_rev < w_rev:
                        should_stage = True
                        stage_reason += f'; replace: higher Revision {w_rev}>{s_rev}'
                    else:
                        w_score = _score(getattr(winner,'c_total',0), getattr(winner,'c_filled',0), getattr(winner,'c_nospace',0))
                        s_score = _score(st_ct, st_cf, st_cn)
                        if w_score > s_score:
                            should_stage = True
                            stage_reason += '; replace: same Revision but better comments'
                        else:
                            should_stage = False
                            stage_reason += '; skip: same Revision; staged comments ≥ winner'
            except Exception:
                should_stage = True
                stage_reason += '; replace: staged unreadable'
        else:
            stage_reason += '; stage: not previously staged'

        # ---- change label vs prior (for report) ----
        prev = prior.get(key)
        if not prev:
            change = ''
        else:
            chg = []
            if (winner.identity.name or '') != (prev.get('preview_name') or ''):
                chg.append('name')
            if (winner.identity.revision_num or -1) != (prev.get('revision_num') or -1):
                chg.append('rev')
            if winner.sha256 != (prev.get('sha256') or ''):
                chg.append('content')
            change = '+'.join(chg) if chg else 'none'

        # ---------- Report rows (staged + candidates) ----------
        # 1) staged row (if present) — includes comment stats
        if staged_dest.exists():
            try:
                st_stat = staged_dest.stat()
                st_idy  = parse_preview_identity(staged_dest) or PreviewIdentity(None, None, None, None)
                st_ct, st_cf, st_cn = comment_stats(staged_dest)
                rows.append({
                    'Key': key,
                    'PreviewName': st_idy.name or (winner.identity.name or ''),
                    'Revision': st_idy.revision_raw or '',
                    'User': 'Staging root',
                    'Size': st_stat.st_size,
                    'Exported': ymd_hms(st_stat.st_mtime),
                    'Change': change,  # group-level label (no 'c' here)

                    'CommentFilled':  st_cf,
                    'CommentTotal':   st_ct,
                    'CommentNoSpace': st_cn,  # match your CSV header

                    'Role': 'STAGED',
                    'WinnerFrom': '',
                    'WinnerReason': '',
                    'Action': ('current' if staged_sha == winner_sha else 'out-of-date'),
                    'WinnerPolicy': args.policy,

                    # hashes (short + long)
                    'Sha8': sha256_file(staged_dest)[:8],  # this row’s file
                    'WinnerSha8': '',                     # blank on staged row
                    'StagedSha8': sha256_file(staged_dest)[:8],

                    'GUID': st_idy.guid or (winner.identity.guid or ''),
                    'SHA256': sha256_file(staged_dest),
                    'UserEmail': '',
                })

                # NEW: remember we already emitted STAGED for this key
                emitted_staged_keys.add(key)

            except Exception as e:
                # Emit a minimal STAGED placeholder so the row is visible in the report
                try:
                    # sys is imported at module level
                    print("...", file=sys.stderr)
                    traceback.print_exc()
                except Exception:
                    pass

                rows.append({
                    'Key': key,
                    'PreviewName': winner.identity.name or '',
                    'Revision': '',
                    'User': 'Staging root',
                    'Size': '',
                    'Exported': '',           # unknown since we couldn't stat()
                    'Change': '',

                    'CommentFilled':  '',
                    'CommentTotal':   '',
                    'CommentNoSpace': '',     # <- matches your header

                    'Role': 'STAGED',
                    'WinnerFrom': '',
                    'WinnerReason': 'staged unreadable',  # clear reason
                    'Action': 'out-of-date',              # conservative default
                    'WinnerPolicy': args.policy,

                    'Sha8': '',
                    'WinnerSha8': '',
                    'StagedSha8': '',

                    'GUID': winner.identity.guid or '',
                    'SHA256': '',
                    'UserEmail': '',
                })

                # NEW: even unreadable staged → count as emitted so we don't duplicate in tail
                emitted_staged_keys.add(key)

        # 2) candidate rows (winner + others)
        for c in sorted(group,
            key=lambda x: ((x.identity.revision_num or -1), x.mtime),
            reverse=True
        ):

            # ---- Winner/Candidate rows for this preview key ----
            is_winner_row  = (c is winner)
            is_report_only = (is_winner_row and action == BLOCKED_ACTION)
            rows.append({
                'Key': key,
                'PreviewName': c.identity.name or '',
                'Revision': c.identity.revision_raw or '',
                'User': c.user,
                'Size': c.size,
                'Exported': ymd_hms(c.mtime),
                'Change': (change if c is winner else ''),

                'CommentFilled': getattr(c, 'c_filled', 0),
                'CommentTotal':  getattr(c, 'c_total', 0),
                'CommentNoSpace': getattr(c, 'c_nospace', 0),

                #'Role': 'WINNER' if c is winner else 'CANDIDATE',
                'Role': ('REPORT-ONLY' if is_report_only else ('WINNER' if is_winner_row else 'CANDIDATE')),
                'WinnerFrom':   (winner_from   if c is winner else ''),
                'WinnerReason': (reason        if c is winner else ''),
                'Action':       (action        if c is winner else ''),
                'WinnerPolicy': (winner_policy if c is winner else ''),

                # Hashes
                'Sha8': (c.sha256[:8] if c.sha256 else ''),         # this row’s file
                'WinnerSha8': (winner_sha8 if c is winner else ''), # on winner row only
                'StagedSha8': (staged_sha8 if c is winner else ''), # on winner row only

                'GUID': c.identity.guid or '',
                'SHA256': c.sha256,
                'UserEmail': c.user_email or '',
            })
      

        # Stage/Archive/Record decisions (unless dry-run)
        if args.apply:
            if should_stage:
                stage_copy(Path(winner.path), staged_dest)
                with conn:
                    conn.execute(
                        'INSERT INTO staging_decisions(run_id,preview_key,winner_path,staged_as,decision_reason,conflict,action) VALUES (?,?,?,?,?,?,?)',
                        (run_id, key, winner.path, str(staged_dest), stage_reason, int(conflict), 'staged')
                    )
                # >>> NEW: record this apply event for the run ledger 25-09-03 GAL
                applied_this_run.append({
                    'Key':         key,
                    'PreviewName': winner.identity.name or '',
                    'Author':      winner.user or '',
                    'Revision':    winner.identity.revision_raw or '',
                    'Size':        winner.size,
                    'Exported':    ymd_hms(winner.mtime),
                    'ApplyDate':   ymd_hms(time.time()),
                    'AppliedBy':   applied_by,
                })
                # <<<
                if archive_root and losers:
                    day = datetime.now(timezone.utc).strftime('%Y-%m-%d')
                    for l in losers:
                        arch_dest = archive_root / day / sanitize_name(l.user) / (
                            default_stage_name(l.identity, Path(l.path)).replace('.lorprev', f"__from_{sanitize_name(l.user)}.lorprev")
                        )
                        ensure_dir(arch_dest.parent)
                        stage_copy(Path(l.path), arch_dest)
                        with conn:
                            conn.execute(
                                'INSERT INTO staging_decisions(run_id,preview_key,winner_path,staged_as,decision_reason,conflict,action) VALUES (?,?,?,?,?,?,?)',
                                (run_id, key, winner.path, str(arch_dest), 'archived non-winner', 0, 'archived')
                            )
            else:
                with conn:
                    conn.execute(
                        'INSERT INTO staging_decisions(run_id,preview_key,winner_path,staged_as,decision_reason,conflict,action) VALUES (?,?,?,?,?,?,?)',
                        (run_id, key, winner.path, str(staged_dest), stage_reason, int(conflict), 'skipped')
                    )

        # progress: one tick per preview key
        prog.tick()
    # after the loop, before the “include staged-only” pass
    prog.done()
    # include staged files that didn’t appear as winners/candidates this run
    for p in sorted(Path(staging_root).glob('*.lorprev')):  # top-level only
        try:
            idy = parse_preview_identity(p) or PreviewIdentity(None, None, None, None)
            key = identity_key(idy) or f"PATH:{p.name.lower()}"

            # skip if we already printed a STAGED row for this key
            if key in emitted_staged_keys:
                continue

            st = p.stat()
            ct, cf, cn = comment_stats(p)
            sha = sha256_file(p); sha8 = sha[:8]

            rows.append({
                'Key': key,
                'PreviewName': idy.name or '',
                'Revision': idy.revision_raw or '',
                'User': 'Staging root',
                'Size': st.st_size,
                'Exported': ymd_hms(st.st_mtime),
                'Change': '',

                'CommentFilled':  cf,
                'CommentTotal':   ct,
                'CommentNoSpace': cn,

                'Role': 'STAGED',
                'WinnerFrom': '',
                'WinnerReason': '',
                'Action': 'staged-only',           # explicit tail marker
                'WinnerPolicy': args.policy,

                'Sha8': sha8,
                'WinnerSha8': '',
                'StagedSha8': sha8,

                'GUID': idy.guid or '',
                'SHA256': sha,
                'UserEmail': '',
            })
        except Exception:
            continue


    # ---- Missing comments report (STAGING ONLY; top-level; skip DeviceType="None")
    # We no longer look at winners/candidates — only what is currently in staging_root.
    try:
        ensure_dir(miss_csv.parent)
        with miss_csv.open('w', newline='', encoding='utf-8-sig') as f:
            w = csv.DictWriter(f, fieldnames=[
                'Key','PreviewName','Revision','User','CommentFilled','CommentNoSpace','CommentTotal','Path'
            ])

            w.writeheader()

            for p in sorted(Path(staging_root).glob('*.lorprev')):  # non-recursive by design
                try:
                    # Allowed to have sparse comments? Skip entirely.
                    if device_type_is_none(p):
                        continue

                    ct, cf, cn = comment_stats(p)
                    # Keep your original semantics: flag when filled < total
                    # Note: If you’d rather treat “missing” as CommentNoSpace < CommentTotal
                    #  (stricter, since it trims blanks), just change cf to cn in the 
                    # if ct > 0 and cf < ct: line and in the w.writerow({... 'CommentFilled': cf, ...}) 
                    # assignment (rename or add a CommentNoSpace column if you want it visible).
                    if ct > 0 and cn < ct:
                        idy = parse_preview_identity(p) or PreviewIdentity(None, None, None, None)
                        w.writerow({
                            'Key': identity_key(idy) or f"PATH:{p.name.lower()}",
                            'PreviewName': idy.name or '',
                            'Revision': idy.revision_raw or '',
                            'User': 'Staging root',
                            'CommentFilled':  cf,   # before trimming
                            'CommentNoSpace': cn,   # after trimming (new column)
                            'CommentTotal':   ct,
                            'Path': str(p),
                        })
                except Exception:
                    # unreadable staged file? just skip from missing-comments view
                    continue

        print(f"Missing-comments CSV: {miss_csv}")
    except PermissionError:
        print(f"\n[locked] {miss_csv} is open in another program. Close it and re-run.", file=sys.stderr)
        sys.exit(4)

    # ---- All-staged comment audit (top-level staging; includes compliant)
    all_csv = miss_csv.with_name('lorprev_all_staged_comments.csv')
    ensure_dir(all_csv.parent)
    with all_csv.open('w', newline='', encoding='utf-8-sig') as f:
        w = csv.DictWriter(f, fieldnames=[
            'Key','PreviewName','Revision','User',
            'CommentFilled','CommentNoSpace','CommentTotal','Path'
        ])
        w.writeheader()
        for p in sorted(Path(staging_root).glob('*.lorprev')):  # non-recursive
            try:
                idy = parse_preview_identity(p) or PreviewIdentity(None, None, None, None)
                ct, cf, cn = comment_stats(p)
                w.writerow({
                    'Key': identity_key(idy) or f"PATH:{p.name.lower()}",
                    'PreviewName': idy.name or '',
                    'Revision': idy.revision_raw or '',
                    'User': 'Staging root',
                    'CommentFilled':  cf,
                    'CommentNoSpace': cn,
                    'CommentTotal':   ct,
                    'Path': str(p),
                })
            except Exception:
                continue
    print(f"All-staged comment audit: {all_csv}")






    # Sort rows by PreviewName (case-insensitive), then Revision (desc)
    def _revnum(v):
        try:
            return float(v or '')
        except Exception:
            return -1.0
    rows.sort(key=lambda r: (r.get('PreviewName','').lower(), -_revnum(r.get('Revision'))))

    # ---- quick stderr summary (linked vs staged-only)
    try:
        # Winners
        winner_rows   = [r for r in rows if r.get('Role') == 'WINNER']
        winners_total = len({r.get('Key') for r in winner_rows})
        noop = sum(1 for r in winner_rows if r.get('Action') == 'noop')
        upd  = sum(1 for r in winner_rows if r.get('Action') == 'update-staging')
        new  = sum(1 for r in winner_rows if r.get('Action') == 'stage-new')

        # Staged
        staged_rows   = [r for r in rows if r.get('Role') == 'STAGED']
        staged_only   = [r for r in staged_rows if r.get('Action') == 'staged-only']
        staged_linked = [r for r in staged_rows if r.get('Action') in ('current', 'out-of-date')]

        staged_cur = sum(1 for r in staged_linked if r.get('Action') == 'current')
        staged_out = sum(1 for r in staged_linked if r.get('Action') == 'out-of-date')

        print(
            f"[summary] previews={winners_total} "
            f"winners: noop={noop} update={upd} stage-new={new} | "
            f"staged(linked): current={staged_cur} out-of-date={staged_out} | "
            f"staged-only={len(staged_only)}",
            file=sys.stderr
        )

        # Optional: list previews that need attention (update or stage-new)
        needs = [r for r in winner_rows if r.get('Action') in ('update-staging','stage-new')]
        if needs:
            needing_keys = sorted({r.get('Key') for r in needs})
            print(f"[summary] needs action: {len(needs)} rows across {len(needing_keys)} previews: {', '.join(needing_keys)}", file=sys.stderr)
    except Exception as e:
        print(f"[summary] failed: {e}", file=sys.stderr)


    # Write CSV/HTML
    write_csv(report_csv, rows, str(input_root), str(staging_root))
    if report_html:
        write_html(report_html, rows, str(input_root), str(staging_root))

    # Optional manifest JSON next to CSV
    manifest_path = report_csv.with_suffix('.manifest.json')
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding='utf-8-sig')
    print(f"\nOK. Report: {report_csv}")
    if args.apply:
        print(f"Staged → {staging_root}")
        if archive_root:
            print(f"Archived non-winners → {archive_root}")

        # 1) Top up apply_events.csv so older applies get ApplyDate/AppliedBy
        try:
            ep, wrote = backfill_apply_events(report_csv, history_db, staging_root, overwrite=False)
            print(f"[ledger/backfill] wrote {wrote} event(s) → {ep}")
        except Exception as e:
            print(f"[ledger/backfill] failed: {e}")

        # 2) Emit the per-run ledger (CSV/HTML). Use in-memory rows if available; else re-read the CSV.
        try:
            try:
                _ = rows  # raises NameError if not defined here
                compare_rows = rows
                print(f"[ledger] using in-memory rows ({len(compare_rows)})")
            except NameError:
                from csv import DictReader
                with open(report_csv, 'r', encoding='utf-8-sig', newline='') as f:
                    compare_rows = list(DictReader(f))
                print(f"[ledger] re-read rows from {report_csv} ({len(compare_rows)})")

            ledger_csv, ledger_html, run_ledger = emit_run_ledger(report_csv, compare_rows, applied_this_run)
            print(f"[ledger] CSV : {ledger_csv}")
            print(f"[ledger] HTML: {ledger_html}")
            print(f"[ledger] Run events appended to: {run_ledger}")
        except Exception as e:
            print(f"[ledger] failed: {e}")

        # 3) NEW: export only what changed in this run
        if applied_this_run:
            applied_csv = report_csv.parent / 'applied_this_run.csv'
            cols = ['Key','PreviewName','Author','Revision','Size','Exported','ApplyDate','AppliedBy']
            with applied_csv.open('w', encoding='utf-8-sig', newline='') as f:
                w = csv.DictWriter(f, fieldnames=cols)
                w.writeheader()
                for r in applied_this_run:
                    w.writerow({c: r.get(c, '') for c in cols})
            print(f"[ledger] Applied this run: {applied_csv}")

if __name__ == '__main__':
    main()
