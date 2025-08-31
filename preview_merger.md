# Preview Merger — Runbook & Reference

This script scans user preview exports (`*.lorprev`), groups candidates by **preview key**, chooses a **WINNER**, compares it to the current **STAGED** copy, and writes CSV/HTML reports. Optionally stages files when `--apply` is used.

**Time:** All times shown are **local tz-aware** with offset. Report column `Exported` replaces the old `MTimeUtc`.  
**Policies:** default is `prefer-revision-then-exported`. Legacy `*-mtime` names are accepted and remapped.

---

## Quick Start
1. Confirm config or defaults.
2. Dry run:
   ```bash
   py preview_merger.py --progress --debug --show-actions
   ```
3. Review `lorprev_compare.csv/.html` and console `[summary]`/`[actions]`.
4. Apply:
   ```bash
   py preview_merger.py --apply --progress
   ```
5. Confirm (expect mostly `noop`):
   ```bash
   py preview_merger.py --progress
   ```

---

## Report Rows & Columns
Per **preview key** you’ll see:
- **WINNER** — chosen user copy.
- **STAGED** — current staged copy for the same key (top-level only).
- **CANDIDATE** — other user copies.
- **STAGED-ONLY** (tail) — staged files with no matching winner this run.

Key columns:
- `Exported` — local exported time (fs mtime).
- `CommentsFilled`, `CommentsTotal`, `CommentNoSpace` — comment metrics.
- `Action`:
  - WINNER: `noop | update-staging | stage-new`
  - STAGED: `current | out-of-date | staged-only`
- Hash helpers: `Sha8` (row), `WinnerSha8`, `StagedSha8`.
- `WinnerFrom`: `USER:<name>`.

---

## Policies (`--policy`)
- `prefer-revision-then-exported` (default): highest numeric **Revision**, tie → better **comments**; if no numeric revision, pick latest **Exported** time.
- `prefer-exported`: latest **Exported** time wins.
- `prefer-comments-then-revision`: prefer comment coverage first, then revision.

Legacy aliases are remapped:
- `prefer-revision-then-mtime` → `prefer-revision-then-exported`
- `prefer-mtime` → `prefer-exported`

---

## Staging Resolution (non‑recursive)
- Scans **top level** of `staging_root` only.
- Match staged by **Key**, then **GUID**, then canonical filename.
- Identical bytes → WINNER `Action=noop`, STAGED `current`.

---

## Flags
- `--config FILE` — optional JSON config.
- `--input-root`, `--staging-root`, `--archive-root`
- `--history-db`, `--report`, `--report-html`
- `--policy` (see above); `--apply` (perform file ops)
- `--force-winner KEY=PATH` (repeatable)
- `--ensure-users`, `--user-map`, `--user-map-json`, `--email-domain`
- `--debug` — diagnostics to stderr
- `--progress` — shows “Building report: n/N (xx%)”
- `--show-actions` — prints compact list of items needing work

---

## Summary Output
Console `[summary]` shows totals for winners and staged (linked vs staged-only).  
With `--show-actions`, it prints per-key details (name, action, reason, sha8s, exported).

---

## DB schema (history)
- `runs(run_id, started, policy)`
- `file_observations(..., exported, sha256)`
- `staging_decisions(run_id, preview_key, winner_path, staged_as, decision_reason, conflict, action)`
- `preview_state(preview_key, ..., sha256, staged_as, last_run_id, last_seen)`

All timestamps are stored as local tz-aware ISO (`YYYY-MM-DDTHH:MM:SS±HH:MM`).

---

## Yearly Workflow
1) Dry-run audit → fix issues.  
2) `--apply` to stage.  
3) Re-run (mostly `noop`).

Non-recursive design keeps the report predictable.
