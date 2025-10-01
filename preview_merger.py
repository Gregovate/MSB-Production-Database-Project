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
import csv as _csv
import html
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
import subprocess
import sys
import traceback  # (optional, if you print tracebacks elsewhere)


# ============================= GLOBAL DEFAULTS ============================= #
G = Path(r"G:\Shared drives\MSB Database")

def require_g():
    if not G.exists():
        print("[FATAL] G: drive not available. All data lives on the shared drive.")
        print("        Mount the shared drive and try again.")
        sys.exit(2)

GLOBAL_DEFAULTS = {
    # Folders
    "input_root": r"G:\Shared drives\MSB Database\UserPreviewStaging",
    # "Secret" location used by LOR parser today
    "staging_root": r"G:\Shared drives\MSB Database\Database Previews",
    #"staging_root": r"G:\Shared drives\MSB Database\database\_secret_staging",
    # Keep merger artifacts under /database/merger
    # Put archived previews directly under Database Previews\archive\YYYY-MM-DD
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

# --- Paths config (repo-aware with env + shared-drive fallback) ---

def get_repo_root() -> Path:
    env_root = os.environ.get("MSB_REPO_ROOT")
    if env_root and (Path(env_root) / ".git").exists():
        return Path(env_root).resolve()
    try:
        top = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL, text=True
        ).strip()
        if top:
            return Path(top).resolve()
    except Exception:
        pass
    here = Path(__file__).resolve()
    for parent in [here] + list(here.parents):
        if (parent / ".git").exists():
            return parent
    return Path.cwd().resolve()

REPO_ROOT = get_repo_root()

# Allow operator to override on each machine without editing code
PREVIEWS_ROOT = Path(os.environ.get("MSB_PREVIEWS_ROOT", REPO_ROOT / "Database Previews"))
USER_STAGING  = Path(os.environ.get("MSB_USER_STAGING",  REPO_ROOT / "UserPreviewStaging"))

# Shared-drive fallbacks (only used if local paths don’t exist)
SHARED_PREVIEWS = Path(r"G:\Shared drives\MSB Database\Database Previews")
SHARED_STAGING  = Path(r"G:\Shared drives\MSB Database\UserPreviewStaging")

def prefer_existing(primary: Path, fallback: Path) -> Path:
    return primary if primary.exists() or not fallback.exists() else fallback

PREVIEWS_ROOT = prefer_existing(PREVIEWS_ROOT, SHARED_PREVIEWS)
USER_STAGING  = prefer_existing(USER_STAGING,  SHARED_STAGING)

print(f"[INFO] PREVIEWS_ROOT: {PREVIEWS_ROOT}")
print(f"[INFO] USER_STAGING : {USER_STAGING}")

# ---------- Config resolution: CLI > JSON > repo/env > GLOBAL_DEFAULTS ----------
def build_repo_defaults(repo_root: Path) -> dict:
    """Repo-relative defaults for everything, so the tool runs from any clone."""
    return {
        "input_root":   str(USER_STAGING),                   # repo/env aware
        "staging_root": str(PREVIEWS_ROOT),                  # repo/env aware
        "archive_root": str(repo_root / "database" / "merger" / "archive"),
        "history_db":   str(repo_root / "database" / "merger" / "preview_history.db"),
        "report_csv":   str(repo_root / "database" / "merger" / "reports" / "lorprev_compare.csv"),
        "report_html":  str(repo_root / "database" / "merger" / "reports" / "lorprev_compare.html"),
        # behavior/users carry over from GLOBAL_DEFAULTS unless overridden
        "policy":       GLOBAL_DEFAULTS.get("policy", "prefer-comments-then-revision"),
        "ensure_users": GLOBAL_DEFAULTS.get("ensure_users", ""),
        "email_domain": GLOBAL_DEFAULTS.get("email_domain", "sheboyganlights.org"),
    }

def load_json_config(path: Optional[str]) -> dict:
    if not path:
        # default: same folder as script
        path = str(Path(__file__).with_name("preview_merger.config.json"))
    p = Path(path)
    if p.exists():
        with p.open("r", encoding="utf-8") as f:
            return json.load(f)
    return {}

def resolve_config(cli_args: dict, json_path: Optional[str]=None) -> dict:
    repo_defaults = build_repo_defaults(REPO_ROOT)
    json_cfg      = load_json_config(json_path)

    # Start from GLOBAL_DEFAULTS, update with repo defaults, then JSON, then CLI.
    cfg = dict(GLOBAL_DEFAULTS)
    cfg.update(repo_defaults)
    cfg.update(json_cfg)

    # CLI args (only set keys that are provided)
    for k, v in cli_args.items():
        if v is not None:
            cfg[k] = v

    # Final: normalize/resolve to paths and ensure directories
    for key in ["input_root", "staging_root", "archive_root"]:
        cfg[key] = os.path.normpath(cfg[key])

    # Ensure report and archive parents exist
    for key in ["report_csv", "report_html", "history_db"]:
        parent = Path(cfg[key]).parent
        parent.mkdir(parents=True, exist_ok=True)

    return cfg

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


# ===== Allowed families (helpers) ============================================

# flexible patterns (space or hyphen after “Stage”, any stage number)
# Use (pattern, human label) tuples
_ALLOWED_PATTERNS = [
    (re.compile(r"^RGB Plus Prop Stage\s+\d+\b", re.I),         "RGB Plus Prop Stage <num> …"),
    (re.compile(r"^Show Background Stage(?:\s+|-)\d+\b", re.I), "Show Background Stage <num> …"),
    (re.compile(r"^Show Animation\s+\d+\b", re.I),              "Show Animation <num> …"),
]

# Keep legacy prefixes (compat with any old calls)
_ALLOWED_PREFIXES = (
    "RGB Plus Prop Stage ",
    "Show Background Stage ",
    "Show Animation ",
    "1st Panel Animation ",
)

# --- regexes (keep only one copy of each) ---
_RX_RGB_PLUS       = re.compile(r"^RGB Plus Prop Stage\s+\d+\b", re.I)
_RX_SHOW_BG_STAGE  = re.compile(r"^Show Background Stage\s+\d+\b", re.I)   # GOOD: space
_RX_SHOW_BG_STAGE_HYPHEN = re.compile(r"^Show Background Stage-\d+\b", re.I)  # BAD: hyphen

def _parts_lower(p: str | Path) -> list[str]:
    try:
        return [x.lower() for x in Path(p).parts]
    except Exception:
        return []

def _is_in_user_previews_for_props(p: str | Path, user: str | None) -> bool:
    r"""
    True iff path looks like:
        ...\UserPreviewStaging\<user>\PreviewsForProps\...
    user may be None/empty; in that case we still require the folder pattern.
    """
    parts = _parts_lower(p)
    if not parts or "userpreviewstaging" not in parts:
        return False
    i = parts.index("userpreviewstaging")
    if i + 1 >= len(parts):
        return False
    uname = parts[i + 1]
    if user and uname.lower() != str(user).lower():
        return False
    if i + 2 >= len(parts):
        return False
    return parts[i + 2] == "previewsforprops"

