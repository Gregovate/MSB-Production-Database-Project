#!/usr/bin/env python3
"""
preview_merger.py — Windows‑friendly, per‑user .lorprev collector with conflict detection,
safe staging, and a history SQLite database for audit/reporting.

Now with **GLOBAL DEFAULTS** and optional **JSON config** so you can just run:

  py preview_merger.py --dry-run

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
    "policy": "prefer-revision-then-mtime",
    "ensure_users": "abiebel,rneerhof,gliebig,showpc,officepc",
    "email_domain": "sheboyganlights.org"
  }

(You can point to another file with --config <path>.)
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import sqlite3
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import xml.etree.ElementTree as ET
import shutil
import sys

# ============================= GLOBAL DEFAULTS ============================= #
GLOBAL_DEFAULTS = {
    # Folders
    "input_root": r"G:\Shared drives\MSB Database\UserPreviewStaging",
    # "Secret" location used by LOR parser today
    "staging_root": r"G:\Shared drives\MSB Database\Database Previews",
    # Keep merger artifacts under /database/merger
    "archive_root": r"G:\Shared drives\MSB Database\database\merger\archive",
    "history_db":   r"G:\Shared drives\MSB Database\database\merger\preview_history.db",
    "report_csv":   r"G:\Shared drives\MSB Database\database\merger\reports\lorprev_compare.csv",
    "report_html":  r"G:\Shared drives\MSB Database\database\merger\reports\lorprev_compare.html",
    # Behavior
    "policy": "prefer-revision-then-mtime",
    # Users and email
    "ensure_users": "abiebel,rneerhof,gliebig,showpc,officepc",
    "email_domain": "sheboyganlights.org",
}

# ============================= Data models ============================= #

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
    user: str                   # top‑level folder name beneath input_root
    user_email: Optional[str]   # from mapping or domain
    path: str
    size: int
    mtime: float
    sha256: str

# ============================= Utilities ============================= #

def ensure_dir(p: Path) -> None:
    p.mkdir(parents=True, exist_ok=True)


def ymd_hms(ts: float) -> str:
    return datetime.fromtimestamp(ts, tz=timezone.utc).strftime('%Y-%m-%d %H:%M:%S%z')


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

# ============================= History DB ============================= #

DDL_HISTORY = """
PRAGMA journal_mode=WAL;
CREATE TABLE IF NOT EXISTS runs (
  run_id      TEXT PRIMARY KEY,
  started_utc TEXT NOT NULL,
  policy      TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS file_observations (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id        TEXT NOT NULL,
  user          TEXT,
  user_email    TEXT,
  path          TEXT,
  file_name     TEXT,
  preview_key   TEXT,
  preview_guid  TEXT,
  preview_name  TEXT,
  revision_raw  TEXT,
  revision_num  REAL,
  file_size     INTEGER,
  mtime_utc     TEXT,
  sha256        TEXT,
  FOREIGN KEY(run_id) REFERENCES runs(run_id)
);
CREATE TABLE IF NOT EXISTS staging_decisions (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id          TEXT NOT NULL,
  preview_key     TEXT NOT NULL,
  winner_path     TEXT,
  staged_as       TEXT,
  decision_reason TEXT,
  conflict        INTEGER DEFAULT 0,
  action          TEXT  -- staged | skipped | conflict | archived
);
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
                data = json.loads(p.read_text(encoding='utf-8'))
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
        # Only scan the ROOT of each user folder (no recursion)
        for path in user_dir.glob('*.lorprev'):
            idy = parse_preview_identity(path)
            if not idy:
                continue
            key = identity_key(idy)
            if not key:
                continue
            stat = path.stat()
            email = user_map.get(user)
            if not email and email_domain:
                email = f"{user}@{email_domain}"
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
                )
            )
    return candidates


def group_by_key(candidates: List[Candidate]) -> Dict[str, List[Candidate]]:
    groups: Dict[str, List[Candidate]] = {}
    for c in candidates:
        groups.setdefault(c.key, []).append(c)
    return groups


