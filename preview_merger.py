#!/usr/bin/env python3
"""
lorprev_merger.py — Collect Light‑O‑Rama .lorprev files from per‑user folders,
compare by Preview identity (GUID id + Name + Revision), detect conflicts, and
safely stage the chosen versions into a private staging folder used to build the DB.

Windows‑friendly; pure Python 3.9+ (no 3rd‑party packages).

Typical layout (you choose the actual paths):

  G:/Shared drives/MSB Database/UserPreviewStaging/
    Adam/*.lorprev
    Rich/*.lorprev
    Greg/*.lorprev
    ShowPC/*.lorprev
    OfficePC/*.lorprev

  Staging ("secret" location — do not edit here manually):
  G:/Shared drives/MSB Database/_secret_staging/

Usage (dry‑run first):
  py preview_merger.py \
     --input-root "G:/Shared drives/MSB Database/UserPreviewStaging/" \
     --staging-root "G:/Shared drives/MSB Database/_secret_staging" \
     --archive-root "G:/Shared drives/MSB Database/_staging_archive" \
     --report "G:/Shared drives/MSB Database/_reports/lorprev_compare.csv" \
     --policy prefer-revision-then-mtime \
     --dry-run

Perform moves after you review the report:
  py lorprev_merger.py --input-root "..." --staging-root "..." --archive-root "..." --report "..." --policy prefer-revision-then-mtime

Then point parse_props_v6.py at STAGING_ROOT for the "Database Previews" folder.

Selection policy:
  prefer-revision-then-mtime (default)
    • If numeric Revisions differ, pick higher numeric.
    • Else pick latest file modified time (mtime).
  prefer-mtime
    • Always pick latest mtime; Revision only shown in report.

Conflicts:
  • If different file content exists with *same* Revision from multiple users,
    this is flagged as a CONFLICT. The script exits with code 2 and does not move files
    (unless you pass --force-winner <fullpath> for specific preview id/Name).

Outputs:
  • CSV report of all candidates and the chosen winner
  • JSON manifest in staging (manifest.json) with provenance and checksums
  • Optional archival of non‑winners into archive folder (with dated subfolders)

"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import xml.etree.ElementTree as ET
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
import shutil
import sys

# -------------- Data models --------------

@dataclass
class PreviewIdentity:
    guid: Optional[str]
    name: Optional[str]
    revision_raw: Optional[str]
    revision_num: Optional[float]  # parsed numeric revision if possible

@dataclass
class Candidate:
    key: str  # stable identity key (guid if present else sanitized name)
    identity: PreviewIdentity
    user: str  # top-level folder name beneath input_root
    path: str
    size: int
    mtime: float
    sha256: str

# -------------- Helpers --------------

def parse_preview_identity(file_path: Path) -> Optional[PreviewIdentity]:
    try:
        tree = ET.parse(file_path)
        root = tree.getroot()
        for el in root.iter():
            if el.tag.endswith("PreviewClass"):
                guid = el.get("id") or None
                name = el.get("Name") or None
                rev = el.get("Revision") or None
                rev_num = None
                if rev is not None:
                    try:
                        rev_num = float(rev)
                    except Exception:
                        rev_num = None
                return PreviewIdentity(guid=guid, name=name, revision_raw=rev, revision_num=rev_num)
        return None
    except Exception:
        return None


def sha256_file(path: Path, chunk: int = 1 << 20) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        while True:
            b = f.read(chunk)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def sanitize_name(s: str) -> str:
    return ''.join(ch if ch.isalnum() or ch in (' ', '-', '_', '.') else '_' for ch in s).strip()


def identity_key(idy: PreviewIdentity) -> Optional[str]:
    if idy.guid:
        return f"GUID:{idy.guid}"
    if idy.name:
        return f"NAME:{idy.name.strip().lower()}"
    return None


def ymd_hms(ts: float) -> str:
    return datetime.fromtimestamp(ts, tz=timezone.utc).strftime('%Y-%m-%d %H:%M:%S%z')

# -------------- Core logic --------------

def scan_input(input_root: Path) -> List[Candidate]:
    candidates: List[Candidate] = []
    for user_dir in input_root.iterdir():
        if not user_dir.is_dir():
            continue
        user = user_dir.name
        for path in user_dir.rglob('*.lorprev'):
            idy = parse_preview_identity(path)
            if not idy:
                continue
            key = identity_key(idy)
            if not key:
                continue
            stat = path.stat()
            candidates.append(
                Candidate(
                    key=key,
                    identity=idy,
                    user=user,
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


def choose_winner(group: List[Candidate], policy: str) -> Tuple[Candidate, List[Candidate], Optional[str], bool]:
    """Return (winner, losers, reason, conflict)"""
    # If only one, it's the winner
    if len(group) == 1:
        return group[0], [], 'single candidate', False

    # Policy: prefer numeric revision if available and not all equal/None
    reason = ''
    conflict = False

    def latest_by_mtime(items: List[Candidate]) -> Candidate:
        return sorted(items, key=lambda c: c.mtime, reverse=True)[0]

    if policy == 'prefer-mtime':
        winner = latest_by_mtime(group)
        reason = 'latest mtime'
    else:
        # prefer-revision-then-mtime
        # Gather numeric revisions (None treated as -inf)
        max_rev = None
        with_rev = []
        for c in group:
            if c.identity.revision_num is not None:
                with_rev.append(c)
                if (max_rev is None) or (c.identity.revision_num > max_rev):
                    max_rev = c.identity.revision_num
        if max_rev is not None:
            rev_max_set = [c for c in group if c.identity.revision_num == max_rev]
            if len(rev_max_set) == 1:
                winner = rev_max_set[0]
                reason = f'highest numeric Revision={max_rev}'
            else:
                # Multiple with same highest revision — compare content hashes
                hashes = {c.sha256 for c in rev_max_set}
                if len(hashes) == 1:
                    winner = latest_by_mtime(rev_max_set)
                    reason = f'same Revision={max_rev}, identical content; picked latest mtime'
                else:
                    # same revision but different content => conflict
                    winner = latest_by_mtime(rev_max_set)
                    reason = f'CONFLICT: same Revision={max_rev} but different content; picked latest mtime (requires human review)'
                    conflict = True
        else:
            # no numeric revisions — fall back to mtime
            winner = latest_by_mtime(group)
            reason = 'no numeric Revision; picked latest mtime'

    losers = [c for c in group if c is not winner]
    return winner, losers, reason, conflict


def ensure_dir(p: Path) -> None:
    p.mkdir(parents=True, exist_ok=True)


def stage_copy(src: Path, dst: Path) -> None:
    # If destination exists with different content, create timestamped backup
    if dst.exists():
        try:
            if sha256_file(dst) != sha256_file(src):
                backup = dst.with_suffix(dst.suffix + f".bak.{datetime.now().strftime('%Y%m%d-%H%M%S')}")
                shutil.copy2(dst, backup)
        except Exception:
            pass
    ensure_dir(dst.parent)
    shutil.copy2(src, dst)


def default_stage_name(idy: PreviewIdentity, winner_src: Path) -> str:
    # Prefer human readable: <sanitized Name>__<GUIDprefix>.lorprev
    base = 'preview'
    if idy.name:
        base = sanitize_name(idy.name)
    elif idy.guid:
        base = f'preview_{idy.guid[:8]}'
    else:
        base = winner_src.stem
    suffix = '.lorprev'
    tag = ''
    if idy.guid:
        tag = f"__{idy.guid[:8]}"
    return f"{base}{tag}{suffix}"


def write_manifest(manifest_path: Path, records: List[Dict]) -> None:
    tmp = manifest_path.with_suffix('.json.tmp')
    with tmp.open('w', encoding='utf-8') as f:
        json.dump(records, f, indent=2)
    tmp.replace(manifest_path)


def write_report(report_csv: Path, rows: List[Dict]) -> None:
    ensure_dir(report_csv.parent)
    fieldnames = list(rows[0].keys()) if rows else [
        'Key','PreviewName','GUID','Revision','User','Path','Size','MTimeUtc','SHA256','Role','WinnerReason','StagedAs']
    with report_csv.open('w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in rows:
            w.writerow(r)


def main():
    ap = argparse.ArgumentParser(description='Collect and stage LOR .lorprev files from per-user folders with conflict detection.')
    ap.add_argument('--input-root', required=True, help='Folder containing per-user subfolders of .lorprev files')
    ap.add_argument('--staging-root', required=True, help='Private staging destination (used by DB builder)')
    ap.add_argument('--archive-root', required=False, help='Optional archive for non-winners')
    ap.add_argument('--report', required=True, help='CSV report path to write comparison results')
    ap.add_argument('--policy', choices=['prefer-revision-then-mtime','prefer-mtime'], default='prefer-revision-then-mtime')
    ap.add_argument('--dry-run', action='store_true', help='Only generate report; do not copy files')
    ap.add_argument('--force-winner', action='append', default=[], help='Full path(s) of files to force as winner for their identity')
    args = ap.parse_args()

    input_root = Path(args.input_root)
    staging_root = Path(args.staging_root)
    archive_root = Path(args.archive_root) if args.archive_root else None
    report_csv = Path(args.report)

    if not input_root.is_dir():
        print(f"ERROR: input-root does not exist: {input_root}")
        sys.exit(1)

    candidates = scan_input(input_root)
    groups = group_by_key(candidates)

    rows: List[Dict] = []
    manifest: List[Dict] = []

    conflicts_found = False

    # Index forced winners by real path for quick lookup
    force_set = {str(Path(p).resolve()) for p in args.force_winner}

    for key, group in sorted(groups.items(), key=lambda kv: kv[0]):
        # If any forced winner belongs to this group, pick it
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

        # Report rows for all candidates
        for c in sorted(group, key=lambda x: (x.identity.revision_num if x.identity.revision_num is not None else -1, x.mtime), reverse=True):
            rows.append({
                'Key': key,
                'PreviewName': c.identity.name or '',
                'GUID': c.identity.guid or '',
                'Revision': c.identity.revision_raw or '',
                'User': c.user,
                'Path': c.path,
                'Size': c.size,
                'MTimeUtc': ymd_hms(c.mtime),
                'SHA256': c.sha256,
                'Role': 'WINNER' if c is winner else 'CANDIDATE',
                'WinnerReason': reason if c is winner else '',
                'StagedAs': str(staged_dest) if c is winner else ''
            })

        # Copy winner (and optionally archive losers) if not dry-run
        if not args.dry_run:
            ensure_dir(staging_root)
            stage_copy(Path(winner.path), staged_dest)

            if archive_root and losers:
                # Subfolder by date key
                day = datetime.utcnow().strftime('%Y-%m-%d')
                for l in losers:
                    arch_dest = archive_root / day / sanitize_name(l.user) / (default_stage_name(l.identity, Path(l.path)).replace('.lorprev', f"__from_{sanitize_name(l.user)}.lorprev"))
                    ensure_dir(arch_dest.parent)
                    stage_copy(Path(l.path), arch_dest)

            manifest.append({
                'key': key,
                'staged_as': str(staged_dest),
                'winner': asdict(winner),
                'losers': [asdict(l) for l in losers],
                'reason': reason,
                'conflict': conflict,
            })

    # Write outputs
    write_report(report_csv, rows)

    if not args.dry_run:
        ensure_dir(staging_root)
        write_manifest(staging_root / 'manifest.json', manifest)

    if conflicts_found:
        print('\nCONFLICTS detected. See report for details. No action taken where human review is advised.' )
        # Non-zero so CI or scripts can react
        sys.exit(2)

    print(f"\nOK. Report written to: {report_csv}")
    if not args.dry_run:
        print(f"Staged previews -> {staging_root}")
        if args.archive_root:
            print(f"Archived non-winners -> {archive_root}")


if __name__ == '__main__':
    main()