def _classify_family(name: str | None,
                     path: str | None = None,
                     user: str | None = None) -> tuple[bool, str]:
    """Return (is_allowed, matched_rule_or_reason)."""
    n = (name or "").strip()
    if not n:
        return False, "empty name"

    if n.lower().startswith("show animation "):
        return True, "Show Animation … (any suffix)"

    if _RX_RGB_PLUS.match(n):
        return True, "RGB Plus Prop Stage <num> …"

    # explicitly reject the hyphenated stage form
    if _RX_SHOW_BG_STAGE_HYPHEN.match(n):
        return False, "invalid stage format (use 'Stage ##', no hyphen after 'Stage')"

    if _RX_SHOW_BG_STAGE.match(n):
        return True, "Show Background Stage <num> …"

    # 1st Panel Animation … must be under UserPreviewStaging\<user>\PreviewsForProps\
    if n.lower().startswith("1st panel animation "):
        if _is_in_user_previews_for_props(path or "", user):
            return True, "1st Panel Animation (valid folder)"
        target = (fr"G:\Shared drives\MSB Database\UserPreviewStaging\{user}\PreviewsForProps"
                  if user else r"G:\Shared drives\MSB Database\UserPreviewStaging\<user>\PreviewsForProps")
        return False, f"wrong folder; move to: {target}"

    return False, "no allowed prefix match"


def _suggest_prefix(name: str) -> str | None:
    """Human suggestion for excluded report (keeps it simple)."""
    if not name:
        return None
    n = name.lower()
    if n.startswith("show anim"):
        return "Show Animation … (any suffix)"
    if n.startswith("rgb plus"):
        return "RGB Plus Prop Stage <num> …"
    if n.startswith("show background stage"):
        return "Show Background Stage <num> …"
    if n.startswith("1st panel animation"):
        return r"Move to UserPreviewStaging\<user>\PreviewsForProps"
    return None

def _excluded_row(row: dict, *, reason: str, suggested: str = "", rule_needed: str = "") -> dict:
    return {
        "PreviewName": row.get("PreviewName",""),
        "Key":         row.get("Key",""),
        "GUID":        row.get("GUID",""),
        "Revision":    row.get("Revision",""),
        "Action":      row.get("Action",""),
        "User":        row.get("User",""),
        "Reason":      reason,
        "Failure":     reason,            # mirror Reason for console roll-up
        "RuleNeeded":  rule_needed,
        "SuggestedFix": suggested,
        "Path":        row.get("Path",""),
        "StagedPath":  row.get("StagedPath",""),
    }

def stage_base_name(s: str) -> str:
    """Filesystem-safe base for staged .lorprev filenames; keeps spaces."""
    s = (s or "").strip()
    s = re.sub(r'[\\/:*?"<>|]+', '_', s)  # replace illegal path chars
    s = re.sub(r'\s+', ' ', s).strip()    # collapse whitespace
    return s

# ===== End allowed families (helpers) =======================================

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

# ============= Date/Time utilities helpers
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

def parse_any_local(s: str):
    """Parse our two formats; return aware datetime or None."""
    if not s: return None
    for fmt in ("%Y-%m-%d %H:%M:%S%z", "%Y-%m-%dT%H:%M:%S%z"):
        try:
            return datetime.strptime(s, fmt)
        except Exception:
            pass
    return None

def newer(a: str, b: str) -> bool:
    """True if a is a newer timestamp string than b (handles both formats)."""
    da, db = parse_any_local(a), parse_any_local(b)
    if not da: return False
    if not db: return True
    return da > db



def file_hash(p: Path) -> str:
    h = hashlib.sha1()
    with open(p, "rb", buffering=1024*1024) as f:
        for chunk in iter(lambda: f.read(1024*1024), b""):
            h.update(chunk)
    return h.hexdigest()

def file_mtime_local(p: Path) -> datetime:
    # local, timezone-aware
    return datetime.fromtimestamp(p.stat().st_mtime).astimezone()

def file_mtime_utc(p: Path) -> datetime:
    # UTC, timezone-aware
    return datetime.utcfromtimestamp(p.stat().st_mtime).replace(tzinfo=timezone.utc)

def fmt_local(ts: datetime) -> str:
    # pretty local string for reports/manifest
    return ts.astimezone().strftime("%Y-%m-%d %H:%M:%S")
# ----------------------------------------------------------------------------

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
            #import csv
            cols = ['Key','PreviewName','Author','Revision','Size','Exported','ApplyDate','AppliedBy']
            w = csv.DictWriter(f, fieldnames=cols)
            if write_header:
                w.writeheader()
            for r in applied_this_run:
                w.writerow({c: r.get(c, '') for c in cols})

    # Build a Key -> (ApplyDate, AppliedBy) map from the accumulated run ledger
    last_apply = {}
    if run_ledger.exists():
        #import csv
        with run_ledger.open('r', encoding='utf-8-sig', newline='') as f:
            for r in csv.DictReader(f):
                k = r.get('Key') or ''
                ad = r.get('ApplyDate') or ''
                ab = r.get('AppliedBy') or ''
                # keep the latest ApplyDate per key
                prev = last_apply.get(k)
                if not prev or newer(ad, prev[0]):
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
    #import csv, html
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
    #import csv, os, sqlite3

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
        if key in existing and not newer(apply_date, existing[key][0]):
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

# Builds a manifest of current previews and archives old previews
def sweep_staging_archive(staging_root: Path, archive_root: Path, keep_files: set[str]) -> tuple[int,int]:
    r"""
    Move any *.lorprev in staging_root that is not in keep_files into
    archive_root\YYYY-MM-DD\ (preserves filename).
    Returns (moved, kept).
    """
    moved = kept = 0
    ensure_dir(archive_root)
    day_folder = archive_root / datetime.now().strftime("%Y-%m-%d")
    ensure_dir(day_folder)

    for p in sorted(staging_root.glob("*.lorprev")):
        if p.name.lower() in keep_files:
            kept += 1
            continue
        dest = day_folder / p.name
        try:
            shutil.move(str(p), str(dest))
            moved += 1
        except Exception:
            # If locked or already moved, just skip
            pass
    return moved, kept

def write_current_manifest(staging_root: Path, out_csv: Path):
    """
    Write a simple manifest of what is currently staged (one row per .lorprev).
    Columns: FileName, PreviewName, GUID, Revision, Size, SHA256, Exported
    """
    ensure_dir(out_csv.parent)
    staged = scan_staged_for_comments(staging_root)  # reuses your existing function
    cols = ["FileName","PreviewName","GUID","Revision","Size","SHA256","Exported"]
    with out_csv.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        for key, info in sorted(staged.items(), key=lambda kv: (kv[1].get('PreviewName') or '').lower()):
            w.writerow({
                "FileName": Path(info.get('Path','')).name,
                "PreviewName": info.get("PreviewName",""),
                "GUID": info.get("GUID",""),
                "Revision": info.get("Revision",""),
                "Size": info.get("Size",""),
                "SHA256": info.get("SHA256",""),
                "Exported": info.get("MTimeUtc",""),
            })