def choose_winner(group: List[Candidate], policy: str) -> Tuple[Candidate, List[Candidate], str, bool]:
    # Single candidate
    if len(group) == 1:
        return group[0], [], 'single candidate', False

    def latest_by_mtime(items: List[Candidate]) -> Candidate:
        return sorted(items, key=lambda c: c.mtime, reverse=True)[0]

    reason = ''
    conflict = False

    if policy == 'prefer-mtime':
        winner = latest_by_mtime(group)
        reason = 'latest mtime'
    else:
        # prefer-revision-then-mtime
        max_rev = None
        for c in group:
            if c.identity.revision_num is not None:
                if (max_rev is None) or (c.identity.revision_num > max_rev):
                    max_rev = c.identity.revision_num
        if max_rev is not None:
            rev_max_set = [c for c in group if c.identity.revision_num == max_rev]
            if len(rev_max_set) == 1:
                winner = rev_max_set[0]
                reason = f'highest numeric Revision={max_rev}'
            else:
                hashes = {c.sha256 for c in rev_max_set}
                if len(hashes) == 1:
                    winner = latest_by_mtime(rev_max_set)
                    reason = f'same Revision={max_rev}, identical content; picked latest mtime'
                else:
                    winner = latest_by_mtime(rev_max_set)
                    reason = f'CONFLICT: same Revision={max_rev} but different content; picked latest mtime (needs review)'
                    conflict = True
        else:
            winner = latest_by_mtime(group)
            reason = 'no numeric Revision; picked latest mtime'

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

