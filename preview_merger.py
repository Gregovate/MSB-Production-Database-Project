#!/usr/bin/env python3
"""
File: preview_merger.py
Purpose: Merge .lorprev updates into primary DB with full audit logging.
Owner: Greg Liebig • Team: MSB Database
Revision: 2025‑09‑01 (v6.1)

# GAL 25-10-16: Begin integrating Core Model v1.0 (no logic swaps yet)
 - Add lor_core import for shared field/signature helpers
 - Add Author-folder scan for Missing_Comments (will be wired in next step)
 - Add run_meta.json writer (filled as we implement categories)


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
    "report_csv": "G:/Shared drives/MSB Database/database/merger/reports/compare.csv",
    "report_html": "G:/Shared drives/MSB Database/database/merger/reports/compare.html",
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
#from datetime import datetime
import socket  # used for ledger 25-09-03 GAL
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Iterable
import xml.etree.ElementTree as ET
import shutil
import subprocess
import sys
import traceback  # (optional, if you print tracebacks elsewhere)
import tempfile # Required for _write_atomic
import datetime as dt

# GAL 25-10-20: toggleable debug flag (set False to silence core compare logs)
# Pick one or the other here:
#DEBUG_CORE = True  # set False once you’re happy
DEBUG_CORE = False
DEBUG_APPLY = True  # set False once you’re happy
# DEBUG_APPLY = FALSE  

# GAL 25-10-20: Force sibling lor_core import and log the actual path/version
from pathlib import Path as _GALPath
import sys as _GALsys, importlib as _GALimp

_GAL_HERE = _GALPath(__file__).resolve().parent
if str(_GAL_HERE) not in _GALsys.path:
    _GALsys.path.insert(0, str(_GAL_HERE))  # GAL 25-10-20: ensure sibling wins on sys.path

try:
    LC = _GALimp.import_module("lor_core")
    _ver = getattr(LC, "CORE_MODEL_VERSION", "unknown")
    _src = getattr(LC, "__file__", "?")
    print(f"[core] Using lor_core={_ver} at { _src }")
except Exception as e:
    LC = None
    print(f"[core] WARNING: lor_core import failed: {e}")


# GAL 25-10-16: Core Model v1.0 alignment (shared helpers; no behavior change yet)
try:
    from lor_core import (
        preview_signature, lor_leg_signature, dmx_leg_signature,
        lor_row_key, dmx_row_key,
        categorize_lor_change, categorize_dmx_change, categorize_preview_change,
        validate_display_name, device_type_flip, is_key_change_same_core,
        PREVIEW_FIELDS, LOR_FIELDS, DMX_FIELDS,
    )
except Exception:
    # Keep merger standalone if lor_core.py isn’t present yet
    def validate_display_name(name):  # minimal shim used by Step 2C
        if name is None: return False, "missing"
        s = (name or "").strip()
        if not s: return False, "blank"
        if s != name: return False, "leading_or_trailing_space"
        if "  " in s: return False, "double_spaces"
        return True, "ok"

# ============================= GLOBAL DEFAULTS ============================= #
G = Path(r"G:\Shared drives\MSB Database")

def require_g():
    if not G.exists():
        print("[FATAL] G: drive not available. All data lives on the shared drive.")
        print("        Mount the shared drive and try again.")
        sys.exit(2)

# ---------------------------------------------------------------------------
# GAL 25-10-15: Default configuration values for preview_merger
# ---------------------------------------------------------------------------
# Notes:
#   • Paths point to the shared MSB Database drive structure.
#   • Policy switched to "prefer-exported" to ensure the newest preview
#     always wins over comment completeness.
#   • Author discovery is now automatic (see discover_authors()).
# ---------------------------------------------------------------------------

# GAL 25-10-16: Unify outputs under Database Previews
GLOBAL_DEFAULTS = {
    # Folders
    "input_root":  r"G:\Shared drives\MSB Database\UserPreviewStaging",
    # Canonical STAGING root used by the LOR parser and where the final Excel goes
    "staging_root": r"G:\Shared drives\MSB Database\Database Previews",
    # Put archived previews directly under: <staging_root>\archive\YYYY-MM-DD
    # (merger will create subfolders per run date)
    "archive_root": r"G:\Shared drives\MSB Database\Database Previews\archive",
    # Keep ALL merger artifacts together under: <staging_root>\reports
    # (CSV inputs for the Excel combiner + run_meta.json + history db + HTML)
    "history_db":  r"G:\Shared drives\MSB Database\Database Previews\reports\preview_history.db",
    "report_csv":  r"G:\Shared drives\MSB Database\Database Previews\reports\compare.csv",
    "report_html": r"G:\Shared drives\MSB Database\Database Previews\reports\compare.html",
    # -----------------------------------------------------------------------
    # GAL 25-10-15: Behavior
    # -----------------------------------------------------------------------
    # Previously: "prefer-comments-then-revision"
    # Now:        "prefer-exported" ensures the newest Exported timestamp
    #             takes priority even if comment fields are incomplete.
    # Comment completeness is still checked and logged as a warning.
    "policy": "prefer-exported",  # GAL 25-10-15 change
    # -----------------------------------------------------------------------
    # GAL 25-10-15: Users and email
    # -----------------------------------------------------------------------
    # Hard-coded ensure_users is now legacy. Author folders are auto-
    # discovered from the directory names under input_root.
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
        "input_root":   str(USER_STAGING),   # repo/env aware
        "staging_root": str(PREVIEWS_ROOT),  # repo/env aware
        # Do NOT set archive/report/history paths here; they will be derived from staging_root later
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

    # GAL 25-10-16: Derive report artifacts from staging_root to avoid drift
    reports_dir = Path(cfg["staging_root"]) / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)

    cfg["history_db"]  = str(reports_dir / "preview_history.db")
    cfg["report_csv"]  = str(reports_dir / "compare.csv")    # harmless; for HTML/summary
    cfg["report_html"] = str(reports_dir / "compare.html")

    # Ensure archive root exists
    Path(cfg["archive_root"]).mkdir(parents=True, exist_ok=True)

    # Optional: log after derivation so we can verify in the console
    print("[INFO] Effective config (final):")
    print(f"  input_root:  {cfg['input_root']}")
    print(f"  staging_root:{cfg['staging_root']}")
    print(f"  archive_root:{cfg['archive_root']}")
    print(f"  history_db:  {cfg['history_db']}")
    print(f"  report_csv:  {cfg['report_csv']}")
    print(f"  report_html: {cfg['report_html']}")

    return cfg


BLOCKED_ACTION = 'needs-DisplayName Fixes'

@dataclass
class PreviewIdentity:
    guid: Optional[str]
    name: Optional[str]
    revision_raw: Optional[str]
    revision_num: Optional[float]

# GAL 25-10-15: added core_sig (must be before any defaulted fields)
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
    semantic_sha256: str        # GAL 25-10-15
    core_sig: str               # GAL 25-10-15
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
# ============= Date/Time utilities helpers
def now_local():
    """Return a timezone-aware local datetime."""
    return dt.datetime.now().astimezone()

def ymd_hms(ts: float) -> str:
    """Format an epoch seconds timestamp in LOCAL time with offset, e.g. '2025-08-31 08:25:33-0500'"""
    try:
        dlocal = dt.datetime.fromtimestamp(ts).astimezone()
        return dlocal.strftime('%Y-%m-%d %H:%M:%S%z')
    except Exception:
        return ''

def parse_any_local(s: str):
    """Parse our two formats; return aware datetime or None."""
    if not s:
        return None
    for fmt in ("%Y-%m-%d %H:%M:%S%z", "%Y-%m-%dT%H:%M:%S%z"):
        try:
            return dt.datetime.strptime(s, fmt)
        except Exception:
            pass
    return None

def newer(a: str, b: str) -> bool:
    """True if a is a newer timestamp string than b (handles both formats)."""
    da, db = parse_any_local(a), parse_any_local(b)
    if not da:
        return False
    if not db:
        return True
    return da > db


def _normalized_bytes(raw: bytes) -> bytes:
    # GAL 25-10-15: remove volatile tags/fields out of the file content
    out = raw
    for pat in _VOLATILE_PATTERNS:
        out = re.sub(pat, b"", out)
    # compact whitespace sequences introduced by removals
    out = re.sub(rb"\s{2,}", b" ", out)
    return out

def hash_file(p: Path, chunk=1024 * 1024) -> str:
    # unchanged raw hash (kept for diagnostics)
    h = hashlib.sha1()
    with p.open("rb") as f:
        while True:
            b = f.read(chunk)
            if not b:
                break
            h.update(b)
    return h.hexdigest()

def hash_file_semantic(p: Path) -> tuple[str, str]:
    """
    GAL 25-10-15
    Returns (semantic_hash, raw_hash).
    - semantic_hash ignores common volatile metadata so 'open & save' without
      functional edits won’t force an APPLY.
    """
    with p.open("rb") as f:
        raw = f.read()
    raw_hash = hashlib.sha1(raw).hexdigest()
    sem_hash = hashlib.sha1(_normalized_bytes(raw)).hexdigest()
    return sem_hash, raw_hash


def file_hash(p: Path) -> str:
    h = hashlib.sha1()
    with open(p, "rb", buffering=1024*1024) as f:
        for chunk in iter(lambda: f.read(1024*1024), b""):
            h.update(chunk)
    return h.hexdigest()

# ----------------------------------------------------------------
# GAL 25-10-15: semantic hash for .lorprev
# Ignores volatile metadata (Revision/SavedOn/etc.) so that an
# open/save that only bumps Revision does NOT force a re-stage.
# ----------------------------------------------------------------
def semantic_sha256_file(path: Path) -> str:
    patt = [
        rb"<Revision>\s*\d+\s*</Revision>",       rb'"Revision"\s*:\s*\d+',
        rb"<SavedOn>[^<]+</SavedOn>",             rb'"SavedOn"\s*:\s*"[^"]+"',
        rb"<SavedBy>[^<]+</SavedBy>",             rb'"SavedBy"\s*:\s*"[^"]+"',
        rb"<Exported>[^<]+</Exported>",           rb'"Exported"\s*:\s*"[^"]+"',
        rb"<FileVersion>[^<]+</FileVersion>",     rb'"FileVersion"\s*:\s*"[^"]+"',
    ]
    raw = path.read_bytes()
    for p in patt:
        raw = _re.sub(p, b"", raw)
    # collapse big whitespace gaps that removals can create
    raw = _re.sub(rb"\s{2,}", b" ", raw)
    import hashlib as _hashlib
    return _hashlib.sha256(raw).hexdigest()

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

# ---------------------------------------------------------------------------
# GAL 25-10-15: Auto-discover author folders
# ---------------------------------------------------------------------------
def discover_authors(input_root: Path) -> list[str]:
    """
    GAL 25-10-15
    Automatically discover author names by scanning the top-level folders
    under the shared UserPreviewStaging path. Each author has their own folder.

    Args:
        input_root (Path): Root path such as
            G:/Shared drives/MSB Database/UserPreviewStaging

    Returns:
        list[str]: Sorted list of author folder names.
    """
    try:
        return sorted([
            d.name for d in Path(input_root).iterdir()
            if d.is_dir() and not d.name.startswith("_")
        ])
    except Exception as e:
        print(f"[WARN][GAL 25-10-15] Could not scan authors: {e}")
        return []

def sanitize_name(s: str) -> str:
    return ''.join(ch if ch.isalnum() or ch in (' ', '-', '_', '.') else '_' for ch in s).strip()



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

# ====================== GAL 25-10-17: Validator & Helpers (BEGIN) ======================

def get_device_type(preview_path: Path) -> str:
    """
    Return device type string for a .lorprev file using existing logic.
    Must match your existing device type values: 'LOR', 'DMX', 'NONE' (or similar).
    """
    try:
        # If you already have a function, call that here instead.
        # e.g., return read_device_type(preview_path)
        dt_is_none = device_type_is_none(preview_path)
        if dt_is_none:
            return "NONE"
        # If you track LOR/DMX more specifically, replace this stub:
        # Prefer your existing logic; fallback: assume LOR if not none.
        return "LOR"
    except Exception:
        return "NONE"

def comments_required_for(dev_type: str) -> bool:
    # Enforce comment completeness only for LOR/DMX (not for NONE)
    return dev_type in ("LOR", "DMX")

def check_display_name_rules(preview_path: Path) -> tuple[bool, str]:
    """
    Hook into your existing display-name/LOR comment hygiene rules.
    Return (ok, reason_if_not_ok).
    """
    # TODO: GAL 25-10-17 — replace with your real rules; default OK for now
    return True, ""

def ymd_hms(epoch: float) -> str:
    from datetime import datetime
    return datetime.fromtimestamp(epoch).strftime("%Y-%m-%d %H:%M:%S")

def find_winner_for(candidate_path: Path) -> Path | None:
    """
    Return the current staged/winner path (if any) for this candidate preview.
    Tie into your existing mapping logic.
    """
    # TODO: GAL 25-10-17 — implement your real lookup here
    return None

def core_different(candidate_path: Path, winner_path: Path | None) -> bool:
    """
    Wrapper that calls lor_core.py’s core diff (your existing compare).
    """
    if not winner_path or not winner_path.exists():
        return True
    # TODO: GAL 25-10-17 — replace with your actual lor_core diff helper
    try:
        from lor_core import core_sha256_file
        return core_sha256_file(candidate_path) != core_sha256_file(winner_path)
    except Exception:
        return True

def evaluate_candidate(candidate_path: Path, winner_path: Path | None):
    """
    Compute core-diff and all validators for this candidate .lorprev.
    - Enforce comment completeness only for DeviceType in {LOR, DMX}
    - Block DeviceType NONE
    - (Hook) Display-name hygiene rules
    """
    idy = parse_preview_identity(candidate_path) or PreviewIdentity(None, None, None, None)
    key = identity_key(idy) or f"PATH:{candidate_path.name.lower()}"

    dev_type = get_device_type(candidate_path)  # 'LOR', 'DMX', or 'NONE'
    ct, cf, cn = comment_stats(candidate_path)  # total, filled, no-space

    required = comments_required_for(dev_type)
    comments_ok = (not required) or (ct > 0 and cf == ct and cn == ct)

    naming_ok, naming_reason = check_display_name_rules(candidate_path)
    device_ok = (dev_type != "NONE")

    changed = core_different(candidate_path, winner_path)

    blockers = []
    if not comments_ok and required: blockers.append("comments")
    if not naming_ok:                blockers.append(f"name:{naming_reason}")
    if not device_ok:                blockers.append("device_type")

    ready_to_apply = changed and not blockers

    return {
        "Key": key,
        "PreviewName": idy.name or "",
        "Revision": idy.revision_raw or "",
        "DeviceType": dev_type,
        "CommentTotal": ct,
        "CommentFilled": cf,
        "CommentNoSpace": cn,
        "comments_required": required,
        "comments_ok": comments_ok,
        "naming_ok": naming_ok,
        "device_ok": device_ok,
        "blockers": ";".join(blockers),
        "core_changed": changed,
        "ready_to_apply": ready_to_apply,
    }

def iter_author_candidates(authors_root: Path):
    """
    Yield (author, .lorprev) pairs from each author folder.
    Adjust the glob to match your layout (e.g., 'UserPreviewStaging/*.lorprev' if needed).
    """
    for author_dir in sorted(p for p in authors_root.iterdir() if p.is_dir()):
        author = author_dir.name
        for p in sorted(author_dir.glob("*.lorprev")):
            yield author, p

# ====================== GAL 25-10-17: Validator & Helpers (END) ======================
# GAL 25-10-19: pretty console list for would-stage previews
def _log_stage_list(label: str, rows: list[dict]):
    """
    rows: dicts containing at least PreviewName, Revision, Author (if present).
    """
    n = len(rows)
    if n == 0:
        print(f"[{label}] WOULD STAGE: 0 preview(s)")
        return
    print(f"[{label}] WOULD STAGE: {n} preview(s)")
    for i, r in enumerate(rows, 1):
        name = r.get("PreviewName") or r.get("FileName") or "?"
        rev  = r.get("Revision") or "?"
        auth = r.get("Author") or r.get("WinnerAuthor") or "?"
        where = r.get("WhereFound") or ""
        # Include a little context if we have it
        extra = f" — {auth}" if auth != "?" else ""
        if where:
            extra += f" [{where}]"
        print(f"  {i:>2}. {name} (rev {rev}){extra}")


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

# ++++ GAL 25-10-19 Change core checking based on parse_props_v6 ++++
# ---------------------------------------------------------------------------
# GAL 25-10-15: File hashing utilities (restored)
# ---------------------------------------------------------------------------

import hashlib
from pathlib import Path
import re

_VOLATILE_PATTERNS = [
    rb"<Revision>\s*\d+\s*</Revision>",       rb'"Revision"\s*:\s*\d+',
    rb"<SavedOn>[^<]+</SavedOn>",             rb'"SavedOn"\s*:\s*"[^"]+"',
    rb"<SavedBy>[^<]+</SavedBy>",             rb'"SavedBy"\s*:\s*"[^"]+"',
    rb"<Exported>[^<]+</Exported>",           rb'"Exported"\s*:\s*"[^"]+"',
    rb"<FileVersion>[^<]+</FileVersion>",     rb'"FileVersion"\s*:\s*"[^"]+"',
]

def sha256_file(path: Path, chunk: int = 1 << 20) -> str:
    """Compute the SHA-256 digest of a file in chunks (1 MB default)."""
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(chunk), b""):
            h.update(block)
    return h.hexdigest()

def semantic_sha256_file(path: Path) -> str:
    """
    Compute a SHA-256 hash after removing volatile metadata patterns.
    Returns a content-stable hash for use in semantic comparison.
    """
    raw = path.read_bytes()
    for pat in _VOLATILE_PATTERNS:
        raw = re.sub(pat, b"", raw)
    raw = re.sub(rb"\s{2,}", b" ", raw)  # compact whitespace
    return hashlib.sha256(raw).hexdigest()


# ===== CORE SNAPSHOT + DIFF using parse_props_v6 (no edits to that file) part 2 25-10-19==========
import hashlib as _hsig
from pathlib import Path

def _nz(x):  # normalize string-ish
    return ("" if x is None else str(x)).strip()

def _as_int(x, default=0):
    try:
        return int(x)
    except Exception:
        return default

def _get(obj, *keys):
    """
    Safe getter that works for:
      - objects (attributes),
      - dict-like,
      - xml.etree.ElementTree.Element (attributes and child tags).
    For ET.Element:
      - If key matches an attribute, return that string.
      - Else if child elements with that tag exist:
          return list[Element] if multiple, or the Element if one.
      - Else return None.
    """
    cur = obj
    for k in keys:
        if cur is None:
            return None

        # object attribute
        if hasattr(cur, k):
            cur = getattr(cur, k)
            continue

        # dict-like
        if isinstance(cur, dict):
            cur = cur.get(k)
            continue

        # ElementTree element
        try:
            import xml.etree.ElementTree as _ET  # local import to avoid top-level cycles
        except Exception:
            _ET = None

        if _ET is not None and isinstance(cur, _ET.Element):
            # attribute?
            if k in cur.attrib:
                cur = cur.attrib[k]
                continue
            # children with this tag?
            kids = list(cur.findall(k))
            if kids:
                cur = kids if len(kids) > 1 else kids[0]
                continue
            return None

        # unknown type
        return None

    return cur


def _iter_grids(prop):
    """
    Yield all channel-grid-like rows for a prop.
    Handles LOR grids and DMX grids; returns zero rows if DeviceType == 'None'.
    Each yielded item is a dict with Network/UID/Start/End/Color/DimmingCurveName.
    """
    # Try the common shapes first
    grids = []
    # LOR style
    for key in ("ChannelGrid", "channel_grid", "Grids", "grids"):
        g = _get(prop, key)
        if g:
            try:
                grids.extend(list(g))
            except Exception:
                pass
    # DMX style (some parsers expose a distinct collection)
    for key in ("DMXChannels", "dmxChannels", "dmx_channels"):
        g = _get(prop, key)
        if g:
            try:
                grids.extend(list(g))
            except Exception:
                pass

    if not grids:
        # No grids at all (e.g., DeviceType == "None")
        yield {
            "Network": "",
            "UID": "",
            "StartChannel": 0,
            "EndChannel": 0,
            "Color": "",
            "DimmingCurveName": _nz(_get(prop, "DimmingCurveName")),
        }
        return

    for row in grids:
        yield {
            "Network":          _nz(_get(row, "Network")),
            "UID":              _nz(_get(row, "UID") or _get(prop, "UID") or _get(prop, "ControllerUID")),
            "StartChannel":     _as_int(_get(row, "StartChannel")),
            "EndChannel":       _as_int(_get(row, "EndChannel")),
            "Color":            _nz(_get(row, "Color") or _get(row, "Lights")),
            "DimmingCurveName": _nz(_get(prop, "DimmingCurveName") or _get(row, "DimmingCurveName")),
        }

def _iter_props_from_preview(path: Path):
    """
    Use parse_props_v6 to load a preview and iterate PropClass entries.
    Defensive against slight API differences (object vs dict).
    """
    try:
        import parse_props_v6 as pp
    except Exception:
        return []

    props = []
    try:
        # common shape
        if hasattr(pp, "load_preview"):
            pv = pp.load_preview(str(path))
            for key in ("props", "PropClass", "Props"):
                arr = _get(pv, key)
                if arr:
                    props = list(arr)
                    break
        elif hasattr(pp, "iter_props"):
            props = list(pp.iter_props(str(path)))
    except Exception:
        props = []

    return props or []

def _row_for_prop_and_grid(prop, gdict) -> tuple:
    """
    Canonical, hashable row representing ONE prop + ONE grid.
    This is the DB-meaningful core we compare.
    """
    prop_id   = _nz(_get(prop, "id") or _get(prop, "PropID"))
    name      = _nz(_get(prop, "Name")).lower()       # Channel Name (case-insensitive)
    comment   = _nz(_get(prop, "Comment") or _get(prop, "LORComment")).lower()  # Display Name
    devtype   = _nz(_get(prop, "DeviceType")).upper() # "LOR" | "DMX" | "NONE" | etc.

    net       = _nz(gdict.get("Network")).upper()
    uid_hex   = _nz(gdict.get("UID")).upper()
    start_ch  = _as_int(gdict.get("StartChannel"))
    end_ch    = _as_int(gdict.get("EndChannel"))
    color     = _nz(gdict.get("Color")).upper()
    curve     = _nz(gdict.get("DimmingCurveName")).lower()

    # Sort-friendly, stable tuple
    return (
        prop_id,
        name,
        comment,
        devtype,
        net,
        uid_hex,
        start_ch,
        end_ch,
        color,
        curve,
    )

def _snapshot_core(path: Path) -> list[tuple]:
    """
    Produce the full canonical core snapshot:
      one row per (PropClass × ChannelGrid-or-DMX-grid). If no grids, a single
      row with empty grid fields is emitted so "None" devices still participate.
    """
    out = []
    for prop in _iter_props_from_preview(Path(path)):
        emitted = False
        for g in _iter_grids(prop):
            out.append(_row_for_prop_and_grid(prop, g))
            emitted = True
        if not emitted:
            # Extremely defensive fallback: synthesize one row even if _iter_grids missed.
            out.append(_row_for_prop_and_grid(prop, {
                "Network": "", "UID": "", "StartChannel": 0, "EndChannel": 0, "Color": "", "DimmingCurveName": _nz(_get(prop, "DimmingCurveName")),
            }))
    out.sort(key=lambda r: (r[0], r[3], r[4], r[5], r[6], r[7], r[1]))  # PropID, DevType, Network, UID, Start, End, Name
    return out

def _sig(rows: list[tuple]) -> tuple[str, int]:
    if not rows:
        return ("", 0)
    h = _hsig.sha256()
    for r in rows:
        h.update(str(r).encode("utf-8"))
    return (h.hexdigest()[:16], len(rows))



def diff_core_fields(src: Path, dst: Path) -> tuple[bool, list[str]]:
    """
    Compare two previews at DB-meaningful granularity using lor_core.core_items_from_lorprev():
      - DeviceType None → (DisplayName=Comment, ChannelName=Name) via LBLTXT tuples
      - LOR legs        → (LOR, Network, UID, Start, End, Color)
      - DMX legs        → (DMX, Network, Universe, Start, End)
    Returns (same, changed_fields[])
    """
    import hashlib

    def _sig(items: set[tuple]) -> str:
        blob = "\n".join(repr(t) for t in sorted(items))
        return hashlib.sha256(blob.encode("utf-8")).hexdigest()[:16]

    # Fallback: in case lor_core couldn’t import for some reason
    if LC is None or not hasattr(LC, "core_items_from_lorprev"):
        try:
            from xml.etree import ElementTree as ET  # noqa
        except Exception:
            return False, ["NoCoreExtractor"]
        raise RuntimeError("lor_core.core_items_from_lorprev not available; please add it per instructions.")

    # GAL 25-10-20: show which lor_core is active during this compare
    if DEBUG_CORE:
        try:
            _core_ver = getattr(LC, "CORE_MODEL_VERSION", "unknown")
            _core_src = getattr(LC, "__file__", "?")
            print(f"[core] compare using lor_core={_core_ver}  source={_core_src}")
        except Exception:
            pass

    # GAL 25-10-20: already Path objects, no need to rewrap
    a_items, a_stats = LC.core_items_from_lorprev(src)
    b_items, b_stats = LC.core_items_from_lorprev(dst)

    # GAL 25-10-20: compute signatures first so we can always log them
    a_sig = _sig(a_items)
    b_sig = _sig(b_items)

    # GAL 25-10-20: compact debug — sizes + sigs + first few tuples to catch label-only diffs
    if DEBUG_CORE:
        try:
            _a_head = tuple(sorted(a_items))[:6]
            _b_head = tuple(sorted(b_items))[:6]
            print(f"[core] A(src) size={len(a_items)} sig={a_sig}  |  B(dst) size={len(b_items)} sig={b_sig}")
            print(f"[core] A(src) head6={_a_head}")
            print(f"[core] B(dst) head6={_b_head}")
        except Exception:
            pass

    same = (a_items == b_items)
    if same:
        return True, []

    changes: list[str] = []
    if a_stats.get("props_total") != b_stats.get("props_total"):
        changes.append(f"PropCount:{b_stats.get('props_total')}→{a_stats.get('props_total')}")
    if a_sig != b_sig:
        changes.append(f"CoreSetSig:{b_sig}→{a_sig}")

    return False, changes



def core_signature(path: Path) -> str:
    """
    Content-stable signature based on the canonical core snapshot
    (PropClass × grids). Uses the same rows as diff_core_fields().
    """
    rows = _snapshot_core(Path(path))
    h = _hsig.sha256()
    for r in rows:
        h.update(str(r).encode("utf-8"))
    return h.hexdigest()
# ===== /CORE SNAPSHOT + DIFF part 2 25-10-19=====







# GAL 25-10-16: Scan AUTHOR folders for comment hygiene
def scan_authors_for_comments(input_root: Path) -> list[dict]:
    """
    Returns list of rows describing comment hygiene issues found in AUTHOR folders.

    Columns returned (no paths):
      Author, PreviewName, CommentStatus, Reason, WhereFound, Revision, Size (optional), Exported (optional)
    """
    rows: list[dict] = []
    if not input_root or not Path(input_root).exists():
        return rows

    for author_dir in sorted(Path(input_root).iterdir()):
        if not author_dir.is_dir():
            continue
        author = author_dir.name
        for p in sorted(author_dir.glob("*.lorprev")):
            try:
                # Minimal, resilient identity read
                idy = parse_preview_identity(p)
                preview_name = (idy.name or '').strip()
                st = p.stat()
                # Validate the LOR Comment (Display Name) by parsing XML quickly
                ok, reason = True, "ok"
                try:
                    tree = ET.parse(p)
                    root = tree.getroot()
                    # find first Comment tag under a typical Prop (fast path)
                    comment_text = None
                    for el in root.iter():
                        tag = (el.tag or '').split('}')[-1]
                        if tag in ('Comment', 'Comments'):
                            comment_text = el.text or ''
                            break
                    ok, reason = validate_display_name(comment_text)
                except Exception:
                    ok, reason = False, "unreadable"

                if not ok:
                    rows.append({
                        "Author": author,
                        "PreviewName": preview_name,
                        "CommentStatus": "invalid",
                        "Reason": reason,
                        "WhereFound": "AuthorFolder",
                        "Revision": idy.revision_raw or '',
                        "Size": st.st_size,
                        "Exported": ymd_hms(st.st_mtime),
                    })
            except Exception:
                # unreadable file in author folder – skip but do not crash
                continue
    return rows


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
    import csv, html  # GAL 25-10-15: ensure local import available

    out_dir = report_csv.parent
    ledger_csv = out_dir / f'{LEDGER_BASENAME}.csv'
    ledger_html = out_dir / f'{LEDGER_BASENAME}.html'
    run_ledger = out_dir / RUN_LEDGER_NAME

    # -----------------------------------------------------------------------
    # GAL 25-10-15: helper — describe what needs to happen (for Comment)
    # -----------------------------------------------------------------------
    def _action_needed_for_row(r: dict) -> str | None:
        a = (r.get('Action') or '').lower().strip()
        s = (r.get('Status') or '').lower().strip()
        reason = (r.get('Reason') or r.get('WinnerReason') or '').lower().strip()

        if a in ('stage-new',):
            return "Stage new"
        if a in ('update-staging',) or 'replace' in a:
            return "Replace staged (winner newer)"
        if 'ready to apply' in a or 'ready to apply' in s:
            return "Apply to staging"
        if 'out-of-date' in a or 'out-of-date' in s:
            return "Staged out-of-date"
        if 'semantic' in reason and 'different' in reason:
            return "Replace staged (content changed)"
        # fallbacks — show trimmed action or status if it looks meaningful
        if a and a not in ('noop', 'current'):
            return a.capitalize()
        if s and s not in ('current',):
            return s.capitalize()
        return None

    # Append this run’s apply events to the small run ledger
    if applied_this_run:
        write_header = not run_ledger.exists()
        with run_ledger.open('a', encoding='utf-8-sig', newline='') as f:
            cols = ['Key','PreviewName','Author','Revision','Size','Exported','ApplyDate','AppliedBy']
            w = csv.DictWriter(f, fieldnames=cols)
            if write_header:
                w.writeheader()
            for r in applied_this_run:
                w.writerow({c: r.get(c, '') for c in cols})

    # Build a Key -> (ApplyDate, AppliedBy) map from the accumulated run ledger
    last_apply = {}
    if run_ledger.exists():
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

        # GAL 25-10-15: synthesize Comment if action is needed
        action_needed = _action_needed_for_row(r)
        if action_needed:
            # If a comment already exists, append; else write fresh text
            existing = (r.get('Comment') or '').strip()
            r['Comment'] = (existing + ('; ' if existing else '') + f"Needs action — {action_needed}")

        k = r.get('Key') or ''
        ad, ab = last_apply.get(k, ('', ''))
        r['ApplyDate'] = ad
        r['AppliedBy'] = ab

    # If this run applied some items, stamp those ApplyDate/AppliedBy now
    if applied_this_run:
        # GAL 25-10-15: ensure mapping by Key (skip missing)
        apply_now = {rr['Key']: (rr.get('ApplyDate',''), rr.get('AppliedBy','')) for rr in applied_this_run if rr.get('Key')}
        for r in current:
            k = r.get('Key') or ''
            if k in apply_now:
                r['ApplyDate'], r['AppliedBy'] = apply_now[k]

    # Sort and write CSV
    current.sort(key=lambda r: (r.get('Author') or '', r.get('PreviewName') or '', r.get('Revision') or ''))

    # GAL 25-10-15: include Comment in the ledger CSV (for filtering)
    cols = ['PreviewName','Size','Revision','Author','Exported','ApplyDate','AppliedBy','Status','DisplayNamesFilledPct','Comment','Key']
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
    html_parts.append(f"<div class='meta'>Generated {dt.datetime.now().astimezone().isoformat(timespec='seconds')}</div>")

    # Grouped by Author
    from itertools import groupby
    for author, group in groupby(current, key=lambda r: r.get('Author') or ''):
        rows_ = list(group)
        html_parts.append(f"<h2>{(author or '(unknown)')}</h2>")
        # GAL 25-10-15: include Comment column in HTML
        html_parts.append(_table(rows_, ['PreviewName','Size','Revision','Exported','ApplyDate','AppliedBy','Status','DisplayNamesFilledPct','Comment']))

    ledger_html.write_text('\n'.join(html_parts), encoding='utf-8')
    return ledger_csv, ledger_html, run_ledger

# === GAL 2025-10-18 22:05 — backfill_apply_events fixed for current DB schema (RO, join on run_id) ===
def backfill_apply_events(report_csv: Path, history_db: Path, staging_root: Path, overwrite: bool=False) -> tuple[Path, int]:
    r"""
    Populate apply_events.csv for current winners using preview_history.db (if available, READ-ONLY),
    falling back to filesystem mtimes for staged files. Returns (events_path, rows_written).
    Schema expected:
      runs(run_id TEXT PRIMARY KEY, started TEXT, policy TEXT)
      staging_decisions(id INTEGER PK, run_id TEXT, preview_key TEXT, staged_as TEXT, action TEXT)
    """
    # Read the current compare rows
    with open(report_csv, 'r', encoding='utf-8-sig', newline='') as f:
        compare_rows = list(csv.DictReader(f))

    # Winners only (keep REPORT-ONLY if you rely on it for summaries)
    winners = [r for r in compare_rows if r.get('Role') in ('WINNER', 'REPORT-ONLY')]
    by_key = {r.get('Key',''): r for r in winners if r.get('Key')}

    events_path = Path(report_csv).parent / RUN_LEDGER_NAME  # e.g., apply_events.csv

    # Read existing events to avoid duplicate/older inserts
    existing: dict[str, tuple[str,str]] = {}
    if events_path.exists() and not overwrite:
        with open(events_path, 'r', encoding='utf-8-sig', newline='') as f:
            for r in csv.DictReader(f):
                k = r.get('Key') or ''
                if k:
                    existing[k] = (r.get('ApplyDate','') or '', r.get('AppliedBy','') or '')

    # Query DB (READ ONLY) for staged decisions (latest per key), joined to runs.started
    latest: dict[str, tuple[str,str,str]] = {}  # key -> (staged_as, run_started_iso, applied_by)
    conn = None
    cur = None
    try:
        import sqlite3
        uri = f"file:{Path(history_db).as_posix()}?mode=ro"
        conn = sqlite3.connect(uri, uri=True)
        cur  = conn.cursor()

        # Be defensive: check if tables/columns exist
        def _has_table(name: str) -> bool:
            cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name=?", (name,))
            return cur.fetchone() is not None

        if _has_table("staging_decisions"):
            # Prefer join to runs.started if runs exists; otherwise just read decisions
            join_runs = _has_table("runs")
            if join_runs:
                # Ensure 'started' column exists
                cur.execute("PRAGMA table_info(runs)")
                cols = {row[1] for row in cur.fetchall()}  # name in second column
                has_started = "started" in cols
            else:
                has_started = False

            if join_runs and has_started:
                # Correct join for current schema (r.run_id = sd.run_id)
                q = """
                    SELECT sd.preview_key,
                           sd.staged_as,
                           r.started AS run_started
                    FROM staging_decisions sd
                    LEFT JOIN runs r ON r.run_id = sd.run_id
                    WHERE sd.action='staged'
                    ORDER BY COALESCE(r.started, '') DESC, sd.rowid DESC
                """
                cur.execute(q)
                for key, staged_as, run_started in cur.fetchall():
                    if key not in by_key or key in latest:
                        continue
                    latest[key] = (staged_as or '', run_started or '', '')  # AppliedBy unknown in this schema
            else:
                # Fallback: no runs.started; take latest by rowid
                q = "SELECT preview_key, staged_as FROM staging_decisions WHERE action='staged' ORDER BY rowid DESC"
                cur.execute(q)
                for key, staged_as in cur.fetchall():
                    if key not in by_key or key in latest:
                        continue
                    latest[key] = (staged_as or '', '', '')  # no run timestamp available
    except Exception:
        # DB unavailable or schema mismatch: we'll fall back to file mtimes below
        pass
    finally:
        try:
            if cur is not None:
                cur.close()
        except Exception:
            pass
        try:
            if conn is not None:
                conn.close()
        except Exception:
            pass

    # Build rows to write (newer only)
    rows_to_write: list[dict] = []
    for key, r in by_key.items():
        staged_as, run_started, applied_by = latest.get(key, ('', '', ''))
        apply_date = run_started  # prefer run's started if present
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
# === /GAL 2025-10-18 22:05 ===


# Builds a manifest of current previews and archives old previews
def sweep_staging_archive(staging_root: Path, archive_root: Path, keep_files: set[str]) -> tuple[int,int]:
    r"""
    Move any *.lorprev in staging_root that is not in keep_files into
    archive_root\YYYY-MM-DD\ (preserves filename).
    Returns (moved, kept).
    """
    moved = kept = 0
    ensure_dir(archive_root)
    day_folder = archive_root / dt.datetime.now().strftime("%Y-%m-%d")
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

# GAL 25-10-18: Build CURRENT (apply) manifest CSV from staged files
def write_current_manifest_csv(staging_root: Path, out_csv: Path):
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

# GAL 25-10-18: Build CURRENT (apply) manifest HTML from staged files
def write_current_manifest_html(staging_root: Path, out_html: Path, author_by_name: dict[str, str] | None = None):
    """
    Write a sortable HTML manifest for the CURRENTLY STAGED previews (.lorprev in staging_root).
    Columns: FileName, Author, Revision, Present, StagedTime
    Notes:
      - Author is looked up via author_by_name map (keyed by PreviewName) if provided.
      - Present is always "Yes" (we’re listing what’s actually staged).
      - Uses existing scan_staged_for_comments() and _emit_manifest_html() helpers.
    """

    def _revnum(v: str) -> float:
        try:
            return float(v or "")
        except Exception:
            return -1.0

    staging_root = Path(staging_root)
    out_html = Path(out_html)
    out_html.parent.mkdir(parents=True, exist_ok=True)

    # Reuse your staged scanner (already in this file)
    staged_map = scan_staged_for_comments(staging_root)

    rows = []
    for _, info in staged_map.items():
        ppath   = Path(info.get("Path", ""))
        fname   = ppath.name
        pn      = (info.get("PreviewName") or "").strip()
        rev     = (info.get("Revision") or "").strip()
        author  = (author_by_name or {}).get(pn, "") if pn else ""
        present = "Yes"
        staged_time = ""
        try:
            ts = os.path.getmtime(ppath)
            staged_time = datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S")
        except Exception:
            pass

        # Columns: FileName, Author, Revision, Present, StagedTime
        rows.append((fname, author, rev, present, staged_time))

    # Sort FileName asc, Revision desc
    rows.sort(key=lambda x: ((x[0] or "").lower(), -_revnum(x[2])))

    # Reuse your HTML renderer used by write_dryrun_manifest_html
    _emit_manifest_html(
        rows,
        out_html,
        headers=[
            ("FileName",   "text"),
            ("Author",     "text"),
            ("Revision",   "number"),
            ("Present",    "text"),
            ("StagedTime", "text"),
        ],
        context_path=str(out_html.parent),
        extra_title=""  # live/current (no DRY RUN tag)
    )
    print(f"[apply] wrote current manifest (HTML): {out_html}")


def _write_csv_atomic(out_path: Path, fieldnames: list[str], rows: list[dict], *,
                      attempts: int = 4, wait_sec: float = 0.6, allow_fallback: bool = True) -> Path:
    """
    Write CSV atomically to shared drives with basic retry.
    Returns the path actually written (out_path or a fallback path).
    Never raises on PermissionError; falls back if locked.
    """
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)

    # Try N times to write atomically: temp → replace
    last_err = None
    for i in range(attempts):
        try:
            # write to a temp file on same volume
            with tempfile.NamedTemporaryFile("w", newline="", encoding="utf-8-sig",
                                             delete=False, dir=str(out_path.parent)) as tmp:
                tmp_path = Path(tmp.name)
                w = csv.DictWriter(tmp, fieldnames=fieldnames)
                w.writeheader()
                w.writerows(rows)
            # atomic replace (best effort on Windows network shares)
            try:
                os.replace(tmp_path, out_path)
            finally:
                if tmp_path.exists():
                    try: tmp_path.unlink(missing_ok=True)
                    except Exception: pass
            return out_path
        except PermissionError as e:
            last_err = e
            time.sleep(wait_sec)
        except Exception as e:
            # other errors: re-raise
            raise

    # Still locked? Write to a timestamped fallback to avoid blocking the run.
    if allow_fallback:
        stamp = time.strftime("%Y%m%d-%H%M%S")
        fb = out_path.with_name(f"{out_path.stem}-{stamp}-locked.csv")
        with fb.open("w", newline="", encoding="utf-8-sig") as f:
            w = csv.DictWriter(f, fieldnames=fieldnames)
            w.writeheader()
            w.writerows(rows)
        print(f"[warn] Could not write {out_path.name} (locked). Wrote fallback: {fb.name}")
        return fb
    else:
        # propagate the last PermissionError
        raise last_err if last_err else PermissionError(f"Failed to write {out_path}")

# import os, time  # (if not already imported)

# Two Helpers for file metadata for the dry-run process GAL 25-10-18
def _fmt_mtime(path: Path | None) -> str:
    if not path or not path.exists():
        return ""
    try:
        ts = os.path.getmtime(path)
        # local time; matches what you see on the share in Explorer
        return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(ts))
    except Exception:
        return ""

def _filesize(path: Path | None) -> int | str:
    if not path or not path.exists():
        return ""
    try:
        return os.path.getsize(path)
    except Exception:
        return ""


# a dry-run (“would-be”) manifest from preview_merger.py without changing any files GAL 25-09-15
# Added atomic_writer to prevent partial writes on network shares GAL 25-10-18
def write_dryrun_manifest_csv(
    staging_root: Path,
    winner_rows: list,
    out_name: str = "current_previews_manifest_dry-run.csv",
    author_by_name: dict[str, str] | None = None,
    input_root: Path | None = None,
    all_rows: list | None = None,   # full compare rows (for NeedsAction)
):
    """
    DRY-RUN:
      - Writes a would-be manifest (winners only, de-duped by PreviewName highest Revision) in the staging root.
      - Backfills reports/current_previews_ledger.csv from winners (same as manifest).
      - Builds reports/needs_action.csv from all_rows (full compare) using STRICT inclusion and core_different() gating.
        Also writes needs_action_debug.csv (debug write never blocks).
    """
    # ---- helpers ----
    def _revnum(v: str) -> float:
        try:
            return float(v or "")
        except Exception:
            return -1.0

    def _norm_action(s: str) -> str:
        # lower; collapse spaces/_// into '-' for consistent matching
        return re.sub(r"[\s_/]+", "-", (s or "").strip().lower())

    def _author_from_winnerfrom(wf: str) -> str:
        s = (wf or "").strip()
        return s.split(":", 1)[1].strip() if s.upper().startswith("USER:") else s

    def _dedupe_manifest(rows: list[dict]) -> list[dict]:
        """Keep one row per PreviewName, preferring highest Revision."""
        best: dict[str, dict] = {}
        for r in rows:
            pn = (r.get("PreviewName") or "").strip()
            if not pn:
                continue
            key = pn.lower()
            cur = best.get(key)
            if cur is None or _revnum(r.get("Revision")) > _revnum(cur.get("Revision")):
                best[key] = r
        out = list(best.values())
        out.sort(key=lambda x: (x["PreviewName"].lower(), -_revnum(x["Revision"])))
        return out

    staging_root = Path(staging_root)
    reports_dir = staging_root / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)
    input_root_safe = Path(input_root) if input_root else None

    # Current staged .lorprev files (root only)
    staged_existing = {p.name.lower() for p in staging_root.glob("*.lorprev")}

    # ------------------------------------------------------------------------------
    # 1) Manifest (WINNERS ONLY, DE-DUPED)  +  Ledger (WINNERS ONLY, DE-DUPED)
    # ------------------------------------------------------------------------------
    manifest_rows_raw = []
    for r in winner_rows:
        pn = (r.get("PreviewName") or "").strip()
        if not pn:
            continue
        fname   = f"{pn}.lorprev"
        present = "Yes" if fname.lower() in staged_existing else "No"
        rev     = r.get("Revision") or ""
        act     = (r.get("Action") or "").strip()
        author  = (author_by_name or {}).get(pn, "")
        manifest_rows_raw.append({
            "FileName": fname,
            "PreviewName": pn,
            "Author": author,
            "Revision": rev,
            "Action": act,
            "Present": present,
        })

    manifest_rows = _dedupe_manifest(manifest_rows_raw)

    # Manifest file (staging root)
    manifest_csv = staging_root / out_name
    _write_csv_atomic(
        manifest_csv,
        ["FileName","PreviewName","Author","Revision","Action","Present"],
        manifest_rows,
        attempts=3
    )
    print(f"[dry-run] wrote preview manifest (no changes made): {manifest_csv}")

    # Ledger mirrors winners (de-duped)
    ledger_csv = reports_dir / "current_previews_ledger.csv"
    _write_csv_atomic(
        ledger_csv,
        ["FileName","PreviewName","Author","Revision","Action","Present"],
        manifest_rows,
        attempts=3
    )
    print(f"[backfill] Ledger CSV: {ledger_csv} (rows={len(manifest_rows)})")

    # ------------------------------------------------------------------------------
    # 2) Needs_Action (built from full compare rows) + Debug
    # ------------------------------------------------------------------------------
    # Build base rows from all_rows if available; fallback to manifest_rows
    if all_rows is None:
        base_rows = manifest_rows[:]
    else:
        base_rows = []
        for r in all_rows:
            pn = (r.get("PreviewName") or "").strip()
            if not pn:
                continue
            fname   = f"{pn}.lorprev"
            present = "Yes" if fname.lower() in staged_existing else "No"

            # Preferred author: explicit map → WinnerFrom → unknown (scan later)
            author = ""
            if author_by_name and pn in author_by_name:
                author = author_by_name[pn]
            elif r.get("WinnerFrom"):
                author = _author_from_winnerfrom(r.get("WinnerFrom"))

            base_rows.append({
                "FileName":    fname,
                "PreviewName": pn,
                "Author":      author,
                "Revision":    r.get("Revision") or "",
                "Action":      (r.get("Action") or "").strip(),
                "Present":     present,
                "Role":        (r.get("Role") or "").strip(),        # WINNER / STAGED / CANDIDATE / REPORT-ONLY
                "WinnerFrom":  (r.get("WinnerFrom") or "").strip(),
            })

    IGNORE_ACTIONS = {"", "noop", "no-op", "ok", "current", "same", "skip", "none", "unchanged"}

    # ---------- Pick ONE best candidate per PreviewName ----------
    # Priority:
    #   role_score: WINNER(2) > STAGED(1) > others(0, excluded anyway)
    #   action_score: real change (2) > staged-out-of-date (1) > otherwise (0)
    #   rev_score: numeric Revision (higher is better)
    def _role_score(role: str) -> int:
        r = (role or "").strip().upper()
        if r == "WINNER": return 2
        if r == "STAGED": return 1
        return 0

    def _action_score(norm_action: str, role_u: str) -> int:
        if norm_action not in IGNORE_ACTIONS:
            return 2
        if role_u == "STAGED" and norm_action in {"out-of-date", "update-staging"}:
            return 1
        return 0

    best_by_pn: dict[str, dict] = {}     # key = previewname lower -> chosen row
    debug_rows: list[dict] = []          # write a debug row for every base row

    for r in base_rows:
        pn          = (r.get("PreviewName") or "").strip()
        if not pn:
            continue
        rev_s       = (r.get("Revision") or "").strip()
        rev_num     = _revnum(rev_s)
        raw_action  = (r.get("Action") or "").strip()
        norm_action = _norm_action(raw_action)
        role_u      = (r.get("Role") or "").strip().upper()
        present     = (r.get("Present") or "").strip().lower()

        # STRICT inclusion by role, matching summary
        if role_u not in {"WINNER", "STAGED"}:
            include = False
            include_reason = "excluded by role"
        else:
            include = (
                (norm_action not in IGNORE_ACTIONS) or
                (role_u == "STAGED" and norm_action in {"out-of-date", "update-staging"}) or
                (role_u == "WINNER" and present == "no")
            )
            if not include:
                include_reason = "no action and already present"
            else:
                if norm_action not in IGNORE_ACTIONS:
                    include_reason = "non-empty change action"
                elif role_u == "STAGED":
                    include_reason = "staged is out-of-date"
                else:
                    include_reason = "not present in staging (winner)"

        # Always record debug
        debug_rows.append({
            "PreviewName":   pn,
            "RawAction":     raw_action,
            "NormAction":    norm_action,
            "Role":          r.get("Role",""),
            "Present":       r.get("Present",""),
            "Author":        r.get("Author",""),
            "AuthorFile":    "",
            "StagedFile":    str(staging_root / f"{pn}.lorprev"),
            "Include":       "yes" if include else "no",
            "IncludeReason": include_reason,
            "ReadyToApply":  "no",
            "Blockers":      "",
        })

        if not include:
            continue

        # Choose the single best candidate per PreviewName
        score = (_role_score(role_u), _action_score(norm_action, role_u), rev_num)
        key = pn.lower()
        cur = best_by_pn.get(key)
        if cur is None or score > cur.get("_score", (-1,-1,-1)):
            r["_score"] = score
            best_by_pn[key] = r

    # ---------- UPDATED GAL 25-10-20 ----------
    # Choose newest AuthorRoot export for this preview (latest-export wins).
    # We ignore PreviewsForProps on purpose (future enhancement).
    def _find_author_and_file(pn: str, author_hint: str | None) -> tuple[str, Path | None, str]:
        """
        Return (author_name, author_file_path_or_None, where_found_tag)

        Policy (GAL 25-10-20):
        - Scan *all* AuthorRoot user folders for <pn>.lorprev
        - Pick the newest by modification time (mtime)
        - Tag as "AuthorRoot(latest)"
        - If none exist, return (author_hint or "", None, "Unknown")

        Rationale:
        - Exports are deliberate actions by users; newest export is presumed intent.
        - Ensures dry-run compares Staging vs most recent user work, regardless of "owner".
        """
        if not input_root_safe or not input_root_safe.exists():
            return (author_hint or "", None, "Unknown")

        newest_author: str | None = None
        newest_path:   Path | None = None
        newest_mtime:  float | None = None

        try:
            for a_dir in input_root_safe.iterdir():
                if not a_dir.is_dir():
                    continue
                p_root = a_dir / f"{pn}.lorprev"
                if p_root.exists():
                    try:
                        m = os.path.getmtime(p_root)
                    except Exception:
                        # If we cannot stat, skip
                        continue
                    if newest_mtime is None or m > newest_mtime:
                        newest_author = a_dir.name
                        newest_path   = p_root
                        newest_mtime  = m
        except Exception:
            # Fall through to Unknown
            pass

        if newest_path is not None:
            if DEBUG_CORE:
                try:
                    print(f"[core] PREVIEW={pn}  AUTHOR(selected)={newest_author}  src={newest_path}  where=AuthorRoot(latest)")
                except Exception:
                    pass
            return (newest_author or "", newest_path, "AuthorRoot(latest)")

        # No matching author export found
        return (author_hint or "", None, "Unknown")


    needs_rows: list[dict] = []

    for key, r in best_by_pn.items():
        pn          = r["PreviewName"]
        present     = (r["Present"] or "").strip().lower()   # "yes"/"no"
        raw_action  = r["Action"]

        # Resolve author hint (explicit map -> WinnerFrom -> None)
        author_hint = (r.get("Author") or "").strip()
        if not author_hint:
            wf = (r.get("WinnerFrom") or "").strip()
            if wf:
                author_hint = wf.split(":",1)[1].strip() if wf.upper().startswith("USER:") else wf

        author, author_file, where_tag = _find_author_and_file(pn, author_hint)
        staged_file = staging_root / f"{pn}.lorprev"

        # Collect file stats
        author_time = _fmt_mtime(author_file)
        author_size = _filesize(author_file)
        staged_time = _fmt_mtime(staged_file)
        staged_size = _filesize(staged_file)

        # author newer?
        author_newer = ""
        try:
            if author_file and staged_file.exists():
                author_newer = "yes" if os.path.getmtime(author_file) > os.path.getmtime(staged_file) else "no"
            elif author_file and not staged_file.exists():
                author_newer = "yes"  # new file
        except Exception:
            author_newer = ""

        # ----- CORE DIFF (exactly what APPLY checks) -----
        # ----- CORE DIFF (exactly what APPLY checks) --25-10-19- updated--
        # ----- CORE DIFF (exactly what APPLY checks) -----
        core_diff_flag = ""          # "yes" | "no" | "" (unknown)
        core_changed_list: list[str] = []
        core_different = None        # True | False | None(unknown)

        try:
            # Use our local diff_core_fields (parse_props_v6–backed)
            if author_file and staged_file.exists():
                same, changed_fields = diff_core_fields(author_file, staged_file)
                core_different    = (not same)
                core_diff_flag    = "yes" if core_different else "no"
                core_changed_list = changed_fields or []
            elif author_file and not staged_file.exists():
                # no staged file yet → treat as different (a new stage)
                core_different = True
                core_diff_flag = "yes"
        except Exception:
            core_different    = None
            core_diff_flag    = ""
            core_changed_list = []
        # GAL 25-10-20: annotate where/how the author file was chosen, and compute AuthorNewer
        # GAL 25-10-20: annotate where/how the author file was chosen, and compute AuthorNewer
        row_where_found = where_tag  # e.g., "AuthorRoot(latest)"

        try:
            staged_mtime = staged_file.stat().st_mtime if staged_file and staged_file.exists() else 0
            author_mtime = author_file.stat().st_mtime if author_file and author_file.exists() else 0
            row_author_newer = "yes" if author_mtime > staged_mtime else ("no" if staged_mtime else "unknown")
        except Exception:
            row_author_newer = "unknown"

        # Ensure this recomputed flag drives both blockers/ready and the row
        author_newer = row_author_newer  # GAL 25-10-20

        if DEBUG_CORE:
            try:
                print(f"[core] META PREVIEW={pn}  AUTHOR={author}  where={row_where_found}  author_newer={row_author_newer}")
            except Exception:
                pass


        # Extra debug: per-side counts & signatures (using same snapshotter)
        try:
            from pathlib import Path as _P
            _arows = _snapshot_core(_P(author_file)) if author_file else []
            _srows = _snapshot_core(staged_file) if staged_file.exists() else []
            _asig, _acnt = _sig(_arows)
            _ssig, _scnt = _sig(_srows)
        except Exception:
            _acnt = _scnt = 0
            _asig = _ssig = ""


        # ----- Ready / Blockers (mirror APPLY gate) -----
        ready    = False
        blockers = []

        if present == "no":
            if author_file:
                ready = True
            else:
                blockers.append("author file missing (root only)")
        else:
            # Present == yes → require core DIFFERENT AND author newer
            # Present == yes → require core DIFFERENT AND author newer
            if not author_file:
                blockers.append("author file missing (root only)")

            if author_file and staged_file.exists():
                # Mirror APPLY: only stage when core_different is True
                if core_different is False:
                    blockers.append("core-identical (DB fields unchanged)")
                # Only check recency when we have both files
                try:
                    if author_newer != "yes":
                        blockers.append("author older than staged")
                except Exception:
                    blockers.append("timestamp check failed")

            # Ready iff both conditions satisfied
            ready = (
                (author_file is not None)
                and (core_different is True)
                and (author_newer == "yes")
            )

            if not ready and not blockers:
                blockers.append("not ready: unmet criteria")


        needs_rows.append({
            "FileName":       r.get("FileName",""),
            "PreviewName":    pn,
            "Author":         author,
            "Revision":       r.get("Revision",""),
            "Action":         raw_action,
            "Present":        present,
            "ReadyToApply":   "yes" if ready else "no",
            "Blockers":       ", ".join(blockers),
            "WhereFound":     where_tag if author else "Unknown",
            "AuthorFileTime": author_time,
            "AuthorFileSize": author_size,
            "StagedFileTime": staged_time,
            "StagedFileSize": staged_size,
            "AuthorNewer":    author_newer,
            "CoreDifferent":  core_diff_flag,
            "CoreChangedFields": ", ".join(core_changed_list),
            "PropCountAuthor": _acnt, # 25-10-19 GAL extra debug
            "PropCountStaged": _scnt,
            "CoreSigAuthor":   _asig,
            "CoreSigStaged":   _ssig,

        })

    # --- WRITE Needs_Action (management) & Debug (diagnostics) CSVs ---
    needs_csv = reports_dir / "needs_action.csv"
    _write_csv_atomic(
        needs_csv,
        [
            "FileName","PreviewName","Author","Revision","Action","Present",
            "ReadyToApply","Blockers","WhereFound",
            "AuthorFileTime","AuthorFileSize","StagedFileTime","StagedFileSize",
            "AuthorNewer","CoreDifferent","CoreChangedFields",
            # GAL 25-10-19: include debug columns (present in needs_rows)
            "PropCountAuthor","PropCountStaged","CoreSigAuthor","CoreSigStaged",
        ],
        needs_rows,
        attempts=3
    )
    print(f"[backfill] Needs_Action CSV: {needs_csv} (rows={len(needs_rows)})")

    for d in debug_rows:
        d.setdefault("CoreDifferent", "")
        d.setdefault("CoreChangedFields", "")

    dbg_csv = reports_dir / "needs_action_debug.csv"
    _write_csv_atomic(
        dbg_csv,
        [
            "PreviewName","RawAction","NormAction","Role","Present","Author","AuthorFile",
            "AuthorFileTime","AuthorFileSize","StagedFile","StagedFileTime","StagedFileSize",
            "AuthorNewer","Include","IncludeReason","ReadyToApply","Blockers",
            "CoreDifferent","CoreChangedFields"
        ],
        debug_rows,
        attempts=2
    )
    print(f"[backfill] Needs_Action DEBUG: {dbg_csv} (rows={len(debug_rows)})")

    # ---- DRY-RUN SUMMARY: how many WOULD stage if --apply ----
    ready_to_apply = [
        r for r in needs_rows
        if (r.get("ReadyToApply", "").lower() == "yes")
    ]

    # Pretty console list (replaces single-line comma join)
    print(f"[dry-run] WOULD STAGE: {len(ready_to_apply)} preview(s)")
    for i, r in enumerate(ready_to_apply, 1):
        name  = r.get("PreviewName") or r.get("FileName") or "?"
        rev   = r.get("Revision") or "?"
        auth  = r.get("Author") or r.get("WinnerAuthor") or "?"
        where = r.get("WhereFound") or ""
        extra = f" — {auth}" if auth != "?" else ""
        if where:
            extra += f" [{where}]"
        print(f"   {i:>2}. {name} (rev {rev}){extra}")
    # Also show previews that differ but are NOT ready, with the gating reason
    not_ready = [
        r for r in needs_rows
        if (r.get("ReadyToApply", "").lower() != "yes")
    ]
    print(f"[dry-run] NOT READY: {len(not_ready)} preview(s)")
    for i, r in enumerate(not_ready, 1):
        name  = r.get("PreviewName") or r.get("FileName") or "?"
        rev   = r.get("Revision") or "?"
        auth  = r.get("Author") or r.get("WinnerAuthor") or "?"
        where = r.get("WhereFound") or ""
        blockers = r.get("Blockers") or r.get("ActionNeeded") or ""
        extra = f" — {auth}" if auth != "?" else ""
        if where:
            extra += f" [{where}]"
        if blockers:
            extra += f"  (reason: {blockers})"
        print(f"   {i:>2}. {name} (rev {rev}){extra}")



    # Persist a tiny summary so Excel/automation can use it
    # JSON with full list, and a human-readable TXT
    # >>> GAL 2025-10-20: write would_stage summary safely
    try:
        import json as _json
        names = [(r.get("PreviewName") or r.get("FileName") or "?") for r in ready_to_apply]
        ws_json = {"count": len(ready_to_apply), "previews": names}
        (reports_dir / "would_stage.json").write_text(
            _json.dumps(ws_json, ensure_ascii=False, indent=2),
            encoding="utf-8"
        )
        (reports_dir / "would_stage.txt").write_text(
            f"{len(ready_to_apply)} preview(s) would stage:\n" + "\n".join(names),
            encoding="utf-8"
        )
    except Exception as _e:
        print(f"[warn] failed writing would_stage summary: {_e}")
    # <<< GAL 2025-10-20





# GAL 25-10-18: Updated to mirror manifest CSV and include timestamps
# --- DRY-RUN HTML manifest (adds Present + StagedTime) ---
# --- DRY-RUN HTML manifest (de-dupe by PreviewName, keep highest Revision) ---
# GAL 25-10-18: Updated to mirror manifest CSV and include timestamps
# --- DRY-RUN HTML manifest (adds Present + StagedTime) ---
# --- DRY-RUN HTML manifest (de-dupe by PreviewName, keep highest Revision) ---
def write_dryrun_manifest_html(
    winner_rows: list,
    out_html: Path,
    author_by_name: dict[str, str] | None = None,
    staging_root: Path | None = None,   # enables Present + StagedTime
):
    r"""
    Build a sortable HTML manifest of DRY-RUN winners, de-duped by PreviewName.
    For duplicates, keep the row with the highest numeric Revision.
    Columns: FileName, Author, Revision, Action, Present, StagedTime
    """
    from datetime import datetime
    #import os
    #import re
    #from pathlib import Path

    def _revnum(v: str) -> float:
        try:
            return float(v or "")
        except Exception:
            return -1.0

    def _norm_action(s: str) -> str:
        return re.sub(r"[\s_/]+", "-", (s or "").strip().lower())

    # Prefer non-empty actions when revisions tie:
    #   real change (2) > staged-out-of-date (1) > noop/empty (0)
    IGNORE_ACTIONS = {"", "noop", "no-op", "ok", "current", "same", "skip", "none", "unchanged"}
    def _action_score(act_norm: str) -> int:
        if act_norm not in IGNORE_ACTIONS:
            return 2
        if act_norm in {"out-of-date", "update-staging"}:
            return 1
        return 0

    # Determine where to check for staged files; fall back to the HTML folder
    staging_root = Path(staging_root) if staging_root else out_html.parent
    staged_map = {p.name.lower(): p for p in staging_root.glob("*.lorprev")}

    # --------- de-dupe by PreviewName (highest Revision, then better action) ---------
    best_by_pn: dict[str, dict] = {}
    for rrow in winner_rows:
        pn = (rrow.get("PreviewName") or "").strip()
        if not pn:
            continue
        rev = (rrow.get("Revision") or "").strip()
        act_raw = (rrow.get("Action") or "").strip()
        act_norm = _norm_action(act_raw)
        score = (_revnum(rev), _action_score(act_norm))  # primary: revision, secondary: action quality

        key = pn.lower()
        cur = best_by_pn.get(key)
        if cur is None or score > cur["score"]:
            best_by_pn[key] = {"row": rrow, "score": score}

    # --------- build output rows (unique per PreviewName) ---------
    rows = []
    for item in best_by_pn.values():
        rrow = item["row"]
        pn     = (rrow.get("PreviewName") or "").strip()
        rev    = rrow.get("Revision") or ""
        act    = (rrow.get("Action") or "").strip()
        author = (rrow.get("Author") or (author_by_name or {}).get(pn, "") or "")
        fname  = f"{pn}.lorprev" if pn else ""

        present = "No"
        staged_time = ""
        if fname:
            p = staged_map.get(fname.lower())
            if p and p.exists():
                present = "Yes"
                try:
                    ts = os.path.getmtime(p)
                    staged_time = datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S")
                except Exception:
                    staged_time = ""

        # FileName, Author, Revision, Action, Present, StagedTime
        rows.append((fname, author, rev, act, present, staged_time))

    # Sort by FileName asc, Revision desc (same intent as CSV manifest)
    rows.sort(key=lambda x: ((x[0] or "").lower(), -_revnum(x[2])))

    _emit_manifest_html(
        rows,
        out_html,
        headers=[
            ("FileName",   "text"),
            ("Author",     "text"),
            ("Revision",   "number"),
            ("Action",     "text"),
            ("Present",    "text"),
            ("StagedTime", "text"),
        ],
        context_path=str(out_html.parent),
        extra_title="(DRY RUN)",
    )
# --- end write_dryrun_manifest_html ---


# GAL 25-10-16: run_meta.json writer (read by merge_reports_to_excel.py Info tab)
def write_run_meta_json(reports_dir: Path, staging_root: Path, run_mode: str, totals: dict):
    """
    Writes reports_dir/run_meta.json with minimal run context.
    'totals' is a free-form dict we will expand in later steps.
    """
    try:
        import getpass, json, socket
        meta = {
            "run_mode": run_mode,                  # "dry-run" | "apply"
            "csv_root": str(reports_dir),          # where CSVs are stored
            "staging_root": str(staging_root),     # canonical staging folder (for Info tab)
            "started_at": dt.datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "user": getpass.getuser(),
            "host": socket.gethostname(),
            "totals": totals or {},
        }
        out = reports_dir / "run_meta.json"
        ensure_dir(reports_dir)
        with out.open("w", encoding="utf-8") as f:
            json.dump(meta, f, indent=2)
        print(f"[meta] wrote {out}")
    except Exception as e:
        print(f"[meta] failed to write run_meta.json: {e}")

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

    run_ts = dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ctx = _esc(context_path or "")
    xt = f" {extra_title.strip()}" if extra_title else ""  # leading space
    # User@Host GAL 25-10-14
    import getpass, socket
    user = getpass.getuser()
    host = socket.gethostname()
    user_label = f"{user}@{host}"

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
<div class="hint">Generated on {run_ts} by {user_label}{('<br>Folder: ' + ctx) if ctx else ''}\nTip: click a column header to sort.</div>
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


def history_connect(db_path: Path, *, mode: str = "rw"):
    """mode='ro' opens read-only; mode='rw' opens read/write and creates the folder."""
    if mode == "ro":
        uri = f"file:{Path(db_path).as_posix()}?mode=ro"
        return sqlite3.connect(uri, uri=True)
    Path(db_path).parent.mkdir(parents=True, exist_ok=True)
    return sqlite3.connect(str(db_path))

# # ============================= Core logic ============================= #

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

            raw_sha         = sha256_file(path)
            semantic_sha256 = semantic_sha256_file(path)   # you already have this
            core_sig        = core_signature(path)         # GAL 25-10-15

            candidates.append(Candidate(
                key=key,
                identity=idy,
                user=user,
                user_email=email,
                path=str(path),
                size=stat.st_size,
                mtime=stat.st_mtime,
                sha256=raw_sha,
                semantic_sha256=semantic_sha256,
                core_sig=core_sig,                         # GAL 25-10-15
                c_total=ct, c_filled=cf, c_nospace=cn,
            ))
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


# ---------------------------------------------------------------------------
# GAL 25-10-15: Controlled copy with optional backup (no writes in dry-run)
# ---------------------------------------------------------------------------
def stage_copy(src: Path, dst: Path, apply_mode: bool, make_backup: bool, *, semantic_different: bool) -> None:
    """
    Copy src -> dst.
    - If apply_mode is False, do nothing (dry-run safeguard).
    - If make_backup and semantic_different and dst exists, write a .bak timestamped copy.
    """
    if not apply_mode:
        return  # GAL 25-10-15: dry-run produces ZERO filesystem writes

    dst.parent.mkdir(parents=True, exist_ok=True)

    # Only back up if content actually changed (semantic), and backups are enabled
    if make_backup and dst.exists() and semantic_different:
        ts = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
        backup = dst.with_suffix(dst.suffix + f".bak.{ts}")
        try:
            shutil.copy2(dst, backup)
        except Exception as e:
            print(f"[WARN][GAL 25-10-15] Could not write backup for {dst.name}: {e}", file=sys.stderr)

    tmp = dst.with_suffix(dst.suffix + ".tmp")
    shutil.copy2(src, tmp)
    tmp.replace(dst)

# ---------------------------------------------------------------------------
# GAL 25-10-18: Archive the currently-Previews for Props file before overwriting
# ---------------------------------------------------------------------------
def archive_with_dated_filename(src: Path, archive_root: Path) -> Path:
    r"""
    Generic helper for future use (e.g., PreviewsForProps\archive).
    Moves 'src' into 'archive_root' with __YYYY-MM-DD_HHMMSS added before the extension.
    """
    ensure_dir(archive_root)
    ts = dt.datetime.now().strftime("%Y-%m-%d_%H%M%S")
    base, ext = src.stem, src.suffix
    dest = archive_root / f"{base}__{ts}{ext}"
    counter = 1
    while dest.exists():
        dest = archive_root / f"{base}__{ts}__{counter}{ext}"
        counter += 1
    shutil.move(str(src), str(dest))
    return dest

# ---------------------------------------------------------------------------
# GAL 25-10-18: Archive the currently-staged file (flat archive folder + dated filename)
# ---------------------------------------------------------------------------
def archive_existing_staged_file(staged_path: Path, archive_root: Path, *, apply_mode: bool):
    r"""
    Archives an existing staged preview by moving it to:
      <archive_root>\

    with a timestamp appended to the filename (before its extension), e.g.:
      'Show Background Stage 07 Whoville 2025.leprop'  ->
      'Show Background Stage 07 Whoville 2025__2025-10-18_193022.leprop'

    Returns the archive destination Path if a move occurred.
    """
    if not apply_mode:
        return None
    if not staged_path.exists():
        return None

    ensure_dir(archive_root)

    # Build dated filename: OriginalBase__YYYY-MM-DD_HHMMSS.ext
    ts = dt.datetime.now().strftime("%Y-%m-%d_%H%M%S")
    base = staged_path.stem
    ext = staged_path.suffix
    archived_name = f"{base}__{ts}{ext}"
    dest = archive_root / archived_name

    # If somehow that exists, add a counter (rare, but keep it robust)
    counter = 1
    while dest.exists():
        archived_name = f"{base}__{ts}__{counter}{ext}"
        dest = archive_root / archived_name
        counter += 1

    shutil.move(str(staged_path), str(dest))
    return dest



# ---------------------------------------------------------------------------
# GAL 25-10-18: Build a human-readable notice of staged preview updates
# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# GAL 25-10-18: Build a human-readable notice of staged preview updates
# ---------------------------------------------------------------------------
def build_preview_update_notice(applied_rows, reports_dir: Path, manifest_path: Path) -> Path:
    r"""
    Create a dated notice summarizing staged preview updates.
    Writes to _notifications\preview-update-YYYYMMDD-HHMMSS.txt
    and returns the path written.
    """
    #from datetime import datetime
    #import os

    # base directories
    notifications_root = Path(r"G:\Shared drives\MSB Database\Database Previews\_notifications")
    notifications_root.mkdir(parents=True, exist_ok=True)

    timestamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    out_path = notifications_root / f"preview-update-{timestamp}.txt"

    rows = applied_rows or []
    lines = []
    lines.append("MSB Preview Staging Update")
    lines.append("------------------------------------------------------------")
    lines.append(f"Generated : {dt.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    lines.append(f"Count     : {len(rows)}")
    lines.append("")

    if rows:
        lines.append("Staged previews (PreviewName — Author — Exported — Revision):")
        for r in sorted(rows, key=lambda x: (
            str(x.get("PreviewName") or "").lower(),
            str(x.get("Author") or "").lower()
        )):
            lines.append(
                f"  - {r.get('PreviewName','?')} — {r.get('Author','?')} — "
                f"{r.get('Exported','?')} — {r.get('Revision','')}"
            )
    else:
        lines.append("No previews were staged in this run.")

    lines.append("")
    lines.append("Reminder: For the latest authoritative list of previews,")
    lines.append(str(manifest_path))

    out_path.write_text("\n".join(lines), encoding="utf-8")

    # also keep the short report copy in /reports for quick access if desired
    try:
        reports_dir.mkdir(parents=True, exist_ok=True)
        (reports_dir / "preview_update_notice.txt").write_text("\n".join(lines), encoding="utf-8")
    except Exception:
        pass  # not fatal

    return out_path



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
        f"<p>Generated: {dt.datetime.now().astimezone().strftime('%Y-%m-%d %H:%M:%S%z')}</p>",
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

def main():
    # -----------------------------------------------------------------------
    # 1) Collect configs: CLI(pre-parse) > JSON > repo/env > GLOBAL_DEFAULTS
    # -----------------------------------------------------------------------
    cli       = parse_cli()
    cfg_path  = _preparse_config_path(sys.argv)          # existing helper
    json_cfg  = _load_config_json(cfg_path)              # existing helper
    repo_defs = build_repo_defaults(REPO_ROOT)           # existing helper

    # precedence: start with globals, overlay repo-aware, then JSON, then CLI
    defaults = dict(GLOBAL_DEFAULTS)
    defaults.update(repo_defs)
    defaults.update(json_cfg)
    for k, v in cli.items():
        if v is not None:
            defaults[k] = v



    # -----------------------------------------------------------------------
    # GAL 25-10-15: Pin critical outputs to G:\ regardless of repo/json/CLI
    # -----------------------------------------------------------------------
    G = Path(r"G:\Shared drives\MSB Database")

    def _is_on_g_str(p: str | Path) -> bool:
        s = str(p or "").strip()
        return s[:2].upper() == "G:"

    def _gpath_str(*parts: str) -> str:
        return str(G.joinpath(*parts))

    # Force these onto G:\ if they arrived as another drive/UNC
    for key, rel in [
        ("archive_root", ("database", "merger", "archive")),
        ("history_db",   ("database", "merger", "preview_history.db")),
        ("report_csv",   ("database", "merger", "reports", "compare.csv")),
        ("report_html",  ("database", "merger", "reports", "compare.html")),
    ]:
        if not _is_on_g_str(defaults.get(key, "")):
            defaults[key] = _gpath_str(*rel)

    # -----------------------------------------------------------------------
    # GAL 25-10-15: Resolve roots from defaults BEFORE author discovery
    #               (prevents UnboundLocalError & pre-args usage)
    # -----------------------------------------------------------------------
    input_root   = Path(defaults["input_root"])
    staging_root = Path(defaults["staging_root"])

    # -----------------------------------------------------------------------
    # GAL 25-10-15: Dynamic author discovery (no args.* here yet).
    #               Write results back to defaults so argparse inherits them.
    # -----------------------------------------------------------------------
    authors = discover_authors(input_root)
    if authors:
        for a in authors:
            ensure_dir(input_root / a)
        print(f"[INFO][GAL 25-10-15] Discovered authors: {', '.join(authors)}")
        defaults["ensure_users"] = ",".join(authors)

        # If no user_map provided via JSON/CLI, synthesize a default from domain
        if defaults.get("email_domain") and not defaults.get("user_map") and not defaults.get("user_map_json"):
            defaults["user_map"] = ";".join(f"{a}={a}@{defaults['email_domain']}" for a in authors)
    else:
        print("[WARN][GAL 25-10-15] No author folders found under input_root; keeping legacy defaults.")

    # -----------------------------------------------------------------------
    # Normalize & ensure dirs (still operating on defaults / strings)
    # -----------------------------------------------------------------------
    for key in ["input_root", "staging_root", "archive_root", "history_db", "report_csv", "report_html"]:
        defaults[key] = os.path.normpath(defaults[key])

    Path(defaults["archive_root"]).mkdir(parents=True, exist_ok=True)
    Path(defaults["history_db"]).parent.mkdir(parents=True, exist_ok=True)
    Path(defaults["report_csv"]).parent.mkdir(parents=True, exist_ok=True)
    Path(defaults["report_html"]).parent.mkdir(parents=True, exist_ok=True)

    print("[INFO] Effective config (pre-CLI):")
    for k in ["input_root","staging_root","archive_root","history_db","report_csv","report_html","policy"]:
        print(f"  {k}: {defaults[k]}")
    # GAL 25-10-20: announce author selection policy in console
    print("[policy] Author selection: AuthorRoot(latest) — newest user export is compared to staging")


    # -----------------------------------------------------------------------
    # 2) Build argparse using UPDATED defaults (after author discovery)
    # -----------------------------------------------------------------------
    ap = argparse.ArgumentParser(
        description='Collect and stage LOR .lorprev files with conflict detection and history DB.',
        fromfile_prefix_chars='@'
    )
    ap.add_argument('--config', help='Path to JSON config file (optional)')
    ap.add_argument('--input-root',   default=defaults['input_root'])
    ap.add_argument('--staging-root', default=defaults['staging_root'])
    ap.add_argument('--archive-root', default=defaults['archive_root'])
    ap.add_argument('--history-db',   default=defaults['history_db'])
    ap.add_argument('--report',       default=defaults['report_csv'])
    ap.add_argument('--report-html',  default=defaults['report_html'])
    ap.add_argument('--policy',
        choices=['prefer-revision-then-exported','prefer-exported','prefer-comments-then-revision'],
        default=defaults['policy']
    )
    ap.add_argument('--apply', action='store_true', help='Stage/archive changes (default is dry-run)')
    ap.add_argument('--force-winner', action='append', default=[])
    ap.add_argument('--ensure-users', default=defaults['ensure_users'],
                    help='Comma-separated list to ensure folders exist under input-root (e.g., usernames)')
    ap.add_argument('--user-map', help='Semicolon-separated username=email pairs, e.g. "gliebig=greg@sheboyganlights.org"')
    ap.add_argument('--user-map-json', help='Path to JSON mapping {"gliebig":"greg@sheboyganlights.org"}')
    ap.add_argument('--email-domain', default=defaults['email_domain'],
                    help='If set, any username without a mapping gets username@<domain>')
    ap.add_argument('--debug', action='store_true', help='Print debug info to stderr')
    ap.add_argument('--progress', dest='progress', action='store_true', default=True,
                    help='Show progress while building report (default: on)')
    ap.add_argument('--no-progress', dest='progress', action='store_false',
                    help='Disable progress output')
    ap.add_argument('--excel-out', default=defaults.get('excel_out'),
                    help="Directory to write the Excel report. If omitted, uses report_html's folder; otherwise reports_dir.")

    args = ap.parse_args()

    # -----------------------------------------------------------------------
    # GAL 25-10-18: Add a clear run mode and single run stamp
    # -----------------------------------------------------------------------
    run_mode  = "apply" if args.apply else "dry-run"
    run_stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")   # <-- USE dt.datetime.now()
    print(f"[mode] {run_mode}  [run] {run_stamp}")
    # If you still have open_history_db, it probably expects a bool (apply_mode).
    # If so, pass args.apply. If you deleted it (Option A earlier), remove this line.
    # conn, run_id = open_history_db(args.apply)

    # -----------------------------------------------------------------------
    # 3) Compute final paths AFTER parsing args (may override defaults)
    # -----------------------------------------------------------------------
    input_root   = Path(args.input_root)
    staging_root = Path(args.staging_root)
    archive_root = Path(args.archive_root) if args.archive_root else None
    history_db   = Path(args.history_db)
    report_csv   = Path(args.report)
    report_html  = Path(args.report_html) if args.report_html else None

    print(f"[INFO] USER_STAGING : {input_root}")
    print(f"[INFO] STAGING_ROOT : {staging_root}")

    # -----------------------------------------------------------------------
    # GAL 25-10-15: Final safety — keep critical outputs on G:\ (no resolve)
    # -----------------------------------------------------------------------
    def _is_on_g(p: Path | None) -> bool:
        if p is None:
            return True
        drv = getattr(p, "drive", "")
        if drv.upper() == "G:":
            return True
        s = str(p)
        return s[:2].upper() == "G:"

    def _gpath(*parts: str) -> Path:
        return G.joinpath(*parts)

    if not _is_on_g(archive_root):
        archive_root = _gpath("database", "merger", "archive")
    if not _is_on_g(history_db):
        history_db   = _gpath("database", "merger", "preview_history.db")
    if not _is_on_g(report_csv):
        report_csv   = _gpath("database", "merger", "reports", "compare.csv")
    if report_html and not _is_on_g(report_html):
        report_html  = _gpath("database", "merger", "reports", "compare.html")

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

    # -----------------------------------------------------------------------
    # GAL 25-10-15: Run-scoped accumulators (define BEFORE first use)
    # -----------------------------------------------------------------------
    applied_this_run: list[dict] = []
    excluded_detailed: list[dict] = []   # for apply-time failures/skips/etc.
    allowed_winner_rows_report: list[dict] = []  # optional: keep if you want
    # >>> GAL 2025-10-19: default so apply path never hits NameError
    core_changed_fields = ""
    # <<< GAL 2025-10-19


    # Useful run metadata
    run_started_local = dt.datetime.now().astimezone().isoformat(timespec='seconds')
    applied_by        = socket.gethostname()  # or os.getlogin()

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
    miss_csv      = report_csv.with_name('missing_comments.csv')
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
    _ts = dt.datetime.now().strftime("%Y%m%d-%H%M")
    xlsx_latest = excel_out / "reports.xlsx"
    xlsx_ts     = excel_out / f"reports-{_ts}.xlsx"

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

    # # === GAL 2025-10-18 21:08 === History DB: start run (APPLY-ONLY; dry-run is RO and writes NOTHING)
    # === GAL 2025-10-18 — History DB run header and guarded interactions ===
    #
    # Policy:
    #   • Dry-run: NEVER write to the DB (no connection opened).
    #   • Apply  : Open R/W, ensure schema, record a single run header row.
    #
    # Notes:
    #   • started_local is LOCAL time (ISO with offset) to match other artifacts.
    #   • We only read/write subsequent tables when (args.apply and conn) is true.

    conn: Optional[sqlite3.Connection] = None
    run_id: Optional[str] = None

    # One canonical local timestamp for this run (used in logs/DB header when apply)
    started_local = dt.datetime.now().astimezone().isoformat(timespec='seconds')  # e.g. 2025-10-19T09:18:11-05:00

    if args.apply:
        # --- APPLY MODE: open DB R/W and ensure schema; record run header once ---
        conn = history_connect(history_db, mode="rw")
        run_id = hashlib.sha256(os.urandom(16)).hexdigest()

        # Ensure minimal schema (idempotent)
        conn.execute("""CREATE TABLE IF NOT EXISTS runs(
            run_id  TEXT PRIMARY KEY,
            started TEXT,
            policy  TEXT
        )""")
        conn.execute("""CREATE TABLE IF NOT EXISTS staging_decisions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            run_id TEXT,
            preview_key TEXT,
            winner_path TEXT,
            staged_as TEXT,
            decision_reason TEXT,
            conflict INTEGER,
            action TEXT
        )""")
        conn.execute("""CREATE TABLE IF NOT EXISTS file_observations(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            run_id TEXT,
            user TEXT,
            user_email TEXT,
            path TEXT,
            file_name TEXT,
            preview_key TEXT,
            preview_guid TEXT,
            preview_name TEXT,
            revision_raw TEXT,
            revision_num REAL,
            file_size INTEGER,
            exported TEXT,
            sha256 TEXT
        )""")

        # Single authoritative run header
        conn.execute(
            'INSERT OR IGNORE INTO runs(run_id, started, policy) VALUES (?,?,?)',
            (run_id, started_local, args.policy)
        )
        conn.commit()
    # --- DRY-RUN: leave conn=None so no DB writes can occur ---

    # (1) Load prior state for cross-run change detection (APPLY only)
    prior: Dict[str, Dict] = {}
    if args.apply and conn:
        try:
            for row in conn.execute(
                "SELECT preview_key, preview_name, revision_num, sha256 FROM preview_state"
            ):
                prior[row[0]] = {
                    "preview_name": row[1],
                    "revision_num": row[2],
                    "sha256": row[3],
                }
        except Exception as e:
            # Table may not exist on first run; proceed with empty 'prior'
            print(f"[warn] prior state unavailable: {e}")

    # (2) Scan candidates (always)
    candidates = scan_input(input_root, user_map, args.email_domain)

    # (3) Record file observations (APPLY only; NEVER on dry-run)
    if args.apply and conn:
        try:
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
        except Exception as e:
            print(f"[warn] could not record file observations: {e}")
    # === /GAL 2025-10-18 — History DB block ===

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
                st_sha = staged_sha  # already computed elsewhere
                st_ct, st_cf, st_cn = comment_stats(staged_dest)

                # GAL 25-10-15: semantic equality = metadata-only; do not stage
                st_sem = semantic_sha256_file(staged_dest)
                if st_sem == winner.semantic_sha256:
                    should_stage = False
                    stage_reason += '; skip: semantic-identical (metadata-only changes)'
                elif st_sha == winner.sha256:
                    should_stage = False
                    stage_reason += '; skip: identical to staged (raw hash)'
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
                # -----------------------------------------------------------------------
                # GAL 25-10-15: Stage winner using DB-core comparison (Name/LORComment/UID/
                #               StartChannel/Network/Lights/PropID). Back up only if core changed.
                # -----------------------------------------------------------------------
                try:
                    ensure_dir(staged_dest.parent)

                    # Compare ONLY DB-meaningful fields (short-circuits rev/metadata noise)
                    # ----- BEGIN CORE COMPARISON AND STAGE DECISION (GAL 25-10-18) -----

                    # Compare ONLY DB-meaningful fields (core)
                    staged_exists = staged_dest.exists()
                    if staged_exists:
                        core_same, core_changed = diff_core_fields(Path(winner.path), staged_dest)  # local helper
                    else:
                        core_same, core_changed = (False, ["new file"])

                    # Archive folder for staged previews (flat folder with dated filenames)
                    # Example: G:\Shared drives\MSB Database\Database Previews\archive
                    staged_archive_root = Path(r"G:\Shared drives\MSB Database\Database Previews\archive")

                    # If we’re going to overwrite an existing staged file with a core change,
                    # archive the old staged file first (one time, before copy; only when --apply)
                    if args.apply and staged_exists and (not core_same):
                        try:
                            archived_prior = archive_existing_staged_file(
                                staged_path=staged_dest,
                                archive_root=staged_archive_root,
                                apply_mode=True
                            )
                            if archived_prior:
                                print(f"[INFO] Archived previous staged file → {archived_prior}")
                        except Exception as e:
                            print(f"[WARN] Failed to archive previous staged file: {e}")
                    # GAL 25-10-20: APPLY → stage newest AuthorRoot export (policy: AuthorRoot(latest))
                    # Preconditions mirror dry-run "Ready" gate:
                    #   - author_file exists
                    #   - core_different is True (DB-meaningful change)
                    #   - author_newer == "yes" (newer than staged or no staged)
                    try:
                        # GAL 25-10-20: resolve preview name safely for logs
                        pn_str = (pn if "pn" in locals() else (r.get("PreviewName") if "r" in locals() else "<unknown>"))
                        # GAL 25-10-20: ensure author_file/author/where_tag exist in this scope
                        if 'author_file' not in locals() or author_file is None:
                            # Re-resolve newest AuthorRoot export for this preview
                            # (Matches dry-run policy so apply uses the same source)
                            author_hint_local = (author if 'author' in locals() else None)
                            _a_name, _a_path, _where = _find_author_and_file(pn_str, author_hint_local)
                            # Fill missing fields; keep any values already set upstream
                            author = author if ('author' in locals() and author) else _a_name
                            where_tag = where_tag if ('where_tag' in locals() and where_tag) else _where
                            author_file = _a_path

                        # ---- GAL 25-10-20: recompute readiness inside APPLY (self-contained) ----
                        # Files exist?
                        staged_exists = bool(staged_dest and staged_dest.exists())
                        author_exists = bool(author_file and author_file.exists())

                        # Recompute AuthorNewer using mtimes
                        try:
                            a_mtime = author_file.stat().st_mtime if author_exists else 0
                            s_mtime = staged_dest.stat().st_mtime if staged_exists else 0
                            author_newer = "yes" if (author_exists and (not staged_exists or a_mtime > s_mtime)) \
                                           else ("no" if staged_exists else "unknown")
                        except Exception:
                            author_newer = "unknown"
                            
                        if 'DEBUG_APPLY' in globals() and DEBUG_APPLY:
                            print(f"[apply][check] PREVIEW='{pn_str}' author_exists={author_exists} "
                                  f"staged_exists={staged_exists} author_newer={author_newer} "
                                  f"core_same={core_same} ready={_ready_to_stage}")



                        # Recompute core diff (use same function as dry-run)
                        core_same = None
                        try:
                            if author_exists and staged_exists:
                                _same, _changes = diff_core_fields(author_file, staged_dest)
                                core_same = True if _same else False
                                core_changed_list = _changes or []
                            elif author_exists and not staged_exists:
                                core_same = False   # new stage → treat as different
                                core_changed_list = ["NewStage"]
                            else:
                                core_same = None
                                core_changed_list = []
                        except Exception:
                            core_same = None
                            core_changed_list = []

                        # Ready iff author exists, core is different, and author is newer
                        _ready_to_stage = (author_exists and (core_same is False) and (author_newer == "yes"))
                        # -------------------------------------------------------------------------


                        if args.apply and _ready_to_stage:
                            # Announce exactly what we’re doing (policy + provenance)
                            print(f"[apply] Staging PREVIEW='{pn_str}' from AUTHOR='{author}' ({where_tag}) → {staged_dest}")

                            # Ensure destination directory exists
                            staged_dest.parent.mkdir(parents=True, exist_ok=True)

                            # Copy with metadata; write to a temp file then replace, to be safe on Windows
                            # import tempfile, shutil  # GAL 25-10-20: local import for clarity
                            with tempfile.NamedTemporaryFile(dir=staged_dest.parent, delete=False) as _tmp:
                                _tmp_path = Path(_tmp.name)
                            try:
                                shutil.copy2(author_file, _tmp_path)  # copy to temp first
                                # On Windows, replace if exists; fall back to unlink+rename if needed
                                try:
                                    os.replace(_tmp_path, staged_dest)
                                except Exception:
                                    if staged_dest.exists():
                                        staged_dest.unlink()
                                    _tmp_path.rename(staged_dest)
                                print(f"[apply] OK → staged: {staged_dest}")
                            except Exception as _e:
                                # Clean up temp on failure
                                try:
                                    if _tmp_path and _tmp_path.exists():
                                        _tmp_path.unlink(missing_ok=True)
                                except Exception:
                                    pass
                                raise
                            # GAL 25-10-20: record a proper apply event for the ledger
                            try:
                                global apply_events_rows, applied_this_run_rows  # safe even if not previously set
                                from uuid import uuid4
                                _pn   = pn_str
                                _auth = author if 'author' in locals() and author else ""
                                _rev  = (r.get("Revision") if 'r' in locals() and isinstance(r, dict) else "")
                                _size = (staged_dest.stat().st_size
                                         if staged_dest and hasattr(staged_dest, "stat") and staged_dest.exists()
                                         else "")
                                _exported = (author_time if 'author_time' in locals() and author_time else "")
                                _applied_by = (os.environ.get("USERNAME")
                                               or os.environ.get("USER")
                                               or socket.gethostname())
                                _apply_date = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

                                _event = {
                                    "Key":         f"GUID:{uuid4()}",
                                    "PreviewName": _pn,
                                    "Author":      _auth,
                                    "Revision":    _rev,
                                    "Size":        _size,
                                    "Exported":    _exported,
                                    "ApplyDate":   _apply_date,
                                    "AppliedBy":   _applied_by,
                                }

                                # Append to in-memory buffers (initialize if missing)
                                try:
                                    apply_events_rows.append(_event)
                                except NameError:
                                    apply_events_rows = [_event]
                                except Exception:
                                    apply_events_rows = [_event]

                                try:
                                    applied_this_run_rows.append(_event)
                                except NameError:
                                    applied_this_run_rows = [_event]
                                except Exception:
                                    applied_this_run_rows = [_event]

                            except Exception as _ee:
                                print(f"[apply][WARN] Failed to record apply event for '{pn_str}': {_ee}")

                            # Optional: log a one-line audit similar to your dry-run summary
                            try:
                                print(f"[apply] CoreChangedFields: {', '.join(core_changed_list) if core_changed_list else '(none listed)'}")
                            except Exception:
                                pass

                        elif args.apply and not _ready_to_stage:
                            # Mirror the same blockers you used in dry-run
                            why = []
                            if author_file is None:
                                why.append("author file missing")
                            if _core_same is True:
                                why.append("core-identical")
                            if author_newer != "yes":
                                why.append("author not newer")
                            print(f"[apply] SKIP PREVIEW='{pn_str}' — not ready ({'; '.join(why) or 'unknown'})")
                    except Exception as _e:
                        print(f"[apply][ERROR] Failed to stage '{pn_str}': {_e}")


                    # Decide whether to stage the winner
                    if core_same:
                        should_stage = False
                        stage_reason = (stage_reason + '; ' if stage_reason else '') + 'skip: core-identical (DB fields unchanged)  # GAL 25-10-18'
                    else:
                        should_stage = True
                        stage_reason = (stage_reason + '; ' if stage_reason else '') + f"apply: core changed ({', '.join(core_changed)})  # GAL 25-10-18"

                    # === GAL 2025-10-19 11:00 === decision logger
                    # Safe locals for logging/ledger (Candidate/Winner doesn’t expose preview_name/author/revision at top level)
                    name       = winner.identity.name
                    author_s   = (winner.user or "")
                    revision_s = (winner.identity.revision_raw or str(winner.identity.revision_num) or "")

                    reason_bits = ["core=DIFF" if not core_same else "core=SAME"]
                    try:
                        t_author = os.path.getmtime(Path(winner.path))
                        t_staged = os.path.getmtime(staged_dest) if staged_dest.exists() else 0
                        newer = "author>staged" if (not staged_dest.exists() or t_author > t_staged) else "author<=staged"
                        reason_bits.append(newer)
                    except Exception:
                        reason_bits.append("time=?")

                    print(
                        f"[decision] {name} → "
                        f"{'STAGE' if should_stage else 'SKIP'} "
                        f"({', '.join(reason_bits)}; winnerfrom={getattr(winner, 'winner_from', '')})"
                    )
                    # === GAL 2025-10-19 11:00 ===


                    # Do the copy (no writes in dry-run; backups only if **core** changed)
                    # === GAL 2025-10-18 21:45 — stage + immediate logging (APPLY ONLY logs; dry-run safe) ===
                    core_different = not core_same
                    copy_ok = True

                    if should_stage:
                        # >>> GAL 2025-10-19: ensure core_changed_fields is set before any apply logging/ledger
                        try:
                            _same, _changed = diff_core_fields(Path(winner.path), Path(staged_dest))
                            core_changed_fields = "; ".join(_changed) if _changed else ""
                        except Exception as e:
                            core_changed_fields = f"Exception during diff: {e}"
                        # <<< GAL 2025-10-19

                        try:
                            stage_copy(
                                Path(winner.path),
                                staged_dest,
                                apply_mode=args.apply,
                                make_backup=True,                 # keep one backup when DB-core changed
                                semantic_different=core_different
                            )

                            # === GAL 2025-10-19 11:00 ===
                            # Only now (success) do we record as applied
                            from datetime import datetime, timezone
                            ts_utc = datetime.now(timezone.utc).isoformat(timespec="seconds")
                            action = "stage-new" if not staged_exists else "update-staging"
                            archived_str = str(archived_prior) if 'archived_prior' in locals() and archived_prior else ""

                            event = {
                                "TS_UTC": ts_utc,
                                "PreviewName": name,        # winner.identity.name
                                "Author":      author_s,    # winner.user
                                "Revision":    revision_s,  # identity.revision_raw/num
                                "Action":      action,
                                "SrcPath":     str(Path(winner.path)),
                                "DestPath":    str(staged_dest),
                                "ArchivedPrior": archived_str,
                                # >>> FIXED LINES (use core_different flag; don't join string chars)
                                "CoreDifferent":     "yes" if core_different else "no",
                                "CoreChangedFields": core_changed_fields,
                                # <<< FIXED
                            }
                            applied_this_run.append(event)
                            # === GAL 2025-10-19 11:00 ===

                            # Append to append-only CSV ledger immediately (durable even if later steps fail)
                            ledger_csv = Path(reports_dir) / "apply_events.csv"
                            header = [
                                "TS_UTC","PreviewName","Author","Revision","Action",
                                "SrcPath","DestPath","ArchivedPrior",
                                "CoreDifferent","CoreChangedFields"
                            ]
                            write_header = not ledger_csv.exists()
                            with ledger_csv.open("a", newline="", encoding="utf-8-sig") as _f:
                                _w = csv.DictWriter(_f, fieldnames=header)
                                if write_header:
                                    _w.writeheader()
                                _w.writerow({k: event.get(k, "") for k in header})


                            # === GAL 2025-10-19 11:00 ===
                            # Insert a staging decision into the history DB (APPLY ONLY)
                            if args.apply and conn:
                                conn.execute("""CREATE TABLE IF NOT EXISTS staging_decisions(
                                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                                    run_id TEXT,
                                    preview_key TEXT,
                                    staged_as TEXT,
                                    action TEXT
                                )""")
                                conn.execute(
                                    "INSERT INTO staging_decisions(run_id, preview_key, staged_as, action) VALUES (?,?,?,?)",
                                    (run_id, getattr(winner, "key", name), str(staged_dest), "staged")  # <— name replaces winner.preview_name
                                )
                                conn.commit()

                            print(f"[OK] Staged: {name} → {staged_dest.name}")  # <— name replaces winner.preview_name
                            # === GAL 2025-10-19 11:00 ===

                        except Exception as e:
                            copy_ok = False
                            print(f"[ERROR] Failed to stage {name}: {e}")  # <— name replaces winner.preview_name
                            # Capture failure context
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

                    else:
                        # Not staging by decision; still considered OK for loop continuity
                        copy_ok = True
                    # === /GAL 2025-10-18 21:45 ===

                    # ----- END CORE COMPARISON AND STAGE DECISION (GAL 25-10-18) -----


                    # NOTE:
                    # We already inserted a 'staged' row into the DB and appended to applied_this_run
                    # immediately AFTER stage_copy(...) succeeded (GAL 2025-10-18 21:45 block).
                    # So we DO NOT repeat those here to avoid duplicate history.

                    # -----------------------------------------------------------------------
                    # Archive losers (apply only). No backups; treat as different path.
                    # -----------------------------------------------------------------------
                    if archive_root and losers:
                        day = dt.datetime.now(timezone.utc).strftime('%Y-%m-%d')
                        for l in losers:
                            arch_dest = archive_root / day / sanitize_name(l.user) / (
                                default_stage_name(l.identity, Path(l.path)).replace(
                                    '.lorprev', f"__from_{sanitize_name(l.user)}.lorprev"
                                )
                            )
                            try:
                                ensure_dir(arch_dest.parent)
                                stage_copy(
                                    Path(l.path),
                                    arch_dest,
                                    apply_mode=args.apply,
                                    make_backup=False,       # archives don’t need backups
                                    semantic_different=True  # copying to a new file → always "different"
                                )
                                # Record archive decision in DB (APPLY ONLY)
                                if args.apply and conn:
                                    with conn:
                                        conn.execute(
                                            'INSERT INTO staging_decisions(run_id,preview_key,winner_path,staged_as,decision_reason,conflict,action) '
                                            'VALUES (?,?,?,?,?,?,?)',
                                            (run_id, key, winner.path, str(arch_dest), 'archived non-winner', 0, 'archived')
                                        )
                            except Exception as e:
                                print(f"[WARN][GAL 25-10-15] Failed archiving loser {l.path} -> {arch_dest}: {e}", file=sys.stderr)
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

                    # If we decided NOT to stage, explicitly record the skip (APPLY ONLY)
                    if (not should_stage) and args.apply and conn:
                        with conn:
                            conn.execute(
                                'INSERT INTO staging_decisions(run_id,preview_key,winner_path,staged_as,decision_reason,conflict,action) '
                                'VALUES (?,?,?,?,?,?,?)',
                                (run_id, key, winner.path, str(staged_dest), stage_reason, int(conflict), 'skipped')
                            )

                # === GAL 2025-10-18 22:28 — close outer try: ensure_dir/diff/archive/skip ===
                except Exception as e:
                    copy_ok = False
                    print(f"[ERROR] Staging flow crashed for {name}: {e}")
                    # Best-effort failure record (avoid NameError if something above wasn't set)
                    try:
                        excluded_detailed.append({
                            "PreviewName":  name if 'name' in locals() else getattr(winner.identity, 'name', ''),
                            "Key":          key if 'key' in locals() else '',
                            "GUID":         winner_guid if 'winner_guid' in locals() else getattr(winner.identity, 'guid', ''),
                            "Revision":     getattr(winner.identity, 'revision_raw', '') or '',
                            "Action":       action if 'action' in locals() else '',
                            "User":         winner.user if hasattr(winner, 'user') else '',
                            "Reason":       "apply failed (outer try)",
                            "Failure":      str(e),
                            "RuleNeeded":   "",
                            "SuggestedFix": "",
                            "Path":         winner.path if hasattr(winner, 'path') else '',
                            "StagedPath":   str(staged_dest) if 'staged_dest' in locals() else '',
                        })
                    except Exception:
                        pass
                # === /GAL 2025-10-18 22:28 ===


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


    # ---- Missing comments report (STAGING ONLY; top-level; skip DeviceType="None") REMOVE LINE AFTER DEBUG
    # GAL 25-10-16: Missing comments report (AUTHOR + STAGING; no path in output)
    # We no longer look at winners/candidates — only what is currently in staging_root.
    # ---- Missing comments report (AUTHOR + STAGING; unified columns, NO Path) ----
    try:
        ensure_dir(miss_csv.parent)

        # Unified schema so DictWriter never drops columns:
        MC_COLS = [
            "Key","PreviewName","Revision","User",
            "CommentFilled","CommentNoSpace","CommentTotal",
            "Author","Reason","WhereFound","Size","Exported"
        ]

        with miss_csv.open("w", encoding="utf-8-sig", newline="") as f:
            w = csv.DictWriter(f, fieldnames=MC_COLS)
            w.writeheader()

            # ========== GAL 25-10-17: REPLACEMENT START (after w.writeheader) ==========
            # 1) Author-folder scan — parse .lorprev to get Key + counts (no Path)  # GAL 25-10-17
            for author_dir in sorted(p for p in Path(input_root).iterdir() if p.is_dir()):  # GAL 25-10-17
                author = author_dir.name  # GAL 25-10-17
                for p in author_dir.glob("*.lorprev"):  # root-level only (no recursion)  # GAL 25-10-17
                    try:  # GAL 25-10-17
                        # Comments are required only when device type is not NONE (i.e., LOR/DMX)  # GAL 25-10-17
                        if device_type_is_none(p):  # GAL 25-10-17
                            continue  # GAL 25-10-17

                        # Totals and counts  # GAL 25-10-17
                        ct, cf, cn = comment_stats(p)  # GAL 25-10-17

                        # GAL 25-10-17: tolerant rule for GAL (off-by-one is OK)
                        try:
                            ct_i = int(ct); cf_i = int(cf); cn_i = int(cn)
                        except Exception:
                            # if counts aren't numeric, don't flag
                            continue

                        # If everything matches, skip
                        if (cf_i >= ct_i) or (cn_i >= ct_i):
                            # counts meet or exceed total → no problem
                            continue

                        # Missing count (worst-case among the two validators)
                        missing = ct_i - max(cf_i, cn_i)

                        # TOLERATE exactly one mismatch (e.g., Northern Lights DMX GAL case)
                        if missing == 1:
                            continue

                        # Determine precise reason (for real problems only)
                        reason = ""
                        if cf_i < ct_i and cn_i == ct_i:
                            reason = "blank comments"
                        elif cn_i < ct_i and cf_i == ct_i:
                            reason = "comments with spaces"
                        else:
                            reason = "blank + spaced comments"

                        # Write the row now that we have a real issue
                        idy = parse_preview_identity(p) or PreviewIdentity(None, None, None, None)
                        w.writerow({
                            "Key":            identity_key(idy) or f"PATH:{p.name.lower()}",
                            "PreviewName":    idy.name or "",
                            "Revision":       idy.revision_raw or "",
                            "User":           author if 'author' in locals() else "Staging root",
                            "CommentFilled":  cf_i,
                            "CommentNoSpace": cn_i,
                            "CommentTotal":   ct_i,
                            "Author":         author if 'author' in locals() else "",
                            "Reason":         reason,
                            "WhereFound":     "AuthorFolder" if 'author' in locals() else "Staging",
                            "Size":           p.stat().st_size,
                            "Exported":       ymd_hms(p.stat().st_mtime),
                        })

                    except Exception:
                        continue

            # 2) Staging-root scan — same rule; include Key + counts (no Path)  # GAL 25-10-17
            for p in sorted(Path(staging_root).glob("*.lorprev")):  # GAL 25-10-17
                try:  # GAL 25-10-17
                    if device_type_is_none(p):  # comments not required for NONE  # GAL 25-10-17
                        continue  # GAL 25-10-17

                        # Totals and counts  # GAL 25-10-17
                        ct, cf, cn = comment_stats(p)  # GAL 25-10-17

                        # GAL 25-10-17: tolerant rule for GAL (off-by-one is OK)
                        try:
                            ct_i = int(ct); cf_i = int(cf); cn_i = int(cn)
                        except Exception:
                            # if counts aren't numeric, don't flag
                            continue

                        # If everything matches, skip
                        if (cf_i >= ct_i) or (cn_i >= ct_i):
                            # counts meet or exceed total → no problem
                            continue

                        # Missing count (worst-case among the two validators)
                        missing = ct_i - max(cf_i, cn_i)

                        # TOLERATE exactly one mismatch (e.g., Northern Lights DMX GAL case)
                        if missing == 1:
                            continue

                        # Determine precise reason (for real problems only)
                        reason = ""
                        if cf_i < ct_i and cn_i == ct_i:
                            reason = "blank comments"
                        elif cn_i < ct_i and cf_i == ct_i:
                            reason = "comments with spaces"
                        else:
                            reason = "blank + spaced comments"

                        # Write the row now that we have a real issue
                        idy = parse_preview_identity(p) or PreviewIdentity(None, None, None, None)
                        w.writerow({
                            "Key":            identity_key(idy) or f"PATH:{p.name.lower()}",
                            "PreviewName":    idy.name or "",
                            "Revision":       idy.revision_raw or "",
                            "User":           author if 'author' in locals() else "Staging root",
                            "CommentFilled":  cf_i,
                            "CommentNoSpace": cn_i,
                            "CommentTotal":   ct_i,
                            "Author":         author if 'author' in locals() else "",
                            "Reason":         reason,
                            "WhereFound":     "AuthorFolder" if 'author' in locals() else "Staging",
                            "Size":           p.stat().st_size,
                            "Exported":       ymd_hms(p.stat().st_mtime),
                        })

                except Exception:
                    continue

            # ========== GAL 25-10-17: REPLACEMENT END ==================================

        print(f"Missing-comments CSV: {miss_csv}")
    except PermissionError:
        print(f"\n[locked] {miss_csv} is open in another program. Close it and re-run.", file=sys.stderr)
        sys.exit(4)


    # ---- All-staged comment audit (top-level staging; includes compliant)
    # ---- All-staged comment audit (top-level staging; includes compliant, NO Path) ----
    all_csv = miss_csv.with_name("all_staged_comments.csv")
    ensure_dir(all_csv.parent)
    with all_csv.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=[
            "Key","PreviewName","Revision","User",
            "CommentFilled","CommentNoSpace","CommentTotal","WhereFound"
        ])
        w.writeheader()
        for p in sorted(Path(staging_root).glob("*.lorprev")):  # non-recursive
            try:
                idy = parse_preview_identity(p) or PreviewIdentity(None, None, None, None)
                ct, cf, cn = comment_stats(p)
                w.writerow({
                    "Key":            identity_key(idy) or f"PATH:{p.name.lower()}",
                    "PreviewName":    idy.name or "",
                    "Revision":       idy.revision_raw or "",
                    "User":           "Staging root",
                    "CommentFilled":  cf,
                    "CommentNoSpace": cn,
                    "CommentTotal":   ct,
                    "WhereFound":     "Staging",
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
    # -----------------------------------------------------------------------
    # GAL 25-10-15: Build winner set, filter by allowed families,
    #               add non-blocking QC warnings (comments/display names),
    #               and compute summary counts.
    # -----------------------------------------------------------------------
    try:
        # Winners from comparison join
        winner_rows = [r for r in rows if r.get('Role') == 'WINNER']

        # ---- Filter winners to only allowed families (log exclusions) ----
        allowed_winner_rows: list[dict] = []
        excluded_detailed:   list[dict] = []   # consumed later by excluded_winners.csv writer

        for r in winner_rows:
            pn       = (r.get('PreviewName') or '').strip()
            user     = (r.get('User') or r.get('Owner') or '').strip()
            src_path = (r.get('Path') or r.get('SourcePath') or '').strip()

            is_allowed, reason = _classify_family(pn, path=src_path, user=user)
            if not is_allowed:
                # GAL 25-10-15: Helpful suggestion for common stage-name format issue
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

            # -------------------------------------------------------------------
            # GAL 25-10-15: Add non-blocking QC warning about display-name/comments
            # We do NOT block application anymore; we only annotate warnings.
            # Common fields you may have upstream:
            #   - c_total / c_nospace (counts)
            #   - DisplayNamesFilledPct (0..100)
            # We’ll check both patterns safely if present.
            # -------------------------------------------------------------------
            qc_warnings: list[str] = []

            c_total   = r.get("c_total")
            c_nospace = r.get("c_nospace")
            try:
                if c_total is not None and c_nospace is not None:
                    if int(c_total) > 0 and int(c_nospace) == 0:
                        qc_warnings.append("warning: blank/spaced display names")
            except Exception:
                pass

            dn_pct = r.get("DisplayNamesFilledPct")
            try:
                if dn_pct is not None and float(dn_pct) < 100.0:
                    qc_warnings.append(f"warning: display names {float(dn_pct):.0f}% filled")
            except Exception:
                pass

            # Attach warnings (non-blocking); keep any existing reason text
            if qc_warnings:
                existing = (r.get("Reason") or "").strip()
                r["Reason"] = (existing + ("; " if existing else "") + "; ".join(qc_warnings))

            allowed_winner_rows.append(r)

        # -----------------------------------------------------------------------
        # GAL 25-10-15: Use the filtered list for the summary numbers
        # Keep semantics identical to original, but be explicit.
        # Actions expected in winners: 'noop' | 'update-staging' | 'stage-new'
        # -----------------------------------------------------------------------
        winners_total = len({(r.get('Key') or r.get('GUID') or r.get('PreviewName')) for r in allowed_winner_rows})
        noop = sum(1 for r in allowed_winner_rows if r.get('Action') == 'noop')
        upd  = sum(1 for r in allowed_winner_rows if r.get('Action') == 'update-staging')
        new  = sum(1 for r in allowed_winner_rows if r.get('Action') == 'stage-new')

        # Staged role rows
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
    excluded_by_family:   list[dict] = []   # GAL 25-10-15: renamed to avoid clobbering apply-time list


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
    # (Optional) log what was excluded so teammates can fix/move them
    if excluded_by_family:
        excl_csv = Path(report_csv).parent / "excluded_winners.csv"
        cols = ["PreviewName","Key","GUID","Revision","Action","User",
                "Reason","Failure","RuleNeeded","SuggestedFix","Path","StagedPath"]
        with excl_csv.open("w", encoding="utf-8-sig", newline="") as f:
            w = _csv.DictWriter(f, fieldnames=cols)
            w.writeheader()
            for row in excluded_by_family:
                w.writerow({c: row.get(c, "") for c in cols})
        print(f"[filter] excluded {len(excluded_by_family)} previews not matching allowed families → {excl_csv}", file=sys.stderr)
        for row in excluded_by_family:
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
        write_current_manifest_csv(staging_root, manifest_csv_path)

        # HTML version too 25-09-19
        manifest_html_path = Path(staging_root) / "current_previews_manifest.html"
        write_current_manifest_html(Path(staging_root), manifest_html_path, author_by_name=author_by_name)
        print(f"[sweep] staging manifest → {manifest_csv_path}")
        print(f"[sweep] staging manifest (HTML) → {manifest_html_path}")

    else:
        # DRY RUN: do not move files — write a 'would-be' manifest for clarity

        # 1) CSV preview manifest (adds Present column)
        #    Only include previews from allowed staging families
        write_dryrun_manifest_csv(
            staging_root=Path(staging_root),
            winner_rows=allowed_winner_rows,
            author_by_name=author_by_name,
            input_root=Path(input_root),
            all_rows=rows
        )
        print("[dry-run] wrote preview manifest (no changes made).")

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

        # Write DRY-RUN manifest HTML (staged files only; sortable)
        preview_html = Path(staging_root) / "current_previews_manifest_dry-run.html"
        write_dryrun_manifest_html(
            allowed_winner_rows,
            preview_html,
            author_by_name=author_by_name,
            staging_root=Path(staging_root),   # enables Present + StagedTime
        )
        print(f"[dry-run] wrote preview manifest (HTML): {preview_html}")

        # subprocess.run(
        #     [sys.executable, "merge_reports_to_excel.py",
        #     "--root", r"G:\Shared drives\MSB Database\database\merger\reports",
        #     "--out",  r"G:\Shared drives\MSB Database\Database Previews"],
        #     check=True
        # )

    # ---------------------------------------------------------------------------
    # GAL 25-10-15: Keep the most recent manifest/report in STAGING.
    #               Move older reports OUT of the staging folder.
    # ---------------------------------------------------------------------------
    from shutil import copy2, move

    def _safe_exists(p: Path | None) -> bool:
        try:
            return bool(p and p.exists())
        except Exception:
            return False

    def _copy_if_newer(src: Path, dst_dir: Path) -> Path | None:
        """
        GAL 25-10-15
        Copy src -> dst_dir/src.name only if src exists and is newer or dst missing.
        Returns destination path (or None if src didn't exist).
        """
        if not _safe_exists(src):
            return None
        dst = dst_dir / src.name
        try:
            if not dst.exists() or src.stat().st_mtime > dst.stat().st_mtime:
                dst_dir.mkdir(parents=True, exist_ok=True)
                copy2(src, dst)
            return dst
        except Exception as e:
            print(f"[WARN][GAL 25-10-15] Failed copying {src.name} to staging: {e}", file=sys.stderr)
            return None

    def _collect_current_outputs(
        report_csv: Path,
        report_html: Path | None,
        excel_path: Path | None,
        manifest_csv: Path | None,
        manifest_html: Path | None,
        manifest_json: Path | None,
    ) -> list[Path]:
        files = []
        for p in (report_csv, report_html, excel_path, manifest_csv, manifest_html, manifest_json):
            if _safe_exists(p):
                files.append(p)
        return files

    def _report_like(p: Path) -> bool:
        """
        GAL 25-10-15
        Returns True if filename looks like one of our reports/manifest files that
        we want to manage inside staging.
        """
        name = p.name.lower()
        if name.startswith("compare."):
            return True
        if name.startswith("current_previews_manifest."):
            return True
        if name in ("reports.xlsx", "missing_comments.csv"):
            return True
        if name.endswith(".manifest.json"):
            return True
        # add other fixed names here if needed
        return False

    def rotate_reports_in_staging(
        staging_root: Path,
        current_outputs: list[Path],
        reports_dir: Path,
    ) -> None:
        """
        GAL 25-10-15
        1) Copy current outputs into staging_root (if newer).
        2) Move older report-like files already in staging_root to
        reports_dir / "archive" / YYYY-MM-DD.
        """
        # 1) Copy current run's outputs to staging (keep newest there)
        staged_points: list[Path] = []
        for src in current_outputs:
            staged = _copy_if_newer(src, staging_root)
            if staged:
                staged_points.append(staged)

        keep_names = {p.name for p in staged_points}

        # 2) Move any *other* report-like files out of staging
        archive_base = reports_dir / "archive" / dt.datetime.now().strftime("%Y-%m-%d")
        archive_base.mkdir(parents=True, exist_ok=True)

        try:
            for p in staging_root.iterdir():
                if not p.is_file():
                    continue
                if not _report_like(p):
                    continue
                if p.name in keep_names:
                    continue  # keep the latest one(s) we just placed
                try:
                    target = archive_base / p.name
                    # If name collision in archive, add a timestamp suffix
                    if target.exists():
                        stem, suf = p.stem, p.suffix
                        ts = dt.datetime.now().strftime("%H%M%S")
                        target = archive_base / f"{stem}.{ts}{suf}"
                    move(str(p), str(target))
                    print(f"[INFO][GAL 25-10-15] Archived old report from staging: {p.name} -> {target}")
                except Exception as e:
                    print(f"[WARN][GAL 25-10-15] Could not archive {p.name} from staging: {e}", file=sys.stderr)
        except FileNotFoundError:
            staging_root.mkdir(parents=True, exist_ok=True)

    # GAL 25-10-16: Unify outputs under STAGING root
    reports_dir = Path(staging_root) / "reports"  # CSVs + run_meta.json live here
    reports_dir.mkdir(parents=True, exist_ok=True)

    excel_out = Path(staging_root)                # final Excel goes at STAGING root
    excel_out.mkdir(parents=True, exist_ok=True)

    # ------------------------------------------------------------------------------
    # Excel: merge reports into a formatted workbook (runs for DRY RUN and APPLY)
    excel_script = Path(__file__).with_name("merge_reports_to_excel.py")
    # GAL 25-10-16 [RunMeta]: minimal metadata (expand in Step 3+)
    # Detect apply mode robustly (prefer argparse if present; fallback to argv)
    apply_flag = False
    _apply_ns = locals().get('args') or globals().get('args')
    if _apply_ns is not None and hasattr(_apply_ns, 'apply'):
        apply_flag = bool(getattr(_apply_ns, 'apply'))
    else:
        apply_flag = ('--apply' in sys.argv)

    run_mode = "apply" if apply_flag else "dry-run"

    # Tolerate missing variable
    _applied = locals().get('applied_this_run') or globals().get('applied_this_run') or []
    if _applied is None:
        _applied = []

    basic_totals = {
        "applied_this_run": len(_applied),
    }
    write_run_meta_json(reports_dir, staging_root, run_mode, basic_totals)

    subprocess.run(
        [sys.executable, str(excel_script),
        "--root", str(reports_dir),      # CSV input dir for combiner
        "--out",  str(excel_out)],       # folder where reports.xlsx is written
        check=True
    )
    print(f"[cfg] CSV root: {reports_dir}")
    print(f"[cfg] Excel out: {excel_out}")
    print("[OK] Excel workbook(s) written by merge_reports_to_excel.py")
    # ------------------------------------------------------------------------------
    # GAL 25-10-18: Human-readable summary + notice file
    total_staged = len(applied_this_run)
    if total_staged:
        print("\n[SUMMARY] Preview staging changes this run:")
        for r in sorted(applied_this_run, key=lambda x: (str(r.get('PreviewName') or ''), str(r.get('Author') or ''))):
            print(f"  • {r.get('PreviewName','?')} — {r.get('Author','?')} — {r.get('Exported','?')} — {r.get('Revision','')}")
    else:
        print("\n[SUMMARY] No previews were staged in this run.")

    notice_path = build_preview_update_notice(
        applied_this_run,
        reports_dir=reports_dir,
        manifest_path=Path(r"G:\Shared drives\MSB Database\Database Previews\current_previews_manifest.html")
    )
    print(f"[INFO] Preview Staging Update Notice → {notice_path}")

    # ------------------------------------------------------------------------------

    if conflicts_found:
        print('\nCONFLICTS detected — review report/HTML. (Exit 2)')
        sys.exit(2)


if __name__ == '__main__':
    main()