# a dry-run (“would-be”) manifest from preview_merger.py without changing any files GAL 25-09-18
def write_dryrun_manifest_csv(staging_root: Path, winner_rows: list, out_name: str = "current_previews_manifest_preview.csv",
                              author_by_name: dict[str, str] | None = None):
    r"""
    Create a 'would-be' manifest (no filesystem changes) listing the winners that
    WOULD remain in staging if --apply were used.
    Columns: FileName, PreviewName, Revision, Action, Present
    - Present = "Yes" if FileName currently exists in the staging_root (ignores .bak/subfolders)
              = "No"  if it would be newly added/updated by --apply
    """
    path = Path(staging_root) / out_name
    path.parent.mkdir(parents=True, exist_ok=True)

    # What actually exists right now (only .lorprev in root, ignore .bak & subfolders)
    existing = {p.name.lower() for p in Path(staging_root).glob("*.lorprev")}

    # Build unique per preview key (you’re already de-duping elsewhere)
    seen = set()
    rows = []
    for r in winner_rows:
        key = r.get('Key')
        if key in seen:
            continue
        seen.add(key)

        pn  = (r.get('PreviewName') or '').strip()
        rev = r.get('Revision') or ''
        act = r.get('Action')   or ''
        fname = f"{pn}.lorprev" if pn else ""
        present = "Yes" if fname.lower() in existing else "No"
        author = (author_by_name or {}).get(pn, "")
        rows.append({
            "FileName": fname,
            "PreviewName": pn,
            "Author": author,
            "Revision": rev,
            "Action": act,
            "Present": present,
        })

    def _revnum(v: str) -> float:
        try:
            return float(v or '')
        except Exception:
            return -1.0

    rows.sort(key=lambda x: (x["PreviewName"].lower(), -_revnum(x["Revision"])))

    with path.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=["FileName","PreviewName","Author","Revision","Action","Present"])
        w.writeheader()
        w.writerows(rows)

    print(f"[dry-run] wrote preview manifest (no changes made): {path}")


# Writes Manifest in HTML format GAL 25-09-19
def write_current_manifest_html(staging_root: Path, out_html: Path, author_by_name: dict[str, str] | None = None):
    rows = []
    for p in sorted(staging_root.glob("*.lorprev")):
        st  = p.stat()
        idy = parse_preview_identity(p) or PreviewIdentity(None, None, None, None)

        # Local file time EXACTLY as Windows shows it
        exported_local_str = datetime.fromtimestamp(st.st_mtime).astimezone().strftime("%Y-%m-%d %H:%M:%S")

        pn     = (idy.name or p.stem) or ""
        author = (author_by_name or {}).get(pn, "")

        # FileName, Author, Revision, Action, Exported (local file time)
        rows.append((p.name, author, idy.revision_raw or '', '', exported_local_str))

    _emit_manifest_html(
        rows,
        out_html,
        headers=[("FileName","text"),("Author","text"),("Revision","number"),("Action","text"),
                 ("Exported","text")],  # keep the name simple; it IS local file time now
        context_path=str(out_html.parent),
        extra_title="(APPLY RUN)"
    )



def write_dryrun_manifest_html(winner_rows: list, out_html: Path, author_by_name: dict[str, str] | None = None):
    seen, rows = set(), []
    def _revnum(v):
        try: return float(v or '')
        except Exception: return -1.0

    for r in winner_rows:
        key = r.get('Key')
        if key in seen: 
            continue
        seen.add(key)

        pn     = (r.get('PreviewName') or '').strip()
        rev    = r.get('Revision') or ''
        act    = r.get('Action') or ''
        author = (r.get('Author') or (author_by_name or {}).get(pn, '') or '')
        fname  = f"{pn}.lorprev" if pn else ""

        # FileName, Author, Revision, Action   (drop PreviewName)
        rows.append((fname, author, rev, act))

    rows.sort(key=lambda x: ( (x[0] or "").lower(), -_revnum(x[2]) ))

    _emit_manifest_html(
        rows,
        out_html,
        headers=[("FileName","text"),("Author","text"),("Revision","number"),("Action","text")],
        context_path=str(out_html.parent),
        extra_title="(DRY RUN)"
    )

def _emit_manifest_html(
    rows,
    out_html: Path,
    headers,
    context_path: str | None = None,
    extra_title: str | None = None,   # <-- NEW
):
    """Emit a minimal, sortable HTML table with run timestamp + optional folder path + mode label."""
    out_html.parent.mkdir(parents=True, exist_ok=True)

    # Normalize headers
    if headers and isinstance(headers[0], str):
        hdrs = [(h, "text") for h in headers]
    else:
        hdrs = headers

    # Optional safety: normalize row lengths to headers (pad/truncate)
    ncols = len(hdrs)
    norm_rows = []
    for row in rows:
        row = tuple("" if i >= len(row) else row[i] for i in range(ncols))  # pad if short
        if len(row) > ncols: row = row[:ncols]                              # trim if long
        norm_rows.append(row)

    th = "".join(
        f"<th data-col='{i}' data-type='{_esc(t)}' title='Click to sort'>{_esc(h)}</th>"
        for i, (h, t) in enumerate(hdrs)
    )
    tr = "\n".join("<tr>" + "".join(f"<td>{_esc(c)}</td>" for c in row) + "</tr>" for row in norm_rows)

    run_ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ctx = _esc(context_path or "")
    xt = f" {extra_title.strip()}" if extra_title else ""  # leading space

    title_text = f"{out_html.name}{xt} – Generated {run_ts}{' – ' + ctx if ctx else ''}"

    html = f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>{_esc(title_text)}</title>