def write_csv(report_csv: Path, rows: List[Dict]) -> None:
    ensure_dir(report_csv.parent)
    fieldnames = list(rows[0].keys()) if rows else [
        'Key','PreviewName','GUID','Revision','User','UserEmail','Path','Size','MTimeUtc','SHA256','Role','WinnerReason','StagedAs']
    with report_csv.open('w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in rows:
            w.writerow(r)


def write_html(report_html: Path, rows: List[Dict]) -> None:
    ensure_dir(report_html.parent)
    def esc(s: str) -> str:
        return (s or '').replace('&','&amp;').replace('<','&lt;').replace('>','&gt;')
    headers = ['Key','PreviewName','GUID','Revision','User','UserEmail','Size','MTimeUtc','Role','WinnerReason','StagedAs','Path']
    html = [
        '<!doctype html><meta charset="utf-8"><title>LOR Preview Compare</title>',
        '<style>body{font:14px system-ui,Segoe UI,Arial}table{border-collapse:collapse;width:100%}th,td{border:1px solid #ddd;padding:6px}th{background:#f4f6f8;text-align:left}tr:nth-child(even){background:#fafafa}</style>',
        '<h2>LOR Preview Compare</h2>',
        f"<p>Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}</p>",
        '<table><thead><tr>' + ''.join(f'<th>{h}</th>' for h in headers) + '</tr></thead><tbody>'
    ]
    for r in rows:
        html.append('<tr>' + ''.join(f'<td>{esc(str(r.get(h,'')))}</td>' for h in headers) + '</tr>')
    html.append('</tbody></table>')
    report_html.write_text('\n'.join(html), encoding='utf-8')

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
            data = json.loads(p.read_text(encoding='utf-8'))
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

    ap = argparse.ArgumentParser(description='Collect and stage LOR .lorprev files with conflict detection and history DB.', fromfile_prefix_chars='@')
    ap.add_argument('--config', help='Path to JSON config file (optional)')
    ap.add_argument('--input-root', default=defaults['input_root'])
    ap.add_argument('--staging-root', default=defaults['staging_root'])
    ap.add_argument('--archive-root', default=defaults['archive_root'])
    ap.add_argument('--history-db', default=defaults['history_db'])
    ap.add_argument('--report', default=defaults['report_csv'])
    ap.add_argument('--report-html', default=defaults['report_html'])
    ap.add_argument('--policy', choices=['prefer-revision-then-mtime','prefer-mtime'], default=defaults['policy'])
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--force-winner', action='append', default=[])
    ap.add_argument('--ensure-users', default=defaults['ensure_users'], help='Comma-separated list to ensure folders exist under input-root (e.g., usernames)')
    ap.add_argument('--user-map', help='Semicolon-separated username=email pairs, e.g. "gliebig=greg@sheboyganlights.org"')
    ap.add_argument('--user-map-json', help='Path to JSON mapping {"gliebig":"greg@sheboyganlights.org"}')
    ap.add_argument('--email-domain', default=defaults['email_domain'], help='If set, any username without a mapping gets username@<domain>')

    args = ap.parse_args()

    input_root   = Path(args.input_root)
    staging_root = Path(args.staging_root)
    archive_root = Path(args.archive_root) if args.archive_root else None
    report_csv   = Path(args.report)
    report_html  = Path(args.report_html) if args.report_html else None
    history_db   = Path(args.history_db)

    # Ensure required folders
    ensure_dir(input_root)
    ensure_dir(staging_root)
    if archive_root: ensure_dir(archive_root)
    ensure_dir(report_csv.parent)
    ensure_dir(history_db.parent)

    # Optionally ensure user subfolders
    if args.ensure_users:
        for u in [s.strip() for s in args.ensure_users.split(',') if s.strip()]:
            ensure_dir(input_root / u)

    # Build user→email map
    user_map = load_user_map(args.user_map, args.user_map_json)

    # History DB: start run
    conn = history_connect(history_db)
    run_id = hashlib.sha256(os.urandom(16)).hexdigest()
    conn.execute('INSERT INTO runs(run_id, started_utc, policy) VALUES (?,?,?)', (run_id, datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S'), args.policy))
    conn.commit()

    # Scan candidates (root only)
    candidates = scan_input(input_root, user_map, args.email_domain)

    # Record file observations
    with conn:
        for c in candidates:
            conn.execute(
                'INSERT INTO file_observations(run_id,user,user_email,path,file_name,preview_key,preview_guid,preview_name,revision_raw,revision_num,file_size,mtime_utc,sha256) '
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
    force_set = {str(Path(p).resolve()) for p in args.force_winner}

    for key, group in sorted(groups.items(), key=lambda kv: kv[0]):
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
        staged_dest = staging_root / staged_filename

        # Report rows
        for c in sorted(group, key=lambda x: (x.identity.revision_num if x.identity.revision_num is not None else -1, x.mtime), reverse=True):
            rows.append({
                'Key': key,
                'PreviewName': c.identity.name or '',
                'GUID': c.identity.guid or '',
                'Revision': c.identity.revision_raw or '',
                'User': c.user,
                'UserEmail': c.user_email or '',
                'Path': c.path,
                'Size': c.size,
                'MTimeUtc': ymd_hms(c.mtime),
                'SHA256': c.sha256,
                'Role': 'WINNER' if c is winner else 'CANDIDATE',
                'WinnerReason': reason if c is winner else '',
                'StagedAs': str(staged_dest) if c is winner else ''
            })

        # Stage/Archive/Record decisions (unless dry‑run)
        if not args.dry_run:
            stage_copy(Path(winner.path), staged_dest)
            with conn:
                conn.execute('INSERT INTO staging_decisions(run_id,preview_key,winner_path,staged_as,decision_reason,conflict,action) VALUES (?,?,?,?,?,?,?)',
                             (run_id, key, winner.path, str(staged_dest), reason, int(conflict), 'staged'))

            if archive_root and losers:
                day = datetime.utcnow().strftime('%Y-%m-%d')
                for l in losers:
                    arch_dest = archive_root / day / sanitize_name(l.user) / (default_stage_name(l.identity, Path(l.path)).replace('.lorprev', f"__from_{sanitize_name(l.user)}.lorprev"))
                    ensure_dir(arch_dest.parent)
                    stage_copy(Path(l.path), arch_dest)
                    with conn:
                        conn.execute('INSERT INTO staging_decisions(run_id,preview_key,winner_path,staged_as,decision_reason,conflict,action) VALUES (?,?,?,?,?,?,?)',
                                     (run_id, key, winner.path, str(arch_dest), 'archived non‑winner', 0, 'archived'))

        manifest.append({
            'key': key,
            'staged_as': str(staged_dest),
            'winner': asdict(winner),
            'losers': [asdict(l) for l in losers],
            'reason': reason,
            'conflict': conflict,
        })

    # Write CSV/HTML
    write_csv(report_csv, rows)
    if report_html:
        write_html(report_html, rows)

    # Optional manifest JSON next to CSV
    manifest_path = report_csv.with_suffix('.manifest.json')
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding='utf-8')

    print(f"\nOK. Report: {report_csv}")
    if report_html: print(f"HTML: {report_html}")
    print(f"History DB: {history_db}")
    if not args.dry_run:
        print(f"Staged → {staging_root}")
        if archive_root: print(f"Archived non‑winners → {archive_root}")

    if conflicts_found:
        print('\nCONFLICTS detected — review report/HTML. (Exit 2)')
        sys.exit(2)


if __name__ == '__main__':
    main()