<style>
 body{{font-family:system-ui,-apple-system,Segoe UI,Roboto,Arial,sans-serif;margin:20px}}
 table{{border-collapse:collapse;width:100%}}
 th,td{{border:1px solid #ddd;padding:8px}}
 th{{background:#f3f3f3;cursor:pointer;position:sticky;top:0}}
 tr:nth-child(even){{background:#fafafa}}
 .hint{{color:#666;margin:.5rem 0 1rem;white-space:pre-wrap}}
</style>
</head>
<body>
<h2>{_esc(out_html.name)}{_esc(xt)}</h2>
<div class="hint">Generated on {run_ts}{('<br>Folder: ' + ctx) if ctx else ''}\nTip: click a column header to sort.</div>
<table id="m">
  <thead><tr>{th}</tr></thead>
  <tbody>
{tr}
  </tbody>
</table>
<script>
(function(){{
  const table = document.getElementById("m");
  const thead = table.tHead;
  const tbody = table.tBodies[0];
  const get = (tr,n)=> (tr.children[n]?.innerText || tr.children[n]?.textContent || "").trim();
  function sortTable(col) {{
    const hdr = thead.rows[0].children[col];
    const type = (hdr.getAttribute("data-type") || "text").toLowerCase();
    const dir  = hdr.getAttribute("data-dir")==="asc" ? "desc" : "asc";
    [...thead.rows[0].children].forEach(th=>th.removeAttribute("data-dir"));
    hdr.setAttribute("data-dir", dir);
    const rows = Array.from(tbody.rows);
    rows.sort((a,b) => {{
      const av=get(a,col), bv=get(b,col);
      let cmp=0;
      if(type==="number"){{
        const an=parseFloat(av), bn=parseFloat(bv);
        if(!isNaN(an) && !isNaN(bn)) cmp = an - bn;
        else cmp = av.localeCompare(bv, undefined, {{numeric:true, sensitivity:'base'}});
      }} else if (type==="date") {{
        cmp = new Date(av) - new Date(bv);
      }} else {{
        cmp = av.localeCompare(bv, undefined, {{numeric:true, sensitivity:'base'}});
      }}
      return dir==="asc" ? cmp : -cmp;
    }});
    rows.forEach(r => tbody.appendChild(r));
  }}
  thead.addEventListener("click", (e) => {{
    const th = e.target.closest("th");
    if (!th) return;
    const col = parseInt(th.getAttribute("data-col"), 10);
    if (!isNaN(col)) sortTable(col);
  }});
}})();
</script>
</body></html>"""
    out_html.write_text(html, encoding="utf-8")


def _esc(v):
    s = "" if v is None else str(v)
    return (s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;")
             .replace('"',"&quot;").replace("'","&#39;"))
   
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
            # Force Exported to the preview file's local mtime
            rr = dict(r)  # avoid mutating caller
            p = None
            fp = (rr.get("FullPath") or "").strip()
            if fp:
                p = Path(fp)
            else:
                pn = (rr.get("PreviewName") or "").strip()
                if pn:
                    cand = Path(staging_root) / f"{pn}.lorprev"
                    p = cand if cand.exists() else (Path(input_root) / f"{pn}.lorprev")

            if p and p.exists():
                rr["Exported"] = fmt_local(file_mtime_local(p))

            w.writerow({k: rr.get(k, '') for k in fieldnames})


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
        # Force Exported to the preview file's local mtime
        rr = dict(r)
        p = None
        fp = (rr.get("FullPath") or "").strip()
        if fp:
            p = Path(fp)
        else:
            pn = (rr.get("PreviewName") or "").strip()
            if pn:
                cand = Path(staging_root) / f"{pn}.lorprev"
                p = cand if cand.exists() else (Path(input_root) / f"{pn}.lorprev")

        if p and p.exists():
            rr["Exported"] = fmt_local(file_mtime_local(p))

        html.append('<tr>' + ''.join(f'<td>{esc(str(rr.get(h, "")))}</td>' for h in headers) + '</tr>')


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
def parse_cli() -> dict:
    # Minimal CLI (all optional). Safe even if you never pass flags.
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("--config")
    ap.add_argument("--input_root")
    ap.add_argument("--staging_root")
    ap.add_argument("--archive_root")
    ap.add_argument("--history_db")
    ap.add_argument("--report_csv")
    ap.add_argument("--report_html")
    ap.add_argument("--policy")
    ap.add_argument("--ensure_users")
    ap.add_argument("--email_domain")
    try:
        args, _ = ap.parse_known_args()
        return vars(args)
    except SystemExit:
        return {}

def build_repo_defaults(repo_root: Path) -> dict:
    # Use the PREVIEWS_ROOT / USER_STAGING you already resolved above
    return {
        "input_root":   str(USER_STAGING),
        "staging_root": str(PREVIEWS_ROOT),
        "archive_root": str(repo_root / "database" / "merger" / "archive"),
        "history_db":   str(repo_root / "database" / "merger" / "preview_history.db"),
        "report_csv":   str(repo_root / "database" / "merger" / "reports" / "lorprev_compare.csv"),
        "report_html":  str(repo_root / "database" / "merger" / "reports" / "lorprev_compare.html"),
        "policy":       GLOBAL_DEFAULTS.get("policy", "prefer-comments-then-revision"),
        "ensure_users": GLOBAL_DEFAULTS.get("ensure_users", ""),
        "email_domain": GLOBAL_DEFAULTS.get("email_domain", "sheboyganlights.org"),
    }

def main():
    # --------- 1) Collect configs: CLI > JSON > repo/env > GLOBAL_DEFAULTS
    cli = parse_cli()
    cfg_path = _preparse_config_path(sys.argv)         # your existing helper
    json_cfg = _load_config_json(cfg_path)             # your existing helper
    repo_defs = build_repo_defaults(REPO_ROOT)

    # precedence: start with globals, overlay repo-aware, then JSON, then CLI
    defaults = dict(GLOBAL_DEFAULTS)
    defaults.update(repo_defs)
    defaults.update(json_cfg)
    for k, v in cli.items():
        if v is not None:
            defaults[k] = v

    # --------- Pin critical outputs to G:\ regardless of repo/json ---------
    G = Path(r"G:\Shared drives\MSB Database")

    def _is_on_g(p: str | Path) -> bool:
        s = str(p or "").strip()
        return s[:2].upper() == "G:"

    def _gpath(*parts: str) -> str:
        return str(G.joinpath(*parts))

    # Force these four onto G:\ if they came in as C:\ (or anything else)
    for key, rel in [
        ("archive_root", ("database", "merger", "archive")),
        ("history_db",   ("database", "merger", "preview_history.db")),
        ("report_csv",   ("database", "merger", "reports", "lorprev_compare.csv")),
        ("report_html",  ("database", "merger", "reports", "lorprev_compare.html")),
    ]:
        if not _is_on_g(defaults.get(key, "")):
            defaults[key] = _gpath(*rel)

    # --------- Normalize and ensure dirs (AFTER coercion) ---------
    for key in ["input_root", "staging_root", "archive_root", "history_db", "report_csv", "report_html"]:
        defaults[key] = os.path.normpath(defaults[key])

    Path(defaults["archive_root"]).mkdir(parents=True, exist_ok=True)
    Path(defaults["history_db"]).parent.mkdir(parents=True, exist_ok=True)
    Path(defaults["report_csv"]).parent.mkdir(parents=True, exist_ok=True)
    Path(defaults["report_html"]).parent.mkdir(parents=True, exist_ok=True)

    print("[INFO] Effective config:")
    for k in ["input_root","staging_root","archive_root","history_db","report_csv","report_html","policy"]:
        print(f"  {k}: {defaults[k]}")

    # --------- 2) Run-scoped accumulators (keep exactly as you had)
    applied_this_run: list[dict] = []
    excluded_detailed: list[dict] = []
    allowed_winner_rows: list[dict] = []
    run_started_local = datetime.now().astimezone().isoformat(timespec='seconds')
    applied_by = socket.gethostname()      # or os.getlogin()

    # --------- 3) Pass `defaults` into the rest of your merger logic
    # ...

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
    ap.add_argument('--excel-out', default=defaults.get('excel_out'), 
                    help="Directory to write the Excel report. If omitted, uses report_html's folder; otherwise reports_dir.")

    args = ap.parse_args()

    # ---- compute report paths EARLY
    input_root   = Path(args.input_root)
    staging_root = Path(args.staging_root)
    archive_root = Path(args.archive_root) if args.archive_root else None
    history_db   = Path(args.history_db)

    report_csv   = Path(args.report)
    report_html  = Path(args.report_html) if args.report_html else None

    # --- helpers: keep everything on G:\ (no Path.resolve() here)
    G = Path(r"G:\Shared drives\MSB Database")

    def _is_on_g(p: Path | None) -> bool:
        if p is None:
            return True
        # Use the raw drive/prefix; do NOT call .resolve() (can flip to UNC)
        drv = getattr(p, "drive", "")  # '' for UNC or relative
        if drv.upper() == "G:":
            return True
        s = str(p)
        return s[:2].upper() == "G:"

    def _gpath(*parts: str) -> Path:
        return G.joinpath(*parts)

    # --- Coerce critical outputs to G:\ as a final safety net
    if not _is_on_g(archive_root):
        archive_root = _gpath("database", "merger", "archive")
    if not _is_on_g(history_db):
        history_db   = _gpath("database", "merger", "preview_history.db")
    if not _is_on_g(report_csv):
        report_csv   = _gpath("database", "merger", "reports", "lorprev_compare.csv")
    if report_html and not _is_on_g(report_html):
        report_html  = _gpath("database", "merger", "reports", "lorprev_compare.html")

    # --- Hard requirement: all data lives on G:\
    def _must_be_on_g(label: str, p: Path | None) -> None:
        if not _is_on_g(p):
            print(f"[FATAL] {label} must be on G:\\ — got: {p}")
            sys.exit(2)

    for label, p in [
        ("input_root",   input_root),
        ("staging_root", staging_root),
        ("archive_root", archive_root),
        ("history_db",   history_db),
        ("report_csv",   report_csv),
        ("report_html",  report_html),
    ]:
        _must_be_on_g(label, p)

    # Directories (create AFTER coercion)
    ensure_dir(report_csv.parent)
    if report_html:
        ensure_dir(report_html.parent)
    if archive_root:
        ensure_dir(archive_root)
    ensure_dir(history_db.parent)

    # NEW: define reports_dir once and reuse it everywhere
    reports_dir = report_csv.parent

    # Canonical companion files (define ONCE here)
    miss_csv      = report_csv.with_name('lorprev_missing_comments.csv')
    manifest_path = report_csv.with_suffix('.manifest.json')
    # --- Build PreviewName -> Author map once from the ledger CSV ---
    author_by_name: dict[str, str] = {}
    ledger_csv = reports_dir / "current_previews_ledger.csv"
    try:
        with ledger_csv.open(encoding="utf-8-sig", newline="") as f:
            # If you imported csv as an alias (e.g., `import csv as _csv`), use that here.
            reader = _csv.DictReader(f)      # or _csv.DictReader(f) if you used an alias
            for row in reader:
                name = (row.get("PreviewName") or "").strip()
                auth = (row.get("Author") or "").strip()
                if name and auth and name not in author_by_name:
                    author_by_name[name] = auth
    except FileNotFoundError:
        # No ledger yet — manifests still render; Author will be blank
        pass


    # Excel output location:
    #   1) --excel-out if provided
    #   2) otherwise, put it in the STAGING folder (Database Previews)
    excel_out = Path(args.excel_out) if getattr(args, "excel_out", None) else Path(staging_root)
    excel_out.mkdir(parents=True, exist_ok=True)

    # Excel targets
    _ts = datetime.now().strftime("%Y%m%d-%H%M")
    xlsx_latest = excel_out / "lorprev_reports.xlsx"
    xlsx_ts     = excel_out / f"lorprev_reports-{_ts}.xlsx"

    # Include Excel files in the lock check
    _fail_if_locked([report_csv, report_html, miss_csv, manifest_path, xlsx_latest, xlsx_ts])

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

                # ---------------- Winner destination & pre-apply decisions ----------------

        # Resolve the staged file for this preview (winner):
        #   1) If this preview already exists in staging, KEEP ITS CURRENT FILENAME.
        #   2) Else, stage to canonical "<PreviewName>.lorprev" (no GUID in filename).
        staged_dest = None

        # 1) exact Key match (preferred)
        staged_dest = staged_by_key.get(key)

        # 2) fallback to GUID match (same preview identity, different name)
        if staged_dest is None:
            gid = getattr(winner.identity, 'guid', None)
            if gid:
                staged_dest = staged_by_guid.get(gid)

        # 3) final fallback: canonical filename (no GUID suffix)
        if staged_dest is None:
            name_for_dest = (getattr(winner.identity, "name", None) or Path(winner.path).stem or "").strip()
            staged_dest = Path(staging_root) / f"{stage_base_name(name_for_dest)}.lorprev"

        # Record winner for post-run reporting
        winners[key] = winner

        # ---- winner origin & staged diff (report-only context) ----
        winner_from  = f"USER:{winner.user or 'unknown'}"
        winner_sha   = winner.sha256 or ''
        winner_sha8  = (winner_sha[:8] if winner_sha else '')

        staged_exists = staged_dest.exists()
        staged_sha    = sha256_file(staged_dest) if staged_exists else ''
        staged_sha8   = (staged_sha[:8] if staged_sha else '')

        # Proposed action based on bytes-only comparison
        if not staged_exists:
            action = 'stage-new'
        elif staged_sha == winner_sha:
            action = 'noop'
        else:
            action = 'update-staging'

        # --- Policy/quality checks that can override staging ---

        # 1) Blocked due to comments: if total>0 and nospace==0 we block
        blocked_no_space = (getattr(winner, 'c_total', 0) > 0 and getattr(winner, 'c_nospace', 0) == 0)
        if blocked_no_space:
            action = BLOCKED_ACTION  # e.g., 'needs-DisplayName Fixes'

        winner_policy = args.policy

        # 2) Start with default: stage unless we discover a specific reason not to
        should_stage = True
        stage_reason = reason  # from choose_winner() or forced

        # 3) Enforce family allowlist (reject hyphenated "Show Background Stage-## …")
        name_for_checks = (getattr(winner.identity, "name", None) or "").strip()
        fam_ok, fam_reason = _classify_family(
            name_for_checks,
            path=winner.path,
            user=winner.user,
        )
        if not fam_ok:
            should_stage = False
            stage_reason = (stage_reason + '; ' if stage_reason else '') + f"skip: disallowed family ({fam_reason})"

        # 4) Block if display-name rules failed
        if blocked_no_space:
            should_stage = False
            stage_reason = (stage_reason + '; ' if stage_reason else '') + f'blocked: {BLOCKED_ACTION} (commentsNoSpace=0)'

        # 5) Compare against currently staged file to avoid regressions
        if should_stage and staged_exists:
            try:
                st_idy = parse_preview_identity(staged_dest)
                st_sha = staged_sha  # already computed
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
                        # Same revision: prefer better comment fill / fewer "no-space"
                        def _score(total: int, filled: int, nospace: int) -> tuple[float, float]:
                            fill_ratio = (filled / total) if total else 0.0
                            return (nospace, fill_ratio)
                        w_score = _score(getattr(winner,'c_total',0), getattr(winner,'c_filled',0), getattr(winner,'c_nospace',0))
                        s_score = _score(st_ct, st_cf, st_cn)
                        if w_score > s_score:
                            should_stage = True
                            stage_reason += '; replace: same Revision but better comments'
                        else:
                            should_stage = False
                            stage_reason += '; skip: same Revision; staged comments ≥ winner'
            except Exception:
                # If the staged file is unreadable, allow replacement
                should_stage = True
                stage_reason += '; replace: staged unreadable'

        elif should_stage and not staged_exists:
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
            # Do NOT recompute staged_dest here; we resolved it above.
            name = (getattr(winner.identity, "name", None) or Path(winner.path).stem or "").strip()
            winner_guid = (getattr(winner.identity, "guid", None) or "").strip()

            # Final allowlist gate (reject "Show Background Stage-## …")
            fam_ok, fam_reason = _classify_family(name, path=winner.path, user=winner.user)
            if not fam_ok:
                should_stage = False
                stage_reason = (stage_reason + '; ' if stage_reason else '') + f"skip: disallowed family ({fam_reason})"
                suggested = f"Rename to: {name.replace('Stage-','Stage ',1)}" if fam_reason.startswith("invalid stage format") else ""
                excluded_detailed.append({
                    "PreviewName":  name,
                    "Key":          key,
                    "GUID":         winner_guid,
                    "Revision":     winner.identity.revision_raw or "",
                    "Action":       action,
                    "User":         winner.user or "",
                    "Reason":       fam_reason,
                    "Failure":      fam_reason,
                    "RuleNeeded":   "Show Background Stage <num> …" if fam_reason.startswith("invalid stage format") else "",
                    "SuggestedFix": suggested,
                    "Path":         winner.path,
                    "StagedPath":   str(staged_dest),
                })

            # GUID safety: don’t overwrite a different preview with same name
            dest_guid = None
            if should_stage and staged_dest.exists():
                try:
                    dest_idy = parse_preview_identity(staged_dest)
                    dest_guid = getattr(dest_idy, "guid", None)
                except Exception:
                    dest_guid = None

            if should_stage and dest_guid and winner_guid and dest_guid != winner_guid:
                should_stage = False
                stage_reason = (stage_reason + '; ' if stage_reason else '') + "skip: GUID mismatch vs staged"
                excluded_detailed.append({
                    "PreviewName":  name,
                    "Key":          key,
                    "GUID":         winner_guid,
                    "Revision":     winner.identity.revision_raw or "",
                    "Action":       action,
                    "User":         winner.user or "",
                    "Reason":       f"GUID mismatch (staged={dest_guid} vs winner={winner_guid})",
                    "Failure":      "GUID mismatch",
                    "SuggestedFix": "Investigate source; do not overwrite a different preview with the same name",
                    "Path":         winner.path,
                    "StagedPath":   str(staged_dest),
                })

            if should_stage:
                copy_ok = False
                try:
                    ensure_dir(staged_dest.parent)
                    stage_copy(Path(winner.path), staged_dest)   # actual copy
                    copy_ok = True
                except Exception as e:
                    excluded_detailed.append({
                        "PreviewName":  name,
                        "Key":          key,
                        "GUID":         winner_guid,
                        "Revision":     winner.identity.revision_raw or "",
                        "Action":       action,
                        "User":         winner.user or "",
                        "Reason":       "apply failed",
                        "Failure":      str(e),
                        "RuleNeeded":   "",
                        "SuggestedFix": "",
                        "Path":         winner.path,
                        "StagedPath":   str(staged_dest),
                    })

                if copy_ok:
                    with conn:
                        conn.execute(
                            'INSERT INTO staging_decisions(run_id,preview_key,winner_path,staged_as,decision_reason,conflict,action) VALUES (?,?,?,?,?,?,?)',
                            (run_id, key, winner.path, str(staged_dest), stage_reason, int(conflict), 'staged')
                        )
                    applied_this_run.append({
                        'Key':         key,
                        'PreviewName': name,
                        'Author':      winner.user or '',
                        'Revision':    winner.identity.revision_raw or '',
                        'Size':        winner.size,
                        'Exported':    ymd_hms(winner.mtime),
                        'ApplyDate':   ymd_hms(time.time()),
                        'AppliedBy':   applied_by,
                    })

                    # Archive losers (ok to keep default_stage_name here)
                    if archive_root and losers:
                        day = datetime.now(timezone.utc).strftime('%Y-%m-%d')
                        for l in losers:
                            arch_dest = archive_root / day / sanitize_name(l.user) / (
                                default_stage_name(l.identity, Path(l.path)).replace(
                                    '.lorprev', f"__from_{sanitize_name(l.user)}.lorprev"
                                )
                            )
                            try:
                                ensure_dir(arch_dest.parent)
                                stage_copy(Path(l.path), arch_dest)
                                with conn:
                                    conn.execute(
                                        'INSERT INTO staging_decisions(run_id,preview_key,winner_path,staged_as,decision_reason,conflict,action) VALUES (?,?,?,?,?,?,?)',
                                        (run_id, key, winner.path, str(arch_dest), 'archived non-winner', 0, 'archived')
                                    )
                            except Exception as e:
                                excluded_detailed.append({
                                    "PreviewName":  l.identity.name or "",
                                    "Key":          key,
                                    "GUID":         l.identity.guid or "",
                                    "Revision":     l.identity.revision_raw or "",
                                    "Action":       "archive",
                                    "User":         l.user or "",
                                    "Reason":       "archive failed",
                                    "Failure":      str(e),
                                    "RuleNeeded":   "",
                                    "SuggestedFix": "",
                                    "Path":         l.path,
                                    "StagedPath":   str(arch_dest),
                                })
            else:
                # explicitly record the skip
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

        # ---- Filter winners to only allowed families (log exclusions) ----
        allowed_winner_rows: list[dict] = []
        excluded_detailed:   list[dict] = []   # consumed later by excluded_winners.csv writer

        for r in winner_rows:
            pn       = (r.get('PreviewName') or '').strip()
            user     = (r.get('User') or r.get('Owner') or '').strip()
            src_path = (r.get('Path') or r.get('SourcePath') or '').strip()

            is_allowed, reason = _classify_family(pn, path=src_path, user=user)
            if not is_allowed:
                suggested = f"Rename to: {pn.replace('Stage-','Stage ',1)}" if reason.startswith("invalid stage format") else ""
                excluded_detailed.append({
                    "PreviewName":  pn,
                    "Key":          r.get("Key",""),
                    "GUID":         r.get("GUID",""),
                    "Revision":     r.get("Revision",""),
                    "Action":       r.get("Action",""),
                    "User":         user,
                    "Reason":       reason,
                    "Failure":      reason,   # used in console roll-up
                    "RuleNeeded":   "Show Background Stage <num> …" if reason.startswith("invalid stage format") else "",
                    "SuggestedFix": suggested,
                    "Path":         src_path,
                    "StagedPath":   r.get("StagedPath",""),
                })
                continue

            allowed_winner_rows.append(r)

        # use the filtered list for the summary numbers
        winners_total = len({r.get('Key') for r in allowed_winner_rows})
        noop = sum(1 for r in allowed_winner_rows if r.get('Action') == 'noop')
        upd  = sum(1 for r in allowed_winner_rows if r.get('Action') == 'update-staging')
        new  = sum(1 for r in allowed_winner_rows if r.get('Action') == 'stage-new')

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

        # ---------- Clean "needs action" summary: names only, multi-line (no GUIDs) ----------
        def _looks_like_guid(s: str) -> bool:
            s = (s or "").strip().lower()
            return s.startswith("guid:") or (len(s) in (36, 38) and s.count("-") == 4)

        def _label_from_identity(idy):
            if not idy: return None
            nm  = getattr(idy, "name", None) or ""
            rev = getattr(idy, "revision", None)
            if not nm: return None
            return f"{nm} (rev {rev})" if rev not in (None, "", "None") else nm

        def _label_for_row(r: dict) -> str | None:
            # 1) Prefer the row's PreviewName (+rev)
            pn  = (r.get("PreviewName") or "").strip()
            rev = r.get("Revision")
            if pn and not _looks_like_guid(pn):
                return f"{pn} (rev {rev})" if rev not in (None, "", "None") else pn

            # 2) Resolve from staged file by GUID/Key → parse identity
            k = r.get("Key"); g = r.get("GUID")
            sbk = globals().get("staged_by_key", {})
            sbg = globals().get("staged_by_guid", {})
            from pathlib import Path
            p = sbg.get(g) if g and sbg else None
            if not p and k and sbk:
                p = sbk.get(k)
            if p:
                try:
                    idy = parse_preview_identity(Path(p))
                    lbl = _label_from_identity(idy)
                    if lbl:
                        return lbl
                except Exception:
                    pass

            # 3) Fallback to filename stem from any known path
            for guess_path in (r.get("StagedPath"), r.get("Path")):
                if guess_path:
                    stem = Path(guess_path).stem.strip()
                    if stem and not _looks_like_guid(stem):
                        return stem
            return None

        needs = [r for r in winner_rows if r.get("Action") in ("update-staging", "stage-new")]
        if needs:
            labels, seen = [], set()
            for r in needs:
                lbl = _label_for_row(r)
                if lbl and lbl not in seen:
                    seen.add(lbl)
                    labels.append(lbl)
            labels.sort(key=str.lower)
            print(
                "[summary] needs action: "
                f"{len(needs)} rows across {len(labels)} previews:\n" +
                ("\n".join(f"  - {x}" for x in labels) if labels else "  (no human-readable names found)"),
                file=sys.stderr
            )

    except Exception as e:
        # keep going even if summary formatting fails
        print(f"[summary] failed: {e}", file=sys.stderr)

    # Write CSV/HTML
    write_csv(report_csv, rows, str(input_root), str(staging_root))
    if report_html:
        write_html(report_html, rows, str(input_root), str(staging_root))

    # Optional manifest JSON next to CSV
    manifest_path = report_csv.with_suffix('.manifest.json')
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding='utf-8-sig')
    print(f"\nOK. Report: {report_csv}")
    if report_html:
        print(f"HTML: {report_html}")
    print(f"History DB: {history_db}")

    # Common: cache winner rows once
    winner_rows = [r for r in rows if r.get('Role') == 'WINNER']

    # Keep only the previews that belong in Database Previews (allowlist) — with detail
    allowed_winner_rows: list[dict] = []
    excluded_detailed:   list[dict] = []

    for r in winner_rows:
        name = r.get('PreviewName') or ""
        ok, detail = _classify_family(name)
        if ok:
            r['FamilyRule'] = detail  # record which rule matched (helpful context)
            allowed_winner_rows.append(r)
        else:
            excluded_detailed.append({
                "PreviewName":  name,
                "Key":          r.get("Key"),
                "GUID":         r.get("GUID"),
                "Revision":     r.get("Revision"),
                "Action":       r.get("Action"),
                "User":         r.get("User"),
                "Reason":       "Family filter",
                "Failure":      detail,  # e.g., empty name / no allowed prefix match
                "RuleNeeded":   " | ".join(lbl for _, lbl in _ALLOWED_PATTERNS),
                "SuggestedFix": (f"Rename to start with: {_suggest_prefix(name)}"
                                if _suggest_prefix(name) else "Rename to match an allowed family"),
                "Path":         r.get("Path"),
                "StagedPath":   r.get("StagedPath"),
            })

    # (Optional) log what was excluded so teammates can fix/move them
    if excluded_detailed:
        excl_csv = Path(report_csv).parent / "excluded_winners.csv"
        cols = ["PreviewName","Key","GUID","Revision","Action","User",
                "Reason","Failure","RuleNeeded","SuggestedFix","Path","StagedPath"]
        with excl_csv.open("w", encoding="utf-8-sig", newline="") as f:
            w = _csv.DictWriter(f, fieldnames=cols)
            w.writeheader()
            for row in excluded_detailed:
                w.writerow({c: row.get(c, "") for c in cols})
        print(f"[filter] excluded {len(excluded_detailed)} previews not matching allowed families → {excl_csv}", file=sys.stderr)
        # quick console roll-up
        for row in excluded_detailed:
            print(f"  - {row['PreviewName']}: {row['Failure']} | {row['SuggestedFix']}", file=sys.stderr)
    else:
        print("[filter] excluded 0 previews; all winners match allowed families", file=sys.stderr)


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
                _ = rows
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

        # 3) Export only what changed in this run (optional)
        if applied_this_run:
            applied_csv = report_csv.parent / 'applied_this_run.csv'
            cols = ['Key','PreviewName','Author','Revision','Size','Exported','ApplyDate','AppliedBy']
            with applied_csv.open('w', encoding='utf-8-sig', newline='') as f:
                w = csv.DictWriter(f, fieldnames=cols)
                w.writeheader()
                for r in applied_this_run:
                    w.writerow({c: r.get(c, '') for c in cols})
            print(f"[ledger] Applied this run: {applied_csv}")

        # 4) Sweep/archive non-winners + write the REAL manifest in Database Previews
        def _sanitize_name(s: str) -> str:
            bad = '<>:"/\\|?*'
            s = (s or '').strip()
            for ch in bad:
                s = s.replace(ch, '-')
            return s.strip().rstrip('.')

        # Keep ONLY the canonical "<PreviewName>.lorprev" in staging.
        # Any old GUID-suffixed files (…__xxxxxxxx.lorprev) should be swept to archive.
        keep_files = {
            f"{_sanitize_name((r.get('PreviewName') or ''))}.lorprev".lower()
            for r in allowed_winner_rows
            if r.get('PreviewName')
        }

        moved, kept = sweep_staging_archive(
            staging_root=Path(staging_root),
            archive_root=Path(archive_root) if archive_root else Path(staging_root) / "archive",
            keep_files=keep_files
        )
        print(f"[sweep] kept={kept} moved_to_archive={moved}")

        # --- Build "applied this run" index by Key (what actually succeeded) ---
        applied_by_key = {}
        for _row in applied_this_run:
            _k = (_row.get('Key') or '').strip()
            if _k and _k not in applied_by_key:
                applied_by_key[_k] = _row

        # --- Write CURRENT PREVIEWS LEDGER (drives Author map & Excel tab) ---
        ledger_csv = reports_dir / "current_previews_ledger.csv"
        with ledger_csv.open("w", newline="", encoding="utf-8-sig") as _f:
            _headers = [
                "PreviewName", "Size", "Revision", "Author", "Exported",
                "ApplyDate", "AppliedBy", "Status", "DisplayNamesFilledPct", "Key", "GUID"
            ]
            _w = _csv.DictWriter(_f, fieldnames=_headers)
            _w.writeheader()

            # Source rows: only the filtered winners from this run
            for r in allowed_winner_rows:
                pn   = (r.get("PreviewName") or "").strip()
                key  = (r.get("Key") or "").strip()
                guid = (r.get("GUID") or "").strip()
                act  = (r.get("Action") or "").strip()  # 'noop' | 'stage-new' | 'update-staging' | ...

                # Default status from planned action (pre-apply)
                if   act == "noop":                           status = "Current"
                elif act in ("stage-new", "update-staging"):  status = "Ready to Apply"
                else:                                         status = (act or "Unknown")

                # If we actually applied it this run, override to Applied
                applied = applied_by_key.get(key)
                if applied:
                    status     = "Applied"
                    apply_date = applied.get("ApplyDate") or ""
                    applied_by = applied.get("AppliedBy") or ""
                    exported   = applied.get("Exported") or (r.get("Exported") or "")
                else:
                    apply_date = r.get("ApplyDate") or ""
                    applied_by = r.get("AppliedBy") or ""
                    exported   = r.get("Exported") or ""

                author = r.get("Author") or r.get("User") or ""
                display_pct = r.get("DisplayNamesFilledPct") or ""

                _w.writerow({
                    "PreviewName": pn,
                    "Size":        r.get("Size") or "",
                    "Revision":    r.get("Revision") or "",
                    "Author":      author,
                    "Exported":    exported,
                    "ApplyDate":   apply_date,
                    "AppliedBy":   applied_by,
                    "Status":      status,
                    "DisplayNamesFilledPct": display_pct,
                    "Key":         key,
                    "GUID":        guid,
                })

        print(f"[ledger] wrote: {ledger_csv}")


        # Write the on-disk manifest of what's actually in staging now
        manifest_csv_path = Path(staging_root) / "current_previews_manifest.csv"
        write_current_manifest(Path(staging_root), manifest_csv_path)

        # HTML version too 25-09-19
        manifest_html_path = Path(staging_root) / "current_previews_manifest.html"
        write_current_manifest_html(Path(staging_root), manifest_html_path, author_by_name=author_by_name)
        print(f"[sweep] staging manifest → {manifest_csv_path}")
        print(f"[sweep] staging manifest (HTML) → {manifest_html_path}")

    else:
        # DRY RUN: do not move files — write a 'would-be' manifest for clarity

        # 1) CSV preview manifest (adds Present column)
        #    Only include previews from allowed staging families
        write_dryrun_manifest_csv(Path(staging_root), allowed_winner_rows, 
                                out_name="current_previews_manifest_preview.csv", author_by_name=author_by_name)
        print(f"[dry-run] wrote preview manifest (no changes made).")

        # 2) HTML preview manifest (build rows locally; don't rely on compare 'rows')
        #    Present = "Yes" if FileName exists in staging right now; "No" otherwise
        existing = {p.name.lower() for p in Path(staging_root).glob("*.lorprev")}
        html_rows = []

        def _revnum(v: str) -> float:
            try:
                return float(v or '')
            except Exception:
                return -1.0

        # de-dupe by preview Key (same rule as CSV writer)
        seen = set()
        for r in allowed_winner_rows:
            k = r.get('Key')
            if k in seen:
                continue
            seen.add(k)

            pn  = (r.get('PreviewName') or '').strip()
            rev = r.get('Revision') or ''
            act = r.get('Action')   or ''
            fname = f"{pn}.lorprev" if pn else ""
            present = "Yes" if fname.lower() in existing else "No"

            html_rows.append((fname, pn, rev, act, present))

        # sort: PreviewName (A→Z), then Revision (numeric DESC)
        html_rows.sort(key=lambda x: (x[1].lower(), -_revnum(x[2])))

        # Write the HTML preview manifest with sortable headers
        # Build once, earlier in main():
        # author_by_name = {...}  # from current_previews_ledger.csv

        preview_html = Path(staging_root) / "current_previews_manifest_preview.html"
        write_dryrun_manifest_html(allowed_winner_rows, preview_html, author_by_name=author_by_name)
        print(f"[dry-run] wrote preview manifest (HTML): {preview_html}")

        # subprocess.run(
        #     [sys.executable, "merge_reports_to_excel.py",
        #     "--root", r"G:\Shared drives\MSB Database\database\merger\reports",
        #     "--out",  r"G:\Shared drives\MSB Database\Database Previews"],
        #     check=True
        # )

    # ------------------------------------------------------------------------------
    # --- Excel: merge reports into a formatted workbook (runs for DRY RUN and APPLY) ---


    # ------------------------------------------------------------------------------
    # Excel: merge reports into a formatted workbook (runs for DRY RUN and APPLY)
    excel_script = Path(__file__).with_name("merge_reports_to_excel.py")
    subprocess.run(
        [sys.executable, str(excel_script),
        "--root", str(reports_dir),
        "--out",  str(excel_out)],
        check=True
    )
    print(f"[cfg] CSV root: {reports_dir}")
    print(f"[cfg] Excel out: {excel_out}")
    print("[OK] Excel workbook(s) written by merge_reports_to_excel.py")

    # ------------------------------------------------------------------------------

    if conflicts_found:
        print('\nCONFLICTS detected — review report/HTML. (Exit 2)')
        sys.exit(2)


if __name__ == '__main__':
    main()
